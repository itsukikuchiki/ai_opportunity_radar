import 'package:flutter/material.dart';
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
      expect(find.text('安排'), findsNothing);
      expect(find.text('信号库'), findsOneWidget);
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
    final bootstrap = AppBootstrapState();
    await bootstrap.prepareLaunch();

    await tester.pumpWidget(RadarApp(bootstrapState: bootstrap));
    await tester.pump();

    expect(bootstrap.onboardingCompleted, isTrue);
    expect(find.byType(OnboardingLaunchPage), findsNothing);
    expect(find.text('Signal Path'), findsOneWidget);
    expect(find.text('看见信号，轻轻调整'), findsOneWidget);
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

    for (final size in const [
      Size(320, 640),
      Size(390, 844),
      Size(430, 932),
    ]) {
      await tester.binding.setSurfaceSize(size);
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
          child: const MaterialApp(
            locale: Locale.fromSubtags(
              languageCode: 'zh',
              scriptCode: 'Hans',
            ),
            home: OnboardingPage(),
          ),
        ),
      );
      await tester.pump();

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
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.drag(find.byType(PageView), Offset(-size.width, 0));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('onboarding-journey-pro-design-preview')),
        findsOneWidget,
      );
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
}
