import 'package:ai_opportunity_radar/core/models/experiment_evaluation_models.dart';
import 'package:ai_opportunity_radar/shared/widgets/experiment_feedback_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('completed small try requires effect and effort', (tester) async {
    SmallTryAttemptFeedbackDraft? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showSmallTryAttemptFeedbackSheet(
                  context,
                  title: '留两分钟缓冲',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('small-try-completed-choice')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('small-try-feedback-save')),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const ValueKey('small-try-effect-helpful')));
    await tester.tap(find.byKey(const ValueKey('small-try-difficulty-easy')));
    await tester.enterText(
      find.byKey(const ValueKey('small-try-feedback-note')),
      '轻了一点',
    );
    final save = find.byKey(const ValueKey('small-try-feedback-save'));
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(result?.completionStatus, 'completed');
    expect(result?.effect, SmallTryEffect.helpful);
    expect(result?.difficulty, SmallTryDifficulty.easy);
    expect(result?.note, '轻了一点');
  });

  testWidgets('not completed returns no fabricated evaluation', (tester) async {
    SmallTryAttemptFeedbackDraft? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showSmallTryAttemptFeedbackSheet(
                  context,
                  title: '离屏五分钟',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('small-try-not-completed-choice')),
    );
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('small-try-effect-helpful')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('small-try-feedback-save')));
    await tester.pumpAndSettle();

    expect(result?.completionStatus, 'not_completed');
    expect(result?.effect, isNull);
    expect(result?.difficulty, isNull);
  });
}
