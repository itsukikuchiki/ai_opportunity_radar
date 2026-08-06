import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/memory_models.dart';
import 'local_cache_invalidation_repository.dart';
import 'local_database.dart';
import 'local_pipeline_run_repository.dart';
import 'local_reflection_result_repository.dart';
import 'local_trace_link_repository.dart';

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
    final reflection =
        await LocalReflectionResultRepository(localDatabase).getLatestContent(
      sourceType: 'journey_snapshot',
      sourceId: snapshotDate,
      reflectionType: 'reflect',
    );
    return _mapRow(rows.first, reflection: reflection);
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
        'journey_data_json': jsonEncode({
          'life_direction': summary.lifeDirection?.toJson(),
          'journey_themes':
              summary.journeyThemes.map((e) => e.toJson()).toList(),
          'journey_traces':
              summary.journeyTraces.map((e) => e.toJson()).toList(),
          'observations': summary.observations.map((e) => e.toJson()).toList(),
          'phase_memory': summary.phaseMemory?.toJson(),
          'period_facts': summary.periodFacts?.toJson(),
        }),
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
      sourceType: 'journey_snapshot',
      sourceId: snapshotDate,
      reflectionType: 'reflect',
      aiLevel: 'L3',
      content: {
        'patterns': summary.patterns.map((e) => e.toJson()).toList(),
        'frictions': summary.frictions.map((e) => e.toJson()).toList(),
        'desires': summary.desires.map((e) => e.toJson()).toList(),
        'experiments': summary.experiments.map((e) => e.toJson()).toList(),
        'journey_data': {
          'life_direction': summary.lifeDirection?.toJson(),
          'journey_themes':
              summary.journeyThemes.map((e) => e.toJson()).toList(),
          'journey_traces':
              summary.journeyTraces.map((e) => e.toJson()).toList(),
          'observations': summary.observations.map((e) => e.toJson()).toList(),
          'phase_memory': summary.phaseMemory?.toJson(),
          'period_facts': summary.periodFacts?.toJson(),
        },
      },
      sourceHash: sourceHash,
    );
    await LocalTraceLinkRepository(localDatabase).replaceForSource(
      sourceType: 'journey_snapshot',
      sourceId: snapshotDate,
      links: summary.journeyTraces.map(
        (trace) => TraceLinkInput(
          sourceType: 'journey_snapshot',
          sourceId: snapshotDate,
          targetType: trace.sourceType,
          targetId: trace.id,
          relationType: 'uses_trace',
          metadata: {
            'local_date': trace.localDate,
            'cluster': trace.cluster,
            'signal_level': trace.signalLevel,
          },
        ),
      ),
    );
    await LocalPipelineRunRepository(localDatabase).recordCompleted(
      pipelineType: 'journey_aggregation',
      sourceType: 'journey_snapshot',
      sourceId: snapshotDate,
      inputHash: sourceHash,
      outputHash: sourceHash,
    );
  }

  Future<String?> getSourceHash(String snapshotDate) async {
    return LocalCacheInvalidationRepository(localDatabase).validSourceHash(
      table: 'journey_snapshots',
      keyColumn: 'snapshot_date',
      keyValue: snapshotDate,
    );
  }

  String buildSourceHash({
    required List<Map<String, dynamic>> entries,
    required List<String> topTokens,
    required int totalDays,
    List<Map<String, dynamic>> experimentHistory = const [],
    List<Map<String, dynamic>> traceEntries = const [],
    List<Map<String, dynamic>> observationEntries = const [],
    String language = '',
  }) {
    final buffer = StringBuffer();
    buffer.write('language:$language||');

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

    for (final experiment in experimentHistory) {
      buffer.write('experiment:');
      buffer.write(experiment['id'] ?? '');
      buffer.write('|');
      buffer.write(experiment['status'] ?? '');
      buffer.write('|');
      buffer.write(experiment['feedback_text'] ?? '');
      buffer.write('|');
      buffer.write(experiment['updated_at'] ?? '');
      buffer.write('||');
    }

    for (final trace in traceEntries) {
      buffer.write('trace:');
      buffer.write(trace['id'] ?? '');
      buffer.write('|');
      buffer.write(trace['source_type'] ?? '');
      buffer.write('|');
      buffer.write(trace['local_date'] ?? '');
      buffer.write('|');
      buffer.write(trace['summary'] ?? '');
      buffer.write('|');
      buffer.write(trace['cluster'] ?? '');
      buffer.write('|');
      buffer.write(trace['intensity'] ?? '');
      buffer.write('|');
      buffer.write(trace['signal_level'] ?? '');
      buffer.write('|');
      buffer.write(jsonEncode(trace['metadata'] ?? const {}));
      buffer.write('||');
    }

    for (final observation in observationEntries) {
      buffer.write('observation:');
      buffer.write(observation['id'] ?? '');
      buffer.write('|');
      buffer.write(observation['status'] ?? '');
      buffer.write('|');
      buffer.write(observation['text'] ?? '');
      buffer.write('|');
      buffer.write(observation['updated_at'] ?? '');
      buffer.write('||');
    }

    buffer.write('days:$totalDays');

    return buffer.toString();
  }

  MemorySummaryModel _mapRow(
    Map<String, Object?> row, {
    Map<String, dynamic>? reflection,
  }) {
    final journeyData = _mapOrNull(reflection?['journey_data']) ??
        _decodeMap(row['journey_data_json'] as String?);
    return MemorySummaryModel(
      patterns: _signalItemsFromValue(reflection?['patterns']) ??
          _decodeSignalItemList(row['patterns_json'] as String?),
      frictions: _signalItemsFromValue(reflection?['frictions']) ??
          _decodeSignalItemList(row['frictions_json'] as String?),
      desires: _signalItemsFromValue(reflection?['desires']) ??
          _decodeSignalItemList(row['desires_json'] as String?),
      experiments: _signalItemsFromValue(reflection?['experiments']) ??
          _decodeSignalItemList(row['experiments_json'] as String?),
      lifeDirection: journeyData['life_direction'] is Map
          ? LifeDirectionModel.fromJson(
              (journeyData['life_direction'] as Map).cast<String, dynamic>(),
            )
          : null,
      journeyThemes: ((journeyData['journey_themes'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => JourneyThemeModel.fromJson(e.cast<String, dynamic>()))
          .toList(),
      journeyTraces: ((journeyData['journey_traces'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => JourneyTraceModel.fromJson(e.cast<String, dynamic>()))
          .toList(),
      observations: ((journeyData['observations'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) =>
              JourneyObservationModel.fromJson(e.cast<String, dynamic>()))
          .toList(),
      phaseMemory: journeyData['phase_memory'] is Map
          ? PhaseMemoryModel.fromJson(
              (journeyData['phase_memory'] as Map).cast<String, dynamic>(),
            )
          : null,
      periodFacts: journeyData['period_facts'] is Map
          ? JourneyPeriodFactsModel.fromJson(
              (journeyData['period_facts'] as Map).cast<String, dynamic>(),
            )
          : null,
    );
  }

  Map<String, dynamic> _decodeMap(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return const {};
    return decoded.cast<String, dynamic>();
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

  List<JourneySignalItemModel>? _signalItemsFromValue(Object? value) {
    if (value is! List) return null;
    return value
        .whereType<Map>()
        .map((e) => JourneySignalItemModel.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Map<String, dynamic>? _mapOrNull(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, value) => MapEntry('$key', value));
    }
    return null;
  }
}
