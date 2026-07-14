import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/weekly_models.dart';
import 'local_cache_invalidation_repository.dart';
import 'local_database.dart';
import 'local_trace_link_repository.dart';

class LocalLifeExperimentRepository {
  final LocalDatabase localDatabase;
  final Uuid _uuid = const Uuid();

  LocalLifeExperimentRepository(this.localDatabase);

  /// Storage helpers used by the candidate planner so creating several formal
  /// experiments and binding all selected candidates can share one SQLite
  /// transaction. Callers must still run [ensureAdoptionArtifacts] after the
  /// transaction commits.
  Map<String, Object?> toStorageRow(LifeExperimentModel experiment) =>
      _toRow(experiment);

  LifeExperimentModel fromStorageRow(Map<String, Object?> row) => _mapRow(row);

  Future<void> ensureAdoptionArtifacts(LifeExperimentModel experiment) async {
    final db = await localDatabase.database;
    final existingCreatedEvent = await db.query(
      'life_experiment_lifecycle_events',
      columns: const ['id'],
      where: 'experiment_id = ? AND event_type = ?',
      whereArgs: [experiment.id, 'created'],
      limit: 1,
    );
    if (existingCreatedEvent.isEmpty) {
      await _recordLifecycleEvent(
        experiment: experiment,
        eventType: 'created',
        statusTo: experiment.status,
        sourceType: 'candidate_adoption',
        sourceId: experiment.originCandidateId,
        eventDate: experiment.adoptedAt,
      );
    }
    await _writeExperimentTraceLinks(experiment);
    await refreshRollup(experiment.id);
  }

  Future<LifeExperimentModel?> getById(String experimentId) async {
    final db = await localDatabase.database;
    final rows = await db.query(
      'life_experiments',
      where: 'id = ?',
      whereArgs: [experimentId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _mapRow(rows.first);
  }

  Future<LifeExperimentModel?> getByOriginCandidateId(
    String originCandidateId,
  ) async {
    final normalized = originCandidateId.trim();
    if (normalized.isEmpty) return null;
    final db = await localDatabase.database;
    final rows = await db.query(
      'life_experiments',
      where: 'origin_candidate_id = ?',
      whereArgs: [normalized],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _mapRow(rows.first);
  }

  Future<LifeExperimentModel?> getByWeekStart({
    required String localUserId,
    required String weekStart,
  }) async {
    final db = await localDatabase.database;
    final rows = await db.query(
      'life_experiments',
      where: 'local_user_id = ? AND source_week_start = ?',
      whereArgs: [localUserId, weekStart],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _mapRow(rows.first);
  }

  Future<LifeExperimentModel> ensureSuggested({
    required String localUserId,
    required String weekStart,
    required String weekEnd,
    required String title,
    required String hypothesis,
    required String suggestedAction,
    required List<String> linkedSignalCardIds,
    String? parentExperimentId,
    String status = 'suggested',
    String? focusAreaId,
    String? patternId,
    String? feedbackPatternId,
    String? iconAssetId,
    String? plannedFrequency,
    int? plannedDurationMinutes,
    int? plannedTotalDays,
    String? originCandidateId,
    DateTime? adoptedAt,
    String? progressStartDate,
    String? progressEndDate,
  }) async {
    final existing = originCandidateId?.trim().isNotEmpty == true
        ? await getByOriginCandidateId(originCandidateId!)
        : await getByWeekStart(
            localUserId: localUserId,
            weekStart: weekStart,
          );
    if (existing != null) return existing;

    final db = await localDatabase.database;
    final now = DateTime.now().toUtc();
    final id = 'exp_${_uuid.v4().replaceAll('-', '').substring(0, 12)}';
    final experiment = LifeExperimentModel(
      id: id,
      localUserId: localUserId,
      sourceWeekStart: weekStart,
      sourceWeekEnd: weekEnd,
      parentExperimentId: parentExperimentId,
      title: title,
      hypothesis: hypothesis,
      suggestedAction: suggestedAction,
      linkedSignalCardIds: linkedSignalCardIds,
      status: status,
      feedbackText: null,
      focusAreaId: focusAreaId,
      patternId: patternId,
      feedbackPatternId: feedbackPatternId,
      iconAssetId: iconAssetId,
      plannedFrequency: plannedFrequency,
      plannedDurationMinutes: plannedDurationMinutes,
      plannedTotalDays: plannedTotalDays,
      originCandidateId: originCandidateId,
      adoptedAt: adoptedAt,
      progressStartDate: progressStartDate,
      progressEndDate: progressEndDate,
      createdAt: now,
      updatedAt: now,
    );

    await db.insert(
      'life_experiments',
      _toRow(experiment),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _recordLifecycleEvent(
      experiment: experiment,
      eventType: 'created',
      statusTo: experiment.status,
      sourceType: parentExperimentId == null ? 'manual_or_weekly' : 'clone',
      sourceId: parentExperimentId,
    );
    await _writeExperimentTraceLinks(experiment);
    await refreshRollup(experiment.id);
    return experiment;
  }

  Future<LifeExperimentModel?> updateStatus({
    required String experimentId,
    required String status,
    String? feedbackText,
  }) async {
    return updateDetails(
      experimentId: experimentId,
      status: status,
      feedbackText: feedbackText,
    );
  }

  Future<LifeExperimentModel?> updateDetails({
    required String experimentId,
    String? title,
    String? hypothesis,
    String? suggestedAction,
    String? status,
    String? feedbackText,
    String? focusAreaId,
    String? patternId,
    String? feedbackPatternId,
    String? iconAssetId,
    String? plannedFrequency,
    int? plannedDurationMinutes,
    int? plannedTotalDays,
  }) async {
    final db = await localDatabase.database;
    final before = await getById(experimentId);
    final now = DateTime.now().toUtc();
    final updates = <String, Object?>{
      'updated_at': now.toIso8601String(),
    };
    if (title != null) updates['title'] = title;
    if (hypothesis != null) updates['hypothesis'] = hypothesis;
    if (suggestedAction != null) updates['suggested_action'] = suggestedAction;
    if (status != null) updates['status'] = status;
    if (feedbackText != null) updates['feedback_text'] = feedbackText;
    if (focusAreaId != null) updates['focus_area_id'] = focusAreaId;
    if (patternId != null) updates['pattern_id'] = patternId;
    if (feedbackPatternId != null) {
      updates['feedback_pattern_id'] = feedbackPatternId;
    }
    if (iconAssetId != null) updates['icon_asset_id'] = iconAssetId;
    if (plannedFrequency != null) {
      updates['planned_frequency'] = plannedFrequency;
    }
    if (plannedDurationMinutes != null) {
      updates['planned_duration_minutes'] = plannedDurationMinutes;
    }
    if (plannedTotalDays != null) {
      updates['planned_total_days'] = plannedTotalDays;
    }

    await db.update(
      'life_experiments',
      updates,
      where: 'id = ?',
      whereArgs: [experimentId],
    );
    final updated = await getById(experimentId);
    if (updated != null) {
      final eventType = status != null && status != before?.status
          ? 'status_changed'
          : 'details_updated';
      await _recordLifecycleEvent(
        experiment: updated,
        eventType: eventType,
        statusFrom: before?.status,
        statusTo: updated.status,
        payload: {
          if (title != null) 'title_changed': true,
          if (hypothesis != null) 'hypothesis_changed': true,
          if (suggestedAction != null) 'suggested_action_changed': true,
          if (feedbackText != null) 'feedback_text': feedbackText,
        },
      );
      await _writeExperimentTraceLinks(updated);
      await refreshRollup(updated.id);
      await LocalCacheInvalidationRepository(localDatabase)
          .markExperimentChanged(
        weekStart: updated.sourceWeekStart,
        eventDate: now,
        reason: eventType,
      );
    }
    return updated;
  }

  Future<void> deleteExperiment(String experimentId) async {
    final experiment = await getById(experimentId);
    if (experiment == null) return;

    final db = await localDatabase.database;
    final feedbacks = await listFeedbacks(experimentId: experimentId);
    final eventDate =
        DateTime.tryParse(experiment.sourceWeekStart) ?? DateTime.now();
    final traceRepository = LocalTraceLinkRepository(localDatabase);
    for (final feedback in feedbacks) {
      await traceRepository.markInactiveForSource(
        sourceType: 'life_experiment_feedback',
        sourceId: feedback.id,
      );
    }
    await traceRepository.markInactiveForSource(
      sourceType: 'life_experiment',
      sourceId: experimentId,
    );
    await traceRepository.markInactiveForSource(
      sourceType: 'life_experiment_rollup',
      sourceId: experimentId,
    );
    await traceRepository.markInactiveForTarget(
      targetType: 'life_experiment',
      targetId: experimentId,
    );

    await db.transaction((txn) async {
      await txn.delete(
        'life_experiment_feedback',
        where: 'experiment_id = ?',
        whereArgs: [experimentId],
      );
      await txn.delete(
        'life_experiments',
        where: 'id = ?',
        whereArgs: [experimentId],
      );
      await txn.delete(
        'life_experiment_rollups',
        where: 'experiment_id = ?',
        whereArgs: [experimentId],
      );
    });
    await LocalCacheInvalidationRepository(localDatabase).markExperimentChanged(
      weekStart: experiment.sourceWeekStart,
      eventDate: eventDate,
      reason: 'life_experiment_deleted',
    );
  }

  Future<void> deleteFeedback(String feedbackId) async {
    final db = await localDatabase.database;
    final rows = await db.query(
      'life_experiment_feedback',
      where: 'id = ?',
      whereArgs: [feedbackId],
      limit: 1,
    );
    if (rows.isEmpty) return;

    final row = rows.first;
    final experimentId = (row['experiment_id'] as String?) ?? '';
    final experiment = await getById(experimentId);
    if (experiment == null) return;

    final feedbackDate = DateTime.tryParse(
          (row['feedback_date'] as String?) ??
              (row['local_date'] as String?) ??
              '',
        ) ??
        DateTime.now();
    await LocalTraceLinkRepository(localDatabase).markInactiveForSource(
      sourceType: 'life_experiment_feedback',
      sourceId: feedbackId,
    );
    await db.delete(
      'life_experiment_feedback',
      where: 'id = ?',
      whereArgs: [feedbackId],
    );
    await refreshRollup(experimentId);
    await _markRollupStale(
      experimentId: experimentId,
      reason: 'life_experiment_feedback_deleted',
    );
    await LocalCacheInvalidationRepository(localDatabase).markExperimentChanged(
      weekStart: experiment.sourceWeekStart,
      eventDate: feedbackDate,
      reason: 'life_experiment_feedback_deleted',
    );
  }

  Future<LifeExperimentFeedbackModel?> updateFeedback({
    required String feedbackId,
    String? completionStatus,
    int? helpfulnessScore,
    String? feedbackText,
    int? durationMinutes,
    List<String>? conditionTags,
  }) async {
    final db = await localDatabase.database;
    final rows = await db.query(
      'life_experiment_feedback',
      where: 'id = ?',
      whereArgs: [feedbackId],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final current = _mapFeedbackRow(rows.first);
    final experiment = await getById(current.experimentId);
    if (experiment == null) return null;

    final now = DateTime.now().toUtc().toIso8601String();
    final updates = <String, Object?>{
      'updated_at': now,
      if (completionStatus != null) ...{
        'completion_status': completionStatus,
        'happened': completionStatus,
      },
      if (helpfulnessScore != null) ...{
        'helpfulness_score': helpfulnessScore,
        'effect': helpfulnessScore.toString(),
      },
      if (feedbackText != null) ...{
        'feedback_text': feedbackText,
        'comment': feedbackText,
      },
      if (durationMinutes != null) ...{
        'duration_minutes': durationMinutes,
        'actual_duration_minutes': durationMinutes,
      },
      if (conditionTags != null)
        'condition_tags_json': jsonEncode(conditionTags),
    };
    await db.update(
      'life_experiment_feedback',
      updates,
      where: 'id = ?',
      whereArgs: [feedbackId],
    );

    final updatedRows = await db.query(
      'life_experiment_feedback',
      where: 'id = ?',
      whereArgs: [feedbackId],
      limit: 1,
    );
    final updated = _mapFeedbackRow(updatedRows.first);
    await _recordLifecycleEvent(
      experiment: experiment,
      eventType: 'feedback_updated',
      statusFrom: experiment.status,
      statusTo: experiment.status,
      sourceType: 'life_experiment_feedback',
      sourceId: feedbackId,
      eventDate: updated.feedbackDate,
      payload: {
        'completion_status': updated.completionStatus,
        if (updated.helpfulnessScore != null)
          'helpfulness_score': updated.helpfulnessScore,
        if (updated.feedbackText != null) 'feedback_text': updated.feedbackText,
        if (updated.durationMinutes != null)
          'duration_minutes': updated.durationMinutes,
      },
    );
    await refreshRollup(experiment.id);
    await _markRollupStale(
      experimentId: experiment.id,
      reason: 'life_experiment_feedback_changed',
    );
    await LocalCacheInvalidationRepository(localDatabase).markExperimentChanged(
      weekStart: experiment.sourceWeekStart,
      eventDate: updated.feedbackDate,
      reason: 'life_experiment_feedback_changed',
    );
    return updated;
  }

  Future<LifeExperimentModel?> getPreviousForWeek({
    required String localUserId,
    required String beforeWeekStart,
  }) async {
    final db = await localDatabase.database;
    final rows = await db.query(
      'life_experiments',
      where: 'local_user_id = ? AND source_week_start < ?',
      whereArgs: [localUserId, beforeWeekStart],
      orderBy: 'source_week_start DESC, updated_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _mapRow(rows.first);
  }

  Future<List<LifeExperimentModel>> listRecent({
    required String localUserId,
    int limit = 100,
  }) async {
    final db = await localDatabase.database;
    final rows = await db.query(
      'life_experiments',
      where: 'local_user_id = ?',
      whereArgs: [localUserId],
      orderBy: 'source_week_start DESC, updated_at DESC',
      limit: limit,
    );
    return rows.map(_mapRow).toList();
  }

  Future<List<LifeExperimentModel>> listRecentForPeriod({
    required String localUserId,
    required String startDate,
    required String endDate,
    int limit = 100,
  }) async {
    final db = await localDatabase.database;
    final rows = await db.query(
      'life_experiments',
      where: '''
        local_user_id = ?
        AND source_week_start <= ?
        AND source_week_end >= ?
      ''',
      whereArgs: [localUserId, endDate, startDate],
      orderBy: 'source_week_start DESC, updated_at DESC',
      limit: limit,
    );
    return rows.map(_mapRow).toList();
  }

  Future<LifeExperimentModel?> getSavedForToday({
    required String localUserId,
    required DateTime today,
  }) async {
    final db = await localDatabase.database;
    final todayKey = _dateKey(today);
    final rows = await db.query(
      'life_experiments',
      where: '''
        local_user_id = ?
        AND status IN (?, ?)
        AND source_week_start <= ?
        AND source_week_end >= ?
      ''',
      whereArgs: [localUserId, 'saved', 'active', todayKey, todayKey],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _mapRow(rows.first);
  }

  Future<LifeExperimentModel> reuseForNextWeek({
    required LifeExperimentModel experiment,
    DateTime? fromDate,
    String? title,
    String? hypothesis,
    String? suggestedAction,
    String? plannedFrequency,
    int? plannedDurationMinutes,
    int? plannedTotalDays,
  }) async {
    final start = _startOfWeek((fromDate ?? DateTime.now()).add(
      const Duration(days: 7),
    ));
    final end = start.add(const Duration(days: 6));
    final now = DateTime.now().toUtc();
    final clone = LifeExperimentModel(
      id: 'exp_${_uuid.v4().replaceAll('-', '').substring(0, 12)}',
      localUserId: experiment.localUserId,
      sourceWeekStart: _dateKey(start),
      sourceWeekEnd: _dateKey(end),
      parentExperimentId: experiment.id,
      title: title ?? experiment.title,
      hypothesis: hypothesis ?? experiment.hypothesis,
      suggestedAction: suggestedAction ?? experiment.suggestedAction,
      linkedSignalCardIds: experiment.linkedSignalCardIds,
      status: 'saved',
      feedbackText: null,
      focusAreaId: experiment.focusAreaId,
      patternId: experiment.patternId,
      feedbackPatternId: experiment.feedbackPatternId,
      iconAssetId: experiment.iconAssetId,
      plannedFrequency: plannedFrequency ?? experiment.plannedFrequency,
      plannedDurationMinutes:
          plannedDurationMinutes ?? experiment.plannedDurationMinutes,
      plannedTotalDays: plannedTotalDays ?? experiment.plannedTotalDays,
      createdAt: now,
      updatedAt: now,
    );

    final db = await localDatabase.database;
    await db.insert(
      'life_experiments',
      _toRow(clone),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _recordLifecycleEvent(
      experiment: clone,
      eventType: 'continued_next_week',
      statusTo: clone.status,
      sourceType: 'life_experiment',
      sourceId: experiment.id,
    );
    await _recordLifecycleEvent(
      experiment: experiment,
      eventType: 'continued_as',
      statusFrom: experiment.status,
      statusTo: experiment.status,
      sourceType: 'life_experiment',
      sourceId: clone.id,
    );
    await _writeExperimentTraceLinks(clone);
    await _writeExperimentTraceLinks(experiment);
    await refreshRollup(clone.id);
    await refreshRollup(experiment.id);
    return clone;
  }

  Future<LifeExperimentModel> appendToCurrentWeek({
    required LifeExperimentModel experiment,
    DateTime? fromDate,
  }) async {
    final start = _startOfWeek(fromDate ?? DateTime.now());
    final end = start.add(const Duration(days: 6));
    final now = DateTime.now().toUtc();
    final clone = LifeExperimentModel(
      id: 'exp_${_uuid.v4().replaceAll('-', '').substring(0, 12)}',
      localUserId: experiment.localUserId,
      sourceWeekStart: _dateKey(start),
      sourceWeekEnd: _dateKey(end),
      parentExperimentId: experiment.id,
      title: experiment.title,
      hypothesis: experiment.hypothesis,
      suggestedAction: experiment.suggestedAction,
      linkedSignalCardIds: experiment.linkedSignalCardIds,
      status: 'saved',
      feedbackText: null,
      focusAreaId: experiment.focusAreaId,
      patternId: experiment.patternId,
      feedbackPatternId: experiment.feedbackPatternId,
      iconAssetId: experiment.iconAssetId,
      plannedFrequency: experiment.plannedFrequency,
      plannedDurationMinutes: experiment.plannedDurationMinutes,
      plannedTotalDays: experiment.plannedTotalDays,
      createdAt: now,
      updatedAt: now,
    );

    final db = await localDatabase.database;
    await db.insert(
      'life_experiments',
      _toRow(clone),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _recordLifecycleEvent(
      experiment: clone,
      eventType: 'appended_to_current_week',
      statusTo: clone.status,
      sourceType: 'life_experiment',
      sourceId: experiment.id,
    );
    await _recordLifecycleEvent(
      experiment: experiment,
      eventType: 'appended_as',
      statusFrom: experiment.status,
      statusTo: experiment.status,
      sourceType: 'life_experiment',
      sourceId: clone.id,
    );
    await _writeExperimentTraceLinks(clone);
    await _writeExperimentTraceLinks(experiment);
    await refreshRollup(clone.id);
    await refreshRollup(experiment.id);
    return clone;
  }

  Future<LifeExperimentFeedbackModel?> recordFeedback({
    required String experimentId,
    String? localUserId,
    String completionStatus = 'done',
    int? helpfulnessScore,
    String? feedbackText,
    DateTime? feedbackDate,
    List<String> conditionTags = const [],
    int? durationMinutes,
    String? timeSlot,
    String? patternId,
    String? feedbackPatternId,
    String? focusAreaId,
  }) async {
    final experiment = await getById(experimentId);
    if (experiment == null) return null;

    final db = await localDatabase.database;
    final now = DateTime.now().toUtc();
    final date = feedbackDate ?? DateTime.now();
    final feedback = LifeExperimentFeedbackModel(
      id: 'exp_fb_${_uuid.v4().replaceAll('-', '').substring(0, 12)}',
      experimentId: experimentId,
      localUserId: localUserId == null || localUserId.trim().isEmpty
          ? experiment.localUserId
          : localUserId,
      feedbackDate: date,
      localDate: _dateKey(date),
      completionStatus: completionStatus,
      helpfulnessScore: helpfulnessScore,
      feedbackText: feedbackText,
      conditionTags: conditionTags,
      durationMinutes: durationMinutes,
      timeSlot: timeSlot,
      patternId: patternId ?? experiment.patternId,
      feedbackPatternId: feedbackPatternId ?? experiment.feedbackPatternId,
      focusAreaId: focusAreaId ?? experiment.focusAreaId,
      createdAt: now,
      updatedAt: now,
    );

    await db.insert(
      'life_experiment_feedback',
      _feedbackToRow(feedback),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    final status = experiment.status.toLowerCase();
    if (status == 'suggested' || status == 'saved' || status == 'pending') {
      await updateStatus(experimentId: experimentId, status: 'active');
    }
    final latest = await getById(experimentId);
    await _recordLifecycleEvent(
      experiment: latest ?? experiment,
      eventType: 'feedback_recorded',
      statusFrom: experiment.status,
      statusTo: latest?.status ?? experiment.status,
      sourceType: 'life_experiment_feedback',
      sourceId: feedback.id,
      eventDate: date,
      payload: {
        'completion_status': completionStatus,
        if (helpfulnessScore != null) 'helpfulness_score': helpfulnessScore,
        if (feedbackText != null) 'feedback_text': feedbackText,
        if (conditionTags.isNotEmpty) 'condition_tags': conditionTags,
        if (durationMinutes != null) 'duration_minutes': durationMinutes,
        if (timeSlot != null) 'time_slot': timeSlot,
      },
    );
    await LocalTraceLinkRepository(localDatabase).upsert(
      TraceLinkInput(
        sourceType: 'life_experiment_feedback',
        sourceId: feedback.id,
        targetType: 'life_experiment',
        targetId: experimentId,
        relationType: 'feedback_for',
        localUserId: feedback.localUserId,
        metadata: {
          'completion_status': completionStatus,
          if (feedbackText != null) 'feedback_text': feedbackText,
        },
      ),
    );
    await refreshRollup(experimentId);
    await LocalCacheInvalidationRepository(localDatabase).markExperimentChanged(
      weekStart: experiment.sourceWeekStart,
      eventDate: date,
      reason: 'life_experiment_feedback_changed',
    );
    return feedback;
  }

  Future<List<Map<String, dynamic>>> listRollups({
    required String localUserId,
    int limit = 100,
  }) async {
    final db = await localDatabase.database;
    final existing = await db.query(
      'life_experiment_rollups',
      where: 'local_user_id = ?',
      whereArgs: [localUserId],
      orderBy: 'source_week_start DESC, updated_at DESC',
      limit: limit,
    );
    if (existing.isNotEmpty) {
      return existing.map((row) => row.map((k, v) => MapEntry(k, v))).toList();
    }

    final experiments =
        await listRecent(localUserId: localUserId, limit: limit);
    for (final experiment in experiments) {
      await refreshRollup(experiment.id);
    }
    final rows = await db.query(
      'life_experiment_rollups',
      where: 'local_user_id = ?',
      whereArgs: [localUserId],
      orderBy: 'source_week_start DESC, updated_at DESC',
      limit: limit,
    );
    return rows.map((row) => row.map((k, v) => MapEntry(k, v))).toList();
  }

  Future<List<Map<String, dynamic>>> listRollupsForPeriod({
    required String localUserId,
    required String startDate,
    required String endDate,
    int limit = 100,
  }) async {
    final db = await localDatabase.database;
    final existing = await db.query(
      'life_experiment_rollups',
      where: '''
        local_user_id = ?
        AND source_week_start <= ?
        AND source_week_end >= ?
      ''',
      whereArgs: [localUserId, endDate, startDate],
      orderBy: 'source_week_start DESC, updated_at DESC',
      limit: limit,
    );
    if (existing.isNotEmpty) {
      return existing.map((row) => row.map((k, v) => MapEntry(k, v))).toList();
    }

    final experiments = await listRecentForPeriod(
      localUserId: localUserId,
      startDate: startDate,
      endDate: endDate,
      limit: limit,
    );
    for (final experiment in experiments) {
      await refreshRollup(experiment.id);
    }
    final rows = await db.query(
      'life_experiment_rollups',
      where: '''
        local_user_id = ?
        AND source_week_start <= ?
        AND source_week_end >= ?
      ''',
      whereArgs: [localUserId, endDate, startDate],
      orderBy: 'source_week_start DESC, updated_at DESC',
      limit: limit,
    );
    return rows.map((row) => row.map((k, v) => MapEntry(k, v))).toList();
  }

  Future<List<Map<String, dynamic>>> listLifecycleEventsForExperiments({
    required Iterable<String> experimentIds,
  }) async {
    final ids = experimentIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) return const [];

    final db = await localDatabase.database;
    final placeholders = List.filled(ids.length, '?').join(', ');
    final rows = await db.query(
      'life_experiment_lifecycle_events',
      where: 'experiment_id IN ($placeholders)',
      whereArgs: ids,
      orderBy: 'event_date ASC, created_at ASC',
    );
    return rows.map((row) => row.map((k, v) => MapEntry(k, v))).toList();
  }

  Future<void> refreshRollup(String experimentId) async {
    final experiment = await getById(experimentId);
    if (experiment == null) return;

    final db = await localDatabase.database;
    final feedbacks = await listFeedbacks(experimentId: experimentId);
    final rootId = await _rootExperimentId(experiment);
    final lineage = await _lineageFor(experiment);
    final familyRows = await db.query(
      'life_experiments',
      columns: ['source_week_start'],
      where: '''
        local_user_id = ?
        AND (id = ? OR parent_experiment_id = ?)
      ''',
      whereArgs: [experiment.localUserId, rootId, rootId],
    );
    final activeWeekCount = {
      experiment.sourceWeekStart,
      ...familyRows
          .map((row) => (row['source_week_start'] as String?) ?? '')
          .where((value) => value.isNotEmpty),
    }.length;
    final helpfulCount = feedbacks
        .where((feedback) =>
            _isHelpfulStatus(feedback.completionStatus) ||
            (feedback.helpfulnessScore ?? 0) >= 4)
        .length;
    final notHelpfulCount = feedbacks
        .where((feedback) => _isNotHelpfulStatus(feedback.completionStatus))
        .length;
    final adjustedCount = feedbacks
        .where((feedback) =>
            feedback.completionStatus.toLowerCase().contains('adjust'))
        .length;
    final triedCount = feedbacks
        .where((feedback) => !_isSkippedStatus(feedback.completionStatus))
        .length;
    final skippedCount = feedbacks
        .where((feedback) => _isSkippedStatus(feedback.completionStatus))
        .length;
    final lastFeedbackAt = feedbacks.isEmpty
        ? null
        : feedbacks
            .map((feedback) => feedback.feedbackDate)
            .reduce((a, b) => a.isAfter(b) ? a : b)
            .toUtc()
            .toIso8601String();
    final lastEvent = await db.query(
      'life_experiment_lifecycle_events',
      columns: ['event_date'],
      where: 'experiment_id = ?',
      whereArgs: [experimentId],
      orderBy: 'event_date DESC',
      limit: 1,
    );
    final now = DateTime.now().toUtc().toIso8601String();

    await db.insert(
      'life_experiment_rollups',
      {
        'experiment_id': experiment.id,
        'local_user_id': experiment.localUserId,
        'root_experiment_id': rootId,
        'parent_experiment_id': experiment.parentExperimentId,
        'source_week_start': experiment.sourceWeekStart,
        'source_week_end': experiment.sourceWeekEnd,
        'current_status': experiment.status,
        'title': experiment.title,
        'hypothesis': experiment.hypothesis,
        'suggested_action': experiment.suggestedAction,
        'total_feedback_count': feedbacks.length,
        'tried_count': triedCount,
        'helpful_count': helpfulCount,
        'not_helpful_count': notHelpfulCount,
        'adjusted_count': adjustedCount,
        'skipped_count': skippedCount,
        'active_week_count': activeWeekCount,
        'first_started_at': experiment.createdAt?.toUtc().toIso8601String(),
        'last_feedback_at': lastFeedbackAt,
        'last_event_at': lastEvent.isEmpty
            ? experiment.updatedAt?.toUtc().toIso8601String()
            : lastEvent.first['event_date'] as String?,
        'lineage_json': jsonEncode(lineage),
        'dirty': 0,
        'is_stale': 0,
        'stale_reason': null,
        'invalidated_at': null,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _writeRollupTraceLinks(
      experiment: experiment,
      rootId: rootId,
      lineage: lineage,
    );
  }

  Future<List<LifeExperimentFeedbackModel>> listFeedbacks({
    required String experimentId,
  }) async {
    final db = await localDatabase.database;
    final rows = await db.query(
      'life_experiment_feedback',
      where: 'experiment_id = ?',
      whereArgs: [experimentId],
      orderBy: 'feedback_date ASC, created_at ASC',
    );
    return rows.map(_mapFeedbackRow).toList();
  }

  Future<List<LifeExperimentFeedbackModel>> listFeedbacksForExperiments({
    required Iterable<String> experimentIds,
  }) async {
    final ids = experimentIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) return const [];

    final db = await localDatabase.database;
    final placeholders = List.filled(ids.length, '?').join(', ');
    final rows = await db.query(
      'life_experiment_feedback',
      where: 'experiment_id IN ($placeholders)',
      whereArgs: ids,
      orderBy: 'feedback_date ASC, created_at ASC',
    );
    return rows.map(_mapFeedbackRow).toList();
  }

  Future<void> linkSignalCards({
    required String experimentId,
    required Iterable<String> signalCardIds,
  }) async {
    final ids = signalCardIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (ids.isEmpty) return;

    final db = await localDatabase.database;
    final placeholders = List.filled(ids.length, '?').join(', ');
    await db.update(
      'signal_cards',
      {
        'linked_experiment_id': experimentId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id IN ($placeholders) OR signal_card_id IN ($placeholders)',
      whereArgs: [...ids, ...ids],
    );
  }

  Future<void> _markRollupStale({
    required String experimentId,
    required String reason,
  }) async {
    final db = await localDatabase.database;
    await db.update(
      'life_experiment_rollups',
      {
        'dirty': 1,
        'is_stale': 1,
        'stale_reason': reason,
        'invalidated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'experiment_id = ?',
      whereArgs: [experimentId],
    );
  }

  Future<void> _writeExperimentTraceLinks(
    LifeExperimentModel experiment,
  ) async {
    final links = <TraceLinkInput>[
      for (final signalId in experiment.linkedSignalCardIds)
        TraceLinkInput(
          sourceType: 'life_experiment',
          sourceId: experiment.id,
          targetType: 'signal_card',
          targetId: signalId,
          relationType: 'evidence_signal',
          localUserId: experiment.localUserId,
        ),
      if (experiment.parentExperimentId != null &&
          experiment.parentExperimentId!.trim().isNotEmpty)
        TraceLinkInput(
          sourceType: 'life_experiment',
          sourceId: experiment.id,
          targetType: 'life_experiment',
          targetId: experiment.parentExperimentId!,
          relationType: 'continued_from',
          localUserId: experiment.localUserId,
        ),
    ];
    await LocalTraceLinkRepository(localDatabase).replaceForSource(
      sourceType: 'life_experiment',
      sourceId: experiment.id,
      links: links,
    );
  }

  Future<void> _writeRollupTraceLinks({
    required LifeExperimentModel experiment,
    required String rootId,
    required List<Map<String, dynamic>> lineage,
  }) async {
    final links = <TraceLinkInput>[
      TraceLinkInput(
        sourceType: 'life_experiment_rollup',
        sourceId: experiment.id,
        targetType: 'life_experiment',
        targetId: experiment.id,
        relationType: 'summarizes',
        localUserId: experiment.localUserId,
      ),
      if (rootId != experiment.id)
        TraceLinkInput(
          sourceType: 'life_experiment_rollup',
          sourceId: experiment.id,
          targetType: 'life_experiment',
          targetId: rootId,
          relationType: 'root_experiment',
          localUserId: experiment.localUserId,
        ),
      for (final item in lineage)
        if ((item['id'] as String?) != null &&
            (item['id'] as String?) != experiment.id)
          TraceLinkInput(
            sourceType: 'life_experiment_rollup',
            sourceId: experiment.id,
            targetType: 'life_experiment',
            targetId: item['id'] as String,
            relationType: 'lineage_member',
            localUserId: experiment.localUserId,
          ),
    ];
    await LocalTraceLinkRepository(localDatabase).replaceForSource(
      sourceType: 'life_experiment_rollup',
      sourceId: experiment.id,
      links: links,
    );
  }

  Future<void> _recordLifecycleEvent({
    required LifeExperimentModel experiment,
    required String eventType,
    String? statusFrom,
    String? statusTo,
    String? sourceType,
    String? sourceId,
    DateTime? eventDate,
    Map<String, dynamic> payload = const {},
  }) async {
    final db = await localDatabase.database;
    final date = eventDate ?? DateTime.now();
    final eventId =
        'exp_evt_${_uuid.v4().replaceAll('-', '').substring(0, 12)}';
    await db.insert(
      'life_experiment_lifecycle_events',
      {
        'id': eventId,
        'experiment_id': experiment.id,
        'local_user_id': experiment.localUserId,
        'event_type': eventType,
        'event_date': date.toUtc().toIso8601String(),
        'local_date': _dateKey(date),
        'source_type': sourceType,
        'source_id': sourceId,
        'status_from': statusFrom,
        'status_to': statusTo,
        'payload_json': jsonEncode(payload),
        'created_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String> _rootExperimentId(LifeExperimentModel experiment) async {
    var current = experiment;
    final seen = <String>{current.id};
    while (current.parentExperimentId != null &&
        current.parentExperimentId!.trim().isNotEmpty) {
      final parent = await getById(current.parentExperimentId!);
      if (parent == null || seen.contains(parent.id)) break;
      seen.add(parent.id);
      current = parent;
    }
    return current.id;
  }

  Future<List<Map<String, dynamic>>> _lineageFor(
    LifeExperimentModel experiment,
  ) async {
    final items = <LifeExperimentModel>[];
    var current = experiment;
    final seen = <String>{};
    while (!seen.contains(current.id)) {
      seen.add(current.id);
      items.add(current);
      final parentId = current.parentExperimentId;
      if (parentId == null || parentId.trim().isEmpty) break;
      final parent = await getById(parentId);
      if (parent == null) break;
      current = parent;
    }
    return items.reversed
        .map(
          (item) => {
            'id': item.id,
            'parent_experiment_id': item.parentExperimentId,
            'source_week_start': item.sourceWeekStart,
            'source_week_end': item.sourceWeekEnd,
            'status': item.status,
            'title': item.title,
          },
        )
        .toList();
  }

  bool _isHelpfulStatus(String status) {
    final value = status.toLowerCase();
    return value.contains('helpful') &&
        !value.contains('not_helpful') &&
        !value.contains('not helpful');
  }

  bool _isNotHelpfulStatus(String status) {
    final value = status.toLowerCase();
    return value.contains('not_helpful') || value.contains('not helpful');
  }

  bool _isSkippedStatus(String status) {
    final value = status.toLowerCase();
    return value.contains('skip') ||
        value == 'no' ||
        value == 'not_tried' ||
        value == 'not_suitable_today' ||
        value == 'not suitable today';
  }

  LifeExperimentModel _mapRow(Map<String, Object?> row) {
    return LifeExperimentModel(
      id: (row['id'] as String?) ?? '',
      localUserId: (row['local_user_id'] as String?) ?? '',
      sourceWeekStart: (row['source_week_start'] as String?) ?? '',
      sourceWeekEnd: (row['source_week_end'] as String?) ?? '',
      parentExperimentId: row['parent_experiment_id'] as String?,
      title: (row['title'] as String?) ?? '',
      hypothesis: (row['hypothesis'] as String?) ?? '',
      suggestedAction: (row['suggested_action'] as String?) ?? '',
      linkedSignalCardIds: _decodeStringList(
        row['linked_signal_card_ids_json'],
      ),
      status: (row['status'] as String?) ?? 'suggested',
      feedbackText: row['feedback_text'] as String?,
      focusAreaId: row['focus_area_id'] as String?,
      patternId: row['pattern_id'] as String?,
      feedbackPatternId: row['feedback_pattern_id'] as String?,
      iconAssetId: row['icon_asset_id'] as String?,
      plannedFrequency: row['planned_frequency'] as String?,
      plannedDurationMinutes: _toInt(row['planned_duration_minutes']),
      plannedTotalDays: _toInt(row['planned_total_days']),
      originCandidateId: row['origin_candidate_id'] as String?,
      adoptedAt: DateTime.tryParse((row['adopted_at'] as String?) ?? ''),
      progressStartDate: row['progress_start_date'] as String?,
      progressEndDate: row['progress_end_date'] as String?,
      sourceChanged: _toInt(row['source_changed']) == 1,
      sourceChangeReason: row['source_change_reason'] as String?,
      createdAt: DateTime.tryParse((row['created_at'] as String?) ?? ''),
      updatedAt: DateTime.tryParse((row['updated_at'] as String?) ?? ''),
    );
  }

  Map<String, Object?> _toRow(LifeExperimentModel experiment) {
    return {
      'id': experiment.id,
      'local_user_id': experiment.localUserId,
      'source_week_start': experiment.sourceWeekStart,
      'source_week_end': experiment.sourceWeekEnd,
      'parent_experiment_id': experiment.parentExperimentId,
      'title': experiment.title,
      'hypothesis': experiment.hypothesis,
      'suggested_action': experiment.suggestedAction,
      'linked_signal_card_ids_json': jsonEncode(
        experiment.linkedSignalCardIds,
      ),
      'status': experiment.status,
      'feedback_text': experiment.feedbackText,
      'focus_area_id': experiment.focusAreaId,
      'pattern_id': experiment.patternId,
      'feedback_pattern_id': experiment.feedbackPatternId,
      'icon_asset_id': experiment.iconAssetId,
      'planned_frequency': experiment.plannedFrequency,
      'planned_duration_minutes': experiment.plannedDurationMinutes,
      'planned_total_days': experiment.plannedTotalDays,
      'origin_candidate_id': experiment.originCandidateId,
      'adopted_at': experiment.adoptedAt?.toUtc().toIso8601String(),
      'progress_start_date': experiment.progressStartDate,
      'progress_end_date': experiment.progressEndDate,
      'source_changed': experiment.sourceChanged ? 1 : 0,
      'source_change_reason': experiment.sourceChangeReason,
      'created_at': experiment.createdAt?.toUtc().toIso8601String() ??
          DateTime.now().toUtc().toIso8601String(),
      'updated_at': experiment.updatedAt?.toUtc().toIso8601String() ??
          DateTime.now().toUtc().toIso8601String(),
    };
  }

  LifeExperimentFeedbackModel _mapFeedbackRow(Map<String, Object?> row) {
    return LifeExperimentFeedbackModel.fromJson(
      row.map((key, value) => MapEntry(key, value)),
    );
  }

  Map<String, Object?> _feedbackToRow(LifeExperimentFeedbackModel feedback) {
    final created = feedback.createdAt?.toUtc().toIso8601String() ??
        DateTime.now().toUtc().toIso8601String();
    final updated = feedback.updatedAt?.toUtc().toIso8601String() ?? created;
    return {
      'id': feedback.id,
      'experiment_id': feedback.experimentId,
      'feedback_date': feedback.feedbackDate.toUtc().toIso8601String(),
      'happened': feedback.completionStatus,
      'trigger_context': feedback.timeSlot,
      'actual_duration_minutes': feedback.durationMinutes,
      'effect': feedback.helpfulnessScore?.toString(),
      'comment': feedback.feedbackText,
      'local_user_id': feedback.localUserId,
      'local_date': feedback.localDate,
      'completion_status': feedback.completionStatus,
      'helpfulness_score': feedback.helpfulnessScore,
      'feedback_text': feedback.feedbackText,
      'condition_tags_json': jsonEncode(feedback.conditionTags),
      'duration_minutes': feedback.durationMinutes,
      'time_slot': feedback.timeSlot,
      'pattern_id': feedback.patternId,
      'feedback_pattern_id': feedback.feedbackPatternId,
      'focus_area_id': feedback.focusAreaId,
      'created_at': created,
      'updated_at': updated,
    };
  }

  List<String> _decodeStringList(Object? raw) {
    if (raw == null) return const [];
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded
              .map((e) => e?.toString().trim() ?? '')
              .where((e) => e.isNotEmpty)
              .toList();
        }
      } catch (_) {}
    }
    return const [];
  }

  int? _toInt(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  DateTime _startOfWeek(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
