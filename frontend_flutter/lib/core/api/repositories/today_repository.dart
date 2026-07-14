import 'dart:async';
import 'dart:ui' as ui;

import 'package:shared_preferences/shared_preferences.dart';

import '../../backup/cloud_backup_sync_service.dart';
import '../../eligibility/signal_eligibility_service.dart';
import '../../local/local_capture_repository.dart';
import '../../local/local_daily_snapshot_repository.dart';
import '../../local/local_life_experiment_repository.dart';
import '../../local/local_pipeline_run_repository.dart';
import '../../local/local_phase3_plus_repository.dart';
import '../../models/phase3_plus_models.dart';
import '../../models/today_models.dart';
import '../../i18n/app_locale_text.dart';
import '../../preferences/focus_domains.dart';
import '../api_client.dart';
import 'analytics_repository.dart';
import 'ai_repository.dart';

typedef FocusAreaLoader = Future<String?> Function();
typedef ResponseStyleLoader = Future<String?> Function();
typedef TodayNowLoader = DateTime Function();

class TodayRepository {
  final LocalCaptureRepository localCaptureRepository;
  final LocalDailySnapshotRepository localDailySnapshotRepository;
  final LocalLifeExperimentRepository? localLifeExperimentRepository;
  final LocalPhase3PlusRepository? localPhase3PlusRepository;
  final AiRepository aiRepository;
  final ApiClient? apiClient;
  final AnalyticsRepository? analyticsRepository;
  final FocusAreaLoader? focusAreaLoader;
  final ResponseStyleLoader? responseStyleLoader;
  final CloudBackupSyncService? cloudBackupSyncService;
  final SignalEligibilityService eligibilityService;
  final String localUserId;
  final TodayNowLoader? nowLoader;

  TodayRepository({
    required this.localCaptureRepository,
    required this.localDailySnapshotRepository,
    this.localLifeExperimentRepository,
    this.localPhase3PlusRepository,
    required this.aiRepository,
    this.apiClient,
    this.analyticsRepository,
    this.focusAreaLoader,
    this.responseStyleLoader,
    this.cloudBackupSyncService,
    this.localUserId = 'local',
    this.nowLoader,
    SignalEligibilityService? eligibilityService,
  }) : eligibilityService =
            eligibilityService ?? const SignalEligibilityService();

  Future<Map<String, dynamic>> fetchToday() async {
    final now = nowLoader?.call() ?? DateTime.now();
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
    final todayKey = _dateKey(now);
    final todaySignals = allSignals
        .where((signal) => signal.localDateKey() == todayKey)
        .toList();
    final snapshot = await localDailySnapshotRepository.getByDate(now);

    final sourceHash =
        localDailySnapshotRepository.buildSourceHash(todaySignals);

    if (todaySignals.isNotEmpty &&
        (snapshot == null || snapshot.sourceHash != sourceHash)) {
      await _regenerateTodaySummary(todaySignals);
    }

    final latestSnapshot = await localDailySnapshotRepository.getByDate(now);
    final latestSignals = apiClient == null
        ? allSignals
        : await localCaptureRepository.listSignalCards(limit: 200);
    var aiJudgement =
        await localPhase3PlusRepository?.getAiJudgementForDate(todayKey);
    final shouldRefreshAiJudgement = aiJudgement == null ||
        _pendingAiJudgementSourcesChanged(
          aiJudgement,
          allSignals: allSignals,
          todayKey: todayKey,
        );
    if (shouldRefreshAiJudgement) {
      try {
        aiJudgement = await createAiJudgementForToday(
          language: _deviceAppLanguage(),
        );
      } catch (_) {
        // 预判属于增强信息，生成失败不阻塞 Today 的记录与时间线。
      }
    }
    final microActions =
        await localPhase3PlusRepository?.listMicroActionsForDate(todayKey) ??
            const <MicroActionModel>[];
    final todayLifeExperiment =
        await localLifeExperimentRepository?.getSavedForToday(
      localUserId: localUserId,
      today: now,
    );

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
      'aiJudgement': aiJudgement,
      'microActions': microActions,
      'todayLifeExperiment': todayLifeExperiment,
    };
  }

  Future<Map<String, dynamic>> submitTodayLifeExperimentFeedback({
    required String experimentId,
    required String status,
    required String feedbackText,
  }) async {
    final feedback = await localLifeExperimentRepository?.recordFeedback(
      experimentId: experimentId,
      completionStatus: status,
      feedbackText: feedbackText,
    );
    if (feedback != null) cloudBackupSyncService?.markDataChanged();
    unawaited(analyticsRepository?.track(
      'life_experiment_feedback_submitted',
      properties: {
        'status': status,
        'has_note': feedbackText.trim().isNotEmpty,
      },
    ));
    return fetchToday();
  }

  Future<AiJudgementModel?> createAiJudgementForToday({
    AppLanguage language = AppLanguage.english,
  }) async {
    final repo = localPhase3PlusRepository;
    if (repo == null) return null;

    final todayKey = _dateKey(DateTime.now());
    final allSignals = await localCaptureRepository.listSignalCards(limit: 200);
    final eligibleSignals = allSignals
        .where((signal) => _isEligibleForAiJudgement(signal, todayKey))
        .toList();
    if (eligibleSignals.isEmpty) {
      return null;
    }

    final existing = await repo.getAiJudgementForDate(todayKey);
    final generated = _buildAiJudgementCopy(eligibleSignals, language);
    final now = DateTime.now();
    final judgement = AiJudgementModel(
      id: existing?.id ?? _stableAiJudgementId(repo.localUserId, todayKey),
      sourceSignalCardIds: eligibleSignals
          .map((signal) => signal.signalCardId ?? signal.id ?? '')
          .where((id) => id.isNotEmpty)
          .take(5)
          .toList(),
      sourceScheduleSignalIds: const [],
      sourceGoalTaskInstanceIds: const [],
      localDate: todayKey,
      judgementText: generated[0],
      evidenceText: generated[1],
      predictionKind: 'inferred_signal',
      predictedSignalText: generated[0],
      suggestedPattern: generated[2],
      suggestedLifeChainStage: generated[3],
      confidenceLevel: eligibleSignals.length >= 3 ? 'medium' : 'low',
      status: existing?.status ?? 'pending',
      userAdjustmentText: existing?.userAdjustmentText,
      confirmationNote: existing?.confirmationNote,
      linkedMicroActionId: existing?.linkedMicroActionId,
      includedInWeekly: existing?.includedInWeekly ?? false,
      includedInJourney: existing?.includedInJourney ?? false,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await repo.upsertAiJudgement(judgement);
    cloudBackupSyncService?.markDataChanged();
    unawaited(analyticsRepository?.track(
      'ai_judgement_generated',
      properties: {
        'signal_count': eligibleSignals.length,
        'confidence_level': judgement.confidenceLevel,
      },
    ));
    return judgement;
  }

  Future<Map<String, dynamic>> respondToAiJudgement({
    required String judgementId,
    required String status,
    String? userAdjustmentText,
    bool addToTimeline = true,
    AppLanguage language = AppLanguage.english,
  }) async {
    final normalizedStatus = status == 'supplemented' ? 'adjusted' : status;
    final confirmedSignal = const {
      'confirmed',
      'adjusted',
      'accurate',
      'partial',
    }.contains(normalizedStatus);

    // Choosing not to add the proposal is a zero-write dismissal. It creates
    // neither a SignalCard nor a persisted match-feedback event.
    if (!confirmedSignal || !addToTimeline) {
      return _readTodayWithoutDerivedWrites();
    }

    final repo = localPhase3PlusRepository;
    if (repo == null) return fetchToday();

    final judgement = await repo.getAiJudgementById(judgementId);
    if (judgement == null) return fetchToday();

    final confirmationNote = _confirmationNote(
      language,
      addedToTimeline: true,
    );
    unawaited(analyticsRepository?.track(
      'ai_judgement_responded',
      properties: {
        'status': normalizedStatus,
        'confirmed_signal': confirmedSignal,
        'added_to_timeline': true,
        'has_adjustment': userAdjustmentText?.trim().isNotEmpty ?? false,
      },
    ));
    await localCaptureRepository.insertConfirmedSignalCard(
      signalCardId: 'ai_prediction_${judgement.id}',
      content: (userAdjustmentText?.trim().isNotEmpty ?? false)
          ? userAdjustmentText!.trim()
          : judgement.predictedSignalText.trim(),
      sourceType: 'ai_predicted',
      language: _languageCode(language),
      acknowledgement: confirmationNote,
      observation: judgement.evidenceText.trim().isEmpty
          ? null
          : judgement.evidenceText.trim(),
      sceneTags: [
        if (judgement.suggestedPattern.trim().isNotEmpty)
          judgement.suggestedPattern.trim(),
        if (judgement.suggestedLifeChainStage.trim().isNotEmpty)
          judgement.suggestedLifeChainStage.trim(),
      ],
      rawPayloadJson: {
        'ai_judgement_id': judgement.id,
        'confirmation_status': normalizedStatus,
        'added_to_timeline': true,
        if (userAdjustmentText?.trim().isNotEmpty ?? false)
          'user_adjustment_text': userAdjustmentText!.trim(),
      },
      includedInSummary: false,
      includedInWeekly: false,
      includedInJourney: false,
    );
    await repo.updateAiJudgementStatus(
      id: judgementId,
      status: normalizedStatus,
      userAdjustmentText: userAdjustmentText,
      confirmationNote: confirmationNote,
      includedInWeekly: false,
      includedInJourney: false,
    );
    cloudBackupSyncService?.markDataChanged();
    return fetchToday();
  }

  /// Returns the current local Today projection without synchronizing,
  /// regenerating summaries or refreshing AI judgements.
  ///
  /// The dismissal path uses this deliberately: "do not add to timeline" is
  /// a strict no-op for persisted product data, including derived caches.
  Future<Map<String, dynamic>> _readTodayWithoutDerivedWrites() async {
    final now = nowLoader?.call() ?? DateTime.now();
    final todayKey = _dateKey(now);
    final signals = await localCaptureRepository.listRecentSignals(limit: 200);
    final todaySignals = signals
        .where((signal) => signal.localDateKey() == todayKey)
        .toList(growable: false);
    final snapshot = await localDailySnapshotRepository.getByDate(now);
    final aiJudgement =
        await localPhase3PlusRepository?.getAiJudgementForDate(todayKey);
    final microActions =
        await localPhase3PlusRepository?.listMicroActionsForDate(todayKey) ??
            const <MicroActionModel>[];
    final todayLifeExperiment =
        await localLifeExperimentRepository?.getSavedForToday(
      localUserId: localUserId,
      today: now,
    );

    return {
      'insight': TodayInsightModel(
        text: snapshot?.observationText ?? _defaultObservation(todaySignals),
      ),
      'pendingQuestion': null,
      'bestAction': DailyBestActionModel(
        text: snapshot?.suggestionText ?? _defaultSuggestion(todaySignals),
      ),
      'recentSignals': signals,
      'aiJudgement': aiJudgement,
      'microActions': microActions,
      'todayLifeExperiment': todayLifeExperiment,
    };
  }

  Future<Map<String, dynamic>> chooseMicroAction({
    required String microActionId,
    required String choice,
    AppLanguage language = AppLanguage.english,
  }) async {
    final repo = localPhase3PlusRepository;
    if (repo == null) return fetchToday();

    final action = await repo.getMicroActionById(microActionId);
    if (action == null) return fetchToday();

    final updated = switch (choice) {
      'today_try' => _copyMicroAction(
          action,
          status: 'accepted',
          actionType: 'today_try',
        ),
      'add_to_weekly' => _copyMicroAction(
          action,
          status: 'active',
          actionType: 'weekly_experiment',
        ),
      'weekly_experiment' => _copyMicroAction(
          action,
          status: 'active',
          actionType: 'weekly_experiment',
        ),
      'lighter' => _copyMicroAction(
          action,
          title: _lighterMicroActionTitle(language),
          difficulty: 'very_light',
          status: 'adjusted',
        ),
      'skip' => _copyMicroAction(action, status: 'skipped'),
      _ => action,
    };

    await repo.upsertMicroAction(updated);
    cloudBackupSyncService?.markDataChanged();
    unawaited(analyticsRepository?.track(
      'micro_action_chosen',
      properties: {
        'choice': choice,
        'result_status': updated.status,
        'action_type': updated.actionType,
        'difficulty': updated.difficulty,
      },
    ));
    return fetchToday();
  }

  Future<Map<String, dynamic>> submitMicroActionFeedback({
    required String microActionId,
    required String feedback,
    String? userNote,
  }) async {
    final repo = localPhase3PlusRepository;
    if (repo == null) return fetchToday();

    final action = await repo.getMicroActionById(microActionId);
    if (action == null) return fetchToday();

    final now = DateTime.now();
    final happened = switch (feedback) {
      'occurred' => 'yes',
      'happened' => 'yes',
      'not_occurred' => 'no',
      'not_happened' => 'no',
      'not_suitable_today' => 'not_suitable_today',
      _ => 'unknown',
    };
    final effect = feedback == 'helpful' ? 'helpful' : 'unclear';
    final difficulty = switch (feedback) {
      'too_hard' => 'too_hard',
      'not_suitable_today' => 'not_suitable_today',
      _ => 'okay',
    };
    final nextAdjustment = switch (feedback) {
      'too_hard' => 'make_lighter',
      'not_suitable_today' => 'try_another_day',
      _ => 'continue',
    };

    await repo.insertMicroActionFeedback(
      MicroActionFeedbackModel(
        id: repo.createId('maf'),
        microActionId: microActionId,
        localDate: _dateKey(now),
        happened: happened,
        effect: effect,
        difficulty: difficulty,
        userNote: userNote,
        nextAdjustment: nextAdjustment,
        createdAt: now,
      ),
    );
    await repo.updateMicroActionStatus(
      id: microActionId,
      status: const {'not_happened', 'not_occurred', 'not_suitable_today'}
              .contains(feedback)
          ? action.status
          : 'done',
      feedbackStatus: feedback,
    );
    cloudBackupSyncService?.markDataChanged();
    unawaited(analyticsRepository?.track(
      'micro_action_feedback_submitted',
      properties: {
        'feedback': feedback,
        'happened': happened,
        'effect': effect,
        'difficulty': difficulty,
        'next_adjustment': nextAdjustment,
        'has_note': userNote?.trim().isNotEmpty ?? false,
      },
    ));
    return fetchToday();
  }

  bool _isEligibleForAiJudgement(RecentSignalModel signal, String todayKey) {
    if (signal.localDateKey() != todayKey) return false;
    if (signal.sourceType == 'ai_predicted') return false;
    if (signal.content.trim().isEmpty) return false;
    return eligibilityService.isEligible(
      signal,
      SignalEligibilityStage.aiReason,
    );
  }

  List<String> _buildAiJudgementCopy(
    List<RecentSignalModel> signals,
    AppLanguage language,
  ) {
    final haystack = signals
        .map((signal) => [
              signal.content,
              signal.scene,
              signal.friction,
              signal.energyLoad,
              signal.positiveSignal,
              ...signal.sceneTags,
              ...signal.intentTags,
            ].whereType<String>().join(' '))
        .join(' ')
        .toLowerCase();
    final hasSwitching = haystack.contains('切换') ||
        haystack.contains('消息') ||
        haystack.contains('switch') ||
        haystack.contains('interrupt');
    final hasRecovery = haystack.contains('累') ||
        haystack.contains('睡') ||
        haystack.contains('恢复') ||
        haystack.contains('tired') ||
        haystack.contains('recovery');
    final hasBoundary = haystack.contains('边界') ||
        haystack.contains('关系') ||
        haystack.contains('拒绝') ||
        haystack.contains('boundary') ||
        haystack.contains('relationship');

    final sample = signals.isEmpty ? '' : signals.first.content.trim();
    switch (language) {
      case AppLanguage.simplifiedChinese:
        if (hasSwitching) {
          return [
            '今天更值得确认的，可能不是事情多，而是切换之后没有留下恢复空隙。',
            sample.isEmpty ? '线索来自今天已记录的信号。' : '线索来自「$sample」。',
            '高切换后的恢复空隙',
            'attention_switching',
          ];
        }
        if (hasBoundary) {
          return [
            '今天可以确认一下：消耗可能来自边界被反复拉扯，而不只是某件事本身。',
            sample.isEmpty ? '线索来自今天的关系或边界相关记录。' : '线索来自「$sample」这类边界感记录。',
            '边界被拉扯后的能量消耗',
            'boundary_load',
          ];
        }
        if (hasRecovery) {
          return [
            '今天可以先看一个恢复线索：身体或注意力可能在提醒你留一点缓冲。',
            sample.isEmpty ? '线索来自今天的恢复和能量记录。' : '线索来自「$sample」这类恢复信号。',
            '恢复信号偏弱',
            'recovery_gap',
          ];
        }
        return [
          '今天可以先确认一个小结构：几条信号可能正在指向同一个生活节奏。',
          sample.isNotEmpty ? '线索来自「$sample」。' : '线索来自今天已记录的信号。',
          '正在形成的生活节奏',
          'daily_pattern',
        ];
      case AppLanguage.traditionalChinese:
        return [
          '今天可以先確認一個小結構：幾條信號可能正在指向同一個生活節奏。',
          sample.isNotEmpty ? '線索來自「$sample」。' : '線索來自今天已記錄的信號。',
          '正在形成的生活節奏',
          'daily_pattern',
        ];
      case AppLanguage.japanese:
        return [
          '今日はまず、小さな構造を一つ確認してもよさそうです。いくつかのシグナルが同じ生活リズムを指しているかもしれません。',
          sample.isNotEmpty
              ? '「$sample」から見える小さな手がかりです。'
              : '今日記録したシグナルから見える手がかりです。',
          '形成されつつある生活リズム',
          'daily_pattern',
        ];
      case AppLanguage.english:
        return [
          'A small structure may be worth checking today: a few signals may be pointing to the same life rhythm.',
          sample.isNotEmpty
              ? 'This comes from “$sample”.'
              : 'This comes from the signals recorded today.',
          'emerging life rhythm',
          'daily_pattern',
        ];
    }
  }

  MicroActionModel _copyMicroAction(
    MicroActionModel action, {
    String? title,
    String? reason,
    String? actionType,
    String? difficulty,
    String? status,
    String? feedbackStatus,
  }) {
    return MicroActionModel(
      id: action.id,
      judgementId: action.judgementId,
      title: title ?? action.title,
      reason: reason ?? action.reason,
      actionType: actionType ?? action.actionType,
      difficulty: difficulty ?? action.difficulty,
      plannedDate: action.plannedDate,
      plannedTime: action.plannedTime,
      linkedScheduleSignalId: action.linkedScheduleSignalId,
      linkedGoalId: action.linkedGoalId,
      linkedLifeExperimentId: action.linkedLifeExperimentId,
      status: status ?? action.status,
      feedbackStatus: feedbackStatus ?? action.feedbackStatus,
      createdAt: action.createdAt,
      updatedAt: DateTime.now(),
    );
  }

  String _lighterMicroActionTitle(AppLanguage language) {
    return switch (language) {
      AppLanguage.simplifiedChinese => '先用 2 分钟补一句场景',
      AppLanguage.traditionalChinese => '先用 2 分鐘補一句情境',
      AppLanguage.japanese => 'まず2分だけ状況を一言足す',
      AppLanguage.english => 'Add one line of context for 2 minutes',
    };
  }

  String _confirmationNote(
    AppLanguage language, {
    required bool addedToTimeline,
  }) {
    if (addedToTimeline) {
      return switch (language) {
        AppLanguage.simplifiedChinese => '这条内容已从 AI 预判确认并加入时间线。',
        AppLanguage.traditionalChinese => '這條內容已從 AI 預判確認並加入時間線。',
        AppLanguage.japanese => 'AI予測から確認し、タイムラインに追加しました。',
        AppLanguage.english =>
          'Confirmed from an AI prediction and added to your timeline.',
      };
    }
    return switch (language) {
      AppLanguage.simplifiedChinese => '已确认这条 AI 预判，未加入时间线。',
      AppLanguage.traditionalChinese => '已確認這條 AI 預判，未加入時間線。',
      AppLanguage.japanese => 'AI予測を確認しました。タイムラインには追加していません。',
      AppLanguage.english =>
        'Confirmed this AI prediction without adding it to the timeline.',
    };
  }

  bool _pendingAiJudgementSourcesChanged(
    AiJudgementModel judgement, {
    required List<RecentSignalModel> allSignals,
    required String todayKey,
  }) {
    if (!judgement.isPending) return false;
    final signalIds = allSignals
        .where((signal) => _isEligibleForAiJudgement(signal, todayKey))
        .map((signal) => signal.signalCardId ?? signal.id ?? '')
        .where((id) => id.isNotEmpty)
        .take(5)
        .toSet();
    return !_sameIds(signalIds, judgement.sourceSignalCardIds) ||
        judgement.sourceScheduleSignalIds.isNotEmpty ||
        judgement.sourceGoalTaskInstanceIds.isNotEmpty;
  }

  bool _sameIds(Set<String> current, List<String> stored) {
    final storedSet = stored.where((id) => id.isNotEmpty).toSet();
    return current.length == storedSet.length && current.containsAll(storedSet);
  }

  String _stableAiJudgementId(String localUserId, String localDate) {
    final user = localUserId.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
    final date = localDate.replaceAll('-', '');
    return 'aj_${user}_$date';
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
    cloudBackupSyncService?.markDataChanged();

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
      final clientId = (draft['client_id'] as String?) ?? draftId;
      final rawText = draft['raw_text'] as String?;
      final rawPayloadJson = switch (draft['raw_payload_json']) {
        final Map raw => raw.map(
            (key, value) => MapEntry(key.toString(), value),
          ),
        _ => const <String, dynamic>{},
      };
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
            'client_id': clientId,
            if (rawPayloadJson.isNotEmpty) 'raw_payload_json': rawPayloadJson,
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
        cloudBackupSyncService?.markDataChanged();
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
    cloudBackupSyncService?.markDataChanged();

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

  Future<void> deleteSignalCard({
    required String signalCardId,
    String reason = 'user_deleted',
  }) async {
    final client = apiClient;
    if (client != null && !signalCardId.startsWith('draft_')) {
      try {
        await client.deleteJson(
          '/api/v1/captures/signal-cards/$signalCardId',
          body: {'reason': reason},
        );
      } catch (_) {
        // 删除先落本地；远端失败不会阻塞用户移除这条 SignalCard。
      }
    }
    await localCaptureRepository.deleteSignalCard(signalCardId, reason: reason);
    cloudBackupSyncService?.markDataChanged();
  }

  Future<void> restoreSignalCard({
    required String signalCardId,
  }) async {
    final client = apiClient;
    if (client == null || signalCardId.startsWith('draft_')) return;
    await client.postJson(
      '/api/v1/captures/signal-cards/$signalCardId/restore',
      const <String, dynamic>{},
    );
    final remoteSignals = await _fetchRemoteSignalCards();
    await localCaptureRepository.upsertRemoteSignalCards(
      remoteSignals,
      restoreTombstoned: true,
    );
    cloudBackupSyncService?.markDataChanged();
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
          'client_id': localDraft.clientId ?? localDraft.id,
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
    final todayKey = _dateKey(DateTime.now());
    final todaySignals = allSignals
        .where((signal) => signal.localDateKey() == todayKey)
        .toList();
    await _regenerateTodaySummary(todaySignals);
    final latestSignals =
        await localCaptureRepository.listSignalCards(limit: 200);
    cloudBackupSyncService?.markDataChanged();

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

  Future<RecentSignalModel> saveLocalDraftCapture({
    required String content,
    String sourceType = 'text',
    String? tagHint,
    Map<String, dynamic> rawPayloadJson = const {},
  }) async {
    final draft = await localCaptureRepository.insertLocalDraftSignal(
      content: content,
      sourceType: sourceType,
      tagHint: tagHint,
      language: _languageCode(),
      timezone: _timezoneName(),
      rawPayloadJson: rawPayloadJson,
    );
    cloudBackupSyncService?.markDataChanged();
    await analyticsRepository?.track(
      'entry_draft_saved',
      properties: {
        'content_length': content.trim().length,
        'source_type': sourceType,
      },
    );
    return draft;
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
      } catch (error) {
        await _recordPipelineFailure(
          pipelineType: 'assist_generation',
          sourceType: 'daily_snapshot',
          sourceId: _dateKey(DateTime.now()),
          inputHash: localDailySnapshotRepository.buildSourceHash(todaySignals),
          error: error,
        );
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

  Future<void> _recordPipelineFailure({
    required String pipelineType,
    required String sourceType,
    required String sourceId,
    required String inputHash,
    required Object error,
  }) async {
    final repository = LocalPipelineRunRepository(
      localDailySnapshotRepository.localDatabase,
    );
    final runId = await repository.start(
      pipelineType: pipelineType,
      sourceType: sourceType,
      sourceId: sourceId,
      inputHash: inputHash,
    );
    await repository.fail(
      runId: runId,
      errorCode: error.runtimeType.toString(),
      errorMessage: error.toString(),
    );
  }

  List<RecentSignalModel> _summaryEligibleSignals(
      List<RecentSignalModel> signals) {
    return eligibilityService.filter(
      signals,
      SignalEligibilityStage.daily,
    );
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
    final focusDomainIds = FocusDomains.normalizeIds(
      prefs.getStringList(FocusDomains.productPreferenceKey) ??
          prefs.getStringList(FocusDomains.preferenceKey) ??
          const [],
    );
    if (focusDomainIds.isNotEmpty) {
      return focusDomainIds.join(',');
    }
    return prefs.getString('repeat_area_preference') ??
        prefs.getString('selected_repeat_area');
  }

  String _languageCode([AppLanguage? language]) {
    if (language != null) {
      return switch (language) {
        AppLanguage.simplifiedChinese => 'zh-Hans',
        AppLanguage.traditionalChinese => 'zh-Hant',
        AppLanguage.japanese => 'ja',
        AppLanguage.english => 'en',
      };
    }
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

  AppLanguage _deviceAppLanguage() {
    return switch (_languageCode()) {
      'zh-Hans' => AppLanguage.simplifiedChinese,
      'zh-Hant' => AppLanguage.traditionalChinese,
      'ja' => AppLanguage.japanese,
      _ => AppLanguage.english,
    };
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
      return '先不用重复输入，这条记录可以先放在今天。';
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
