import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/weekly_models.dart';
import '../policies/planning_content_edit_policy.dart';
import 'local_database.dart';
import 'local_life_experiment_repository.dart';

class LocalExperimentCandidateRepository {
  final LocalDatabase localDatabase;
  final DateTime Function() nowLoader;

  LocalExperimentCandidateRepository(
    this.localDatabase, {
    DateTime Function()? nowLoader,
  }) : nowLoader = nowLoader ?? DateTime.now;

  Future<LifeExperimentModel?> getById(String candidateId) async {
    final db = await localDatabase.database;
    final rows = await db.query(
      'experiment_candidates',
      where: 'id = ?',
      whereArgs: [candidateId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _mapRow(rows.first);
  }

  Future<LifeExperimentModel?> getWeeklyCandidate({
    required String localUserId,
    required String weekStart,
  }) async {
    final db = await localDatabase.database;
    final rows = await db.query(
      'experiment_candidates',
      where: '''
        local_user_id = ?
        AND source_type = ?
        AND source_id = ?
        AND dirty = 0
        AND is_stale = 0
      ''',
      whereArgs: [localUserId, 'weekly_reflection', weekStart],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _mapRow(rows.first);
  }

  Future<LifeExperimentModel> ensureWeeklyCandidate({
    required String localUserId,
    required String weekStart,
    required String weekEnd,
    required String title,
    required String hypothesis,
    required String suggestedAction,
    required List<String> linkedSignalCardIds,
    List<String> linkedObservationIds = const [],
    int? plannedTotalDays,
  }) async {
    final db = await localDatabase.database;
    final existing = await db.query(
      'experiment_candidates',
      where: '''
        local_user_id = ?
        AND source_type = ?
        AND source_id = ?
        AND dirty = 0
        AND is_stale = 0
      ''',
      whereArgs: [localUserId, 'weekly_reflection', weekStart],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    if (existing.isNotEmpty) return _mapRow(existing.first);

    final now = DateTime.now().toUtc();
    final candidate = LifeExperimentModel(
      id: _weeklyCandidateId(localUserId, weekStart),
      localUserId: localUserId,
      sourceWeekStart: weekStart,
      sourceWeekEnd: weekEnd,
      title: title,
      hypothesis: hypothesis,
      suggestedAction: suggestedAction,
      linkedSignalCardIds: linkedSignalCardIds,
      status: 'suggested',
      plannedTotalDays: plannedTotalDays != null && plannedTotalDays > 0
          ? plannedTotalDays
          : null,
      createdAt: now,
      updatedAt: now,
    );

    await db.insert(
      'experiment_candidates',
      {
        ..._toRow(candidate),
        'source_type': 'weekly_reflection',
        'source_id': weekStart,
        'linked_observation_ids_json': jsonEncode(linkedObservationIds),
        'status': 'generated',
        'confidence_level': 'medium',
        'metadata_json': jsonEncode({
          'presentation_status': 'suggested',
          'created_from': 'weekly_experiment_planning',
          if (candidate.plannedTotalDays != null)
            'planned_total_days': candidate.plannedTotalDays,
        }),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return candidate;
  }

  Future<LifeExperimentModel?> updateStatus({
    required String candidateId,
    required String status,
  }) async {
    final db = await localDatabase.database;
    final presentationStatus = status == 'generated' ? 'suggested' : status;
    final normalizedStatus = status.trim().toLowerCase();
    await db.update(
      'experiment_candidates',
      {
        'status': status,
        if (const {'saved', 'considering', 'observing', 'reviewing'}
            .contains(normalizedStatus))
          'decision_status': 'considering',
        if (const {'adopted', 'planned', 'active'}.contains(normalizedStatus))
          'decision_status': 'adopted',
        'metadata_json': jsonEncode({
          'presentation_status': presentationStatus,
          'created_from': 'weekly_experiment_planning',
        }),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [candidateId],
    );
    final candidate = await getById(candidateId);
    return candidate?.copyWith(
      status: status == 'skipped' ? 'skipped' : candidate.status,
      feedbackText: status == 'skipped' ? 'Skipped for now' : null,
    );
  }

  Future<LifeExperimentModel?> updateContent({
    required String candidateId,
    required String title,
    required String hypothesis,
    required String suggestedAction,
  }) async {
    final normalizedTitle = title.trim();
    final normalizedAction = suggestedAction.trim();
    if (normalizedTitle.isEmpty || normalizedAction.isEmpty) return null;
    final db = await localDatabase.database;
    final rows = await db.query(
      'experiment_candidates',
      where: 'id = ?',
      whereArgs: [candidateId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final status = (row['status'] as String? ?? '').toLowerCase();
    final sourceStart = DateTime.tryParse(
      (row['source_week_start'] as String?) ?? '',
    );
    final sourceEnd = DateTime.tryParse(
      (row['source_week_end'] as String?) ?? '',
    );
    if (!const {'generated', 'edited'}.contains(status) ||
        sourceStart == null ||
        sourceEnd == null ||
        !PlanningContentEditPolicy.canEditRange(
          start: sourceStart.add(const Duration(days: 7)),
          end: sourceEnd.add(const Duration(days: 7)),
          now: nowLoader(),
        )) {
      return null;
    }
    final affected = await db.update(
      'experiment_candidates',
      {
        'title': normalizedTitle,
        'hypothesis': hypothesis.trim(),
        'suggested_action': normalizedAction,
        'status': 'edited',
        'updated_at': nowLoader().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [candidateId],
    );
    return affected == 0 ? null : getById(candidateId);
  }

  Future<LifeExperimentModel?> adoptCandidate({
    required String candidateId,
    required LocalLifeExperimentRepository lifeExperimentRepository,
  }) async {
    final candidate = await getById(candidateId);
    if (candidate == null) return null;

    // A weekly candidate is generated from the week being reviewed, but it is
    // an option for the following week. Keep the candidate's source period
    // unchanged for provenance and move only the adopted, formal experiment
    // into its actual active period.
    final activeWeekStart = _shiftDateKey(candidate.sourceWeekStart, 7);
    final activeWeekEnd = _shiftDateKey(candidate.sourceWeekEnd, 7);
    final progressEndDate = _progressEndDate(
      activeWeekStart,
      candidate.plannedTotalDays,
    );
    final adoptedAt = DateTime.now();

    final ensured = await lifeExperimentRepository.ensureSuggested(
      localUserId: candidate.localUserId,
      weekStart: activeWeekStart,
      weekEnd: activeWeekEnd,
      title: candidate.title,
      hypothesis: candidate.hypothesis,
      suggestedAction: candidate.suggestedAction,
      linkedSignalCardIds: candidate.linkedSignalCardIds,
      status: 'saved',
      parentExperimentId: candidate.parentExperimentId,
      focusAreaId: candidate.focusAreaId,
      patternId: candidate.patternId,
      feedbackPatternId: candidate.feedbackPatternId,
      iconAssetId: candidate.iconAssetId,
      plannedFrequency: candidate.plannedFrequency,
      plannedDurationMinutes: candidate.plannedDurationMinutes,
      plannedTotalDays: candidate.plannedTotalDays,
      originCandidateId: candidate.id,
      adoptedAt: adoptedAt,
      progressStartDate: activeWeekStart,
      progressEndDate: progressEndDate,
    );
    final experiment = ensured.status == 'saved'
        ? ensured
        : await lifeExperimentRepository.updateStatus(
              experimentId: ensured.id,
              status: 'saved',
            ) ??
            ensured.copyWith(status: 'saved');

    final db = await localDatabase.database;
    await db.update(
      'experiment_candidates',
      {
        'status': 'adopted',
        'decision_status': 'adopted',
        'adopted_experiment_id': experiment.id,
        'metadata_json': jsonEncode({
          'presentation_status': 'adopted',
          'created_from': 'weekly_experiment_planning',
        }),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [candidateId],
    );
    return experiment;
  }

  Future<LifeExperimentModel?> getAdoptedExperiment({
    required String candidateId,
    required LocalLifeExperimentRepository lifeExperimentRepository,
  }) async {
    final db = await localDatabase.database;
    final rows = await db.query(
      'experiment_candidates',
      columns: const ['adopted_experiment_id'],
      where: 'id = ?',
      whereArgs: [candidateId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final experimentId =
        (rows.first['adopted_experiment_id'] as String?)?.trim();
    if (experimentId == null || experimentId.isEmpty) return null;
    return lifeExperimentRepository.getById(experimentId);
  }

  LifeExperimentModel _mapRow(Map<String, Object?> row) {
    final metadata = _decodeMap(row['metadata_json']);
    final presentationStatus =
        (metadata['presentation_status'] as String?)?.trim();
    final storageStatus = (row['status'] as String?) ?? 'generated';
    final status = presentationStatus?.isNotEmpty == true
        ? presentationStatus!
        : storageStatus == 'generated'
            ? 'suggested'
            : storageStatus;

    return LifeExperimentModel(
      id: (row['id'] as String?) ?? '',
      localUserId: (row['local_user_id'] as String?) ?? 'local',
      sourceWeekStart: (row['source_week_start'] as String?) ?? '',
      sourceWeekEnd: (row['source_week_end'] as String?) ?? '',
      title: (row['title'] as String?) ?? '',
      hypothesis: (row['hypothesis'] as String?) ?? '',
      suggestedAction: (row['suggested_action'] as String?) ?? '',
      linkedSignalCardIds: _decodeStringList(
        row['linked_signal_card_ids_json'],
      ),
      plannedTotalDays: _positiveInt(metadata['planned_total_days']),
      status: status,
      createdAt: DateTime.tryParse((row['created_at'] as String?) ?? ''),
      updatedAt: DateTime.tryParse((row['updated_at'] as String?) ?? ''),
    );
  }

  Map<String, Object?> _toRow(LifeExperimentModel candidate) {
    return {
      'id': candidate.id,
      'local_user_id': candidate.localUserId,
      'source_week_start': candidate.sourceWeekStart,
      'source_week_end': candidate.sourceWeekEnd,
      'title': candidate.title,
      'hypothesis': candidate.hypothesis,
      'suggested_action': candidate.suggestedAction,
      'linked_signal_card_ids_json': jsonEncode(
        candidate.linkedSignalCardIds,
      ),
      'created_at': candidate.createdAt?.toUtc().toIso8601String() ??
          DateTime.now().toUtc().toIso8601String(),
      'updated_at': candidate.updatedAt?.toUtc().toIso8601String() ??
          DateTime.now().toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> _decodeMap(Object? raw) {
    if (raw is! String || raw.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
    } catch (_) {}
    return const {};
  }

  List<String> _decodeStringList(Object? raw) {
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

  String _weeklyCandidateId(String localUserId, String weekStart) {
    final raw = '${localUserId}_$weekStart';
    final stable = raw.replaceAll(RegExp(r'[^A-Za-z0-9_]+'), '_');
    return 'cand_weekly_$stable';
  }

  String _shiftDateKey(String value, int days) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    final shifted = parsed.add(Duration(days: days));
    return '${shifted.year.toString().padLeft(4, '0')}-'
        '${shifted.month.toString().padLeft(2, '0')}-'
        '${shifted.day.toString().padLeft(2, '0')}';
  }

  String? _progressEndDate(String startDate, int? plannedTotalDays) {
    if (plannedTotalDays == null || plannedTotalDays <= 0) return null;
    final start = DateTime.tryParse(startDate);
    if (start == null) return null;
    return _shiftDateKey(startDate, plannedTotalDays - 1);
  }

  int? _positiveInt(Object? value) {
    final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
    return parsed != null && parsed > 0 ? parsed : null;
  }
}
