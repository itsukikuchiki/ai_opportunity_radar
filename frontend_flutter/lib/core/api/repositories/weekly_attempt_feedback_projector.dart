import '../../models/experiment_evaluation_models.dart';
import '../../models/feedback_event_models.dart';
import '../../models/weekly_models.dart';

/// Builds the fact-only attempt conclusions shown in Weekly.
///
/// This uses the complete date-bounded feedback event list. It must not read
/// the shortened `_feedback_event_summary.events` list, which exists only to
/// select a representative illustration.
abstract final class WeeklyAttemptFeedbackProjector {
  static List<WeeklyAttemptFeedbackSummaryModel> build(
    Iterable<FeedbackEventModel> events,
  ) {
    final buckets = <String, _AttemptFeedbackBucket>{};
    final latestGoalDailyEvents = <String, Map<String, FeedbackEventModel>>{};

    _AttemptFeedbackBucket bucketFor(FeedbackEventModel event) {
      final key = '${event.subjectType}:${event.subjectId}';
      return buckets.putIfAbsent(
        key,
        () => _AttemptFeedbackBucket(
          subjectType: event.subjectType,
          subjectId: event.subjectId,
        ),
      );
    }

    for (final event in events) {
      if (event.subjectId.trim().isEmpty) continue;
      switch (event.sourceType) {
        case 'micro_action_feedback':
          final bucket = bucketFor(event);
          bucket.recordMicroActionFeedback(event);
        case 'micro_action_round_review':
          final bucket = bucketFor(event);
          bucket.recordMicroActionRoundReview(event);
        case 'life_experiment_feedback':
          final byDate =
              latestGoalDailyEvents.putIfAbsent(event.subjectId, () => {});
          final existing = byDate[event.localDate];
          if (existing == null || _isLater(event, existing)) {
            byDate[event.localDate] = event;
          }
        case 'life_experiment_outcome_review':
          final bucket = bucketFor(event);
          bucket.recordGoalOutcomeReview(event);
      }
    }

    for (final entry in latestGoalDailyEvents.entries) {
      final bucket = buckets.putIfAbsent(
        'life_experiment:${entry.key}',
        () => _AttemptFeedbackBucket(
          subjectType: 'life_experiment',
          subjectId: entry.key,
        ),
      );
      final dailyEvents = entry.value.values.toList()..sort(_compareEvents);
      for (final event in dailyEvents) {
        bucket.recordGoalDailyFeedback(event);
      }
    }

    final summaries = buckets.values
        .map((bucket) => bucket.toModel())
        .where(
          (summary) =>
              summary.recordedCount > 0 ||
              summary.latestRoundResult != null ||
              summary.latestWeeklyOutcome != null,
        )
        .toList()
      ..sort((a, b) {
        final typeCompare = a.subjectType.compareTo(b.subjectType);
        if (typeCompare != 0) return typeCompare;
        return a.subjectId.compareTo(b.subjectId);
      });
    return summaries;
  }

  static bool _isLater(
    FeedbackEventModel candidate,
    FeedbackEventModel current,
  ) {
    return _compareEvents(candidate, current) > 0;
  }

  static int _compareEvents(
    FeedbackEventModel left,
    FeedbackEventModel right,
  ) {
    final leftTime = left.createdAt ??
        left.occurredAt ??
        DateTime.tryParse(left.localDate) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final rightTime = right.createdAt ??
        right.occurredAt ??
        DateTime.tryParse(right.localDate) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final timeCompare = leftTime.compareTo(rightTime);
    if (timeCompare != 0) return timeCompare;
    return left.id.compareTo(right.id);
  }
}

class _AttemptFeedbackBucket {
  final String subjectType;
  final String subjectId;
  int recordedCount = 0;
  final Set<String> recordedDates = {};
  int completedCount = 0;
  int notCompletedCount = 0;
  int helpfulCount = 0;
  int somewhatHelpfulCount = 0;
  int noEffectCount = 0;
  int easyCount = 0;
  int okayCount = 0;
  int difficultCount = 0;
  FeedbackEventModel? latestRoundReview;
  FeedbackEventModel? latestWeeklyGoalReview;

  _AttemptFeedbackBucket({
    required this.subjectType,
    required this.subjectId,
  });

  void recordMicroActionFeedback(FeedbackEventModel event) {
    recordedCount += 1;
    if (event.localDate.trim().isNotEmpty) {
      recordedDates.add(event.localDate);
    }
    final completed = _isCompletedStatus(event.status);
    if (completed) {
      completedCount += 1;
      _recordEffect(event.effect ?? event.metadata['effect']?.toString());
      _recordDifficulty(event.metadata['difficulty']?.toString());
    } else if (_isNotCompletedStatus(event.status)) {
      notCompletedCount += 1;
    }
  }

  void recordMicroActionRoundReview(FeedbackEventModel event) {
    final current = latestRoundReview;
    if (current == null ||
        WeeklyAttemptFeedbackProjector._isLater(event, current)) {
      latestRoundReview = event;
    }
  }

  void recordGoalDailyFeedback(FeedbackEventModel event) {
    recordedCount += 1;
    if (event.localDate.trim().isNotEmpty) {
      recordedDates.add(event.localDate);
    }
    if (_isCompletedStatus(event.status)) {
      completedCount += 1;
    } else if (_isNotCompletedStatus(event.status)) {
      notCompletedCount += 1;
    }
  }

  void recordGoalOutcomeReview(FeedbackEventModel event) {
    final reviewType = event.metadata['review_type']?.toString().trim() ?? '';
    if (reviewType != GoalReviewType.weekly) return;
    final current = latestWeeklyGoalReview;
    if (current == null ||
        WeeklyAttemptFeedbackProjector._isLater(event, current)) {
      latestWeeklyGoalReview = event;
    }
  }

  void _recordEffect(String? raw) {
    switch (normalizeSmallTryEffect(raw)) {
      case SmallTryEffect.helpful:
        helpfulCount += 1;
      case SmallTryEffect.somewhatHelpful:
        somewhatHelpfulCount += 1;
      case SmallTryEffect.noEffect:
        noEffectCount += 1;
    }
  }

  void _recordDifficulty(String? raw) {
    switch (normalizeSmallTryDifficulty(raw)) {
      case SmallTryDifficulty.easy:
        easyCount += 1;
      case SmallTryDifficulty.okay:
        okayCount += 1;
      case SmallTryDifficulty.difficult:
        difficultCount += 1;
    }
  }

  WeeklyAttemptFeedbackSummaryModel toModel() {
    final roundReview = latestRoundReview;
    final weeklyGoalReview = latestWeeklyGoalReview;
    return WeeklyAttemptFeedbackSummaryModel(
      subjectType: subjectType,
      subjectId: subjectId,
      recordedCount: recordedCount,
      recordedDayCount: recordedDates.length,
      completedCount: completedCount,
      notCompletedCount: notCompletedCount,
      helpfulCount: helpfulCount,
      somewhatHelpfulCount: somewhatHelpfulCount,
      noEffectCount: noEffectCount,
      easyCount: easyCount,
      okayCount: okayCount,
      difficultCount: difficultCount,
      latestRoundResult: _nonEmpty(
        roundReview?.metadata['result']?.toString() ?? roundReview?.effect,
      ),
      latestRoundEffort: _nonEmpty(
        roundReview?.metadata['effort']?.toString(),
      ),
      latestWeeklyOutcome: _nonEmpty(
        weeklyGoalReview?.metadata['outcome_result']?.toString() ??
            weeklyGoalReview?.effect,
      ),
      latestWeeklyBurden: _nonEmpty(
        weeklyGoalReview?.metadata['burden']?.toString(),
      ),
      completedDaysAtWeeklyReview: _intValue(
        weeklyGoalReview?.metadata['completed_days_at_review'],
      ),
      minimumObservationDays: _intValue(
        weeklyGoalReview?.metadata['minimum_observation_days'],
      ),
    );
  }

  bool _isCompletedStatus(String? raw) {
    final value = raw?.trim().toLowerCase() ?? '';
    return const {
      'completed',
      'done',
      'happened',
      'occurred',
      'yes',
      'true',
      '1',
    }.contains(value);
  }

  bool _isNotCompletedStatus(String? raw) {
    final value = raw?.trim().toLowerCase() ?? '';
    return const {
      'not_completed',
      'not_done',
      'not_happened',
      'missed',
      'skipped',
      'not_today',
      'no',
      'false',
      '0',
    }.contains(value);
  }

  String? _nonEmpty(String? raw) {
    final value = raw?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  int? _intValue(Object? raw) {
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '');
  }
}
