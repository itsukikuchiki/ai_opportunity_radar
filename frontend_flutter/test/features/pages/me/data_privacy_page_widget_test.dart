import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ai_opportunity_radar/app/app_router.dart';
import 'package:ai_opportunity_radar/features/pages/me/data_privacy_page.dart';

void main() {
  test('data privacy is available as a direct QA route', () {
    expect(
      resolvedInitialRoute(AppRoutes.dataPrivacy),
      AppRoutes.dataPrivacy,
    );
  });

  testWidgets('explains each data owner without exposing destructive controls',
      (tester) async {
    await tester.pumpWidget(
      _testApp(
        child: DataPrivacyPage(openExternal: (_) async => true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Data and privacy'), findsOneWidget);
    expect(find.text('On this device'), findsOneWidget);
    expect(find.text('App Store / StoreKit'), findsOneWidget);
    expect(find.text('Signal Path service'), findsOneWidget);
    expect(
        find.textContaining('export or promise cloud backup'), findsOneWidget);

    await _scrollUntilVisible(
      tester,
      find.textContaining('does not cancel your subscription'),
    );
    expect(
      find.textContaining('does not cancel your subscription'),
      findsOneWidget,
    );

    await _scrollUntilVisible(
      tester,
      find.text('Health data has two separate controls'),
    );
    expect(find.text('Health data has two separate controls'), findsOneWidget);
    expect(find.textContaining('does not change the iOS Health permission'),
        findsOneWidget);
    expect(find.textContaining('stops future Health reads'), findsOneWidget);

    expect(find.textContaining('Calendar'), findsNothing);
    expect(
        find.byKey(const ValueKey('data-privacy-delete-button')), findsNothing);
    await _scrollUntilVisible(
      tester,
      find.byKey(const ValueKey('data-privacy-policy-button')),
    );
  });

  testWidgets('opens the existing external privacy policy URL', (tester) async {
    Uri? opened;
    await tester.pumpWidget(
      _testApp(
        child: DataPrivacyPage(
          openExternal: (uri) async {
            opened = uri;
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final button = find.byKey(const ValueKey('data-privacy-policy-button'));
    await _scrollUntilVisible(tester, button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(opened, DataPrivacyPage.privacyPolicyUri);
  });

  testWidgets('policy launch failure is visible and privacy safe',
      (tester) async {
    await tester.pumpWidget(
      _testApp(
        child: DataPrivacyPage(openExternal: (_) async => false),
      ),
    );
    await tester.pumpAndSettle();

    final button = find.byKey(const ValueKey('data-privacy-policy-button'));
    await _scrollUntilVisible(tester, button);
    await tester.tap(button);
    await tester.pump();

    expect(
      find.text('Could not open the privacy policy right now.'),
      findsOneWidget,
    );
  });

  testWidgets('simplified Chinese fits a compact phone at 1.3x text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _testApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        textScaler: const TextScaler.linear(1.3),
        child: DataPrivacyPage(openExternal: (_) async => true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('数据与隐私'), findsOneWidget);
    expect(find.text('本机'), findsOneWidget);
    await _scrollUntilVisible(tester, find.text('清除数据与订阅'));
    expect(find.text('清除数据与订阅'), findsOneWidget);
    await _scrollUntilVisible(tester, find.text('健康数据有两种不同控制'));
    expect(find.text('健康数据有两种不同控制'), findsOneWidget);

    await _scrollUntilVisible(tester, find.text('打开隐私政策'));
    expect(find.text('打开隐私政策'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('back returns to the real previous page', (tester) async {
    final router = GoRouter(
      initialLocation: '/caller',
      routes: [
        GoRoute(
          path: '/caller',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.push(AppRoutes.dataPrivacy),
              child: const Text('Open privacy'),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.dataPrivacy,
          builder: (_, __) => DataPrivacyPage(
            openExternal: (_) async => true,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open privacy'));
    await tester.pumpAndSettle();
    expect(find.byType(DataPrivacyPage), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('data-privacy-back')));
    await tester.pumpAndSettle();
    expect(find.text('Open privacy'), findsOneWidget);
    expect(router.routerDelegate.currentConfiguration.uri.path, '/caller');
  });
}

Future<void> _scrollUntilVisible(
  WidgetTester tester,
  Finder target,
) async {
  final scrollable = find.byKey(const ValueKey('data-privacy-scroll'));
  for (var i = 0; i < 12 && target.evaluate().isEmpty; i++) {
    await tester.drag(scrollable, const Offset(0, -420));
    await tester.pumpAndSettle();
  }
  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Widget _testApp({
  required Widget child,
  Locale locale = const Locale('en'),
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: const [
      Locale('en'),
      Locale('ja'),
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    ],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: MediaQuery(
      data: MediaQueryData(textScaler: textScaler),
      child: child,
    ),
  );
}
