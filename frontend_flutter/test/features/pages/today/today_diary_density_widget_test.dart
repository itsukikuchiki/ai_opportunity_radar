import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ai_opportunity_radar/core/models/phase3_plus_models.dart';
import 'package:ai_opportunity_radar/core/models/today_models.dart';
import 'package:ai_opportunity_radar/features/pages/today/today_diary_page.dart';
import 'package:ai_opportunity_radar/features/pages/today/today_view_model.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('手帐页使用与 Today 时间线一致的紧凑信息密度', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime.now();
    final localDate = now.toIso8601String().split('T').first;
    final repository = StubTodayRepository(
      fetchTodayResult: {
        'insight': TodayInsightModel(text: '今天可以先这样看。'),
        'pendingQuestion': null,
        'bestAction': DailyBestActionModel(text: '先留一点余地。'),
        'recentSignals': [
          for (var index = 0; index < 3; index++)
            RecentSignalModel(
              id: 'compact-diary-$index',
              sourceType: 'text',
              content: '今天的第 ${index + 1} 条信号',
              createdAt: now.subtract(Duration(minutes: index)),
              localDate: localDate,
            ),
          RecentSignalModel(
            id: 'legacy-schedule-signal',
            sourceType: 'manual_schedule',
            content: '旧安排信号不应出现',
            createdAt: now,
            localDate: localDate,
          ),
        ],
        'scheduleSignals': [
          ScheduleSignalModel(
            id: 'legacy-schedule',
            title: '旧安排记录不应出现',
            anchorDate: localDate,
            datePrecision: 'date',
            timePrecision: 'none',
            createdAt: now,
            updatedAt: now,
          ),
        ],
      },
    );

    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        child: const TodayDiaryPage(),
        providers: [
          ChangeNotifierProvider<TodayViewModel>(
            create: (_) => TodayViewModel(repository),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final hero = find.byKey(const ValueKey('today-diary-hero'));
    final filters = find.byKey(const ValueKey('today-diary-filter-bar'));
    final dateHeader = find.byKey(const ValueKey('today-diary-date-header'));
    final cards = find.byKey(const ValueKey('today-diary-entry-card'));

    expect(hero, findsOneWidget);
    expect(tester.getSize(hero).height, lessThanOrEqualTo(116));
    expect(filters, findsOneWidget);
    expect(tester.getSize(filters).height, 40);
    expect(dateHeader, findsOneWidget);
    expect(cards, findsNWidgets(3));
    expect(find.text('安排'), findsNothing);
    expect(find.text('旧安排信号不应出现'), findsNothing);
    expect(find.text('旧安排记录不应出现'), findsNothing);
    expect(tester.getTopLeft(cards.first).dy, lessThan(260));
    expect(tester.getSize(cards.first).height, lessThanOrEqualTo(80));
    expect(tester.getBottomRight(cards.at(2)).dy, lessThan(560));
    expect(tester.takeException(), isNull);
  });
}
