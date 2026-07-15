import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ai_opportunity_radar/core/di/app_dependencies.dart';
import 'package:ai_opportunity_radar/core/models/today_models.dart';
import 'package:ai_opportunity_radar/features/pages/today/today_dialog_page.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
      tester.getSemantics(
        find.byKey(const ValueKey('today-dialog-heading-semantics')),
      ),
      matchesSemantics(label: 'Chat With AI', isHeader: true),
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
