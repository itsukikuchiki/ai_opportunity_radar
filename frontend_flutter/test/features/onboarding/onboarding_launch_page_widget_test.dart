import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_opportunity_radar/app/app.dart';
import 'package:ai_opportunity_radar/core/api/api_client.dart';
import 'package:ai_opportunity_radar/core/state/app_bootstrap_state.dart';
import 'package:ai_opportunity_radar/features/onboarding/onboarding_page.dart';
import 'package:ai_opportunity_radar/features/onboarding/onboarding_view_model.dart';
import 'package:ai_opportunity_radar/shared/widgets/aurora_ui.dart';

void main() {
  testWidgets('fresh launch first frame is the onboarding opening scene',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final bootstrap = AppBootstrapState();
    await bootstrap.prepareLaunch();

    for (final size in const [
      Size(320, 640),
      Size(390, 844),
      Size(430, 932),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(RadarApp(bootstrapState: bootstrap));
      await tester.pump();

      expect(find.byType(OnboardingLaunchPage), findsOneWidget);
      expect(
        find.byKey(const ValueKey('onboarding-opening-scene')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('onboarding-opening-icon-background')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('onboarding-today-signal-design-preview'),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              const {
                'Start with\none Signal today',
                '今天，留下\n一条 Signal',
                '今天，留下\n一條 Signal',
                '今日、まず一つの\nSignal を残す',
              }.contains(widget.data),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('completed onboarding keeps the returning launch screen',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(
      tester.platformDispatcher.clearTextScaleFactorTestValue,
    );
    final semantics = tester.ensureSemantics();
    SharedPreferences.setMockInitialValues({
      'onboarding_completed': true,
    });
    tester.platformDispatcher.localeTestValue = const Locale.fromSubtags(
      languageCode: 'zh',
      scriptCode: 'Hans',
    );
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    final bootstrap = AppBootstrapState();
    await bootstrap.prepareLaunch();

    await tester.pumpWidget(RadarApp(bootstrapState: bootstrap));
    await tester.pump();

    expect(bootstrap.onboardingCompleted, isTrue);
    expect(find.byType(OnboardingLaunchPage), findsNothing);
    expect(find.text('Signal Path'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            const {
              'Notice the Signal, adjust gently',
              '看见信号，轻轻调整',
              '看見信號，輕輕調整',
              'シグナルに気づき、少しずつ整える',
            }.contains(widget.data),
      ),
      findsOneWidget,
    );
    expect(find.byType(AuroraPage), findsOneWidget);
    expect(find.byType(AuroraCard), findsOneWidget);
    expect(find.byType(AuroraHeroEmblem), findsOneWidget);
    expect(tester.takeException(), isNull);

    final surface = find.byKey(const ValueKey('brand-launch-surface'));
    final surfaceRect = tester.getRect(surface);
    expect(surfaceRect.left, greaterThanOrEqualTo(0));
    expect(surfaceRect.top, greaterThanOrEqualTo(0));
    expect(surfaceRect.right, lessThanOrEqualTo(390));
    expect(surfaceRect.bottom, lessThanOrEqualTo(844));
    expect(
      tester.getSemantics(
        find.byKey(const ValueKey('brand-launch-title')),
      ),
      matchesSemantics(label: 'Signal Path', isHeader: true),
    );
    semantics.dispose();
  });

  testWidgets('combined onboarding previews fit supported phone sizes',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(
      tester.platformDispatcher.clearTextScaleFactorTestValue,
    );

    for (final size in const [
      Size(320, 640),
      Size(390, 844),
      Size(430, 932),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await _pumpOnboarding(
        tester,
        const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
      );

      expect(find.text('今天，留下\n一条 Signal'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey('onboarding-today-signal-design-preview'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.drag(find.byType(PageView), Offset(-size.width, 0));
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const ValueKey('onboarding-weekly-experiment-design-preview'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('onboarding-life-experiment-bridge-preview'),
        ),
        findsNothing,
      );
      expect(find.text('把一周，\n整理成下一步'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.drag(find.byType(PageView), Offset(-size.width, 0));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('onboarding-journey-pro-design-preview')),
        findsOneWidget,
      );
      expect(find.text('看见生活，\n怎样慢慢变化'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.drag(find.byType(PageView), Offset(-size.width, 0));
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const ValueKey('onboarding-preference-icon-background'),
        ),
        findsOneWidget,
      );
      expect(
        find
            .byKey(const ValueKey('onboarding-focus-interests_hobbies'))
            .hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('onboarding-start-button')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets('first three pages support all app locales at 1.3 text scale',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(
      tester.platformDispatcher.clearTextScaleFactorTestValue,
    );

    const cases = [
      (
        locale: Locale('en'),
        opening: 'Start with\none Signal today',
        weekly: 'Turn one week\ninto a next step',
        journey: 'See how life\nslowly changes',
        preference: 'Choose your focus',
      ),
      (
        locale: Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        opening: '今天，留下\n一条 Signal',
        weekly: '把一周，\n整理成下一步',
        journey: '看见生活，\n怎样慢慢变化',
        preference: '选择你的关注重点',
      ),
      (
        locale: Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hant',
        ),
        opening: '今天，留下\n一條 Signal',
        weekly: '把一週，\n整理成下一步',
        journey: '看見生活，\n怎樣慢慢變化',
        preference: '選擇你的關注重點',
      ),
      (
        locale: Locale('ja'),
        opening: '今日、まず一つの\nSignal を残す',
        weekly: '一週間を、\n次の一歩に整える',
        journey: '生活が少しずつ\n変わる様子を見る',
        preference: '注目したいことを選ぶ',
      ),
    ];

    for (final testCase in cases) {
      await _pumpOnboarding(tester, testCase.locale);

      expect(find.text(testCase.opening), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey('onboarding-today-signal-design-preview'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.drag(find.byType(PageView), const Offset(-390, 0));
      await tester.pumpAndSettle();
      expect(find.text(testCase.weekly), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey('onboarding-weekly-experiment-design-preview'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.drag(find.byType(PageView), const Offset(-390, 0));
      await tester.pumpAndSettle();
      expect(find.text(testCase.journey), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey('onboarding-journey-pro-design-preview'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.drag(find.byType(PageView), const Offset(-390, 0));
      await tester.pumpAndSettle();
      expect(find.text(testCase.preference), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey('onboarding-preference-icon-background'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
}

Future<void> _pumpOnboarding(
  WidgetTester tester,
  Locale locale,
) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppBootstrapState>(
          create: (_) => AppBootstrapState(),
        ),
        ChangeNotifierProvider<OnboardingViewModel>(
          create: (_) => OnboardingViewModel(
            ApiClient(
              baseUrl: 'https://example.invalid',
              userId: 'onboarding-preview-test',
            ),
          ),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        supportedLocales: const [
          Locale('en'),
          Locale('ja'),
          Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
          Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        ],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const OnboardingPage(),
      ),
    ),
  );
  await tester.pump();
}
