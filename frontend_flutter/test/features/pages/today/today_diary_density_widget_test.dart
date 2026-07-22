import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ai_opportunity_radar/core/models/phase3_plus_models.dart';
import 'package:ai_opportunity_radar/core/models/today_models.dart';
import 'package:ai_opportunity_radar/features/pages/today/today_diary_page.dart';
import 'package:ai_opportunity_radar/features/pages/today/today_view_model.dart';
import 'package:ai_opportunity_radar/shared/widgets/aurora_ui.dart';

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
    final dateNavigator =
        find.byKey(const ValueKey('today-diary-date-navigator'));
    final filters = find.byKey(const ValueKey('today-diary-filter-bar'));
    final cards = find.byKey(const ValueKey('today-diary-entry-card'));

    expect(hero, findsOneWidget);
    expect(tester.getSize(hero).height, lessThanOrEqualTo(116));
    expect(
      find.byKey(const ValueKey('today-diary-signal-pattern')),
      findsOneWidget,
    );
    expect(find.byType(AuroraHeroEmblem), findsNothing);
    expect(dateNavigator, findsOneWidget);
    expect(tester.getSize(dateNavigator).height, lessThanOrEqualTo(136));
    expect(filters, findsOneWidget);
    expect(tester.getSize(filters).height, 40);
    expect(cards, findsNWidgets(3));
    expect(find.text('安排'), findsNothing);
    expect(find.text('旧安排信号不应出现'), findsNothing);
    expect(find.text('旧安排记录不应出现'), findsNothing);
    expect(tester.getTopLeft(cards.first).dy, lessThan(330));
    expect(tester.getSize(cards.first).height, lessThanOrEqualTo(80));
    expect(tester.getBottomRight(cards.at(2)).dy, lessThan(560));
    expect(tester.takeException(), isNull);
  });

  testWidgets('手帐将 time_use 显示为安排并使用登记开始时间', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime.now();
    final localDate = now.toIso8601String().split('T').first;
    final startAt = DateTime(now.year, now.month, now.day, 9, 30);
    final repository = StubTodayRepository(
      fetchTodayResult: {
        'insight': TodayInsightModel(text: '今天可以先这样看。'),
        'pendingQuestion': null,
        'bestAction': DailyBestActionModel(text: '先留一点余地。'),
        'recentSignals': [
          RecentSignalModel(
            id: 'time-use-signal',
            sourceType: 'time_use',
            content: '09:30–10:30 · 工作 · 团队会议',
            createdAt: now,
            localDate: localDate,
            sceneTags: const ['growth_plan'],
            rawPayloadJson: {
              'timeline_type': 'time_use',
              'focus_domain_id': 'growth_plan',
              'category': 'growth_plan',
              'start_at': startAt.toIso8601String(),
              'end_at': startAt.add(const Duration(hours: 1)).toIso8601String(),
              'duration_minutes': 60,
            },
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

    expect(find.text('安排'), findsOneWidget);
    expect(find.text('09:30'), findsOneWidget);
    expect(find.text('成长计划'), findsOneWidget);
    expect(find.text('growth_plan'), findsNothing);
    expect(find.textContaining('团队会议'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('手帐将普通 Signal 的关注领域代码显示为本地化名称', (tester) async {
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
          RecentSignalModel(
            id: 'growth-domain-signal',
            sourceType: 'text',
            content: '把下一步写了下来',
            createdAt: now,
            localDate: localDate,
            sceneTags: const ['unknown'],
            rawPayloadJson: const {'focus_domain_id': 'growth_plan'},
          ),
          RecentSignalModel(
            id: 'sleep-domain-signal',
            sourceType: 'voice',
            content: '昨晚没有睡好',
            createdAt: now.subtract(const Duration(minutes: 1)),
            localDate: localDate,
            sceneTags: const ['food_sleep'],
          ),
          RecentSignalModel(
            id: 'neutral-state-signal',
            sourceType: 'state',
            content: '现在状态比较平稳',
            createdAt: now.subtract(const Duration(minutes: 2)),
            localDate: localDate,
            energyLoad: 'neutral',
          ),
          RecentSignalModel(
            id: 'switching-friction-signal',
            sourceType: 'text',
            content: '上午连续切换了几个任务',
            createdAt: now.subtract(const Duration(minutes: 3)),
            localDate: localDate,
            sceneTags: const ['context_switching'],
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

    expect(find.text('成长计划'), findsOneWidget);
    expect(find.text('饮食睡眠'), findsOneWidget);
    expect(find.text('中性'), findsOneWidget);
    expect(find.text('频繁切换'), findsOneWidget);
    expect(find.text('growth_plan'), findsNothing);
    expect(find.text('food_sleep'), findsNothing);
    expect(find.text('neutral'), findsNothing);
    expect(find.text('context_switching'), findsNothing);
    expect(find.text('context switching'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
