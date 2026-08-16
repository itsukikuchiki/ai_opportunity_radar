import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_opportunity_radar/shared/widgets/keyboard_dismiss_scope.dart';

void main() {
  Widget buildSubject() {
    return const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(viewInsets: EdgeInsets.only(bottom: 300)),
        child: KeyboardDismissScope(
          child: Scaffold(
            body: Column(
              children: [
                TextField(key: ValueKey('field')),
                ColoredBox(
                  key: ValueKey('outside'),
                  color: Colors.transparent,
                  child: SizedBox(width: 120, height: 120),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('tap outside the focused editor dismisses the keyboard',
      (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.tap(find.byKey(const ValueKey('field')));
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, isNotNull);

    await tester.tap(find.byKey(const ValueKey('outside')));
    await tester.pump();

    expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isFalse);
  });

  testWidgets('tap inside the focused editor preserves focus', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.tap(find.byKey(const ValueKey('field')));
    await tester.pump();
    final focusBefore = FocusManager.instance.primaryFocus;

    await tester.tap(find.byKey(const ValueKey('field')));
    await tester.pump();

    expect(FocusManager.instance.primaryFocus, same(focusBefore));
  });

  testWidgets('explicit keyboard control dismisses focus', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.tap(find.byKey(const ValueKey('field')));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('global-keyboard-dismiss-button')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('global-keyboard-dismiss-button')),
    );
    await tester.pump();

    expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isFalse);
  });
}
