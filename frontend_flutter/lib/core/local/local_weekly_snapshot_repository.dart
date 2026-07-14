import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../debug/legacy_fallback_monitor.dart';
import '../models/weekly_models.dart';
import 'local_cache_invalidation_repository.dart';
import 'local_database.dart';
import 'local_pipeline_run_repository.dart';
import 'local_reflection_result_repository.dart';

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
    final reflection =
        await LocalReflectionResultRepository(localDatabase).getLatestContent(
      sourceType: 'weekly_snapshot',
      sourceId: weekStart,
      reflectionType: 'reflect',
    );
    return _mapRow(rows.first, reflection: reflection);
  }

  Future<void> upsert({
    required WeeklyInsightModel weekly,
    required String sourceHash,
  }) async {
    final db = await localDatabase.database;
    final opportunitySnapshotForWrite =
        _opportunitySnapshotForActiveWrite(weekly.opportunitySnapshot);

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
        'opportunity_snapshot_json': opportunitySnapshotForWrite == null
            ? null
            : jsonEncode(opportunitySnapshotForWrite),
        'chart_data_json': jsonEncode(
          weekly.chartData.map((e) => e.toJson()).toList(),
        ),
        'feedback_submitted': weekly.feedbackSubmitted ? 1 : 0,
        'source_hash': sourceHash,
        'schema_version': 1,
        'pipeline_version': 'v4_p1_06',
        'dirty': 0,
        'is_stale': 0,
        'stale_reason': null,
        'invalidated_at': null,
        'generated_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await LocalReflectionResultRepository(localDatabase).saveCurrent(
      sourceType: 'weekly_snapshot',
      sourceId: weekly.weekStart,
      reflectionType: 'reflect',
      aiLevel: 'L3',
      content: {
        'key_insight': weekly.keyInsight,
        'patterns': weekly.patterns,
        'frictions': weekly.frictions,
        'best_action': weekly.bestAction,
        'opportunity_snapshot': opportunitySnapshotForWrite,
      },
      sourceHash: sourceHash,
    );
    await LocalPipelineRunRepository(localDatabase).recordCompleted(
      pipelineType: 'weekly_aggregation',
      sourceType: 'weekly_snapshot',
      sourceId: weekly.weekStart,
      inputHash: sourceHash,
      outputHash: sourceHash,
    );
  }

  Map<String, dynamic>? _opportunitySnapshotForActiveWrite(
    Map<String, dynamic>? snapshot,
  ) {
    if (snapshot == null) return null;
    final sanitized = Map<String, dynamic>.from(snapshot)
      ..remove('_life_experiment');
    return sanitized.isEmpty ? null : sanitized;
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
    return LocalCacheInvalidationRepository(localDatabase).validSourceHash(
      table: 'weekly_snapshots',
      keyColumn: 'week_start',
      keyValue: weekStart,
    );
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

  WeeklyInsightModel _mapRow(
    Map<String, Object?> row, {
    Map<String, dynamic>? reflection,
  }) {
    final reflectedKeyInsight = _stringOrNull(reflection?['key_insight']);
    final reflectedPatterns = _listOrNull(reflection?['patterns']);
    final reflectedFrictions = _listOrNull(reflection?['frictions']);
    final reflectedBestAction = _stringOrNull(reflection?['best_action']);
    final reflectedOpportunity =
        _mapOrNull(reflection?['opportunity_snapshot']);
    if (reflectedKeyInsight == null && row['key_insight'] != null) {
      LegacyFallbackMonitor.record(LegacyFallbackMonitor.snapshotAiField);
    }
    if (reflectedPatterns == null && row['patterns_json'] != null) {
      LegacyFallbackMonitor.record(LegacyFallbackMonitor.snapshotAiField);
    }
    if (reflectedFrictions == null && row['frictions_json'] != null) {
      LegacyFallbackMonitor.record(LegacyFallbackMonitor.snapshotAiField);
    }
    if (reflectedBestAction == null && row['best_action'] != null) {
      LegacyFallbackMonitor.record(LegacyFallbackMonitor.snapshotAiField);
    }
    if (reflectedOpportunity == null &&
        row['opportunity_snapshot_json'] != null) {
      LegacyFallbackMonitor.record(LegacyFallbackMonitor.snapshotAiField);
    }
    return WeeklyInsightModel(
      weekStart: (row['week_start'] as String?) ?? '',
      weekEnd: (row['week_end'] as String?) ?? '',
      status: (row['status'] as String?) ?? 'ready',
      keyInsight: reflectedKeyInsight ?? row['key_insight'] as String?,
      patterns:
          reflectedPatterns ?? _decodeList(row['patterns_json'] as String?),
      frictions:
          reflectedFrictions ?? _decodeList(row['frictions_json'] as String?),
      bestAction: reflectedBestAction ?? row['best_action'] as String?,
      opportunitySnapshot: reflectedOpportunity ??
          _decodeMap(
            row['opportunity_snapshot_json'] as String?,
          ),
      feedbackSubmitted: (row['feedback_submitted'] as int? ?? 0) == 1,
      chartData: _decodeChartData(row['chart_data_json'] as String?),
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

  List<WeeklyChartPointModel> _decodeChartData(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((e) => WeeklyChartPointModel.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  String? _stringOrNull(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  List<dynamic>? _listOrNull(Object? value) {
    if (value is List) return value;
    return null;
  }

  Map<String, dynamic>? _mapOrNull(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, value) => MapEntry('$key', value));
    }
    return null;
  }
}
