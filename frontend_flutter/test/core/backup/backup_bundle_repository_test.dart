import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_opportunity_radar/core/backup/backup_bundle_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/notifications/schedule_notification_service.dart';
import 'package:ai_opportunity_radar/core/notifications/signal_reminder_repository.dart';

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
    await prefs.setString(
      SignalReminderRepository.preferencesKey,
      '[{"id":"reminder-1"}]',
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
    expect(
      (bundle['preferences'] as Map)
          .containsKey(SignalReminderRepository.preferencesKey),
      isFalse,
      reason: 'local notification rules must never be exported in a backup',
    );

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

  test('v4 candidate backup defaults decisions and v6 exports them', () async {
    final localDatabase = await _openDatabase(tempDir, 'candidate-v4.db');
    final prefs = await SharedPreferences.getInstance();
    final repository = BackupBundleRepository(
      localDatabase: localDatabase,
      preferences: prefs,
    );
    final result = await repository.importBundle({
      'schema_version': 4,
      'tables': {
        'micro_action_candidates': [
          {
            'id': 'legacy-candidate',
            'candidate_group_id': 'legacy-group',
            'local_user_id': 'local-user',
            'local_date': '2026-07-16',
            'rank': 1,
            'title': '先观察这个小尝试',
            'reason': '',
            'difficulty': 'very_light',
            'linked_signal_card_ids_json': '[]',
            'focus_domain_ids_json': '[]',
            'status': 'generated',
            'source_hash': 'legacy-source',
            'dirty': 0,
            'is_stale': 0,
            'created_at': '2026-07-16T00:00:00.000Z',
            'updated_at': '2026-07-16T00:00:00.000Z',
            // A future additive column must be ignored rather than making
            // the otherwise compatible backup fail.
            'future_only_column': 'ignored',
          },
        ],
      },
    });
    expect(result.importedRows, 1);
    final db = await localDatabase.database;
    final restored = (await db.query(
      'micro_action_candidates',
      where: 'id = ?',
      whereArgs: ['legacy-candidate'],
    ))
        .single;
    expect(restored['decision_status'], 'undecided');

    await db.update(
      'micro_action_candidates',
      {'decision_status': 'considering'},
      where: 'id = ?',
      whereArgs: ['legacy-candidate'],
    );
    final exported = await repository.exportBundle(
      localUserId: 'local-user',
      deviceId: 'device-a',
    );
    expect(exported['schema_version'], 6);
    final exportedCandidates =
        ((exported['tables'] as Map)['micro_action_candidates'] as List)
            .cast<Map>();
    expect(exportedCandidates.single['decision_status'], 'considering');
    await localDatabase.close();
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

  test('roundtrips and deletes immutable plan content versions', () async {
    final sourceDatabase = await _openDatabase(tempDir, 'plan-source.db');
    final prefs = await SharedPreferences.getInstance();
    final sourceRepository = BackupBundleRepository(
      localDatabase: sourceDatabase,
      preferences: prefs,
    );
    final sourceDb = await sourceDatabase.database;
    await sourceDb.insert('plan_content_versions', {
      'id': 'plan-version-1',
      'local_user_id': 'local-user',
      'object_kind': 'quick_try',
      'object_id': 'quick-try-1',
      'version_no': 1,
      'effective_from_local_date': '2026-07-13',
      'content_json': '{"title":"原始小尝试"}',
      'created_at': '2026-07-13T00:00:00.000Z',
    });

    final bundle = await sourceRepository.exportBundle(
      localUserId: 'local-user',
      deviceId: 'device-a',
    );
    expect(bundle['schema_version'], 6);
    expect(
      ((bundle['tables'] as Map)['plan_content_versions'] as List),
      hasLength(1),
    );
    await sourceDatabase.close();

    final targetDatabase = await _openDatabase(tempDir, 'plan-target.db');
    final targetRepository = BackupBundleRepository(
      localDatabase: targetDatabase,
      preferences: prefs,
    );
    await targetRepository.importBundle(bundle);
    final targetDb = await targetDatabase.database;
    final restored = await targetDb.query('plan_content_versions');
    expect(restored, hasLength(1));
    expect(restored.single['content_json'], '{"title":"原始小尝试"}');

    await targetRepository.deleteAllLocalData();
    expect(await targetDb.query('plan_content_versions'), isEmpty);
    await targetDatabase.close();
  });

  test('roundtrips and deletes explicitly adopted deepening observation plans',
      () async {
    final sourceDatabase =
        await _openDatabase(tempDir, 'deepening-observation-source.db');
    final prefs = await SharedPreferences.getInstance();
    final sourceRepository = BackupBundleRepository(
      localDatabase: sourceDatabase,
      preferences: prefs,
    );
    await _insertObservationPlan(sourceDatabase);

    final bundle = await sourceRepository.exportBundle(
      localUserId: 'local-user',
      deviceId: 'device-a',
    );
    expect(
      ((bundle['tables'] as Map)['observation_plans'] as List),
      hasLength(1),
    );
    await sourceDatabase.close();

    final targetDatabase =
        await _openDatabase(tempDir, 'deepening-observation-target.db');
    final targetRepository = BackupBundleRepository(
      localDatabase: targetDatabase,
      preferences: prefs,
    );
    await targetRepository.importBundle(bundle);
    final targetDb = await targetDatabase.database;
    final restored = await targetDb.query('observation_plans');
    expect(restored, hasLength(1));
    expect(restored.single['question'], '恢复是否更容易开始？');

    await targetRepository.deleteAllLocalData();
    expect(await targetDb.query('observation_plans'), isEmpty);
    await targetDatabase.close();
  });

  test('roundtrips append-only small-try and goal outcome reviews', () async {
    final sourceDatabase = await _openDatabase(tempDir, 'review-source.db');
    final prefs = await SharedPreferences.getInstance();
    final sourceRepository = BackupBundleRepository(
      localDatabase: sourceDatabase,
      preferences: prefs,
    );
    final sourceDb = await sourceDatabase.database;
    const now = '2026-07-22T03:00:00.000Z';
    await sourceDb.insert('micro_action_review_events', {
      'id': 'small-review-1',
      'micro_action_id': 'small-1',
      'local_user_id': 'local-user',
      'reviewed_at': now,
      'local_date': '2026-07-22',
      'result': 'worth_keeping',
      'effort': 'easy',
      'next_adjustment': 'keep',
      'note': '值得保留',
      'completed_days_at_review': 2,
      'created_at': now,
    });
    await sourceDb.insert('life_experiments', {
      'id': 'goal-review-1',
      'local_user_id': 'local-user',
      'source_week_start': '2026-07-20',
      'source_week_end': '2026-08-20',
      'title': '长期目标',
      'hypothesis': '连续观察后可能有变化',
      'suggested_action': '持续记录',
      'linked_signal_card_ids_json': '[]',
      'status': 'active',
      'minimum_observation_days': 5,
      'created_at': now,
      'updated_at': now,
    });
    await sourceDb.insert('life_experiment_lifecycle_events', {
      'id': 'goal-outcome-1',
      'experiment_id': 'goal-review-1',
      'local_user_id': 'local-user',
      'event_type': 'outcome_reviewed',
      'event_date': now,
      'local_date': '2026-07-22',
      'payload_json':
          '{"outcome_result":"somewhat_improved","burden":"acceptable","completed_days_at_review":3,"minimum_observation_days":5}',
      'created_at': now,
    });

    final bundle = await sourceRepository.exportBundle(
      localUserId: 'local-user',
      deviceId: 'device-a',
    );
    expect(bundle['schema_version'], 6);
    await sourceDatabase.close();

    final targetDatabase = await _openDatabase(tempDir, 'review-target.db');
    final targetRepository = BackupBundleRepository(
      localDatabase: targetDatabase,
      preferences: prefs,
    );
    await targetRepository.importBundle(bundle);
    final targetDb = await targetDatabase.database;
    expect(await targetDb.query('micro_action_review_events'), hasLength(1));
    final goals = await targetDb.query(
      'life_experiments',
      where: 'id = ?',
      whereArgs: ['goal-review-1'],
    );
    expect(goals.single['minimum_observation_days'], 5);
    expect(
      await targetDb.query(
        'life_experiment_lifecycle_events',
        where: 'event_type = ?',
        whereArgs: ['outcome_reviewed'],
      ),
      hasLength(1),
    );
    await targetRepository.deleteAllLocalData();
    expect(await targetDb.query('micro_action_review_events'), isEmpty);
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
      SignalReminderRepository.preferencesKey: '[{"id":"reminder-1"}]',
    });
    final prefs = await SharedPreferences.getInstance();
    final reminderScheduler = _FakeSignalReminderScheduler();
    final repository = BackupBundleRepository(
      localDatabase: localDatabase,
      preferences: prefs,
      signalReminderRepository: SignalReminderRepository(
        preferences: prefs,
        scheduler: reminderScheduler,
      ),
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
    expect(prefs.getString(SignalReminderRepository.preferencesKey), isNull);
    expect(reminderScheduler.cancelAllCalls, 1,
        reason: 'account deletion must cancel native Signal reminders');
    expect(prefs.getBool('premium_entitlement_active'), isTrue,
        reason: 'StoreKit entitlement is independent from diary deletion');
    expect(prefs.getString('premium_entitlement_product_id'), 'pro.yearly');

    await localDatabase.close();
  });
}

class _FakeSignalReminderScheduler implements SignalReminderScheduler {
  int cancelAllCalls = 0;

  @override
  Future<bool> cancelAllSignalReminders() async {
    cancelAllCalls += 1;
    return true;
  }

  @override
  Future<bool> cancelSignalReminder(String notificationId) async => true;

  @override
  Future<SignalReminderPermissionResult>
      requestSignalReminderPermission() async {
    return const SignalReminderPermissionResult(
      SignalReminderPermissionStatus.granted,
    );
  }

  @override
  Future<bool> scheduleSignalReminder({
    required String notificationId,
    required DateTime scheduledAt,
    String? localeTag,
  }) async =>
      true;
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

Future<void> _insertObservationPlan(LocalDatabase localDatabase) async {
  final db = await localDatabase.database;
  await db.insert('observation_plans', {
    'id': 'observation-plan-1',
    'local_user_id': 'local-user',
    'source_week_start': '2026-07-06',
    'source_week_end': '2026-07-12',
    'target_week_start': '2026-07-13',
    'question': '恢复是否更容易开始？',
    'what_to_watch_json': '["恢复"]',
    'source_signal_card_ids_json': '["sig-1"]',
    'source_hash': 'source-hash',
    'status': 'planned',
    'result_signal_card_ids_json': '[]',
    'created_at': '2026-07-13T00:00:00.000Z',
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
