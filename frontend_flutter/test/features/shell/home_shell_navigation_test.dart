import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:ai_opportunity_radar/app/app_router.dart';
import 'package:ai_opportunity_radar/core/models/phase3_plus_models.dart';
import 'package:ai_opportunity_radar/core/state/app_data_refresh_coordinator.dart';
import 'package:ai_opportunity_radar/features/pages/today/today_view_model.dart';
import 'package:ai_opportunity_radar/features/shell/home_shell_page.dart';

import '../../helpers/widget_test_helpers.dart';

void main() {
  testWidgets('notification resume consumes the Today destination once',
      (tester) async {
    const notifications = MethodChannel('signalpath/local_notifications');
    var pendingToday = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notifications, (call) async {
      if (call.method != 'consumeSignalReminderDestination') return null;
      if (!pendingToday) return null;
      pendingToday = false;
      return 'today';
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(notifications, null);
    });

    final router = GoRouter(
      initialLocation: AppRoutes.weekly,
      routes: [
        ShellRoute(
          builder: (_, __, child) => HomeShellPage(child: child),
          routes: [
            _testRoute(AppRoutes.today, 'today page'),
            _testRoute(AppRoutes.weekly, 'weekly page'),
            _testRoute(AppRoutes.experiment, 'experiment page'),
            _testRoute(AppRoutes.memory, 'journey page'),
            _testRoute(AppRoutes.signalLibrary, 'library page'),
            _testRoute(AppRoutes.me, 'me page'),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('weekly page'), findsOneWidget);

    pendingToday = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('today page'), findsOneWidget);
    expect(pendingToday, isFalse);
  });

  testWidgets('five-tab shell keeps existing tabs and opens Life Experiment',
      (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;

    final router = GoRouter(
      initialLocation: AppRoutes.today,
      routes: [
        ShellRoute(
          builder: (_, __, child) => HomeShellPage(child: child),
          routes: [
            _testRoute(AppRoutes.today, 'today page'),
            _testRoute(AppRoutes.weekly, 'weekly page'),
            _testRoute(AppRoutes.experiment, 'experiment page'),
            _testRoute(AppRoutes.memory, 'journey page'),
            _testRoute(AppRoutes.signalLibrary, 'library page'),
            _testRoute(AppRoutes.me, 'me page'),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Weekly'), findsOneWidget);
    expect(find.text('Journey'), findsOneWidget);
    expect(find.text('Life Experiment'), findsOneWidget);
    expect(find.text('Me'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Life Experiment'));
    await tester.pumpAndSettle();

    expect(find.text('experiment page'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Weekly'), findsOneWidget);
    expect(find.text('Journey'), findsOneWidget);
    expect(find.text('Me'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'dirty route refreshes on entry and active route refreshes on resume',
      (tester) async {
    final mutations = StreamController<AppDataMutation>.broadcast(sync: true);
    var todayLoads = 0;
    var weeklyLoads = 0;
    final coordinator = AppDataRefreshCoordinator(
      mutationStream: mutations.stream,
      routeLoaders: {
        AppRoutes.today: () async {
          todayLoads += 1;
        },
        AppRoutes.weekly: () async {
          weeklyLoads += 1;
        },
      },
    );
    addTearDown(() async {
      coordinator.dispose();
      await mutations.close();
    });

    final router = GoRouter(
      initialLocation: AppRoutes.today,
      routes: [
        ShellRoute(
          builder: (_, __, child) => HomeShellPage(child: child),
          routes: [
            _testRoute(AppRoutes.today, 'today page'),
            _testRoute(AppRoutes.weekly, 'weekly page'),
            _testRoute(AppRoutes.experiment, 'experiment page'),
            _testRoute(AppRoutes.memory, 'journey page'),
            _testRoute(AppRoutes.signalLibrary, 'library page'),
            _testRoute(AppRoutes.me, 'me page'),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      Provider<AppDataRefreshCoordinator>.value(
        value: coordinator,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(todayLoads, 0);

    mutations.add(const AppDataMutation(
      kind: AppDataMutationKind.focusDomains,
      reason: 'focus_changed',
    ));
    await tester.tap(find.text('Weekly'));
    await tester.pumpAndSettle();
    expect(weeklyLoads, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(weeklyLoads, 2);
    expect(todayLoads, 0);

    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    expect(todayLoads, 1);

    await tester.tap(find.text('Weekly'));
    await tester.pumpAndSettle();
    expect(weeklyLoads, 3);
  });

  testWidgets(
      'Today -> Weekly -> Today starts a fresh three-replacement AI session',
      (tester) async {
    const initialJudgement = AiJudgementModel(
      id: 'route-session-prediction',
      sourceSignalCardIds: ['signal-1'],
      localDate: '2026-07-16',
      judgementText: 'Initial prediction',
      evidenceText: 'Based on one saved signal.',
      predictedSignalText: 'Initial prediction',
      suggestedPattern: 'initial',
      suggestedLifeChainStage: 'daily_pattern',
    );
    final repository = StubTodayRepository(
      fetchTodayResult: <String, dynamic>{
        'aiJudgement': initialJudgement,
      },
    );
    final viewModel = TodayViewModel(repository);
    addTearDown(viewModel.dispose);
    await viewModel.load();

    // Consume all three replacements and reject the third replacement so the
    // first page visit reaches its exhausted state.
    for (var index = 0; index < 4; index++) {
      final current = viewModel.state.aiJudgement;
      expect(current, isNotNull);
      await viewModel.showAnotherAiJudgement(judgement: current!);
    }
    expect(viewModel.state.aiJudgementExhausted, isTrue);
    expect(repository.aiJudgementGenerationVariants, [1, 2, 3]);

    final coordinator = AppDataRefreshCoordinator(
      routeLoaders: {
        AppRoutes.today: viewModel.load,
        AppRoutes.weekly: () async {},
      },
    );
    addTearDown(coordinator.dispose);
    final router = GoRouter(
      initialLocation: AppRoutes.today,
      routes: [
        ShellRoute(
          builder: (_, __, child) => HomeShellPage(child: child),
          routes: [
            _testRoute(AppRoutes.today, 'today page'),
            _testRoute(AppRoutes.weekly, 'weekly page'),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TodayViewModel>.value(value: viewModel),
          Provider<AppDataRefreshCoordinator>.value(value: coordinator),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weekly'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();

    expect(viewModel.state.aiJudgementExhausted, isFalse);
    expect(
        viewModel.state.aiJudgement?.predictedSignalText, 'Initial prediction');

    for (var index = 0; index < 3; index++) {
      final current = viewModel.state.aiJudgement;
      expect(current, isNotNull);
      await viewModel.showAnotherAiJudgement(judgement: current!);
    }
    expect(viewModel.state.aiJudgementExhausted, isFalse);
    expect(
      repository.aiJudgementGenerationVariants,
      [1, 2, 3, 1, 2, 3],
    );
    expect(repository.aiJudgementResponses, isEmpty);
  });

  testWidgets('compact bottom navigation remains usable in all app languages',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const cases = <(Locale, List<String>)>[
      (Locale('en'), ['Today', 'Weekly', 'Life Experiment', 'Journey', 'Me']),
      (Locale('ja'), ['今日', '週間レビュー', '生活実験', 'Journey', 'マイ']),
      (
        Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
        ['今天', '每周复盘', '生活小实验', '旅程', '我的'],
      ),
      (
        Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        ['今天', '每週復盤', '生活小實驗', '旅程', '我的'],
      ),
    ];

    for (final entry in cases) {
      final router = _buildShellRouter();
      await tester.pumpWidget(
        MaterialApp.router(
          locale: entry.$1,
          supportedLocales: cases.map((item) => item.$1),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.3),
            ),
            child: child!,
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final label in entry.$2) {
        expect(find.text(label), findsOneWidget);
        final rect = tester.getRect(find.text(label));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320));
      }
      expect(find.text('Schedule'), findsNothing);
      expect(find.text('Goal'), findsNothing);
      expect(find.text('Calendar'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
    }
  });

  test(
      'removed Schedule, Goal and system Calendar paths cannot be QA entry routes',
      () {
    for (final removedPath in const [
      '/schedule',
      '/goal',
      '/calendar',
      '/me/calendar-signals',
    ]) {
      expect(resolvedInitialRoute(removedPath), AppRoutes.today);
    }
  });
}

GoRouter _buildShellRouter() {
  return GoRouter(
    initialLocation: AppRoutes.today,
    routes: [
      ShellRoute(
        builder: (_, __, child) => HomeShellPage(child: child),
        routes: [
          _testRoute(AppRoutes.today, 'today page'),
          _testRoute(AppRoutes.weekly, 'weekly page'),
          _testRoute(AppRoutes.experiment, 'experiment page'),
          _testRoute(AppRoutes.memory, 'journey page'),
          _testRoute(AppRoutes.signalLibrary, 'library page'),
          _testRoute(AppRoutes.me, 'me page'),
        ],
      ),
    ],
  );
}

GoRoute _testRoute(String path, String label) {
  return GoRoute(
    path: path,
    builder: (_, __) => Scaffold(body: Center(child: Text(label))),
  );
}
