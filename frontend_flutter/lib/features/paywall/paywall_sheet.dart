import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_locale_text.dart';
import '../../core/purchases/purchase_controller.dart';

Future<void> showPremiumPaywall(
  BuildContext context, {
  required String source,
}) {
  final purchase = context.read<PurchaseController?>();
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

class _PremiumPaywall extends StatelessWidget {
  final String source;

  const _PremiumPaywall({
    required this.source,
  });

  @override
  Widget build(BuildContext context) {
    final purchase = context.watch<PurchaseController?>();
    final theme = Theme.of(context);
    final loading = purchase?.loading ?? false;
    final pending = purchase?.purchasePending ?? false;
    final restoring = purchase?.restoring ?? false;
    final isPremium = purchase?.isPremium ?? false;
    final price = purchase?.proMonthlyDisplayPrice ?? '\$0.99';
    final storeReady = purchase?.canBuyPro ?? false;

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
              _subtitle(context, source),
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
                en: 'Continue Today entries as light dialogue',
                zhHans: '把 Today 记录继续成轻量对话',
                zhHant: '把 Today 記錄繼續成輕量對話',
                ja: 'Today の記録を短い対話として続ける',
              ),
            ),
            _BenefitRow(
              icon: Icons.auto_graph_outlined,
              text: AppLocaleText.tr(
                context,
                en: 'Open Deep Weekly and Monthly reviews',
                zhHans: '打开 Deep Weekly 和 Monthly 回看',
                zhHant: '打開 Deep Weekly 和 Monthly 回看',
                ja: 'Deep Weekly と Monthly レビューを開く',
              ),
            ),
            _BenefitRow(
              icon: Icons.menu_book_outlined,
              text: AppLocaleText.tr(
                context,
                en: 'Use the Journey journal and self-review modules',
                zhHans: '使用 Journey 手帐和专题式自我梳理',
                zhHant: '使用 Journey 手帳和專題式自我梳理',
                ja: 'Journey 手帳と Self-Review を使う',
              ),
            ),
            const SizedBox(height: 18),
            if (!isPremium)
              FilledButton.icon(
                onPressed: storeReady && !loading && !pending
                    ? () => purchase?.buyProMonthly()
                    : null,
                icon: pending || loading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_open_rounded),
                label: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Start Pro - $price / month',
                    zhHans: '开通 Pro - $price / 月',
                    zhHant: '開通 Pro - $price / 月',
                    ja: 'Pro を始める - $price / 月',
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
            if (purchase?.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                purchase!.errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ] else if (!(purchase?.storeAvailable ?? true)) ...[
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
