import '../models/today_models.dart';

/// User-facing report layers have different evidence requirements.
///
/// The evaluator only receives SignalCards that have already passed the
/// shared eligibility policy and that are already bounded to the report's
/// period. It never treats feedback, observations, or AI output as another
/// SignalCard.
enum ReportSurface {
  weekly,
  journey,
}

class ReportReadinessRule {
  final ReportSurface surface;
  final int minimumSignals;
  final int minimumDistinctDays;
  final int minimumDistinctWeeks;
  final int windowDays;

  const ReportReadinessRule({
    required this.surface,
    required this.minimumSignals,
    required this.minimumDistinctDays,
    required this.minimumDistinctWeeks,
    required this.windowDays,
  });
}

class ReportReadiness {
  final ReportReadinessRule rule;
  final int signalCount;
  final int distinctDayCount;
  final int distinctWeekCount;

  const ReportReadiness({
    required this.rule,
    required this.signalCount,
    required this.distinctDayCount,
    required this.distinctWeekCount,
  });

  bool get isReady =>
      signalCount >= rule.minimumSignals &&
      distinctDayCount >= rule.minimumDistinctDays &&
      distinctWeekCount >= rule.minimumDistinctWeeks;

  int get remainingSignals =>
      (rule.minimumSignals - signalCount).clamp(0, rule.minimumSignals);

  int get remainingDays => (rule.minimumDistinctDays - distinctDayCount)
      .clamp(0, rule.minimumDistinctDays);

  int get remainingWeeks => (rule.minimumDistinctWeeks - distinctWeekCount)
      .clamp(0, rule.minimumDistinctWeeks);

  double get progress {
    final signalProgress = (signalCount / rule.minimumSignals).clamp(0.0, 1.0);
    final dayProgress =
        (distinctDayCount / rule.minimumDistinctDays).clamp(0.0, 1.0);
    final weekProgress =
        (distinctWeekCount / rule.minimumDistinctWeeks).clamp(0.0, 1.0);
    // Every dimension is a hard requirement. Using the least-complete one is
    // honest; averaging would make 1/3 Weekly signals look almost complete
    // merely because its one-day and one-week requirements already pass.
    var result = signalProgress;
    if (dayProgress < result) result = dayProgress;
    if (weekProgress < result) result = weekProgress;
    return result;
  }

  Map<String, dynamic> toMap() {
    return {
      'surface': rule.surface.name,
      'minimum_signals': rule.minimumSignals,
      'minimum_distinct_days': rule.minimumDistinctDays,
      'minimum_distinct_weeks': rule.minimumDistinctWeeks,
      'window_days': rule.windowDays,
      'signal_count': signalCount,
      'distinct_day_count': distinctDayCount,
      'distinct_week_count': distinctWeekCount,
      'is_ready': isReady,
    };
  }

  factory ReportReadiness.fromMap(
    Map<String, dynamic>? map, {
    required ReportReadinessRule fallbackRule,
  }) {
    if (map == null) return ReportReadiness.empty(fallbackRule);
    return ReportReadiness(
      rule: fallbackRule,
      signalCount: (map['signal_count'] as num?)?.toInt() ?? 0,
      distinctDayCount: (map['distinct_day_count'] as num?)?.toInt() ?? 0,
      distinctWeekCount: (map['distinct_week_count'] as num?)?.toInt() ?? 0,
    );
  }

  static ReportReadiness empty(ReportReadinessRule rule) {
    return ReportReadiness(
      rule: rule,
      signalCount: 0,
      distinctDayCount: 0,
      distinctWeekCount: 0,
    );
  }
}

class ReportReadinessEvaluator {
  /// Weekly is a user-local Monday-Sunday period.
  static const weeklyRule = ReportReadinessRule(
    surface: ReportSurface.weekly,
    minimumSignals: 3,
    minimumDistinctDays: 1,
    minimumDistinctWeeks: 1,
    windowDays: 7,
  );

  /// Free Journey shows a bounded monthly synthesis only after repeated input,
  /// rather than drawing a life pattern from one moment.
  static const journeyRule = ReportReadinessRule(
    surface: ReportSurface.journey,
    minimumSignals: 7,
    minimumDistinctDays: 3,
    minimumDistinctWeeks: 1,
    windowDays: 31,
  );

  const ReportReadinessEvaluator();

  ReportReadiness evaluate(
    Iterable<RecentSignalModel> signals,
    ReportReadinessRule rule,
  ) {
    final ids = <String>{};
    final days = <String>{};
    final weeks = <String>{};

    for (final signal in signals) {
      final signalCardId = signal.signalCardId?.trim() ?? '';
      final id = signalCardId.isEmpty ? signal.id?.trim() ?? '' : signalCardId;
      final day = _parseLocalDay(signal.localDateKey());
      if (id.isEmpty || day == null || !ids.add(id)) continue;
      days.add(_dateKey(day));
      weeks.add(_dateKey(_mondayOf(day)));
    }

    return ReportReadiness(
      rule: rule,
      signalCount: ids.length,
      distinctDayCount: days.length,
      distinctWeekCount: weeks.length,
    );
  }

  DateTime? _parseLocalDay(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    final local = parsed.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  DateTime _mondayOf(DateTime date) {
    return date.subtract(Duration(days: date.weekday - DateTime.monday));
  }

  String _dateKey(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
