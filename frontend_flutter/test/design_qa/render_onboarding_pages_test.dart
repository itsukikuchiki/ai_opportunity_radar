import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ai_opportunity_radar/core/api/api_client.dart';
import 'package:ai_opportunity_radar/core/state/app_bootstrap_state.dart';
import 'package:ai_opportunity_radar/features/onboarding/onboarding_page.dart';
import 'package:ai_opportunity_radar/features/onboarding/onboarding_view_model.dart';

import '../helpers/design_qa_font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadDesignQaFonts(_designReviewFontFamily);
  });

  testWidgets('renders the first three onboarding pages for design review',
      (tester) async {
    _configureViewport(tester);
    final captureKey = GlobalKey();

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
                userId: 'onboarding-design-review',
              ),
            ),
          ),
        ],
        child: _DesignReviewApp(
          child: RepaintBoundary(
            key: captureKey,
            child: const OnboardingPage(),
          ),
        ),
      ),
    );
    await tester.pump();

    for (final assetPath in _heroAssets) {
      await _precacheAsset(tester, captureKey, assetPath);
    }
    await tester.pumpAndSettle();

    expect(find.text('今天，留下\n一条 Signal'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(
      tester,
      captureKey,
      'design_qa/onboarding_2026-07-29/01-today-390x844.png',
    );

    await tester.drag(find.byType(PageView), const Offset(-390, 0));
    await tester.pumpAndSettle();
    expect(find.text('把一周，\n整理成下一步'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(
      tester,
      captureKey,
      'design_qa/onboarding_2026-07-29/02-weekly-390x844.png',
    );

    await tester.drag(find.byType(PageView), const Offset(-390, 0));
    await tester.pumpAndSettle();
    expect(find.text('看见生活，\n怎样慢慢变化'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(
      tester,
      captureKey,
      'design_qa/onboarding_2026-07-29/03-journey-390x844.png',
    );
  });
}

void _configureViewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _precacheAsset(
  WidgetTester tester,
  GlobalKey captureKey,
  String assetPath,
) async {
  await tester.runAsync(
    () => precacheImage(
      AssetImage(assetPath),
      captureKey.currentContext!,
    ),
  );
  await tester.pump();
}

Future<void> _capture(
  WidgetTester tester,
  GlobalKey captureKey,
  String path,
) async {
  await tester.runAsync(() async {
    final boundary =
        captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
    image.dispose();
  });
}

class _DesignReviewApp extends StatelessWidget {
  final Widget child;

  const _DesignReviewApp({required this.child});

  @override
  Widget build(BuildContext context) {
    const scheme = ColorScheme.light(
      primary: Color(0xFF7767F4),
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFEDEBFF),
      onPrimaryContainer: Color(0xFF151A33),
      secondary: Color(0xFF5F95E8),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFEAF3FF),
      onSecondaryContainer: Color(0xFF151A33),
      tertiary: Color(0xFF62C594),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFEAF8F0),
      onTertiaryContainer: Color(0xFF151A33),
      surface: Color(0xFFFFFCFA),
      onSurface: Color(0xFF252B4A),
      surfaceContainerHighest: Color(0xFFF5F4F8),
      onSurfaceVariant: Color(0xFF7F8797),
      outline: Color(0xFFCFCBD8),
      outlineVariant: Color(0xFFE7E4EC),
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
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
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: scheme.surface,
        fontFamily: _designReviewFontFamily,
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            textStyle: const TextStyle(
              fontFamily: _designReviewFontFamily,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        textTheme: const TextTheme(
          headlineMedium:
              TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.2),
          headlineSmall:
              TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0),
          titleLarge: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0),
          titleMedium: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0),
          labelLarge: TextStyle(
            fontFamily: _designReviewFontFamily,
            fontWeight: FontWeight.w400,
          ),
          bodyLarge: TextStyle(height: 1.48, letterSpacing: 0),
          bodyMedium: TextStyle(height: 1.48, letterSpacing: 0),
        ),
      ),
      home: child,
    );
  }
}

const _heroAssets = [
  'assets/hero_art/today-signal-points-v1.png',
  'assets/hero_art/weekly-review-network-v1.png',
  'assets/hero_art/journey-ring-path-v1.png',
];

const _designReviewFontFamily = 'DesignReviewCJK';
