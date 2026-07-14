import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/di/app_dependencies.dart';
import '../../core/i18n/app_locale_text.dart';
import '../../core/purchases/purchase_controller.dart';

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
                Icon(
                  Icons.workspace_premium_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AppLocaleText.tr(
                      context,
                      en: 'Signal Path Pro',
                      zhHans: 'Signal Path Pro',
                      zhHant: 'Signal Path Pro',
                      ja: 'Signal Path Pro',
                    ),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _subtitle(context, widget.source),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
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
                            zhHans: '这台设备已开通 Pro。',
                            zhHant: '這台裝置已開通 Pro。',
                            ja: 'このデバイスでは Pro が有効です。',
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
              icon: Icons.chat_bubble_outline,
              text: AppLocaleText.tr(
                context,
                en: 'Ask deeper follow-up questions across periods',
                zhHans: '围绕跨周期模式进行更深入的追问',
                zhHant: '圍繞跨週期模式進行更深入的追問',
                ja: '期間をまたぐパターンについて、より深く問いかける',
              ),
            ),
            _BenefitRow(
              icon: Icons.auto_graph_outlined,
              text: AppLocaleText.tr(
                context,
                en: 'Open Weekly deep review and Journey L3 synthesis',
                zhHans: '打开 Weekly 本周深读和 Journey L3 综合',
                zhHant: '打開 Weekly 本週深讀和 Journey L3 綜合',
                ja: 'Weekly 深掘りと Journey L3 統合を開く',
              ),
            ),
            _BenefitRow(
              icon: Icons.menu_book_outlined,
              text: AppLocaleText.tr(
                context,
                en: 'Compare periods and get evidence-backed adjustment directions',
                zhHans: '比较不同周期，获得有证据支持的调整方向',
                zhHant: '比較不同週期，獲得有證據支持的調整方向',
                ja: '期間を比較し、根拠に基づく調整方向を確認する',
              ),
            ),
            const SizedBox(height: 18),
            if (!isPremium) ...[
              _PlanOption(
                title: AppLocaleText.tr(
                  context,
                  en: 'Yearly Pro',
                  zhHans: '年付 Pro',
                  zhHant: '年付 Pro',
                  ja: '年額 Pro',
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
                  zhHans: '月付 Pro',
                  zhHant: '月付 Pro',
                  ja: '月額 Pro',
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
                        ja: 'Debug unlock',
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
                zhHans: '订阅会自动续期，可在 App Store 账户中取消。',
                zhHant: '訂閱會自動續期，可在 App Store 帳戶中取消。',
                ja: 'サブスクリプションは App Store アカウントで解約するまで自動更新されます。',
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
    return AppLocaleText.tr(
      context,
      en: '$source is part of the deeper Pro layer for longer reflection and follow-up.',
      zhHans: '$source 属于 Pro 的深度层，用来做更长周期的回看和追问。',
      zhHant: '$source 屬於 Pro 的深度層，用來做更長週期的回看和追問。',
      ja: '$source は、より深い振り返りとフォローアップのための Pro 機能です。',
    );
  }

  String _localizedPurchaseMessage(BuildContext context, String message) {
    if (message == PurchaseController.noRestorableSubscriptionMessage) {
      return AppLocaleText.tr(
        context,
        en: 'No active Pro subscription was found in this StoreKit environment.',
        zhHans: '当前 StoreKit 环境中没有找到可恢复的 Pro 订阅。',
        zhHant: '目前 StoreKit 環境中沒有找到可恢復的 Pro 訂閱。',
        ja: '現在の StoreKit 環境では復元できる Pro サブスクリプションが見つかりませんでした。',
      );
    }
    if (message == PurchaseController.restoreTemporarilyUnavailableMessage) {
      return AppLocaleText.tr(
        context,
        en: 'The App Store could not refresh purchases right now. Please check the connection and try again later.',
        zhHans: 'App Store 暂时无法刷新购买状态，请检查网络后稍后重试。',
        zhHant: 'App Store 暫時無法重新整理購買狀態，請檢查網路後稍後重試。',
        ja: 'App Store から購入状態を更新できませんでした。少し待ってから復元をお試しください。',
      );
    }
    if (message == PurchaseController.sandboxRestoreMessage) {
      return AppLocaleText.tr(
        context,
        en: 'This TestFlight build can only restore Pro purchased in TestFlight. A production App Store subscription can be restored only in the App Store version.',
        zhHans:
            'TestFlight 版只能恢复在 TestFlight 中购买的测试订阅；App Store 正式订阅需要在正式版中恢复。',
        zhHant:
            'TestFlight 版只能恢復在 TestFlight 中購買的測試訂閱；App Store 正式訂閱需要在正式版中恢復。',
        ja: 'TestFlight 版では TestFlight 内で購入したテスト用サブスクリプションのみ復元できます。App Store の正式な購読は正式版で復元してください。',
      );
    }
    if (message == PurchaseController.localStoreKitRestoreMessage) {
      return AppLocaleText.tr(
        context,
        en: 'This development build can only restore purchases made in the same StoreKit test environment.',
        zhHans: '开发测试版只能恢复同一个 StoreKit 测试环境中的购买。',
        zhHant: '開發測試版只能恢復同一個 StoreKit 測試環境中的購買。',
        ja: '開発用ビルドでは、同じ StoreKit テスト環境で行った購入のみ復元できます。',
      );
    }
    if (message ==
        PurchaseController.entitlementEnvironmentReconciliationMessage) {
      return AppLocaleText.tr(
        context,
        en: 'Pro was verified in another or unknown StoreKit environment. Access stays active while the entitlement is reconciled.',
        zhHans: 'Pro 权益来自另一个或尚未识别的 StoreKit 环境；对账期间会继续保留访问权限。',
        zhHant: 'Pro 權益來自另一個或尚未識別的 StoreKit 環境；對帳期間會繼續保留存取權限。',
        ja: 'Pro は別の、または未確認の StoreKit 環境で検証されています。照合中もアクセスは維持されます。',
      );
    }
    return message;
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
        zhHans: '正在当前 StoreKit 环境中查询有效的 Pro 权益…',
        zhHant: '正在目前 StoreKit 環境中查詢有效的 Pro 權益…',
        ja: '現在の StoreKit 環境で有効な Pro 権利を確認しています…',
      );
    }
    if (purchase.entitlementReconciliationPending) {
      return AppLocaleText.tr(
        context,
        en: 'Pro is active. Backend verification is syncing in the background and does not block access.',
        zhHans: 'Pro 已激活。后台验证正在异步同步，不影响当前使用。',
        zhHant: 'Pro 已啟用。後台驗證正在非同步同步，不影響目前使用。',
        ja: 'Pro は有効です。バックエンド検証はバックグラウンドで同期中ですが、利用には影響しません。',
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
          ? '开通 Pro - $yearlyPrice / 年'
          : '开通 Pro - $monthlyPrice / 月',
      zhHant: productId == PurchaseController.proYearlyProductId
          ? '開通 Pro - $yearlyPrice / 年'
          : '開通 Pro - $monthlyPrice / 月',
      ja: productId == PurchaseController.proYearlyProductId
          ? 'Pro を始める - $yearlyPrice / 年'
          : 'Pro を始める - $monthlyPrice / 月',
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
              zhHans: '使用条款 (EULA)',
              zhHant: '使用條款 (EULA)',
              ja: '利用規約 (EULA)',
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
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.34)
              : theme.colorScheme.surface,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(8),
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
                            fontWeight: FontWeight.w800,
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
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
