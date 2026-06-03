import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ai_opportunity_radar/core/models/energy_budget_models.dart';
import 'package:ai_opportunity_radar/core/models/weekly_models.dart';
import 'package:ai_opportunity_radar/features/pages/me/me_view_model.dart';
import 'package:ai_opportunity_radar/features/pages/weekly/weekly_page.dart';
import 'package:ai_opportunity_radar/features/pages/weekly/weekly_view_model.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Weekly 页面能加载并触发一次数据获取', (tester) async {
    final repo = StubWeeklyRepository(
      weekly: WeeklyInsightModel(
        weekStart: '2026-04-15',
        weekEnd: '2026-04-21',
        status: 'ready',
        keyInsight:
            'Interruptions and recovery are both clearly visible this week.',
        patterns: const [
          {
            'name': 'Interruptions during focused work',
            'summary': 'This repeated across several entries.',
          },
        ],
        frictions: const [
          {
            'name': 'Meetings draining energy',
            'summary': 'Energy dropped most clearly around meetings.',
          },
        ],
        bestAction: 'Next week, track the first interruption of the day.',
        opportunitySnapshot: null,
        feedbackSubmitted: false,
        chartData: const [
          WeeklyChartPointModel(
            date: '2026-04-15',
            signalCount: 1,
            moodScore: -0.2,
            frictionScore: 0.6,
            hasPositiveSignal: false,
          ),
          WeeklyChartPointModel(
            date: '2026-04-16',
            signalCount: 3,
            moodScore: -0.6,
            frictionScore: 0.8,
            hasPositiveSignal: false,
          ),
          WeeklyChartPointModel(
            date: '2026-04-17',
            signalCount: 2,
            moodScore: 0.1,
            frictionScore: 0.3,
            hasPositiveSignal: true,
          ),
        ],
      ),
    );
    final energyRepo = StubEnergyBudgetRepository(
      budget: const EnergyBudgetModel(
        status: 'ready',
        mostDrainingSource:
            'This period, meetings may feel costly. This is not a score.',
        recoveryClue: 'A short walk looks like a recovery clue.',
        bufferLocation: 'Meeting-heavy mornings may need a little buffer.',
        switchingAdjustment:
            'You can leave a little room before the next context switch.',
        experimentConnection:
            'Keep the next Life Experiment optional and small.',
        blocks: [
          EnergyBlockModel(
            type: 'high_drain',
            label: 'high-drain block',
            summary: 'Meetings may be a bit costly.',
            count: 2,
            evidenceLevel: 'unconfirmed',
          ),
        ],
      ),
    );

    final meVm = await buildMeViewModel(repeatArea: 'work_tasks');

    await tester.pumpWidget(
      buildTestApp(
        child: const WeeklyPage(),
        providers: [
          ChangeNotifierProvider<WeeklyViewModel>(
            create: (_) => WeeklyViewModel(
              repo,
              energyBudgetRepository: energyRepo,
            ),
          ),
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(WeeklyPage), findsOneWidget);
    expect(find.text('Weekly'), findsWidgets);
    expect(find.text('Observation'), findsOneWidget);
    expect(find.text('Energy'), findsOneWidget);
    expect(find.text('Experiment'), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('weekly-page-view')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Energy Budget'),
      240,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Signal density and weekly trend'), findsOneWidget);
    expect(find.text('Energy Budget'), findsOneWidget);
    expect(find.text('Most costly source'), findsOneWidget);
    expect(find.text('Buffer point'), findsOneWidget);
    expect(
      find.textContaining('not a score or diagnosis'),
      findsOneWidget,
    );
    expect(repo.fetchCallCount, 1);
    expect(energyRepo.fetchCallCount, 1);
  });

  testWidgets('Weekly V3C 显示 one pattern / one experiment / inclusion 文案',
      (tester) async {
    final repo = StubWeeklyRepository(
      weekly: WeeklyInsightModel(
        weekStart: '2026-04-15',
        weekEnd: '2026-04-21',
        status: 'ready',
        keyInsight: '这周可以先这样看：安排过密让切换感更明显。',
        patterns: const [
          {
            'name': '安排过密',
            'summary': '几个记录都围绕安排太满展开。',
          },
        ],
        frictions: const [
          {
            'name': '频繁切换',
            'summary': '切换让一天变得更散。',
          },
        ],
        bestAction: '下周可以试试只保护一个不被打断的半小时。',
        opportunitySnapshot: const {
          'name': '散步后的恢复',
          'summary': '晚上散步之后状态有一点往回收。',
          '_weekly_inclusion': {
            'used_count': 3,
            'timeline_only_count': 2,
            'excluded_count': 2,
            'legacy_reference_count': 1,
          },
          '_life_experiment': {
            'id': 'exp_widget',
            'local_user_id': 'test-user',
            'source_week_start': '2026-04-15',
            'source_week_end': '2026-04-21',
            'title': '安排过密',
            'hypothesis': '如果先保护一个半小时，可能会省一点力。',
            'suggested_action': '下周可以试试只保护一个不被打断的半小时。',
            'linked_signal_card_ids': ['sig_1', 'sig_2', 'sig_3'],
            'status': 'suggested',
          },
        },
        feedbackSubmitted: false,
      ),
    );
    final energyRepo = StubEnergyBudgetRepository(
      budget: const EnergyBudgetModel(
        status: 'ready',
        mostDrainingSource: '这段时间最耗力的一个来源可能是“频繁切换”。这里可能有点耗力。',
        recoveryClue: '一个恢复线索是“散步后的恢复”。',
        bufferLocation: '可以先把“会议之间”看作需要 buffer 的位置。',
        switchingAdjustment: '可以先给这里留一点余地：只保护一个不被打断的半小时。',
        experimentConnection: '可以连接到最近的 Life Experiment。这个调整也可以只是试试看。',
        blocks: [
          EnergyBlockModel(
            type: 'high_switching',
            label: 'high-switching block',
            summary: '这里像是切换负担比较重的位置。',
            count: 3,
            evidenceLevel: 'unconfirmed',
          ),
        ],
      ),
    );

    final meVm = await buildMeViewModel(repeatArea: 'work_tasks');

    await tester.pumpWidget(
      buildTestApp(
        child: const WeeklyPage(),
        providers: [
          ChangeNotifierProvider<WeeklyViewModel>(
            create: (_) => WeeklyViewModel(
              repo,
              energyBudgetRepository: energyRepo,
            ),
          ),
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
      ),
    );

    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('How your notes were used'),
      240,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('How your notes were used'), findsOneWidget);
    expect(
      find.text(
        '3 notes were used for this Weekly. 2 stayed only in Timeline. 1 older notes were treated as gentle context.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('stay saved in your Timeline'),
      findsOneWidget,
    );
    await tester.drag(
      find.byKey(const ValueKey('weekly-page-view')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Energy Budget'),
      240,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Energy Budget'), findsOneWidget);
    expect(find.text('Most costly source'), findsOneWidget);
    expect(find.text('Small adjustment'), findsOneWidget);
    expect(
      find.textContaining('not used here'),
      findsOneWidget,
    );
    await tester.drag(
      find.byKey(const ValueKey('weekly-page-view')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('This week, you can look at it this way'), findsOneWidget);
    expect(find.text('One pattern'), findsOneWidget);
    expect(find.text('One small experiment'), findsOneWidget);
    expect(find.text('Recovery signal'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('A small experiment you can keep'),
      240,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('A small experiment you can keep'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
  });

  testWidgets('Weekly Energy Budget 数据不足时显示低压力 fallback', (tester) async {
    final repo = StubWeeklyRepository(
      weekly: WeeklyInsightModel(
        weekStart: '2026-04-15',
        weekEnd: '2026-04-21',
        status: 'light_ready',
        keyInsight: '这周先轻轻看。',
        patterns: const [],
        frictions: const [],
        bestAction: '下周可以试试给会议之间留十分钟。',
        opportunitySnapshot: null,
        feedbackSubmitted: false,
      ),
    );
    final energyRepo = StubEnergyBudgetRepository(
      budget: const EnergyBudgetModel(
        status: 'insufficient_data',
        mostDrainingSource: '现在还没有足够的内部信号来判断能量流向。',
        recoveryClue: '可以先记录哪里稍微省力。',
        bufferLocation: '暂时还没有明确需要 buffer 的位置。',
        switchingAdjustment: '这个调整也可以只是试试看。',
        experimentConnection: '还没有可连接的 Life Experiment。',
        blocks: [],
      ),
    );

    final meVm = await buildMeViewModel(repeatArea: 'work_tasks');

    await tester.pumpWidget(
      buildTestApp(
        child: const WeeklyPage(),
        providers: [
          ChangeNotifierProvider<WeeklyViewModel>(
            create: (_) => WeeklyViewModel(
              repo,
              energyBudgetRepository: energyRepo,
            ),
          ),
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
      ),
    );

    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('weekly-page-view')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Energy Budget'),
      240,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Energy Budget'), findsOneWidget);
    expect(
      find.textContaining('not a score or diagnosis'),
      findsWidgets,
    );
    expect(
      find.textContaining('not used here'),
      findsOneWidget,
    );
  });

  testWidgets('Weekly 第一天 gate 会显示对应空态', (tester) async {
    final repo = StubWeeklyRepository(
      weekly: WeeklyInsightModel(
        weekStart: '2026-04-15',
        weekEnd: '2026-04-21',
        status: 'first_day_gate',
        keyInsight: null,
        patterns: const [],
        frictions: const [],
        bestAction: null,
        opportunitySnapshot: null,
        feedbackSubmitted: false,
        chartData: const [],
      ),
    );

    final meVm = await buildMeViewModel();

    await tester.pumpWidget(
      buildTestApp(
        child: const WeeklyPage(),
        providers: [
          ChangeNotifierProvider<WeeklyViewModel>(
            create: (_) => WeeklyViewModel(repo),
          ),
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Weekly is forming'), findsOneWidget);
  });
}
