import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_opportunity_radar/core/local/local_database.dart';

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late LocalDatabase localDatabase;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('legacy_migration_test_');
    localDatabase = LocalDatabase(
      dbPathOverride: p.join(tempDir.path, 'local.db'),
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

  test('P2-04 migrates legacy weekly life experiment cache once', () async {
    final db = await localDatabase.database;
    await db.insert('weekly_snapshots', {
      'week_start': '2026-07-01',
      'week_end': '2026-07-07',
      'status': 'ready',
      'key_insight': '本周需要降低实验强度。',
      'patterns_json': '[]',
      'frictions_json': '[]',
      'best_action': '午后留一点空白。',
      'opportunity_snapshot_json': jsonEncode({
        'energy_budget': 'low',
        '_life_experiment': {
          'title': '午后留白',
          'hypothesis': '少安排会更容易恢复',
          'suggested_action': '午后留 10 分钟',
          'status': 'suggested',
          'linked_signal_card_ids': ['sig_1'],
        },
      }),
      'chart_data_json': '[]',
      'feedback_submitted': 0,
      'source_hash': 'weekly-source-v1',
      'generated_at': '2026-07-08T00:00:00.000Z',
    });

    await localDatabase.runP2LegacyDataMigration();
    await localDatabase.runP2LegacyDataMigration();

    final candidates = await db.query('experiment_candidates');
    expect(candidates, hasLength(1));
    expect(candidates.single['id'], 'cand_local_2026_07_01');
    expect(candidates.single['source_type'], 'weekly_reflection');
    expect(candidates.single['source_id'], '2026-07-01');
    expect(candidates.single['title'], '午后留白');
    expect(candidates.single['hypothesis'], '少安排会更容易恢复');
    expect(candidates.single['suggested_action'], '午后留 10 分钟');
    expect(candidates.single['linked_signal_card_ids_json'],
        jsonEncode(['sig_1']));

    final metadata = jsonDecode(candidates.single['metadata_json'] as String)
        as Map<String, dynamic>;
    expect(metadata['created_from'], 'legacy_opportunity_snapshot_migration');
    expect(metadata['legacy_source'], 'weekly_snapshot._life_experiment');
    expect(metadata['legacy_source_unknown'], isFalse);

    final weeklyRows = await db.query('weekly_snapshots');
    final sanitizedOpportunity =
        jsonDecode(weeklyRows.single['opportunity_snapshot_json'] as String)
            as Map<String, dynamic>;
    expect(sanitizedOpportunity.containsKey('_life_experiment'), isFalse);

    final reflections = await db.query('reflection_results');
    final reflectionContent =
        jsonDecode(reflections.single['content_json'] as String)
            as Map<String, dynamic>;
    final reflectedOpportunity =
        reflectionContent['opportunity_snapshot'] as Map<String, dynamic>;
    expect(reflectedOpportunity.containsKey('_life_experiment'), isFalse);

    final traceLinks = await db.query(
      'trace_links',
      where: 'source_type = ? AND source_id = ?',
      whereArgs: ['experiment_candidate', 'cand_local_2026_07_01'],
      orderBy: 'relation_type ASC',
    );
    expect(traceLinks, hasLength(2));
    expect(
      traceLinks.map((row) => row['relation_type']),
      containsAll(['legacy_linked_signal', 'legacy_migrated_from']),
    );
    expect(
      traceLinks.where((row) =>
          row['target_type'] == 'weekly_snapshot' &&
          row['target_id'] == '2026-07-01'),
      hasLength(1),
    );
    expect(
      traceLinks.where((row) =>
          row['target_type'] == 'signal_card' && row['target_id'] == 'sig_1'),
      hasLength(1),
    );
  });
}
