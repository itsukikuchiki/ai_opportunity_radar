import '../api_client.dart';

class AnalyticsRepository {
  final ApiClient apiClient;

  AnalyticsRepository(this.apiClient);

  Future<void> track(
    String eventName, {
    Map<String, dynamic>? properties,
    double? numericValue,
  }) async {
    try {
      await apiClient.postJson('/api/v1/analytics/events', {
        'event_name': eventName,
        'properties': properties ?? <String, dynamic>{},
        'numeric_value': numericValue,
      }).timeout(const Duration(seconds: 4));
    } catch (_) {
      // Analytics must never block the app's core journaling flow.
    }
  }
}
