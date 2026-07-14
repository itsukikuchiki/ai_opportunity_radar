import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_opportunity_radar/app/app_router.dart';
import 'package:ai_opportunity_radar/core/backup/backup_bundle_repository.dart';
import 'package:ai_opportunity_radar/core/debug/legacy_fallback_monitor.dart';
import 'package:ai_opportunity_radar/core/local/local_capture_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/local/local_weekly_snapshot_repository.dart';
import 'package:ai_opportunity_radar/core/models/weekly_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory tempDir;
  late LocalDatabase localDatabase;

  setUp(() async {
    LegacyFallbackMonitor.reset();
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('legacy_fallback_test_');
    localDatabase = LocalDatabase(
      dbPathOverride: p.join(tempDir.path, 'local.db'),
      databaseFactoryOverride: databaseFactoryFfi,
    );
    await localDatabase.init();
  });

  tearDown(() async {
    LegacyFallbackMonitor.reset();
    await localDatabase.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('new Weekly and SignalCard data do not trigger legacy fallback counters',
      () async {
    final weeklyRepository = LocalWeeklySnapshotRepository(localDatabase);
    await weeklyRepository.upsert(
      weekly: WeeklyInsightModel(
        weekStart: '2026-07-06',
        weekEnd: '2026-07-12',
        status: 'ready',
        keyInsight: '新周复盘走 reflection_results。',
        patterns: const [
          {'name': '新模式'}
        ],
        frictions: const [],
        bestAction: '继续轻量实验。',
        opportunitySnapshot: const {'energy_budget': 'steady'},
        feedbackSubmitted: false,
      ),
      sourceHash: 'new-weekly',
    );

    final captureRepository = LocalCaptureRepository(localDatabase);
    final signal = await captureRepository.insertLocalDraftSignal(
      content: '新 SignalCard 走 split tables',
      language: 'zh-Hans',
    );
    await captureRepository.updateSignalCardInclusion(
      signalCardIds: [signal.signalCardId!],
      includedInSummary: true,
      includedInWeekly: true,
      includedInJourney: true,
    );

    LegacyFallbackMonitor.reset();
    await weeklyRepository.getByWeekStart('2026-07-06');
    await captureRepository.listSignalCards();

    final counts = LegacyFallbackMonitor.snapshot();
    expect(counts[LegacyFallbackMonitor.opportunitySnapshotLifeExperiment], 0);
    expect(counts[LegacyFallbackMonitor.snapshotAiField], 0);
    expect(counts[LegacyFallbackMonitor.signalInclusionField], 0);
    expect(counts[LegacyFallbackMonitor.signalPrivacyField], 0);
  });

  test('legacy _life_experiment and snapshot AI mirror increment counters',
      () async {
    final db = await localDatabase.database;
    await _insertLegacyWeeklySnapshot(db);
    final repository = LocalWeeklySnapshotRepository(localDatabase);

    final weekly = await repository.getByWeekStart('2026-07-06');
    expect(weekly?.keyInsight, '旧周复盘只在 snapshot mirror');
    expect(weekly?.lifeExperiment?.title, '旧实验');

    final counts = LegacyFallbackMonitor.snapshot();
    expect(counts[LegacyFallbackMonitor.snapshotAiField], greaterThan(0));
    expect(counts[LegacyFallbackMonitor.opportunitySnapshotLifeExperiment], 1);
  });

  test(
      'SignalCard legacy mirror fields increment then migration drops counters',
      () async {
    final db = await localDatabase.database;
    await db.insert('signal_cards', {
      'id': 'legacy_signal',
      'signal_card_id': 'legacy_signal',
      'source_type': 'text',
      'raw_text': '旧 SignalCard mirror',
      'created_at': '2026-07-06T00:00:00.000Z',
      'local_date': '2026-07-06',
      'timezone': 'Asia/Tokyo',
      'user_confirmation': 'unconfirmed',
      'raw_payload_json': '{}',
      'user_correction_json': '{}',
      'included_in_summary': 1,
      'included_in_weekly': 1,
      'included_in_journey': 1,
      'privacy_level': 'private',
      'is_legacy': 1,
      'migration_status': 'local_legacy',
      'is_local_draft': 0,
      'sync_failed': 0,
      'sync_status': 'synced',
      'updated_at': '2026-07-06T00:00:00.000Z',
    });
    final repository = LocalCaptureRepository(localDatabase);

    await repository.getCaptureById('legacy_signal');
    var counts = LegacyFallbackMonitor.snapshot();
    expect(counts[LegacyFallbackMonitor.signalInclusionField], greaterThan(0));
    expect(counts[LegacyFallbackMonitor.signalPrivacyField], 1);

    LegacyFallbackMonitor.reset();
    await repository.listSignalCards();
    counts = LegacyFallbackMonitor.snapshot();
    expect(counts[LegacyFallbackMonitor.signalInclusionField], 0);
    expect(counts[LegacyFallbackMonitor.signalPrivacyField], 0);
  });

  test('P2 migration drops _life_experiment fallback to zero', () async {
    final db = await localDatabase.database;
    await _insertLegacyWeeklySnapshot(db);

    await localDatabase.runP2LegacyDataMigration();
    LegacyFallbackMonitor.reset();

    final weekly =
        await LocalWeeklySnapshotRepository(localDatabase).getByWeekStart(
      '2026-07-06',
    );
    expect(weekly?.lifeExperiment, isNull);

    final counts = LegacyFallbackMonitor.snapshot();
    expect(counts[LegacyFallbackMonitor.opportunitySnapshotLifeExperiment], 0);
  });

  test('captures raw and compatibility mirror increment legacy counters',
      () async {
    final db = await localDatabase.database;
    await db.insert('captures', {
      'id': 'cap_legacy',
      'content': '旧 captures raw',
      'created_at': '2026-07-06T00:00:00.000Z',
      'input_mode': 'text',
      'ai_acknowledgement': '旧 AI 回复',
      'updated_at': '2026-07-06T00:00:00.000Z',
    });
    final repository = LocalCaptureRepository(localDatabase);

    await repository.listRecentSignals();
    await repository.mirrorLegacyCapturesToSignalCards();

    final counts = LegacyFallbackMonitor.snapshot();
    expect(counts[LegacyFallbackMonitor.capturesRawRead], 1);
    expect(counts[LegacyFallbackMonitor.capturesMirror], 1);
  });

  test('backup export/import is counted as legacy-only capability', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = BackupBundleRepository(
      localDatabase: localDatabase,
      preferences: prefs,
    );

    final bundle = await repository.exportBundle(
      localUserId: 'local',
      deviceId: 'device-a',
    );
    await repository.importBundle(bundle);

    final counts = LegacyFallbackMonitor.snapshot();
    expect(counts[LegacyFallbackMonitor.backupExport], 1);
    expect(counts[LegacyFallbackMonitor.backupImport], 1);
  });

  test('DeepWeekly legacy route resolves to Weekly Reflect canonical route',
      () {
    expect(resolvedInitialRoute(AppRoutes.deepWeekly), AppRoutes.weeklyReflect);
  });
}

Future<void> _insertLegacyWeeklySnapshot(Database db) async {
  await db.insert('weekly_snapshots', {
    'week_start': '2026-07-06',
    'week_end': '2026-07-12',
    'status': 'ready',
    'key_insight': '旧周复盘只在 snapshot mirror',
    'patterns_json': '[]',
    'frictions_json': '[]',
    'best_action': '旧行动',
    'opportunity_snapshot_json': jsonEncode({
      'energy_budget': 'low',
      '_life_experiment': {
        'id': 'legacy_exp',
        'title': '旧实验',
        'hypothesis': '旧假设',
        'suggested_action': '旧行动',
        'status': 'suggested',
        'source_week_start': '2026-07-06',
        'source_week_end': '2026-07-12',
        'linked_signal_card_ids': [],
      },
    }),
    'chart_data_json': '[]',
    'feedback_submitted': 0,
    'source_hash': 'legacy-weekly',
    'schema_version': 1,
    'pipeline_version': 'legacy',
    'dirty': 0,
    'is_stale': 0,
    'generated_at': '2026-07-12T00:00:00.000Z',
  });
}
