import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'local_database.dart';

class TraceLinkInput {
  final String sourceType;
  final String sourceId;
  final String targetType;
  final String targetId;
  final String relationType;
  final String localUserId;
  final double weight;
  final String status;
  final Map<String, dynamic> metadata;

  const TraceLinkInput({
    required this.sourceType,
    required this.sourceId,
    required this.targetType,
    required this.targetId,
    required this.relationType,
    this.localUserId = 'local',
    this.weight = 1.0,
    this.status = 'active',
    this.metadata = const {},
  });
}

class LocalTraceLinkRepository {
  final LocalDatabase localDatabase;

  const LocalTraceLinkRepository(this.localDatabase);

  Future<void> upsert(TraceLinkInput link) async {
    if (!_isValid(link)) return;
    final db = await localDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.insert(
      'trace_links',
      {
        'id': _idFor(link),
        'local_user_id':
            link.localUserId.trim().isEmpty ? 'local' : link.localUserId.trim(),
        'source_type': link.sourceType,
        'source_id': link.sourceId,
        'target_type': link.targetType,
        'target_id': link.targetId,
        'relation_type': link.relationType,
        'weight': link.weight,
        'status': link.status,
        'metadata_json': jsonEncode(link.metadata),
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertMany(Iterable<TraceLinkInput> links) async {
    for (final link in links) {
      await upsert(link);
    }
  }

  Future<void> replaceForSource({
    required String sourceType,
    required String sourceId,
    required Iterable<TraceLinkInput> links,
  }) async {
    final db = await localDatabase.database;
    await db.delete(
      'trace_links',
      where: 'source_type = ? AND source_id = ?',
      whereArgs: [sourceType, sourceId],
    );
    await upsertMany(links);
  }

  Future<void> markInactiveForTarget({
    required String targetType,
    required String targetId,
    String status = 'inactive',
  }) async {
    final db = await localDatabase.database;
    await db.update(
      'trace_links',
      {
        'status': status,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'target_type = ? AND target_id = ?',
      whereArgs: [targetType, targetId],
    );
  }

  Future<void> markInactiveForSource({
    required String sourceType,
    required String sourceId,
    String status = 'inactive',
  }) async {
    final db = await localDatabase.database;
    await db.update(
      'trace_links',
      {
        'status': status,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'source_type = ? AND source_id = ?',
      whereArgs: [sourceType, sourceId],
    );
  }

  Future<List<Map<String, Object?>>> listForSource({
    required String sourceType,
    required String sourceId,
    List<String> statuses = const ['active'],
  }) async {
    final db = await localDatabase.database;
    final placeholders = List.filled(statuses.length, '?').join(', ');
    return db.query(
      'trace_links',
      where: 'source_type = ? AND source_id = ? AND status IN ($placeholders)',
      whereArgs: [sourceType, sourceId, ...statuses],
      orderBy: 'relation_type ASC, weight DESC, updated_at DESC',
    );
  }

  bool _isValid(TraceLinkInput link) {
    return link.sourceType.trim().isNotEmpty &&
        link.sourceId.trim().isNotEmpty &&
        link.targetType.trim().isNotEmpty &&
        link.targetId.trim().isNotEmpty &&
        link.relationType.trim().isNotEmpty;
  }

  String _idFor(TraceLinkInput link) {
    return [
      'trace',
      link.sourceType,
      link.sourceId,
      link.targetType,
      link.targetId,
      link.relationType,
    ].map(_stableIdPart).join('_');
  }

  String _stableIdPart(String raw) {
    return raw.replaceAll(RegExp(r'[^A-Za-z0-9_]+'), '_');
  }
}
