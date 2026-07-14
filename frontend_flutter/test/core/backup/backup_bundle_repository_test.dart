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

  test('roundtrips AI judgement and Observation feedback, then deletes it',
      () async {
    final sourceDatabase = await _openDatabase(tempDir, 'feedback-source.db');
    final prefs = await SharedPreferences.getInstance();
    final sourceRepository = BackupBundleRepository(
      localDatabase: sourceDatabase,
      preferences: prefs,
    );
    await _insertSignalCard(
      sourceDatabase,
      id: 'sig-feedback-source',
      rawText: '用于预判的信号',
      privacyLevel: 'private',
    );
    await _insertPredictionFeedback(sourceDatabase);

    final bundle = await sourceRepository.exportBundle(
      localUserId: 'local-user',
      deviceId: 'device-a',
    );
    expect(((bundle['tables'] as Map)['ai_judgements'] as List), hasLength(1));
    expect(((bundle['tables'] as Map)['observations'] as List), hasLength(1));
    expect(
      ((bundle['tables'] as Map)['observation_signal_links'] as List),
      hasLength(1),
    );
    expect(((bundle['tables'] as Map)['trace_links'] as List), hasLength(1));
    await sourceDatabase.close();

    final targetDatabase = await _openDatabase(tempDir, 'feedback-target.db');
    final targetRepository = BackupBundleRepository(
      localDatabase: targetDatabase,
      preferences: prefs,
    );
    await targetRepository.importBundle(bundle);
    final db = await targetDatabase.database;
    expect(await db.query('ai_judgements'), hasLength(1));
    expect(await db.query('observations'), hasLength(1));
    expect(await db.query('observation_signal_links'), hasLength(1));
    expect(await db.query('trace_links'), hasLength(1));

    await targetRepository.deleteAllLocalData();
    expect(await db.query('ai_judgements'), isEmpty);
    expect(await db.query('observations'), isEmpty);
    expect(await db.query('observation_signal_links'), isEmpty);
    expect(await db.query('trace_links'), isEmpty);
    await targetDatabase.close();
  });

  test('roundtrips and deletes canonical SignalCard control-plane tables',
      () async {
    final sourceDatabase = await _openDatabase(tempDir, 'control-source.db');
    final prefs = await SharedPreferences.getInstance();
    final sourceRepository = BackupBundleRepository(
      localDatabase: sourceDatabase,
      preferences: prefs,
    );
    await _insertSignalCard(
      sourceDatabase,
      id: 'sig-control',
      rawText: '用于控制面备份的信号',
      privacyLevel: 'private',
    );
    await _insertCanonicalControlPlaneRows(sourceDatabase);

    final bundle = await sourceRepository.exportBundle(
      localUserId: 'local-user',
      deviceId: 'device-a',
    );
    final tables = bundle['tables'] as Map;
    for (final table in const [
      'signal_tombstones',
      'signal_sync_identity',
      'signal_processing_state',
      'signal_analysis_policy',
      'reflection_results',
      'pipeline_runs',
    ]) {
      expect(tables[table], hasLength(1), reason: '$table must be backed up');
    }
    await sourceDatabase.close();

    final targetDatabase = await _openDatabase(tempDir, 'control-target.db');
    final targetRepository = BackupBundleRepository(
      localDatabase: targetDatabase,
      preferences: prefs,
    );
    await targetRepository.importBundle(bundle);
    final db = await targetDatabase.database;
    for (final table in const [
      'signal_tombstones',
      'signal_sync_identity',
      'signal_processing_state',
      'signal_analysis_policy',
      'reflection_results',
      'pipeline_runs',
    ]) {
      expect(await db.query(table), hasLength(1),
          reason: '$table must be restored');
    }

    await targetRepository.deleteAllLocalData();
    for (final table in const [
      'signal_tombstones',
      'signal_sync_identity',
      'signal_processing_state',
      'signal_analysis_policy',
      'reflection_results',
      'pipeline_runs',
    ]) {
      expect(await db.query(table), isEmpty,
          reason: '$table must be removed on account deletion');
    }
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
      'selected_focus_domains': <String>['growth_plan'],
      'external_health_abstract_hints_json': '{"low_recovery_hint":"low"}',
      'external_calendar_abstract_hints_json':
          '{"schedule_density_hint":"dense"}',
      'installation_date': '2026-07-01T00:00:00.000',
      'local_app_started_date': '2026-07-01T00:00:00.000',
      'me_profile_display_name': 'Mina',
      'me_life_direction': '给恢复和创造留空间',
      'me_life_direction_created_at': '2026-07-13T00:00:00Z',
      'premium_entitlement_active': true,
      'premium_entitlement_product_id': 'pro.yearly',
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
    expect(prefs.getString('me_profile_display_name'), isNull);
    expect(prefs.getString('me_life_direction'), isNull);
    expect(prefs.getStringList('selected_focus_domains'), isNull);
    expect(prefs.getString('external_health_abstract_hints_json'), isNull);
    expect(prefs.getString('external_calendar_abstract_hints_json'), isNull);
    expect(prefs.getString('installation_date'), isNull);
    expect(prefs.getString('local_app_started_date'), isNull);
    expect(prefs.getBool('premium_entitlement_active'), isTrue,
        reason: 'StoreKit entitlement is independent from diary deletion');
    expect(prefs.getString('premium_entitlement_product_id'), 'pro.yearly');

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
    'client_id': 'draft-delete-client',
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

Future<void> _insertCanonicalControlPlaneRows(
  LocalDatabase localDatabase,
) async {
  const now = '2026-07-13T01:00:00.000Z';
  final db = await localDatabase.database;
  await db.insert('signal_tombstones', {
    'signal_id': 'sig-deleted',
    'signal_card_id': 'sig-deleted',
    'reason': 'user_deleted',
    'status': 'active',
    'deleted_at': now,
    'updated_at': now,
  });
  await db.insert('signal_sync_identity', {
    'client_id': 'client-control',
    'server_id': 'server-control',
    'local_signal_id': 'sig-control',
    'sync_status': 'synced',
    'last_synced_at': now,
    'created_at': now,
    'updated_at': now,
  });
  await db.insert('signal_processing_state', {
    'signal_id': 'sig-control',
    'sync_status': 'synced',
    'created_at': now,
    'updated_at': now,
  });
  await db.insert('signal_analysis_policy', {
    'signal_id': 'sig-control',
    'privacy_level': 'private',
    'confirmed_by_user': 1,
    'updated_at': now,
  });
  await db.insert('reflection_results', {
    'id': 'reflection-control',
    'source_type': 'signal_card',
    'source_id': 'sig-control',
    'reflection_type': 'l1_attune',
    'ai_level': 'l1',
    'content_json': '{"text":"收到"}',
    'generated_at': now,
    'created_at': now,
    'updated_at': now,
  });
  await db.insert('pipeline_runs', {
    'id': 'pipeline-control',
    'local_user_id': 'local-user',
    'pipeline_type': 'daily_reflection',
    'source_type': 'signal_card',
    'source_id': 'sig-control',
    'status': 'completed',
    'started_at': now,
    'finished_at': now,
    'created_at': now,
    'updated_at': now,
  });
}

Future<void> _insertPredictionFeedback(LocalDatabase localDatabase) async {
  final now = DateTime.utc(2026, 6, 14, 9).toIso8601String();
  final db = await localDatabase.database;
  await db.insert('ai_judgements', {
    'id': 'aj-feedback',
    'source_signal_card_ids_json': '["sig-feedback-source"]',
    'local_date': '2026-06-14',
    'judgement_text': '连续安排后需要一点恢复。',
    'status': 'partial',
    'user_adjustment_text': '更接近连续切换后的疲惫。',
    'created_at': now,
    'updated_at': now,
  });
  await db.insert('observations', {
    'id': 'obs-feedback',
    'local_user_id': 'local-user',
    'observation_text': '更接近连续切换后的疲惫。',
    'observation_type': 'inferred_signal',
    'confidence': 'low',
    'status': 'confirmed',
    'source_ai_judgement_id': 'aj-feedback',
    'created_at': now,
    'updated_at': now,
    'confirmed_at': now,
  });
  await db.insert('observation_signal_links', {
    'observation_id': 'obs-feedback',
    'signal_id': 'sig-feedback-source',
    'weight': 1.0,
    'reason': 'source_signal',
    'created_at': now,
  });
  await db.insert('trace_links', {
    'id': 'trace-feedback',
    'local_user_id': 'local-user',
    'source_type': 'observation',
    'source_id': 'obs-feedback',
    'target_type': 'signal_card',
    'target_id': 'sig-feedback-source',
    'relation_type': 'evidence_signal',
    'weight': 1.0,
    'status': 'active',
    'metadata_json': '{}',
    'created_at': now,
    'updated_at': now,
  });
}
