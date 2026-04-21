import '../../models/memory_models.dart';
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
  }) async {
    try {
      final res = await apiClient.postJson(
        '/api/v1/ai/capture-reply',
        {
          'content': content,
          'recent_assistant_texts': recentAssistantTexts,
          'focus_area': focusArea,
        },
      );

      final data = (res['data'] as Map<String, dynamic>?) ?? res;

      return AiCaptureReplyResult(
        acknowledgement:
            (data['acknowledgement'] as String?) ??
            _fallbackAcknowledgement(content),
        observation:
            (data['observation'] as String?) ??
            _fallbackSingleObservation(content),
        tryNext:
            (data['try_next'] as String?) ??
            _fallbackSingleTryNext(content),
        emotion:
            (data['emotion'] as String?) ??
            _fallbackEmotion(content),
        intensity:
            (data['intensity'] as String?) ??
            _fallbackIntensity(content),
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
        acknowledgement: _fallbackAcknowledgement(content),
        observation: _fallbackSingleObservation(content),
        tryNext: _fallbackSingleTryNext(content),
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
  }) async {
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
        },
      );

      final data = (res['data'] as Map<String, dynamic>?) ?? res;

      return AiTodaySummaryResult(
        observation:
            (data['observation'] as String?) ?? _fallbackObservation(entries),
        suggestion:
            (data['suggestion'] as String?) ?? _fallbackSuggestion(entries),
      );
    } catch (_) {
      return AiTodaySummaryResult(
        observation: _fallbackObservation(entries),
        suggestion: _fallbackSuggestion(entries),
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
  }) async {
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
        },
      );

      final data = (res['data'] as Map<String, dynamic>?) ?? res;
      return LightDialogResponseModel.fromJson(data);
    } catch (_) {
      return const LightDialogResponseModel(
        reply: '我先顺着这条陪你多看一点。先别急着解释完整，只要把最卡住你的那个瞬间说得更具体一点，就已经很有用了。',
        suggestedPrompts: [
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
      return DeepWeeklyModel(
        summary: '${topic.reason} 这一周更像是同一种拉扯在不同场景里回来，而不是几件彼此无关的事。',
        rootTension: '更深一层的 tension 往往不是单个事件，而是你想推进的方向和反复回来的摩擦点互相顶住。',
        hiddenPattern: '把图和文字放在一起看，重点不是哪一天最糟，而是线索一密集时，同类问题也会一起浮上来。',
        nextFocus: topic.nextWatch,
        riskNote: '这份 deep weekly 适合帮你收窄观察面，不适合一次性下结论。',
        keyNodes: [topic.headline],
      );
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
      return first.observation ??
          '今天记录了 1 条。你已经开始把今天里真正触动你的事留了下来。';
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
      return first.tryNext ??
          '如果同类事情今天再出现一次，再补记一条就可以。';
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
      '开心', '高兴', '喜欢', '顺利', '放松', '舒服', '满足', '期待', '有成就感',
      '轻松', '好吃', '快乐', '愉快', '安心', '踏实',
      '嬉しい', '楽しい', 'よかった', '満足', '安心',
      'happy', 'glad', 'good', 'great', 'relieved', 'nice',
    ];
    final negativeKeywords = [
      '烦', '累', '崩', '难受', '焦虑', '生气', '压力', '不想', '麻烦', '受不了',
      '被打断', '烦躁', '委屈', '失控', '糟糕', '痛苦', '压抑',
      'しんどい', 'つらい', '疲れた', 'イライラ', '不安', '最悪',
      'annoyed', 'tired', 'upset', 'angry', 'anxious', 'stressed', 'frustrated',
    ];
    final mixedMarkers = [
      '但是', '但', '不过', '后来', '虽然', '又', '缓回来', '好了一点',
      'けど', 'でも', 'そのあと',
      'but', 'however', 'though', 'later',
    ];

    final hasPositive = positiveKeywords.any(text.contains);
    final hasNegative = negativeKeywords.any(text.contains);
    final hasMixedMarker = mixedMarkers.any(text.contains);

    if ((hasPositive && hasNegative) || (hasMixedMarker && (hasPositive || hasNegative))) {
      return 'mixed';
    }
    if (hasNegative) return 'negative';
    if (hasPositive) return 'positive';
    return 'neutral';
  }

  String _fallbackIntensity(String content) {
    final text = content.toLowerCase();

    final strongMarkers = [
      '一直', '总是', '反复', '受不了', '崩了', '特别', '非常', '真的', '很烦', '很累',
      'ずっと', 'かなり', '本当に', 'めちゃくちゃ',
      'very', 'really', 'extremely',
    ];
    final mediumMarkers = [
      '有点', '有一些', '有一点', '有些', '稍微',
      'ちょっと', '少し',
      'a bit', 'kind of', 'somewhat',
    ];

    if (strongMarkers.any(text.contains) || content.contains('!') || content.contains('！')) {
      return 'high';
    }
    if (mediumMarkers.any(text.contains) || _fallbackEmotion(content) != 'neutral') {
      return 'medium';
    }
    return 'low';
  }

  List<String> _fallbackSceneTags(String content) {
    final text = content.toLowerCase();
    final scenes = <String>[];

    bool hit(List<String> keywords) => keywords.any(text.contains);

    if (hit(['上班', '开会', '同事', '老板', '需求', '任务', '公司', '工作', '邮件', '会议', '職場', '仕事', '会議', 'task', 'work', 'meeting', 'manager'])) {
      scenes.add('work');
    }
    if (hit(['通勤', '地铁', '电车', '路上', '回家路上', '出门', '満員電車', 'commute', 'train'])) {
      scenes.add('commute');
    }
    if (hit(['朋友', '家人', '恋人', '关系', '聊天', '人間関係', 'family', 'friend', 'partner'])) {
      scenes.add('relationship');
    }
    if (hit(['头疼', '困', '睡', '累', '身体', '胃', '不舒服', '健康', '体調', '眠い', 'body', 'health'])) {
      scenes.add('body');
    }
    if (hit(['花钱', '工资', '金钱', '消费', '买', '预算', 'お金', '支出', 'money', 'budget', 'spent'])) {
      scenes.add('money');
    }
    if (hit(['休息', '放松', '睡觉', '午休', '恢复', '发呆', '散步', '休憩', 'rest', 'relax'])) {
      scenes.add('rest');
    }
    if (hit(['完成', '做完', '推进', '成果', '达成', '有进展', '進んだ', '達成', 'finished', 'done'])) {
      scenes.add('achievement');
    }
    if (hit(['怀疑自己', '自我否定', '不够好', '没做好', '担心自己', '自信がない', 'self doubt'])) {
      scenes.add('self_doubt');
    }
    if (hit(['被打断', '重复', '麻烦', '卡住', '拖延', '琐事', '不顺', 'interrupted', 'blocked', 'friction'])) {
      scenes.add('daily_friction');
    }
    if (hit(['在家', '回家', '房间', '家里', '家务', '家', '家で', 'home'])) {
      scenes.add('home');
    }
    if (hit(['学习', '看书', '复习', '考试', '输出', '写作', '勉強', 'study', 'reading', 'writing'])) {
      scenes.add('study');
    }
    if (hit(['吃饭', '好吃', '逛', '买东西', '天气', '散步', '咖啡', '食べた', 'lunch', 'coffee'])) {
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

    if ([
      '为什么', '是不是', '感觉', '好像', '也许', 'maybe', 'wonder', '気がする'
    ].any(text.contains) &&
        !intents.contains('reflection')) {
      intents.add('reflection');
    }

    if ([
      '要不要', '决定', '算了', 'whether', 'decide', '決める'
    ].any(text.contains) &&
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

    final topTokenText = topTokens.isEmpty ? '本周记录' : topTokens.first;
    final peakDay = _resolvePeakDay(dayCounts);

    return WeeklyInsightModel(
      weekStart: weekStart,
      weekEnd: weekEnd,
      status: 'ready',
      keyInsight: '这周的记录开始围绕“$topTokenText”聚集，$peakDay 的信号更密集。',
      patterns: [
        {
          'name': '重复出现的主题',
          'summary': '这周有一些内容在反复出现，说明它已经不只是一次性的瞬间。',
        },
        {
          'name': '高频关键词：$topTokenText',
          'summary': '从本地统计看，这个主题在这周尤其明显。',
        },
      ],
      frictions: [
        {
          'name': '本周的主要消耗',
          'summary': '当前最大的摩擦，更像是同类事情反复回来，而不是单次事件。',
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
    required List<String> topTokens,
    required int totalDays,
  }) {
    final topToken = topTokens.isEmpty ? '最近的记录' : topTokens.first;

    return MemorySummaryModel(
      patterns: [
        JourneySignalItemModel(
          name: '反复出现的主题',
          summary: '一路看下来，“$topToken”开始不止一次地出现，说明它已经在慢慢形成长期模式。',
          signalLevel: totalDays >= 3 ? 'repeated_pattern' : 'weak_signal',
        ),
      ],
      frictions: [
        JourneySignalItemModel(
          name: '持续性的摩擦',
          summary: '这段时间里，有些问题不是一次性的，而是在慢慢累积，开始形成稳定摩擦。',
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

  String _resolvePeakDay(Map<String, int> dayCounts) {
    if (dayCounts.isEmpty) return '这周';
    return dayCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}
