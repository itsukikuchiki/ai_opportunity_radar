import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/weekly_models.dart';
import 'local_database.dart';

class LocalLifeExperimentRepository {
  final LocalDatabase localDatabase;
  final Uuid _uuid = const Uuid();

  LocalLifeExperimentRepository(this.localDatabase);

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
  }) async {
    final existing = await getByWeekStart(
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
      title: title,
      hypothesis: hypothesis,
      suggestedAction: suggestedAction,
      linkedSignalCardIds: linkedSignalCardIds,
      status: 'suggested',
      feedbackText: null,
      createdAt: now,
      updatedAt: now,
    );

    await db.insert(
      'life_experiments',
      _toRow(experiment),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return experiment;
  }

  Future<LifeExperimentModel?> updateStatus({
    required String experimentId,
    required String status,
    String? feedbackText,
  }) async {
    final db = await localDatabase.database;
    final now = DateTime.now().toUtc();
    await db.update(
      'life_experiments',
      {
        'status': status,
        'feedback_text': feedbackText,
        'updated_at': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [experimentId],
    );

    final rows = await db.query(
      'life_experiments',
      where: 'id = ?',
      whereArgs: [experimentId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _mapRow(rows.first);
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

  LifeExperimentModel _mapRow(Map<String, Object?> row) {
    return LifeExperimentModel(
      id: (row['id'] as String?) ?? '',
      localUserId: (row['local_user_id'] as String?) ?? '',
      sourceWeekStart: (row['source_week_start'] as String?) ?? '',
      sourceWeekEnd: (row['source_week_end'] as String?) ?? '',
      title: (row['title'] as String?) ?? '',
      hypothesis: (row['hypothesis'] as String?) ?? '',
      suggestedAction: (row['suggested_action'] as String?) ?? '',
      linkedSignalCardIds: _decodeStringList(
        row['linked_signal_card_ids_json'],
      ),
      status: (row['status'] as String?) ?? 'suggested',
      feedbackText: row['feedback_text'] as String?,
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
      'title': experiment.title,
      'hypothesis': experiment.hypothesis,
      'suggested_action': experiment.suggestedAction,
      'linked_signal_card_ids_json': jsonEncode(
        experiment.linkedSignalCardIds,
      ),
      'status': experiment.status,
      'feedback_text': experiment.feedbackText,
      'created_at': experiment.createdAt?.toUtc().toIso8601String() ??
          DateTime.now().toUtc().toIso8601String(),
      'updated_at': experiment.updatedAt?.toUtc().toIso8601String() ??
          DateTime.now().toUtc().toIso8601String(),
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
}
