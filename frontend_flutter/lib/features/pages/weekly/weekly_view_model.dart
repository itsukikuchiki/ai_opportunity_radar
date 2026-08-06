import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/api/repositories/energy_budget_repository.dart';
import '../../../core/api/repositories/weekly_repository.dart';
import '../../../core/api/repositories/analytics_repository.dart';
import '../../../core/i18n/app_locale_text.dart';
import '../../../core/i18n/runtime_locale_text.dart';
import '../../../core/local/local_candidate_planning_repository.dart';
import '../../../core/models/candidate_models.dart';
import '../../../core/models/energy_budget_models.dart';
import '../../../core/models/phase3_plus_models.dart';
import '../../../core/models/weekly_models.dart';
import '../../../core/readiness/report_readiness.dart';
import '../../../shared/states/load_state.dart';

class WeeklyViewModel extends ChangeNotifier {
  final WeeklyRepository repository;
  final EnergyBudgetRepository? energyBudgetRepository;
  final AnalyticsRepository? analyticsRepository;
  late final LocalCandidatePlanningRepository? candidatePlanningRepository;
  late final bool _ownsCandidatePlanningRepository;

  LoadState loadState = LoadState.initial;
  SubmitState feedbackSubmitState = SubmitState.idle;
  SubmitState experimentSubmitState = SubmitState.idle;
  SubmitState attemptFeedbackSubmitState = SubmitState.idle;
  SubmitState goalWeeklySummarySubmitState = SubmitState.idle;
  WeeklyInsightModel? weeklyInsight;
  LifeExperimentModel? currentWeekExperiment;
  LifeExperimentModel? nextWeekExperiment;
  EnergyBudgetModel? energyBudget;
  List<AdoptedMicroActionProgress> activeMicroActions = const [];
  List<AdoptedLifeExperimentProgress> activeExperiments = const [];
  CandidateSnapshot<ExperimentCandidateRecord>? experimentCandidateSnapshot;
  String? errorMessage;
  String? candidateErrorMessage;
  bool progressLoadFailed = false;
  bool showFirstDayGate = false;
  bool _disposed = false;

  WeeklyViewModel(
    this.repository, {
    this.energyBudgetRepository,
    this.analyticsRepository,
    LocalCandidatePlanningRepository? candidatePlanningRepository,
  }) {
    this.candidatePlanningRepository = candidatePlanningRepository ??
        _candidatePlannerFromWeeklyRepository(repository);
    _ownsCandidatePlanningRepository = candidatePlanningRepository == null &&
        this.candidatePlanningRepository != null;
    load();
  }

  bool get isLightReady => weeklyInsight?.status == 'light_ready';
  bool get isReady => weeklyInsight?.status == 'ready';
  DateTime get currentLocalDay => repository.nowLoader().toLocal();
  ReportReadiness get reportReadiness =>
      weeklyInsight?.reportReadiness ??
      ReportReadiness.empty(ReportReadinessEvaluator.weeklyRule);

  CandidateGenerationStatus get experimentCandidateStatus {
    final snapshot = experimentCandidateSnapshot;
    if (snapshot != null) return snapshot.generation.status;
    if ((weeklyInsight?.inclusionSummary.usedCount ?? 0) < 3) {
      return CandidateGenerationStatus.gated;
    }
    if (nextWeekExperiment != null) {
      return CandidateGenerationStatus.ready;
    }
    return CandidateGenerationStatus.stale;
  }

  int get experimentCandidateCount {
    final snapshot = experimentCandidateSnapshot;
    if (snapshot != null) return snapshot.candidates.length;
    return nextWeekExperiment == null ? 0 : 1;
  }

  int get experimentCandidateEligibleSignalCount =>
      experimentCandidateSnapshot?.gate.eligibleSignalCount ??
      weeklyInsight?.inclusionSummary.usedCount ??
      0;

  String? get experimentCandidatePreviewTitle {
    final candidates = experimentCandidateSnapshot?.candidates;
    if (candidates != null && candidates.isNotEmpty) {
      return candidates.first.title;
    }
    return nextWeekExperiment?.title;
  }

  String? get experimentCandidateStaleReason =>
      experimentCandidateSnapshot?.generation.staleReason;

  Future<void> load() async {
    loadState = LoadState.loading;
    errorMessage = null;
    feedbackSubmitState = SubmitState.idle;
    experimentSubmitState = SubmitState.idle;
    attemptFeedbackSubmitState = SubmitState.idle;
    goalWeeklySummarySubmitState = SubmitState.idle;
    showFirstDayGate = false;
    currentWeekExperiment = null;
    nextWeekExperiment = null;
    activeMicroActions = const [];
    activeExperiments = const [];
    experimentCandidateSnapshot = null;
    candidateErrorMessage = null;
    progressLoadFailed = false;
    _notifyListeners();

    try {
      final weekly = await repository.fetchCurrentWeekly();
      weeklyInsight = weekly;
      await _loadAdoptedProgress(weekly);
      await _loadExperimentCandidateState(weekly);
      if (weekly.inclusionSummary.usedCount >= 3) {
        nextWeekExperiment = await repository.fetchNextWeekExperiment(
          weekStart: weekly.weekStart,
        );
      }
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

    _notifyListeners();
  }

  Future<void> _loadAdoptedProgress(WeeklyInsightModel weekly) async {
    final planner = candidatePlanningRepository;
    if (planner == null) {
      currentWeekExperiment = await repository.fetchCurrentWeekLifeExperiment(
        weekStart: weekly.weekStart,
      );
      return;
    }

    try {
      final weekStart = DateTime.tryParse(weekly.weekStart) ??
          _startOfWeek(repository.nowLoader());
      final weekEnd = DateTime.tryParse(weekly.weekEnd) ??
          weekStart.add(const Duration(days: 6));
      activeMicroActions = await planner.listAdoptedSmallTriesForWeek(
        weekStart: weekStart,
        weekEnd: weekEnd,
      );
      activeExperiments = await planner.listAdoptedGoalsForWeek(
        weekStart: weekStart,
        weekEnd: weekEnd,
      );
    } catch (_) {
      progressLoadFailed = true;
      activeMicroActions = const [];
      activeExperiments = const [];
    }

    currentWeekExperiment = activeExperiments.isNotEmpty
        ? activeExperiments.first.experiment
        : await repository.fetchCurrentWeekLifeExperiment(
            weekStart: weekly.weekStart,
          );
  }

  Future<void> _loadExperimentCandidateState(
    WeeklyInsightModel weekly,
  ) async {
    final planner = candidatePlanningRepository;
    if (planner == null) return;
    final weekDay = DateTime.tryParse(weekly.weekStart) ?? DateTime.now();

    try {
      experimentCandidateSnapshot =
          await planner.weeklyCandidateSnapshot(weekDay);
      _notifyListeners();
      experimentCandidateSnapshot =
          await planner.refreshWeeklyWithGroundedSuggestions(
        day: weekDay,
        language: _repositoryLanguage(),
      );
    } catch (error) {
      candidateErrorMessage = error.toString();
      try {
        experimentCandidateSnapshot =
            await planner.weeklyCandidateSnapshot(weekDay);
      } catch (_) {
        // The Weekly report remains usable even when candidate storage fails.
      }
    }
  }

  static LocalCandidatePlanningRepository?
      _candidatePlannerFromWeeklyRepository(WeeklyRepository repository) {
    final lifeExperimentRepository = repository.localLifeExperimentRepository;
    if (lifeExperimentRepository == null) return null;
    return LocalCandidatePlanningRepository(
      localDatabase: repository.localWeeklySnapshotRepository.localDatabase,
      localCaptureRepository: repository.localCaptureRepository,
      localLifeExperimentRepository: lifeExperimentRepository,
      localUserId: repository.localUserId,
      eligibilityService: repository.eligibilityService,
      nowLoader: repository.nowLoader,
    );
  }

  static DateTime _startOfWeek(DateTime value) {
    final day = DateTime(value.year, value.month, value.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  AppLanguage _repositoryLanguage() {
    return switch (
        RuntimeLocaleText.normalize(repository.aiRepository.languageLoader())) {
      'zh-Hans' => AppLanguage.simplifiedChinese,
      'zh-Hant' => AppLanguage.traditionalChinese,
      'ja' => AppLanguage.japanese,
      _ => AppLanguage.english,
    };
  }

  void _notifyListeners() {
    if (!_disposed) notifyListeners();
  }

  Future<void> retry() => load();

  Future<void> submitFeedback(String value) async {
    final weekly = weeklyInsight;
    if (weekly == null) return;

    feedbackSubmitState = SubmitState.submitting;
    errorMessage = null;
    _notifyListeners();

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

    _notifyListeners();
  }

  Future<void> submitMicroActionFeedback({
    required MicroActionModel action,
    required String status,
    String? effect,
    String? difficulty,
    String? userNote,
  }) async {
    final weekly = weeklyInsight;
    if (weekly == null ||
        attemptFeedbackSubmitState == SubmitState.submitting) {
      return;
    }

    attemptFeedbackSubmitState = SubmitState.submitting;
    errorMessage = null;
    _notifyListeners();
    try {
      final updated = await repository.submitMicroActionFeedback(
        microActionId: action.id,
        status: status,
        effect: effect,
        difficulty: difficulty,
        userNote: userNote,
      );
      if (updated == null) {
        throw StateError('micro_action_feedback_not_recorded');
      }
      await _loadAdoptedProgress(weekly);
      await analyticsRepository?.track(
        'weekly_attempt_feedback',
        properties: {
          'kind': 'small_try',
          'status': status,
          'week_start': weekly.weekStart,
        },
      );
      attemptFeedbackSubmitState = SubmitState.success;
    } catch (e) {
      attemptFeedbackSubmitState = SubmitState.failure;
      errorMessage = e.toString();
    }
    _notifyListeners();
  }

  Future<void> submitLifeExperimentFeedback({
    required LifeExperimentModel experiment,
    required String status,
    String? feedbackText,
  }) async {
    final weekly = weeklyInsight;
    if (weekly == null ||
        attemptFeedbackSubmitState == SubmitState.submitting) {
      return;
    }

    attemptFeedbackSubmitState = SubmitState.submitting;
    errorMessage = null;
    _notifyListeners();
    try {
      final updated = await repository.submitLifeExperimentFeedback(
        experimentId: experiment.id,
        status: status,
        feedbackText: feedbackText?.trim() ?? '',
      );
      if (updated == null) {
        throw StateError('life_experiment_feedback_not_recorded');
      }
      await _loadAdoptedProgress(weekly);
      await analyticsRepository?.track(
        'weekly_attempt_feedback',
        properties: {
          'kind': 'goal',
          'status': status,
          'week_start': weekly.weekStart,
        },
      );
      attemptFeedbackSubmitState = SubmitState.success;
    } catch (e) {
      attemptFeedbackSubmitState = SubmitState.failure;
      errorMessage = e.toString();
    }
    _notifyListeners();
  }

  Future<int> completedGoalObservationDays(
    LifeExperimentModel experiment,
  ) async {
    final localRepository = repository.localLifeExperimentRepository;
    if (localRepository == null) return 0;
    final feedbacks = await localRepository.listFeedbacks(
      experimentId: experiment.id,
    );
    final latestByDay = <String, LifeExperimentFeedbackModel>{};
    for (final feedback in feedbacks) {
      latestByDay[feedback.localDate] = feedback;
    }
    return latestByDay.values
        .where(
          (feedback) => const {
            'done',
            'completed',
            'occurred',
            'happened',
            'true',
            'yes',
            '1',
          }.contains(feedback.completionStatus.trim().toLowerCase()),
        )
        .length;
  }

  Future<bool> submitGoalWeeklySummary({
    required LifeExperimentModel experiment,
    required String outcomeResult,
    required String burden,
    String? note,
  }) async {
    final weekly = weeklyInsight;
    final localRepository = repository.localLifeExperimentRepository;
    if (weekly == null ||
        localRepository == null ||
        goalWeeklySummarySubmitState == SubmitState.submitting) {
      return false;
    }
    goalWeeklySummarySubmitState = SubmitState.submitting;
    errorMessage = null;
    _notifyListeners();
    try {
      final saved = await localRepository.recordWeeklyReview(
        experimentId: experiment.id,
        outcomeResult: outcomeResult,
        burden: burden,
        reviewNote: note,
        reviewedAt: currentLocalDay,
      );
      if (saved == null) {
        throw StateError('goal_weekly_summary_not_recorded');
      }
      await _loadAdoptedProgress(weekly);
      await analyticsRepository?.track(
        'weekly_goal_summary',
        properties: {
          'week_start': weekly.weekStart,
          'outcome_result': outcomeResult,
          'burden': burden,
        },
      );
      goalWeeklySummarySubmitState = SubmitState.success;
      _notifyListeners();
      return true;
    } catch (error) {
      goalWeeklySummarySubmitState = SubmitState.failure;
      errorMessage = error.toString();
      _notifyListeners();
      return false;
    }
  }

  Future<void> saveExperiment() async {
    final experiment = nextWeekExperiment;
    if (experiment == null) return;
    experimentSubmitState = SubmitState.submitting;
    _notifyListeners();

    final updated = await repository.saveLifeExperiment(experiment.id);
    _replaceExperiment(updated);
  }

  Future<void> updateExperimentDetails({
    required String title,
    required String hypothesis,
    required String suggestedAction,
  }) async {
    final experiment = nextWeekExperiment;
    if (experiment == null) return;
    experimentSubmitState = SubmitState.submitting;
    _notifyListeners();

    final updated = await repository.updateLifeExperimentDetails(
      experimentId: experiment.id,
      title: title,
      hypothesis: hypothesis,
      suggestedAction: suggestedAction,
    );
    _replaceNextWeekExperiment(updated);
  }

  void _replaceExperiment(LifeExperimentModel? experiment) {
    _replaceNextWeekExperiment(experiment);
  }

  void _replaceNextWeekExperiment(LifeExperimentModel? experiment) {
    final weekly = weeklyInsight;
    if (weekly == null || experiment == null) {
      experimentSubmitState = SubmitState.failure;
      _notifyListeners();
      return;
    }

    nextWeekExperiment = experiment;
    experimentSubmitState = SubmitState.success;
    _notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    if (_ownsCandidatePlanningRepository) {
      final planner = candidatePlanningRepository;
      if (planner != null) unawaited(planner.dispose());
    }
    super.dispose();
  }
}
