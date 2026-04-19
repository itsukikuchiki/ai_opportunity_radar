import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/memory_models.dart';
import 'local_database.dart';

class LocalJourneySnapshotRepository {
  final LocalDatabase localDatabase;

  LocalJourneySnapshotRepository(this.localDatabase);

  Future<MemorySummaryModel?> getByDate(String snapshotDate) async {
    final db = await localDatabase.database;
    final rows = await db.query(
      'journey_snapshots',
      where: 'snapshot_date = ?',
      whereArgs: [snapshotDate],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return _mapRow(rows.first);
  }

  Future<void> upsert({
    required String snapshotDate,
    required MemorySummaryModel summary,
    required String sourceHash,
  }) async {
    final db = await localDatabase.database;

    await db.insert(
      'journey_snapshots',
      {
        'snapshot_date': snapshotDate,
        'patterns_json': jsonEncode(
          summary.patterns.map((e) => e.toJson()).toList(),
        ),
        'frictions_json': jsonEncode(
          summary.frictions.map((e) => e.toJson()).toList(),
        ),
        'desires_json': jsonEncode(
          summary.desires.map((e) => e.toJson()).toList(),
        ),
        'experiments_json': jsonEncode(
          summary.experiments.map((e) => e.toJson()).toList(),
        ),
        'source_hash': sourceHash,
        'generated_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSourceHash(String snapshotDate) async {
    final db = await localDatabase.database;
    final rows = await db.query(
      'journey_snapshots',
      columns: ['source_hash'],
      where: 'snapshot_date = ?',
      whereArgs: [snapshotDate],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return rows.first['source_hash'] as String?;
  }

  String buildSourceHash({
    required List<Map<String, dynamic>> entries,
    required List<String> topTokens,
    required int totalDays,
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

    for (final token in topTokens) {
      buffer.write('token:$token|');
    }

    buffer.write('days:$totalDays');

    return buffer.toString();
  }

  MemorySummaryModel _mapRow(Map<String, Object?> row) {
    return MemorySummaryModel(
      patterns: _decodeSignalItemList(row['patterns_json'] as String?),
      frictions: _decodeSignalItemList(row['frictions_json'] as String?),
      desires: _decodeSignalItemList(row['desires_json'] as String?),
      experiments: _decodeSignalItemList(row['experiments_json'] as String?),
    );
  }

  List<JourneySignalItemModel> _decodeSignalItemList(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((e) => JourneySignalItemModel.fromJson(e.cast<String, dynamic>()))
        .toList();
  }
}
