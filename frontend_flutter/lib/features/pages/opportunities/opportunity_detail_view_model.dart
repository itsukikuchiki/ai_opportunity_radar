import 'package:flutter/foundation.dart';
import '../../../core/api/repositories/opportunity_repository.dart';
import '../../../core/models/opportunity_models.dart';
import '../../../shared/states/load_state.dart';

class OpportunityDetailViewModel extends ChangeNotifier {
  final OpportunityRepository repository;
  LoadState loadState = LoadState.initial;
  SubmitState submitState = SubmitState.idle;
  OpportunityDetailModel? detail;
  String? errorMessage;

  OpportunityDetailViewModel(this.repository);

  Future<void> load(String id) async {
    loadState = LoadState.loading;
    notifyListeners();
    try {
      detail = await repository.fetchOpportunityDetail(id);
      loadState = LoadState.ready;
    } catch (e) {
      errorMessage = e.toString();
      loadState = LoadState.error;
    }
    notifyListeners();
  }

  Future<void> submitFeedback(String value) async {
    final id = detail?.id;
    if (id == null) return;
    submitState = SubmitState.submitting;
    notifyListeners();
    try {
      await repository.submitOpportunityFeedback(opportunityId: id, feedbackValue: value);
      submitState = SubmitState.success;
    } catch (e) {
      errorMessage = e.toString();
      submitState = SubmitState.failure;
    }
    notifyListeners();
  }
}
