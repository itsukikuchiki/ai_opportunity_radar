import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_opportunity_radar/core/api/repositories/memory_repository.dart';
import 'package:ai_opportunity_radar/core/di/app_dependencies.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/models/energy_budget_models.dart';
import 'package:ai_opportunity_radar/core/models/memory_models.dart';
import 'package:ai_opportunity_radar/core/models/monthly_models.dart';
import 'package:ai_opportunity_radar/core/models/phase3_plus_models.dart';
import 'package:ai_opportunity_radar/core/models/today_models.dart';
import 'package:ai_opportunity_radar/core/models/weekly_models.dart';
import 'package:ai_opportunity_radar/core/readiness/report_readiness.dart';
import 'package:ai_opportunity_radar/features/pages/experiment/experiment_page.dart';
import 'package:ai_opportunity_radar/features/pages/me/me_view_model.dart';
import 'package:ai_opportunity_radar/features/pages/memory/memory_page.dart';
import 'package:ai_opportunity_radar/features/pages/memory/memory_view_model.dart';
import 'package:ai_opportunity_radar/features/pages/today/today_page.dart';
import 'package:ai_opportunity_radar/features/pages/today/today_experiment_feedback_page.dart';
import 'package:ai_opportunity_radar/features/pages/today/today_view_model.dart';
import 'package:ai_opportunity_radar/features/pages/weekly/weekly_page.dart';
import 'package:ai_opportunity_radar/features/pages/weekly/weekly_view_model.dart';

import '../helpers/design_qa_font_loader.dart';
import '../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    sqfliteFfiInit();
    await loadDesignQaFonts(_designReviewFontFamily);
  });

  testWidgets('renders the current Today page for design review',
      (tester) async {
    _configureViewport(tester);
    final now = DateTime.now();
    final repository = StubTodayRepository(
      fetchTodayResult: {
        'insight': TodayInsightModel(
          text: '今天已经记录了 4 条，几条 Signal 正在“连续切换任务”上聚起来。',
        ),
        'pendingQuestion': null,
        'bestAction': DailyBestActionModel(text: '任务切换前留两分钟缓冲。'),
        'recentSignals': [
          RecentSignalModel(
            id: 'signal-state',
            signalCardId: 'signal-state',
            sourceType: 'one_tap',
            content: '现在状态比较平稳，精力还好。',
            createdAt: now.subtract(const Duration(minutes: 18)),
            rawPayloadJson: const {'energy_level': 1},
            energyLoad: 'neutral',
            userConfirmation: 'confirmed',
            includedInSummary: true,
            includedInWeekly: true,
            includedInJourney: true,
          ),
          RecentSignalModel(
            id: 'signal-switching',
            signalCardId: 'signal-switching',
            content: '上午连续切了三个任务，真正累的是不停重新进入状态。',
            createdAt: now.subtract(const Duration(minutes: 42)),
            acknowledgement: '我接住了，先把这个切换感留在这里。',
            observation: '连续切换任务后，比任务本身更难恢复。',
            friction: 'context_switching',
            energyLoad: 'draining',
            sceneTags: const ['work'],
            userConfirmation: 'confirmed',
            includedInSummary: true,
            includedInWeekly: true,
            includedInJourney: true,
          ),
          RecentSignalModel(
            id: 'signal-recovery',
            signalCardId: 'signal-recovery',
            sourceType: 'time_use',
            content: '午后离开屏幕走了十分钟，回来时轻松了一点。',
            createdAt: now.subtract(const Duration(hours: 2)),
            rawPayloadJson: const {
              'record_status': 'completed',
              'energy_effect': 'restoring',
            },
            intentTags: const ['recovery'],
            userConfirmation: 'confirmed',
            includedInSummary: true,
            includedInWeekly: true,
            includedInJourney: true,
          ),
          RecentSignalModel(
            id: 'signal-note',
            signalCardId: 'signal-note',
            content: '把下一件事缩小以后，开始变得容易了。',
            createdAt: now.subtract(const Duration(hours: 3)),
            energyLoad: 'neutral',
            userConfirmation: 'confirmed',
            includedInSummary: true,
            includedInWeekly: true,
            includedInJourney: true,
          ),
        ],
        'aiJudgement': AiJudgementModel(
          id: 'judgement-today',
          localDate: _dateKey(now),
          judgementText: '今天更值得确认的，可能不是事情多，而是切换后没有留下恢复空隙。',
          evidenceText: 'Signal 来自上午连续切换任务与午后的恢复记录。',
          predictedSignalText: '连续切换后，我需要一点恢复空隙。',
          suggestedPattern: 'context_switching',
          suggestedLifeChainStage: 'observation',
        ),
        'activeMicroAction': const MicroActionModel(
          id: 'action-today',
          judgementId: 'judgement-today',
          title: '任务切换前留两分钟缓冲',
          reason: '先用很轻的方式观察切换后的状态。',
          status: 'active',
          progressStartDate: '2026-07-13',
          progressEndDate: '2026-07-19',
        ),
        'todayLifeExperiment': const LifeExperimentModel(
          id: 'goal-today',
          localUserId: 'design-review',
          sourceWeekStart: '2026-07-13',
          sourceWeekEnd: '2026-07-19',
          title: '午后十分钟离屏恢复',
          hypothesis: '在疲惫刚出现时离屏，可能更容易恢复。',
          suggestedAction: '午后第一次明显疲惫时，离开屏幕十分钟。',
          linkedSignalCardIds: ['signal-recovery'],
          status: 'active',
          progressStartDate: '2026-07-13',
          progressEndDate: '2026-07-19',
        ),
      },
    );
    final meViewModel = await buildMeViewModel(repeatArea: 'work_tasks');
    final captureKey = GlobalKey();

    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: _DesignReviewApp(
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider<TodayViewModel>(
                create: (_) => TodayViewModel(repository),
              ),
              ChangeNotifierProvider<MeViewModel>.value(value: meViewModel),
            ],
            child: const TodayPage(),
          ),
        ),
      ),
    );
    await _precacheHero(
      tester,
      captureKey,
      'assets/hero_art/today-signal-points-v1.png',
    );
    await tester.pumpAndSettle();
    expect(find.text('context_switching'), findsNothing);
    expect(find.text('context switching'), findsNothing);
    expect(find.textContaining('连续切换任务'), findsWidgets);
    await _capture(
      tester,
      captureKey,
      'design_qa/today-current-2026-07-17.png',
    );
  });

  testWidgets('renders the current Weekly page for design review',
      (tester) async {
    _configureViewport(tester);
    final repository = StubWeeklyRepository(
      weekly: WeeklyInsightModel(
        weekStart: '2026-07-13',
        weekEnd: '2026-07-19',
        status: 'ready',
        keyInsight: '这周真正消耗你的，更多是频繁切换，而不是任务数量本身。',
        patterns: const [
          {
            'name': '切换后难以重新进入状态',
            'summary': '工作被打断后，恢复专注需要更长时间。',
          },
        ],
        frictions: const [
          {
            'name': '频繁切换',
            'summary': '多个工作场景里都出现了切换后的耗力。',
          },
        ],
        bestAction: '下周先保留一个低成本的切换缓冲。',
        opportunitySnapshot: const {
          '_weekly_inclusion': {
            'used_count': 11,
            'timeline_only_count': 0,
            'excluded_count': 0,
            'legacy_reference_count': 0,
          },
        },
        feedbackSubmitted: false,
        chartData: const [
          WeeklyChartPointModel(
            date: '2026-07-13',
            signalCount: 2,
            moodScore: -0.2,
            frictionScore: 0.6,
            hasPositiveSignal: false,
          ),
          WeeklyChartPointModel(
            date: '2026-07-15',
            signalCount: 4,
            moodScore: -0.1,
            frictionScore: 0.7,
            hasPositiveSignal: true,
          ),
          WeeklyChartPointModel(
            date: '2026-07-17',
            signalCount: 5,
            moodScore: 0.2,
            frictionScore: 0.4,
            hasPositiveSignal: true,
          ),
        ],
        previousWeekSummary: const PreviousWeekSummaryModel(
          weekStart: '2026-07-06',
          weekEnd: '2026-07-12',
          readiness: ReportReadiness(
            rule: ReportReadinessEvaluator.weeklyRule,
            signalCount: 8,
            distinctDayCount: 5,
            distinctWeekCount: 1,
          ),
          signalCount: 8,
          recordedDayCount: 5,
          factualSummary: '上周多个工作日都出现了任务切换，短暂离开屏幕后更容易重新开始。',
          thisWeekWatchpoint: '本周可留意：恢复空隙是否能减少切换后的耗力。',
          sourceSignalCardIds: ['previous-1', 'previous-2'],
          sourceHash: 'design-review',
        ),
        behaviorPatterns: const [
          WeeklyBehaviorPatternModel(
            id: 'pattern-switch',
            label: '切换越密集，重新开始越困难',
            summary: '上午和午后都出现了相同的切换—耗力顺序。',
            kind: 'behavior_sequence',
            sourceSignalCardIds: ['signal-1', 'signal-2', 'signal-3'],
            supportDates: ['2026-07-14', '2026-07-16'],
            illustrationHint: 'route_interrupted',
          ),
        ],
      ),
      experimentCandidate: const LifeExperimentModel(
        id: 'next-week-goal',
        localUserId: 'design-review',
        sourceWeekStart: '2026-07-13',
        sourceWeekEnd: '2026-07-19',
        title: '为任务切换预留恢复块',
        hypothesis: '短暂缓冲可能帮助重新进入状态。',
        suggestedAction: '两项任务之间保留五分钟空白。',
        linkedSignalCardIds: ['signal-1', 'signal-2'],
        status: 'suggested',
      ),
    );
    final energyRepository = StubEnergyBudgetRepository(
      budget: const EnergyBudgetModel(
        status: 'ready',
        mostDrainingSource: '切换密集时更偏耗力。',
        recoveryClue: '短暂离屏是本周较明确的恢复线索。',
        bufferLocation: '任务之间适合保留一点余地。',
        switchingAdjustment: '下周维持轻量，不自动增加计划。',
        experimentConnection: '优先排序低切换、可暂停的尝试。',
        blocks: [],
      ),
    );
    final meViewModel = await buildMeViewModel(repeatArea: 'work_tasks');
    final captureKey = GlobalKey();

    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: _DesignReviewApp(
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider<WeeklyViewModel>(
                create: (_) => WeeklyViewModel(
                  repository,
                  energyBudgetRepository: energyRepository,
                ),
              ),
              ChangeNotifierProvider<MeViewModel>.value(value: meViewModel),
            ],
            child: const WeeklyPage(),
          ),
        ),
      ),
    );
    await _precacheHero(
      tester,
      captureKey,
      'assets/hero_art/weekly-review-network-v1.png',
    );
    await tester.pumpAndSettle();
    await _capture(
      tester,
      captureKey,
      'design_qa/weekly-current-2026-07-17.png',
    );
  });

  testWidgets('renders the current Life Experiment page for design review',
      (tester) async {
    _configureViewport(tester);
    final today = DateTime.now();
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    final repository = StubWeeklyRepository(
      weekly: WeeklyInsightModel(
        weekStart: _dateKey(weekStart),
        weekEnd: _dateKey(weekEnd),
        status: 'ready',
        keyInsight: '这周可以继续用更轻的方式尝试改变。',
        patterns: const [],
        frictions: const [],
        bestAction: '任务切换前留两分钟缓冲。',
        opportunitySnapshot: const {},
        feedbackSubmitted: false,
        chartData: const [],
      ),
    );
    late Directory tempDir;
    late LocalDatabase database;
    late AppDependencies dependencies;
    await tester.runAsync(() async {
      tempDir = await Directory.systemTemp.createTemp('design_experiment_');
      database = LocalDatabase(
        dbPathOverride: p.join(tempDir.path, 'experiment.db'),
        databaseFactoryOverride: databaseFactoryFfi,
      );
      await database.init();
      dependencies = await buildTestDependencies(
        todayRepository: StubTodayRepository(fetchTodayResult: const {}),
        weeklyRepository: repository,
        localDatabaseOverride: database,
      );
      await dependencies.localPhase3PlusRepository.upsertMicroAction(
        MicroActionModel(
          id: 'design-small-try',
          judgementId: 'design-judgement',
          title: '任务切换前留两分钟缓冲',
          reason: '现在就能开始的一次轻尝试。',
          status: 'active',
          localUserId: dependencies.localUserId,
          adoptedAt: today.subtract(const Duration(days: 2)),
          progressStartDate: _dateKey(today.subtract(const Duration(days: 2))),
          progressEndDate: _dateKey(today.add(const Duration(days: 4))),
          linkedSignalCardIds: const ['signal-switching', 'signal-recovery'],
        ),
      );
      final db = await database.database;
      await db.insert(
        'life_experiments',
        dependencies.localLifeExperimentRepository.toStorageRow(
          LifeExperimentModel(
            id: 'design-goal',
            localUserId: dependencies.localUserId,
            sourceWeekStart: _dateKey(weekStart),
            sourceWeekEnd: _dateKey(weekEnd),
            title: '午后十分钟离屏恢复',
            hypothesis: '在疲惫刚出现时离屏，可能更容易恢复。',
            suggestedAction: '午后第一次明显疲惫时，离开屏幕十分钟。',
            linkedSignalCardIds: const ['signal-recovery'],
            status: 'active',
            originCandidateId: 'design-goal-candidate',
            adoptedAt: today.subtract(const Duration(days: 2)),
            progressStartDate:
                _dateKey(today.subtract(const Duration(days: 2))),
            progressEndDate: _dateKey(today.add(const Duration(days: 4))),
            createdAt: today.subtract(const Duration(days: 2)),
            updatedAt: today,
          ),
        ),
      );
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
        child: _DesignReviewApp(
          child: MultiProvider(
            providers: [
              Provider<AppDependencies>.value(value: dependencies),
              ChangeNotifierProvider<WeeklyViewModel>(
                create: (_) => WeeklyViewModel(repository),
              ),
            ],
            child: const ExperimentPage(),
          ),
        ),
      ),
    );
    await _precacheHero(
      tester,
      captureKey,
      'assets/experiment/life-experiment-branching-v2.png',
    );
    await tester.pump();
    for (var attempt = 0; attempt < 20; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 40));
      if (find.text('任务切换前留两分钟缓冲').evaluate().isNotEmpty) {
        break;
      }
    }
    await _capture(
      tester,
      captureKey,
      'design_qa/experiment-current-2026-07-17.png',
    );

    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    final smallTry = find.byKey(
      const ValueKey('life-experiment-small-try-design-small-try'),
    );
    await tester.ensureVisible(smallTry);
    await tester.tap(smallTry);
    await tester.pumpAndSettle();
    expect(find.text('小实验详情'), findsOneWidget);
    await _capture(
      tester,
      captureKey,
      'design_qa/experiment-small-try-detail-390x844-2026-07-22.png',
    );
  });

  testWidgets('renders the current Journey page for design review',
      (tester) async {
    _configureViewport(tester);
    final repository = StubMemoryRepository(
      result: MemoryFetchResult(
        isFirstDayGate: false,
        journeyReadiness: const ReportReadiness(
          rule: ReportReadinessEvaluator.journeyRule,
          signalCount: 12,
          distinctDayCount: 6,
          distinctWeekCount: 2,
        ),
        summary: MemorySummaryModel(
          patterns: const [
            JourneySignalItemModel(
              name: '切换后需要一点恢复空隙',
              summary: '这条路径已经在多个记录日重复出现。',
              signalLevel: 'repeated_pattern',
            ),
          ],
          frictions: const [
            JourneySignalItemModel(
              name: '任务连续切换',
              summary: '切换密集时，重新进入状态会更慢。',
              signalLevel: 'repeated_pattern',
            ),
          ],
          desires: const [
            JourneySignalItemModel(
              name: '短暂离屏恢复',
              summary: '午后的恢复 Signal 正在形成一条清晰路径。',
              signalLevel: 'stable_mode',
            ),
          ],
          experiments: const [
            JourneySignalItemModel(
              name: '切换前两分钟缓冲',
              summary: '轻尝试开始连接到更稳定的节奏。',
              signalLevel: 'weak_signal',
            ),
          ],
          monthlyReview: const MonthlyReviewModel(
            monthStart: '2026-07-01',
            monthEnd: '2026-07-31',
            status: 'ready',
            monthlySummary: '这个月的 Signal 正从零散记录连成一条关于切换与恢复的路径。',
            repeatedThemes: ['切换后的恢复', '为重要事情保留余地'],
            improvingSignals: ['午后离屏后更容易重新开始'],
            unresolvedPoints: ['高切换日是否需要更早减量'],
            nextMonthWatch: '继续观察恢复空隙与重新开始之间的关系。',
          ),
          lifeDirection: const LifeDirectionModel(
            title: '为重要的事留下连续空间',
            summary: '从减少无意切换开始，让节奏更稳定。',
          ),
          journeyThemes: const [
            JourneyThemeModel(id: 'recovery', title: '恢复与余地', count: 7),
            JourneyThemeModel(id: 'focus', title: '专注与切换', count: 5),
          ],
          journeyTraces: const [
            JourneyTraceModel(
              id: 'journey-1',
              sourceType: 'signal_card',
              title: '连续切换后很难重新开始',
              summary: '上午的工作 Signal。',
              localDate: '2026-07-16',
              cluster: 'work',
              intensity: 0.82,
              signalLevel: 'repeated_pattern',
            ),
            JourneyTraceModel(
              id: 'journey-2',
              sourceType: 'signal_card',
              title: '离屏十分钟后轻松了一点',
              summary: '午后的恢复 Signal。',
              localDate: '2026-07-15',
              cluster: 'recovery',
              intensity: 0.64,
              signalLevel: 'stable_mode',
            ),
          ],
        ),
      ),
    );
    final meViewModel = await buildMeViewModel(repeatArea: 'time_rhythm');
    final captureKey = GlobalKey();

    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: _DesignReviewApp(
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider<MemoryViewModel>(
                create: (_) => MemoryViewModel(repository),
              ),
              ChangeNotifierProvider<MeViewModel>.value(value: meViewModel),
            ],
            child: const MemoryPage(),
          ),
        ),
      ),
    );
    await _precacheHero(
      tester,
      captureKey,
      'assets/hero_art/journey-ring-path-v1.png',
    );
    await tester.pumpAndSettle();
    await _capture(
      tester,
      captureKey,
      'design_qa/journey-current-2026-07-17.png',
    );
  });

  testWidgets(
      'renders the current Life Experiment feedback page for design review',
      (tester) async {
    _configureViewport(tester);
    final today = DateTime.now();
    late Directory tempDir;
    late LocalDatabase database;
    late AppDependencies dependencies;
    late String experimentId;
    await tester.runAsync(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'design_experiment_feedback_',
      );
      database = LocalDatabase(
        dbPathOverride: p.join(tempDir.path, 'experiment-feedback.db'),
        databaseFactoryOverride: databaseFactoryFfi,
      );
      await database.init();
      dependencies = await buildTestDependencies(
        todayRepository: StubTodayRepository(fetchTodayResult: const {}),
        localDatabaseOverride: database,
      );
      final start = today.subtract(const Duration(days: 2));
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
        child: _DesignReviewApp(
          child: Provider<AppDependencies>.value(
            value: dependencies,
            child: TodayExperimentFeedbackPage(experimentId: experimentId),
          ),
        ),
      ),
    );
    await _precacheHero(
      tester,
      captureKey,
      'assets/experiment/life-experiment-branching-v2.png',
    );
    await tester.pump();
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
      'design_qa/experiment-feedback-current-2026-07-17.png',
    );
  });
}

void _configureViewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 932);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _precacheHero(
  WidgetTester tester,
  GlobalKey captureKey,
  String assetPath,
) async {
  await tester.pump();
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
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(path).writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
    image.dispose();
  });
}

String _dateKey(DateTime value) => '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

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

const _designReviewFontFamily = 'DesignReviewCJK';
