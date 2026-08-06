import 'package:ai_opportunity_radar/core/energy/today_status_overview.dart';
import 'package:ai_opportunity_radar/core/models/energy_budget_models.dart';
import 'package:ai_opportunity_radar/core/models/today_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 7, 27, 18);

  RecentSignalModel signal(
    String id, {
    String sourceType = 'text',
    String content = '记录',
    String? energyLoad,
    String? friction,
    String? energyState,
    Map<String, dynamic> rawPayload = const {},
    DateTime? createdAt,
    String migrationStatus = 'native',
  }) {
    return RecentSignalModel(
      id: id,
      sourceType: sourceType,
      content: content,
      energyLoad: energyLoad,
      friction: friction,
      energyState: energyState,
      rawPayloadJson: rawPayload,
      createdAt: createdAt ?? now,
      migrationStatus: migrationStatus,
    );
  }

  test('精力综合当天所有真实 Signal，不依赖单条状态', () {
    final withCapacity = TodayStatusOverview.fromSignals(
      [
        signal('ease-1', energyState: 'ease'),
        signal('ease-2', energyState: 'ease'),
        signal('steady', energyState: 'steady'),
      ],
      now: now,
    );
    expect(withCapacity.energy, TodayEnergyStatus.capacity);

    final low = TodayStatusOverview.fromSignals(
      [
        signal('drain-1', energyState: 'draining'),
        signal('drain-2', energyState: 'draining'),
        signal('steady-2', energyState: 'steady'),
      ],
      now: now,
    );
    expect(low.energy, TodayEnergyStatus.low);
  });

  test('最新明确状态是高权重锚点，但不会覆盖相反的当天 Signal', () {
    final overview = TodayStatusOverview.fromSignals(
      [
        signal(
          'status-high',
          sourceType: 'one_tap',
          content: '现在精力很足',
          createdAt: now.subtract(const Duration(hours: 3)),
          rawPayload: const {'energy_level': 2},
        ),
        signal('drain-1', energyState: 'draining'),
        signal('drain-2', energyState: 'draining'),
        signal('drain-3', energyState: 'draining'),
      ],
      now: now,
    );

    expect(overview.energy, TodayEnergyStatus.mixed);
    expect(overview.load, TodayLoadStatus.attention);
  });

  test('单条间接线索不会给精力或负担下强结论', () {
    final overview = TodayStatusOverview.fromSignals(
      [signal('single-drain', energyState: 'draining')],
      now: now,
    );

    expect(overview.energy, TodayEnergyStatus.waiting);
    expect(overview.load, TodayLoadStatus.waiting);
    expect(overview.recovery, TodayRecoveryStatus.notSeen);
  });

  test('已发生安排参与综合判定，未来安排完全不参与', () {
    final overview = TodayStatusOverview.fromSignals(
      [
        signal(
          'completed',
          sourceType: 'time_use',
          rawPayload: {
            'record_status': 'completed',
            'energy_level': 0,
            'end_at':
                now.subtract(const Duration(minutes: 5)).toIso8601String(),
          },
        ),
        signal(
          'planned',
          sourceType: 'time_use',
          rawPayload: {
            'record_status': 'planned',
            'energy_level': 2,
            'end_at': now.add(const Duration(hours: 2)).toIso8601String(),
          },
        ),
        signal('steady', energyState: 'steady'),
      ],
      now: now,
    );

    expect(overview.eligibleSignalCount, 2);
    expect(overview.energy, TodayEnergyStatus.low);
  });

  test('负担与恢复独立计算，背景 friction 不会重复制造负担', () {
    final overview = TodayStatusOverview.fromSignals(
      [
        signal(
          'ease',
          energyState: 'ease',
          friction: 'self_pressure',
        ),
        signal(
          'recovery',
          energyState: 'recovery',
          friction: 'fatigue',
        ),
        signal(
          'boundary',
          energyState: 'boundary_buffer',
          friction: 'dense_schedule',
        ),
        signal(
          'steady-load',
          energyState: 'steady',
          friction: 'context_switch',
        ),
      ],
      now: now,
    );

    expect(overview.burdenSignalCount, 1);
    expect(overview.load, TodayLoadStatus.moderate);
    expect(overview.recoverySignalCount, 1);
    expect(overview.recovery, TodayRecoveryStatus.appearing);
    expect(overview.stateCounts[EnergySignalState.recovery], 1);
  });

  test('QA showcase 只从 Today 派生中排除', () {
    final overview = TodayStatusOverview.fromSignals(
      [
        signal(
          'qa_demo_signal_1',
          energyState: 'draining',
          friction: 'overload',
          rawPayload: const {'qa_showcase': true},
          migrationStatus: 'qa_showcase',
        ),
        signal(
          'real-status',
          sourceType: 'one_tap',
          rawPayload: const {'energy_level': 2},
        ),
      ],
      now: now,
    );

    expect(overview.eligibleSignalCount, 1);
    expect(overview.includedSignalIds, const ['real-status']);
    expect(overview.energy, TodayEnergyStatus.capacity);
    expect(overview.load, TodayLoadStatus.waiting);
  });

  test('同一组 Signal 的输入顺序不改变综合结果', () {
    final signals = [
      signal('a', energyState: 'ease'),
      signal('b', energyState: 'draining'),
      signal('c', energyState: 'steady'),
    ];
    final forward = TodayStatusOverview.fromSignals(signals, now: now);
    final reverse = TodayStatusOverview.fromSignals(signals.reversed, now: now);

    expect(reverse.energy, forward.energy);
    expect(reverse.load, forward.load);
    expect(reverse.recovery, forward.recovery);
    expect(reverse.stateCounts, forward.stateCounts);
  });
}
