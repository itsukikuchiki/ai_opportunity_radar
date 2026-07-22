import 'dart:io';

import 'package:ai_opportunity_radar/core/di/app_dependencies.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/qa/qa_showcase_seeder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory tempDir;
  late LocalDatabase localDatabase;
  late AppDependencies dependencies;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'local_user_id': 'qa-showcase-user',
      'device_id': 'qa-showcase-device',
    });
    tempDir = await Directory.systemTemp.createTemp('qa_showcase_seed_');
    localDatabase = LocalDatabase(
      dbPathOverride: p.join(tempDir.path, 'showcase.db'),
      databaseFactoryOverride: databaseFactoryFfi,
    );
    dependencies = await AppDependencies.create(
      localDatabaseOverride: localDatabase,
      trackNewUserRegistration: false,
    );
  });

  tearDown(() async {
    await dependencies.localCandidatePlanningRepository.dispose();
    dependencies.apiClient.close();
    await localDatabase.close();
    await tempDir.delete(recursive: true);
  });

  test('seeds current Weekly, Journey and Pro evidence without user overwrite',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime(2026, 7, 15, 13, 30);
    final db = await localDatabase.database;
    await db.insert('signal_cards', {
      'id': 'user_signal_keep',
      'signal_card_id': 'user_signal_keep',
      'client_id': 'user_signal_keep',
      'server_id': null,
      'source_type': 'text',
      'raw_text': '用户自己的记录必须保留。',
      'created_at': now.toUtc().toIso8601String(),
      'local_date': '2026-07-15',
      'timezone': 'Asia/Tokyo',
      'language': 'zh-Hans',
      'linked_life_chain_stage': '[]',
      'user_confirmation': 'confirmed',
      'user_correction_json': '{}',
      'included_in_summary': 1,
      'included_in_weekly': 1,
      'included_in_journey': 1,
      'privacy_level': 'private',
      'is_legacy': 0,
      'migration_status': 'native',
      'is_local_draft': 0,
      'sync_failed': 0,
      'sync_status': 'local_only',
      'updated_at': now.toUtc().toIso8601String(),
    });

    await QaShowcaseSeeder.seed(
      dependencies: dependencies,
      preferences: prefs,
      now: now,
    );

    final demoCount = Sqflite.firstIntValue(await db.rawQuery(
          "SELECT COUNT(*) FROM signal_cards WHERE id LIKE 'qa_demo_signal_%'",
        )) ??
        0;
    expect(demoCount, greaterThanOrEqualTo(14));
    expect(
      Sqflite.firstIntValue(await db.rawQuery(
        "SELECT COUNT(*) FROM signal_cards WHERE id = 'user_signal_keep'",
      )),
      1,
    );
    expect(
      Sqflite.firstIntValue(await db.rawQuery(
        "SELECT COUNT(DISTINCT local_date) FROM signal_cards WHERE id LIKE 'qa_demo_signal_%'",
      )),
      greaterThanOrEqualTo(7),
    );
    expect(
      Sqflite.firstIntValue(await db.rawQuery(
        "SELECT COUNT(*) FROM micro_actions WHERE id LIKE 'qa_demo_action_%'",
      )),
      1,
    );
    expect(
      Sqflite.firstIntValue(await db.rawQuery(
        "SELECT COUNT(*) FROM life_experiments WHERE id LIKE 'qa_demo_experiment_%'",
      )),
      1,
    );
    expect(
      Sqflite.firstIntValue(await db.rawQuery(
        "SELECT COUNT(*) FROM observations WHERE id LIKE 'qa_demo_observation_%'",
      )),
      2,
    );

    final proReport =
        await dependencies.journeyProRepository.fetchThreeMonthChange(
      selectedMonthKey: '2026-07',
    );
    expect(
      proReport.months.map((month) => month.monthKey),
      ['2026-05', '2026-06', '2026-07'],
    );
    expect(proReport.totalSignalCount, greaterThanOrEqualTo(18));
    final periodEnd = DateTime.parse(proReport.periodEnd);
    expect(periodEnd.year, 2026);
    expect(periodEnd.month, DateTime.july);
    expect(periodEnd.day, inInclusiveRange(15, 31));
    expect(proReport.sourceHash, isNotEmpty);
    expect(prefs.getBool('onboarding_completed'), isTrue);
    expect(prefs.getString('local_app_started_date'), isNotNull);
    expect(prefs.getBool('premium_entitlement_active'), isNull);
  });

  test('same-day seeding is idempotent', () async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime(2026, 7, 15, 13, 30);

    await QaShowcaseSeeder.seed(
      dependencies: dependencies,
      preferences: prefs,
      now: now,
    );
    await QaShowcaseSeeder.seed(
      dependencies: dependencies,
      preferences: prefs,
      now: now,
    );

    final db = await localDatabase.database;
    expect(
      Sqflite.firstIntValue(await db.rawQuery(
        "SELECT COUNT(*) FROM signal_cards WHERE id LIKE 'qa_demo_signal_%'",
      )),
      18,
    );
    expect(
      Sqflite.firstIntValue(await db.rawQuery(
        "SELECT COUNT(*) FROM micro_action_feedback WHERE micro_action_id = 'qa_demo_action_01'",
      )),
      2,
    );
  });
}
