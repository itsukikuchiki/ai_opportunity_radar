/// Canonical effect values for one completed small experiment attempt.
///
/// Legacy values remain readable through [normalizeSmallTryEffect], but new
/// writes use only these three user-facing choices.
abstract final class SmallTryEffect {
  static const helpful = 'helpful';
  static const somewhatHelpful = 'somewhat_helpful';
  static const noEffect = 'no_effect';

  static const values = {helpful, somewhatHelpful, noEffect};
}

abstract final class SmallTryDifficulty {
  static const easy = 'easy';
  static const okay = 'okay';
  static const difficult = 'difficult';

  static const values = {easy, okay, difficult};
}

/// Product boundary: a small experiment is an immediate behaviour that can be
/// completed in no more than ten minutes. Goals deliberately have no maximum
/// duration and use their own observation period.
abstract final class SmallTryPlanningLimits {
  static const maxDurationMinutes = 10;
}

abstract final class SmallTryRoundResult {
  static const worthKeeping = 'worth_keeping';
  static const adjustAndRetry = 'adjust_and_retry';
  static const noHelpObserved = 'no_help_observed';

  static const values = {worthKeeping, adjustAndRetry, noHelpObserved};
}

abstract final class EvaluationEffort {
  static const easy = 'easy';
  static const acceptable = 'acceptable';
  static const tooDifficult = 'too_difficult';

  static const values = {easy, acceptable, tooDifficult};
}

abstract final class SmallTryNextAdjustment {
  static const keep = 'keep';
  static const makeLighter = 'make_lighter';

  static const values = {keep, makeLighter};
}

class MicroActionReviewEventModel {
  final String id;
  final String microActionId;
  final String localUserId;
  final DateTime reviewedAt;
  final String localDate;
  final String result;
  final String effort;
  final String nextAdjustment;
  final String? note;
  final int completedAttemptsAtReview;
  final DateTime createdAt;

  const MicroActionReviewEventModel({
    required this.id,
    required this.microActionId,
    required this.localUserId,
    required this.reviewedAt,
    required this.localDate,
    required this.result,
    required this.effort,
    required this.nextAdjustment,
    this.note,
    required this.completedAttemptsAtReview,
    required this.createdAt,
  });

  Map<String, Object?> toDb() => {
        'id': id,
        'micro_action_id': microActionId,
        'local_user_id': localUserId,
        'reviewed_at': reviewedAt.toUtc().toIso8601String(),
        'local_date': localDate,
        'result': result,
        'effort': effort,
        'next_adjustment': nextAdjustment,
        'note': note,
        // Keep the legacy column populated so older backup readers remain
        // compatible. The v40 canonical value counts real attempts.
        'completed_days_at_review': completedAttemptsAtReview,
        'completed_attempts_at_review': completedAttemptsAtReview,
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  factory MicroActionReviewEventModel.fromDb(Map<String, Object?> row) {
    return MicroActionReviewEventModel(
      id: row['id']?.toString() ?? '',
      microActionId: row['micro_action_id']?.toString() ?? '',
      localUserId: row['local_user_id']?.toString() ?? 'local',
      reviewedAt: DateTime.tryParse(row['reviewed_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      localDate: row['local_date']?.toString() ?? '',
      result: row['result']?.toString() ?? '',
      effort: row['effort']?.toString() ?? '',
      nextAdjustment: row['next_adjustment']?.toString() ?? '',
      note: row['note']?.toString(),
      completedAttemptsAtReview: int.tryParse(
            row['completed_attempts_at_review']?.toString() ?? '',
          ) ??
          int.tryParse(row['completed_days_at_review']?.toString() ?? '') ??
          0,
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  /// Compatibility alias for UI code written before quick experiments became
  /// attempt-based. New code should use [completedAttemptsAtReview].
  int get completedDaysAtReview => completedAttemptsAtReview;
}

abstract final class GoalOutcomeResult {
  static const improved = 'improved';
  static const somewhatImproved = 'somewhat_improved';
  static const noChange = 'no_change';
  static const worse = 'worse';
  static const unclear = 'unclear';

  static const values = {
    improved,
    somewhatImproved,
    noChange,
    worse,
    unclear,
  };
}

abstract final class GoalReviewType {
  static const weekly = 'weekly';
  static const wholeRound = 'whole_round';

  static const values = {weekly, wholeRound};
}

class LifeExperimentOutcomeReviewModel {
  final String id;
  final String experimentId;
  final String localUserId;
  final DateTime reviewedAt;
  final String localDate;
  final String outcomeResult;
  final String reviewType;
  final String burden;
  final String? reviewNote;
  final int completedDaysAtReview;
  final int minimumObservationDays;
  final DateTime createdAt;

  const LifeExperimentOutcomeReviewModel({
    required this.id,
    required this.experimentId,
    required this.localUserId,
    required this.reviewedAt,
    required this.localDate,
    required this.outcomeResult,
    this.reviewType = GoalReviewType.wholeRound,
    required this.burden,
    this.reviewNote,
    required this.completedDaysAtReview,
    required this.minimumObservationDays,
    required this.createdAt,
  });

  factory LifeExperimentOutcomeReviewModel.fromLifecycleRow(
    Map<String, dynamic> row,
    Map<String, dynamic> payload,
  ) {
    final reviewedAt = DateTime.tryParse(row['event_date']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return LifeExperimentOutcomeReviewModel(
      id: row['id']?.toString() ?? '',
      experimentId: row['experiment_id']?.toString() ?? '',
      localUserId: row['local_user_id']?.toString() ?? 'local',
      reviewedAt: reviewedAt,
      localDate: row['local_date']?.toString() ?? '',
      outcomeResult: payload['outcome_result']?.toString() ?? '',
      reviewType: row['review_type']?.toString().trim().isNotEmpty == true
          ? row['review_type']!.toString()
          : payload['review_type']?.toString() ?? GoalReviewType.wholeRound,
      burden: payload['burden']?.toString() ?? '',
      reviewNote: payload['review_note']?.toString(),
      completedDaysAtReview:
          int.tryParse('${payload['completed_days_at_review'] ?? 0}') ?? 0,
      minimumObservationDays:
          int.tryParse('${payload['minimum_observation_days'] ?? 3}') ?? 3,
      createdAt:
          DateTime.tryParse(row['created_at']?.toString() ?? '') ?? reviewedAt,
    );
  }
}

String normalizeSmallTryEffect(String? raw) {
  final value = raw?.trim().toLowerCase() ?? '';
  if (SmallTryEffect.values.contains(value)) return value;
  if (const {'somewhat', 'partial', 'a_little', '有一点'}.contains(value)) {
    return SmallTryEffect.somewhatHelpful;
  }
  if (const {'none', 'not_helpful', 'no_help', '没感觉'}.contains(value)) {
    return SmallTryEffect.noEffect;
  }
  if (const {'effective', 'helped', '有帮助'}.contains(value)) {
    return SmallTryEffect.helpful;
  }
  // Do not rewrite old ambiguous values into a positive/negative judgement.
  return value;
}

String normalizeSmallTryDifficulty(String? raw) {
  final value = raw?.trim().toLowerCase() ?? '';
  if (SmallTryDifficulty.values.contains(value)) return value;
  if (const {'light', 'very_light', '轻松'}.contains(value)) {
    return SmallTryDifficulty.easy;
  }
  if (const {'normal', 'acceptable', '还好'}.contains(value)) {
    return SmallTryDifficulty.okay;
  }
  if (const {'hard', 'too_hard', 'too_difficult', '偏费力'}.contains(value)) {
    return SmallTryDifficulty.difficult;
  }
  return value;
}
