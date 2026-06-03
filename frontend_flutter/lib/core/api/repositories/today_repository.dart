import 'dart:ui' as ui;

import 'package:shared_preferences/shared_preferences.dart';

import '../../local/local_capture_repository.dart';
import '../../local/local_daily_snapshot_repository.dart';
import '../../models/today_models.dart';
import '../api_client.dart';
import 'analytics_repository.dart';
import 'ai_repository.dart';

typedef FocusAreaLoader = Future<String?> Function();
typedef ResponseStyleLoader = Future<String?> Function();

class TodayRepository {
  final LocalCaptureRepository localCaptureRepository;
  final LocalDailySnapshotRepository localDailySnapshotRepository;
  final AiRepository aiRepository;
  final ApiClient? apiClient;
  final AnalyticsRepository? analyticsRepository;
  final FocusAreaLoader? focusAreaLoader;
  final ResponseStyleLoader? responseStyleLoader;

  TodayRepository({
    required this.localCaptureRepository,
    required this.localDailySnapshotRepository,
    required this.aiRepository,
    this.apiClient,
    this.analyticsRepository,
    this.focusAreaLoader,
    this.responseStyleLoader,
  });

  Future<Map<String, dynamic>> fetchToday() async {
    await retryPendingDrafts();
    if (apiClient != null) {
      try {
        final remoteSignals = await _fetchRemoteSignalCards();
        await localCaptureRepository.upsertRemoteSignalCards(remoteSignals);
      } catch (_) {
        // 远端不可用时继续使用本地 SignalCard 缓存和 draft queue。
      }
    }

    final allSignals = apiClient == null
        ? await localCaptureRepository.listRecentSignals(limit: 200)
        : await localCaptureRepository.listSignalCards(limit: 200);
    final todaySignals = allSignals
        .where((signal) => signal.localDateKey() == _dateKey(DateTime.now()))
        .toList();
    final snapshot =
        await localDailySnapshotRepository.getByDate(DateTime.now());

    final sourceHash =
        localDailySnapshotRepository.buildSourceHash(todaySignals);

    if (todaySignals.isNotEmpty &&
        (snapshot == null || snapshot.sourceHash != sourceHash)) {
      await _regenerateTodaySummary(todaySignals);
    }

    final latestSnapshot =
        await localDailySnapshotRepository.getByDate(DateTime.now());
    final latestSignals = apiClient == null
        ? allSignals
        : await localCaptureRepository.listSignalCards(limit: 200);

    return {
      'insight': TodayInsightModel(
        text: latestSnapshot?.observationText ??
            _defaultObservation(todaySignals),
      ),
      'pendingQuestion': null,
      'bestAction': DailyBestActionModel(
        text:
            latestSnapshot?.suggestionText ?? _defaultSuggestion(todaySignals),
      ),
      'recentSignals': latestSignals,
    };
  }

  Future<RecentSignalModel?> getCaptureById(String captureId) {
    return localCaptureRepository.getCaptureById(captureId);
  }

  Future<LightDialogResponseModel> continueLightDialog({
    required RecentSignalModel signal,
    required List<LightDialogTurnModel> history,
    required String userMessage,
  }) async {
    final focusArea = await _readFocusArea();
    final responseStyle = await _readResponseStyle();
    return aiRepository.generateLightDialog(
      signal: signal,
      history: history,
      userMessage: userMessage,
      focusArea: focusArea,
      responseStyle: responseStyle,
    );
  }

  Future<Map<String, dynamic>> submitCapture({
    required String content,
    String? tagHint,
    String sourceType = 'text',
    Map<String, dynamic> rawPayloadJson = const {},
  }) async {
    if (apiClient != null) {
      return _submitCaptureViaSignalCard(
        content: content,
        tagHint: tagHint,
        sourceType: sourceType,
        rawPayloadJson: rawPayloadJson,
      );
    }

    final inserted = await localCaptureRepository.insertCapture(
      content: content,
      inputMode: sourceType,
      tagHint: tagHint,
    );
    await analyticsRepository?.track(
      'entry_created',
      properties: {
        'content_length': content.trim().length,
        'has_tag_hint': tagHint != null && tagHint.trim().isNotEmpty,
      },
    );

    final focusArea = await _readFocusArea();
    final responseStyle = await _readResponseStyle();
    final recentAssistantTexts =
        await localCaptureRepository.listRecentAcknowledgements(limit: 10);

    late AiCaptureReplyResult aiReply;

    try {
      aiReply = await aiRepository.generateCaptureReply(
        content: content,
        recentAssistantTexts: recentAssistantTexts,
        focusArea: focusArea,
        responseStyle: responseStyle,
      );
    } catch (_) {
      aiReply = AiCaptureReplyResult(
        acknowledgement: _defaultAcknowledgement(content),
        observation: _defaultSingleObservation(content),
        tryNext: _defaultSingleTryNext(content),
        emotion: _defaultEmotion(content),
        intensity: _defaultIntensity(content),
        sceneTags: _defaultSceneTags(content),
        intentTags: _defaultIntentTags(content),
        followup: null,
      );
    }

    if (inserted.id != null) {
      await localCaptureRepository.updateAiReply(
        captureId: inserted.id!,
        acknowledgement: aiReply.acknowledgement,
        observation: aiReply.observation,
        tryNext: aiReply.tryNext,
        emotion: aiReply.emotion,
        intensity: aiReply.intensity,
        sceneTags: aiReply.sceneTags,
        intentTags: aiReply.intentTags,
      );
    }

    final refreshedTodaySignals =
        await localCaptureRepository.listTodaySignals();

    await _regenerateTodaySummary(refreshedTodaySignals);

    return {
      'acknowledgement': aiReply.acknowledgement,
      'followup': aiReply.followup,
      'updatedRecentSignals': refreshedTodaySignals,
      'localSignal': RecentSignalModel(
        id: inserted.id,
        content: inserted.content,
        createdAt: inserted.createdAt,
        acknowledgement: aiReply.acknowledgement,
        observation: aiReply.observation,
        tryNext: aiReply.tryNext,
        emotion: aiReply.emotion,
        intensity: aiReply.intensity,
        sceneTags: aiReply.sceneTags,
        intentTags: aiReply.intentTags,
      ),
    };
  }

  Future<void> retryPendingDrafts() async {
    final client = apiClient;
    if (client == null) return;

    final drafts = await localCaptureRepository.listPendingDraftRows();
    for (final draft in drafts) {
      final draftId = draft['draft_id'] as String?;
      final rawText = draft['raw_text'] as String?;
      if (draftId == null || rawText == null || rawText.trim().isEmpty) {
        continue;
      }
      try {
        final response = await client.postJson(
          '/api/v1/captures',
          {
            'content': rawText,
            'input_mode': draft['source_type'] as String? ?? 'text',
            'tag_hint': draft['tag_hint'] as String?,
            'language': draft['language'] as String? ?? _languageCode(),
            'timezone': draft['timezone'] as String? ?? _timezoneName(),
          },
        );
        final signals = _parseRecentSignals(response);
        final remoteSignalId =
            signals.isEmpty ? null : signals.first.signalCardId;
        await localCaptureRepository.upsertRemoteSignalCards(signals);
        await localCaptureRepository.markDraftSynced(
          draftId: draftId,
          remoteSignalCardId: remoteSignalId,
        );
      } catch (e) {
        await localCaptureRepository.markDraftFailed(
          draftId: draftId,
          error: e.toString(),
        );
      }
    }
  }

  Future<void> confirmSignalCard({
    required String signalCardId,
    required String userConfirmation,
    Map<String, dynamic> userCorrectionJson = const {},
  }) async {
    await localCaptureRepository.updateSignalCardConfirmation(
      signalCardId: signalCardId,
      userConfirmation: userConfirmation,
      userCorrectionJson: userCorrectionJson,
    );

    final client = apiClient;
    if (client == null || signalCardId.startsWith('draft_')) return;

    try {
      await client.patchJson(
        '/api/v1/captures/signal-cards/$signalCardId/confirmation',
        {
          'user_confirmation': userConfirmation,
          'user_correction_json': userCorrectionJson,
        },
      );
    } catch (_) {
      // 确认动作先落本地；下一轮同步基础版不阻塞用户操作。
    }
  }

  Future<Map<String, dynamic>> _submitCaptureViaSignalCard({
    required String content,
    String? tagHint,
    String sourceType = 'text',
    Map<String, dynamic> rawPayloadJson = const {},
  }) async {
    final localDraft = await localCaptureRepository.insertLocalDraftSignal(
      content: content,
      sourceType: sourceType,
      tagHint: tagHint,
      language: _languageCode(),
      timezone: _timezoneName(),
      rawPayloadJson: rawPayloadJson,
    );
    await analyticsRepository?.track(
      'entry_created',
      properties: {
        'content_length': content.trim().length,
        'has_tag_hint': tagHint != null && tagHint.trim().isNotEmpty,
        'signal_card_source': 'v3b',
      },
    );

    try {
      final response = await apiClient!.postJson(
        '/api/v1/captures',
        {
          'content': content,
          'input_mode': sourceType,
          'tag_hint': tagHint,
          'language': _languageCode(),
          'timezone': _timezoneName(),
          if (rawPayloadJson.isNotEmpty) 'raw_payload_json': rawPayloadJson,
        },
      );
      final signals = _parseRecentSignals(response);
      await localCaptureRepository.upsertRemoteSignalCards(signals);
      await localCaptureRepository.markDraftSynced(
        draftId: localDraft.signalCardId ?? localDraft.id ?? '',
        remoteSignalCardId: signals.isEmpty ? null : signals.first.signalCardId,
      );
    } catch (e) {
      await localCaptureRepository.markDraftFailed(
        draftId: localDraft.signalCardId ?? localDraft.id ?? '',
        error: e.toString(),
      );
    }

    final allSignals = await localCaptureRepository.listSignalCards(limit: 200);
    final todaySignals = allSignals
        .where((signal) => signal.localDateKey() == _dateKey(DateTime.now()))
        .toList();
    await _regenerateTodaySummary(todaySignals);
    final latestSignals =
        await localCaptureRepository.listSignalCards(limit: 200);

    return {
      'acknowledgement': latestSignals
          .firstWhere(
            (signal) => signal.content == content,
            orElse: () => localDraft,
          )
          .acknowledgement,
      'followup': null,
      'updatedRecentSignals': latestSignals,
      'localSignal': localDraft,
    };
  }

  Future<List<RecentSignalModel>> _fetchRemoteSignalCards() async {
    final response = await apiClient!.getJson('/api/v1/captures/recent');
    return _parseRecentSignals(response);
  }

  List<RecentSignalModel> _parseRecentSignals(Map<String, dynamic> response) {
    final data = (response['data'] as Map<String, dynamic>?) ?? response;
    final raw = (data['recent_signals'] as List?) ??
        ((data['recentSignals'] as List?) ?? const []);
    return raw
        .whereType<Map>()
        .map((e) => RecentSignalModel.fromJson(
              e.map((key, value) => MapEntry(key.toString(), value)),
            ))
        .toList();
  }

  Future<void> submitFollowup({
    required String followupId,
    required String answerValue,
  }) async {
    // Phase 1 先不做后续问题回写；保留接口，避免页面层大改。
  }

  Future<void> _regenerateTodaySummary(
      List<RecentSignalModel> todaySignals) async {
    final focusArea = await _readFocusArea();
    final responseStyle = await _readResponseStyle();
    final summarySignals = _summaryEligibleSignals(todaySignals);

    String observationText;
    String suggestionText;

    if (summarySignals.isEmpty && todaySignals.isNotEmpty) {
      observationText = _deferredSummaryObservation(todaySignals);
      suggestionText = _deferredSummarySuggestion(todaySignals);
    } else {
      try {
        final result = await aiRepository.generateTodaySummary(
          date: DateTime.now(),
          entries: summarySignals,
          focusArea: focusArea,
          responseStyle: responseStyle,
        );
        observationText = result.observation;
        suggestionText = result.suggestion;
      } catch (_) {
        observationText = _defaultObservation(summarySignals);
        suggestionText = _defaultSuggestion(summarySignals);
      }
    }

    final sourceHash =
        localDailySnapshotRepository.buildSourceHash(todaySignals);

    await localDailySnapshotRepository.upsert(
      date: DateTime.now(),
      entryCount: todaySignals.length,
      observationText: observationText,
      suggestionText: suggestionText,
      sourceHash: sourceHash,
    );

    await localCaptureRepository.updateSignalCardInclusion(
      signalCardIds: summarySignals
          .map((signal) => signal.signalCardId ?? signal.id ?? '')
          .where((id) => id.trim().isNotEmpty),
      includedInSummary: true,
    );
  }

  List<RecentSignalModel> _summaryEligibleSignals(
      List<RecentSignalModel> signals) {
    return signals
        .where((signal) => !signal.isLegacy)
        .where((signal) => !signal.isLocalDraft)
        .where((signal) => !signal.syncFailed)
        .where((signal) => signal.userConfirmation != 'inaccurate')
        .where((signal) =>
            !signal.isLibrarySaved || signal.hasUserConfirmedLibrarySaved)
        .where((signal) =>
            !signal.isAiPredicted || signal.hasUserConfirmedAiPrediction)
        .toList();
  }

  Future<String?> _readResponseStyle() async {
    if (responseStyleLoader != null) {
      return responseStyleLoader!();
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('response_style_preference') ?? 'gentle';
    } catch (_) {
      return 'gentle';
    }
  }

  Future<String?> _readFocusArea() async {
    if (focusAreaLoader != null) {
      return focusAreaLoader!();
    }

    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('repeat_area_preference') ??
        prefs.getString('selected_repeat_area');
  }

  String _languageCode() {
    final locale = ui.PlatformDispatcher.instance.locale;
    final languageCode = locale.languageCode.toLowerCase();
    final scriptCode = locale.scriptCode?.toLowerCase();
    final countryCode = locale.countryCode?.toUpperCase();

    if (languageCode == 'ja') return 'ja';
    if (languageCode == 'zh') {
      final isTraditional = scriptCode == 'hant' ||
          countryCode == 'TW' ||
          countryCode == 'HK' ||
          countryCode == 'MO';
      return isTraditional ? 'zh-Hant' : 'zh-Hans';
    }
    return 'en';
  }

  String _timezoneName() {
    return DateTime.now().timeZoneName;
  }

  String _dateKey(DateTime date) {
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  String _defaultAcknowledgement(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return '先把这一条留在这里。';
    }

    final emotion = _defaultEmotion(content);
    final sceneTags = _defaultSceneTags(content);

    if (emotion == 'mixed') {
      return '这条里能感觉到你先被拉扯了一下，后面又靠一点具体的小事缓回来一些。';
    }
    if (emotion == 'positive') {
      if (sceneTags.contains('achievement')) {
        return '这一下不是普通地“还不错”，而是你真的感受到一点推进和成形。';
      }
      return '这条里有一个很具体的小好时刻，被你好好接住了。';
    }
    if (emotion == 'negative') {
      if (sceneTags.contains('work')) {
        return '这一下更像是工作里的节奏或失控感在消耗你，难怪会觉得烦。';
      }
      return '这一下听起来确实挺消耗人的，先把它放在这里就好。';
    }
    return '先把这一条留在这里也很好，它本身就是一个值得继续看的线索。';
  }

  String _defaultSingleObservation(String content) {
    final emotion = _defaultEmotion(content);
    final sceneTags = _defaultSceneTags(content);

    if (emotion == 'positive') {
      if (sceneTags.contains('achievement')) {
        return '今天比较值得记住的，是你会被“确实有推进”的感觉明显提起来。';
      }
      return '今天更清楚的线索是：一些具体的小好事，确实能给你补回状态。';
    }
    if (emotion == 'mixed') {
      return '这条里最值得记的是那种拉扯感：你会被消耗，也会被一些具体的东西重新接住。';
    }
    if (emotion == 'negative') {
      if (sceneTags.contains('work')) {
        return '今天更明显的不是情绪本身，而是工作里的打断、改动或失控感在反复磨你。';
      }
      return '今天更明显的不是一句“烦”，而是某个具体场景正在稳定地消耗你。';
    }
    return '你今天更像是在留下一条状态线索，而不是在表达一股很强的情绪。';
  }

  String _defaultSingleTryNext(String content) {
    final emotion = _defaultEmotion(content);
    final sceneTags = _defaultSceneTags(content);

    if (emotion == 'positive') {
      if (sceneTags.contains('achievement')) {
        return '先记住这一下具体是因为什么推进感出现的，之后很容易复用。';
      }
      return '先把让你感觉不错的那个具体点记下来，不用写多。';
    }
    if (emotion == 'mixed') {
      return '今天先别急着总结整天，只记住是什么让你后面稍微缓回来一点。';
    }
    if (emotion == 'negative') {
      if (sceneTags.contains('work')) {
        return '下次再出现时，只补一句它发生在什么工作场景里，就已经很有用了。';
      }
      return '先把最卡你的那个瞬间记下来，其他先不用整理。';
    }
    return '先把这一条放着，看看之后它会不会再回来。';
  }

  String _defaultObservation(List<RecentSignalModel> entries) {
    if (entries.isEmpty) {
      return '今天还没有记录，先留下一件真实发生的小事就好。';
    }
    if (entries.length == 1) {
      return entries.first.observation ?? '今天记录了 1 条。你已经开始把今天里真实发生的事留了下来。';
    }

    final mixedCount = entries.where((e) => e.emotion == 'mixed').length;
    final negativeCount = entries.where((e) => e.emotion == 'negative').length;
    final positiveCount = entries.where((e) => e.emotion == 'positive').length;

    if (mixedCount > 0) {
      return '今天记录了 ${entries.length} 条，几条线索不是单向变化，而是在来回拉扯。';
    }
    if (negativeCount >= positiveCount && negativeCount > 0) {
      return '今天记录了 ${entries.length} 条，更明显的是某些场景在反复消耗你。';
    }
    if (positiveCount > 0) {
      return '今天记录了 ${entries.length} 条，里面已经开始出现一些能把你拉回来的具体片段。';
    }
    return '今天记录了 ${entries.length} 条。今天的线索已经开始慢慢聚起来了。';
  }

  String _defaultSuggestion(List<RecentSignalModel> entries) {
    if (entries.isEmpty) {
      return '今天先记下一件让你停顿了一下的小事就好。';
    }
    if (entries.length == 1) {
      return entries.first.tryNext ?? '如果同类事情今天再出现一次，再补记一条就可以。';
    }

    final workHeavy = entries.where((e) => e.sceneTags.contains('work')).length;
    final mixedCount = entries.where((e) => e.emotion == 'mixed').length;

    if (mixedCount > 0) {
      return '今天先留意：哪些场景会把你拉低，哪些小事又会把你拉回来。';
    }
    if (workHeavy > 0) {
      return '今天可以先试试：下次再出现同类工作场景时，用一句话补记它发生在什么地方。';
    }
    return '接下来先留意：今天有没有哪类事情已经不是第一次这样发生。';
  }

  String _deferredSummaryObservation(List<RecentSignalModel> entries) {
    if (entries.any((signal) => signal.isLocalDraft || signal.syncFailed)) {
      return '今天可以先这样看：原文已经保存，等同步完成后再整理也来得及。';
    }
    if (entries.any((signal) => signal.isLegacy)) {
      return '今天可以先这样看：旧记录已经放回时间线，这里先不急着重新判断它。';
    }
    return '今天可以先这样看：记录已经留下，等线索更稳一点再整理。';
  }

  String _deferredSummarySuggestion(List<RecentSignalModel> entries) {
    if (entries.any((signal) => signal.isLocalDraft || signal.syncFailed)) {
      return '先不用重复输入，等网络恢复后同步这一条就好。';
    }
    return '先让这条记录待在这里，不需要马上给它下结论。';
  }

  String _defaultEmotion(String content) {
    final text = content.toLowerCase();

    final positiveKeywords = [
      '开心',
      '高兴',
      '喜欢',
      '顺利',
      '放松',
      '舒服',
      '满足',
      '期待',
      '有成就感',
      '轻松',
      '好吃',
      '快乐',
      '愉快',
      '安心',
      '踏实',
      '嬉しい',
      '楽しい',
      'よかった',
      '満足',
      '安心',
      'happy',
      'glad',
      'good',
      'great',
      'relieved',
      'nice',
    ];
    final negativeKeywords = [
      '烦',
      '累',
      '崩',
      '难受',
      '焦虑',
      '生气',
      '压力',
      '不想',
      '麻烦',
      '受不了',
      '被打断',
      '烦躁',
      '委屈',
      '失控',
      '糟糕',
      '痛苦',
      '压抑',
      'しんどい',
      'つらい',
      '疲れた',
      'イライラ',
      '不安',
      '最悪',
      'annoyed',
      'tired',
      'upset',
      'angry',
      'anxious',
      'stressed',
      'frustrated',
    ];
    final mixedMarkers = [
      '但是',
      '但',
      '不过',
      '后来',
      '虽然',
      '又',
      '缓回来',
      '好了一点',
      'けど',
      'でも',
      'そのあと',
      'but',
      'however',
      'though',
      'later',
    ];

    final hasPositive = positiveKeywords.any(text.contains);
    final hasNegative = negativeKeywords.any(text.contains);
    final hasMixedMarker = mixedMarkers.any(text.contains);

    if ((hasPositive && hasNegative) ||
        (hasMixedMarker && (hasPositive || hasNegative))) {
      return 'mixed';
    }
    if (hasNegative) return 'negative';
    if (hasPositive) return 'positive';
    return 'neutral';
  }

  String _defaultIntensity(String content) {
    final text = content.toLowerCase();

    final strongMarkers = [
      '一直',
      '总是',
      '反复',
      '受不了',
      '崩了',
      '特别',
      '非常',
      '真的',
      '很烦',
      '很累',
      'ずっと',
      'かなり',
      '本当に',
      'めちゃくちゃ',
      'very',
      'really',
      'extremely',
    ];
    final mediumMarkers = [
      '有点',
      '有一些',
      '有一点',
      '有些',
      '稍微',
      'ちょっと',
      '少し',
      'a bit',
      'kind of',
      'somewhat',
    ];

    if (strongMarkers.any(text.contains) ||
        content.contains('!') ||
        content.contains('！')) {
      return 'high';
    }
    if (mediumMarkers.any(text.contains) ||
        _defaultEmotion(content) != 'neutral') {
      return 'medium';
    }
    return 'low';
  }

  List<String> _defaultSceneTags(String content) {
    final text = content.toLowerCase();
    final scenes = <String>[];

    bool hit(List<String> keywords) => keywords.any(text.contains);

    if (hit([
      '上班',
      '开会',
      '同事',
      '老板',
      '需求',
      '任务',
      '公司',
      '工作',
      '邮件',
      '会议',
      '職場',
      '仕事',
      '会議',
      'task',
      'work',
      'meeting',
      'manager'
    ])) {
      scenes.add('work');
    }
    if (hit(
        ['通勤', '地铁', '电车', '路上', '回家路上', '出门', '満員電車', 'commute', 'train'])) {
      scenes.add('commute');
    }
    if (hit([
      '朋友',
      '家人',
      '恋人',
      '关系',
      '聊天',
      '人間関係',
      'family',
      'friend',
      'partner'
    ])) {
      scenes.add('relationship');
    }
    if (hit([
      '头疼',
      '困',
      '睡',
      '累',
      '身体',
      '胃',
      '不舒服',
      '健康',
      '体調',
      '眠い',
      'body',
      'health'
    ])) {
      scenes.add('body');
    }
    if (hit([
      '花钱',
      '工资',
      '金钱',
      '消费',
      '买',
      '预算',
      'お金',
      '支出',
      'money',
      'budget',
      'spent'
    ])) {
      scenes.add('money');
    }
    if (hit(
        ['休息', '放松', '睡觉', '午休', '恢复', '发呆', '散步', '休憩', 'rest', 'relax'])) {
      scenes.add('rest');
    }
    if (hit([
      '完成',
      '做完',
      '推进',
      '成果',
      '达成',
      '有进展',
      '進んだ',
      '達成',
      'finished',
      'done'
    ])) {
      scenes.add('achievement');
    }
    if (hit(['怀疑自己', '自我否定', '不够好', '没做好', '担心自己', '自信がない', 'self doubt'])) {
      scenes.add('self_doubt');
    }
    if (hit([
      '被打断',
      '重复',
      '麻烦',
      '卡住',
      '拖延',
      '琐事',
      '不顺',
      'interrupted',
      'blocked',
      'friction'
    ])) {
      scenes.add('daily_friction');
    }
    if (hit(['在家', '回家', '房间', '家里', '家务', '家', '家で', 'home'])) {
      scenes.add('home');
    }
    if (hit([
      '学习',
      '看书',
      '复习',
      '考试',
      '输出',
      '写作',
      '勉強',
      'study',
      'reading',
      'writing'
    ])) {
      scenes.add('study');
    }
    if (hit(
        ['吃饭', '好吃', '逛', '买东西', '天气', '散步', '咖啡', '食べた', 'lunch', 'coffee'])) {
      scenes.add('daily_life');
    }

    if (scenes.isEmpty) {
      return _defaultEmotion(content) == 'negative'
          ? const ['daily_friction']
          : const ['daily_life'];
    }
    return scenes.take(3).toList();
  }

  List<String> _defaultIntentTags(String content) {
    final emotion = _defaultEmotion(content);
    final text = content.toLowerCase();
    final intents = <String>[];

    if (emotion == 'negative') intents.add('vent');
    if (emotion == 'positive') intents.add('celebrate');
    if (emotion == 'mixed') {
      intents.add('vent');
      intents.add('reflection');
    }
    if (intents.isEmpty) intents.add('record');

    if (['为什么', '是不是', '感觉', '好像', '也许', 'maybe', 'wonder', '気がする']
            .any(text.contains) &&
        !intents.contains('reflection')) {
      intents.add('reflection');
    }

    if (['要不要', '决定', '算了', 'whether', 'decide', '決める'].any(text.contains) &&
        !intents.contains('decision')) {
      intents.add('decision');
    }

    return intents.take(3).toList();
  }
}
