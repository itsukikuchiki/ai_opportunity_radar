import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_opportunity_radar/core/local/local_daily_snapshot_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_cache_invalidation_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/local/local_weekly_snapshot_repository.dart';
import 'package:ai_opportunity_radar/core/models/weekly_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late LocalDatabase localDatabase;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('reflection_result_test_');
    localDatabase = LocalDatabase(
      dbPathOverride: p.join(tempDir.path, 'reflection.db'),
      databaseFactoryOverride: databaseFactoryFfi,
    );
    await localDatabase.init();
  });

  tearDown(() async {
    await localDatabase.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('daily snapshot writes AI text into reflection_results', () async {
    final repository = LocalDailySnapshotRepository(localDatabase);

    await repository.upsert(
      date: DateTime(2026, 7, 5),
      entryCount: 2,
      observationText: '今天的能量变化比较明显。',
      suggestionText: '把小实验调轻一点。',
      sourceHash: 'daily-source-v1',
    );

    final db = await localDatabase.database;
    final rows = await db.query('reflection_results');
    final pipelineRows = await db.query('pipeline_runs');

    expect(rows, hasLength(1));
    expect(pipelineRows, hasLength(1));
    expect(rows.first['source_type'], 'daily_snapshot');
    expect(rows.first['source_id'], '2026-07-05');
    expect(rows.first['reflection_type'], 'assist');
    expect(rows.first['ai_level'], 'L1');
    expect(rows.first['source_hash'], 'daily-source-v1');
    expect(rows.first['pipeline_version'], 'v4_p0_05');
    expect(pipelineRows.first['pipeline_type'], 'daily_aggregation');
    expect(pipelineRows.first['status'], 'completed');
    expect(pipelineRows.first['input_hash'], 'daily-source-v1');
    final traceRows = await db.query('trace_links');
    expect(traceRows, hasLength(1));
    expect(traceRows.first['source_type'], 'reflection_result');
    expect(traceRows.first['target_type'], 'daily_snapshot');
    expect(traceRows.first['target_id'], '2026-07-05');
    expect(traceRows.first['relation_type'], 'derived_from');

    final content = jsonDecode(rows.first['content_json'] as String)
        as Map<String, dynamic>;
    expect(content['observation_text'], '今天的能量变化比较明显。');

    final snapshot = await repository.getByDate(DateTime(2026, 7, 5));
    expect(snapshot?.observationText, '今天的能量变化比较明显。');
    expect(snapshot?.suggestionText, '把小实验调轻一点。');
  });

  test('weekly snapshot keeps reflection versions separately', () async {
    final repository = LocalWeeklySnapshotRepository(localDatabase);

    await repository.upsert(
      weekly: WeeklyInsightModel(
        weekStart: '2026-07-06',
        weekEnd: '2026-07-12',
        status: 'ready',
        keyInsight: '本周能量偏低。',
        patterns: const [
          {'name': '会议后更累'},
        ],
        frictions: const [],
        bestAction: '降低实验强度。',
        opportunitySnapshot: const {'energy_budget': 'low'},
        feedbackSubmitted: false,
      ),
      sourceHash: 'weekly-source-v1',
    );

    await repository.upsert(
      weekly: WeeklyInsightModel(
        weekStart: '2026-07-06',
        weekEnd: '2026-07-12',
        status: 'ready',
        keyInsight: '更新后的周复盘。',
        patterns: const [],
        frictions: const [],
        bestAction: '继续轻量实验。',
        opportunitySnapshot: null,
        feedbackSubmitted: false,
      ),
      sourceHash: 'weekly-source-v2',
    );

    final db = await localDatabase.database;
    final rows = await db.query(
      'reflection_results',
      orderBy: 'generated_at ASC',
    );
    final pipelineRows = await db.query(
      'pipeline_runs',
      where: 'pipeline_type = ? AND source_type = ? AND source_id = ?',
      whereArgs: ['weekly_aggregation', 'weekly_snapshot', '2026-07-06'],
    );

    expect(rows, hasLength(2));
    expect(pipelineRows, hasLength(2));
    expect(rows.map((row) => row['status']).toSet(), {
      'superseded',
      'generated',
    });

    final active = rows.singleWhere((row) => row['status'] == 'generated');
    final content =
        jsonDecode(active['content_json'] as String) as Map<String, dynamic>;
    expect(active['source_type'], 'weekly_snapshot');
    expect(active['reflection_type'], 'reflect');
    expect(active['ai_level'], 'L3');
    expect(active['pipeline_version'], 'v4_p0_05');
    expect(content['key_insight'], '更新后的周复盘。');
    expect(pipelineRows.every((row) => row['status'] == 'completed'), isTrue);
    final activeTraceRows = await db.query(
      'trace_links',
      where: 'source_id = ? AND target_type = ? AND target_id = ?',
      whereArgs: [active['id'], 'weekly_snapshot', '2026-07-06'],
    );
    expect(activeTraceRows, hasLength(1));
    expect(activeTraceRows.single['relation_type'], 'derived_from');

    final weekly = await repository.getByWeekStart('2026-07-06');
    expect(weekly?.keyInsight, '更新后的周复盘。');
    expect(weekly?.bestAction, '继续轻量实验。');
  });

  test(
      'dirty snapshot no longer returns source hash and marks reflection stale',
      () async {
    final repository = LocalWeeklySnapshotRepository(localDatabase);

    await repository.upsert(
      weekly: WeeklyInsightModel(
        weekStart: '2026-07-06',
        weekEnd: '2026-07-12',
        status: 'ready',
        keyInsight: '本周先轻一点。',
        patterns: const [],
        frictions: const [],
        bestAction: '降低实验强度。',
        opportunitySnapshot: null,
        feedbackSubmitted: false,
      ),
      sourceHash: 'weekly-source-v1',
    );

    expect(await repository.getSourceHash('2026-07-06'), 'weekly-source-v1');

    await LocalCacheInvalidationRepository(localDatabase).markSnapshotStale(
      table: 'weekly_snapshots',
      keyColumn: 'week_start',
      keyValue: '2026-07-06',
      reason: 'test_stale',
    );

    expect(await repository.getSourceHash('2026-07-06'), isNull);

    final db = await localDatabase.database;
    final snapshot = await db.query(
      'weekly_snapshots',
      where: 'week_start = ?',
      whereArgs: ['2026-07-06'],
      limit: 1,
    );
    final reflection = await db.query(
      'reflection_results',
      where: 'source_type = ? AND source_id = ? AND status = ?',
      whereArgs: ['weekly_snapshot', '2026-07-06', 'generated'],
      limit: 1,
    );

    expect(snapshot.single['dirty'], 1);
    expect(snapshot.single['is_stale'], 1);
    expect(snapshot.single['stale_reason'], 'test_stale');
    expect(reflection.single['dirty'], 1);
    expect(reflection.single['is_stale'], 1);
    expect(reflection.single['stale_reason'], 'test_stale');
  });
}
