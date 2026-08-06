import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ai_opportunity_radar/core/purchases/purchase_controller.dart';
import 'package:ai_opportunity_radar/features/paywall/paywall_sheet.dart';

void main() {
  const locales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ];

  for (final locale in locales) {
    testWidgets(
      'restore environment states are localized for $locale',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(800, 1400);
        addTearDown(tester.view.reset);

        for (final scenario in _scenarios) {
          final purchase = PurchaseController(
            storeSupported: false,
            useNativeStoreKit: false,
          )
            ..loading = false
            ..storeAvailable = true
            ..restoreStatus = scenario.status
            ..errorMessage = scenario.message;

          await tester.pumpWidget(
            ChangeNotifierProvider<PurchaseController?>.value(
              value: purchase,
              child: MaterialApp(
                locale: locale,
                supportedLocales: locales,
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                home: Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () => showPremiumPaywall(
                        context,
                        source: 'Today',
                      ),
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
            ),
          );

          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();

          expect(
            find.byKey(const ValueKey('purchase-restore-status-banner')),
            findsOneWidget,
          );
          expect(find.text(scenario.expected(locale)), findsOneWidget);
          expect(find.textContaining('confirm the Apple ID'), findsNothing);

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          purchase.dispose();
        }
      },
    );
  }
}

class _RestoreScenario {
  final PurchaseRestoreStatus status;
  final String message;
  final String Function(Locale locale) expected;

  const _RestoreScenario({
    required this.status,
    required this.message,
    required this.expected,
  });
}

final _scenarios = <_RestoreScenario>[
  _RestoreScenario(
    status: PurchaseRestoreStatus.noEntitlement,
    message: PurchaseController.sandboxRestoreMessage,
    expected: (locale) => _localized(
      locale,
      en: 'This TestFlight build can only restore Pro purchased in TestFlight. A production App Store subscription can be restored only in the App Store version.',
      zhHans: '内部测试版只能恢复在内部测试中购买的测试订阅；正式订阅需要在正式版中恢复。',
      zhHant: '內部測試版只能恢復在內部測試中購買的測試訂閱；正式訂閱需要在正式版中恢復。',
      ja: '内部テスト版では、内部テストで購入したテスト用サブスクリプションのみ復元できます。正式な購読は正式版で復元してください。',
    ),
  ),
  _RestoreScenario(
    status: PurchaseRestoreStatus.noEntitlement,
    message: PurchaseController.localStoreKitRestoreMessage,
    expected: (locale) => _localized(
      locale,
      en: 'This development build can only restore purchases made in the same StoreKit test environment.',
      zhHans: '开发测试版只能恢复同一个购买测试环境中的购买。',
      zhHant: '開發測試版只能恢復同一個購買測試環境中的購買。',
      ja: '開発用ビルドでは、同じ購入テスト環境で行った購入のみ復元できます。',
    ),
  ),
  _RestoreScenario(
    status: PurchaseRestoreStatus.storeUnavailable,
    message: PurchaseController.entitlementEnvironmentReconciliationMessage,
    expected: (locale) => _localized(
      locale,
      en: 'Pro was verified in another or unknown StoreKit environment. Access stays active while the entitlement is reconciled.',
      zhHans: '专业版权益来自另一个或尚未识别的购买环境；对账期间会继续保留访问权限。',
      zhHant: '專業版權益來自另一個或尚未識別的購買環境；對帳期間會繼續保留存取權限。',
      ja: 'プロ版は別の、または未確認の購入環境で検証されています。照合中もアクセスは維持されます。',
    ),
  ),
];

String _localized(
  Locale locale, {
  required String en,
  required String zhHans,
  required String zhHant,
  required String ja,
}) {
  if (locale.languageCode == 'ja') return ja;
  if (locale.languageCode != 'zh') return en;
  return locale.scriptCode == 'Hant' ? zhHant : zhHans;
}
