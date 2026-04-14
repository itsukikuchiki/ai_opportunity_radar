import 'package:flutter/foundation.dart';

import '../../../core/api/repositories/weekly_repository.dart';
import '../../../core/models/weekly_models.dart';
import '../../../shared/states/load_state.dart';

class WeeklyViewModel extends ChangeNotifier {
  final WeeklyRepository repository;

  LoadState loadState = LoadState.initial;
  SubmitState feedbackSubmitState = SubmitState.idle;
  WeeklyInsightModel? weeklyInsight;
  String? errorMessage;
  bool showFirstDayGate = false;

  WeeklyViewModel(this.repository) {
    load();
  }

  Future<void> load() async {
    loadState = LoadState.loading;
    errorMessage = null;
    feedbackSubmitState = SubmitState.idle;
    showFirstDayGate = false;
    notifyListeners();

    try {
      weeklyInsight = await repository.fetchCurrentWeekly();

      if (weeklyInsight?.status == 'first_day_gate') {
        showFirstDayGate = true;
        loadState = LoadState.empty;
      } else if (weeklyInsight?.status == 'insufficient_data' ||
          weeklyInsight?.status == 'not_started') {
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

  Future<void> submitFeedback(String value) async {
    final weekly = weeklyInsight;
    if (weekly == null) return;

    feedbackSubmitState = SubmitState.submitting;
    errorMessage = null;
    notifyListeners();

    try {
      await repository.submitWeeklyFeedback(
        weekStart: weekly.weekStart,
        feedbackValue: value,
      );

      feedbackSubmitState = SubmitState.success;
      weeklyInsight = WeeklyInsightModel(
        weekStart: weekly.weekStart,
        weekEnd: weekly.weekEnd,
        status: weekly.status,
        keyInsight: weekly.keyInsight,
        patterns: weekly.patterns,
        frictions: weekly.frictions,
        bestAction: weekly.bestAction,
        opportunitySnapshot: weekly.opportunitySnapshot,
        feedbackSubmitted: true,
      );
    } catch (e) {
      feedbackSubmitState = SubmitState.failure;
      errorMessage = e.toString();
    }

    notifyListeners();
  }
}
