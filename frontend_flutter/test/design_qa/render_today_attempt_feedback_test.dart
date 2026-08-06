import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_opportunity_radar/core/local/local_candidate_planning_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_capture_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/local/local_life_experiment_repository.dart';
import 'package:ai_opportunity_radar/core/models/candidate_models.dart';
import 'package:ai_opportunity_radar/core/models/phase3_plus_models.dart';
import 'package:ai_opportunity_radar/core/models/weekly_models.dart';
import 'package:ai_opportunity_radar/features/pages/today/today_adopted_plans_section.dart';

import '../helpers/design_qa_font_loader.dart';

const _designReviewFontFamily = 'DesignReviewCJK';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadDesignQaFonts(_designReviewFontFamily);
  });

  testWidgets(
    'renders Today small experiment and goal feedback states for design QA',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const action = MicroActionModel(
        id: 'qa-small-experiment',
        judgementId: 'qa-judgement',
        title: '任务切换前留两分钟缓冲',
        reason: '现在就能开始的一次简单尝试。',
        status: 'active',
      );
      const goal = LifeExperimentModel(
        id: 'qa-goal',
        localUserId: 'qa-user',
        sourceWeekStart: '2026-07-27',
        sourceWeekEnd: '2026-08-02',
        title: '午后十分钟离屏恢复',
        hypothesis: '在疲惫刚出现时离屏，可能更容易恢复。',
        suggestedAction: '午后第一次明显疲惫时，离开屏幕十分钟。',
        linkedSignalCardIds: [],
        status: 'active',
      );
      final repository = _QaPlanningRepository(
        actions: [
          const AdoptedMicroActionProgress(
            action: action,
            progress: SevenDayProgressModel(
              subjectId: 'qa-small-experiment',
              startDate: '2026-07-27',
              endDate: '2026-07-27',
              cells: [
                SevenDayProgressCell(
                  localDate: '2026-07-27',
                  state: ProgressCellState.completed,
                  latestEventId: 'qa-attempt-1',
                ),
                SevenDayProgressCell(
                  localDate: '2026-07-27',
                  state: ProgressCellState.notCompleted,
                  latestEventId: 'qa-attempt-2',
                ),
                SevenDayProgressCell(
                  localDate: '2026-07-27',
                  state: ProgressCellState.completed,
                  latestEventId: 'qa-attempt-3',
                ),
              ],
            ),
          ),
        ],
        goals: [
          const AdoptedLifeExperimentProgress(
            experiment: goal,
            progress: SevenDayProgressModel(
              subjectId: 'qa-goal',
              startDate: '2026-07-27',
              endDate: '2026-08-02',
              cells: [
                SevenDayProgressCell(
                  localDate: '2026-07-27',
                  state: ProgressCellState.completed,
                ),
                SevenDayProgressCell(
                  localDate: '2026-07-28',
                  state: ProgressCellState.completed,
                ),
                SevenDayProgressCell(
                  localDate: '2026-07-29',
                  state: ProgressCellState.completed,
                ),
                SevenDayProgressCell(
                  localDate: '2026-07-30',
                  state: ProgressCellState.completed,
                ),
                SevenDayProgressCell(
                  localDate: '2026-07-31',
                  state: ProgressCellState.empty,
                ),
                SevenDayProgressCell(
                  localDate: '2026-08-01',
                  state: ProgressCellState.empty,
                ),
                SevenDayProgressCell(
                  localDate: '2026-08-02',
                  state: ProgressCellState.empty,
                ),
              ],
            ),
          ),
        ],
      );
      final captureKey = GlobalKey();

      await tester.pumpWidget(
        RepaintBoundary(
          key: captureKey,
          child: _QaApp(
            child: Scaffold(
              extendBody: true,
              body: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
                child: TodayAdoptedPlansSection(
                  signals: const [],
                  compatibilityAction: null,
                  compatibilityExperiment: null,
                  isBusy: false,
                  repositoryOverride: repository,
                  onActionFeedback: (_, __) async {},
                  onExperimentFeedback: (_, __) async {},
                  onOpenAll: () {},
                  onOpenActionHub: () {},
                  onOpenExperimentHub: () {},
                ),
              ),
              bottomNavigationBar: const _QaBottomNavigation(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('尝试 2 次 · 未尝试 1 次'), findsOneWidget);
      expect(find.text('已完成 4 天'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _capture(
        tester,
        captureKey,
        'design_qa/today-attempts-focused-390x844-2026-07-27.png',
      );

      await tester.tap(
        find.byKey(
          const ValueKey(
            'today-small-experiment-completed-qa-small-experiment',
          ),
        ),
      );
      await tester.pumpAndSettle();
      final details = find.byKey(
        const ValueKey('today-small-experiment-completed-details'),
      );
      expect(details, findsOneWidget);
      final save = find.byKey(
        const ValueKey('today-small-experiment-save-completed'),
      );
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();

      final navigationTop =
          tester.getTopLeft(find.byKey(const ValueKey('qa-bottom-navigation')));
      final saveBottom = tester.getBottomLeft(save);
      expect(saveBottom.dy, lessThanOrEqualTo(navigationTop.dy));
      expect(tester.takeException(), isNull);
      await _capture(
        tester,
        captureKey,
        'design_qa/today-small-experiment-feedback-390x844-2026-07-27.png',
      );
    },
  );
}

class _QaApp extends StatelessWidget {
  final Widget child;

  const _QaApp({required this.child});

  @override
  Widget build(BuildContext context) {
    const scheme = ColorScheme.light(
      primary: Color(0xFF7767F4),
      onPrimary: Colors.white,
      secondary: Color(0xFF5F95E8),
      tertiary: Color(0xFF62C594),
      surface: Color(0xFFFFFCFA),
      onSurface: Color(0xFF252B4A),
      surfaceContainerHighest: Color(0xFFF5F4F8),
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
        fontFamily: _designReviewFontFamily,
        scaffoldBackgroundColor: scheme.surface,
        textTheme: const TextTheme(
          headlineMedium:
              TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.2),
          headlineSmall:
              TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0),
          titleLarge: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0),
          titleMedium: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0),
          bodyLarge: TextStyle(height: 1.48, letterSpacing: 0),
          bodyMedium: TextStyle(height: 1.48, letterSpacing: 0),
        ),
      ),
      home: child,
    );
  }
}

class _QaBottomNavigation extends StatelessWidget {
  const _QaBottomNavigation();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('qa-bottom-navigation'),
      height: 84,
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE5E3F3)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _QaNavigationItem(icon: Icons.chat_bubble_rounded, label: '今天'),
          _QaNavigationItem(icon: Icons.calendar_month_rounded, label: '每周复盘'),
          _QaNavigationItem(icon: Icons.science_outlined, label: '生活小实验'),
          _QaNavigationItem(icon: Icons.explore_outlined, label: '旅程'),
          _QaNavigationItem(icon: Icons.person_outline_rounded, label: '我的'),
        ],
      ),
    );
  }
}

class _QaNavigationItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _QaNavigationItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF858A9D)),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: const Color(0xFF858A9D),
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _QaPlanningRepository extends LocalCandidatePlanningRepository {
  final List<AdoptedMicroActionProgress> actions;
  final List<AdoptedLifeExperimentProgress> goals;

  _QaPlanningRepository({
    required this.actions,
    required this.goals,
  }) : super(
          localDatabase: LocalDatabase(
            dbPathOverride: 'today_design_qa_candidate.db',
          ),
          localCaptureRepository: LocalCaptureRepository(
            LocalDatabase(
              dbPathOverride: 'today_design_qa_capture.db',
            ),
          ),
          localLifeExperimentRepository: LocalLifeExperimentRepository(
            LocalDatabase(
              dbPathOverride: 'today_design_qa_goal.db',
            ),
          ),
          localUserId: 'qa-user',
        );

  @override
  Future<CandidateGateState> dailyGate(DateTime day) async {
    return const CandidateGateState(
      kind: CandidateKind.microAction,
      periodStart: '2026-07-27',
      periodEnd: '2026-07-27',
      eligibleSignalCount: 4,
    );
  }

  @override
  Future<CandidateGateState> weeklyGate(DateTime day) async {
    return const CandidateGateState(
      kind: CandidateKind.lifeExperiment,
      periodStart: '2026-07-27',
      periodEnd: '2026-08-02',
      eligibleSignalCount: 9,
    );
  }

  @override
  Future<List<AdoptedMicroActionProgress>> listActiveMicroActionsForDate(
    DateTime day,
  ) async {
    return actions;
  }

  @override
  Future<List<AdoptedLifeExperimentProgress>> listActiveExperimentsForDate(
    DateTime day,
  ) async {
    return goals;
  }
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
