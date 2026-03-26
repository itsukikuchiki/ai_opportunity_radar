import '../../models/today_models.dart';
import '../api_client.dart';

class TodayRepository {
  final ApiClient apiClient;
  TodayRepository(this.apiClient);

  Future<Map<String, dynamic>> fetchToday() async {
    final weeklyRes = await apiClient.getJson('/api/v1/weekly/current');
    final memoryRes = await apiClient.getJson('/api/v1/memory/summary');
    final weekly = weeklyRes['data'] as Map<String, dynamic>;
    final memory = memoryRes['data'] as Map<String, dynamic>;
    return {
      'insight': weekly['key_insight'] == null
          ? TodayInsightModel(text: '先留下几句生活信号，我会开始看出模式。')
          : TodayInsightModel(text: weekly['key_insight'] as String),
      'pendingQuestion': null,
      'bestAction': weekly['best_action'] == null
          ? DailyBestActionModel(text: '今天只要记录一个让你觉得“又来了”的瞬间。')
          : DailyBestActionModel(text: weekly['best_action'] as String),
      'recentSignals': ((memory['patterns'] as List?) ?? const [])
          .take(3)
          .map((e) => RecentSignalModel(content: (e as Map<String, dynamic>)['summary'] as String? ?? ''))
          .toList(),
    };
  }

  Future<Map<String, dynamic>> submitCapture({required String content, String? tagHint}) async {
    final res = await apiClient.postJson('/api/v1/captures', {
      'content': content,
      'input_mode': 'quick_capture',
      'tag_hint': tagHint,
    });
    final data = res['data'] as Map<String, dynamic>;
    return {
      'acknowledgement': data['acknowledgement'] as String,
      'followup': data['followup'] == null
          ? null
          : FollowupQuestionModel.fromJson(data['followup'] as Map<String, dynamic>),
      'updatedRecentSignals': ((data['recent_signals'] as List?) ?? [])
          .map((e) => RecentSignalModel(content: (e as Map<String, dynamic>)['content'] as String))
          .toList(),
    };
  }

  Future<void> submitFollowup({required String followupId, required String answerValue}) async {
    await apiClient.postJson('/api/v1/followups/$followupId/submit', {
      'answer_value': answerValue,
    });
  }
}
