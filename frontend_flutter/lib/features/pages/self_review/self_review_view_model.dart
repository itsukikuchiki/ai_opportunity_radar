import 'package:flutter/foundation.dart';

import '../../../core/api/repositories/self_review_repository.dart';
import '../../../core/models/self_review_models.dart';
import '../../../shared/states/load_state.dart';

class SelfReviewViewModel extends ChangeNotifier {
  final SelfReviewRepository repository;

  LoadState loadState = LoadState.initial;
  SelfReviewModel? review;
  String? errorMessage;

  SelfReviewViewModel(this.repository) {
    load();
  }

  Future<void> load() async {
    loadState = LoadState.loading;
    errorMessage = null;
    notifyListeners();

    try {
      review = await repository.fetchSelfReview();
      if (review == null || review!.isInsufficient) {
        loadState = LoadState.empty;
      } else {
        loadState = LoadState.ready;
      }
    } catch (e) {
      errorMessage = e.toString();
      loadState = LoadState.error;
    }

    notifyListeners();
  }

  Future<void> retry() => load();
}
