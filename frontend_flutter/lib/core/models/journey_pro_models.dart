/// A factual three-calendar-month projection for the Journey Pro surface.
///
/// The window contains the selected local calendar month and the two preceding
/// local calendar months. Raw Signal content, source drill-downs, experiments,
/// goals, and AI chat deliberately do not belong to this projection.
class JourneyProReportModel {
  static const minimumSignalsPerMonth = 7;
  static const minimumActiveDaysPerMonth = 3;
  static const minimumComparableMonths = 2;

  final String selectedMonthKey;
  final String periodStart;
  final String periodEnd;
  final String sourceHash;
  final List<JourneyProMonthChangeModel> months;
  final JourneyProContextCoverageModel contextCoverage;

  const JourneyProReportModel({
    required this.selectedMonthKey,
    required this.periodStart,
    required this.periodEnd,
    required this.sourceHash,
    required this.months,
    required this.contextCoverage,
  });

  bool get hasData => months.any((month) => month.signalCount > 0);

  int get totalSignalCount => months.fold(
        0,
        (total, month) => total + month.signalCount,
      );

  int get readyMonthCount =>
      months.where((month) => month.meetsComparisonMinimum).length;

  bool get canShowChange => readyMonthCount >= minimumComparableMonths;

  int get remainingComparableMonths =>
      (minimumComparableMonths - readyMonthCount).clamp(
        0,
        minimumComparableMonths,
      );

  int get latestSignalDelta {
    if (months.length < 2) return 0;
    return months.last.signalCount - months[months.length - 2].signalCount;
  }

  int get latestActiveDayDelta {
    if (months.length < 2) return 0;
    return months.last.activeDayCount -
        months[months.length - 2].activeDayCount;
  }
}

/// Privacy-safe coverage of non-Signal context used by the integrated summary.
///
/// These counts describe source breadth since first app use. They never count
/// toward report readiness and never expose the underlying private text.
class JourneyProContextCoverageModel {
  final int feedbackCount;
  final int reviewCount;
  final int experimentContextCount;
  final int observationCount;

  const JourneyProContextCoverageModel({
    required this.feedbackCount,
    required this.reviewCount,
    required this.experimentContextCount,
    required this.observationCount,
  });

  int get totalContextCount =>
      feedbackCount + reviewCount + experimentContextCount + observationCount;

  int get coveredKindCount => [
        feedbackCount,
        reviewCount,
        experimentContextCount,
        observationCount,
      ].where((count) => count > 0).length;

  bool get hasContext => totalContextCount > 0;

  bool get hasBroadContext => coveredKindCount >= 3 && totalContextCount >= 6;
}

/// One user-local calendar month's reproducible change metrics.
///
/// Signal identities and active dates are deduplicated before these counts are
/// created. The current month is intentionally month-to-date.
class JourneyProMonthChangeModel {
  final String monthKey;
  final String periodStart;
  final String periodEnd;
  final int signalCount;
  final int activeDayCount;
  final Map<String, int> energyStateCounts;
  final Map<String, int> domainCounts;

  const JourneyProMonthChangeModel({
    required this.monthKey,
    required this.periodStart,
    required this.periodEnd,
    required this.signalCount,
    required this.activeDayCount,
    required this.energyStateCounts,
    required this.domainCounts,
  });

  int energyCount(String state) => energyStateCounts[state] ?? 0;

  int domainCount(String domainId) => domainCounts[domainId] ?? 0;

  bool get meetsComparisonMinimum =>
      signalCount >= JourneyProReportModel.minimumSignalsPerMonth &&
      activeDayCount >= JourneyProReportModel.minimumActiveDaysPerMonth;

  int get remainingSignals =>
      (JourneyProReportModel.minimumSignalsPerMonth - signalCount).clamp(
        0,
        JourneyProReportModel.minimumSignalsPerMonth,
      );

  int get remainingActiveDays =>
      (JourneyProReportModel.minimumActiveDaysPerMonth - activeDayCount).clamp(
        0,
        JourneyProReportModel.minimumActiveDaysPerMonth,
      );
}
