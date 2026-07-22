import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import 'package:ai_opportunity_radar/core/models/journey_pro_models.dart';
import 'package:ai_opportunity_radar/features/pages/memory/journey_pro_page.dart';
import 'package:ai_opportunity_radar/features/pages/memory/journey_pro_view_model.dart';

import '../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final fontBytes =
        await File('/System/Library/Fonts/Hiragino Sans GB.ttc').readAsBytes();
    await (FontLoader(_designReviewFontFamily)
          ..addFont(Future.value(ByteData.sublistView(fontBytes))))
        .load();
    final iconBytes = await File(
      '/Users/yangyang/development/flutter/bin/cache/artifacts/material_fonts/'
      'MaterialIcons-Regular.otf',
    ).readAsBytes();
    await (FontLoader('MaterialIcons')
          ..addFont(Future.value(ByteData.sublistView(iconBytes))))
        .load();
    Directory(_designQaDirectory).createSync(recursive: true);
  });

  testWidgets('renders Journey Pro depth analysis for design review',
      (tester) async {
    _configureViewport(tester);
    final repository = StubJourneyProRepository(
      report: JourneyProReportModel(
        selectedMonthKey: '2026-07',
        periodStart: '2026-05-01',
        periodEnd: '2026-07-17',
        sourceHash: 'design-review-three-month-source',
        contextCoverage: const JourneyProContextCoverageModel(
          feedbackCount: 7,
          reviewCount: 3,
          experimentContextCount: 4,
          observationCount: 2,
        ),
        months: [
          _proMonth('2026-05', signals: 8, days: 4, draining: 3),
          _proMonth('2026-06', signals: 11, days: 6, draining: 5),
          _proMonth(
            '2026-07',
            signals: 10,
            days: 5,
            draining: 3,
            periodEnd: '2026-07-17',
          ),
        ],
      ),
    );
    final captureKey = GlobalKey();

    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: _DesignReviewApp(
          child: ChangeNotifierProvider<JourneyProViewModel>(
            create: (_) => JourneyProViewModel(repository),
            child: const JourneyProPage(initialMonthKey: '2026-07'),
          ),
        ),
      ),
    );
    await _precacheJourneyHero(tester, captureKey);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('journey-pro-three-month-hero')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await _capture(
      tester,
      captureKey,
      'journey-pro-secondary-current-2026-07-17.png',
    );
  });
}

Future<void> _precacheJourneyHero(
  WidgetTester tester,
  GlobalKey captureKey,
) async {
  await tester.pump();
  await tester.runAsync(
    () => precacheImage(
      const AssetImage('assets/hero_art/journey-ring-path-v1.png'),
      captureKey.currentContext!,
    ),
  );
  await tester.pump();
}

void _configureViewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _capture(
  WidgetTester tester,
  GlobalKey captureKey,
  String fileName,
) async {
  await tester.runAsync(() async {
    final boundary =
        captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(p.join(_designQaDirectory, fileName))
        .writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
    image.dispose();
  });
}

String get _designQaDirectory {
  final current = Directory.current;
  if (File(p.join(current.path, 'pubspec.yaml')).existsSync()) {
    return p.join(current.path, 'design_qa');
  }
  return p.join(current.path, 'frontend_flutter', 'design_qa');
}

class _DesignReviewApp extends StatelessWidget {
  final Widget child;

  const _DesignReviewApp({required this.child});

  @override
  Widget build(BuildContext context) {
    const scheme = ColorScheme.light(
      primary: Color(0xFF7767F4),
      onPrimary: Colors.white,
      secondary: Color(0xFF5F95E8),
      tertiary: Color(0xFF62C594),
      surface: Color(0xFFFFFCFA),
      onSurface: Color(0xFF252B4A),
      outline: Color(0xFFCFCBD8),
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
        fontFamily: _designReviewFontFamily,
        scaffoldBackgroundColor: scheme.surface,
        textTheme: const TextTheme(
          headlineMedium: TextStyle(fontWeight: FontWeight.w700),
          headlineSmall: TextStyle(fontWeight: FontWeight.w700),
          titleLarge: TextStyle(fontWeight: FontWeight.w700),
          titleMedium: TextStyle(fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(height: 1.48),
          bodyMedium: TextStyle(height: 1.48),
        ),
      ),
      home: child,
    );
  }
}

JourneyProMonthChangeModel _proMonth(
  String monthKey, {
  required int signals,
  required int days,
  required int draining,
  String? periodEnd,
}) {
  final parts = monthKey.split('-');
  final naturalEnd = DateTime(
    int.parse(parts.first),
    int.parse(parts.last) + 1,
    0,
  ).day;
  return JourneyProMonthChangeModel(
    monthKey: monthKey,
    periodStart: '$monthKey-01',
    periodEnd:
        periodEnd ?? '$monthKey-${naturalEnd.toString().padLeft(2, '0')}',
    signalCount: signals,
    activeDayCount: days,
    energyStateCounts: {
      'draining': draining,
      'steady': signals - draining - 2,
      'ease': 1,
      'recovery': 1,
      'boundary_buffer': 0,
    },
    domainCounts: {
      'growth_plan': signals - 3,
      'emotional_stability': 2,
      'interests': 1,
    },
  );
}

const _designReviewFontFamily = 'DesignReviewCJK';
