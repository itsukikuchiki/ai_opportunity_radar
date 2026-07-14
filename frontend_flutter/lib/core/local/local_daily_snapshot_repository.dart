import 'package:sqflite/sqflite.dart';

import '../debug/legacy_fallback_monitor.dart';
import '../models/today_models.dart';
import 'local_database.dart';
import 'local_pipeline_run_repository.dart';
import 'local_reflection_result_repository.dart';

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
    final reflection =
        await LocalReflectionResultRepository(localDatabase).getLatestContent(
      sourceType: 'daily_snapshot',
      sourceId: key,
      reflectionType: 'assist',
    );
    if (reflection == null) {
      LegacyFallbackMonitor.record(LegacyFallbackMonitor.snapshotAiField);
      return DailySnapshotModel.fromDb(rows.first);
    }
    final merged = Map<String, Object?>.from(rows.first);
    final observationFromReflection =
        _stringOrNull(reflection['observation_text']);
    final suggestionFromReflection =
        _stringOrNull(reflection['suggestion_text']);
    if (observationFromReflection == null &&
        _stringOrNull(merged['observation_text']) != null) {
      LegacyFallbackMonitor.record(LegacyFallbackMonitor.snapshotAiField);
    }
    if (suggestionFromReflection == null &&
        _stringOrNull(merged['suggestion_text']) != null) {
      LegacyFallbackMonitor.record(LegacyFallbackMonitor.snapshotAiField);
    }
    merged['observation_text'] =
        observationFromReflection ?? merged['observation_text'];
    merged['suggestion_text'] =
        suggestionFromReflection ?? merged['suggestion_text'];
    return DailySnapshotModel.fromDb(merged);
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
        'schema_version': 1,
        'pipeline_version': 'v4_p1_06',
        'dirty': 0,
        'is_stale': 0,
        'stale_reason': null,
        'invalidated_at': null,
        'generated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await LocalReflectionResultRepository(localDatabase).saveCurrent(
      sourceType: 'daily_snapshot',
      sourceId: key,
      reflectionType: 'assist',
      aiLevel: 'L1',
      content: {
        'observation_text': observationText,
        'suggestion_text': suggestionText,
      },
      sourceHash: sourceHash,
      generatedAt: DateTime.tryParse(now),
    );
    await LocalPipelineRunRepository(localDatabase).recordCompleted(
      pipelineType: 'daily_aggregation',
      sourceType: 'daily_snapshot',
      sourceId: key,
      inputHash: sourceHash,
      outputHash: sourceHash,
    );
  }

  String buildSourceHash(List<RecentSignalModel> signals) {
    final buffer = StringBuffer();
    for (final signal in signals) {
      buffer.write(signal.id ?? '');
      buffer.write('|');
      buffer.write(signal.content.trim());
      buffer.write('|');
      buffer.write(signal.sourceType);
      buffer.write('|');
      buffer.write(signal.userConfirmation);
      buffer.write('|');
      buffer.write(signal.privacyLevel);
      buffer.write('|');
      buffer.write(signal.isLegacy ? 'legacy' : 'native');
      buffer.write('|');
      buffer.write(signal.isLocalDraft ? 'draft' : 'synced');
      buffer.write('|');
      buffer.write(signal.syncFailed ? 'sync_failed' : 'sync_ok');
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

  String? _stringOrNull(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }
}
