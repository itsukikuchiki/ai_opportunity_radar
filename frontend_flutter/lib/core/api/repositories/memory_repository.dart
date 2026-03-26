import '../../models/memory_models.dart';
import '../api_client.dart';

class MemoryRepository {
  final ApiClient apiClient;
  MemoryRepository(this.apiClient);

  Future<MemorySummaryModel> fetchMemorySummary() async {
    final res = await apiClient.getJson('/api/v1/memory/summary');
    return MemorySummaryModel.fromJson(res['data'] as Map<String, dynamic>);
  }
}
