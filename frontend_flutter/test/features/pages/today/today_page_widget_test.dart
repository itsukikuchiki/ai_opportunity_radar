import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ai_opportunity_radar/core/models/today_models.dart';
import 'package:ai_opportunity_radar/features/pages/me/me_view_model.dart';
import 'package:ai_opportunity_radar/features/pages/today/today_diary_page.dart';
import 'package:ai_opportunity_radar/features/pages/today/today_page.dart';
import 'package:ai_opportunity_radar/features/pages/today/today_view_model.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Today 页面能加载并触发一次数据获取', (tester) async {
    final repo = StubTodayRepository(
      fetchTodayResult: {
        'insight': TodayInsightModel(
          text: 'Today, the tension seems to gather around work interruptions.',
        ),
        'pendingQuestion': null,
        'bestAction': DailyBestActionModel(
          text: 'Try noticing the exact moment the pressure first rises.',
        ),
        'recentSignals': [
          RecentSignalModel(
            id: 'signal-1',
            content: 'The meeting kept getting interrupted and I felt drained.',
            createdAt: DateTime.now(),
            acknowledgement: 'That sounds genuinely draining.',
            observation:
                'Work interruptions are taking up more space than they seem.',
            tryNext: 'Write down the first interruption next time.',
            emotion: 'negative',
            intensity: 'medium',
            sceneTags: const ['work'],
          ),
        ],
      },
    );

    final meVm = await buildMeViewModel();

    await tester.pumpWidget(
      buildTestApp(
        child: const TodayPage(),
        providers: [
          ChangeNotifierProvider<TodayViewModel>(
            create: (_) => TodayViewModel(repo),
          ),
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(TodayPage), findsOneWidget);
    expect(find.text('Today'), findsWidgets);
    expect(find.text('Signal inbox'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(repo.fetchTodayCallCount, 1);
  });

  testWidgets('library_saved 在 Timeline 中显示为来自 Library 的私密观察', (tester) async {
    final repo = StubTodayRepository(
      fetchTodayResult: {
        'insight': TodayInsightModel(text: '今天可以先轻轻观察。'),
        'pendingQuestion': null,
        'bestAction': DailyBestActionModel(text: '不用急着确认。'),
        'recentSignals': [
          RecentSignalModel(
            id: 'library-signal-1',
            signalCardId: 'library-signal-1',
            sourceType: 'library_saved',
            content: '',
            createdAt: DateTime.now(),
            acknowledgement:
                'Saved privately into your observations. You can add a little of your own context when it feels useful.',
            rawPayloadJson: const {
              'library_pattern_id': 'over_scheduled_weeks',
              'title': 'Over-scheduled weeks',
              'abstract_pattern':
                  'Some people encounter a similar structure when the week has many fixed commitments and very little space between them.',
            },
            privacyLevel: 'private',
            userConfirmation: 'unconfirmed',
          ),
        ],
      },
    );

    final meVm = await buildMeViewModel();

    await tester.pumpWidget(
      buildTestApp(
        child: const TodayPage(),
        providers: [
          ChangeNotifierProvider<TodayViewModel>(
            create: (_) => TodayViewModel(repo),
          ),
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
      ),
    );

    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Saved from Library'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Saved from Library'), findsWidgets);
    expect(find.text('Over-scheduled weeks'), findsWidgets);
    expect(find.text('From Library'), findsWidgets);
    expect(find.text('Private observation'), findsWidgets);
    expect(find.textContaining('you have this problem'), findsNothing);
  });

  testWidgets('Today 不再内嵌手账时间线，并提供手账入口', (tester) async {
    final repo = StubTodayRepository(
      fetchTodayResult: {
        'insight': TodayInsightModel(text: '今天可以先这样看。'),
        'pendingQuestion': null,
        'bestAction': DailyBestActionModel(text: '先留下一点余地。'),
        'recentSignals': <RecentSignalModel>[],
      },
    );
    final meVm = await buildMeViewModel();

    await tester.pumpWidget(
      buildTestApp(
        child: const TodayPage(),
        providers: [
          ChangeNotifierProvider<TodayViewModel>(
            create: (_) => TodayViewModel(repo),
          ),
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Open diary'), findsOneWidget);
    expect(find.text('Diary Timeline'), findsNothing);
  });

  testWidgets('手账按日期一页一页展示并可左滑翻页', (tester) async {
    final now = DateTime.now();
    final today = _dateKey(now);
    final yesterday = _dateKey(now.subtract(const Duration(days: 1)));
    final repo = StubTodayRepository(
      fetchTodayResult: {
        'insight': TodayInsightModel(text: '今天可以先这样看。'),
        'pendingQuestion': null,
        'bestAction': DailyBestActionModel(text: '先留下一点余地。'),
        'recentSignals': <RecentSignalModel>[
          RecentSignalModel(
            id: 'today',
            content: '今天的记录',
            createdAt: now,
            localDate: today,
          ),
          RecentSignalModel(
            id: 'yesterday',
            content: '昨天的记录',
            createdAt: now.subtract(const Duration(days: 1)),
            localDate: yesterday,
          ),
        ],
      },
    );

    await tester.pumpWidget(
      buildTestApp(
        child: const TodayDiaryPage(),
        providers: [
          ChangeNotifierProvider<TodayViewModel>(
            create: (_) => TodayViewModel(repo),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(today), findsOneWidget);
    expect(find.text('今天的记录'), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('today-diary-page-view')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text(yesterday), findsOneWidget);
    expect(find.text('昨天的记录'), findsOneWidget);
  });

  testWidgets('同步按钮会触发重试并显示完成反馈', (tester) async {
    final fetchResult = <String, dynamic>{
      'insight': TodayInsightModel(text: '原文已经保存。'),
      'pendingQuestion': null,
      'bestAction': DailyBestActionModel(text: '网络稳定后再整理也来得及。'),
      'recentSignals': <RecentSignalModel>[
        RecentSignalModel(
          id: 'draft_1',
          sourceType: 'text',
          content: '不想上班',
          createdAt: DateTime.now(),
          isLocalDraft: true,
          syncFailed: true,
        ),
      ],
    };
    final repo = StubTodayRepository(
      fetchTodayResult: fetchResult,
      onRetryPendingDrafts: () async {
        fetchResult['recentSignals'] = <RecentSignalModel>[];
      },
    );
    final meVm = await buildMeViewModel();

    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        child: const TodayPage(),
        providers: [
          ChangeNotifierProvider<TodayViewModel>(
            create: (_) => TodayViewModel(repo),
          ),
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('同步'));
    await tester.pumpAndSettle();

    expect(repo.retryPendingDraftsCallCount, 1);
    expect(find.text('同步完成。'), findsOneWidget);
    expect(find.textContaining('1 条内容已先保存在这台设备上'), findsNothing);
  });
}

String _dateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
