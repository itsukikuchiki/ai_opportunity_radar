import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ai_opportunity_radar/core/di/app_dependencies.dart';
import 'package:ai_opportunity_radar/core/models/today_models.dart';
import 'package:ai_opportunity_radar/features/pages/today/today_dialog_page.dart';
import 'package:ai_opportunity_radar/shared/widgets/aurora_ui.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fallbackOpenings = <({Locale locale, String expected})>[
    (
      locale: const Locale('en'),
      expected:
          'I hear you saying “今天切换得有点密集,” and I am staying with it as you experienced it.',
    ),
    (
      locale: const Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hans',
      ),
      expected: '我听见你在说“今天切换得有点密集”，这件事先按你感受到的样子留在这里。',
    ),
    (
      locale: const Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hant',
      ),
      expected: '我聽見你在說「今天切换得有点密集」，這件事先按你感受到的樣子留在這裡。',
    ),
    (
      locale: const Locale('ja'),
      expected: '「今天切换得有点密集」と感じていることを、そのまま受け止めます。',
    ),
  ];

  for (final sample in fallbackOpenings) {
    testWidgets(
        'TodayDialog fallback opening only acknowledges in '
        '${sample.locale.toLanguageTag()}', (tester) async {
      final signal = RecentSignalModel(
        id: 'fallback-opening',
        content: '今天切换得有点密集',
        createdAt: DateTime(2026, 7, 16, 9, 20),
      );
      final repository = StubTodayRepository(
        fetchTodayResult: const {},
        captureById: {'fallback-opening': signal},
      );
      final dependencies = await buildTestDependencies(
        todayRepository: repository,
      );

      await tester.pumpWidget(
        buildTestApp(
          locale: sample.locale,
          child: const TodayDialogPage(captureId: 'fallback-opening'),
          providers: [
            Provider<AppDependencies>.value(value: dependencies),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(sample.expected), findsOneWidget);
      expect(sample.expected, isNot(contains('?')));
      expect(sample.expected, isNot(contains('？')));
    });
  }

  testWidgets('历史 AI 预判确认状态不作为聊天开场展示', (tester) async {
    final signal = RecentSignalModel(
      id: 'legacy-ai-prediction',
      sourceType: 'ai_predicted',
      content: '事情太多了',
      acknowledgement: '这条内容已从 AI 预判确认并加入时间线。',
    );
    final repository = StubTodayRepository(
      fetchTodayResult: const {},
      captureById: {'legacy-ai-prediction': signal},
    );
    final dependencies = await buildTestDependencies(
      todayRepository: repository,
    );

    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        child: const TodayDialogPage(captureId: 'legacy-ai-prediction'),
        providers: [Provider<AppDependencies>.value(value: dependencies)],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('这条内容已从 AI 预判确认并加入时间线。'), findsNothing);
    expect(find.textContaining('这么多事压过来'), findsOneWidget);
    expect(find.textContaining('喘不过气'), findsOneWidget);
  });

  testWidgets('TodayDialog 本地化 time_use 关注领域且不泄漏内部能量枚举', (tester) async {
    final signal = RecentSignalModel(
      id: 'time-use-1',
      signalCardId: 'time-use-1',
      sourceType: 'time_use',
      content: '把下一步写下来。',
      scene: 'growth_plan',
      energyLoad: 'draining',
      createdAt: DateTime(2026, 7, 16, 10, 20),
      rawPayloadJson: const {
        'timeline_type': 'time_use',
        'focus_domain_id': 'growth_plan',
        'category': 'growth_plan',
        'record_status': 'completed',
        'energy_level': 0,
      },
    );
    final repository = StubTodayRepository(
      fetchTodayResult: const {},
      captureById: {'time-use-1': signal},
    );
    final dependencies = await buildTestDependencies(
      todayRepository: repository,
    );

    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        child: const TodayDialogPage(captureId: 'time-use-1'),
        providers: [
          Provider<AppDependencies>.value(value: dependencies),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('today-dialog-signal-pattern')),
      findsOneWidget,
    );
    expect(find.byType(AuroraHeroEmblem), findsNothing);
    expect(find.text('成长计划'), findsOneWidget);
    expect(find.textContaining('growth_plan'), findsNothing);
    expect(find.textContaining('draining'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TodayDialog supports 390x844, 1.3x text and semantic controls',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();

    final repository = StubTodayRepository(
      fetchTodayResult: const {},
      captureById: {
        'signal-1': RecentSignalModel(
          id: 'signal-1',
          content: 'Several transitions felt too dense today.',
          createdAt: DateTime(2026, 7, 15, 9, 20),
          acknowledgement:
              'It sounds like the switching itself took a lot of energy.',
          sceneTags: const ['work'],
        ),
      },
    );
    final dependencies = await buildTestDependencies(
      todayRepository: repository,
    );

    await tester.pumpWidget(
      buildTestApp(
        child: const MediaQuery(
          data: MediaQueryData(
            size: Size(390, 844),
            textScaler: TextScaler.linear(1.3),
          ),
          child: TodayDialogPage(captureId: 'signal-1'),
        ),
        providers: [
          Provider<AppDependencies>.value(value: dependencies),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const ValueKey('today-dialog-back'))),
      const Size(44, 44),
    );
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('today-dialog-send')))
          .shortestSide,
      greaterThanOrEqualTo(44),
    );
    expect(find.byTooltip('Send'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('today-dialog-composer-input')),
      findsOneWidget,
    );
    expect(find.text('Say more'), findsNothing);
    expect(find.text('Small action'), findsNothing);
    expect(find.text('Summarize'), findsNothing);
    expect(
      tester.getSemantics(
        find.byKey(const ValueKey('today-dialog-heading-semantics')),
      ),
      matchesSemantics(label: 'Chat With AI', isHeader: true),
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
