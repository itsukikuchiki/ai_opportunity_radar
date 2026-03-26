import 'package:flutter/foundation.dart';
import '../../../core/api/repositories/weekly_repository.dart';
import '../../../shared/states/load_state.dart';
import '../../../core/models/weekly_models.dart';

class WeeklyViewModel extends ChangeNotifier {
  final WeeklyRepository repository;
  LoadState loadState = LoadState.initial;
  SubmitState feedbackSubmitState = SubmitState.idle;
  WeeklyInsightModel? weeklyInsight;
  String? errorMessage;

  WeeklyViewModel(this.repository) {
    load();
  }

  Future<void> load() async {
    loadState = LoadState.loading;
    notifyListeners();
    try {
      weeklyInsight = await repository.fetchCurrentWeekly();
      loadState = weeklyInsight!.status == 'insufficient_data' ? LoadState.empty : LoadState.ready;
    } catch (e) {
      errorMessage = e.toString();
      loadState = LoadState.error;
    }
    notifyListeners();
  }

  Future<void> submitFeedback(String value) async {
    final weekly = weeklyInsight;
    if (weekly == null) return;
    feedbackSubmitState = SubmitState.submitting;
    notifyListeners();
    try {
      await repository.submitWeeklyFeedback(weekStart: weekly.weekStart, feedbackValue: value);
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
