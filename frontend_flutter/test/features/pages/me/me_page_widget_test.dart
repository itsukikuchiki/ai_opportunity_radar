import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/purchases/purchase_controller.dart';
import 'package:ai_opportunity_radar/features/pages/me/me_page.dart';
import 'package:ai_opportunity_radar/features/pages/me/me_view_model.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  testWidgets('Me 主页面使用 Today 的字体和区域密度标准', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final meVm = await buildMeViewModel();

    await tester.pumpWidget(
      buildTestApp(
        child: const MePage(),
        providers: [
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final list = tester.widget<ListView>(
      find.byKey(const ValueKey('me-scroll-view')),
    );
    final padding = list.padding! as EdgeInsets;
    expect(padding, const EdgeInsets.fromLTRB(18, 14, 18, 96));
    expect(
      tester.getSize(find.byKey(const ValueKey('me-hero-header'))).height,
      lessThanOrEqualTo(170),
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('me-hero-title')))
          .style
          ?.fontSize,
      36,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('me-profile-avatar'))),
      const Size(68, 68),
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('me-life-direction-card')))
          .height,
      closeTo(158, 1),
    );
  });

  testWidgets('Me 紧凑屏幕和放大文字不溢出', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final meVm = await buildMeViewModel();

    await tester.pumpWidget(
      buildTestApp(
        child: const MediaQuery(
          data: MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(1.3),
          ),
          child: MePage(),
        ),
        providers: [
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Me'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Me page renders redesigned Chinese profile sections',
      (tester) async {
    final meVm = await buildMeViewModel();

    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        child: const MePage(),
        providers: [
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('你好'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
    expect(find.text('我的人生方向'), findsOneWidget);
    expect(find.text('还没有设置人生方向。'), findsOneWidget);
    expect(find.text('我的关注重点'), findsOneWidget);
    expect(
      find.textContaining('不会隐藏其他记录'),
      findsOneWidget,
    );
    expect(find.textContaining('仅保存在本机'), findsOneWidget);
    expect(find.text('情绪安定'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('升级到 Pro'),
      220,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('升级到 Pro'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('复盘与 AI'),
      260,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('结构化自我复盘'), findsOneWidget);
    expect(find.text('AI 回应风格'), findsOneWidget);
    expect(find.textContaining('温和 ·'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('数据与隐私'),
      260,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('高级信号'), findsOneWidget);
    expect(find.text('隐私与安全'), findsOneWidget);
    expect(find.text('帮助与支持'), findsOneWidget);
    expect(find.text('清除本机数据'), findsOneWidget);
    expect(find.textContaining('如何处理你的数据'), findsOneWidget);

    expect(find.text('本月使用'), findsNothing);
    expect(find.text('使用记录'), findsNothing);
    expect(find.text('数据与备份'), findsNothing);
    expect(find.text('导出数据'), findsNothing);
    expect(find.text('备份与同步'), findsNothing);
    expect(find.text('恢复数据'), findsNothing);
    expect(find.textContaining('Restore'), findsNothing);
    expect(find.textContaining('Backup'), findsNothing);
    expect(find.textContaining('Export'), findsNothing);
    expect(find.text('语言设置'), findsNothing);
    expect(find.text('通知设置'), findsNothing);
    expect(find.text('用户指南'), findsNothing);
  });

  testWidgets('Me reflects the actual saved AI response style', (tester) async {
    final meVm = await buildMeViewModel(responseStyle: 'direct');

    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        child: const MePage(),
        providers: [
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('AI 回应风格'),
      260,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('直接 · 更短，更直接'), findsOneWidget);
  });

  testWidgets('Me renders real quota values instead of placeholder usage',
      (tester) async {
    final meVm = await buildMeViewModel();
    meVm.usageEntitlement = 'free';
    meVm.usageQuotas = const {
      'l3_reflect': UsageQuotaViewData(
        featureKey: 'l3_reflect',
        periodType: 'monthly',
        used: 4,
        limit: 12,
      ),
    };

    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        child: const MePage(),
        providers: [
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('本月使用'),
      240,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('本月使用'), findsOneWidget);
    expect(find.text('4/12'), findsOneWidget);
    expect(find.text('0/12'), findsNothing);
    expect(find.byKey(const ValueKey('me-usage-sync-state')), findsNothing);
  });

  testWidgets('Me shows reconciliation without blocking locally unlocked Pro',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final meVm = await buildMeViewModel();
    meVm.usageEntitlement = 'free';
    meVm.usageQuotas = const {
      'l3_reflect': UsageQuotaViewData(
        featureKey: 'l3_reflect',
        periodType: 'monthly',
        used: 4,
        limit: 12,
      ),
    };
    final purchase = PurchaseController(
      storeSupported: false,
      useNativeStoreKit: false,
    );
    await purchase.init();
    purchase
      ..loading = false
      ..isPremium = true;
    addTearDown(purchase.dispose);

    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        child: const MePage(),
        providers: [
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
          ChangeNotifierProvider<PurchaseController?>.value(value: purchase),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(meVm.usageMatchesLocalEntitlement(true), isFalse);
    expect(
      Provider.of<PurchaseController?>(
        tester.element(find.byType(MePage)),
        listen: false,
      )?.isPremium,
      isTrue,
    );
    final syncCard = find.byKey(const ValueKey('me-usage-sync-state'));
    for (var attempt = 0;
        attempt < 8 && syncCard.evaluate().isEmpty;
        attempt++) {
      await tester.drag(
        find.byKey(const ValueKey('me-scroll-view')),
        const Offset(0, -180),
      );
      await tester.pumpAndSettle();
    }
    expect(
      syncCard,
      findsOneWidget,
    );
    expect(find.text('Pro 已解锁，用量正在对账'), findsOneWidget);
    expect(find.textContaining('不会把网络错误误显示为 0'), findsOneWidget);
    expect(find.text('4/12'), findsNothing);
  });

  testWidgets(
      'Me deletion requires confirmation, explains StoreKit separation, and clears real local profile data',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({
      MeViewModel.profileDisplayNamePreferenceKey: 'Mina',
      MeViewModel.lifeDirectionPreferenceKey: '给恢复和创造留空间。',
      MeViewModel.responseStylePreferenceKey: 'direct',
    });
    final database = LocalDatabase(
      dbPathOverride: ':memory:',
      databaseFactoryOverride: databaseFactoryFfi,
    );
    addTearDown(database.close);
    final meVm = MeViewModel(null, database);
    await meVm.load();

    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        child: const MePage(),
        providers: [
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('清除本机数据'), findsOneWidget);
    await tester.tap(find.text('清除本机数据'));
    await tester.pumpAndSettle();

    expect(find.text('清除本机全部数据？'), findsOneWidget);
    expect(find.textContaining('StoreKit 购买权益仍由 Apple 单独管理'), findsOneWidget);
    expect(meVm.profileDisplayName, 'Mina');

    await tester.tap(find.text('删除'));
    await tester.pump();
    await tester.runAsync(() async {
      for (var attempt = 0; attempt < 100 && meVm.deletingData; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(meVm.errorMessage, isNull);
    expect(meVm.profileDisplayName, isNull);
    expect(meVm.lifeDirection, isNull);
    expect(
      prefs.getString(MeViewModel.profileDisplayNamePreferenceKey),
      isNull,
    );
    expect(find.text('Signal Path 数据已删除。'), findsOneWidget);
  });
}
