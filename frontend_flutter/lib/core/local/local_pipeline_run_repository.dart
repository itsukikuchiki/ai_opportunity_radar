import 'package:sqflite/sqflite.dart';

import 'local_database.dart';

class LocalPipelineRunRepository {
  static const defaultPipelineVersion = 'v4_p0_05';

  final LocalDatabase localDatabase;

  LocalPipelineRunRepository(this.localDatabase);

  Future<String> start({
    required String pipelineType,
    required String sourceType,
    required String sourceId,
    String localUserId = 'local',
    String? inputHash,
    String pipelineVersion = defaultPipelineVersion,
  }) async {
    final db = await localDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final id = _buildRunId(
      localUserId: localUserId,
      pipelineType: pipelineType,
      sourceType: sourceType,
      sourceId: sourceId,
    );
    await db.insert(
      'pipeline_runs',
      {
        'id': id,
        'local_user_id': localUserId,
        'pipeline_type': pipelineType,
        'source_type': sourceType,
        'source_id': sourceId,
        'status': 'running',
        'started_at': now,
        'input_hash': inputHash,
        'pipeline_version': pipelineVersion,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return id;
  }

  Future<void> complete({
    required String runId,
    String? outputHash,
  }) async {
    final db = await localDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'pipeline_runs',
      {
        'status': 'completed',
        'finished_at': now,
        'output_hash': outputHash,
        'can_retry': 0,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [runId],
    );
  }

  Future<void> fail({
    required String runId,
    String? errorCode,
    String? errorMessage,
    bool canRetry = true,
  }) async {
    final db = await localDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'pipeline_runs',
      {
        'status': 'failed',
        'finished_at': now,
        'error_code': errorCode,
        'error_message': errorMessage,
        'can_retry': canRetry ? 1 : 0,
        'retry_count': 1,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [runId],
    );
  }

  Future<void> recordCompleted({
    required String pipelineType,
    required String sourceType,
    required String sourceId,
    String localUserId = 'local',
    String? inputHash,
    String? outputHash,
    String pipelineVersion = defaultPipelineVersion,
  }) async {
    final runId = await start(
      pipelineType: pipelineType,
      sourceType: sourceType,
      sourceId: sourceId,
      localUserId: localUserId,
      inputHash: inputHash,
      pipelineVersion: pipelineVersion,
    );
    await complete(runId: runId, outputHash: outputHash);
  }

  Future<Map<String, Object?>?> latestForSource({
    required String pipelineType,
    required String sourceType,
    required String sourceId,
  }) async {
    final db = await localDatabase.database;
    final rows = await db.query(
      'pipeline_runs',
      where: 'pipeline_type = ? AND source_type = ? AND source_id = ?',
      whereArgs: [pipelineType, sourceType, sourceId],
      orderBy: 'started_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  String _buildRunId({
    required String localUserId,
    required String pipelineType,
    required String sourceType,
    required String sourceId,
  }) {
    final timestamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    return [
      'pipe',
      _stableIdPart(localUserId),
      _stableIdPart(pipelineType),
      _stableIdPart(sourceType),
      _stableIdPart(sourceId),
      timestamp,
    ].join('_');
  }

  String _stableIdPart(String raw) {
    return raw.replaceAll(RegExp(r'[^A-Za-z0-9_]+'), '_');
  }
}
