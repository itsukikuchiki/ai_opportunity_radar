import '../../models/memory_models.dart';
import '../../models/monthly_models.dart';
import '../../models/today_models.dart';
import '../../models/weekly_models.dart';
import '../api_client.dart';

class AiRepository {
  final ApiClient apiClient;

  AiRepository(this.apiClient);

  Future<AiCaptureReplyResult> generateCaptureReply({
    required String content,
    required List<String> recentAssistantTexts,
    String? focusArea,
    String? responseStyle,
  }) async {
    final style = _normalizeResponseStyle(responseStyle);

    try {
      final res = await apiClient.postJson(
        '/api/v1/ai/capture-reply',
        {
          'content': content,
          'recent_assistant_texts': recentAssistantTexts,
          'focus_area': focusArea,
          'response_style': style,
        },
      );

      final data = (res['data'] as Map<String, dynamic>?) ?? res;

      return AiCaptureReplyResult(
        acknowledgement: (data['acknowledgement'] as String?) ??
            _styleText(_fallbackAcknowledgement(content), style),
        observation: (data['observation'] as String?) ??
            _styleText(_fallbackSingleObservation(content), style),
        tryNext: (data['try_next'] as String?) ??
            _styleText(_fallbackSingleTryNext(content), style),
        emotion: (data['emotion'] as String?) ?? _fallbackEmotion(content),
        intensity:
            (data['intensity'] as String?) ?? _fallbackIntensity(content),
        sceneTags: _parseStringList(data['scene_tags']),
        intentTags: _parseStringList(data['intent_tags']),
        followup: data['followup'] == null
            ? null
            : FollowupQuestionModel.fromJson(
                data['followup'] as Map<String, dynamic>,
              ),
      );
    } catch (_) {
      return AiCaptureReplyResult(
        acknowledgement: _styleText(_fallbackAcknowledgement(content), style),
        observation: _styleText(_fallbackSingleObservation(content), style),
        tryNext: _styleText(_fallbackSingleTryNext(content), style),
        emotion: _fallbackEmotion(content),
        intensity: _fallbackIntensity(content),
        sceneTags: _fallbackSceneTags(content),
        intentTags: _fallbackIntentTags(content),
        followup: null,
      );
    }
  }

  Future<AiTodaySummaryResult> generateTodaySummary({
    required DateTime date,
    required List<RecentSignalModel> entries,
    String? focusArea,
    String? responseStyle,
  }) async {
    final style = _normalizeResponseStyle(responseStyle);

    try {
      final res = await apiClient.postJson(
        '/api/v1/ai/today-summary',
        {
          'date': _dateKey(date),
          'entry_count': entries.length,
          'entries': entries
              .map(
                (e) => {
                  'id': e.id,
                  'content': e.content,
                  'created_at': e.createdAt?.toUtc().toIso8601String(),
                  'acknowledgement': e.acknowledgement,
                  'observation': e.observation,
                  'try_next': e.tryNext,
                  'emotion': e.emotion,
                  'intensity': e.intensity,
                  'scene_tags': e.sceneTags,
                  'intent_tags': e.intentTags,
                },
              )
              .toList(),
          'focus_area': focusArea,
          'response_style': style,
        },
      );

      final data = (res['data'] as Map<String, dynamic>?) ?? res;

      return AiTodaySummaryResult(
        observation: (data['observation'] as String?) ??
            _styleText(_fallbackObservation(entries), style),
        suggestion: (data['suggestion'] as String?) ??
            _styleText(_fallbackSuggestion(entries), style),
      );
    } catch (_) {
      return AiTodaySummaryResult(
        observation: _styleText(_fallbackObservation(entries), style),
        suggestion: _styleText(_fallbackSuggestion(entries), style),
      );
    }
  }

  Future<WeeklyInsightModel> generateWeeklySummary({
    required String weekStart,
    required String weekEnd,
    required List<Map<String, dynamic>> entries,
    required Map<String, int> dayCounts,
    required List<String> topTokens,
    String? focusArea,
  }) async {
    try {
      final res = await apiClient.postJson(
        '/api/v1/ai/weekly-generate',
        {
          'week_start': weekStart,
          'week_end': weekEnd,
          'entry_count': entries.length,
          'entries': entries,
          'day_counts': dayCounts,
          'top_tokens': topTokens,
          'focus_area': focusArea,
        },
      );

      final data = (res['data'] as Map<String, dynamic>?) ?? res;
      return WeeklyInsightModel.fromJson(data);
    } catch (_) {
      return _fallbackWeeklyInsight(
        weekStart: weekStart,
        weekEnd: weekEnd,
        entries: entries,
        dayCounts: dayCounts,
        topTokens: topTokens,
      );
    }
  }

  Future<MemorySummaryModel> generateJourneySummary({
    required String snapshotDate,
    required List<Map<String, dynamic>> entries,
    required List<String> topTokens,
    required int totalDays,
    String? focusArea,
  }) async {
    try {
      final res = await apiClient.postJson(
        '/api/v1/ai/journey-generate',
        {
          'snapshot_date': snapshotDate,
          'entry_count': entries.length,
          'entries': entries,
          'top_tokens': topTokens,
          'total_days': totalDays,
          'focus_area': focusArea,
        },
      );

      final data = (res['data'] as Map<String, dynamic>?) ?? res;
      return MemorySummaryModel.fromJson(data);
    } catch (_) {
      return _fallbackJourneySummary(
        entries: entries,
        topTokens: topTokens,
        totalDays: totalDays,
      );
    }
  }

  Future<MonthlyReviewModel> generateMonthlyReview({
    required String monthStart,
    required String monthEnd,
    required List<Map<String, dynamic>> entries,
    required List<String> topTokens,
    required int totalDays,
    String? focusArea,
  }) async {
    try {
      final res = await apiClient.postJson(
        '/api/v1/ai/monthly-generate',
        {
          'month_start': monthStart,
          'month_end': monthEnd,
          'entry_count': entries.length,
          'entries': entries,
          'top_tokens': topTokens,
          'total_days': totalDays,
          'focus_area': focusArea,
        },
      );

      final data = (res['data'] as Map<String, dynamic>?) ?? res;
      return MonthlyReviewModel.fromJson(data);
    } catch (_) {
      return _fallbackMonthlyReview(
        monthStart: monthStart,
        monthEnd: monthEnd,
        entries: entries,
        topTokens: topTokens,
        totalDays: totalDays,
      );
    }
  }

  Future<LightDialogResponseModel> generateLightDialog({
    required RecentSignalModel signal,
    required List<LightDialogTurnModel> history,
    required String userMessage,
    String? focusArea,
    String? responseStyle,
  }) async {
    final style = _normalizeResponseStyle(responseStyle);

    try {
      final res = await apiClient.postJson(
        '/api/v1/ai/light-dialog',
        {
          'capture_content': signal.content,
          'capture_acknowledgement': signal.acknowledgement,
          'capture_observation': signal.observation,
          'capture_try_next': signal.tryNext,
          'history': history.map((e) => e.toJson()).toList(),
          'user_message': userMessage,
          'focus_area': focusArea,
          'response_style': style,
        },
      );

      final data = (res['data'] as Map<String, dynamic>?) ?? res;
      return LightDialogResponseModel.fromJson(data);
    } catch (_) {
      return LightDialogResponseModel(
        reply: _styleText(
          '我先顺着这条陪你多看一点。先别急着解释完整，只要把最卡住你的那个瞬间说得更具体一点，就已经很有用了。',
          style,
        ),
        suggestedPrompts: const [
          '我最卡住的是哪一个瞬间？',
          '这件事让我最在意的是什么？',
          '下次再遇到时我想先做什么？',
        ],
      );
    }
  }

  Future<DeepWeeklyModel> generateDeepWeekly({
    required WeeklyInsightModel weekly,
    String? focusArea,
  }) async {
    try {
      final res = await apiClient.postJson(
        '/api/v1/ai/deep-weekly',
        {
          'week_start': weekly.weekStart,
          'week_end': weekly.weekEnd,
          'key_insight': weekly.keyInsight,
          'patterns': weekly.patterns,
          'frictions': weekly.frictions,
          'best_action': weekly.bestAction,
          'chart_data': weekly.chartData.map((e) => e.toJson()).toList(),
          'focus_area': focusArea,
        },
      );
      final data = (res['data'] as Map<String, dynamic>?) ?? res;
      return DeepWeeklyModel.fromJson(data);
    } catch (_) {
      final topic = weekly.deriveTopicFocus();
      final chartPoints = [...weekly.chartData]..sort(
          (a, b) => a.date.compareTo(b.date),
        );
      WeeklyChartPointModel? peak;
      WeeklyChartPointModel? low;
      if (chartPoints.isNotEmpty) {
        peak = chartPoints.reduce(
          (a, b) => a.signalCount >= b.signalCount ? a : b,
        );
        low = chartPoints.reduce(
          (a, b) => a.moodScore <= b.moodScore ? a : b,
        );
      }
      final peakLabel = _shortDateLabel(peak?.date) ?? '这周某一天';
      final lowLabel = _shortDateLabel(low?.date) ?? '这周某个低点';
      return DeepWeeklyModel(
        summary: '${topic.reason} Deep Weekly 更需要看的，是这些记录背后的同一种拉扯，而不是把免费版内容拉长。',
        rootTension:
            '更深一层的 tension 往往不是单个事件，而是你想推进的方向和反复回来的摩擦点互相顶住，导致每次都要重新找回节奏。',
        hiddenPattern:
            '把图和文字放在一起看，$peakLabel 是线索更密的节点，$lowLabel 更像状态低点。重点不是哪天最糟，而是压力聚集后你如何被拉走。',
        nextFocus: '${topic.nextWatch} 下次再出现同类场景时，多记一句它发生在开始、推进中段，还是收尾阶段。',
        riskNote: '这份 deep weekly 适合帮你收窄观察面，不适合一次性下结论。',
        keyNodes: [
          topic.headline,
          '线索密集点：$peakLabel',
          '走势低点：$lowLabel',
        ],
      );
    }
  }

  String? _shortDateLabel(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return raw.length >= 10 && raw.contains('-') ? raw.substring(5) : raw;
  }

  String _normalizeResponseStyle(String? value) {
    switch (value) {
      case 'clear':
      case 'direct':
      case 'gentle':
        return value!;
      default:
        return 'gentle';
    }
  }

  String _styleText(String text, String style) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return trimmed;

    switch (style) {
      case 'direct':
        return trimmed
            .replaceAll('先把', '把')
            .replaceAll('就好', '')
            .replaceAll('先不用', '不用')
            .trim();
      case 'clear':
        return trimmed;
      case 'gentle':
      default:
        return trimmed;
    }
  }

  String _dateKey(DateTime date) {
    final local = date.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd';
  }

  String _fallbackAcknowledgement(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return '先把这一条留在这里。';

    final topic = _topicHint(content);
    if (topic != null) {
      return _topicAcknowledgement(topic);
    }

    final emotion = _fallbackEmotion(content);
    final sceneTags = _fallbackSceneTags(content);

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
      if (sceneTags.contains('body')) {
        return '这一下更像是身体和情绪一起在往下掉，先不用急着把它想明白。';
      }
      return '这一下听起来确实挺消耗人的，先把它放在这里就好。';
    }

    return '先把这一条留在这里也很好，它本身就是一个值得继续看的线索。';
  }

  String _fallbackSingleObservation(String content) {
    final topic = _topicHint(content);
    if (topic != null) {
      return _topicObservation(topic);
    }

    final emotion = _fallbackEmotion(content);
    final sceneTags = _fallbackSceneTags(content);

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
      if (sceneTags.contains('body')) {
        return '你今天更像是先被身体状态拖住了，情绪只是跟着一起往下。';
      }
      return '今天更明显的不是一句“烦”，而是某个具体场景正在稳定地消耗你。';
    }

    return '你今天更像是在留下一条状态线索，而不是在表达一股很强的情绪。';
  }

  String _fallbackSingleTryNext(String content) {
    final topic = _topicHint(content);
    if (topic != null) {
      return _topicTryNext(topic);
    }

    final emotion = _fallbackEmotion(content);
    final sceneTags = _fallbackSceneTags(content);

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
      if (sceneTags.contains('body')) {
        return '先不用分析原因，只留意一下这种身体状态是从什么时候开始的。';
      }
      return '先把最卡你的那个瞬间记下来，其他先不用整理。';
    }

    return '先把这一条放着，看看之后它会不会再回来。';
  }

  String _fallbackObservation(List<RecentSignalModel> entries) {
    if (entries.isEmpty) {
      return '今天还没有记录，先留下一件真实发生的小事就好。';
    }

    if (entries.length == 1) {
      final first = entries.first;
      return first.observation ?? '今天记录了 1 条。你已经开始把今天里真正触动你的事留了下来。';
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
    return '今天记录了 ${entries.length} 条。今天的线索已经开始聚起来了。';
  }

  String _fallbackSuggestion(List<RecentSignalModel> entries) {
    if (entries.isEmpty) {
      return '今天先记下一件让你停顿了一下的小事就好。';
    }

    if (entries.length == 1) {
      final first = entries.first;
      return first.tryNext ?? '如果同类事情今天再出现一次，再补记一条就可以。';
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

  String _fallbackEmotion(String content) {
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

  String? _topicHint(String content) {
    final text = content.toLowerCase();
    bool hit(List<String> keywords) => keywords.any(text.contains);

    if (hit(['token', 'tokens', 'トークン']) &&
        hit(['贵', '高', 'expensive', 'cost', '高い'])) {
      return 'cost';
    }
    if (hit(['骑马', '乗馬', '馬', 'horse'])) {
      return 'horse_expectation';
    }
    if (hit([
      '无法预测明天',
      '不能预测明天',
      '预测明天',
      '活在当下',
      '明日',
      '予測',
      'tomorrow',
      'present'
    ])) {
      return 'tomorrow_uncertainty';
    }
    if (hit(['退休', '退職', '引退', 'retire'])) {
      return 'retirement_wish';
    }
    if (hit(['天气不错', '好天气', 'いい天気', 'weather is nice', 'good weather'])) {
      return 'weather_good';
    }
    if (hit(['不想上班', '休息', '休みたい', 'rest'])) {
      return 'rest_wish';
    }
    if (hit(
        ['钱', '贵', '预算', '成本', '花费', '价格', 'お金', 'money', 'budget', 'cost'])) {
      return 'money';
    }
    return null;
  }

  String _topicAcknowledgement(String topic) {
    switch (topic) {
      case 'cost':
        return '你在意的不是小情绪，而是成本突然变得很明显：token 花费这件事需要被认真看一下。';
      case 'horse_expectation':
        return '这一条的重点很清楚：骑马像是这一周里真正能让你期待的一块恢复时间。';
      case 'tomorrow_uncertainty':
        return '你写到的是对明天不可控的提醒，也是在把注意力轻轻拉回当下。';
      case 'retirement_wish':
        return '“想早点退休”背后更像是持续被工作消耗后的逃离感，不只是随口一说。';
      case 'weather_good':
        return '天气不错这件小事已经让今天亮了一点，它本身就值得被留下来。';
      case 'rest_wish':
        return '这里最明显的是想停下来休息的念头，可能是身体和心力都在要一点空间。';
      case 'money':
        return '这条和钱有关，真正牵动你的可能是支出、价值感或安全感之间的拉扯。';
      default:
        return '这条可以先作为一个具体线索留下来。';
    }
  }

  String _topicObservation(String topic) {
    switch (topic) {
      case 'cost':
        return '这条更像是成本提醒：当 token 或 AI 使用成本变得显眼，它会影响你对工具是否值得继续用的判断。';
      case 'horse_expectation':
        return '这条的恢复线索很明确：骑马不是普通安排，而是你这周少数真正期待的事情。';
      case 'tomorrow_uncertainty':
        return '这条更像是一种生活视角：明天不可控，所以今天能抓住的当下变得更重要。';
      case 'retirement_wish':
        return '这条不是简单抱怨，它更像是在提示：现在的工作消耗已经让你开始想象彻底离开的生活。';
      case 'weather_good':
        return '这条里的正向线索很小但清楚：外部环境变轻，会让今天更容易松一点。';
      case 'rest_wish':
        return '这条更像是恢复需求浮出来了：你可能不是懒，而是确实想要一点不用继续扛的空间。';
      case 'money':
        return '这条和钱有关，也可能牵着安全感、值不值得、以及资源是否够用的判断。';
      default:
        return '这条可以先作为一个具体线索留下来。';
    }
  }

  String _topicTryNext(String topic) {
    switch (topic) {
      case 'cost':
        return '可以先记一笔：这次让你觉得贵的，是单次花费、持续消耗，还是不确定能不能换来价值。';
      case 'horse_expectation':
        return '可以先补一句：骑马让你期待的到底是身体活动、自由感，还是暂时离开日常压力。';
      case 'tomorrow_uncertainty':
        return '今天不用把明天想清楚，只选一件当下能好好做的小事就够了。';
      case 'retirement_wish':
        return '先不用立刻讨论退休，只补一句：最想离开的到底是工作量、节奏，还是长期没有恢复空间。';
      case 'weather_good':
        return '如果可以，今天留意一下：天气变好后，你更想散步、休息，还是做一点轻松的事。';
      case 'rest_wish':
        return '先给自己一个很小的恢复块：哪怕只是十分钟不输入、不处理、不回应。';
      case 'money':
        return '先记清楚这笔钱让你卡住的点：价格、必要性，还是付出之后的确定感。';
      default:
        return '先看看它之后还会不会再回来。';
    }
  }

  String _fallbackIntensity(String content) {
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
        _fallbackEmotion(content) != 'neutral') {
      return 'medium';
    }
    return 'low';
  }

  List<String> _fallbackSceneTags(String content) {
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
      'token',
      '贵',
      '成本',
      '价格',
      'お金',
      '支出',
      'money',
      'budget',
      'cost',
      'spent'
    ])) {
      scenes.add('money');
    }
    if (hit([
      '明天',
      '未来',
      '预测',
      '当下',
      '明日',
      '予測',
      'tomorrow',
      'future',
      'present'
    ])) {
      scenes.add('future');
    }
    if (hit(['骑马', '乗馬', 'horse', 'ride'])) {
      scenes.add('hobby');
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
      return _fallbackEmotion(content) == 'negative'
          ? const ['daily_friction']
          : const ['daily_life'];
    }
    return scenes.take(3).toList();
  }

  List<String> _fallbackIntentTags(String content) {
    final emotion = _fallbackEmotion(content);
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

  List<String> _parseStringList(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) {
      return raw
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return const [];
      return trimmed
          .split(',')
          .map((e) => e.replaceAll('"', '').replaceAll("'", '').trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  WeeklyInsightModel _fallbackWeeklyInsight({
    required String weekStart,
    required String weekEnd,
    required List<Map<String, dynamic>> entries,
    required Map<String, int> dayCounts,
    required List<String> topTokens,
  }) {
    if (entries.isEmpty) {
      return WeeklyInsightModel(
        weekStart: weekStart,
        weekEnd: weekEnd,
        status: 'insufficient_data',
        keyInsight: null,
        patterns: const [],
        frictions: const [],
        bestAction: null,
        opportunitySnapshot: null,
        feedbackSubmitted: false,
        chartData: const [],
      );
    }

    final contents = _entryContents(entries);
    final topTokenText = _evidenceTopicFromEntries(
      contents: contents,
      topTokens: topTokens,
      fallback: '本周记录',
    );
    final peakDay = _resolvePeakDay(dayCounts);
    final confidenceLine =
        entries.length < 4 ? '基于目前少量信号，先把它当成临时观察。' : '这周已经有足够线索，可以先看它的重复方式。';

    return WeeklyInsightModel(
      weekStart: weekStart,
      weekEnd: weekEnd,
      status: 'ready',
      keyInsight: '$confidenceLine 这周先看“$topTokenText”，$peakDay 的信号更密集。',
      patterns: [
        {
          'name': '本周小观察：$topTokenText',
          'summary': '$confidenceLine 先看它在哪些场景里回来。',
        },
        {
          'name': '证据来源',
          'summary':
              _evidenceSummary(contents: contents, fallback: topTokenText),
        },
      ],
      frictions: [
        {
          'name': '本周可能的消耗点',
          'summary': '目前先看“$topTokenText”带来的负担；还不需要当成结论。',
        },
      ],
      bestAction: '这周先试一步：下次再出现同类情况时，用一句话补记它发生在什么场景。',
      opportunitySnapshot: const {
        'name': '把重复信号固定下来',
        'summary': '如果某类事情总是回来，它可能值得先被结构化记录。',
      },
      feedbackSubmitted: false,
      chartData: const [],
    );
  }

  MemorySummaryModel _fallbackJourneySummary({
    required List<Map<String, dynamic>> entries,
    required List<String> topTokens,
    required int totalDays,
  }) {
    final contents = _entryContents(entries);
    final topToken = _evidenceTopicFromEntries(
      contents: contents,
      topTokens: topTokens,
      fallback: '最近的记录',
    );
    final confidence = entries.length < 6 ? '还只是早期生活轨迹' : '已经开始有长期线索';

    return MemorySummaryModel(
      patterns: [
        JourneySignalItemModel(
          name: '正在形成的生活路径',
          summary: '$confidence：目前最清楚的是“$topToken”。先看它是偶尔出现，还是慢慢变成重复结构。',
          signalLevel: totalDays >= 3 ? 'repeated_pattern' : 'weak_signal',
        ),
      ],
      frictions: [
        JourneySignalItemModel(
          name: '可能的长期消耗',
          summary: '如果“$topToken”继续出现，它可能是后面要回看的消耗来源；现在先保持小观察。',
          signalLevel: totalDays >= 4 ? 'stable_mode' : 'repeated_pattern',
        ),
      ],
      desires: [
        JourneySignalItemModel(
          name: '还在浮现的方向',
          summary: '记录已经跨越 $totalDays 天，一些真正长期在意的方向正在慢慢浮现。',
          signalLevel: totalDays >= 2 ? 'repeated_pattern' : 'weak_signal',
        ),
      ],
      experiments: [
        JourneySignalItemModel(
          name: '开始有帮助的东西',
          summary: '继续记录下去，会更容易看见什么做法不是偶然有效，而是在慢慢变得有帮助。',
          signalLevel: totalDays >= 2 ? 'repeated_pattern' : 'weak_signal',
        ),
      ],
    );
  }

  List<String> _entryContents(List<Map<String, dynamic>> entries) {
    return entries
        .map((e) => (e['content'] ?? '').toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String _evidenceTopicFromEntries({
    required List<String> contents,
    required List<String> topTokens,
    required String fallback,
  }) {
    final joined = contents.join(' ');
    final topic = _topicHint(joined);
    switch (topic) {
      case 'cost':
        return 'token 成本';
      case 'horse_expectation':
        return '骑马带来的期待和恢复';
      case 'tomorrow_uncertainty':
        return '明天不可控与活在当下';
      case 'retirement_wish':
        return '想离开工作消耗';
      case 'weather_good':
        return '天气带来的轻一点的状态';
      case 'rest_wish':
        return '想停下来休息';
      case 'money':
        return '钱和成本压力';
      default:
        return topTokens.isEmpty ? fallback : _readableToken(topTokens.first);
    }
  }

  String _evidenceSummary({
    required List<String> contents,
    required String fallback,
  }) {
    final samples = contents.take(2).toList();
    if (samples.isEmpty) {
      return '目前证据还少，先把“$fallback”作为待观察线索。';
    }
    if (samples.length == 1) {
      return '目前主要来自一条记录：“${_truncateEvidence(samples.first)}”。先不要过度判断。';
    }
    return '目前主要来自这些记录：“${_truncateEvidence(samples[0], 18)}”和“${_truncateEvidence(samples[1], 18)}”。先看它们是否还会重复。';
  }

  String _truncateEvidence(String value, [int maxLength = 28]) {
    final trimmed = value.trim();
    if (trimmed.length <= maxLength) return trimmed;
    return '${trimmed.substring(0, maxLength)}…';
  }

  MonthlyReviewModel _fallbackMonthlyReview({
    required String monthStart,
    required String monthEnd,
    required List<Map<String, dynamic>> entries,
    required List<String> topTokens,
    required int totalDays,
  }) {
    final topToken =
        topTokens.isEmpty ? '这个月的记录' : _readableToken(topTokens.first);
    final repeated = topTokens.take(3).map(_readableToken).toList();
    final week1Count = entries.isEmpty ? 0 : entries.length;

    return MonthlyReviewModel(
      monthStart: monthStart,
      monthEnd: monthEnd,
      status: entries.isEmpty ? 'insufficient_data' : 'ready',
      monthlySummary: '这个月的记录反复围绕“$topToken”回来，说明它已经不是偶发的小波动。',
      repeatedThemes: repeated.isEmpty
          ? const ['这个月已经开始出现重复主题。']
          : repeated.map((e) => '“$e” 反复出现。').toList(),
      improvingSignals: const [
        '有些恢复方式正在慢慢变得更稳定。',
      ],
      unresolvedPoints: const [
        '高消耗场景还没有真正被拆开看清。',
      ],
      nextMonthWatch: '下个月先继续看，哪一类场景最容易触发第一下消耗。',
      weeklyBridges: [
        MonthlyBridgeWeekModel(
          label: 'Week 1',
          summary: '$week1Count 条记录落在这个月的主要观察里。',
        ),
      ],
    );
  }

  String _resolvePeakDay(Map<String, int> dayCounts) {
    if (dayCounts.isEmpty) return '这周';
    return dayCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  String _readableToken(String token) {
    final normalized = token
        .replaceAll(RegExp(r'^[\[\("“]+|[\]\)"”]+$'), '')
        .replaceAll('_', ' ')
        .trim()
        .toLowerCase();
    const labels = {
      'planning': '安排',
      'work': '工作',
      'relationship': '关系',
      'relations': '关系',
      'boundary': '边界',
      'boundaries': '边界',
      'recovery': '恢复',
      'rest': '休息',
      'sleep': '睡眠',
      'body': '身体',
      'energy': '能量',
      'attention': '注意力',
      'switching': '切换',
      'schedule': '日程',
      'schedule density': '安排密度',
      'care load': '照顾负荷',
      'limited buffer': '缓冲不足',
      'buffer': '缓冲',
      'weather': '天气',
      'commute': '通勤',
      'home': '家里',
      'daily friction': '日常摩擦',
      'daily life': '日常生活',
    };
    return labels[normalized] ?? token.trim();
  }
}
