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
import 'package:ai_opportunity_radar/shared/widgets/aurora_ui.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('未达到两个月门槛时仍显示三个月事实图，只隐藏变化总结', (tester) async {
    tester.view.physicalSize = const Size(390, 1800);
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

    expect(find.byType(AuroraJourneyHeroPattern), findsOneWidget);
    expect(
      find.byKey(const ValueKey('journey-pro-three-month-chart')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('journey-pro-energy-state-trend')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('journey-pro-domain-trend')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('journey-pro-three-month-readiness')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('journey-pro-three-month-change')),
      findsNothing,
    );
    expect(find.textContaining('已有 1/2 个自然月可比较'), findsOneWidget);
    expect(find.text('分析范围'), findsNothing);
    expect(find.text('和 AI 聊聊'), findsNothing);
    expect(find.textContaining('来源 Signal'), findsNothing);
    expect(repository.requestedMonths, ['2026-07']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('至少两个自然月达标后显示保守的月度变化总结', (tester) async {
    tester.view.physicalSize = const Size(390, 1900);
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

    expect(
      find.byKey(const ValueKey('journey-pro-three-month-change')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('journey-pro-three-month-readiness')),
      findsNothing,
    );
    expect(find.text('最近一个月的变化'), findsOneWidget);
    expect(find.textContaining('不推断因果'), findsWidgets);
    expect(
      find.byKey(const ValueKey('journey-pro-context-coverage')),
      findsNothing,
    );
    expect(find.textContaining('资料范围'), findsNothing);
    expect(find.text('生活小实验'), findsNothing);
    expect(find.text('目标'), findsNothing);
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

    expect(find.text('Three-month change failed to load'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(repository.requestedMonths, ['2026-05']);
  });

  testWidgets('Pro 路由保留付费门槛，并把 month 查询参数传给三个月页面', (tester) async {
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
    periodStart: '2026-05-01',
    periodEnd: '2026-07-22',
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
      _month(
        key: '2026-05',
        signals: ready ? 8 : 3,
        days: ready ? 4 : 2,
        draining: 2,
        steady: 1,
        recovery: ready ? 5 : 0,
        work: ready ? 5 : 2,
        recoveryDomain: ready ? 3 : 1,
      ),
      _month(
        key: '2026-06',
        signals: 9,
        days: 5,
        draining: 4,
        steady: 3,
        recovery: 2,
        work: 7,
        recoveryDomain: 2,
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
        end: '2026-07-22',
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
