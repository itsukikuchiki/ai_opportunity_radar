import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_opportunity_radar/app/app_router.dart';
import 'package:ai_opportunity_radar/core/models/journey_pro_models.dart';
import 'package:ai_opportunity_radar/core/purchases/purchase_controller.dart';
import 'package:ai_opportunity_radar/core/state/app_bootstrap_state.dart';
import 'package:ai_opportunity_radar/features/pages/memory/journey_pro_page.dart';
import 'package:ai_opportunity_radar/features/pages/memory/journey_pro_view_model.dart';
import 'package:ai_opportunity_radar/features/shell/main_tab_bottom_navigation.dart';
import 'package:ai_opportunity_radar/shared/widgets/aurora_ui.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('只有一个有记录月份且未达总结门槛时仍显示首次使用至今的事实时间轴', (tester) async {
    tester.view.physicalSize = const Size(390, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = StubJourneyProRepository(report: _report(ready: false));
    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        child: const JourneyProPage(initialMonthKey: '2026-07'),
        providers: [
          ChangeNotifierProvider<JourneyProViewModel>(
            create: (_) => JourneyProViewModel(repository),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MainTabBottomNavigation), findsOneWidget);
    expect(
      find.byKey(MainTabBottomNavigation.navigationKey),
      findsOneWidget,
    );
    expect(
      tester
          .widget<MainTabBottomNavigation>(
            find.byType(MainTabBottomNavigation),
          )
          .selectedIndex,
      3,
    );
    expect(find.byType(AuroraJourneyHeroPattern), findsOneWidget);
    expect(
      find.byKey(const ValueKey('journey-pro-full-history-hero')),
      findsOneWidget,
    );
    expect(
      tester
              .getBottomLeft(
                find.byKey(const ValueKey('journey-pro-full-history-hero')),
              )
              .dy -
          tester
              .getBottomLeft(
                find.byKey(const ValueKey('journey-pro-history-period')),
              )
              .dy,
      lessThanOrEqualTo(17),
    );
    expect(
      find.byKey(const ValueKey('journey-pro-history-overview')),
      findsOneWidget,
    );
    final scrollable = find
        .descendant(
          of: find.byKey(const ValueKey('journey-pro-scroll-view')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('journey-pro-domain-history')),
      280,
      scrollable: scrollable,
    );
    expect(
      find.byKey(const ValueKey('journey-pro-domain-history')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('journey-pro-theme-history')),
      280,
      scrollable: scrollable,
    );
    expect(
      find.byKey(const ValueKey('journey-pro-theme-history')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('journey-pro-theme-history')),
        matching: find.text('其他线索'),
      ),
      findsNothing,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('journey-pro-energy-rhythm-history')),
      280,
      scrollable: scrollable,
    );
    expect(
      find.byKey(const ValueKey('journey-pro-energy-rhythm-history')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('journey-pro-history-conclusion')),
      280,
      scrollable: scrollable,
    );
    expect(
      find.byKey(const ValueKey('journey-pro-history-conclusion')),
      findsOneWidget,
    );
    expect(find.textContaining('真实时间轴已经显示'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('journey-pro-three-month-chart')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('journey-pro-three-month-readiness')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('journey-pro-three-month-change')),
      findsNothing,
    );
    expect(find.text('分析范围'), findsNothing);
    expect(find.text('和 AI 聊聊'), findsNothing);
    expect(find.textContaining('来源 Signal'), findsNothing);
    expect(repository.requestedMonths, ['2026-07']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('只有一个完整月份时图表点与月份轴居中对齐', (tester) async {
    tester.view.physicalSize = const Size(390, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = StubJourneyProRepository(
      report: JourneyProReportModel(
        selectedMonthKey: '2026-07',
        periodStart: '2026-07-01',
        periodEnd: '2026-07-31',
        sourceHash: 'single-complete-month',
        contextCoverage: const JourneyProContextCoverageModel(
          feedbackCount: 0,
          reviewCount: 0,
          experimentContextCount: 0,
          observationCount: 0,
        ),
        months: [
          _month(
            key: '2026-07',
            signals: 8,
            days: 4,
            draining: 2,
            steady: 3,
            recovery: 3,
            work: 5,
            recoveryDomain: 3,
          ),
        ],
      ),
    );
    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        child: const JourneyProPage(initialMonthKey: '2026-07'),
        providers: [
          ChangeNotifierProvider<JourneyProViewModel>(
            create: (_) => JourneyProViewModel(repository),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final card = find.byKey(const ValueKey('journey-pro-domain-history'));
    final scrollable = find
        .descendant(
          of: find.byKey(const ValueKey('journey-pro-scroll-view')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(card, 280, scrollable: scrollable);
    final chart = find.descendant(of: card, matching: find.byType(CustomPaint));
    final monthLabel = find.descendant(of: card, matching: find.text('7月'));

    expect(chart, findsOneWidget);
    expect(monthLabel, findsOneWidget);
    final chartSize = tester.getSize(chart);
    final plot =
        Rect.fromLTRB(10, 10, chartSize.width - 8, chartSize.height - 24);
    expect(
      journeyHistoryLinePointX(plot: plot, index: 0, pointCount: 1),
      plot.center.dx,
    );
    expect(
      (tester.getCenter(chart).dx - tester.getCenter(monthLabel).dx).abs(),
      lessThanOrEqualTo(2),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('多个有记录月份时显示完整时间轴回看', (tester) async {
    tester.view.physicalSize = const Size(390, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = StubJourneyProRepository(report: _report(ready: true));
    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        child: const JourneyProPage(initialMonthKey: '2026-07'),
        providers: [
          ChangeNotifierProvider<JourneyProViewModel>(
            create: (_) => JourneyProViewModel(repository),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = find
        .descendant(
          of: find.byKey(const ValueKey('journey-pro-scroll-view')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('journey-pro-history-conclusion')),
      320,
      scrollable: scrollable,
    );
    expect(find.text('完整时间轴回看'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('journey-pro-history-conclusion')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('journey-pro-context-coverage')),
      findsNothing,
    );
    expect(find.textContaining('资料范围'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('journey-pro-scroll-view')),
        matching: find.text('生活小实验'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('journey-pro-scroll-view')),
        matching: find.text('目标'),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pro 页面不显示分析范围或资料范围区块', (tester) async {
    tester.view.physicalSize = const Size(390, 1900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = StubJourneyProRepository(
      report: _report(ready: true, withContext: false),
    );
    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        child: const JourneyProPage(initialMonthKey: '2026-07'),
        providers: [
          ChangeNotifierProvider<JourneyProViewModel>(
            create: (_) => JourneyProViewModel(repository),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('journey-pro-context-coverage')),
      findsNothing,
    );
    expect(find.textContaining('分析范围'), findsNothing);
    expect(find.textContaining('资料范围'), findsNothing);
  });

  testWidgets('首个自然月尚未结束时说明月底后再显示', (tester) async {
    final repository = StubJourneyProRepository(
      report: const JourneyProReportModel(
        selectedMonthKey: '2026-07',
        periodStart: '2026-07-31',
        periodEnd: '2026-07-31',
        sourceHash: 'no-complete-month',
        months: [],
        contextCoverage: JourneyProContextCoverageModel(
          feedbackCount: 0,
          reviewCount: 0,
          experimentContextCount: 0,
          observationCount: 0,
        ),
      ),
    );
    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        child: const JourneyProPage(initialMonthKey: '2026-07'),
        providers: [
          ChangeNotifierProvider<JourneyProViewModel>(
            create: (_) => JourneyProViewModel(repository),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('首个自然月结束后显示'), findsOneWidget);
    expect(find.text('首个完整月份还在形成中'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('journey-pro-theme-history')),
      findsNothing,
    );
  });

  testWidgets('加载失败显示可重试状态', (tester) async {
    final repository = StubJourneyProRepository(
      report: _report(ready: false),
      loadError: StateError('offline'),
    );
    await tester.pumpWidget(
      buildTestApp(
        child: const JourneyProPage(initialMonthKey: '2026-05'),
        providers: [
          ChangeNotifierProvider<JourneyProViewModel>(
            create: (_) => JourneyProViewModel(repository),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Journey history failed to load'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(repository.requestedMonths, ['2026-05']);
  });

  testWidgets('Pro 路由保留付费门槛，并兼容已有 month 查询参数', (tester) async {
    final freeHarness = await _RouteHarness.create(isPremium: false);
    addTearDown(freeHarness.dispose);
    await tester.pumpWidget(freeHarness.app);
    await tester.pumpAndSettle();

    expect(find.text('Signal Path Pro'), findsOneWidget);
    expect(find.byType(JourneyProPage), findsNothing);
    expect(freeHarness.repository.requestedMonths, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    final proHarness = await _RouteHarness.create(isPremium: true);
    addTearDown(proHarness.dispose);
    await tester.pumpWidget(proHarness.app);
    await tester.pumpAndSettle();

    expect(find.byType(JourneyProPage), findsOneWidget);
    expect(proHarness.repository.requestedMonths, ['2026-05']);
  });
}

JourneyProReportModel _report({
  required bool ready,
  bool withContext = true,
}) {
  return JourneyProReportModel(
    selectedMonthKey: '2026-07',
    periodStart: '2026-01-01',
    periodEnd: '2026-07-31',
    sourceHash: ready ? 'ready-source' : 'forming-source',
    contextCoverage: withContext
        ? const JourneyProContextCoverageModel(
            feedbackCount: 4,
            reviewCount: 2,
            experimentContextCount: 2,
            observationCount: 3,
          )
        : const JourneyProContextCoverageModel(
            feedbackCount: 0,
            reviewCount: 0,
            experimentContextCount: 0,
            observationCount: 0,
          ),
    months: [
      for (final monthKey in const [
        '2026-01',
        '2026-02',
        '2026-03',
        '2026-04',
      ])
        _month(
          key: monthKey,
          signals: 0,
          days: 0,
          draining: 0,
          steady: 0,
          recovery: 0,
          work: 0,
          recoveryDomain: 0,
        ),
      _month(
        key: '2026-05',
        signals: ready ? 8 : 0,
        days: ready ? 4 : 0,
        draining: ready ? 2 : 0,
        steady: ready ? 1 : 0,
        recovery: ready ? 5 : 0,
        work: ready ? 5 : 0,
        recoveryDomain: ready ? 3 : 0,
      ),
      _month(
        key: '2026-06',
        signals: ready ? 9 : 0,
        days: ready ? 5 : 0,
        draining: ready ? 4 : 0,
        steady: ready ? 3 : 0,
        recovery: ready ? 2 : 0,
        work: ready ? 7 : 0,
        recoveryDomain: ready ? 2 : 0,
      ),
      _month(
        key: '2026-07',
        signals: ready ? 11 : 4,
        days: ready ? 6 : 2,
        draining: ready ? 3 : 2,
        steady: ready ? 4 : 1,
        recovery: ready ? 4 : 1,
        work: ready ? 6 : 3,
        recoveryDomain: ready ? 5 : 1,
      ),
    ],
  );
}

JourneyProMonthChangeModel _month({
  required String key,
  required int signals,
  required int days,
  required int draining,
  required int steady,
  required int recovery,
  required int work,
  required int recoveryDomain,
  String? end,
}) {
  final parts = key.split('-');
  final year = int.parse(parts.first);
  final month = int.parse(parts.last);
  final naturalEnd = DateTime(year, month + 1, 0).day;
  return JourneyProMonthChangeModel(
    monthKey: key,
    periodStart: '$key-01',
    periodEnd: end ?? '$key-${naturalEnd.toString().padLeft(2, '0')}',
    signalCount: signals,
    activeDayCount: days,
    energyStateCounts: {
      'draining': draining,
      'steady': steady,
      'ease': 0,
      'recovery': recovery,
      'boundary_buffer': 0,
    },
    domainCounts: {
      'growth_plan': work,
      'emotional_stability': recoveryDomain,
    },
    themeCounts: {
      'food_sleep': recovery,
      'growth_plan': signals - recovery,
    },
  );
}

class _RouteHarness {
  final StubJourneyProRepository repository;
  final JourneyProViewModel viewModel;
  final PurchaseController purchaseController;
  final dynamic router;
  final Widget app;

  _RouteHarness._({
    required this.repository,
    required this.viewModel,
    required this.purchaseController,
    required this.router,
    required this.app,
  });

  static Future<_RouteHarness> create({required bool isPremium}) async {
    SharedPreferences.setMockInitialValues({'onboarding_completed': true});
    final bootstrap = AppBootstrapState();
    await bootstrap.prepareLaunch();
    final router = createAppRouter(bootstrap)
      ..go('${AppRoutes.journeyPro}?month=2026-05');
    final purchase = PurchaseController(storeSupported: false);
    await purchase.init();
    purchase.isPremium = isPremium;
    final repository = StubJourneyProRepository(report: _report(ready: true));
    final viewModel = JourneyProViewModel(repository);
    final app = MultiProvider(
      providers: [
        ChangeNotifierProvider<JourneyProViewModel>.value(value: viewModel),
        ChangeNotifierProvider<PurchaseController?>.value(value: purchase),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        supportedLocales: const [
          Locale('en'),
          Locale('ja'),
          Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
          Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        ],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
      ),
    );
    return _RouteHarness._(
      repository: repository,
      viewModel: viewModel,
      purchaseController: purchase,
      router: router,
      app: app,
    );
  }

  void dispose() {
    viewModel.dispose();
    purchaseController.dispose();
    router.dispose();
  }
}
