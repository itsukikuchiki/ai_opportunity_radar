import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ai_opportunity_radar/core/di/app_dependencies.dart';
import 'package:ai_opportunity_radar/core/i18n/app_locale_text.dart';
import 'package:ai_opportunity_radar/core/local/local_candidate_planning_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_capture_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/local/local_life_experiment_repository.dart';
import 'package:ai_opportunity_radar/core/models/candidate_models.dart';
import 'package:ai_opportunity_radar/core/models/energy_budget_models.dart';
import 'package:ai_opportunity_radar/core/models/phase3_plus_models.dart';
import 'package:ai_opportunity_radar/core/models/weekly_models.dart';
import 'package:ai_opportunity_radar/features/pages/me/me_view_model.dart';
import 'package:ai_opportunity_radar/features/pages/weekly/deep_weekly_page.dart';
import 'package:ai_opportunity_radar/features/pages/weekly/weekly_page.dart';
import 'package:ai_opportunity_radar/features/pages/weekly/weekly_view_model.dart';

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
          .widget<Text>(find.byKey(const ValueKey('weekly-hero-title')))
          .style
          ?.fontSize,
      36,
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
    final distributionCard = tester.widget<Container>(
      find.byKey(const ValueKey('weekly-signal-distribution-card')),
    );
    expect(
      distributionCard.padding,
      const EdgeInsets.fromLTRB(16, 14, 16, 16),
    );
    expect(
      (distributionCard.decoration! as BoxDecoration).borderRadius,
      BorderRadius.circular(20),
    );
    expect(
      tester.widget<Text>(find.text('Signal distribution')).style?.fontSize,
      17,
    );
    expect(
      tester
          .getTopLeft(
              find.byKey(const ValueKey('weekly-behavior-pattern-card')))
          .dy,
      greaterThan(
        tester
            .getBottomLeft(
              find.byKey(const ValueKey('weekly-signal-distribution-card')),
            )
            .dy,
      ),
    );
    expect(find.text('Weekly Review'), findsOneWidget);
    expect(find.text('Signal distribution'), findsOneWidget);
    expect(find.text('Behavior pattern'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Energy Budget'),
      find.byType(ListView).first,
      const Offset(0, -260),
    );
    expect(find.text('Energy Budget'), findsOneWidget);
    expect(find.text('Costly point'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Small actions and review'),
      find.byType(ListView).first,
      const Offset(0, -280),
    );
    expect(find.text('Small actions and review'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Next week experiment'),
      find.byType(ListView).first,
      const Offset(0, -280),
    );
    expect(find.text('Next week experiment'), findsOneWidget);
    expect(find.text('Signals changed'), findsOneWidget);
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
    expect(find.text('Signal distribution'), findsOneWidget);
    expect(find.text('Behavior pattern'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Small actions and review'),
      find.byType(ListView),
      const Offset(0, -360),
    );
    expect(find.text('Small actions and review'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Experiment result and review'),
      find.byType(ListView).first,
      const Offset(0, -240),
    );
    expect(find.text('Experiment result and review'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Next week experiment'),
      find.byType(ListView).first,
      const Offset(0, -240),
    );
    expect(find.text('Next week experiment'), findsOneWidget);
    expect(find.text('本周正式实验'), findsOneWidget);
    expect(find.text('候选：保护半小时'), findsOneWidget);
    expect(find.text('Choose experiments'), findsOneWidget);
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
      find.text('Next week experiment'),
      find.byType(ListView).first,
      const Offset(0, -420),
    );

    expect(find.text('View all experiments'), findsOneWidget);
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

  testWidgets('Weekly Reflect smoke: 标题/入口使用 Weekly Reflect 语义',
      (tester) async {
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
    final deps = await buildTestDependencies(
      todayRepository: StubTodayRepository(
        fetchTodayResult: const <String, dynamic>{},
      ),
      weeklyRepository: weeklyRepo,
    );

    await tester.pumpWidget(
      buildTestApp(
        child: const WeeklyReflectPage(),
        providers: [
          Provider<AppDependencies>.value(value: deps),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(WeeklyReflectPage), findsOneWidget);
    expect(find.text('Weekly Deep Review'), findsOneWidget);
    expect(find.text('Reflect'), findsOneWidget);
    expect(find.textContaining('Weekly Reflect keeps'), findsOneWidget);
    expect(find.textContaining('Keep the next experiment light'), findsWidgets);
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
    expect(find.text('2/7'), findsOneWidget);
    expect(find.textContaining('Source changed'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('Single-task recovery'),
      find.byKey(const ValueKey('weekly-scroll-view')),
      const Offset(0, -220),
    );
    expect(find.text('Morning buffer'), findsOneWidget);
    expect(find.text('Single-task recovery'), findsOneWidget);
    expect(find.text('1/7'), findsOneWidget);
    expect(find.text('3/7'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('2 candidates ready'),
      find.byKey(const ValueKey('weekly-scroll-view')),
      const Offset(0, -260),
    );
    expect(find.text('2 candidates ready'), findsOneWidget);
    expect(find.text('Candidate 1'), findsOneWidget);
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

  testWidgets('Weekly 行为模式优先使用本周全部真实 SignalCard', (tester) async {
    final repo = StubWeeklyRepository(
      weekly: WeeklyInsightModel(
        weekStart: '2026-06-22',
        weekEnd: '2026-06-28',
        status: 'ready',
        keyInsight: '这一周可以先从真实信号里看模式。',
        patterns: const [
          {
            'name': '旧的固定模式',
            'summary': '不应该优先显示这个。',
          },
        ],
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

    expect(find.text('本周行为模式'), findsOneWidget);
    expect(find.text('恢复'), findsOneWidget);
    expect(find.textContaining('2 条信号'), findsOneWidget);
    expect(find.text('安排信号'), findsNothing);
    expect(find.text('会议接得太紧，切换很明显。'), findsNothing);
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

    expect(find.text('Weekly Review'), findsOneWidget);
    expect(find.text('This week in one sentence'), findsOneWidget);
    expect(find.text('Signal distribution'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Energy Budget'),
      find.byType(ListView).first,
      const Offset(0, -360),
    );
    expect(find.text('Energy Budget'), findsOneWidget);
    expect(find.text('Energy change'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Next week experiment'),
      find.byType(ListView).first,
      const Offset(0, -420),
    );
    expect(find.text('Next week experiment'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('weekly-next-experiment-forming')),
      findsOneWidget,
    );
    expect(
        find.textContaining('After 3 eligible life signals'), findsOneWidget);
  });

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
          .widget<Text>(find.byKey(const ValueKey('weekly-hero-title')))
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
      find.byKey(const ValueKey('weekly-report-readiness-progress')),
      findsOneWidget,
    );
    expect(find.textContaining('0 / 3 eligible signals'), findsOneWidget);
    expect(find.text('Next week experiment plan is forming'), findsOneWidget);
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
              'summary': 'This label should stay inside the signal card.',
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
        of: find.byKey(const ValueKey('weekly-signal-distribution-card')),
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
}
