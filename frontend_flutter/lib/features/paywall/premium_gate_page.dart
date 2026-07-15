import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_locale_text.dart';
import '../../core/purchases/purchase_controller.dart';
import '../../shared/widgets/aurora_ui.dart';
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
                      onPressed: () => Navigator.of(context).maybePop(),
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
                                  en: 'Read this week in more structure after the 3-signal Weekly gate.',
                                  zhHans: '达到每周复盘的 3 条信号门槛后，对本周做更有结构的回看。',
                                  zhHant: '達到 Weekly 的 3 條信號門檻後，對本週做更有結構的回看。',
                                  ja: 'Weekly の 3 件ゲート後、今週をより構造的に振り返ります。',
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
                                  en: 'Long-term patterns',
                                  zhHans: '长期趋势洞察',
                                  zhHant: '長期趨勢洞察',
                                  ja: '長期パターン',
                                ),
                                body: AppLocaleText.tr(
                                  context,
                                  en: 'L3 period comparison starts after 14 eligible signals across 7 days and 2 local weeks in the latest 28 days.',
                                  zhHans:
                                      '近 28 天达到 14 条有效信号、覆盖 7 个记录日和 2 个自然周后，开始显示跨周期深度分析报告。',
                                  zhHant:
                                      '近 28 天達到 14 條有效信號、覆蓋 7 個記錄日和 2 個自然週後，開始顯示 L3 跨週期深度報告。',
                                  ja: '直近 28 日で有効なシグナル 14 件、記録日 7 日、ローカル週 2 週を満たすと L3 期間比較を表示します。',
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
