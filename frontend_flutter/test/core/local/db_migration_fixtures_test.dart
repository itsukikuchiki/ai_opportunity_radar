import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_opportunity_radar/core/local/local_database.dart';

void main() {
  sqfliteFfiInit();

  final fixtureDir = Directory(
    p.join(
      Directory.current.path,
      'test',
      'fixtures',
      'db_migrations',
    ),
  );

  group('P2.1-11 DB migration fixtures', () {
    test('all requested fixture files exist with expected user_version',
        () async {
      final expectedVersions = <String, int>{
        'fresh_user_v30.db': 30,
        'legacy_v27_captures.db': 27,
        'legacy_v28_snapshot_ai_fields.db': 28,
        'legacy_v29_life_experiment_embedded.db': 29,
        'legacy_signal_mirror_fields.db': 29,
        'legacy_no_trace_data.db': 30,
        'large_user_2000_signals.db': 32,
        'deleted_signal_with_trace.db': 32,
        'old_prompt_version.db': 32,
      };

      for (final entry in expectedVersions.entries) {
        final file = File(p.join(fixtureDir.path, entry.key));
        expect(file.existsSync(), isTrue, reason: entry.key);

        final db = await _openReadOnly(file);
        addTearDown(db.close);
        expect(await _userVersion(db), entry.value, reason: entry.key);
      }
    });

    test('fixtures contain the expected legacy and edge-case records',
        () async {
      await _withFixture(fixtureDir, 'legacy_v27_captures.db', (db) async {
        expect(await _count(db, 'captures'), 1);
        final rows = await db.query('captures');
        expect(rows.single['ai_observation'], '旧 observation mirror');
      });

      await _withFixture(fixtureDir, 'legacy_v28_snapshot_ai_fields.db',
          (db) async {
        expect(await _count(db, 'weekly_snapshots'), 1);
        expect(await _count(db, 'reflection_results'), 0);
        final rows = await db.query('weekly_snapshots');
        expect(rows.single['key_insight'], contains('旧 weekly snapshot'));
      });

      await _withFixture(fixtureDir, 'legacy_v29_life_experiment_embedded.db',
          (db) async {
        final rows = await db.query('weekly_snapshots');
        final opportunity = jsonDecode(
          rows.single['opportunity_snapshot_json'] as String,
        ) as Map<String, dynamic>;
        expect(opportunity.containsKey('_life_experiment'), isTrue);
      });

      await _withFixture(fixtureDir, 'legacy_signal_mirror_fields.db',
          (db) async {
        expect(await _count(db, 'signal_cards'), 1);
        expect(
          await _count(
            db,
            'signal_processing_state',
            where: 'signal_id = ?',
            whereArgs: ['sig_legacy_mirror_001'],
          ),
          0,
        );
        expect(
          await _count(
            db,
            'signal_analysis_policy',
            where: 'signal_id = ?',
            whereArgs: ['sig_legacy_mirror_001'],
          ),
          0,
        );
      });

      await _withFixture(fixtureDir, 'legacy_no_trace_data.db', (db) async {
        expect(await _count(db, 'life_experiments'), 1);
        expect(await _count(db, 'trace_links'), 0);
      });

      await _withFixture(fixtureDir, 'large_user_2000_signals.db', (db) async {
        expect(await _count(db, 'signal_cards'), 2000);
      });

      await _withFixture(fixtureDir, 'deleted_signal_with_trace.db',
          (db) async {
        expect(
          await _count(
            db,
            'signal_cards',
            where: 'id = ?',
            whereArgs: ['sig_deleted_trace_001'],
          ),
          0,
        );
        expect(
          await _count(
            db,
            'trace_links',
            where: 'target_id = ? AND status = ?',
            whereArgs: ['sig_deleted_trace_001', 'inactive'],
          ),
          1,
        );
        expect(
          await _count(
            db,
            'signal_tombstones',
            where: 'signal_id = ? AND status = ?',
            whereArgs: ['sig_deleted_trace_001', 'active'],
          ),
          1,
        );
      });

      await _withFixture(fixtureDir, 'old_prompt_version.db', (db) async {
        final rows = await db.query('reflection_results');
        expect(rows.single['prompt_version'], 'weekly_reflect_prompt_v1');
        expect(rows.single['model_version'], 'model_reflect_v1');
      });
    });

    test('legacy embedded life experiment fixture upgrades into candidates',
        () async {
      final tempDir =
          await Directory.systemTemp.createTemp('db_fixture_upgrade_test_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final source = File(
        p.join(fixtureDir.path, 'legacy_v29_life_experiment_embedded.db'),
      );
      final copied = await source.copy(p.join(tempDir.path, 'upgrade.db'));
      final localDatabase = LocalDatabase(
        dbPathOverride: copied.path,
        databaseFactoryOverride: databaseFactoryFfi,
      );
      addTearDown(localDatabase.close);

      await localDatabase.init();
      final db = await localDatabase.database;

      expect(await _userVersion(db), 34);
      final candidates = await db.query('experiment_candidates');
      expect(candidates, hasLength(1));
      expect(candidates.single['title'], '旧内嵌实验');
      expect(candidates.single['source_type'], 'weekly_reflection');

      final weeklyRows = await db.query('weekly_snapshots');
      final opportunity = jsonDecode(
        weeklyRows.single['opportunity_snapshot_json'] as String,
      ) as Map<String, dynamic>;
      expect(opportunity.containsKey('_life_experiment'), isFalse);
    });

    test('v32 repairs legacy AI feedback states and keeps edited wording',
        () async {
      final tempDir =
          await Directory.systemTemp.createTemp('observation_feedback_v32_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      final path = p.join(tempDir.path, 'upgrade.db');
      final seedDatabase = LocalDatabase(
        dbPathOverride: path,
        databaseFactoryOverride: databaseFactoryFfi,
      );
      await seedDatabase.init();
      final seedDb = await seedDatabase.database;
      final now = DateTime(2026, 7, 10).toUtc().toIso8601String();

      for (final entry in [
        (
          id: 'ignored',
          status: 'ignored',
          adjustment: null,
          original: '不该继续参与分析',
        ),
        (
          id: 'partial',
          status: 'partial',
          adjustment: '用户修改后的最终表述',
          original: '旧的 AI 表述',
        ),
      ]) {
        await seedDb.insert('ai_judgements', {
          'id': 'aj_${entry.id}',
          'source_signal_card_ids_json': '[]',
          'local_date': '2026-07-10',
          'judgement_text': entry.original,
          'status': entry.status,
          'user_adjustment_text': entry.adjustment,
          'created_at': now,
          'updated_at': now,
        });
        await seedDb.insert('observations', {
          'id': 'obs_${entry.id}',
          'local_user_id': 'local',
          'observation_text': entry.original,
          'observation_type': 'inferred_signal',
          'confidence': 'low',
          'status': 'generated',
          'source_ai_judgement_id': 'aj_${entry.id}',
          'user_adjustment_text': entry.adjustment,
          'created_at': now,
          'updated_at': now,
        });
      }
      await seedDb.execute('PRAGMA user_version = 32');
      await seedDatabase.close();

      final upgradedDatabase = LocalDatabase(
        dbPathOverride: path,
        databaseFactoryOverride: databaseFactoryFfi,
      );
      addTearDown(upgradedDatabase.close);
      await upgradedDatabase.init();
      final upgradedDb = await upgradedDatabase.database;

      final ignored = await upgradedDb.query(
        'observations',
        where: 'id = ?',
        whereArgs: ['obs_ignored'],
      );
      expect(ignored.single['status'], 'dismissed');
      expect(ignored.single['dismissed_at'], isNotNull);
      expect(ignored.single['confirmed_at'], isNull);

      final partial = await upgradedDb.query(
        'observations',
        where: 'id = ?',
        whereArgs: ['obs_partial'],
      );
      expect(partial.single['status'], 'confirmed');
      expect(partial.single['observation_text'], '用户修改后的最终表述');
      expect(partial.single['confirmed_at'], isNotNull);
      expect(partial.single['dismissed_at'], isNull);
      expect(await _userVersion(upgradedDb), 34);
    });
  });
}

Future<void> _withFixture(
  Directory fixtureDir,
  String name,
  Future<void> Function(Database db) callback,
) async {
  final db = await _openReadOnly(File(p.join(fixtureDir.path, name)));
  try {
    await callback(db);
  } finally {
    await db.close();
  }
}

Future<Database> _openReadOnly(File file) {
  return databaseFactoryFfi.openDatabase(
    file.path,
    options: OpenDatabaseOptions(
      readOnly: true,
      singleInstance: false,
    ),
  );
}

Future<int> _userVersion(Database db) async {
  final rows = await db.rawQuery('PRAGMA user_version');
  return rows.single.values.single as int;
}

Future<int> _count(
  Database db,
  String table, {
  String? where,
  List<Object?>? whereArgs,
}) async {
  final rows = await db.query(
    table,
    columns: const ['COUNT(*) AS count'],
    where: where,
    whereArgs: whereArgs,
  );
  return rows.single['count'] as int;
}
