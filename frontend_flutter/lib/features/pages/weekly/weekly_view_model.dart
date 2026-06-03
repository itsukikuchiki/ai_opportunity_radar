import 'package:flutter/foundation.dart';

import '../../../core/api/repositories/energy_budget_repository.dart';
import '../../../core/api/repositories/weekly_repository.dart';
import '../../../core/api/repositories/analytics_repository.dart';
import '../../../core/models/energy_budget_models.dart';
import '../../../core/models/weekly_models.dart';
import '../../../shared/states/load_state.dart';

class WeeklyViewModel extends ChangeNotifier {
  final WeeklyRepository repository;
  final EnergyBudgetRepository? energyBudgetRepository;
  final AnalyticsRepository? analyticsRepository;

  LoadState loadState = LoadState.initial;
  SubmitState feedbackSubmitState = SubmitState.idle;
  SubmitState experimentSubmitState = SubmitState.idle;
  WeeklyInsightModel? weeklyInsight;
  EnergyBudgetModel? energyBudget;
  String? errorMessage;
  bool showFirstDayGate = false;

  WeeklyViewModel(
    this.repository, {
    this.energyBudgetRepository,
    this.analyticsRepository,
  }) {
    load();
  }

  bool get isLightReady => weeklyInsight?.status == 'light_ready';
  bool get isReady => weeklyInsight?.status == 'ready';

  Future<void> load() async {
    loadState = LoadState.loading;
    errorMessage = null;
    feedbackSubmitState = SubmitState.idle;
    experimentSubmitState = SubmitState.idle;
    showFirstDayGate = false;
    notifyListeners();

    try {
      weeklyInsight = await repository.fetchCurrentWeekly();
      energyBudget = await energyBudgetRepository?.fetchBasicEnergyBudget(
        weekly: weeklyInsight,
      );
      await analyticsRepository?.track(
        'weekly_open',
        properties: {
          'status': weeklyInsight?.status ?? 'unknown',
        },
      );

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
      await analyticsRepository?.track(
        'weekly_open',
        properties: {'status': 'error'},
      );
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
      await analyticsRepository?.track(
        'weekly_feedback',
        properties: {
          'week_start': weekly.weekStart,
          'feedback_value': value,
        },
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
        chartData: weekly.chartData,
      );
    } catch (e) {
      feedbackSubmitState = SubmitState.failure;
      errorMessage = e.toString();
    }

    notifyListeners();
  }

  Future<void> saveExperiment() async {
    final experiment = weeklyInsight?.lifeExperiment;
    if (experiment == null) return;
    experimentSubmitState = SubmitState.submitting;
    notifyListeners();

    final updated = await repository.saveLifeExperiment(experiment.id);
    _replaceExperiment(updated);
  }

  Future<void> skipExperiment() async {
    final experiment = weeklyInsight?.lifeExperiment;
    if (experiment == null) return;
    experimentSubmitState = SubmitState.submitting;
    notifyListeners();

    final updated = await repository.skipLifeExperiment(experiment.id);
    _replaceExperiment(updated);
  }

  Future<void> submitExperimentFeedback({
    required String status,
    required String feedbackText,
  }) async {
    final experiment = weeklyInsight?.lifeExperiment;
    if (experiment == null) return;
    experimentSubmitState = SubmitState.submitting;
    notifyListeners();

    final updated = await repository.submitLifeExperimentFeedback(
      experimentId: experiment.id,
      status: status,
      feedbackText: feedbackText,
    );
    _replaceExperiment(updated);
  }

  void _replaceExperiment(LifeExperimentModel? experiment) {
    final weekly = weeklyInsight;
    if (weekly == null || experiment == null) {
      experimentSubmitState = SubmitState.failure;
      notifyListeners();
      return;
    }

    weeklyInsight = WeeklyInsightModel(
      weekStart: weekly.weekStart,
      weekEnd: weekly.weekEnd,
      status: weekly.status,
      keyInsight: weekly.keyInsight,
      patterns: weekly.patterns,
      frictions: weekly.frictions,
      bestAction: weekly.bestAction,
      opportunitySnapshot: {
        ...?weekly.opportunitySnapshot,
        '_life_experiment': experiment.toJson(),
      },
      feedbackSubmitted: weekly.feedbackSubmitted,
      chartData: weekly.chartData,
    );
    experimentSubmitState = SubmitState.success;
    notifyListeners();
  }
}
