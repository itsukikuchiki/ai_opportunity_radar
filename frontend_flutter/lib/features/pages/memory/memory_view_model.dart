import 'package:flutter/foundation.dart';

import '../../../core/api/repositories/analytics_repository.dart';
import '../../../core/api/repositories/memory_repository.dart';
import '../../../core/models/memory_models.dart';
import '../../../core/models/journey_pro_models.dart';
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
  ReportReadiness proReadiness = ReportReadiness.empty(
    ReportReadinessEvaluator.journeyProRule,
  );
  JourneyProReportModel? proReport;
  LoadState proReportLoadState = LoadState.initial;
  String? proReportErrorMessage;

  MemoryViewModel(
    this.repository, {
    this.analyticsRepository,
  }) {
    load();
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
    proReadiness =
        ReportReadiness.empty(ReportReadinessEvaluator.journeyProRule);
    notifyListeners();

    try {
      final result = await repository.fetchMemorySummaryResult();
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
      proReadiness = result.proReadiness ??
          ReportReadiness.empty(ReportReadinessEvaluator.journeyProRule);
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

  Future<void> loadProReport() async {
    proReportLoadState = LoadState.loading;
    proReportErrorMessage = null;
    notifyListeners();
    try {
      final report = await repository.fetchJourneyProReport();
      proReport = report;
      proReadiness = report.readiness;
      proReportLoadState = report.isReady ? LoadState.ready : LoadState.empty;
    } catch (error) {
      proReport = null;
      proReportErrorMessage = error.toString();
      proReportLoadState = LoadState.error;
    }
    notifyListeners();
  }

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
