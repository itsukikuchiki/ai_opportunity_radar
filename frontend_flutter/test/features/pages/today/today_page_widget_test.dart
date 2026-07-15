import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:ai_opportunity_radar/app/app_router.dart';
import 'package:ai_opportunity_radar/core/models/phase3_plus_models.dart';
import 'package:ai_opportunity_radar/core/models/today_models.dart';
import 'package:ai_opportunity_radar/core/models/weekly_models.dart';
import 'package:ai_opportunity_radar/core/state/app_data_refresh_coordinator.dart';
import 'package:ai_opportunity_radar/features/pages/me/me_view_model.dart';
import 'package:ai_opportunity_radar/features/pages/today/today_dialog_page.dart';
import 'package:ai_opportunity_radar/features/pages/today/today_diary_page.dart';
import 'package:ai_opportunity_radar/features/pages/today/today_page.dart';
import 'package:ai_opportunity_radar/features/pages/today/today_view_model.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Today 页面能加载并触发一次数据获取', (tester) async {
    final repo = StubTodayRepository(
      fetchTodayResult: {
        'insight': TodayInsightModel(
          text: 'Today, the tension seems to gather around work interruptions.',
        ),
        'pendingQuestion': null,
        'bestAction': DailyBestActionModel(
          text: 'Try noticing the exact moment the pressure first rises.',
        ),
        'recentSignals': [
          RecentSignalModel(
            id: 'signal-1',
            content: 'The meeting kept getting interrupted and I felt drained.',
            createdAt: DateTime.now(),
            acknowledgement: 'That sounds genuinely draining.',
            observation:
                'Work interruptions are taking up more space than they seem.',
            tryNext: 'Write down the first interruption next time.',
            emotion: 'negative',
            intensity: 'medium',
            sceneTags: const ['work'],
          ),
        ],
      },
    );

    final meVm = await buildMeViewModel();

    await tester.pumpWidget(
      buildTestApp(
        child: const TodayPage(),
        providers: [
          ChangeNotifierProvider<TodayViewModel>(
            create: (_) => TodayViewModel(repo),
          ),
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(TodayPage), findsOneWidget);
    expect(find.text('How is today going?'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Text'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('today-submit-text-action')), findsOneWidget);
    expect(repo.fetchTodayCallCount, 1);
  });

  testWidgets('Today awaits Signal Library return and refreshes once',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = StubTodayRepository(
      fetchTodayResult: {
        'insight': TodayInsightModel(text: 'Keep one small signal visible.'),
        'pendingQuestion': null,
        'bestAction': DailyBestActionModel(text: 'Leave a little room.'),
        'recentSignals': <RecentSignalModel>[],
      },
    );
    final todayViewModel = TodayViewModel(repo);
    final meViewModel = await buildMeViewModel();
    final coordinator = AppDataRefreshCoordinator(
      routeLoaders: {AppRoutes.today: todayViewModel.load},
    );
    addTearDown(() {
      coordinator.dispose();
      todayViewModel.dispose();
      meViewModel.dispose();
    });
    final router = GoRouter(
      initialLocation: AppRoutes.today,
      routes: [
        GoRoute(
          path: AppRoutes.today,
          builder: (_, __) => const TodayPage(),
        ),
        GoRoute(
          path: AppRoutes.signalLibrary,
          builder: (context, __) => Scaffold(
            body: Center(
              child: TextButton(
                key: const ValueKey('library-back'),
                onPressed: () => context.pop(),
                child: const Text('Back from library'),
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TodayViewModel>.value(value: todayViewModel),
          ChangeNotifierProvider<MeViewModel>.value(value: meViewModel),
          Provider<AppDataRefreshCoordinator>.value(value: coordinator),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.fetchTodayCallCount, 1);

    await tester.tap(
      find.byKey(const ValueKey('today-signal-library-action')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('library-back')), findsOneWidget);
    expect(repo.fetchTodayCallCount, 1);

    await tester.tap(find.byKey(const ValueKey('library-back')));
    await tester.pumpAndSettle();

    expect(find.byType(TodayPage), findsOneWidget);
    expect(repo.fetchTodayCallCount, 2);
  });

  testWidgets('Today 顶部压缩并整合当天动态观察与概览线索', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = StubTodayRepository(
      fetchTodayResult: {
        'insight': TodayInsightModel(
          text: '今天可以先这样看：恢复线索正在出现。',
        ),
        'pendingQuestion': null,
        'bestAction': DailyBestActionModel(text: '先留一点恢复空间。'),
        'recentSignals': [
          RecentSignalModel(
            id: 'hero-dynamic-signal',
            content: '散步后感觉缓过来一点。',
            createdAt: DateTime.now(),
            energyLoad: 'restoring',
            friction: 'schedule_pressure',
          ),
        ],
      },
    );
    final meVm = await buildMeViewModel();

    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        child: const TodayPage(),
        providers: [
          ChangeNotifierProvider<TodayViewModel>(
            create: (_) => TodayViewModel(repo),
          ),
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final hero = find.byKey(const ValueKey('today-hero-header'));
    expect(hero, findsOneWidget);
    expect(tester.getSize(hero).height, lessThanOrEqualTo(170));
    expect(find.text('今天可以先这样看'), findsOneWidget);
    expect(find.text('恢复线索正在出现。'), findsOneWidget);
    expect(find.text('今日概览'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('today-hero-energy')),
        matching: find.text('在回升'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('today-hero-friction')),
        matching: find.text('有线索'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('today-hero-recovery')),
        matching: find.text('有线索'),
      ),
      findsOneWidget,
    );
    expect(
      tester.getBottomLeft(hero).dy,
      lessThan(tester.getTopLeft(find.text('今天过得怎么样？')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Today 空状态忽略旧概览并保持中性', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = StubTodayRepository(
      fetchTodayResult: {
        'insight': TodayInsightModel(text: '旧概览：恢复不足。'),
        'pendingQuestion': null,
        'bestAction': DailyBestActionModel(text: '旧建议。'),
        'recentSignals': <RecentSignalModel>[],
      },
    );
    final meVm = await buildMeViewModel();

    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        child: const TodayPage(),
        providers: [
          ChangeNotifierProvider<TodayViewModel>(
            create: (_) => TodayViewModel(repo),
          ),
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('今天还没有记录，先留下一件真实发生的小事就好。'), findsOneWidget);
    expect(find.text('旧概览：恢复不足。'), findsNothing);
    expect(find.text('今日概览'), findsNothing);
    expect(find.text('偏低'), findsNothing);
    expect(find.text('偏高'), findsNothing);
    expect(find.text('不足'), findsNothing);
    expect(find.byKey(const ValueKey('today-hero-energy')), findsNothing);
    expect(find.byKey(const ValueKey('today-hero-friction')), findsNothing);
    expect(find.byKey(const ValueKey('today-hero-recovery')), findsNothing);
    expect(
      tester.getSize(find.byKey(const ValueKey('today-hero-header'))).height,
      lessThanOrEqualTo(140),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('未分类本机草稿只显示保存提示，不生成负面概览', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = StubTodayRepository(
      fetchTodayResult: {
        'insight': TodayInsightModel(
          text: '今天可以先这样看：原文已经保存，等同步完成后再整理也来得及。',
        ),
        'pendingQuestion': null,
        'bestAction': DailyBestActionModel(text: '先不用重复输入。'),
        'recentSignals': [
          RecentSignalModel(
            id: 'hero-local-draft',
            content: '今天有点乱。',
            createdAt: DateTime.now(),
            energyLoad: 'draining',
            isLocalDraft: true,
            syncFailed: true,
          ),
        ],
      },
    );
    final meVm = await buildMeViewModel();

    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        child: const TodayPage(),
        providers: [
          ChangeNotifierProvider<TodayViewModel>(
            create: (_) => TodayViewModel(repo),
          ),
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('原文已经保存，等同步完成后再整理也来得及。'), findsOneWidget);
    expect(find.byKey(const ValueKey('today-hero-energy')), findsNothing);
    expect(find.byKey(const ValueKey('today-hero-friction')), findsNothing);
    expect(find.byKey(const ValueKey('today-hero-recovery')), findsNothing);
    expect(find.text('偏低'), findsNothing);
    expect(find.text('偏高'), findsNothing);
    expect(find.text('不足'), findsNothing);
  });

  testWidgets('Today smoke: 记录、Observation、删除/排除入口可见并可触发', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = StubTodayRepository(
      fetchTodayResult: {
        'insight': TodayInsightModel(
          text: 'Observation: meetings and recovery are linked today.',
        ),
        'pendingQuestion': null,
        'bestAction': DailyBestActionModel(text: 'Keep the next action tiny.'),
        'aiJudgement': const AiJudgementModel(
          id: 'judge-ui-smoke-1',
          sourceSignalCardIds: ['sig-ui-smoke-1'],
          localDate: '2026-07-05',
          judgementText: 'Meetings may be draining recovery capacity.',
          evidenceText:
              'One signal mentions three meetings and feeling drained.',
          suggestedPattern: 'Meeting density affects recovery.',
          suggestedLifeChainStage: 'energy',
        ),
        'recentSignals': [
          RecentSignalModel(
            id: 'sig-ui-smoke-1',
            signalCardId: 'sig-ui-smoke-1',
            content: 'I felt drained after three meetings.',
            createdAt: DateTime.now(),
            acknowledgement: 'This is saved as a small signal.',
            observation: 'Meetings are draining recovery capacity.',
            tryNext: 'Try one lighter recovery action.',
            sourceType: 'ai_predicted',
            userConfirmation: 'unconfirmed',
          ),
        ],
      },
    );
    final meVm = await buildMeViewModel();

    await tester.pumpWidget(
      buildTestApp(
        child: const TodayPage(),
        providers: [
          ChangeNotifierProvider<TodayViewModel>(
            create: (_) => TodayViewModel(repo),
          ),
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('How is today going?'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('I felt drained after three meetings.'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('I felt drained after three meetings.'), findsOneWidget);
    expect(find.textContaining('Meetings may be draining'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('Not accurate').first,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Not accurate').first);
    await tester.pumpAndSettle();

    expect(repo.aiJudgementResponses, isEmpty);
    expect(find.text('Not accurate'), findsNothing);
  });

  testWidgets('删除独立预判按钮，准可在确认窗编辑后记入时间线', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = StubTodayRepository(
      fetchTodayResult: {
        'insight': TodayInsightModel(text: '今天可以先这样看。'),
        'pendingQuestion': null,
        'bestAction': DailyBestActionModel(text: '先留下一点余地。'),
        'aiJudgement': const AiJudgementModel(
          id: 'judge-accurate-1',
          sourceSignalCardIds: ['sig-1'],
          localDate: '2026-07-10',
          judgementText: '连续推进后，你可能正在经历明显疲惫。',
          evidenceText: '今天的记录多次提到切换和疲惫。',
          suggestedPattern: '推进后的疲惫',
          suggestedLifeChainStage: 'energy',
        ),
        'recentSignals': <RecentSignalModel>[],
      },
    );
    final meVm = await buildMeViewModel();

    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        child: const TodayPage(),
        providers: [
          ChangeNotifierProvider<TodayViewModel>(
            create: (_) => TodayViewModel(repo),
          ),
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('today-ai-judgement-action')),
      findsNothing,
    );
    final panel = find.byKey(const ValueKey('today-ai-prediction-panel'));
    expect(panel, findsOneWidget);
    expect(
      tester.getTopLeft(panel).dy,
      greaterThan(tester.getTopLeft(find.text('今天过得怎么样？')).dy),
    );

    await tester.tap(find.byKey(const ValueKey('ai-prediction-accurate')));
    await tester.pumpAndSettle();
    expect(find.text('要记入时间线吗？'), findsOneWidget);
    expect(
      find.text('连续推进后，你可能正在经历明显疲惫。'),
      findsWidgets,
    );

    await tester.tap(
      find.byKey(const ValueKey('ai-prediction-dialog-cancel')),
    );
    await tester.pumpAndSettle();
    expect(repo.aiJudgementResponses, isEmpty);

    await tester.tap(find.byKey(const ValueKey('ai-prediction-accurate')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('ai-prediction-timeline-input')),
      '连续会议以后，我确实需要先恢复十分钟。',
    );
    await tester.tap(
      find.byKey(const ValueKey('ai-prediction-add-timeline')),
    );
    await tester.pumpAndSettle();

    expect(repo.aiJudgementResponses, hasLength(1));
    expect(repo.aiJudgementResponses.single['status'], 'accurate');
    expect(repo.aiJudgementResponses.single['userAdjustmentText'],
        '连续会议以后，我确实需要先恢复十分钟。');
    expect(repo.aiJudgementResponses.single['addToTimeline'], isTrue);
  });

  testWidgets('有一点像但不加入时间线时零写入', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = StubTodayRepository(
      fetchTodayResult: {
        'insight': TodayInsightModel(text: '今天可以先这样看。'),
        'pendingQuestion': null,
        'bestAction': DailyBestActionModel(text: '先留下一点余地。'),
        'aiJudgement': const AiJudgementModel(
          id: 'judge-partial-1',
          sourceSignalCardIds: ['sig-1'],
          localDate: '2026-07-10',
          judgementText: '今天的消耗可能主要来自安排太密。',
          evidenceText: '记录里出现了多个连续安排。',
          suggestedPattern: '安排密度',
          suggestedLifeChainStage: 'schedule',
        ),
        'recentSignals': <RecentSignalModel>[],
      },
    );
    final meVm = await buildMeViewModel();

    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        child: const TodayPage(),
        providers: [
          ChangeNotifierProvider<TodayViewModel>(
            create: (_) => TodayViewModel(repo),
          ),
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('ai-prediction-partial')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('ai-prediction-timeline-input')),
      '有一点像，更接近的是频繁切换带来的消耗。',
    );
    await tester.tap(
      find.byKey(const ValueKey('ai-prediction-do-not-add')),
    );
    await tester.pumpAndSettle();

    expect(repo.aiJudgementResponses, isEmpty);
    expect(
      find.byKey(const ValueKey('ai-prediction-partial')),
      findsNothing,
    );
  });

  testWidgets('library_saved 在 Timeline 中显示为来自 Library 的 SignalCard',
      (tester) async {
    final repo = StubTodayRepository(
      fetchTodayResult: {
        'insight': TodayInsightModel(text: '今天可以先轻轻观察。'),
        'pendingQuestion': null,
        'bestAction': DailyBestActionModel(text: '不用急着确认。'),
        'recentSignals': [
          RecentSignalModel(
            id: 'library-signal-1',
            signalCardId: 'library-signal-1',
            sourceType: 'library_saved',
            content: '',
            createdAt: DateTime.now(),
            acknowledgement:
                'You can adapt this shared signal into your own words.',
            rawPayloadJson: const {
              'library_pattern_id': 'over_scheduled_weeks',
              'title': 'Over-scheduled weeks',
              'abstract_pattern':
                  'Some people encounter a similar structure when the week has many fixed commitments and very little space between them.',
            },
            privacyLevel: 'private',
            userConfirmation: 'unconfirmed',
          ),
        ],
      },
    );

    final meVm = await buildMeViewModel();

    await tester.pumpWidget(
      buildTestApp(
        child: const TodayPage(),
        providers: [
          ChangeNotifierProvider<TodayViewModel>(
            create: (_) => TodayViewModel(repo),
          ),
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
      ),
    );

    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.textContaining('Saved from Library'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Saved from Library'), findsWidgets);
    expect(find.textContaining('Over-scheduled weeks'), findsWidgets);
    expect(find.text('From Library'), findsWidgets);
    expect(find.text('Adapted'), findsWidgets);
    expect(find.textContaining('you have this problem'), findsNothing);
  });

  testWidgets('Today 内嵌高保真手账时间线', (tester) async {
    final repo = StubTodayRepository(
      fetchTodayResult: {
        'insight': TodayInsightModel(text: '今天可以先这样看。'),
        'pendingQuestion': null,
        'bestAction': DailyBestActionModel(text: '先留下一点余地。'),
        'recentSignals': <RecentSignalModel>[],
      },
    );
    final meVm = await buildMeViewModel();

    await tester.pumpWidget(
      buildTestApp(
        child: const TodayPage(),
        providers: [
          ChangeNotifierProvider<TodayViewModel>(
            create: (_) => TodayViewModel(repo),
          ),
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Today timeline'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byTooltip('Open diary'), findsNothing);
    expect(find.text('Today timeline'), findsOneWidget);
    expect(find.byKey(const ValueKey('today-timeline-empty')), findsOneWidget);
    expect(
        find.text('I did not want to reply to messages today.'), findsNothing);
  });

  testWidgets('Today 只显示已采纳的本周小实验，不再显示下周规划卡', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const mountedExperiment = LifeExperimentModel(
      id: 'mounted-exp-1',
      localUserId: 'local',
      sourceWeekStart: '2026-06-22',
      sourceWeekEnd: '2026-06-28',
      title: '先让恢复发生',
      hypothesis: '晚上先有一个恢复动作，会更容易继续。',
      suggestedAction: '睡前 10 分钟不看手机，只做拉伸或写一句观察。',
      linkedSignalCardIds: ['sig-1'],
      status: 'saved',
    );

    final repo = StubTodayRepository(
      fetchTodayResult: {
        'insight': TodayInsightModel(text: '今天可以先这样看。'),
        'pendingQuestion': null,
        'bestAction': DailyBestActionModel(text: '先留下一点余地。'),
        'recentSignals': <RecentSignalModel>[],
        'todayLifeExperiment': mountedExperiment,
      },
    );
    final meVm = await buildMeViewModel();

    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        child: const TodayPage(),
        providers: [
          ChangeNotifierProvider<TodayViewModel>(
            create: (_) => TodayViewModel(repo),
          ),
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('本周小实验'), findsOneWidget);
    expect(find.text('先让恢复发生'), findsOneWidget);
    expect(
      find.text('睡前 10 分钟不看手机，只做拉伸或写一句观察。'),
      findsOneWidget,
    );
    expect(find.text('本周小实验今日建议'), findsNothing);
    expect(find.text('下周小实验计划正在形成'), findsNothing);
    expect(repo.submittedLifeExperimentFeedbacks, isEmpty);
  });

  testWidgets('Today 底部只保留底栏安全间距，不再留大片空白', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = StubTodayRepository(
      fetchTodayResult: {
        'insight': TodayInsightModel(text: '今天可以先这样看。'),
        'pendingQuestion': null,
        'bestAction': DailyBestActionModel(text: '先留下一点余地。'),
        'recentSignals': <RecentSignalModel>[],
      },
    );
    final meVm = await buildMeViewModel();

    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        child: const TodayPage(),
        providers: [
          ChangeNotifierProvider<TodayViewModel>(
            create: (_) => TodayViewModel(repo),
          ),
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final list = tester.widget<ListView>(
      find.byKey(const ValueKey('today-scroll-view')),
    );
    final padding = list.padding! as EdgeInsets;
    expect(padding.bottom, 96);
    expect(padding.bottom, lessThan(148));
    expect(find.text('下周小实验计划正在形成'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('手帐时间线按时间顺序展示记录', (tester) async {
    final now = DateTime.now();
    final today = _dateKey(now);
    final yesterday = _dateKey(now.subtract(const Duration(days: 1)));
    final repo = StubTodayRepository(
      fetchTodayResult: {
        'insight': TodayInsightModel(text: '今天可以先这样看。'),
        'pendingQuestion': null,
        'bestAction': DailyBestActionModel(text: '先留下一点余地。'),
        'recentSignals': <RecentSignalModel>[
          RecentSignalModel(
            id: 'today',
            content: '今天的记录',
            createdAt: now,
            localDate: today,
          ),
          RecentSignalModel(
            id: 'yesterday',
            content: '昨天的记录',
            createdAt: now.subtract(const Duration(days: 1)),
            localDate: yesterday,
          ),
        ],
      },
    );

    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        child: const TodayDiaryPage(),
        providers: [
          ChangeNotifierProvider<TodayViewModel>(
            create: (_) => TodayViewModel(repo),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('手帐时间线'), findsOneWidget);
    expect(find.text('今天'), findsWidgets);
    expect(find.text('今天的记录'), findsOneWidget);
    expect(find.text('昨天的记录'), findsNothing);
  });

  testWidgets('手帐时间线信号筛选只显示信号类记录', (tester) async {
    final now = DateTime.now();
    final today = _dateKey(now);
    final repo = StubTodayRepository(
      fetchTodayResult: {
        'insight': TodayInsightModel(text: '今天可以先这样看。'),
        'pendingQuestion': null,
        'bestAction': DailyBestActionModel(text: '先留下一点余地。'),
        'recentSignals': <RecentSignalModel>[
          RecentSignalModel(
            id: 'today-filter-record',
            content: '今天筛选记录',
            createdAt: now,
            localDate: today,
          ),
          RecentSignalModel(
            id: 'action-filter-record',
            sourceType: 'micro_action',
            content: '下班后先休息 10 分钟',
            createdAt: now.add(const Duration(minutes: 1)),
            localDate: today,
          ),
        ],
      },
    );

    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        child: const TodayDiaryPage(),
        providers: [
          ChangeNotifierProvider<TodayViewModel>(
            create: (_) => TodayViewModel(repo),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('今天筛选记录'), findsOneWidget);
    expect(find.text('下班后先休息 10 分钟'), findsOneWidget);

    await tester.tap(find.text('记录'));
    await tester.pumpAndSettle();

    expect(find.text('今天筛选记录'), findsOneWidget);
    expect(find.text('下班后先休息 10 分钟'), findsNothing);
  });

  testWidgets('手帐时间线小行动筛选显示 action 记录', (tester) async {
    final now = DateTime.now();
    final today = _dateKey(now);
    final repo = StubTodayRepository(
      fetchTodayResult: {
        'insight': TodayInsightModel(text: '今天可以先这样看。'),
        'pendingQuestion': null,
        'bestAction': DailyBestActionModel(text: '先留下一点余地。'),
        'recentSignals': <RecentSignalModel>[
          RecentSignalModel(
            id: 'signal-record',
            sourceType: 'text',
            content: '一早就有点赶',
            createdAt: now,
            localDate: today,
          ),
          RecentSignalModel(
            id: 'micro-action-record',
            sourceType: 'micro_action',
            content: '下班后先休息 10 分钟',
            createdAt: now.add(const Duration(minutes: 1)),
            localDate: today,
            rawPayloadJson: {'feedback': 'done'},
          ),
        ],
      },
    );

    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        child: const TodayDiaryPage(),
        providers: [
          ChangeNotifierProvider<TodayViewModel>(
            create: (_) => TodayViewModel(repo),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('小行动'));
    await tester.pumpAndSettle();

    expect(find.text('下班后先休息 10 分钟'), findsOneWidget);
    expect(find.text('一早就有点赶'), findsNothing);
    expect(find.text('发生了'), findsOneWidget);
  });

  testWidgets('手帐时间线小行动筛选包含反馈记录', (tester) async {
    final now = DateTime.now();
    final today = _dateKey(now);
    final repo = StubTodayRepository(
      fetchTodayResult: {
        'insight': TodayInsightModel(text: '今天可以先这样看。'),
        'pendingQuestion': null,
        'bestAction': DailyBestActionModel(text: '先留下一点余地。'),
        'recentSignals': <RecentSignalModel>[
          RecentSignalModel(
            id: 'text-source-record',
            sourceType: 'text',
            content: '文字来源记录',
            createdAt: now,
            localDate: today,
          ),
          RecentSignalModel(
            id: 'feedback-record',
            sourceType: 'feedback',
            content: '发生了，有帮助，晚上没有那么空转。',
            createdAt: now.add(const Duration(minutes: 1)),
            localDate: today,
          ),
        ],
      },
    );

    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        child: const TodayDiaryPage(),
        providers: [
          ChangeNotifierProvider<TodayViewModel>(
            create: (_) => TodayViewModel(repo),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('小行动').first);
    await tester.pumpAndSettle();

    expect(find.text('发生了，有帮助，晚上没有那么空转。'), findsOneWidget);
    expect(find.text('文字来源记录'), findsNothing);
  });

  testWidgets('本地优先状态不再暴露手动同步按钮', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fetchResult = <String, dynamic>{
      'insight': TodayInsightModel(text: '原文已经保存。'),
      'pendingQuestion': null,
      'bestAction': DailyBestActionModel(text: '网络稳定后再整理也来得及。'),
      'recentSignals': <RecentSignalModel>[
        RecentSignalModel(
          id: 'draft_1',
          sourceType: 'text',
          content: '不想上班',
          createdAt: DateTime.now(),
          isLocalDraft: true,
          syncFailed: true,
        ),
      ],
    };
    final repo = StubTodayRepository(
      fetchTodayResult: fetchResult,
      onRetryPendingDrafts: () async {
        fetchResult['recentSignals'] = <RecentSignalModel>[];
      },
    );
    final meVm = await buildMeViewModel();

    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        child: const TodayPage(),
        providers: [
          ChangeNotifierProvider<TodayViewModel>(
            create: (_) => TodayViewModel(repo),
          ),
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('today-sync-action')), findsNothing);
    expect(find.text('同步'), findsNothing);
    expect(find.text('今天过得怎么样？'), findsOneWidget);
    expect(find.text('今日时间线'), findsOneWidget);
    expect(repo.retryPendingDraftsCallCount, 0);
  });

  testWidgets('Today 不显示无目的趋势/查看全部入口，空输入保存只聚焦输入框', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = StubTodayRepository(
      fetchTodayResult: {
        'insight': TodayInsightModel(text: '今天可以先这样看。'),
        'pendingQuestion': null,
        'bestAction': DailyBestActionModel(text: '先留下一点余地。'),
        'recentSignals': <RecentSignalModel>[],
      },
    );
    final meVm = await buildMeViewModel();

    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        child: const TodayPage(),
        providers: [
          ChangeNotifierProvider<TodayViewModel>(
            create: (_) => TodayViewModel(repo),
          ),
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('查看趋势'), findsNothing);
    expect(find.text('今日练习打卡'), findsNothing);
    expect(find.byKey(const ValueKey('today-sync-action')), findsNothing);

    expect(find.text('文字'), findsOneWidget);
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('today-submit-text-action')),
      find.byType(ListView).first,
      const Offset(0, 260),
    );
    await tester.tap(find.byKey(const ValueKey('today-submit-text-action')));
    await tester.pumpAndSettle();

    expect(find.text('先写下一件小事。'), findsNothing);
    expect(tester.testTextInput.isVisible, isTrue);
  });

  testWidgets('AI 对话展开入口目标页可以按 SignalCard id 读取并继续回应', (tester) async {
    final signal = RecentSignalModel(
      id: 'local-1',
      signalCardId: 'sig-1',
      content: '今天不想回消息。',
      createdAt: DateTime(2026, 6, 16, 21, 43),
      acknowledgement: '我注意到你记录了“今天不想回消息”。',
      observation: '不是生气，就是突然不想说话，想一个人待着。',
      emotion: '情绪',
      friction: '回避',
      energyLoad: '偏低',
    );
    final repo = StubTodayRepository(
      fetchTodayResult: {
        'insight': TodayInsightModel(text: '今天可以先这样看。'),
        'pendingQuestion': null,
        'bestAction': DailyBestActionModel(text: '先留下一点余地。'),
        'recentSignals': [signal],
      },
      captureById: {'sig-1': signal},
    );
    final deps = await buildTestDependencies(todayRepository: repo);

    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        child: const TodayDialogPage(captureId: 'sig-1'),
        providers: [
          Provider.value(value: deps),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('没找到这条记录。'), findsNothing);
    expect(find.text('和 AI 聊聊'), findsOneWidget);
    expect(find.text('这条记录'), findsOneWidget);
    expect(find.text('今天不想回消息。'), findsWidgets);
    expect(find.text('再说一点'), findsOneWidget);
    expect(find.text('看看小行动'), findsOneWidget);
    expect(find.text('总结这条'), findsOneWidget);

    await tester.tap(find.text('再说一点'));
    await tester.pumpAndSettle();

    expect(repo.lightDialogMessages, contains('帮我围绕这条记录再多看一点。'));
    await tester.drag(find.byType(ListView), const Offset(0, -220));
    await tester.pumpAndSettle();
    expect(find.text('我会先贴着这条记录看，不急着下结论。'), findsOneWidget);
  });

  testWidgets('Today 不再显示目标练习打卡区', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = StubTodayRepository(
      fetchTodayResult: {
        'insight': TodayInsightModel(text: '今天可以先这样看。'),
        'pendingQuestion': null,
        'bestAction': DailyBestActionModel(text: '先留下一点余地。'),
        'recentSignals': <RecentSignalModel>[],
        'activeGoals': const [
          {'id': 'legacy-goal'},
        ],
        'goalTasks': const [
          {'id': 'legacy-goal-task'},
        ],
        'goalProgress': const [
          {'goal_id': 'legacy-goal', 'completed_days': 0},
        ],
      },
    );
    final meVm = await buildMeViewModel();

    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        child: const TodayPage(),
        providers: [
          ChangeNotifierProvider<TodayViewModel>(
            create: (_) => TodayViewModel(repo),
          ),
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('今日小行动'), findsOneWidget);
    expect(find.text('今日练习打卡'), findsNothing);
    expect(
        find.byKey(const ValueKey('goal-practice-checkin-card')), findsNothing);
  });

  testWidgets('语音识别 sheet 的暂停、停止、关闭和保存按钮可响应', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = StubTodayRepository(
      fetchTodayResult: {
        'insight': TodayInsightModel(text: '今天可以先这样看。'),
        'pendingQuestion': null,
        'bestAction': DailyBestActionModel(text: '先留下一点余地。'),
        'recentSignals': <RecentSignalModel>[],
      },
    );
    final meVm = await buildMeViewModel();
    final startSpeechArguments = <Object?>[];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('signalpath/speech'),
      (call) async {
        if (call.method == 'startVoiceRecognition') {
          startSpeechArguments.add(call.arguments);
          return null;
        }
        if (call.method == 'stopVoiceRecognition') {
          return '今天骑马很开心，想把这种轻松留下来。';
        }
        if (call.method == 'cancelVoiceRecognition') return null;
        return null;
      },
    );
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('signalpath/speech'),
        null,
      );
    });

    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        child: const TodayPage(),
        providers: [
          ChangeNotifierProvider<TodayViewModel>(
            create: (_) => TodayViewModel(repo),
          ),
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('语音'));
    await tester.pumpAndSettle();

    expect(find.text('准备录音'), findsOneWidget);
    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('开始录音'), findsOneWidget);
    expect(find.text('识别内容'), findsOneWidget);

    await tester
        .tap(find.byKey(const ValueKey('voice-start-recording-action')));
    await tester.pumpAndSettle();

    expect(
      startSpeechArguments.single,
      containsPair('localeIdentifier', 'zh-CN'),
    );
    expect(find.text('正在录音'), findsOneWidget);
    expect(find.text('完成录音'), findsOneWidget);

    await tester.tap(find.text('暂停'));
    await tester.pumpAndSettle();

    expect(find.text('已暂停'), findsWidgets);
    expect(find.text('继续'), findsOneWidget);

    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();

    expect(find.text('正在录音'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('voice-stop-edit-action')));
    await tester.pumpAndSettle();

    await tester
        .tap(find.byKey(const ValueKey('voice-save-transcript-action')));
    await tester.pumpAndSettle();

    expect(repo.submittedCaptures, hasLength(1));
    expect(repo.submittedCaptures.single['content'], '今天骑马很开心，想把这种轻松留下来。');
    expect(repo.submittedCaptures.single['sourceType'], 'voice');
    expect(
      repo.submittedCaptures.single['rawPayloadJson'],
      containsPair('audio_uploaded', false),
    );

    await tester.tap(find.text('语音'));
    await tester.pumpAndSettle();

    await tester
        .tap(find.byKey(const ValueKey('voice-start-recording-action')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('voice-stop-edit-action')));
    await tester.pumpAndSettle();

    expect(find.text('先存草稿'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('voice-skip-action')));
    await tester.pumpAndSettle();

    expect(find.text('语音记录'), findsNothing);
    expect(repo.submittedCaptures, hasLength(1));
    expect(repo.savedDraftCaptures, isEmpty);
  });

  testWidgets('Today 展示时间安排入口，但仍隐藏 legacy Schedule 数据', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime.now();
    final localDate = now.toIso8601String().split('T').first;
    final repo = StubTodayRepository(
      fetchTodayResult: {
        'insight': TodayInsightModel(text: '今天可以先这样看。'),
        'pendingQuestion': null,
        'bestAction': DailyBestActionModel(text: '先留下一点余地。'),
        'recentSignals': <RecentSignalModel>[
          RecentSignalModel(
            id: 'visible-signal',
            sourceType: 'text',
            content: '这是一条真实信号',
            createdAt: now,
            localDate: localDate,
          ),
          RecentSignalModel(
            id: 'legacy-schedule-signal',
            sourceType: 'manual_schedule',
            content: '不应展示的旧安排信号',
            createdAt: now,
            localDate: localDate,
          ),
        ],
        'scheduleSignals': const <Map<String, Object?>>[
          {'id': 'legacy-schedule', 'title': '不应展示的旧安排'},
        ],
      },
    );
    final meVm = await buildMeViewModel();

    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        child: const TodayPage(),
        providers: [
          ChangeNotifierProvider<TodayViewModel>(
            create: (_) => TodayViewModel(repo),
          ),
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('today-schedule-action')),
      findsOneWidget,
    );
    expect(find.text('语音'), findsOneWidget);
    expect(find.text('状态'), findsOneWidget);
    expect(find.text('信号库'), findsOneWidget);
    expect(find.text('这是一条真实信号'), findsOneWidget);
    expect(find.text('不应展示的旧安排信号'), findsNothing);
    expect(find.text('不应展示的旧安排'), findsNothing);
  });

  testWidgets('安排保存为结构化 time_use Signal Card', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = StubTodayRepository(
      fetchTodayResult: {
        'insight': TodayInsightModel(text: '今天可以先这样看。'),
        'pendingQuestion': null,
        'bestAction': DailyBestActionModel(text: '先留下一点余地。'),
        'recentSignals': <RecentSignalModel>[],
      },
    );
    final meVm = await buildMeViewModel();
    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        child: const TodayPage(),
        providers: [
          ChangeNotifierProvider<TodayViewModel>(
            create: (_) => TodayViewModel(repo),
          ),
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('today-schedule-action')));
    await tester.pumpAndSettle();
    expect(find.text('这段时间用在了哪里？'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('time-use-title-field')),
      '团队会议',
    );
    await tester.drag(
      find.byKey(const ValueKey('time-use-sheet-scroll')),
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('time-use-save-action')));
    await tester.pumpAndSettle();

    expect(repo.submittedCaptures, hasLength(1));
    final submitted = repo.submittedCaptures.single;
    expect(submitted['sourceType'], 'time_use');
    final payload = submitted['rawPayloadJson'] as Map<String, dynamic>;
    expect(payload['timeline_type'], 'time_use');
    expect(payload['title'], '团队会议');
    expect(payload['category'], 'work');
    expect(payload['duration_minutes'], greaterThan(0));
    expect(payload['start_at'], isNotNull);
    expect(payload['end_at'], isNotNull);
  });

  testWidgets('状态 sheet 提供正向中性和负面选项，并保存为 one_tap Signal', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = StubTodayRepository(
      fetchTodayResult: {
        'insight': TodayInsightModel(text: '今天可以先这样看。'),
        'pendingQuestion': null,
        'bestAction': DailyBestActionModel(text: '先留下一点余地。'),
        'recentSignals': <RecentSignalModel>[],
      },
    );
    final meVm = await buildMeViewModel();

    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        child: const TodayPage(),
        providers: [
          ChangeNotifierProvider<TodayViewModel>(
            create: (_) => TodayViewModel(repo),
          ),
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('today-status-action')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('today-status-action')));
    await tester.pumpAndSettle();

    expect(find.text('状态记录'), findsOneWidget);
    expect(find.text('此刻状态'), findsOneWidget);
    expect(find.text('平静'), findsOneWidget);
    expect(find.text('开心'), findsOneWidget);
    expect(find.text('疲惫'), findsOneWidget);
    expect(find.text('焦虑'), findsOneWidget);
    expect(find.text('混乱'), findsOneWidget);
    expect(find.text('补一句（可选）'), findsOneWidget);
    expect(find.text('补一句观察（可选）'), findsNothing);

    await tester.tap(find.text('开心'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('很足'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      '今天下午开始有点紧，脑子转不动。',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('保存为今天的信号'));
    await tester.pumpAndSettle();

    expect(repo.submittedCaptures, hasLength(1));
    expect(repo.submittedCaptures.single['sourceType'], 'one_tap');
    expect(
      repo.submittedCaptures.single['content'],
      contains('现在感觉还不错。'),
    );
    expect(
      repo.submittedCaptures.single['content'],
      contains('精力很足'),
    );
    expect(
      repo.submittedCaptures.single['content'],
      contains('今天下午开始有点紧，脑子转不动。'),
    );
    expect(
      repo.submittedCaptures.single['rawPayloadJson'],
      containsPair('quick_status', 'good'),
    );
    expect(repo.submittedCaptures.single['rawPayloadJson'],
        isNot(contains('detail')));
    expect(
      repo.submittedCaptures.single['rawPayloadJson'],
      containsPair('energy_level', 2),
    );
    expect(
      repo.submittedCaptures.single['rawPayloadJson'],
      containsPair('note', '今天下午开始有点紧，脑子转不动。'),
    );

    await tester.scrollUntilVisible(
      find.textContaining('现在感觉还不错。'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('现在感觉还不错。'), findsOneWidget);
    expect(find.text('这个状态已经放进你的手帐时间线。'), findsOneWidget);
  });
}

String _dateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
