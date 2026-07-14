import '../readiness/report_readiness.dart';

/// A verifiable, local-data projection for the Journey Pro L3 surface.
///
/// This model deliberately contains counts and user-owned SignalCard excerpts
/// only. Interpretive copy belongs to an actually generated Journey summary;
/// the Pro page must never manufacture one from placeholder text.
class JourneyProReportModel {
  final ReportReadiness readiness;
  final String periodStart;
  final String periodEnd;
  final JourneyProWeekStats currentWeek;
  final JourneyProWeekStats previousWeek;
  final List<JourneyProEvidenceModel> evidence;

  const JourneyProReportModel({
    required this.readiness,
    required this.periodStart,
    required this.periodEnd,
    required this.currentWeek,
    required this.previousWeek,
    required this.evidence,
  });

  bool get isReady => readiness.isReady;
  int get weekSignalDelta => currentWeek.signalCount - previousWeek.signalCount;
  int get weekActiveDayDelta =>
      currentWeek.activeDayCount - previousWeek.activeDayCount;
}

class JourneyProWeekStats {
  final String weekStart;
  final String weekEnd;
  final int signalCount;
  final int activeDayCount;

  const JourneyProWeekStats({
    required this.weekStart,
    required this.weekEnd,
    required this.signalCount,
    required this.activeDayCount,
  });
}

class JourneyProEvidenceModel {
  final String signalId;
  final String content;
  final String localDate;
  final String sourceType;

  const JourneyProEvidenceModel({
    required this.signalId,
    required this.content,
    required this.localDate,
    required this.sourceType,
  });
}
