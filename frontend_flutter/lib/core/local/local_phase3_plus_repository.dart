import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/phase3_plus_models.dart';
import 'local_database.dart';

class LocalPhase3PlusRepository {
  final LocalDatabase localDatabase;
  final Uuid _uuid = const Uuid();

  LocalPhase3PlusRepository(this.localDatabase);

  Future<ScheduleSignalModel> createScheduleSignal({
    required String title,
    DateTime? date,
    DateTime? time,
    DateTime? endTime,
    String? scene,
    String? note,
    String? expectedEnergyLoad,
    bool reminderEnabled = false,
    String scheduleType = 'manual',
    String sourceType = 'manual_schedule',
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('schedule_title_required');
    }

    final now = DateTime.now();
    final nowUtc = now.toUtc();
    final hasDate = date != null;
    final hasTime = time != null;
    final effectiveDate = hasDate
        ? DateTime(date.year, date.month, date.day)
        : hasTime
            ? DateTime(now.year, now.month, now.day)
            : null;
    final start = hasTime && effectiveDate != null
        ? DateTime(
            effectiveDate.year,
            effectiveDate.month,
            effectiveDate.day,
            time.hour,
            time.minute,
          )
        : null;
    final localDate = effectiveDate == null ? null : _dateKey(effectiveDate);
    final datePrecision = hasDate || hasTime ? 'date' : 'none';
    final timePrecision = hasTime ? 'time' : 'none';
    final status = hasDate || hasTime ? 'planned' : 'unscheduled';
    final end = _resolveEndTime(start, effectiveDate, endTime);
    final model = ScheduleSignalModel(
      id: _id('sch'),
      title: trimmed,
      scheduleStatus: status,
      scheduleType: scheduleType,
      sourceType: sourceType,
      startTime: start,
      endTime: end,
      localDate: localDate,
      anchorDate: _dateKey(now),
      datePrecision: datePrecision,
      timePrecision: timePrecision,
      scene: _emptyToNull(scene),
      note: _emptyToNull(note),
      expectedEnergyLoad: _emptyToNull(expectedEnergyLoad),
      reminderEnabled: reminderEnabled && start != null,
      reminderTime: reminderEnabled && start != null
          ? start.subtract(const Duration(minutes: 15))
          : null,
      createdAt: nowUtc,
      updatedAt: nowUtc,
    );

    final db = await localDatabase.database;
    await db.insert(
      'schedule_signals',
      model.toDb(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return model;
  }

  Future<ScheduleSignalModel?> updateScheduleSignal({
    required String id,
    required String title,
    DateTime? date,
    DateTime? time,
    DateTime? endTime,
    String? scene,
    String? note,
    String? expectedEnergyLoad,
    bool reminderEnabled = false,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('schedule_title_required');
    }

    final db = await localDatabase.database;
    final rows = await db.query(
      'schedule_signals',
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final existing = ScheduleSignalModel.fromDb(rows.first);
    final now = DateTime.now();
    final nowUtc = now.toUtc();
    final hasDate = date != null;
    final hasTime = time != null;
    final effectiveDate = hasDate
        ? DateTime(date.year, date.month, date.day)
        : hasTime
            ? DateTime(now.year, now.month, now.day)
            : null;
    final start = hasTime && effectiveDate != null
        ? DateTime(
            effectiveDate.year,
            effectiveDate.month,
            effectiveDate.day,
            time.hour,
            time.minute,
          )
        : null;
    final localDate = effectiveDate == null ? null : _dateKey(effectiveDate);
    final datePrecision = hasDate || hasTime ? 'date' : 'none';
    final timePrecision = hasTime ? 'time' : 'none';
    final status = hasDate || hasTime ? 'planned' : 'unscheduled';

    final updated = ScheduleSignalModel(
      id: existing.id,
      title: trimmed,
      scheduleStatus: status,
      scheduleType: existing.scheduleType,
      sourceType: existing.sourceType,
      startTime: start,
      endTime: _resolveEndTime(start, effectiveDate, endTime),
      localDate: localDate,
      anchorDate: existing.anchorDate,
      datePrecision: datePrecision,
      timePrecision: timePrecision,
      scene: _emptyToNull(scene),
      note: _emptyToNull(note),
      expectedEnergyLoad: _emptyToNull(expectedEnergyLoad),
      actualEnergyLoad: existing.actualEnergyLoad,
      preMood: existing.preMood,
      postMood: existing.postMood,
      friction: existing.friction,
      recoverySignal: existing.recoverySignal,
      interruptionLevel: existing.interruptionLevel,
      bufferBeforeMinutes: existing.bufferBeforeMinutes,
      bufferAfterMinutes: existing.bufferAfterMinutes,
      reminderEnabled: reminderEnabled && start != null,
      reminderTime: reminderEnabled && start != null
          ? start.subtract(const Duration(minutes: 15))
          : null,
      feedbackStatus: existing.feedbackStatus,
      linkedSignalCardIds: existing.linkedSignalCardIds,
      linkedExperimentId: existing.linkedExperimentId,
      linkedGoalId: existing.linkedGoalId,
      linkedGoalTaskInstanceId: existing.linkedGoalTaskInstanceId,
      includedInWeekly: existing.includedInWeekly,
      includedInJourney: existing.includedInJourney,
      privacyLevel: existing.privacyLevel,
      createdAt: existing.createdAt,
      updatedAt: nowUtc,
      deletedAt: existing.deletedAt,
    );

    await db.update(
      'schedule_signals',
      updated.toDb(),
      where: 'id = ?',
      whereArgs: [id],
    );
    return updated;
  }

  Future<void> deleteScheduleSignal(String id) async {
    final db = await localDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'schedule_signals',
      {
        'deleted_at': now,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<ScheduleSignalModel>> listTodaySchedules() async {
    final db = await localDatabase.database;
    final today = _dateKey(DateTime.now());
    final rows = await db.query(
      'schedule_signals',
      where:
          'deleted_at IS NULL AND (local_date = ? OR (date_precision = ? AND anchor_date = ?))',
      whereArgs: [today, 'none', today],
      orderBy:
          "CASE WHEN time_precision = 'time' THEN 0 ELSE 1 END, start_time ASC, updated_at DESC",
    );
    return rows.map(ScheduleSignalModel.fromDb).toList();
  }

  Future<List<ScheduleSignalModel>> listSchedulesBetween({
    required String startDate,
    required String endDate,
  }) async {
    final db = await localDatabase.database;
    final rows = await db.query(
      'schedule_signals',
      where:
          'deleted_at IS NULL AND ((local_date >= ? AND local_date <= ?) OR (anchor_date >= ? AND anchor_date <= ?))',
      whereArgs: [startDate, endDate, startDate, endDate],
      orderBy: 'COALESCE(local_date, anchor_date) ASC, start_time ASC',
    );
    return rows.map(ScheduleSignalModel.fromDb).toList();
  }

  Future<void> updateScheduleFeedback({
    required String scheduleId,
    String feedbackStatus = 'recorded',
    String? actualEnergyLoad,
    String? preMood,
    String? postMood,
    String? friction,
    String? recoverySignal,
    String? linkedSignalCardId,
  }) async {
    final db = await localDatabase.database;
    final rows = await db.query(
      'schedule_signals',
      where: 'id = ?',
      whereArgs: [scheduleId],
      limit: 1,
    );
    final existing = rows.isEmpty
        ? const <String>[]
        : ScheduleSignalModel.fromDb(rows.first).linkedSignalCardIds;
    final linkedIds = {
      ...existing,
      if (linkedSignalCardId != null && linkedSignalCardId.trim().isNotEmpty)
        linkedSignalCardId.trim(),
    }.toList();
    await db.update(
      'schedule_signals',
      {
        'feedback_status': feedbackStatus,
        'actual_energy_load': _emptyToNull(actualEnergyLoad),
        'pre_mood': _emptyToNull(preMood),
        'post_mood': _emptyToNull(postMood),
        'friction': _emptyToNull(friction),
        'recovery_signal': _emptyToNull(recoverySignal),
        'linked_signal_card_ids_json': jsonEncode(linkedIds),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [scheduleId],
    );
  }

  Future<GoalModel> createGoalWithPlan({
    required String title,
    String goalType = 'personal',
    String period = 'weekly',
    String? desiredFrequency,
    int? desiredDurationMinutes,
    DateTime? deadline,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) throw ArgumentError('goal_title_required');

    final db = await localDatabase.database;
    final now = DateTime.now().toUtc();
    final goal = GoalModel(
      id: _id('goal'),
      title: trimmed,
      goalType: goalType,
      period: period,
      desiredFrequency: desiredFrequency,
      desiredDurationMinutes: desiredDurationMinutes,
      deadline: deadline,
      createdAt: now,
      updatedAt: now,
    );
    await db.insert(
      'goals',
      {
        'id': goal.id,
        'title': goal.title,
        'goal_type': goal.goalType,
        'period': goal.period,
        'desired_frequency': goal.desiredFrequency,
        'desired_duration_minutes': goal.desiredDurationMinutes,
        'deadline': goal.deadline?.toUtc().toIso8601String(),
        'reminder_enabled': goal.reminderEnabled ? 1 : 0,
        'status': goal.status,
        'privacy_level': 'private',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    final planId = _id('plan');
    final duration = desiredDurationMinutes ?? 12;
    await db.insert(
      'goal_plans',
      {
        'id': planId,
        'goal_id': goal.id,
        'plan_level': 'standard',
        'minimum_task': '先做 2 分钟：$trimmed',
        'standard_task': '留 $duration 分钟做一次：$trimmed',
        'full_task': '如果状态允许，完成一段更完整的：$trimmed',
        'frequency': desiredFrequency ?? '每周 3 次',
        'time_suggestion': '放在一天里切换较少的时段',
        'user_adjustment': null,
        'adopted': 1,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await _ensureTodayGoalTask(
      goalId: goal.id,
      planId: planId,
      title: '今天先做 2 分钟：$trimmed',
      durationMinutes: 2,
    );
    return goal;
  }

  Future<List<GoalModel>> listActiveGoals() async {
    final db = await localDatabase.database;
    final rows = await db.query(
      'goals',
      where: 'deleted_at IS NULL AND status = ?',
      whereArgs: ['active'],
      orderBy: 'updated_at DESC',
    );
    return rows.map(GoalModel.fromDb).toList();
  }

  Future<List<GoalTaskInstanceModel>> listTodayGoalTasks() async {
    final db = await localDatabase.database;
    final today = _dateKey(DateTime.now());
    final rows = await db.query(
      'goal_task_instances',
      where: 'local_date = ?',
      whereArgs: [today],
      orderBy: 'updated_at DESC',
    );
    return rows.map(GoalTaskInstanceModel.fromDb).toList();
  }

  Future<void> submitGoalFeedback({
    required String goalId,
    String? goalTaskInstanceId,
    required String happened,
    String? effortLevel,
    String? effect,
    String? comment,
    String? nextAdjustment,
  }) async {
    final db = await localDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.insert(
      'goal_feedback',
      {
        'id': _id('gfb'),
        'goal_id': goalId,
        'goal_task_instance_id': goalTaskInstanceId,
        'feedback_date': _dateKey(DateTime.now()),
        'happened': happened,
        'effort_level': effortLevel,
        'effect': effect,
        'comment': comment,
        'next_adjustment': nextAdjustment,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (goalTaskInstanceId != null) {
      await db.update(
        'goal_task_instances',
        {
          'status': happened == 'yes' ? 'tried' : 'not_today',
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [goalTaskInstanceId],
      );
    }
  }

  String createId(String prefix) => _id(prefix);

  String todayKey() => _dateKey(DateTime.now());

  Future<AiJudgementModel?> getAiJudgementForDate(String localDate) async {
    final db = await localDatabase.database;
    final rows = await db.query(
      'ai_judgements',
      where: 'local_date = ?',
      whereArgs: [localDate],
      orderBy: 'updated_at DESC, created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AiJudgementModel.fromDb(rows.first);
  }

  Future<AiJudgementModel?> getAiJudgementById(String id) async {
    final db = await localDatabase.database;
    final rows = await db.query(
      'ai_judgements',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AiJudgementModel.fromDb(rows.first);
  }

  Future<void> upsertAiJudgement(AiJudgementModel model) async {
    final db = await localDatabase.database;
    await db.insert(
      'ai_judgements',
      model.toDb(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateAiJudgementStatus({
    required String id,
    required String status,
    String? userAdjustmentText,
    String? linkedMicroActionId,
    bool? includedInWeekly,
    bool? includedInJourney,
  }) async {
    final db = await localDatabase.database;
    final values = <String, Object?>{
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (userAdjustmentText != null) {
      values['user_adjustment_text'] = userAdjustmentText;
    }
    if (linkedMicroActionId != null) {
      values['linked_micro_action_id'] = linkedMicroActionId;
    }
    if (includedInWeekly != null) {
      values['included_in_weekly'] = includedInWeekly ? 1 : 0;
    }
    if (includedInJourney != null) {
      values['included_in_journey'] = includedInJourney ? 1 : 0;
    }
    await db.update(
      'ai_judgements',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<MicroActionModel>> listMicroActionsForDate(
    String localDate,
  ) async {
    final db = await localDatabase.database;
    final rows = await db.query(
      'micro_actions',
      where: 'planned_date = ?',
      whereArgs: [localDate],
      orderBy: 'updated_at DESC, created_at DESC',
    );
    return rows.map(MicroActionModel.fromDb).toList();
  }

  Future<MicroActionModel?> getMicroActionById(String id) async {
    final db = await localDatabase.database;
    final rows = await db.query(
      'micro_actions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MicroActionModel.fromDb(rows.first);
  }

  Future<void> upsertMicroAction(MicroActionModel model) async {
    final db = await localDatabase.database;
    await db.insert(
      'micro_actions',
      model.toDb(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateMicroActionStatus({
    required String id,
    required String status,
    String? feedbackStatus,
  }) async {
    final db = await localDatabase.database;
    final values = <String, Object?>{
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (feedbackStatus != null) {
      values['feedback_status'] = feedbackStatus;
    }
    await db.update(
      'micro_actions',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> insertMicroActionFeedback(
    MicroActionFeedbackModel feedback,
  ) async {
    final db = await localDatabase.database;
    await db.insert(
      'micro_action_feedback',
      feedback.toDb(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>> summarizeActionLoop({
    required String startDate,
    required String endDate,
  }) async {
    final db = await localDatabase.database;
    final judgementRows = await db.query(
      'ai_judgements',
      where: 'local_date >= ? AND local_date <= ?',
      whereArgs: [startDate, endDate],
      orderBy: 'created_at DESC',
    );
    final actionRows = await db.query(
      'micro_actions',
      where:
          '(planned_date >= ? AND planned_date <= ?) OR planned_date IS NULL',
      whereArgs: [startDate, endDate],
      orderBy: 'created_at DESC',
    );
    final feedbackRows = await db.query(
      'micro_action_feedback',
      where: 'local_date >= ? AND local_date <= ?',
      whereArgs: [startDate, endDate],
      orderBy: 'created_at DESC',
    );

    final judgements =
        judgementRows.map(AiJudgementModel.fromDb).toList(growable: false);
    final actions =
        actionRows.map(MicroActionModel.fromDb).toList(growable: false);
    final feedbacks = feedbackRows
        .map(MicroActionFeedbackModel.fromDb)
        .toList(growable: false);
    final actionsById = {for (final action in actions) action.id: action};

    final confirmedJudgementCount = judgements
        .where((judgement) => _isConfirmedJudgementStatus(judgement.status))
        .length;
    final triedActionIds = <String>{
      for (final action in actions)
        if (_isTriedActionStatus(action.status) ||
            _isHelpfulFeedbackStatus(action.feedbackStatus))
          action.id,
      for (final feedback in feedbacks)
        if (_isHappenedFeedback(feedback.happened)) feedback.microActionId,
    };
    final helpfulFeedbacks = feedbacks
        .where((feedback) => _isHelpfulFeedbackStatus(feedback.effect))
        .toList(growable: false);
    final helpfulActionIds = <String>{
      for (final action in actions)
        if (_isHelpfulFeedbackStatus(action.feedbackStatus)) action.id,
      for (final feedback in helpfulFeedbacks) feedback.microActionId,
    };
    final hardFeedback = _firstOrNull(feedbacks.where(_isHardFeedback));
    final helpfulAction = _firstOrNull(
          helpfulFeedbacks
              .map((feedback) => actionsById[feedback.microActionId])
              .whereType<MicroActionModel>(),
        ) ??
        _firstOrNull(
          actions.where((action) =>
              _isHelpfulFeedbackStatus(action.feedbackStatus) ||
              action.isActive),
        );
    final hardAction = hardFeedback == null
        ? _firstOrNull(
            actions.where((action) =>
                action.feedbackStatus == 'not_helpful' ||
                action.status == 'skipped'),
          )
        : actionsById[hardFeedback.microActionId];

    return {
      'ai_judgement_count': judgements.length,
      'confirmed_judgement_count': confirmedJudgementCount,
      'generated_action_count': actions.length,
      'tried_action_count': triedActionIds.length,
      'helpful_action_count': helpfulActionIds.length,
      'most_helpful_action': helpfulAction?.title ?? '',
      'hardest_action': hardAction?.title ?? '',
      'next_adjustment': _deriveNextAdjustment(
        feedbacks: feedbacks,
        helpfulActionCount: helpfulActionIds.length,
        triedActionCount: triedActionIds.length,
      ),
      'linked_micro_action_ids': actions.map((action) => action.id).toList(),
    };
  }

  Future<Phase3PlusSummary> summarizeRange({
    required String startDate,
    required String endDate,
  }) async {
    final schedules = await listSchedulesBetween(
      startDate: startDate,
      endDate: endDate,
    );
    final activeGoals = await listActiveGoals();
    final todayTasks = await listTodayGoalTasks();
    final db = await localDatabase.database;
    final goalFeedbackRows = await db.query(
      'goal_feedback',
      where: 'feedback_date >= ? AND feedback_date <= ?',
      whereArgs: [startDate, endDate],
    );

    return Phase3PlusSummary(
      scheduleKnownCount: schedules.where((s) => s.hasExactTime).length,
      pendingScheduleCount: schedules.where((s) => s.isPending).length,
      unexpectedScheduleCount:
          schedules.where((s) => s.scheduleType == 'unexpected').length,
      feedbackCount:
          schedules.where((s) => s.feedbackStatus != 'not_started').length,
      highExpectedLoadCount: schedules
          .where((s) => s.expectedEnergyLoad == 'high_draining')
          .length,
      highActualDrainCount:
          schedules.where((s) => s.actualEnergyLoad == 'draining').length,
      recoveryScheduleCount:
          schedules.where((s) => s.expectedEnergyLoad == 'restoring').length,
      activeGoalCount: activeGoals.length,
      todayGoalTaskCount: todayTasks.length,
      goalFeedbackCount: goalFeedbackRows.length,
    );
  }

  bool _isConfirmedJudgementStatus(String status) {
    return const {
      'confirmed',
      'accurate',
      'partial',
      'adjusted',
      'accepted',
    }.contains(status);
  }

  bool _isTriedActionStatus(String status) {
    return const {
      'accepted',
      'active',
      'tried',
      'done',
      'completed',
    }.contains(status);
  }

  bool _isHappenedFeedback(String happened) {
    return const {
      'yes',
      'happened',
      'partial',
      'tried',
    }.contains(happened);
  }

  bool _isHelpfulFeedbackStatus(String status) {
    return const {
      'helpful',
      'helped',
      'lighter',
      'better',
      'yes',
      'somewhat',
    }.contains(status);
  }

  bool _isHardFeedback(MicroActionFeedbackModel feedback) {
    return const {'hard', 'too_hard', 'not_helpful', 'no'}
            .contains(feedback.difficulty) ||
        const {'not_helpful', 'worse', 'no'}.contains(feedback.effect) ||
        const {'lighter', 'adjust', 'switch', 'pause'}
            .contains(feedback.nextAdjustment);
  }

  String _deriveNextAdjustment({
    required List<MicroActionFeedbackModel> feedbacks,
    required int helpfulActionCount,
    required int triedActionCount,
  }) {
    final explicit = _firstOrNull(feedbacks
        .map((feedback) => feedback.nextAdjustment)
        .where((value) => value != 'continue'));
    switch (explicit) {
      case 'lighter':
        return '调轻一点';
      case 'switch':
        return '换一个策略';
      case 'pause':
        return '暂时不做';
      case 'adjust':
        return '调整后再试';
    }
    if (triedActionCount == 0) return '先选一个很小的尝试';
    if (helpfulActionCount > 0) return '继续这个方向';
    return '调轻一点';
  }

  T? _firstOrNull<T>(Iterable<T> values) {
    final iterator = values.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }

  Future<void> _ensureTodayGoalTask({
    required String goalId,
    required String planId,
    required String title,
    required int durationMinutes,
  }) async {
    final db = await localDatabase.database;
    final today = _dateKey(DateTime.now());
    final rows = await db.query(
      'goal_task_instances',
      where: 'goal_id = ? AND local_date = ?',
      whereArgs: [goalId, today],
      limit: 1,
    );
    if (rows.isNotEmpty) return;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.insert(
      'goal_task_instances',
      {
        'id': _id('gtask'),
        'goal_id': goalId,
        'goal_plan_id': planId,
        'title': title,
        'local_date': today,
        'planned_time': null,
        'duration_minutes': durationMinutes,
        'schedule_signal_id': null,
        'status': 'suggested',
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  String _id(String prefix) =>
      '${prefix}_${_uuid.v4().replaceAll('-', '').substring(0, 12)}';

  String _dateKey(DateTime date) {
    final local = date.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  DateTime? _resolveEndTime(
    DateTime? start,
    DateTime? effectiveDate,
    DateTime? endTime,
  ) {
    if (start == null || effectiveDate == null) return null;
    final requested = endTime == null
        ? null
        : DateTime(
            effectiveDate.year,
            effectiveDate.month,
            effectiveDate.day,
            endTime.hour,
            endTime.minute,
          );
    if (requested != null && requested.isAfter(start)) return requested;
    return start.add(const Duration(hours: 1));
  }
}
