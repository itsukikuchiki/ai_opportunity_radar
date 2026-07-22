import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_opportunity_radar/app/app_router.dart';
import 'package:ai_opportunity_radar/core/state/app_bootstrap_state.dart';
import 'package:ai_opportunity_radar/features/pages/today/today_diary_page.dart';
import 'package:ai_opportunity_radar/features/pages/today/today_view_model.dart';

import '../helpers/widget_test_helpers.dart';

void main() {
  test('legacy Journey journal links resolve to the canonical Today diary', () {
    expect(canonicalDiaryLocation(), AppRoutes.todayDiary);
    expect(canonicalDiaryLocation(date: '   '), AppRoutes.todayDiary);
    expect(
      canonicalDiaryLocation(date: '2026-07-05'),
      '${AppRoutes.todayDiary}?date=2026-07-05',
    );
  });

  test('legacy Journey month-fragment links resolve to the canonical diary',
      () {
    expect(
      canonicalDiaryLocationForMonth(month: '2026-07'),
      '${AppRoutes.todayDiary}?date=2026-07-01',
    );
    expect(
        canonicalDiaryLocationForMonth(month: 'invalid'), AppRoutes.todayDiary);
    expect(canonicalDiaryLocationForMonth(), AppRoutes.todayDiary);
  });

  testWidgets('real router redirects both legacy Journey routes to Today diary',
      (tester) async {
    SharedPreferences.setMockInitialValues(
      <String, Object>{'onboarding_completed': true},
    );
    final bootstrap = AppBootstrapState();
    await bootstrap.prepareLaunch();
    final router = createAppRouter(bootstrap);
    addTearDown(router.dispose);
    final todayViewModel = TodayViewModel(
      StubTodayRepository(fetchTodayResult: const <String, dynamic>{}),
    );
    addTearDown(todayViewModel.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<TodayViewModel>.value(
        value: todayViewModel,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    router.go('${AppRoutes.journal}?date=2026-07-05');
    await tester.pumpAndSettle();
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '${AppRoutes.todayDiary}?date=2026-07-05',
    );
    expect(
      tester.widget<TodayDiaryPage>(find.byType(TodayDiaryPage)).initialDateKey,
      '2026-07-05',
    );

    router.go('${AppRoutes.journeyFragments}?month=2026-06');
    await tester.pumpAndSettle();
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '${AppRoutes.todayDiary}?date=2026-06-01',
    );
    expect(
      tester.widget<TodayDiaryPage>(find.byType(TodayDiaryPage)).initialDateKey,
      '2026-06-01',
    );
  });
}
