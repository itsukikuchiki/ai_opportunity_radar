import 'package:flutter_test/flutter_test.dart';

import 'package:ai_opportunity_radar/core/api/repositories/journey_pro_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_capture_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/local/local_journey_aggregation_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_observation_repository.dart';
import 'package:ai_opportunity_radar/core/models/feedback_event_models.dart';
import 'package:ai_opportunity_radar/core/models/today_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('uses three natural months and eligible Signal only for readiness',
      () async {
    final signals = _threeReadyMonths();
    final repository = _repository(
      aggregation: _aggregation(
        signals: signals,
        feedbackEvents: const [],
      ),
    );

    final report = await repository.fetchThreeMonthChange(
      selectedMonthKey: '2026-07',
    );

    expect(
      report.months.map((month) => month.monthKey),
      ['2026-05', '2026-06', '2026-07'],
    );
    expect(report.periodStart, '2026-05-01');
    expect(report.periodEnd, '2026-07-22');
    expect(report.readyMonthCount, 3);
    expect(report.canShowChange, isTrue);
    expect(report.totalSignalCount, 21);
    for (final month in report.months) {
      expect(
        month.energyStateCounts.values
            .fold<int>(0, (sum, value) => sum + value),
        month.signalCount,
      );
      expect(
        month.domainCounts.values.fold<int>(0, (sum, value) => sum + value),
        month.signalCount,
      );
    }
  });

  test(
      'feedback, reviews and internal observations change context coverage and source version without changing readiness',
      () async {
    final signals = _threeReadyMonths();
    final signalOnly = await _repository(
      aggregation: _aggregation(signals: signals, feedbackEvents: const []),
    ).fetchThreeMonthChange(selectedMonthKey: '2026-07');
    final withContext = await _repository(
      aggregation: _aggregation(
        signals: signals,
        feedbackEvents: [
          _feedback('feedback-1', 'micro_action_feedback'),
          _feedback('feedback-2', 'life_experiment_feedback'),
          _feedback('feedback-3', 'schedule_feedback'),
          _feedback('review-1', 'micro_action_round_review'),
          _feedback('review-2', 'life_experiment_outcome_review'),
        ],
        planContentVersions: const [
          {
            'id': 'plan-version-1',
            'object_kind': 'quick_try',
            'object_id': 'quick-1',
            'version_no': 1,
            'effective_from_local_date': '2026-07-01',
            'content_json': '{"title":"先缩小一步"}',
          },
        ],
      ),
      observations: const [
        {
          'id': 'internal-observation-1',
          'status': 'confirmed',
          'observation_text': 'internal only',
          'source_period_start': '2026-06-01',
          'updated_at': '2026-07-20T00:00:00Z',
        },
      ],
    ).fetchThreeMonthChange(selectedMonthKey: '2026-07');

    expect(withContext.readyMonthCount, signalOnly.readyMonthCount);
    expect(withContext.canShowChange, signalOnly.canShowChange);
    expect(withContext.totalSignalCount, signalOnly.totalSignalCount);
    expect(signalOnly.contextCoverage.hasContext, isFalse);
    expect(withContext.contextCoverage.hasBroadContext, isTrue);
    expect(withContext.contextCoverage.feedbackCount, 3);
    expect(withContext.contextCoverage.reviewCount, 2);
    expect(withContext.contextCoverage.experimentContextCount, 1);
    expect(withContext.contextCoverage.observationCount, 1);
    expect(withContext.sourceHash, isNot(signalOnly.sourceHash));
  });

  test('past selected month ends on its natural month boundary', () async {
    final report = await _repository(
      aggregation: _aggregation(
        signals: _threeReadyMonths(),
        feedbackEvents: const [],
      ),
    ).fetchThreeMonthChange(selectedMonthKey: '2026-06');

    expect(report.selectedMonthKey, '2026-06');
    expect(report.periodStart, '2026-04-01');
    expect(report.periodEnd, '2026-06-30');
  });
}

JourneyProRepository _repository({
  required JourneyAggregationModel aggregation,
  List<Map<String, Object?>> observations = const [],
}) {
  final database = LocalDatabase(dbPathOverride: 'journey_pro_test.db');
  final capture = LocalCaptureRepository(database);
  return JourneyProRepository(
    localCaptureRepository: capture,
    journeyAggregationRepository: _StubAggregationRepository(
      capture,
      aggregation,
    ),
    localObservationRepository: _StubObservationRepository(
      database,
      observations,
    ),
    nowLoader: () => DateTime(2026, 7, 22, 12),
    installationDateLoader: () async => DateTime(2026, 1, 10),
  );
}

JourneyAggregationModel _aggregation({
  required List<RecentSignalModel> signals,
  required List<FeedbackEventModel> feedbackEvents,
  List<Map<String, dynamic>> planContentVersions = const [],
}) {
  return JourneyAggregationModel(
    periodStart: DateTime(2026, 7, 1),
    periodEnd: DateTime(2026, 7, 22),
    startDate: '2026-07-01',
    endDate: '2026-07-22',
    signals: signals
        .where((signal) => signal.localDate!.startsWith('2026-07'))
        .toList(),
    experimentHistory: const [],
    experimentRollups: const [],
    feedbackEvents: const [],
    microActionFeedbacks: const [],
    experimentFeedbacks: const [],
    weeklyReviews: const [],
    sourceSignals: signals,
    sourceExperimentHistory: const [],
    sourceExperimentRollups: const [],
    sourcePlanContentVersions: planContentVersions,
    sourceFeedbackEvents: feedbackEvents,
    sourceWeeklyReviews: const [],
  );
}

List<RecentSignalModel> _threeReadyMonths() {
  final signals = <RecentSignalModel>[];
  for (final month in [5, 6, 7]) {
    for (var index = 0; index < 7; index += 1) {
      final day = 1 + (index % 3);
      final monthKey = month.toString().padLeft(2, '0');
      final dayKey = day.toString().padLeft(2, '0');
      signals.add(
        RecentSignalModel(
          id: 'signal-$month-$index',
          signalCardId: 'signal-$month-$index',
          content: 'eligible $month/$day #$index',
          localDate: '2026-$monthKey-$dayKey',
          createdAt: DateTime(2026, month, day, 9 + index),
          energyState: index.isEven ? 'steady' : 'recovery',
          rawPayloadJson: const {'focus_domain_id': 'growth_plan'},
          userConfirmation: 'confirmed',
          includedInSummary: true,
          includedInWeekly: true,
          includedInJourney: true,
        ),
      );
    }
  }
  return signals;
}

class _StubAggregationRepository extends LocalJourneyAggregationRepository {
  final JourneyAggregationModel result;

  _StubAggregationRepository(
    LocalCaptureRepository capture,
    this.result,
  ) : super(localCaptureRepository: capture);

  @override
  Future<JourneyAggregationModel> fetchMonth({
    required String localUserId,
    required DateTime selectedMonth,
    required DateTime today,
    required DateTime installationDate,
  }) async {
    return result;
  }
}

class _StubObservationRepository extends LocalObservationRepository {
  final List<Map<String, Object?>> result;

  _StubObservationRepository(
    super.database,
    this.result,
  );

  @override
  Future<List<Map<String, Object?>>> listForPeriod({
    required String startDate,
    required String endDate,
    List<String> statuses = const ['generated', 'confirmed'],
  }) async {
    return result;
  }
}

FeedbackEventModel _feedback(String id, String sourceType) {
  return FeedbackEventModel(
    id: id,
    sourceType: sourceType,
    sourceId: id,
    subjectType: 'test',
    subjectId: 'subject',
    localUserId: 'local',
    localDate: '2026-07-20',
    status: 'recorded',
  );
}
