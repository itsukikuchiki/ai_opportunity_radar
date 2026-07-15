import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ai_opportunity_radar/shared/widgets/aurora_ui.dart';
import 'package:ai_opportunity_radar/shared/widgets/editable_timeline_decision_dialog.dart';

import '../../helpers/widget_test_helpers.dart';

void main() {
  testWidgets('Aurora 时间线决定弹窗在 390x844 可编辑并返回决定', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    EditableTimelineDecision? result;

    await tester.pumpWidget(
      buildTestApp(
        providers: [Provider<int>.value(value: 0)],
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        child: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => FilledButton(
                onPressed: () async {
                  result = await showEditableTimelineDecisionDialog(
                    context,
                    initialText: '原来的时间线内容',
                    keyPrefix: 'test-decision',
                  );
                },
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('test-decision-aurora-dialog')),
      findsOneWidget,
    );
    expect(find.byType(AuroraModalSurface), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.enterText(
      find.byKey(const ValueKey('test-decision-timeline-input')),
      '修改后的真实记录',
    );
    await tester.tap(
      find.byKey(const ValueKey('test-decision-add-timeline')),
    );
    await tester.pumpAndSettle();

    expect(result?.addToTimeline, isTrue);
    expect(result?.text, '修改后的真实记录');
    expect(tester.takeException(), isNull);
  });
}
