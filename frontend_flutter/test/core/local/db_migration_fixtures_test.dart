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
    test('v38 adds candidate decisions and backfills adopted history',
        () async {
      final tempDir =
          await Directory.systemTemp.createTemp('db_v38_candidate_decision_');
      addTearDown(() async {
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      });
      final path = p.join(tempDir.path, 'legacy_v37.db');
      final legacy = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 37,
          onCreate: (db, _) async {
            await db.execute('''
              CREATE TABLE micro_action_candidates (
                id TEXT PRIMARY KEY,
                local_user_id TEXT NOT NULL DEFAULT 'local',
                status TEXT NOT NULL DEFAULT 'generated',
                adopted_micro_action_id TEXT,
                updated_at TEXT NOT NULL
              )
            ''');
            await db.execute('''
              CREATE TABLE experiment_candidates (
                id TEXT PRIMARY KEY,
                local_user_id TEXT NOT NULL DEFAULT 'local',
                status TEXT NOT NULL DEFAULT 'generated',
                adopted_experiment_id TEXT,
                updated_at TEXT NOT NULL
              )
            ''');
          },
        ),
      );
      const timestamp = '2026-07-16T00:00:00.000Z';
      await legacy.insert('micro_action_candidates', {
        'id': 'micro-adopted',
        'status': 'generated',
        'adopted_micro_action_id': 'micro-1',
        'updated_at': timestamp,
      });
      await legacy.insert('micro_action_candidates', {
        'id': 'micro-considering',
        'status': 'observing',
        'updated_at': timestamp,
      });
      await legacy.insert('experiment_candidates', {
        'id': 'goal-planned',
        'status': 'planned',
        'updated_at': timestamp,
      });
      await legacy.insert('experiment_candidates', {
        'id': 'goal-undecided',
        'status': 'generated',
        'updated_at': timestamp,
      });
      await legacy.close();

      final localDatabase = LocalDatabase(
        dbPathOverride: path,
        databaseFactoryOverride: databaseFactoryFfi,
      );
      addTearDown(localDatabase.close);
      final upgraded = await localDatabase.database;
      expect(await _userVersion(upgraded), 40);
      final microRows = {
        for (final row in await upgraded.query('micro_action_candidates'))
          row['id']: row['decision_status'],
      };
      final goalRows = {
        for (final row in await upgraded.query('experiment_candidates'))
          row['id']: row['decision_status'],
      };
      expect(microRows['micro-adopted'], 'adopted');
      expect(microRows['micro-considering'], 'considering');
      expect(goalRows['goal-planned'], 'adopted');
      expect(goalRows['goal-undecided'], 'undecided');
    });

    test('v39 adds effect review storage without rewriting old feedback',
        () async {
      final tempDir =
          await Directory.systemTemp.createTemp('db_v39_effect_review_');
      addTearDown(() async {
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      });
      final path = p.join(tempDir.path, 'legacy_v38.db');
      final legacy = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 38,
          onCreate: (db, _) async {
            await db.execute('''
              CREATE TABLE life_experiments (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL
              )
            ''');
            await db.execute('''
              CREATE TABLE micro_action_feedback (
                id TEXT PRIMARY KEY,
                micro_action_id TEXT NOT NULL,
                local_date TEXT NOT NULL,
                happened TEXT NOT NULL,
                effect TEXT,
                difficulty TEXT,
                user_note TEXT,
                next_adjustment TEXT,
                created_at TEXT NOT NULL
              )
            ''');
          },
        ),
      );
      await legacy.insert('life_experiments', {
        'id': 'legacy-goal',
        'title': '旧目标',
      });
      await legacy.insert('micro_action_feedback', {
        'id': 'legacy-feedback',
        'micro_action_id': 'legacy-action',
        'local_date': '2026-07-20',
        'happened': 'done',
        'effect': 'helpful',
        'difficulty': 'adjusted',
        'user_note': '旧事实必须保留',
        'next_adjustment': 'continue',
        'created_at': '2026-07-20T00:00:00.000Z',
      });
      await legacy.close();

      final localDatabase = LocalDatabase(
        dbPathOverride: path,
        databaseFactoryOverride: databaseFactoryFfi,
      );
      addTearDown(localDatabase.close);
      final upgraded = await localDatabase.database;
      expect(await _userVersion(upgraded), 40);
      final goal = (await upgraded.query('life_experiments')).single;
      expect(goal['minimum_observation_days'], 3);
      expect(await _tableExists(upgraded, 'micro_action_review_events'), true);
      final legacyFeedback =
          (await upgraded.query('micro_action_feedback')).single;
      expect(legacyFeedback['effect'], 'helpful');
      expect(legacyFeedback['difficulty'], 'adjusted');
      expect(legacyFeedback['user_note'], '旧事实必须保留');
    });

    test('fresh v40 database creates candidate columns before v40 repair',
        () async {
      final tempDir =
          await Directory.systemTemp.createTemp('db_v40_fresh_order_');
      addTearDown(() async {
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      });
      final path = p.join(tempDir.path, 'fresh_v40.db');
      final localDatabase = LocalDatabase(
        dbPathOverride: path,
        databaseFactoryOverride: databaseFactoryFfi,
      );
      addTearDown(localDatabase.close);

      final db = await localDatabase.database;
      expect(await _userVersion(db), 40);
      final columns = await db.rawQuery('PRAGMA table_info(micro_actions)');
      final names = columns.map((row) => row['name']).toSet();
      expect(names, contains('progress_end_date'));
      expect(names, contains('planned_duration_minutes'));
    });

    test('v40 migrates real-attempt and typed-review fields compatibly',
        () async {
      final tempDir =
          await Directory.systemTemp.createTemp('db_v40_attempt_review_');
      addTearDown(() async {
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      });
      final path = p.join(tempDir.path, 'legacy_v39.db');
      final legacy = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 39,
          onCreate: (db, _) async {
            await db.execute('''
              CREATE TABLE micro_actions (
                id TEXT PRIMARY KEY,
                status TEXT,
                progress_start_date TEXT,
                progress_end_date TEXT
              )
            ''');
            await db.execute('''
              CREATE TABLE micro_action_feedback (
                id TEXT PRIMARY KEY
              )
            ''');
            await db.execute('''
              CREATE TABLE micro_action_review_events (
                id TEXT PRIMARY KEY,
                completed_days_at_review INTEGER NOT NULL DEFAULT 0
              )
            ''');
            await db.execute('''
              CREATE TABLE life_experiment_lifecycle_events (
                id TEXT PRIMARY KEY,
                experiment_id TEXT NOT NULL,
                event_type TEXT NOT NULL,
                event_date TEXT NOT NULL
              )
            ''');
          },
        ),
      );
      await legacy.insert('micro_actions', {
        'id': 'open-seven-day-row',
        'status': 'active',
        'progress_start_date': '2026-07-01',
        'progress_end_date': '2026-07-07',
      });
      await legacy.insert('micro_actions', {
        'id': 'terminal-seven-day-row',
        'status': 'completed',
        'progress_start_date': '2026-07-01',
        'progress_end_date': '2026-07-07',
      });
      await legacy.insert('micro_action_feedback', {'id': 'feedback-1'});
      await legacy.insert('micro_action_review_events', {
        'id': 'review-1',
        'completed_days_at_review': 2,
      });
      await legacy.insert('life_experiment_lifecycle_events', {
        'id': 'goal-review-1',
        'experiment_id': 'goal-1',
        'event_type': 'outcome_reviewed',
        'event_date': '2026-07-07T10:00:00.000Z',
      });
      await legacy.close();

      final localDatabase = LocalDatabase(
        dbPathOverride: path,
        databaseFactoryOverride: databaseFactoryFfi,
      );
      addTearDown(localDatabase.close);
      final db = await localDatabase.database;
      expect(await _userVersion(db), 40);

      final open = (await db.query(
        'micro_actions',
        where: 'id = ?',
        whereArgs: ['open-seven-day-row'],
      ))
          .single;
      final terminal = (await db.query(
        'micro_actions',
        where: 'id = ?',
        whereArgs: ['terminal-seven-day-row'],
      ))
          .single;
      expect(open['progress_end_date'], isNull);
      expect(open['planned_duration_minutes'], 10);
      expect(terminal['progress_end_date'], '2026-07-07');
      expect(
        (await db.query('micro_action_review_events'))
            .single['completed_attempts_at_review'],
        2,
      );
      expect(
        (await db.query('life_experiment_lifecycle_events'))
            .single['review_type'],
        'whole_round',
      );
      expect(
        () => db.update(
          'micro_actions',
          {'planned_duration_minutes': 11},
          where: 'id = ?',
          whereArgs: ['open-seven-day-row'],
        ),
        throwsA(isA<DatabaseException>()),
      );
      expect(
        () => db.update(
          'micro_action_feedback',
          {'duration_minutes': 11},
          where: 'id = ?',
          whereArgs: ['feedback-1'],
        ),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('v35 restores legacy daily-completed small tries to active lifecycle',
        () async {
      final tempDir =
          await Directory.systemTemp.createTemp('db_v35_micro_action_');
      addTearDown(() async {
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      });
      final path = p.join(tempDir.path, 'legacy_v34.db');
      final legacy = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 34,
          onCreate: (db, _) async {
            await db.execute('''
              CREATE TABLE micro_actions (
                id TEXT PRIMARY KEY,
                status TEXT,
                adopted_at TEXT,
                origin_candidate_id TEXT
              )
            ''');
            await db.execute('''
              CREATE TABLE micro_action_feedback (
                id TEXT PRIMARY KEY,
                micro_action_id TEXT NOT NULL
              )
            ''');
          },
        ),
      );
      await legacy.insert('micro_actions', {
        'id': 'daily-completion',
        'status': 'done',
        'adopted_at': '2026-07-15T09:00:00Z',
      });
      await legacy.insert('micro_action_feedback', {
        'id': 'feedback-1',
        'micro_action_id': 'daily-completion',
      });
      await legacy.insert('micro_actions', {
        'id': 'explicit-lifecycle-done',
        'status': 'done',
        'adopted_at': '2026-07-15T09:00:00Z',
      });
      await legacy.close();

      final localDatabase = LocalDatabase(
        dbPathOverride: path,
        databaseFactoryOverride: databaseFactoryFfi,
      );
      addTearDown(localDatabase.close);
      final upgraded = await localDatabase.database;
      final daily = await upgraded.query(
        'micro_actions',
        where: 'id = ?',
        whereArgs: ['daily-completion'],
      );
      final explicit = await upgraded.query(
        'micro_actions',
        where: 'id = ?',
        whereArgs: ['explicit-lifecycle-done'],
      );
      expect(daily.single['status'], 'active');
      expect(explicit.single['status'], 'done');
    });

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

      expect(await _userVersion(db), 40);
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
      expect(await _userVersion(upgradedDb), 40);
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

Future<bool> _tableExists(Database db, String table) async {
  final rows = await db.query(
    'sqlite_master',
    columns: const ['name'],
    where: 'type = ? AND name = ?',
    whereArgs: ['table', table],
    limit: 1,
  );
  return rows.isNotEmpty;
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
