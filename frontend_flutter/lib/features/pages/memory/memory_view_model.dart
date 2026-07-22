import 'package:flutter/foundation.dart';

import '../../../core/api/repositories/analytics_repository.dart';
import '../../../core/api/repositories/memory_repository.dart';
import '../../../core/models/memory_models.dart';
import '../../../core/readiness/report_readiness.dart';
import '../../../shared/states/load_state.dart';

class MemoryViewModel extends ChangeNotifier {
  final MemoryRepository repository;
  final AnalyticsRepository? analyticsRepository;

  LoadState loadState = LoadState.initial;
  MemorySummaryModel? summary;
  List<JourneyEvidenceItemModel> evidenceItems = const [];
  SubmitState evidenceLoadState = SubmitState.idle;
  String? errorMessage;
  String? evidenceErrorMessage;
  bool showFirstDayGate = false;
  ReportReadiness journeyReadiness = ReportReadiness.empty(
    ReportReadinessEvaluator.journeyRule,
  );
  late DateTime selectedMonth;

  MemoryViewModel(
    this.repository, {
    this.analyticsRepository,
  }) {
    final now = DateTime.now();
    selectedMonth = DateTime(now.year, now.month);
    load();
  }

  bool get canSelectNextMonth {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    return selectedMonth.isBefore(currentMonth);
  }

  Future<void> selectMonth(DateTime month) async {
    final normalized = DateTime(month.year, month.month);
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    if (normalized.isAfter(currentMonth) || normalized == selectedMonth) return;
    selectedMonth = normalized;
    await load();
  }

  bool get hasSummary => summary != null && summary!.hasAnySignals;
  int get weakSignalCount => summary?.weakSignals.length ?? 0;
  int get repeatedPatternCount => summary?.repeatedPatterns.length ?? 0;
  int get stableModeCount => summary?.stableModes.length ?? 0;

  Future<void> load() async {
    loadState = LoadState.loading;
    errorMessage = null;
    evidenceErrorMessage = null;
    evidenceItems = const [];
    evidenceLoadState = SubmitState.idle;
    showFirstDayGate = false;
    journeyReadiness =
        ReportReadiness.empty(ReportReadinessEvaluator.journeyRule);
    notifyListeners();

    try {
      final result = await repository.fetchMemorySummaryResult(
        month: selectedMonth,
      );
      summary = result.summary;
      showFirstDayGate = result.isFirstDayGate;
      journeyReadiness = result.journeyReadiness ??
          (summary?.hasAnySignals == true
              ? const ReportReadiness(
                  rule: ReportReadinessEvaluator.journeyRule,
                  signalCount: 7,
                  distinctDayCount: 3,
                  distinctWeekCount: 1,
                )
              : ReportReadiness.empty(ReportReadinessEvaluator.journeyRule));
      await analyticsRepository?.track(
        'journey_open',
        properties: {
          'status': result.isFirstDayGate
              ? 'first_day_gate'
              : summary?.hasAnySignals == true
                  ? 'ready'
                  : 'empty',
        },
      );

      if (showFirstDayGate) {
        loadState = LoadState.empty;
      } else if (!journeyReadiness.isReady ||
          summary == null ||
          !summary!.hasAnySignals) {
        loadState = LoadState.empty;
      } else {
        loadState = LoadState.ready;
      }
    } catch (e) {
      await analyticsRepository?.track(
        'journey_open',
        properties: {'status': 'error'},
      );
      errorMessage = e.toString();
      loadState = LoadState.error;
    }

    notifyListeners();
  }

  Future<void> retry() => load();

  Future<List<JourneyEvidenceItemModel>> loadEvidence({
    JourneyTraceModel? trace,
  }) async {
    evidenceLoadState = SubmitState.submitting;
    evidenceErrorMessage = null;
    notifyListeners();

    try {
      final result = await repository.fetchJourneyEvidence(trace: trace);
      evidenceItems = result;
      evidenceLoadState = SubmitState.success;
      notifyListeners();
      return result;
    } catch (e) {
      evidenceItems = const [];
      evidenceErrorMessage = e.toString();
      evidenceLoadState = SubmitState.failure;
      notifyListeners();
      return const [];
    }
  }
}
