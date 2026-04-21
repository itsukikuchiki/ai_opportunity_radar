import 'package:flutter/foundation.dart';

import '../../../core/api/repositories/monthly_repository.dart';
import '../../../core/models/monthly_models.dart';
import '../../../shared/states/load_state.dart';

class MonthlyViewModel extends ChangeNotifier {
  final MonthlyRepository repository;

  LoadState loadState = LoadState.initial;
  MonthlyReviewModel? monthly;
  String? errorMessage;
  bool showFirstMonthGate = false;

  MonthlyViewModel(this.repository) {
    load();
  }

  Future<void> load() async {
    loadState = LoadState.loading;
    errorMessage = null;
    showFirstMonthGate = false;
    notifyListeners();

    try {
      monthly = await repository.fetchCurrentMonthly();
      if (monthly?.status == 'first_month_gate') {
        showFirstMonthGate = true;
        loadState = LoadState.empty;
      } else if (monthly?.status == 'insufficient_data' || monthly?.status == 'not_started') {
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
