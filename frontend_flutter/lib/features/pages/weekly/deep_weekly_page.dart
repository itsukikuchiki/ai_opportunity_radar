import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/di/app_dependencies.dart';
import '../../../core/i18n/app_locale_text.dart';
import '../../../core/i18n/energy_budget_text.dart';
import '../../../core/models/weekly_models.dart';
import '../../../core/readiness/report_readiness.dart';
import '../../../shared/widgets/aurora_ui.dart';

class WeeklyReflectPage extends StatelessWidget {
  const WeeklyReflectPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          AuroraPage(
            child: SafeArea(
              bottom: false,
              child: FutureBuilder<_WeeklyReflectLoad>(
                future: _load(context),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const _WeeklyReflectLoading();
                  }
                  final result = snapshot.data!;
                  if (!result.readiness.isReady || result.reflect == null) {
                    return _WeeklyReflectUnavailable(
                      readiness: result.readiness,
                    );
                  }
                  final deep = _localizedWeeklyReflectCopy(
                    context,
                    result.reflect!,
                  );
                  return ListView(
                    key: const ValueKey('weekly-reflect-scroll-view'),
                    padding: AuroraMainPageSpec.scrollPadding(context),
                    children: [
                      const _WeeklyReflectHero(showStatus: true),
                      const SizedBox(height: AuroraMainPageSpec.heroGap),
                      _HeroInsightCard(deep: deep),
                      const SizedBox(height: AuroraMainPageSpec.sectionGap),
                      _CoreTopicsCard(deep: deep),
                      const SizedBox(height: AuroraMainPageSpec.sectionGap),
                      _EvidenceAndEnergyGrid(deep: deep),
                      const SizedBox(height: AuroraMainPageSpec.sectionGap),
                      _PatternFlowCard(deep: deep),
                      const SizedBox(height: AuroraMainPageSpec.sectionGap),
                      _ExperimentSuggestionCard(deep: deep),
                      const SizedBox(height: AuroraMainPageSpec.sectionGap),
                      _DeepActionDesignCard(deep: deep),
                      const SizedBox(height: AuroraMainPageSpec.sectionGap),
                      _SectionCard(
                        title: AppLocaleText.tr(
                          context,
                          en: 'Use gently',
                          zhHans: '温和使用',
                          zhHant: '溫和使用',
                          ja: 'やさしく使う',
                        ),
                        body: deep.riskNote,
                        color: AuroraColors.gold,
                        icon: Icons.light_mode_rounded,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const AuroraSafeTopMask(),
        ],
      ),
    );
  }

  Future<_WeeklyReflectLoad> _load(BuildContext context) async {
    final repository = context.read<AppDependencies>().weeklyRepository;
    final weekly = await repository.fetchCurrentWeekly();
    final readiness = weekly.reportReadiness;
    if (!readiness.isReady) {
      return _WeeklyReflectLoad(readiness: readiness);
    }
    return _WeeklyReflectLoad(
      readiness: readiness,
      reflect: await repository.fetchWeeklyReflect(),
    );
  }
}

class _WeeklyReflectHero extends StatelessWidget {
  final bool showStatus;

  const _WeeklyReflectHero({required this.showStatus});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 360;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.15;
    return SizedBox(
      key: const ValueKey('weekly-reflect-hero'),
      height: largeText ? (showStatus ? 226 : 210) : 190,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: compact ? -18 : -12,
            top: compact ? -26 : -30,
            child: IgnorePointer(
              child: AuroraHeroEmblem(
                size: compact ? 116 : 142,
                opacity: 0.86,
              ),
            ),
          ),
          Positioned(
            left: -6,
            top: -4,
            child: IconButton(
              key: const ValueKey('weekly-reflect-back'),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              color: AuroraColors.ink,
            ),
          ),
          Positioned.fill(
            top: 44,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 86),
                  child: AuroraHeroTitle(
                    text: AppLocaleText.tr(
                      context,
                      en: 'Weekly Deep Review',
                      zhHans: '每周复盘深度分析',
                      zhHant: '每週復盤深度分析',
                      ja: '今週の深掘りレビュー',
                    ),
                    fontSize: compact ? 28 : 30,
                    maxLines: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(right: 78),
                  child: Text(
                    AppLocaleText.tr(
                      context,
                      en: 'A structural reading based on this week’s signals.',
                      zhHans: '基于你本周的信号，做一次更有结构的深读。',
                      zhHant: '基於你本週的信號，做一次更有結構的深讀。',
                      ja: '今週のシグナルから、構造を少し深く読み解きます。',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AuroraColors.ink.withValues(alpha: 0.70),
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
                if (showStatus) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      AuroraChip(
                        label: AppLocaleText.tr(
                          context,
                          en: 'Reflect',
                          zhHans: '深度反思',
                          zhHant: '深度反思',
                          ja: 'Reflect',
                        ),
                      ),
                      const AuroraChip(label: '3/4', color: AuroraColors.blue),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyReflectLoad {
  final ReportReadiness readiness;
  final WeeklyReflectModel? reflect;

  const _WeeklyReflectLoad({
    required this.readiness,
    this.reflect,
  });
}

WeeklyReflectModel _localizedWeeklyReflectCopy(
  BuildContext context,
  WeeklyReflectModel source,
) {
  final replacement = switch (AppLocaleText.resolve(context)) {
    AppLanguage.english => 'Deep Analysis',
    AppLanguage.simplifiedChinese => '深度分析',
    AppLanguage.traditionalChinese => '深度分析',
    AppLanguage.japanese => '詳細分析',
  };
  final tensionLabel = AppLocaleText.tr(
    context,
    en: 'tension',
    zhHans: '内在拉扯',
    zhHant: '內在拉扯',
    ja: '内的な葛藤',
  );
  final internalFieldLabels = <String, String>{
    'root_tension': AppLocaleText.tr(
      context,
      en: 'core tension',
      zhHans: '核心拉扯',
      zhHant: '核心拉扯',
      ja: '核心の葛藤',
    ),
    'hidden_pattern': AppLocaleText.tr(
      context,
      en: 'hidden pattern',
      zhHans: '隐藏模式',
      zhHant: '隱藏模式',
      ja: '隠れたパターン',
    ),
    'next_focus': AppLocaleText.tr(
      context,
      en: 'next focus',
      zhHans: '下一步关注',
      zhHant: '下一步關注',
      ja: '次の注目点',
    ),
  };

  String localize(String value) {
    var result = value
        .replaceAll(
          RegExp(r'\bPro\s*L3(?:\s*Reflect)?\b', caseSensitive: false),
          replacement,
        )
        .replaceAll(
          RegExp(r'\bL3\s*Reflect\b', caseSensitive: false),
          replacement,
        )
        .replaceAll(
          RegExp(r'\bL3\b', caseSensitive: false),
          replacement,
        );
    result = EnergyBudgetText.localizeCopy(context, result);
    for (final entry in internalFieldLabels.entries) {
      result = result.replaceAll(
        RegExp('\\b${entry.key}\\b', caseSensitive: false),
        entry.value,
      );
    }
    return result.replaceAll(
      RegExp(r'\btension\b', caseSensitive: false),
      tensionLabel,
    );
  }

  return WeeklyReflectModel(
    summary: localize(source.summary),
    rootTension: localize(source.rootTension),
    hiddenPattern: localize(source.hiddenPattern),
    nextFocus: localize(source.nextFocus),
    riskNote: localize(source.riskNote),
    keyNodes: source.keyNodes.map(localize).toList(growable: false),
  );
}

class _WeeklyReflectUnavailable extends StatelessWidget {
  final ReportReadiness readiness;

  const _WeeklyReflectUnavailable({required this.readiness});

  @override
  Widget build(BuildContext context) {
    final progressText = AppLocaleText.tr(
      context,
      en: '${readiness.signalCount} / 3 eligible signals this week',
      zhHans: '本周已记录 ${readiness.signalCount} / 3 条有效信号',
      zhHant: '本週已記錄 ${readiness.signalCount} / 3 條有效信號',
      ja: '今週の有効なシグナル ${readiness.signalCount} / 3 件',
    );
    return ListView(
      key: const ValueKey('weekly-reflect-unavailable-scroll-view'),
      padding: AuroraMainPageSpec.scrollPadding(context),
      children: [
        const _WeeklyReflectHero(showStatus: false),
        const SizedBox(height: AuroraMainPageSpec.heroGap),
        AuroraCard(
          key: const ValueKey('weekly-reflect-readiness-card'),
          padding: AuroraMainPageSpec.comfortableCardPadding,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.86),
              const Color(0xFFF3F0FF).withValues(alpha: 0.76),
              const Color(0xFFFFFAF5).withValues(alpha: 0.76),
            ],
          ),
          child: Column(
            children: [
              const AuroraSoftIconCircle(
                icon: Icons.auto_graph_rounded,
                color: AuroraColors.purple,
                size: 72,
              ),
              const SizedBox(height: 16),
              Text(
                AppLocaleText.tr(
                  context,
                  en: 'The weekly report is still forming',
                  zhHans: '本周报告还在形成',
                  zhHant: '本週報告還在形成',
                  ja: '今週のレポートはまだ形成中です',
                ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AuroraColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocaleText.tr(
                  context,
                  en: 'Weekly review and its same-week Deep Analysis start after 3 eligible Signal Cards in the current local Monday-Sunday week. Cross-period Deep Analysis uses the separate 28-day Pro threshold.',
                  zhHans:
                      '当前本地周一至周日达到 3 条有效 Signal Card 后，每周复盘和本周深度分析才开始显示。跨周期深度分析使用独立的 28 天 Pro 门槛。',
                  zhHant:
                      '當前本地週一至週日達到 3 條有效 Signal Card 後，每週復盤和本週深度分析才開始顯示。跨週期深度分析使用獨立的 28 天 Pro 門檻。',
                  ja: '現在のローカル月曜〜日曜で有効な Signal Card が 3 件になると、週間レビューと今週の詳細分析を表示します。期間比較の詳細分析には別の 28 日 Pro 条件を使います。',
                ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AuroraColors.muted,
                      height: 1.45,
                    ),
              ),
              const SizedBox(height: 14),
              Text(
                progressText,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AuroraColors.purple,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Semantics(
                label: progressText,
                value: '${(readiness.progress * 100).round()}%',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: readiness.progress,
                    minHeight: 8,
                    color: AuroraColors.purple,
                    backgroundColor:
                        AuroraColors.purple.withValues(alpha: 0.12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeeklyReflectLoading extends StatelessWidget {
  const _WeeklyReflectLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AuroraMainPageSpec.scrollPadding(context),
      children: [
        const _WeeklyReflectHero(showStatus: false),
        const SizedBox(height: AuroraMainPageSpec.heroGap),
        AuroraCard(
          padding: AuroraMainPageSpec.comfortableCardPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AuroraSoftIconCircle(
                icon: Icons.auto_graph_rounded,
                color: AuroraColors.purple,
                size: 76,
              ),
              const SizedBox(height: 18),
              Text(
                AppLocaleText.tr(
                  context,
                  en: 'Reading this week one layer deeper...',
                  zhHans: '正在把这一周再往深一层看...',
                  zhHant: '正在把這一週再往深一層看...',
                  ja: '今週をもう一段深く見ています...',
                ),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AuroraColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroInsightCard extends StatelessWidget {
  final WeeklyReflectModel deep;

  const _HeroInsightCard({required this.deep});

  @override
  Widget build(BuildContext context) {
    return AuroraCard(
      key: const ValueKey('weekly-reflect-insight-card'),
      padding: const EdgeInsets.all(18),
      gradient: const LinearGradient(
        colors: [Color(0xFFFFFFFF), Color(0xFFF2F0FF), Color(0xFFFFFBF4)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AuroraLandscapeMedallion(size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AuroraChip(
                    label: AppLocaleText.tr(
                      context,
                      en: 'This week’s core insight',
                      zhHans: '本周核心洞察',
                      zhHant: '本週核心洞察',
                      ja: '今週の中心',
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            deep.summary,
            key: const ValueKey('weekly-reflect-summary'),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AuroraColors.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final stackInsights = constraints.maxWidth < 560;
              final friction = _MiniInsight(
                key: const ValueKey('weekly-reflect-mini-insight-friction'),
                icon: Icons.bolt_rounded,
                label: AppLocaleText.tr(context,
                    en: 'Friction', zhHans: '摩擦源', zhHant: '摩擦源', ja: '摩擦'),
                value: deep.rootTension,
                color: AuroraColors.orange,
              );
              final direction = _MiniInsight(
                key: const ValueKey('weekly-reflect-mini-insight-direction'),
                icon: Icons.trending_up_rounded,
                label: AppLocaleText.tr(context,
                    en: 'Direction', zhHans: '能量方向', zhHant: '能量方向', ja: '方向'),
                value: deep.nextFocus,
                color: AuroraColors.mint,
              );
              if (stackInsights) {
                return Column(
                  children: [
                    friction,
                    const SizedBox(height: 8),
                    direction,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: friction),
                  const SizedBox(width: 8),
                  Expanded(child: direction),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MiniInsight extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MiniInsight({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          AuroraSoftIconCircle(
              icon: icon, color: color, size: 32, iconSize: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelSmall),
                Text(
                  value,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AuroraColors.ink,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CoreTopicsCard extends StatelessWidget {
  final WeeklyReflectModel deep;

  const _CoreTopicsCard({required this.deep});

  @override
  Widget build(BuildContext context) {
    final topics = [
      (
        Icons.favorite_border_rounded,
        deep.rootTension,
        '32%',
        AuroraColors.purple
      ),
      (
        Icons.battery_charging_full_rounded,
        deep.hiddenPattern,
        '26%',
        AuroraColors.orange
      ),
      (Icons.science_rounded, deep.nextFocus, '19%', AuroraColors.blue),
      (
        Icons.spa_rounded,
        AppLocaleText.tr(context,
            en: 'Growth and trying',
            zhHans: '成长与尝试',
            zhHant: '成長與嘗試',
            ja: '成長と試み'),
        '8%',
        AuroraColors.gold
      ),
    ];
    return AuroraCard(
      padding: AuroraMainPageSpec.comfortableCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AuroraSectionIcon(
                icon: Icons.hub_rounded,
                size: 30,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  AppLocaleText.tr(context,
                      en: 'Core topics',
                      zhHans: '核心主题',
                      zhHant: '核心主題',
                      ja: '中心テーマ'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AuroraColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final tiles = topics.indexed
                  .map(
                    (entry) => _CoreTopicTile(
                      key: ValueKey('weekly-reflect-core-topic-${entry.$1}'),
                      icon: entry.$2.$1,
                      body: entry.$2.$2,
                      percentage: entry.$2.$3,
                      color: entry.$2.$4,
                    ),
                  )
                  .toList(growable: false);
              if (constraints.maxWidth < 560) {
                return Column(
                  children: [
                    for (var index = 0; index < tiles.length; index++) ...[
                      tiles[index],
                      if (index < tiles.length - 1) const SizedBox(height: 10),
                    ],
                  ],
                );
              }
              final tileWidth = (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: tiles
                    .map((tile) => SizedBox(width: tileWidth, child: tile))
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CoreTopicTile extends StatelessWidget {
  final IconData icon;
  final String body;
  final String percentage;
  final Color color;

  const _CoreTopicTile({
    super.key,
    required this.icon,
    required this.body,
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuroraSoftIconCircle(
            icon: icon,
            color: color,
            size: 34,
            iconSize: 17,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              body,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AuroraColors.ink,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
            ),
          ),
          const SizedBox(width: 10),
          AuroraChip(label: percentage, color: color),
        ],
      ),
    );
  }
}

class _EvidenceAndEnergyGrid extends StatelessWidget {
  final WeeklyReflectModel deep;

  const _EvidenceAndEnergyGrid({required this.deep});

  @override
  Widget build(BuildContext context) {
    final evidence = _SectionCard(
      title: AppLocaleText.tr(context,
          en: 'Evidence gathered',
          zhHans: '证据聚集',
          zhHant: '證據聚集',
          ja: '集まった証拠'),
      body: deep.keyNodes.isEmpty
          ? AppLocaleText.tr(context,
              en: 'Signals are still forming.',
              zhHans: '信号还在形成中。',
              zhHant: '信號還在形成中。',
              ja: 'シグナルはまだ形成中です。')
          : deep.keyNodes.take(4).join('\n'),
      color: AuroraColors.mint,
      icon: Icons.fact_check_rounded,
    );
    final energy = AuroraCard(
      padding: const EdgeInsets.all(16),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.86),
          AuroraColors.mint.withValues(alpha: 0.08),
          AuroraColors.purple.withValues(alpha: 0.07),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AuroraSectionIcon(
                icon: Icons.battery_charging_full_rounded,
                color: AuroraColors.mint,
                size: 30,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  AppLocaleText.tr(context,
                      en: 'Energy structure',
                      zhHans: '能量与摩擦结构',
                      zhHant: '能量與摩擦結構',
                      ja: 'エネルギー構造'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AuroraColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 108,
            height: 108,
            child: CustomPaint(painter: _DonutPainter()),
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 430) {
          return Column(
            children: [
              evidence,
              const SizedBox(height: AuroraMainPageSpec.sectionGap),
              energy,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: evidence),
            const SizedBox(width: 12),
            Expanded(child: energy),
          ],
        );
      },
    );
  }
}

class _PatternFlowCard extends StatelessWidget {
  final WeeklyReflectModel deep;

  const _PatternFlowCard({required this.deep});

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        Icons.chat_bubble_outline_rounded,
        AppLocaleText.tr(context,
            en: 'Trigger', zhHans: '触发点', zhHant: '觸發點', ja: 'きっかけ')
      ),
      (
        Icons.flash_on_rounded,
        AppLocaleText.tr(context,
            en: 'Reaction', zhHans: '典型反应', zhHant: '典型反應', ja: '反応')
      ),
      (
        Icons.track_changes_rounded,
        AppLocaleText.tr(context,
            en: 'Short result', zhHans: '短期结果', zhHant: '短期結果', ja: '短期結果')
      ),
      (
        Icons.spa_rounded,
        AppLocaleText.tr(context,
            en: 'Long impact', zhHans: '长期影响', zhHant: '長期影響', ja: '長期影響')
      ),
    ];
    return AuroraCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AuroraSectionIcon(
                icon: Icons.account_tree_rounded,
                size: 30,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  AppLocaleText.tr(context,
                      en: 'This week’s pattern breakdown',
                      zhHans: '本周模式拆解',
                      zhHant: '本週模式拆解',
                      ja: '今週のパターン分解'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AuroraColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final tileWidth = compact
                  ? (constraints.maxWidth - 8) / 2
                  : (constraints.maxWidth - 24) / 4;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < items.length; i++)
                    SizedBox(
                      width: tileWidth,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 92),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.78),
                              (i.isEven
                                      ? AuroraColors.purple
                                      : AuroraColors.orange)
                                  .withValues(alpha: 0.08),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: (i.isEven
                                    ? AuroraColors.purple
                                    : AuroraColors.orange)
                                .withValues(alpha: 0.12),
                          ),
                        ),
                        child: Row(
                          children: [
                            AuroraSoftIconCircle(
                              icon: items[i].$1,
                              color: i.isEven
                                  ? AuroraColors.purple
                                  : AuroraColors.orange,
                              size: 34,
                              iconSize: 17,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                items[i].$2,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(
                                      color: AuroraColors.ink,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ExperimentSuggestionCard extends StatelessWidget {
  final WeeklyReflectModel deep;

  const _ExperimentSuggestionCard({required this.deep});

  @override
  Widget build(BuildContext context) {
    return AuroraCard(
      padding: AuroraMainPageSpec.comfortableCardPadding,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.88),
          const Color(0xFFF8F3FF).withValues(alpha: 0.82),
          const Color(0xFFFFF8F0).withValues(alpha: 0.78),
        ],
      ),
      child: Row(
        children: [
          const AuroraSectionIcon(
            icon: Icons.science_rounded,
            size: 42,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocaleText.tr(context,
                      en: 'Suggested small experiment',
                      zhHans: '建议的小实验',
                      zhHant: '建議的小實驗',
                      ja: 'おすすめの小さな実験'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AuroraColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  deep.nextFocus,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AuroraColors.ink,
                        height: 1.4,
                      ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AuroraColors.muted),
        ],
      ),
    );
  }
}

class _DeepActionDesignCard extends StatelessWidget {
  final WeeklyReflectModel deep;

  const _DeepActionDesignCard({required this.deep});

  @override
  Widget build(BuildContext context) {
    final strategy = deep.rootTension.trim().isEmpty
        ? AppLocaleText.tr(
            context,
            en: 'Look at the repeated loop before changing too much at once.',
            zhHans: '先看反复出现的循环，不急着一次改太多。',
            zhHant: '先看反覆出現的循環，不急著一次改太多。',
            ja: '一度に変えすぎる前に、繰り返している循環を見ます。',
          )
        : deep.rootTension.trim();
    final design = deep.nextFocus.trim().isEmpty
        ? AppLocaleText.tr(
            context,
            en: 'Try one small adjustment next week and keep feedback light.',
            zhHans: '下周只试一个小调整，反馈保持轻一点。',
            zhHant: '下週只試一個小調整，回饋保持輕一點。',
            ja: '来週は小さな調整を一つだけ試し、反応は軽く残します。',
          )
        : deep.nextFocus.trim();

    return AuroraCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      gradient: LinearGradient(
        colors: [
          AuroraColors.purple.withValues(alpha: 0.10),
          Colors.white.withValues(alpha: 0.94),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AuroraSectionIcon(
                icon: Icons.architecture_rounded,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Deep action design',
                    zhHans: '深度行动设计',
                    zhHant: '深度行動設計',
                    ja: '深い行動デザイン',
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AuroraColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _DeepDesignRow(
            label: 'Strategy',
            title: AppLocaleText.tr(
              context,
              en: 'Why this first',
              zhHans: '为什么先做',
              zhHant: '為什麼先做',
              ja: 'なぜ先に見るか',
            ),
            body: strategy,
            icon: Icons.track_changes_rounded,
            color: AuroraColors.mint,
          ),
          const SizedBox(height: 10),
          _DeepDesignRow(
            label: 'Design',
            title: AppLocaleText.tr(
              context,
              en: 'Next small try',
              zhHans: '下周试试',
              zhHant: '下週試試',
              ja: '次の小さな試み',
            ),
            body: design,
            icon: Icons.edit_rounded,
            color: AuroraColors.orange,
          ),
          const SizedBox(height: 10),
          _DeepDesignRow(
            label: 'Development',
            title: AppLocaleText.tr(
              context,
              en: 'Review signal',
              zhHans: '复盘指标',
              zhHant: '復盤指標',
              ja: 'ふり返りの目印',
            ),
            body: AppLocaleText.tr(
              context,
              en: 'Notice whether evening fatigue softens, recovery starts sooner, or the design needs to be lighter.',
              zhHans: '观察晚间疲惫是否下降、恢复是否更容易开始，或这个设计是否需要调轻。',
              zhHant: '觀察晚間疲憊是否下降、恢復是否更容易開始，或這個設計是否需要調輕。',
              ja: '夜の疲れがやわらぐか、回復が始まりやすくなるか、設計を軽くする必要があるかを見ます。',
            ),
            icon: Icons.insights_rounded,
            color: AuroraColors.blue,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DeepConfirmChip(
                label: AppLocaleText.tr(
                  context,
                  en: 'Looks right',
                  zhHans: '准',
                  zhHant: '準',
                  ja: '合っている',
                ),
              ),
              _DeepConfirmChip(
                label: AppLocaleText.tr(
                  context,
                  en: 'Partly',
                  zhHans: '有一部分准',
                  zhHant: '有一部分準',
                  ja: '一部合っている',
                ),
              ),
              _DeepConfirmChip(
                label: AppLocaleText.tr(
                  context,
                  en: 'Another angle',
                  zhHans: '换个角度',
                  zhHant: '換個角度',
                  ja: '別の角度',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeepDesignRow extends StatelessWidget {
  final String label;
  final String title;
  final String body;
  final IconData icon;
  final Color color;

  const _DeepDesignRow({
    required this.label,
    required this.title,
    required this.body,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.13)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuroraSoftIconCircle(
              icon: icon, color: color, size: 34, iconSize: 18),
          const SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AuroraColors.ink,
                      height: 1.42,
                    ),
                children: [
                  TextSpan(
                    text: '$title：',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: body),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeepConfirmChip extends StatelessWidget {
  final String label;

  const _DeepConfirmChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      avatar: const Icon(Icons.check_circle_outline_rounded, size: 18),
      backgroundColor: Colors.white.withValues(alpha: 0.80),
      side: BorderSide(color: AuroraColors.purple.withValues(alpha: 0.18)),
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocaleText.tr(
                context,
                en: 'Saved as a review signal.',
                zhHans: '已记录为下次复盘的参考。',
                zhHant: '已記錄為下次復盤的參考。',
                ja: '次のふり返りの参考として残しました。',
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DonutPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = size.width * 0.16;
    final colors = [
      AuroraColors.purple,
      AuroraColors.mint,
      AuroraColors.gold,
      AuroraColors.orange,
    ];
    var start = -1.57;
    for (final color in colors) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.70);
      canvas.drawArc(rect.deflate(stroke), start, 1.15, false, paint);
      start += 1.35;
    }
    final textPainter = TextPainter(
      text: const TextSpan(
        text: '+18%',
        style: TextStyle(
          color: AuroraColors.mint,
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String body;
  final Color color;
  final IconData icon;

  const _SectionCard({
    required this.title,
    required this.body,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return AuroraCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuroraSectionIcon(icon: icon, color: color, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AuroraColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AuroraColors.ink,
                        height: 1.45,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
