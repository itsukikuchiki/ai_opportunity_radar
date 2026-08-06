import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ai_opportunity_radar/core/models/experiment_evaluation_models.dart';
import 'package:ai_opportunity_radar/core/models/phase3_plus_models.dart';
import 'package:ai_opportunity_radar/features/pages/today/today_adopted_plans_section.dart';
import 'package:ai_opportunity_radar/shared/widgets/experiment_feedback_sheets.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  testWidgets(
    '390x844 固定底栏下可完整滚动并保存小实验完成反馈且不打开弹层',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const action = MicroActionModel(
        id: 'compact-small-experiment',
        judgementId: '',
        title: '任务切换前留两分钟缓冲',
        reason: '最近的切换比较密集。',
        status: 'active',
      );
      final submissions = <SmallTryAttemptFeedbackDraft>[];

      await tester.pumpWidget(
        buildTestApp(
          locale: const Locale.fromSubtags(
            languageCode: 'zh',
            scriptCode: 'Hans',
          ),
          providers: [Provider<int>.value(value: 0)],
          child: Scaffold(
            extendBody: true,
            body: SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 420, 16, 124),
                child: TodayAdoptedPlansSection(
                  signals: const [],
                  compatibilityAction: action,
                  compatibilityExperiment: null,
                  isBusy: false,
                  onActionFeedback: (_, feedback) async {
                    submissions.add(feedback);
                  },
                  onExperimentFeedback: (_, __) async {},
                  onOpenAll: () {},
                  onOpenActionHub: () {},
                  onOpenExperimentHub: () {},
                ),
              ),
            ),
            bottomNavigationBar: const SizedBox(
              key: ValueKey('fixed-bottom-navigation'),
              height: 96,
              child: ColoredBox(
                color: Color(0xFFF8F7FF),
                child: Center(child: Text('固定底部导航')),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final initialModalBarrierCount =
          find.byType(ModalBarrier).evaluate().length;
      final completed = find.byKey(
        const ValueKey(
          'today-small-experiment-completed-compact-small-experiment',
        ),
      );
      await tester.ensureVisible(completed);
      await tester.tap(completed);
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey('today-small-experiment-completed-details'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('small-try-feedback-sheet')),
        findsNothing,
      );
      expect(find.byType(BottomSheet), findsNothing);
      expect(
        find.byType(ModalBarrier).evaluate().length,
        initialModalBarrierCount,
      );

      final effect = find.byKey(
        const ValueKey('today-small-experiment-effect-helpful'),
      );
      await tester.ensureVisible(effect);
      await tester.tap(effect);
      await tester.pump();

      final difficulty = find.byKey(
        const ValueKey('today-small-experiment-difficulty-easy'),
      );
      await tester.ensureVisible(difficulty);
      await tester.tap(difficulty);
      await tester.pump();

      final save = find.byKey(
        const ValueKey('today-small-experiment-save-completed'),
      );
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();

      final saveRect = tester.getRect(save);
      final navigationRect = tester.getRect(
        find.byKey(const ValueKey('fixed-bottom-navigation')),
      );
      expect(
        saveRect.bottom,
        lessThanOrEqualTo(navigationRect.top),
        reason: '保存按钮必须能滚动到固定底部导航上方。',
      );

      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(submissions, hasLength(1));
      expect(submissions.single.completionStatus, 'completed');
      expect(submissions.single.effect, SmallTryEffect.helpful);
      expect(submissions.single.difficulty, SmallTryDifficulty.easy);
      expect(
        find.byKey(
          const ValueKey('today-small-experiment-completed-details'),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
