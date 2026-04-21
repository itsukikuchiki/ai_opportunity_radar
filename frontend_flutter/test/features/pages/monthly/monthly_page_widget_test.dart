import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ai_opportunity_radar/core/models/monthly_models.dart';
import 'package:ai_opportunity_radar/features/pages/me/me_view_model.dart';
import 'package:ai_opportunity_radar/features/pages/monthly/monthly_page.dart';
import 'package:ai_opportunity_radar/features/pages/monthly/monthly_view_model.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Monthly 页面能加载并触发一次数据获取', (tester) async {
    final repo = StubMonthlyRepository(
      monthly: MonthlyReviewModel(
        monthStart: '2026-04-01',
        monthEnd: '2026-04-30',
        status: 'ready',
        monthlySummary: 'This month keeps circling around work interruptions.',
        repeatedThemes: const ['Work interruptions keep returning.'],
        improvingSignals: const ['Short recovery walks are helping a little more often.'],
        unresolvedPoints: const ['Meeting-heavy days still drain energy quickly.'],
        nextMonthWatch: 'Watch which situation triggers the first drop in energy.',
        weeklyBridges: const [
          MonthlyBridgeWeekModel(label: 'Week 1', summary: '3 entries landed here.'),
        ],
      ),
    );

    final meVm = await buildMeViewModel(repeatArea: 'work_tasks');

    await tester.pumpWidget(
      buildTestApp(
        child: const MonthlyPage(),
        providers: [
          ChangeNotifierProvider<MonthlyViewModel>(create: (_) => MonthlyViewModel(repo)),
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(MonthlyPage), findsOneWidget);
    expect(find.text('Monthly'), findsWidgets);
    expect(find.text('Repeated themes'), findsOneWidget);
    expect(repo.fetchCallCount, 1);
  });

  testWidgets('Monthly 第一个月 gate 会显示对应空态', (tester) async {
    final repo = StubMonthlyRepository(
      monthly: const MonthlyReviewModel(
        monthStart: '2026-04-01',
        monthEnd: '2026-04-30',
        status: 'first_month_gate',
      ),
    );
    final meVm = await buildMeViewModel();

    await tester.pumpWidget(
      buildTestApp(
        child: const MonthlyPage(),
        providers: [
          ChangeNotifierProvider<MonthlyViewModel>(create: (_) => MonthlyViewModel(repo)),
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Monthly starts after your first month has begun'), findsOneWidget);
  });
}
