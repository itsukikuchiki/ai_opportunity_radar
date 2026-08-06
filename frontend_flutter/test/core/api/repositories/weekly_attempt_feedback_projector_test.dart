import 'package:flutter_test/flutter_test.dart';
import 'package:ai_opportunity_radar/core/api/repositories/weekly_attempt_feedback_projector.dart';
import 'package:ai_opportunity_radar/core/models/experiment_evaluation_models.dart';
import 'package:ai_opportunity_radar/core/models/feedback_event_models.dart';

void main() {
  test('uses the complete feedback set and keeps same-day attempts separate',
      () {
    final events = List.generate(13, (index) {
      return _event(
        id: 'micro-$index',
        sourceType: 'micro_action_feedback',
        subjectType: 'micro_action',
        subjectId: 'micro-1',
        localDate: '2026-07-27',
        status: index == 12 ? 'not_completed' : 'completed',
        effect: index.isEven ? SmallTryEffect.helpful : null,
        metadata: {
          if (index != 12)
            'difficulty': index.isEven
                ? SmallTryDifficulty.easy
                : SmallTryDifficulty.okay,
        },
        createdAt: DateTime.utc(2026, 7, 27, 8, index),
      );
    });

    final summary = WeeklyAttemptFeedbackProjector.build(events).single;

    expect(summary.recordedCount, 13);
    expect(summary.recordedDayCount, 1);
    expect(summary.completedCount, 12);
    expect(summary.notCompletedCount, 1);
    expect(summary.helpfulCount, 6);
    expect(summary.easyCount, 6);
    expect(summary.okayCount, 6);
  });

  test('does not treat completion as evidence that an attempt was helpful', () {
    final summary = WeeklyAttemptFeedbackProjector.build([
      _event(
        id: 'completed-without-effect',
        sourceType: 'micro_action_feedback',
        subjectType: 'micro_action',
        subjectId: 'micro-1',
        localDate: '2026-07-27',
        status: 'completed',
        createdAt: DateTime.utc(2026, 7, 27, 9),
      ),
    ]).single;

    expect(summary.completedCount, 1);
    expect(summary.helpfulCount, 0);
    expect(summary.somewhatHelpfulCount, 0);
    expect(summary.noEffectCount, 0);
  });

  test(
      'goal uses the last daily feedback and keeps weekly review outside daily completion',
      () {
    final events = [
      _event(
        id: 'day-one-first',
        sourceType: 'life_experiment_feedback',
        subjectType: 'life_experiment',
        subjectId: 'goal-1',
        localDate: '2026-07-27',
        status: 'completed',
        createdAt: DateTime.utc(2026, 7, 27, 8),
      ),
      _event(
        id: 'day-one-last',
        sourceType: 'life_experiment_feedback',
        subjectType: 'life_experiment',
        subjectId: 'goal-1',
        localDate: '2026-07-27',
        status: 'not_completed',
        createdAt: DateTime.utc(2026, 7, 27, 10),
      ),
      _event(
        id: 'day-two',
        sourceType: 'life_experiment_feedback',
        subjectType: 'life_experiment',
        subjectId: 'goal-1',
        localDate: '2026-07-28',
        status: 'completed',
        createdAt: DateTime.utc(2026, 7, 28, 8),
      ),
      _event(
        id: 'weekly-review',
        sourceType: 'life_experiment_outcome_review',
        subjectType: 'life_experiment',
        subjectId: 'goal-1',
        localDate: '2026-07-28',
        status: 'outcome_reviewed',
        effect: GoalOutcomeResult.somewhatImproved,
        metadata: const {
          'review_type': GoalReviewType.weekly,
          'outcome_result': GoalOutcomeResult.somewhatImproved,
          'burden': EvaluationEffort.acceptable,
          'completed_days_at_review': 2,
          'minimum_observation_days': 3,
        },
        createdAt: DateTime.utc(2026, 7, 28, 11),
      ),
      _event(
        id: 'whole-round-review',
        sourceType: 'life_experiment_outcome_review',
        subjectType: 'life_experiment',
        subjectId: 'goal-1',
        localDate: '2026-07-28',
        status: 'outcome_reviewed',
        effect: GoalOutcomeResult.improved,
        metadata: const {
          'review_type': GoalReviewType.wholeRound,
          'outcome_result': GoalOutcomeResult.improved,
          'burden': EvaluationEffort.easy,
        },
        createdAt: DateTime.utc(2026, 7, 28, 12),
      ),
    ];

    final summary = WeeklyAttemptFeedbackProjector.build(events).single;

    expect(summary.recordedCount, 2);
    expect(summary.recordedDayCount, 2);
    expect(summary.completedCount, 1);
    expect(summary.notCompletedCount, 1);
    expect(summary.latestWeeklyOutcome, GoalOutcomeResult.somewhatImproved);
    expect(summary.latestWeeklyBurden, EvaluationEffort.acceptable);
    expect(summary.completedDaysAtWeeklyReview, 2);
    expect(summary.minimumObservationDays, 3);
  });

  test('round review does not increase small experiment attempt totals', () {
    final summary = WeeklyAttemptFeedbackProjector.build([
      _event(
        id: 'micro-feedback',
        sourceType: 'micro_action_feedback',
        subjectType: 'micro_action',
        subjectId: 'micro-1',
        localDate: '2026-07-27',
        status: 'completed',
        effect: SmallTryEffect.helpful,
        metadata: const {'difficulty': SmallTryDifficulty.easy},
        createdAt: DateTime.utc(2026, 7, 27, 8),
      ),
      _event(
        id: 'micro-round-review',
        sourceType: 'micro_action_round_review',
        subjectType: 'micro_action',
        subjectId: 'micro-1',
        localDate: '2026-07-28',
        status: SmallTryRoundResult.worthKeeping,
        effect: SmallTryRoundResult.worthKeeping,
        metadata: const {
          'result': SmallTryRoundResult.worthKeeping,
          'effort': EvaluationEffort.easy,
        },
        createdAt: DateTime.utc(2026, 7, 28, 9),
      ),
    ]).single;

    expect(summary.recordedCount, 1);
    expect(summary.completedCount, 1);
    expect(summary.latestRoundResult, SmallTryRoundResult.worthKeeping);
    expect(summary.latestRoundEffort, EvaluationEffort.easy);
  });
}

FeedbackEventModel _event({
  required String id,
  required String sourceType,
  required String subjectType,
  required String subjectId,
  required String localDate,
  required String status,
  String? effect,
  Map<String, dynamic> metadata = const {},
  DateTime? createdAt,
}) {
  return FeedbackEventModel(
    id: id,
    sourceType: sourceType,
    sourceId: id,
    subjectType: subjectType,
    subjectId: subjectId,
    localUserId: 'local',
    localDate: localDate,
    occurredAt: createdAt,
    status: status,
    effect: effect,
    metadata: metadata,
    createdAt: createdAt,
  );
}
