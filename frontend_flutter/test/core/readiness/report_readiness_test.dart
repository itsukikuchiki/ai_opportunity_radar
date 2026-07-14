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

  test('Journey Pro requires 14 signals, 7 days, and 2 Monday-week buckets',
      () {
    final signals = <RecentSignalModel>[];
    for (var day = 0; day < 7; day += 1) {
      final date = DateTime(2026, 7, 6).add(Duration(days: day));
      final key = _dateKey(date);
      signals
        ..add(_signal('$day-a', key))
        ..add(_signal('$day-b', key));
    }

    final oneWeek = evaluator.evaluate(
      signals,
      ReportReadinessEvaluator.journeyProRule,
    );
    expect(oneWeek.signalCount, 14);
    expect(oneWeek.distinctDayCount, 7);
    expect(oneWeek.distinctWeekCount, 1);
    expect(oneWeek.isReady, isFalse);

    signals[signals.length - 1] = _signal('next-week', '2026-07-13');
    final ready = evaluator.evaluate(
      signals,
      ReportReadinessEvaluator.journeyProRule,
    );
    expect(ready.distinctWeekCount, 2);
    expect(ready.isReady, isTrue);
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

String _dateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
