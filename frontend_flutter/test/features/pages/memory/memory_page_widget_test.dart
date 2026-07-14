import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ai_opportunity_radar/core/api/repositories/memory_repository.dart';
import 'package:ai_opportunity_radar/core/models/memory_models.dart';
import 'package:ai_opportunity_radar/core/readiness/report_readiness.dart';
import 'package:ai_opportunity_radar/features/pages/me/me_view_model.dart';
import 'package:ai_opportunity_radar/features/pages/memory/memory_page.dart';
import 'package:ai_opportunity_radar/features/pages/memory/memory_view_model.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    expect(tester.getSize(hero).height, lessThanOrEqualTo(170));
    final journeyTitle = tester.widget<Text>(find.text('Journey'));
    expect(journeyTitle.style?.fontSize, 36);
    expect(journeyTitle.style?.fontFamily, isNot('Georgia'));
    for (var i = 0;
        i < 3 && find.textContaining('Track overview').evaluate().isEmpty;
        i++) {
      await tester.drag(scrollView, const Offset(0, -100));
      await tester.pumpAndSettle();
    }
    final sectionTitle =
        tester.widget<Text>(find.textContaining('Track overview'));
    expect(sectionTitle.style?.fontSize, 17);
    expect(find.text('Journey'), findsOneWidget);
    expect(find.text('Open journal view'), findsNothing);
    expect(find.text('打开手帐视图'), findsNothing);
    for (var i = 0;
        i < 6 &&
            find
                .text('Meetings and recovery appeared together.')
                .evaluate()
                .isEmpty;
        i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -260));
      await tester.pumpAndSettle();
    }
    expect(
        find.text('Meetings and recovery appeared together.'), findsOneWidget);
    expect(find.text('Confirmed'), findsOneWidget);
    expect(find.text('Generated'), findsOneWidget);
    expect(find.text('Dismissed'), findsOneWidget);
    expect(
      find.text('Legacy schedule feedback must stay hidden'),
      findsNothing,
    );
    expect(repo.fetchCallCount, 1);

    await tester.tap(find.text('Meetings and recovery appeared together.'));
    await tester.pumpAndSettle();

    expect(find.text('Observation'), findsWidgets);
    expect(find.text('Signal'), findsWidgets);
    expect(find.text('Weekly Reflection'), findsWidgets);
    expect(find.text('Experiment Feedback'), findsWidgets);
    expect(
        find.text('Legacy schedule evidence must stay hidden'), findsNothing);
    expect(find.text('Schedule Feedback'), findsNothing);
    expect(repo.evidenceCallCount, 1);
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

    expect(find.text('Your Life Journey is forming'), findsOneWidget);
    final scrollView = find.byKey(const ValueKey('journey-scroll-view'));
    expect(scrollView, findsOneWidget);
    final listView = tester.widget<ListView>(scrollView);
    expect(
      listView.padding,
      const EdgeInsets.fromLTRB(18, 14, 18, 96),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('journey-hero-header'))).height,
      lessThanOrEqualTo(170),
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
        proReadiness: ReportReadiness(
          rule: ReportReadinessEvaluator.journeyProRule,
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
      find.byKey(const ValueKey('journey-report-readiness')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('journey-pro-report-readiness')),
      findsOneWidget,
    );
    expect(find.textContaining('2/7 signals'), findsOneWidget);
    expect(find.textContaining('2/14 signals'), findsOneWidget);
    expect(find.textContaining('7 eligible SignalCards'), findsOneWidget);
    expect(find.text('View Pro L3 progress'), findsOneWidget);
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
            ),
          ],
        ),
        journeyReadiness: const ReportReadiness(
          rule: ReportReadinessEvaluator.journeyRule,
          signalCount: 1,
          distinctDayCount: 1,
          distinctWeekCount: 1,
        ),
        proReadiness: const ReportReadiness(
          rule: ReportReadinessEvaluator.journeyProRule,
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

    expect(find.text('Your Life Journey is forming'), findsOneWidget);
    expect(find.text('Fragments kept this month'), findsOneWidget);
    expect(find.text('A real timeline signal'), findsOneWidget);
    expect(find.text('Monthly view'), findsOneWidget);
    expect(find.text('Life state curve'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('journey-report-readiness')),
      findsOneWidget,
    );
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
      lessThanOrEqualTo(170),
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
  Future<MemoryFetchResult> fetchMemorySummaryResult() async {
    throw StateError('journey load failed');
  }
}
