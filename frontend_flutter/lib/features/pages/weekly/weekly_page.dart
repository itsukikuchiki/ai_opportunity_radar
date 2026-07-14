// ignore_for_file: unused_element

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/i18n/app_locale_text.dart';
import '../../../core/models/candidate_models.dart';
import '../../../core/models/energy_budget_models.dart';
import '../../../core/models/weekly_models.dart';
import '../../../core/preferences/focus_domains.dart';
import '../../../core/readiness/report_readiness.dart';
import '../../../shared/states/load_state.dart';
import '../../../shared/widgets/aurora_ui.dart';
import '../../../shared/widgets/empty_state_block.dart';
import '../../../shared/widgets/signal_illustration_kit.dart';
import '../../paywall/paywall_sheet.dart';
import 'weekly_view_model.dart';

class WeeklyPage extends StatelessWidget {
  const WeeklyPage({super.key});

  void _openMePage(BuildContext context) {
    context.go(AppRoutes.me);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WeeklyViewModel>();

    return Scaffold(
      body: Stack(
        children: [
          AuroraPage(
            child: SafeArea(
              bottom: false,
              child: vm.loadState == LoadState.ready && vm.weeklyInsight != null
                  ? _WeeklyReadyBody(
                      weekly: vm.weeklyInsight!,
                      currentWeekExperiment: vm.currentWeekExperiment,
                      nextWeekExperiment: vm.nextWeekExperiment,
                      activeMicroActions: vm.activeMicroActions,
                      activeExperiments: vm.activeExperiments,
                      energyBudget: vm.energyBudget,
                      progressLoadFailed: vm.progressLoadFailed,
                      candidateStatus: vm.experimentCandidateStatus,
                      candidateCount: vm.experimentCandidateCount,
                      candidatePreviewTitle: vm.experimentCandidatePreviewTitle,
                      candidateStaleReason: vm.experimentCandidateStaleReason,
                      candidateEligibleSignalCount:
                          vm.experimentCandidateEligibleSignalCount,
                      candidateRefreshFailed: vm.candidateErrorMessage != null,
                      feedbackSubmitState: vm.feedbackSubmitState,
                      experimentSubmitState: vm.experimentSubmitState,
                      onSubmitFeedback: (value) async {
                        await vm.submitFeedback(value);
                        if (!context.mounted) return;
                        _showWeeklyHint(
                          context,
                          AppLocaleText.tr(
                            context,
                            en: 'This weekly feedback is saved.',
                            zhHans: '这周的反馈已保存。',
                            zhHant: '這週的回饋已保存。',
                            ja: '今週のフィードバックを保存しました。',
                          ),
                        );
                      },
                      onSaveExperiment: () async {
                        await context
                            .push(AppRoutes.weeklyExperimentCandidates);
                        if (context.mounted) await vm.load();
                      },
                      onRefresh: vm.load,
                    )
                  : ListView(
                      key: const ValueKey('weekly-scroll-view'),
                      padding: AuroraMainPageSpec.scrollPadding(context),
                      children: [
                        _WeeklyHeroHeader(weekly: vm.weeklyInsight),
                        const SizedBox(height: AuroraMainPageSpec.heroGap),
                        switch (vm.loadState) {
                          LoadState.loading => const Padding(
                              padding: EdgeInsets.symmetric(vertical: 56),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                          LoadState.error => EmptyStateBlock(
                              icon: Icons.error_outline,
                              title: AppLocaleText.tr(
                                context,
                                en: 'Failed to load this week',
                                zhHans: '这周的内容加载失败了',
                                zhHant: '這週的內容載入失敗了',
                                ja: '今週の内容を読み込めませんでした',
                              ),
                              subtitle: vm.errorMessage ??
                                  AppLocaleText.tr(
                                    context,
                                    en: 'Please try again later.',
                                    zhHans: '请稍后重试。',
                                    zhHant: '請稍後重試。',
                                    ja: 'しばらくしてから、もう一度試してください。',
                                  ),
                            ),
                          LoadState.empty => _WeeklyEmptyReviewState(
                              readiness: vm.reportReadiness,
                              onToday: () => context.go(AppRoutes.today),
                            ),
                          _ => const SizedBox.shrink(),
                        },
                      ],
                    ),
            ),
          ),
          const AuroraSafeTopMask(extraHeight: 4),
        ],
      ),
    );
  }

  String _weeklyHeroText(BuildContext context, WeeklyInsightModel? weekly) {
    final insight = weekly?.keyInsight;
    if (insight != null && insight.trim().isNotEmpty) return insight;
    return AppLocaleText.tr(
      context,
      en: 'This week may be less about doing more, and more about switching less and recovering a little earlier.',
      zhHans: '这周最耗你的，不是任务量，而是切换太多、恢复太少。',
      zhHant: '這週最耗你的，不是任務量，而是切換太多、恢復太少。',
      ja: '今週いちばん消耗したのは、量そのものより、切り替えの多さと回復の少なさかもしれません。',
    );
  }

  String _buildWeekRange(BuildContext context, WeeklyInsightModel? weekly) {
    if (weekly == null) {
      return AppLocaleText.tr(
        context,
        en: 'This week',
        zhHans: '这一周',
        zhHant: '這一週',
        ja: '今週',
      );
    }
    return '${weekly.weekStart} - ${weekly.weekEnd}';
  }

  String _buildHeaderSummary(BuildContext context, WeeklyViewModel vm) {
    if (vm.loadState == LoadState.loading) {
      return AppLocaleText.tr(
        context,
        en: 'Gathering this week’s signals...',
        zhHans: '正在整理这一周的线索',
        zhHant: '正在整理這一週的線索',
        ja: '今週の手がかりを整理しています',
      );
    }

    if (vm.showFirstDayGate) {
      return AppLocaleText.tr(
        context,
        en: 'Weekly starts after 3 eligible signals in the current local Monday-Sunday week.',
        zhHans: '当前本地周一至周日记录满 3 条有效信号后，Weekly 开始显示报告。',
        zhHant: '當前本地週一至週日記錄滿 3 條有效信號後，Weekly 開始顯示報告。',
        ja: '現在のローカル月曜〜日曜で有効なシグナルが 3 件になると Weekly レポートを表示します。',
      );
    }

    if (vm.loadState == LoadState.empty) {
      return AppLocaleText.tr(
        context,
        en: 'Weekly is forming. The page shows exact X/3 progress before publishing a report.',
        zhHans: 'Weekly 正在形成。达到门槛前只显示明确的 X/3 进度，不发布推断报告。',
        zhHant: 'Weekly 正在形成。達到門檻前只顯示明確的 X/3 進度，不發布推斷報告。',
        ja: 'Weekly は形成中です。条件を満たすまでは X/3 の進捗だけを表示します。',
      );
    }

    if (vm.isLightReady) {
      return AppLocaleText.tr(
        context,
        en: 'A light weekly read is available now. It is early, so this page stays gentle and provisional.',
        zhHans: '这周已经有足够线索开始形成观察了，但还比较早，所以这里只先给温和的阶段观察。',
        zhHant: '這週已經有足夠線索開始形成觀察了，但還比較早，所以這裡先給溫和的階段觀察。',
        ja: '今週は軽い見立てが見られる段階です。まだ早いので、ここではやわらかい途中観察として表示します。',
      );
    }

    return AppLocaleText.tr(
      context,
      en: 'A fuller weekly read is starting to take shape.',
      zhHans: '这周已经开始形成更完整的阶段判断。',
      zhHant: '這週已經開始形成更完整的階段判斷。',
      ja: '今週の見立てが、よりまとまった形になり始めています。',
    );
  }

  String _preferenceText(BuildContext context, String? value) {
    final focusLabel = _focusAreaLabel(context, value);
    return AppLocaleText.tr(
      context,
      en: 'Focus this week: $focusLabel',
      zhHans: '本周关注：$focusLabel',
      zhHant: '本週關注：$focusLabel',
      ja: '今週の注目：$focusLabel',
    );
  }

  String _focusAreaLabel(BuildContext context, String? value) {
    return FocusDomains.labelFor(context, value);
  }
}

void _showWeeklyHint(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
      ),
    );
}

class _WeeklyEmptyReviewState extends StatelessWidget {
  final ReportReadiness readiness;
  final VoidCallback onToday;

  const _WeeklyEmptyReviewState({
    required this.readiness,
    required this.onToday,
  });

  @override
  Widget build(BuildContext context) {
    return _WeeklyGlassCard(
      containerKey: const ValueKey('weekly-empty-card'),
      title: AppLocaleText.tr(
        context,
        en: 'Not enough signals yet',
        zhHans: '本周还没有足够信号',
        zhHant: '本週還沒有足夠信號',
        ja: '今週はまだシグナルが足りません',
      ),
      child: Column(
        children: [
          const AuroraSoftIconCircle(
            icon: Icons.auto_awesome_rounded,
            color: AuroraColors.purple,
            size: 64,
            iconSize: 32,
          ),
          const SizedBox(height: AuroraMainPageSpec.sectionGap),
          Text(
            AppLocaleText.tr(
              context,
              en: 'After three or more life signals, Weekly will organize this week’s patterns and next-week suggestions.',
              zhHans: '记录 3 条以上生活信号后，这里会帮你整理本周模式和下周建议。',
              zhHant: '記錄 3 條以上生活信號後，這裡會幫你整理本週模式和下週建議。',
              ja: '生活シグナルが 3 件以上になると、今週のパターンと来週の提案を整理します。',
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF5F687C),
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 14),
          _ReportReadinessProgress(
            readiness: readiness,
            label: AppLocaleText.tr(
              context,
              en: '${readiness.signalCount} / 3 eligible signals this week',
              zhHans: '本周已记录 ${readiness.signalCount} / 3 条有效信号',
              zhHant: '本週已記錄 ${readiness.signalCount} / 3 條有效信號',
              ja: '今週の有効なシグナル ${readiness.signalCount} / 3 件',
            ),
          ),
          const SizedBox(height: AuroraMainPageSpec.sectionGap),
          const _NextWeekExperimentFormingState(),
          const SizedBox(height: AuroraMainPageSpec.sectionGap),
          AuroraPillButton(
            filled: true,
            label: AppLocaleText.tr(
              context,
              en: 'Record today',
              zhHans: '去记录今天',
              zhHant: '去記錄今天',
              ja: '今日を記録する',
            ),
            onPressed: onToday,
          ),
        ],
      ),
    );
  }
}

class _ReportReadinessProgress extends StatelessWidget {
  final ReportReadiness readiness;
  final String label;

  const _ReportReadinessProgress({
    required this.readiness,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      value: '${(readiness.progress * 100).round()}%',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AuroraColors.purple,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              key: const ValueKey('weekly-report-readiness-progress'),
              value: readiness.progress,
              minHeight: 8,
              color: AuroraColors.purple,
              backgroundColor: AuroraColors.purple.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyReadyBody extends StatelessWidget {
  final WeeklyInsightModel weekly;
  final LifeExperimentModel? currentWeekExperiment;
  final LifeExperimentModel? nextWeekExperiment;
  final List<AdoptedMicroActionProgress> activeMicroActions;
  final List<AdoptedLifeExperimentProgress> activeExperiments;
  final EnergyBudgetModel? energyBudget;
  final bool progressLoadFailed;
  final CandidateGenerationStatus candidateStatus;
  final int candidateCount;
  final String? candidatePreviewTitle;
  final String? candidateStaleReason;
  final int candidateEligibleSignalCount;
  final bool candidateRefreshFailed;
  final SubmitState feedbackSubmitState;
  final SubmitState experimentSubmitState;
  final Future<void> Function(String) onSubmitFeedback;
  final Future<void> Function() onSaveExperiment;
  final Future<void> Function() onRefresh;

  const _WeeklyReadyBody({
    required this.weekly,
    required this.currentWeekExperiment,
    required this.nextWeekExperiment,
    required this.activeMicroActions,
    required this.activeExperiments,
    required this.energyBudget,
    required this.progressLoadFailed,
    required this.candidateStatus,
    required this.candidateCount,
    required this.candidatePreviewTitle,
    required this.candidateStaleReason,
    required this.candidateEligibleSignalCount,
    required this.candidateRefreshFailed,
    required this.feedbackSubmitState,
    required this.experimentSubmitState,
    required this.onSubmitFeedback,
    required this.onSaveExperiment,
    required this.onRefresh,
  });

  bool get isLightReady => weekly.status == 'light_ready';

  @override
  Widget build(BuildContext context) {
    final insight = weekly.keyInsight ??
        AppLocaleText.tr(
          context,
          en: 'A weekly read is starting to take shape.',
          zhHans: '这周已经开始形成阶段判断。',
          zhHant: '這週已經開始形成階段判斷。',
          ja: '今週の見立てが少しずつ形になってきています。',
        );

    final topic = weekly.deriveTopicFocus();
    final structure = weekly.deriveV3CStructure();
    final actionPlan = weekly.deriveActionPlan();

    return RefreshIndicator(
      key: const ValueKey('weekly-pull-to-refresh'),
      onRefresh: onRefresh,
      child: ListView(
        key: const ValueKey('weekly-scroll-view'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AuroraMainPageSpec.scrollPadding(context),
        children: [
          _WeeklyHeroHeader(weekly: weekly),
          const SizedBox(height: AuroraMainPageSpec.heroGap),
          _WeeklyAiQuoteCard(
            text: insight,
            weekly: weekly,
          ),
          const SizedBox(height: AuroraMainPageSpec.sectionGap),
          _WeeklySignalDistributionCard(weekly: weekly),
          const SizedBox(height: 6),
          _WeeklyBehaviorPatternCard(
            weekly: weekly,
            structure: structure,
            topic: topic,
          ),
          const SizedBox(height: AuroraMainPageSpec.sectionGap),
          _EnergyBudgetLiteCard(budget: energyBudget),
          const SizedBox(height: AuroraMainPageSpec.sectionGap),
          _WeeklyAttemptsCard(
            activeMicroActions: activeMicroActions,
            activeExperiments: activeExperiments,
            fallbackExperiment: currentWeekExperiment,
            progressLoadFailed: progressLoadFailed,
          ),
          const SizedBox(height: AuroraMainPageSpec.sectionGap),
          _NextWeekExperimentCard(
            actionPlan: actionPlan,
            experiment: nextWeekExperiment,
            candidateStatus: candidateStatus,
            candidateCount: candidateCount,
            candidatePreviewTitle: candidatePreviewTitle,
            candidateStaleReason: candidateStaleReason,
            candidateRefreshFailed: candidateRefreshFailed,
            eligibleSignalCount: candidateEligibleSignalCount,
            weekEnd: weekly.weekEnd,
            energyBudget: energyBudget,
            experimentSubmitState: experimentSubmitState,
            onSaveExperiment: onSaveExperiment,
            onRefresh: onRefresh,
          ),
          const SizedBox(height: AuroraMainPageSpec.sectionGap),
          const _WeeklyProEntryCard(),
        ],
      ),
    );
  }
}

class _WeeklyHeroHeader extends StatelessWidget {
  final WeeklyInsightModel? weekly;

  const _WeeklyHeroHeader({this.weekly});

  @override
  Widget build(BuildContext context) {
    final titleSize = AuroraMainPageSpec.responsiveHeroTitleSize(context);
    return SizedBox(
      key: const ValueKey('weekly-hero-header'),
      height: 168,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            right: -12,
            top: -10,
            width: 132,
            height: 132,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.32,
                child: Image.asset(
                  'assets/brand-icon-transparent.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      CustomPaint(painter: _WeeklySignalOrbPainter()),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 82),
                  child: Text(
                    AppLocaleText.tr(
                      context,
                      en: 'Weekly Review',
                      zhHans: '本周复盘',
                      zhHant: '本週復盤',
                      ja: '今週の振り返り',
                    ),
                    key: const ValueKey('weekly-hero-title'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontSize: titleSize,
                          height: 1,
                          letterSpacing: 0,
                          color: const Color(0xFF0A1D3D),
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                const SizedBox(height: 6),
                _WeekRangePill(weekly: weekly),
                const SizedBox(height: 7),
                Text(
                  AppLocaleText.tr(
                    context,
                    en: 'See this week’s pattern and find the next way that fits you.',
                    zhHans: '看见这周的模式，找到下一步更适合你的方式。',
                    zhHant: '看見這週的模式，找到下一步更適合你的方式。',
                    ja: '今週のパターンを見て、次に合うやり方を見つけます。',
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF526076),
                        fontSize: AuroraMainPageSpec.heroSubtitleSize,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
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

class _WeekRangePill extends StatelessWidget {
  final WeeklyInsightModel? weekly;

  const _WeekRangePill({required this.weekly});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('weekly-range-pill'),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.92)),
        boxShadow: [
          BoxShadow(
            color: AuroraColors.purple.withValues(alpha: 0.11),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_month_rounded,
              size: 14, color: AuroraColors.purple),
          const SizedBox(width: 5),
          Text(
            weekly == null
                ? AppLocaleText.tr(
                    context,
                    en: 'This week',
                    zhHans: '这一周',
                    zhHant: '這一週',
                    ja: '今週',
                  )
                : _formatWeekRange(weekly!.weekStart, weekly!.weekEnd),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AuroraColors.purple,
                  fontSize: AuroraMainPageSpec.supportingSize,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyAiQuoteCard extends StatelessWidget {
  final String text;
  final WeeklyInsightModel weekly;

  const _WeeklyAiQuoteCard({
    required this.text,
    required this.weekly,
  });

  @override
  Widget build(BuildContext context) {
    final readiness = weekly.reportReadiness;
    final recordDays = readiness.distinctDayCount > 0
        ? readiness.distinctDayCount
        : (readiness.signalCount > 0 ? 1 : 0);
    return Container(
      key: const ValueKey('weekly-ai-quote-card'),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AuroraMainPageSpec.cardRadiusLarge),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocaleText.tr(
                  context,
                  en: 'This week in one sentence',
                  zhHans: '本周一句话',
                  zhHant: '本週一句話',
                  ja: '今週の一言',
                ),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AuroraColors.purple,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF172440),
                      fontSize: 17,
                      height: 1.38,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocaleText.tr(
                  context,
                  en: 'Based on ${readiness.signalCount} eligible signals · $recordDays record days',
                  zhHans:
                      '基于本周 ${readiness.signalCount} 条有效信号 · $recordDays 个记录日',
                  zhHant:
                      '基於本週 ${readiness.signalCount} 條有效信號 · $recordDays 個記錄日',
                  ja: '今週の有効なシグナル ${readiness.signalCount} 件・記録日 $recordDays 日に基づく',
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF647086),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Opacity(
              opacity: 0,
              child: SizedBox(
                key: const ValueKey('weekly-ai-quote-badge'),
                width: 40,
                height: 40,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklySignalDistributionCard extends StatelessWidget {
  final WeeklyInsightModel weekly;

  const _WeeklySignalDistributionCard({required this.weekly});

  @override
  Widget build(BuildContext context) {
    final rows = _rows(context);
    final readiness = weekly.reportReadiness;
    final recordDays = readiness.distinctDayCount > 0
        ? readiness.distinctDayCount
        : (readiness.signalCount > 0 ? 1 : 0);
    return _WeeklyGlassCard(
      containerKey: const ValueKey('weekly-signal-distribution-card'),
      title: AppLocaleText.tr(
        context,
        en: 'Signal distribution',
        zhHans: '本周信号',
        zhHant: '本週信號',
        ja: '今週のシグナル分布',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.push(AppRoutes.journal),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        AppLocaleText.tr(
                          context,
                          en: 'View evidence',
                          zhHans: '查看证据',
                          zhHant: '查看證據',
                          ja: '根拠を見る',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AuroraColors.purple,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 19,
                      color: AuroraColors.purple,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _WeeklyMetricBox(
                  icon: Icons.show_chart_rounded,
                  color: AuroraColors.purple,
                  value: '${readiness.signalCount}',
                  label: AppLocaleText.tr(
                    context,
                    en: 'signals',
                    zhHans: '条信号',
                    zhHant: '條信號',
                    ja: '件のシグナル',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _WeeklyMetricBox(
                  icon: Icons.calendar_today_rounded,
                  color: AuroraColors.blue,
                  value: '$recordDays',
                  label: AppLocaleText.tr(
                    context,
                    en: 'record days',
                    zhHans: '个记录日',
                    zhHant: '個記錄日',
                    ja: '記録日',
                  ),
                ),
              ),
            ],
          ),
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) => Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final row in rows.take(3))
                    _WeeklyDomainChip(
                      data: row,
                      maxWidth: constraints.maxWidth,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<_DistributionData> _rows(BuildContext context) {
    final totalSignals = weekly.chartData.fold<int>(
      0,
      (sum, point) => sum + point.signalCount,
    );
    final signalRows = _rowsFromSignalEntries();
    if (signalRows.isNotEmpty) return signalRows;

    final sourceRows = [
      ...weekly.patterns.whereType<Map>(),
      ...weekly.frictions.whereType<Map>(),
    ];
    final rows = <_DistributionData>[];
    for (final raw in sourceRows) {
      final map = raw.map((key, value) => MapEntry('$key', value));
      final label = _labelFromMap(map);
      if (label.isEmpty || rows.any((row) => row.label == label)) continue;
      rows.add(
        _DistributionData(
          icon: _domainIcon(label),
          illustrationAsset: _WeeklyIllustrationAsset.forText(label),
          label: label,
          count: _countFromMap(map, fallback: 1),
          color: _domainColor(label, rows.length),
        ),
      );
      if (rows.length >= 4) break;
    }
    if (rows.isNotEmpty) return rows;

    final topic = weekly.deriveTopicFocus();
    final label = _displayLabel(topic.headline, '');
    if (label.isEmpty) return const [];
    return [
      _DistributionData(
        icon: _domainIcon(label),
        illustrationAsset: _WeeklyIllustrationAsset.forText(label),
        label: label,
        count: math.max(1, totalSignals),
        color: _domainColor(label, 0),
      ),
    ];
  }

  List<_DistributionData> _rowsFromSignalEntries() {
    final raw = weekly.opportunitySnapshot?['_weekly_signal_entries'];
    if (raw is! List) return const [];
    final counts = <String, int>{};
    for (final item in raw.whereType<Map>()) {
      final map = item.map((key, value) => MapEntry('$key', value));
      final label = _domainFromSignalEntry(map);
      counts[label] = (counts[label] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) {
        final countCompare = b.value.compareTo(a.value);
        if (countCompare != 0) return countCompare;
        return a.key.compareTo(b.key);
      });
    return sorted.take(5).map((entry) {
      final index = sorted.indexOf(entry);
      return _DistributionData(
        icon: _domainIcon(entry.key),
        illustrationAsset: _WeeklyIllustrationAsset.forText(entry.key),
        label: entry.key,
        count: entry.value,
        color: _domainColor(entry.key, index),
      );
    }).toList();
  }

  String _domainFromSignalEntry(Map<String, dynamic> entry) {
    final candidates = <String>[
      ..._stringList(entry['domain_tags']),
      ..._stringList(entry['focus_domains']),
      ..._stringList(entry['scene_tags']),
      ..._stringList(entry['intent_tags']),
      _textFromMap(entry, const ['scene', 'emotion', 'source_type']),
      _textFromMap(entry, const [
        'content',
        'observation',
        'try_next',
        'friction',
        'positive_signal',
        'energy_load',
      ]),
    ].where((value) => value.trim().isNotEmpty).toList();

    final joined = candidates.join(' ');
    if (_containsAny(joined, const [
      '情绪',
      '心情',
      '平静',
      '开心',
      '焦虑',
      '混乱',
      '累',
      '疲惫',
      'emotion',
      'mood',
      'status'
    ])) {
      return '情绪安定';
    }
    if (_containsAny(joined,
        const ['关系', '家人', '朋友', '同事', '伴侣', 'connection', 'relationship'])) {
      return '关系连接';
    }
    if (_containsAny(
        joined, const ['意义', '价值', '方向', 'why', 'meaning', 'value'])) {
      return '价值意义';
    }
    if (_containsAny(joined, const ['边界', '拒绝', '自己的时间', '推着', 'boundary'])) {
      return '自我边界';
    }
    if (_containsAny(
        joined, const ['成长', '计划', '学习', '推进', '目标', 'growth', 'plan'])) {
      return '成长计划';
    }
    if (_containsAny(
        joined, const ['创造', '表达', '写', '画', '作品', 'create', 'creative'])) {
      return '创造表达';
    }
    if (_containsAny(joined, const [
      '饮食',
      '睡眠',
      '睡',
      '晚',
      '午餐',
      '吃',
      '休息',
      '恢复',
      'sleep',
      'food',
      'recovery'
    ])) {
      return '饮食睡眠';
    }
    if (_containsAny(joined,
        const ['环境', '房间', '家里', '整理', '出门', '通勤', 'environment', 'home'])) {
      return '生活环境';
    }
    if (_containsAny(
        joined, const ['兴趣', '爱好', '骑马', '音乐', '游戏', 'hobby', 'interest'])) {
      return '兴趣爱好';
    }
    return '情绪安定';
  }

  List<String> _stringList(Object? raw) {
    if (raw is List) {
      return raw
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    final text = raw?.toString().trim();
    if (text == null || text.isEmpty) return const [];
    return [text];
  }

  bool _containsAny(String text, List<String> needles) {
    final lower = text.toLowerCase();
    return needles.any((needle) => lower.contains(needle.toLowerCase()));
  }

  int _maxCount(List<_DistributionData> rows) {
    if (rows.isEmpty) return 1;
    return rows.map((row) => row.count).reduce(math.max);
  }

  String _labelFromMap(Map<String, dynamic> map) {
    for (final key in const ['focus_domain', 'domain', 'category', 'name']) {
      final value = map[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return '';
  }

  String _textFromMap(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return '';
  }

  int _countFromMap(Map<String, dynamic> map, {required int fallback}) {
    for (final key in const ['count', 'signal_count', 'frequency']) {
      final value = map[key];
      if (value is num && value > 0) return value.round();
    }
    return math.max(1, fallback);
  }

  IconData _domainIcon(String label) {
    if (label.contains('情绪')) return Icons.mood_rounded;
    if (label.contains('关系')) return Icons.groups_rounded;
    if (label.contains('价值')) return Icons.stars_rounded;
    if (label.contains('边界')) return Icons.shield_rounded;
    if (label.contains('成长')) return Icons.spa_rounded;
    if (label.contains('创造')) return Icons.brush_rounded;
    if (label.contains('饮食') || label.contains('睡眠')) {
      return Icons.nightlight_round;
    }
    if (label.contains('环境')) return Icons.home_rounded;
    if (label.contains('兴趣')) return Icons.favorite_rounded;
    return Icons.auto_awesome_rounded;
  }

  Color _domainColor(String label, int index) {
    if (label.contains('情绪')) return AuroraColors.orange;
    if (label.contains('边界')) return AuroraColors.purple;
    if (label.contains('饮食') || label.contains('睡眠')) {
      return const Color(0xFF48C9CE);
    }
    if (label.contains('成长')) return AuroraColors.blue;
    if (label.contains('兴趣')) return const Color(0xFFF07CB9);
    if (label.contains('关系')) return const Color(0xFF8D7AF6);
    if (label.contains('价值')) return const Color(0xFFFFC45B);
    if (label.contains('创造')) return const Color(0xFFFF8BC6);
    if (label.contains('环境')) return const Color(0xFF74D9A4);
    const palette = [
      AuroraColors.purple,
      AuroraColors.orange,
      Color(0xFF48C9CE),
      AuroraColors.blue,
    ];
    return palette[index % palette.length];
  }
}

class _WeeklyMetricBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _WeeklyMetricBox({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AuroraColors.line.withValues(alpha: 0.72)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 19, color: color),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF172440),
                      height: 1.05,
                      fontWeight: FontWeight.w700,
                    ),
                children: [
                  TextSpan(
                    text: '$value\n',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  TextSpan(text: label),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyDomainChip extends StatelessWidget {
  final _DistributionData data;
  final double maxWidth;

  const _WeeklyDomainChip({
    required this.data,
    required this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.50),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AuroraColors.line.withValues(alpha: 0.70)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(data.icon, size: 17, color: data.color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                data.label,
                maxLines: 2,
                softWrap: true,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: const Color(0xFF25324D),
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            const SizedBox(width: 7),
            Text(
              '${data.count}',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: const Color(0xFF172440),
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyBehaviorPatternCard extends StatelessWidget {
  final WeeklyInsightModel weekly;
  final WeeklyV3CStructureModel structure;
  final WeeklyTopicFocusModel topic;

  const _WeeklyBehaviorPatternCard({
    required this.weekly,
    required this.structure,
    required this.topic,
  });

  @override
  Widget build(BuildContext context) {
    final steps = _stepsFromWeekly(context);
    final lead = steps.first;
    return _WeeklyGlassCard(
      containerKey: const ValueKey('weekly-behavior-pattern-card'),
      title: AppLocaleText.tr(
        context,
        en: 'Behavior pattern',
        zhHans: '本周行为模式',
        zhHant: '本週行為模式',
        ja: '今週の行動パターン',
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: lead.color.withValues(alpha: 0.13),
              shape: BoxShape.circle,
            ),
            child: Icon(lead.icon, size: 18, color: lead.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Stage observation',
                    zhHans: '阶段观察',
                    zhHant: '階段觀察',
                    ja: '途中の観察',
                  ),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AuroraColors.purple,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  lead.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: const Color(0xFF22304A),
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  lead.body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF536077),
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_BehaviorStep> _stepsFromWeekly(BuildContext context) {
    final signalSteps = _stepsFromSignalEntries();
    if (signalSteps.isNotEmpty) return signalSteps;

    final rawSteps = <Map<String, dynamic>>[];
    rawSteps.addAll(
      weekly.patterns.whereType<Map>().take(3).map(
            (map) => map.map((key, value) => MapEntry('$key', value)),
          ),
    );
    if (rawSteps.length < 3) {
      rawSteps.addAll(
        weekly.frictions.whereType<Map>().take(3 - rawSteps.length).map(
              (map) => map.map((key, value) => MapEntry('$key', value)),
            ),
      );
    }
    final steps = <_BehaviorStep>[];
    for (final map in rawSteps) {
      final title = _textFromMap(map, const ['name', 'title', 'pattern']);
      final body =
          _textFromMap(map, const ['summary', 'description', 'reason']);
      final hint = _illustrationHintFromMap(map);
      if (title.isEmpty && body.isEmpty) continue;
      steps.add(
        _BehaviorStep(
          icon: _iconForText('$hint $title $body'),
          illustrationAsset:
              _WeeklyIllustrationAsset.forText('$hint $title $body'),
          title: title.isNotEmpty ? title : topic.headline,
          body: _compact(body, topic.reason),
          color: steps.length == 2 ? AuroraColors.blue : AuroraColors.purple,
        ),
      );
    }
    if (steps.isNotEmpty) return steps;
    return [
      _BehaviorStep(
        icon: _iconForText(topic.headline),
        illustrationAsset: _WeeklyIllustrationAsset.forText(
          '${topic.headline} ${topic.reason}',
        ),
        title: topic.headline,
        body: _compact(topic.reason, structure.lightObservation),
        color: AuroraColors.purple,
      ),
    ];
  }

  List<_BehaviorStep> _stepsFromSignalEntries() {
    final entries = _weeklySignalEntries();
    if (entries.isEmpty) return const [];

    final buckets = <String, List<Map<String, dynamic>>>{};
    for (final entry in entries) {
      final key = _signalBucketKey(entry);
      buckets.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(entry);
    }

    final sorted = buckets.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    final palette = [
      AuroraColors.orange,
      AuroraColors.purple,
      AuroraColors.blue,
      const Color(0xFF48C9CE),
    ];

    return sorted.take(3).map((bucket) {
      final sample = bucket.value.first;
      final body = _compact(
        _signalBody(sample),
        '${bucket.value.length} 条信号里出现过这个线索。',
      );
      final hint = _signalIllustrationHint(sample, bucket.key, body);
      return _BehaviorStep(
        icon: _iconForText('$hint ${bucket.key} $body'),
        illustrationAsset: _WeeklyIllustrationAsset.forText(
          '$hint ${bucket.key} $body',
        ),
        title: bucket.key,
        body: bucket.value.length > 1
            ? '$body · ${bucket.value.length} 条信号'
            : body,
        color: palette[sorted.indexOf(bucket) % palette.length],
      );
    }).toList();
  }

  String _illustrationHintFromMap(Map<String, dynamic> map) {
    final explicit = _textFromMap(map, const [
      'illustration_hint',
      'illustrationHint',
      'visual_hint',
      'visualHint',
      'illustration_keyword',
      'illustrationKeyword',
      'asset_hint',
      'assetHint',
    ]);
    if (explicit.isNotEmpty) return explicit;
    final title = _textFromMap(map, const ['name', 'title', 'pattern']);
    final body = _textFromMap(map, const ['summary', 'description', 'reason']);
    return _deriveIllustrationHint('$title $body');
  }

  List<Map<String, dynamic>> _weeklySignalEntries() {
    final raw = weekly.opportunitySnapshot?['_weekly_signal_entries'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((map) => map.map((key, value) => MapEntry('$key', value)))
        .where(
          (map) =>
              map.isNotEmpty &&
              !_textFromMap(map, const ['source_type', 'sourceType'])
                  .toLowerCase()
                  .contains('schedule'),
        )
        .toList();
  }

  String _signalBucketKey(Map<String, dynamic> entry) {
    for (final key in const ['scene_tags', 'intent_tags', 'domain_tags']) {
      final tags = _stringList(entry[key]);
      if (tags.isNotEmpty) return tags.first;
    }
    final sourceType = _textFromMap(entry, const ['source_type', 'sourceType']);
    if (sourceType.isNotEmpty && sourceType != 'text') {
      return switch (sourceType) {
        'voice' => '语音信号',
        'status' || 'quick_status' => '状态信号',
        'ai_predicted' => 'AI 预判信号',
        _ => sourceType,
      };
    }
    final emotion = _textFromMap(entry, const ['emotion', 'mood']);
    if (emotion.isNotEmpty) return emotion;
    return '本周信号';
  }

  String _signalBody(Map<String, dynamic> entry) {
    final body = _textFromMap(entry, const [
      'content',
      'observation',
      'try_next',
      'tryNext',
      'positive_signal',
      'friction',
      'energy_load',
      'acknowledgement',
    ]);
    return _compact(body, topic.reason);
  }

  String _signalIllustrationHint(
    Map<String, dynamic> entry,
    String bucket,
    String body,
  ) {
    final explicit = _textFromMap(entry, const [
      'illustration_hint',
      'illustrationHint',
      'visual_hint',
      'visualHint',
    ]);
    if (explicit.isNotEmpty) return explicit;
    return _deriveIllustrationHint('$bucket $body ${entry.values.join(' ')}');
  }

  String _deriveIllustrationHint(String text) {
    if (_hasAny(text, const ['任务', '堆', '太多', 'todo'])) {
      return '任务堆积，开始变困难';
    }
    if (_hasAny(text, const ['会议', '开会'])) return '会议密集，注意力被切碎';
    if (_hasAny(text, const ['临时', '变化', '打断'])) {
      return '临时变化打断原本节奏';
    }
    if (_hasAny(text, const ['休息', '恢复', '挤'])) return '休息时间被任务挤掉';
    if (_hasAny(text, const ['空转', '停不下来'])) {
      return '想休息，但停下来后反而空转';
    }
    if (_hasAny(text, const ['手机', '短视频', '刷'])) return '晚上刷手机变多';
    if (_hasAny(text, const ['早上', '启动'])) return '早上启动困难';
    if (_hasAny(text, const ['中午', '午后', '下午', '精力'])) {
      return '中午以后精力明显下降';
    }
    if (_hasAny(text, const ['日程', '安排', '密度'])) {
      return '情绪被日程密度带着走';
    }
    if (_hasAny(text, const ['焦虑', '紧张', '还没开始'])) {
      return '焦虑提前出现，还没开始就紧张';
    }
    if (_hasAny(text, const ['完成', '做完', '更累'])) {
      return '做完事后更累，不是更轻松';
    }
    if (_hasAny(text, const ['计划', '目标', '太大'])) {
      return '计划越大，越容易不开始';
    }
    if (_hasAny(text, const ['分散', '目标太多'])) return '目标太多，注意力分散';
    if (_hasAny(text, const ['创作', '创造', '工作'])) return '创作被工作挤掉';
    if (_hasAny(text, const ['拒绝', '边界', '自己的时间'])) {
      return '不敢拒绝，自己的时间被挤占';
    }
    if (_hasAny(text, const ['迎合', '疲惫'])) return '过度迎合后感到疲惫';
    if (_hasAny(text, const ['表达', '说不清'])) return '想表达，但说不清';
    if (_hasAny(text, const ['独处'])) return '独处不足，恢复变慢';
    if (_hasAny(text, const ['环境', '房间', '混乱'])) return '生活环境混乱，心情也乱';
    if (_hasAny(text, const ['关系', '对话', '内耗'])) return '关系对话后反复内耗';
    if (_hasAny(text, const ['金钱', '钱', '现实压力'])) {
      return '金钱或现实压力牵动安全感';
    }
    if (_hasAny(text, const ['身体', '累'])) return '身体信号先出现，才意识到累';
    if (_hasAny(text, const ['有效', '稳定'])) return '小行动有效，节奏开始稳定';
    if (_hasAny(text, const ['兴趣', '爱好'])) return '兴趣活动带来恢复感';
    return '只是观察也有帮助';
  }

  bool _hasAny(String text, List<String> tokens) {
    final lower = text.toLowerCase();
    return tokens.any((token) => lower.contains(token.toLowerCase()));
  }

  List<String> _stringList(Object? raw) {
    if (raw is List) {
      return raw
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    final text = raw?.toString().trim();
    if (text == null || text.isEmpty) return const [];
    return [text];
  }

  String _textFromMap(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return '';
  }

  IconData _iconForText(String text) {
    if (text.contains('安排') || text.contains('会议')) {
      return Icons.calendar_month_rounded;
    }
    if (text.contains('休息') || text.contains('恢复')) {
      return Icons.schedule_rounded;
    }
    if (text.contains('睡') || text.contains('晚')) {
      return Icons.nights_stay_rounded;
    }
    if (text.contains('关系')) return Icons.groups_rounded;
    if (text.contains('边界')) return Icons.shield_rounded;
    if (text.contains('创造')) return Icons.brush_rounded;
    return Icons.auto_awesome_rounded;
  }
}

class _WeeklyAttemptsCard extends StatelessWidget {
  final List<AdoptedMicroActionProgress> activeMicroActions;
  final List<AdoptedLifeExperimentProgress> activeExperiments;
  final LifeExperimentModel? fallbackExperiment;
  final bool progressLoadFailed;

  const _WeeklyAttemptsCard({
    required this.activeMicroActions,
    required this.activeExperiments,
    required this.fallbackExperiment,
    required this.progressLoadFailed,
  });

  @override
  Widget build(BuildContext context) {
    final hasCanonicalExperiments = activeExperiments.isNotEmpty;

    return _WeeklyGlassCard(
      containerKey: const ValueKey('weekly-action-review-card'),
      title: AppLocaleText.tr(
        context,
        en: 'Small actions and review',
        zhHans: '本周尝试',
        zhHant: '本週嘗試',
        ja: '今週の試み',
      ),
      child: Column(
        children: [
          if (progressLoadFailed) const _WeeklyProgressLoadWarning(),
          if (activeMicroActions.isEmpty)
            _WeeklyAttemptEmptyRow(
              icon: Icons.eco_rounded,
              color: AuroraColors.mint,
              kind: AppLocaleText.tr(
                context,
                en: 'Small action',
                zhHans: '小行动',
                zhHant: '小行動',
                ja: '小さな行動',
              ),
              message: AppLocaleText.tr(
                context,
                en: 'No adopted small actions in the current 7-day window.',
                zhHans: '当前 7 天周期内还没有采纳的小行动。',
                zhHant: '目前 7 天週期內還沒有採納的小行動。',
                ja: '現在の 7 日間には、採用した小さな行動がまだありません。',
              ),
            )
          else
            for (final item in activeMicroActions)
              Padding(
                padding: EdgeInsets.only(
                  bottom: identical(item, activeMicroActions.last) ? 0 : 12,
                ),
                child: _WeeklyAttemptRow(
                  icon: Icons.eco_rounded,
                  color: AuroraColors.mint,
                  kind: AppLocaleText.tr(
                    context,
                    en: 'Small action',
                    zhHans: '小行动',
                    zhHant: '小行動',
                    ja: '小さな行動',
                  ),
                  title: item.action.title,
                  progress: item.progress.completedDays,
                  total: SevenDayProgressModel.totalDays,
                  sourceChanged: item.action.sourceChanged,
                ),
              ),
          Divider(
            height: 20,
            color: AuroraColors.line.withValues(alpha: 0.65),
          ),
          Container(
            key: const ValueKey('weekly-experiment-result-card'),
            child: Column(
              children: [
                if (!hasCanonicalExperiments && fallbackExperiment == null)
                  _WeeklyAttemptEmptyRow(
                    icon: Icons.science_outlined,
                    color: AuroraColors.blue,
                    kind: AppLocaleText.tr(
                      context,
                      en: 'Experiment result and review',
                      zhHans: '小实验',
                      zhHant: '小實驗',
                      ja: '小さな実験',
                    ),
                    message: AppLocaleText.tr(
                      context,
                      en: 'No adopted experiments in the current 7-day window.',
                      zhHans: '当前 7 天周期内还没有采纳的小实验。',
                      zhHant: '目前 7 天週期內還沒有採納的小實驗。',
                      ja: '現在の 7 日間には、採用した実験がまだありません。',
                    ),
                  )
                else if (hasCanonicalExperiments)
                  for (final item in activeExperiments)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom:
                            identical(item, activeExperiments.last) ? 0 : 12,
                      ),
                      child: _WeeklyAttemptRow(
                        icon: Icons.science_outlined,
                        color: AuroraColors.blue,
                        kind: AppLocaleText.tr(
                          context,
                          en: 'Experiment result and review',
                          zhHans: '小实验',
                          zhHant: '小實驗',
                          ja: '小さな実験',
                        ),
                        title: item.experiment.title,
                        progress: item.progress.completedDays,
                        total: SevenDayProgressModel.totalDays,
                        sourceChanged: item.experiment.sourceChanged,
                        onTap: () => context.push(AppRoutes.experiment),
                      ),
                    )
                else
                  _WeeklyAttemptRow(
                    icon: Icons.science_outlined,
                    color: AuroraColors.blue,
                    kind: AppLocaleText.tr(
                      context,
                      en: 'Experiment result and review',
                      zhHans: '小实验',
                      zhHant: '小實驗',
                      ja: '小さな実験',
                    ),
                    title: fallbackExperiment!.title,
                    progress: 0,
                    total: SevenDayProgressModel.totalDays,
                    sourceChanged: fallbackExperiment!.sourceChanged,
                    onTap: () => context.push(AppRoutes.experiment),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyAttemptEmptyRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String kind;
  final String message;

  const _WeeklyAttemptEmptyRow({
    required this.icon,
    required this.color,
    required this.kind,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                kind,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: const Color(0xFF24314C),
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF6B7487),
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeeklyProgressLoadWarning extends StatelessWidget {
  const _WeeklyProgressLoadWarning();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('weekly-progress-load-warning'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AuroraColors.orange.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        AppLocaleText.tr(
          context,
          en: 'Progress could not be refreshed. Pull down to try again.',
          zhHans: '进度暂时无法刷新，下拉页面可重试。',
          zhHant: '進度暫時無法重新整理，下拉頁面可重試。',
          ja: '進捗を更新できませんでした。下に引いて再試行できます。',
        ),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF7A5630),
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _WeeklyAttemptRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String kind;
  final String title;
  final int progress;
  final int total;
  final bool sourceChanged;
  final VoidCallback? onTap;

  const _WeeklyAttemptRow({
    required this.icon,
    required this.color,
    required this.kind,
    required this.title,
    required this.progress,
    required this.total,
    this.sourceChanged = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: '$kind, $title, $progress / $total',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, size: 22, color: color),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 82,
                    child: Text(
                      kind,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: const Color(0xFF24314C),
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF354158),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$progress/$total',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AuroraColors.purple,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 21,
                    color: onTap == null
                        ? const Color(0xFF9AA2B2).withValues(alpha: 0.48)
                        : const Color(0xFF7D879A),
                  ),
                ],
              ),
              if (sourceChanged) ...[
                const SizedBox(height: 7),
                Padding(
                  padding: const EdgeInsets.only(left: 32),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.sync_problem_rounded,
                        size: 15,
                        color: AuroraColors.orange,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          _sourceChangedText(context),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF8A5D2C),
                                    height: 1.3,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _sourceChangedText(BuildContext context) {
    return AppLocaleText.tr(
      context,
      en: 'Source changed. This adopted item is kept.',
      zhHans: '来源已变化，已采纳内容继续保留。',
      zhHant: '來源已變化，已採納內容繼續保留。',
      ja: '参照元が変わりました。採用済みの内容は保持されます。',
    );
  }
}

class _WeeklyActionReviewSummaryCard extends StatelessWidget {
  final WeeklyActionReviewModel review;
  final LifeExperimentModel? experiment;
  final WeeklyV3CStructureModel structure;

  const _WeeklyActionReviewSummaryCard({
    required this.review,
    required this.experiment,
    required this.structure,
  });

  @override
  Widget build(BuildContext context) {
    final rows = _rows(context);
    return _WeeklyGlassCard(
      containerKey: const ValueKey('weekly-action-review-card'),
      title: AppLocaleText.tr(
        context,
        en: 'Small actions and review',
        zhHans: '本周小行动和复盘',
        zhHant: '本週小行動和復盤',
        ja: '今週の小さな行動と振り返り',
      ),
      child: rows.isEmpty
          ? Text(
              AppLocaleText.tr(
                context,
                en: 'No micro action feedback has been recorded this week yet.',
                zhHans: '这周还没有保存小行动反馈。',
                zhHant: '這週還沒有保存小行動回饋。',
                ja: '今週はまだ小さな行動のフィードバックが保存されていません。',
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF4B5468),
                    height: 1.45,
                  ),
            )
          : Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  _ActionReviewRow(data: rows[i]),
                  if (i != rows.length - 1)
                    Divider(
                      height: 1,
                      color: AuroraColors.line.withValues(alpha: 0.55),
                    ),
                ],
              ],
            ),
    );
  }

  List<_ActionReviewRowData> _rows(BuildContext context) {
    final rows = <_ActionReviewRowData>[];
    if (review.mostHelpfulAction.trim().isNotEmpty) {
      final hint = _helpfulActionIllustrationHint(review.mostHelpfulAction);
      rows.add(
        _ActionReviewRowData(
          icon: Icons.task_alt_rounded,
          illustrationAsset: _WeeklyIllustrationAsset.forText(
            '$hint ${review.mostHelpfulAction} 做到了 有帮助',
          ),
          title: review.mostHelpfulAction.trim(),
          count: math.max(1, review.helpfulActionCount),
          status: AppLocaleText.tr(
            context,
            en: 'Helpful',
            zhHans: '有帮助',
            zhHant: '有幫助',
            ja: '役立つ',
          ),
          color: AuroraColors.mint,
        ),
      );
    }
    if (review.hardestAction.trim().isNotEmpty) {
      final hint = _hardActionIllustrationHint(review.hardestAction);
      rows.add(
        _ActionReviewRowData(
          icon: Icons.remove_circle_outline_rounded,
          illustrationAsset: _WeeklyIllustrationAsset.forText(
            '$hint ${review.hardestAction} 偏难 更累',
          ),
          title: review.hardestAction.trim(),
          count:
              math.max(1, review.triedActionCount - review.helpfulActionCount),
          status: AppLocaleText.tr(
            context,
            en: 'Hard',
            zhHans: '偏难',
            zhHant: '偏難',
            ja: '難しめ',
          ),
          color: const Color(0xFFFF6F8D),
        ),
      );
    }
    if (review.nextAdjustment.trim().isNotEmpty) {
      final hint = _nextAdjustmentIllustrationHint(review.nextAdjustment);
      rows.add(
        _ActionReviewRowData(
          icon: Icons.tune_rounded,
          illustrationAsset: _WeeklyIllustrationAsset.forText(
            '$hint ${review.nextAdjustment} 调整',
          ),
          title: review.nextAdjustment.trim(),
          count: math.max(1, review.generatedActionCount),
          status: AppLocaleText.tr(
            context,
            en: 'Adjust',
            zhHans: '调整',
            zhHant: '調整',
            ja: '調整',
          ),
          color: AuroraColors.orange,
        ),
      );
    }
    if (rows.isEmpty && experiment?.suggestedAction.trim().isNotEmpty == true) {
      final hint = _helpfulActionIllustrationHint(experiment!.suggestedAction);
      rows.add(
        _ActionReviewRowData(
          icon: Icons.science_rounded,
          illustrationAsset: _WeeklyIllustrationAsset.forText(
            '$hint ${experiment!.suggestedAction}',
          ),
          title: experiment!.suggestedAction.trim(),
          count: math.max(1, review.triedActionCount),
          status: AppLocaleText.tr(
            context,
            en: 'Experiment',
            zhHans: '实验',
            zhHant: '實驗',
            ja: '実験',
          ),
          color: AuroraColors.purple,
        ),
      );
    }
    return rows;
  }

  String _helpfulActionIllustrationHint(String text) {
    if (_hasAny(text, const ['10', '十分钟', '分钟', '短'])) {
      return '10 分钟以内更容易发生';
    }
    if (_hasAny(text, const ['身体', '拉伸', '呼吸', '放松'])) {
      return '身体类小行动更有效';
    }
    if (_hasAny(text, const ['写', '观察', '一句', '记录'])) {
      return '写一句观察更有效';
    }
    if (_hasAny(text, const ['散步', '走路', '走'])) {
      return '散步类行动更有效';
    }
    if (_hasAny(text, const ['手机', '屏幕', '刷'])) {
      return '放下手机类行动有效';
    }
    if (_hasAny(text, const ['整理', '房间', '环境', '收纳'])) {
      return '整理环境类行动有效';
    }
    if (_hasAny(text, const ['关系', '表达', '对话', '沟通'])) {
      return '关系表达类行动有效';
    }
    if (_hasAny(text, const ['拆', '目标', '小步', '小一点'])) {
      return '目标拆小类行动有效';
    }
    return '有帮助';
  }

  String _hardActionIllustrationHint(String text) {
    if (_hasAny(text, const ['打卡', '任务', '清单', '必须'])) {
      return '太像任务打卡';
    }
    if (_hasAny(text, const ['太长', '很久', '半小时', '30', '一小时'])) {
      return '时间太长';
    }
    if (_hasAny(text, const ['复杂', '步骤', '太多', '流程'])) {
      return '太复杂了';
    }
    return '太难了';
  }

  String _nextAdjustmentIllustrationHint(String text) {
    if (_hasAny(text, const ['早上', '晨间', '上午'])) return '早上更容易做到';
    if (_hasAny(text, const ['晚上', '睡前', '夜里'])) return '晚上更容易做到';
    if (_hasAny(text, const ['周末'])) return '周末更容易做到';
    if (_hasAny(text, const ['连续', '几天', '保持'])) return '连续发生几天';
    if (_hasAny(text, const ['重新', '中断', '再开始'])) return '中断后重新开始';
    if (_hasAny(text, const ['部分', '一半'])) return '部分发生';
    if (_hasAny(text, const ['观察', '看见', '记录'])) return '只是观察也有帮助';
    if (_hasAny(text, const ['安排', '日程', '会议'])) return '被安排打断';
    if (_hasAny(text, const ['情绪', '焦虑', '烦'])) return '被情绪打断';
    if (_hasAny(text, const ['继续', '停止', '改小', '调轻', '归档', '换'])) {
      return '下周继续 / 停止 / 改小';
    }
    return '想调整';
  }

  bool _hasAny(String text, List<String> tokens) {
    final source = text.toLowerCase();
    return tokens.any((token) => source.contains(token.toLowerCase()));
  }
}

class _WeeklyExperimentResultCard extends StatelessWidget {
  final WeeklyV3CStructureModel structure;
  final LifeExperimentModel? experiment;
  final WeeklyActionReviewModel review;

  const _WeeklyExperimentResultCard({
    required this.structure,
    required this.experiment,
    required this.review,
  });

  @override
  Widget build(BuildContext context) {
    final totalDays = math.max(1, experiment?.plannedTotalDays ?? 7);
    final progress = math.max(0, math.min(totalDays, review.triedActionCount));
    final title = experiment?.title.trim().isNotEmpty == true
        ? experiment!.title.trim()
        : structure.onePattern;
    return _WeeklyGlassCard(
      containerKey: const ValueKey('weekly-experiment-result-card'),
      title: AppLocaleText.tr(
        context,
        en: 'Experiment result and review',
        zhHans: '本周小实验结果和复盘',
        zhHant: '本週小實驗結果和復盤',
        ja: '今週の実験結果と振り返り',
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (experiment == null) {
            return _EmptyWeeklyExperimentResult();
          }
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AuroraColors.purple,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                structure.oneExperiment,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF49536A),
                      height: 1.45,
                    ),
              ),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AuroraColors.purple.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'More suitable for low-pressure, clear-body actions.',
                    zhHans: '你更适合低压力、身体感明确、可以马上开始的小动作。',
                    zhHant: '你更適合低壓力、身體感明確、可以馬上開始的小動作。',
                    ja: '低負荷で、身体感覚が明確な小さな行動が合いそうです。',
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AuroraColors.purple,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          );
          if (constraints.maxWidth < 330) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProgressRing(progress: progress, total: totalDays),
                const SizedBox(height: 16),
                copy,
              ],
            );
          }
          return Row(
            children: [
              _ProgressRing(progress: progress, total: totalDays),
              const SizedBox(width: 20),
              Expanded(child: copy),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyWeeklyExperimentResult extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AuroraSoftIconCircle(
          icon: Icons.science_outlined,
          color: AuroraColors.purple,
          size: 56,
          iconSize: 28,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocaleText.tr(
                  context,
                  en: 'No experiment this week',
                  zhHans: '本周还没有小实验',
                  zhHant: '本週還沒有小實驗',
                  ja: '今週の実験はまだありません',
                ),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF29334D),
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocaleText.tr(
                  context,
                  en: 'When a saved Life Experiment has attempts or feedback, its progress and review will appear here.',
                  zhHans: '保存的小实验出现尝试或反馈后，这里会显示真实进度和复盘。',
                  zhHant: '保存的小實驗出現嘗試或回饋後，這裡會顯示真實進度和復盤。',
                  ja: '保存した実験に試行や反応が出ると、進捗と振り返りがここに表示されます。',
                ),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF5C6578),
                      height: 1.42,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NextWeekExperimentCard extends StatelessWidget {
  final WeeklyActionPlanModel actionPlan;
  final LifeExperimentModel? experiment;
  final CandidateGenerationStatus candidateStatus;
  final int candidateCount;
  final String? candidatePreviewTitle;
  final String? candidateStaleReason;
  final bool candidateRefreshFailed;
  final int eligibleSignalCount;
  final String weekEnd;
  final EnergyBudgetModel? energyBudget;
  final SubmitState experimentSubmitState;
  final Future<void> Function() onSaveExperiment;
  final Future<void> Function() onRefresh;

  const _NextWeekExperimentCard({
    required this.actionPlan,
    required this.experiment,
    required this.candidateStatus,
    required this.candidateCount,
    required this.candidatePreviewTitle,
    required this.candidateStaleReason,
    required this.candidateRefreshFailed,
    required this.eligibleSignalCount,
    required this.weekEnd,
    required this.energyBudget,
    required this.experimentSubmitState,
    required this.onSaveExperiment,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final busy = experimentSubmitState == SubmitState.submitting;
    final hasExperiment = experiment != null;
    final isAdopted = hasExperiment && !experiment!.id.startsWith('cand_');
    return _WeeklyGlassCard(
      containerKey: const ValueKey('weekly-next-experiment-card'),
      title: AppLocaleText.tr(
        context,
        en: 'Next week experiment',
        zhHans: '下周小实验',
        zhHant: '下週小實驗',
        ja: '来週の小さな実験',
      ),
      child: switch (candidateStatus) {
        CandidateGenerationStatus.gated => _NextWeekExperimentFormingState(
            eligibleSignalCount: eligibleSignalCount,
          ),
        CandidateGenerationStatus.stale => _WeeklyCandidateStatusState(
            key: const ValueKey('weekly-candidate-status-stale'),
            icon: Icons.sync_problem_rounded,
            title: AppLocaleText.tr(
              context,
              en: 'Signals changed',
              zhHans: '信号来源已变化',
              zhHant: '信號來源已變化',
              ja: 'シグナルの参照元が変わりました',
            ),
            message: AppLocaleText.tr(
              context,
              en: 'Old candidates are no longer shown. Refresh to rebuild them from the latest signals.',
              zhHans: '旧候选已失效并停止展示。请根据最新信号重新生成。',
              zhHant: '舊候選已失效並停止顯示。請根據最新信號重新生成。',
              ja: '古い候補は無効になりました。最新のシグナルから作り直してください。',
            ),
            detail: candidateStaleReason == null
                ? null
                : AppLocaleText.tr(
                    context,
                    en: 'The evidence set changed after these candidates were generated.',
                    zhHans: '这些候选生成后，作为依据的信号集合发生了变化。',
                    zhHant: '這些候選生成後，作為依據的信號集合發生了變化。',
                    ja: '候補の作成後に、根拠となるシグナルの組み合わせが変わりました。',
                  ),
            buttonLabel: AppLocaleText.tr(
              context,
              en: 'Refresh candidates',
              zhHans: '刷新候选',
              zhHant: '重新整理候選',
              ja: '候補を更新',
            ),
            onPressed: onRefresh,
          ),
        CandidateGenerationStatus.regenerating => _WeeklyCandidateStatusState(
            key: const ValueKey('weekly-candidate-status-regenerating'),
            loading: true,
            icon: Icons.auto_awesome_rounded,
            title: AppLocaleText.tr(
              context,
              en: 'Updating candidates',
              zhHans: '正在更新候选',
              zhHant: '正在更新候選',
              ja: '候補を更新しています',
            ),
            message: AppLocaleText.tr(
              context,
              en: 'The latest signals are being reorganized. Existing adopted experiments stay unchanged.',
              zhHans: '正在根据最新信号重新整理。已采纳的小实验不会被覆盖。',
              zhHant: '正在根據最新信號重新整理。已採納的小實驗不會被覆蓋。',
              ja: '最新のシグナルから整理し直しています。採用済みの実験は変わりません。',
            ),
          ),
        CandidateGenerationStatus.failed => _WeeklyCandidateStatusState(
            key: const ValueKey('weekly-candidate-status-failed'),
            icon: Icons.error_outline_rounded,
            title: AppLocaleText.tr(
              context,
              en: 'Candidates could not be generated',
              zhHans: '候选暂时生成失败',
              zhHant: '候選暫時生成失敗',
              ja: '候補を作成できませんでした',
            ),
            message: AppLocaleText.tr(
              context,
              en: candidateRefreshFailed
                  ? 'Your Weekly report is still available. Try candidate generation again.'
                  : 'Try candidate generation again when you are ready.',
              zhHans: candidateRefreshFailed
                  ? 'Weekly 报告仍可正常查看，可以单独重试候选生成。'
                  : '准备好后可以再次生成候选。',
              zhHant: candidateRefreshFailed
                  ? 'Weekly 報告仍可正常查看，可以單獨重試候選生成。'
                  : '準備好後可以再次生成候選。',
              ja: candidateRefreshFailed
                  ? 'Weekly レポートは引き続き見られます。候補作成だけ再試行できます。'
                  : '準備ができたら、候補作成をもう一度試せます。',
            ),
            buttonLabel: AppLocaleText.tr(
              context,
              en: 'Try again',
              zhHans: '重试',
              zhHant: '重試',
              ja: '再試行',
            ),
            onPressed: onRefresh,
          ),
        CandidateGenerationStatus.ready => candidateCount <= 0
            ? _WeeklyCandidateStatusState(
                key: const ValueKey('weekly-candidate-status-ready-empty'),
                icon: Icons.inbox_outlined,
                title: AppLocaleText.tr(
                  context,
                  en: 'No candidates available yet',
                  zhHans: '暂时没有可用候选',
                  zhHant: '暫時沒有可用候選',
                  ja: '利用できる候補がまだありません',
                ),
                message: AppLocaleText.tr(
                  context,
                  en: 'Refresh once more to use the latest eligible signals.',
                  zhHans: '可再次刷新，使用最新符合条件的信号生成。',
                  zhHant: '可再次重新整理，使用最新符合條件的信號生成。',
                  ja: '最新の有効なシグナルでもう一度更新できます。',
                ),
                buttonLabel: AppLocaleText.tr(
                  context,
                  en: 'Refresh candidates',
                  zhHans: '刷新候选',
                  zhHant: '重新整理候選',
                  ja: '候補を更新',
                ),
                onPressed: onRefresh,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _nextWeekRange(context),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF526077),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppLocaleText.tr(
                      context,
                      en: '$candidateCount candidate${candidateCount == 1 ? '' : 's'} ready',
                      zhHans: '$candidateCount 个候选已准备好',
                      zhHant: '$candidateCount 個候選已準備好',
                      ja: '候補が $candidateCount 件そろいました',
                    ),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: const Color(0xFF213052),
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  if (candidatePreviewTitle?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 5),
                    Text(
                      candidatePreviewTitle!.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF536077),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _WeeklyCandidateTrait(
                        label: _energyStrengthText(context, energyBudget),
                        color: AuroraColors.purple,
                      ),
                      _WeeklyCandidateTrait(
                        label: AppLocaleText.tr(
                          context,
                          en: 'Low switching',
                          zhHans: '低切换',
                          zhHant: '低切換',
                          ja: '切替少なめ',
                        ),
                        color: AuroraColors.blue,
                      ),
                      _WeeklyCandidateTrait(
                        label: AppLocaleText.tr(
                          context,
                          en: 'Pausable',
                          zhHans: '可暂停',
                          zhHant: '可暫停',
                          ja: '中断できる',
                        ),
                        color: AuroraColors.mint,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AuroraPillButton(
                    filled: true,
                    label: busy
                        ? AppLocaleText.tr(
                            context,
                            en: 'Saving',
                            zhHans: '保存中',
                            zhHant: '保存中',
                            ja: '保存中',
                          )
                        : AppLocaleText.tr(
                            context,
                            en: isAdopted
                                ? 'View all experiments'
                                : 'Choose experiments',
                            zhHans: isAdopted
                                ? '查看全部小实验'
                                : '查看 $candidateCount 个候选',
                            zhHant: isAdopted
                                ? '查看全部小實驗'
                                : '查看 $candidateCount 個候選',
                            ja: isAdopted
                                ? 'すべての実験を見る'
                                : '候補を $candidateCount 件見る',
                          ),
                    onPressed: busy ? null : onSaveExperiment,
                  ),
                ],
              ),
      },
    );
  }

  String _nextWeekRange(BuildContext context) {
    final end = DateTime.tryParse(weekEnd);
    if (end == null) {
      return AppLocaleText.tr(
        context,
        en: 'Next week',
        zhHans: '下周',
        zhHant: '下週',
        ja: '来週',
      );
    }
    final start = end.add(const Duration(days: 1));
    final nextEnd = end.add(const Duration(days: 7));
    String format(DateTime value) => '${value.month}月${value.day}日';
    return '${format(start)}–${format(nextEnd)}';
  }

  String _energyAdjustedExperimentText(BuildContext context) {
    final candidateAction = experiment?.suggestedAction.trim();
    final base = candidateAction != null && candidateAction.isNotEmpty
        ? candidateAction
        : actionPlan.smallExperiment.trim();
    final budget = energyBudget;
    if (budget == null || budget.status == 'insufficient_data') {
      return AppLocaleText.tr(
        context,
        en: '${base.isEmpty ? 'Try one very small experiment next week.' : base} Keep it light until energy signals become clearer.',
        zhHans: '${base.isEmpty ? '下周先试一个很小的实验。' : base} 在能量线索更清楚前，先保持轻量。',
        zhHant: '${base.isEmpty ? '下週先試一個很小的實驗。' : base} 在能量線索更清楚前，先保持輕量。',
        ja: '${base.isEmpty ? '来週はとても小さな実験を一つ試します。' : base} エネルギーの手がかりが見えるまでは軽めにします。',
      );
    }

    final adjustment = budget.switchingAdjustment.trim().isNotEmpty
        ? budget.switchingAdjustment.trim()
        : budget.bufferLocation.trim();
    if (adjustment.isEmpty) {
      return base.isEmpty
          ? AppLocaleText.tr(
              context,
              en: 'Try one small experiment, with enough buffer around it.',
              zhHans: '下周先试一个小实验，并给它前后留一点余地。',
              zhHant: '下週先試一個小實驗，並給它前後留一點餘地。',
              ja: '来週は小さな実験を一つ、前後に余白を残して試します。',
            )
          : base;
    }
    return AppLocaleText.tr(
      context,
      en: '${base.isEmpty ? 'Try one small experiment.' : base} Energy adjustment: $adjustment',
      zhHans: '${base.isEmpty ? '下周先试一个小实验。' : base} 能量调节：$adjustment',
      zhHant: '${base.isEmpty ? '下週先試一個小實驗。' : base} 能量調節：$adjustment',
      ja: '${base.isEmpty ? '来週は小さな実験を一つ試します。' : base} エネルギー調整：$adjustment',
    );
  }
}

class _WeeklyCandidateStatusState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? detail;
  final String? buttonLabel;
  final Future<void> Function()? onPressed;
  final bool loading;

  const _WeeklyCandidateStatusState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.detail,
    this.buttonLabel,
    this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final detailText = detail?.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F0FF).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AuroraColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              else
                Icon(icon, size: 21, color: AuroraColors.purple),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: const Color(0xFF29334D),
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF5C6578),
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (detailText != null && detailText.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              detailText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF7A8292),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
          if (buttonLabel != null && onPressed != null) ...[
            const SizedBox(height: 12),
            AuroraPillButton(
              filled: false,
              label: buttonLabel!,
              onPressed: () async => onPressed!.call(),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeeklyCandidateTrait extends StatelessWidget {
  final String label;
  final Color color;

  const _WeeklyCandidateTrait({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 190),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }
}

class _WeeklyProEntryCard extends StatelessWidget {
  const _WeeklyProEntryCard();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppLocaleText.tr(
        context,
        en: 'Pro weekly deep read. Data is ready.',
        zhHans: 'Pro 本周深读，数据已准备好',
        zhHant: 'Pro 本週深讀，資料已準備好',
        ja: 'Pro 今週の深掘り。データの準備ができました。',
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push(AppRoutes.weeklyReflect),
        child: Container(
          key: const ValueKey('weekly-pro-entry-card'),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFFFF3DC).withValues(alpha: 0.92),
                Colors.white.withValues(alpha: 0.72),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFE8C27A).withValues(alpha: 0.60),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3CA68),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  'Pro',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: const Color(0xFF5B4215),
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'This week deep read · Data is ready',
                    zhHans: '本周深读 · 数据已准备好',
                    zhHant: '本週深讀 · 資料已準備好',
                    ja: '今週の深掘り・データ準備済み',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF4A3B2A),
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF776C61),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextWeekExperimentFormingState extends StatelessWidget {
  final int eligibleSignalCount;

  const _NextWeekExperimentFormingState({this.eligibleSignalCount = 0});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('weekly-next-experiment-forming'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F0FF).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AuroraColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocaleText.tr(
              context,
              en: 'Next week experiment plan is forming',
              zhHans: '下周小实验计划正在形成',
              zhHant: '下週小實驗計畫正在形成',
              ja: '来週の小さな実験計画を作っています',
            ),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: const Color(0xFF29334D),
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 5),
          Text(
            AppLocaleText.tr(
              context,
              en: 'After 3 eligible life signals, up to 3 optional experiments appear (${eligibleSignalCount.clamp(0, 3)}/3). Waiting helps avoid over-reading one moment.',
              zhHans:
                  '记录 3 条符合条件的生活信号后，最多显示 3 个可选实验（${eligibleSignalCount.clamp(0, 3)}/3）。先等待几条信号，是为了避免过度解读一个瞬间。',
              zhHant:
                  '記錄 3 條符合條件的生活信號後，最多顯示 3 個可選實驗（${eligibleSignalCount.clamp(0, 3)}/3）。先等待幾條信號，是為了避免過度解讀一個瞬間。',
              ja: '条件を満たすシグナルが 3 件になると、最大 3 件の実験候補を表示します（${eligibleSignalCount.clamp(0, 3)}/3）。一つの瞬間を読み込みすぎないためです。',
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF5C6578),
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyGlassCard extends StatelessWidget {
  final Key? containerKey;
  final String title;
  final Widget child;

  const _WeeklyGlassCard({
    this.containerKey,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: containerKey,
      padding: AuroraMainPageSpec.comfortableCardPadding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(AuroraMainPageSpec.cardRadiusLarge),
        border: Border.all(color: Colors.white.withValues(alpha: 0.90)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7568A6).withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF213052),
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: AuroraMainPageSpec.sectionGap),
          child,
        ],
      ),
    );
  }
}

class _WeeklyIllustrationAsset {
  static const emotionStable =
      'assets/weekly/weekly-illustration-emotion-stable.png';
  static const growthPlan = 'assets/weekly/weekly-illustration-growth-plan.png';
  static const eveningLoop =
      'assets/weekly/weekly-illustration-evening-loop.png';
  static const scheduleHeavy =
      'assets/weekly/weekly-illustration-schedule-heavy.png';
  static const interestHobby =
      'assets/weekly/weekly-illustration-interest-hobby.png';
  static const secondDayTired =
      'assets/weekly/weekly-illustration-second-day-tired.png';
  static const selfBoundary =
      'assets/weekly/weekly-illustration-self-boundary.png';
  static const foodSleep = 'assets/weekly/weekly-illustration-food-sleep.png';
  static const taskPileStartBlocked =
      'assets/weekly/weekly-pattern-task-pile-start-blocked.png';
  static const meetingFragmented =
      'assets/weekly/weekly-pattern-meeting-fragmented.png';
  static const routeInterrupted =
      'assets/weekly/weekly-pattern-route-interrupted.png';
  static const restSqueezed = 'assets/weekly/weekly-pattern-rest-squeezed.png';
  static const stopLoop = 'assets/weekly/weekly-pattern-stop-loop.png';
  static const nightPhone = 'assets/weekly/weekly-pattern-night-phone.png';
  static const morningStartSlow =
      'assets/weekly/weekly-pattern-morning-start-slow.png';
  static const afternoonEnergyDrop =
      'assets/weekly/weekly-pattern-afternoon-energy-drop.png';
  static const scheduleDrivenMood =
      'assets/weekly/weekly-pattern-schedule-driven-mood.png';
  static const anticipatoryAnxiety =
      'assets/weekly/weekly-pattern-anticipatory-anxiety.png';
  static const doneMoreTired =
      'assets/weekly/weekly-pattern-done-more-tired.png';
  static const largePlanHardStart =
      'assets/weekly/weekly-pattern-large-plan-hard-start.png';
  static const tooManyGoalsScattered =
      'assets/weekly/weekly-pattern-too-many-goals-scattered.png';
  static const creationSqueezedByWork =
      'assets/weekly/weekly-pattern-creation-squeezed-by-work.png';
  static const boundaryPushedTimeSqueezed =
      'assets/weekly/weekly-pattern-boundary-pushed-time-squeezed.png';
  static const peoplePleasingTired =
      'assets/weekly/weekly-pattern-people-pleasing-tired.png';
  static const unclearExpression =
      'assets/weekly/weekly-pattern-unclear-expression.png';
  static const solitudeInsufficient =
      'assets/weekly/weekly-pattern-solitude-insufficient.png';
  static const messyEnvironmentMood =
      'assets/weekly/weekly-pattern-messy-environment-mood.png';
  static const relationshipDialogueRumination =
      'assets/weekly/weekly-pattern-relationship-dialogue-rumination.png';
  static const moneySafetyPressure =
      'assets/weekly/weekly-pattern-money-safety-pressure.png';
  static const bodySignalBeforeTired =
      'assets/weekly/weekly-pattern-body-signal-before-tired.png';
  static const smallActionStabilizes =
      'assets/weekly/weekly-pattern-small-action-stabilizes.png';
  static const interestRecovery =
      'assets/weekly/weekly-pattern-interest-recovery.png';
  static const reviewDone = 'assets/weekly/weekly-review-done.png';
  static const reviewNotDone = 'assets/weekly/weekly-review-not-done.png';
  static const reviewSkip = 'assets/weekly/weekly-review-skip.png';
  static const reviewNotSuitableToday =
      'assets/weekly/weekly-review-not-suitable-today.png';
  static const reviewHelpful = 'assets/weekly/weekly-review-helpful.png';
  static const reviewNeutral = 'assets/weekly/weekly-review-neutral.png';
  static const reviewNotHelpful = 'assets/weekly/weekly-review-not-helpful.png';
  static const reviewAdjust = 'assets/weekly/weekly-review-adjust.png';
  static const reviewTooHard = 'assets/weekly/weekly-review-too-hard.png';
  static const reviewTooComplex = 'assets/weekly/weekly-review-too-complex.png';
  static const reviewTaskCheckinPressure =
      'assets/weekly/weekly-review-task-checkin-pressure.png';
  static const reviewTooLong = 'assets/weekly/weekly-review-too-long.png';
  static const reviewUnderTenMinutes =
      'assets/weekly/weekly-review-under-ten-minutes.png';
  static const reviewBodyActionEffective =
      'assets/weekly/weekly-review-body-action-effective.png';
  static const reviewOneLineObservationEffective =
      'assets/weekly/weekly-review-one-line-observation-effective.png';
  static const reviewWalkEffective =
      'assets/weekly/weekly-review-walk-effective.png';
  static const reviewPutPhoneDownEffective =
      'assets/weekly/weekly-review-put-phone-down-effective.png';
  static const reviewOrganizeSpaceEffective =
      'assets/weekly/weekly-review-organize-space-effective.png';
  static const reviewRelationshipExpressionEffective =
      'assets/weekly/weekly-review-relationship-expression-effective.png';
  static const reviewBreakGoalSmallerEffective =
      'assets/weekly/weekly-review-break-goal-smaller-effective.png';
  static const reviewMorningEasier =
      'assets/weekly/weekly-review-morning-easier.png';
  static const reviewEveningEasier =
      'assets/weekly/weekly-review-evening-easier.png';
  static const reviewWeekendEasier =
      'assets/weekly/weekly-review-weekend-easier.png';
  static const reviewContinuousDays =
      'assets/weekly/weekly-review-continuous-days.png';
  static const reviewRestartAfterInterruption =
      'assets/weekly/weekly-review-restart-after-interruption.png';
  static const reviewPartialHappened =
      'assets/weekly/weekly-review-partial-happened.png';
  static const reviewObservationHelpful =
      'assets/weekly/weekly-review-observation-helpful.png';
  static const reviewInterruptedBySchedule =
      'assets/weekly/weekly-review-interrupted-by-schedule.png';
  static const reviewInterruptedByEmotion =
      'assets/weekly/weekly-review-interrupted-by-emotion.png';
  static const reviewNextWeekBranch =
      'assets/weekly/weekly-review-next-week-branch.png';

  static String? forText(String text) {
    final lower = text.toLowerCase();
    if (_contains(lower, const [
      '太像任务打卡',
      '像任务打卡',
      '清单压力',
      '红点提醒',
      'checkin pressure',
    ])) {
      return reviewTaskCheckinPressure;
    }
    if (_contains(lower, const [
      '时间太长',
      '太长',
      '长时钟',
      '拉长进度条',
      'too long',
    ])) {
      return reviewTooLong;
    }
    if (_contains(lower, const [
      '10 分钟以内',
      '10分钟以内',
      '十分钟以内',
      '更容易发生',
      '短进度条',
      'under ten',
    ])) {
      return reviewUnderTenMinutes;
    }
    if (_contains(lower, const [
      '身体类小行动更有效',
      '身体类',
      '拉伸小人',
      '身体光点',
      'body action effective',
    ])) {
      return reviewBodyActionEffective;
    }
    if (_contains(lower, const [
      '写一句观察更有效',
      '一句观察',
      '一行文字',
      'one line observation',
    ])) {
      return reviewOneLineObservationEffective;
    }
    if (_contains(lower, const [
      '散步类行动更有效',
      '散步类',
      '脚印',
      '小路',
      'walk effective',
    ])) {
      return reviewWalkEffective;
    }
    if (_contains(lower, const [
      '放下手机类行动有效',
      '放下手机',
      '手机休眠',
      'put phone down',
    ])) {
      return reviewPutPhoneDownEffective;
    }
    if (_contains(lower, const [
      '整理环境类行动有效',
      '整理环境',
      '收纳盒',
      'organize space',
    ])) {
      return reviewOrganizeSpaceEffective;
    }
    if (_contains(lower, const [
      '关系表达类行动有效',
      '关系表达',
      '小桥',
      'relationship expression',
    ])) {
      return reviewRelationshipExpressionEffective;
    }
    if (_contains(lower, const [
      '目标拆小类行动有效',
      '目标拆小',
      '小台阶',
      '小旗帜',
      'break goal smaller',
    ])) {
      return reviewBreakGoalSmallerEffective;
    }
    if (_contains(lower, const [
      '早上更容易做到',
      '早上更容易',
      '晨光',
      '日出',
      'morning easier',
    ])) {
      return reviewMorningEasier;
    }
    if (_contains(lower, const [
      '晚上更容易做到',
      '晚上更容易',
      '夜灯',
      '月亮',
      'evening easier',
    ])) {
      return reviewEveningEasier;
    }
    if (_contains(lower, const [
      '周末更容易做到',
      '周末更容易',
      '周末日历',
      '松弛线',
      'weekend easier',
    ])) {
      return reviewWeekendEasier;
    }
    if (_contains(lower, const [
      '连续发生几天',
      '连续发生',
      '连续几天',
      '连续圆点',
      '进度链',
      'continuous days',
    ])) {
      return reviewContinuousDays;
    }
    if (_contains(lower, const [
      '中断后重新开始',
      '断线重连',
      '重新开始',
      '回到小路',
      'restart after interruption',
    ])) {
      return reviewRestartAfterInterruption;
    }
    if (_contains(lower, const [
      '部分发生',
      '半圆勾',
      '半亮星',
      'partial happened',
    ])) {
      return reviewPartialHappened;
    }
    if (_contains(lower, const [
      '只是观察也有帮助',
      '观察也有帮助',
      '眼睛',
      '观察点',
      'observation helpful',
    ])) {
      return reviewObservationHelpful;
    }
    if (_contains(lower, const [
      '被安排打断',
      '日历插入',
      '中断线',
      'interrupted by schedule',
    ])) {
      return reviewInterruptedBySchedule;
    }
    if (_contains(lower, const [
      '被情绪打断',
      '情绪波浪',
      '偏移箭头',
      'interrupted by emotion',
    ])) {
      return reviewInterruptedByEmotion;
    }
    if (_contains(lower, const [
      '下周继续',
      '继续 / 停止 / 改小',
      '继续、归档、缩小',
      '分叉箭头',
      '改小',
      '归档',
      'next week branch',
    ])) {
      return reviewNextWeekBranch;
    }
    if (_contains(lower, const ['今天不适合', '不适合', '轻跳过'])) {
      return reviewNotSuitableToday;
    }
    if (_contains(lower, const ['没帮助', '没有帮助', '暗淡星', 'not helpful'])) {
      return reviewNotHelpful;
    }
    if (_contains(lower, const ['太复杂', '复杂了', '线团', '多步骤', 'complex'])) {
      return reviewTooComplex;
    }
    if (_contains(lower, const ['太难了', '太难', '陡坡', '高台阶', 'too hard'])) {
      return reviewTooHard;
    }
    if (_contains(lower, const ['有帮助', 'helpful', 'helped'])) {
      return reviewHelpful;
    }
    if (_contains(lower, const ['没做到', '沒有做到', 'not_done', 'missed'])) {
      return reviewNotDone;
    }
    if (_contains(lower, const ['不想做', '暂时不做', 'skip', 'not want'])) {
      return reviewSkip;
    }
    if (_contains(lower, const ['一般', 'neutral', 'ordinary'])) {
      return reviewNeutral;
    }
    if (_contains(lower, const ['想调整', '调整', '改一下', 'adjust'])) {
      return reviewAdjust;
    }
    if (_contains(lower, const ['做到了', '做到', '完成', 'done'])) {
      return reviewDone;
    }
    if (_contains(lower, const [
      '关系对话后反复内耗',
      '对话后反复内耗',
      '关系内耗',
      '对话气泡循环',
      '回声线',
      'dialogue rumination',
    ])) {
      return relationshipDialogueRumination;
    }
    if (_contains(lower, const [
      '金钱或现实压力',
      '现实压力',
      '牵动安全感',
      '钱币',
      '保护盾',
      'money pressure',
      'safety pressure',
    ])) {
      return moneySafetyPressure;
    }
    if (_contains(lower, const [
      '身体信号先出现',
      '才意识到累',
      '身体信号',
      '身体轮廓',
      '提醒灯',
      'body signal',
    ])) {
      return bodySignalBeforeTired;
    }
    if (_contains(lower, const [
      '小行动有效',
      '节奏开始稳定',
      '开始稳定',
      '稳定光环',
      'small action effective',
      'stabilize',
    ])) {
      return smallActionStabilizes;
    }
    if (_contains(lower, const [
      '兴趣活动带来恢复感',
      '兴趣带来恢复',
      '带来恢复感',
      '小星光',
      'interest recovery',
    ])) {
      return interestRecovery;
    }
    if (_contains(lower, const [
      '做完事后更累',
      '做完更累',
      '完成后更累',
      '不是更轻松',
      '低电量',
      'done tired',
    ])) {
      return doneMoreTired;
    }
    if (_contains(lower, const [
      '计划越大',
      '越容易不开始',
      '巨大清单',
      '不开始',
      'large plan',
      'hard start',
    ])) {
      return largePlanHardStart;
    }
    if (_contains(lower, const [
      '目标太多',
      '注意力分散',
      '多条分叉路',
      '散开的星点',
      'too many goals',
      'scattered',
    ])) {
      return tooManyGoalsScattered;
    }
    if (_contains(lower, const [
      '创作被工作挤掉',
      '创造被工作挤掉',
      '画笔被文件压住',
      '创作被挤掉',
      'creation squeezed',
    ])) {
      return creationSqueezedByWork;
    }
    if (_contains(lower, const [
      '不敢拒绝',
      '自己的时间被挤占',
      '边界线被推开',
      '时间被挤占',
      'boundary pushed',
    ])) {
      return boundaryPushedTimeSqueezed;
    }
    if (_contains(lower, const [
      '过度迎合',
      '迎合后感到疲惫',
      '微笑面具',
      'people pleasing',
    ])) {
      return peoplePleasingTired;
    }
    if (_contains(lower, const [
      '想表达但说不清',
      '想表达',
      '说不清',
      '断开的对话',
      'unclear expression',
    ])) {
      return unclearExpression;
    }
    if (_contains(lower, const [
      '独处不足',
      '恢复变慢',
      '安静空间缺失',
      '小房间',
      'solitude',
    ])) {
      return solitudeInsufficient;
    }
    if (_contains(lower, const [
      '生活环境混乱',
      '环境混乱',
      '房间杂物',
      '心情也乱',
      'messy environment',
    ])) {
      return messyEnvironmentMood;
    }
    if (_contains(lower, const [
      '任务堆积',
      '任务太多',
      '堆积',
      '开始变困难',
      '起点被挡',
      'task pile',
      'backlog',
    ])) {
      return taskPileStartBlocked;
    }
    if (_contains(lower, const [
      '会议密集',
      '会议太多',
      '注意力被切碎',
      '碎片化',
      'meeting-heavy',
      'fragment',
    ])) {
      return meetingFragmented;
    }
    if (_contains(lower, const [
      '临时变化',
      '打断原本节奏',
      '被打断',
      '插入',
      'route interrupted',
      'interruption',
    ])) {
      return routeInterrupted;
    }
    if (_contains(lower, const [
      '休息时间被任务挤掉',
      '休息被挤掉',
      '休息被任务',
      '休息被压缩',
      '休息被压',
      '休息压缩',
      '被压缩',
    ])) {
      return restSqueezed;
    }
    if (_contains(lower, const [
      '想休息但停下来',
      '停下来后空转',
      '停下来反而空转',
      '停止键',
      '旋转圆圈',
      'stop loop',
    ])) {
      return stopLoop;
    }
    if (_contains(lower, const [
      '晚上刷手机',
      '刷手机变多',
      '手机发光',
      '通知点',
      'night phone',
    ])) {
      return nightPhone;
    }
    if (_contains(lower, const [
      '早上启动困难',
      '早上启动',
      '晨间启动',
      '慢启动',
      'morning start',
    ])) {
      return morningStartSlow;
    }
    if (_contains(lower, const [
      '中午以后精力下降',
      '午后精力',
      '下午精力',
      '电量下降',
      'energy drop',
      'afternoon',
    ])) {
      return afternoonEnergyDrop;
    }
    if (_contains(lower, const [
      '情绪被日程',
      '日程密度',
      '日历连接情绪',
      'schedule mood',
    ])) {
      return scheduleDrivenMood;
    }
    if (_contains(lower, const [
      '焦虑提前',
      '还没开始就紧张',
      '提前紧张',
      '未来时间点',
      'anticipatory',
    ])) {
      return anticipatoryAnxiety;
    }
    if (_contains(lower, const ['第二天', '更累', '偏难', '太难', 'hard'])) {
      return secondDayTired;
    }
    if (_contains(lower, const ['自我边界', '边界', 'boundary'])) {
      return selfBoundary;
    }
    if (_contains(lower, const ['饮食睡眠', '饮食', '吃', '午餐', 'food'])) {
      return foodSleep;
    }
    if (_contains(lower, const ['安排', '会议', '日程', 'schedule', 'calendar'])) {
      return scheduleHeavy;
    }
    if (_contains(lower, const ['晚上空转', '空转', '刷手机', '睡', '晚', 'sleep'])) {
      return eveningLoop;
    }
    if (_contains(lower, const ['成长', '计划', '目标', '推进', 'growth', 'plan'])) {
      return growthPlan;
    }
    if (_contains(lower, const ['兴趣', '爱好', '创造', '表达', 'hobby', 'interest'])) {
      return interestHobby;
    }
    if (_contains(lower, const ['情绪', '状态', '平静', '稳定', '焦虑', '累', 'mood'])) {
      return emotionStable;
    }
    return null;
  }

  static bool _contains(String text, List<String> needles) {
    return needles.any((needle) => text.contains(needle.toLowerCase()));
  }
}

class _WeeklyIllustrationThumb extends StatelessWidget {
  final String? asset;
  final IconData fallbackIcon;
  final Color color;
  final double size;
  final double iconSize;

  const _WeeklyIllustrationThumb({
    required this.asset,
    required this.fallbackIcon,
    required this.color,
    required this.size,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final path = asset;
    if (path == null) {
      return AuroraSoftIconCircle(
        icon: fallbackIcon,
        color: color,
        size: size,
        iconSize: iconSize,
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.26),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        path,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}

class _DistributionRow extends StatelessWidget {
  final _DistributionData data;
  final int maxCount;

  const _DistributionRow({
    required this.data,
    required this.maxCount,
  });

  @override
  Widget build(BuildContext context) {
    final widthFactor = (data.count / math.max(1, maxCount)).clamp(0.18, 1.0);
    return Row(
      children: [
        _WeeklyIllustrationThumb(
          asset: data.illustrationAsset,
          fallbackIcon: data.icon,
          color: data.color,
          size: 44,
          iconSize: 22,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      data.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: const Color(0xFF313A56),
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  Text(
                    '${data.count}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: const Color(0xFF34405D),
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: Stack(
                  children: [
                    Container(
                      height: 7,
                      color: AuroraColors.purple.withValues(alpha: 0.10),
                    ),
                    FractionallySizedBox(
                      widthFactor: widthFactor,
                      child: Container(
                        height: 7,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          color: data.color,
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
    );
  }
}

class _BehaviorStepTile extends StatelessWidget {
  final int index;
  final _BehaviorStep step;

  const _BehaviorStepTile({
    required this.index,
    required this.step,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                step.color.withValues(alpha: 0.85),
                AuroraColors.purple.withValues(alpha: 0.70),
              ],
            ),
          ),
          child: Text(
            '$index',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
          ),
          child: Column(
            children: [
              _WeeklyIllustrationThumb(
                asset: step.illustrationAsset,
                fallbackIcon: step.icon,
                color: step.color,
                size: 46,
                iconSize: 23,
              ),
              const SizedBox(height: 10),
              Text(
                step.title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: const Color(0xFF26314F),
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 5),
              Text(
                step.body,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF687389),
                      height: 1.25,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionReviewRow extends StatelessWidget {
  final _ActionReviewRowData data;

  const _ActionReviewRow({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _WeeklyIllustrationThumb(
            asset: data.illustrationAsset,
            fallbackIcon: data.icon,
            color: data.color,
            size: 36,
            iconSize: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              data.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF26304A),
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              AppLocaleText.tr(
                context,
                en: 'Happened ${data.count} times',
                zhHans: '发生了 ${data.count} 次',
                zhHant: '發生了 ${data.count} 次',
                ja: '${data.count}回発生',
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: const Color(0xFF4E5870),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          _StatusPill(label: data.status, color: data.color),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final failed = label.contains('没') ||
        label.toLowerCase().contains('miss') ||
        label.contains('でき');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            failed ? Icons.close_rounded : Icons.check_rounded,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  final int progress;
  final int total;

  const _ProgressRing({
    required this.progress,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      height: 112,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size.square(112),
            painter: _ProgressRingPainter(progress / total),
          ),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$progress',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AuroraColors.purple,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                TextSpan(
                  text: '/$total',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AuroraColors.purple.withValues(alpha: 0.68),
                        fontWeight: FontWeight.w800,
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

class _DistributionData {
  final IconData icon;
  final String? illustrationAsset;
  final String label;
  final int count;
  final Color color;

  const _DistributionData({
    required this.icon,
    this.illustrationAsset,
    required this.label,
    required this.count,
    required this.color,
  });
}

class _SignalDistributionDonut extends StatelessWidget {
  final List<_DistributionData> rows;
  final int total;

  const _SignalDistributionDonut({
    required this.rows,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AuroraColors.purple.withValues(alpha: 0.10),
                    blurRadius: 34,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),
          ),
          CustomPaint(
            painter: _SignalDistributionDonutPainter(
              rows: rows,
              total: total,
            ),
            child: const SizedBox.expand(),
          ),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.42),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.72),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.55),
                  blurRadius: 24,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white.withValues(alpha: 0.92),
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

class _DistributionFocusNote extends StatelessWidget {
  final List<_DistributionData> rows;

  const _DistributionFocusNote({required this.rows});

  @override
  Widget build(BuildContext context) {
    final first = rows.first;
    final second = rows.length > 1 ? rows[1] : null;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.68)),
      ),
      child: Row(
        children: [
          _WeeklyIllustrationThumb(
            asset: first.illustrationAsset,
            fallbackIcon: Icons.star_rounded,
            color: first.color,
            size: 52,
            iconSize: 24,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: AppLocaleText.tr(
                  context,
                  en: 'This week is more concentrated in ',
                  zhHans: '本周重点更集中在',
                  zhHant: '本週重點更集中在',
                  ja: '今週は特に',
                ),
                children: [
                  TextSpan(
                    text: first.label,
                    style: TextStyle(color: first.color),
                  ),
                  if (second != null)
                    TextSpan(
                      text: AppLocaleText.tr(
                        context,
                        en: ' and ',
                        zhHans: '和',
                        zhHant: '和',
                        ja: 'と',
                      ),
                    ),
                  if (second != null)
                    TextSpan(
                      text: second.label,
                      style: TextStyle(color: second.color),
                    ),
                  TextSpan(
                    text: AppLocaleText.tr(
                      context,
                      en: '.',
                      zhHans: '。',
                      zhHant: '。',
                      ja: 'に集中しています。',
                    ),
                  ),
                ],
              ),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF4D566D),
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalDistributionDonutPainter extends CustomPainter {
  final List<_DistributionData> rows;
  final int total;

  _SignalDistributionDonutPainter({
    required this.rows,
    required this.total,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = size.shortestSide * 0.35;
    final stroke = size.shortestSide * 0.16;
    final ringRect = Rect.fromCircle(center: center, radius: radius);
    final background = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt
      ..color = Colors.white.withValues(alpha: 0.42);
    canvas.drawCircle(center, radius, background);

    if (rows.isEmpty || total <= 0) return;

    var start = -math.pi / 2.25;
    const gap = math.pi * 0.018;
    for (final row in rows) {
      final sweep = math.max(0.08, (row.count / total) * math.pi * 2 - gap);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt
        ..shader = SweepGradient(
          startAngle: start,
          endAngle: start + sweep,
          colors: [
            row.color.withValues(alpha: 0.58),
            row.color,
            Colors.white.withValues(alpha: 0.76),
          ],
        ).createShader(ringRect);
      canvas.drawArc(ringRect, start, sweep, false, paint);

      final dotAngle = start + sweep * 0.12;
      final dot = Offset(
        center.dx + math.cos(dotAngle) * radius,
        center.dy + math.sin(dotAngle) * radius,
      );
      canvas.drawCircle(
        dot,
        stroke * 0.20,
        Paint()..color = Colors.white.withValues(alpha: 0.95),
      );
      canvas.drawCircle(
        dot,
        stroke * 0.12,
        Paint()..color = row.color.withValues(alpha: 0.85),
      );
      start += sweep + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _SignalDistributionDonutPainter oldDelegate) {
    return oldDelegate.rows != rows || oldDelegate.total != total;
  }
}

class _BehaviorStep {
  final IconData icon;
  final String? illustrationAsset;
  final String title;
  final String body;
  final Color color;

  const _BehaviorStep({
    required this.icon,
    this.illustrationAsset,
    required this.title,
    required this.body,
    required this.color,
  });
}

class _ActionReviewRowData {
  final IconData icon;
  final String? illustrationAsset;
  final String title;
  final int count;
  final String status;
  final Color color;

  const _ActionReviewRowData({
    required this.icon,
    this.illustrationAsset,
    required this.title,
    required this.count,
    required this.status,
    required this.color,
  });
}

String _formatWeekRange(String start, String end) {
  String format(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return '${parsed.month}月${parsed.day}日';
  }

  return '${format(start)} - ${format(end)}';
}

String _displayLabel(String raw, String fallback) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return fallback;
  if (trimmed.runes.length <= 8) return trimmed;
  return String.fromCharCodes(trimmed.runes.take(8));
}

String _compact(String raw, String fallback) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return fallback;
  final first = trimmed.split(RegExp(r'[。；;\n]')).first.trim();
  final source = first.isEmpty ? trimmed : first;
  if (source.runes.length <= 22) return source;
  return '${String.fromCharCodes(source.runes.take(22))}...';
}

class _SoftPlant extends StatelessWidget {
  final Color color;

  const _SoftPlant({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      height: 92,
      child: CustomPaint(painter: _SoftPlantPainter(color)),
    );
  }
}

class _SoftPlantPainter extends CustomPainter {
  final Color color;

  _SoftPlantPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final stem = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    final start = Offset(size.width * 0.5, size.height);
    final end = Offset(size.width * 0.48, size.height * 0.05);
    canvas.drawLine(start, end, stem);

    final leaf = Paint()..color = color.withValues(alpha: 0.78);
    for (var i = 0; i < 5; i++) {
      final y = size.height * (0.22 + i * 0.13);
      final left = i.isEven;
      final path = Path()
        ..moveTo(size.width * 0.50, y)
        ..cubicTo(
          left ? size.width * 0.16 : size.width * 0.84,
          y - 16,
          left ? size.width * 0.16 : size.width * 0.84,
          y + 4,
          size.width * 0.50,
          y + 14,
        )
        ..close();
      canvas.drawPath(path, leaf);
    }
  }

  @override
  bool shouldRepaint(covariant _SoftPlantPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;

  _ProgressRingPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = size.width * 0.12;
    final ringRect = rect.deflate(stroke / 2);
    canvas.drawArc(
      ringRect,
      -math.pi / 2,
      math.pi * 2,
      false,
      Paint()
        ..color = AuroraColors.purple.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke,
    );
    canvas.drawArc(
      ringRect,
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0, 1),
      false,
      Paint()
        ..shader = const SweepGradient(
          colors: [
            Color(0xFF7B6FF2),
            Color(0xFF69A7FF),
            Color(0xFFB982FF),
            Color(0xFF7B6FF2),
          ],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _WeeklySignalOrbPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) * 0.36;
    canvas.drawCircle(
      center,
      radius * 1.36,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.90),
            AuroraColors.purple.withValues(alpha: 0.18),
            Colors.transparent,
          ],
        ).createShader(rect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const SweepGradient(
          colors: [
            Color(0xFFFFB45B),
            Color(0xFF65D7D4),
            Color(0xFF6D92F8),
            Color(0xFF9665F4),
            Color(0xFFFFB45B),
          ],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round,
    );

    final soft = Paint()
      ..color = Colors.white.withValues(alpha: 0.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius + 9, soft);
    canvas.drawCircle(center, radius - 24, soft..strokeWidth = 1.4);

    final path = Path()
      ..moveTo(center.dx - 4, center.dy - 18)
      ..cubicTo(center.dx + 48, center.dy - 6, center.dx + 34, center.dy + 18,
          center.dx - 2, center.dy + 30)
      ..cubicTo(center.dx - 58, center.dy + 49, center.dx - 26, center.dy + 72,
          center.dx + 48, center.dy + 92);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.68)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );

    for (final dot in [
      Offset(center.dx - radius, center.dy - 6),
      Offset(center.dx + radius * 0.74, center.dy - radius * 0.70),
      Offset(center.dx + radius * 0.72, center.dy + radius * 0.64),
      Offset(center.dx - radius * 0.72, center.dy + radius * 0.72),
    ]) {
      canvas.drawCircle(dot, 6, Paint()..color = Colors.white);
      canvas.drawCircle(
        dot,
        3.3,
        Paint()..color = AuroraColors.purple.withValues(alpha: 0.70),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WeeklyPagerPage {
  final String title;
  final List<Widget> children;

  const _WeeklyPagerPage({
    required this.title,
    required this.children,
  });
}

class _WeeklyPager extends StatefulWidget {
  final List<_WeeklyPagerPage> pages;

  const _WeeklyPager({required this.pages});

  @override
  State<_WeeklyPager> createState() => _WeeklyPagerState();
}

class _WeeklyPagerState extends State<_WeeklyPager> {
  static const _qaInitialPage =
      int.fromEnvironment('SIGNALPATH_WEEKLY_PAGE', defaultValue: 0);
  late final PageController _pageController;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = _qaInitialPage.clamp(0, widget.pages.length - 1);
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _setPage(int index) {
    if (index == _currentPage) return;
    setState(() => _currentPage = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Row(
            children: [
              for (var index = 0; index < widget.pages.length; index++) ...[
                Expanded(
                  child: _WeeklyPageTab(
                    label: widget.pages[index].title,
                    selected: index == _currentPage,
                    onTap: () => _setPage(index),
                  ),
                ),
                if (index < widget.pages.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        Expanded(
          child: PageView.builder(
            key: const ValueKey('weekly-page-view'),
            controller: _pageController,
            itemCount: widget.pages.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              return ListView(
                key: PageStorageKey<String>('weekly-page-$index'),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 132),
                children: widget.pages[index].children,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _WeeklyPageTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _WeeklyPageTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? AuroraColors.purple.withValues(alpha: 0.13)
                  : Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? AuroraColors.purple.withValues(alpha: 0.36)
                    : AuroraColors.line,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AuroraColors.purple.withValues(alpha: 0.10),
                        blurRadius: 14,
                        offset: const Offset(0, 7),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: theme.textTheme.labelMedium?.copyWith(
                color: selected ? AuroraColors.purple : AuroraColors.muted,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WeeklyDrainChainCard extends StatelessWidget {
  final WeeklyV3CStructureModel structure;

  const _WeeklyDrainChainCard({required this.structure});

  @override
  Widget build(BuildContext context) {
    final nodes = _weeklyDrainNodes(context, structure);
    return AuroraCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocaleText.tr(
              context,
              en: 'Main drain chain',
              zhHans: '主要消耗链',
              zhHant: '主要消耗鏈',
              ja: '主な消耗の流れ',
            ),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < nodes.length; i++) ...[
                Expanded(
                  child: Column(
                    children: [
                      AuroraSoftIconCircle(
                        icon: nodes[i].icon,
                        color: nodes[i].color,
                        size: 48,
                        iconSize: 23,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        nodes[i].label,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: AuroraColors.ink,
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                ),
                      ),
                    ],
                  ),
                ),
                if (i != nodes.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 22,
                      color: AuroraColors.muted.withValues(alpha: 0.66),
                    ),
                  ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Text(
            structure.onePattern,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AuroraColors.muted,
                  height: 1.35,
                ),
          ),
        ],
      ),
    );
  }

  List<_WeeklyDrainNode> _weeklyDrainNodes(
    BuildContext context,
    WeeklyV3CStructureModel structure,
  ) {
    final pattern = _compactNodeLabel(structure.onePattern);
    final experiment = _compactNodeLabel(structure.oneExperiment);
    final positive = _compactNodeLabel(structure.positiveSignal);
    return [
      _WeeklyDrainNode(
        label: pattern.isNotEmpty
            ? pattern
            : AppLocaleText.tr(
                context,
                en: 'Main pattern',
                zhHans: '主要模式',
                zhHant: '主要模式',
                ja: '主なパターン',
              ),
        icon: Icons.center_focus_strong_rounded,
        color: AuroraColors.purple,
      ),
      _WeeklyDrainNode(
        label: AppLocaleText.tr(
          context,
          en: 'Drain point',
          zhHans: '消耗点',
          zhHant: '消耗點',
          ja: '消耗点',
        ),
        icon: Icons.bolt_rounded,
        color: AuroraColors.orange,
      ),
      _WeeklyDrainNode(
        label: AppLocaleText.tr(
          context,
          en: 'Energy load',
          zhHans: '能量负荷',
          zhHant: '能量負荷',
          ja: '負荷',
        ),
        icon: Icons.battery_saver_rounded,
        color: AuroraColors.blue,
      ),
      _WeeklyDrainNode(
        label: experiment.isNotEmpty
            ? experiment
            : AppLocaleText.tr(
                context,
                en: 'Small experiment',
                zhHans: '小实验',
                zhHant: '小實驗',
                ja: '小さな試み',
              ),
        icon: Icons.science_outlined,
        color: AuroraColors.mint,
      ),
      _WeeklyDrainNode(
        label: positive.isNotEmpty
            ? positive
            : AppLocaleText.tr(
                context,
                en: 'Recovery clue',
                zhHans: '恢复线索',
                zhHant: '恢復線索',
                ja: '回復の手がかり',
              ),
        icon: Icons.wb_twilight_rounded,
        color: AuroraColors.gold,
      ),
    ];
  }

  String _compactNodeLabel(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    final separators = RegExp(r'[：:，,。.\n]');
    final first = trimmed.split(separators).first.trim();
    final source = first.isEmpty ? trimmed : first;
    if (source.runes.length <= 9) return source;
    return String.fromCharCodes(source.runes.take(9));
  }
}

class _WeeklyDrainNode {
  final String label;
  final IconData icon;
  final Color color;

  const _WeeklyDrainNode({
    required this.label,
    required this.icon,
    required this.color,
  });
}

class _DrainSourcesCard extends StatelessWidget {
  final WeeklyInsightModel weekly;
  final EnergyBudgetModel? budget;

  const _DrainSourcesCard({
    required this.weekly,
    required this.budget,
  });

  @override
  Widget build(BuildContext context) {
    final sources = _buildSources(context);
    return AuroraCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                AppLocaleText.tr(
                  context,
                  en: 'Drain sources',
                  zhHans: '消耗来源',
                  zhHant: '消耗來源',
                  ja: '消耗の来源',
                ),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
              ),
              const Spacer(),
              Text(
                AppLocaleText.tr(
                  context,
                  en: 'This week',
                  zhHans: '本周',
                  zhHant: '本週',
                  ja: '今週',
                ),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AuroraColors.muted,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (sources.isEmpty)
            Text(
              AppLocaleText.tr(
                context,
                en: 'A clearer ranking will appear after a few more signals.',
                zhHans: '再多几条信号后，这里会出现更可靠的来源排序。',
                zhHant: '再多幾條信號後，這裡會出現更可靠的來源排序。',
                ja: 'もう少しシグナルが集まると、ここに来源の並びが表示されます。',
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AuroraColors.muted,
                  ),
            )
          else
            for (final source in sources) ...[
              _DrainSourceRow(
                icon: source.icon,
                label: source.label,
                value: source.value,
              ),
              if (source != sources.last) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  List<_DrainSourceData> _buildSources(BuildContext context) {
    final blocks = [...?budget?.blocks]
      ..sort((a, b) => b.count.compareTo(a.count));
    if (blocks.isNotEmpty) {
      final total = blocks.fold<int>(0, (sum, block) => sum + block.count);
      final denominator = total == 0 ? 1 : total;
      return blocks.take(4).map((block) {
        return _DrainSourceData(
          icon: _blockIcon(block.type),
          label: _blockLabel(context, block),
          value: block.count / denominator,
        );
      }).toList();
    }

    final items = [
      ...weekly.frictions.whereType<Map>(),
      ...weekly.patterns.whereType<Map>(),
    ];
    if (items.isEmpty) return const [];
    final take = items.take(4).toList();
    final denominator = take.length;
    return [
      for (var i = 0; i < take.length; i++)
        _DrainSourceData(
          icon: _rankIcon(i),
          label: _itemName(take[i]),
          value: (denominator - i) / denominator,
        ),
    ];
  }

  String _itemName(Map item) {
    final raw = item['name'] ?? item['title'] ?? item['label'];
    final text = raw?.toString().trim() ?? '';
    return text.isEmpty ? 'Signal' : text;
  }

  IconData _rankIcon(int index) {
    const icons = [
      Icons.notifications_none_rounded,
      Icons.calendar_month_rounded,
      Icons.help_outline_rounded,
      Icons.groups_rounded,
    ];
    return icons[index.clamp(0, icons.length - 1)];
  }

  IconData _blockIcon(String type) {
    switch (type) {
      case 'high_switching':
        return Icons.swap_horiz_rounded;
      case 'deep':
        return Icons.center_focus_strong_rounded;
      case 'recovery':
        return Icons.nights_stay_outlined;
      case 'boundary':
        return Icons.health_and_safety_outlined;
      case 'buffer':
        return Icons.hourglass_empty_rounded;
      default:
        return Icons.bolt_rounded;
    }
  }

  String _blockLabel(BuildContext context, EnergyBlockModel block) {
    switch (block.type) {
      case 'high_switching':
        return AppLocaleText.tr(context,
            en: 'Switching load', zhHans: '切换消耗', zhHant: '切換消耗', ja: '切替負荷');
      case 'deep':
        return AppLocaleText.tr(context,
            en: 'Deep work', zhHans: '深度投入', zhHant: '深度投入', ja: '深い作業');
      case 'recovery':
        return AppLocaleText.tr(context,
            en: 'Recovery clue', zhHans: '恢复线索', zhHant: '恢復線索', ja: '回復の手がかり');
      case 'boundary':
        return AppLocaleText.tr(context,
            en: 'Boundary load', zhHans: '边界负荷', zhHant: '邊界負荷', ja: '境界の負荷');
      case 'buffer':
        return AppLocaleText.tr(context,
            en: 'Buffer need', zhHans: '缓冲需求', zhHant: '緩衝需求', ja: '余白の必要');
      default:
        return AppLocaleText.tr(context,
            en: 'High drain', zhHans: '高消耗', zhHant: '高消耗', ja: '高い消耗');
    }
  }
}

class _DrainSourceData {
  final IconData icon;
  final String label;
  final double value;

  const _DrainSourceData({
    required this.icon,
    required this.label,
    required this.value,
  });
}

class _DrainSourceRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;

  const _DrainSourceRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AuroraColors.purple, size: 22),
        const SizedBox(width: 10),
        SizedBox(
          width: 92,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AuroraColors.ink,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(
              children: [
                Container(
                  height: 8,
                  color: AuroraColors.line.withValues(alpha: 0.42),
                ),
                FractionallySizedBox(
                  widthFactor: value.clamp(0.0, 1.0),
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AuroraColors.purple.withValues(alpha: 0.78),
                          AuroraColors.blue.withValues(alpha: 0.58),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 38,
          child: Text(
            '${(value * 100).round()}%',
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AuroraColors.ink,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }
}

class _OneWeeklyFocusCard extends StatelessWidget {
  final WeeklyTopicFocusModel topic;

  const _OneWeeklyFocusCard({required this.topic});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: () => _showWeeklyHint(
        context,
        AppLocaleText.tr(
          context,
          en: 'This is the one direction to keep visible this week.',
          zhHans: '这是这周先放在眼前的一个观察方向。',
          zhHant: '這是這週先放在眼前的一個觀察方向。',
          ja: 'これは今週、まず見える場所に置いておく一つの方向です。',
        ),
      ),
      child: AuroraCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            const AuroraSoftIconCircle(
              icon: Icons.center_focus_strong_rounded,
              color: AuroraColors.purple,
              size: 54,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'One Weekly Focus',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AuroraColors.purple,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    topic.nextWatch,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AuroraColors.ink,
                          height: 1.35,
                        ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AuroraColors.muted),
          ],
        ),
      ),
    );
  }
}

class _TopicFocusCard extends StatelessWidget {
  final WeeklyTopicFocusModel topic;
  final bool isLightReady;

  const _TopicFocusCard({
    required this.topic,
    required this.isLightReady,
  });

  @override
  Widget build(BuildContext context) {
    return _UnifiedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocaleText.tr(
              context,
              en: 'This week’s key topic',
              zhHans: '本周重点议题',
              zhHant: '本週重點議題',
              ja: '今週の重点トピック',
            ),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          const SwitchingGapVisual(),
          const SizedBox(height: 12),
          _TopicRow(
            label: AppLocaleText.tr(
              context,
              en: 'Topic',
              zhHans: '议题',
              zhHant: '議題',
              ja: 'トピック',
            ),
            value: topic.headline,
          ),
          const SizedBox(height: 10),
          _TopicRow(
            label: AppLocaleText.tr(
              context,
              en: 'Why it matters now',
              zhHans: '为什么这周先看这个',
              zhHant: '為什麼這週先看這個',
              ja: 'なぜ今週はこれを見るのか',
            ),
            value: topic.reason,
          ),
          const SizedBox(height: 10),
          _TopicRow(
            label: isLightReady
                ? AppLocaleText.tr(
                    context,
                    en: 'Keep watching',
                    zhHans: '接下来继续看',
                    zhHant: '接下來繼續看',
                    ja: 'このあと見続けること',
                  )
                : AppLocaleText.tr(
                    context,
                    en: 'Watch next week',
                    zhHans: '下周先观察',
                    zhHant: '下週先觀察',
                    ja: '来週はまず何を見るか',
                  ),
            value: topic.nextWatch,
          ),
        ],
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  final String label;
  final String value;

  const _TopicRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 4),
        Text(value),
      ],
    );
  }
}

class _WeeklyV3CStructureCard extends StatelessWidget {
  final WeeklyV3CStructureModel structure;
  final bool isLightReady;

  const _WeeklyV3CStructureCard({
    required this.structure,
    required this.isLightReady,
  });

  @override
  Widget build(BuildContext context) {
    return _UnifiedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocaleText.tr(
              context,
              en: 'This week, you can look at it this way',
              zhHans: '这周可以先这样看',
              zhHant: '這週可以先這樣看',
              ja: '今週はまずこう見てみる',
            ),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          const ExperimentPathVisual(),
          const SizedBox(height: 8),
          _WeeklyStructureRow(
            icon: Icons.notes_outlined,
            label: AppLocaleText.tr(
              context,
              en: 'Small observation',
              zhHans: '本周小观察',
              zhHant: '本週小觀察',
              ja: '今週の小さな観察',
            ),
            value: structure.lightObservation,
          ),
          const SizedBox(height: 12),
          _WeeklyStructureRow(
            icon: Icons.blur_linear_outlined,
            label: AppLocaleText.tr(
              context,
              en: 'One pattern',
              zhHans: '一个最消耗的模式',
              zhHant: '一個最消耗的模式',
              ja: '一つの消耗 pattern',
            ),
            value: structure.onePattern,
          ),
          const SizedBox(height: 12),
          _WeeklyStructureRow(
            icon: Icons.science_outlined,
            label: AppLocaleText.tr(
              context,
              en: 'One small experiment',
              zhHans: '一个低成本小实验',
              zhHant: '一個低成本小實驗',
              ja: '一つの小さな実験',
            ),
            value: structure.oneExperiment,
          ),
          const SizedBox(height: 12),
          _WeeklyStructureRow(
            icon: Icons.spa_outlined,
            label: AppLocaleText.tr(
              context,
              en: 'Recovery signal',
              zhHans: '一个恢复线索',
              zhHant: '一個恢復線索',
              ja: '回復の手がかり',
            ),
            value: structure.positiveSignal,
          ),
        ],
      ),
    );
  }
}

class _WeeklyStructureRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _WeeklyStructureRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              Text(value),
            ],
          ),
        ),
      ],
    );
  }
}

class _EnergyBudgetLiteCard extends StatelessWidget {
  final EnergyBudgetModel? budget;

  const _EnergyBudgetLiteCard({
    required this.budget,
  });

  @override
  Widget build(BuildContext context) {
    final value = budget;
    final isFallback = value == null || value.status == 'insufficient_data';

    return _UnifiedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Energy Budget',
                    zhHans: '本周 Energy Budget',
                    zhHant: '本週 Energy Budget',
                    ja: '今週の Energy Budget',
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF213052),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: AuroraColors.purple.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: AuroraColors.purple.withValues(alpha: 0.16),
                  ),
                ),
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: isFallback ? 'Forming' : 'Initial read',
                    zhHans: isFallback ? '形成中' : '初步形成',
                    zhHant: isFallback ? '形成中' : '初步形成',
                    ja: isFallback ? '形成中' : '初期の見立て',
                  ),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AuroraColors.purple,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isFallback)
            _EnergyBudgetRow(
              label: AppLocaleText.tr(
                context,
                en: 'Energy change',
                zhHans: '能量变化',
                zhHant: '能量變化',
                ja: 'エネルギー変化',
              ),
              value: value?.mostDrainingSource.trim().isNotEmpty == true
                  ? value!.mostDrainingSource
                  : AppLocaleText.tr(
                      context,
                      en: 'Energy signals are still forming. Keep the next experiment very small.',
                      zhHans: '能量线索还在形成中，下周小实验先保持很小。',
                      zhHant: '能量線索還在形成中，下週小實驗先保持很小。',
                      ja: 'エネルギーの手がかりは形成中です。次の実験は小さくします。',
                    ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final tiles = [
                  _EnergyBudgetCompactTile(
                    icon: Icons.bolt_rounded,
                    color: AuroraColors.orange,
                    label: AppLocaleText.tr(
                      context,
                      en: 'Costly point',
                      zhHans: '最耗力',
                      zhHant: '最耗力',
                      ja: '最も消耗',
                    ),
                    value: value.mostDrainingSource,
                  ),
                  _EnergyBudgetCompactTile(
                    icon: Icons.eco_rounded,
                    color: AuroraColors.mint,
                    label: AppLocaleText.tr(
                      context,
                      en: 'Recovery clue',
                      zhHans: '恢复线索',
                      zhHant: '恢復線索',
                      ja: '回復の手がかり',
                    ),
                    value: value.recoveryClue,
                  ),
                  _EnergyBudgetCompactTile(
                    icon: Icons.schedule_rounded,
                    color: AuroraColors.blue,
                    label: AppLocaleText.tr(
                      context,
                      en: 'Needs buffer',
                      zhHans: '需要缓冲',
                      zhHant: '需要緩衝',
                      ja: '余白が必要',
                    ),
                    value: value.bufferLocation,
                  ),
                  _EnergyBudgetCompactTile(
                    icon: Icons.swap_horiz_rounded,
                    color: AuroraColors.purple,
                    label: AppLocaleText.tr(
                      context,
                      en: 'Switching load',
                      zhHans: '切换负荷',
                      zhHant: '切換負荷',
                      ja: '切替負荷',
                    ),
                    value: value.switchingAdjustment,
                  ),
                ];
                if (constraints.maxWidth < 300) {
                  return Column(
                    children: [
                      for (var i = 0; i < tiles.length; i++) ...[
                        tiles[i],
                        if (i != tiles.length - 1) const SizedBox(height: 8),
                      ],
                    ],
                  );
                }
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: tiles[0]),
                        const SizedBox(width: 8),
                        Expanded(child: tiles[1]),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: tiles[2]),
                        const SizedBox(width: 8),
                        Expanded(child: tiles[3]),
                      ],
                    ),
                  ],
                );
              },
            ),
          const SizedBox(height: 10),
          Text(
            isFallback
                ? _energyStrengthText(context, value)
                : AppLocaleText.tr(
                    context,
                    en: 'Next-week candidates will prioritize light, low-switching, pausable experiments.',
                    zhHans: '下周候选将优先采用 3–5 分钟、低切换、可暂停的轻量尝试。',
                    zhHant: '下週候選將優先採用 3–5 分鐘、低切換、可暫停的輕量嘗試。',
                    ja: '来週は短時間・切替少なめ・中断できる軽い候補を優先します。',
                  ),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF536077),
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _EnergyBudgetCompactTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _EnergyBudgetCompactTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 78),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AuroraColors.line.withValues(alpha: 0.66)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: const Color(0xFF22304A),
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  value.trim().isEmpty ? '—' : value.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF536077),
                        height: 1.3,
                        fontWeight: FontWeight.w600,
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

class _EnergyBudgetRows extends StatelessWidget {
  final EnergyBudgetModel? budget;

  const _EnergyBudgetRows({required this.budget});

  @override
  Widget build(BuildContext context) {
    final value = budget;
    if (value == null || value.status == 'insufficient_data') {
      return _EnergyBudgetRow(
        label: AppLocaleText.tr(
          context,
          en: 'Energy change',
          zhHans: '能量变化',
          zhHant: '能量變化',
          ja: 'エネルギー変化',
        ),
        value: value?.mostDrainingSource.trim().isNotEmpty == true
            ? value!.mostDrainingSource
            : AppLocaleText.tr(
                context,
                en: 'Energy signals are still forming. The next experiment should stay very small.',
                zhHans: '能量线索还在形成中，下周小实验先保持很小。',
                zhHant: '能量線索還在形成中，下週小實驗先保持很小。',
                ja: 'エネルギーの手がかりは形成中です。次の実験はとても小さくします。',
              ),
      );
    }

    final rows = [
      (
        AppLocaleText.tr(
          context,
          en: 'Costly point',
          zhHans: '耗力点',
          zhHant: '耗力點',
          ja: '消耗点',
        ),
        value.mostDrainingSource
      ),
      (
        AppLocaleText.tr(
          context,
          en: 'Recovery clue',
          zhHans: '恢复线索',
          zhHant: '恢復線索',
          ja: '回復の手がかり',
        ),
        value.recoveryClue
      ),
      (
        AppLocaleText.tr(
          context,
          en: 'Experiment strength',
          zhHans: '实验强度',
          zhHant: '實驗強度',
          ja: '実験の強さ',
        ),
        _energyStrengthText(context, value)
      ),
    ].where((row) => row.$2.trim().isNotEmpty).toList();

    return Column(
      children: [
        for (final row in rows.take(3))
          _EnergyBudgetRow(label: row.$1, value: row.$2),
      ],
    );
  }
}

class _EnergyIntensityPill extends StatelessWidget {
  final EnergyBudgetModel? budget;

  const _EnergyIntensityPill({required this.budget});

  @override
  Widget build(BuildContext context) {
    final label = _energyStrengthText(context, budget);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AuroraColors.blue.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: AuroraColors.blue.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.battery_saver_rounded,
              size: 16,
              color: AuroraColors.blue,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AuroraColors.blue,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _energyStrengthText(BuildContext context, EnergyBudgetModel? budget) {
  final value = budget;
  if (value == null || value.status == 'insufficient_data') {
    return AppLocaleText.tr(
      context,
      en: 'Very light experiment',
      zhHans: '先用很轻的小实验',
      zhHant: '先用很輕的小實驗',
      ja: 'とても軽い実験',
    );
  }

  final hasHighLoad = value.blocks.any(
      (block) => block.type == 'high_drain' || block.type == 'high_switching');
  final hasRecovery = value.blocks.any((block) => block.type == 'recovery');

  if (hasHighLoad) {
    return AppLocaleText.tr(
      context,
      en: 'Lower the experiment intensity',
      zhHans: '根据能量变化调轻实验强度',
      zhHant: '根據能量變化調輕實驗強度',
      ja: 'エネルギーに合わせて実験を軽くする',
    );
  }
  if (hasRecovery) {
    return AppLocaleText.tr(
      context,
      en: 'Keep the recovery-friendly version',
      zhHans: '保留更容易恢复的版本',
      zhHant: '保留更容易恢復的版本',
      ja: '回復しやすい形で続ける',
    );
  }
  return AppLocaleText.tr(
    context,
    en: 'Keep it small and buffered',
    zhHans: '保持小一点，并留出余地',
    zhHant: '保持小一點，並留出餘地',
    ja: '小さく、余白を残す',
  );
}

class _EnergyDistributionBar extends StatelessWidget {
  final List<EnergyBlockModel> blocks;

  const _EnergyDistributionBar({required this.blocks});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (blocks.isEmpty) {
      return Text(
        AppLocaleText.tr(
          context,
          en: 'Energy blocks will appear here once a few signals have enough shape.',
          zhHans: '等几条信号更成形后，这里会出现轻量能量块。',
          zhHant: '等幾條信號更成形後，這裡會出現輕量能量塊。',
          ja: 'いくつかのシグナルが見えてくると、ここに小さな energy block が表示されます。',
        ),
        style: theme.textTheme.bodySmall,
      );
    }

    final total = blocks.fold<int>(0, (sum, block) => sum + block.count);
    final safeTotal = total == 0 ? 1 : total;
    final colors = <Color>[
      const Color(0xFF8B7CF6),
      const Color(0xFFFF9B58),
      const Color(0xFFFFCD62),
      const Color(0xFF74D58C),
      const Color(0xFF64A8F7),
    ];
    final visibleBlocks = blocks.take(5).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final block in visibleBlocks)
              Text(
                '${(block.count * 100 / safeTotal).round()}%',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 16,
            child: Row(
              children: [
                for (var i = 0; i < visibleBlocks.length; i++)
                  Expanded(
                    flex: (visibleBlocks[i].count * 100 / safeTotal)
                        .round()
                        .clamp(1, 100),
                    child: Container(
                      height: 16,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colors[i % colors.length].withValues(alpha: 0.92),
                            colors[i % colors.length].withValues(alpha: 0.62),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            for (var i = 0; i < visibleBlocks.length; i++)
              _EnergyLegendItem(
                color: colors[i % colors.length],
                label: _energyBlockLabel(context, visibleBlocks[i]),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          AppLocaleText.tr(
            context,
            en: 'Display only: this helps read distribution, not performance.',
            zhHans: '仅用于展示分布，不是表现评分。',
            zhHant: '僅用於展示分布，不是表現評分。',
            ja: '表示のみです。分布を見るためのもので、評価ではありません。',
          ),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  String _energyBlockLabel(BuildContext context, EnergyBlockModel block) {
    switch (block.type) {
      case 'high_drain':
      case 'high-drain':
      case 'high-drain block':
        return AppLocaleText.tr(
          context,
          en: 'drain',
          zhHans: '耗力',
          zhHant: '耗力',
          ja: '消耗',
        );
      case 'high_switching':
      case 'high-switching':
      case 'high-switching block':
        return AppLocaleText.tr(
          context,
          en: 'switching',
          zhHans: '切换',
          zhHant: '切換',
          ja: '切替',
        );
      case 'recovery':
      case 'recovery block':
        return AppLocaleText.tr(
          context,
          en: 'recovery',
          zhHans: '恢复',
          zhHant: '恢復',
          ja: '回復',
        );
      case 'boundary':
      case 'boundary block':
        return AppLocaleText.tr(
          context,
          en: 'boundary',
          zhHans: '边界',
          zhHant: '邊界',
          ja: '境界',
        );
      case 'buffer':
      case 'buffer block':
        return AppLocaleText.tr(
          context,
          en: 'buffer',
          zhHans: '余地',
          zhHant: '餘地',
          ja: '余白',
        );
      default:
        return block.label;
    }
  }
}

class _EnergyLegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _EnergyLegendItem({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.28),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _EnergyBudgetRow extends StatelessWidget {
  final String label;
  final String value;

  const _EnergyBudgetRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 3),
          Text(value),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final String text;

  const _MetaPill(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(text, style: theme.textTheme.labelSmall),
      ),
    );
  }
}

class _WeeklyActionReviewCard extends StatelessWidget {
  final WeeklyActionReviewModel review;

  const _WeeklyActionReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _UnifiedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.route_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Small action review',
                    zhHans: '本周小行动复盘',
                    zhHant: '本週小行動回顧',
                    ja: '今週の小さな行動の振り返り',
                  ),
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionReviewChip(
                label: AppLocaleText.tr(
                  context,
                  en: 'AI predictions',
                  zhHans: 'AI 预判',
                  zhHant: 'AI 預判',
                  ja: 'AI 予測',
                ),
                value: review.aiJudgementCount,
                color: AuroraColors.purple,
              ),
              _ActionReviewChip(
                label: AppLocaleText.tr(
                  context,
                  en: 'Confirmed',
                  zhHans: '用户确认',
                  zhHant: '使用者確認',
                  ja: '確認済み',
                ),
                value: review.confirmedJudgementCount,
                color: AuroraColors.mint,
              ),
              _ActionReviewChip(
                label: AppLocaleText.tr(
                  context,
                  en: 'Actions',
                  zhHans: '生成小行动',
                  zhHant: '生成小行動',
                  ja: '小さな行動',
                ),
                value: review.generatedActionCount,
                color: AuroraColors.blue,
              ),
              _ActionReviewChip(
                label: AppLocaleText.tr(
                  context,
                  en: 'Tried',
                  zhHans: '实际尝试',
                  zhHant: '實際嘗試',
                  ja: '試した',
                ),
                value: review.triedActionCount,
                color: AuroraColors.gold,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _reviewSentence(context),
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
          if (review.mostHelpfulAction.trim().isNotEmpty ||
              review.hardestAction.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _ActionReviewLine(
              icon: Icons.favorite_outline_rounded,
              label: AppLocaleText.tr(
                context,
                en: 'Most helpful',
                zhHans: '最有帮助',
                zhHant: '最有幫助',
                ja: '助けになったこと',
              ),
              value: review.mostHelpfulAction.trim().isNotEmpty
                  ? review.mostHelpfulAction
                  : AppLocaleText.tr(
                      context,
                      en: 'Still forming',
                      zhHans: '还在形成',
                      zhHant: '還在形成',
                      ja: 'まだ形成中',
                    ),
              color: AuroraColors.mint,
            ),
            const SizedBox(height: 8),
            _ActionReviewLine(
              icon: Icons.tune_rounded,
              label: AppLocaleText.tr(
                context,
                en: 'Needs adjustment',
                zhHans: '需要调整',
                zhHant: '需要調整',
                ja: '調整したいこと',
              ),
              value: review.hardestAction.trim().isNotEmpty
                  ? review.hardestAction
                  : review.nextAdjustment,
              color: AuroraColors.orange,
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionDecisionButton(
                label: AppLocaleText.tr(
                  context,
                  en: 'Continue',
                  zhHans: '继续这个方向',
                  zhHant: '繼續這個方向',
                  ja: 'この方向を続ける',
                ),
              ),
              _ActionDecisionButton(
                label: AppLocaleText.tr(
                  context,
                  en: 'Make it lighter',
                  zhHans: '调轻一点',
                  zhHant: '調輕一點',
                  ja: '軽くする',
                ),
              ),
              _ActionDecisionButton(
                label: AppLocaleText.tr(
                  context,
                  en: 'Try another',
                  zhHans: '换一个策略',
                  zhHant: '換一個策略',
                  ja: '別の方法へ',
                ),
              ),
              _ActionDecisionButton(
                label: AppLocaleText.tr(
                  context,
                  en: 'Pause',
                  zhHans: '暂时不做',
                  zhHant: '暫時不做',
                  ja: 'いったん休む',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _reviewSentence(BuildContext context) {
    if (!review.hasData) {
      return AppLocaleText.tr(
        context,
        en: 'No action loop has settled yet. This week can still be read as a small observation.',
        zhHans: '这一周还没有形成明确的小行动闭环，先把它当作一个小观察。',
        zhHant: '這一週還沒有形成明確的小行動閉環，先把它當作一個小觀察。',
        ja: '今週はまだ小さな行動の循環がはっきりしていません。小さな観察として扱います。',
      );
    }
    return AppLocaleText.tr(
      context,
      en: '${review.aiJudgementCount} AI prediction(s), ${review.confirmedJudgementCount} confirmed, ${review.generatedActionCount} small action(s), ${review.triedActionCount} tried. Next: ${review.nextAdjustment}',
      zhHans:
          '这周有 ${review.aiJudgementCount} 条 AI 预判，${review.confirmedJudgementCount} 条被确认，生成 ${review.generatedActionCount} 个小行动，实际尝试 ${review.triedActionCount} 个。下周可以先看：${review.nextAdjustment}',
      zhHant:
          '這週有 ${review.aiJudgementCount} 條 AI 預判，${review.confirmedJudgementCount} 條被確認，生成 ${review.generatedActionCount} 個小行動，實際嘗試 ${review.triedActionCount} 個。下週可以先看：${review.nextAdjustment}',
      ja: '今週は AI 予測が ${review.aiJudgementCount} 件、確認済みが ${review.confirmedJudgementCount} 件、小さな行動が ${review.generatedActionCount} 件、試したものが ${review.triedActionCount} 件。次は「${review.nextAdjustment}」を見ます。',
    );
  }
}

class _ActionReviewChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _ActionReviewChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Text(
        '$label $value',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _ActionReviewLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ActionReviewLine({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$label：$value',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AuroraColors.muted,
                  height: 1.35,
                ),
          ),
        ),
      ],
    );
  }
}

class _ActionDecisionButton extends StatelessWidget {
  final String label;

  const _ActionDecisionButton({required this.label});

  @override
  Widget build(BuildContext context) {
    return AuroraPillButton(
      icon: Icons.check_circle_outline_rounded,
      label: label,
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocaleText.tr(
                context,
                en: 'Saved for the next review.',
                zhHans: '已保存到下一次回看。',
                zhHant: '已保存到下一次回看。',
                ja: '次の振り返りに保存しました。',
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WeeklyInclusionCard extends StatelessWidget {
  final WeeklyInclusionSummaryModel inclusion;

  const _WeeklyInclusionCard({required this.inclusion});

  @override
  Widget build(BuildContext context) {
    return _UnifiedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocaleText.tr(
              context,
              en: 'How your notes were used',
              zhHans: '这些记录是怎么被使用的',
              zhHant: '這些記錄是怎麼被使用的',
              ja: '記録の使われ方',
            ),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Text(
            _summaryText(context),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            AppLocaleText.tr(
              context,
              en: 'Notes marked not quite right or kept out of analysis stay in your Timeline, but are not used for this Weekly.',
              zhHans: '被标记为不太准、或不参与分析的记录，会保留在时间线里，但不会被当成这周判断材料。',
              zhHant: '被標記為不太準、或不參與分析的記錄，會保留在時間線裡，但不會被當成這週判斷材料。',
              ja: 'しっくりこない記録や分析から外した記録はタイムラインに残りますが、今週の見立てには使いません。',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  String _summaryText(BuildContext context) {
    final used = inclusion.usedCount;
    final timelineOnly = inclusion.timelineOnlyCount;
    final legacy = inclusion.legacyReferenceCount;

    return AppLocaleText.tr(
      context,
      en: '$used notes were used for this Weekly. $timelineOnly stayed only in Timeline. $legacy older notes were treated as gentle context.',
      zhHans:
          '$used 条记录进入了这份 Weekly，$timelineOnly 条只保留在 Timeline。$legacy 条旧记录只作为轻量背景参考。',
      zhHant:
          '$used 條記錄進入了這份 Weekly，$timelineOnly 條只保留在 Timeline。$legacy 條舊記錄只作為輕量背景參考。',
      ja: '$used 件の記録をこの Weekly に使いました。$timelineOnly 件は Timeline にだけ残しています。$legacy 件の古い記録は軽い背景として扱いました。',
    );
  }
}

class _LifeExperimentCard extends StatelessWidget {
  final WeeklyActionPlanModel actionPlan;
  final LifeExperimentModel experiment;
  final SubmitState submitState;
  final Future<void> Function() onSave;
  final Future<void> Function() onSkip;
  final Future<void> Function({
    required String status,
    required String feedbackText,
  }) onFeedback;

  const _LifeExperimentCard({
    required this.actionPlan,
    required this.experiment,
    required this.submitState,
    required this.onSave,
    required this.onSkip,
    required this.onFeedback,
  });

  bool get _isSubmitting => submitState == SubmitState.submitting;

  @override
  Widget build(BuildContext context) {
    final isSaved = experiment.status == 'saved';
    final hasFeedback = const {
      'tried',
      'not_helpful',
      'adjusted',
    }.contains(experiment.status);

    return _UnifiedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.science_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Weekly Action Plan',
                    zhHans: '下周小实验计划',
                    zhHant: '下週小實驗計畫',
                    ja: '来週の小さな実験計画',
                  ),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            AppLocaleText.tr(
              context,
              en: 'One medium-range adjustment from this week. Save it to let Today turn it into small optional actions next week.',
              zhHans: '这是从本周信号里提炼出的一个中期调整。保存后，下周 Today 会把它变成可选的小行动。',
              zhHant: '這是從本週信號裡提煉出的一個中期調整。保存後，下週 Today 會把它變成可選的小行動。',
              ja: '今週のシグナルから生まれた中期の調整です。保存すると、来週のTodayで小さな任意の行動になります。',
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AuroraColors.muted,
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 12),
          Text(actionPlan.title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(
            AppLocaleText.tr(
              context,
              en: 'Medium-range goal: ${actionPlan.mediumRangeGoal}',
              zhHans: '中期改善目标：${actionPlan.mediumRangeGoal}',
              zhHant: '中期改善目標：${actionPlan.mediumRangeGoal}',
              ja: '中期の調整目標：${actionPlan.mediumRangeGoal}',
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AuroraColors.muted,
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 6),
          Text(actionPlan.smallExperiment),
          const SizedBox(height: 10),
          Text(
            AppLocaleText.tr(
              context,
              en: 'The experiment archive keeps the record and feedback later; Weekly only proposes the next small experiment.',
              zhHans: '小实验档案负责保存记录和反馈；Weekly 这里只提出下周可以试的小实验。',
              zhHant: '小實驗檔案負責保存記錄和回饋；Weekly 这里只提出下週可以試的小實驗。',
              ja: '実験アーカイブは記録と反応を残す場所です。Weekly は来週試す小さな実験だけを提案します。',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (experiment.status == 'skipped')
            Text(
              AppLocaleText.tr(
                context,
                en: 'Skipped for now. It stays as context, not a miss.',
                zhHans: '这次先不看。它会作为背景留下，不算错过。',
                zhHant: '這次先不看。它會作為背景留下，不算錯過。',
                ja: '今回は見送っています。失敗ではなく、背景として残ります。',
              ),
            )
          else if (hasFeedback)
            Text(
              AppLocaleText.tr(
                context,
                en: 'Your feedback is saved for the next review.',
                zhHans: '你的反馈已经保存，会进入下一次回看。',
                zhHant: '你的回饋已經保存，會進入下一次回看。',
                ja: 'フィードバックは次の振り返り用に保存されています。',
              ),
            )
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _isSubmitting || isSaved ? null : onSave,
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: Text(
                    AppLocaleText.tr(
                      context,
                      en: isSaved ? 'Saved' : 'Save',
                      zhHans: isSaved ? '已保存' : '保存',
                      zhHant: isSaved ? '已保存' : '保存',
                      ja: isSaved ? '保存済み' : '保存',
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _isSubmitting ? null : onSkip,
                  child: Text(
                    AppLocaleText.tr(
                      context,
                      en: 'Not now',
                      zhHans: '稍后再看',
                      zhHant: '稍後再看',
                      ja: '今は見送る',
                    ),
                  ),
                ),
              ],
            ),
            if (isSaved) ...[
              const SizedBox(height: 12),
              Text(
                AppLocaleText.tr(
                  context,
                  en: 'Did this design save you a little energy?',
                  zhHans: '这个尝试有没有帮你省一点力？',
                  zhHant: '這個嘗試有沒有幫你省一點力？',
                  ja: 'この設計は少し楽にしてくれましたか？',
                ),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: _isSubmitting
                        ? null
                        : () => onFeedback(
                              status: 'tried',
                              feedbackText: 'Helped a little',
                            ),
                    child: Text(
                      AppLocaleText.tr(
                        context,
                        en: 'Helped a little',
                        zhHans: '有一点帮助',
                        zhHant: '有一點幫助',
                        ja: '少し助かった',
                      ),
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: _isSubmitting
                        ? null
                        : () => onFeedback(
                              status: 'adjusted',
                              feedbackText: 'Needs adjustment',
                            ),
                    child: Text(
                      AppLocaleText.tr(
                        context,
                        en: 'Needs adjustment',
                        zhHans: '需要调整',
                        zhHant: '需要調整',
                        ja: '調整したい',
                      ),
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: _isSubmitting
                        ? null
                        : () => onFeedback(
                              status: 'not_helpful',
                              feedbackText: 'Not helpful this time',
                            ),
                    child: Text(
                      AppLocaleText.tr(
                        context,
                        en: 'Not helpful this time',
                        zhHans: '这次帮助不明显',
                        zhHant: '這次幫助不明顯',
                        ja: '今回はあまり合わない',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _CompositeChartCard extends StatelessWidget {
  final List<WeeklyChartPointModel> points;
  final bool isLightReady;

  const _CompositeChartCard({
    required this.points,
    required this.isLightReady,
  });

  @override
  Widget build(BuildContext context) {
    final safePoints = points.isEmpty ? _emptyWeekPoints() : points;
    final humanSummary = _buildHumanSummary(context, safePoints, isLightReady);

    return _UnifiedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocaleText.tr(
              context,
              en: 'Signal density and weekly trend',
              zhHans: '线索密度与本周走势',
              zhHant: '線索密度與本週走勢',
              ja: '手がかりの密度と今週の流れ',
            ),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            humanSummary,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 220,
            width: double.infinity,
            child: _CompositeWeeklyChart(points: safePoints),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              _LegendItem(
                label: AppLocaleText.tr(
                  context,
                  en: 'Bars = signal count',
                  zhHans: '柱状 = 线索数量',
                  zhHant: '柱狀 = 線索數量',
                  ja: '棒 = 手がかりの数',
                ),
                kind: _LegendKind.bar,
              ),
              _LegendItem(
                label: AppLocaleText.tr(
                  context,
                  en: 'Line = weekly trend',
                  zhHans: '折线 = 本周走势',
                  zhHant: '折線 = 本週走勢',
                  ja: '折れ線 = 今週の流れ',
                ),
                kind: _LegendKind.line,
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<WeeklyChartPointModel> _emptyWeekPoints() {
    return List.generate(
      7,
      (index) => WeeklyChartPointModel(
        date: 'day$index',
        signalCount: 0,
        moodScore: 0,
        frictionScore: 0,
        hasPositiveSignal: false,
      ),
    );
  }

  String _buildHumanSummary(
    BuildContext context,
    List<WeeklyChartPointModel> points,
    bool isLightReady,
  ) {
    final peak = points.reduce(
      (a, b) => a.signalCount >= b.signalCount ? a : b,
    );
    final avgMood = points.isEmpty
        ? 0.0
        : points.map((e) => e.moodScore).reduce((a, b) => a + b) /
            points.length;

    final peakDay = _dayLabel(context, peak.date);

    if (isLightReady) {
      if (peak.signalCount <= 0) {
        return AppLocaleText.tr(
          context,
          en: 'Signals are starting to gather, but it is still too early to say much more.',
          zhHans: '线索已经开始聚起来了，但现在还比较早，先不下太重判断。',
          zhHant: '線索已經開始聚起來了，但現在還比較早，先不下太重判斷。',
          ja: '手がかりは集まり始めていますが、まだ早いので、ここでは重い判断はしません。',
        );
      }
      return AppLocaleText.tr(
        context,
        en: 'For now, the densest day is $peakDay, and the weekly trend is ${avgMood >= 0 ? 'not clearly falling' : 'a little pulled downward'}.',
        zhHans:
            '目前线索最集中的一天是$peakDay，这一周的走势${avgMood >= 0 ? '没有明显往下掉' : '有一点被往下拉'}。',
        zhHant:
            '目前線索最集中的一天是$peakDay，這一週的走勢${avgMood >= 0 ? '沒有明顯往下掉' : '有一點被往下拉'}。',
        ja: '今のところ、手がかりがいちばん集まっているのは$peakDayで、今週の流れは${avgMood >= 0 ? '大きく下がってはいません' : '少し下に引かれています'}。',
      );
    }

    return AppLocaleText.tr(
      context,
      en: 'The bars show where this week’s signals gathered most, and the line shows whether the weekly trend was lifting or dropping.',
      zhHans: '柱状能看到这周线索最集中的是哪几天，折线则能看到这一周的走势是在往上走还是往下掉。',
      zhHant: '柱狀能看到這週線索最集中的是哪幾天，折線則能看到這一週的走勢是在往上走還是往下掉。',
      ja: '棒を見ると今週の手がかりがどの日に集まったかがわかり、折れ線を見ると今週の流れが上向きだったか下向きだったかが見えてきます。',
    );
  }

  String _dayLabel(BuildContext context, String date) {
    if (date.length >= 10 && date.contains('-')) {
      return date.substring(5);
    }
    return AppLocaleText.tr(
      context,
      en: 'this week',
      zhHans: '这周',
      zhHant: '這週',
      ja: '今週',
    );
  }
}

class _CompositeWeeklyChart extends StatelessWidget {
  final List<WeeklyChartPointModel> points;

  const _CompositeWeeklyChart({
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CompositeWeeklyChartPainter(
        points: points,
        textDirection: Directionality.of(context),
      ),
      child: Container(),
    );
  }
}

class _CompositeWeeklyChartPainter extends CustomPainter {
  final List<WeeklyChartPointModel> points;
  final TextDirection textDirection;

  _CompositeWeeklyChartPainter({
    required this.points,
    required this.textDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const topPad = 14.0;
    const rightPad = 10.0;
    const bottomPad = 34.0;
    const leftPad = 10.0;

    final chartRect = Rect.fromLTWH(
      leftPad,
      topPad,
      size.width - leftPad - rightPad,
      size.height - topPad - bottomPad,
    );

    final baseLineY = chartRect.bottom;
    final midLineY = chartRect.top + chartRect.height / 2;

    final gridPaint = Paint()
      ..color = Colors.grey.withAlpha(70)
      ..strokeWidth = 1;

    final axisPaint = Paint()
      ..color = Colors.grey.withAlpha(120)
      ..strokeWidth = 1.2;

    canvas.drawLine(
      Offset(chartRect.left, baseLineY),
      Offset(chartRect.right, baseLineY),
      axisPaint,
    );
    canvas.drawLine(
      Offset(chartRect.left, midLineY),
      Offset(chartRect.right, midLineY),
      gridPaint,
    );
    canvas.drawLine(
      Offset(chartRect.left, chartRect.top),
      Offset(chartRect.right, chartRect.top),
      gridPaint,
    );

    final maxSignal = math.max(
      1,
      points.map((e) => e.signalCount).fold<int>(0, math.max),
    );

    final segmentWidth = chartRect.width / points.length;
    final barWidth = segmentWidth * 0.42;

    final barPaint = Paint()
      ..color = Colors.blueGrey.withAlpha(125)
      ..style = PaintingStyle.fill;

    final positiveDotPaint = Paint()
      ..color = Colors.green.withAlpha(160)
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = Colors.black.withAlpha(180)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final linePath = Path();

    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final centerX = chartRect.left + (segmentWidth * i) + (segmentWidth / 2);

      final barHeight = (point.signalCount / maxSignal) * chartRect.height;
      final barRect = Rect.fromLTWH(
        centerX - barWidth / 2,
        baseLineY - barHeight,
        barWidth,
        barHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(barRect, const Radius.circular(4)),
        barPaint,
      );

      final clampedMood = point.moodScore.clamp(-1.0, 1.0);
      final y = midLineY - (clampedMood * (chartRect.height * 0.42));
      final p = Offset(centerX, y);

      if (i == 0) {
        linePath.moveTo(p.dx, p.dy);
      } else {
        linePath.lineTo(p.dx, p.dy);
      }

      if (point.hasPositiveSignal) {
        canvas.drawCircle(
          Offset(centerX, baseLineY - barHeight - 6),
          3,
          positiveDotPaint,
        );
      }

      _drawBottomLabel(
        canvas,
        text: _shortDate(point.date),
        center: Offset(centerX, size.height - 14),
      );
    }

    canvas.drawPath(linePath, linePaint);
  }

  String _shortDate(String date) {
    if (date.length >= 10 && date.contains('-')) {
      return date.substring(5);
    }
    return date;
  }

  void _drawBottomLabel(Canvas canvas,
      {required String text, required Offset center}) {
    final span = TextSpan(
      text: text,
      style: TextStyle(
        color: Colors.grey.withAlpha(180),
        fontSize: 10,
      ),
    );
    final painter = TextPainter(
      text: span,
      textDirection: textDirection,
      maxLines: 1,
    )..layout(minWidth: 0, maxWidth: 40);

    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _CompositeWeeklyChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.textDirection != textDirection;
  }
}

enum _LegendKind { bar, line }

class _LegendItem extends StatelessWidget {
  final String label;
  final _LegendKind kind;

  const _LegendItem({
    required this.label,
    required this.kind,
  });

  @override
  Widget build(BuildContext context) {
    Widget marker;
    switch (kind) {
      case _LegendKind.bar:
        marker = Container(
          width: 16,
          height: 10,
          decoration: BoxDecoration(
            color: Colors.blueGrey.withAlpha(125),
            borderRadius: BorderRadius.circular(3),
          ),
        );
        break;
      case _LegendKind.line:
        marker = SizedBox(
          width: 18,
          height: 10,
          child: CustomPaint(
            painter: _LineLegendPainter(),
          ),
        );
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        marker,
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

class _LineLegendPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withAlpha(180)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _LineLegendPainter oldDelegate) => false;
}

class _StatusChipBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _StatusChipBanner({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return _UnifiedCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(subtitle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroInsightCard extends StatelessWidget {
  final String title;
  final String body;

  const _HeroInsightCard({
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return _UnifiedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _OpportunityCard extends StatelessWidget {
  final String title;
  final Map<String, dynamic> snapshot;

  const _OpportunityCard({
    required this.title,
    required this.snapshot,
  });

  @override
  Widget build(BuildContext context) {
    final name = (snapshot['name'] as String?) ?? '';
    final summary = (snapshot['summary'] as String?) ?? '';

    return _UnifiedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          if (name.trim().isNotEmpty) ...[
            Text(name, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
          ],
          Text(summary),
        ],
      ),
    );
  }
}

class _PremiumChartInsightCard extends StatelessWidget {
  const _PremiumChartInsightCard();

  @override
  Widget build(BuildContext context) {
    return _UnifiedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lock_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Pro chart reading',
                    zhHans: 'Pro 图表解读',
                    zhHant: 'Pro 圖表解讀',
                    ja: 'Pro の図表読み',
                  ),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            AppLocaleText.tr(
              context,
              en: 'Unlock the key density day, low point, rebound signal, and what this week’s curve is asking you to watch next.',
              zhHans: '解锁线索最密的一天、走势低点、回升信号，以及这条曲线提示你下周该看什么。',
              zhHant: '解鎖線索最密的一天、走勢低點、回升訊號，以及這條曲線提示你下週該看什麼。',
              ja: '手がかりが最も濃い日、低い点、戻りの兆し、来週見るべきポイントを開きます。',
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: () => showPremiumPaywall(
                context,
                source: 'Weekly chart reading',
              ),
              icon: const Icon(Icons.workspace_premium_outlined),
              label: Text(
                AppLocaleText.tr(
                  context,
                  en: 'Unlock reading',
                  zhHans: '解锁解读',
                  zhHant: '解鎖解讀',
                  ja: '読みを開く',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartInsightCard extends StatelessWidget {
  final List<WeeklyChartPointModel> points;

  const _ChartInsightCard({required this.points});

  @override
  Widget build(BuildContext context) {
    final safePoints =
        points.isEmpty ? const <WeeklyChartPointModel>[] : [...points]
          ..sort((a, b) => a.date.compareTo(b.date));

    String densityText;
    String trendText;
    String reboundText;

    if (safePoints.isEmpty) {
      densityText = '这一周还没有足够图表线索。';
      trendText = '等记录再多一点，这里会开始指出哪一天最集中、走势什么时候往下或往上。';
      reboundText = '目前先继续记下重复出现的场景就好。';
    } else {
      final peak =
          safePoints.reduce((a, b) => a.signalCount >= b.signalCount ? a : b);
      final low =
          safePoints.reduce((a, b) => a.moodScore <= b.moodScore ? a : b);
      final rebound = safePoints.last;
      densityText =
          '线索最密的一天是 ${peak.date.length >= 10 ? peak.date.substring(5) : peak.date}，更像是同类事情在那一天集中冒头。';
      trendText =
          '走势最低点更接近 ${low.date.length >= 10 ? low.date.substring(5) : low.date}，说明那附近的状态更容易被往下拉。';
      reboundText = rebound.moodScore > low.moodScore
          ? '从后半段看，状态有一点往回收，说明并不是整周都在持续往下掉。'
          : '从后半段看，状态还没有明显回弹，下周更适合继续缩小观察范围。';
    }

    return _UnifiedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocaleText.tr(
              context,
              en: 'What this chart is pointing at',
              zhHans: '这张图在提示什么',
              zhHant: '這張圖在提示什麼',
              ja: 'この図が示していること',
            ),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Text('• $densityText'),
          const SizedBox(height: 8),
          Text('• $trendText'),
          const SizedBox(height: 8),
          Text('• $reboundText'),
        ],
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final bool isSubmitted;
  final SubmitState submitState;
  final Future<void> Function(String) onSubmit;

  const _FeedbackCard({
    required this.isSubmitted,
    required this.submitState,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    if (isSubmitted) {
      return _UnifiedCard(
        child: Text(
          AppLocaleText.tr(
            context,
            en: 'Thanks — your feedback for this week has been saved.',
            zhHans: '谢谢，这周的反馈已经保存。',
            zhHant: '謝謝，這週的回饋已經保存。',
            ja: 'ありがとうございます。今週のフィードバックは保存されました。',
          ),
        ),
      );
    }

    final isSubmitting = submitState == SubmitState.submitting;

    return _UnifiedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocaleText.tr(
              context,
              en: 'Did this weekly read feel right?',
              zhHans: '这份 Weekly 看起来对吗？',
              zhHant: '這份 Weekly 看起來對嗎？',
              ja: 'この Weekly の見立てはしっくりきましたか？',
            ),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: isSubmitting ? null : () => onSubmit('helpful'),
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Mostly yes',
                    zhHans: '大体是',
                    zhHant: '大體是',
                    ja: 'だいたい合っている',
                  ),
                ),
              ),
              FilledButton.tonal(
                onPressed: isSubmitting ? null : () => onSubmit('partial'),
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Partly',
                    zhHans: '一部分对',
                    zhHant: '一部分對',
                    ja: '一部は合っている',
                  ),
                ),
              ),
              FilledButton.tonal(
                onPressed: isSubmitting ? null : () => onSubmit('off'),
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Not really',
                    zhHans: '不太对',
                    zhHant: '不太對',
                    ja: 'あまり合っていない',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UnifiedCard extends StatelessWidget {
  final Widget child;

  const _UnifiedCard({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AuroraMainPageSpec.comfortableCardPadding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(AuroraMainPageSpec.cardRadiusLarge),
        border: Border.all(color: Colors.white.withValues(alpha: 0.90)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7568A6).withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }
}
