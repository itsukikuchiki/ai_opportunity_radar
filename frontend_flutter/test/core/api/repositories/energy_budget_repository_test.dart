import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_opportunity_radar/core/api/repositories/energy_budget_repository.dart';
import 'package:ai_opportunity_radar/core/models/advanced_energy_boundary_models.dart';
import 'package:ai_opportunity_radar/core/local/external_energy_hint_store.dart';
import 'package:ai_opportunity_radar/core/local/local_capture_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/local/local_life_experiment_repository.dart';
import 'package:ai_opportunity_radar/core/models/energy_budget_models.dart';
import 'package:ai_opportunity_radar/core/models/memory_models.dart';
import 'package:ai_opportunity_radar/core/models/weekly_models.dart';

final _fixedNow = DateTime(2026, 7, 8, 12);
const _fixedDate = '2026-07-08';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('EnergySignalState 只暴露五个稳定存储值', () {
    expect(
      EnergySignalState.values.map((state) => state.storageValue).toList(),
      const [
        'draining',
        'steady',
        'ease',
        'recovery',
        'boundary_buffer',
      ],
    );
    expect(
      EnergySignalState.fromStorage('unknown'),
      EnergySignalState.steady,
    );
  });

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
      await harness.seedNeutralGateSignals(count: 1);

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

    test('time_use v1 的场景和 energy_effect 保持兼容', () async {
      final harness = await _createHarness(dbPath);

      await harness.seedSignalCard(
        id: 'time_use_meeting',
        sourceType: 'time_use',
        content: '09:00–10:30 · 成长计划 · 团队会议',
        rawPayloadJson: const {
          'timeline_type': 'time_use',
          'schema_version': 1,
          'record_status': 'completed',
          'category': 'growth_plan',
          'energy_effect': 'draining',
          'duration_minutes': 90,
        },
      );
      await harness.seedNeutralGateSignals(count: 2);

      final budget = await harness.repository.fetchBasicEnergyBudget();

      expect(budget.blockByType('high_drain'), isNotNull);
      expect(budget.mostDrainingSource, contains('growth_plan'));
      expect(budget.scheduleDensityHint, contains('主动登记的时间 Signal'));

      await harness.close();
    });

    test('每条合格 Signal 互斥投影为五种能量状态', () async {
      final harness = await _createHarness(dbPath);

      await harness.seedSignalCard(
        id: 'explicit_low_wins',
        content: '显式低精力优先',
        energyLoad: 'restoring',
        positiveSignal: 'walk',
        rawPayloadJson: const {'energy_level': 0},
      );
      await harness.seedSignalCard(
        id: 'explicit_high_wins',
        content: '显式高精力优先',
        energyLoad: 'draining',
        rawPayloadJson: const {'energy_level': 2},
      );
      await harness.seedSignalCard(
        id: 'legacy_neutral',
        content: '旧三态中性',
        rawPayloadJson: const {'energy_effect': 'neutral'},
      );
      await harness.seedSignalCard(
        id: 'draining_marker',
        content: '明确耗力标记',
        energyLoad: 'draining',
      );
      await harness.seedSignalCard(
        id: 'recovery_marker',
        content: '明确恢复标记',
        energyLoad: 'restoring',
        positiveSignal: 'quiet_break',
      );
      await harness.seedSignalCard(
        id: 'conflicting_markers',
        content: '耗力与恢复标记冲突',
        energyLoad: 'draining',
        positiveSignal: 'support',
      );
      await harness.seedSignalCard(
        id: 'directionless',
        content: '没有能量方向也不落入未判断',
      );
      await harness.seedSignalCard(
        id: 'boundary_buffer_marker',
        content: '给下一件事留了缓冲',
        friction: 'boundary_load',
        lifeChainStages: const ['boundary_buffer'],
      );
      await harness.seedSignalCard(
        id: 'ease_marker',
        content: '今天做得很顺畅，还有余力',
        positiveSignal: 'flow',
      );
      await harness.seedSignalCard(
        id: 'planned_energy_is_not_fact',
        content: '计划中的高精力不是已发生事实',
        sourceType: 'time_use',
        rawPayloadJson: const {
          'schema_version': 2,
          'record_status': 'planned',
          'energy_level': 2,
          'energy_effect': 'restoring',
        },
      );

      final budget = await harness.repository.fetchBasicEnergyBudget();

      expect(
        budget.energyStateCounts,
        const {
          'draining': 3,
          'steady': 3,
          'ease': 2,
          'recovery': 1,
          'boundary_buffer': 1,
        },
      );
      expect(
        budget.energyStateCounts.values
            .fold<int>(0, (sum, count) => sum + count),
        10,
        reason: '每条合格 Signal 必须且只能计入一个能量状态。',
      );
      expect(budget.energyStateCounts, isNot(contains('unknown')));
      expect(budget.energyStateCounts, isNot(contains('resourced')));
      expect(budget.energyStateCounts, isNot(contains('restoring')));

      await harness.close();
    });

    test('关注领域本身不自动推断恢复 block', () async {
      final harness = await _createHarness(dbPath);

      await harness.seedSignalCard(
        id: 'legacy_recovery_category_only',
        sourceType: 'time_use',
        content: '记录了一段恢复时间，但没有登记体感',
        rawPayloadJson: const {
          'timeline_type': 'time_use',
          'schema_version': 1,
          'record_status': 'completed',
          'category': 'recovery',
        },
      );
      await harness.seedNeutralGateSignals(count: 2);

      final budget = await harness.repository.fetchBasicEnergyBudget();

      expect(budget.blockByType('recovery'), isNull);
      await harness.close();
    });

    test('legacy / inaccurate 被排除，普通 unconfirmed 只保留轻证据等级', () async {
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
      await harness.seedNeutralGateSignals(count: 2);

      final budget = await harness.repository.fetchBasicEnergyBudget();

      expect(budget.hasAnyBlocks, true);
      expect(budget.blockByType('high_drain')?.count, 1);
      expect(budget.mostDrainingSource, isNot(contains('overload')));
      expect(
        {'light_observation'}
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
      await harness.seedNeutralGateSignals(count: 2);

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
      await harness.seedNeutralGateSignals(count: 2);

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
      await harness.seedNeutralGateSignals(count: 2);

      final budget = await harness.repository.fetchBasicEnergyBudget();

      expect(budget.experimentConnection, contains('小实验'));
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

    test('Health abstract hints 辅助 Energy Budget，Calendar 保持隔离', () async {
      final harness = await _createHarness(dbPath);

      await harness.seedSignalCard(
        id: 'confirmed_internal',
        content: '我确认真正耗力的是会议后的切换。',
        energyLoad: 'draining',
        friction: 'context_switch',
        userConfirmation: 'accurate',
      );
      await harness.seedNeutralGateSignals(count: 2);

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

      expect(budget.status, 'ready');
      expect(budget.mostDrainingSource, contains('context_switch'));
      expect(budget.scheduleDensityHint, contains('不会读取系统日历'));
      expect(budget.recoverySignalHint, contains('恢复 Signal'));
      expect(
        budget.recoverySignalHint,
        isNot(contains('Recovery signals')),
      );
      expect(budget.recoverySignalHint, isNot(contains('分数低')));
      expect(budget.recoverySignalHint, isNot(contains('诊断')));
      expect(
        budget.externalConflictNote,
        contains('以你确认过的 Signal 记录'),
      );
      expect(
        budget.abstractExternalHints.keys,
        isNot(contains('schedule_density_hint')),
      );
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
      await harness.seedNeutralGateSignals(count: 2);

      final budget = await harness.repository.fetchBasicEnergyBudget(
        externalSummary: const AdvancedEnergyExternalSummary(),
      );

      expect(budget.status, 'ready');
      expect(budget.mostDrainingSource, contains('task_switching'));
      expect(budget.scheduleDensityHint, contains('不会读取系统日历'));
      expect(budget.recoverySignalHint, contains('内部记录'));
      expect(budget.externalConflictNote, contains('内部 Signal 记录'));
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
      await harness.seedNeutralGateSignals(count: 2);

      final budget = await harness.repository.fetchBasicEnergyBudget(
        externalSummary: const AdvancedEnergyExternalSummary(
          lowRecoveryHint:
              'Recovery signals may be a little weak in this stretch.',
          scheduleDensityHint: 'This period may be fairly full.',
        ),
      );

      expect(budget.mostDrainingSource, contains('relationship_message'));
      expect(budget.recoveryClue, contains('quiet_evening'));
      expect(
        budget.externalConflictNote,
        contains('以你确认过的 Signal 记录'),
      );
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
      await harness.seedNeutralGateSignals(count: 2);

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
      await harness.seedNeutralGateSignals(count: 2);

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

    test('设置页保存的 abstract hints 会被 Energy Budget 自动读取', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final hintStore = ExternalEnergyHintStore(prefs);
      await hintStore.saveCalendarHints(const {
        'schedule_density_hint': 'This period may be somewhat dense.',
        'event_title': 'Private meeting title',
      });
      await hintStore.saveHealthHints(const {
        'low_recovery_hint': 'Recovery signals may be a little weak.',
        'raw_sleep_samples': 'private health sample',
      });
      final harness = await _createHarness(dbPath, hintStore: hintStore);

      await harness.seedSignalCard(
        id: 'stored_hint_internal',
        content: '今天真正耗力的是消息切换。',
        energyLoad: 'draining',
        friction: 'message_switch',
        userConfirmation: 'accurate',
      );
      await harness.seedNeutralGateSignals(count: 2);

      final budget = await harness.repository.fetchBasicEnergyBudget();

      expect(budget.scheduleDensityHint, contains('不会读取系统日历'));
      expect(budget.recoverySignalHint, contains('恢复 Signal'));
      expect(
        budget.recoverySignalHint,
        isNot(contains('Recovery signals')),
      );
      expect(
        budget.abstractExternalHints.keys,
        isNot(contains('schedule_density_hint')),
      );
      expect(budget.abstractExternalHints.keys, contains('low_recovery_hint'));
      expect(budget.abstractExternalHints.keys, isNot(contains('event_title')));
      expect(
        budget.abstractExternalHints.keys,
        isNot(contains('raw_sleep_samples')),
      );
      expect(budget.mostDrainingSource, contains('message_switch'));

      await harness.close();
    });

    test('当日最后一条明确状态生效，跨过本地日界后回到 unknown', () async {
      final harness = await _createHarness(dbPath);
      await harness.seedSignalCard(
        id: 'state_high_first',
        content: '早上状态还可以',
        sourceType: 'one_tap',
        rawPayloadJson: const {
          'quick_status': 'calm',
          'energy_level': 2,
        },
        createdAt: DateTime(2026, 7, 8, 8),
      );
      await harness.seedSignalCard(
        id: 'state_low_latest',
        content: '下午明确感到疲惫',
        sourceType: 'one_tap',
        rawPayloadJson: const {
          'quick_status': 'tired',
          'energy_level': 0,
        },
        createdAt: DateTime(2026, 7, 8, 16),
      );

      final today = await harness.repository.fetchDailySnapshot(
        day: _fixedNow,
      );
      final nextDay = await harness.repository.fetchDailySnapshot(
        day: DateTime(2026, 7, 9, 9),
      );

      expect(today.periodStart, _fixedDate);
      expect(today.capacityBand, EnergyCapacityBand.veryLow);
      expect(today.evidenceSignalIds, contains('state_high_first'));
      expect(today.evidenceSignalIds, contains('state_low_latest'));
      expect(nextDay.capacityBand, EnergyCapacityBand.unknown);
      expect(nextDay.evidenceSignalIds, isEmpty);
      await harness.close();
    });

    test('completed time_use v2 可提供当日上下文，planned 精力不参与', () async {
      final harness = await _createHarness(dbPath);
      await harness.seedSignalCard(
        id: 'completed_time_use_low',
        content: '上午这段时间后精力偏低',
        sourceType: 'time_use',
        rawPayloadJson: const {
          'timeline_type': 'time_use',
          'schema_version': 2,
          'record_status': 'completed',
          'focus_domain_id': 'growth_plan',
          'category': 'growth_plan',
          'energy_level': 0,
          'end_at': '2026-07-08T10:00:00+09:00',
        },
        createdAt: DateTime(2026, 7, 8, 10),
      );
      await harness.seedSignalCard(
        id: 'planned_time_use_high',
        content: '晚上计划做一件可能有精神的事',
        sourceType: 'time_use',
        rawPayloadJson: const {
          'timeline_type': 'time_use',
          'schema_version': 2,
          'record_status': 'planned',
          'focus_domain_id': 'interests_hobbies',
          'category': 'interests_hobbies',
          'energy_level': 2,
          'energy_effect': 'restoring',
          'end_at': '2026-07-08T20:00:00+09:00',
        },
        createdAt: DateTime(2026, 7, 8, 11),
      );

      final snapshot = await harness.repository.fetchDailySnapshot(
        day: _fixedNow,
      );

      expect(snapshot.capacityBand, EnergyCapacityBand.low);
      expect(snapshot.budget.blockByType('recovery'), isNull);
      await harness.close();
    });

    test('time_use v1 的 neutral effect 是明确中性上下文证据', () async {
      final harness = await _createHarness(dbPath);
      await harness.seedSignalCard(
        id: 'legacy_neutral_time_use',
        content: '这段时间体感一般',
        sourceType: 'time_use',
        rawPayloadJson: const {
          'timeline_type': 'time_use',
          'schema_version': 1,
          'record_status': 'completed',
          'category': 'work',
          'energy_effect': 'neutral',
          'end_at': '2026-07-08T10:00:00+09:00',
        },
        createdAt: DateTime(2026, 7, 8, 10),
      );

      final snapshot = await harness.repository.fetchDailySnapshot(
        day: _fixedNow,
      );

      expect(snapshot.capacityBand, EnergyCapacityBand.medium);
      expect(snapshot.confidence, isNot('unknown'));
      await harness.close();
    });

    test('当天 one_tap 是 current state 锚点，不被后续 time_use 覆盖', () async {
      final harness = await _createHarness(dbPath);
      await harness.seedSignalCard(
        id: 'explicit_current_high',
        content: '现在精力很足',
        sourceType: 'one_tap',
        rawPayloadJson: const {
          'quick_status': 'calm',
          'energy_level': 2,
        },
        createdAt: DateTime(2026, 7, 8, 9),
      );
      await harness.seedSignalCard(
        id: 'later_time_use_low',
        content: '一段工作后的体感偏低',
        sourceType: 'time_use',
        rawPayloadJson: const {
          'timeline_type': 'time_use',
          'schema_version': 2,
          'record_status': 'completed',
          'focus_domain_id': 'growth_plan',
          'category': 'growth_plan',
          'energy_level': 0,
          'end_at': '2026-07-08T11:00:00+09:00',
        },
        createdAt: DateTime(2026, 7, 8, 11),
      );

      final snapshot = await harness.repository.fetchDailySnapshot(
        day: _fixedNow,
      );

      expect(snapshot.capacityBand, EnergyCapacityBand.high);
      await harness.close();
    });

    test('周聚合纳入 completed time_use，忽略 planned time_use 精力', () async {
      final harness = await _createHarness(dbPath);
      await harness.seedSignalCard(
        id: 'week_completed_low',
        content: '已发生时段后的精力偏低',
        sourceType: 'time_use',
        rawPayloadJson: const {
          'timeline_type': 'time_use',
          'schema_version': 2,
          'record_status': 'completed',
          'focus_domain_id': 'self_boundary',
          'category': 'self_boundary',
          'energy_level': 0,
          'end_at': '2026-07-08T09:00:00+09:00',
        },
        createdAt: DateTime(2026, 7, 8, 9),
      );
      await harness.seedSignalCard(
        id: 'week_planned_high',
        content: '未来计划不能当成真实精力',
        sourceType: 'time_use',
        rawPayloadJson: const {
          'timeline_type': 'time_use',
          'schema_version': 2,
          'record_status': 'planned',
          'focus_domain_id': 'interests_hobbies',
          'category': 'interests_hobbies',
          'energy_level': 2,
          'energy_effect': 'restoring',
          'end_at': '2026-07-08T20:00:00+09:00',
        },
        createdAt: DateTime(2026, 7, 8, 10),
      );
      await harness.seedNeutralGateSignals(count: 1);

      final snapshot = await harness.repository.fetchWeeklySnapshot(
        day: _fixedNow,
      );

      expect(snapshot.readiness, 'ready');
      expect(snapshot.capacityBand, EnergyCapacityBand.low);
      expect(snapshot.budget.blockByType('recovery'), isNull);
      await harness.close();
    });

    test('周快照严格限定本地周一到周日，不混入历史信号', () async {
      final harness = await _createHarness(dbPath);
      await harness.seedSignalCard(
        id: 'current_week_drain',
        content: '本周任务切换很耗力',
        energyLoad: 'draining',
        friction: 'current_switching',
      );
      await harness.seedNeutralGateSignals(count: 2);
      await harness.seedSignalCard(
        id: 'previous_week_drain',
        content: '上周的强烈消耗不应混入',
        energyLoad: 'draining',
        friction: 'historical_overload',
        localDate: '2026-07-05',
        createdAt: DateTime(2026, 7, 5, 20),
      );

      final snapshot = await harness.repository.fetchWeeklySnapshot(
        day: _fixedNow,
      );

      expect(snapshot.periodStart, '2026-07-06');
      expect(snapshot.periodEnd, '2026-07-12');
      expect(snapshot.evidenceSignalIds, contains('current_week_drain'));
      expect(
          snapshot.evidenceSignalIds, isNot(contains('previous_week_drain')));
      expect(snapshot.budget.mostDrainingSource, contains('current_switching'));
      expect(snapshot.budget.mostDrainingSource,
          isNot(contains('historical_overload')));
      await harness.close();
    });

    test('周信号未达 3 条时只有中性 readiness，不生成完整结论', () async {
      final harness = await _createHarness(dbPath);
      await harness.seedSignalCard(
        id: 'one_of_two',
        content: '今天消耗较多',
        energyLoad: 'draining',
        friction: 'overload',
      );
      await harness.seedNeutralGateSignals(count: 1);

      final snapshot = await harness.repository.fetchWeeklySnapshot(
        day: _fixedNow,
      );

      expect(snapshot.readiness, 'light_ready');
      expect(snapshot.budget.status, 'insufficient_data');
      expect(snapshot.budget.blocks, isEmpty);
      expect(
        snapshot.budget.energyStateCounts,
        const {
          'draining': 1,
          'steady': 1,
          'ease': 0,
          'recovery': 0,
          'boundary_buffer': 0,
        },
        reason: '报告门槛不得丢失已有 Signal 的五态归类。',
      );
      await harness.close();
    });

    test('Calendar 抽象提示不进快照或 source hash，Health 允许值会进入', () async {
      final harness = await _createHarness(dbPath);
      await harness.seedNeutralGateSignals(count: 3);

      final calendarA = await harness.repository.fetchWeeklySnapshot(
        day: _fixedNow,
        externalSummary: const AdvancedEnergyExternalSummary(
          scheduleDensityHint: 'calendar-a',
          switchingHint: 'calendar-switch-a',
        ),
      );
      final calendarB = await harness.repository.fetchWeeklySnapshot(
        day: _fixedNow,
        externalSummary: const AdvancedEnergyExternalSummary(
          scheduleDensityHint: 'calendar-b',
          switchingHint: 'calendar-switch-b',
        ),
      );
      final health = await harness.repository.fetchWeeklySnapshot(
        day: _fixedNow,
        externalSummary: const AdvancedEnergyExternalSummary(
          lowRecoveryHint: 'recovery may be low',
        ),
      );

      expect(calendarA.sourceHash, calendarB.sourceHash);
      expect(calendarA.budget.abstractExternalHints, isEmpty);
      expect(health.sourceHash, isNot(calendarA.sourceHash));
      expect(health.budget.abstractExternalHints.keys,
          contains('low_recovery_hint'));
      expect(health.capacityBand, EnergyCapacityBand.unknown,
          reason: 'Health-only evidence must not invent a capacity state.');
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
    String localDate = _fixedDate,
    DateTime? createdAt,
  }) async {
    final db = await localDatabase.database;
    final now = (createdAt ?? _fixedNow).toUtc();
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
        'local_date': localDate,
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

  Future<void> seedNeutralGateSignals({required int count}) async {
    for (var index = 0; index < count; index++) {
      await seedSignalCard(
        id: 'neutral_gate_$index',
        content: '用于达到三条信号门槛的中性记录 $index',
      );
    }
  }

  Future<void> seedExperiment({
    String status = 'saved',
    String? feedbackText,
  }) async {
    final db = await localDatabase.database;
    final now = _fixedNow.toUtc();
    await db.insert(
      'life_experiments',
      {
        'id': 'exp_energy',
        'local_user_id': 'test-user',
        'source_week_start': '2026-07-06',
        'source_week_end': '2026-07-12',
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

Future<_Harness> _createHarness(
  String dbPath, {
  ExternalEnergyHintStore? hintStore,
}) async {
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
    externalEnergyHintStore: hintStore,
    localUserId: 'test-user',
    nowLoader: () => _fixedNow,
    languageLoader: () => 'zh-Hans',
  );

  return _Harness(
    localDatabase: localDatabase,
    repository: repository,
  );
}
