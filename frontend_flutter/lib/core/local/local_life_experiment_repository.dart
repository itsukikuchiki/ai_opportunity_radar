import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/weekly_models.dart';
import '../models/experiment_evaluation_models.dart';
import '../policies/planning_content_edit_policy.dart';
import 'local_cache_invalidation_repository.dart';
import 'local_database.dart';
import 'local_plan_content_version_repository.dart';
import 'local_trace_link_repository.dart';

class _PlanProjectionMissing implements Exception {
  const _PlanProjectionMissing();
}

class LocalLifeExperimentRepository {
  final LocalDatabase localDatabase;
  final DateTime Function() nowLoader;
  late final LocalPlanContentVersionRepository planContentVersionRepository;
  final Uuid _uuid = const Uuid();

  LocalLifeExperimentRepository(
    this.localDatabase, {
    DateTime Function()? nowLoader,
    LocalPlanContentVersionRepository? planContentVersionRepository,
  }) : nowLoader = nowLoader ?? DateTime.now {
    this.planContentVersionRepository = planContentVersionRepository ??
        LocalPlanContentVersionRepository(localDatabase);
  }

  /// Storage helpers used by the candidate planner so creating several formal
  /// experiments and binding all selected candidates can share one SQLite
  /// transaction. Callers must still run [ensureAdoptionArtifacts] after the
  /// transaction commits.
  Map<String, Object?> toStorageRow(LifeExperimentModel experiment) =>
      _toRow(experiment);

  LifeExperimentModel fromStorageRow(Map<String, Object?> row) => _mapRow(row);

  Future<void> ensureAdoptionArtifacts(LifeExperimentModel experiment) async {
    await _ensureInitialContentVersion(experiment);
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

  Future<LifeExperimentModel?> getById(
    String experimentId, {
    String? selectedLocalDate,
  }) async {
    final db = await localDatabase.database;
    final rows = await db.query(
      'life_experiments',
      where: 'id = ?',
      whereArgs: [experimentId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return selectedLocalDate == null
        ? _mapRow(rows.first)
        : _mapRowForDate(rows.first, selectedLocalDate);
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
    String? selectedLocalDate,
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
    return selectedLocalDate == null
        ? _mapRow(rows.first)
        : _mapRowForDate(rows.first, selectedLocalDate);
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
    int minimumObservationDays = 3,
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
    final now = nowLoader().toUtc();
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
      minimumObservationDays: _normalizeMinimumObservationDays(
        minimumObservationDays,
      ),
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
    if (_hasAdoptionEvidence(experiment)) {
      await _ensureInitialContentVersion(experiment);
    }
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
    int? minimumObservationDays,
  }) async {
    final db = await localDatabase.database;
    final before = await getById(experimentId);
    if (before == null) return null;
    final changesPlanningContent = title != null ||
        hypothesis != null ||
        suggestedAction != null ||
        focusAreaId != null ||
        patternId != null ||
        feedbackPatternId != null ||
        iconAssetId != null ||
        plannedFrequency != null ||
        plannedDurationMinutes != null ||
        plannedTotalDays != null;
    // The minimum observation threshold is future planning content too. It
    // can change only while the same plan content is still editable.
    final changesObservationThreshold = minimumObservationDays != null;
    final changesAnyPlanningContent =
        changesPlanningContent || changesObservationThreshold;
    if (changesAnyPlanningContent &&
        !PlanningContentEditPolicy.canEditLifeExperiment(
          before,
          now: nowLoader(),
        )) {
      return null;
    }
    String? effectiveDate;
    if (changesAnyPlanningContent) {
      effectiveDate = await _lifeExperimentEditEffectiveDate(before);
      if (effectiveDate == null) return null;
    }
    final now = nowLoader().toUtc();
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
    if (minimumObservationDays != null) {
      updates['minimum_observation_days'] =
          _normalizeMinimumObservationDays(minimumObservationDays);
    }

    late final LifeExperimentModel updated;
    try {
      updated = await db.transaction((txn) async {
        if (changesAnyPlanningContent) {
          await planContentVersionRepository.ensureInitialWithExecutor(
            txn,
            localUserId: before.localUserId,
            objectKind: PlanContentObjectKind.goal,
            objectId: before.id,
            effectiveFromLocalDate: _lifeExperimentStartDate(before),
            content: _lifeExperimentContent(before),
            createdAt: before.createdAt,
          );
          await planContentVersionRepository.appendWithExecutor(
            txn,
            localUserId: before.localUserId,
            objectKind: PlanContentObjectKind.goal,
            objectId: before.id,
            effectiveFromLocalDate: effectiveDate!,
            content: _lifeExperimentContent(
              before,
              title: title,
              hypothesis: hypothesis,
              suggestedAction: suggestedAction,
              focusAreaId: focusAreaId,
              patternId: patternId,
              feedbackPatternId: feedbackPatternId,
              iconAssetId: iconAssetId,
              plannedFrequency: plannedFrequency,
              plannedDurationMinutes: plannedDurationMinutes,
              plannedTotalDays: plannedTotalDays,
              minimumObservationDays: minimumObservationDays,
            ),
            createdAt: now,
          );
        }
        final affected = await txn.update(
          'life_experiments',
          updates,
          where: 'id = ?',
          whereArgs: [experimentId],
        );
        if (affected == 0) throw const _PlanProjectionMissing();
        final updatedRows = await txn.query(
          'life_experiments',
          where: 'id = ?',
          whereArgs: [experimentId],
          limit: 1,
        );
        if (updatedRows.isEmpty) throw const _PlanProjectionMissing();
        final projected = _mapRow(updatedRows.first);
        if (!changesAnyPlanningContent && _hasAdoptionEvidence(projected)) {
          await planContentVersionRepository.ensureInitialWithExecutor(
            txn,
            localUserId: projected.localUserId,
            objectKind: PlanContentObjectKind.goal,
            objectId: projected.id,
            effectiveFromLocalDate: _lifeExperimentStartDate(projected),
            content: _lifeExperimentContent(projected),
            createdAt: projected.createdAt,
          );
        }
        return projected;
      });
    } on _PlanProjectionMissing {
      return null;
    }
    final eventType = status != null && status != before.status
        ? 'status_changed'
        : 'details_updated';
    await _recordLifecycleEvent(
      experiment: updated,
      eventType: eventType,
      statusFrom: before.status,
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
    await LocalCacheInvalidationRepository(localDatabase).markExperimentChanged(
      weekStart: updated.sourceWeekStart,
      eventDate: now,
      reason: eventType,
    );
    return updated;
  }

  Future<void> deleteExperiment(String experimentId) async {
    final experiment = await getById(experimentId);
    if (experiment == null) return;

    final db = await localDatabase.database;
    // Deletion must clean traces for invalidated feedback too. User-facing
    // reads and rollups use [listFeedbacks], which intentionally hides them.
    final feedbacks = await _listAllFeedbacks(experimentId: experimentId);
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
        'plan_content_versions',
        where: 'local_user_id = ? AND object_kind = ? AND object_id = ?',
        whereArgs: [
          experiment.localUserId,
          PlanContentObjectKind.goal.storageValue,
          experimentId,
        ],
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
    throw UnsupportedError('life_experiment_feedback_is_append_only');
  }

  Future<LifeExperimentFeedbackModel?> updateFeedback({
    required String feedbackId,
    String? completionStatus,
    int? helpfulnessScore,
    String? feedbackText,
    int? durationMinutes,
    List<String>? conditionTags,
  }) async {
    throw UnsupportedError('life_experiment_feedback_is_append_only');
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
    int offset = 0,
  }) async {
    final db = await localDatabase.database;
    final rows = await db.query(
      'life_experiments',
      where: 'local_user_id = ?',
      whereArgs: [localUserId],
      orderBy: 'source_week_start DESC, updated_at DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(_mapRow).toList();
  }

  /// Paged all-time archive of adopted goals.
  ///
  /// Current rows carry explicit adoption evidence. The status branch keeps
  /// legacy accepted/saved goals visible after migrating older databases.
  /// Suggested/generated rows never enter the archive.
  Future<List<LifeExperimentModel>> listAdoptedGoals({
    required String localUserId,
    int limit = 20,
    int offset = 0,
  }) async {
    final db = await localDatabase.database;
    final rows = await db.query(
      'life_experiments',
      where: '''
        local_user_id = ?
        AND TRIM(title) != ''
        AND TRIM(status) != ''
        AND LOWER(status) NOT LIKE '%suggest%'
        AND LOWER(status) NOT LIKE '%candidate%'
        AND LOWER(status) NOT LIKE '%generated%'
        AND LOWER(status) NOT LIKE '%gated%'
        AND LOWER(status) NOT LIKE '%dismiss%'
        AND (
          adopted_at IS NOT NULL
          OR (origin_candidate_id IS NOT NULL AND TRIM(origin_candidate_id) != '')
          OR LOWER(status) IN (
            'accepted', 'saved', 'active', 'adjusted', 'done', 'completed',
            'paused', 'stopped', 'archived', 'effective', 'not_effective'
          )
        )
      ''',
      whereArgs: [localUserId],
      orderBy:
          'source_week_start DESC, COALESCE(adopted_at, updated_at, created_at) DESC',
      limit: limit,
      offset: offset,
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
    final result = <LifeExperimentModel>[];
    for (final row in rows) {
      result.add(await _mapRowForDate(row, endDate));
    }
    return result;
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
        AND COALESCE(progress_start_date, source_week_start) <= ?
        AND (
          progress_end_date IS NULL
          OR TRIM(progress_end_date) = ''
          OR progress_end_date >= ?
        )
      ''',
      whereArgs: [localUserId, 'saved', 'active', todayKey, todayKey],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _mapRowForDate(rows.first, todayKey);
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
    int? minimumObservationDays,
  }) async {
    final start = _startOfWeek((fromDate ?? nowLoader()).add(
      const Duration(days: 7),
    ));
    final displayWeekEnd = start.add(const Duration(days: 6));
    final resolvedPlannedTotalDays =
        plannedTotalDays ?? experiment.plannedTotalDays;
    final normalizedPlannedTotalDays =
        resolvedPlannedTotalDays != null && resolvedPlannedTotalDays > 0
            ? resolvedPlannedTotalDays
            : null;
    final progressEnd = normalizedPlannedTotalDays == null
        ? null
        : start.add(Duration(days: normalizedPlannedTotalDays - 1));
    final now = nowLoader().toUtc();
    final db = await localDatabase.database;
    final proposed = LifeExperimentModel(
      id: 'exp_${_uuid.v4().replaceAll('-', '').substring(0, 12)}',
      localUserId: experiment.localUserId,
      sourceWeekStart: _dateKey(start),
      sourceWeekEnd: _dateKey(displayWeekEnd),
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
      plannedTotalDays: normalizedPlannedTotalDays,
      minimumObservationDays: minimumObservationDays == null
          ? experiment.minimumObservationDays
          : _normalizeMinimumObservationDays(minimumObservationDays),
      adoptedAt: now,
      progressStartDate: _dateKey(start),
      progressEndDate: progressEnd == null ? null : _dateKey(progressEnd),
      createdAt: now,
      updatedAt: now,
    );
    final persisted = await db.transaction<(LifeExperimentModel, bool)>(
      (txn) async {
        final existingRows = await txn.query(
          'life_experiments',
          where: '''
            local_user_id = ?
            AND parent_experiment_id = ?
            AND source_week_start = ?
          ''',
          whereArgs: [
            experiment.localUserId,
            experiment.id,
            _dateKey(start),
          ],
          orderBy: 'updated_at DESC',
          limit: 1,
        );
        if (existingRows.isNotEmpty) {
          return (_mapRow(existingRows.first), false);
        }
        await txn.insert(
          'life_experiments',
          _toRow(proposed),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        return (proposed, true);
      },
    );
    final clone = persisted.$1;
    if (!persisted.$2) return clone;

    await _ensureInitialContentVersion(clone);
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
    await LocalCacheInvalidationRepository(localDatabase).markExperimentChanged(
      weekStart: clone.sourceWeekStart,
      eventDate: start,
      reason: 'life_experiment_continued_next_week',
    );
    return clone;
  }

  Future<LifeExperimentModel> appendToCurrentWeek({
    required LifeExperimentModel experiment,
    DateTime? fromDate,
  }) async {
    final start = _startOfWeek(fromDate ?? nowLoader());
    final end = start.add(const Duration(days: 6));
    final now = nowLoader().toUtc();
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
      minimumObservationDays: experiment.minimumObservationDays,
      createdAt: now,
      updatedAt: now,
    );

    final db = await localDatabase.database;
    await db.insert(
      'life_experiments',
      _toRow(clone),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _ensureInitialContentVersion(clone);
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
    bool enforceProgressWindow = false,
  }) async {
    final experiment = await getById(experimentId);
    if (experiment == null) return null;

    final db = await localDatabase.database;
    final now = DateTime.now().toUtc();
    final date = feedbackDate ?? DateTime.now();
    if (enforceProgressWindow &&
        !_canRecordFeedbackOn(experiment: experiment, date: date)) {
      return null;
    }
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
      conflictAlgorithm: ConflictAlgorithm.abort,
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

  /// Appends a period-level goal outcome. This is deliberately separate from
  /// daily completion feedback: completing days is an observation count, not
  /// proof that the goal helped.
  Future<LifeExperimentOutcomeReviewModel?> recordOutcomeReview({
    required String experimentId,
    required String outcomeResult,
    required String burden,
    String reviewType = GoalReviewType.wholeRound,
    bool userConfirmedRoundEnd = false,
    String? reviewNote,
    DateTime? reviewedAt,
  }) async {
    if (!GoalOutcomeResult.values.contains(outcomeResult)) {
      throw ArgumentError.value(
        outcomeResult,
        'outcomeResult',
        'unsupported_goal_outcome',
      );
    }
    if (!EvaluationEffort.values.contains(burden)) {
      throw ArgumentError.value(
        burden,
        'burden',
        'unsupported_goal_burden',
      );
    }
    if (!GoalReviewType.values.contains(reviewType)) {
      throw ArgumentError.value(
        reviewType,
        'reviewType',
        'unsupported_goal_review_type',
      );
    }
    final experiment = await getById(experimentId);
    if (experiment == null) return null;
    final date = reviewedAt ?? nowLoader();
    final feedbacks = await listFeedbacks(experimentId: experimentId);
    final effective = _latestFeedbackPerLocalDate(feedbacks);
    final completedDays = effective
        .where((feedback) => _isCompletedStatus(feedback.completionStatus))
        .length;
    final minimumDays = experiment.minimumObservationDays;
    final metMinimumObservationDays = completedDays >= minimumDays;
    final reachedExplicitPeriodEnd =
        _hasReachedExplicitProgressEnd(experiment, date);
    final terminalLifecycle = _isTerminalExperimentStatus(experiment.status);
    if (reviewType == GoalReviewType.wholeRound) {
      final mayEndRound = metMinimumObservationDays ||
          reachedExplicitPeriodEnd ||
          terminalLifecycle ||
          userConfirmedRoundEnd;
      if (!mayEndRound) {
        throw StateError(
          'goal_whole_round_review_requires_minimum_or_round_end:'
          '$completedDays/$minimumDays',
        );
      }
      // Reaching the period boundary (or explicitly ending early) makes a
      // whole-round review writable, but it does not manufacture enough
      // observations for a directional outcome.
      if (!metMinimumObservationDays &&
          outcomeResult != GoalOutcomeResult.unclear) {
        throw StateError(
          'goal_whole_round_review_below_minimum_requires_unclear:'
          '$completedDays/$minimumDays',
        );
      }
    }
    if (reviewType == GoalReviewType.weekly) {
      final weekStart = _startOfWeek(date);
      final weekEnd = weekStart.add(const Duration(days: 6));
      final hasWeeklyFeedback = feedbacks.any((feedback) {
        final day = DateTime.tryParse(feedback.localDate);
        if (day == null) return false;
        final local = DateTime(day.year, day.month, day.day);
        return !local.isBefore(weekStart) && !local.isAfter(weekEnd);
      });
      if (!hasWeeklyFeedback) {
        throw StateError('goal_weekly_review_requires_feedback_in_week');
      }
      if (!metMinimumObservationDays &&
          outcomeResult != GoalOutcomeResult.unclear) {
        throw StateError(
          'goal_weekly_review_below_minimum_requires_unclear:'
          '$completedDays/$minimumDays',
        );
      }
    }
    final createdAt = nowLoader().toUtc();
    final eventId = await _recordLifecycleEvent(
      experiment: experiment,
      eventType: 'outcome_reviewed',
      statusFrom: experiment.status,
      statusTo: experiment.status,
      eventDate: date,
      payload: {
        'outcome_result': outcomeResult,
        'review_type': reviewType,
        'burden': burden,
        if (reviewNote != null && reviewNote.trim().isNotEmpty)
          'review_note': reviewNote.trim(),
        'completed_days_at_review': completedDays,
        'minimum_observation_days': minimumDays,
        'minimum_observation_days_met': metMinimumObservationDays,
        if (reviewType == GoalReviewType.wholeRound)
          'round_end_context': {
            'explicit_period_end_reached': reachedExplicitPeriodEnd,
            'terminal_lifecycle': terminalLifecycle,
            'user_confirmed_round_end': userConfirmedRoundEnd,
          },
      },
      createdAt: createdAt,
    );
    await refreshRollup(experimentId);
    await LocalCacheInvalidationRepository(localDatabase).markExperimentChanged(
      weekStart: experiment.sourceWeekStart,
      eventDate: date,
      reason: 'life_experiment_outcome_reviewed',
    );
    return LifeExperimentOutcomeReviewModel(
      id: eventId,
      experimentId: experimentId,
      localUserId: experiment.localUserId,
      reviewedAt: date,
      localDate: _dateKey(date),
      outcomeResult: outcomeResult,
      reviewType: reviewType,
      burden: burden,
      reviewNote:
          reviewNote?.trim().isEmpty == true ? null : reviewNote?.trim(),
      completedDaysAtReview: completedDays,
      minimumObservationDays: minimumDays,
      createdAt: createdAt,
    );
  }

  Future<List<LifeExperimentOutcomeReviewModel>> listOutcomeReviews({
    required String experimentId,
    String? reviewType,
  }) async {
    if (reviewType != null && !GoalReviewType.values.contains(reviewType)) {
      throw ArgumentError.value(
        reviewType,
        'reviewType',
        'unsupported_goal_review_type',
      );
    }
    final db = await localDatabase.database;
    final rows = await db.query(
      'life_experiment_lifecycle_events',
      where: reviewType == null
          ? 'experiment_id = ? AND event_type = ?'
          : 'experiment_id = ? AND event_type = ? AND review_type = ?',
      whereArgs: [
        experimentId,
        'outcome_reviewed',
        if (reviewType != null) reviewType,
      ],
      orderBy: 'event_date ASC, created_at ASC, id ASC',
    );
    return rows.map((row) {
      final payload = _decodeMap(row['payload_json']);
      return LifeExperimentOutcomeReviewModel.fromLifecycleRow(
        row.map((key, value) => MapEntry(key, value)),
        payload,
      );
    }).toList(growable: false);
  }

  Future<LifeExperimentOutcomeReviewModel?> recordWeeklyReview({
    required String experimentId,
    required String outcomeResult,
    required String burden,
    String? reviewNote,
    DateTime? reviewedAt,
  }) {
    return recordOutcomeReview(
      experimentId: experimentId,
      outcomeResult: outcomeResult,
      burden: burden,
      reviewType: GoalReviewType.weekly,
      reviewNote: reviewNote,
      reviewedAt: reviewedAt,
    );
  }

  Future<LifeExperimentOutcomeReviewModel?> recordWholeRoundReview({
    required String experimentId,
    required String outcomeResult,
    required String burden,
    bool userConfirmedRoundEnd = false,
    String? reviewNote,
    DateTime? reviewedAt,
  }) {
    return recordOutcomeReview(
      experimentId: experimentId,
      outcomeResult: outcomeResult,
      burden: burden,
      reviewType: GoalReviewType.wholeRound,
      userConfirmedRoundEnd: userConfirmedRoundEnd,
      reviewNote: reviewNote,
      reviewedAt: reviewedAt,
    );
  }

  bool _hasReachedExplicitProgressEnd(
    LifeExperimentModel experiment,
    DateTime reviewedAt,
  ) {
    final end = DateTime.tryParse(experiment.progressEndDate?.trim() ?? '');
    if (end == null) return false;
    final localReview = DateTime(
      reviewedAt.year,
      reviewedAt.month,
      reviewedAt.day,
    );
    final localEnd = DateTime(end.year, end.month, end.day);
    return !localReview.isBefore(localEnd);
  }

  bool _isTerminalExperimentStatus(String status) {
    final lifecycle = status.trim().toLowerCase();
    return lifecycle.contains('stop') ||
        lifecycle.contains('archive') ||
        lifecycle.contains('complete') ||
        lifecycle.contains('done') ||
        lifecycle.contains('finish') ||
        lifecycle.contains('dismiss') ||
        lifecycle == 'effective' ||
        lifecycle == 'not_effective';
  }

  bool _canRecordFeedbackOn({
    required LifeExperimentModel experiment,
    required DateTime date,
  }) {
    final lifecycle = experiment.status.trim().toLowerCase();
    if (lifecycle.contains('pause') ||
        lifecycle.contains('stop') ||
        lifecycle.contains('skip') ||
        lifecycle.contains('archive') ||
        lifecycle.contains('complete') ||
        lifecycle.contains('done') ||
        lifecycle.contains('finish') ||
        lifecycle.contains('dismiss')) {
      return false;
    }

    final start = DateTime.tryParse(
          experiment.progressStartDate ?? experiment.sourceWeekStart,
        ) ??
        experiment.adoptedAt ??
        experiment.createdAt;
    if (start == null) return false;
    final configuredEnd = DateTime.tryParse(
      experiment.progressEndDate?.trim() ?? '',
    );
    final localDate = DateTime(date.year, date.month, date.day);
    final localStart = DateTime(start.year, start.month, start.day);
    if (localDate.isBefore(localStart)) return false;
    // sourceWeekEnd only identifies the Signal source period. A goal with no
    // explicit progressEndDate remains open while its lifecycle is writable.
    if (configuredEnd == null) return true;
    final localEnd = DateTime(
      configuredEnd.year,
      configuredEnd.month,
      configuredEnd.day,
    );
    return !localDate.isAfter(localEnd);
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

  /// Reads rollups only for goals already loaded by the archive pager.
  Future<List<Map<String, dynamic>>> listRollupsForExperiments({
    required Iterable<String> experimentIds,
  }) async {
    final ids = experimentIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (ids.isEmpty) return const [];

    final db = await localDatabase.database;
    final result = <Map<String, dynamic>>[];
    for (var start = 0; start < ids.length; start += 400) {
      final end = start + 400 < ids.length ? start + 400 : ids.length;
      final chunk = ids.sublist(start, end);
      final placeholders = List.filled(chunk.length, '?').join(', ');
      final rows = await db.query(
        'life_experiment_rollups',
        where: 'experiment_id IN ($placeholders)',
        whereArgs: chunk,
      );
      result.addAll(
        rows.map((row) => row.map((key, value) => MapEntry(key, value))),
      );
    }
    return result;
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
    final result = <Map<String, dynamic>>[];
    for (var start = 0; start < ids.length; start += 400) {
      final end = start + 400 < ids.length ? start + 400 : ids.length;
      final chunk = ids.sublist(start, end);
      final placeholders = List.filled(chunk.length, '?').join(', ');
      final rows = await db.query(
        'life_experiment_lifecycle_events',
        where: 'experiment_id IN ($placeholders)',
        whereArgs: chunk,
        orderBy: 'event_date ASC, created_at ASC',
      );
      result.addAll(
        rows.map((row) => row.map((k, v) => MapEntry(k, v))),
      );
    }
    result.sort((a, b) {
      final aDate = '${a['event_date'] ?? ''}|${a['created_at'] ?? ''}';
      final bDate = '${b['event_date'] ?? ''}|${b['created_at'] ?? ''}';
      return aDate.compareTo(bDate);
    });
    return result;
  }

  Future<void> refreshRollup(String experimentId) async {
    final experiment = await getById(experimentId);
    if (experiment == null) return;

    final db = await localDatabase.database;
    final feedbacks = await listFeedbacks(experimentId: experimentId);
    final effectiveFeedbacks = _latestFeedbackPerLocalDate(feedbacks);
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
    final helpfulCount = effectiveFeedbacks
        .where((feedback) =>
            _isHelpfulStatus(feedback.completionStatus) ||
            (feedback.helpfulnessScore ?? 0) >= 4)
        .length;
    final notHelpfulCount = effectiveFeedbacks
        .where((feedback) => _isNotHelpfulStatus(feedback.completionStatus))
        .length;
    final adjustedCount = effectiveFeedbacks
        .where((feedback) =>
            feedback.completionStatus.toLowerCase().contains('adjust'))
        .length;
    final triedCount = effectiveFeedbacks
        .where((feedback) => !_isSkippedStatus(feedback.completionStatus))
        .length;
    final skippedCount = effectiveFeedbacks
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
      where: '''
        experiment_id = ?
        AND COALESCE(is_valid, 1) = 1
      ''',
      whereArgs: [experimentId],
      orderBy: 'feedback_date ASC, created_at ASC',
    );
    return rows.map(_mapFeedbackRow).toList();
  }

  Future<List<LifeExperimentFeedbackModel>> _listAllFeedbacks({
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
    final result = <LifeExperimentFeedbackModel>[];
    for (var start = 0; start < ids.length; start += 400) {
      final end = start + 400 < ids.length ? start + 400 : ids.length;
      final chunk = ids.sublist(start, end);
      final placeholders = List.filled(chunk.length, '?').join(', ');
      final rows = await db.query(
        'life_experiment_feedback',
        where: '''
          experiment_id IN ($placeholders)
          AND COALESCE(is_valid, 1) = 1
        ''',
        whereArgs: chunk,
        orderBy: 'feedback_date ASC, created_at ASC',
      );
      result.addAll(rows.map(_mapFeedbackRow));
    }
    result.sort((a, b) {
      final dateComparison = a.feedbackDate.compareTo(b.feedbackDate);
      if (dateComparison != 0) return dateComparison;
      final aCreated = a.createdAt ?? a.feedbackDate;
      final bCreated = b.createdAt ?? b.feedbackDate;
      return aCreated.compareTo(bCreated);
    });
    return result;
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

  Future<String> _recordLifecycleEvent({
    required LifeExperimentModel experiment,
    required String eventType,
    String? statusFrom,
    String? statusTo,
    String? sourceType,
    String? sourceId,
    DateTime? eventDate,
    Map<String, dynamic> payload = const {},
    DateTime? createdAt,
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
        'review_type':
            eventType == 'outcome_reviewed' ? payload['review_type'] : null,
        'event_date': date.toUtc().toIso8601String(),
        'local_date': _dateKey(date),
        'source_type': sourceType,
        'source_id': sourceId,
        'status_from': statusFrom,
        'status_to': statusTo,
        'payload_json': jsonEncode(payload),
        'created_at': (createdAt ?? DateTime.now()).toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    return eventId;
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
    final value = status.trim().toLowerCase();
    return value.contains('skip') ||
        value == 'no' ||
        value == 'not_completed' ||
        value == 'not_done' ||
        value == 'not_happened' ||
        value == 'not_occurred' ||
        value == 'not_tried' ||
        value == 'not_today' ||
        value == 'not_suitable_today' ||
        value == 'not suitable today' ||
        value == 'false' ||
        value == 'missed';
  }

  bool _isCompletedStatus(String status) {
    final value = status.trim().toLowerCase();
    return const {
      'done',
      'completed',
      'occurred',
      'happened',
      'true',
      'yes',
      '1',
    }.contains(value);
  }

  List<LifeExperimentFeedbackModel> _latestFeedbackPerLocalDate(
    List<LifeExperimentFeedbackModel> feedbacks,
  ) {
    final latest = <String, LifeExperimentFeedbackModel>{};
    for (final feedback in feedbacks) {
      final current = latest[feedback.localDate];
      if (current == null || _isLaterFeedback(feedback, current)) {
        latest[feedback.localDate] = feedback;
      }
    }
    return latest.values.toList(growable: false);
  }

  int _normalizeMinimumObservationDays(int value) =>
      value.clamp(1, 36500).toInt();

  Map<String, dynamic> _decodeMap(Object? raw) {
    if (raw is Map) {
      return raw.map((key, value) => MapEntry('$key', value));
    }
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return decoded.map((key, value) => MapEntry('$key', value));
        }
      } catch (_) {
        return const {};
      }
    }
    return const {};
  }

  bool _isLaterFeedback(
    LifeExperimentFeedbackModel candidate,
    LifeExperimentFeedbackModel current,
  ) {
    final candidateTime =
        candidate.updatedAt ?? candidate.createdAt ?? candidate.feedbackDate;
    final currentTime =
        current.updatedAt ?? current.createdAt ?? current.feedbackDate;
    final comparison = candidateTime.compareTo(currentTime);
    if (comparison != 0) return comparison > 0;
    return candidate.id.compareTo(current.id) > 0;
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
      minimumObservationDays: _normalizeMinimumObservationDays(
        _toInt(row['minimum_observation_days']) ?? 3,
      ),
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
      'minimum_observation_days': experiment.minimumObservationDays,
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

  Future<LifeExperimentModel> _mapRowForDate(
    Map<String, Object?> row,
    String selectedLocalDate,
  ) async {
    final current = _mapRow(row);
    final content = await planContentVersionRepository.resolveContent(
      localUserId: current.localUserId,
      objectKind: PlanContentObjectKind.goal,
      objectId: current.id,
      selectedLocalDate: selectedLocalDate,
    );
    if (content == null) return current;
    return _mapRow(<String, Object?>{
      ...row,
      ...content,
    });
  }

  Future<void> _ensureInitialContentVersion(
    LifeExperimentModel experiment,
  ) async {
    await planContentVersionRepository.ensureInitial(
      localUserId: experiment.localUserId,
      objectKind: PlanContentObjectKind.goal,
      objectId: experiment.id,
      effectiveFromLocalDate: _lifeExperimentStartDate(experiment),
      content: _lifeExperimentContent(experiment),
      createdAt: experiment.createdAt,
    );
  }

  Future<String?> _lifeExperimentEditEffectiveDate(
    LifeExperimentModel experiment,
  ) async {
    final now = nowLoader().toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime.tryParse(_lifeExperimentStartDate(experiment));
    final end = DateTime.tryParse(experiment.progressEndDate?.trim() ?? '');
    if (start == null || (end != null && end.isBefore(start))) return null;
    final localStart = DateTime(start.year, start.month, start.day);
    final localEnd =
        end == null ? null : DateTime(end.year, end.month, end.day);
    if (localEnd?.isBefore(today) ?? false) return null;

    final nextWeekStart = _startOfWeek(today).add(const Duration(days: 7));
    final nextWeekEnd = nextWeekStart.add(const Duration(days: 6));
    if (localStart.isAfter(nextWeekEnd)) return null;

    late DateTime effective;
    if (!localStart.isBefore(nextWeekStart)) {
      effective = localStart;
    } else {
      final db = await localDatabase.database;
      final feedback = await db.query(
        'life_experiment_feedback',
        columns: const ['id'],
        where: '''
          experiment_id = ? AND local_date = ?
          AND COALESCE(is_valid, 1) = 1
        ''',
        whereArgs: [experiment.id, _dateKey(today)],
        limit: 1,
      );
      effective = feedback.isNotEmpty
          ? today.add(const Duration(days: 1))
          : (localStart.isAfter(today) ? localStart : today);
    }
    if (localEnd != null && effective.isAfter(localEnd)) return null;
    return _dateKey(effective);
  }

  String _lifeExperimentStartDate(LifeExperimentModel experiment) {
    final progressStart = experiment.progressStartDate?.trim() ?? '';
    if (DateTime.tryParse(progressStart) != null) return progressStart;
    final sourceStart = experiment.sourceWeekStart.trim();
    if (DateTime.tryParse(sourceStart) != null) return sourceStart;
    final fallback = experiment.adoptedAt?.toLocal() ??
        experiment.createdAt?.toLocal() ??
        nowLoader().toLocal();
    return _dateKey(fallback);
  }

  Map<String, dynamic> _lifeExperimentContent(
    LifeExperimentModel experiment, {
    String? title,
    String? hypothesis,
    String? suggestedAction,
    String? focusAreaId,
    String? patternId,
    String? feedbackPatternId,
    String? iconAssetId,
    String? plannedFrequency,
    int? plannedDurationMinutes,
    int? plannedTotalDays,
    int? minimumObservationDays,
  }) {
    return {
      'title': title ?? experiment.title,
      'hypothesis': hypothesis ?? experiment.hypothesis,
      'suggested_action': suggestedAction ?? experiment.suggestedAction,
      'focus_area_id': focusAreaId ?? experiment.focusAreaId,
      'pattern_id': patternId ?? experiment.patternId,
      'feedback_pattern_id': feedbackPatternId ?? experiment.feedbackPatternId,
      'icon_asset_id': iconAssetId ?? experiment.iconAssetId,
      'planned_frequency': plannedFrequency ?? experiment.plannedFrequency,
      'planned_duration_minutes':
          plannedDurationMinutes ?? experiment.plannedDurationMinutes,
      'planned_total_days': plannedTotalDays ?? experiment.plannedTotalDays,
      'minimum_observation_days': _normalizeMinimumObservationDays(
        minimumObservationDays ?? experiment.minimumObservationDays,
      ),
    };
  }

  bool _hasAdoptionEvidence(LifeExperimentModel experiment) {
    if (experiment.adoptedAt != null ||
        (experiment.originCandidateId?.trim().isNotEmpty ?? false)) {
      return true;
    }
    return const {
      'accepted',
      'saved',
      'active',
      'adjusted',
      'done',
      'completed',
      'paused',
      'stopped',
      'archived',
      'effective',
      'not_effective',
    }.contains(experiment.status.trim().toLowerCase());
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
