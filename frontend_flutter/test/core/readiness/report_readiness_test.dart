import 'package:flutter_test/flutter_test.dart';

import 'package:ai_opportunity_radar/core/models/today_models.dart';
import 'package:ai_opportunity_radar/core/readiness/report_readiness.dart';

void main() {
  const evaluator = ReportReadinessEvaluator();

  test('Weekly requires 3 distinct eligible SignalCards in the bounded week',
      () {
    final twoSignals = [
      _signal('a', '2026-07-06'),
      _signal('b', '2026-07-06'),
    ];
    final notReady = evaluator.evaluate(
      twoSignals,
      ReportReadinessEvaluator.weeklyRule,
    );

    expect(notReady.isReady, isFalse);
    expect(notReady.remainingSignals, 1);
    expect(notReady.progress, closeTo(2 / 3, 0.001));

    final ready = evaluator.evaluate(
      [...twoSignals, _signal('c', '2026-07-07')],
      ReportReadinessEvaluator.weeklyRule,
    );
    expect(ready.isReady, isTrue);
    expect(ready.signalCount, 3);
  });

  test('Journey requires 7 signals across at least 3 local dates', () {
    final sixAcrossThreeDays = [
      _signal('a', '2026-07-01'),
      _signal('b', '2026-07-01'),
      _signal('c', '2026-07-02'),
      _signal('d', '2026-07-02'),
      _signal('e', '2026-07-03'),
      _signal('f', '2026-07-03'),
    ];

    expect(
      evaluator
          .evaluate(
            sixAcrossThreeDays,
            ReportReadinessEvaluator.journeyRule,
          )
          .isReady,
      isFalse,
    );

    final sevenOneDay = List.generate(
      7,
      (index) => _signal('one-day-$index', '2026-07-01'),
    );
    expect(
      evaluator
          .evaluate(
            sevenOneDay,
            ReportReadinessEvaluator.journeyRule,
          )
          .isReady,
      isFalse,
    );

    final ready = evaluator.evaluate(
      [...sixAcrossThreeDays, _signal('g', '2026-07-03')],
      ReportReadinessEvaluator.journeyRule,
    );
    expect(ready.isReady, isTrue);
    expect(ready.distinctDayCount, 3);
  });

  test('Duplicate SignalCard identities do not inflate report readiness', () {
    final result = evaluator.evaluate(
      [
        _signal('same', '2026-07-06'),
        _signal('same', '2026-07-07'),
        _signal('other', '2026-07-08'),
      ],
      ReportReadinessEvaluator.weeklyRule,
    );

    expect(result.signalCount, 2);
    expect(result.isReady, isFalse);
  });
}

RecentSignalModel _signal(String id, String localDate) {
  return RecentSignalModel(
    id: id,
    signalCardId: id,
    content: 'signal $id',
    localDate: localDate,
    userConfirmation: 'accurate',
  );
}
