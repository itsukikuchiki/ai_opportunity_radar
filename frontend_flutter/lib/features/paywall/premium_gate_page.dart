import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_locale_text.dart';
import '../../core/navigation/app_back_navigation.dart';
import '../../core/purchases/purchase_controller.dart';
import '../../shared/widgets/aurora_ui.dart';
import 'paywall_sheet.dart';

class PremiumGatePage extends StatelessWidget {
  final String source;
  final String fallbackRoute;
  final Widget child;

  const PremiumGatePage({
    super.key,
    required this.source,
    required this.fallbackRoute,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final purchase = context.watch<PurchaseController?>();
    if (purchase == null || purchase.isPremium) return child;

    final theme = Theme.of(context);
    const gateTitle = 'Signal Path Pro';
    return Scaffold(
      body: Stack(
        children: [
          AuroraPage(
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 36),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AuroraIconButton(
                      key: const ValueKey('premium-gate-close'),
                      icon: Icons.close_rounded,
                      tooltip:
                          MaterialLocalizations.of(context).closeButtonTooltip,
                      onPressed: () => context.popOrGo(fallbackRoute),
                    ),
                  ),
                  const SizedBox(height: 10),
                  AuroraCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(24, 34, 24, 30),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AuroraColors.purple.withValues(alpha: 0.14),
                                AuroraColors.blue.withValues(alpha: 0.10),
                                AuroraColors.gold.withValues(alpha: 0.10),
                              ],
                            ),
                          ),
                          child: Column(
                            children: [
                              const AuroraHeroEmblem(size: 124),
                              const SizedBox(height: 12),
                              Semantics(
                                key: const ValueKey(
                                    'premium-gate-heading-semantics'),
                                container: true,
                                excludeSemantics: true,
                                header: true,
                                label: gateTitle,
                                child: Text(
                                  gateTitle,
                                  textAlign: TextAlign.center,
                                  style:
                                      theme.textTheme.headlineSmall?.copyWith(
                                    color: AuroraColors.ink,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                AppLocaleText.tr(
                                  context,
                                  en: 'Go deeper, grow with more clarity',
                                  zhHans: '更深洞察，更稳成长',
                                  zhHant: '更深洞察，更穩成長',
                                  ja: 'より深く振り返り、静かに育つ',
                                ),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AuroraColors.muted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                          child: Column(
                            children: [
                              _GateBenefitTile(
                                icon: Icons.hexagon_rounded,
                                color: AuroraColors.purple,
                                title: AppLocaleText.tr(
                                  context,
                                  en: 'Weekly deep review',
                                  zhHans: '每周复盘深度分析',
                                  zhHant: 'Weekly 本週深讀',
                                  ja: 'Weekly 深掘りレビュー',
                                ),
                                body: AppLocaleText.tr(
                                  context,
                                  en: 'Read this week in more structure after the 3-Signal Weekly gate, and use it as reference for next week’s tries.',
                                  zhHans:
                                      '达到每周复盘的 3 条 Signal 门槛后，对本周做更有结构的回看，并作为下周尝试生成时的参考。',
                                  zhHant:
                                      '達到每週復盤的 3 條 Signal 門檻後，對本週做更有結構的回看，並作為下週嘗試生成時的參考。',
                                  ja: '毎週の Signal が 3 件に達したら、今週をより構造的に振り返り、来週の試みを考える参考にします。',
                                ),
                              ),
                              const SizedBox(height: 10),
                              _GateBenefitTile(
                                icon: Icons.auto_awesome_rounded,
                                color: AuroraColors.blue,
                                title: AppLocaleText.tr(
                                  context,
                                  en: 'Structured self-review',
                                  zhHans: '深度专题梳理',
                                  zhHant: '深度專題梳理',
                                  ja: 'テーマ別セルフレビュー',
                                ),
                                body: AppLocaleText.tr(
                                  context,
                                  en: 'Collect related signals into one focused review.',
                                  zhHans: '把相关信号收成一次更聚焦的回看。',
                                  zhHant: '把相關信號收成一次更聚焦的回看。',
                                  ja: '関連するシグナルをまとめて振り返ります。',
                                ),
                              ),
                              const SizedBox(height: 10),
                              _GateBenefitTile(
                                icon: Icons.insights_rounded,
                                color: AuroraColors.mint,
                                title: AppLocaleText.tr(
                                  context,
                                  en: 'Three-month change',
                                  zhHans: '三个月变化',
                                  zhHant: '三個月變化',
                                  ja: '3か月の変化',
                                ),
                                body: AppLocaleText.tr(
                                  context,
                                  en: 'Compare the selected natural month with the two months before it. Change summaries appear after two months each reach 7 eligible Signals across 3 recording days.',
                                  zhHans:
                                      '比较选定自然月与之前两个月；其中至少两个月各达到 7 条有效 Signal、覆盖 3 个记录日后，开始显示变化总结。',
                                  zhHant:
                                      '比較選定自然月與之前兩個月；其中至少兩個月各達到 7 條有效 Signal、覆蓋 3 個記錄日後，開始顯示變化總結。',
                                  ja: '選択月とその前の2か月を比較します。2か月以上で各月Signal 7件・記録日3日を満たすと、変化のまとめを表示します。',
                                ),
                              ),
                              const SizedBox(height: 18),
                              SizedBox(
                                width: double.infinity,
                                child: AuroraPillButton(
                                  label: AppLocaleText.tr(
                                    context,
                                    en: 'View Pro',
                                    zhHans: '查看 Pro',
                                    zhHant: '查看 Pro',
                                    ja: 'Pro を見る',
                                  ),
                                  icon: Icons.workspace_premium_rounded,
                                  filled: true,
                                  onPressed: () => showPremiumPaywall(
                                    context,
                                    source: source,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const AuroraSafeTopMask(),
        ],
      ),
    );
  }
}

class _GateBenefitTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const _GateBenefitTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AuroraCard(
      padding: const EdgeInsets.all(14),
      borderRadius: BorderRadius.circular(22),
      color: Colors.white.withValues(alpha: 0.62),
      child: Row(
        children: [
          AuroraSoftIconCircle(icon: icon, color: color, size: 46),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AuroraColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AuroraColors.muted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: AuroraColors.muted.withValues(alpha: 0.72),
          ),
        ],
      ),
    );
  }
}
