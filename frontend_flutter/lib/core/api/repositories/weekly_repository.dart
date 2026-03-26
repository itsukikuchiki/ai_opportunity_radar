import '../../models/weekly_models.dart';
import '../api_client.dart';

class WeeklyRepository {
  final ApiClient apiClient;
  WeeklyRepository(this.apiClient);

  Future<WeeklyInsightModel> fetchCurrentWeekly() async {
    final res = await apiClient.getJson('/api/v1/weekly/current');
    return WeeklyInsightModel.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> submitWeeklyFeedback({required String weekStart, required String feedbackValue}) async {
    await apiClient.postJson('/api/v1/weekly/$weekStart/feedback', {
      'feedback_value': feedbackValue,
    });
  }
}
