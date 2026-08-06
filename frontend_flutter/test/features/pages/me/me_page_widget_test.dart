import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/purchases/purchase_controller.dart';
import 'package:ai_opportunity_radar/features/pages/me/me_page.dart';
import 'package:ai_opportunity_radar/features/pages/me/me_view_model.dart';
import 'package:ai_opportunity_radar/shared/widgets/aurora_ui.dart';

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
      lessThanOrEqualTo(196),
    );
    expect(
      tester
          .widget<AuroraHeroTitle>(
            find.byKey(const ValueKey('me-hero-title')),
          )
          .fontSize,
      36,
    );
    expect(find.byType(AuroraJourneyHeroPattern), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('me-profile-avatar'))),
      const Size(68, 68),
    );
    expect(find.byKey(const ValueKey('me-profile-summary')), findsOneWidget);
    expect(
      tester.getBottomLeft(find.byKey(const ValueKey('me-hero-header'))).dy -
          tester
              .getBottomLeft(find.byKey(const ValueKey('me-profile-summary')))
              .dy,
      lessThanOrEqualTo(17),
    );
    expect(find.byKey(const ValueKey('me-focus-domains-card')), findsOneWidget);
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

  testWidgets('Me main content follows the approved control-center order',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1800));
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

    final orderedKeys = <ValueKey<String>>[
      const ValueKey('me-profile-summary'),
      const ValueKey('me-focus-domains-card'),
      const ValueKey('me-pro-usage-card'),
      const ValueKey('me-reminders-data-card'),
      const ValueKey('me-data-privacy-card'),
      const ValueKey('me-help-about-card'),
    ];
    final tops = [
      for (final key in orderedKeys) tester.getTopLeft(find.byKey(key)).dy,
    ];
    expect(tops, orderedEquals(tops.toList()..sort()));
  });

  testWidgets('Me page renders redesigned Chinese profile sections',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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
    final greetingRect = tester.getRect(find.text('你好'));
    final editRect = tester.getRect(
      find.byKey(const ValueKey('me-profile-edit-button')),
    );
    expect(editRect.left - greetingRect.right, lessThanOrEqualTo(12));
    expect(find.text('我的'), findsOneWidget);
    expect(find.text('准备好时，再写下你想靠近的生活。'), findsOneWidget);
    expect(find.text('保存在本机'), findsNothing);
    expect(find.text('我的人生方向'), findsOneWidget);
    expect(find.text('我的关注重点'), findsNothing);
    expect(find.text('情绪安定'), findsOneWidget);

    await _scrollMeUntilVisible(tester, '升级到专业版');
    expect(find.text('升级到专业版'), findsOneWidget);

    expect(find.byKey(const ValueKey('me-pro-usage-card')), findsOneWidget);
    expect(find.text('管理订阅'), findsOneWidget);

    await _scrollMeUntilVisible(tester, '提醒与联动');
    expect(find.text('Signal 记录提醒'), findsOneWidget);
    expect(find.text('联动'), findsOneWidget);
    expect(find.text('高级信号'), findsNothing);

    await _scrollMeUntilVisible(tester, '数据与隐私');
    expect(find.text('隐私与安全'), findsOneWidget);
    expect(find.text('清除本机数据'), findsOneWidget);
    expect(find.textContaining('如何处理你的数据'), findsOneWidget);

    await _scrollMeUntilVisible(tester, '帮助与关于');
    expect(find.text('帮助与支持'), findsOneWidget);
    expect(find.text('使用条款'), findsNothing);

    expect(find.text('结构化自我复盘'), findsNothing);
    expect(find.text('AI 回应风格'), findsNothing);

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

  testWidgets('用户名铅笔只编辑用户名，人生方向由独立入口调整', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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

    await tester.tap(
      find.byKey(const ValueKey('me-profile-edit-button')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('me-profile-name-field')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('me-life-direction-settings-field')),
      findsNothing,
    );

    await tester.enterText(
      find.byKey(const ValueKey('me-profile-name-field')),
      '小路',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(meVm.profileDisplayName, '小路');

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('me-life-direction-edit-button')),
      180,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(
      find.byKey(const ValueKey('me-life-direction-edit-button')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('me-life-direction-settings-field')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('me-profile-name-field')), findsNothing);
  });

  testWidgets('隐私与支持直接打开站点，不进入应用内次级页面', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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

    await tester.scrollUntilVisible(
      find.text('隐私与安全'),
      260,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.text('隐私与安全'));
    await tester.pumpAndSettle();
    expect(find.byType(MePage), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('帮助与支持'),
      260,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.text('帮助与支持'));
    await tester.pumpAndSettle();
    expect(find.byType(MePage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Me does not expose saved AI response style', (tester) async {
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

    await tester.drag(
      find.byKey(const ValueKey('me-scroll-view')),
      const Offset(0, -1200),
    );
    await tester.pumpAndSettle();
    expect(find.text('AI 回应风格'), findsNothing);
    expect(find.text('直接 · 更短，更直接'), findsNothing);
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
    expect(find.text('4/12'), findsNWidgets(2));
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
    expect(find.text('专业版已解锁，用量正在对账'), findsOneWidget);
    expect(find.textContaining('不会把网络错误误显示为 0'), findsOneWidget);
    expect(find.text('4/12'), findsNothing);
    final proCard = find.byKey(const ValueKey('me-pro-usage-card'));
    final manageButton =
        find.byKey(const ValueKey('me-manage-subscription-button'));
    expect(manageButton, findsOneWidget);
    expect(tester.getSize(manageButton).height, greaterThanOrEqualTo(44));
    expect(
      tester.getSize(manageButton).width,
      greaterThanOrEqualTo(tester.getSize(proCard).width - 34),
    );
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
    expect(find.textContaining('购买权益仍由苹果单独管理'), findsOneWidget);
    expect(meVm.profileDisplayName, 'Mina');

    await tester.tap(find.text('删除'));
    await tester.pump();
    await tester.runAsync(() async {
      for (var attempt = 0; attempt < 1000; attempt++) {
        if (!meVm.deletingData && meVm.profileDisplayName == null) break;
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

Future<void> _scrollMeUntilVisible(
  WidgetTester tester,
  String text,
) async {
  final target = find.text(text);
  for (var attempt = 0; attempt < 12; attempt += 1) {
    if (target.evaluate().isNotEmpty) {
      await tester.ensureVisible(target.first);
      await tester.pumpAndSettle();
      return;
    }
    await tester.drag(
      find.byKey(const ValueKey('me-scroll-view')),
      const Offset(0, -280),
    );
    await tester.pumpAndSettle();
  }
  fail('Could not reveal "$text" in the Me page.');
}
