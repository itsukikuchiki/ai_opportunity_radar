import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_opportunity_radar/app/app.dart';
import 'package:ai_opportunity_radar/core/diagnostics/privacy_safe_logger.dart';
import 'package:ai_opportunity_radar/core/state/app_bootstrap_state.dart';
import 'package:ai_opportunity_radar/features/system/initialization_failure_page.dart';
import 'package:ai_opportunity_radar/shared/widgets/aurora_ui.dart';

void main() {
  testWidgets('initialization failure never renders the raw exception',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final semantics = tester.ensureSemantics();
    SharedPreferences.setMockInitialValues({
      'onboarding_completed': true,
      'legacy_schedule_notifications_cleared_v1': true,
    });
    var attempts = 0;
    final logger = PrivacySafeLogger(
      sink: (_) {},
      idFactory: () => 'safe-reference-${attempts + 1}',
    );
    final bootstrap = AppBootstrapState(
      logger: logger,
      dependenciesFactory: () async {
        attempts += 1;
        throw StateError('raw user text and /private/database/path');
      },
    );
    await bootstrap.prepareLaunch();
    await bootstrap.init();

    await tester.pumpWidget(RadarApp(bootstrapState: bootstrap));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('initialization-failure-title')),
      findsOneWidget,
    );
    expect(find.textContaining('raw user text'), findsNothing);
    expect(find.textContaining('/private/database/path'), findsNothing);
    expect(find.textContaining('safe-reference-2'), findsOneWidget);
    expect(find.byType(AuroraPage), findsOneWidget);
    expect(find.byType(AuroraCard), findsOneWidget);
    expect(find.byType(AuroraHeroEmblem), findsOneWidget);
    expect(find.byType(AuroraSectionIcon), findsOneWidget);

    final retry = find.byKey(const ValueKey('initialization-retry-action'));
    expect(retry, findsOneWidget);
    expect(tester.getSize(retry).height, greaterThanOrEqualTo(44));
    expect(
      tester.getSemantics(retry),
      matchesSemantics(
        label: 'Try again',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.textContaining('raw user text'), findsNothing);
    bootstrap.dispose();
    semantics.dispose();
  });

  const localeCases = <(Locale, String, String)>[
    (Locale('en'), 'Signal Path could not finish starting', 'Try again'),
    (
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      'Signal Path 暂时无法完成启动',
      '重试',
    ),
    (
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      'Signal Path 暫時無法完成啟動',
      '重試',
    ),
    (Locale('ja'), 'Signal Path を起動できませんでした', 'もう一度試す'),
  ];

  for (final localeCase in localeCases) {
    testWidgets(
      'initialization failure supports ${localeCase.$1} at 1.3x',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          MaterialApp(
            locale: localeCase.$1,
            supportedLocales: [localeCase.$1],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.3),
              ),
              child: child!,
            ),
            home: InitializationFailurePage(
              referenceId: 'safe-reference',
              onRetry: () async {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(localeCase.$2), findsOneWidget);
        expect(find.text(localeCase.$3), findsOneWidget);
        expect(find.byType(AuroraPage), findsOneWidget);
        expect(find.byType(AuroraCard), findsOneWidget);
        expect(find.byType(AuroraHeroEmblem), findsOneWidget);
        expect(tester.takeException(), isNull);
        final retry = find.byKey(
          const ValueKey('initialization-retry-action'),
        );
        expect(tester.getSize(retry).height, greaterThanOrEqualTo(44));
        expect(
          tester.getSemantics(retry),
          matchesSemantics(
            label: localeCase.$3,
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            isFocusable: true,
            hasTapAction: true,
            hasFocusAction: true,
          ),
        );
        final title = find.byKey(
          const ValueKey('initialization-failure-title'),
        );
        expect(
          tester.getSemantics(title),
          matchesSemantics(label: localeCase.$2, isHeader: true),
        );
        semantics.dispose();
      },
    );
  }
}
