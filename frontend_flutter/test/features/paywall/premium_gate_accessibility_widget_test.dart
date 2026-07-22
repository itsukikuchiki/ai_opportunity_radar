import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ai_opportunity_radar/core/purchases/purchase_controller.dart';
import 'package:ai_opportunity_radar/features/paywall/premium_gate_page.dart';

import '../../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PremiumGate keeps its controls accessible at 390x844 and 1.3x',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    final purchase = PurchaseController(storeSupported: false);
    addTearDown(purchase.dispose);

    await tester.pumpWidget(
      buildTestApp(
        child: const MediaQuery(
          data: MediaQueryData(
            size: Size(390, 844),
            textScaler: TextScaler.linear(1.3),
          ),
          child: PremiumGatePage(
            source: 'accessibility_test',
            fallbackRoute: '/today',
            child: SizedBox.shrink(),
          ),
        ),
        providers: [
          ChangeNotifierProvider<PurchaseController>.value(value: purchase),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const ValueKey('premium-gate-close'))),
      const Size(44, 44),
    );
    expect(find.byTooltip('Close'), findsOneWidget);
    expect(
      tester.getSemantics(
        find.byKey(const ValueKey('premium-gate-heading-semantics')),
      ),
      matchesSemantics(label: 'Signal Path Pro', isHeader: true),
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('PremiumGate describes deep analysis as next-week reference',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final purchase = PurchaseController(storeSupported: false);
    addTearDown(purchase.dispose);

    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        child: const PremiumGatePage(
          source: 'copy_test',
          fallbackRoute: '/today',
          child: SizedBox.shrink(),
        ),
        providers: [
          ChangeNotifierProvider<PurchaseController>.value(value: purchase),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('作为下周尝试生成时的参考'),
      findsOneWidget,
    );
    expect(find.textContaining('不自动创建'), findsNothing);
    expect(find.textContaining('不自动采纳'), findsNothing);
    expect(find.textContaining('不会自动创建'), findsNothing);
    expect(find.textContaining('不会自动采纳'), findsNothing);
  });
}
