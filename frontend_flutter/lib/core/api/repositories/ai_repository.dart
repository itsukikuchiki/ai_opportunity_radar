import '../../models/today_models.dart';
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
        acknowledgement: (data['acknowledgement'] as String?) ?? _fallbackAcknowledgement(content),
        followup: data['followup'] == null
            ? null
            : FollowupQuestionModel.fromJson(data['followup'] as Map<String, dynamic>),
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
        observation: (data['observation'] as String?) ?? _fallbackObservation(entries),
        suggestion: (data['suggestion'] as String?) ?? _fallbackSuggestion(entries),
      );
    } catch (_) {
      return AiTodaySummaryResult(
        observation: _fallbackObservation(entries),
        suggestion: _fallbackSuggestion(entries),
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
}
