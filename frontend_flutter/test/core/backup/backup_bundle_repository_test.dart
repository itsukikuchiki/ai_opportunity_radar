import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_opportunity_radar/core/backup/backup_bundle_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('signalpath_backup_test_');
    SharedPreferences.setMockInitialValues({
      'response_style_preference': 'gentle',
    });
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('exports private app data but excludes local_only SignalCards',
      () async {
    final localDatabase = await _openDatabase(tempDir, 'source.db');
    final prefs = await SharedPreferences.getInstance();
    final repository = BackupBundleRepository(
      localDatabase: localDatabase,
      preferences: prefs,
    );

    await _insertSignalCard(
      localDatabase,
      id: 'sig-private',
      rawText: '今天留下一个信号',
      privacyLevel: 'private',
    );
    await _insertSignalCard(
      localDatabase,
      id: 'sig-local-only',
      rawText: '只留在本机',
      privacyLevel: 'local_only',
    );

    final bundle = await repository.exportBundle(
      localUserId: 'local-user',
      deviceId: 'device-a',
    );

    final signalCards =
        ((bundle['tables'] as Map)['signal_cards'] as List).cast<Map>();
    expect(signalCards.map((row) => row['id']), contains('sig-private'));
    expect(
        signalCards.map((row) => row['id']), isNot(contains('sig-local-only')));
    expect((bundle['counts'] as Map)['signal_cards'], 1);
    expect(
        (bundle['preferences'] as Map)['response_style_preference'], 'gentle');

    await localDatabase.close();
  });

  test('imports a backup bundle into a fresh local database', () async {
    final sourceDatabase = await _openDatabase(tempDir, 'source.db');
    final prefs = await SharedPreferences.getInstance();
    final sourceRepository = BackupBundleRepository(
      localDatabase: sourceDatabase,
      preferences: prefs,
    );

    await _insertSignalCard(
      sourceDatabase,
      id: 'sig-restore',
      rawText: '可以被恢复的记录',
      privacyLevel: 'private',
    );

    final bundle = await sourceRepository.exportBundle(
      localUserId: 'local-user',
      deviceId: 'device-a',
    );
    await sourceDatabase.close();

    final targetDatabase = await _openDatabase(tempDir, 'target.db');
    final targetRepository = BackupBundleRepository(
      localDatabase: targetDatabase,
      preferences: prefs,
    );

    final result = await targetRepository.importBundle(bundle);

    final db = await targetDatabase.database;
    final restoredRows = await db.query(
      'signal_cards',
      where: 'id = ?',
      whereArgs: const ['sig-restore'],
    );

    expect(result.importedRows, greaterThan(0));
    expect(restoredRows, hasLength(1));
    expect(restoredRows.first['raw_text'], '可以被恢复的记录');

    await targetDatabase.close();
  });

  test('deletes local account data and account preferences', () async {
    final localDatabase = await _openDatabase(tempDir, 'delete.db');
    SharedPreferences.setMockInitialValues({
      'cloud_account_session_token': 'session',
      'cloud_account_id': 'account',
      'cloud_latest_backup_version': '2026-06-14T00:00:00Z',
      'local_user_id': 'local-user',
      'device_id': 'device-a',
      'onboarding_completed': true,
      'response_style_preference': 'gentle',
    });
    final prefs = await SharedPreferences.getInstance();
    final repository = BackupBundleRepository(
      localDatabase: localDatabase,
      preferences: prefs,
    );

    await _insertSignalCard(
      localDatabase,
      id: 'sig-delete',
      rawText: '需要被删除的记录',
      privacyLevel: 'private',
    );
    await _insertDraft(localDatabase);

    final deletedRows = await repository.deleteAllLocalData();

    final db = await localDatabase.database;
    expect(deletedRows, greaterThanOrEqualTo(2));
    expect(await db.query('signal_cards'), isEmpty);
    expect(await db.query('signal_card_drafts'), isEmpty);
    expect(prefs.getString('cloud_account_session_token'), isNull);
    expect(prefs.getString('cloud_account_id'), isNull);
    expect(prefs.getString('local_user_id'), isNull);
    expect(prefs.getBool('onboarding_completed'), isNull);

    await localDatabase.close();
  });
}

Future<LocalDatabase> _openDatabase(Directory tempDir, String fileName) async {
  final localDatabase = LocalDatabase(
    dbPathOverride: p.join(tempDir.path, fileName),
    databaseFactoryOverride: databaseFactoryFfi,
  );
  await localDatabase.init();
  return localDatabase;
}

Future<void> _insertSignalCard(
  LocalDatabase localDatabase, {
  required String id,
  required String rawText,
  required String privacyLevel,
}) async {
  final now = DateTime.utc(2026, 6, 14, 9).toIso8601String();
  final db = await localDatabase.database;
  await db.insert('signal_cards', {
    'id': id,
    'signal_card_id': id,
    'source_type': 'text',
    'raw_text': rawText,
    'created_at': now,
    'local_date': '2026-06-14',
    'timezone': 'Asia/Tokyo',
    'language': 'zh-Hans',
    'ai_reply': '先放在这里。',
    'linked_life_chain_stage': '[]',
    'user_confirmation': 'unconfirmed',
    'included_in_summary': 0,
    'included_in_weekly': 0,
    'included_in_journey': 0,
    'privacy_level': privacyLevel,
    'is_legacy': 0,
    'migration_status': 'native',
    'is_local_draft': 0,
    'sync_failed': 0,
    'sync_status': 'synced',
    'updated_at': now,
  });
}

Future<void> _insertDraft(LocalDatabase localDatabase) async {
  final now = DateTime.utc(2026, 6, 14, 9).toIso8601String();
  final db = await localDatabase.database;
  await db.insert('signal_card_drafts', {
    'draft_id': 'draft-delete',
    'raw_text': '还没同步的草稿',
    'source_type': 'text',
    'created_at': now,
    'local_date': '2026-06-14',
    'timezone': 'Asia/Tokyo',
    'language': 'zh-Hans',
    'status': 'pending',
    'retry_count': 0,
    'updated_at': now,
  });
}
