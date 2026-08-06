import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_opportunity_radar/core/di/app_dependencies.dart';
import 'package:ai_opportunity_radar/core/i18n/app_locale_text.dart';
import 'package:ai_opportunity_radar/core/local/local_candidate_planning_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_capture_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/local/local_life_experiment_repository.dart';
import 'package:ai_opportunity_radar/core/models/candidate_models.dart';
import 'package:ai_opportunity_radar/core/models/energy_budget_models.dart';
import 'package:ai_opportunity_radar/core/models/phase3_plus_models.dart';
import 'package:ai_opportunity_radar/core/models/weekly_models.dart';
import 'package:ai_opportunity_radar/features/pages/candidates/candidate_hub_page.dart';
import 'package:ai_opportunity_radar/features/pages/weekly/deep_weekly_page.dart';

import '../helpers/design_qa_font_loader.dart';
import '../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    sqfliteFfiInit();
    await loadDesignQaFonts(_designReviewFontFamily);
  });

  testWidgets('renders the current Weekly deep analysis for design review',
      (tester) async {
    _configureViewport(tester);
    SharedPreferences.setMockInitialValues(const {});

    final weeklyRepository = StubWeeklyRepository(
      weekly: _deepAnalysisWeekly(),
      weeklyReflect: const WeeklyReflectModel(
        summary: '这周真正消耗你的，更多是频繁切换，而不是任务数量本身。把这些 Signal 放在一起看，恢复空隙是值得继续留意的线索。',
        rootTension: '临时消息与任务切换不断打断原来的推进节奏。',
        hiddenPattern: '切换越密集，重新进入重要任务所需的时间越长。',
        nextFocus: '下周可留意：恢复空隙是否能减少切换后的耗力。',
        riskNote: '这里只说明本周共同出现的关系，不代表因果或长期结论。',
        keyNodes: ['临时消息', '任务切换', '恢复空隙'],
        patternLabel: '切换后难以重新进入状态',
        frictionLabel: '临时消息与连续任务',
        impactLabel: '重新开始变慢',
        relationshipSummary: '临时消息出现后，任务切换与偏耗力的 Signal 常在同一天出现。',
        timingSummary: '周三下午与周五上午的 Signal 较密，适合在这些时段轻轻提醒记录。',
        nextQuestion: '切换再次发生时，一小段恢复空隙是否会让重新开始更容易？',
        illustrationHint: 'route_interrupted',
        sourceSignalCardIds: ['signal-1', 'signal-2', 'signal-3'],
        scopeNote: '可以看见本周共同出现的场景、行为与能量变化；不能据此判断长期性格或医学状态。',
      ),
    );
    final energyRepository = StubEnergyBudgetRepository(
      budget: const EnergyBudgetModel(
        status: 'ready',
        mostDrainingSource: '连续切换的时段更偏耗力。',
        recoveryClue: '离开屏幕十分钟是较清楚的恢复 Signal。',
        bufferLocation: '两项任务之间适合保留一点余地。',
        switchingAdjustment: '下周负荷建议：维持。',
        experimentConnection: '优先排序低切换、可暂停的简单尝试。',
        energyStateCounts: {
          'draining': 3,
          'steady': 3,
          'ease': 1,
          'recovery': 2,
          'boundary_buffer': 2,
        },
        blocks: [],
      ),
    );
    final dependencies = await buildTestDependencies(
      todayRepository: StubTodayRepository(
        fetchTodayResult: const <String, dynamic>{},
      ),
      weeklyRepository: weeklyRepository,
      energyBudgetRepository: energyRepository,
    );
    final captureKey = GlobalKey();

    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: _DesignReviewApp(
          child: Provider<AppDependencies>.value(
            value: dependencies,
            child: const WeeklyReflectPage(),
          ),
        ),
      ),
    );
    await _precacheReviewHero(tester, captureKey);
    await tester.pumpAndSettle();

    expect(find.byType(WeeklyReflectPage), findsOneWidget);
    expect(find.byKey(const ValueKey('weekly-reflect-hero')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('weekly-reflect-review-pattern')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await _capture(
      tester,
      captureKey,
      'design_qa/spacing-2026-08-01/weekly-deep-final.png',
    );
  });

  testWidgets('renders the current next-week tries page for design review',
      (tester) async {
    _configureViewport(tester);
    final repository = _DesignCandidatePlanningRepository();
    final captureKey = GlobalKey();

    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: _DesignReviewApp(
          child: CandidateHubPage(
            kind: CandidateKind.lifeExperiment,
            repositoryOverride: repository,
            nowLoader: () => DateTime(2026, 7, 17),
          ),
        ),
      ),
    );
    await _precacheReviewHero(tester, captureKey);
    await tester.pumpAndSettle();

    expect(find.text('下周尝试'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('candidate-hub-review-pattern')),
      findsOneWidget,
    );
    expect(find.text('进行中的小实验与目标'), findsOneWidget);
    expect(find.text('午后十分钟离屏恢复'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(
      tester,
      captureKey,
      'design_qa/weekly-next-week-tries-2026-07-17.png',
    );
  });
}

Future<void> _precacheReviewHero(
  WidgetTester tester,
  GlobalKey captureKey,
) async {
  await tester.pump();
  await tester.runAsync(
    () => precacheImage(
      const AssetImage('assets/hero_art/weekly-review-network-v1.png'),
      captureKey.currentContext!,
    ),
  );
  await tester.pump();
}

WeeklyInsightModel _deepAnalysisWeekly() {
  const days = [
    WeeklyEnergyDayModel(
      date: '2026-07-13',
      signalCount: 1,
      feedbackCount: 0,
      stateCounts: {'steady': 1},
      dominantState: 'steady',
    ),
    WeeklyEnergyDayModel(
      date: '2026-07-14',
      signalCount: 2,
      feedbackCount: 1,
      stateCounts: {'draining': 1, 'boundary_buffer': 1},
      dominantState: 'draining',
    ),
    WeeklyEnergyDayModel(
      date: '2026-07-15',
      signalCount: 3,
      feedbackCount: 0,
      stateCounts: {'draining': 1, 'steady': 1, 'boundary_buffer': 1},
      dominantState: 'boundary_buffer',
    ),
    WeeklyEnergyDayModel(
      date: '2026-07-16',
      signalCount: 1,
      feedbackCount: 1,
      stateCounts: {'recovery': 1},
      dominantState: 'recovery',
    ),
    WeeklyEnergyDayModel(
      date: '2026-07-17',
      signalCount: 2,
      feedbackCount: 1,
      stateCounts: {'draining': 1, 'steady': 1},
      dominantState: 'draining',
    ),
    WeeklyEnergyDayModel(
      date: '2026-07-18',
      signalCount: 1,
      feedbackCount: 0,
      stateCounts: {'ease': 1},
      dominantState: 'ease',
    ),
    WeeklyEnergyDayModel(
      date: '2026-07-19',
      signalCount: 1,
      feedbackCount: 1,
      stateCounts: {'recovery': 1},
      dominantState: 'recovery',
    ),
  ];
  return WeeklyInsightModel(
    weekStart: '2026-07-13',
    weekEnd: '2026-07-19',
    status: 'ready',
    keyInsight: '切换越密集，重新开始越困难。',
    patterns: const [
      {
        'name': '切换后难以重新进入状态',
        'summary': '上午和午后都出现了相同的切换—耗力顺序。',
        'illustration_hint': 'route_interrupted',
      },
    ],
    frictions: const [
      {
        'name': '频繁切换',
        'summary': '多个工作场景都出现了切换后的耗力。',
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
      '_report_readiness': {
        'signal_count': 11,
        'distinct_day_count': 7,
        'distinct_week_count': 1,
      },
    },
    feedbackSubmitted: false,
    chartData: const [
      WeeklyChartPointModel(
        date: '2026-07-13',
        signalCount: 1,
        moodScore: 0,
        frictionScore: 0.3,
        hasPositiveSignal: false,
      ),
      WeeklyChartPointModel(
        date: '2026-07-14',
        signalCount: 2,
        moodScore: -0.2,
        frictionScore: 0.6,
        hasPositiveSignal: false,
      ),
      WeeklyChartPointModel(
        date: '2026-07-15',
        signalCount: 3,
        moodScore: -0.3,
        frictionScore: 0.8,
        hasPositiveSignal: false,
      ),
      WeeklyChartPointModel(
        date: '2026-07-16',
        signalCount: 1,
        moodScore: 0.4,
        frictionScore: 0.2,
        hasPositiveSignal: true,
      ),
      WeeklyChartPointModel(
        date: '2026-07-17',
        signalCount: 2,
        moodScore: -0.1,
        frictionScore: 0.6,
        hasPositiveSignal: false,
      ),
      WeeklyChartPointModel(
        date: '2026-07-18',
        signalCount: 1,
        moodScore: 0.5,
        frictionScore: 0.1,
        hasPositiveSignal: true,
      ),
      WeeklyChartPointModel(
        date: '2026-07-19',
        signalCount: 1,
        moodScore: 0.3,
        frictionScore: 0.1,
        hasPositiveSignal: true,
      ),
    ],
    behaviorPatterns: const [
      WeeklyBehaviorPatternModel(
        id: 'pattern-switching',
        label: '切换后较难回到原来的节奏',
        summary: '临时消息后重新开始重要任务的记录同时出现。',
        kind: 'context_response',
        sourceSignalCardIds: ['signal-1', 'signal-2', 'signal-3'],
        supportDates: ['2026-07-14', '2026-07-15', '2026-07-17'],
        illustrationHint: 'route_interrupted',
      ),
    ],
    energyProjection: const WeeklyEnergyProjectionModel(
      days: days,
      totals: {
        'draining': 3,
        'steady': 3,
        'ease': 1,
        'recovery': 2,
        'boundary_buffer': 2,
      },
      recommendation: 'maintain',
      rationale: '恢复 Signal 已出现，但切换后的耗力仍然明显，适合维持当前负荷。',
    ),
  );
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
  String path,
) async {
  await tester.runAsync(() async {
    final boundary =
        captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final output = File(path);
    await output.parent.create(recursive: true);
    await output.writeAsBytes(
      bytes!.buffer.asUint8List(),
      flush: true,
    );
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
      ),
      home: child,
    );
  }
}

class _DesignCandidatePlanningRepository
    extends LocalCandidatePlanningRepository {
  _DesignCandidatePlanningRepository()
      : super(
          localDatabase: LocalDatabase(
            dbPathOverride: 'weekly_secondary_design_candidate.db',
          ),
          localCaptureRepository: LocalCaptureRepository(
            LocalDatabase(
              dbPathOverride: 'weekly_secondary_design_capture.db',
            ),
          ),
          localLifeExperimentRepository: LocalLifeExperimentRepository(
            LocalDatabase(
              dbPathOverride: 'weekly_secondary_design_experiment.db',
            ),
          ),
          localUserId: 'design-review',
        );

  static const _gate = CandidateGateState(
    kind: CandidateKind.lifeExperiment,
    periodStart: '2026-07-13',
    periodEnd: '2026-07-19',
    eligibleSignalCount: 8,
    eligibleSignalCardIds: [
      'signal-1',
      'signal-2',
      'signal-3',
      'signal-4',
      'signal-5',
      'signal-6',
      'signal-7',
      'signal-8',
    ],
  );

  static const _generation = CandidateGenerationState(
    kind: CandidateKind.lifeExperiment,
    periodStart: '2026-07-13',
    periodEnd: '2026-07-19',
    status: CandidateGenerationStatus.ready,
    eligibleSignalCount: 8,
  );

  static const _smallTries = [
    MicroActionCandidateModel(
      id: 'next-small-try',
      candidateGroupId: 'next-week-plan',
      localUserId: 'design-review',
      localDate: '2026-07-20',
      rank: 1,
      title: '切换任务前留两分钟缓冲',
      reason: '来自本周频繁切换与恢复空隙的 Signal。',
      difficulty: 'very_light',
      linkedSignalCardIds: ['signal-1', 'signal-2', 'signal-3'],
      focusDomainIds: ['growth_plan'],
      status: 'generated',
      sourceHash: 'next-week-plan-v1',
      energyCapacityBand: EnergyCapacityBand.medium,
      energyAdaptationExplanation: '当前能量状态适合低切换、可暂停的小尝试。',
      recommendedIntensity: 'very_light',
    ),
  ];

  static const _goals = [
    ExperimentCandidateRecord(
      id: 'next-goal-recovery',
      candidateGroupId: 'next-week-plan',
      localUserId: 'design-review',
      weekStart: '2026-07-20',
      weekEnd: '2026-07-26',
      rank: 1,
      title: '保留一个固定恢复块',
      hypothesis: '在疲惫刚出现时恢复，可能更容易重新进入状态。',
      suggestedAction: '午后第一次明显疲惫时，离开屏幕十分钟。',
      linkedSignalCardIds: ['signal-2', 'signal-4', 'signal-6'],
      linkedObservationIds: [],
      confidenceLevel: 'medium',
      metadata: {},
      status: 'generated',
      sourceHash: 'next-week-plan-v1',
      energyCapacityBand: EnergyCapacityBand.medium,
      energyAdaptationExplanation: '保持规模轻量，不额外增加安排。',
      recommendedIntensity: 'light',
    ),
    ExperimentCandidateRecord(
      id: 'next-goal-boundary',
      candidateGroupId: 'next-week-plan',
      localUserId: 'design-review',
      weekStart: '2026-07-20',
      weekEnd: '2026-07-26',
      rank: 2,
      title: '保护每天一段不被切换的时间',
      hypothesis: '一段有边界的时间，可能减少不断重新开始的耗力。',
      suggestedAction: '每天选一段二十分钟，把即时消息暂时静音。',
      linkedSignalCardIds: ['signal-1', 'signal-3', 'signal-5'],
      linkedObservationIds: [],
      confidenceLevel: 'medium',
      metadata: {},
      status: 'generated',
      sourceHash: 'next-week-plan-v1',
      energyCapacityBand: EnergyCapacityBand.medium,
      energyAdaptationExplanation: '只保护一小段时间，避免形成新的压力。',
      recommendedIntensity: 'light',
    ),
  ];

  static const _continuing = AdoptedLifeExperimentProgress(
    experiment: LifeExperimentModel(
      id: 'continuing-recovery',
      localUserId: 'design-review',
      sourceWeekStart: '2026-07-13',
      sourceWeekEnd: '2026-07-19',
      title: '午后十分钟离屏恢复',
      hypothesis: '在疲惫刚出现时离屏，可能更容易恢复。',
      suggestedAction: '午后第一次明显疲惫时，离开屏幕十分钟。',
      linkedSignalCardIds: ['signal-2', 'signal-4'],
      status: 'active',
      progressStartDate: '2026-07-13',
      progressEndDate: '2026-07-19',
    ),
    progress: SevenDayProgressModel(
      subjectId: 'continuing-recovery',
      startDate: '2026-07-13',
      endDate: '2026-07-19',
      cells: [
        SevenDayProgressCell(
          localDate: '2026-07-13',
          state: ProgressCellState.completed,
        ),
        SevenDayProgressCell(
          localDate: '2026-07-14',
          state: ProgressCellState.notCompleted,
        ),
        SevenDayProgressCell(
          localDate: '2026-07-15',
          state: ProgressCellState.completed,
        ),
        SevenDayProgressCell(
          localDate: '2026-07-16',
          state: ProgressCellState.empty,
        ),
        SevenDayProgressCell(
          localDate: '2026-07-17',
          state: ProgressCellState.completed,
        ),
        SevenDayProgressCell(
          localDate: '2026-07-18',
          state: ProgressCellState.empty,
        ),
        SevenDayProgressCell(
          localDate: '2026-07-19',
          state: ProgressCellState.empty,
        ),
      ],
    ),
  );

  CandidateSnapshot<ExperimentCandidateRecord> get _experimentSnapshot =>
      const CandidateSnapshot(
        gate: _gate,
        generation: _generation,
        candidates: _goals,
      );

  @override
  Future<CandidateSnapshot<ExperimentCandidateRecord>> weeklyCandidateSnapshot(
    DateTime day,
  ) async {
    return _experimentSnapshot;
  }

  @override
  Future<NextWeekPlanCandidateSnapshot>
      refreshNextWeekPlanWithGroundedSuggestions({
    required DateTime day,
    AppLanguage language = AppLanguage.simplifiedChinese,
  }) async {
    return nextWeekPlanCandidateSnapshot(day);
  }

  @override
  Future<NextWeekPlanCandidateSnapshot> nextWeekPlanCandidateSnapshot(
    DateTime day,
  ) async {
    return const NextWeekPlanCandidateSnapshot(
      gate: _gate,
      targetWeekStart: '2026-07-20',
      targetWeekEnd: '2026-07-26',
      smallTryCandidates: _smallTries,
      goalCandidates: _goals,
    );
  }

  @override
  Stream<CandidateGenerationState> watchGenerationState({
    required CandidateKind kind,
    required String periodStart,
    required String periodEnd,
  }) {
    return Stream.value(_generation);
  }

  @override
  Future<List<AdoptedLifeExperimentProgress>>
      listContinuableExperimentsForNextWeek(DateTime day) async {
    return const [_continuing];
  }

  @override
  Future<List<AdoptedMicroActionProgress>>
      listContinuableMicroActionsForNextWeek(DateTime day) async {
    return const [];
  }

  @override
  Future<List<MicroActionModel>> listPlannedMicroActionsForNextWeek(
    DateTime day,
  ) async {
    return const [];
  }

  @override
  Future<List<LifeExperimentModel>> listPlannedExperimentsForNextWeek(
    DateTime day,
  ) async {
    return const [];
  }
}

const _designReviewFontFamily = 'DesignReviewCJK';
