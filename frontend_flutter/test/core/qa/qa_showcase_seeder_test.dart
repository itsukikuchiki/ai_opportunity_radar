import 'dart:convert';
import 'dart:io';

import 'package:ai_opportunity_radar/core/api/repositories/ai_repository.dart';
import 'package:ai_opportunity_radar/core/api/repositories/weekly_repository.dart';
import 'package:ai_opportunity_radar/core/di/app_dependencies.dart';
import 'package:ai_opportunity_radar/core/i18n/app_locale_text.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/preferences/focus_domains.dart';
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

  test('seeds current Weekly, Journey and Pro history without user overwrite',
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
    expect(demoCount, 18);
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
      14,
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
    expect(await _showcaseCounts(db), {
      'signals': 18,
      'recordDays': 14,
      'microActionFeedback': 2,
      'experimentFeedback': 3,
    });

    final proReport =
        await dependencies.journeyProRepository.fetchFullHistoryChange(
      selectedMonthKey: '2026-07',
    );
    expect(
      proReport.months.map((month) => month.monthKey),
      ['2026-06', '2026-07'],
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

  test('seeds a fully Traditional Chinese showcase package', () async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime(2026, 7, 31, 13, 30);

    await QaShowcaseSeeder.seed(
      dependencies: dependencies,
      preferences: prefs,
      now: now,
      language: 'zh-Hant',
    );

    final db = await localDatabase.database;
    expect(await _showcaseCounts(db), {
      'signals': 18,
      'recordDays': 14,
      'microActionFeedback': 2,
      'experimentFeedback': 3,
    });
    expect(
      Sqflite.firstIntValue(await db.rawQuery(
        "SELECT COUNT(*) FROM signal_cards WHERE id LIKE 'qa_demo_signal_%' AND language = 'zh-Hant'",
      )),
      18,
    );
    final taxonomyRows = await db.query(
      'signal_cards',
      columns: const ['local_date', 'raw_payload_json'],
      where: "id LIKE 'qa_demo_signal_%'",
    );
    final validFocusDomainIds =
        FocusDomains.options.map((option) => option.id).toSet();
    final weeklyDomainCounts = <String, int>{};
    final weeklyEnergyCounts = <String, int>{};
    final weeklyEnergyLevelsByDate = <String, List<int>>{};
    for (final row in taxonomyRows) {
      final payload =
          jsonDecode(row['raw_payload_json'] as String) as Map<String, dynamic>;
      final focusDomainId = payload['focus_domain_id'] as String;
      final energyLevel = payload['energy_level'] as int;
      final energyState = payload['energy_state'] as String;
      expect(validFocusDomainIds, contains(focusDomainId));
      expect(
        energyState,
        {0: 'draining', 1: 'steady', 2: 'ease'}[energyLevel],
      );

      final localDate = row['local_date'] as String;
      if (localDate.compareTo('2026-07-27') < 0) continue;
      weeklyDomainCounts.update(
        focusDomainId,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      weeklyEnergyCounts.update(
        energyState,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      weeklyEnergyLevelsByDate
          .putIfAbsent(localDate, () => <int>[])
          .add(energyLevel);
    }
    for (final levels in weeklyEnergyLevelsByDate.values) {
      levels.sort();
    }
    expect(weeklyDomainCounts, {
      'emotional_stability': 6,
      'food_sleep': 2,
      'growth_plan': 1,
    });
    expect(weeklyEnergyCounts, {
      'draining': 1,
      'steady': 3,
      'ease': 5,
    });
    expect(weeklyEnergyLevelsByDate, {
      '2026-07-27': [0],
      '2026-07-28': [1],
      '2026-07-29': [2],
      '2026-07-30': [1, 1],
      '2026-07-31': [2, 2, 2, 2],
    });
    expect(prefs.getString('profile_display_name'), 'Signal Path 測試');

    final visibleText = await _showcaseVisibleText(db);
    expect(visibleText, contains('任務切換前留兩分鐘緩衝'));
    expect(visibleText, contains('午後十分鐘離屏恢復'));
    expect(visibleText, contains('訊號'));
    expect(visibleText, contains('回饋'));

    const simplifiedResidue = <String>[
      '连续',
      '任务',
      '明显',
      '频繁',
      '切换',
      '两周',
      '信号',
      '恢复',
      '反馈',
      '重复',
      '短暂',
      '屏幕',
      '分钟',
      '记录',
      '减少',
      '开始',
      '这个',
      '已经',
      '复杂',
      '回复消息',
      '推进',
      '会议',
      '计划',
      '选择',
      '数量',
      '价值',
    ];
    for (final token in simplifiedResidue) {
      expect(
        visibleText,
        isNot(contains(token)),
        reason: 'Traditional Chinese showcase still contains "$token".',
      );
    }
  });

  test('seeds a fully Japanese showcase package', () async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime(2026, 7, 31, 13, 30);

    await QaShowcaseSeeder.seed(
      dependencies: dependencies,
      preferences: prefs,
      now: now,
      language: 'ja-JP',
    );

    final db = await localDatabase.database;
    expect(await _showcaseCounts(db), {
      'signals': 18,
      'recordDays': 14,
      'microActionFeedback': 2,
      'experimentFeedback': 3,
    });
    expect(
      Sqflite.firstIntValue(await db.rawQuery(
        "SELECT COUNT(*) FROM signal_cards WHERE id LIKE 'qa_demo_signal_%' AND language = 'ja'",
      )),
      18,
    );
    expect(prefs.getString('profile_display_name'), 'Signal Path テスト');
    expect(
      prefs.getString('qa_showcase_seed_signature_v2'),
      '2026-07-31|ja|localized_v5',
    );

    final signalRows = await db.query(
      'signal_cards',
      columns: const ['raw_text', 'ai_reply', 'observation', 'try_next'],
      where: "id LIKE 'qa_demo_signal_%'",
      orderBy: 'id ASC',
    );
    expect(signalRows, hasLength(18));
    final japaneseScript = RegExp(r'[ぁ-ゟァ-ヿ]');
    for (final row in signalRows) {
      for (final column in const [
        'raw_text',
        'ai_reply',
        'observation',
        'try_next',
      ]) {
        final value = row[column] as String?;
        expect(value, isNotNull, reason: '$column must be populated.');
        expect(value, isNotEmpty, reason: '$column must be visible.');
        expect(
          value,
          matches(japaneseScript),
          reason: '$column must contain Japanese copy: $value',
        );
      }
    }

    final visibleText = await _showcaseVisibleText(db);
    expect(visibleText, contains('タスクを切り替える前に2分間の余白をつくる'));
    expect(visibleText, contains('午後に10分間画面から離れて回復する'));
    expect(visibleText, contains('フィードバック'));
    expect(visibleText, contains('スムーズに戻れた'));

    const chineseResidue = <String>[
      '连续切换',
      '連續切換',
      '任务切换前',
      '任務切換前',
      '工作信号',
      '工作訊號',
      '恢复反馈',
      '恢復回饋',
      '午后十分钟离屏恢复',
      '午後十分鐘離屏恢復',
    ];
    for (final token in chineseResidue) {
      expect(
        visibleText,
        isNot(contains(token)),
        reason: 'Japanese showcase still contains Chinese copy "$token".',
      );
    }

    final derivedText = await _weeklyDerivedVisibleText(
      dependencies,
      now: now,
      languageCode: 'ja',
      language: AppLanguage.japanese,
    );
    expect(derivedText, matches(japaneseScript));
    for (final token in const [
      '本周偏耗力',
      '下周候选',
      '如果这周',
      '上一轮反馈',
      '记录中',
      '本周最消耗',
      '这周先',
    ]) {
      expect(
        derivedText,
        isNot(contains(token)),
        reason: 'Japanese Weekly derivation still contains "$token".',
      );
    }
  });

  test('seeds a fully English showcase package', () async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime(2026, 7, 31, 13, 30);

    await QaShowcaseSeeder.seed(
      dependencies: dependencies,
      preferences: prefs,
      now: now,
      language: 'en-US',
    );

    final db = await localDatabase.database;
    expect(await _showcaseCounts(db), {
      'signals': 18,
      'recordDays': 14,
      'microActionFeedback': 2,
      'experimentFeedback': 3,
    });
    expect(
      Sqflite.firstIntValue(await db.rawQuery(
        "SELECT COUNT(*) FROM signal_cards WHERE id LIKE 'qa_demo_signal_%' AND language = 'en'",
      )),
      18,
    );
    expect(prefs.getString('profile_display_name'), 'Signal Path QA');
    expect(
      prefs.getString('qa_showcase_seed_signature_v2'),
      '2026-07-31|en|localized_v5',
    );

    final signalRows = await db.query(
      'signal_cards',
      columns: const ['raw_text', 'ai_reply', 'observation', 'try_next'],
      where: "id LIKE 'qa_demo_signal_%'",
      orderBy: 'id ASC',
    );
    expect(signalRows, hasLength(18));
    final latinScript = RegExp(r'[A-Za-z]');
    for (final row in signalRows) {
      for (final column in const [
        'raw_text',
        'ai_reply',
        'observation',
        'try_next',
      ]) {
        final value = row[column] as String?;
        expect(value, isNotNull, reason: '$column must be populated.');
        expect(value, isNotEmpty, reason: '$column must be visible.');
        expect(
          value,
          matches(latinScript),
          reason: '$column must contain English copy: $value',
        );
      }
    }

    final visibleText = await _showcaseVisibleText(db);
    expect(
      visibleText,
      contains('Leave a two-minute buffer before switching tasks'),
    );
    expect(visibleText, contains('Ten-minute afternoon screen break'));
    expect(visibleText, contains('Work Signals and recovery feedback'));
    expect(visibleText, contains('easier to get back into the afternoon'));

    final cjkScript = RegExp(r'[぀-ヿ㐀-鿿]');
    expect(
      cjkScript.hasMatch(visibleText),
      isFalse,
      reason: 'English showcase must not contain Chinese or Japanese copy.',
    );

    final derivedText = await _weeklyDerivedVisibleText(
      dependencies,
      now: now,
      languageCode: 'en',
      language: AppLanguage.english,
    );
    expect(
      cjkScript.hasMatch(derivedText),
      isFalse,
      reason:
          'English Weekly, deep analysis and next-week candidates must not contain CJK copy.',
    );
  });

  test('grounded candidate cache invalidates when display language changes',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime(2026, 7, 31, 13, 30);
    await QaShowcaseSeeder.seed(
      dependencies: dependencies,
      preferences: prefs,
      now: now,
      language: 'en',
    );

    final planner = dependencies.localCandidatePlanningRepository;
    final english = await planner.refreshWeeklyWithGroundedSuggestions(
      day: now,
      language: AppLanguage.english,
    );
    final japanese = await planner.refreshWeeklyWithGroundedSuggestions(
      day: now,
      language: AppLanguage.japanese,
    );

    expect(english.generation.sourceHash, isNotEmpty);
    expect(japanese.generation.sourceHash, isNotEmpty);
    expect(
      japanese.generation.sourceHash,
      isNot(equals(english.generation.sourceHash)),
    );
    expect(english.candidates, isNotEmpty);
    expect(japanese.candidates, isNotEmpty);
    expect(
      english.candidates.map((item) => item.hypothesis).join(' '),
      isNot(matches(RegExp(r'[぀-ヿ]'))),
    );
    expect(
      japanese.candidates.map((item) => item.hypothesis).join(' '),
      matches(RegExp(r'[぀-ヿ]')),
    );
  });

  test('same-day Simplified to Traditional reseed is idempotent', () async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime(2026, 7, 31, 13, 30);

    await QaShowcaseSeeder.seed(
      dependencies: dependencies,
      preferences: prefs,
      now: now,
      language: 'zh-Hans',
    );
    final db = await localDatabase.database;
    var firstSignal = (await db.query(
      'signal_cards',
      columns: const ['raw_text', 'language'],
      where: 'id = ?',
      whereArgs: const ['qa_demo_signal_01'],
    ))
        .single;
    expect(firstSignal['raw_text'], '上午连续切了三个任务，真正累的是不停重新进入状态。');
    expect(firstSignal['language'], 'zh-Hans');

    await QaShowcaseSeeder.seed(
      dependencies: dependencies,
      preferences: prefs,
      now: now,
      language: 'zh-Hant',
    );
    firstSignal = (await db.query(
      'signal_cards',
      columns: const ['raw_text', 'language'],
      where: 'id = ?',
      whereArgs: const ['qa_demo_signal_01'],
    ))
        .single;
    expect(firstSignal['raw_text'], '上午連續切了三個任務，真正累的是不停重新進入狀態。');
    expect(firstSignal['language'], 'zh-Hant');
    expect(
      prefs.getString('qa_showcase_seed_signature_v2'),
      '2026-07-31|zh-Hant|localized_v5',
    );
    expect(await _showcaseCounts(db), {
      'signals': 18,
      'recordDays': 14,
      'microActionFeedback': 2,
      'experimentFeedback': 3,
    });

    await QaShowcaseSeeder.seed(
      dependencies: dependencies,
      preferences: prefs,
      now: now,
      language: 'zh-Hant',
    );

    expect(await _showcaseCounts(db), {
      'signals': 18,
      'recordDays': 14,
      'microActionFeedback': 2,
      'experimentFeedback': 3,
    });
  });

  test('production purge removes only QA-owned data and preferences', () async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime(2026, 7, 31, 13, 30);
    await QaShowcaseSeeder.seed(
      dependencies: dependencies,
      preferences: prefs,
      now: now,
      language: 'en',
    );
    final db = await localDatabase.database;

    final userSignal = Map<String, Object?>.from((await db.query(
      'signal_cards',
      where: 'id = ?',
      whereArgs: const ['qa_demo_signal_01'],
    ))
        .single)
      ..addAll({
        'id': 'user_signal_keep',
        'signal_card_id': 'user_signal_keep',
        'client_id': 'user_signal_keep',
        'server_id': null,
        'raw_text': 'A real user record must remain.',
        'migration_status': 'native',
        'raw_payload_json': '{}',
        'intent_tags_json': '[]',
      });
    await db.insert('signal_cards', userSignal);

    final userObservation = Map<String, Object?>.from((await db.query(
      'observations',
      where: 'id = ?',
      whereArgs: const ['qa_demo_observation_01'],
    ))
        .single)
      ..addAll({
        'id': 'user_observation_keep',
        'created_by': 'user',
        'observation_text': 'A real observation must remain.',
      });
    await db.insert('observations', userObservation);

    final userAction = Map<String, Object?>.from((await db.query(
      'micro_actions',
      where: 'id = ?',
      whereArgs: const ['qa_demo_action_01'],
    ))
        .single)
      ..addAll({
        'id': 'user_action_keep',
        'judgement_id': null,
        'title': 'A real quick try must remain.',
        'linked_signal_card_ids_json': '["user_signal_keep"]',
      });
    await db.insert('micro_actions', userAction);

    final userExperiment = Map<String, Object?>.from((await db.query(
      'life_experiments',
      where: 'id = ?',
      whereArgs: const ['qa_demo_experiment_01'],
    ))
        .single)
      ..addAll({
        'id': 'user_experiment_keep',
        'origin_candidate_id': null,
        'pattern_id': 'user_pattern',
        'title': 'A real goal must remain.',
        'linked_signal_card_ids_json': '["user_signal_keep"]',
      });
    await db.insert('life_experiments', userExperiment);

    await prefs.setString('profile_display_name', 'A real profile name');

    await QaShowcaseSeeder.purgeOwnedPreferences(prefs);
    await QaShowcaseSeeder.purgeOwnedData(dependencies: dependencies);

    expect(await _showcaseCounts(db), {
      'signals': 0,
      'recordDays': 0,
      'microActionFeedback': 0,
      'experimentFeedback': 0,
    });
    for (final entry in <String, String>{
      'signal_processing_state': "signal_id LIKE 'qa_demo_%'",
      'signal_analysis_policy': "signal_id LIKE 'qa_demo_%'",
      'signal_sync_identity': "client_id LIKE 'qa_demo_%'",
      'trace_links': "source_id LIKE 'qa_demo_%' OR target_id LIKE 'qa_demo_%'",
      'observations': "id LIKE 'qa_demo_%' OR created_by = 'qa_showcase'",
      'micro_actions': "id LIKE 'qa_demo_%'",
      'micro_action_feedback': "micro_action_id LIKE 'qa_demo_%'",
      'life_experiments': "id LIKE 'qa_demo_%'",
      'life_experiment_feedback': "experiment_id LIKE 'qa_demo_%'",
      'life_experiment_lifecycle_events': "experiment_id LIKE 'qa_demo_%'",
      'life_experiment_rollups': "experiment_id LIKE 'qa_demo_%'",
      'plan_content_versions': "object_id LIKE 'qa_demo_%'",
    }.entries) {
      expect(
        Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM ${entry.key} WHERE ${entry.value}',
        )),
        0,
        reason: '${entry.key} still contains QA-owned rows.',
      );
    }
    for (final entry in <String, String>{
      'signal_cards': 'user_signal_keep',
      'observations': 'user_observation_keep',
      'micro_actions': 'user_action_keep',
      'life_experiments': 'user_experiment_keep',
    }.entries) {
      expect(
        Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM ${entry.key} WHERE id = ?',
          [entry.value],
        )),
        1,
        reason: '${entry.key} user row was removed.',
      );
    }
    expect(prefs.getString('qa_showcase_seed_signature_v2'), isNull);
    expect(prefs.getString('profile_display_name'), 'A real profile name');
    expect(prefs.getBool('onboarding_completed'), isNull);
    expect(prefs.getBool('onboardingCompleted'), isNull);
    expect(prefs.getString('local_app_started_date'), isNull);
  });
}

Future<Map<String, int>> _showcaseCounts(Database db) async => {
      'signals': Sqflite.firstIntValue(await db.rawQuery(
            "SELECT COUNT(*) FROM signal_cards WHERE id LIKE 'qa_demo_signal_%'",
          )) ??
          0,
      'recordDays': Sqflite.firstIntValue(await db.rawQuery(
            "SELECT COUNT(DISTINCT local_date) FROM signal_cards WHERE id LIKE 'qa_demo_signal_%'",
          )) ??
          0,
      'microActionFeedback': Sqflite.firstIntValue(await db.rawQuery(
            "SELECT COUNT(*) FROM micro_action_feedback WHERE micro_action_id = 'qa_demo_action_01'",
          )) ??
          0,
      'experimentFeedback': Sqflite.firstIntValue(await db.rawQuery(
            "SELECT COUNT(*) FROM life_experiment_feedback WHERE experiment_id = 'qa_demo_experiment_01'",
          )) ??
          0,
    };

Future<String> _showcaseVisibleText(Database db) async {
  final fragments = <String>[];

  Future<void> append(
    String table,
    List<String> columns, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final rows = await db.query(
      table,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
    );
    for (final row in rows) {
      for (final column in columns) {
        final value = row[column];
        if (value is String && value.isNotEmpty) fragments.add(value);
      }
    }
  }

  await append(
    'signal_cards',
    const ['raw_text', 'ai_reply', 'observation', 'try_next'],
    where: "id LIKE 'qa_demo_signal_%'",
  );
  await append(
    'observations',
    const ['observation_text', 'suggested_pattern', 'evidence_text'],
    where: "id LIKE 'qa_demo_observation_%'",
  );
  await append(
    'micro_actions',
    const ['title', 'reason'],
    where: "id LIKE 'qa_demo_action_%'",
  );
  await append(
    'micro_action_feedback',
    const ['user_note'],
    where: "micro_action_id = 'qa_demo_action_01'",
  );
  await append(
    'life_experiments',
    const ['title', 'hypothesis', 'suggested_action'],
    where: "id = 'qa_demo_experiment_01'",
  );
  await append(
    'life_experiment_feedback',
    const ['feedback_text'],
    where: "experiment_id = 'qa_demo_experiment_01'",
  );

  return fragments.join('\n');
}

Future<String> _weeklyDerivedVisibleText(
  AppDependencies dependencies, {
  required DateTime now,
  required String languageCode,
  required AppLanguage language,
}) async {
  final aiRepository = AiRepository(
    dependencies.apiClient,
    languageLoader: () => languageCode,
  );
  final weeklyRepository = WeeklyRepository(
    localCaptureRepository: dependencies.localCaptureRepository,
    localWeeklySnapshotRepository: dependencies.localWeeklySnapshotRepository,
    localLifeExperimentRepository: dependencies.localLifeExperimentRepository,
    localPhase3PlusRepository: dependencies.localPhase3PlusRepository,
    aiRepository: aiRepository,
    localUserId: dependencies.localUserId,
    installationDateLoader: () async => now.subtract(const Duration(days: 21)),
    nowLoader: () => now,
  );
  final weekly = await weeklyRepository.fetchCurrentWeekly();
  final deep = await weeklyRepository.fetchWeeklyReflect();
  final candidates = await dependencies.localCandidatePlanningRepository
      .refreshWeeklyWithGroundedSuggestions(
    day: now,
    language: language,
  );
  final fragments = <String>[
    weekly.keyInsight ?? '',
    weekly.bestAction ?? '',
    ..._visibleMapCopy(weekly.patterns),
    ..._visibleMapCopy(weekly.frictions),
    ..._visibleMapCopy([weekly.opportunitySnapshot]),
    for (final pattern in weekly.behaviorPatterns) ...[
      pattern.label,
      pattern.summary,
    ],
    weekly.energyProjection?.rationale ?? '',
    deep.summary,
    deep.rootTension,
    deep.hiddenPattern,
    deep.nextFocus,
    deep.riskNote,
    deep.patternLabel,
    deep.frictionLabel,
    deep.impactLabel,
    deep.relationshipSummary,
    deep.timingSummary,
    deep.nextQuestion,
    deep.scopeNote,
    for (final candidate in candidates.candidates) ...[
      candidate.title,
      candidate.hypothesis,
      candidate.suggestedAction,
    ],
  ];
  return fragments.where((value) => value.trim().isNotEmpty).join('\n');
}

Iterable<String> _visibleMapCopy(Iterable<Object?> rows) sync* {
  for (final row in rows) {
    if (row is! Map) continue;
    for (final key in const ['name', 'title', 'summary', 'description']) {
      final value = row[key]?.toString().trim();
      if (value != null && value.isNotEmpty) yield value;
    }
  }
}
