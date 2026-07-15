// ignore_for_file: unused_element

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/i18n/app_locale_text.dart';
import '../../../core/models/memory_models.dart';
import '../../../core/preferences/focus_domains.dart';
import '../../../core/readiness/report_readiness.dart';
import '../../../shared/states/load_state.dart';
import '../../../shared/widgets/aurora_ui.dart';
import '../../../shared/widgets/empty_state_block.dart';
import 'journey_display_text.dart';
import 'memory_view_model.dart';

class MemoryPage extends StatelessWidget {
  const MemoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MemoryViewModel>();

    return Scaffold(
      body: Stack(
        children: [
          AuroraPage(
            child: SafeArea(
              bottom: false,
              child: switch (vm.loadState) {
                LoadState.loading =>
                  const Center(child: CircularProgressIndicator()),
                LoadState.error => ListView(
                    key: const ValueKey('journey-scroll-view'),
                    padding: AuroraMainPageSpec.scrollPadding(context),
                    children: [
                      _JourneyTop(summary: vm.summary),
                      const SizedBox(height: AuroraMainPageSpec.heroGap),
                      EmptyStateBlock(
                        icon: Icons.error_outline,
                        title: AppLocaleText.tr(
                          context,
                          en: 'Journey failed to load',
                          zhHans: '旅程加载失败了',
                          zhHant: 'Journey 載入失敗了',
                          ja: 'Journey の読み込みに失敗しました',
                        ),
                        subtitle: vm.errorMessage ??
                            AppLocaleText.tr(
                              context,
                              en: 'Reason: local Journey data or generation failed. Report content starts after 7 eligible SignalCards across 3 local days in the current month.',
                              zhHans:
                                  '原因：本地旅程数据或生成过程读取失败。本月达到 7 条有效 Signal Card、覆盖 3 个本地日期后，才开始显示报告内容。',
                              zhHant:
                                  '原因：本地 Journey 資料或生成過程讀取失敗。本月達到 7 條有效 SignalCard、覆蓋 3 個本地日期後，才開始顯示報告內容。',
                              ja: '理由: Journey データまたは生成の読み込みに失敗しました。今月、有効な SignalCard 7 件とローカル日付 3 日を満たすとレポートを表示します。',
                            ),
                      ),
                    ],
                  ),
                LoadState.empty => _JourneyFormingBody(vm: vm),
                _ => _JourneyReadyBody(vm: vm),
              },
            ),
          ),
          const AuroraSafeTopMask(extraHeight: 4),
        ],
      ),
    );
  }
}

/// The report threshold never hides facts the user already owns.
///
/// Before the monthly synthesis is ready, Journey still exposes the free
/// factual layer (timeline fragments, calendar, curve, and evidence). Only
/// interpretive report sections remain gated.
class _JourneyFormingBody extends StatefulWidget {
  final MemoryViewModel vm;

  const _JourneyFormingBody({required this.vm});

  @override
  State<_JourneyFormingBody> createState() => _JourneyFormingBodyState();
}

class _JourneyFormingBodyState extends State<_JourneyFormingBody> {
  late DateTime _visibleMonth;
  final _calendarKey = GlobalKey();
  final _curveKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final summary = vm.summary;
    final traces = summary == null
        ? const <JourneyTraceModel>[]
        : _userVisibleJourneyTraces(summary.journeyTraces);

    return ListView(
      key: const ValueKey('journey-scroll-view'),
      padding: AuroraMainPageSpec.scrollPadding(context),
      children: [
        // A sparse factual projection can carry a neutral lifeDirection for
        // layout compatibility; do not render it as report text before the
        // evidence threshold is met.
        _JourneyTop(
          summary: null,
          readiness: vm.journeyReadiness,
          vm: vm,
        ),
        const SizedBox(height: AuroraMainPageSpec.heroGap),
        _JourneyFormingSummaryCard(firstDay: vm.showFirstDayGate),
        const SizedBox(height: AuroraMainPageSpec.sectionGap),
        _JourneyReadinessCard(
          readiness: vm.journeyReadiness,
          proReadiness: vm.proReadiness,
          showPro: false,
        ),
        if (summary != null && traces.isNotEmpty) ...[
          const SizedBox(height: AuroraMainPageSpec.sectionGap),
          _JourneyMetricsOverview(
            summary: summary,
            readiness: vm.journeyReadiness,
            onTimeline: () => context.go(
              '${AppRoutes.journeyFragments}?month=${_monthKey(_visibleMonth)}',
            ),
            onCalendar: () => _scrollToJourneySection(_calendarKey),
            onCurve: () => _scrollToJourneySection(_curveKey),
            onEvidence: () => _showJourneyEvidenceSheet(context, vm: vm),
          ),
          const SizedBox(height: AuroraMainPageSpec.sectionGap),
          _JourneyMonthFragments(
            summary: summary,
            month: _visibleMonth,
            vm: vm,
          ),
          const SizedBox(height: AuroraMainPageSpec.sectionGap),
          _JourneyCalendarCard(
            key: _calendarKey,
            month: _visibleMonth,
            traces: traces,
            onPrevious: () => setState(
              () => _visibleMonth = DateTime(
                _visibleMonth.year,
                _visibleMonth.month - 1,
              ),
            ),
            onNext: () => setState(
              () => _visibleMonth = DateTime(
                _visibleMonth.year,
                _visibleMonth.month + 1,
              ),
            ),
          ),
          const SizedBox(height: AuroraMainPageSpec.sectionGap),
          _JourneyLifeCurveCard(
            key: _curveKey,
            month: _visibleMonth,
            traces: traces,
          ),
        ],
        const SizedBox(height: AuroraMainPageSpec.sectionGap),
        _JourneyReadinessCard(
          readiness: vm.journeyReadiness,
          proReadiness: vm.proReadiness,
          showPro: true,
        ),
      ],
    );
  }

  void _scrollToJourneySection(GlobalKey key) {
    final targetContext = key.currentContext;
    if (targetContext == null) return;
    Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }
}

class _JourneyFormingSummaryCard extends StatelessWidget {
  final bool firstDay;

  const _JourneyFormingSummaryCard({required this.firstDay});

  @override
  Widget build(BuildContext context) {
    return _JourneyGlassCard(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _JourneyRoundIcon(
            icon: firstDay ? Icons.route_outlined : Icons.timeline_outlined,
            color: const Color(0xFF7667F5),
            size: 44,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Your Life Journey is forming',
                    zhHans: '报告正在形成',
                    zhHant: '報告正在形成',
                    ja: 'レポートを作成中です',
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF081C4E),
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 5),
                Text(
                  AppLocaleText.tr(
                    context,
                    en: 'The monthly synthesis starts after 7 eligible SignalCards across at least 3 local days. Timeline, calendar, curve, and evidence remain free below.',
                    zhHans:
                        '本月达到 7 条有效 Signal Card、覆盖至少 3 个记录日后开始显示综合；时间线、日历、曲线和证据仍可免费查看。',
                    zhHant:
                        '本月達到 7 條有效 SignalCard、覆蓋至少 3 個記錄日後開始顯示綜合；時間線、日曆、曲線和證據仍可免費查看。',
                    ja: '今月、有効な SignalCard 7 件が 3 日以上に分布すると統合を表示します。時系列、カレンダー、曲線、根拠は無料で確認できます。',
                  ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF49659A),
                        height: 1.42,
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

class JourneyFragmentsPage extends StatelessWidget {
  final String? monthKey;

  const JourneyFragmentsPage({
    super.key,
    this.monthKey,
  });

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MemoryViewModel>();
    final now = DateTime.now();
    final month = DateTime.tryParse('${monthKey ?? _monthKey(now)}-01') ??
        DateTime(now.year, now.month);
    final summary = vm.summary;
    final fragments = summary == null
        ? const <_JourneyFragmentData>[]
        : _fragmentItems(context, summary, month);

    return Scaffold(
      body: AuroraPage(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 34),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => context.go(AppRoutes.memory),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  Expanded(
                    child: Text(
                      AppLocaleText.tr(
                        context,
                        en: 'All fragments this month',
                        zhHans: '本月留下的全部片段',
                        zhHant: '本月留下的全部片段',
                        ja: '今月残した断片',
                      ),
                      textAlign: TextAlign.center,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: AuroraColors.ink,
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _monthLabel(context, month),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: const Color(0xFF7B57E8),
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 16),
              _JourneyGlassCard(
                padding: const EdgeInsets.all(18),
                child: fragments.isEmpty
                    ? Text(
                        AppLocaleText.tr(
                          context,
                          en: 'No fragments have been kept for this month yet.',
                          zhHans: '这个月还没有留下片段。',
                          zhHant: '這個月還沒有留下片段。',
                          ja: '今月の断片はまだありません。',
                        ),
                      )
                    : Column(
                        children: [
                          for (var i = 0; i < fragments.length; i++) ...[
                            _JourneyFragmentRow(
                              data: fragments[i],
                              vm: vm,
                            ),
                            if (i < fragments.length - 1)
                              Divider(
                                height: 1,
                                indent: 58,
                                color: Colors.white.withValues(alpha: 0.82),
                              ),
                          ],
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

void _showJourneyHint(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
      ),
    );
}

Future<void> _showJourneyEvidenceSheet(
  BuildContext context, {
  required MemoryViewModel vm,
  JourneyTraceModel? trace,
}) async {
  final items = (await vm.loadEvidence(trace: trace))
      .where((item) => !_isLegacyScheduleSource(item.sourceType))
      .toList(growable: false);
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return _JourneyEvidenceSheet(
        trace: trace,
        items: items,
        errorMessage: vm.evidenceErrorMessage,
      );
    },
  );
}

class _JourneyEvidenceButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _JourneyEvidenceButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.76),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.90)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.manage_search_rounded,
              size: 18,
              color: Color(0xFF7B57E8),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: const Color(0xFF7B57E8),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JourneyEvidenceSheet extends StatelessWidget {
  final JourneyTraceModel? trace;
  final List<JourneyEvidenceItemModel> items;
  final String? errorMessage;

  const _JourneyEvidenceSheet({
    required this.trace,
    required this.items,
    required this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final title = trace == null
        ? AppLocaleText.tr(
            context,
            en: 'Journey evidence',
            zhHans: '旅程依据',
            zhHant: 'Journey 依據',
            ja: 'Journey の根拠',
          )
        : _localizedGeneratedText(context, trace!.title);
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.38,
      maxChildSize: 0.92,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF9F7FF),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC6B8F7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const _JourneyRoundIcon(
                    icon: Icons.manage_search_rounded,
                    color: Color(0xFF7B57E8),
                    size: 46,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: const Color(0xFF09286A),
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        Text(
                          AppLocaleText.tr(
                            context,
                            en: '${items.length} linked evidence',
                            zhHans: '${items.length} 条关联依据',
                            zhHant: '${items.length} 條關聯依據',
                            ja: '${items.length} 件の根拠',
                          ),
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xFF5C70A4),
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (errorMessage != null)
                _JourneyEvidenceEmpty(message: errorMessage!)
              else if (items.isEmpty)
                _JourneyEvidenceEmpty(
                  message: AppLocaleText.tr(
                    context,
                    en: 'No trace_links evidence was found for this item yet.',
                    zhHans: '还没有找到这条内容对应的 trace_links 依据。',
                    zhHant: '還沒有找到這條內容對應的 trace_links 依據。',
                    ja: 'この項目に対応する trace_links の根拠はまだありません。',
                  ),
                )
              else ...[
                _JourneyEvidenceSourceChips(items: items),
                const SizedBox(height: 12),
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _JourneyEvidenceTile(item: item),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _JourneyEvidenceSourceChips extends StatelessWidget {
  final List<JourneyEvidenceItemModel> items;

  const _JourneyEvidenceSourceChips({required this.items});

  @override
  Widget build(BuildContext context) {
    final sourceTypes = items.map((item) => item.sourceType).toSet().toList();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final sourceType in sourceTypes)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _evidenceColor(sourceType).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: _evidenceColor(sourceType).withValues(alpha: 0.26),
              ),
            ),
            child: Text(
              _evidenceSourceLabel(context, sourceType),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF09286A),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
      ],
    );
  }
}

class _JourneyEvidenceTile extends StatelessWidget {
  final JourneyEvidenceItemModel item;

  const _JourneyEvidenceTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final label = _evidenceSourceLabel(context, item.sourceType);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: _journeyGlassDecoration(radius: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _JourneyRoundIcon(
            icon: _traceIcon(item.sourceType),
            color: _evidenceColor(item.sourceType),
            size: 44,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: const Color(0xFF7B57E8),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if (item.localDate.trim().isNotEmpty)
                      Text(
                        _traceDateLabel(item.localDate),
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: const Color(0xFF5C70A4),
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item.title.trim().isEmpty
                      ? label
                      : localizeJourneyCategoryLabel(context, item.title),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF09286A),
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (item.summary.trim().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    _localizedGeneratedText(context, item.summary),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF315083),
                          height: 1.42,
                          fontWeight: FontWeight.w600,
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

class _JourneyEvidenceEmpty extends StatelessWidget {
  final String message;

  const _JourneyEvidenceEmpty({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: _journeyGlassDecoration(radius: 18),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF5C70A4),
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _JourneyTop extends StatelessWidget {
  final MemorySummaryModel? summary;
  final ReportReadiness? readiness;
  final MemoryViewModel? vm;

  const _JourneyTop({
    required this.summary,
    this.readiness,
    this.vm,
  });

  @override
  Widget build(BuildContext context) {
    return _JourneyHeroSurface(
      summary: summary,
      readiness: readiness,
      vm: vm,
      reportReady: false,
    );
  }
}

class _JourneyHeroSurface extends StatelessWidget {
  final MemorySummaryModel? summary;
  final ReportReadiness? readiness;
  final MemoryViewModel? vm;
  final bool reportReady;

  const _JourneyHeroSurface({
    required this.summary,
    required this.readiness,
    required this.vm,
    required this.reportReady,
  });

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < AuroraMainPageSpec.compactBreakpoint;
    final generated = summary?.longTermPattern?.summary.trim();
    final summaryText = generated != null && generated.isNotEmpty
        ? _localizedGeneratedText(context, generated)
        : AppLocaleText.tr(
            context,
            en: reportReady
                ? 'Your monthly path is taking shape from the signals you kept.'
                : 'Your Life Journey is still forming from the signals you keep.',
            zhHans: reportReady
                ? '这个月的生活轨迹，正在从你留下的信号里变得清晰。'
                : '你的生活地图正在从留下的信号里慢慢形成。',
            zhHant: reportReady
                ? '這個月的生活軌跡，正在從你留下的信號裡變得清晰。'
                : '你的生活地圖正在從留下的信號裡慢慢形成。',
            ja: reportReady
                ? '今月の道すじが、残したシグナルから見え始めています。'
                : 'あなたの生活の旅路は、残したシグナルから少しずつ形になっています。',
          );
    final now = DateTime.now();
    final monthLabel = AppLocaleText.tr(
      context,
      en: '${_englishJourneyMonth(now.month)} · Your life path',
      zhHans: '${now.month}月 · 你的生活轨迹',
      zhHant: '${now.month}月 · 你的生活軌跡',
      ja: '${now.month}月 · あなたの生活の軌跡',
    );

    return ConstrainedBox(
      key: const ValueKey('journey-hero-header'),
      constraints: const BoxConstraints(minHeight: 160),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: compact ? -18 : -12,
            top: compact ? -24 : -30,
            width: compact ? 120 : 144,
            height: compact ? 120 : 144,
            child: IgnorePointer(
              child: AuroraHeroEmblem(
                size: compact ? 120 : 144,
                opacity: 0.82,
              ),
            ),
          ),
          Positioned(
            left: -38,
            top: 52,
            width: 238,
            height: 118,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.58),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(2, compact ? 2 : 4, 2, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.only(right: compact ? 88 : 108),
                  child: AuroraHeroTitle(
                    text: AppLocaleText.tr(
                      context,
                      en: 'Journey',
                      zhHans: '旅程',
                      zhHant: '旅程',
                      ja: '旅程',
                    ),
                    fontSize: compact
                        ? AuroraMainPageSpec.compactHeroTitleSize
                        : AuroraMainPageSpec.heroTitleSize,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        monthLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              color: AuroraColors.ink.withValues(alpha: 0.88),
                              fontSize: compact ? 13.5 : 15,
                              height: 1.1,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    if (vm != null)
                      _JourneyEvidenceButton(
                        label: AppLocaleText.tr(
                          context,
                          en: 'Evidence',
                          zhHans: '查看依据',
                          zhHant: '查看依據',
                          ja: '根拠',
                        ),
                        onTap: () => _showJourneyEvidenceSheet(
                          context,
                          vm: vm!,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 9),
                Padding(
                  padding: EdgeInsets.only(right: compact ? 72 : 94),
                  child: Text(
                    summaryText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AuroraColors.ink.withValues(alpha: 0.78),
                          fontSize: AuroraMainPageSpec.heroSubtitleSize,
                          height: 1.32,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
                if (readiness != null) ...[
                  const SizedBox(height: 9),
                  _JourneyHeroReadiness(
                    readiness: readiness!,
                    reportReady: reportReady,
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

class _JourneyHeroReadiness extends StatelessWidget {
  final ReportReadiness readiness;
  final bool reportReady;

  const _JourneyHeroReadiness({
    required this.readiness,
    required this.reportReady,
  });

  @override
  Widget build(BuildContext context) {
    final accent = reportReady ? const Color(0xFF45B894) : AuroraColors.purple;
    return Row(
      children: [
        Icon(
          reportReady ? Icons.check_circle_rounded : Icons.route_rounded,
          size: 19,
          color: accent,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            reportReady
                ? AppLocaleText.tr(
                    context,
                    en: 'Monthly synthesis ready',
                    zhHans: '月度综合已形成',
                    zhHant: '月度綜合已形成',
                    ja: '月次サマリーができました',
                  )
                : AppLocaleText.tr(
                    context,
                    en: 'Monthly synthesis is forming',
                    zhHans: '月度综合正在形成',
                    zhHant: '月度綜合正在形成',
                    ja: '月次サマリーを作成中',
                  ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            AppLocaleText.tr(
              context,
              en: '${readiness.signalCount} signals · ${readiness.distinctDayCount} record days',
              zhHans:
                  '${readiness.signalCount} 条有效信号 · ${readiness.distinctDayCount} 个记录日',
              zhHant:
                  '${readiness.signalCount} 條有效信號 · ${readiness.distinctDayCount} 個記錄日',
              ja: '${readiness.signalCount} 件 · ${readiness.distinctDayCount} 記録日',
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF49659A),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }
}

String _englishJourneyMonth(int month) {
  return const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ][month - 1];
}

String _localizedGeneratedText(BuildContext context, String text) {
  return localizeJourneyDisplayText(context, text);
}

class _LongTermPatternStrip extends StatelessWidget {
  final int totalCount;
  final MemorySummaryModel summary;

  const _LongTermPatternStrip({
    required this.totalCount,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    return AuroraCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Long-term goal signals',
                    zhHans: '长期目标信号',
                    zhHant: '長期目標信號',
                    ja: '長期目標のシグナル',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _PatternMini(
                  color: AuroraColors.purple,
                  icon: Icons.repeat_rounded,
                  title: AppLocaleText.tr(
                    context,
                    en: 'Repeated',
                    zhHans: '重复模式',
                    zhHant: '重複模式',
                    ja: '反復',
                  ),
                  body: _patternText(
                    context,
                    summary.repeatedPatterns,
                    fallback: AppLocaleText.tr(
                      context,
                      en: 'Repeated signals',
                      zhHans: '重复线索',
                      zhHant: '重複線索',
                      ja: '反復シグナル',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PatternMini(
                  color: AuroraColors.orange,
                  icon: Icons.timeline_rounded,
                  title: AppLocaleText.tr(
                    context,
                    en: 'Stable',
                    zhHans: '稳定模式',
                    zhHant: '穩定模式',
                    ja: '安定',
                  ),
                  body: _patternText(
                    context,
                    summary.stableModes,
                    fallback: AppLocaleText.tr(
                      context,
                      en: 'Stable mode forming',
                      zhHans: '稳定模式形成中',
                      zhHant: '穩定模式形成中',
                      ja: '安定モード形成中',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PatternMini(
                  color: AuroraColors.blue,
                  icon: Icons.trending_up_rounded,
                  title: AppLocaleText.tr(
                    context,
                    en: 'Shifting',
                    zhHans: '变化模式',
                    zhHant: '變化模式',
                    ja: '変化',
                  ),
                  body: AppLocaleText.tr(
                    context,
                    en: '$totalCount signals settling',
                    zhHans: '$totalCount 条长期线索',
                    zhHant: '$totalCount 條長期線索',
                    ja: '$totalCount 件のシグナル',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _patternText(
    BuildContext context,
    List<JourneySignalItemModel> items, {
    required String fallback,
  }) {
    if (items.isEmpty) return fallback;
    final name = items.first.name.trim();
    if (name.isNotEmpty) return name;
    final summary = items.first.summary.trim();
    if (summary.isEmpty) return fallback;
    final first = summary.split(RegExp(r'[。.!！\n]')).first.trim();
    return first.isEmpty ? fallback : first;
  }
}

class _PatternMini extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String body;

  const _PatternMini({
    required this.color,
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuroraSoftIconCircle(
            icon: icon,
            color: color,
            size: 44,
            iconSize: 22,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: color,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _JourneyReadyBody extends StatefulWidget {
  final MemoryViewModel vm;

  const _JourneyReadyBody({required this.vm});

  @override
  State<_JourneyReadyBody> createState() => _JourneyReadyBodyState();
}

class _JourneyReadyBodyState extends State<_JourneyReadyBody> {
  late DateTime _visibleMonth;
  final _calendarKey = GlobalKey();
  final _curveKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.vm.summary;

    if (summary == null || !summary.hasAnySignals) {
      return ListView(
        key: const ValueKey('journey-scroll-view'),
        padding: AuroraMainPageSpec.scrollPadding(context),
        children: [
          _JourneyTop(summary: summary),
          const SizedBox(height: AuroraMainPageSpec.heroGap),
          EmptyStateBlock(
            icon: Icons.timeline_outlined,
            title: AppLocaleText.tr(
              context,
              en: 'No long-term signals yet',
              zhHans: '生活地图正在形成',
              zhHant: '生活地圖正在形成',
              ja: '生活の旅路が形になり始めています',
            ),
            subtitle: AppLocaleText.tr(
              context,
              en: 'Reason: no eligible Journey records were found yet. It starts with SignalCard, feedback, Weekly Review, Life Experiment, or manual reflection data.',
              zhHans:
                  '原因：还没有找到可进入旅程的记录。Signal Card、反馈、每周复盘、生活小实验或手动反思出现后会开始显示。',
              zhHant:
                  '原因：還沒有找到可進入 Journey 的記錄。SignalCard、回饋、Weekly Review、Life Experiment 或手動反思出現後會開始顯示。',
              ja: '理由: Journey に使える記録がまだありません。SignalCard、反応、Weekly Review、Life Experiment、手動の振り返りで表示が始まります。',
            ),
          ),
        ],
      );
    }

    return ListView(
      key: const ValueKey('journey-scroll-view'),
      scrollCacheExtent: const ScrollCacheExtent.pixels(900),
      padding: AuroraMainPageSpec.scrollPadding(context),
      children: [
        _DreamJourneyHero(
          summary: summary,
          vm: widget.vm,
          readiness: widget.vm.journeyReadiness,
        ),
        const SizedBox(height: AuroraMainPageSpec.heroGap),
        _JourneyMetricsOverview(
          summary: summary,
          readiness: widget.vm.journeyReadiness,
          onTimeline: () => context.go(
            '${AppRoutes.journeyFragments}?month=${_monthKey(_visibleMonth)}',
          ),
          onCalendar: () => _scrollToJourneySection(_calendarKey),
          onCurve: () => _scrollToJourneySection(_curveKey),
          onEvidence: () => _showJourneyEvidenceSheet(
            context,
            vm: widget.vm,
          ),
        ),
        const SizedBox(height: AuroraMainPageSpec.sectionGap),
        _JourneyFeaturedPatternCard(
          summary: summary,
          readiness: widget.vm.journeyReadiness,
          vm: widget.vm,
        ),
        const SizedBox(height: AuroraMainPageSpec.sectionGap),
        _JourneyReadinessCard(
          readiness: widget.vm.journeyReadiness,
          proReadiness: widget.vm.proReadiness,
          showPro: true,
        ),
        const SizedBox(height: AuroraMainPageSpec.sectionGap),
        _JourneyMonthFragments(
          summary: summary,
          month: _visibleMonth,
          vm: widget.vm,
        ),
        if (summary.observations.length > 1) ...[
          const SizedBox(height: AuroraMainPageSpec.sectionGap),
          _JourneyObservationsCard(
            summary: summary,
            vm: widget.vm,
          ),
        ],
        const SizedBox(height: AuroraMainPageSpec.sectionGap),
        _JourneyCalendarCard(
          key: _calendarKey,
          month: _visibleMonth,
          traces: _userVisibleJourneyTraces(summary.journeyTraces),
          onPrevious: () => setState(
            () => _visibleMonth = DateTime(
              _visibleMonth.year,
              _visibleMonth.month - 1,
            ),
          ),
          onNext: () => setState(
            () => _visibleMonth = DateTime(
              _visibleMonth.year,
              _visibleMonth.month + 1,
            ),
          ),
        ),
        const SizedBox(height: AuroraMainPageSpec.sectionGap),
        _JourneyLifeCurveCard(
          key: _curveKey,
          month: _visibleMonth,
          traces: _userVisibleJourneyTraces(summary.journeyTraces),
        ),
        const SizedBox(height: AuroraMainPageSpec.sectionGap),
        _JourneyGentleReviewCard(summary: summary, month: _visibleMonth),
      ],
    );
  }

  void _scrollToJourneySection(GlobalKey key) {
    final targetContext = key.currentContext;
    if (targetContext == null) return;
    Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  String _headerSubtitle(BuildContext context, String? focusArea) {
    final focusLabel = _focusAreaLabel(context, focusArea);
    return AppLocaleText.tr(
      context,
      en: 'Long-term signals around $focusLabel',
      zhHans: '围绕「$focusLabel」的长期线索',
      zhHant: '圍繞「$focusLabel」的長期線索',
      ja: '「$focusLabel」をめぐる長期的な手がかり',
    );
  }

  String _focusAreaLabel(BuildContext context, String? value) {
    final option = FocusDomains.optionFor(value);
    if (option != null) return option.label(context);
    return AppLocaleText.tr(context,
        en: 'your recent records',
        zhHans: '最近的记录',
        zhHant: '最近的記錄',
        ja: '最近の記録');
  }
}

class _JourneyReadinessCard extends StatelessWidget {
  final ReportReadiness readiness;
  final ReportReadiness proReadiness;
  final bool showPro;

  const _JourneyReadinessCard({
    required this.readiness,
    required this.proReadiness,
    required this.showPro,
  });

  @override
  Widget build(BuildContext context) {
    final active = showPro ? proReadiness : readiness;
    final title = showPro
        ? AppLocaleText.tr(
            context,
            en: 'Pro L3 report readiness',
            zhHans: 'Pro 深度分析报告进度',
            zhHant: 'Pro L3 深度報告進度',
            ja: 'Pro L3 レポートの準備状況',
          )
        : AppLocaleText.tr(
            context,
            en: 'Journey report readiness',
            zhHans: '旅程报告进度',
            zhHant: 'Journey 報告進度',
            ja: 'Journey レポートの準備状況',
          );
    return _JourneyGlassCard(
      key: ValueKey(showPro
          ? 'journey-pro-report-readiness'
          : 'journey-report-readiness'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  showPro
                      ? AppLocaleText.tr(
                          context,
                          en: 'Pro L3 deep review',
                          zhHans: 'Pro 深度分析',
                          zhHant: 'Pro L3 深度回看',
                          ja: 'Pro L3 深い振り返り',
                        )
                      : title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF081C4E),
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              if (showPro)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AuroraColors.gold.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Pro',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: const Color(0xFFB36B13),
                          fontWeight: FontWeight.w700,
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                )
              else if (active.isReady)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AuroraColors.mint,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            active.isReady
                ? (showPro
                    ? AppLocaleText.tr(
                        context,
                        en: 'The evidence threshold for period comparison is ready.',
                        zhHans: '已达到跨周期深度综合所需的数据门槛。',
                        zhHant: '已達到跨週期深度綜合所需的資料門檻。',
                        ja: '期間比較に必要なデータ条件を満たしました。',
                      )
                    : AppLocaleText.tr(
                        context,
                        en: 'Journey report is ready.',
                        zhHans: '旅程报告已经可以显示。',
                        zhHant: 'Journey 報告已經可以顯示。',
                        ja: 'Journey レポートを表示できます。',
                      ))
                : showPro
                    ? AppLocaleText.tr(
                        context,
                        en: 'Cross-period evidence from the latest 28 days is still forming.',
                        zhHans: '近 28 天的跨周期证据还在形成',
                        zhHant: '近 28 天的跨週期證據還在形成',
                        ja: '直近 28 日の期間比較の根拠を作成中です。',
                      )
                    : AppLocaleText.tr(
                        context,
                        en: 'The monthly evidence is still forming.',
                        zhHans: '本月综合所需的证据还在形成。',
                        zhHant: '本月綜合所需的證據還在形成。',
                        ja: '月次サマリーに必要な根拠を作成中です。',
                      ),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF49659A),
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: _JourneyReadinessMetric(
                  value: AppLocaleText.tr(
                    context,
                    en: '${active.signalCount}/${showPro ? 14 : 7} signals',
                    zhHans: '${active.signalCount}/${showPro ? 14 : 7} 条信号',
                    zhHant: '${active.signalCount}/${showPro ? 14 : 7} 條信號',
                    ja: '${active.signalCount}/${showPro ? 14 : 7} 件',
                  ),
                  met: active.signalCount >= (showPro ? 14 : 7),
                  color: const Color(0xFF7667F5),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _JourneyReadinessMetric(
                  value: AppLocaleText.tr(
                    context,
                    en: '${active.distinctDayCount}/${showPro ? 7 : 3} days',
                    zhHans:
                        '${active.distinctDayCount}/${showPro ? 7 : 3} 个记录日',
                    zhHant:
                        '${active.distinctDayCount}/${showPro ? 7 : 3} 個記錄日',
                    ja: '${active.distinctDayCount}/${showPro ? 7 : 3} 日',
                  ),
                  met: active.distinctDayCount >= (showPro ? 7 : 3),
                  color: const Color(0xFF4E8FF2),
                ),
              ),
              if (showPro) ...[
                const SizedBox(width: 7),
                Expanded(
                  child: _JourneyReadinessMetric(
                    value: AppLocaleText.tr(
                      context,
                      en: '${active.distinctWeekCount}/2 weeks',
                      zhHans: '${active.distinctWeekCount}/2 个自然周',
                      zhHant: '${active.distinctWeekCount}/2 個自然週',
                      ja: '${active.distinctWeekCount}/2 週',
                    ),
                    met: active.distinctWeekCount >= 2,
                    color: const Color(0xFF45B894),
                  ),
                ),
              ],
            ],
          ),
          if (showPro) ...[
            const SizedBox(height: 9),
            SizedBox(
              height: 38,
              child: OutlinedButton.icon(
                onPressed: () => context.push(AppRoutes.journeyPro),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                iconAlignment: IconAlignment.end,
                label: Text(
                  active.isReady
                      ? AppLocaleText.tr(
                          context,
                          en: 'Open Pro L3 report',
                          zhHans: '打开 Pro 深度分析报告',
                          zhHant: '打開 Pro L3 報告',
                          ja: 'Pro L3 レポートを開く',
                        )
                      : AppLocaleText.tr(
                          context,
                          en: 'View Pro L3 progress',
                          zhHans: '查看 Pro 深度分析进度',
                          zhHant: '查看 Pro L3 進度',
                          ja: 'Pro L3 の進捗を見る',
                        ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF6957EE),
                  side: BorderSide(
                    color: const Color(0xFF7667F5).withValues(alpha: 0.38),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _JourneyReadinessMetric extends StatelessWidget {
  final String value;
  final bool met;
  final Color color;

  const _JourneyReadinessMetric({
    required this.value,
    required this.met,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          met ? Icons.check_circle_rounded : Icons.circle_outlined,
          size: 18,
          color: met ? const Color(0xFF45B894) : color,
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: const Color(0xFF233B69),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }
}

class _DreamJourneyHero extends StatelessWidget {
  final MemorySummaryModel summary;
  final MemoryViewModel vm;
  final ReportReadiness readiness;

  const _DreamJourneyHero({
    required this.summary,
    required this.vm,
    required this.readiness,
  });

  @override
  Widget build(BuildContext context) {
    return _JourneyHeroSurface(
      summary: summary,
      readiness: readiness,
      vm: vm,
      reportReady: true,
    );
  }
}

class _JourneyMetricsOverview extends StatelessWidget {
  final MemorySummaryModel summary;
  final ReportReadiness readiness;
  final VoidCallback onTimeline;
  final VoidCallback onCalendar;
  final VoidCallback onCurve;
  final VoidCallback onEvidence;

  const _JourneyMetricsOverview({
    required this.summary,
    required this.readiness,
    required this.onTimeline,
    required this.onCalendar,
    required this.onCurve,
    required this.onEvidence,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _JourneyMetricData(
        icon: Icons.route_rounded,
        color: const Color(0xFF7667F5),
        title: AppLocaleText.tr(
          context,
          en: 'Signals',
          zhHans: '信号',
          zhHant: '信號',
          ja: 'シグナル',
        ),
        value: '${readiness.signalCount}',
        unit: AppLocaleText.tr(
          context,
          en: '',
          zhHans: '条',
          zhHant: '條',
          ja: '件',
        ),
      ),
      _JourneyMetricData(
        icon: Icons.calendar_month_rounded,
        color: const Color(0xFF4E8FF2),
        title: AppLocaleText.tr(
          context,
          en: 'Record days',
          zhHans: '记录日',
          zhHant: '記錄日',
          ja: '記録日',
        ),
        value: '${readiness.distinctDayCount}',
        unit: AppLocaleText.tr(
          context,
          en: 'days',
          zhHans: '天',
          zhHant: '天',
          ja: '日',
        ),
      ),
      _JourneyMetricData(
        icon: Icons.science_rounded,
        color: const Color(0xFF45B894),
        title: AppLocaleText.tr(
          context,
          en: 'Related experiments',
          zhHans: '相关实验',
          zhHant: '相關實驗',
          ja: '関連実験',
        ),
        value: '${summary.experiments.length}',
        unit: AppLocaleText.tr(context,
            en: '', zhHans: '个', zhHant: '個', ja: '件'),
      ),
    ];

    return _JourneyGlassCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Track overview',
                    zhHans: '本月轨迹概览',
                    zhHant: '本月軌跡概覽',
                    ja: '今月の軌跡',
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF081C4E),
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Text(
                AppLocaleText.tr(
                  context,
                  en: _englishJourneyMonth(DateTime.now().month),
                  zhHans: '${DateTime.now().month}月',
                  zhHant: '${DateTime.now().month}月',
                  ja: '${DateTime.now().month}月',
                ),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: const Color(0xFF49659A),
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              const columns = 3;
              const spacing = 10.0;
              final itemWidth =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final item in items)
                    SizedBox(
                      width: itemWidth,
                      child: _JourneyMetricTile(data: item),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: _JourneyFactShortcut(
                  icon: Icons.timeline_rounded,
                  label: AppLocaleText.tr(
                    context,
                    en: 'Timeline',
                    zhHans: '时间线',
                    zhHant: '時間線',
                    ja: '時系列',
                  ),
                  color: const Color(0xFF7667F5),
                  onTap: onTimeline,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _JourneyFactShortcut(
                  icon: Icons.calendar_month_rounded,
                  label: AppLocaleText.tr(
                    context,
                    en: 'Calendar',
                    zhHans: '日历',
                    zhHant: '日曆',
                    ja: 'カレンダー',
                  ),
                  color: const Color(0xFF4E8FF2),
                  onTap: onCalendar,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _JourneyFactShortcut(
                  icon: Icons.show_chart_rounded,
                  label: AppLocaleText.tr(
                    context,
                    en: 'Curve',
                    zhHans: '曲线',
                    zhHant: '曲線',
                    ja: '曲線',
                  ),
                  color: const Color(0xFF45B894),
                  onTap: onCurve,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _JourneyFactShortcut(
                  icon: Icons.manage_search_rounded,
                  label: AppLocaleText.tr(
                    context,
                    en: 'Evidence',
                    zhHans: '证据',
                    zhHant: '證據',
                    ja: '根拠',
                  ),
                  color: const Color(0xFFFF9A55),
                  onTap: onEvidence,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _JourneyFactShortcut extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _JourneyFactShortcut({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.52),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFCAD8F0).withValues(alpha: 0.62),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF102B67),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JourneyFeaturedPatternCard extends StatelessWidget {
  final MemorySummaryModel summary;
  final ReportReadiness readiness;
  final MemoryViewModel vm;

  const _JourneyFeaturedPatternCard({
    required this.summary,
    required this.readiness,
    required this.vm,
  });

  @override
  Widget build(BuildContext context) {
    final observations = summary.observations;
    final observation = observations.isEmpty
        ? null
        : observations.firstWhere(
            (item) => item.isConfirmed,
            orElse: () => observations.first,
          );
    final repeated = summary.repeatedPatterns.isNotEmpty
        ? summary.repeatedPatterns.first
        : summary.longTermPattern;
    final patternText =
        observation != null && observation.suggestedPattern.trim().isNotEmpty
            ? _localizedGeneratedText(context, observation.suggestedPattern)
            : repeated != null && repeated.summary.trim().isNotEmpty
                ? _localizedGeneratedText(context, repeated.summary)
                : observation != null
                    ? _localizedGeneratedText(context, observation.text)
                    : AppLocaleText.tr(
                        context,
                        en: 'A repeated pattern is beginning to become clearer.',
                        zhHans: '一个反复出现的生活模式正在变得更清晰。',
                        zhHant: '一個反覆出現的生活模式正在變得更清晰。',
                        ja: 'くり返し現れるパターンが少しずつ見えてきました。',
                      );
    final experimentCount = summary.experiments.length;

    return _JourneyGlassCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'A pattern repeating this month',
                    zhHans: '本月反复出现的模式',
                    zhHant: '本月反覆出現的模式',
                    ja: '今月くり返し現れたパターン',
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF081C4E),
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              _JourneyPatternClarityPill(),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _JourneyRoundIcon(
                icon: Icons.sync_alt_rounded,
                color: Color(0xFF55BFA3),
                size: 42,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  patternText,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF102B67),
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final evidenceLink = InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => _showJourneyEvidenceSheet(
                  context,
                  vm: vm,
                  trace: observation == null
                      ? null
                      : _observationTrace(observation),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppLocaleText.tr(
                          context,
                          en: 'View evidence',
                          zhHans: '查看依据',
                          zhHant: '查看依據',
                          ja: '根拠を見る',
                        ),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: const Color(0xFF6957EE),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF6957EE),
                        size: 19,
                      ),
                    ],
                  ),
                ),
              );
              final chips = <Widget>[
                _JourneyEvidenceCountChip(
                  label: AppLocaleText.tr(
                    context,
                    en: '${readiness.signalCount} signals',
                    zhHans: '${readiness.signalCount} 条信号',
                    zhHant: '${readiness.signalCount} 條信號',
                    ja: '${readiness.signalCount} 件のシグナル',
                  ),
                  color: const Color(0xFF7667F5),
                ),
                if (experimentCount > 0)
                  _JourneyEvidenceCountChip(
                    label: AppLocaleText.tr(
                      context,
                      en: '$experimentCount experiment clues',
                      zhHans: '$experimentCount 次实验线索',
                      zhHant: '$experimentCount 次實驗線索',
                      ja: '実験の手がかり $experimentCount 件',
                    ),
                    color: const Color(0xFF4E8FF2),
                  ),
              ];
              if (constraints.maxWidth < 360) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(spacing: 7, runSpacing: 7, children: chips),
                    Align(
                      alignment: Alignment.centerRight,
                      child: evidenceLink,
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  ...chips.expand(
                    (chip) => [
                      Flexible(child: chip),
                      const SizedBox(width: 7),
                    ],
                  ),
                  const Spacer(),
                  evidenceLink,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _JourneyPatternClarityPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF55BFA3).withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        AppLocaleText.tr(
          context,
          en: 'Getting clearer',
          zhHans: '逐渐清晰',
          zhHant: '逐漸清晰',
          ja: '見えてきた',
        ),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: const Color(0xFF319476),
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _JourneyEvidenceCountChip extends StatelessWidget {
  final String label;
  final Color color;

  const _JourneyEvidenceCountChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 112),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.54)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _JourneyObservationsCard extends StatelessWidget {
  final MemorySummaryModel summary;
  final MemoryViewModel vm;

  const _JourneyObservationsCard({
    required this.summary,
    required this.vm,
  });

  @override
  Widget build(BuildContext context) {
    final observations = summary.observations.take(5).toList(growable: false);
    if (observations.isEmpty) return const SizedBox.shrink();

    final confirmedCount =
        observations.where((observation) => observation.isConfirmed).length;
    final generatedCount = observations
        .where((observation) => observation.status == 'generated')
        .length;
    final dismissedCount =
        observations.where((observation) => observation.isDismissed).length;

    return _JourneyGlassCard(
      padding: AuroraMainPageSpec.comfortableCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _JourneySectionTitle(
            title: AppLocaleText.tr(
              context,
              en: 'Repeated observations',
              zhHans: '本月反复出现的观察',
              zhHant: '本月反覆出現的觀察',
              ja: '今月くり返し見えた観察',
            ),
            suffix: AppLocaleText.tr(
              context,
              en: 'clearer patterns',
              zhHans: '逐渐清晰的模式',
              zhHant: '逐漸清晰的模式',
              ja: '見えてきたパターン',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocaleText.tr(
              context,
              en: '$confirmedCount confirmed · $generatedCount generated · $dismissedCount dismissed',
              zhHans:
                  '$confirmedCount 条已确认 · $generatedCount 条生成中 · $dismissedCount 条已排除',
              zhHant:
                  '$confirmedCount 條已確認 · $generatedCount 條生成中 · $dismissedCount 條已排除',
              ja: '$confirmedCount 件確認済み · $generatedCount 件生成 · $dismissedCount 件却下',
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF5C70A4),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < observations.length; i++) ...[
            _JourneyObservationRow(
              observation: observations[i],
              onTap: () => _showJourneyEvidenceSheet(
                context,
                vm: vm,
                trace: _observationTrace(observations[i]),
              ),
            ),
            if (i < observations.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _JourneyObservationRow extends StatelessWidget {
  final JourneyObservationModel observation;
  final VoidCallback onTap;

  const _JourneyObservationRow({
    required this.observation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _observationStatusColor(observation.status);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(13, 12, 12, 12),
        decoration: BoxDecoration(
          color: observation.isDismissed
              ? Colors.white.withValues(alpha: 0.42)
              : Colors.white.withValues(alpha: 0.68),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color:
                color.withValues(alpha: observation.isDismissed ? 0.18 : 0.28),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _JourneyRoundIcon(
              icon: observation.isConfirmed
                  ? Icons.check_circle_rounded
                  : observation.isDismissed
                      ? Icons.do_not_disturb_on_rounded
                      : Icons.psychology_alt_rounded,
              color: color,
              size: 42,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _JourneyObservationStatusPill(
                        status: observation.status,
                      ),
                      if (observation.localDate.trim().isNotEmpty)
                        Text(
                          _traceDateLabel(observation.localDate),
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: const Color(0xFF5C70A4),
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _localizedGeneratedText(context, observation.text),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: observation.isDismissed
                              ? const Color(0xFF7180A8)
                              : const Color(0xFF09286A),
                          height: 1.38,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if (observation.suggestedPattern.trim().isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      _localizedGeneratedText(
                        context,
                        observation.suggestedPattern,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF5C70A4),
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.manage_search_rounded,
              color: color,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _JourneyObservationStatusPill extends StatelessWidget {
  final String status;

  const _JourneyObservationStatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _observationStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Text(
        _observationStatusLabel(context, status),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _JourneyMonthFragments extends StatelessWidget {
  final MemorySummaryModel summary;
  final DateTime month;
  final MemoryViewModel vm;

  const _JourneyMonthFragments({
    required this.summary,
    required this.month,
    required this.vm,
  });

  @override
  Widget build(BuildContext context) {
    final fragments = _fragmentItems(context, summary, month).take(3).toList();
    return _JourneyGlassCard(
      padding: AuroraMainPageSpec.comfortableCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _JourneySectionTitle(
                  title: AppLocaleText.tr(
                    context,
                    en: 'Fragments kept this month',
                    zhHans: '本月留下的片段',
                    zhHant: '本月留下的片段',
                    ja: '今月残した断片',
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => context.go(
                  '${AppRoutes.journeyFragments}?month=${_monthKey(month)}',
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Row(
                    children: [
                      Text(
                        AppLocaleText.tr(context,
                            en: 'View all',
                            zhHans: '查看全部',
                            zhHant: '查看全部',
                            ja: 'すべて見る'),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: const Color(0xFF7B57E8),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(Icons.chevron_right_rounded,
                          color: Color(0xFF7B57E8), size: 21),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (fragments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                AppLocaleText.tr(
                  context,
                  en: 'No fragments have been kept for this month yet.',
                  zhHans: '这个月还没有留下片段。',
                  zhHant: '這個月還沒有留下片段。',
                  ja: '今月の断片はまだありません。',
                ),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF5C70A4),
                      fontWeight: FontWeight.w700,
                    ),
              ),
            )
          else
            for (var i = 0; i < fragments.length; i++) ...[
              _JourneyFragmentRow(data: fragments[i], vm: vm),
              if (i < fragments.length - 1)
                Divider(
                  height: 1,
                  indent: 58,
                  color: Colors.white.withValues(alpha: 0.82),
                ),
            ],
        ],
      ),
    );
  }
}

class _JourneyCalendarCard extends StatelessWidget {
  final DateTime month;
  final List<JourneyTraceModel> traces;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _JourneyCalendarCard({
    super.key,
    required this.month,
    required this.traces,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return _JourneyGlassCard(
      padding: AuroraMainPageSpec.comfortableCardPadding,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _JourneySectionTitle(
                  title: AppLocaleText.tr(context,
                      en: 'Monthly view',
                      zhHans: '月度视图',
                      zhHant: '月度視圖',
                      ja: '月間ビュー'),
                ),
              ),
              _SmallCircleButton(
                icon: Icons.chevron_left_rounded,
                onTap: onPrevious,
              ),
              const SizedBox(width: 16),
              Text(
                _monthLabel(context, month),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: const Color(0xFF7B57E8),
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(width: 16),
              _SmallCircleButton(
                icon: Icons.chevron_right_rounded,
                onTap: onNext,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
            ),
            child: _JourneyCalendarGrid(month: month, traces: traces),
          ),
        ],
      ),
    );
  }
}

class _JourneyLifeCurveCard extends StatelessWidget {
  final DateTime month;
  final List<JourneyTraceModel> traces;

  const _JourneyLifeCurveCard({
    super.key,
    required this.month,
    required this.traces,
  });

  @override
  Widget build(BuildContext context) {
    final monthTraces =
        traces.where((trace) => _sameMonth(trace.localDate, month)).toList();
    return _JourneyGlassCard(
      padding: AuroraMainPageSpec.comfortableCardPadding,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _JourneySectionTitle(
                  title: AppLocaleText.tr(context,
                      en: 'Life state curve',
                      zhHans: '生活状态曲线',
                      zhHant: '生活狀態曲線',
                      ja: '生活状態の曲線'),
                  infoIcon: true,
                ),
              ),
              Text(
                _monthLabel(context, month),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: const Color(0xFF5C70A4),
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 158,
            child: Row(
              children: [
                const Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CurveLegend(
                        icon: Icons.mood_rounded,
                        color: Color(0xFFFF6CA8),
                        label: '情绪'),
                    _CurveLegend(
                        icon: Icons.bolt_rounded,
                        color: Color(0xFFFFAF49),
                        label: '能量'),
                    _CurveLegend(
                        icon: Icons.track_changes_rounded,
                        color: Color(0xFF55A4FF),
                        label: '专注'),
                    _CurveLegend(
                        icon: Icons.spa_rounded,
                        color: Color(0xFF45CDBB),
                        label: '平静'),
                    _CurveLegend(
                        icon: Icons.groups_rounded,
                        color: Color(0xFF9B78F5),
                        label: '社交'),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: CustomPaint(
                    painter: _JourneyCurvePainter(
                      month: month,
                      traces: monthTraces,
                    ),
                    child: const SizedBox.expand(),
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

class _JourneyGentleReviewCard extends StatelessWidget {
  final MemorySummaryModel summary;
  final DateTime month;

  const _JourneyGentleReviewCard({
    required this.summary,
    required this.month,
  });

  @override
  Widget build(BuildContext context) {
    final rows = _gentleReviewRows(context, summary, month);
    return _JourneyGlassCard(
      padding: AuroraMainPageSpec.comfortableCardPadding,
      child: Stack(
        children: [
          Positioned(
            right: -8,
            bottom: -8,
            child: Opacity(
              opacity: 0.72,
              child: Image.asset(
                'assets/journey/journey-review-road.png',
                width: 232,
                height: 118,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _JourneySectionTitle(
                title: AppLocaleText.tr(context,
                    en: 'Gentle review',
                    zhHans: '温柔回顾',
                    zhHant: '溫柔回顧',
                    ja: 'やさしい振り返り'),
              ),
              const SizedBox(height: 10),
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _JourneyRoundIcon(icon: row.$1, color: row.$2, size: 42),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          row.$3,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xFF173773),
                                    height: 1.42,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _JourneyGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _JourneyGlassCard({
    super.key,
    required this.child,
    this.padding = AuroraMainPageSpec.comfortableCardPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _journeyGlassDecoration(
        radius: AuroraMainPageSpec.cardRadiusLarge,
      ),
      padding: padding,
      child: child,
    );
  }
}

class _JourneySectionTitle extends StatelessWidget {
  final String title;
  final String? suffix;
  final bool infoIcon;

  const _JourneySectionTitle({
    required this.title,
    this.suffix,
    this.infoIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('✦', style: TextStyle(color: Color(0xFFE6B7FF))),
        const SizedBox(width: 6),
        Flexible(
          child: suffix == null
              ? Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF09286A),
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                )
              : Text.rich(
                  TextSpan(
                    text: title,
                    children: [
                      TextSpan(
                        text: '  $suffix',
                        style: const TextStyle(
                          fontSize: AuroraMainPageSpec.supportingSize,
                          color: Color(0xFF49659A),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF09286A),
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                ),
        ),
        if (infoIcon) ...[
          const SizedBox(width: 7),
          const Icon(Icons.info_outline_rounded,
              size: 17, color: Color(0xFF8794C2)),
        ],
      ],
    );
  }
}

class _JourneyMetricData {
  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String unit;

  const _JourneyMetricData({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.unit,
  });
}

class _JourneyMetricTile extends StatelessWidget {
  final _JourneyMetricData data;

  const _JourneyMetricTile({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFCAD8F0).withValues(alpha: 0.62),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text.rich(
            TextSpan(
              text: data.value,
              children: [
                TextSpan(
                  text: data.unit.isEmpty ? '' : ' ${data.unit}',
                  style: const TextStyle(
                    color: Color(0xFF315083),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: data.color,
                  fontSize: 23,
                  height: 1,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 5),
          Text(
            data.title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF233B69),
                  fontSize: AuroraMainPageSpec.supportingSize,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _JourneyFragmentData {
  final IconData icon;
  final Color color;
  final String title;
  final String meta;
  final String localDate;
  final JourneyTraceModel trace;

  const _JourneyFragmentData({
    required this.icon,
    required this.color,
    required this.title,
    required this.meta,
    required this.localDate,
    required this.trace,
  });
}

class _JourneyFragmentRow extends StatelessWidget {
  final _JourneyFragmentData data;
  final MemoryViewModel vm;

  const _JourneyFragmentRow({
    required this.data,
    required this.vm,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.go('${AppRoutes.journal}?date=${data.localDate}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            _JourneyRoundIcon(icon: data.icon, color: data.color, size: 48),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: const Color(0xFF09286A),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    data.meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF5C70A4),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: AppLocaleText.tr(
                context,
                en: 'View evidence',
                zhHans: '查看依据',
                zhHant: '查看依據',
                ja: '根拠を見る',
              ),
              onPressed: () => _showJourneyEvidenceSheet(
                context,
                vm: vm,
                trace: data.trace,
              ),
              icon: const Icon(
                Icons.manage_search_rounded,
                color: Color(0xFF7B57E8),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFF8E74E8), size: 26),
          ],
        ),
      ),
    );
  }
}

class _JourneyCalendarGrid extends StatelessWidget {
  final DateTime month;
  final List<JourneyTraceModel> traces;

  const _JourneyCalendarGrid({
    required this.month,
    required this.traces,
  });

  @override
  Widget build(BuildContext context) {
    final days = ['日', '一', '二', '三', '四', '五', '六'];
    final first = DateTime(month.year, month.month);
    final leading = first.weekday % 7;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final cellCount = ((leading + daysInMonth + 6) ~/ 7) * 7;
    final markersByDay = <int, List<Color>>{};
    for (final trace
        in traces.where((trace) => _sameMonth(trace.localDate, month))) {
      final parsed = DateTime.tryParse(trace.localDate);
      if (parsed == null) continue;
      markersByDay.putIfAbsent(parsed.day, () => []).add(_traceColor(trace));
    }
    return Column(
      children: [
        Row(
          children: [
            for (final day in days)
              Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: const Color(0xFF5C70A4),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cellCount,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: 34,
          ),
          itemBuilder: (context, index) {
            final day = index - leading + 1;
            final faded = day < 1 || day > daysInMonth;
            final display = faded ? '' : '$day';
            final markers = faded
                ? const <Color>[]
                : (markersByDay[day] ?? const <Color>[]);
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  display,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: faded
                            ? const Color(0xFFAEB6D7)
                            : const Color(0xFF09286A),
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final color in markers.take(2))
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration:
                            BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        const Wrap(
          alignment: WrapAlignment.center,
          spacing: 18,
          runSpacing: 6,
          children: [
            _CalendarLegend(color: Color(0xFF63D4A6), label: '记录'),
            _CalendarLegend(color: Color(0xFFFF9A55), label: '重要时刻'),
            _CalendarLegend(color: Color(0xFF8B62E8), label: '反思记录'),
            _CalendarLegend(color: Color(0xFF55A4FF), label: '实验关联'),
          ],
        ),
      ],
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _CalendarLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: const Color(0xFF5C70A4),
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _CurveLegend extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _CurveLegend({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: color.withValues(alpha: 0.9),
          child: Icon(icon, color: Colors.white, size: 15),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _SegmentedPill extends StatelessWidget {
  final List<String> labels;

  const _SegmentedPill({required this.labels});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.84)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Container(
              width: 44,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: i == 0
                    ? const LinearGradient(
                        colors: [Color(0xFFB58BFF), Color(0xFF7B57E8)])
                    : null,
              ),
              child: Text(
                labels[i],
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: i == 0 ? Colors.white : const Color(0xFF5C70A4),
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SmallCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _SmallCircleButton({
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 29,
        height: 29,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.72),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.86)),
        ),
        child: Icon(icon, color: const Color(0xFF09286A), size: 20),
      ),
    );
  }
}

class _JourneyRoundIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _JourneyRoundIcon({
    required this.icon,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.42, -0.48),
          colors: [
            Colors.white.withValues(alpha: 0.96),
            color.withValues(alpha: 0.48),
            color.withValues(alpha: 0.88),
          ],
          stops: const [0, 0.55, 1],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.5),
    );
  }
}

class _JourneyCurvePainter extends CustomPainter {
  final DateTime month;
  final List<JourneyTraceModel> traces;

  const _JourneyCurvePainter({
    required this.month,
    required this.traces,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.38)
      ..strokeWidth = 1;
    for (var i = 0; i < 5; i++) {
      final y = size.height * (i + 1) / 6;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final grouped = <String, List<JourneyTraceModel>>{};
    for (final trace in traces) {
      grouped.putIfAbsent(trace.cluster, () => []).add(trace);
    }
    final specs = grouped.entries.isEmpty
        ? [
            const MapEntry('life', <JourneyTraceModel>[]),
          ]
        : grouped.entries.take(5).toList();
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    for (final entry in specs) {
      final color = _clusterCurveColor(entry.key);
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final path = Path();
      final points = entry.value.isEmpty
          ? List.generate(
              4,
              (index) => (
                x: size.width * index / 3,
                y: size.height * (0.58 + 0.08 * _wave(index, 0.4)),
              ),
            )
          : entry.value.map((trace) {
              final parsed = DateTime.tryParse(trace.localDate);
              final day = parsed?.day ?? 1;
              final x = size.width * (day - 1) / math.max(1, daysInMonth - 1);
              final y = size.height * (1 - trace.intensity.clamp(0.1, 0.95));
              return (x: x, y: y);
            }).toList()
        ..sort((a, b) => a.x.compareTo(b.x));
      for (var i = 0; i < points.length; i++) {
        final point = points[i];
        if (i == 0) {
          path.moveTo(point.x, point.y);
        } else {
          final prev = points[i - 1];
          final control =
              Offset((prev.x + point.x) / 2, (prev.y + point.y) / 2);
          path.quadraticBezierTo(control.dx, control.dy, point.x, point.y);
        }
      }
      canvas.drawPath(path, paint);
      final last = Offset(points.last.x, points.last.y);
      canvas.drawCircle(last, 5, Paint()..color = Colors.white);
      canvas.drawCircle(last, 4, Paint()..color = color);
    }
  }

  double _wave(num x, double seed) {
    return 0.55 * (x % 2 == 0 ? -1 : 1) +
        0.35 * (((x * 3 + seed * 10) % 4) - 1.5);
  }

  @override
  bool shouldRepaint(covariant _JourneyCurvePainter oldDelegate) {
    return oldDelegate.month != month || oldDelegate.traces != traces;
  }
}

BoxDecoration _journeyGlassDecoration({double radius = 20}) {
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withValues(alpha: 0.86),
        const Color(0xFFFFF8F4).withValues(alpha: 0.72),
        const Color(0xFFF3F1FF).withValues(alpha: 0.66),
        const Color(0xFFF1F8FF).withValues(alpha: 0.62),
      ],
      stops: const [0, 0.36, 0.72, 1],
    ),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: Colors.white.withValues(alpha: 0.84),
      width: 1,
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF7164A8).withValues(alpha: 0.10),
        blurRadius: 30,
        spreadRadius: -14,
        offset: const Offset(0, 15),
      ),
      BoxShadow(
        color: const Color(0xFFFFB17C).withValues(alpha: 0.07),
        blurRadius: 26,
        spreadRadius: -14,
        offset: const Offset(-6, 10),
      ),
      BoxShadow(
        color: Colors.white.withValues(alpha: 0.90),
        blurRadius: 12,
        spreadRadius: -7,
        offset: const Offset(-4, -4),
      ),
    ],
  );
}

String _directionText(BuildContext context, MemorySummaryModel summary) {
  final generated = summary.longTermPattern?.summary.trim();
  if (generated != null && generated.isNotEmpty) {
    return _localizedGeneratedText(context, generated);
  }
  return AppLocaleText.tr(
    context,
    en: 'A life that is freer, steadier, creative, and connected with the world.',
    zhHans: '过一种更自由、更稳定、能持续创造，也与世界保持连接的生活。',
    zhHant: '過一種更自由、更穩定、能持續創造，也與世界保持連接的生活。',
    ja: 'より自由で安定し、創造を続け、世界とつながる暮らし。',
  );
}

List<_JourneyFragmentData> _fragmentItems(
  BuildContext context,
  MemorySummaryModel summary,
  DateTime month,
) {
  final traces = summary.journeyTraces
      .where((trace) => !_isLegacyScheduleSource(trace.sourceType))
      .where((trace) => _sameMonth(trace.localDate, month))
      .toList()
    ..sort((a, b) => b.localDate.compareTo(a.localDate));
  return traces.map((trace) {
    return _JourneyFragmentData(
      icon: _traceIcon(trace.sourceType),
      color: _traceColor(trace),
      title: localizeJourneyCategoryLabel(context, trace.title),
      meta:
          '${_traceDateLabel(trace.localDate)} · ${_traceSourceLabel(context, trace)}',
      localDate: trace.localDate,
      trace: trace,
    );
  }).toList(growable: false);
}

String _traceSourceLabel(BuildContext context, JourneyTraceModel trace) {
  switch (trace.sourceType) {
    case 'observation':
      return AppLocaleText.tr(context,
          en: 'Observation',
          zhHans: '观察判断',
          zhHant: 'Observation 判斷',
          ja: 'Observation');
    case 'manual_reflection':
      return AppLocaleText.tr(context,
          en: 'manual reflection',
          zhHans: '手动反思',
          zhHant: '手動反思',
          ja: '手動の振り返り');
    case 'micro_action_feedback':
      return AppLocaleText.tr(context,
          en: 'small action feedback',
          zhHans: '小行动反馈',
          zhHant: '小行動回饋',
          ja: '小さな行動');
    case 'weekly_review':
      return AppLocaleText.tr(context,
          en: 'Weekly Review',
          zhHans: '每周复盘回顾',
          zhHant: 'Weekly 回顧',
          ja: 'Weekly Review');
    case 'goal_feedback':
      return AppLocaleText.tr(context,
          en: 'Goal feedback', zhHans: '目标反馈', zhHant: '目標回饋', ja: '目標の反応');
    case 'life_experiment':
      return AppLocaleText.tr(context,
          en: 'Life Experiment',
          zhHans: '生活小实验',
          zhHant: '生活實驗',
          ja: 'Life Experiment');
    default:
      return AppLocaleText.tr(context,
          en: 'SignalCard',
          zhHans: 'Signal Card',
          zhHant: 'SignalCard',
          ja: 'SignalCard');
  }
}

JourneyTraceModel _observationTrace(JourneyObservationModel observation) {
  return JourneyTraceModel(
    id: observation.id,
    sourceType: 'observation',
    title: 'Observation',
    summary: [
      observation.text,
      observation.evidenceText,
      observation.suggestedPattern,
    ].where((value) => value.trim().isNotEmpty).join(' · '),
    localDate: observation.localDate,
    cluster: 'observation',
    intensity: observation.isConfirmed
        ? 0.78
        : observation.isDismissed
            ? 0.32
            : 0.56,
    signalLevel: observation.isConfirmed ? 'repeated_pattern' : 'weak_signal',
  );
}

String _observationStatusLabel(BuildContext context, String status) {
  switch (status) {
    case 'confirmed':
      return AppLocaleText.tr(context,
          en: 'Confirmed', zhHans: '已确认', zhHant: '已確認', ja: '確認済み');
    case 'dismissed':
      return AppLocaleText.tr(context,
          en: 'Dismissed', zhHans: '已排除', zhHant: '已排除', ja: '却下');
    default:
      return AppLocaleText.tr(context,
          en: 'Generated', zhHans: '生成中', zhHant: '生成中', ja: '生成');
  }
}

Color _observationStatusColor(String status) {
  switch (status) {
    case 'confirmed':
      return const Color(0xFF18A06B);
    case 'dismissed':
      return const Color(0xFF8C96B6);
    default:
      return const Color(0xFF7B6FF2);
  }
}

String _evidenceSourceLabel(BuildContext context, String sourceType) {
  switch (sourceType) {
    case 'manual_reflection':
      return AppLocaleText.tr(context,
          en: 'Manual Reflection',
          zhHans: '手动反思',
          zhHant: '手動反思',
          ja: '手動の振り返り');
    case 'observation':
      return AppLocaleText.tr(context,
          en: 'Observation',
          zhHans: '观察判断',
          zhHant: 'Observation 判斷',
          ja: 'Observation');
    case 'micro_action_feedback':
      return AppLocaleText.tr(context,
          en: 'Micro Action Feedback',
          zhHans: '小行动反馈',
          zhHant: '小行動回饋',
          ja: '小さな行動の反応');
    case 'weekly_review':
      return AppLocaleText.tr(context,
          en: 'Weekly Reflection',
          zhHans: '每周复盘反思',
          zhHant: 'Weekly Reflection',
          ja: 'Weekly Reflection');
    case 'goal_feedback':
      return AppLocaleText.tr(context,
          en: 'Goal Feedback', zhHans: '目标反馈', zhHant: '目標回饋', ja: '目標フィードバック');
    case 'life_experiment':
    case 'life_experiment_feedback':
      return AppLocaleText.tr(context,
          en: 'Experiment Feedback',
          zhHans: '实验反馈',
          zhHant: '實驗回饋',
          ja: '実験フィードバック');
    default:
      return AppLocaleText.tr(context,
          en: 'Signal', zhHans: '信号', zhHant: 'Signal', ja: 'Signal');
  }
}

String _traceDateLabel(String localDate) {
  final parsed = DateTime.tryParse(localDate);
  if (parsed == null) return localDate;
  return '${parsed.month}/${parsed.day}';
}

IconData _traceIcon(String sourceType) {
  switch (sourceType) {
    case 'manual_reflection':
      return Icons.edit_note_rounded;
    case 'micro_action_feedback':
      return Icons.spa_rounded;
    case 'weekly_review':
      return Icons.calendar_month_rounded;
    case 'goal_feedback':
      return Icons.flag_rounded;
    case 'life_experiment':
    case 'life_experiment_feedback':
      return Icons.science_rounded;
    case 'observation':
      return Icons.psychology_alt_rounded;
    default:
      return Icons.auto_awesome_rounded;
  }
}

Color _evidenceColor(String sourceType) {
  switch (sourceType) {
    case 'observation':
      return const Color(0xFF7B6FF2);
    case 'weekly_review':
      return const Color(0xFF9B78F5);
    case 'goal_feedback':
      return const Color(0xFF18A06B);
    case 'life_experiment':
    case 'life_experiment_feedback':
      return const Color(0xFF55A4FF);
    case 'micro_action_feedback':
      return const Color(0xFF63D4A6);
    case 'manual_reflection':
      return const Color(0xFFFF9A55);
    default:
      return const Color(0xFF8B62E8);
  }
}

Color _traceColor(JourneyTraceModel trace) {
  switch (trace.cluster) {
    case 'recovery':
      return const Color(0xFF63D4A6);
    case 'friction':
      return const Color(0xFFFF9A55);
    case 'work':
      return const Color(0xFF55A4FF);
    case 'helpful':
      return const Color(0xFFFF6CA8);
    case 'weekly':
      return const Color(0xFF9B78F5);
    default:
      return const Color(0xFF8B62E8);
  }
}

Color _clusterCurveColor(String cluster) {
  return _traceColor(
    JourneyTraceModel(
      id: cluster,
      sourceType: 'curve',
      title: cluster,
      summary: '',
      localDate: '',
      cluster: cluster,
      intensity: 0.5,
      signalLevel: 'weak_signal',
    ),
  );
}

String _monthKey(DateTime month) {
  return '${month.year}-${month.month.toString().padLeft(2, '0')}';
}

String _monthLabel(BuildContext context, DateTime month) {
  return AppLocaleText.tr(
    context,
    en: '${_englishMonth(month.month)} ${month.year}',
    zhHans: '${month.year}年${month.month}月',
    zhHant: '${month.year}年${month.month}月',
    ja: '${month.year}年${month.month}月',
  );
}

String _englishMonth(int month) {
  const names = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return names[(month - 1).clamp(0, 11)];
}

bool _sameMonth(String localDate, DateTime month) {
  final parsed = DateTime.tryParse(localDate);
  if (parsed == null) return false;
  return parsed.year == month.year && parsed.month == month.month;
}

bool _isLegacyScheduleSource(String sourceType) {
  final normalized = sourceType.toLowerCase();
  return normalized == 'calendar' ||
      normalized.contains('schedule') ||
      normalized == 'goal' ||
      normalized.startsWith('goal_');
}

List<JourneyTraceModel> _userVisibleJourneyTraces(
  List<JourneyTraceModel> traces,
) {
  return traces
      .where((trace) => !_isLegacyScheduleSource(trace.sourceType))
      .toList(growable: false);
}

List<(IconData, Color, String)> _gentleReviewRows(
  BuildContext context,
  MemorySummaryModel summary,
  DateTime month,
) {
  final traces = summary.journeyTraces
      .where((trace) => !_isLegacyScheduleSource(trace.sourceType))
      .where((trace) => _sameMonth(trace.localDate, month))
      .toList();
  final recoveryCount =
      traces.where((trace) => trace.cluster == 'recovery').length;
  final frictionCount =
      traces.where((trace) => trace.cluster == 'friction').length;
  final experimentCount =
      traces.where((trace) => trace.sourceType == 'life_experiment').length;
  final reflectionCount =
      traces.where((trace) => trace.sourceType == 'manual_reflection').length;

  return [
    (
      Icons.route_rounded,
      const Color(0xFF7B6FF2),
      AppLocaleText.tr(
        context,
        en: 'This month keeps ${traces.length} real trace(s), across ${traces.map((e) => e.localDate).toSet().length} recorded day(s).',
        zhHans:
            '这个月留下了 ${traces.length} 条真实轨迹，分布在 ${traces.map((e) => e.localDate).toSet().length} 个记录日里。',
        zhHant:
            '這個月留下了 ${traces.length} 條真實軌跡，分布在 ${traces.map((e) => e.localDate).toSet().length} 個記錄日裡。',
        ja: '今月は ${traces.length} 件の実際の軌跡が、${traces.map((e) => e.localDate).toSet().length} 日に残っています。',
      ),
    ),
    (
      frictionCount > recoveryCount
          ? Icons.thunderstorm_rounded
          : Icons.spa_rounded,
      frictionCount > recoveryCount
          ? const Color(0xFFFF9A55)
          : const Color(0xFF63D4A6),
      AppLocaleText.tr(
        context,
        en: frictionCount > recoveryCount
            ? 'The heavier moments are showing up more clearly; the next step can stay smaller.'
            : 'Recovery traces are visible; keep noticing what makes life a little easier.',
        zhHans: frictionCount > recoveryCount
            ? '耗力时刻更清楚地出现了；下一步可以继续调小一点。'
            : '恢复线索已经可见；继续留意什么让生活稍微省力。',
        zhHant: frictionCount > recoveryCount
            ? '耗力時刻更清楚地出現了；下一步可以繼續調小一點。'
            : '恢復線索已經可見；繼續留意什麼讓生活稍微省力。',
        ja: frictionCount > recoveryCount
            ? '負荷のある場面が見えています。次はもう少し小さくできます。'
            : '回復の手がかりが見えています。少し楽になる形を見ていきます。',
      ),
    ),
    (
      Icons.favorite_rounded,
      const Color(0xFFFF6CA8),
      AppLocaleText.tr(
        context,
        en: '$reflectionCount reflection(s) and $experimentCount experiment trace(s) are becoming material for the next month.',
        zhHans: '$reflectionCount 条反思和 $experimentCount 条实验轨迹，会成为下个月继续调整的材料。',
        zhHant: '$reflectionCount 條反思和 $experimentCount 條實驗軌跡，會成為下個月繼續調整的材料。',
        ja: '$reflectionCount 件の振り返りと $experimentCount 件の実験が、次の月の材料になります。',
      ),
    ),
  ];
}

class _JourneyStructurePathCard extends StatelessWidget {
  final MemorySummaryModel summary;

  const _JourneyStructurePathCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final nodes = _structureNodes(context, summary);
    return AuroraCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Life structure path',
                    zhHans: '生活结构路径',
                    zhHant: '生活結構路徑',
                    ja: '生活構造の道すじ',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 0,
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => _showJourneyHint(
                    context,
                    AppLocaleText.tr(
                      context,
                      en: 'The current life structure path is shown here.',
                      zhHans: '当前的生活结构路径已显示在这里。',
                      zhHant: '目前的生活結構路徑已顯示在這裡。',
                      ja: '現在の生活構造の道すじはここに表示しています。',
                    ),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            AppLocaleText.tr(
                              context,
                              en: 'View all',
                              zhHans: '查看全部',
                              zhHant: '查看全部',
                              ja: 'すべて見る',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: AuroraColors.muted,
                                ),
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            color: AuroraColors.muted),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
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
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
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
                      color: AuroraColors.muted.withValues(alpha: 0.58),
                    ),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  List<_JourneyPathNode> _structureNodes(
    BuildContext context,
    MemorySummaryModel summary,
  ) {
    final items = [
      summary.mainFriction,
      summary.longTermPattern,
      summary.recoverySignal,
      summary.experimentFeedback,
      summary.nextAdjustmentDirection,
    ];
    final fallbackLabels = [
      AppLocaleText.tr(context,
          en: 'Main friction', zhHans: '主要摩擦', zhHant: '主要摩擦', ja: '主な摩擦'),
      AppLocaleText.tr(context,
          en: 'Repeated pattern', zhHans: '重复模式', zhHant: '重複模式', ja: '反復パターン'),
      AppLocaleText.tr(context,
          en: 'Recovery clue', zhHans: '恢复线索', zhHant: '恢復線索', ja: '回復の手がかり'),
      AppLocaleText.tr(context,
          en: 'Experiment feedback',
          zhHans: '实验反馈',
          zhHant: '實驗回饋',
          ja: '試みの反応'),
      AppLocaleText.tr(context,
          en: 'Next adjustment', zhHans: '下次调整', zhHant: '下次調整', ja: '次の調整'),
    ];
    const icons = [
      Icons.battery_alert_outlined,
      Icons.repeat_rounded,
      Icons.nights_stay_rounded,
      Icons.science_outlined,
      Icons.wb_twilight_rounded,
    ];
    const colors = [
      AuroraColors.orange,
      AuroraColors.purple,
      AuroraColors.blue,
      AuroraColors.mint,
      AuroraColors.gold,
    ];
    return [
      for (var i = 0; i < fallbackLabels.length; i++)
        _JourneyPathNode(
          label: _fallbackIfEmpty(
            _compactLabel(items[i]?.name ?? items[i]?.summary ?? ''),
            fallbackLabels[i],
          ),
          icon: icons[i],
          color: colors[i],
        ),
    ];
  }

  String _compactLabel(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    final first = trimmed.split(RegExp(r'[：:，,。.!！\n]')).first.trim();
    final source = first.isEmpty ? trimmed : first;
    if (source.runes.length <= 8) return source;
    return String.fromCharCodes(source.runes.take(8));
  }

  String _fallbackIfEmpty(String value, String fallback) {
    return value.trim().isEmpty ? fallback : value;
  }
}

class _JourneyPathNode {
  final String label;
  final IconData icon;
  final Color color;

  const _JourneyPathNode({
    required this.label,
    required this.icon,
    required this.color,
  });
}

class _ExperimentTracksCard extends StatelessWidget {
  final MemorySummaryModel summary;

  const _ExperimentTracksCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final items = _trackItems(context);
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
                  en: 'Life Experiment archive',
                  zhHans: '生活小实验档案',
                  zhHant: 'Life Experiment 檔案',
                  ja: 'Life Experiment アーカイブ',
                ),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
              ),
              const Spacer(),
              Text(
                summary.experiments.isNotEmpty
                    ? AppLocaleText.tr(
                        context,
                        en: '${summary.experiments.length} item(s)',
                        zhHans: '共 ${summary.experiments.length} 个',
                        zhHant: '共 ${summary.experiments.length} 個',
                        ja: '${summary.experiments.length}件',
                      )
                    : AppLocaleText.tr(
                        context,
                        en: 'Forming',
                        zhHans: '形成中',
                        zhHant: '形成中',
                        ja: '形成中',
                      ),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AuroraColors.muted,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            Text(
              AppLocaleText.tr(
                context,
                en: 'Saved experiments, feedback, and what seems to fit you will appear here.',
                zhHans: '保存过的小实验、反馈、以及适合你的方法会沉淀在这里。',
                zhHant: '保存過的小實驗、回饋，以及適合你的方法會沉澱在這裡。',
                ja: '保存した小さな実験、反応、自分に合う方法がここに残ります。',
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AuroraColors.muted,
                  ),
            )
          else if (items.length == 1)
            _ExperimentTrackTile(
              icon: items.first.icon,
              title: items.first.title,
              status: items.first.status,
              color: items.first.color,
              isCompact: true,
            )
          else
            GridView.count(
              crossAxisCount: items.length < 3 ? items.length : 4,
              crossAxisSpacing: 9,
              mainAxisSpacing: 9,
              childAspectRatio: 0.98,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final item in items)
                  _ExperimentTrackTile(
                    icon: item.icon,
                    title: item.title,
                    status: item.status,
                    color: item.color,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  List<_ExperimentTrackData> _trackItems(BuildContext context) {
    return summary.experiments.take(4).map((item) {
      final color = switch (item.signalLevel) {
        'stable_mode' => AuroraColors.mint,
        'repeated_pattern' => AuroraColors.orange,
        _ => AuroraColors.purple,
      };
      return _ExperimentTrackData(
        icon: Icons.science_outlined,
        title: _compactTrackTitle(item.name),
        status: _trackStatus(context, item.signalLevel),
        color: color,
      );
    }).toList();
  }

  String _compactTrackTitle(String value) {
    final text = value.trim();
    if (text.isEmpty) return 'Experiment';
    if (text.runes.length <= 8) return text;
    return String.fromCharCodes(text.runes.take(8));
  }

  String _trackStatus(BuildContext context, String level) {
    switch (level) {
      case 'stable_mode':
        return AppLocaleText.tr(
          context,
          en: 'Helpful',
          zhHans: '有效',
          zhHant: '有效',
          ja: '有効',
        );
      case 'repeated_pattern':
        return AppLocaleText.tr(
          context,
          en: 'Learning',
          zhHans: '学习中',
          zhHant: '學習中',
          ja: '学び中',
        );
      default:
        return AppLocaleText.tr(
          context,
          en: 'Unsteady',
          zhHans: '未稳定',
          zhHant: '未穩定',
          ja: 'まだ不安定',
        );
    }
  }
}

class _ExperimentTrackData {
  final IconData icon;
  final String title;
  final String status;
  final Color color;

  const _ExperimentTrackData({
    required this.icon,
    required this.title,
    required this.status,
    required this.color,
  });
}

class _ExperimentTrackTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String status;
  final Color color;
  final bool isCompact;

  const _ExperimentTrackTile({
    required this.icon,
    required this.title,
    required this.status,
    required this.color,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.055),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.16)),
        ),
        child: Row(
          children: [
            AuroraSoftIconCircle(
              icon: icon,
              color: color,
              size: 40,
              iconSize: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AuroraColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 5),
                  SizedBox(
                    height: 18,
                    child: AuroraSparkline(color: color),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            AuroraChip(label: status, color: color),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(9, 10, 9, 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuroraSoftIconCircle(
            icon: icon,
            color: color,
            size: 34,
            iconSize: 18,
          ),
          const Spacer(),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AuroraColors.ink,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 18,
            width: double.infinity,
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: AuroraSparkline(color: color),
            ),
          ),
          AuroraChip(label: status, color: color),
        ],
      ),
    );
  }
}

class _JourneyActionLoopCard extends StatelessWidget {
  final MemorySummaryModel summary;

  const _JourneyActionLoopCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final confirmedCount =
        summary.repeatedPatterns.length + summary.stableModes.length;
    final triedCount = summary.experiments.length;
    final helpfulCount = summary.experiments
        .where((item) => item.signalLevel == 'stable_mode')
        .length;
    final feedback = summary.experimentFeedback?.summary.trim() ?? '';
    final next = summary.nextAdjustmentDirection.summary.trim();
    final loopText = feedback.isNotEmpty
        ? feedback
        : next.isNotEmpty
            ? next
            : AppLocaleText.tr(
                context,
                en: 'Saved actions and feedback will slowly show which small designs fit your life.',
                zhHans: '保存的小行动和反馈会慢慢看出，哪些生活设计更适合你。',
                zhHant: '保存的小行動和回饋會慢慢看出，哪些生活設計更適合你。',
                ja: '保存した小さな行動と反応から、どんな生活設計が合うかが少しずつ見えてきます。',
              );

    return AuroraCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AuroraSoftIconCircle(
                icon: Icons.loop_rounded,
                color: AuroraColors.purple,
                size: 34,
                iconSize: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Action fit pattern',
                    zhHans: '行动适配模式',
                    zhHant: '行動適配模式',
                    ja: '行動の合いやすさ',
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _JourneyLoopMetric(
                  label: AppLocaleText.tr(
                    context,
                    en: 'Confirmed',
                    zhHans: '已确认',
                    zhHant: '已確認',
                    ja: '確認済み',
                  ),
                  value: confirmedCount,
                  color: AuroraColors.purple,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _JourneyLoopMetric(
                  label: AppLocaleText.tr(
                    context,
                    en: 'Tried',
                    zhHans: '尝试过',
                    zhHant: '嘗試過',
                    ja: '試した',
                  ),
                  value: triedCount,
                  color: AuroraColors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _JourneyLoopMetric(
                  label: AppLocaleText.tr(
                    context,
                    en: 'Helpful',
                    zhHans: '有帮助',
                    zhHant: '有幫助',
                    ja: '助けになる',
                  ),
                  value: helpfulCount,
                  color: AuroraColors.mint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AuroraColors.purple.withValues(alpha: 0.055),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AuroraColors.purple.withValues(alpha: 0.12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Long-term loop trace',
                    zhHans: '长期闭环轨迹',
                    zhHant: '長期閉環軌跡',
                    ja: '長期の循環メモ',
                  ),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AuroraColors.purple,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  loopText,
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

class _JourneyLoopMetric extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _JourneyLoopMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.065),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Column(
        children: [
          Text(
            value.toString(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AuroraColors.muted,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _JourneyBottomInsightCard extends StatelessWidget {
  final MemorySummaryModel summary;

  const _JourneyBottomInsightCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final text = summary.nextAdjustmentDirection.summary.trim();
    return AuroraQuoteCard(
      minHeight: 76,
      landscape: true,
      text: text.isEmpty
          ? AppLocaleText.tr(
              context,
              en: 'For now, keep one small adjustment visible rather than forcing a big change.',
              zhHans: '现在先保留一个小调整方向，不需要强行大改。',
              zhHant: '現在先保留一個小調整方向，不需要強行大改。',
              ja: '今は大きく変えるより、小さな調整を一つ見える場所に置いておきます。',
            )
          : text,
    );
  }
}

class _JourneyHeatmapLite extends StatelessWidget {
  final MemorySummaryModel summary;
  final int weakCount;
  final int repeatedCount;
  final int stableCount;

  const _JourneyHeatmapLite({
    required this.summary,
    required this.weakCount,
    required this.repeatedCount,
    required this.stableCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final frictionStatus = _statusFromItem(
      summary.mainFriction,
      fallback: repeatedCount > 0
          ? AppLocaleText.tr(context,
              en: 'Pressured', zhHans: '有压力', zhHant: '有壓力', ja: '圧あり')
          : AppLocaleText.tr(context,
              en: 'Forming', zhHans: '形成中', zhHant: '形成中', ja: '形成中'),
    );
    final recoveryStatus = _statusFromItem(
      summary.recoverySignal,
      fallback: stableCount > 0
          ? AppLocaleText.tr(context,
              en: 'Visible', zhHans: '可见', zhHant: '可見', ja: '見える')
          : AppLocaleText.tr(context,
              en: 'Low', zhHans: '不足', zhHant: '不足', ja: '少なめ'),
    );
    final patternStatus = _statusFromItem(
      summary.longTermPattern,
      fallback: stableCount > 0
          ? AppLocaleText.tr(context,
              en: 'Stable', zhHans: '稳定', zhHant: '穩定', ja: '安定')
          : AppLocaleText.tr(context,
              en: 'Early', zhHans: '早期', zhHant: '早期', ja: '初期'),
    );
    final experimentStatus = _statusFromItem(
      summary.experimentFeedback,
      fallback: summary.experiments.isEmpty
          ? AppLocaleText.tr(context,
              en: 'Not yet', zhHans: '暂未出现', zhHant: '暫未出現', ja: 'まだ')
          : AppLocaleText.tr(context,
              en: 'Learning', zhHans: '学习中', zhHant: '學習中', ja: '学び中'),
    );
    final monthly = summary.monthlyReview;
    final monthlyRepeated = _firstMonthlyText(
      monthly?.repeatedThemes,
      fallback: frictionStatus,
    );
    final monthlyImproving = _firstMonthlyText(
      monthly?.improvingSignals,
      fallback: recoveryStatus,
    );
    final monthlyUnresolved = _firstMonthlyText(
      monthly?.unresolvedPoints,
      fallback: patternStatus,
    );
    final monthlyWatch = _shortStatus(
      monthly?.nextMonthWatch,
      fallback: experimentStatus,
    );
    final areas = [
      (
        Icons.work_outline_rounded,
        AppLocaleText.tr(context,
            en: 'Work / responsibility',
            zhHans: '工作 / 责任',
            zhHant: '工作 / 責任',
            ja: '仕事 / 責任'),
        monthlyRepeated,
        AuroraColors.orange,
      ),
      (
        Icons.track_changes_rounded,
        AppLocaleText.tr(context,
            en: 'Attention', zhHans: '注意力', zhHant: '注意力', ja: '注意'),
        monthlyUnresolved,
        AuroraColors.gold,
      ),
      (
        Icons.nights_stay_rounded,
        AppLocaleText.tr(context,
            en: 'Recovery', zhHans: '恢复', zhHant: '恢復', ja: '回復'),
        monthlyImproving,
        AuroraColors.blue,
      ),
      (
        Icons.groups_rounded,
        AppLocaleText.tr(context,
            en: 'Relationships',
            zhHans: '关系 / 边界',
            zhHant: '關係 / 邊界',
            ja: '関係 / 境界'),
        monthlyRepeated,
        AuroraColors.purple,
      ),
      (
        Icons.favorite_rounded,
        AppLocaleText.tr(context,
            en: 'Body', zhHans: '身体', zhHant: '身體', ja: '身体'),
        monthlyImproving,
        AuroraColors.mint,
      ),
      (
        Icons.near_me_rounded,
        AppLocaleText.tr(context,
            en: 'Freedom', zhHans: '自由感', zhHant: '自由感', ja: '自由感'),
        monthlyWatch,
        AuroraColors.blue,
      ),
    ];

    return _UnifiedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocaleText.tr(
              context,
              en: 'Monthly life map',
              zhHans: '轻量生活地图',
              zhHant: '輕量生活地圖',
              ja: '月の生活の旅路',
            ),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocaleText.tr(
              context,
              en: 'A map of where signals are gathering. It is not a score.',
              zhHans: monthly == null
                  ? '简单看一下信号正在聚到哪里。它是地图，不是评分。'
                  : '来自同一份月度快照：看信号聚到哪里，不是评分。',
              zhHant: '簡單看一下信號正在聚到哪裡。它是地圖，不是評分。',
              ja: 'シグナルがどこに集まっているかを軽く見る地図です。点数ではありません。',
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AuroraColors.muted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.65,
            children: [
              for (final area in areas)
                _LifeMapAreaCard(
                  icon: area.$1,
                  title: area.$2,
                  status: area.$3,
                  color: area.$4,
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _firstMonthlyText(
    List<String>? items, {
    required String fallback,
  }) {
    if (items == null || items.isEmpty) return fallback;
    return _shortStatus(items.first, fallback: fallback);
  }

  String _shortStatus(String? value, {required String fallback}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return fallback;
    final first = trimmed.split(RegExp(r'[，。,.、：:]')).first.trim();
    if (first.isEmpty) return fallback;
    final runes = first.runes.toList();
    if (runes.length <= 8) return first;
    return String.fromCharCodes(runes.take(8));
  }

  String _statusFromItem(
    JourneySignalItemModel? item, {
    required String fallback,
  }) {
    final name = item?.name.trim();
    if (name != null && name.isNotEmpty) {
      if (name.runes.length <= 5) return name;
      return String.fromCharCodes(name.runes.take(5));
    }
    return fallback;
  }
}

class _LifeMapAreaCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String status;
  final Color color;

  const _LifeMapAreaCard({
    required this.icon,
    required this.title,
    required this.status,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 0.68),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          AuroraSoftIconCircle(
              icon: icon, color: color, size: 36, iconSize: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AuroraColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                AuroraChip(label: status, color: color),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _JourneyOverviewCard extends StatelessWidget {
  final int weakCount;
  final int repeatedCount;
  final int stableCount;

  const _JourneyOverviewCard({
    required this.weakCount,
    required this.repeatedCount,
    required this.stableCount,
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
              en: 'Where your journey stands now',
              zhHans: '你现在的旅程，停在这里',
              zhHant: '你現在的 Journey，停在這裡',
              ja: '今の Journey はこのあたりです',
            ),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Text(
            AppLocaleText.tr(
              context,
              en: 'This page no longer shows only categories. It now shows how far each signal has actually developed.',
              zhHans: '这里不再只显示类别，而开始显示每条线索究竟发展到了哪一步。',
              zhHant: '這裡不再只顯示類別，而開始顯示每條線索究竟發展到了哪一步。',
              ja: 'ここではカテゴリだけでなく、それぞれの手がかりがどこまで育っているかも見えるようになっています。',
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _CountChip(
                label: AppLocaleText.tr(
                  context,
                  en: 'Weak',
                  zhHans: '冒头',
                  zhHant: '冒頭',
                  ja: '出始め',
                ),
                count: weakCount,
              ),
              _CountChip(
                label: AppLocaleText.tr(
                  context,
                  en: 'Repeated',
                  zhHans: '重复',
                  zhHant: '重複',
                  ja: '反復',
                ),
                count: repeatedCount,
              ),
              _CountChip(
                label: AppLocaleText.tr(
                  context,
                  en: 'Stable',
                  zhHans: '稳定',
                  zhHant: '穩定',
                  ja: '安定',
                ),
                count: stableCount,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  final int count;

  const _CountChip({
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewAdjustSection extends StatelessWidget {
  final MemorySummaryModel summary;

  const _ReviewAdjustSection({required this.summary});

  @override
  Widget build(BuildContext context) {
    return _UnifiedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocaleText.tr(
              context,
              en: 'This period, start here',
              zhHans: '这段时间，可以先这样看',
              zhHant: '這段時間，可以先這樣看',
              ja: 'この期間は、まずこう見てみる',
            ),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            AppLocaleText.tr(
              context,
              en: 'A light review of one pattern, one source of friction, one recovery clue, and what the latest experiment taught you.',
              zhHans: '先轻轻回看一个模式、一个消耗来源、一个恢复线索，以及最近一次实验留下的反馈。',
              zhHant: '先輕輕回看一個模式、一個消耗來源、一個恢復線索，以及最近一次實驗留下的回饋。',
              ja: 'ひとつの pattern、ひとつの friction、ひとつの回復の手がかり、そして直近の実験から見えたことを軽く振り返ります。',
            ),
          ),
          const SizedBox(height: 14),
          _ReviewAdjustTile(
            icon: Icons.repeat_rounded,
            title: AppLocaleText.tr(
              context,
              en: 'One pattern',
              zhHans: '一个反复出现的生活模式',
              zhHant: '一個反覆出現的生活模式',
              ja: 'ひとつの pattern',
            ),
            item: summary.longTermPattern,
            fallback: AppLocaleText.tr(
              context,
              en: 'There is no clear repeated pattern yet. Keeping the notes is enough for now.',
              zhHans: '暂时还没有清楚重复起来的模式。现在先把记录留下来就够了。',
              zhHant: '暫時還沒有清楚重複起來的模式。現在先把記錄留下來就夠了。',
              ja: 'まだはっきり繰り返す pattern はありません。今は記録が残っていれば十分です。',
            ),
          ),
          _ReviewAdjustTile(
            icon: Icons.bolt_outlined,
            title: AppLocaleText.tr(
              context,
              en: 'One friction source',
              zhHans: '一个主要消耗来源',
              zhHant: '一個主要消耗來源',
              ja: 'ひとつの friction',
            ),
            item: summary.mainFriction,
            fallback: AppLocaleText.tr(
              context,
              en: 'No single friction source is standing out yet.',
              zhHans: '暂时还没有特别突出的单一消耗来源。',
              zhHant: '暫時還沒有特別突出的單一消耗來源。',
              ja: '今はまだ、ひとつだけ目立つ friction はありません。',
            ),
          ),
          _ReviewAdjustTile(
            icon: Icons.spa_outlined,
            title: AppLocaleText.tr(
              context,
              en: 'One recovery clue',
              zhHans: '一个恢复线索',
              zhHant: '一個恢復線索',
              ja: 'ひとつの回復の手がかり',
            ),
            item: summary.recoverySignal,
            fallback: AppLocaleText.tr(
              context,
              en: 'A recovery clue has not surfaced clearly yet.',
              zhHans: '恢复线索还没有很清楚地浮出来。',
              zhHant: '恢復線索還沒有很清楚地浮出來。',
              ja: '回復の手がかりは、まだはっきり見えていません。',
            ),
          ),
          _ReviewAdjustTile(
            icon: Icons.tune_rounded,
            title: AppLocaleText.tr(
              context,
              en: 'Experiment feedback',
              zhHans: '一次实验反馈',
              zhHant: '一次實驗回饋',
              ja: '実験からのフィードバック',
            ),
            item: summary.experimentFeedback,
            fallback: AppLocaleText.tr(
              context,
              en: 'No experiment feedback yet. That does not block Journey.',
              zhHans: '暂时还没有实验反馈，这不会影响旅程继续回看。',
              zhHant: '暫時還沒有實驗回饋，這不會影響 Journey 繼續回看。',
              ja: 'まだ実験のフィードバックはありません。Journey の振り返りには影響しません。',
            ),
          ),
          _ReviewAdjustTile(
            icon: Icons.arrow_forward_rounded,
            title: AppLocaleText.tr(
              context,
              en: 'Next gentle adjustment',
              zhHans: '下次温和调整方向',
              zhHant: '下次溫和調整方向',
              ja: '次の小さな調整',
            ),
            item: summary.nextAdjustmentDirection,
            fallback: '',
          ),
        ],
      ),
    );
  }
}

class _ReviewAdjustTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final JourneySignalItemModel? item;
  final String fallback;

  const _ReviewAdjustTile({
    required this.icon,
    required this.title,
    required this.item,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final text =
        item?.summary.trim().isNotEmpty == true ? item!.summary : fallback;
    final name = item?.name.trim();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (name != null && name.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(text),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalLayerSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<JourneySignalItemModel> items;
  final String emptyText;

  const _SignalLayerSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.items,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    return _UnifiedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(subtitle),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text(emptyText)
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _JourneySignalCard(item: item),
              ),
            ),
        ],
      ),
    );
  }
}

class _JourneySignalCard extends StatelessWidget {
  final JourneySignalItemModel item;

  const _JourneySignalCard({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final tagLabel = _signalLevelLabel(context, item.signalLevel);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                item.name,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              _LevelChip(label: tagLabel),
            ],
          ),
          const SizedBox(height: 8),
          Text(item.summary),
        ],
      ),
    );
  }

  String _signalLevelLabel(BuildContext context, String level) {
    switch (level) {
      case 'stable_mode':
        return AppLocaleText.tr(
          context,
          en: 'stable mode',
          zhHans: '稳定倾向',
          zhHant: '穩定傾向',
          ja: '安定し始めた mode',
        );
      case 'repeated_pattern':
        return AppLocaleText.tr(
          context,
          en: 'repeated pattern',
          zhHans: '重复模式',
          zhHant: '重複模式',
          ja: '繰り返している pattern',
        );
      default:
        return AppLocaleText.tr(
          context,
          en: 'weak signal',
          zhHans: '弱线索',
          zhHant: '弱線索',
          ja: '弱いシグナル',
        );
    }
  }
}

class _SourceGroupsSection extends StatelessWidget {
  final MemorySummaryModel summary;

  const _SourceGroupsSection({
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SourceGroupTile(
          icon: Icons.sync_alt_rounded,
          title: AppLocaleText.tr(
            context,
            en: 'Patterns',
            zhHans: 'Patterns / 模式',
            zhHant: 'Patterns / 模式',
            ja: 'Patterns / パターン',
          ),
          subtitle: AppLocaleText.tr(
            context,
            en: 'Things that keep coming back in a similar way.',
            zhHans: '那些会以相似方式一再回来的东西。',
            zhHant: '那些會以相似方式一再回來的東西。',
            ja: '似た形で繰り返し戻ってくるもの。',
          ),
          items: summary.patterns,
        ),
        const SizedBox(height: 12),
        _SourceGroupTile(
          icon: Icons.warning_amber_rounded,
          title: AppLocaleText.tr(
            context,
            en: 'Frictions',
            zhHans: 'Frictions / 摩擦',
            zhHant: 'Frictions / 摩擦',
            ja: 'Frictions / 摩擦',
          ),
          subtitle: AppLocaleText.tr(
            context,
            en: 'Things that keep draining your time, focus, or energy.',
            zhHans: '那些持续消耗你时间、注意力或精力的东西。',
            zhHant: '那些持續消耗你時間、注意力或精力的東西。',
            ja: '時間や集中力、エネルギーを削り続けるもの。',
          ),
          items: summary.frictions,
        ),
        const SizedBox(height: 12),
        _SourceGroupTile(
          icon: Icons.explore_outlined,
          title: AppLocaleText.tr(
            context,
            en: 'Desires',
            zhHans: 'Desires / 方向',
            zhHant: 'Desires / 方向',
            ja: 'Desires / 方向',
          ),
          subtitle: AppLocaleText.tr(
            context,
            en: 'Things you may be moving toward, even if they are still vague.',
            zhHans: '那些你可能正在靠近、但还没完全说清的方向。',
            zhHant: '那些你可能正在靠近、但還沒完全說清的方向。',
            ja: 'まだ曖昧でも、少しずつ向かい始めている方向。',
          ),
          items: summary.desires,
        ),
        const SizedBox(height: 12),
        _SourceGroupTile(
          icon: Icons.auto_awesome_outlined,
          title: AppLocaleText.tr(
            context,
            en: 'Experiments',
            zhHans: 'Experiments / 有效尝试',
            zhHant: 'Experiments / 有效嘗試',
            ja: 'Experiments / 効いている試み',
          ),
          subtitle: AppLocaleText.tr(
            context,
            en: 'Things that may already be helping a little.',
            zhHans: '那些可能已经开始起一点作用的东西。',
            zhHant: '那些可能已經開始起一點作用的東西。',
            ja: '少しずつ助けになり始めているかもしれないもの。',
          ),
          items: summary.experiments,
        ),
      ],
    );
  }
}

class _SourceGroupTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<JourneySignalItemModel> items;

  const _SourceGroupTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        backgroundColor: Theme.of(context).cardColor,
        collapsedBackgroundColor: Theme.of(context).cardColor,
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        children: [
          if (items.isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                AppLocaleText.tr(
                  context,
                  en: 'There are no clear signals in this source yet.',
                  zhHans: '这个来源下暂时还没有很明确的线索。',
                  zhHant: '這個來源下暫時還沒有很明確的線索。',
                  ja: 'この出所では、まだはっきりした手がかりは見えていません。',
                ),
              ),
            )
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _JourneySignalCard(item: item),
              ),
            ),
        ],
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  final String label;

  const _LevelChip({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall,
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
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: child,
      ),
    );
  }
}
