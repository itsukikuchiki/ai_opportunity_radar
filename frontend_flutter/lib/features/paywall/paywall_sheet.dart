import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/di/app_dependencies.dart';
import '../../core/i18n/app_locale_text.dart';
import '../../core/purchases/purchase_controller.dart';
import '../../shared/widgets/aurora_ui.dart';

Future<void> showPremiumPaywall(
  BuildContext context, {
  required String source,
}) {
  final purchase = context.read<PurchaseController?>();
  try {
    unawaited(
      context.read<AppDependencies>().analyticsRepository.track(
        'paywall_open',
        properties: {'source': source},
      ),
    );
  } catch (_) {
    // Some widget tests mount the paywall without the full app dependency graph.
  }
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => purchase == null
        ? _PremiumPaywall(source: source)
        : ChangeNotifierProvider<PurchaseController?>.value(
            value: purchase,
            child: _PremiumPaywall(source: source),
          ),
  );
}

class _PremiumPaywall extends StatefulWidget {
  final String source;

  const _PremiumPaywall({
    required this.source,
  });

  @override
  State<_PremiumPaywall> createState() => _PremiumPaywallState();
}

class _PremiumPaywallState extends State<_PremiumPaywall> {
  static final Uri _privacyPolicyUri = Uri.parse(
    'https://itsukikuchiki.github.io/signalpath-support/',
  );
  static final Uri _termsOfUseUri = Uri.parse(
    'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
  );

  String _selectedProductId = PurchaseController.proYearlyProductId;

  @override
  Widget build(BuildContext context) {
    final purchase = context.watch<PurchaseController?>();
    final theme = Theme.of(context);
    final loading = purchase?.loading ?? false;
    final pending = purchase?.purchasePending ?? false;
    final restoring = purchase?.restoring ?? false;
    final isPremium = purchase?.isPremium ?? false;
    final monthlyPrice = purchase?.proMonthlyDisplayPrice ?? '\$2.99';
    final yearlyPrice = purchase?.proYearlyDisplayPrice ?? '\$29.99';
    final effectiveProductId = _effectiveProductId(purchase);
    final selectedReady = purchase?.canBuyProduct(effectiveProductId) ?? false;
    final hasAnyPlan = purchase?.proYearlyProduct != null ||
        purchase?.proMonthlyProduct != null;
    final canAttemptNativePurchase =
        purchase?.canAttemptNativeStoreKitPurchase ?? false;
    final canStartPurchase = purchase != null &&
        !pending &&
        !loading &&
        (selectedReady || canAttemptNativePurchase);
    final canReloadPlans = purchase != null &&
        !pending &&
        !loading &&
        !hasAnyPlan &&
        !canAttemptNativePurchase;
    final restoreStatusMessage =
        purchase == null ? null : _restoreStatusMessage(context, purchase);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const AuroraSectionIcon(
                  icon: Icons.workspace_premium_outlined,
                  color: AuroraColors.purple,
                  size: 38,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AppLocaleText.tr(
                      context,
                      en: 'Signal Path Pro',
                      zhHans: 'Signal Path 专业版',
                      zhHant: 'Signal Path 專業版',
                      ja: 'Signal Path プロ版',
                    ),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AuroraColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _subtitle(context, widget.source),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AuroraColors.muted,
              ),
            ),
            const SizedBox(height: 16),
            if (isPremium) ...[
              Card(
                color: theme.colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          AppLocaleText.tr(
                            context,
                            en: 'Pro is active on this device.',
                            zhHans: '这台设备已开通专业版。',
                            zhHant: '這台裝置已開通專業版。',
                            ja: 'このデバイスではプロ版が有効です。',
                          ),
                          style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Done',
                    zhHans: '完成',
                    zhHant: '完成',
                    ja: '完了',
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            _BenefitRow(
              icon: Icons.auto_graph_outlined,
              text: AppLocaleText.tr(
                context,
                en: 'See focus-area, theme, energy and rhythm changes across every month since first use',
                zhHans: '查看从首次使用至今，每个月的关注领域、主题、能量与节奏变化',
                zhHant: '查看從首次使用至今，每個月的關注領域、主題、能量與節奏變化',
                ja: '初回利用から現在まで、すべての月の関心領域・テーマ・'
                    'エネルギー・リズムの変化を見る',
              ),
            ),
            _BenefitRow(
              icon: Icons.auto_graph_outlined,
              text: AppLocaleText.tr(
                context,
                en: 'Use Weekly deep analysis as a reference for next week’s tries',
                zhHans: '用每周复盘的深度分析，作为下周尝试生成时的参考',
                zhHant: '用每週復盤的深度分析，作為下週嘗試生成時的參考',
                ja: '毎週の深い分析を、来週の試みを考えるための参考にする',
              ),
            ),
            _BenefitRow(
              icon: Icons.menu_book_outlined,
              text: AppLocaleText.tr(
                context,
                en: 'Review conservative month-to-month change summaries',
                zhHans: '回看保守、可核对的月度变化总结',
                zhHant: '回看保守、可核對的月度變化總結',
                ja: '控えめで確認可能な月ごとの変化を振り返る',
              ),
            ),
            _BenefitRow(
              icon: Icons.insights_outlined,
              text: AppLocaleText.tr(
                context,
                en: 'Summarize which experiments feel more helpful, manageable and easier to begin',
                zhHans: '整理哪些实验更有帮助、负担更合适，也更容易开始',
                zhHant: '整理哪些實驗更有幫助、負擔更合適，也更容易開始',
                ja: '役立ちやすく、負担が合い、始めやすい実験の傾向を整理する',
              ),
            ),
            const SizedBox(height: 18),
            if (!isPremium) ...[
              _PlanOption(
                title: AppLocaleText.tr(
                  context,
                  en: 'Yearly Pro',
                  zhHans: '年付专业版',
                  zhHant: '年付專業版',
                  ja: '年額プロ版',
                ),
                subtitle: AppLocaleText.tr(
                  context,
                  en: 'Best for long-term reflection',
                  zhHans: '更适合长期回看',
                  zhHant: '更適合長期回看',
                  ja: '長期の振り返りにおすすめ',
                ),
                price: AppLocaleText.tr(
                  context,
                  en: '$yearlyPrice / year',
                  zhHans: '$yearlyPrice / 年',
                  zhHant: '$yearlyPrice / 年',
                  ja: '$yearlyPrice / 年',
                ),
                selected:
                    effectiveProductId == PurchaseController.proYearlyProductId,
                enabled: true,
                badge: AppLocaleText.tr(
                  context,
                  en: 'Best value',
                  zhHans: '更划算',
                  zhHant: '更划算',
                  ja: 'おすすめ',
                ),
                onTap: () {
                  setState(() {
                    _selectedProductId = PurchaseController.proYearlyProductId;
                  });
                },
              ),
              const SizedBox(height: 8),
              _PlanOption(
                title: AppLocaleText.tr(
                  context,
                  en: 'Monthly Pro',
                  zhHans: '月付专业版',
                  zhHant: '月付專業版',
                  ja: '月額プロ版',
                ),
                subtitle: AppLocaleText.tr(
                  context,
                  en: 'Flexible month-to-month access',
                  zhHans: '按月灵活开通',
                  zhHant: '按月彈性開通',
                  ja: '月ごとに気軽に使う',
                ),
                price: AppLocaleText.tr(
                  context,
                  en: '$monthlyPrice / month',
                  zhHans: '$monthlyPrice / 月',
                  zhHant: '$monthlyPrice / 月',
                  ja: '$monthlyPrice / 月',
                ),
                selected: effectiveProductId ==
                    PurchaseController.proMonthlyProductId,
                enabled: true,
                onTap: () {
                  setState(() {
                    _selectedProductId = PurchaseController.proMonthlyProductId;
                  });
                },
              ),
              const SizedBox(height: 14),
            ],
            if (!isPremium)
              FilledButton.icon(
                onPressed: canStartPurchase
                    ? () => purchase.buyProProduct(effectiveProductId)
                    : canReloadPlans
                        ? () => purchase.init()
                        : null,
                icon: pending
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : canStartPurchase
                        ? const Icon(Icons.lock_open_rounded)
                        : !selectedReady || loading || !hasAnyPlan
                            ? const Icon(Icons.refresh_rounded)
                            : const Icon(Icons.lock_open_rounded),
                label: Text(
                  _primaryButtonText(
                    context,
                    productId: effectiveProductId,
                    hasAnyPlan: hasAnyPlan,
                    canAttemptNativePurchase: canAttemptNativePurchase,
                    yearlyPrice: yearlyPrice,
                    monthlyPrice: monthlyPrice,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed:
                      restoring ? null : () => purchase?.restorePurchases(),
                  child: Text(
                    restoring
                        ? AppLocaleText.tr(
                            context,
                            en: 'Restoring...',
                            zhHans: '正在恢复...',
                            zhHant: '正在恢復...',
                            ja: '復元中...',
                          )
                        : AppLocaleText.tr(
                            context,
                            en: 'Restore purchases',
                            zhHans: '恢复购买',
                            zhHant: '恢復購買',
                            ja: '購入を復元',
                          ),
                  ),
                ),
                if (kDebugMode) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => purchase?.unlockForLocalTesting(),
                    child: Text(
                      AppLocaleText.tr(
                        context,
                        en: 'Debug unlock',
                        zhHans: '调试解锁',
                        zhHant: '調試解鎖',
                        ja: 'デバッグ解除',
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (restoreStatusMessage != null) ...[
              const SizedBox(height: 4),
              _RestoreStatusBanner(
                status: purchase!.restoreStatus,
                message: restoreStatusMessage,
              ),
            ],
            const SizedBox(height: 4),
            _LegalLinksRow(
              onOpenPrivacy: () => _openLegalLink(_privacyPolicyUri),
              onOpenTerms: () => _openLegalLink(_termsOfUseUri),
            ),
            if (purchase?.errorMessage == null &&
                !(purchase?.storeAvailable ?? true)) ...[
              const SizedBox(height: 8),
              Text(
                AppLocaleText.tr(
                  context,
                  en: 'The store is not available on this device right now.',
                  zhHans: '当前设备暂时无法连接商店。',
                  zhHant: '目前裝置暫時無法連接商店。',
                  ja: 'このデバイスでは現在ストアを利用できません。',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              AppLocaleText.tr(
                context,
                en: 'Subscription renews automatically until canceled in your App Store account.',
                zhHans: '订阅会自动续期，可在苹果应用商店账户中取消。',
                zhHant: '訂閱會自動續期，可在蘋果應用程式商店帳戶中取消。',
                ja: 'サブスクリプションはアプリストアのアカウントで解約するまで自動更新されます。',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle(BuildContext context, String source) {
    final visibleSource = switch (AppLocaleText.resolve(context)) {
      AppLanguage.simplifiedChinese => switch (source) {
          'Structured self-review' => '深度专题梳理',
          'Weekly chart reading' => '每周复盘图表解读',
          'goal_summary_history' => '目标总结历史',
          'small_experiment_summary_history' => '小实验总结历史',
          'life_experiment_action_preferences' => '行动偏好深度报告',
          'Pro' => '专业版',
          'Today record' || '今天记录' || '今天記錄' || '今日の記録' => '今天记录',
          '每周复盘深度分析' => '每周复盘深度分析',
          '旅程深度分析' => '旅程深度分析',
          _ => '专业版功能',
        },
      AppLanguage.traditionalChinese => switch (source) {
          'Structured self-review' => '深度專題梳理',
          'Weekly chart reading' => '每週復盤圖表解讀',
          'goal_summary_history' => '目標總結歷史',
          'small_experiment_summary_history' => '小實驗總結歷史',
          'life_experiment_action_preferences' => '行動偏好深度報告',
          'Pro' => '專業版',
          'Today record' || '今天记录' || '今天記錄' || '今日の記録' => '今天記錄',
          '每周复盘深度分析' => '每週復盤深度分析',
          '旅程深度分析' => '旅程深度分析',
          _ => '專業版功能',
        },
      AppLanguage.japanese => switch (source) {
          'Structured self-review' => '深掘りテーマ整理',
          'Weekly chart reading' => '週次振り返りの図表解説',
          'goal_summary_history' => '目標まとめの履歴',
          'small_experiment_summary_history' => '小さな実験まとめの履歴',
          'life_experiment_action_preferences' => '行動傾向の深掘りレポート',
          'Pro' => 'プロ版',
          'Today record' || '今天记录' || '今天記錄' || '今日の記録' => '今日の記録',
          '每周复盘深度分析' => '週次振り返りの深掘り分析',
          '旅程深度分析' => '旅程の深掘り分析',
          _ => 'プロ版機能',
        },
      AppLanguage.english => source,
    };
    return AppLocaleText.tr(
      context,
      en: '$visibleSource is part of the Pro layer for longer-period reflection.',
      zhHans: '$visibleSource 属于专业版的深度层，用来做更长周期的回看。',
      zhHant: '$visibleSource 屬於專業版的深度層，用來做更長週期的回看。',
      ja: '$visibleSource は、より長い期間を振り返るためのプロ版機能です。',
    );
  }

  String _localizedPurchaseMessage(BuildContext context, String message) {
    if (message == PurchaseController.noRestorableSubscriptionMessage) {
      return AppLocaleText.tr(
        context,
        en: 'No active Pro subscription was found in this StoreKit environment.',
        zhHans: '当前购买环境中没有找到可恢复的专业版订阅。',
        zhHant: '目前購買環境中沒有找到可恢復的專業版訂閱。',
        ja: '現在の購入環境では復元できるプロ版サブスクリプションが見つかりませんでした。',
      );
    }
    if (message == PurchaseController.restoreTemporarilyUnavailableMessage) {
      return AppLocaleText.tr(
        context,
        en: 'The App Store could not refresh purchases right now. Please check the connection and try again later.',
        zhHans: '苹果应用商店暂时无法刷新购买状态，请检查网络后稍后重试。',
        zhHant: '蘋果應用程式商店暫時無法重新整理購買狀態，請檢查網路後稍後重試。',
        ja: 'アプリストアから購入状態を更新できませんでした。少し待ってから復元をお試しください。',
      );
    }
    if (message == PurchaseController.sandboxRestoreMessage) {
      return AppLocaleText.tr(
        context,
        en: 'This TestFlight build can only restore Pro purchased in TestFlight. A production App Store subscription can be restored only in the App Store version.',
        zhHans: '内部测试版只能恢复在内部测试中购买的测试订阅；正式订阅需要在正式版中恢复。',
        zhHant: '內部測試版只能恢復在內部測試中購買的測試訂閱；正式訂閱需要在正式版中恢復。',
        ja: '内部テスト版では、内部テストで購入したテスト用サブスクリプションのみ復元できます。正式な購読は正式版で復元してください。',
      );
    }
    if (message == PurchaseController.localStoreKitRestoreMessage) {
      return AppLocaleText.tr(
        context,
        en: 'This development build can only restore purchases made in the same StoreKit test environment.',
        zhHans: '开发测试版只能恢复同一个购买测试环境中的购买。',
        zhHant: '開發測試版只能恢復同一個購買測試環境中的購買。',
        ja: '開発用ビルドでは、同じ購入テスト環境で行った購入のみ復元できます。',
      );
    }
    if (message ==
        PurchaseController.entitlementEnvironmentReconciliationMessage) {
      return AppLocaleText.tr(
        context,
        en: 'Pro was verified in another or unknown StoreKit environment. Access stays active while the entitlement is reconciled.',
        zhHans: '专业版权益来自另一个或尚未识别的购买环境；对账期间会继续保留访问权限。',
        zhHant: '專業版權益來自另一個或尚未識別的購買環境；對帳期間會繼續保留存取權限。',
        ja: 'プロ版は別の、または未確認の購入環境で検証されています。照合中もアクセスは維持されます。',
      );
    }
    return switch (AppLocaleText.resolve(context)) {
      AppLanguage.english => message,
      AppLanguage.simplifiedChinese => switch (message) {
          'Purchases are temporarily unavailable.' => '购买功能暂时不可用，请稍后重试。',
          'Premium product is not available from the store yet.' =>
            '商店暂时还没有提供专业版方案。',
          'The store could not start the purchase.' => '商店暂时无法开始购买，请稍后重试。',
          'The store did not return a transaction.' => '商店没有返回购买结果，请稍后重试。',
          'Purchases are not available on this platform.' => '当前平台不支持应用内购买。',
          'Purchase failed. Please try again.' => '购买失败，请稍后重试。',
          _ => '暂时无法完成购买操作，请稍后重试。',
        },
      AppLanguage.traditionalChinese => switch (message) {
          'Purchases are temporarily unavailable.' => '購買功能暫時不可用，請稍後重試。',
          'Premium product is not available from the store yet.' =>
            '商店暫時還沒有提供專業版方案。',
          'The store could not start the purchase.' => '商店暫時無法開始購買，請稍後重試。',
          'The store did not return a transaction.' => '商店沒有傳回購買結果，請稍後重試。',
          'Purchases are not available on this platform.' => '目前平台不支援應用程式內購買。',
          'Purchase failed. Please try again.' => '購買失敗，請稍後重試。',
          _ => '暫時無法完成購買操作，請稍後重試。',
        },
      AppLanguage.japanese => switch (message) {
          'Purchases are temporarily unavailable.' =>
            '購入機能は一時的に利用できません。しばらくしてから再試行してください。',
          'Premium product is not available from the store yet.' =>
            'ストアではまだプロ版を利用できません。',
          'The store could not start the purchase.' =>
            'ストアで購入を開始できませんでした。しばらくしてから再試行してください。',
          'The store did not return a transaction.' =>
            'ストアから購入結果が返されませんでした。しばらくしてから再試行してください。',
          'Purchases are not available on this platform.' =>
            'このプラットフォームではアプリ内購入を利用できません。',
          'Purchase failed. Please try again.' =>
            '購入できませんでした。しばらくしてから再試行してください。',
          _ => '購入を完了できませんでした。しばらくしてから再試行してください。',
        },
    };
  }

  String? _restoreStatusMessage(
    BuildContext context,
    PurchaseController purchase,
  ) {
    final error = purchase.errorMessage;
    if (error != null && error.trim().isNotEmpty) {
      return _localizedPurchaseMessage(context, error);
    }
    if (purchase.restoring ||
        purchase.restoreStatus == PurchaseRestoreStatus.checkingStore) {
      return AppLocaleText.tr(
        context,
        en: 'Checking this StoreKit environment for an active Pro entitlement...',
        zhHans: '正在当前购买环境中查询有效的专业版权益…',
        zhHant: '正在目前購買環境中查詢有效的專業版權益…',
        ja: '現在の購入環境で有効なプロ版の権利を確認しています…',
      );
    }
    if (purchase.entitlementReconciliationPending) {
      return AppLocaleText.tr(
        context,
        en: 'Pro is active. Backend verification is syncing in the background and does not block access.',
        zhHans: '专业版已激活。后台验证正在异步同步，不影响当前使用。',
        zhHant: '專業版已啟用。後台驗證正在非同步同步，不影響目前使用。',
        ja: 'プロ版は有効です。バックエンド検証はバックグラウンドで同期中ですが、利用には影響しません。',
      );
    }
    return null;
  }

  String _effectiveProductId(PurchaseController? purchase) {
    if (purchase?.canBuyProduct(_selectedProductId) ?? false) {
      return _selectedProductId;
    }
    if (purchase?.proYearlyProduct != null) {
      return PurchaseController.proYearlyProductId;
    }
    if (purchase?.proMonthlyProduct != null) {
      return PurchaseController.proMonthlyProductId;
    }
    return _selectedProductId;
  }

  String _primaryButtonText(
    BuildContext context, {
    required String productId,
    required bool hasAnyPlan,
    required bool canAttemptNativePurchase,
    required String yearlyPrice,
    required String monthlyPrice,
  }) {
    if (!hasAnyPlan && !canAttemptNativePurchase) {
      return AppLocaleText.tr(
        context,
        en: 'Reload purchase options',
        zhHans: '重新加载购买选项',
        zhHant: '重新載入購買選項',
        ja: '購入オプションを再読み込み',
      );
    }

    return AppLocaleText.tr(
      context,
      en: productId == PurchaseController.proYearlyProductId
          ? 'Start Pro - $yearlyPrice / year'
          : 'Start Pro - $monthlyPrice / month',
      zhHans: productId == PurchaseController.proYearlyProductId
          ? '开通专业版 - $yearlyPrice / 年'
          : '开通专业版 - $monthlyPrice / 月',
      zhHant: productId == PurchaseController.proYearlyProductId
          ? '開通專業版 - $yearlyPrice / 年'
          : '開通專業版 - $monthlyPrice / 月',
      ja: productId == PurchaseController.proYearlyProductId
          ? 'プロ版を始める - $yearlyPrice / 年'
          : 'プロ版を始める - $monthlyPrice / 月',
    );
  }

  Future<void> _openLegalLink(Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }
}

class _RestoreStatusBanner extends StatelessWidget {
  final PurchaseRestoreStatus status;
  final String message;

  const _RestoreStatusBanner({
    required this.status,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isError = status == PurchaseRestoreStatus.failed ||
        status == PurchaseRestoreStatus.storeUnavailable;
    final isPending = status == PurchaseRestoreStatus.checkingStore ||
        status == PurchaseRestoreStatus.verificationPending;
    final color = isError
        ? Theme.of(context).colorScheme.error
        : isPending
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurfaceVariant;

    return Semantics(
      liveRegion: true,
      label: message,
      child: Container(
        key: const ValueKey('purchase-restore-status-banner'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.24)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : isPending
                      ? Icons.sync_rounded
                      : Icons.info_outline_rounded,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalLinksRow extends StatelessWidget {
  final VoidCallback onOpenPrivacy;
  final VoidCallback onOpenTerms;

  const _LegalLinksRow({
    required this.onOpenPrivacy,
    required this.onOpenTerms,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 0,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TextButton(
          onPressed: onOpenPrivacy,
          child: Text(
            AppLocaleText.tr(
              context,
              en: 'Privacy Policy',
              zhHans: '隐私政策',
              zhHant: '隱私政策',
              ja: 'プライバシーポリシー',
            ),
          ),
        ),
        TextButton(
          onPressed: onOpenTerms,
          child: Text(
            AppLocaleText.tr(
              context,
              en: 'Terms of Use (EULA)',
              zhHans: '使用条款（最终用户许可协议）',
              zhHant: '使用條款（最終使用者授權協議）',
              ja: '利用規約（エンドユーザー使用許諾契約）',
            ),
          ),
        ),
      ],
    );
  }
}

class _PlanOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final String price;
  final String? badge;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _PlanOption({
    required this.title,
    required this.subtitle,
    required this.price,
    this.badge,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor =
        selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant;
    final foreground = enabled
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.58);

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: selected
                ? [
                    Colors.white.withValues(alpha: 0.92),
                    AuroraColors.purple.withValues(alpha: 0.12),
                    AuroraColors.blue.withValues(alpha: 0.08),
                  ]
                : [
                    Colors.white.withValues(alpha: 0.82),
                    const Color(0xFFF8F5FF).withValues(alpha: 0.70),
                  ],
          ),
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(18),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AuroraColors.purple.withValues(alpha: 0.12),
                    blurRadius: 18,
                    spreadRadius: -8,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: enabled
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            child: Text(
                              badge!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              price,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BenefitRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuroraSectionIcon(
            icon: icon,
            color: theme.colorScheme.primary,
            size: 30,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AuroraColors.ink.withValues(alpha: 0.82),
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
