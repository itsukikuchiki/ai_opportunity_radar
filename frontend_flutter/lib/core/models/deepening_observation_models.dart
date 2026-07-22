/// A read-only follow-up question proposed by deep analysis.  It is not a
/// Signal, task, candidate, or notification rule.  Only an explicit adoption
/// creates an observation plan for the following local week.
class DeepeningObservationProposal {
  final String sourceWeekStart;
  final String sourceWeekEnd;
  final String question;
  final List<String> whatToWatch;
  final List<String> sourceSignalCardIds;
  final String sourceHash;

  const DeepeningObservationProposal({
    required this.sourceWeekStart,
    required this.sourceWeekEnd,
    required this.question,
    required this.whatToWatch,
    required this.sourceSignalCardIds,
    required this.sourceHash,
  });
}

enum DeepeningObservationPlanStatus { planned, resolved }

enum DeepeningObservationResultStatus { supported, mixed, notEnoughData }

class DeepeningObservationPlan {
  final String id;
  final String localUserId;
  final String sourceWeekStart;
  final String sourceWeekEnd;
  final String targetWeekStart;
  final String question;
  final List<String> whatToWatch;
  final List<String> sourceSignalCardIds;
  final String sourceHash;
  final DeepeningObservationPlanStatus status;
  final DeepeningObservationResultStatus? resultStatus;
  final String? resultSummary;
  final List<String> resultSignalCardIds;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  const DeepeningObservationPlan({
    required this.id,
    required this.localUserId,
    required this.sourceWeekStart,
    required this.sourceWeekEnd,
    required this.targetWeekStart,
    required this.question,
    required this.whatToWatch,
    required this.sourceSignalCardIds,
    required this.sourceHash,
    required this.status,
    this.resultStatus,
    this.resultSummary,
    this.resultSignalCardIds = const [],
    required this.createdAt,
    this.resolvedAt,
  });
}
