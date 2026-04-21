import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ai_opportunity_radar/core/models/weekly_models.dart';
import 'package:ai_opportunity_radar/features/pages/me/me_view_model.dart';
import 'package:ai_opportunity_radar/features/pages/weekly/weekly_page.dart';
import 'package:ai_opportunity_radar/features/pages/weekly/weekly_view_model.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Weekly 页面能加载并触发一次数据获取', (tester) async {
    final repo = StubWeeklyRepository(
      weekly: WeeklyInsightModel(
        weekStart: '2026-04-15',
        weekEnd: '2026-04-21',
        status: 'ready',
        keyInsight: 'Interruptions and recovery are both clearly visible this week.',
        patterns: const [
          {
            'name': 'Interruptions during focused work',
            'summary': 'This repeated across several entries.',
          },
        ],
        frictions: const [
          {
            'name': 'Meetings draining energy',
            'summary': 'Energy dropped most clearly around meetings.',
          },
        ],
        bestAction: 'Next week, track the first interruption of the day.',
        opportunitySnapshot: null,
        feedbackSubmitted: false,
        chartData: const [
          WeeklyChartPointModel(
            date: '2026-04-15',
            signalCount: 1,
            moodScore: -0.2,
            frictionScore: 0.6,
            hasPositiveSignal: false,
          ),
          WeeklyChartPointModel(
            date: '2026-04-16',
            signalCount: 3,
            moodScore: -0.6,
            frictionScore: 0.8,
            hasPositiveSignal: false,
          ),
          WeeklyChartPointModel(
            date: '2026-04-17',
            signalCount: 2,
            moodScore: 0.1,
            frictionScore: 0.3,
            hasPositiveSignal: true,
          ),
        ],
      ),
    );

    final meVm = await buildMeViewModel(repeatArea: 'work_tasks');

    await tester.pumpWidget(
      buildTestApp(
        child: const WeeklyPage(),
        providers: [
          ChangeNotifierProvider<WeeklyViewModel>(
            create: (_) => WeeklyViewModel(repo),
          ),
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(WeeklyPage), findsOneWidget);
    expect(find.text('Weekly'), findsWidgets);
    expect(find.text('Signal density and weekly trend'), findsOneWidget);
    expect(repo.fetchCallCount, 1);
  });

  testWidgets('Weekly 第一天 gate 会显示对应空态', (tester) async {
    final repo = StubWeeklyRepository(
      weekly: WeeklyInsightModel(
        weekStart: '2026-04-15',
        weekEnd: '2026-04-21',
        status: 'first_day_gate',
        keyInsight: null,
        patterns: const [],
        frictions: const [],
        bestAction: null,
        opportunitySnapshot: null,
        feedbackSubmitted: false,
        chartData: const [],
      ),
    );

    final meVm = await buildMeViewModel();

    await tester.pumpWidget(
      buildTestApp(
        child: const WeeklyPage(),
        providers: [
          ChangeNotifierProvider<WeeklyViewModel>(
            create: (_) => WeeklyViewModel(repo),
          ),
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Weekly starts on day 2'), findsOneWidget);
  });
}
