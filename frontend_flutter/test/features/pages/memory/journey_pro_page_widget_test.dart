import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_opportunity_radar/app/app_router.dart';
import 'package:ai_opportunity_radar/core/api/repositories/memory_repository.dart';
import 'package:ai_opportunity_radar/core/models/journey_pro_models.dart';
import 'package:ai_opportunity_radar/core/models/memory_models.dart';
import 'package:ai_opportunity_radar/core/purchases/purchase_controller.dart';
import 'package:ai_opportunity_radar/core/readiness/report_readiness.dart';
import 'package:ai_opportunity_radar/core/state/app_bootstrap_state.dart';
import 'package:ai_opportunity_radar/features/pages/memory/journey_pro_page.dart';
import 'package:ai_opportunity_radar/features/pages/memory/memory_view_model.dart';
import 'package:ai_opportunity_radar/shared/widgets/aurora_ui.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Pro L3 未达门槛只显示精确进度，不显示报告内容', (tester) async {
    final repo = StubMemoryRepository(
      result: const MemoryFetchResult(
        isFirstDayGate: false,
        summary: null,
        proReadiness: ReportReadiness(
          rule: ReportReadinessEvaluator.journeyProRule,
          signalCount: 5,
          distinctDayCount: 3,
          distinctWeekCount: 1,
        ),
      ),
      proReportResult: _report(
        signalCount: 5,
        dayCount: 3,
        weekCount: 1,
      ),
    );

    await tester.pumpWidget(
      buildTestApp(
        child: const JourneyProPage(),
        providers: [
          ChangeNotifierProvider<MemoryViewModel>(
            create: (_) => MemoryViewModel(repo),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(JourneyProPage), findsOneWidget);
    expect(find.byType(AuroraHeroTitle), findsOneWidget);
    expect(find.byType(AuroraHeroEmblem), findsOneWidget);
    expect(find.textContaining('5/14 eligible SignalCards'), findsOneWidget);
    expect(find.textContaining('3/7 recorded days'), findsOneWidget);
    expect(find.textContaining('1/2 local weeks'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('journey-pro-l3-synthesis')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('journey-pro-period-comparison')),
      findsNothing,
    );
    expect(find.textContaining('not generated'), findsOneWidget);
    expect(repo.proReportCallCount, 1);
  });

  testWidgets('Pro L3 达标后只展示真实 summary、周统计和 SignalCard 证据', (tester) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = StubMemoryRepository(
      result: MemoryFetchResult(
        isFirstDayGate: false,
        summary: MemorySummaryModel(
          patterns: const [
            JourneySignalItemModel(
              name: 'Actual repeated work pattern',
              summary: 'Generated from the current Journey evidence.',
              signalLevel: 'repeated_pattern',
            ),
          ],
          frictions: const [],
          desires: const [],
          experiments: const [],
        ),
        proReadiness: _readyReadiness,
      ),
      proReportResult: _report(
        signalCount: 14,
        dayCount: 7,
        weekCount: 2,
        evidence: const [
          JourneyProEvidenceModel(
            signalId: 'signal-real-1',
            content: 'A real SignalCard about a difficult transition.',
            localDate: '2026-07-12',
            sourceType: 'text',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      buildTestApp(
        child: const JourneyProPage(),
        providers: [
          ChangeNotifierProvider<MemoryViewModel>(
            create: (_) => MemoryViewModel(repo),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('journey-pro-l3-synthesis')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('journey-pro-period-comparison')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('journey-pro-evidence')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('journey-pro-followup')),
      findsOneWidget,
    );
    expect(find.text('Actual repeated work pattern'), findsOneWidget);
    expect(
      find.text('A real SignalCard about a difficult transition.'),
      findsOneWidget,
    );
    expect(find.text('Previous week'), findsOneWidget);
    expect(find.text('Current week to date'), findsOneWidget);
    expect(find.text('Ask from this evidence'), findsOneWidget);
    expect(find.textContaining('Why is recovery difficult'), findsNothing);
  });

  testWidgets('简体中文深度分析本地化分析枚举与证据来源', (tester) async {
    tester.view.physicalSize = const Size(390, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = StubMemoryRepository(
      result: MemoryFetchResult(
        isFirstDayGate: false,
        summary: MemorySummaryModel(
          patterns: const [
            JourneySignalItemModel(
              name: 'work',
              summary: '目前最清楚的是“work”。',
              signalLevel: 'repeated_pattern',
            ),
          ],
          frictions: const [
            JourneySignalItemModel(
              name: '可能的长期消耗',
              summary: '如果“work”继续出现，先保持轻观察。',
              signalLevel: 'repeated_pattern',
            ),
          ],
          desires: const [],
          experiments: const [],
        ),
        proReadiness: _readyReadiness,
      ),
      proReportResult: _report(
        signalCount: 18,
        dayCount: 14,
        weekCount: 3,
        evidence: const [
          JourneyProEvidenceModel(
            signalId: 'localized-evidence',
            content: '一条可追溯的真实记录。',
            localDate: '2026-07-15',
            sourceType: 'text',
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
        child: const JourneyProPage(),
        providers: [
          ChangeNotifierProvider<MemoryViewModel>(
            create: (_) => MemoryViewModel(repo),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('工作'), findsOneWidget);
    expect(find.text('目前最清楚的是“工作”。'), findsOneWidget);
    expect(find.text('如果“工作”继续出现，先保持轻观察。'), findsOneWidget);
    expect(find.text('文字'), findsOneWidget);
    expect(find.text('work'), findsNothing);
    expect(find.text('text'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppRoutes.journeyPro 直接访问时未订阅只能看到付费门槛', (tester) async {
    final harness = await _RouteHarness.create(isPremium: false);
    addTearDown(harness.dispose);

    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    expect(find.text('Signal Path Pro'), findsOneWidget);
    expect(find.byType(JourneyProPage), findsNothing);
    expect(harness.repository.proReportCallCount, 0);
  });

  testWidgets('AppRoutes.journeyPro 已订阅且达标后才进入 L3 页面', (tester) async {
    final harness = await _RouteHarness.create(isPremium: true);
    addTearDown(harness.dispose);

    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    expect(find.byType(JourneyProPage), findsOneWidget);
    expect(
      find.byKey(const ValueKey('journey-pro-l3-synthesis')),
      findsOneWidget,
    );
    expect(harness.repository.proReportCallCount, 1);
  });
}

const _readyReadiness = ReportReadiness(
  rule: ReportReadinessEvaluator.journeyProRule,
  signalCount: 14,
  distinctDayCount: 7,
  distinctWeekCount: 2,
);

JourneyProReportModel _report({
  required int signalCount,
  required int dayCount,
  required int weekCount,
  List<JourneyProEvidenceModel> evidence = const [],
}) {
  return JourneyProReportModel(
    readiness: ReportReadiness(
      rule: ReportReadinessEvaluator.journeyProRule,
      signalCount: signalCount,
      distinctDayCount: dayCount,
      distinctWeekCount: weekCount,
    ),
    periodStart: '2026-06-15',
    periodEnd: '2026-07-12',
    currentWeek: const JourneyProWeekStats(
      weekStart: '2026-07-06',
      weekEnd: '2026-07-12',
      signalCount: 8,
      activeDayCount: 4,
    ),
    previousWeek: const JourneyProWeekStats(
      weekStart: '2026-06-29',
      weekEnd: '2026-07-05',
      signalCount: 6,
      activeDayCount: 3,
    ),
    evidence: evidence,
  );
}

class _RouteHarness {
  final StubMemoryRepository repository;
  final MemoryViewModel memoryViewModel;
  final PurchaseController purchaseController;
  final dynamic router;
  final Widget app;

  _RouteHarness._({
    required this.repository,
    required this.memoryViewModel,
    required this.purchaseController,
    required this.router,
    required this.app,
  });

  static Future<_RouteHarness> create({required bool isPremium}) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_completed': true,
    });
    final bootstrap = AppBootstrapState();
    await bootstrap.prepareLaunch();
    final router = createAppRouter(bootstrap)..go(AppRoutes.journeyPro);
    final purchase = PurchaseController(storeSupported: false);
    await purchase.init();
    purchase.isPremium = isPremium;

    final repository = StubMemoryRepository(
      result: MemoryFetchResult(
        isFirstDayGate: false,
        summary: MemorySummaryModel(
          patterns: const [
            JourneySignalItemModel(
              name: 'Route-backed real pattern',
              summary: 'A stored Journey summary.',
              signalLevel: 'repeated_pattern',
            ),
          ],
          frictions: const [],
          desires: const [],
          experiments: const [],
        ),
        proReadiness: _readyReadiness,
      ),
      proReportResult: _report(
        signalCount: 14,
        dayCount: 7,
        weekCount: 2,
        evidence: const [
          JourneyProEvidenceModel(
            signalId: 'route-signal',
            content: 'Route evidence',
            localDate: '2026-07-12',
            sourceType: 'text',
          ),
        ],
      ),
    );
    final memory = MemoryViewModel(repository);
    final app = MultiProvider(
      providers: [
        ChangeNotifierProvider<MemoryViewModel>.value(value: memory),
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
      memoryViewModel: memory,
      purchaseController: purchase,
      router: router,
      app: app,
    );
  }

  void dispose() {
    memoryViewModel.dispose();
    purchaseController.dispose();
    router.dispose();
  }
}
