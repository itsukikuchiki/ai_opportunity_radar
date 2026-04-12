import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/weekly_models.dart';
import 'local_database.dart';

class LocalWeeklySnapshotRepository {
  final LocalDatabase localDatabase;

  LocalWeeklySnapshotRepository(this.localDatabase);

  Future<WeeklyInsightModel?> getByWeekStart(String weekStart) async {
    final db = await localDatabase.database;
    final rows = await db.query(
      'weekly_snapshots',
      where: 'week_start = ?',
      whereArgs: [weekStart],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return _mapRow(rows.first);
  }

  Future<void> upsert({
    required WeeklyInsightModel weekly,
    required String sourceHash,
  }) async {
    final db = await localDatabase.database;

    await db.insert(
      'weekly_snapshots',
      {
        'week_start': weekly.weekStart,
        'week_end': weekly.weekEnd,
        'status': weekly.status,
        'key_insight': weekly.keyInsight,
        'patterns_json': jsonEncode(weekly.patterns),
        'frictions_json': jsonEncode(weekly.frictions),
        'best_action': weekly.bestAction,
        'opportunity_snapshot_json': weekly.opportunitySnapshot == null
            ? null
            : jsonEncode(weekly.opportunitySnapshot),
        'feedback_submitted': weekly.feedbackSubmitted ? 1 : 0,
        'source_hash': sourceHash,
        'generated_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> markFeedbackSubmitted(String weekStart) async {
    final db = await localDatabase.database;
    await db.update(
      'weekly_snapshots',
      {
        'feedback_submitted': 1,
      },
      where: 'week_start = ?',
      whereArgs: [weekStart],
    );
  }

  Future<String?> getSourceHash(String weekStart) async {
    final db = await localDatabase.database;
    final rows = await db.query(
      'weekly_snapshots',
      columns: ['source_hash'],
      where: 'week_start = ?',
      whereArgs: [weekStart],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return rows.first['source_hash'] as String?;
  }

  String buildSourceHash({
    required List<Map<String, dynamic>> entries,
    required Map<String, int> dayCounts,
    required List<String> topTokens,
  }) {
    final buffer = StringBuffer();

    for (final entry in entries) {
      buffer.write(entry['id'] ?? '');
      buffer.write('|');
      buffer.write(entry['content'] ?? '');
      buffer.write('|');
      buffer.write(entry['created_at'] ?? '');
      buffer.write('||');
    }

    final sortedDayKeys = dayCounts.keys.toList()..sort();
    for (final key in sortedDayKeys) {
      buffer.write('$key:${dayCounts[key]}|');
    }

    for (final token in topTokens) {
      buffer.write('token:$token|');
    }

    return buffer.toString();
  }

  WeeklyInsightModel _mapRow(Map<String, Object?> row) {
    return WeeklyInsightModel(
      weekStart: (row['week_start'] as String?) ?? '',
      weekEnd: (row['week_end'] as String?) ?? '',
      status: (row['status'] as String?) ?? 'ready',
      keyInsight: row['key_insight'] as String?,
      patterns: _decodeList(row['patterns_json'] as String?),
      frictions: _decodeList(row['frictions_json'] as String?),
      bestAction: row['best_action'] as String?,
      opportunitySnapshot: _decodeMap(
        row['opportunity_snapshot_json'] as String?,
      ),
      feedbackSubmitted: (row['feedback_submitted'] as int? ?? 0) == 1,
    );
  }

  List<dynamic> _decodeList(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is List) return decoded;
    return const [];
  }

  Map<String, dynamic>? _decodeMap(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry('$key', value));
    }
    return null;
  }
}
