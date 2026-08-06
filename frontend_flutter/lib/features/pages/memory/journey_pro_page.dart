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
import '../../shell/main_tab_bottom_navigation.dart';
import 'journey_display_text.dart';
import 'journey_pro_view_model.dart';

/// Pro projection from first app use through the latest completed local month.
///
/// Experiments, goals, raw Signal drill-down, date drill-down, and AI chat
/// belong to other surfaces and must not be reintroduced here.
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
      extendBody: true,
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
      bottomNavigationBar: const MainTabBottomNavigation(selectedIndex: 3),
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
              en: 'Journey history failed to load',
              zhHans: '完整旅程变化加载失败',
              zhHant: '完整旅程變化載入失敗',
              ja: '旅程全体の変化を読み込めませんでした',
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
        if (report.months.isEmpty) {
          return [
            EmptyStateBlock(
              icon: Icons.calendar_month_rounded,
              title: AppLocaleText.tr(
                context,
                en: 'Your first complete month is still forming',
                zhHans: '首个完整月份还在形成中',
                zhHant: '首個完整月份仍在形成中',
                ja: '最初の1か月はまだ進行中です',
              ),
              subtitle: AppLocaleText.tr(
                context,
                en: 'Journey Pro will show it after the calendar month ends, so partial data cannot distort the trend.',
                zhHans: '自然月结束后，旅程深度分析才会显示这个月，避免不完整数据让趋势图失真。',
                zhHant: '自然月結束後，旅程深度分析才會顯示這個月，避免不完整資料讓趨勢圖失真。',
                ja: '不完全なデータで傾向が歪まないよう、月が終わってから旅程の深度分析に表示します。',
              ),
            ),
          ];
        }
        if (!report.hasData) {
          return [
            _JourneyHistoryOverview(report: report),
            const SizedBox(height: AuroraMainPageSpec.sectionGap),
            EmptyStateBlock(
              icon: Icons.route_outlined,
              title: AppLocaleText.tr(
                context,
                en: 'Your complete timeline is ready to begin',
                zhHans: '完整时间轴等待第一条记录',
                zhHant: '完整時間軸等待第一條記錄',
                ja: '全期間のタイムラインは最初の記録を待っています',
              ),
              subtitle: AppLocaleText.tr(
                context,
                en: 'Record Signal first. Focus, themes, energy and rhythm will appear here without inventing missing months.',
                zhHans: '先留下 Signal；关注领域、主题、能量与节奏会按真实月份逐步显示，不会补造缺失数据。',
                zhHant: '先留下 Signal；關注領域、主題、能量與節奏會按真實月份逐步顯示，不會補造缺失資料。',
                ja: 'まず Signal を残してください。関心領域、テーマ、エネルギーとリズムを、存在しない月を補わずに表示します。',
              ),
            ),
          ];
        }
        return [
          _JourneyHistoryOverview(report: report),
          const SizedBox(height: AuroraMainPageSpec.sectionGap),
          _JourneyHistoryLineCard(
            report: report,
            kind: _JourneyHistoryLineKind.domain,
          ),
          const SizedBox(height: AuroraMainPageSpec.sectionGap),
          _JourneyHistoryLineCard(
            report: report,
            kind: _JourneyHistoryLineKind.theme,
          ),
          const SizedBox(height: AuroraMainPageSpec.sectionGap),
          _JourneyEnergyRhythmHistoryCard(report: report),
          const SizedBox(height: AuroraMainPageSpec.sectionGap),
          _JourneyHistoryConclusionCard(report: report),
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
              zhHans: '旅程深度分析',
              zhHant: '旅程深度分析',
              ja: '旅程の深度分析',
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

  const _Hero({
    required this.report,
  });

  @override
  Widget build(BuildContext context) {
    return AuroraCard(
      key: const ValueKey('journey-pro-full-history-hero'),
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
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
                      en: 'Complete Journey changes',
                      zhHans: '完整旅程变化',
                      zhHant: '完整旅程變化',
                      ja: '旅程全体の変化',
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
                        en: 'See how focus, themes, energy, and rhythm changed through your latest complete month.',
                        zhHans: '查看从开始使用到最近一个完整月份，关注领域、主题、能量与节奏如何变化。',
                        zhHant: '查看從開始使用到最近一個完整月份，關注領域、主題、能量與節奏如何變化。',
                        ja: '利用開始から直近の完了月まで、関心領域、テーマ、エネルギーとリズムがどう変化したかを確認します。',
                      ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AuroraColors.muted,
                            height: 1.42,
                          ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    key: const ValueKey('journey-pro-history-period'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AuroraColors.purple.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Text(
                      report == null
                          ? AppLocaleText.tr(
                              context,
                              en: 'Loading…',
                              zhHans: '加载中…',
                              zhHant: '載入中…',
                              ja: '読み込み中…',
                            )
                          : report!.months.isEmpty
                              ? AppLocaleText.tr(
                                  context,
                                  en: 'Available after the first complete month',
                                  zhHans: '首个自然月结束后显示',
                                  zhHant: '首個自然月結束後顯示',
                                  ja: '最初の1か月終了後に表示',
                                )
                              : '${_shortDate(context, report!.periodStart)} — ${_shortDate(context, report!.periodEnd)}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AuroraColors.purple,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JourneyHistoryOverview extends StatelessWidget {
  final JourneyProReportModel report;

  const _JourneyHistoryOverview({required this.report});

  @override
  Widget build(BuildContext context) {
    final activeMonths =
        report.months.where((month) => month.signalCount > 0).length;
    return AuroraCard(
      key: const ValueKey('journey-pro-history-overview'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocaleText.tr(
              context,
              en: 'Timeline overview',
              zhHans: '完整时间轴概览',
              zhHant: '完整時間軸概覽',
              ja: '全期間の概要',
            ),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AuroraColors.ink,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _HistoryMetricTile(
                  icon: Icons.calendar_view_month_rounded,
                  color: AuroraColors.purple,
                  value: '$activeMonths',
                  label: AppLocaleText.tr(
                    context,
                    en: 'recorded months',
                    zhHans: '有记录月份',
                    zhHant: '有記錄月份',
                    ja: '記録した月',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HistoryMetricTile(
                  icon: Icons.auto_awesome_rounded,
                  color: AuroraColors.blue,
                  value: '${report.totalSignalCount}',
                  label: 'Signal',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _HistoryMetricTile(
            icon: Icons.calendar_today_rounded,
            color: AuroraColors.mint,
            value: '${report.totalActiveDayCount}',
            label: AppLocaleText.tr(
              context,
              en: 'recording days across the timeline',
              zhHans: '完整时间轴记录日',
              zhHant: '完整時間軸記錄日',
              ja: '全期間の記録日',
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryMetricTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _HistoryMetricTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 25),
          const SizedBox(width: 9),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AuroraColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _JourneyHistoryLineKind { domain, theme }

class _JourneyHistoryLineCard extends StatelessWidget {
  final JourneyProReportModel report;
  final _JourneyHistoryLineKind kind;

  const _JourneyHistoryLineCard({
    required this.report,
    required this.kind,
  });

  @override
  Widget build(BuildContext context) {
    final totals = <String, int>{};
    for (final month in report.months) {
      final counts = kind == _JourneyHistoryLineKind.domain
          ? month.domainCounts
          : month.themeCounts;
      for (final entry in counts.entries) {
        totals[entry.key] = (totals[entry.key] ?? 0) + entry.value;
      }
    }
    final keys = totals.keys.toList()
      ..sort((a, b) => (totals[b] ?? 0).compareTo(totals[a] ?? 0));
    const palette = [
      Color(0xFFFF83B5),
      Color(0xFF7B6FF2),
      Color(0xFF58B8F6),
      Color(0xFF55C7B2),
    ];
    final series = <_HistoryLineSeries>[];
    for (var index = 0; index < math.min(4, keys.length); index++) {
      final key = keys[index];
      series.add(
        _HistoryLineSeries(
          label: kind == _JourneyHistoryLineKind.domain
              ? _domainLabel(context, key)
              : localizeJourneyChartSeriesLabel(
                  context,
                  categoryId: key,
                ),
          color: palette[index],
          values: [
            for (final month in report.months)
              kind == _JourneyHistoryLineKind.domain
                  ? month.domainCount(key).toDouble()
                  : month.themeCount(key).toDouble(),
          ],
        ),
      );
    }
    return AuroraCard(
      key: ValueKey(
        kind == _JourneyHistoryLineKind.domain
            ? 'journey-pro-domain-history'
            : 'journey-pro-theme-history',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kind == _JourneyHistoryLineKind.domain
                ? AppLocaleText.tr(
                    context,
                    en: 'Focus-area change',
                    zhHans: '关注领域变化',
                    zhHant: '關注領域變化',
                    ja: '関心領域の変化',
                  )
                : AppLocaleText.tr(
                    context,
                    en: 'Theme change',
                    zhHans: '主题变化',
                    zhHant: '主題變化',
                    ja: 'テーマの変化',
                  ),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AuroraColors.ink,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 14),
          if (series.isEmpty)
            Text(
              AppLocaleText.tr(
                context,
                en: 'Changes will appear as you keep recording Signal.',
                zhHans: '继续记录 Signal 后，变化会显示在这里。',
                zhHant: '繼續記錄 Signal 後，變化會顯示在這裡。',
                ja: 'Signal を記録し続けると、変化がここに表示されます。',
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AuroraColors.muted,
                  ),
            )
          else ...[
            SizedBox(
              height: 180,
              child: CustomPaint(
                painter: _HistoryLinePainter(series),
                child: const SizedBox.expand(),
              ),
            ),
            _HistoryTimelineAxis(months: report.months),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 7,
              children: [
                for (final item in series)
                  _Legend(color: item.color, label: item.label),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryLineSeries {
  final String label;
  final Color color;
  final List<double> values;

  const _HistoryLineSeries({
    required this.label,
    required this.color,
    required this.values,
  });
}

class _HistoryLinePainter extends CustomPainter {
  final List<_HistoryLineSeries> series;

  const _HistoryLinePainter(this.series);

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(10, 10, size.width - 8, size.height - 24);
    final gridPaint = Paint()
      ..color = AuroraColors.muted.withValues(alpha: 0.15)
      ..strokeWidth = 1;
    for (var index = 0; index < 4; index++) {
      final y = plot.top + plot.height * index / 3;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
    }
    final maxValue = series
        .expand((item) => item.values)
        .fold<double>(1, (value, item) => math.max(value, item));
    for (final item in series) {
      final path = Path();
      for (var index = 0; index < item.values.length; index++) {
        final x = journeyHistoryLinePointX(
          plot: plot,
          index: index,
          pointCount: item.values.length,
        );
        final y =
            plot.bottom - (item.values[index] / maxValue) * plot.height * 0.82;
        if (index == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = item.color
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
      for (var index = 0; index < item.values.length; index++) {
        if (item.values[index] <= 0) continue;
        final x = journeyHistoryLinePointX(
          plot: plot,
          index: index,
          pointCount: item.values.length,
        );
        final y =
            plot.bottom - (item.values[index] / maxValue) * plot.height * 0.82;
        canvas.drawCircle(Offset(x, y), 3.5, Paint()..color = Colors.white);
        canvas.drawCircle(Offset(x, y), 2.2, Paint()..color = item.color);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HistoryLinePainter oldDelegate) =>
      oldDelegate.series != series;
}

@visibleForTesting
double journeyHistoryLinePointX({
  required Rect plot,
  required int index,
  required int pointCount,
}) {
  if (pointCount <= 1) return plot.center.dx;
  return plot.left + plot.width * index / (pointCount - 1);
}

class _HistoryTimelineAxis extends StatelessWidget {
  final List<JourneyProMonthChangeModel> months;

  const _HistoryTimelineAxis({required this.months});

  @override
  Widget build(BuildContext context) {
    if (months.isEmpty) return const SizedBox.shrink();
    if (months.length == 1) {
      return SizedBox(
        height: 24,
        child: Center(
          child: Text(
            _shortMonthLabel(context, months.first.monthKey),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AuroraColors.muted,
                ),
          ),
        ),
      );
    }

    final lastIndex = months.length - 1;
    final indices = <int>{
      0,
      (lastIndex / 3).round(),
      (lastIndex * 2 / 3).round(),
      lastIndex,
    }.toList()
      ..sort();
    return SizedBox(
      height: 24,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final labelWidth =
              math.min(72.0, constraints.maxWidth / indices.length);
          return Stack(
            children: [
              for (final index in indices)
                Positioned(
                  left: (constraints.maxWidth * index / lastIndex -
                          labelWidth / 2)
                      .clamp(0.0, constraints.maxWidth - labelWidth),
                  width: labelWidth,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _shortMonthLabel(context, months[index].monthKey),
                      maxLines: 1,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AuroraColors.muted,
                          ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _JourneyEnergyRhythmHistoryCard extends StatelessWidget {
  final JourneyProReportModel report;

  const _JourneyEnergyRhythmHistoryCard({required this.report});

  static const _colors = <EnergySignalState, Color>{
    EnergySignalState.draining: Color(0xFFF39A66),
    EnergySignalState.steady: Color(0xFF6E9BF2),
    EnergySignalState.ease: Color(0xFFF2C85B),
    EnergySignalState.recovery: Color(0xFF58C6A7),
    EnergySignalState.boundaryBuffer: Color(0xFF9A78E8),
  };

  @override
  Widget build(BuildContext context) {
    final series = [
      for (final state in EnergySignalState.values)
        _HistoryLineSeries(
          label: _energyStateLabel(context, state),
          color: _colors[state]!,
          values: [
            for (final month in report.months)
              month.energyCount(state.storageValue).toDouble(),
          ],
        ),
    ];
    return AuroraCard(
      key: const ValueKey('journey-pro-energy-rhythm-history'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocaleText.tr(
              context,
              en: 'Energy and rhythm change',
              zhHans: '能量与节奏变化',
              zhHant: '能量與節奏變化',
              ja: 'エネルギーとリズムの変化',
            ),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AuroraColors.ink,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 180,
            child: CustomPaint(
              painter: _HistoryLinePainter(series),
              child: const SizedBox.expand(),
            ),
          ),
          _HistoryTimelineAxis(months: report.months),
          const SizedBox(height: 10),
          Wrap(
            spacing: 9,
            runSpacing: 7,
            children: [
              for (final item in series)
                _Legend(color: item.color, label: item.label),
            ],
          ),
        ],
      ),
    );
  }
}

class _JourneyHistoryConclusionCard extends StatelessWidget {
  final JourneyProReportModel report;

  const _JourneyHistoryConclusionCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final recorded = report.months
        .where((month) => month.meetsComparisonMinimum)
        .toList(growable: false);
    final text = recorded.isEmpty
        ? AppLocaleText.tr(
            context,
            en: 'The factual timeline is visible now. A month-level conclusion appears after one month reaches 7 eligible Signals across 3 recording days.',
            zhHans: '真实时间轴已经显示。任一月份达到 7 条有效 Signal、覆盖 3 个记录日后，才会形成该月结论。',
            zhHant: '真實時間軸已經顯示。任一月份達到 7 條有效 Signal、覆蓋 3 個記錄日後，才會形成該月結論。',
            ja: '事実のタイムラインは表示されています。1か月で有効な Signal 7件・記録日3日を満たすと、その月のまとめが表示されます。',
          )
        : recorded.length < 2
            ? AppLocaleText.tr(
                context,
                en: 'One month is ready for a factual summary. The full timeline remains visible while change is still forming.',
                zhHans: '已有一个月份可以形成事实总结；完整时间轴会继续显示，跨月变化仍在形成。',
                zhHant: '已有一個月份可以形成事實總結；完整時間軸會繼續顯示，跨月變化仍在形成。',
                ja: '1か月分の事実をまとめられる状態です。全期間のタイムラインを表示しながら、月をまたぐ変化は形成中として扱います。',
              )
            : _fullHistorySummary(context, recorded);
    return AuroraCard(
      key: const ValueKey('journey-pro-history-conclusion'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AuroraSectionIcon(
            icon: Icons.route_rounded,
            color: AuroraColors.purple,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Changes across your timeline',
                    zhHans: '完整时间轴回看',
                    zhHant: '完整時間軸回看',
                    ja: '全期間の振り返り',
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AuroraColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 7),
                Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AuroraColors.ink,
                        height: 1.48,
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

// Legacy widgets below are retained only for local fixture compatibility; the
// active Journey Pro tree uses the complete-history line charts above.
// ignore: unused_element
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

// ignore: unused_element
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
      key: const ValueKey('journey-pro-legacy-month-chart'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocaleText.tr(
              context,
              en: 'Complete timeline',
              zhHans: '完整时间轴',
              zhHant: '完整時間軸',
              ja: '全期間のタイムライン',
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

// ignore: unused_element
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

// ignore: unused_element
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

// ignore: unused_element
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

// ignore: unused_element
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

String _shortDate(BuildContext context, String dateKey) {
  final parsed = DateTime.tryParse(dateKey);
  if (parsed == null) return dateKey;
  return AppLocaleText.tr(
    context,
    en: '${parsed.month}/${parsed.day}/${parsed.year}',
    zhHans: '${parsed.year}/${parsed.month}/${parsed.day}',
    zhHant: '${parsed.year}/${parsed.month}/${parsed.day}',
    ja: '${parsed.year}/${parsed.month}/${parsed.day}',
  );
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
  return FocusDomains.labelFor(context, domainId);
}

String _fullHistorySummary(
  BuildContext context,
  List<JourneyProMonthChangeModel> readyMonths,
) {
  if (readyMonths.isEmpty) return '';
  final first = readyMonths.first;
  final latest = readyMonths.last;
  final firstDomain = _topCountKey(first.domainCounts);
  final latestDomain = _topCountKey(latest.domainCounts);
  final firstTheme = _topCountKey(first.themeCounts);
  final latestTheme = _topCountKey(latest.themeCounts);

  final domainText = firstDomain == null || latestDomain == null
      ? ''
      : firstDomain == latestDomain
          ? AppLocaleText.tr(
              context,
              en: '${_domainLabel(context, latestDomain)} remained the most-recorded focus area.',
              zhHans: '记录最多的关注领域一直是${_domainLabel(context, latestDomain)}。',
              zhHant: '記錄最多的關注領域一直是${_domainLabel(context, latestDomain)}。',
              ja: '最も多く記録された関心領域は引き続き${_domainLabel(context, latestDomain)}です。',
            )
          : AppLocaleText.tr(
              context,
              en: 'The most-recorded focus area changed from ${_domainLabel(context, firstDomain)} to ${_domainLabel(context, latestDomain)}.',
              zhHans:
                  '记录最多的关注领域从${_domainLabel(context, firstDomain)}变为${_domainLabel(context, latestDomain)}。',
              zhHant:
                  '記錄最多的關注領域從${_domainLabel(context, firstDomain)}變為${_domainLabel(context, latestDomain)}。',
              ja: '最も多く記録された関心領域は${_domainLabel(context, firstDomain)}から${_domainLabel(context, latestDomain)}に変わりました。',
            );
  final themeText = firstTheme == null || latestTheme == null
      ? ''
      : firstTheme == latestTheme
          ? AppLocaleText.tr(
              context,
              en: '${_domainLabel(context, latestTheme)} remained the most visible theme.',
              zhHans: '出现最多的主题一直是${_domainLabel(context, latestTheme)}。',
              zhHant: '出現最多的主題一直是${_domainLabel(context, latestTheme)}。',
              ja: '最も多く現れたテーマは引き続き${_domainLabel(context, latestTheme)}です。',
            )
          : AppLocaleText.tr(
              context,
              en: 'The most visible theme changed from ${_domainLabel(context, firstTheme)} to ${_domainLabel(context, latestTheme)}.',
              zhHans:
                  '出现最多的主题从${_domainLabel(context, firstTheme)}变为${_domainLabel(context, latestTheme)}。',
              zhHant:
                  '出現最多的主題從${_domainLabel(context, firstTheme)}變為${_domainLabel(context, latestTheme)}。',
              ja: '最も多く現れたテーマは${_domainLabel(context, firstTheme)}から${_domainLabel(context, latestTheme)}に変わりました。',
            );
  final statements =
      [domainText, themeText].where((item) => item.trim().isNotEmpty).join(' ');
  final range = AppLocaleText.tr(
    context,
    en: 'From ${_shortMonthLabel(context, first.monthKey)} to ${_shortMonthLabel(context, latest.monthKey)}, ',
    zhHans:
        '从${_shortMonthLabel(context, first.monthKey)}到${_shortMonthLabel(context, latest.monthKey)}，',
    zhHant:
        '從${_shortMonthLabel(context, first.monthKey)}到${_shortMonthLabel(context, latest.monthKey)}，',
    ja: '${_shortMonthLabel(context, first.monthKey)}から${_shortMonthLabel(context, latest.monthKey)}まで、',
  );
  final fallback = AppLocaleText.tr(
    context,
    en: 'the recorded months now support a cautious comparison across the full timeline.',
    zhHans: '已有月份可以进行一次保守的完整时间轴比较。',
    zhHant: '已有月份可以進行一次保守的完整時間軸比較。',
    ja: '記録済みの月を使って、全期間を控えめに比較できます。',
  );
  final scope = AppLocaleText.tr(
    context,
    en: ' These are co-occurring timeline changes, not causal conclusions.',
    zhHans: '这些只是时间轴中共同出现的变化，不代表因果。',
    zhHant: '這些只是時間軸中共同出現的變化，不代表因果。',
    ja: 'これは時系列上で同時に見られた変化であり、因果関係を示すものではありません。',
  );
  return '$range${statements.isEmpty ? fallback : statements}$scope';
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
