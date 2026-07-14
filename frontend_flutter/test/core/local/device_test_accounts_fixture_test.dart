import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  final fixtureDir = _fixtureDir();

  group('P2.1-17 device test account fixtures', () {
    test('all requested account databases and manifest entries exist',
        () async {
      final expected = <String, String>{
        'fresh_user': 'fresh_user.db',
        'legacy_user': 'legacy_user.db',
        'heavy_user': 'heavy_user.db',
        'offline_user': 'offline_user.db',
        'experiment_user': 'experiment_user.db',
        'privacy_user': 'privacy_user.db',
      };

      for (final fileName in expected.values) {
        final file = File(p.join(fixtureDir.path, fileName));
        expect(file.existsSync(), isTrue, reason: fileName);
      }

      final manifestFile = File(p.join(fixtureDir.path, 'manifest.json'));
      expect(manifestFile.existsSync(), isTrue);
      final manifest =
          jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
      final accountIds = (manifest['accounts'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((entry) => entry['account_id'])
          .toSet();
      expect(accountIds, expected.keys.toSet());
    });

    test('fresh user starts empty', () async {
      await _withFixture('fresh_user.db', (db) async {
        expect(await _count(db, 'signal_cards'), 0);
        expect(await _count(db, 'weekly_snapshots'), 0);
        expect(await _count(db, 'life_experiments'), 0);
      });
    });

    test('legacy user covers every requested legacy data sample', () async {
      await _withFixture('legacy_user.db', (db) async {
        expect(await _count(db, 'captures'), 1);

        final weeklyRows = await db.query('weekly_snapshots');
        expect(weeklyRows, hasLength(1));
        final opportunity = jsonDecode(
          weeklyRows.single['opportunity_snapshot_json'] as String,
        ) as Map<String, dynamic>;
        expect(opportunity.containsKey('_life_experiment'), isTrue);
        expect(opportunity['legacy_ai_summary'], isNotNull);

        final deepWeeklyRows = await db.query(
          'reflection_results',
          where: 'reflection_type = ? AND pipeline_version = ?',
          whereArgs: ['deep_weekly', 'legacy_deep_weekly'],
        );
        expect(deepWeeklyRows, hasLength(1));

        expect(await _count(db, 'life_experiment_feedback'), 1);

        expect(
          await _count(
            db,
            'signal_cards',
            where: 'is_legacy = 1',
          ),
          1,
        );
        expect(
          await _count(
            db,
            'signal_processing_state',
            where: 'signal_id = ?',
            whereArgs: ['sig_legacy_mirror_001'],
          ),
          0,
        );
        expect(await _count(db, 'journey_snapshots'), 1);
        expect(await _count(db, 'trace_links'), 0);
      });
    });

    test('heavy user has large period-query dataset', () async {
      await _withFixture('heavy_user.db', (db) async {
        expect(await _count(db, 'signal_cards'), 2000);
        expect(await _count(db, 'signal_processing_state'), 2000);
        expect(await _count(db, 'signal_analysis_policy'), 2000);
        expect(await _count(db, 'journey_snapshots'), 1);
      });
    });

    test('offline user has draft and sync failed retry identities', () async {
      await _withFixture('offline_user.db', (db) async {
        final draftRows = await db.query(
          'signal_cards',
          where: 'client_id = ? AND is_local_draft = 1',
          whereArgs: ['client_offline_retry_001'],
        );
        expect(draftRows, hasLength(1));

        final failedRows = await db.query(
          'signal_cards',
          where: 'client_id = ? AND sync_failed = 1',
          whereArgs: ['client_offline_failed_001'],
        );
        expect(failedRows, hasLength(1));
      });
    });

    test(
        'experiment user contains candidate, lifecycle, rollup, feedback, trace',
        () async {
      await _withFixture('experiment_user.db', (db) async {
        expect(await _count(db, 'experiment_candidates'), 1);
        expect(await _count(db, 'life_experiments'), 1);
        expect(await _count(db, 'life_experiment_lifecycle_events'), 3);
        expect(await _count(db, 'life_experiment_feedback'), 1);
        expect(await _count(db, 'life_experiment_rollups'), 1);
        expect(
          await _count(
            db,
            'trace_links',
            where: 'status = ?',
            whereArgs: ['active'],
          ),
          4,
        );
        expect(await _count(db, 'micro_action_feedback'), 1);
        expect(await _count(db, 'schedule_signals'), 1);
        expect(await _count(db, 'goal_feedback'), 1);
      });
    });

    test(
        'privacy user contains exclusion, tombstone, inactive trace, stale rows',
        () async {
      await _withFixture('privacy_user.db', (db) async {
        expect(
          await _count(
            db,
            'signal_analysis_policy',
            where: 'privacy_level = ? OR inaccurate = 1',
            whereArgs: ['excluded'],
          ),
          2,
        );
        expect(
          await _count(
            db,
            'signal_analysis_policy',
            where: 'do_not_analyze = 1',
          ),
          1,
        );
        expect(await _count(db, 'signal_tombstones'), 1);
        expect(
          await _count(
            db,
            'trace_links',
            where: 'status = ?',
            whereArgs: ['inactive'],
          ),
          1,
        );
        expect(
          await _count(
            db,
            'reflection_results',
            where: 'is_stale = 1',
          ),
          1,
        );
        expect(
          await _count(
            db,
            'experiment_candidates',
            where: 'is_stale = 1',
          ),
          1,
        );
      });
    });
  });

  group('device fixture importer', () {
    test('lists the six supported fixture accounts', () async {
      final result = await Process.run(
        'bash',
        [_importerPath(), '--list'],
        workingDirectory: Directory.current.path,
      );

      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(
        (result.stdout as String).trim().split('\n'),
        [
          'fresh_user',
          'legacy_user',
          'heavy_user',
          'offline_user',
          'experiment_user',
          'privacy_user',
        ],
      );
    });

    test('simulator import backs up, removes sidecars, copies, and repeats',
        () async {
      if (Platform.isWindows) return;

      final tempDir =
          await Directory.systemTemp.createTemp('fixture_importer_test_');
      addTearDown(() => tempDir.delete(recursive: true));
      final documents =
          await Directory(p.join(tempDir.path, 'container', 'Documents'))
              .create(recursive: true);
      final backupRoot =
          await Directory(p.join(tempDir.path, 'backups')).create();
      final destination =
          File(p.join(documents.path, 'ai_opportunity_radar_local.db'));
      final wal = File('${destination.path}-wal');
      await destination.writeAsString('old database');
      await wal.writeAsString('old wal');

      final toolLog = File(p.join(tempDir.path, 'xcrun.log'));
      final fakeXcrun = await _writeExecutable(
        tempDir,
        'fake-xcrun',
        r'''#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$MOCK_XCRUN_LOG"
if [[ "$1" == "simctl" && "$2" == "get_app_container" ]]; then
  printf '%s\n' "$MOCK_CONTAINER"
  exit 0
fi
if [[ "$1" == "simctl" && ( "$2" == "terminate" || "$2" == "launch" ) ]]; then
  exit 0
fi
exit 90
''',
      );
      final fakeSqlite = await _writeExecutable(
        tempDir,
        'fake-sqlite3',
        '#!/usr/bin/env bash\nprintf "ok\\n"\n',
      );
      final environment = {
        ...Platform.environment,
        'XCRUN_BIN': fakeXcrun.path,
        'SQLITE3_BIN': fakeSqlite.path,
        'FIXTURE_IMPORT_BACKUP_ROOT': backupRoot.path,
        'MOCK_XCRUN_LOG': toolLog.path,
        'MOCK_CONTAINER': p.dirname(documents.path),
      };

      final first = await _runImporter(
        ['fresh_user', '--simulator', 'booted'],
        environment: environment,
      );
      expect(first.exitCode, 0, reason: '${first.stdout}\n${first.stderr}');
      expect(
        await destination.readAsBytes(),
        await File(p.join(fixtureDir.path, 'fresh_user.db')).readAsBytes(),
      );
      expect(wal.existsSync(), isFalse);
      final firstBackupNames = backupRoot
          .listSync(recursive: true)
          .whereType<File>()
          .map((file) => p.basename(file.path))
          .toList();
      expect(firstBackupNames, contains('ai_opportunity_radar_local.db'));
      expect(firstBackupNames, contains('ai_opportunity_radar_local.db-wal'));
      expect(firstBackupNames, contains('import.txt'));

      final second = await _runImporter(
        ['legacy_user', '--simulator', 'booted', '--launch'],
        environment: environment,
      );
      expect(second.exitCode, 0, reason: '${second.stdout}\n${second.stderr}');
      expect(
        await destination.readAsBytes(),
        await File(p.join(fixtureDir.path, 'legacy_user.db')).readAsBytes(),
      );
      expect(toolLog.readAsStringSync(), contains('simctl terminate'));
      expect(toolLog.readAsStringSync(), contains('simctl launch'));
      expect(
        backupRoot
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) =>
                p.basename(file.path) == 'ai_opportunity_radar_local.db')
            .length,
        2,
      );
    });

    test('devicectl plan is non-writing and never reports success', () async {
      final tempDir =
          await Directory.systemTemp.createTemp('fixture_device_plan_test_');
      addTearDown(() => tempDir.delete(recursive: true));

      final result = await _runImporter(
        [
          'privacy_user',
          '--device',
          'TEST-UDID',
          '--device-method',
          'devicectl-plan',
        ],
        environment: {
          ...Platform.environment,
          'FIXTURE_IMPORT_BACKUP_ROOT': p.join(tempDir.path, 'backups'),
        },
      );

      expect(result.exitCode, 3);
      expect(result.stderr, contains('NO DEVICE WRITE WAS PERFORMED'));
      expect(result.stderr, contains('devicectl device copy from'));
      expect(result.stderr, contains('devicectl device copy to'));
      expect(result.stdout, isNot(contains('Imported and verified')));
      expect(Directory(p.join(tempDir.path, 'backups')).existsSync(), isFalse);
    });

    test('ios-deploy path backs up, clears sidecars, uploads, and reads back',
        () async {
      if (Platform.isWindows) return;

      final tempDir =
          await Directory.systemTemp.createTemp('fixture_ios_device_test_');
      addTearDown(() => tempDir.delete(recursive: true));
      final deviceDocuments =
          await Directory(p.join(tempDir.path, 'device-documents')).create();
      final remoteDatabase =
          File(p.join(deviceDocuments.path, 'ai_opportunity_radar_local.db'));
      final remoteWal = File('${remoteDatabase.path}-wal');
      await remoteDatabase.writeAsBytes(
        await File(p.join(fixtureDir.path, 'privacy_user.db')).readAsBytes(),
      );
      await remoteWal.writeAsString('stale wal');

      final fakeIosDeploy = await _writeExecutable(
        tempDir,
        'fake-ios-deploy',
        r'''#!/usr/bin/env bash
set -euo pipefail
args=("$@")
for ((i=0; i<${#args[@]}; i++)); do
  case "${args[$i]}" in
    --exists|--kill)
      exit 0
      ;;
    --download=/Documents)
      for ((j=0; j<${#args[@]}; j++)); do
        if [[ "${args[$j]}" == "--to" ]]; then
          destination="${args[$((j + 1))]}"
          mkdir -p "$destination/Documents"
          cp -R "$MOCK_DEVICE_DOCUMENTS/." "$destination/Documents/"
          exit 0
        fi
      done
      ;;
    --rm)
      remote_path="${args[$((i + 1))]}"
      rm -f "$MOCK_DEVICE_DOCUMENTS/${remote_path##*/}"
      exit 0
      ;;
    --upload)
      source_path="${args[$((i + 1))]}"
      for ((j=0; j<${#args[@]}; j++)); do
        if [[ "${args[$j]}" == "--to" ]]; then
          remote_path="${args[$((j + 1))]}"
          cp "$source_path" "$MOCK_DEVICE_DOCUMENTS/${remote_path##*/}"
          exit 0
        fi
      done
      ;;
  esac
done
exit 91
''',
      );
      final fakeSqlite = await _writeExecutable(
        tempDir,
        'fake-sqlite3',
        '#!/usr/bin/env bash\nprintf "ok\\n"\n',
      );
      final backupRoot = p.join(tempDir.path, 'backups');

      final result = await _runImporter(
        [
          'experiment_user',
          '--device',
          'TEST-UDID',
          '--device-method',
          'ios-deploy',
        ],
        environment: {
          ...Platform.environment,
          'IOS_DEPLOY_BIN': fakeIosDeploy.path,
          'SQLITE3_BIN': fakeSqlite.path,
          'FIXTURE_IMPORT_BACKUP_ROOT': backupRoot,
          'MOCK_DEVICE_DOCUMENTS': deviceDocuments.path,
        },
      );

      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(result.stdout, contains('Imported and verified'));
      expect(
        await remoteDatabase.readAsBytes(),
        await File(p.join(fixtureDir.path, 'experiment_user.db')).readAsBytes(),
      );
      expect(remoteWal.existsSync(), isFalse);
      final backupNames = Directory(backupRoot)
          .listSync(recursive: true)
          .whereType<File>()
          .map((file) => p.basename(file.path))
          .toList();
      expect(backupNames, contains('ai_opportunity_radar_local.db-wal'));
      expect(backupNames, contains('import.txt'));
    });

    test('unknown account fails before any target lookup', () async {
      final result = await _runImporter(['not_a_fixture', '--dry-run']);

      expect(result.exitCode, 2);
      expect(result.stderr, contains('Unknown fixture account'));
      expect(result.stdout, isNot(contains('Imported and verified')));
    });
  });
}

Directory _fixtureDir() {
  return Directory(
    p.join(Directory.current.path, 'test', 'fixtures', 'device_accounts'),
  );
}

Future<void> _withFixture(
  String fileName,
  Future<void> Function(Database db) body,
) async {
  final file = File(p.join(_fixtureDir().path, fileName));
  final db = await databaseFactoryFfi.openDatabase(file.path);
  addTearDown(db.close);
  await body(db);
}

Future<int> _count(
  Database db,
  String table, {
  String? where,
  List<Object?>? whereArgs,
}) async {
  final rows = await db.query(table, where: where, whereArgs: whereArgs);
  return rows.length;
}

String _importerPath() =>
    p.join(Directory.current.path, 'tool', 'import_device_fixture.sh');

Future<ProcessResult> _runImporter(
  List<String> arguments, {
  Map<String, String>? environment,
}) {
  return Process.run(
    'bash',
    [_importerPath(), ...arguments],
    workingDirectory: Directory.current.path,
    environment: environment,
  );
}

Future<File> _writeExecutable(
  Directory directory,
  String name,
  String contents,
) async {
  final file = File(p.join(directory.path, name));
  await file.writeAsString(contents);
  final chmod = await Process.run('chmod', ['+x', file.path]);
  expect(chmod.exitCode, 0, reason: '${chmod.stderr}');
  return file;
}
