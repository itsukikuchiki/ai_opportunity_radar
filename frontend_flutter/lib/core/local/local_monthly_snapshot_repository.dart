import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/monthly_models.dart';
import 'local_database.dart';

class LocalMonthlySnapshotRepository {
  final LocalDatabase localDatabase;

  LocalMonthlySnapshotRepository(this.localDatabase);

  Future<MonthlyReviewModel?> getByMonthStart(String monthStart) async {
    final db = await localDatabase.database;
    final rows = await db.query(
      'monthly_snapshots',
      where: 'month_start = ?',
      whereArgs: [monthStart],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return _mapRow(rows.first);
  }

  Future<void> upsert({
    required MonthlyReviewModel monthly,
    required String sourceHash,
  }) async {
    final db = await localDatabase.database;
    await db.insert(
      'monthly_snapshots',
      {
        'month_start': monthly.monthStart,
        'month_end': monthly.monthEnd,
        'status': monthly.status,
        'monthly_summary': monthly.monthlySummary,
        'repeated_themes_json': jsonEncode(monthly.repeatedThemes),
        'improving_signals_json': jsonEncode(monthly.improvingSignals),
        'unresolved_points_json': jsonEncode(monthly.unresolvedPoints),
        'next_month_watch': monthly.nextMonthWatch,
        'weekly_bridges_json': jsonEncode(
          monthly.weeklyBridges.map((e) => e.toJson()).toList(),
        ),
        'source_hash': sourceHash,
        'generated_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSourceHash(String monthStart) async {
    final db = await localDatabase.database;
    final rows = await db.query(
      'monthly_snapshots',
      columns: ['source_hash'],
      where: 'month_start = ?',
      whereArgs: [monthStart],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['source_hash'] as String?;
  }

  String buildSourceHash({
    required List<Map<String, dynamic>> entries,
    required Map<String, int> weekCounts,
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
    final keys = weekCounts.keys.toList()..sort();
    for (final key in keys) {
      buffer.write('$key:${weekCounts[key]}|');
    }
    for (final token in topTokens) {
      buffer.write('token:$token|');
    }
    return buffer.toString();
  }

  MonthlyReviewModel _mapRow(Map<String, Object?> row) {
    return MonthlyReviewModel(
      monthStart: (row['month_start'] as String?) ?? '',
      monthEnd: (row['month_end'] as String?) ?? '',
      status: (row['status'] as String?) ?? 'ready',
      monthlySummary: row['monthly_summary'] as String?,
      repeatedThemes: _decodeStringList(row['repeated_themes_json'] as String?),
      improvingSignals: _decodeStringList(row['improving_signals_json'] as String?),
      unresolvedPoints: _decodeStringList(row['unresolved_points_json'] as String?),
      nextMonthWatch: row['next_month_watch'] as String?,
      weeklyBridges: _decodeWeeklyBridges(row['weekly_bridges_json'] as String?),
    );
  }

  List<String> _decodeStringList(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .map((e) => e?.toString() ?? '')
        .where((e) => e.trim().isNotEmpty)
        .toList();
  }

  List<MonthlyBridgeWeekModel> _decodeWeeklyBridges(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((e) => MonthlyBridgeWeekModel.fromJson(e.cast<String, dynamic>()))
        .toList();
  }
}
