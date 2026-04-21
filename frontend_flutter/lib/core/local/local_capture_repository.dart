import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/today_models.dart';
import 'local_database.dart';

class LocalCaptureRepository {
  final LocalDatabase localDatabase;
  final Uuid _uuid = const Uuid();

  LocalCaptureRepository(this.localDatabase);

  Future<RecentSignalModel> insertCapture({
    required String content,
    String inputMode = 'quick_capture',
    String? tagHint,
  }) async {
    final db = await localDatabase.database;
    final now = DateTime.now().toUtc();
    final id = 'cap_${_uuid.v4().replaceAll('-', '').substring(0, 12)}';

    await db.insert(
      'captures',
      {
        'id': id,
        'content': content,
        'created_at': now.toIso8601String(),
        'input_mode': inputMode,
        'tag_hint': tagHint,
        'ai_acknowledgement': null,
        'ai_observation': null,
        'ai_try_next': null,
        'ai_emotion': null,
        'ai_intensity': null,
        'ai_scene_tags_json': null,
        'ai_intent_tags_json': null,
        'ai_status': 'pending',
        'followup_question_json': null,
        'followup_answer': null,
        'updated_at': now.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return RecentSignalModel(
      id: id,
      content: content,
      createdAt: now.toLocal(),
      acknowledgement: null,
      observation: null,
      tryNext: null,
      emotion: null,
      intensity: null,
      sceneTags: const [],
      intentTags: const [],
    );
  }

  Future<void> updateAiReply({
    required String captureId,
    required String? acknowledgement,
    required String? observation,
    required String? tryNext,
    required String? emotion,
    required String? intensity,
    required List<String> sceneTags,
    required List<String> intentTags,
  }) async {
    final db = await localDatabase.database;
    await db.update(
      'captures',
      {
        'ai_acknowledgement': acknowledgement,
        'ai_observation': observation,
        'ai_try_next': tryNext,
        'ai_emotion': emotion,
        'ai_intensity': intensity,
        'ai_scene_tags_json': jsonEncode(sceneTags),
        'ai_intent_tags_json': jsonEncode(intentTags),
        'ai_status': acknowledgement == null ? 'failed' : 'done',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [captureId],
    );
  }

  Future<void> updateAcknowledgement({
    required String captureId,
    required String? acknowledgement,
  }) async {
    final db = await localDatabase.database;
    await db.update(
      'captures',
      {
        'ai_acknowledgement': acknowledgement,
        'ai_status': acknowledgement == null ? 'failed' : 'done',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [captureId],
    );
  }


  Future<RecentSignalModel?> getCaptureById(String captureId) async {
    final db = await localDatabase.database;
    final rows = await db.query(
      'captures',
      where: 'id = ?',
      whereArgs: [captureId],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return _mapRowToSignal(rows.first);
  }

  Future<List<RecentSignalModel>> listTodaySignals() async {
    final db = await localDatabase.database;

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    final rows = await db.query(
      'captures',
      where: 'created_at >= ? AND created_at < ?',
      whereArgs: [
        start.toUtc().toIso8601String(),
        end.toUtc().toIso8601String(),
      ],
      orderBy: 'created_at DESC',
    );

    return rows.map(_mapRowToSignal).toList();
  }

  Future<List<RecentSignalModel>> listRecentSignals({int limit = 10}) async {
    final db = await localDatabase.database;

    final rows = await db.query(
      'captures',
      orderBy: 'created_at DESC',
      limit: limit,
    );

    return rows.map(_mapRowToSignal).toList();
  }

  Future<List<String>> listRecentAcknowledgements({int limit = 10}) async {
    final db = await localDatabase.database;

    final rows = await db.query(
      'captures',
      columns: ['ai_acknowledgement'],
      where: 'ai_acknowledgement IS NOT NULL AND ai_acknowledgement != ?',
      whereArgs: [''],
      orderBy: 'created_at DESC',
      limit: limit,
    );

    return rows
        .map((row) => (row['ai_acknowledgement'] as String?)?.trim())
        .whereType<String>()
        .where((text) => text.isNotEmpty)
        .toList();
  }

  RecentSignalModel _mapRowToSignal(Map<String, Object?> row) {
    return RecentSignalModel(
      id: row['id'] as String?,
      content: (row['content'] as String?) ?? '',
      createdAt: DateTime.tryParse((row['created_at'] as String?) ?? '')?.toLocal(),
      acknowledgement: row['ai_acknowledgement'] as String?,
      observation: row['ai_observation'] as String?,
      tryNext: row['ai_try_next'] as String?,
      emotion: row['ai_emotion'] as String?,
      intensity: row['ai_intensity'] as String?,
      sceneTags: _decodeJsonStringList(row['ai_scene_tags_json']),
      intentTags: _decodeJsonStringList(row['ai_intent_tags_json']),
    );
  }

  List<String> _decodeJsonStringList(Object? raw) {
    if (raw == null) return const [];
    if (raw is List) {
      return raw
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return const [];
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          return decoded
              .map((e) => e?.toString().trim() ?? '')
              .where((e) => e.isNotEmpty)
              .toList();
        }
      } catch (_) {
        return trimmed
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    }
    return const [];
  }
}
