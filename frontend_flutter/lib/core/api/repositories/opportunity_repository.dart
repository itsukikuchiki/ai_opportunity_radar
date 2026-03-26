import '../../models/opportunity_models.dart';
import '../api_client.dart';

class OpportunityRepository {
  final ApiClient apiClient;
  OpportunityRepository(this.apiClient);

  Future<List<OpportunityListItemModel>> fetchOpportunities() async {
    final res = await apiClient.getJson('/api/v1/opportunities');
    return ((res['data'] as Map<String, dynamic>)['items'] as List)
        .map((e) => OpportunityListItemModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<OpportunityDetailModel> fetchOpportunityDetail(String id) async {
    final res = await apiClient.getJson('/api/v1/opportunities/$id');
    return OpportunityDetailModel.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> submitOpportunityFeedback({required String opportunityId, required String feedbackValue}) async {
    await apiClient.postJson('/api/v1/opportunities/$opportunityId/feedback', {
      'feedback_value': feedbackValue,
    });
  }
}
