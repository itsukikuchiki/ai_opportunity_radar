import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/i18n/app_locale_text.dart';
import '../../../core/models/journey_pro_models.dart';
import '../../../core/models/memory_models.dart';
import '../../../core/readiness/report_readiness.dart';
import '../../../shared/states/load_state.dart';
import '../../../shared/widgets/aurora_ui.dart';
import '../../../shared/widgets/empty_state_block.dart';
import 'journey_display_text.dart';
import 'memory_view_model.dart';

class JourneyProPage extends StatefulWidget {
  const JourneyProPage({super.key});

  @override
  State<JourneyProPage> createState() => _JourneyProPageState();
}

class _JourneyProPageState extends State<JourneyProPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (mounted) context.read<MemoryViewModel>().loadProReport();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MemoryViewModel>();
    return Scaffold(
      body: Stack(
        children: [
          AuroraPage(
            child: SafeArea(
              bottom: false,
              child: ListView(
                key: const ValueKey('journey-pro-scroll-view'),
                padding: AuroraMainPageSpec.scrollPadding(context),
                children: [
                  _ProHeader(onBack: () => _goBack(context)),
                  const SizedBox(height: AuroraMainPageSpec.heroGap),
                  _ProHero(readiness: vm.proReport?.readiness),
                  const SizedBox(height: AuroraMainPageSpec.sectionGap),
                  ..._body(context, vm),
                ],
              ),
            ),
          ),
          const AuroraSafeTopMask(extraHeight: 4),
        ],
      ),
    );
  }

  List<Widget> _body(BuildContext context, MemoryViewModel vm) {
    switch (vm.proReportLoadState) {
      case LoadState.initial:
      case LoadState.loading:
        return const [
          SizedBox(height: 80),
          Center(child: CircularProgressIndicator()),
        ];
      case LoadState.error:
        return [
          EmptyStateBlock(
            icon: Icons.error_outline_rounded,
            title: AppLocaleText.tr(
              context,
              en: 'Pro report failed to load',
              zhHans: 'Pro 报告加载失败',
              zhHant: 'Pro 報告載入失敗',
              ja: 'Pro レポートを読み込めませんでした',
            ),
            subtitle: vm.proReportErrorMessage ??
                AppLocaleText.tr(
                  context,
                  en: 'Your local Journey data was not changed.',
                  zhHans: '你的本地旅程数据没有被修改。',
                  zhHant: '你的本地 Journey 資料沒有被修改。',
                  ja: 'ローカルの Journey データは変更されていません。',
                ),
          ),
          const SizedBox(height: AuroraMainPageSpec.sectionGap),
          SizedBox(
            height: 44,
            child: AuroraPillButton(
              label: AppLocaleText.tr(
                context,
                en: 'Try again',
                zhHans: '重新加载',
                zhHant: '重新載入',
                ja: '再読み込み',
              ),
              icon: Icons.refresh_rounded,
              onPressed: vm.loadProReport,
            ),
          ),
        ];
      case LoadState.empty:
        final report = vm.proReport;
        return [
          if (report != null) _ProReadinessCard(report: report),
          const SizedBox(height: AuroraMainPageSpec.sectionGap),
          _BoundaryCard(
            text: AppLocaleText.tr(
              context,
              en: 'L3 content is not generated before every requirement is met. Journey Free still keeps your timeline, calendar, curve, and evidence available.',
              zhHans: '所有条件同时达到前，不生成深度分析综合或周期结论。旅程免费层的时间线、日历、曲线和证据仍可正常查看。',
              zhHant:
                  '所有條件同時達到前，不生成 L3 綜合或週期結論。Journey 免費層的時間線、日曆、曲線和證據仍可正常查看。',
              ja: 'すべての条件を満たす前に L3 の統合や期間結論は生成しません。Journey Free のタイムライン、カレンダー、曲線、根拠は引き続き利用できます。',
            ),
          ),
        ];
      case LoadState.ready:
        final report = vm.proReport;
        if (report == null) return const [SizedBox.shrink()];
        return [
          _ProReadinessCard(report: report),
          const SizedBox(height: AuroraMainPageSpec.sectionGap),
          _L3SynthesisCard(report: report, summary: vm.summary),
          const SizedBox(height: AuroraMainPageSpec.sectionGap),
          _PeriodComparisonCard(report: report),
          const SizedBox(height: AuroraMainPageSpec.sectionGap),
          _ProEvidenceCard(report: report),
          const SizedBox(height: AuroraMainPageSpec.sectionGap),
          _FollowupCard(report: report),
        ];
    }
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.memory);
    }
  }
}

class _ProHeader extends StatelessWidget {
  final VoidCallback onBack;

  const _ProHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AuroraIconButton(
          icon: Icons.arrow_back_rounded,
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: onBack,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            AppLocaleText.tr(
              context,
              en: 'Journey Pro L3',
              zhHans: '旅程 Pro 深度分析',
              zhHant: 'Journey Pro L3',
              ja: 'Journey Pro L3',
            ),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AuroraColors.ink,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }
}

class _ProHero extends StatelessWidget {
  final ReportReadiness? readiness;

  const _ProHero({required this.readiness});

  @override
  Widget build(BuildContext context) {
    final isReady = readiness?.isReady == true;
    final compact =
        MediaQuery.sizeOf(context).width < AuroraMainPageSpec.compactBreakpoint;
    return ConstrainedBox(
      key: const ValueKey('journey-pro-hero'),
      constraints: const BoxConstraints(minHeight: 144),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: compact ? -18 : -12,
            top: compact ? -26 : -32,
            child: IgnorePointer(
              child: AuroraHeroEmblem(
                size: compact ? 116 : 140,
                opacity: 0.80,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 4, 2, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(right: compact ? 76 : 98),
                  child: AuroraHeroTitle(
                    text: AppLocaleText.tr(
                      context,
                      en: isReady
                          ? 'Cross-period review'
                          : 'Cross-period review is forming',
                      zhHans: isReady ? '跨周期深度回看' : '跨周期报告正在形成',
                      zhHant: isReady ? '跨週期深度回看' : '跨週期報告正在形成',
                      ja: isReady ? '期間をまたぐ振り返り' : '期間比較を準備中',
                    ),
                    fontSize: compact ? 29 : 32,
                    maxLines: 2,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: EdgeInsets.only(right: compact ? 58 : 82),
                  child: Text(
                    AppLocaleText.tr(
                      context,
                      en: 'Latest 28 local dates · Monday-Sunday week buckets',
                      zhHans: '最新 28 个本地日期 · 周一至周日自然周',
                      zhHant: '最新 28 個本地日期 · 週一至週日自然週',
                      ja: '直近 28 ローカル日 · 月曜〜日曜の週区切り',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AuroraColors.ink.withValues(alpha: 0.74),
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
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

class _ProReadinessCard extends StatelessWidget {
  final JourneyProReportModel report;

  const _ProReadinessCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final readiness = report.readiness;
    final detail = AppLocaleText.tr(
      context,
      en: '${readiness.signalCount}/14 eligible SignalCards · ${readiness.distinctDayCount}/7 recorded days · ${readiness.distinctWeekCount}/2 local weeks',
      zhHans:
          '${readiness.signalCount}/14 条有效 Signal Card · ${readiness.distinctDayCount}/7 个记录日 · ${readiness.distinctWeekCount}/2 个本地自然周',
      zhHant:
          '${readiness.signalCount}/14 條有效 SignalCard · ${readiness.distinctDayCount}/7 個記錄日 · ${readiness.distinctWeekCount}/2 個本地自然週',
      ja: '有効 SignalCard ${readiness.signalCount}/14 件 · 記録日 ${readiness.distinctDayCount}/7 日 · ローカル週 ${readiness.distinctWeekCount}/2 週',
    );
    return AuroraCard(
      key: const ValueKey('journey-pro-l3-readiness'),
      padding: AuroraMainPageSpec.comfortableCardPadding,
      borderRadius: BorderRadius.circular(AuroraMainPageSpec.cardRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const AuroraSoftIconCircle(
                icon: Icons.query_stats_rounded,
                color: AuroraColors.gold,
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: report.isReady ? 'Evidence ready' : 'Evidence progress',
                    zhHans: report.isReady ? '证据门槛已达到' : '证据积累进度',
                    zhHant: report.isReady ? '證據門檻已達到' : '證據累積進度',
                    ja: report.isReady ? '根拠がそろいました' : '根拠の進捗',
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AuroraColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              if (report.isReady)
                const Icon(Icons.check_circle_rounded,
                    color: AuroraColors.mint),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            detail,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AuroraColors.muted,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 10),
          Semantics(
            label: detail,
            value: '${(readiness.progress * 100).round()}%',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: readiness.progress,
                minHeight: 8,
                color: AuroraColors.gold,
                backgroundColor: AuroraColors.gold.withValues(alpha: 0.14),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${report.periodStart} — ${report.periodEnd}',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AuroraColors.muted,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _L3SynthesisCard extends StatelessWidget {
  final JourneyProReportModel report;
  final MemorySummaryModel? summary;

  const _L3SynthesisCard({required this.report, required this.summary});

  @override
  Widget build(BuildContext context) {
    final items = _summaryItems(summary);
    return _ProSectionCard(
      key: const ValueKey('journey-pro-l3-synthesis'),
      icon: Icons.hub_rounded,
      color: AuroraColors.purple,
      title: AppLocaleText.tr(
        context,
        en: 'L3 evidence synthesis',
        zhHans: '深度分析证据综合',
        zhHant: 'L3 證據綜合',
        ja: 'L3 根拠の統合',
      ),
      children: [
        Text(
          AppLocaleText.tr(
            context,
            en: 'The verified 28-day window contains ${report.readiness.signalCount} eligible SignalCards across ${report.readiness.distinctDayCount} local days and ${report.readiness.distinctWeekCount} Monday-Sunday weeks.',
            zhHans:
                '可验证的 28 日窗口内共有 ${report.readiness.signalCount} 条有效 Signal Card，覆盖 ${report.readiness.distinctDayCount} 个本地记录日和 ${report.readiness.distinctWeekCount} 个周一至周日自然周。',
            zhHant:
                '可驗證的 28 日窗口內共有 ${report.readiness.signalCount} 條有效 SignalCard，覆蓋 ${report.readiness.distinctDayCount} 個本地記錄日和 ${report.readiness.distinctWeekCount} 個週一至週日自然週。',
            ja: '検証可能な 28 日間に、有効 SignalCard ${report.readiness.signalCount} 件、ローカル記録日 ${report.readiness.distinctDayCount} 日、月曜〜日曜の週 ${report.readiness.distinctWeekCount} 週があります。',
          ),
          style: _bodyStyle(context),
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            AppLocaleText.tr(
              context,
              en: 'Available Journey synthesis',
              zhHans: '已有旅程综合',
              zhHant: '已有 Journey 綜合',
              ja: '利用可能な Journey 統合',
            ),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AuroraColors.purple,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SummaryRow(item: item),
            ),
        ] else ...[
          const SizedBox(height: 10),
          _BoundaryCard(
            text: AppLocaleText.tr(
              context,
              en: 'No interpretive Journey summary is cached for the current month, so this page shows verified statistics and source evidence only.',
              zhHans: '本月尚无已生成的解释性旅程综合，因此这里只展示可验证统计和来源证据。',
              zhHant: '本月尚無已生成的解釋性 Journey 綜合，因此這裡只展示可驗證統計和來源證據。',
              ja: '今月の解釈的な Journey 統合はまだ保存されていないため、検証可能な統計と出典のみを表示します。',
            ),
          ),
        ],
      ],
    );
  }

  List<_SummaryItem> _summaryItems(MemorySummaryModel? summary) {
    if (summary == null) return const [];
    return [
      ...summary.patterns.map((item) => _SummaryItem('Pattern', item)),
      ...summary.frictions.map((item) => _SummaryItem('Friction', item)),
      ...summary.desires.map((item) => _SummaryItem('Recovery', item)),
      ...summary.experiments.map((item) => _SummaryItem('Experiment', item)),
    ].take(4).toList(growable: false);
  }
}

class _SummaryItem {
  final String label;
  final JourneySignalItemModel item;

  const _SummaryItem(this.label, this.item);
}

class _SummaryRow extends StatelessWidget {
  final _SummaryItem item;

  const _SummaryRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AuroraColors.purple.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _label(context),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AuroraColors.purple,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 3),
          Text(
            localizeJourneyDisplayText(context, item.item.name),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AuroraColors.ink,
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (item.item.summary.trim().isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              localizeJourneyDisplayText(context, item.item.summary),
              style: _bodyStyle(context),
            ),
          ],
        ],
      ),
    );
  }

  String _label(BuildContext context) {
    switch (item.label) {
      case 'Pattern':
        return AppLocaleText.tr(
          context,
          en: 'Pattern',
          zhHans: '模式',
          zhHant: '模式',
          ja: 'パターン',
        );
      case 'Friction':
        return AppLocaleText.tr(
          context,
          en: 'Friction',
          zhHans: '摩擦',
          zhHant: '摩擦',
          ja: '摩擦',
        );
      case 'Recovery':
        return AppLocaleText.tr(
          context,
          en: 'Recovery',
          zhHans: '恢复',
          zhHant: '恢復',
          ja: '回復',
        );
      default:
        return AppLocaleText.tr(
          context,
          en: 'Experiment',
          zhHans: '小实验',
          zhHant: '小實驗',
          ja: '小さな実験',
        );
    }
  }
}

class _PeriodComparisonCard extends StatelessWidget {
  final JourneyProReportModel report;

  const _PeriodComparisonCard({required this.report});

  @override
  Widget build(BuildContext context) {
    return _ProSectionCard(
      key: const ValueKey('journey-pro-period-comparison'),
      icon: Icons.compare_arrows_rounded,
      color: AuroraColors.blue,
      title: AppLocaleText.tr(
        context,
        en: 'Monday-Sunday period comparison',
        zhHans: '周一至周日周期对比',
        zhHant: '週一至週日週期對比',
        ja: '月曜〜日曜の期間比較',
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: _WeekStatTile(
                label: AppLocaleText.tr(
                  context,
                  en: 'Previous week',
                  zhHans: '上一自然周',
                  zhHant: '上一自然週',
                  ja: '前の週',
                ),
                stats: report.previousWeek,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _WeekStatTile(
                label: AppLocaleText.tr(
                  context,
                  en: 'Current week to date',
                  zhHans: '本周截至今天',
                  zhHant: '本週截至今天',
                  ja: '今週（今日まで）',
                ),
                stats: report.currentWeek,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AuroraChip(
              label: AppLocaleText.tr(
                context,
                en: 'Signals ${_signed(report.weekSignalDelta)}',
                zhHans: '信号 ${_signed(report.weekSignalDelta)}',
                zhHant: '信號 ${_signed(report.weekSignalDelta)}',
                ja: 'シグナル ${_signed(report.weekSignalDelta)}',
              ),
              color: AuroraColors.blue,
            ),
            AuroraChip(
              label: AppLocaleText.tr(
                context,
                en: 'Recorded days ${_signed(report.weekActiveDayDelta)}',
                zhHans: '记录日 ${_signed(report.weekActiveDayDelta)}',
                zhHant: '記錄日 ${_signed(report.weekActiveDayDelta)}',
                ja: '記録日 ${_signed(report.weekActiveDayDelta)}',
              ),
              color: AuroraColors.mint,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          AppLocaleText.tr(
            context,
            en: 'Counts are factual. This comparison does not label an increase or decrease as better or worse.',
            zhHans: '这里只比较事实数量，不把增加或减少判断为更好或更差。',
            zhHant: '這裡只比較事實數量，不把增加或減少判斷為更好或更差。',
            ja: 'ここでは事実の件数だけを比較し、増減を良し悪しとして評価しません。',
          ),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AuroraColors.muted,
                height: 1.4,
              ),
        ),
      ],
    );
  }

  String _signed(int value) => value > 0 ? '+$value' : '$value';
}

class _WeekStatTile extends StatelessWidget {
  final String label;
  final JourneyProWeekStats stats;

  const _WeekStatTile({required this.label, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AuroraColors.blue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AuroraColors.blue.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AuroraColors.blue,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            AppLocaleText.tr(
              context,
              en: '${stats.signalCount} signals',
              zhHans: '${stats.signalCount} 条信号',
              zhHant: '${stats.signalCount} 條信號',
              ja: '${stats.signalCount} 件',
            ),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AuroraColors.ink,
                  fontWeight: FontWeight.w700,
                ),
          ),
          Text(
            AppLocaleText.tr(
              context,
              en: '${stats.activeDayCount} recorded days',
              zhHans: '${stats.activeDayCount} 个记录日',
              zhHant: '${stats.activeDayCount} 個記錄日',
              ja: '${stats.activeDayCount} 記録日',
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AuroraColors.muted,
                ),
          ),
          const SizedBox(height: 5),
          Text(
            '${stats.weekStart}\n${stats.weekEnd}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AuroraColors.muted,
                  height: 1.35,
                ),
          ),
        ],
      ),
    );
  }
}

class _ProEvidenceCard extends StatelessWidget {
  final JourneyProReportModel report;

  const _ProEvidenceCard({required this.report});

  @override
  Widget build(BuildContext context) {
    return _ProSectionCard(
      key: const ValueKey('journey-pro-evidence'),
      icon: Icons.fact_check_outlined,
      color: AuroraColors.mint,
      title: AppLocaleText.tr(
        context,
        en: 'Source evidence',
        zhHans: '来源证据',
        zhHant: '來源證據',
        ja: '出典となる根拠',
      ),
      children: [
        for (var index = 0; index < report.evidence.length; index++) ...[
          _EvidenceRow(evidence: report.evidence[index]),
          if (index < report.evidence.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _EvidenceRow extends StatelessWidget {
  final JourneyProEvidenceModel evidence;

  const _EvidenceRow({required this.evidence});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AuroraColors.mint.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  evidence.localDate,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AuroraColors.mint,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              AuroraChip(
                label: journeySourceTypeLabel(context, evidence.sourceType),
                color: AuroraColors.mint,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            localizeJourneyDisplayText(context, evidence.content),
            style: _bodyStyle(context),
          ),
          const SizedBox(height: 5),
          SizedBox(
            height: 44,
            child: TextButton.icon(
              onPressed: () => context.push(
                '${AppRoutes.todayDialog}/${Uri.encodeComponent(evidence.signalId)}',
              ),
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
              label: Text(
                AppLocaleText.tr(
                  context,
                  en: 'Ask from this evidence',
                  zhHans: '围绕这条证据追问',
                  zhHant: '圍繞這條證據追問',
                  ja: 'この根拠から質問する',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FollowupCard extends StatelessWidget {
  final JourneyProReportModel report;

  const _FollowupCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final evidence = report.evidence.isEmpty ? null : report.evidence.first;
    return _ProSectionCard(
      key: const ValueKey('journey-pro-followup'),
      icon: Icons.chat_bubble_outline_rounded,
      color: AuroraColors.orange,
      title: AppLocaleText.tr(
        context,
        en: 'Follow up with evidence',
        zhHans: '带着证据继续追问',
        zhHant: '帶著證據繼續追問',
        ja: '根拠からさらに質問',
      ),
      children: [
        Text(
          AppLocaleText.tr(
            context,
            en: 'The conversation opens from an actual SignalCard, so the question keeps a traceable source.',
            zhHans: '对话会从真实 Signal Card 打开，让追问始终保留可追溯来源。',
            zhHant: '對話會從真實 SignalCard 打開，讓追問始終保留可追溯來源。',
            ja: '実際の SignalCard から会話を開くため、質問の出典を追跡できます。',
          ),
          style: _bodyStyle(context),
        ),
        if (evidence != null) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: AuroraPillButton(
              label: AppLocaleText.tr(
                context,
                en: 'Start evidence follow-up',
                zhHans: '开始证据追问',
                zhHant: '開始證據追問',
                ja: '根拠から質問する',
              ),
              icon: Icons.arrow_forward_rounded,
              filled: true,
              onPressed: () => context.push(
                '${AppRoutes.todayDialog}/${Uri.encodeComponent(evidence.signalId)}',
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ProSectionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final List<Widget> children;

  const _ProSectionCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return AuroraCard(
      padding: AuroraMainPageSpec.comfortableCardPadding,
      borderRadius: BorderRadius.circular(AuroraMainPageSpec.cardRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AuroraSoftIconCircle(icon: icon, color: color, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AuroraColors.ink,
                        fontSize: AuroraMainPageSpec.sectionTitleSize,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _BoundaryCard extends StatelessWidget {
  final String text;

  const _BoundaryCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AuroraColors.gold.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AuroraColors.gold.withValues(alpha: 0.18)),
      ),
      child: Text(text, style: _bodyStyle(context)),
    );
  }
}

TextStyle? _bodyStyle(BuildContext context) {
  return Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: AuroraColors.muted,
        fontSize: AuroraMainPageSpec.bodySize,
        height: 1.45,
        fontWeight: FontWeight.w600,
      );
}
