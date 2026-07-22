import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:ai_opportunity_radar/app/app_router.dart';
import 'package:ai_opportunity_radar/core/api/repositories/weekly_repository.dart';
import 'package:ai_opportunity_radar/core/di/app_dependencies.dart';
import 'package:ai_opportunity_radar/core/i18n/app_locale_text.dart';
import 'package:ai_opportunity_radar/core/local/local_candidate_planning_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_capture_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/local/local_life_experiment_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_weekly_snapshot_repository.dart';
import 'package:ai_opportunity_radar/core/models/candidate_models.dart';
import 'package:ai_opportunity_radar/core/models/energy_budget_models.dart';
import 'package:ai_opportunity_radar/core/models/phase3_plus_models.dart';
import 'package:ai_opportunity_radar/core/models/weekly_models.dart';
import 'package:ai_opportunity_radar/features/pages/me/me_view_model.dart';
import 'package:ai_opportunity_radar/features/pages/weekly/deep_weekly_page.dart';
import 'package:ai_opportunity_radar/features/pages/weekly/weekly_page.dart';
import 'package:ai_opportunity_radar/features/pages/weekly/weekly_view_model.dart';
import 'package:ai_opportunity_radar/shared/widgets/aurora_ui.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Weekly 页面能加载并触发一次数据获取', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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
        opportunitySnapshot: const {
          '_weekly_inclusion': {
            'used_count': 3,
            'timeline_only_count': 0,
            'excluded_count': 0,
            'legacy_reference_count': 0,
          },
        },
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
    final scrollView = tester.widget<ListView>(
      find.byKey(const ValueKey('weekly-scroll-view')),
    );
    expect(
      scrollView.padding,
      const EdgeInsets.fromLTRB(18, 14, 18, 96),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('weekly-hero-header'))).height,
      lessThanOrEqualTo(170),
    );
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(const ValueKey('weekly-hero-title')),
              matching: find.byType(Text),
            ),
          )
          .style
          ?.fontSize,
      36,
    );
    final weeklyHero = find.byKey(const ValueKey('weekly-hero-header'));
    expect(
      find.descendant(
        of: weeklyHero,
        matching: find.byKey(const ValueKey('weekly-hero-review-pattern')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: weeklyHero,
        matching: find.byType(AuroraReviewHeroPattern),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: weeklyHero,
        matching: find.byType(AuroraHeroEmblem),
      ),
      findsNothing,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('weekly-ai-quote-badge'))),
      const Size(40, 40),
    );
    final quoteCard = tester.widget<Container>(
      find.byKey(const ValueKey('weekly-ai-quote-card')),
    );
    expect(quoteCard.padding, const EdgeInsets.fromLTRB(14, 13, 14, 13));
    expect(
      (quoteCard.decoration! as BoxDecoration).borderRadius,
      BorderRadius.circular(20),
    );
    final report = find.byKey(const ValueKey('weekly-review-report-card'));
    expect(report, findsOneWidget);
    expect(
      tester.widget<Container>(report).padding,
      const EdgeInsets.fromLTRB(16, 14, 16, 16),
    );
    expect(
      (tester.widget<Container>(report).decoration! as BoxDecoration)
          .borderRadius,
      BorderRadius.circular(20),
    );
    expect(
      tester
          .widget<Text>(find.text('This week’s review report'))
          .style
          ?.fontSize,
      17,
    );
    for (final key in const [
      'weekly-signal-distribution-card',
      'weekly-behavior-pattern-card',
      'weekly-action-review-card',
    ]) {
      expect(
        find.descendant(
          of: report,
          matching: find.byKey(ValueKey(key)),
        ),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(
        of: report,
        matching: find.textContaining('evidence'),
      ),
      findsNothing,
    );
    expect(find.text('Weekly Review'), findsOneWidget);
    expect(find.text('Signal facts'), findsOneWidget);
    expect(find.text('Behavior patterns'), findsOneWidget);
    expect(find.text('Attempt results'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Next week’s tries'),
      find.byType(ListView).first,
      const Offset(0, -280),
    );
    expect(find.text('Next week’s tries'), findsOneWidget);
    expect(find.text('This week’s energy state'), findsNothing);
    expect(find.text('Signals changed'), findsOneWidget);
    expect(repo.fetchCallCount, 1);
    expect(energyRepo.fetchCallCount, 1);
  });

  testWidgets('查看本周 Signal 打开手帐时间线并定位到本周最后一个有记录的日期', (tester) async {
    final repo = StubWeeklyRepository(
      weekly: WeeklyInsightModel(
        weekStart: '2026-04-13',
        weekEnd: '2026-04-19',
        status: 'ready',
        keyInsight: 'This week has a repeated pattern.',
        patterns: const [],
        frictions: const [],
        bestAction: 'Keep the next try small.',
        opportunitySnapshot: const {
          '_report_readiness': {
            'signal_count': 4,
            'distinct_day_count': 3,
            'eligible': true,
          },
        },
        feedbackSubmitted: false,
        chartData: const [
          WeeklyChartPointModel(
            date: '2026-04-14',
            signalCount: 1,
            moodScore: 0,
            frictionScore: 0,
            hasPositiveSignal: false,
          ),
          WeeklyChartPointModel(
            date: '2026-04-17',
            signalCount: 3,
            moodScore: 0,
            frictionScore: 0,
            hasPositiveSignal: true,
          ),
          WeeklyChartPointModel(
            date: '2026-04-19',
            signalCount: 0,
            moodScore: 0,
            frictionScore: 0,
            hasPositiveSignal: false,
          ),
        ],
      ),
    );
    final energyRepo = StubEnergyBudgetRepository(
      budget: const EnergyBudgetModel(
        status: 'ready',
        mostDrainingSource: '',
        recoveryClue: '',
        bufferLocation: '',
        switchingAdjustment: '',
        experimentConnection: '',
        blocks: [],
      ),
    );
    final meVm = await buildMeViewModel(repeatArea: 'work_tasks');
    final router = GoRouter(
      initialLocation: AppRoutes.weekly,
      routes: [
        GoRoute(
          path: AppRoutes.weekly,
          builder: (_, __) => const WeeklyPage(),
        ),
        GoRoute(
          path: AppRoutes.todayDiary,
          builder: (_, state) => Scaffold(
            body: Text(
              'timeline:${state.uri.queryParameters['date']}',
              textDirection: TextDirection.ltr,
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WeeklyViewModel>(
            create: (_) => WeeklyViewModel(
              repo,
              energyBudgetRepository: energyRepo,
            ),
          ),
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final openTimeline =
        find.byKey(const ValueKey('weekly-open-signal-timeline'));
    expect(openTimeline, findsOneWidget);
    await tester.ensureVisible(openTimeline);
    await tester.tap(openTimeline);
    await tester.pumpAndSettle();

    expect(find.text('timeline:2026-04-17'), findsOneWidget);
  });

  testWidgets('Weekly V3C 显示 one pattern / one goal / inclusion 文案',
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
        },
        feedbackSubmitted: false,
      ),
      experimentCandidate: const LifeExperimentModel(
        id: 'cand_widget',
        localUserId: 'test-user',
        sourceWeekStart: '2026-04-15',
        sourceWeekEnd: '2026-04-21',
        title: '候选：保护半小时',
        hypothesis: '如果先保护一个半小时，可能会省一点力。',
        suggestedAction: '下周可以试试只保护一个不被打断的半小时。',
        linkedSignalCardIds: ['sig_1', 'sig_2', 'sig_3'],
        status: 'suggested',
      ),
      currentWeekExperiment: const LifeExperimentModel(
        id: 'exp_current_widget',
        localUserId: 'test-user',
        sourceWeekStart: '2026-04-15',
        sourceWeekEnd: '2026-04-21',
        title: '本周正式实验',
        hypothesis: '本周已经在执行。',
        suggestedAction: '本周继续保护恢复窗口。',
        linkedSignalCardIds: ['sig_previous'],
        status: 'active',
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

    expect(find.text('Weekly Review'), findsOneWidget);
    expect(find.text('This week’s review report'), findsOneWidget);
    expect(find.text('Signal facts'), findsOneWidget);
    expect(find.text('Behavior patterns'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Attempt results'),
      find.byType(ListView),
      const Offset(0, -360),
    );
    expect(find.text('Attempt results'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('weekly-attempt-fact-summary')),
      findsOneWidget,
    );
    await tester.dragUntilVisible(
      find.text('本周正式实验'),
      find.byType(ListView).first,
      const Offset(0, -180),
    );
    expect(find.text('本周正式实验'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Next week’s tries'),
      find.byType(ListView).first,
      const Offset(0, -240),
    );
    expect(find.text('Next week’s tries'), findsOneWidget);
    expect(find.text('候选：保护半小时'), findsOneWidget);
    expect(find.text('Choose next week’s tries'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('weekly-experiment-feedback-happened')),
      findsNothing,
    );
    expect(find.text('Change'), findsNothing);
  });

  testWidgets('Weekly 已采纳的下周实验只显示查看入口，不提前登记反馈', (tester) async {
    final repo = StubWeeklyRepository(
      weekly: WeeklyInsightModel(
        weekStart: '2026-07-06',
        weekEnd: '2026-07-12',
        status: 'ready',
        keyInsight: '本周恢复信号已经开始聚合。',
        patterns: const [],
        frictions: const [],
        bestAction: '下周先保留一次十分钟散步。',
        opportunitySnapshot: const {
          '_weekly_inclusion': {
            'used_count': 3,
            'timeline_only_count': 0,
            'excluded_count': 0,
            'legacy_reference_count': 0,
          },
        },
        feedbackSubmitted: false,
      ),
      experimentCandidate: const LifeExperimentModel(
        id: 'exp_weekly_feedback',
        localUserId: 'test-user',
        sourceWeekStart: '2026-07-13',
        sourceWeekEnd: '2026-07-19',
        title: '十分钟散步',
        hypothesis: '短散步可能帮助恢复。',
        suggestedAction: '下周选一天散步十分钟。',
        linkedSignalCardIds: ['sig_1', 'sig_2', 'sig_3'],
        status: 'active',
      ),
    );
    final vm = WeeklyViewModel(repo);
    final meVm = await buildMeViewModel();

    await tester.pumpWidget(
      buildTestApp(
        child: const WeeklyPage(),
        providers: [
          ChangeNotifierProvider<WeeklyViewModel>.value(value: vm),
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Next week’s tries'),
      find.byType(ListView).first,
      const Offset(0, -420),
    );

    expect(find.text('View selected tries'), findsOneWidget);
    expect(vm.nextWeekExperiment?.id, 'exp_weekly_feedback');
    expect(
      find.byKey(const ValueKey('weekly-experiment-feedback-happened')),
      findsNothing,
    );
    expect(find.text('Happened'), findsNothing);
    expect(find.text('Not today'), findsNothing);
    expect(find.text('Helpful'), findsNothing);
    vm.dispose();
  });

  testWidgets('Deep Analysis smoke: 顶部显示真实周范围而不是装饰进度', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final weeklyRepo = StubWeeklyRepository(
      weekly: WeeklyInsightModel(
        weekStart: '2026-07-01',
        weekEnd: '2026-07-07',
        status: 'ready',
        keyInsight: 'Energy changed with meeting density.',
        patterns: const [],
        frictions: const [],
        bestAction: 'Keep the next experiment light.',
        opportunitySnapshot: const {
          '_weekly_inclusion': {
            'used_count': 3,
            'timeline_only_count': 0,
            'excluded_count': 0,
            'legacy_reference_count': 0,
          },
        },
        feedbackSubmitted: false,
        chartData: const [
          WeeklyChartPointModel(
            date: '2026-07-01',
            signalCount: 3,
            moodScore: 0,
            frictionScore: 0.4,
            hasPositiveSignal: false,
          ),
        ],
      ),
    );
    final energyRepo = StubEnergyBudgetRepository(
      budget: const EnergyBudgetModel(
        status: 'ready',
        mostDrainingSource: '会议后的切换最耗力。',
        recoveryClue: '散步是恢复线索。',
        bufferLocation: '下午需要留白。',
        switchingAdjustment: '连续任务之间需要缓冲。',
        experimentConnection: '下周尝试保持轻量。',
        energyStateCounts: {
          'draining': 3,
          'steady': 3,
          'ease': 0,
          'recovery': 0,
          'boundary_buffer': 0,
        },
        blocks: [
          EnergyBlockModel(
            type: 'high_drain',
            label: 'high-drain block',
            summary: '会议较耗力。',
            count: 3,
            evidenceLevel: 'supported',
          ),
          EnergyBlockModel(
            type: 'high_switching',
            label: 'high-switching block',
            summary: '切换较多。',
            count: 2,
            evidenceLevel: 'supported',
          ),
          EnergyBlockModel(
            type: 'deep',
            label: 'deep block',
            summary: '需要完整注意力。',
            count: 1,
            evidenceLevel: 'supported',
          ),
          EnergyBlockModel(
            type: 'recovery',
            label: 'recovery block',
            summary: '散步带来恢复。',
            count: 2,
            evidenceLevel: 'supported',
          ),
          EnergyBlockModel(
            type: 'boundary',
            label: 'boundary block',
            summary: '需要边界。',
            count: 1,
            evidenceLevel: 'supported',
          ),
          EnergyBlockModel(
            type: 'buffer',
            label: 'buffer block',
            summary: '需要余地。',
            count: 1,
            evidenceLevel: 'supported',
          ),
        ],
      ),
    );
    final deps = await buildTestDependencies(
      todayRepository: StubTodayRepository(
        fetchTodayResult: const <String, dynamic>{},
      ),
      weeklyRepository: weeklyRepo,
      energyBudgetRepository: energyRepo,
    );

    await tester.pumpWidget(
      buildTestApp(
        child: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: WeeklyReflectPage(),
        ),
        providers: [
          Provider<AppDependencies>.value(value: deps),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(WeeklyReflectPage), findsOneWidget);
    expect(
      find.byKey(const ValueKey('weekly-reflect-hero')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('weekly-reflect-review-pattern')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('weekly-reflect-hero')),
        matching: find.byType(AuroraReviewHeroPattern),
      ),
      findsOneWidget,
    );
    expect(find.byType(AuroraHeroEmblem), findsNothing);
    expect(
      tester.getSize(find.byKey(const ValueKey('weekly-reflect-back'))).width,
      greaterThanOrEqualTo(44),
    );
    final reflectScroll = tester.widget<ListView>(
      find.byKey(const ValueKey('weekly-reflect-scroll-view')),
    );
    expect(
      reflectScroll.padding,
      const EdgeInsets.fromLTRB(18, 14, 18, 96),
    );
    expect(find.text('This Week’s Deep Analysis'), findsOneWidget);
    expect(find.text('7/1–7/7'), findsOneWidget);
    expect(find.text('3 Signals · 1 days'), findsOneWidget);
    expect(find.text('3/4'), findsNothing);
    expect(find.textContaining('Weekly Reflect keeps'), findsOneWidget);
    expect(energyRepo.fetchCallCount, 0);
  });

  testWidgets('深度分析在 390x844 与 1.3x 下显示关系、七日位置、验证与分析范围', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final weeklyRepo = StubWeeklyRepository(
      weekly: WeeklyInsightModel(
        weekStart: '2026-07-13',
        weekEnd: '2026-07-19',
        status: 'ready',
        keyInsight: '本周的信号已经开始聚合。',
        patterns: const [
          {
            'name': '任务堆积',
            'summary': '任务一多，开始就变困难。',
            'illustration_hint': '任务堆积，开始变困难',
          },
        ],
        frictions: const [
          {
            'name': '安排打断',
            'summary': '临时安排会切断原来的节奏。',
          },
        ],
        bestAction: '下周先保留一个轻量尝试。',
        opportunitySnapshot: const {
          '_weekly_inclusion': {
            'used_count': 6,
            'timeline_only_count': 0,
            'excluded_count': 0,
            'legacy_reference_count': 0,
          },
          '_report_readiness': {
            'signal_count': 6,
            'distinct_day_count': 4,
            'distinct_week_count': 1,
          },
          '_feedback_event_summary': {
            'events': [
              {
                'subject_type': 'micro_action',
                'source_type': 'micro_action_feedback',
                'status': 'completed',
                'created_at': '2026-07-17T09:00:00+09:00',
                'metadata': {
                  'feedback_pattern_id': 'review.interrupted_by_schedule',
                },
              },
            ],
          },
        },
        feedbackSubmitted: false,
        behaviorPatterns: const [
          WeeklyBehaviorPatternModel(
            id: 'deep-pattern-switching',
            label: '切换后较难回到原来的节奏',
            summary: '即时消息后重新开始重要任务的记录同时出现。',
            kind: 'context_response',
            sourceSignalCardIds: ['signal-1'],
            supportDates: ['2026-07-13'],
          ),
        ],
        chartData: const [
          WeeklyChartPointModel(
            date: '2026-07-13',
            signalCount: 1,
            moodScore: 0,
            frictionScore: 0.4,
            hasPositiveSignal: false,
          ),
          WeeklyChartPointModel(
            date: '2026-07-14',
            signalCount: 0,
            moodScore: 0,
            frictionScore: 0,
            hasPositiveSignal: false,
          ),
          WeeklyChartPointModel(
            date: '2026-07-15',
            signalCount: 2,
            moodScore: -0.2,
            frictionScore: 0.6,
            hasPositiveSignal: false,
          ),
          WeeklyChartPointModel(
            date: '2026-07-16',
            signalCount: 0,
            moodScore: 0,
            frictionScore: 0,
            hasPositiveSignal: false,
          ),
          WeeklyChartPointModel(
            date: '2026-07-17',
            signalCount: 1,
            moodScore: 0,
            frictionScore: 0.3,
            hasPositiveSignal: false,
          ),
          WeeklyChartPointModel(
            date: '2026-07-18',
            signalCount: 2,
            moodScore: 0.2,
            frictionScore: 0.2,
            hasPositiveSignal: true,
          ),
          WeeklyChartPointModel(
            date: '2026-07-19',
            signalCount: 0,
            moodScore: 0,
            frictionScore: 0,
            hasPositiveSignal: false,
          ),
        ],
      ),
      weeklyReflect: const WeeklyReflectModel(
        summary: '这周已经有足够线索，可以先看它的重复方式。L3 Reflect 只补充关系，不重复每周复盘。',
        rootTension: '表层事件是几条不同记录；底层 tension 是不断重启判断和重新找回节奏。',
        hiddenPattern: '把图和文字放在一起看，线索更密的节点和状态低点互相牵引。',
        nextFocus: '下周先不要扩大观察面，只盯一个小问题：摩擦出现在哪个阶段。',
        riskNote: '这份 Pro L3 只用来收窄观察面。',
        keyNodes: ['重复主题：任务堆积', '主要摩擦：安排打断'],
        patternLabel: '任务堆积',
        frictionLabel: '安排打断',
        impactLabel: '本周 2 个完成日',
        relationshipSummary: '任务堆积与安排打断在同一周反复共同出现。',
        timingSummary: '周三和周六的 Signal 更密，周六开始有一点回收。',
        nextQuestion: '安排再次出现时，任务是在开始、推进还是收尾阶段？',
        illustrationHint: '任务堆积，开始变困难',
        sourceSignalCardIds: ['signal-1', 'signal-2'],
        scopeNote: '只说明本周共同出现的关系，不代表因果或长期结论。',
      ),
    );
    final energyRepo = StubEnergyBudgetRepository(
      budget: const EnergyBudgetModel(
        status: 'ready',
        mostDrainingSource: '会议后的切换最耗力。',
        recoveryClue: '散步是恢复线索。',
        bufferLocation: '下午需要留白。',
        switchingAdjustment: '连续任务之间需要缓冲。',
        experimentConnection: '下周尝试保持轻量。',
        energyStateCounts: {
          'draining': 3,
          'steady': 3,
          'ease': 0,
          'recovery': 0,
          'boundary_buffer': 0,
        },
        blocks: [
          EnergyBlockModel(
            type: 'high_drain',
            label: 'high-drain block',
            summary: '会议较耗力。',
            count: 3,
            evidenceLevel: 'supported',
          ),
          EnergyBlockModel(
            type: 'high_switching',
            label: 'high-switching block',
            summary: '切换较多。',
            count: 2,
            evidenceLevel: 'supported',
          ),
          EnergyBlockModel(
            type: 'deep',
            label: 'deep block',
            summary: '需要完整注意力。',
            count: 1,
            evidenceLevel: 'supported',
          ),
          EnergyBlockModel(
            type: 'recovery',
            label: 'recovery block',
            summary: '散步带来恢复。',
            count: 2,
            evidenceLevel: 'supported',
          ),
          EnergyBlockModel(
            type: 'boundary',
            label: 'boundary block',
            summary: '需要边界。',
            count: 1,
            evidenceLevel: 'supported',
          ),
          EnergyBlockModel(
            type: 'buffer',
            label: 'buffer block',
            summary: '需要余地。',
            count: 1,
            evidenceLevel: 'supported',
          ),
        ],
      ),
    );
    final deps = await buildTestDependencies(
      todayRepository: StubTodayRepository(
        fetchTodayResult: const <String, dynamic>{},
      ),
      weeklyRepository: weeklyRepo,
      energyBudgetRepository: energyRepo,
    );

    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        child: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: WeeklyReflectPage(),
        ),
        providers: [Provider<AppDependencies>.value(value: deps)],
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('L3 Reflect'), findsNothing);
    expect(find.textContaining('Pro L3'), findsNothing);
    expect(find.textContaining('tension'), findsNothing);
    expect(find.textContaining('深度分析'), findsWidgets);

    final summary = tester.widget<Text>(
      find.byKey(const ValueKey('weekly-reflect-summary')),
    );
    expect(summary.maxLines, 4);
    expect(summary.overflow, TextOverflow.ellipsis);
    expect(summary.style?.fontSize, 16);
    expect(summary.style?.fontWeight, FontWeight.w600);
    expect(summary.style?.height, 1.5);
    expect(
      find.byKey(const ValueKey('weekly-reflect-pattern-illustration')),
      findsOneWidget,
    );
    expect(find.text('3/4'), findsNothing);
    expect(find.text('本周能量状态'), findsNothing);
    expect(find.text('Signal 聚集'), findsNothing);
    expect(energyRepo.fetchCallCount, 0);

    final scrollable = find.byKey(
      const ValueKey('weekly-reflect-scroll-view'),
    );
    await tester.dragUntilVisible(
      find.text('本周关系图'),
      scrollable,
      const Offset(0, -280),
    );
    await tester.pumpAndSettle();

    for (var index = 0; index < 3; index++) {
      final tile = find.byKey(
        ValueKey('weekly-reflect-relationship-$index'),
      );
      expect(tile, findsOneWidget);
      expect(tester.getSize(tile).width, greaterThan(290));
    }
    final semantics = tester.ensureSemantics();
    expect(
      tester
          .getSemantics(
            find.byKey(const ValueKey('weekly-reflect-relationship-0')),
          )
          .flagsCollection
          .isButton,
      isTrue,
    );
    semantics.dispose();

    await tester.dragUntilVisible(
      find.text('本周出现位置'),
      scrollable,
      const Offset(0, -280),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('weekly-deep-timing-chart')),
      findsOneWidget,
    );
    for (final date in const [
      '2026-07-13',
      '2026-07-14',
      '2026-07-15',
      '2026-07-16',
      '2026-07-17',
      '2026-07-18',
      '2026-07-19',
    ]) {
      expect(
        find.byKey(ValueKey('weekly-deep-signal-bar-$date')),
        findsOneWidget,
      );
    }
    final energySemantics = tester.ensureSemantics();
    expect(
      tester
          .getSemantics(
            find.bySemanticsLabel(RegExp(r'^7/13：1 条 Signal，'),
                skipOffstage: false),
          )
          .flagsCollection
          .isButton,
      isTrue,
    );
    energySemantics.dispose();

    await tester.dragUntilVisible(
      find.text('本周能量状态'),
      scrollable,
      const Offset(0, -280),
    );
    await tester.pumpAndSettle();
    expect(find.text('本周能量状态'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('提案下周深化观察的问题'),
      scrollable,
      const Offset(0, -280),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('weekly-deep-review-illustration')),
      findsOneWidget,
    );
    for (final label in const [
      '想区分什么可能性',
      '下周应该观察哪些 Signal',
      '什么现象支持不同解释',
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.dragUntilVisible(
      find.text('分析范围'),
      scrollable,
      const Offset(0, -280),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('weekly-analysis-scope-card')),
      findsOneWidget,
    );
    expect(find.text('能说明：'), findsOneWidget);
    expect(find.text('不能说明：'), findsOneWidget);
    expect(find.text('温和使用'), findsNothing);
    expect(find.textContaining('32%'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('英文深度分析将旧 L3 Reflect 术语显示为 Deep Analysis', (tester) async {
    final weeklyRepo = StubWeeklyRepository(
      weekly: WeeklyInsightModel(
        weekStart: '2026-07-13',
        weekEnd: '2026-07-19',
        status: 'ready',
        keyInsight: 'Signals are starting to form a weekly pattern.',
        patterns: const [],
        frictions: const [],
        bestAction: 'Keep the next experiment light.',
        opportunitySnapshot: const {
          '_weekly_inclusion': {
            'used_count': 3,
            'timeline_only_count': 0,
            'excluded_count': 0,
            'legacy_reference_count': 0,
          },
        },
        feedbackSubmitted: false,
        chartData: const [
          WeeklyChartPointModel(
            date: '2026-07-15',
            signalCount: 3,
            moodScore: 0,
            frictionScore: 0.4,
            hasPositiveSignal: false,
          ),
        ],
      ),
      weeklyReflect: const WeeklyReflectModel(
        summary: 'L3 Reflect keeps the deeper read tied to this week.',
        rootTension: 'Energy dropped when meetings compressed recovery.',
        hiddenPattern: 'Small recovery actions worked better than plans.',
        nextFocus: 'Keep the next experiment light and observable.',
        riskNote: 'Use ProL3 as a hypothesis, not a judgement.',
      ),
    );
    final deps = await buildTestDependencies(
      todayRepository: StubTodayRepository(
        fetchTodayResult: const <String, dynamic>{},
      ),
      weeklyRepository: weeklyRepo,
    );

    await tester.pumpWidget(
      buildTestApp(
        child: const WeeklyReflectPage(),
        providers: [Provider<AppDependencies>.value(value: deps)],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('L3 Reflect'), findsNothing);
    expect(find.textContaining('ProL3'), findsNothing);
    expect(find.textContaining('Deep Analysis'), findsWidgets);
  });

  testWidgets('Weekly Reflect 未达 3 条时显示报告进度而不生成 L3 内容', (tester) async {
    final weeklyRepo = StubWeeklyRepository(
      weekly: WeeklyInsightModel(
        weekStart: '2026-07-06',
        weekEnd: '2026-07-12',
        status: 'insufficient_data',
        keyInsight: null,
        patterns: const [],
        frictions: const [],
        bestAction: null,
        opportunitySnapshot: const {
          '_weekly_inclusion': {
            'used_count': 2,
            'timeline_only_count': 0,
            'excluded_count': 0,
            'legacy_reference_count': 0,
          },
          '_report_readiness': {
            'signal_count': 2,
            'distinct_day_count': 1,
            'distinct_week_count': 1,
          },
        },
        feedbackSubmitted: false,
      ),
    );
    final deps = await buildTestDependencies(
      todayRepository: StubTodayRepository(
        fetchTodayResult: const <String, dynamic>{},
      ),
      weeklyRepository: weeklyRepo,
    );

    await tester.pumpWidget(
      buildTestApp(
        child: const WeeklyReflectPage(),
        providers: [Provider<AppDependencies>.value(value: deps)],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('weekly-reflect-readiness-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('weekly-reflect-hero')),
      findsOneWidget,
    );
    expect(find.textContaining('2 / 3 eligible signals'), findsOneWidget);
    expect(find.text('This week’s core insight'), findsNothing);
  });

  testWidgets('WeeklyViewModel 分离本周正式实验与下周候选，不主读 legacy 内嵌实验', (tester) async {
    final repo = StubWeeklyRepository(
      weekly: WeeklyInsightModel(
        weekStart: '2026-04-15',
        weekEnd: '2026-04-21',
        status: 'ready',
        keyInsight: '这周先保留候选实验。',
        patterns: const [],
        frictions: const [],
        bestAction: '先试一个很轻的动作。',
        opportunitySnapshot: const {
          '_weekly_inclusion': {
            'used_count': 3,
            'timeline_only_count': 0,
            'excluded_count': 0,
            'legacy_reference_count': 0,
          },
          '_life_experiment': {
            'id': 'legacy_embedded_exp',
            'title': '旧内嵌实验',
            'hypothesis': '旧路径',
            'suggested_action': '旧建议',
            'status': 'suggested',
            'source_week_start': '2026-04-15',
            'source_week_end': '2026-04-21',
            'linked_signal_card_ids': [],
          },
        },
        feedbackSubmitted: false,
      ),
      experimentCandidate: const LifeExperimentModel(
        id: 'cand_view_model',
        localUserId: 'test-user',
        sourceWeekStart: '2026-04-15',
        sourceWeekEnd: '2026-04-21',
        title: '候选实验优先',
        hypothesis: '候选应覆盖旧内嵌实验。',
        suggestedAction: '先做候选里的轻动作。',
        linkedSignalCardIds: ['sig_1'],
        status: 'suggested',
      ),
    );

    final vm = WeeklyViewModel(repo);
    await tester.pump();
    await tester.pump();

    expect(vm.weeklyInsight?.lifeExperiment?.id, 'legacy_embedded_exp');
    expect(vm.currentWeekExperiment, isNull);
    expect(vm.nextWeekExperiment?.id, 'cand_view_model');
    vm.dispose();
  });

  testWidgets('Weekly 两条信号时隐藏旧候选并显示三条后形成提示', (tester) async {
    final repo = StubWeeklyRepository(
      weekly: WeeklyInsightModel(
        weekStart: '2026-07-06',
        weekEnd: '2026-07-12',
        status: 'light_ready',
        keyInsight: '线索刚开始聚起来。',
        patterns: const [],
        frictions: const [],
        bestAction: '先继续记录。',
        opportunitySnapshot: const {
          '_weekly_inclusion': {
            'used_count': 2,
            'timeline_only_count': 0,
            'excluded_count': 0,
            'legacy_reference_count': 0,
          },
        },
        feedbackSubmitted: false,
      ),
      experimentCandidate: const LifeExperimentModel(
        id: 'cand_legacy_before_threshold',
        localUserId: 'test-user',
        sourceWeekStart: '2026-07-06',
        sourceWeekEnd: '2026-07-12',
        title: '旧版本提前生成的候选',
        hypothesis: '不应提前显示。',
        suggestedAction: '先不要显示。',
        linkedSignalCardIds: ['sig_1', 'sig_2'],
        status: 'suggested',
      ),
    );
    final vm = WeeklyViewModel(repo);
    final meVm = await buildMeViewModel();

    await tester.pumpWidget(
      buildTestApp(
        child: const WeeklyPage(),
        providers: [
          ChangeNotifierProvider<WeeklyViewModel>.value(value: vm),
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.byKey(const ValueKey('weekly-next-experiment-forming')),
      find.byType(ListView).first,
      const Offset(0, -420),
    );
    expect(vm.nextWeekExperiment, isNull);
    expect(find.text('旧版本提前生成的候选'), findsNothing);
    expect(
      find.byKey(const ValueKey('weekly-next-experiment-forming')),
      findsOneWidget,
    );
    expect(
        find.textContaining('After 3 eligible life signals'), findsOneWidget);
    vm.dispose();
  });

  testWidgets('Weekly 展示复数采纳对象各自的真实七日进度与来源变化提示', (tester) async {
    final planner = _StubCandidatePlanningRepository(
      snapshot: _candidateSnapshot(
        status: CandidateGenerationStatus.ready,
        candidateCount: 2,
      ),
      activeMicroActions: [
        AdoptedMicroActionProgress(
          action: const MicroActionModel(
            id: 'action_one',
            judgementId: 'judgement_one',
            title: 'Protect a ten-minute pause',
            reason: 'Recovery appeared after short pauses.',
            status: 'active',
            sourceChanged: true,
            sourceChangeReason: 'linked signal was removed',
          ),
          progress: _progress('action_one', 2),
        ),
      ],
      activeExperiments: [
        AdoptedLifeExperimentProgress(
          experiment: _activeExperiment(
            id: 'experiment_one',
            title: 'Morning buffer',
          ),
          progress: _progress('experiment_one', 1),
        ),
        AdoptedLifeExperimentProgress(
          experiment: _activeExperiment(
            id: 'experiment_two',
            title: 'Single-task recovery',
          ),
          progress: _progress('experiment_two', 3),
        ),
      ],
    );
    final vm = WeeklyViewModel(
      StubWeeklyRepository(weekly: _readyWeeklyInsight()),
      candidatePlanningRepository: planner,
    );
    addTearDown(vm.dispose);
    addTearDown(planner.dispose);

    await tester.pumpWidget(
      buildTestApp(
        child: const WeeklyPage(),
        providers: [
          ChangeNotifierProvider<WeeklyViewModel>.value(value: vm),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Protect a ten-minute pause'),
      find.byKey(const ValueKey('weekly-scroll-view')),
      const Offset(0, -320),
    );
    expect(find.text('Protect a ten-minute pause'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('weekly-attempt-row-action_one')),
      findsOneWidget,
    );
    expect(find.textContaining('source Signal changed'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('Single-task recovery'),
      find.byKey(const ValueKey('weekly-scroll-view')),
      const Offset(0, -220),
    );
    expect(find.text('Morning buffer'), findsOneWidget);
    expect(find.text('Single-task recovery'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('weekly-attempt-row-experiment_one')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('weekly-attempt-row-experiment_two')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('weekly-goal-summary-experiment_one')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('weekly-goal-summary-experiment_two')),
      findsOneWidget,
    );
    expect(find.text('3 attempts'), findsOneWidget);
    expect(find.text('3 recorded days'), findsOneWidget);
    expect(find.text('6 completions'), findsOneWidget);

    final weeklySummaryButton =
        find.byKey(const ValueKey('weekly-goal-summary-experiment_one'));
    await Scrollable.ensureVisible(
      tester.element(weeklySummaryButton),
      alignment: 0.45,
    );
    await tester.pumpAndSettle();
    await tester.tap(weeklySummaryButton);
    await tester.pumpAndSettle();
    expect(find.text('Weekly goal summary'), findsOneWidget);
    expect(find.text('Too early to tell'), findsOneWidget);
    expect(find.text('Improved'), findsNothing);
    expect(find.text('A little'), findsNothing);
    expect(find.text('No change'), findsNothing);
    expect(find.text('Worse'), findsNothing);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('2 candidates ready'),
      find.byKey(const ValueKey('weekly-scroll-view')),
      const Offset(0, -260),
    );
    expect(find.text('2 candidates ready'), findsOneWidget);
    expect(find.text('Candidate 1'), findsOneWidget);
  });

  testWidgets('本周尝试只有今天格子可登记，过去与未来格子保持只读', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repository = _InteractiveWeeklyRepository(
      weekly: _readyWeeklyInsight(),
      currentDay: DateTime(2026, 7, 16, 11, 30),
    );
    final planner = _StubCandidatePlanningRepository(
      snapshot: _candidateSnapshot(
        status: CandidateGenerationStatus.ready,
        candidateCount: 1,
      ),
      activeMicroActions: [
        AdoptedMicroActionProgress(
          action: const MicroActionModel(
            id: 'action_interactive',
            judgementId: 'judgement_interactive',
            title: 'Leave a two-minute buffer',
            reason: 'Short buffers appeared alongside steadier recovery.',
            status: 'active',
            progressStartDate: '2026-07-13',
            progressEndDate: '2026-07-19',
          ),
          progress: _progress('action_interactive', 0),
        ),
      ],
    );
    final vm = WeeklyViewModel(
      repository,
      candidatePlanningRepository: planner,
    );
    addTearDown(vm.dispose);
    addTearDown(planner.dispose);

    await tester.pumpWidget(
      buildTestApp(
        child: const WeeklyPage(),
        providers: [
          ChangeNotifierProvider<WeeklyViewModel>.value(value: vm),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final todayCell = find.byKey(
      const ValueKey('weekly-attempt-cell-action_interactive-2026-07-16'),
    );
    final pastCell = find.byKey(
      const ValueKey('weekly-attempt-cell-action_interactive-2026-07-15'),
    );
    final futureCell = find.byKey(
      const ValueKey('weekly-attempt-cell-action_interactive-2026-07-17'),
    );
    await tester.dragUntilVisible(
      todayCell,
      find.byKey(const ValueKey('weekly-scroll-view')),
      const Offset(0, -320),
    );

    await tester.ensureVisible(pastCell);
    await tester.pumpAndSettle();
    expect(tester.widget<InkWell>(pastCell).onTap, isNull);
    await tester.tap(pastCell);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('small-try-feedback-sheet')),
      findsNothing,
    );

    await tester.ensureVisible(futureCell);
    await tester.pumpAndSettle();
    expect(tester.widget<InkWell>(futureCell).onTap, isNull);
    await tester.tap(futureCell);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('small-try-feedback-sheet')),
      findsNothing,
    );

    await Scrollable.ensureVisible(
      tester.element(todayCell),
      alignment: 0.40,
    );
    await tester.pumpAndSettle();
    expect(tester.widget<InkWell>(todayCell).onTap, isNotNull);
    await tester.tap(todayCell);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('small-try-feedback-sheet')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('small-try-completed-choice')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('small-try-effect-helpful')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('small-try-difficulty-easy')),
    );
    await tester.pump();
    final saveFeedback = find.byKey(const ValueKey('small-try-feedback-save'));
    await Scrollable.ensureVisible(
      tester.element(saveFeedback),
      alignment: 0.75,
    );
    await tester.pumpAndSettle();
    await tester.tap(saveFeedback);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('small-try-feedback-sheet')),
      findsNothing,
    );
    expect(repository.submittedMicroActionIds, ['action_interactive']);
    expect(repository.submittedMicroActionStatuses, ['completed']);
  });

  test('WeeklyViewModel 保留 gated stale regenerating ready failed 真实状态',
      () async {
    for (final status in CandidateGenerationStatus.values) {
      final planner = _StubCandidatePlanningRepository(
        snapshot: _candidateSnapshot(
          status: status,
          eligibleSignalCount:
              status == CandidateGenerationStatus.gated ? 2 : 3,
          candidateCount: status == CandidateGenerationStatus.ready ? 1 : 0,
        ),
      );
      final vm = WeeklyViewModel(
        StubWeeklyRepository(weekly: _readyWeeklyInsight()),
        candidatePlanningRepository: planner,
      );
      await vm.load();
      expect(vm.experimentCandidateStatus, status);
      expect(
        vm.experimentCandidateEligibleSignalCount,
        status == CandidateGenerationStatus.gated ? 2 : 3,
      );
      vm.dispose();
      await planner.dispose();
    }
  });

  testWidgets('Weekly 支持下拉刷新真实候选状态', (tester) async {
    final planner = _StubCandidatePlanningRepository(
      snapshot: _candidateSnapshot(
        status: CandidateGenerationStatus.ready,
        candidateCount: 1,
      ),
    );
    final vm = WeeklyViewModel(
      StubWeeklyRepository(weekly: _readyWeeklyInsight()),
      candidatePlanningRepository: planner,
    );
    addTearDown(vm.dispose);
    addTearDown(planner.dispose);

    await tester.pumpWidget(
      buildTestApp(
        child: const WeeklyPage(),
        providers: [
          ChangeNotifierProvider<WeeklyViewModel>.value(value: vm),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('weekly-pull-to-refresh')),
      findsOneWidget,
    );
    expect(planner.refreshCallCount, 1);

    await tester.drag(
      find.byKey(const ValueKey('weekly-scroll-view')),
      const Offset(0, 360),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    expect(planner.refreshCallCount, 2);
  });

  testWidgets('Weekly 复盘中 Signal 事实与模式判断各司其职', (tester) async {
    final repo = StubWeeklyRepository(
      weekly: WeeklyInsightModel(
        weekStart: '2026-06-22',
        weekEnd: '2026-06-28',
        status: 'ready',
        keyInsight: '这一周可以先从真实信号里看模式。',
        patterns: const [],
        frictions: const [
          {
            'name': '只来自摩擦的旧内容',
            'summary': '不应该只看摩擦。',
          },
        ],
        bestAction: '下周先轻轻试一个动作。',
        opportunitySnapshot: const {
          '_weekly_signal_entries': [
            {
              'id': 'sig-1',
              'source_type': 'text',
              'content': '晚上散步后脑子清楚一点。',
              'scene_tags': ['恢复'],
            },
            {
              'id': 'sig-2',
              'source_type': 'status',
              'content': '午后很累，想先暂停。',
              'scene_tags': ['恢复'],
            },
            {
              'id': 'sig-3',
              'source_type': 'schedule',
              'content': '会议接得太紧，切换很明显。',
              'scene_tags': ['安排'],
            },
          ],
        },
        feedbackSubmitted: false,
        behaviorPatterns: const [
          WeeklyBehaviorPatternModel(
            id: 'pattern-meeting-switch',
            label: '会议密集时更容易频繁切换',
            summary: '从处理即时消息后再回到重要任务的记录中整理。',
            kind: 'context_response',
            sourceSignalCardIds: ['sig-1', 'sig-2'],
            supportDates: ['2026-06-23', '2026-06-25'],
          ),
        ],
      ),
    );
    final energyRepo = StubEnergyBudgetRepository(
      budget: const EnergyBudgetModel(
        status: 'ready',
        mostDrainingSource: '这周的信号显示节奏变化比较明显。',
        recoveryClue: '恢复相关信号出现得更多。',
        bufferLocation: '安排前后可以留一点空隙。',
        switchingAdjustment: '下周可以先把一个恢复动作放进 Today。',
        experimentConnection: '小实验保持轻一点。',
        blocks: [],
      ),
    );
    final meVm = await buildMeViewModel(repeatArea: 'work_tasks');

    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
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

    final report = find.byKey(const ValueKey('weekly-review-report-card'));
    expect(report, findsOneWidget);
    expect(find.text('Signal 事实'), findsOneWidget);
    expect(find.text('行为模式'), findsOneWidget);
    expect(find.text('会议密集时更容易频繁切换'), findsOneWidget);
    expect(find.textContaining('支持日期：2026-06-23、2026-06-25'), findsOneWidget);
    expect(find.text('证据来源'), findsNothing);
    expect(find.text('不应重复显示在模式层。'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('weekly-signal-distribution-card')),
        matching: find.text('旧的固定模式'),
      ),
      findsNothing,
    );
    expect(find.text('会议接得太紧，切换很明显。'), findsNothing);
    expect(
      find.descendant(
        of: report,
        matching: find.textContaining('证据'),
      ),
      findsNothing,
    );
  });

  for (final testCase in <({Locale locale, String expected})>[
    (locale: const Locale('en'), expected: 'Pattern still forming'),
    (
      locale: const Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hans',
      ),
      expected: '模式仍在形成',
    ),
    (
      locale: const Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hant',
      ),
      expected: '模式仍在形成',
    ),
    (locale: const Locale('ja'), expected: 'パターンは形成中'),
  ]) {
    testWidgets(
      'Weekly 不用 Signal 标签补造模式：${testCase.expected}',
      (tester) async {
        final repo = StubWeeklyRepository(
          weekly: WeeklyInsightModel(
            weekStart: '2026-07-13',
            weekEnd: '2026-07-19',
            status: 'ready',
            keyInsight: '这周已经有足够线索。',
            patterns: const [],
            frictions: const [],
            bestAction: '下周先继续这个小尝试。',
            opportunitySnapshot: const {
              '_weekly_signal_entries': [
                {
                  'id': 'work-signal-1',
                  'source_type': 'text',
                  'content': '把复杂任务拆成第一步后更容易开始。',
                  'scene_tags': ['work'],
                },
                {
                  'id': 'work-signal-2',
                  'source_type': 'text',
                  'content': '今天专注的时间更长了。',
                  'scene_tags': ['work'],
                },
                {
                  'id': 'focus-signal-1',
                  'source_type': 'time_use',
                  'content': '把下一步写下来。',
                  'focus_domain_id': 'growth_plan',
                  'scene_tags': ['growth_plan'],
                },
              ],
            },
            feedbackSubmitted: false,
          ),
        );

        await tester.pumpWidget(
          buildTestApp(
            locale: testCase.locale,
            child: const WeeklyPage(),
            providers: [
              ChangeNotifierProvider<WeeklyViewModel>(
                create: (_) => WeeklyViewModel(repo),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(testCase.expected), findsOneWidget);
        expect(find.text('work'), findsNothing);
        expect(find.text('growth_plan'), findsNothing);
        expect(find.text('Work'), findsNothing);
        expect(find.text('工作'), findsNothing);
        expect(find.text('仕事'), findsNothing);
      },
    );
  }

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

    expect(find.text('Weekly Review'), findsOneWidget);
    expect(find.text('Last week, looking back'), findsOneWidget);
    expect(find.text('This week’s review report'), findsOneWidget);
    expect(find.text('Signal facts'), findsOneWidget);
    expect(find.text('This week’s energy state'), findsNothing);
    await tester.dragUntilVisible(
      find.text('Next week’s tries'),
      find.byType(ListView).first,
      const Offset(0, -420),
    );
    expect(find.text('Next week’s tries'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('weekly-next-experiment-forming')),
      findsOneWidget,
    );
    expect(
        find.textContaining('After 3 eligible life signals'), findsOneWidget);
  });

  testWidgets('Weekly 主页面不显示仅属于 Pro 的能量状态', (tester) async {
    final repo = StubWeeklyRepository(
      weekly: WeeklyInsightModel(
        weekStart: '2026-07-13',
        weekEnd: '2026-07-19',
        status: 'ready',
        keyInsight: '本周已经有足够线索。',
        patterns: const [],
        frictions: const [],
        bestAction: '下周先继续这个小尝试。',
        opportunitySnapshot: const {
          '_weekly_signal_entries': [
            {
              'id': 'signal-1',
              'source_type': 'text',
              'content': '把复杂任务拆成第一步后更容易开始。',
              'scene_tags': ['work'],
            },
          ],
        },
        feedbackSubmitted: false,
      ),
    );
    final energyRepo = StubEnergyBudgetRepository(
      budget: const EnergyBudgetModel(
        status: 'ready',
        mostDrainingSource: '这段时间最耗能的来源可能是“starting”。',
        recoveryClue: '一个恢复线索是“small_start”。',
        bufferLocation: '可以先把“work”看作需要缓冲的位置。',
        switchingAdjustment: '先给“context_switching”留一点余地。',
        experimentConnection: '保持小一点。',
        energyStateCounts: {
          'draining': 3,
          'steady': 2,
          'ease': 1,
          'recovery': 1,
          'boundary_buffer': 1,
        },
        blocks: [],
      ),
    );

    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        child: const WeeklyPage(),
        providers: [
          ChangeNotifierProvider<WeeklyViewModel>(
            create: (_) => WeeklyViewModel(
              repo,
              energyBudgetRepository: energyRepo,
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('本周能量状态'), findsNothing);
    expect(find.textContaining('“启动阻力”'), findsNothing);
    expect(find.textContaining('“小步启动”'), findsNothing);
    expect(find.textContaining('small_start'), findsNothing);
    expect(find.textContaining('context_switching'), findsNothing);
  });

  for (final testCase in <({Locale locale, String title})>[
    (
      locale: const Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hant',
      ),
      title: '本週能量狀態',
    ),
    (locale: const Locale('ja'), title: '今週のエネルギー状態'),
  ]) {
    testWidgets('Weekly 首页不显示 ${testCase.title}', (tester) async {
      final repo = StubWeeklyRepository(weekly: _readyWeeklyInsight());
      final energyRepo = StubEnergyBudgetRepository(
        budget: const EnergyBudgetModel(
          status: 'ready',
          mostDrainingSource: '“starting”',
          recoveryClue: '“small_start”',
          bufferLocation: '“work”',
          switchingAdjustment: '“context_switching”',
          experimentConnection: 'Keep it small.',
          blocks: [],
        ),
      );

      await tester.pumpWidget(
        buildTestApp(
          locale: testCase.locale,
          child: const WeeklyPage(),
          providers: [
            ChangeNotifierProvider<WeeklyViewModel>(
              create: (_) => WeeklyViewModel(
                repo,
                energyBudgetRepository: energyRepo,
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(testCase.title), findsNothing);
      expect(find.textContaining('Energy Budget'), findsNothing);
    });
  }

  testWidgets('Weekly 第一天 gate 会显示对应空态', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(350, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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

    final scrollView = tester.widget<ListView>(
      find.byKey(const ValueKey('weekly-scroll-view')),
    );
    expect(
      scrollView.padding,
      const EdgeInsets.fromLTRB(18, 14, 18, 96),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('weekly-hero-header'))).height,
      lessThanOrEqualTo(170),
    );
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(const ValueKey('weekly-hero-title')),
              matching: find.byType(Text),
            ),
          )
          .style
          ?.fontSize,
      34,
    );
    final emptyCard = tester.widget<Container>(
      find.byKey(const ValueKey('weekly-empty-card')),
    );
    expect(
      emptyCard.padding,
      const EdgeInsets.fromLTRB(16, 14, 16, 16),
    );
    expect(
      (emptyCard.decoration! as BoxDecoration).borderRadius,
      BorderRadius.circular(20),
    );
    expect(find.text('Weekly Review'), findsOneWidget);
    expect(find.text('Not enough signals yet'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('weekly-review-report-card')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('weekly-report-readiness-progress')),
      findsOneWidget,
    );
    expect(find.textContaining('0 / 3 eligible signals'), findsOneWidget);
    expect(find.text('Next week goals are taking shape'), findsOneWidget);
    expect(
        find.textContaining('After 3 eligible life signals'), findsOneWidget);
    expect(find.text('Record today'), findsOneWidget);
    expect(find.text('View trend'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Weekly 领域标签在 320/390 宽和 1.3x 字号下不会横向溢出', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const longDomainLabel =
        'A very long weekly domain label that must wrap without overflowing';

    for (final width in [320.0, 390.0]) {
      tester.view.physicalSize = Size(width, 844);
      final repo = StubWeeklyRepository(
        weekly: WeeklyInsightModel(
          weekStart: '2026-07-13',
          weekEnd: '2026-07-19',
          status: 'ready',
          keyInsight: 'Switching and recovery are both visible this week.',
          patterns: const [
            {
              'name': longDomainLabel,
              'summary': 'This label should stay inside the pattern section.',
            },
          ],
          frictions: const [],
          bestAction: 'Keep the next experiment light.',
          opportunitySnapshot: const {
            '_weekly_inclusion': {
              'used_count': 3,
              'timeline_only_count': 0,
              'excluded_count': 0,
              'legacy_reference_count': 0,
            },
          },
          feedbackSubmitted: false,
          chartData: const [
            WeeklyChartPointModel(
              date: '2026-07-13',
              signalCount: 3,
              moodScore: 0,
              frictionScore: 0.3,
              hasPositiveSignal: true,
            ),
          ],
        ),
      );
      final meVm = await buildMeViewModel();

      await tester.pumpWidget(
        buildTestApp(
          child: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 844),
              devicePixelRatio: 1,
              textScaler: const TextScaler.linear(1.3),
            ),
            child: const WeeklyPage(),
          ),
          providers: [
            ChangeNotifierProvider<WeeklyViewModel>(
              create: (_) => WeeklyViewModel(repo),
            ),
            ChangeNotifierProvider<MeViewModel>.value(value: meVm),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final labelFinder = find.descendant(
        of: find.byKey(const ValueKey('weekly-behavior-pattern-card')),
        matching: find.text(longDomainLabel),
      );
      expect(labelFinder, findsOneWidget);
      final labelRect = tester.getRect(labelFinder);
      expect(labelRect.right, lessThanOrEqualTo(width - 18));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}

WeeklyInsightModel _readyWeeklyInsight() {
  return WeeklyInsightModel(
    weekStart: '2026-07-13',
    weekEnd: '2026-07-19',
    status: 'ready',
    keyInsight: 'Recovery and switching are both visible this week.',
    patterns: const [],
    frictions: const [],
    bestAction: 'Keep the next attempt small.',
    opportunitySnapshot: const {
      '_weekly_inclusion': {
        'used_count': 3,
        'timeline_only_count': 0,
        'excluded_count': 0,
        'legacy_reference_count': 0,
      },
    },
    feedbackSubmitted: false,
  );
}

CandidateSnapshot<ExperimentCandidateRecord> _candidateSnapshot({
  required CandidateGenerationStatus status,
  int eligibleSignalCount = 3,
  int candidateCount = 0,
}) {
  const start = '2026-07-13';
  const end = '2026-07-19';
  return CandidateSnapshot<ExperimentCandidateRecord>(
    gate: CandidateGateState(
      kind: CandidateKind.lifeExperiment,
      periodStart: start,
      periodEnd: end,
      eligibleSignalCount: eligibleSignalCount,
    ),
    generation: CandidateGenerationState(
      kind: CandidateKind.lifeExperiment,
      periodStart: start,
      periodEnd: end,
      status: status,
      eligibleSignalCount: eligibleSignalCount,
      staleReason: status == CandidateGenerationStatus.stale
          ? 'signal_source_changed'
          : null,
    ),
    candidates: status == CandidateGenerationStatus.ready
        ? List.generate(
            candidateCount,
            (index) => ExperimentCandidateRecord(
              id: 'candidate_${index + 1}',
              candidateGroupId: 'weekly_group',
              localUserId: 'test-user',
              weekStart: start,
              weekEnd: end,
              rank: index + 1,
              title: 'Candidate ${index + 1}',
              hypothesis: 'A small change may make recovery easier.',
              suggestedAction: 'Try this once.',
              linkedSignalCardIds: const ['signal_1'],
              linkedObservationIds: const [],
              confidenceLevel: 'medium',
              metadata: const {},
              status: 'suggested',
              sourceHash: 'source_hash',
            ),
          )
        : const [],
  );
}

LifeExperimentModel _activeExperiment({
  required String id,
  required String title,
}) {
  return LifeExperimentModel(
    id: id,
    localUserId: 'test-user',
    sourceWeekStart: '2026-07-13',
    sourceWeekEnd: '2026-07-19',
    title: title,
    hypothesis: 'This may reduce switching.',
    suggestedAction: 'Try it once.',
    linkedSignalCardIds: const ['signal_1'],
    status: 'active',
  );
}

SevenDayProgressModel _progress(String subjectId, int completedDays) {
  return SevenDayProgressModel(
    subjectId: subjectId,
    startDate: '2026-07-13',
    endDate: '2026-07-19',
    cells: List.generate(
      SevenDayProgressModel.totalDays,
      (index) => SevenDayProgressCell(
        localDate: '2026-07-${13 + index}',
        state: index < completedDays
            ? ProgressCellState.completed
            : ProgressCellState.empty,
      ),
    ),
  );
}

class _InteractiveWeeklyRepository extends WeeklyRepository {
  final WeeklyInsightModel weekly;
  final List<String> submittedMicroActionIds = [];
  final List<String> submittedMicroActionStatuses = [];

  factory _InteractiveWeeklyRepository({
    required WeeklyInsightModel weekly,
    required DateTime currentDay,
  }) {
    final database = createDummyDatabase();
    return _InteractiveWeeklyRepository._(
      database,
      weekly: weekly,
      currentDay: currentDay,
    );
  }

  _InteractiveWeeklyRepository._(
    LocalDatabase database, {
    required this.weekly,
    required DateTime currentDay,
  }) : super(
          localCaptureRepository: LocalCaptureRepository(database),
          localWeeklySnapshotRepository:
              LocalWeeklySnapshotRepository(database),
          aiRepository: DummyAiRepository(),
          nowLoader: () => currentDay,
        );

  @override
  Future<WeeklyInsightModel> fetchCurrentWeekly() async => weekly;

  @override
  Future<LifeExperimentModel?> fetchCurrentWeekLifeExperiment({
    required String weekStart,
  }) async =>
      null;

  @override
  Future<LifeExperimentModel?> fetchNextWeekExperiment({
    required String weekStart,
  }) async =>
      null;

  @override
  Future<MicroActionModel?> submitMicroActionFeedback({
    required String microActionId,
    required String status,
    String? effect,
    String? difficulty,
    String? userNote,
  }) async {
    submittedMicroActionIds.add(microActionId);
    submittedMicroActionStatuses.add(status);
    return MicroActionModel(
      id: microActionId,
      judgementId: 'interactive_judgement',
      title: 'Interactive small try',
      reason: 'Used by the Weekly cell test.',
      status: 'active',
      originCandidateId: 'interactive_candidate',
      adoptedAt: DateTime(2026, 7, 13),
      progressStartDate: '2026-07-13',
      progressEndDate: '2026-07-19',
    );
  }
}

class _StubCandidatePlanningRepository
    extends LocalCandidatePlanningRepository {
  CandidateSnapshot<ExperimentCandidateRecord> snapshot;
  final List<AdoptedMicroActionProgress> activeMicroActions;
  final List<AdoptedLifeExperimentProgress> activeExperiments;
  int refreshCallCount = 0;

  factory _StubCandidatePlanningRepository({
    required CandidateSnapshot<ExperimentCandidateRecord> snapshot,
    List<AdoptedMicroActionProgress> activeMicroActions = const [],
    List<AdoptedLifeExperimentProgress> activeExperiments = const [],
  }) {
    final database = createDummyDatabase();
    return _StubCandidatePlanningRepository._(
      database,
      snapshot: snapshot,
      activeMicroActions: activeMicroActions,
      activeExperiments: activeExperiments,
    );
  }

  _StubCandidatePlanningRepository._(
    LocalDatabase database, {
    required this.snapshot,
    required this.activeMicroActions,
    required this.activeExperiments,
  }) : super(
          localDatabase: database,
          localCaptureRepository: LocalCaptureRepository(database),
          localLifeExperimentRepository:
              LocalLifeExperimentRepository(database),
          localUserId: 'test-user',
        );

  @override
  Future<CandidateSnapshot<ExperimentCandidateRecord>> weeklyCandidateSnapshot(
          DateTime day) async =>
      snapshot;

  @override
  Future<CandidateSnapshot<ExperimentCandidateRecord>>
      refreshWeeklyWithGroundedSuggestions({
    required DateTime day,
    AppLanguage language = AppLanguage.simplifiedChinese,
    Duration debounce = Duration.zero,
  }) async {
    refreshCallCount += 1;
    return snapshot;
  }

  @override
  Future<List<AdoptedMicroActionProgress>> listActiveMicroActionsForDate(
    DateTime day,
  ) async =>
      activeMicroActions;

  @override
  Future<List<AdoptedLifeExperimentProgress>> listActiveExperimentsForDate(
    DateTime day,
  ) async =>
      activeExperiments;

  @override
  Future<List<AdoptedMicroActionProgress>> listAdoptedSmallTriesForWeek({
    required DateTime weekStart,
    required DateTime weekEnd,
  }) async =>
      activeMicroActions;

  @override
  Future<List<AdoptedLifeExperimentProgress>> listAdoptedGoalsForWeek({
    required DateTime weekStart,
    required DateTime weekEnd,
  }) async =>
      activeExperiments;
}
