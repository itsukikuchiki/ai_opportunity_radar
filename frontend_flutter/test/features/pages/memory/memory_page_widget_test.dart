import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ai_opportunity_radar/core/api/repositories/memory_repository.dart';
import 'package:ai_opportunity_radar/core/models/memory_models.dart';
import 'package:ai_opportunity_radar/core/readiness/report_readiness.dart';
import 'package:ai_opportunity_radar/features/pages/me/me_view_model.dart';
import 'package:ai_opportunity_radar/features/pages/memory/memory_page.dart';
import 'package:ai_opportunity_radar/features/pages/memory/memory_view_model.dart';
import 'package:ai_opportunity_radar/shared/widgets/aurora_ui.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Journey 历史月份切换会按所选月份重新取数且禁止未来月', (tester) async {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final previousMonth = DateTime(now.year, now.month - 1);
    final repo = _MonthAwareMemoryRepository(
      currentMonth: currentMonth,
      currentResult: const MemoryFetchResult(
        isFirstDayGate: false,
        summary: null,
      ),
      previousResult: MemoryFetchResult(
        isFirstDayGate: false,
        summary: MemorySummaryModel(
          patterns: const [],
          frictions: const [],
          desires: const [],
          experiments: const [],
          journeyTraces: [
            JourneyTraceModel(
              id: 'previous-month-signal',
              sourceType: 'signal_card',
              title: '上个月的一个轨迹点',
              summary: 'This content belongs only to the selected month.',
              localDate:
                  '${previousMonth.year}-${previousMonth.month.toString().padLeft(2, '0')}-08',
              cluster: 'steady',
              intensity: 0.5,
              signalLevel: 'weak_signal',
              metadata: const {'display_lane': 'monthly_path'},
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        child: const MemoryPage(),
        providers: [
          ChangeNotifierProvider<MemoryViewModel>(
            create: (_) => MemoryViewModel(repo),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.requestedMonths, [currentMonth]);
    expect(find.text('这个月没有留下记录。'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('journey-previous-month')));
    await tester.pumpAndSettle();
    expect(repo.requestedMonths.last, previousMonth);
    expect(
      find.text('${previousMonth.year}年${previousMonth.month}月 · 你的生活轨迹'),
      findsOneWidget,
    );
    expect(find.text('上个月的一个轨迹点'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('journey-next-month')));
    await tester.pumpAndSettle();
    expect(repo.requestedMonths.last, currentMonth);
    expect(find.text('上个月的一个轨迹点'), findsNothing);
    expect(find.text('这个月没有留下记录。'), findsOneWidget);
    final requestCount = repo.requestedMonths.length;
    await tester.tap(find.byKey(const ValueKey('journey-next-month')));
    await tester.pump();
    expect(repo.requestedMonths.length, requestCount);
  });

  testWidgets('Journey 页面能加载并触发一次数据获取', (tester) async {
    final repo = StubMemoryRepository(
      result: MemoryFetchResult(
        isFirstDayGate: false,
        summary: MemorySummaryModel(
          patterns: const [
            JourneySignalItemModel(
              name: 'Needing a quiet reset after meetings',
              summary: 'A small need is starting to repeat.',
              signalLevel: 'weak_signal',
            ),
          ],
          frictions: const [
            JourneySignalItemModel(
              name: 'Interruptions during focused work',
              summary:
                  'This has already repeated enough to count as a pattern.',
              signalLevel: 'repeated_pattern',
            ),
          ],
          desires: const [],
          experiments: const [
            JourneySignalItemModel(
              name: 'A short evening reset walk',
              summary: 'This is starting to settle into a stable mode.',
              signalLevel: 'stable_mode',
            ),
          ],
          journeyTraces: const [
            JourneyTraceModel(
              id: 'sig_widget',
              sourceType: 'signal_card',
              title: 'Meeting recovery',
              summary: 'A real signal from Today.',
              localDate: '2026-07-05',
              cluster: 'recovery',
              intensity: 0.6,
              signalLevel: 'weak_signal',
              metadata: {'display_lane': 'monthly_path'},
            ),
            JourneyTraceModel(
              id: 'weekly_widget',
              sourceType: 'weekly_review',
              title: 'Weekly behavior pattern must not enter monthly path',
              summary: 'Weekly synthesis.',
              localDate: '2026-07-05',
              cluster: 'weekly',
              intensity: 0.5,
              signalLevel: 'repeated_pattern',
            ),
            JourneyTraceModel(
              id: 'attempt_widget',
              sourceType: 'micro_action_feedback',
              title: 'Two-minute reset',
              summary: 'Completed once.',
              localDate: '2026-07-05',
              cluster: 'experiment',
              intensity: 0.5,
              signalLevel: 'weak_signal',
              metadata: {'display_lane': 'experiment_goal_track'},
            ),
            JourneyTraceModel(
              id: 'legacy_schedule_widget',
              sourceType: 'schedule_feedback',
              title: 'Legacy schedule feedback must stay hidden',
              summary: 'Legacy compatibility data.',
              localDate: '2026-07-05',
              cluster: 'work',
              intensity: 0.5,
              signalLevel: 'weak_signal',
            ),
          ],
          periodFacts: const JourneyPeriodFactsModel(
            periodStart: '2026-07-01',
            periodEnd: '2026-07-31',
            signalCount: 7,
            activeDayCount: 3,
            smallExperimentAttemptCount: 1,
            goalFeedbackCount: 2,
            energyStateCounts: {
              'draining': 1,
              'steady': 2,
              'ease': 1,
              'recovery': 2,
              'boundary_buffer': 1,
            },
            days: [
              JourneyDayFactModel(
                localDate: '2026-07-05',
                signalCount: 2,
                smallExperimentAttemptCount: 1,
                goalFeedbackCount: 1,
              ),
            ],
            experimentTracks: [
              JourneyExperimentTrackModel(
                subjectId: 'small-1',
                kind: 'small_experiment',
                title: 'Two-minute reset',
                attemptCount: 1,
                roundReviewCount: 1,
                latestResult: 'Felt easier to restart.',
                latestLocalDate: '2026-07-05',
              ),
              JourneyExperimentTrackModel(
                subjectId: 'goal-1',
                kind: 'goal',
                title: 'Protect evening recovery',
                feedbackCount: 2,
                weeklyReviewCount: 1,
                latestResult: 'Recovery started earlier.',
                latestLocalDate: '2026-07-05',
              ),
            ],
          ),
          observations: const [
            JourneyObservationModel(
              id: 'obs_widget',
              text: 'Meetings and recovery appeared together.',
              status: 'confirmed',
              confidence: 'high',
              observationType: 'hypothesis',
              evidenceText: 'Two meeting notes mention recovery.',
              suggestedPattern:
                  'Recovery after meetings is becoming a pattern.',
              localDate: '2026-07-05',
            ),
            JourneyObservationModel(
              id: 'obs_generated',
              text: 'Evening resets may be starting to matter.',
              status: 'generated',
              confidence: 'medium',
              observationType: 'hypothesis',
              evidenceText: 'One evening note mentioned a reset.',
              suggestedPattern: '',
              localDate: '2026-07-04',
            ),
            JourneyObservationModel(
              id: 'obs_dismissed',
              text: 'A dismissed observation remains visible as excluded.',
              status: 'dismissed',
              confidence: 'low',
              observationType: 'hypothesis',
              evidenceText: '',
              suggestedPattern: '',
              localDate: '2026-07-03',
            ),
          ],
        ),
      ),
      evidenceItems: const [
        JourneyEvidenceItemModel(
          sourceType: 'signal_card',
          sourceId: 'sig_widget',
          title: 'Signal source',
          summary: 'Meeting recovery needed.',
          localDate: '2026-07-05',
          relationType: 'uses_trace',
        ),
        JourneyEvidenceItemModel(
          sourceType: 'observation',
          sourceId: 'obs_widget',
          title: 'Observation',
          summary: 'Meetings and recovery appeared together.',
          localDate: '2026-07-05',
          relationType: 'uses_trace',
        ),
        JourneyEvidenceItemModel(
          sourceType: 'weekly_review',
          sourceId: 'weekly_widget',
          title: 'Weekly Reflection',
          summary: 'Recovery became clearer this week.',
          localDate: '2026-07-05',
          relationType: 'uses_trace',
        ),
        JourneyEvidenceItemModel(
          sourceType: 'life_experiment_feedback',
          sourceId: 'fb_widget',
          title: 'Experiment Feedback',
          summary: 'The small reset helped.',
          localDate: '2026-07-05',
          relationType: 'uses_trace',
        ),
        JourneyEvidenceItemModel(
          sourceType: 'schedule_feedback',
          sourceId: 'legacy_schedule_widget',
          title: 'Legacy schedule evidence must stay hidden',
          summary: 'Legacy compatibility data.',
          localDate: '2026-07-05',
          relationType: 'uses_trace',
        ),
      ],
    );

    final meVm = await buildMeViewModel(repeatArea: 'time_rhythm');

    await tester.pumpWidget(
      buildTestApp(
        child: const MemoryPage(),
        providers: [
          ChangeNotifierProvider<MemoryViewModel>(
            create: (_) => MemoryViewModel(repo),
          ),
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(MemoryPage), findsOneWidget);
    final scrollView = find.byKey(const ValueKey('journey-scroll-view'));
    expect(scrollView, findsOneWidget);
    final listView = tester.widget<ListView>(scrollView);
    expect(
      listView.padding,
      const EdgeInsets.fromLTRB(18, 14, 18, 96),
    );
    final hero = find.byKey(const ValueKey('journey-hero-header'));
    expect(hero, findsOneWidget);
    expect(tester.getSize(hero).height, lessThanOrEqualTo(192));
    final journeyTitle = tester.widget<Text>(find.text('Journey'));
    expect(journeyTitle.style?.fontSize, 36);
    expect(journeyTitle.style?.fontWeight, FontWeight.w700);
    expect(journeyTitle.style?.fontFamily, isNot('Georgia'));
    expect(find.byType(AuroraHeroTitle), findsOneWidget);
    expect(find.byType(AuroraJourneyHeroPattern), findsOneWidget);
    expect(
      find.byKey(const ValueKey('journey-hero-pattern')),
      findsOneWidget,
    );
    expect(find.byType(AuroraHeroEmblem), findsNothing);
    expect(find.byType(AuroraSignalHeroPattern), findsNothing);
    expect(find.byType(AuroraReviewHeroPattern), findsNothing);
    expect(find.text('Journey'), findsOneWidget);
    expect(find.text('Open journal view'), findsNothing);
    expect(find.text('打开手帐视图'), findsNothing);

    final journeyScrollable = find
        .descendant(of: scrollView, matching: find.byType(Scrollable))
        .first;

    final monthlyPath = find.byKey(const ValueKey('journey-monthly-path'));
    expect(monthlyPath, findsOneWidget);
    expect(
      find.descendant(of: monthlyPath, matching: find.text('Meeting recovery')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: monthlyPath,
        matching:
            find.text('Weekly behavior pattern must not enter monthly path'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: monthlyPath, matching: find.text('Two-minute reset')),
      findsNothing,
    );
    expect(
      find.text('Legacy schedule feedback must stay hidden'),
      findsNothing,
    );
    expect(repo.fetchCallCount, 1);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('journey-monthly-facts')),
      280,
      scrollable: journeyScrollable,
    );
    expect(find.text('7'), findsWidgets);
    expect(find.text('3'), findsWidgets);
    expect(find.text('1'), findsWidgets);
    expect(find.text('2'), findsWidgets);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('journey-experiment-goal-trajectory')),
      280,
      scrollable: journeyScrollable,
    );
    expect(find.text('Two-minute reset'), findsOneWidget);
    expect(find.text('1 real attempt'), findsOneWidget);
    expect(find.textContaining('1 round review'), findsOneWidget);
    expect(find.text('Protect evening recovery'), findsOneWidget);
    expect(find.text('2 progress records'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('journey-state-rhythm')),
      280,
      scrollable: journeyScrollable,
    );
    expect(find.text('Effortful 1'), findsOneWidget);
    expect(find.text('Steady 2'), findsOneWidget);
    expect(find.text('Room to spare 1'), findsOneWidget);
    expect(find.text('Recovery 2'), findsOneWidget);
    expect(find.text('Boundaries and space 1'), findsOneWidget);
    expect(repo.evidenceCallCount, 0);
  });

  testWidgets('Journey 第一天 gate 会显示对应空态', (tester) async {
    final repo = StubMemoryRepository(
      result: const MemoryFetchResult(
        isFirstDayGate: true,
        summary: null,
      ),
    );

    final meVm = await buildMeViewModel();

    await tester.pumpWidget(
      buildTestApp(
        child: const MemoryPage(),
        providers: [
          ChangeNotifierProvider<MemoryViewModel>(
            create: (_) => MemoryViewModel(repo),
          ),
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Monthly synthesis is still forming'), findsOneWidget);
    final scrollView = find.byKey(const ValueKey('journey-scroll-view'));
    expect(scrollView, findsOneWidget);
    final listView = tester.widget<ListView>(scrollView);
    expect(
      listView.padding,
      const EdgeInsets.fromLTRB(18, 14, 18, 96),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('journey-hero-header'))).height,
      lessThanOrEqualTo(192),
    );
  });

  testWidgets('Journey 未达门槛时显示 Free 与 Pro 的明确数据进度', (tester) async {
    final repo = StubMemoryRepository(
      result: const MemoryFetchResult(
        isFirstDayGate: false,
        summary: null,
        journeyReadiness: ReportReadiness(
          rule: ReportReadinessEvaluator.journeyRule,
          signalCount: 2,
          distinctDayCount: 1,
          distinctWeekCount: 1,
        ),
      ),
    );
    final meVm = await buildMeViewModel();

    await tester.pumpWidget(
      buildTestApp(
        child: const MemoryPage(),
        providers: [
          ChangeNotifierProvider<MemoryViewModel>(
            create: (_) => MemoryViewModel(repo),
          ),
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('journey-report-threshold-notice')),
      findsOneWidget,
    );
    expect(
        find.textContaining('5 Signal(s) and 2 day(s) remain'), findsOneWidget);
    expect(find.byKey(const ValueKey('journey-pro-entry')), findsOneWidget);
  });

  testWidgets('Journey 报告未达门槛也不隐藏免费事实视图', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = StubMemoryRepository(
      result: MemoryFetchResult(
        isFirstDayGate: false,
        summary: MemorySummaryModel(
          patterns: const [],
          frictions: const [],
          desires: const [],
          experiments: const [],
          journeyTraces: const [
            JourneyTraceModel(
              id: 'forming-signal',
              sourceType: 'signal_card',
              title: 'A real timeline signal',
              summary: 'User-owned evidence remains visible.',
              localDate: '2026-07-12',
              cluster: 'life',
              intensity: 0.5,
              signalLevel: 'weak_signal',
              metadata: {'display_lane': 'monthly_path'},
            ),
          ],
          periodFacts: const JourneyPeriodFactsModel(
            periodStart: '2026-07-01',
            periodEnd: '2026-07-31',
            signalCount: 1,
            activeDayCount: 1,
            energyStateCounts: {'steady': 1},
            days: [
              JourneyDayFactModel(
                localDate: '2026-07-12',
                signalCount: 1,
                energyStateCounts: {'steady': 1},
              ),
            ],
          ),
        ),
        journeyReadiness: const ReportReadiness(
          rule: ReportReadinessEvaluator.journeyRule,
          signalCount: 1,
          distinctDayCount: 1,
          distinctWeekCount: 1,
        ),
      ),
    );
    final meVm = await buildMeViewModel();

    await tester.pumpWidget(
      buildTestApp(
        child: const MemoryPage(),
        providers: [
          ChangeNotifierProvider<MemoryViewModel>(
            create: (_) => MemoryViewModel(repo),
          ),
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Monthly synthesis is still forming'), findsOneWidget);
    final scrollView = find.byKey(const ValueKey('journey-scroll-view'));
    final journeyScrollable = find
        .descendant(of: scrollView, matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('journey-monthly-path')),
      220,
      scrollable: journeyScrollable,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('journey-monthly-path')),
        matching: find.text('A real timeline signal'),
      ),
      findsOneWidget,
    );
    expect(find.text('A real timeline signal'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('journey-monthly-facts')),
      220,
      scrollable: journeyScrollable,
    );
    expect(find.text('Facts this month'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('journey-state-rhythm')),
      220,
      scrollable: journeyScrollable,
    );
    expect(
      find.byKey(const ValueKey('journey-state-rhythm')),
      findsOneWidget,
    );
    expect(find.text('Steady 1'), findsOneWidget);
    expect(find.text('Recovery 0'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('journey-report-threshold-notice')),
      findsOneWidget,
    );
    expect(
        find.byKey(const ValueKey('journey-themes-and-changes')), findsNothing);
    expect(find.byKey(const ValueKey('journey-month-review')), findsNothing);
  });

  testWidgets('Journey 紧凑宽度沿用 Today 的 34 号主标题', (tester) async {
    tester.view.physicalSize = const Size(350, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = StubMemoryRepository(
      result: const MemoryFetchResult(
        isFirstDayGate: true,
        summary: null,
      ),
    );
    final meVm = await buildMeViewModel();

    await tester.pumpWidget(
      buildTestApp(
        child: const MemoryPage(),
        providers: [
          ChangeNotifierProvider<MemoryViewModel>(
            create: (_) => MemoryViewModel(repo),
          ),
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('journey-scroll-view')), findsOneWidget);
    expect(find.byKey(const ValueKey('journey-hero-header')), findsOneWidget);
    expect(tester.widget<Text>(find.text('Journey')).style?.fontSize, 34);
    expect(tester.takeException(), isNull);
  });

  testWidgets('简体中文旅程不显示原始场景枚举且信号计数完整', (tester) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    String dateKey(int day) =>
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    final repo = StubMemoryRepository(
      result: MemoryFetchResult(
        isFirstDayGate: false,
        summary: MemorySummaryModel(
          patterns: const [
            JourneySignalItemModel(
              name: '正在形成的生活路径',
              summary: '目前最清楚的是“work”。',
              signalLevel: 'repeated_pattern',
            ),
          ],
          frictions: const [],
          desires: const [],
          experiments: const [
            JourneySignalItemModel(
              name: '短暂离屏恢复',
              summary: '真实实验线索。',
              signalLevel: 'weak_signal',
            ),
          ],
          journeyTraces: [
            JourneyTraceModel(
              id: 'emotional-trace',
              sourceType: 'signal_card',
              title: 'emotional',
              summary: '情绪线索。',
              localDate: dateKey(3),
              cluster: 'life',
              intensity: 0.5,
              signalLevel: 'weak_signal',
            ),
            JourneyTraceModel(
              id: 'friction-trace',
              sourceType: 'signal_card',
              title: 'daily_friction',
              summary: '日常摩擦线索。',
              localDate: dateKey(2),
              cluster: 'friction',
              intensity: 0.5,
              signalLevel: 'weak_signal',
            ),
            JourneyTraceModel(
              id: 'doubt-trace',
              sourceType: 'signal_card',
              title: 'self_doubt',
              summary: '自我怀疑线索。',
              localDate: dateKey(1),
              cluster: 'life',
              intensity: 0.5,
              signalLevel: 'weak_signal',
            ),
          ],
        ),
        journeyReadiness: const ReportReadiness(
          rule: ReportReadinessEvaluator.journeyRule,
          signalCount: 18,
          distinctDayCount: 14,
          distinctWeekCount: 3,
        ),
      ),
    );
    final meVm = await buildMeViewModel();

    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        child: const MemoryPage(),
        providers: [
          ChangeNotifierProvider<MemoryViewModel>(
            create: (_) => MemoryViewModel(repo),
          ),
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('目前最清楚的是“工作”。'), findsWidgets);
    expect(find.textContaining('18 条有效信号'), findsOneWidget);
    expect(find.text('情绪'), findsWidgets);
    expect(find.text('日常摩擦'), findsOneWidget);
    expect(find.text('自我怀疑'), findsOneWidget);
    expect(find.text('emotional'), findsNothing);
    expect(find.text('daily_friction'), findsNothing);
    expect(find.text('self_doubt'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Journey 错误态沿用统一主页面边距与紧凑 Hero', (tester) async {
    final repo = _ThrowingMemoryRepository();
    final meVm = await buildMeViewModel();

    await tester.pumpWidget(
      buildTestApp(
        child: const MemoryPage(),
        providers: [
          ChangeNotifierProvider<MemoryViewModel>(
            create: (_) => MemoryViewModel(repo),
          ),
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Journey failed to load'), findsOneWidget);
    final scrollView = find.byKey(const ValueKey('journey-scroll-view'));
    expect(scrollView, findsOneWidget);
    expect(
      tester.widget<ListView>(scrollView).padding,
      const EdgeInsets.fromLTRB(18, 14, 18, 96),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('journey-hero-header'))).height,
      lessThanOrEqualTo(192),
    );
  });
}

class _ThrowingMemoryRepository extends StubMemoryRepository {
  _ThrowingMemoryRepository()
      : super(
          result: const MemoryFetchResult(
            isFirstDayGate: false,
            summary: null,
          ),
        );

  @override
  Future<MemoryFetchResult> fetchMemorySummaryResult({DateTime? month}) async {
    throw StateError('journey load failed');
  }
}

class _MonthAwareMemoryRepository extends StubMemoryRepository {
  final DateTime currentMonth;
  final MemoryFetchResult currentResult;
  final MemoryFetchResult previousResult;

  _MonthAwareMemoryRepository({
    required this.currentMonth,
    required this.currentResult,
    required this.previousResult,
  }) : super(result: currentResult);

  @override
  Future<MemoryFetchResult> fetchMemorySummaryResult({DateTime? month}) async {
    fetchCallCount += 1;
    requestedMonths.add(month);
    if (month != null && month.isBefore(currentMonth)) return previousResult;
    return currentResult;
  }
}
