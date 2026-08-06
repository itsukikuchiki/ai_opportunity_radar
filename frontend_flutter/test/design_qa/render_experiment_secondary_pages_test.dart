import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_opportunity_radar/core/di/app_dependencies.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/models/weekly_models.dart';
import 'package:ai_opportunity_radar/features/pages/experiment/experiment_action_preference_report.dart';
import 'package:ai_opportunity_radar/features/pages/experiment/experiment_page.dart';
import 'package:ai_opportunity_radar/features/pages/today/today_experiment_feedback_page.dart';
import 'package:ai_opportunity_radar/features/pages/weekly/weekly_view_model.dart';

import '../helpers/design_qa_font_loader.dart';
import '../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    sqfliteFfiInit();
    await loadDesignQaFonts(_fontFamily);
  });

  testWidgets('captures the compact action preference hero at 390x844',
      (tester) async {
    _configureViewport(tester);
    const report = ExperimentActionPreferenceReport(
      totalEvaluatedFeedbackCount: 10,
      distinctItemCount: 3,
      distinctDayCount: 5,
      smallExperimentFeedbackCount: 6,
      goalReviewCount: 4,
      positiveCount: 5,
      partialPositiveCount: 3,
      neutralOrNegativeCount: 2,
      easyCount: 4,
      acceptableCount: 4,
      difficultCount: 2,
      userCreatedFeedbackCount: 4,
      suggestedFeedbackCount: 6,
      themes: [
        ExperimentActionThemeSummary(
          theme: ExperimentActionTheme.recoveryAndBuffer,
          evaluatedFeedbackCount: 6,
          positiveFeedbackCount: 5,
          manageableFeedbackCount: 5,
          distinctItemCount: 2,
        ),
      ],
    );
    final captureKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: const _ReviewApp(
          child: ExperimentActionPreferenceReportPage(report: report),
        ),
      ),
    );
    await _precacheHero(tester, captureKey);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('experiment-action-preference-hero')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await _capture(
      tester,
      captureKey,
      'design_qa/spacing-2026-08-01/action-preference-hero-final.png',
    );
  });

  testWidgets('captures the Life Experiment feedback page at 390x844',
      (tester) async {
    _configureViewport(tester);
    final today = DateTime.now();
    late Directory tempDir;
    late LocalDatabase database;
    late AppDependencies dependencies;
    late String experimentId;
    await tester.runAsync(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'design_experiment_feedback_secondary_',
      );
      database = LocalDatabase(
        dbPathOverride: p.join(tempDir.path, 'feedback.db'),
        databaseFactoryOverride: databaseFactoryFfi,
      );
      await database.init();
      dependencies = await buildTestDependencies(
        todayRepository: StubTodayRepository(fetchTodayResult: const {}),
        localDatabaseOverride: database,
      );
      final start = DateTime(today.year, today.month, today.day)
          .subtract(const Duration(days: 2));
      final experiment =
          await dependencies.localLifeExperimentRepository.ensureSuggested(
        localUserId: dependencies.localUserId,
        weekStart: _dateKey(start),
        weekEnd: _dateKey(start.add(const Duration(days: 6))),
        title: '午后十分钟离屏恢复',
        hypothesis: '在疲惫刚出现时离屏，可能更容易恢复。',
        suggestedAction: '午后第一次明显疲惫时，离开屏幕十分钟。',
        linkedSignalCardIds: const ['signal-recovery', 'signal-energy'],
        status: 'active',
      );
      experimentId = experiment.id;
    });
    addTearDown(() async {
      await dependencies.localCandidatePlanningRepository.dispose();
      await database.close();
      await tempDir.delete(recursive: true);
    });
    final captureKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: _ReviewApp(
          child: Provider<AppDependencies>.value(
            value: dependencies,
            child: TodayExperimentFeedbackPage(experimentId: experimentId),
          ),
        ),
      ),
    );
    await _precacheHero(tester, captureKey);
    for (var attempt = 0; attempt < 20; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 40));
      if (find.text('午后十分钟离屏恢复').evaluate().isNotEmpty) break;
    }
    await _capture(
      tester,
      captureKey,
      'design_qa/experiment-feedback-secondary-390x844-2026-07-17.png',
    );
  });

  testWidgets('captures the Life Experiment goal detail at 390x844',
      (tester) async {
    _configureViewport(tester);
    final captureKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: ChangeNotifierProvider(
          create: (_) => WeeklyViewModel(
            StubWeeklyRepository(weekly: _weeklyFixture),
          ),
          child: const _ReviewApp(child: ExperimentPage()),
        ),
      ),
    );
    await _precacheHero(tester, captureKey);
    await tester.pumpAndSettle();
    final showGoalsSegment =
        find.byKey(const ValueKey('experiment-track-switch-goals'));
    final archiveScroll = find.byKey(const ValueKey('experiment-scroll-view'));
    await tester.dragUntilVisible(
      showGoalsSegment,
      archiveScroll,
      const Offset(0, -240),
    );
    await _capture(
      tester,
      captureKey,
      'design_qa/experiment-track-switch-390x844-2026-07-29.png',
    );
    await tester.tap(showGoalsSegment);
    await tester.pumpAndSettle();
    final detailCard = find.byKey(
      const ValueKey('experiment-archive-card-experiment_detail_fixture'),
    );
    await tester.dragUntilVisible(
      detailCard,
      archiveScroll,
      const Offset(0, -240),
    );
    await tester.drag(archiveScroll, const Offset(0, -100));
    await tester.pumpAndSettle();
    await tester.tap(detailCard);
    await tester.pumpAndSettle();
    expect(find.text('目标详情'), findsOneWidget);
    expect(find.textContaining('active'), findsNothing);
    expect(find.textContaining('life experiment'), findsNothing);
    expect(find.textContaining('进行中'), findsWidgets);
    expect(find.text('这个目标要观察什么'), findsOneWidget);
    expect(
      tester.getSize(find.text('午后十分钟离屏恢复')).height,
      lessThan(30),
    );
    expect(find.text('长期进度'), findsNothing);
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('goal-weekly-summary-card')),
      find.byType(Scrollable).first,
      const Offset(0, -240),
    );
    expect(find.text('周次总结'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('goal-weekly-summary-card')),
        matching: find.byKey(
          const ValueKey(
            'goal-observation-timeline-experiment_detail_fixture',
          ),
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('概览'), findsNothing);
    await _capture(
      tester,
      captureKey,
      'design_qa/experiment-goal-detail-390x844-2026-07-22.png',
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

Future<void> _precacheHero(
  WidgetTester tester,
  GlobalKey captureKey,
) async {
  await tester.pump();
  await tester.runAsync(
    () => precacheImage(
      const AssetImage('assets/experiment/life-experiment-branching-v2.png'),
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
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final output = File(path);
    await output.parent.create(recursive: true);
    await output.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
    image.dispose();
  });
}

String _dateKey(DateTime value) => '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

class _ReviewApp extends StatelessWidget {
  final Widget child;

  const _ReviewApp({required this.child});

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
      locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
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
        fontFamily: _fontFamily,
        scaffoldBackgroundColor: scheme.surface,
      ),
      home: child,
    );
  }
}

final _weeklyFixture = WeeklyInsightModel(
  weekStart: '2026-07-13',
  weekEnd: '2026-07-19',
  status: 'ready',
  keyInsight: '短暂离屏后，恢复更容易开始。',
  patterns: const [
    {'name': '恢复节奏', 'summary': '午后的短暂停顿有帮助。'},
  ],
  frictions: const [
    {'name': '连续切换', 'summary': '切换密集时更容易疲惫。'},
  ],
  bestAction: '午后第一次疲惫时，离开屏幕十分钟。',
  opportunitySnapshot: const {
    '_life_experiment': {
      'id': 'experiment_detail_fixture',
      'local_user_id': 'test-user',
      'source_week_start': '2026-07-13',
      'source_week_end': '2026-07-19',
      'title': '午后十分钟离屏恢复',
      'hypothesis': '在疲惫刚出现时离屏，可能更容易恢复。',
      'suggested_action': '午后第一次明显疲惫时，离开屏幕十分钟。',
      'feedback_text': '离屏后更容易重新开始。',
      'created_at': '2026-07-13T08:00:00.000',
      'updated_at': '2026-07-17T20:00:00.000',
      'linked_signal_card_ids': [
        'signal-recovery',
        'signal-energy',
      ],
      'status': 'active',
    },
  },
  feedbackSubmitted: false,
);

const _fontFamily = 'ExperimentSecondaryDesignReviewCJK';
