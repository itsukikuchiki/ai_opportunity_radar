import 'dart:convert';

class ScheduleSignalModel {
  final String id;
  final String title;
  final String scheduleStatus;
  final String scheduleType;
  final String sourceType;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? localDate;
  final String anchorDate;
  final String datePrecision;
  final String timePrecision;
  final String? scene;
  final String? note;
  final String? expectedEnergyLoad;
  final String? actualEnergyLoad;
  final String? preMood;
  final String? postMood;
  final String? friction;
  final String? recoverySignal;
  final String? interruptionLevel;
  final int? bufferBeforeMinutes;
  final int? bufferAfterMinutes;
  final bool reminderEnabled;
  final DateTime? reminderTime;
  final String feedbackStatus;
  final List<String> linkedSignalCardIds;
  final String? linkedExperimentId;
  final String? linkedGoalId;
  final String? linkedGoalTaskInstanceId;
  final bool includedInWeekly;
  final bool includedInJourney;
  final String privacyLevel;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  const ScheduleSignalModel({
    required this.id,
    required this.title,
    this.scheduleStatus = 'unscheduled',
    this.scheduleType = 'manual',
    this.sourceType = 'manual_schedule',
    this.startTime,
    this.endTime,
    this.localDate,
    required this.anchorDate,
    this.datePrecision = 'none',
    this.timePrecision = 'none',
    this.scene,
    this.note,
    this.expectedEnergyLoad,
    this.actualEnergyLoad,
    this.preMood,
    this.postMood,
    this.friction,
    this.recoverySignal,
    this.interruptionLevel,
    this.bufferBeforeMinutes,
    this.bufferAfterMinutes,
    this.reminderEnabled = false,
    this.reminderTime,
    this.feedbackStatus = 'not_started',
    this.linkedSignalCardIds = const [],
    this.linkedExperimentId,
    this.linkedGoalId,
    this.linkedGoalTaskInstanceId,
    this.includedInWeekly = false,
    this.includedInJourney = false,
    this.privacyLevel = 'private',
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  bool get isUnscheduled => datePrecision == 'none' && timePrecision == 'none';
  bool get hasExactTime => datePrecision == 'date' && timePrecision == 'time';
  bool get isPending => scheduleStatus == 'unscheduled' || !hasExactTime;

  factory ScheduleSignalModel.fromDb(Map<String, Object?> row) {
    return ScheduleSignalModel(
      id: row['id'] as String? ?? '',
      title: row['title'] as String? ?? '',
      scheduleStatus: row['schedule_status'] as String? ?? 'unscheduled',
      scheduleType: row['schedule_type'] as String? ?? 'manual',
      sourceType: row['source_type'] as String? ?? 'manual_schedule',
      startTime: _parseDate(row['start_time']),
      endTime: _parseDate(row['end_time']),
      localDate: row['local_date'] as String?,
      anchorDate: row['anchor_date'] as String? ?? '',
      datePrecision: row['date_precision'] as String? ?? 'none',
      timePrecision: row['time_precision'] as String? ?? 'none',
      scene: row['scene'] as String?,
      note: row['note'] as String?,
      expectedEnergyLoad: row['expected_energy_load'] as String?,
      actualEnergyLoad: row['actual_energy_load'] as String?,
      preMood: row['pre_mood'] as String?,
      postMood: row['post_mood'] as String?,
      friction: row['friction'] as String?,
      recoverySignal: row['recovery_signal'] as String?,
      interruptionLevel: row['interruption_level'] as String?,
      bufferBeforeMinutes: row['buffer_before_minutes'] as int?,
      bufferAfterMinutes: row['buffer_after_minutes'] as int?,
      reminderEnabled: _bool(row['reminder_enabled']),
      reminderTime: _parseDate(row['reminder_time']),
      feedbackStatus: row['feedback_status'] as String? ?? 'not_started',
      linkedSignalCardIds:
          _decodeStringList(row['linked_signal_card_ids_json']),
      linkedExperimentId: row['linked_experiment_id'] as String?,
      linkedGoalId: row['linked_goal_id'] as String?,
      linkedGoalTaskInstanceId: row['linked_goal_task_instance_id'] as String?,
      includedInWeekly: _bool(row['included_in_weekly']),
      includedInJourney: _bool(row['included_in_journey']),
      privacyLevel: row['privacy_level'] as String? ?? 'private',
      createdAt: _parseDate(row['created_at']),
      updatedAt: _parseDate(row['updated_at']),
      deletedAt: _parseDate(row['deleted_at']),
    );
  }

  Map<String, Object?> toDb() => {
        'id': id,
        'title': title,
        'schedule_status': scheduleStatus,
        'schedule_type': scheduleType,
        'source_type': sourceType,
        'start_time': startTime?.toUtc().toIso8601String(),
        'end_time': endTime?.toUtc().toIso8601String(),
        'local_date': localDate,
        'anchor_date': anchorDate,
        'date_precision': datePrecision,
        'time_precision': timePrecision,
        'scene': scene,
        'note': note,
        'expected_energy_load': expectedEnergyLoad,
        'actual_energy_load': actualEnergyLoad,
        'pre_mood': preMood,
        'post_mood': postMood,
        'friction': friction,
        'recovery_signal': recoverySignal,
        'interruption_level': interruptionLevel,
        'buffer_before_minutes': bufferBeforeMinutes,
        'buffer_after_minutes': bufferAfterMinutes,
        'reminder_enabled': reminderEnabled ? 1 : 0,
        'reminder_time': reminderTime?.toUtc().toIso8601String(),
        'feedback_status': feedbackStatus,
        'linked_signal_card_ids_json': jsonEncode(linkedSignalCardIds),
        'linked_experiment_id': linkedExperimentId,
        'linked_goal_id': linkedGoalId,
        'linked_goal_task_instance_id': linkedGoalTaskInstanceId,
        'included_in_weekly': includedInWeekly ? 1 : 0,
        'included_in_journey': includedInJourney ? 1 : 0,
        'privacy_level': privacyLevel,
        'created_at': createdAt?.toUtc().toIso8601String() ??
            DateTime.now().toUtc().toIso8601String(),
        'updated_at': updatedAt?.toUtc().toIso8601String() ??
            DateTime.now().toUtc().toIso8601String(),
        'deleted_at': deletedAt?.toUtc().toIso8601String(),
      };

  static DateTime? _parseDate(Object? raw) {
    if (raw is DateTime) return raw;
    if (raw is String && raw.trim().isNotEmpty) return DateTime.tryParse(raw);
    return null;
  }

  static bool _bool(Object? raw) {
    if (raw is bool) return raw;
    if (raw is int) return raw != 0;
    if (raw is String) return raw == '1' || raw.toLowerCase() == 'true';
    return false;
  }

  static List<String> _decodeStringList(Object? raw) {
    if (raw is! String || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((e) => e?.toString().trim() ?? '')
            .where((e) => e.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return const [];
  }
}

class GoalModel {
  final String id;
  final String title;
  final String goalType;
  final String period;
  final String? desiredFrequency;
  final int? desiredDurationMinutes;
  final DateTime? deadline;
  final bool reminderEnabled;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const GoalModel({
    required this.id,
    required this.title,
    this.goalType = 'personal',
    this.period = 'weekly',
    this.desiredFrequency,
    this.desiredDurationMinutes,
    this.deadline,
    this.reminderEnabled = false,
    this.status = 'active',
    this.createdAt,
    this.updatedAt,
  });

  factory GoalModel.fromDb(Map<String, Object?> row) => GoalModel(
        id: row['id'] as String? ?? '',
        title: row['title'] as String? ?? '',
        goalType: row['goal_type'] as String? ?? 'personal',
        period: row['period'] as String? ?? 'weekly',
        desiredFrequency: row['desired_frequency'] as String?,
        desiredDurationMinutes: row['desired_duration_minutes'] as int?,
        deadline: ScheduleSignalModel._parseDate(row['deadline']),
        reminderEnabled: ScheduleSignalModel._bool(row['reminder_enabled']),
        status: row['status'] as String? ?? 'active',
        createdAt: ScheduleSignalModel._parseDate(row['created_at']),
        updatedAt: ScheduleSignalModel._parseDate(row['updated_at']),
      );
}

class GoalPlanModel {
  final String id;
  final String goalId;
  final String planLevel;
  final String minimumTask;
  final String standardTask;
  final String fullTask;
  final String? frequency;
  final String? timeSuggestion;
  final String? userAdjustment;
  final bool adopted;

  const GoalPlanModel({
    required this.id,
    required this.goalId,
    this.planLevel = 'standard',
    required this.minimumTask,
    required this.standardTask,
    required this.fullTask,
    this.frequency,
    this.timeSuggestion,
    this.userAdjustment,
    this.adopted = false,
  });

  factory GoalPlanModel.fromDb(Map<String, Object?> row) => GoalPlanModel(
        id: row['id'] as String? ?? '',
        goalId: row['goal_id'] as String? ?? '',
        planLevel: row['plan_level'] as String? ?? 'standard',
        minimumTask: row['minimum_task'] as String? ?? '',
        standardTask: row['standard_task'] as String? ?? '',
        fullTask: row['full_task'] as String? ?? '',
        frequency: row['frequency'] as String?,
        timeSuggestion: row['time_suggestion'] as String?,
        userAdjustment: row['user_adjustment'] as String?,
        adopted: ScheduleSignalModel._bool(row['adopted']),
      );
}

class GoalTaskInstanceModel {
  final String id;
  final String goalId;
  final String? goalPlanId;
  final String title;
  final String localDate;
  final DateTime? plannedTime;
  final int? durationMinutes;
  final String? scheduleSignalId;
  final String status;

  const GoalTaskInstanceModel({
    required this.id,
    required this.goalId,
    this.goalPlanId,
    required this.title,
    required this.localDate,
    this.plannedTime,
    this.durationMinutes,
    this.scheduleSignalId,
    this.status = 'suggested',
  });

  factory GoalTaskInstanceModel.fromDb(Map<String, Object?> row) =>
      GoalTaskInstanceModel(
        id: row['id'] as String? ?? '',
        goalId: row['goal_id'] as String? ?? '',
        goalPlanId: row['goal_plan_id'] as String?,
        title: row['title'] as String? ?? '',
        localDate: row['local_date'] as String? ?? '',
        plannedTime: ScheduleSignalModel._parseDate(row['planned_time']),
        durationMinutes: row['duration_minutes'] as int?,
        scheduleSignalId: row['schedule_signal_id'] as String?,
        status: row['status'] as String? ?? 'suggested',
      );
}

class Phase3PlusSummary {
  final int scheduleKnownCount;
  final int pendingScheduleCount;
  final int unexpectedScheduleCount;
  final int feedbackCount;
  final int highExpectedLoadCount;
  final int highActualDrainCount;
  final int recoveryScheduleCount;
  final int activeGoalCount;
  final int todayGoalTaskCount;
  final int goalFeedbackCount;

  const Phase3PlusSummary({
    this.scheduleKnownCount = 0,
    this.pendingScheduleCount = 0,
    this.unexpectedScheduleCount = 0,
    this.feedbackCount = 0,
    this.highExpectedLoadCount = 0,
    this.highActualDrainCount = 0,
    this.recoveryScheduleCount = 0,
    this.activeGoalCount = 0,
    this.todayGoalTaskCount = 0,
    this.goalFeedbackCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'schedule_known_count': scheduleKnownCount,
        'pending_schedule_count': pendingScheduleCount,
        'unexpected_schedule_count': unexpectedScheduleCount,
        'feedback_count': feedbackCount,
        'high_expected_load_count': highExpectedLoadCount,
        'high_actual_drain_count': highActualDrainCount,
        'recovery_schedule_count': recoveryScheduleCount,
        'active_goal_count': activeGoalCount,
        'today_goal_task_count': todayGoalTaskCount,
        'goal_feedback_count': goalFeedbackCount,
      };
}

class AiJudgementModel {
  final String id;
  final List<String> sourceSignalCardIds;
  final List<String> sourceScheduleSignalIds;
  final List<String> sourceGoalTaskInstanceIds;
  final String localDate;
  final String judgementText;
  final String evidenceText;
  final String suggestedPattern;
  final String suggestedLifeChainStage;
  final String confidenceLevel;
  final String status;
  final String? userAdjustmentText;
  final String? linkedMicroActionId;
  final bool includedInWeekly;
  final bool includedInJourney;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AiJudgementModel({
    required this.id,
    this.sourceSignalCardIds = const [],
    this.sourceScheduleSignalIds = const [],
    this.sourceGoalTaskInstanceIds = const [],
    required this.localDate,
    required this.judgementText,
    required this.evidenceText,
    required this.suggestedPattern,
    required this.suggestedLifeChainStage,
    this.confidenceLevel = 'medium',
    this.status = 'pending',
    this.userAdjustmentText,
    this.linkedMicroActionId,
    this.includedInWeekly = false,
    this.includedInJourney = false,
    this.createdAt,
    this.updatedAt,
  });

  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed' || status == 'adjusted';
  bool get isInaccurate => status == 'inaccurate';

  Map<String, Object?> toDb() {
    final created = createdAt ?? DateTime.now();
    final updated = updatedAt ?? DateTime.now();
    return {
      'id': id,
      'source_signal_card_ids_json': jsonEncode(sourceSignalCardIds),
      'source_schedule_signal_ids_json': jsonEncode(sourceScheduleSignalIds),
      'source_goal_task_instance_ids_json':
          jsonEncode(sourceGoalTaskInstanceIds),
      'local_date': localDate,
      'judgement_text': judgementText,
      'evidence_text': evidenceText,
      'suggested_pattern': suggestedPattern,
      'suggested_life_chain_stage': suggestedLifeChainStage,
      'confidence_level': confidenceLevel,
      'status': status,
      'user_adjustment_text': userAdjustmentText,
      'linked_micro_action_id': linkedMicroActionId,
      'included_in_weekly': includedInWeekly ? 1 : 0,
      'included_in_journey': includedInJourney ? 1 : 0,
      'created_at': created.toUtc().toIso8601String(),
      'updated_at': updated.toUtc().toIso8601String(),
    };
  }

  factory AiJudgementModel.fromDb(Map<String, Object?> row) {
    return AiJudgementModel(
      id: row['id'] as String? ?? '',
      sourceSignalCardIds:
          ScheduleSignalModel._decodeStringList(row['source_signal_card_ids_json']),
      sourceScheduleSignalIds: ScheduleSignalModel._decodeStringList(
          row['source_schedule_signal_ids_json']),
      sourceGoalTaskInstanceIds: ScheduleSignalModel._decodeStringList(
          row['source_goal_task_instance_ids_json']),
      localDate: row['local_date'] as String? ?? '',
      judgementText: row['judgement_text'] as String? ?? '',
      evidenceText: row['evidence_text'] as String? ?? '',
      suggestedPattern: row['suggested_pattern'] as String? ?? '',
      suggestedLifeChainStage:
          row['suggested_life_chain_stage'] as String? ?? '',
      confidenceLevel: row['confidence_level'] as String? ?? 'medium',
      status: row['status'] as String? ?? 'pending',
      userAdjustmentText: row['user_adjustment_text'] as String?,
      linkedMicroActionId: row['linked_micro_action_id'] as String?,
      includedInWeekly: ScheduleSignalModel._bool(row['included_in_weekly']),
      includedInJourney: ScheduleSignalModel._bool(row['included_in_journey']),
      createdAt: ScheduleSignalModel._parseDate(row['created_at']),
      updatedAt: ScheduleSignalModel._parseDate(row['updated_at']),
    );
  }
}

class MicroActionModel {
  final String id;
  final String judgementId;
  final String title;
  final String reason;
  final String actionType;
  final String difficulty;
  final String? plannedDate;
  final DateTime? plannedTime;
  final String? linkedScheduleSignalId;
  final String? linkedGoalId;
  final String? linkedLifeExperimentId;
  final String status;
  final String feedbackStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const MicroActionModel({
    required this.id,
    required this.judgementId,
    required this.title,
    required this.reason,
    this.actionType = 'today_try',
    this.difficulty = 'very_light',
    this.plannedDate,
    this.plannedTime,
    this.linkedScheduleSignalId,
    this.linkedGoalId,
    this.linkedLifeExperimentId,
    this.status = 'suggested',
    this.feedbackStatus = 'none',
    this.createdAt,
    this.updatedAt,
  });

  bool get isActive =>
      status == 'accepted' || status == 'active' || status == 'done';

  Map<String, Object?> toDb() {
    final created = createdAt ?? DateTime.now();
    final updated = updatedAt ?? DateTime.now();
    return {
      'id': id,
      'judgement_id': judgementId,
      'title': title,
      'reason': reason,
      'action_type': actionType,
      'difficulty': difficulty,
      'planned_date': plannedDate,
      'planned_time': plannedTime?.toUtc().toIso8601String(),
      'linked_schedule_signal_id': linkedScheduleSignalId,
      'linked_goal_id': linkedGoalId,
      'linked_life_experiment_id': linkedLifeExperimentId,
      'status': status,
      'feedback_status': feedbackStatus,
      'created_at': created.toUtc().toIso8601String(),
      'updated_at': updated.toUtc().toIso8601String(),
    };
  }

  factory MicroActionModel.fromDb(Map<String, Object?> row) {
    return MicroActionModel(
      id: row['id'] as String? ?? '',
      judgementId: row['judgement_id'] as String? ?? '',
      title: row['title'] as String? ?? '',
      reason: row['reason'] as String? ?? '',
      actionType: row['action_type'] as String? ?? 'today_try',
      difficulty: row['difficulty'] as String? ?? 'very_light',
      plannedDate: row['planned_date'] as String?,
      plannedTime: ScheduleSignalModel._parseDate(row['planned_time']),
      linkedScheduleSignalId: row['linked_schedule_signal_id'] as String?,
      linkedGoalId: row['linked_goal_id'] as String?,
      linkedLifeExperimentId: row['linked_life_experiment_id'] as String?,
      status: row['status'] as String? ?? 'suggested',
      feedbackStatus: row['feedback_status'] as String? ?? 'none',
      createdAt: ScheduleSignalModel._parseDate(row['created_at']),
      updatedAt: ScheduleSignalModel._parseDate(row['updated_at']),
    );
  }
}

class MicroActionFeedbackModel {
  final String id;
  final String microActionId;
  final String localDate;
  final String happened;
  final String effect;
  final String difficulty;
  final String? userNote;
  final String nextAdjustment;
  final DateTime? createdAt;

  const MicroActionFeedbackModel({
    required this.id,
    required this.microActionId,
    required this.localDate,
    this.happened = 'unknown',
    this.effect = 'unclear',
    this.difficulty = 'okay',
    this.userNote,
    this.nextAdjustment = 'continue',
    this.createdAt,
  });

  Map<String, Object?> toDb() {
    final created = createdAt ?? DateTime.now();
    return {
      'id': id,
      'micro_action_id': microActionId,
      'local_date': localDate,
      'happened': happened,
      'effect': effect,
      'difficulty': difficulty,
      'user_note': userNote,
      'next_adjustment': nextAdjustment,
      'created_at': created.toUtc().toIso8601String(),
    };
  }

  factory MicroActionFeedbackModel.fromDb(Map<String, Object?> row) {
    return MicroActionFeedbackModel(
      id: row['id'] as String? ?? '',
      microActionId: row['micro_action_id'] as String? ?? '',
      localDate: row['local_date'] as String? ?? '',
      happened: row['happened'] as String? ?? 'unknown',
      effect: row['effect'] as String? ?? 'unclear',
      difficulty: row['difficulty'] as String? ?? 'okay',
      userNote: row['user_note'] as String?,
      nextAdjustment: row['next_adjustment'] as String? ?? 'continue',
      createdAt: ScheduleSignalModel._parseDate(row['created_at']),
    );
  }
}
