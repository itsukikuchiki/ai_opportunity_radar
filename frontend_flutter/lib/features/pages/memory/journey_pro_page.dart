import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/i18n/app_locale_text.dart';
import '../../../core/models/energy_budget_models.dart';
import '../../../core/models/journey_pro_models.dart';
import '../../../core/navigation/app_back_navigation.dart';
import '../../../core/preferences/focus_domains.dart';
import '../../../shared/states/load_state.dart';
import '../../../shared/widgets/aurora_ui.dart';
import '../../../shared/widgets/empty_state_block.dart';
import 'journey_pro_view_model.dart';

/// Pro projection for the selected month and its two preceding natural months.
///
/// This surface intentionally contains only three-month change. Experiments,
/// goals, analysis-scope copy, raw Signal drill-down, date drill-down, and AI
/// chat belong to other surfaces and must not be reintroduced here.
class JourneyProPage extends StatefulWidget {
  final String? initialMonthKey;

  const JourneyProPage({
    super.key,
    this.initialMonthKey,
  });

  @override
  State<JourneyProPage> createState() => _JourneyProPageState();
}

class _JourneyProPageState extends State<JourneyProPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (!mounted) return;
      context.read<JourneyProViewModel>().load(
            selectedMonthKey: widget.initialMonthKey,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<JourneyProViewModel>();
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
                  _Header(onBack: () => context.popOrGo(AppRoutes.memory)),
                  const SizedBox(height: 14),
                  _Hero(
                    report: vm.report,
                    onPrevious: vm.loadState == LoadState.loading
                        ? null
                        : () => vm.moveByMonths(-1),
                    onNext: vm.loadState == LoadState.loading ||
                            !vm.canMoveToNextMonth
                        ? null
                        : () => vm.moveByMonths(1),
                  ),
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

  List<Widget> _body(BuildContext context, JourneyProViewModel vm) {
    switch (vm.loadState) {
      case LoadState.initial:
      case LoadState.loading:
        return const [
          SizedBox(height: 88),
          Center(child: CircularProgressIndicator()),
        ];
      case LoadState.error:
        return [
          EmptyStateBlock(
            icon: Icons.error_outline_rounded,
            title: AppLocaleText.tr(
              context,
              en: 'Three-month change failed to load',
              zhHans: '三个月变化加载失败',
              zhHant: '三個月變化載入失敗',
              ja: '3か月の変化を読み込めませんでした',
            ),
            subtitle: AppLocaleText.tr(
              context,
              en: 'Your Journey data was not changed. Please try again.',
              zhHans: '你的旅程数据没有被修改，请重新加载。',
              zhHant: '你的旅程資料沒有被修改，請重新載入。',
              ja: '旅程データは変更されていません。再読み込みしてください。',
            ),
          ),
          const SizedBox(height: 12),
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
              onPressed: vm.retry,
            ),
          ),
        ];
      case LoadState.empty:
      case LoadState.ready:
        final report = vm.report;
        if (report == null) return const [SizedBox.shrink()];
        return [
          _ThreeMonthChart(report: report),
          const SizedBox(height: AuroraMainPageSpec.sectionGap),
          _EnergyStateTrend(report: report),
          const SizedBox(height: AuroraMainPageSpec.sectionGap),
          _DomainTrend(report: report),
          const SizedBox(height: AuroraMainPageSpec.sectionGap),
          if (report.canShowChange)
            _ChangeSummary(report: report)
          else
            _ComparisonReadiness(report: report),
        ];
    }
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onBack;

  const _Header({required this.onBack});

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
              en: 'Journey Pro',
              zhHans: '旅程 Pro',
              zhHant: '旅程 Pro',
              ja: '旅程 Pro',
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

class _Hero extends StatelessWidget {
  final JourneyProReportModel? report;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _Hero({
    required this.report,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final selectedMonth = report?.selectedMonthKey;
    return AuroraCard(
      key: const ValueKey('journey-pro-three-month-hero'),
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 210),
          child: Stack(
            children: [
              const Positioned.fill(
                child: AuroraJourneyHeroPattern(
                  opacity: 0.62,
                  alignment: Alignment.centerRight,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AuroraHeroTitle(
                      text: AppLocaleText.tr(
                        context,
                        en: 'Three-month change',
                        zhHans: '三个月变化',
                        zhHant: '三個月變化',
                        ja: '3か月の変化',
                      ),
                      fontSize: 31,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 236,
                      child: Text(
                        AppLocaleText.tr(
                          context,
                          en: 'Compare the selected month with the two natural months before it.',
                          zhHans: '比较选定月与之前两个自然月的记录变化。',
                          zhHant: '比較選定月與之前兩個自然月的記錄變化。',
                          ja: '選択した月と、その前の2か月の記録変化を比べます。',
                        ),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AuroraColors.muted,
                              height: 1.42,
                            ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _MonthArrow(
                          icon: Icons.chevron_left_rounded,
                          onPressed: onPrevious,
                        ),
                        const SizedBox(width: 8),
                        Container(
                          key: const ValueKey('journey-pro-selected-month'),
                          constraints: const BoxConstraints(minWidth: 112),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.78),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color:
                                  AuroraColors.purple.withValues(alpha: 0.16),
                            ),
                          ),
                          child: Text(
                            selectedMonth == null
                                ? AppLocaleText.tr(
                                    context,
                                    en: 'Loading…',
                                    zhHans: '加载中…',
                                    zhHant: '載入中…',
                                    ja: '読み込み中…',
                                  )
                                : _monthLabel(context, selectedMonth),
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: AuroraColors.purple,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _MonthArrow(
                          icon: Icons.chevron_right_rounded,
                          onPressed: onNext,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _MonthArrow({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        color: AuroraColors.purple,
        disabledColor: AuroraColors.muted.withValues(alpha: 0.28),
        tooltip: MaterialLocalizations.of(context).previousMonthTooltip,
      ),
    );
  }
}

class _ThreeMonthChart extends StatelessWidget {
  final JourneyProReportModel report;

  const _ThreeMonthChart({required this.report});

  @override
  Widget build(BuildContext context) {
    final maxSignals = math.max(
      JourneyProReportModel.minimumSignalsPerMonth,
      report.months
          .fold<int>(0, (value, month) => math.max(value, month.signalCount)),
    );
    final maxDays = math.max(
      JourneyProReportModel.minimumActiveDaysPerMonth,
      report.months.fold<int>(
          0, (value, month) => math.max(value, month.activeDayCount)),
    );
    return AuroraCard(
      key: const ValueKey('journey-pro-three-month-chart'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocaleText.tr(
              context,
              en: 'Three natural months',
              zhHans: '三个自然月',
              zhHant: '三個自然月',
              ja: '3つの暦月',
            ),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AuroraColors.ink,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const _Legend(color: AuroraColors.purple, label: 'Signal'),
              const SizedBox(width: 16),
              _Legend(
                color: AuroraColors.mint,
                label: AppLocaleText.tr(
                  context,
                  en: 'recording days',
                  zhHans: '记录日',
                  zhHant: '記錄日',
                  ja: '記録日',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 188,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < report.months.length; index++) ...[
                  if (index > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _MonthColumn(
                      month: report.months[index],
                      maxSignals: maxSignals,
                      maxDays: maxDays,
                    ),
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

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AuroraColors.muted,
              ),
        ),
      ],
    );
  }
}

class _MonthColumn extends StatelessWidget {
  final JourneyProMonthChangeModel month;
  final int maxSignals;
  final int maxDays;

  const _MonthColumn({
    required this.month,
    required this.maxSignals,
    required this.maxDays,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _Bar(
                value: month.signalCount,
                maximum: maxSignals,
                color: AuroraColors.purple,
              ),
              const SizedBox(width: 7),
              _Bar(
                value: month.activeDayCount,
                maximum: maxDays,
                color: AuroraColors.mint,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _shortMonthLabel(context, month.monthKey),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AuroraColors.ink,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 3),
        Text(
          AppLocaleText.tr(
            context,
            en: '${month.signalCount} · ${month.activeDayCount} days',
            zhHans: '${month.signalCount} 条 · ${month.activeDayCount} 日',
            zhHant: '${month.signalCount} 條 · ${month.activeDayCount} 日',
            ja: '${month.signalCount}件 · ${month.activeDayCount}日',
          ),
          maxLines: 1,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AuroraColors.muted,
              ),
        ),
        const SizedBox(height: 5),
        Icon(
          month.meetsComparisonMinimum
              ? Icons.check_circle_rounded
              : Icons.circle_outlined,
          size: 17,
          color: month.meetsComparisonMinimum
              ? AuroraColors.mint
              : AuroraColors.muted.withValues(alpha: 0.42),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  final int value;
  final int maximum;
  final Color color;

  const _Bar({
    required this.value,
    required this.maximum,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = maximum <= 0 ? 0.0 : (value / maximum).clamp(0.0, 1.0);
    return Tooltip(
      message: '$value',
      child: Container(
        width: 25,
        height: math.max(8, 110 * fraction),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [color, color.withValues(alpha: 0.42)],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
        ),
      ),
    );
  }
}

class _EnergyStateTrend extends StatelessWidget {
  final JourneyProReportModel report;

  const _EnergyStateTrend({required this.report});

  static const _colors = <EnergySignalState, Color>{
    EnergySignalState.draining: Color(0xFFF39A66),
    EnergySignalState.steady: Color(0xFF6E9BF2),
    EnergySignalState.ease: Color(0xFFF2C85B),
    EnergySignalState.recovery: Color(0xFF58C6A7),
    EnergySignalState.boundaryBuffer: Color(0xFF9A78E8),
  };

  @override
  Widget build(BuildContext context) {
    return AuroraCard(
      key: const ValueKey('journey-pro-energy-state-trend'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocaleText.tr(
              context,
              en: 'Energy-state change',
              zhHans: '能量状态变化',
              zhHant: '能量狀態變化',
              ja: 'エネルギー状態の変化',
            ),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AuroraColors.ink,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 7,
            children: [
              for (final state in EnergySignalState.values)
                _Legend(
                  color: _colors[state]!,
                  label: _energyStateLabel(context, state),
                ),
            ],
          ),
          const SizedBox(height: 16),
          for (final month in report.months) ...[
            _StackedEnergyRow(
              month: month,
              colors: _colors,
            ),
            if (month != report.months.last) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _StackedEnergyRow extends StatelessWidget {
  final JourneyProMonthChangeModel month;
  final Map<EnergySignalState, Color> colors;

  const _StackedEnergyRow({required this.month, required this.colors});

  @override
  Widget build(BuildContext context) {
    final total = month.energyStateCounts.values.fold<int>(0, (a, b) => a + b);
    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(
            _shortMonthLabel(context, month.monthKey),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AuroraColors.muted,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 18,
              color: AuroraColors.muted.withValues(alpha: 0.08),
              child: total == 0
                  ? const SizedBox.shrink()
                  : Row(
                      children: [
                        for (final state in EnergySignalState.values)
                          if (month.energyCount(state.storageValue) > 0)
                            Expanded(
                              flex: month.energyCount(state.storageValue),
                              child: ColoredBox(color: colors[state]!),
                            ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 24,
          child: Text(
            '$total',
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AuroraColors.muted,
                ),
          ),
        ),
      ],
    );
  }
}

class _DomainTrend extends StatelessWidget {
  final JourneyProReportModel report;

  const _DomainTrend({required this.report});

  @override
  Widget build(BuildContext context) {
    final totals = <String, int>{};
    for (final month in report.months) {
      for (final entry in month.domainCounts.entries) {
        totals[entry.key] = (totals[entry.key] ?? 0) + entry.value;
      }
    }
    final domains = totals.keys.toList()
      ..sort((a, b) {
        final count = (totals[b] ?? 0).compareTo(totals[a] ?? 0);
        return count == 0 ? a.compareTo(b) : count;
      });
    final visibleDomains = domains.take(4).toList(growable: false);
    final maxCount = report.months
        .expand((month) => month.domainCounts.values)
        .fold<int>(1, math.max);
    return AuroraCard(
      key: const ValueKey('journey-pro-domain-trend'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocaleText.tr(
              context,
              en: 'Life-area change',
              zhHans: '生活领域变化',
              zhHant: '生活領域變化',
              ja: '生活領域の変化',
            ),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AuroraColors.ink,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 14),
          if (visibleDomains.isEmpty)
            Text(
              AppLocaleText.tr(
                context,
                en: 'No eligible Signal yet.',
                zhHans: '暂时还没有可统计的 Signal。',
                zhHant: '暫時還沒有可統計的 Signal。',
                ja: '集計できるSignalはまだありません。',
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AuroraColors.muted,
                  ),
            )
          else ...[
            Row(
              children: [
                const SizedBox(width: 92),
                for (final month in report.months)
                  Expanded(
                    child: Text(
                      _shortMonthLabel(context, month.monthKey),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AuroraColors.muted,
                          ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            for (final domainId in visibleDomains) ...[
              _DomainRow(
                domainId: domainId,
                months: report.months,
                maxCount: maxCount,
              ),
              if (domainId != visibleDomains.last) const SizedBox(height: 9),
            ],
          ],
        ],
      ),
    );
  }
}

class _DomainRow extends StatelessWidget {
  final String domainId;
  final List<JourneyProMonthChangeModel> months;
  final int maxCount;

  const _DomainRow({
    required this.domainId,
    required this.months,
    required this.maxCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(
            _domainLabel(context, domainId),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AuroraColors.ink,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        for (final month in months)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _DomainCountCell(
                value: month.domainCount(domainId),
                maximum: maxCount,
              ),
            ),
          ),
      ],
    );
  }
}

class _DomainCountCell extends StatelessWidget {
  final int value;
  final int maximum;

  const _DomainCountCell({required this.value, required this.maximum});

  @override
  Widget build(BuildContext context) {
    final intensity = maximum <= 0 ? 0.0 : value / maximum;
    return Container(
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AuroraColors.purple.withValues(alpha: 0.05 + intensity * 0.22),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$value',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: value == 0 ? AuroraColors.muted : AuroraColors.purple,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _ComparisonReadiness extends StatelessWidget {
  final JourneyProReportModel report;

  const _ComparisonReadiness({required this.report});

  @override
  Widget build(BuildContext context) {
    return AuroraCard(
      key: const ValueKey('journey-pro-three-month-readiness'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AuroraSectionIcon(
                icon: Icons.hourglass_top_rounded,
                color: AuroraColors.orange,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Change is still forming',
                    zhHans: '变化还在形成',
                    zhHant: '變化還在形成',
                    ja: '変化はまだ形成中です',
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AuroraColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            AppLocaleText.tr(
              context,
              en: '${report.readyMonthCount}/2 months are ready. A month counts after 7 eligible Signals across 3 recording days.',
              zhHans:
                  '已有 ${report.readyMonthCount}/2 个自然月可比较。每个月达到 7 条有效 Signal、覆盖 3 个记录日后计入。',
              zhHant:
                  '已有 ${report.readyMonthCount}/2 個自然月可比較。每個月達到 7 條有效 Signal、覆蓋 3 個記錄日後計入。',
              ja: '${report.readyMonthCount}/2か月が比較可能です。各月で有効なSignal 7件・記録日3日を満たすと対象になります。',
            ),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AuroraColors.muted,
                  height: 1.48,
                ),
          ),
        ],
      ),
    );
  }
}

class _ChangeSummary extends StatelessWidget {
  final JourneyProReportModel report;

  const _ChangeSummary({required this.report});

  @override
  Widget build(BuildContext context) {
    return AuroraCard(
      key: const ValueKey('journey-pro-three-month-change'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AuroraSectionIcon(
                icon: Icons.auto_graph_rounded,
                color: AuroraColors.blue,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Latest monthly change',
                    zhHans: '最近一个月的变化',
                    zhHant: '最近一個月的變化',
                    ja: '直近1か月の変化',
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AuroraColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _DeltaTile(
                  label: 'Signal',
                  delta: report.latestSignalDelta,
                  color: AuroraColors.purple,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DeltaTile(
                  label: AppLocaleText.tr(
                    context,
                    en: 'Recording days',
                    zhHans: '记录日',
                    zhHant: '記錄日',
                    ja: '記録日',
                  ),
                  delta: report.latestActiveDayDelta,
                  color: AuroraColors.mint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _factChangeSummary(context, report),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AuroraColors.ink,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            AppLocaleText.tr(
              context,
              en: 'These are recording changes between natural months, not a score or a causal conclusion.',
              zhHans: '这里只比较自然月之间的记录变化，不代表评分，也不推断因果。',
              zhHant: '這裡只比較自然月之間的記錄變化，不代表評分，也不推斷因果。',
              ja: '暦月ごとの記録変化だけを示します。スコアや因果の結論ではありません。',
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AuroraColors.muted,
                  height: 1.45,
                ),
          ),
        ],
      ),
    );
  }
}

class _DeltaTile extends StatelessWidget {
  final String label;
  final int delta;
  final Color color;

  const _DeltaTile({
    required this.label,
    required this.delta,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final value = delta > 0 ? '+$delta' : '$delta';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AuroraColors.muted,
                ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

String _monthLabel(BuildContext context, String monthKey) {
  final month = _parseMonthKey(monthKey);
  if (month == null) return monthKey;
  return MaterialLocalizations.of(context).formatMonthYear(month);
}

String _shortMonthLabel(BuildContext context, String monthKey) {
  final month = _parseMonthKey(monthKey);
  if (month == null) return monthKey;
  final locale = Localizations.localeOf(context).languageCode;
  if (locale == 'zh' || locale == 'ja') return '${month.month}月';
  const labels = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return labels[month.month - 1];
}

DateTime? _parseMonthKey(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(value);
  if (match == null) return null;
  final year = int.tryParse(match.group(1)!);
  final month = int.tryParse(match.group(2)!);
  if (year == null || month == null || month < 1 || month > 12) return null;
  return DateTime(year, month);
}

String _energyStateLabel(BuildContext context, EnergySignalState state) {
  return switch (state) {
    EnergySignalState.draining => AppLocaleText.tr(
        context,
        en: 'draining',
        zhHans: '偏耗力',
        zhHant: '偏耗力',
        ja: '消耗気味',
      ),
    EnergySignalState.steady => AppLocaleText.tr(
        context,
        en: 'steady',
        zhHans: '平稳',
        zhHant: '平穩',
        ja: '安定',
      ),
    EnergySignalState.ease => AppLocaleText.tr(
        context,
        en: 'at ease',
        zhHans: '有余力',
        zhHant: '有餘力',
        ja: '余力あり',
      ),
    EnergySignalState.recovery => AppLocaleText.tr(
        context,
        en: 'recovery',
        zhHans: '恢复',
        zhHant: '恢復',
        ja: '回復',
      ),
    EnergySignalState.boundaryBuffer => AppLocaleText.tr(
        context,
        en: 'boundary & buffer',
        zhHans: '边界与余地',
        zhHant: '邊界與餘地',
        ja: '境界と余白',
      ),
  };
}

String _domainLabel(BuildContext context, String domainId) {
  if (domainId == 'other') {
    return AppLocaleText.tr(
      context,
      en: 'Other',
      zhHans: '其他',
      zhHant: '其他',
      ja: 'その他',
    );
  }
  return FocusDomains.labelFor(context, domainId);
}

String _factChangeSummary(
  BuildContext context,
  JourneyProReportModel report,
) {
  if (report.months.length < 2) return '';
  final previous = report.months[report.months.length - 2];
  final latest = report.months.last;
  final previousDomain = _topCountKey(previous.domainCounts);
  final latestDomain = _topCountKey(latest.domainCounts);
  final previousEnergy = _topCountKey(previous.energyStateCounts);
  final latestEnergy = _topCountKey(latest.energyStateCounts);

  final domainText = previousDomain == null || latestDomain == null
      ? AppLocaleText.tr(
          context,
          en: 'The life-area distribution is still sparse.',
          zhHans: '生活领域分布还比较稀疏。',
          zhHant: '生活領域分布還比較稀疏。',
          ja: '生活領域の分布はまだ少ない状態です。',
        )
      : previousDomain == latestDomain
          ? AppLocaleText.tr(
              context,
              en: '${_domainLabel(context, latestDomain)} remained the most-recorded life area in the latest two months.',
              zhHans:
                  '最近两个月，${_domainLabel(context, latestDomain)}都是记录最多的生活领域。',
              zhHant:
                  '最近兩個月，${_domainLabel(context, latestDomain)}都是記錄最多的生活領域。',
              ja: '直近2か月は、${_domainLabel(context, latestDomain)}の記録が最も多くなっています。',
            )
          : AppLocaleText.tr(
              context,
              en: 'The most-recorded life area changed from ${_domainLabel(context, previousDomain)} to ${_domainLabel(context, latestDomain)}.',
              zhHans:
                  '记录最多的生活领域从${_domainLabel(context, previousDomain)}变为${_domainLabel(context, latestDomain)}。',
              zhHant:
                  '記錄最多的生活領域從${_domainLabel(context, previousDomain)}變為${_domainLabel(context, latestDomain)}。',
              ja: '記録が最も多い生活領域は、${_domainLabel(context, previousDomain)}から${_domainLabel(context, latestDomain)}に変わりました。',
            );

  final previousEnergyState = EnergySignalState.fromStorage(previousEnergy);
  final latestEnergyState = EnergySignalState.fromStorage(latestEnergy);
  final energyText = previousEnergy == null || latestEnergy == null
      ? ''
      : previousEnergyState == latestEnergyState
          ? AppLocaleText.tr(
              context,
              en: '${_energyStateLabel(context, latestEnergyState)} remained the largest energy-state share.',
              zhHans:
                  '${_energyStateLabel(context, latestEnergyState)}仍是占比最多的能量状态。',
              zhHant:
                  '${_energyStateLabel(context, latestEnergyState)}仍是佔比最多的能量狀態。',
              ja: '${_energyStateLabel(context, latestEnergyState)}が引き続き最も多い状態です。',
            )
          : AppLocaleText.tr(
              context,
              en: 'The largest energy-state share changed from ${_energyStateLabel(context, previousEnergyState)} to ${_energyStateLabel(context, latestEnergyState)}.',
              zhHans:
                  '占比最多的能量状态从${_energyStateLabel(context, previousEnergyState)}变为${_energyStateLabel(context, latestEnergyState)}。',
              zhHant:
                  '佔比最多的能量狀態從${_energyStateLabel(context, previousEnergyState)}變為${_energyStateLabel(context, latestEnergyState)}。',
              ja: '最も多いエネルギー状態は、${_energyStateLabel(context, previousEnergyState)}から${_energyStateLabel(context, latestEnergyState)}に変わりました。',
            );
  return '$domainText${energyText.isEmpty ? '' : ' $energyText'}';
}

String? _topCountKey(Map<String, int> values) {
  final positive = values.entries.where((entry) => entry.value > 0).toList()
    ..sort((a, b) {
      final count = b.value.compareTo(a.value);
      return count == 0 ? a.key.compareTo(b.key) : count;
    });
  return positive.isEmpty ? null : positive.first.key;
}
