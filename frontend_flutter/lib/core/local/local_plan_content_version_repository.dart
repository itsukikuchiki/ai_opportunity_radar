import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'local_database.dart';

enum PlanContentObjectKind {
  quickTry('quick_try'),
  goal('goal');

  final String storageValue;

  const PlanContentObjectKind(this.storageValue);
}

class PlanContentVersion {
  final String id;
  final String localUserId;
  final PlanContentObjectKind objectKind;
  final String objectId;
  final int versionNo;
  final String effectiveFromLocalDate;
  final Map<String, dynamic> content;
  final DateTime createdAt;

  const PlanContentVersion({
    required this.id,
    required this.localUserId,
    required this.objectKind,
    required this.objectId,
    required this.versionNo,
    required this.effectiveFromLocalDate,
    required this.content,
    required this.createdAt,
  });

  factory PlanContentVersion.fromDb(Map<String, Object?> row) {
    final rawKind = row['object_kind'] as String? ?? '';
    final kind = PlanContentObjectKind.values.firstWhere(
      (candidate) => candidate.storageValue == rawKind,
      orElse: () => throw StateError(
        'Unsupported plan content object kind: $rawKind',
      ),
    );
    final rawContent = row['content_json'] as String? ?? '{}';
    final decoded = jsonDecode(rawContent);
    if (decoded is! Map) {
      throw const FormatException('Plan content must decode to an object.');
    }
    final createdAt = DateTime.tryParse(
      row['created_at'] as String? ?? '',
    );
    if (createdAt == null) {
      throw const FormatException('Plan content version has no created_at.');
    }
    return PlanContentVersion(
      id: row['id'] as String? ?? '',
      localUserId: row['local_user_id'] as String? ?? 'local',
      objectKind: kind,
      objectId: row['object_id'] as String? ?? '',
      versionNo: (row['version_no'] as num?)?.toInt() ?? 0,
      effectiveFromLocalDate: row['effective_from_local_date'] as String? ?? '',
      content: Map<String, dynamic>.unmodifiable(
        decoded.map((key, value) => MapEntry('$key', value)),
      ),
      createdAt: createdAt,
    );
  }
}

/// Append-only source of truth for editable current/next-week plan content.
///
/// The `micro_actions` and `life_experiments` rows may remain convenient latest
/// projections. Date-scoped readers must resolve through this repository so a
/// later plan edit cannot rewrite an earlier Diary page.
class LocalPlanContentVersionRepository {
  final LocalDatabase localDatabase;
  final Uuid _uuid;

  LocalPlanContentVersionRepository(
    this.localDatabase, {
    Uuid uuid = const Uuid(),
  }) : _uuid = uuid;

  Future<PlanContentVersion> ensureInitial({
    required String localUserId,
    required PlanContentObjectKind objectKind,
    required String objectId,
    required String effectiveFromLocalDate,
    required Map<String, dynamic> content,
    DateTime? createdAt,
  }) async {
    final db = await localDatabase.database;
    return db.transaction(
      (txn) => ensureInitialWithExecutor(
        txn,
        localUserId: localUserId,
        objectKind: objectKind,
        objectId: objectId,
        effectiveFromLocalDate: effectiveFromLocalDate,
        content: content,
        createdAt: createdAt,
      ),
    );
  }

  /// Uses an existing transaction/executor so a content version and its
  /// latest-row projection can commit atomically. The caller owns the
  /// transaction lifecycle.
  Future<PlanContentVersion> ensureInitialWithExecutor(
    DatabaseExecutor executor, {
    required String localUserId,
    required PlanContentObjectKind objectKind,
    required String objectId,
    required String effectiveFromLocalDate,
    required Map<String, dynamic> content,
    DateTime? createdAt,
  }) async {
    final userId = _requiredText(localUserId, 'localUserId');
    final resolvedObjectId = _requiredText(objectId, 'objectId');
    final effectiveDate = _localDateKey(effectiveFromLocalDate);
    final encodedContent = _encodeContent(content);
    final existing = await _getVersion(
      executor,
      localUserId: userId,
      objectKind: objectKind,
      objectId: resolvedObjectId,
      versionNo: 1,
    );
    if (existing != null) return existing;

    final now = (createdAt ?? DateTime.now()).toUtc();
    await executor.insert(
      'plan_content_versions',
      {
        'id': 'plan_${_uuid.v4()}',
        'local_user_id': userId,
        'object_kind': objectKind.storageValue,
        'object_id': resolvedObjectId,
        'version_no': 1,
        'effective_from_local_date': effectiveDate,
        'content_json': encodedContent,
        'created_at': now.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final inserted = await _getVersion(
      executor,
      localUserId: userId,
      objectKind: objectKind,
      objectId: resolvedObjectId,
      versionNo: 1,
    );
    if (inserted == null) {
      throw StateError('Unable to create initial plan content version.');
    }
    return inserted;
  }

  Future<PlanContentVersion> append({
    required String localUserId,
    required PlanContentObjectKind objectKind,
    required String objectId,
    required String effectiveFromLocalDate,
    required Map<String, dynamic> content,
    DateTime? createdAt,
  }) async {
    final db = await localDatabase.database;
    return db.transaction(
      (txn) => appendWithExecutor(
        txn,
        localUserId: localUserId,
        objectKind: objectKind,
        objectId: objectId,
        effectiveFromLocalDate: effectiveFromLocalDate,
        content: content,
        createdAt: createdAt,
      ),
    );
  }

  /// Transaction-aware variant paired with [ensureInitialWithExecutor].
  Future<PlanContentVersion> appendWithExecutor(
    DatabaseExecutor executor, {
    required String localUserId,
    required PlanContentObjectKind objectKind,
    required String objectId,
    required String effectiveFromLocalDate,
    required Map<String, dynamic> content,
    DateTime? createdAt,
  }) async {
    final userId = _requiredText(localUserId, 'localUserId');
    final resolvedObjectId = _requiredText(objectId, 'objectId');
    final effectiveDate = _localDateKey(effectiveFromLocalDate);
    final encodedContent = _encodeContent(content);
    final maxRows = await executor.rawQuery(
      '''
      SELECT MAX(version_no) AS max_version
      FROM plan_content_versions
      WHERE local_user_id = ? AND object_kind = ? AND object_id = ?
      ''',
      [userId, objectKind.storageValue, resolvedObjectId],
    );
    final maxVersion = maxRows.isEmpty
        ? 0
        : (maxRows.first['max_version'] as num?)?.toInt() ?? 0;
    if (maxVersion < 1) {
      throw StateError(
        'Initial plan content version is required before append.',
      );
    }
    final nextVersion = maxVersion + 1;
    final now = (createdAt ?? DateTime.now()).toUtc();
    await executor.insert(
      'plan_content_versions',
      {
        'id': 'plan_${_uuid.v4()}',
        'local_user_id': userId,
        'object_kind': objectKind.storageValue,
        'object_id': resolvedObjectId,
        'version_no': nextVersion,
        'effective_from_local_date': effectiveDate,
        'content_json': encodedContent,
        'created_at': now.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    final inserted = await _getVersion(
      executor,
      localUserId: userId,
      objectKind: objectKind,
      objectId: resolvedObjectId,
      versionNo: nextVersion,
    );
    if (inserted == null) {
      throw StateError('Unable to append plan content version.');
    }
    return inserted;
  }

  Future<PlanContentVersion?> resolve({
    required String localUserId,
    required PlanContentObjectKind objectKind,
    required String objectId,
    required String selectedLocalDate,
  }) async {
    final userId = _requiredText(localUserId, 'localUserId');
    final resolvedObjectId = _requiredText(objectId, 'objectId');
    final selectedDate = _localDateKey(selectedLocalDate);
    final db = await localDatabase.database;
    final rows = await db.query(
      'plan_content_versions',
      where: '''
        local_user_id = ?
        AND object_kind = ?
        AND object_id = ?
        AND effective_from_local_date <= ?
      ''',
      whereArgs: [
        userId,
        objectKind.storageValue,
        resolvedObjectId,
        selectedDate,
      ],
      orderBy: 'effective_from_local_date DESC, version_no DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : PlanContentVersion.fromDb(rows.first);
  }

  Future<Map<String, dynamic>?> resolveContent({
    required String localUserId,
    required PlanContentObjectKind objectKind,
    required String objectId,
    required String selectedLocalDate,
  }) async {
    final version = await resolve(
      localUserId: localUserId,
      objectKind: objectKind,
      objectId: objectId,
      selectedLocalDate: selectedLocalDate,
    );
    return version?.content;
  }

  Future<List<PlanContentVersion>> listForObject({
    required String localUserId,
    required PlanContentObjectKind objectKind,
    required String objectId,
  }) async {
    final userId = _requiredText(localUserId, 'localUserId');
    final resolvedObjectId = _requiredText(objectId, 'objectId');
    final db = await localDatabase.database;
    final rows = await db.query(
      'plan_content_versions',
      where: 'local_user_id = ? AND object_kind = ? AND object_id = ?',
      whereArgs: [userId, objectKind.storageValue, resolvedObjectId],
      orderBy: 'version_no ASC',
    );
    return rows.map(PlanContentVersion.fromDb).toList(growable: false);
  }

  Future<PlanContentVersion?> _getVersion(
    DatabaseExecutor db, {
    required String localUserId,
    required PlanContentObjectKind objectKind,
    required String objectId,
    required int versionNo,
  }) async {
    final rows = await db.query(
      'plan_content_versions',
      where: '''
        local_user_id = ? AND object_kind = ? AND object_id = ?
        AND version_no = ?
      ''',
      whereArgs: [
        localUserId,
        objectKind.storageValue,
        objectId,
        versionNo,
      ],
      limit: 1,
    );
    return rows.isEmpty ? null : PlanContentVersion.fromDb(rows.first);
  }

  String _requiredText(String raw, String field) {
    final value = raw.trim();
    if (value.isEmpty) {
      throw ArgumentError.value(raw, field, 'must not be empty');
    }
    return value;
  }

  String _localDateKey(String raw) {
    final value = raw.trim();
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      throw ArgumentError.value(raw, 'localDate', 'must use YYYY-MM-DD');
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null ||
        parsed.year.toString().padLeft(4, '0') != value.substring(0, 4) ||
        parsed.month.toString().padLeft(2, '0') != value.substring(5, 7) ||
        parsed.day.toString().padLeft(2, '0') != value.substring(8, 10)) {
      throw ArgumentError.value(raw, 'localDate', 'must be a valid date');
    }
    return value;
  }

  String _encodeContent(Map<String, dynamic> content) {
    final encoded = jsonEncode(content);
    final decoded = jsonDecode(encoded);
    if (decoded is! Map) {
      throw ArgumentError.value(content, 'content', 'must encode to an object');
    }
    return encoded;
  }
}
