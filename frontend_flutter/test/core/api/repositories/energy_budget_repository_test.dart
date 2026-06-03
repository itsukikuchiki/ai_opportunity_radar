import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_opportunity_radar/core/api/repositories/energy_budget_repository.dart';
import 'package:ai_opportunity_radar/core/models/advanced_energy_boundary_models.dart';
import 'package:ai_opportunity_radar/core/local/local_capture_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/local/local_life_experiment_repository.dart';
import 'package:ai_opportunity_radar/core/models/memory_models.dart';
import 'package:ai_opportunity_radar/core/models/weekly_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String dbPath;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    tempDir =
        await Directory.systemTemp.createTemp('ai_radar_energy_budget_test_');
    dbPath = p.join(tempDir.path, 'energy_budget_test.db');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('EnergyBudgetRepository basic internal signals', () {
    test('读取 SignalCard，并从 energy_load / friction 聚合 energy blocks', () async {
      final harness = await _createHarness(dbPath);

      await harness.seedSignalCard(
        id: 'drain_switch',
        content: '上午会议切换很多，晚上很累',
        energyLoad: 'draining',
        friction: 'context_switch',
        scene: 'work',
        lifeChainStages: const ['attention_switching', 'energy_drain'],
      );
      await harness.seedSignalCard(
        id: 'recovery_walk',
        content: '散步之后恢复了一点',
        energyLoad: 'restoring',
        positiveSignal: 'walk',
        scene: 'recovery',
        lifeChainStages: const ['recovery'],
      );

      final budget = await harness.repository.fetchBasicEnergyBudget();

      expect(budget.status, 'ready');
      expect(budget.blockByType('high_drain'), isNotNull);
      expect(budget.blockByType('high_switching'), isNotNull);
      expect(budget.blockByType('recovery'), isNotNull);
      expect(budget.mostDrainingSource, contains('context_switch'));
      expect(budget.recoveryClue, contains('walk'));
      expect(budget.switchingAdjustment, contains('留一点余地'));

      await harness.close();
    });

    test('legacy / unconfirmed 可进入但保持证据等级，inaccurate 不进入', () async {
      final harness = await _createHarness(dbPath);

      await harness.seedSignalCard(
        id: 'legacy_context',
        content: '旧记录：会议之后耗力',
        energyLoad: 'draining',
        friction: 'meeting',
        isLegacy: true,
      );
      await harness.seedSignalCard(
        id: 'unconfirmed_context',
        content: '未确认：消息切换很多',
        energyLoad: 'draining',
        friction: 'message_switch',
      );
      await harness.seedSignalCard(
        id: 'inaccurate_context',
        content: '用户说这个不准',
        energyLoad: 'draining',
        friction: 'overload',
        userConfirmation: 'inaccurate',
      );

      final budget = await harness.repository.fetchBasicEnergyBudget();

      expect(budget.hasAnyBlocks, true);
      expect(budget.blockByType('high_drain')?.count, 2);
      expect(budget.mostDrainingSource, isNot(contains('overload')));
      expect(
        {'legacy_context', 'unconfirmed'}
            .contains(budget.blockByType('high_drain')?.evidenceLevel),
        true,
      );

      await harness.close();
    });

    test('excluded / sensitive / sync failed 不进入 Energy Budget', () async {
      final harness = await _createHarness(dbPath);

      await harness.seedSignalCard(
        id: 'good',
        content: '工作切换多',
        energyLoad: 'draining',
        friction: 'context_switch',
      );
      await harness.seedSignalCard(
        id: 'excluded',
        content: '不分析',
        energyLoad: 'draining',
        friction: 'overload',
        privacyLevel: 'excluded',
      );
      await harness.seedSignalCard(
        id: 'sensitive',
        content: '敏感内容',
        energyLoad: 'draining',
        friction: 'relationship',
        privacyLevel: 'sensitive',
      );
      await harness.seedSignalCard(
        id: 'failed',
        content: '同步失败',
        energyLoad: 'draining',
        friction: 'meeting',
        syncFailed: true,
      );

      final budget = await harness.repository.fetchBasicEnergyBudget();

      expect(budget.blockByType('high_drain')?.count, 1);
      expect(budget.mostDrainingSource, contains('context_switch'));
      expect(budget.mostDrainingSource, isNot(contains('overload')));
      expect(budget.mostDrainingSource, isNot(contains('relationship')));
      expect(budget.mostDrainingSource, isNot(contains('meeting')));

      await harness.close();
    });

    test('unconfirmed library_saved 不作为 Energy Budget 强证据', () async {
      final harness = await _createHarness(dbPath);

      await harness.seedSignalCard(
        id: 'library_unconfirmed',
        content: '',
        sourceType: 'library_saved',
        userConfirmation: 'unconfirmed',
        energyLoad: 'draining',
        friction: 'context_switch',
        rawPayloadJson: const {
          'library_pattern_id': 'attention_switching_fatigue',
          'title': 'Attention switching fatigue',
        },
      );
      await harness.seedSignalCard(
        id: 'library_confirmed',
        content: '',
        sourceType: 'library_saved',
        userConfirmation: 'supplemented',
        userCorrectionJson: const {
          'supplement_text': 'This matched my week after I added context.',
        },
        energyLoad: 'draining',
        friction: 'message_switch',
        rawPayloadJson: const {
          'library_pattern_id': 'boundary_fatigue',
          'title': 'Boundary fatigue',
        },
      );

      final budget = await harness.repository.fetchBasicEnergyBudget();

      expect(budget.blockByType('high_drain')?.count, 1);
      expect(
        budget.blockByType('high_drain')?.evidenceLevel,
        'library_saved_confirmed',
      );
      expect(budget.mostDrainingSource, isNot(contains('context_switch')));

      await harness.close();
    });

    test('Life Experiment feedback 接入，不变成 habit tracker 或失败评判', () async {
      final harness = await _createHarness(dbPath);

      await harness.seedSignalCard(
        id: 'buffer_need',
        content: '晚上安排太满',
        energyLoad: 'draining',
        friction: 'schedule_overload',
        lifeChainStages: const ['buffer'],
      );
      await harness.seedExperiment(
        status: 'not_helpful',
        feedbackText: '这次帮助不明显，需要再调小。',
      );

      final budget = await harness.repository.fetchBasicEnergyBudget();

      expect(budget.experimentConnection, contains('Life Experiment'));
      expect(budget.experimentConnection, contains('帮助不明显'));
      expect(budget.experimentConnection, contains('省一点力'));
      expect(budget.experimentConnection, isNot(contains('失败')));

      await harness.close();
    });

    test('数据不足时可以用 Weekly / Journey 作为轻量 fallback', () async {
      final harness = await _createHarness(dbPath);
      final weekly = WeeklyInsightModel(
        weekStart: '2026-05-25',
        weekEnd: '2026-05-31',
        status: 'light_ready',
        keyInsight: '这周先轻一点看。',
        patterns: const [],
        frictions: const [],
        bestAction: '下周可以试试给会议之间留十分钟。',
        opportunitySnapshot: null,
        feedbackSubmitted: false,
      );
      final journey = MemorySummaryModel(
        patterns: const [],
        frictions: const [],
        desires: const [
          JourneySignalItemModel(
            name: '恢复线索',
            summary: '散步让状态稍微往回收一点。',
            signalLevel: 'weak_signal',
          ),
        ],
        experiments: const [],
      );

      final budget = await harness.repository.fetchBasicEnergyBudget(
        weekly: weekly,
        journey: journey,
      );

      expect(budget.status, 'insufficient_data');
      expect(budget.blocks, isEmpty);
      expect(budget.switchingAdjustment, contains('会议之间留十分钟'));
      expect(budget.experimentConnection, contains('不用急着改变'));

      await harness.close();
    });

    test('Calendar / HealthKit 未授权时仍基于内部 SignalCard 运行', () async {
      const consent = AdvancedEnergyConsentState(
        calendar: ExternalEnergyPermissionStatus.denied,
        healthKit: ExternalEnergyPermissionStatus.notRequested,
      );
      final harness = await _createHarness(dbPath);

      await harness.seedSignalCard(
        id: 'internal_signal',
        content: '会议之间切换很多，有点耗力',
        energyLoad: 'draining',
        friction: 'context_switch',
      );

      final budget = await harness.repository.fetchBasicEnergyBudget();

      expect(consent.appCanRunWithoutExternalConsent, isTrue);
      expect(budget.status, 'light_ready');
      expect(budget.mostDrainingSource, contains('context_switch'));
      expect(budget.blocks, isNotEmpty);

      await harness.close();
    });

    test('Calendar + Health abstract hints 接入 Energy Budget 辅助层', () async {
      final harness = await _createHarness(dbPath);

      await harness.seedSignalCard(
        id: 'confirmed_internal',
        content: '我确认真正耗力的是会议后的切换。',
        energyLoad: 'draining',
        friction: 'context_switch',
        userConfirmation: 'accurate',
      );

      final budget = await harness.repository.fetchBasicEnergyBudget(
        externalSummary: const AdvancedEnergyExternalSummary(
          scheduleDensityHint: 'This period may be somewhat dense.',
          switchingHint:
              'Several transitions may make this period feel a little dense.',
          lowRecoveryHint:
              'Recovery signals may be a little weak in this stretch.',
          recoveryGapHint:
              'This period may be a good place to leave some recovery space.',
        ),
      );

      expect(budget.status, 'light_ready');
      expect(budget.mostDrainingSource, contains('context_switch'));
      expect(budget.scheduleDensityHint, contains('日程密度提示'));
      expect(budget.recoverySignalHint, contains('恢复信号提示'));
      expect(budget.recoverySignalHint, isNot(contains('分数低')));
      expect(budget.recoverySignalHint, isNot(contains('诊断')));
      expect(budget.externalConflictNote, contains('以你确认过的 SignalCard'));
      expect(
          budget.abstractExternalHints.keys, contains('schedule_density_hint'));
      expect(budget.abstractExternalHints.keys, contains('low_recovery_hint'));

      await harness.close();
    });

    test('external hints 缺失时回到内部 SignalCard Energy Budget', () async {
      final harness = await _createHarness(dbPath);

      await harness.seedSignalCard(
        id: 'internal_only',
        content: '今天主要是任务切换耗力。',
        energyLoad: 'draining',
        friction: 'task_switching',
      );

      final budget = await harness.repository.fetchBasicEnergyBudget(
        externalSummary: const AdvancedEnergyExternalSummary(),
      );

      expect(budget.status, 'light_ready');
      expect(budget.mostDrainingSource, contains('task_switching'));
      expect(budget.scheduleDensityHint, contains('内部记录'));
      expect(budget.recoverySignalHint, contains('内部记录'));
      expect(budget.externalConflictNote, contains('内部 SignalCard'));
      expect(budget.abstractExternalHints, isEmpty);

      await harness.close();
    });

    test('conflict rule: user-confirmed SignalCard 优先于外部 hints', () async {
      final harness = await _createHarness(dbPath);

      await harness.seedSignalCard(
        id: 'user_confirmed_recovery',
        content: '我确认今天恢复感还可以，真正耗力的是关系消息。',
        energyLoad: 'restoring',
        friction: 'relationship_message',
        positiveSignal: 'quiet_evening',
        userConfirmation: 'supplemented',
      );

      final budget = await harness.repository.fetchBasicEnergyBudget(
        externalSummary: const AdvancedEnergyExternalSummary(
          lowRecoveryHint:
              'Recovery signals may be a little weak in this stretch.',
          scheduleDensityHint: 'This period may be fairly full.',
        ),
      );

      expect(budget.mostDrainingSource, contains('relationship_message'));
      expect(budget.recoveryClue, contains('quiet_evening'));
      expect(budget.externalConflictNote, contains('以你确认过的 SignalCard'));
      expect(budget.externalConflictNote, isNot(contains('自动')));

      await harness.close();
    });

    test('raw external data 不进入 Energy Budget 输出或 metadata', () async {
      final harness = await _createHarness(dbPath);

      await harness.seedSignalCard(
        id: 'safe_internal',
        content: '今天会议切换多。',
        energyLoad: 'draining',
        friction: 'meeting_switch',
      );

      final budget = await harness.repository.fetchBasicEnergyBudget(
        externalSummary: const AdvancedEnergyExternalSummary(
          scheduleDensityHint: 'This period may be fairly full.',
          sleepRecoveryHint: 'Sleep recovery signals may be a little light.',
        ),
      );

      final output = [
        budget.mostDrainingSource,
        budget.scheduleDensityHint,
        budget.recoverySignalHint,
        budget.bufferLocation,
        budget.switchingAdjustment,
        budget.experimentConnection,
      ].join('\n');

      expect(output, isNot(contains('event_title')));
      expect(output, isNot(contains('location')));
      expect(output, isNot(contains('attendees')));
      expect(output, isNot(contains('raw_sleep_samples')));
      expect(output, isNot(contains('raw_heart_rate')));
      expect(budget.abstractExternalHints.keys, isNot(contains('event_title')));
      expect(
        budget.abstractExternalHints.keys,
        isNot(contains('raw_sleep_samples')),
      );

      await harness.close();
    });

    test('external hints 不进入 Signal Library，也不作为主证据', () async {
      final harness = await _createHarness(dbPath);

      await harness.seedSignalCard(
        id: 'primary_internal',
        content: '我记录的是边界感消耗。',
        energyLoad: 'draining',
        friction: 'boundary',
        userConfirmation: 'accurate',
      );

      final budget = await harness.repository.fetchBasicEnergyBudget(
        externalSummary: const AdvancedEnergyExternalSummary(
          scheduleDensityHint: 'This period may be somewhat dense.',
          stableRecoveryHint:
              'Recovery signals look relatively stable in this stretch.',
        ),
      );

      expect(budget.mostDrainingSource, contains('boundary'));
      expect(budget.abstractExternalHints, isNotEmpty);
      expect(budget.abstractExternalHints.keys, isNot(contains('raw_text')));
      expect(budget.externalConflictNote, contains('确认记录'));

      await harness.close();
    });
  });
}

class _Harness {
  final LocalDatabase localDatabase;
  final EnergyBudgetRepository repository;

  _Harness({
    required this.localDatabase,
    required this.repository,
  });

  Future<void> seedSignalCard({
    required String id,
    required String content,
    String energyLoad = 'neutral',
    String? friction,
    String? scene,
    String? positiveSignal,
    List<String> lifeChainStages = const [],
    String sourceType = 'text',
    Map<String, dynamic> rawPayloadJson = const {},
    Map<String, dynamic> userCorrectionJson = const {},
    String userConfirmation = 'unconfirmed',
    String privacyLevel = 'private',
    bool isLegacy = false,
    bool syncFailed = false,
  }) async {
    final db = await localDatabase.database;
    final now = DateTime.now().toUtc();
    await db.insert(
      'signal_cards',
      {
        'id': id,
        'signal_card_id': id,
        'raw_memory_id': null,
        'capture_id': null,
        'source_type': sourceType,
        'raw_text': content,
        'created_at': now.toIso8601String(),
        'local_date': _dateKey(now),
        'timezone': 'Asia/Tokyo',
        'language': 'zh-Hans',
        'ai_reply': '先保存下来。',
        'observation': null,
        'try_next': null,
        'emotion': null,
        'intensity': null,
        'scene': scene,
        'friction': friction,
        'positive_signal': positiveSignal,
        'energy_load': energyLoad,
        'linked_life_chain_stage': jsonEncode(lifeChainStages),
        'raw_payload_json': jsonEncode(rawPayloadJson),
        'scene_tags_json': '[]',
        'intent_tags_json': '[]',
        'user_confirmation': userConfirmation,
        'user_correction_json': jsonEncode(userCorrectionJson),
        'included_in_summary': 0,
        'included_in_weekly': 0,
        'included_in_journey': 0,
        'linked_experiment_id': null,
        'privacy_level': privacyLevel,
        'is_legacy': isLegacy ? 1 : 0,
        'migration_status': isLegacy ? 'local_legacy' : 'native',
        'is_local_draft': 0,
        'sync_failed': syncFailed ? 1 : 0,
        'sync_status': syncFailed ? 'failed' : 'synced',
        'last_error': syncFailed ? 'network failed' : null,
        'updated_at': now.toIso8601String(),
      },
    );
  }

  Future<void> seedExperiment({
    String status = 'saved',
    String? feedbackText,
  }) async {
    final db = await localDatabase.database;
    final now = DateTime.now().toUtc();
    await db.insert(
      'life_experiments',
      {
        'id': 'exp_energy',
        'local_user_id': 'test-user',
        'source_week_start': '2026-05-25',
        'source_week_end': '2026-05-31',
        'title': '给晚上留一点缓冲',
        'hypothesis': '少一点贴紧安排可能会省力',
        'suggested_action': '晚间安排之间留十分钟',
        'linked_signal_card_ids_json': '[]',
        'status': status,
        'feedback_text': feedbackText,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      },
    );
  }

  Future<void> close() async {
    await localDatabase.close();
  }
}

Future<_Harness> _createHarness(String dbPath) async {
  final localDatabase = LocalDatabase(
    dbPathOverride: dbPath,
    databaseFactoryOverride: databaseFactoryFfi,
  );
  await localDatabase.init();

  final localCaptureRepository = LocalCaptureRepository(localDatabase);
  final localLifeExperimentRepository =
      LocalLifeExperimentRepository(localDatabase);

  final repository = EnergyBudgetRepository(
    localCaptureRepository: localCaptureRepository,
    localLifeExperimentRepository: localLifeExperimentRepository,
    localUserId: 'test-user',
  );

  return _Harness(
    localDatabase: localDatabase,
    repository: repository,
  );
}

String _dateKey(DateTime date) {
  final local = date.toLocal();
  final mm = local.month.toString().padLeft(2, '0');
  final dd = local.day.toString().padLeft(2, '0');
  return '${local.year}-$mm-$dd';
}
