import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_locale_text.dart';
import '../../core/purchases/purchase_controller.dart';
import 'paywall_sheet.dart';

class PremiumGatePage extends StatelessWidget {
  final String source;
  final Widget child;

  const PremiumGatePage({
    super.key,
    required this.source,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final purchase = context.watch<PurchaseController?>();
    if (purchase == null || purchase.isPremium) return child;

    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(source),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                size: 44,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 14),
              Text(
                AppLocaleText.tr(
                  context,
                  en: '$source is a Pro feature',
                  zhHans: '$source 是 Pro 功能',
                  zhHant: '$source 是 Pro 功能',
                  ja: '$source は Pro 機能です',
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocaleText.tr(
                  context,
                  en: 'Upgrade to unlock deeper reviews, journal view, and follow-up dialogue.',
                  zhHans: '升级后可以使用更深层回看、手帐视图和追问对话。',
                  zhHant: '升級後可以使用更深層回看、手帳視圖和追問對話。',
                  ja: 'アップグレードすると、深い振り返り、手帳ビュー、フォローアップ対話が使えます。',
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => showPremiumPaywall(context, source: source),
                icon: const Icon(Icons.workspace_premium_outlined),
                label: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'View Pro',
                    zhHans: '查看 Pro',
                    zhHant: '查看 Pro',
                    ja: 'Pro を見る',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
