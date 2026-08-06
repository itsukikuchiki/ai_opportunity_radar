import 'package:flutter_test/flutter_test.dart';

import 'package:ai_opportunity_radar/core/api/repositories/journey_pro_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_capture_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/local/local_journey_aggregation_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_observation_repository.dart';
import 'package:ai_opportunity_radar/core/models/feedback_event_models.dart';
import 'package:ai_opportunity_radar/core/models/today_models.dart';
import 'package:ai_opportunity_radar/core/preferences/focus_domains.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('uses every natural month through the latest completed month', () async {
    final signals = _threeReadyMonths();
    final repository = _repository(
      aggregation: _aggregation(
        signals: signals,
        feedbackEvents: const [],
      ),
    );

    final report = await repository.fetchFullHistoryChange(
      selectedMonthKey: '2026-07',
    );

    expect(
      report.months.map((month) => month.monthKey),
      [
        '2026-01',
        '2026-02',
        '2026-03',
        '2026-04',
        '2026-05',
        '2026-06',
        '2026-07',
      ],
    );
    expect(report.periodStart, '2026-01-01');
    expect(report.periodEnd, '2026-07-31');
    expect(report.selectedMonthKey, '2026-07');
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
      expect(
        month.themeCounts.values.fold<int>(0, (sum, value) => sum + value),
        month.signalCount,
      );
    }
    expect(
        report.months.take(4).every((month) => month.signalCount == 0), isTrue);
  });

  test(
      'feedback, reviews and internal observations change context coverage and source version without changing readiness',
      () async {
    final signals = _threeReadyMonths();
    final signalOnly = await _repository(
      aggregation: _aggregation(signals: signals, feedbackEvents: const []),
    ).fetchFullHistoryChange(selectedMonthKey: '2026-07');
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
    ).fetchFullHistoryChange(selectedMonthKey: '2026-07');

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

  test('a historical selection does not truncate the Pro history', () async {
    final report = await _repository(
      aggregation: _aggregation(
        signals: _threeReadyMonths(),
        feedbackEvents: const [],
      ),
    ).fetchFullHistoryChange(selectedMonthKey: '2026-06');

    expect(report.selectedMonthKey, '2026-07');
    expect(report.periodStart, '2026-01-01');
    expect(report.periodEnd, '2026-07-31');
    expect(
      report.months.map((month) => month.monthKey),
      [
        '2026-01',
        '2026-02',
        '2026-03',
        '2026-04',
        '2026-05',
        '2026-06',
        '2026-07',
      ],
    );
  });

  test('waits for the calendar month to end before adding it', () async {
    final signals = [
      ..._threeReadyMonths(),
      _signal(
        id: 'signal-august',
        localDate: '2026-08-01',
        content: 'August should still be in progress',
        sceneTags: const ['work'],
      ),
    ];
    final aggregation = _aggregation(
      signals: signals,
      feedbackEvents: const [],
    );

    final duringAugust = await _repository(
      aggregation: aggregation,
      now: DateTime(2026, 8, 31, 23, 59),
    ).fetchFullHistoryChange();
    final afterAugust = await _repository(
      aggregation: aggregation,
      now: DateTime(2026, 9, 1),
    ).fetchFullHistoryChange();

    expect(duringAugust.months.last.monthKey, '2026-07');
    expect(duringAugust.periodEnd, '2026-07-31');
    expect(duringAugust.totalSignalCount, 21);
    expect(afterAugust.months.last.monthKey, '2026-08');
    expect(afterAugust.periodEnd, '2026-08-31');
    expect(afterAugust.selectedMonthKey, '2026-08');
    expect(afterAugust.totalSignalCount, 22);
  });

  test('current or future selections cannot reveal an unfinished month',
      () async {
    final repository = _repository(
      aggregation: _aggregation(
        signals: [
          ..._threeReadyMonths(),
          _signal(
            id: 'unfinished-august',
            localDate: '2026-08-18',
            content: 'This month is not complete yet',
          ),
        ],
        feedbackEvents: const [],
      ),
      now: DateTime(2026, 8, 20),
    );

    for (final selection in const ['2026-08', '2026-12']) {
      final report = await repository.fetchFullHistoryChange(
        selectedMonthKey: selection,
      );
      expect(report.months.last.monthKey, '2026-07');
      expect(report.periodEnd, '2026-07-31');
      expect(report.totalSignalCount, 21);
    }
  });

  test('domain and theme projections stay inside the nine focus domains',
      () async {
    final signals = <RecentSignalModel>[
      _signal(
        id: 'explicit-domain-wins',
        localDate: '2026-07-01',
        content: 'work meeting',
        rawPayloadJson: const {
          'focus_domain_id': 'relationship_connection',
          'theme': 'other',
        },
        sceneTags: const ['work'],
        intentTags: const ['qa_showcase'],
      ),
      _signal(
        id: 'meaning',
        localDate: '2026-07-02',
        content: 'neutral',
        sceneTags: const ['self_doubt'],
      ),
      _signal(
        id: 'boundary',
        localDate: '2026-07-03',
        content: 'neutral',
        sceneTags: const ['boundary'],
      ),
      _signal(
        id: 'creative',
        localDate: '2026-07-04',
        content: 'neutral',
        sceneTags: const ['writing'],
      ),
      _signal(
        id: 'food-sleep',
        localDate: '2026-07-05',
        content: 'neutral',
        sceneTags: const ['recovery'],
      ),
      _signal(
        id: 'living',
        localDate: '2026-07-06',
        content: 'neutral',
        sceneTags: const ['home'],
      ),
      _signal(
        id: 'hobby',
        localDate: '2026-07-07',
        content: 'neutral',
        sceneTags: const ['hobby'],
      ),
      _signal(
        id: 'emotional',
        localDate: '2026-07-08',
        content: 'neutral',
        sceneTags: const ['daily_friction'],
      ),
      _signal(
        id: 'communication',
        localDate: '2026-07-09',
        content: 'neutral',
        sceneTags: const ['communication'],
      ),
      _signal(
        id: 'unknown-fallback',
        localDate: '2026-07-10',
        content: 'neutral entry',
        rawPayloadJson: const {'theme_id': 'other'},
        intentTags: const ['qa_showcase'],
      ),
    ];
    final report = await _repository(
      aggregation: _aggregation(signals: signals, feedbackEvents: const []),
    ).fetchFullHistoryChange();
    final july = report.months.singleWhere(
      (month) => month.monthKey == '2026-07',
    );
    final allowed = FocusDomains.options.map((option) => option.id).toSet();

    expect(allowed, hasLength(9));
    expect(july.domainCounts.keys.toSet().difference(allowed), isEmpty);
    expect(july.themeCounts.keys.toSet().difference(allowed), isEmpty);
    expect(july.domainCounts, isNot(contains('other')));
    expect(july.themeCounts, isNot(contains('other')));
    expect(july.themeCounts, isNot(contains('qa_showcase')));
    expect(july.domainCounts['relationship_connection'], 2);
    expect(
      july.domainCounts.values.fold<int>(0, (sum, count) => sum + count),
      july.signalCount,
    );
    expect(
      july.themeCounts.values.fold<int>(0, (sum, count) => sum + count),
      july.signalCount,
    );
  });

  test('underlying Signal fields change focus, theme and energy chart series',
      () async {
    final before = await _repository(
      aggregation: _aggregation(
        signals: [
          _signal(
            id: 'mutable-chart-source',
            localDate: '2026-07-10',
            content: 'The original factual Signal row',
            energyState: 'draining',
            rawPayloadJson: const {
              'focus_domain_id': 'emotional_stability',
              'theme_id': 'food_sleep',
            },
          ),
        ],
        feedbackEvents: const [],
      ),
    ).fetchFullHistoryChange();
    final after = await _repository(
      aggregation: _aggregation(
        signals: [
          _signal(
            id: 'mutable-chart-source',
            localDate: '2026-07-10',
            content: 'The same row after a factual user correction',
            energyState: 'recovery',
            rawPayloadJson: const {
              'focus_domain_id': 'relationship_connection',
              'theme_id': 'creative_expression',
            },
          ),
        ],
        feedbackEvents: const [],
      ),
    ).fetchFullHistoryChange();

    final beforeFocus = before.months
        .map((month) => month.domainCount('emotional_stability'))
        .toList(growable: false);
    final afterFocus = after.months
        .map((month) => month.domainCount('emotional_stability'))
        .toList(growable: false);
    final beforeTheme = before.months
        .map((month) => month.themeCount('food_sleep'))
        .toList(growable: false);
    final afterTheme = after.months
        .map((month) => month.themeCount('food_sleep'))
        .toList(growable: false);
    final beforeEnergy = before.months
        .map((month) => month.energyCount('draining'))
        .toList(growable: false);
    final afterEnergy = after.months
        .map((month) => month.energyCount('draining'))
        .toList(growable: false);

    expect(beforeFocus.last, 1);
    expect(afterFocus.last, 0);
    expect(after.months.last.domainCount('relationship_connection'), 1);
    expect(beforeTheme.last, 1);
    expect(afterTheme.last, 0);
    expect(after.months.last.themeCount('creative_expression'), 1);
    expect(beforeEnergy.last, 1);
    expect(afterEnergy.last, 0);
    expect(after.months.last.energyCount('recovery'), 1);
    expect(afterFocus, isNot(beforeFocus));
    expect(afterTheme, isNot(beforeTheme));
    expect(afterEnergy, isNot(beforeEnergy));
    expect(after.sourceHash, isNot(before.sourceHash));
  });

  test('returns an empty, non-reversed range before the first month ends',
      () async {
    final signal = _signal(
      id: 'current-month-only',
      localDate: '2026-08-02',
      content: 'still in the first month',
    );
    final report = await _repository(
      aggregation: _aggregation(signals: [signal], feedbackEvents: const []),
      now: DateTime(2026, 8, 15),
      installationDate: DateTime(2026, 8, 1),
    ).fetchFullHistoryChange();

    expect(report.months, isEmpty);
    expect(report.hasData, isFalse);
    expect(report.periodStart, report.periodEnd);
    expect(report.periodEnd, '2026-07-31');
  });
}

JourneyProRepository _repository({
  required JourneyAggregationModel aggregation,
  List<Map<String, Object?>> observations = const [],
  DateTime? now,
  DateTime? installationDate,
}) {
  final database = LocalDatabase(dbPathOverride: 'journey_pro_test.db');
  final capture = _StubCaptureRepository(
    database,
    aggregation.sourceSignals,
  );
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
    nowLoader: () => now ?? DateTime(2026, 8, 1),
    installationDateLoader: () async =>
        installationDate ?? DateTime(2026, 1, 10),
  );
}

class _StubCaptureRepository extends LocalCaptureRepository {
  final List<RecentSignalModel> signals;

  _StubCaptureRepository(
    super.localDatabase,
    this.signals,
  );

  @override
  Future<List<RecentSignalModel>> listSignalCardsBetween({
    required String startDate,
    required String endDate,
    int limit = 2000,
  }) async {
    return signals
        .where((signal) {
          final localDate = signal.localDateKey();
          return localDate.compareTo(startDate) >= 0 &&
              localDate.compareTo(endDate) <= 0;
        })
        .take(limit)
        .toList(growable: false);
  }
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

RecentSignalModel _signal({
  required String id,
  required String localDate,
  required String content,
  String? energyState,
  Map<String, dynamic> rawPayloadJson = const {},
  List<String> sceneTags = const [],
  List<String> intentTags = const [],
}) {
  return RecentSignalModel(
    id: id,
    signalCardId: id,
    content: content,
    localDate: localDate,
    createdAt: DateTime.parse('${localDate}T09:00:00'),
    energyState: energyState,
    rawPayloadJson: rawPayloadJson,
    sceneTags: sceneTags,
    intentTags: intentTags,
    userConfirmation: 'confirmed',
    includedInSummary: true,
    includedInWeekly: true,
    includedInJourney: true,
  );
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
