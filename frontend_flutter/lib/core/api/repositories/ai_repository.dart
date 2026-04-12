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
        followup: data['followup'] == null
            ? null
            : FollowupQuestionModel.fromJson(
                data['followup'] as Map<String, dynamic>,
              ),
      );
    } catch (_) {
      return AiCaptureReplyResult(
        acknowledgement: _fallbackAcknowledgement(content),
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
                  'content': e.content,
                  'created_at': e.createdAt?.toUtc().toIso8601String(),
                  'acknowledgement': e.acknowledgement,
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

  String _dateKey(DateTime date) {
    final local = date.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd';
  }

  String _fallbackAcknowledgement(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return '先把这一条留在这里。';
    return '我看到了这条记录：$trimmed。先把它放在今天里。';
  }

  String _fallbackObservation(List<RecentSignalModel> entries) {
    if (entries.isEmpty) {
      return '今天还没有记录，先留下一件真实发生的小事就好。';
    }
    if (entries.length == 1) {
      return '今天记录了 1 条。你已经开始把今天里真正触动你的事留了下来。';
    }
    return '今天记录了 ${entries.length} 条。今天的线索已经开始聚起来了。';
  }

  String _fallbackSuggestion(List<RecentSignalModel> entries) {
    if (entries.isEmpty) {
      return '今天先记下一件让你停顿了一下的小事就好。';
    }
    if (entries.length == 1) {
      return '如果同类事情今天再出现一次，再补记一条就可以。';
    }
    return '接下来先留意：今天有没有哪类事情已经不是第一次这样发生。';
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
    );
  }

  MemorySummaryModel _fallbackJourneySummary({
    required List<String> topTokens,
    required int totalDays,
  }) {
    final topToken = topTokens.isEmpty ? '最近的记录' : topTokens.first;

    return MemorySummaryModel(
      patterns: [
        {
          'name': '反复出现的主题',
          'summary': '一路看下来，“$topToken”开始不止一次地出现。',
        },
      ],
      frictions: [
        {
          'name': '持续性的摩擦',
          'summary': '这段时间里，某些同类问题不是一次性，而是在慢慢累积。',
        },
      ],
      desires: [
        {
          'name': '还在浮现的方向',
          'summary': '记录已经跨越 $totalDays 天，一些真正长期在意的方向正在慢慢浮现。',
        },
      ],
      experiments: [
        {
          'name': '开始有帮助的东西',
          'summary': '继续记录下去，会更容易看见什么正在慢慢对你起作用。',
        },
      ],
    );
  }

  String _resolvePeakDay(Map<String, int> dayCounts) {
    if (dayCounts.isEmpty) return '这周';
    final entries = dayCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.first.key;
  }
}
