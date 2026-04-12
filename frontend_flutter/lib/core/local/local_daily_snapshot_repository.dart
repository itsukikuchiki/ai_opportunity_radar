import 'package:sqflite/sqflite.dart';

import '../models/today_models.dart';
import 'local_database.dart';

class LocalDailySnapshotRepository {
  final LocalDatabase localDatabase;

  LocalDailySnapshotRepository(this.localDatabase);

  Future<DailySnapshotModel?> getByDate(DateTime date) async {
    final db = await localDatabase.database;
    final key = _dateKey(date);

    final rows = await db.query(
      'daily_snapshots',
      where: 'date = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return DailySnapshotModel.fromDb(rows.first);
  }

  Future<void> upsert({
    required DateTime date,
    required int entryCount,
    required String observationText,
    required String suggestionText,
    required String sourceHash,
  }) async {
    final db = await localDatabase.database;
    final key = _dateKey(date);
    final now = DateTime.now().toUtc().toIso8601String();

    await db.insert(
      'daily_snapshots',
      {
        'date': key,
        'entry_count': entryCount,
        'observation_text': observationText,
        'suggestion_text': suggestionText,
        'source_hash': sourceHash,
        'generated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  String buildSourceHash(List<RecentSignalModel> signals) {
    final buffer = StringBuffer();
    for (final signal in signals) {
      buffer.write(signal.id ?? '');
      buffer.write('|');
      buffer.write(signal.content.trim());
      buffer.write('|');
      buffer.write(signal.createdAt?.toUtc().toIso8601String() ?? '');
      buffer.write('||');
    }
    return buffer.toString();
  }

  String _dateKey(DateTime date) {
    final local = date.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd';
  }
}
