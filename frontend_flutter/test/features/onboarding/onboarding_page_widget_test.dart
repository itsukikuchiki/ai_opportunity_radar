import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_opportunity_radar/app/app_router.dart';
import 'package:ai_opportunity_radar/core/api/api_client.dart';
import 'package:ai_opportunity_radar/core/preferences/focus_domains.dart';
import 'package:ai_opportunity_radar/core/state/app_bootstrap_state.dart';
import 'package:ai_opportunity_radar/features/onboarding/onboarding_page.dart';
import 'package:ai_opportunity_radar/features/onboarding/onboarding_view_model.dart';
import 'package:ai_opportunity_radar/features/pages/me/me_page.dart';
import 'package:ai_opportunity_radar/features/pages/me/me_view_model.dart';

import '../../helpers/widget_test_helpers.dart';

void main() {
  testWidgets('start setup persists focus domains and enters Today',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      FocusDomains.productPreferenceKey: FocusDomains.defaultIds,
      FocusDomains.preferenceKey: FocusDomains.defaultIds,
      FocusDomains.legacyRepeatAreaKey: FocusDomains.defaultIds.first,
      FocusDomains.legacySelectedRepeatAreaKey: FocusDomains.defaultIds.first,
    });
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final meViewModel = MeViewModel();
    await meViewModel.load();
    expect(meViewModel.selectedFocusDomainIds, FocusDomains.defaultIds);

    final onboardingViewModel = OnboardingViewModel(
      _FailingApiClient(),
      onFocusDomainsPersisted: meViewModel.applyPersistedFocusDomains,
    );
    final bootstrap = AppBootstrapState();
    final router = GoRouter(
      initialLocation: AppRoutes.onboarding,
      routes: [
        GoRoute(
          path: AppRoutes.onboarding,
          builder: (_, __) => const OnboardingPage(),
        ),
        GoRoute(
          path: AppRoutes.today,
          builder: (_, __) => const Scaffold(body: Text('Today reached')),
        ),
      ],
    );
    addTearDown(meViewModel.dispose);
    addTearDown(onboardingViewModel.dispose);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppBootstrapState>.value(value: bootstrap),
          ChangeNotifierProvider<OnboardingViewModel>.value(
            value: onboardingViewModel,
          ),
          ChangeNotifierProvider<MeViewModel>.value(
            value: meViewModel,
          ),
        ],
        child: MaterialApp.router(
          locale: const Locale.fromSubtags(
            languageCode: 'zh',
            scriptCode: 'Hans',
          ),
          supportedLocales: const [
            Locale('en'),
            Locale('ja'),
            Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
            Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
          ],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(PageView), const Offset(-390, 0));
    await tester.pumpAndSettle();

    expect(find.text('每周看见一个真实模式'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey('onboarding-weekly-experiment-design-preview'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('onboarding-weekly-experiment-icon-background'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('onboarding-life-experiment-bridge-preview'),
      ),
      findsOneWidget,
    );
    expect(find.text('本周行为模式'), findsOneWidget);
    expect(find.text('下周目标'), findsOneWidget);
    expect(find.text('加入下周'), findsOneWidget);
    expect(find.text('每周复盘'), findsOneWidget);
    expect(find.textContaining('采纳后进入生活小实验'), findsOneWidget);
    expect(find.text('生活小实验 · 目标'), findsOneWidget);
    expect(find.textContaining('已完成'), findsWidgets);
    expect(find.textContaining('未完成'), findsWidgets);
    expect(find.textContaining('Life Experiment'), findsNothing);

    await tester.drag(find.byType(PageView), const Offset(-390, 0));
    await tester.pumpAndSettle();

    expect(find.text('看见更长的生活轨迹'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('onboarding-journey-pro-design-preview')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('onboarding-journey-pro-icon-background')),
      findsOneWidget,
    );
    expect(find.text('本月反复出现的观察'), findsOneWidget);
    expect(find.text('查看 Signal'), findsOneWidget);
    expect(find.text('旅程'), findsOneWidget);
    expect(find.text('每周复盘 · 深度分析'), findsOneWidget);
    expect(find.text('PRO'), findsOneWidget);
    expect(find.textContaining('Weekly 本周深读'), findsNothing);
    expect(find.textContaining('Pro 的 L3'), findsNothing);

    await tester.drag(find.byType(PageView), const Offset(-390, 0));
    await tester.pumpAndSettle();

    expect(find.text('选择你的关注重点'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey('onboarding-preference-icon-background'),
      ),
      findsOneWidget,
    );
    expect(find.text('开始  >'), findsOneWidget);

    for (final id in const [
      'relationship_connection',
      'emotional_stability',
      'growth_plan',
      'food_sleep',
      'creative_expression',
    ]) {
      await tester.tap(find.byKey(ValueKey('onboarding-focus-$id')));
      await tester.pump();
    }

    await tester.tap(find.text('开始  >'));
    await tester.pumpAndSettle();

    const expectedFocusIds = [
      'relationship_connection',
      'creative_expression',
    ];
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_completed'), isTrue);
    expect(prefs.getBool('onboardingCompleted'), isTrue);
    expect(
      prefs.getStringList(FocusDomains.productPreferenceKey),
      expectedFocusIds,
    );
    expect(meViewModel.selectedFocusDomainIds, expectedFocusIds);
    expect(find.text('Today reached'), findsOneWidget);

    await tester.binding.setSurfaceSize(const Size(800, 1000));
    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        child: const MePage(),
        providers: [
          ChangeNotifierProvider<MeViewModel>.value(value: meViewModel),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('关系连接'), findsOneWidget);
    expect(find.text('创造表达'), findsOneWidget);
    expect(find.text('情绪安定'), findsNothing);
    expect(find.text('成长计划'), findsNothing);
    expect(find.text('饮食睡眠'), findsNothing);
  });
}

class _FailingApiClient extends ApiClient {
  _FailingApiClient() : super(baseUrl: 'http://127.0.0.1:1', userId: 'test');

  @override
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    throw Exception('offline');
  }
}
