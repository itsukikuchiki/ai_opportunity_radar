import 'dart:convert';

import 'phase3_plus_models.dart';
import 'weekly_models.dart';

class FeedbackEventModel {
  final String id;
  final String sourceType;
  final String sourceId;
  final String subjectType;
  final String subjectId;
  final String localUserId;
  final String localDate;
  final DateTime? occurredAt;
  final String status;
  final String? effect;
  final String? note;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;

  const FeedbackEventModel({
    required this.id,
    required this.sourceType,
    required this.sourceId,
    required this.subjectType,
    required this.subjectId,
    required this.localUserId,
    required this.localDate,
    required this.status,
    this.occurredAt,
    this.effect,
    this.note,
    this.metadata = const {},
    this.createdAt,
  });

  factory FeedbackEventModel.fromMicroActionFeedback(
    MicroActionFeedbackModel feedback, {
    required String localUserId,
  }) {
    return FeedbackEventModel(
      id: 'micro_action_feedback:${feedback.id}',
      sourceType: 'micro_action_feedback',
      sourceId: feedback.id,
      subjectType: 'micro_action',
      subjectId: feedback.microActionId,
      localUserId: localUserId,
      localDate: feedback.localDate,
      occurredAt: _dateFromKey(feedback.localDate),
      status: feedback.happened,
      effect: feedback.effect,
      note: feedback.userNote,
      metadata: {
        'happened': feedback.happened,
        'effect': feedback.effect,
        'difficulty': feedback.difficulty,
        'next_adjustment': feedback.nextAdjustment,
        if (feedback.durationMinutes != null)
          'duration_minutes': feedback.durationMinutes,
        if (feedback.userNote != null) 'user_note': feedback.userNote,
      },
      createdAt: feedback.createdAt,
    );
  }

  factory FeedbackEventModel.fromLifeExperimentFeedback(
    LifeExperimentFeedbackModel feedback,
  ) {
    return FeedbackEventModel(
      id: 'life_experiment_feedback:${feedback.id}',
      sourceType: 'life_experiment_feedback',
      sourceId: feedback.id,
      subjectType: 'life_experiment',
      subjectId: feedback.experimentId,
      localUserId: feedback.localUserId,
      localDate: feedback.localDate,
      occurredAt: feedback.feedbackDate,
      status: feedback.completionStatus,
      effect: feedback.helpfulnessScore?.toString(),
      note: feedback.feedbackText,
      metadata: {
        'completion_status': feedback.completionStatus,
        if (feedback.helpfulnessScore != null)
          'helpfulness_score': feedback.helpfulnessScore,
        if (feedback.feedbackText != null)
          'feedback_text': feedback.feedbackText,
        if (feedback.conditionTags.isNotEmpty)
          'condition_tags': feedback.conditionTags,
        if (feedback.durationMinutes != null)
          'duration_minutes': feedback.durationMinutes,
        if (feedback.timeSlot != null) 'time_slot': feedback.timeSlot,
        if (feedback.patternId != null) 'pattern_id': feedback.patternId,
        if (feedback.feedbackPatternId != null)
          'feedback_pattern_id': feedback.feedbackPatternId,
        if (feedback.focusAreaId != null) 'focus_area_id': feedback.focusAreaId,
      },
      createdAt: feedback.createdAt,
    );
  }

  factory FeedbackEventModel.fromMicroActionRoundReviewRow(
    Map<String, Object?> row,
  ) {
    final localDate = row['local_date']?.toString() ?? '';
    final sourceId = row['id']?.toString() ?? '';
    return FeedbackEventModel(
      id: 'micro_action_round_review:$sourceId',
      sourceType: 'micro_action_round_review',
      sourceId: sourceId,
      subjectType: 'micro_action',
      subjectId: row['micro_action_id']?.toString() ?? '',
      localUserId: row['local_user_id']?.toString() ?? 'local',
      localDate: localDate,
      occurredAt:
          _dateMetaFromRaw(row['reviewed_at']) ?? _dateFromKey(localDate),
      status: row['result']?.toString() ?? '',
      effect: row['result']?.toString(),
      note: row['note']?.toString(),
      metadata: {
        'result': row['result'],
        'effort': row['effort'],
        'next_adjustment': row['next_adjustment'],
        'completed_attempts_at_review': row['completed_attempts_at_review'] ??
            row['completed_days_at_review'],
      },
      createdAt: _dateMetaFromRaw(row['created_at']),
    );
  }

  factory FeedbackEventModel.fromLifeExperimentOutcomeReviewRow(
    Map<String, Object?> row,
  ) {
    final localDate = row['local_date']?.toString() ?? '';
    final sourceId = row['id']?.toString() ?? '';
    final payload = _decodeJsonMap(row['payload_json']);
    return FeedbackEventModel(
      id: 'life_experiment_outcome_review:$sourceId',
      sourceType: 'life_experiment_outcome_review',
      sourceId: sourceId,
      subjectType: 'life_experiment',
      subjectId: row['experiment_id']?.toString() ?? '',
      localUserId: row['local_user_id']?.toString() ?? 'local',
      localDate: localDate,
      occurredAt:
          _dateMetaFromRaw(row['event_date']) ?? _dateFromKey(localDate),
      status: 'outcome_reviewed',
      effect: payload['outcome_result']?.toString(),
      note: payload['review_note']?.toString(),
      metadata: {
        'outcome_result': payload['outcome_result'],
        'review_type': row['review_type'] ?? payload['review_type'],
        'burden': payload['burden'],
        'completed_days_at_review': payload['completed_days_at_review'],
        'minimum_observation_days': payload['minimum_observation_days'],
      },
      createdAt: _dateMetaFromRaw(row['created_at']),
    );
  }

  factory FeedbackEventModel.fromScheduleFeedback(
    ScheduleSignalModel schedule, {
    required String localUserId,
  }) {
    final localDate = (schedule.localDate?.trim().isNotEmpty ?? false)
        ? schedule.localDate!
        : schedule.anchorDate;
    return FeedbackEventModel(
      id: 'schedule_feedback:${schedule.id}',
      sourceType: 'schedule_feedback',
      sourceId: schedule.id,
      subjectType: 'schedule_signal',
      subjectId: schedule.id,
      localUserId: localUserId,
      localDate: localDate,
      occurredAt: schedule.updatedAt ?? _dateFromKey(localDate),
      status: schedule.feedbackStatus,
      effect: schedule.actualEnergyLoad,
      note: schedule.note,
      metadata: {
        'title': schedule.title,
        'feedback_status': schedule.feedbackStatus,
        if (schedule.actualEnergyLoad != null)
          'actual_energy_load': schedule.actualEnergyLoad,
        if (schedule.expectedEnergyLoad != null)
          'expected_energy_load': schedule.expectedEnergyLoad,
        if (schedule.preMood != null) 'pre_mood': schedule.preMood,
        if (schedule.postMood != null) 'post_mood': schedule.postMood,
        if (schedule.friction != null) 'friction': schedule.friction,
        if (schedule.recoverySignal != null)
          'recovery_signal': schedule.recoverySignal,
        if (schedule.scene != null) 'scene': schedule.scene,
      },
      createdAt: schedule.createdAt,
    );
  }

  factory FeedbackEventModel.fromGoalFeedbackRow(
    Map<String, Object?> row, {
    required String localUserId,
  }) {
    final feedbackDate = row['feedback_date'] as String? ?? '';
    final sourceId = row['id'] as String? ?? '';
    return FeedbackEventModel(
      id: 'goal_feedback:$sourceId',
      sourceType: 'goal_feedback',
      sourceId: sourceId,
      subjectType: 'goal',
      subjectId: row['goal_id'] as String? ?? '',
      localUserId: localUserId,
      localDate: feedbackDate,
      occurredAt: _dateFromKey(feedbackDate),
      status: row['happened'] as String? ?? 'unknown',
      effect: row['effect'] as String?,
      note: row['comment'] as String?,
      metadata: {
        if (row['goal_task_instance_id'] != null)
          'goal_task_instance_id': row['goal_task_instance_id'],
        if (row['effort_level'] != null) 'effort_level': row['effort_level'],
        if (row['effect'] != null) 'effect': row['effect'],
        if (row['comment'] != null) 'comment': row['comment'],
        if (row['next_adjustment'] != null)
          'next_adjustment': row['next_adjustment'],
        if (row['updated_at'] != null) 'updated_at': row['updated_at'],
      },
      createdAt: _dateMetaFromRaw(row['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'source_type': sourceType,
      'source_id': sourceId,
      'subject_type': subjectType,
      'subject_id': subjectId,
      'local_user_id': localUserId,
      'local_date': localDate,
      'occurred_at': occurredAt?.toUtc().toIso8601String(),
      'status': status,
      'effect': effect,
      'note': note,
      'metadata': metadata,
      'created_at': createdAt?.toUtc().toIso8601String(),
    };
  }

  MicroActionFeedbackModel? toMicroActionFeedback() {
    if (sourceType != 'micro_action_feedback') return null;
    return MicroActionFeedbackModel(
      id: sourceId,
      microActionId: subjectId,
      localDate: localDate,
      happened: status,
      effect: _stringMeta('effect') ?? effect ?? 'unclear',
      difficulty: _stringMeta('difficulty') ?? 'okay',
      userNote: note ?? _stringMeta('user_note'),
      nextAdjustment: _stringMeta('next_adjustment') ?? 'continue',
      createdAt: createdAt,
    );
  }

  LifeExperimentFeedbackModel? toLifeExperimentFeedback() {
    if (sourceType != 'life_experiment_feedback') return null;
    final feedbackDate =
        occurredAt ?? _dateFromKey(localDate) ?? DateTime.now();
    return LifeExperimentFeedbackModel(
      id: sourceId,
      experimentId: subjectId,
      localUserId: localUserId,
      feedbackDate: feedbackDate,
      localDate: localDate,
      completionStatus: status,
      helpfulnessScore:
          _intMeta('helpfulness_score') ?? int.tryParse(effect ?? ''),
      feedbackText: note ?? _stringMeta('feedback_text'),
      conditionTags: _stringListMeta('condition_tags'),
      durationMinutes: _intMeta('duration_minutes'),
      timeSlot: _stringMeta('time_slot'),
      patternId: _stringMeta('pattern_id'),
      feedbackPatternId: _stringMeta('feedback_pattern_id'),
      focusAreaId: _stringMeta('focus_area_id'),
      createdAt: createdAt,
      updatedAt: _dateMeta('updated_at'),
    );
  }

  String? _stringMeta(String key) {
    final raw = metadata[key];
    final value = raw?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  int? _intMeta(String key) {
    final raw = metadata[key];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim());
    return null;
  }

  DateTime? _dateMeta(String key) {
    final raw = metadata[key];
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  List<String> _stringListMeta(String key) {
    final raw = metadata[key];
    if (raw is List) {
      return raw
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded
              .map((item) => item?.toString().trim() ?? '')
              .where((item) => item.isNotEmpty)
              .toList(growable: false);
        }
      } catch (_) {
        return raw
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false);
      }
    }
    return const [];
  }
}

Map<String, dynamic> _decodeJsonMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is! String || raw.trim().isEmpty) return const {};
  try {
    final decoded = jsonDecode(raw);
    return decoded is Map
        ? decoded.map((key, value) => MapEntry(key.toString(), value))
        : const {};
  } catch (_) {
    return const {};
  }
}

DateTime? _dateFromKey(String key) {
  if (key.trim().isEmpty) return null;
  return DateTime.tryParse(key);
}

DateTime? _dateMetaFromRaw(Object? raw) {
  if (raw is DateTime) return raw;
  if (raw is String && raw.trim().isNotEmpty) return DateTime.tryParse(raw);
  return null;
}
