import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ai_opportunity_radar/core/models/today_models.dart';
import 'package:ai_opportunity_radar/features/pages/me/me_view_model.dart';
import 'package:ai_opportunity_radar/features/pages/today/today_dialog_page.dart';
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
    expect(find.text('Signal input'), findsOneWidget);
    expect(find.text('Today'), findsNothing);
    expect(find.text('Text'), findsOneWidget);
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
      find.textContaining('Saved from Library'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Saved from Library'), findsWidgets);
    expect(find.textContaining('Over-scheduled weeks'), findsWidgets);
    expect(find.text('From Library'), findsWidgets);
    expect(find.text('Private observation'), findsWidgets);
    expect(find.textContaining('you have this problem'), findsNothing);
  });

  testWidgets('Today 内嵌高保真手账时间线', (tester) async {
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

    await tester.scrollUntilVisible(
      find.text('Diary Timeline'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byTooltip('Open diary'), findsNothing);
    expect(find.text('Diary Timeline'), findsOneWidget);
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
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
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

    await tester.tap(find.text('全部'));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('today-diary-page-view')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text(yesterday), findsOneWidget);
    expect(find.text('昨天的记录'), findsOneWidget);
  });

  testWidgets('手帐时间线本周和全部筛选可切换', (tester) async {
    final now = DateTime.now();
    final today = _dateKey(now);
    final oldDay = _dateKey(now.subtract(const Duration(days: 14)));
    final repo = StubTodayRepository(
      fetchTodayResult: {
        'insight': TodayInsightModel(text: '今天可以先这样看。'),
        'pendingQuestion': null,
        'bestAction': DailyBestActionModel(text: '先留下一点余地。'),
        'recentSignals': <RecentSignalModel>[
          RecentSignalModel(
            id: 'today-filter-record',
            content: '今天筛选记录',
            createdAt: now,
            localDate: today,
          ),
          RecentSignalModel(
            id: 'old-filter-record',
            content: '两周前的记录',
            createdAt: now.subtract(const Duration(days: 14)),
            localDate: oldDay,
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
            create: (_) => TodayViewModel(repo),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('今天筛选记录'), findsOneWidget);
    expect(find.text('两周前的记录'), findsNothing);

    await tester.tap(find.text('全部'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('today-diary-page-view')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();

    expect(find.text('两周前的记录'), findsOneWidget);

    await tester.tap(find.text('本周'));
    await tester.pumpAndSettle();

    expect(find.text('今天筛选记录'), findsOneWidget);
    expect(find.text('两周前的记录'), findsNothing);
  });

  testWidgets('手帐时间线搜索按原文和 AI 回应过滤', (tester) async {
    final now = DateTime.now();
    final today = _dateKey(now);
    final repo = StubTodayRepository(
      fetchTodayResult: {
        'insight': TodayInsightModel(text: '今天可以先这样看。'),
        'pendingQuestion': null,
        'bestAction': DailyBestActionModel(text: '先留下一点余地。'),
        'recentSignals': <RecentSignalModel>[
          RecentSignalModel(
            id: 'horse-record',
            content: '骑马很开心',
            acknowledgement: '这种轻松值得留下。',
            createdAt: now,
            localDate: today,
          ),
          RecentSignalModel(
            id: 'meeting-record',
            content: '会议太碎',
            acknowledgement: '切换有点多。',
            createdAt: now.add(const Duration(minutes: 1)),
            localDate: today,
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
            create: (_) => TodayViewModel(repo),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('today-diary-search-field')),
      '骑马',
    );
    await tester.pumpAndSettle();

    expect(find.text('骑马很开心'), findsOneWidget);
    expect(find.text('会议太碎'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('today-diary-search-field')),
      '切换',
    );
    await tester.pumpAndSettle();

    expect(find.text('会议太碎'), findsOneWidget);
    expect(find.text('骑马很开心'), findsNothing);
  });

  testWidgets('手帐时间线筛选按钮可以按来源过滤', (tester) async {
    final now = DateTime.now();
    final today = _dateKey(now);
    final repo = StubTodayRepository(
      fetchTodayResult: {
        'insight': TodayInsightModel(text: '今天可以先这样看。'),
        'pendingQuestion': null,
        'bestAction': DailyBestActionModel(text: '先留下一点余地。'),
        'recentSignals': <RecentSignalModel>[
          RecentSignalModel(
            id: 'text-source-record',
            sourceType: 'text',
            content: '文字来源记录',
            createdAt: now,
            localDate: today,
          ),
          RecentSignalModel(
            id: 'voice-source-record',
            sourceType: 'voice',
            content: '语音来源记录',
            createdAt: now.add(const Duration(minutes: 1)),
            localDate: today,
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
            create: (_) => TodayViewModel(repo),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('today-diary-filter-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, '语音'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('应用'));
    await tester.pumpAndSettle();

    expect(find.text('语音来源记录'), findsOneWidget);
    expect(find.text('文字来源记录'), findsNothing);
  });

  testWidgets('本地优先状态不再暴露手动同步按钮', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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

    expect(find.byKey(const ValueKey('today-sync-action')), findsNothing);
    expect(find.text('同步'), findsNothing);
    expect(find.text('信号输入'), findsOneWidget);
    expect(find.text('今日概览'), findsOneWidget);
    expect(repo.retryPendingDraftsCallCount, 0);
  });

  testWidgets('Today 不显示无目的趋势/查看全部入口，空文字按钮只聚焦输入框', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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

    expect(find.text('查看趋势'), findsNothing);
    expect(find.text('今日练习任务'), findsOneWidget);
    expect(find.byKey(const ValueKey('today-sync-action')), findsNothing);

    await tester.tap(find.text('文字'));
    await tester.pumpAndSettle();

    expect(find.text('先写下一件小事。'), findsNothing);
    expect(tester.testTextInput.isVisible, isTrue);
  });

  testWidgets('AI 对话展开入口目标页可以按 SignalCard id 读取并继续回应', (tester) async {
    final signal = RecentSignalModel(
      id: 'local-1',
      signalCardId: 'sig-1',
      content: '今天不想回消息。',
      createdAt: DateTime(2026, 6, 16, 21, 43),
      acknowledgement: '我注意到你记录了“今天不想回消息”。',
      observation: '不是生气，就是突然不想说话，想一个人待着。',
      emotion: '情绪',
      friction: '回避',
      energyLoad: '偏低',
    );
    final repo = StubTodayRepository(
      fetchTodayResult: {
        'insight': TodayInsightModel(text: '今天可以先这样看。'),
        'pendingQuestion': null,
        'bestAction': DailyBestActionModel(text: '先留下一点余地。'),
        'recentSignals': [signal],
      },
      captureById: {'sig-1': signal},
    );
    final deps = await buildTestDependencies(todayRepository: repo);

    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        child: const TodayDialogPage(captureId: 'sig-1'),
        providers: [
          Provider.value(value: deps),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('没找到这条记录。'), findsNothing);
    expect(find.text('正在探讨的信号'), findsOneWidget);
    expect(find.text('今天不想回消息。'), findsWidgets);
    expect(find.text('AI 回顾与回应'), findsOneWidget);
    expect(find.text('继续想一想'), findsOneWidget);
    expect(find.text('换个角度'), findsOneWidget);
    expect(find.text('帮我总结'), findsOneWidget);

    await tester.tap(find.text('继续想一想'));
    await tester.pumpAndSettle();

    expect(repo.lightDialogMessages, contains('帮我再往下想一步。'));
    expect(find.text('我会先贴着这条记录看，不急着下结论。'), findsOneWidget);
  });

  testWidgets('语音识别 sheet 的暂停、停止、关闭和保存按钮可响应', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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

    await tester.tap(find.text('语音'));
    await tester.pumpAndSettle();

    expect(find.text('准备录音'), findsOneWidget);
    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('开始录音'), findsOneWidget);
    expect(find.text('还未开始录音'), findsOneWidget);

    await tester.tap(find.text('开始录音'));
    await tester.pumpAndSettle();

    expect(find.text('正在识别中...'), findsOneWidget);
    expect(find.text('正在聆听...'), findsOneWidget);
    expect(find.text('停止并编辑'), findsOneWidget);

    await tester.tap(find.text('暂停'));
    await tester.pumpAndSettle();

    expect(find.text('已暂停'), findsWidgets);
    expect(find.text('继续'), findsOneWidget);

    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();

    expect(find.text('正在聆听...'), findsOneWidget);

    await tester.tap(find.text('停止'));
    await tester.pumpAndSettle();

    expect(find.text('识别完成'), findsOneWidget);
    expect(find.text('关闭'), findsOneWidget);
    expect(find.text('保存为信号'), findsOneWidget);

    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();

    expect(repo.submittedCaptures, isEmpty);

    await tester.tap(find.text('语音'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('开始录音'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('停止并编辑'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('保存为信号'));
    await tester.pumpAndSettle();

    expect(repo.submittedCaptures, isEmpty);
    expect(find.text('请先补上要保存的转写内容。'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField).last,
      '今天骑马很开心，想把这种轻松留下来。',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('保存为信号'));
    await tester.pumpAndSettle();

    expect(repo.submittedCaptures, hasLength(1));
    expect(repo.submittedCaptures.single['content'], '今天骑马很开心，想把这种轻松留下来。');
    expect(repo.submittedCaptures.single['sourceType'], 'voice');
    expect(
      repo.submittedCaptures.single['rawPayloadJson'],
      containsPair('audio_uploaded', false),
    );
  });

  testWidgets('安排表单可选择其他类型并保存为 ScheduleSignal', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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

    final scheduleAction = find.byKey(const ValueKey('today-schedule-action'));
    await tester.ensureVisible(scheduleAction);
    await tester.pumpAndSettle();
    await tester.tap(scheduleAction);
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('schedule-title-field')), '临时杂事');
    await tester.pump();

    await tester.ensureVisible(find.text('其他'));
    await tester.tap(find.text('其他'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('保存').last);
    await tester.pumpAndSettle();

    expect(repo.submittedSchedules, hasLength(1));
    expect(repo.submittedSchedules.single['title'], '临时杂事');
    expect(repo.submittedSchedules.single['scene'], 'other');
  });

  testWidgets('状态 sheet 提供正向中性和负面选项，并保存为 one_tap Signal', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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

    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(-220, 0),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('today-status-action')));
    await tester.pumpAndSettle();

    expect(find.text('留一个当前状态'), findsOneWidget);
    expect(find.text('感觉不错'), findsOneWidget);
    expect(find.text('比较平稳'), findsOneWidget);
    expect(find.text('有点累'), findsOneWidget);
    expect(find.text('有点烦'), findsOneWidget);
    expect(find.text('想恢复'), findsOneWidget);
    expect(find.text('想独处'), findsOneWidget);

    await tester.tap(find.text('感觉不错'));
    await tester.pumpAndSettle();

    expect(repo.submittedCaptures, hasLength(1));
    expect(repo.submittedCaptures.single['sourceType'], 'one_tap');
    expect(repo.submittedCaptures.single['content'], '现在感觉还不错。');

    await tester.scrollUntilVisible(
      find.text('现在感觉还不错。'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('现在感觉还不错。'), findsOneWidget);
    expect(find.text('这个状态已经放进你的手帐时间线。'), findsOneWidget);
  });
}

String _dateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
