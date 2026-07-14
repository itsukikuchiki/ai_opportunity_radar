import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/di/app_dependencies.dart';
import '../../../core/eligibility/signal_eligibility_service.dart';
import '../../../core/i18n/app_locale_text.dart';
import '../../../core/local/local_cache_invalidation_repository.dart';
import '../../../core/local/local_candidate_planning_repository.dart';
import '../../../core/models/candidate_models.dart';
import '../../../core/models/phase3_plus_models.dart';
import '../../../core/models/today_models.dart';
import '../../../core/models/weekly_models.dart';
import '../../../shared/widgets/aurora_ui.dart';

/// Compact Today projection of adopted MicroActions and LifeExperiments.
///
/// The dedicated candidate hubs own selection and the complete list. Today
/// shows at most three adopted objects per kind and their real 7-day progress.
class TodayAdoptedPlansSection extends StatefulWidget {
  final List<RecentSignalModel> signals;
  final MicroActionModel? compatibilityAction;
  final LifeExperimentModel? compatibilityExperiment;
  final bool isBusy;
  final Future<void> Function(MicroActionModel action, String feedback)
      onActionFeedback;
  final VoidCallback onOpenActionHub;
  final VoidCallback onOpenExperimentHub;
  final VoidCallback onOpenExperiment;
  final LocalCandidatePlanningRepository? repositoryOverride;

  const TodayAdoptedPlansSection({
    super.key,
    required this.signals,
    required this.compatibilityAction,
    required this.compatibilityExperiment,
    required this.isBusy,
    required this.onActionFeedback,
    required this.onOpenActionHub,
    required this.onOpenExperimentHub,
    required this.onOpenExperiment,
    this.repositoryOverride,
  });

  @override
  State<TodayAdoptedPlansSection> createState() =>
      _TodayAdoptedPlansSectionState();
}

class _TodayAdoptedPlansSectionState extends State<TodayAdoptedPlansSection> {
  List<AdoptedMicroActionProgress> _actions = const [];
  List<AdoptedLifeExperimentProgress> _experiments = const [];
  CandidateGateState? _dailyGate;
  CandidateGateState? _weeklyGate;
  bool _loading = true;
  StreamSubscription<CandidateInvalidationNotice>? _invalidationSubscription;

  DateTime get _today => DateTime.now();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _watchInvalidations();
    if (!_loading) return;
    unawaited(_load());
  }

  @override
  void dispose() {
    unawaited(_invalidationSubscription?.cancel());
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TodayAdoptedPlansSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.signals != widget.signals ||
        oldWidget.compatibilityAction != widget.compatibilityAction ||
        oldWidget.compatibilityExperiment != widget.compatibilityExperiment) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final dependencies = context.read<AppDependencies?>();
    final repository = widget.repositoryOverride ??
        dependencies?.localCandidatePlanningRepository;
    if (repository == null) {
      final dailyCount = const SignalEligibilityService()
          .filter(widget.signals, SignalEligibilityStage.daily)
          .where((signal) => _isSameLocalDay(signal, _today))
          .length;
      final weekStart = _startOfWeek(_today);
      final weekEnd = weekStart.add(const Duration(days: 6));
      final weeklyCount = const SignalEligibilityService()
          .filter(widget.signals, SignalEligibilityStage.weekly)
          .where((signal) {
        final date = DateTime.tryParse(signal.localDateKey());
        if (date == null) return false;
        return !date.isBefore(weekStart) && !date.isAfter(weekEnd);
      }).length;
      if (!mounted) return;
      setState(() {
        _dailyGate = CandidateGateState(
          kind: CandidateKind.microAction,
          periodStart: _dateKey(_today),
          periodEnd: _dateKey(_today),
          eligibleSignalCount: dailyCount,
        );
        _weeklyGate = CandidateGateState(
          kind: CandidateKind.lifeExperiment,
          periodStart: _dateKey(weekStart),
          periodEnd: _dateKey(weekEnd),
          eligibleSignalCount: weeklyCount,
        );
        _actions = widget.compatibilityAction == null
            ? const []
            : [
                AdoptedMicroActionProgress(
                  action: widget.compatibilityAction!,
                  progress: _emptyProgress(
                    widget.compatibilityAction!.id,
                    widget.compatibilityAction!.progressStartDate,
                  ),
                ),
              ];
        _experiments = widget.compatibilityExperiment == null
            ? const []
            : [
                AdoptedLifeExperimentProgress(
                  experiment: widget.compatibilityExperiment!,
                  progress: _emptyProgress(
                    widget.compatibilityExperiment!.id,
                    widget.compatibilityExperiment!.progressStartDate,
                  ),
                ),
              ];
        _loading = false;
      });
      return;
    }

    final results = await Future.wait<Object>([
      repository.dailyGate(_today),
      repository.weeklyGate(_today),
      repository.listActiveMicroActionsForDate(_today),
      repository.listActiveExperimentsForDate(_today),
    ]);
    if (!mounted) return;
    setState(() {
      _dailyGate = results[0] as CandidateGateState;
      _weeklyGate = results[1] as CandidateGateState;
      _actions = results[2] as List<AdoptedMicroActionProgress>;
      _experiments = results[3] as List<AdoptedLifeExperimentProgress>;
      _loading = false;
    });
  }

  void _watchInvalidations() {
    if (_invalidationSubscription != null) return;
    final dependencies = context.read<AppDependencies?>();
    final repository = widget.repositoryOverride ??
        dependencies?.localCandidatePlanningRepository;
    if (repository == null) return;
    _invalidationSubscription = CandidateInvalidationBus.stream
        .where((notice) => identical(
              notice.localDatabase,
              repository.localDatabase,
            ))
        .listen((_) {
      if (mounted) unawaited(_load());
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }
    return _TodayPlanGroup(
      key: const ValueKey('today-attempts'),
      dailyGate: _dailyGate!,
      weeklyGate: _weeklyGate!,
      actionItems: _actions.take(3).toList(growable: false),
      experimentItems: _experiments.take(3).toList(growable: false),
      hiddenActionCount: (_actions.length - 3).clamp(0, _actions.length),
      hiddenExperimentCount:
          (_experiments.length - 3).clamp(0, _experiments.length),
      isBusy: widget.isBusy,
      onOpenAll: _openAllAttempts,
      onOpenExperiment: widget.onOpenExperiment,
      onActionFeedback: (item, feedback) async {
        await widget.onActionFeedback(item.action, feedback);
        await _load();
      },
    );
  }

  Future<void> _openAllAttempts() async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFFFFCFA),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const AuroraSoftIconCircle(
                icon: Icons.spa_rounded,
                color: AuroraColors.mint,
              ),
              title: Text(
                AppLocaleText.tr(
                  context,
                  en: 'Today small actions',
                  zhHans: '今日小行动',
                  zhHant: '今日小行動',
                  ja: '今日の小さな行動',
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(sheetContext).pop();
                widget.onOpenActionHub();
              },
            ),
            ListTile(
              leading: const AuroraSoftIconCircle(
                icon: Icons.science_rounded,
                color: AuroraColors.blue,
              ),
              title: Text(
                AppLocaleText.tr(
                  context,
                  en: 'Active experiments',
                  zhHans: '进行中的小实验',
                  zhHant: '進行中的小實驗',
                  ja: '進行中の小さな実験',
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(sheetContext).pop();
                widget.onOpenExperimentHub();
              },
            ),
          ],
        ),
      ),
    );
  }

  bool _isSameLocalDay(RecentSignalModel signal, DateTime day) {
    return signal.localDateKey() == _dateKey(day);
  }

  DateTime _startOfWeek(DateTime value) {
    final day = DateTime(value.year, value.month, value.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  String _dateKey(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  SevenDayProgressModel _emptyProgress(String id, String? startValue) {
    final start = DateTime.tryParse(startValue ?? '') ?? _today;
    final localStart = DateTime(start.year, start.month, start.day);
    final cells = List.generate(
      7,
      (index) => SevenDayProgressCell(
        localDate: _dateKey(localStart.add(Duration(days: index))),
        state: ProgressCellState.empty,
      ),
    );
    return SevenDayProgressModel(
      subjectId: id,
      startDate: cells.first.localDate,
      endDate: cells.last.localDate,
      cells: cells,
    );
  }
}

class _TodayPlanGroup extends StatelessWidget {
  final CandidateGateState dailyGate;
  final CandidateGateState weeklyGate;
  final List<AdoptedMicroActionProgress> actionItems;
  final List<AdoptedLifeExperimentProgress> experimentItems;
  final int hiddenActionCount;
  final int hiddenExperimentCount;
  final bool isBusy;
  final VoidCallback onOpenAll;
  final VoidCallback onOpenExperiment;
  final Future<void> Function(
    AdoptedMicroActionProgress item,
    String feedback,
  ) onActionFeedback;

  const _TodayPlanGroup({
    super.key,
    required this.dailyGate,
    required this.weeklyGate,
    required this.actionItems,
    required this.experimentItems,
    required this.hiddenActionCount,
    required this.hiddenExperimentCount,
    required this.isBusy,
    required this.onOpenAll,
    required this.onOpenExperiment,
    required this.onActionFeedback,
  });

  @override
  Widget build(BuildContext context) {
    return AuroraCard(
      padding: AuroraMainPageSpec.comfortableCardPadding,
      borderRadius: BorderRadius.circular(AuroraMainPageSpec.cardRadiusLarge),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFFF8FFF9).withValues(alpha: 0.82),
          const Color(0xFFF2F3FF).withValues(alpha: 0.78),
          const Color(0xFFFFFBF7).withValues(alpha: 0.84),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Today attempts',
                    zhHans: '今日尝试',
                    zhHant: '今日嘗試',
                    ja: '今日の試み',
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AuroraColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                ),
                onPressed: onOpenAll,
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'View all',
                    zhHans: '查看全部',
                    zhHant: '查看全部',
                    ja: 'すべて見る',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          KeyedSubtree(
            key: const ValueKey('today-adopted-actions'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _TodayAttemptTypeHeader(
                  icon: Icons.spa_rounded,
                  label: '今日小行动',
                  accent: AuroraColors.mint,
                ),
                const SizedBox(height: 8),
                if (actionItems.isEmpty)
                  _TodayGateSummary(
                    gate: dailyGate,
                    kind: CandidateKind.microAction,
                  )
                else
                  for (var index = 0; index < actionItems.length; index++) ...[
                    _TodayActionProgressRow(
                      item: actionItems[index],
                      isBusy: isBusy,
                      onFeedback: (feedback) =>
                          onActionFeedback(actionItems[index], feedback),
                    ),
                    if (index != actionItems.length - 1)
                      const Divider(height: 22),
                  ],
                if (hiddenActionCount > 0) ...[
                  const SizedBox(height: 8),
                  _TodayHiddenAttemptCount(count: hiddenActionCount),
                ],
              ],
            ),
          ),
          const Divider(height: 24),
          KeyedSubtree(
            key: const ValueKey('today-adopted-experiments'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _TodayAttemptTypeHeader(
                  icon: Icons.science_rounded,
                  label: '本周小实验',
                  accent: AuroraColors.blue,
                ),
                const SizedBox(height: 8),
                if (experimentItems.isEmpty)
                  _TodayGateSummary(
                    gate: weeklyGate,
                    kind: CandidateKind.lifeExperiment,
                  )
                else
                  for (var index = 0;
                      index < experimentItems.length;
                      index++) ...[
                    _TodayExperimentProgressRow(
                      item: experimentItems[index],
                      onTap: onOpenExperiment,
                    ),
                    if (index != experimentItems.length - 1)
                      const Divider(height: 22),
                  ],
                if (hiddenExperimentCount > 0) ...[
                  const SizedBox(height: 8),
                  _TodayHiddenAttemptCount(count: hiddenExperimentCount),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayAttemptTypeHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;

  const _TodayAttemptTypeHeader({
    required this.icon,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: accent),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AuroraColors.ink,
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}

class _TodayHiddenAttemptCount extends StatelessWidget {
  final int count;

  const _TodayHiddenAttemptCount({required this.count});

  @override
  Widget build(BuildContext context) {
    return Text(
      AppLocaleText.tr(
        context,
        en: '$count more adopted items are available in View all.',
        zhHans: '还有 $count 项已采纳内容，可在“查看全部”中登记。',
        zhHant: '還有 $count 項已採納內容，可在「查看全部」中登記。',
        ja: '採用済みの項目があと $count 件あります。',
      ),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AuroraColors.muted,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

class _TodayGateSummary extends StatelessWidget {
  final CandidateGateState gate;
  final CandidateKind kind;

  const _TodayGateSummary({required this.gate, required this.kind});

  @override
  Widget build(BuildContext context) {
    final count = gate.eligibleSignalCount.clamp(0, 3);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          gate.isOpen
              ? AppLocaleText.tr(
                  context,
                  en: 'Suggestions are ready. Open to choose what fits.',
                  zhHans: '候选已经准备好，打开后选择适合你的内容。',
                  zhHant: '候選已經準備好，打開後選擇適合你的內容。',
                  ja: '候補の準備ができました。自分に合うものを選べます。',
                )
              : AppLocaleText.tr(
                  context,
                  en: 'Suggestions appear after 3 eligible signals ($count/3).',
                  zhHans: '记录 3 条符合条件的信号后开始显示（$count/3）。',
                  zhHant: '記錄 3 條符合條件的信號後開始顯示（$count/3）。',
                  ja: '条件を満たすシグナルが 3 件になると表示します（$count/3）。',
                ),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AuroraColors.ink.withValues(alpha: 0.78),
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 5),
        Text(
          AppLocaleText.tr(
            context,
            en: 'Waiting for a few signals avoids over-reading one moment.',
            zhHans: '先等待几条真实信号，是为了避免过度解读一个瞬间。',
            zhHant: '先等待幾條真實信號，是為了避免過度解讀一個瞬間。',
            ja: '一つの瞬間を読み込みすぎないため、複数のシグナルを待ちます。',
          ),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AuroraColors.muted,
                height: 1.4,
              ),
        ),
      ],
    );
  }
}

class _TodayActionProgressRow extends StatelessWidget {
  final AdoptedMicroActionProgress item;
  final bool isBusy;
  final ValueChanged<String> onFeedback;

  const _TodayActionProgressRow({
    required this.item,
    required this.isBusy,
    required this.onFeedback,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                item.action.title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AuroraColors.ink,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            Text(
              '${item.progress.completedDays}/7',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AuroraColors.mint,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ],
        ),
        if (item.action.sourceChanged) ...[
          const SizedBox(height: 5),
          const _SourceChangedLabel(),
        ],
        const SizedBox(height: 8),
        _CompactProgressCells(progress: item.progress),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _TodayFeedbackButton(
              icon: Icons.check_rounded,
              label: AppLocaleText.tr(
                context,
                en: 'Happened',
                zhHans: '发生了',
                zhHant: '發生了',
                ja: 'できた',
              ),
              color: AuroraColors.mint,
              onPressed: isBusy ? null : () => onFeedback('occurred'),
            ),
            _TodayFeedbackButton(
              icon: Icons.close_rounded,
              label: AppLocaleText.tr(
                context,
                en: 'Did not happen',
                zhHans: '没发生',
                zhHant: '沒發生',
                ja: 'できなかった',
              ),
              color: AuroraColors.orange,
              onPressed: isBusy ? null : () => onFeedback('not_occurred'),
            ),
            _TodayFeedbackButton(
              icon: Icons.remove_circle_outline_rounded,
              label: AppLocaleText.tr(
                context,
                en: 'Not suitable',
                zhHans: '今天不适合',
                zhHant: '今天不適合',
                ja: '今日は合わない',
              ),
              color: AuroraColors.muted,
              onPressed: isBusy ? null : () => onFeedback('not_suitable_today'),
            ),
          ],
        ),
      ],
    );
  }
}

class _TodayExperimentProgressRow extends StatelessWidget {
  final AdoptedLifeExperimentProgress item;
  final VoidCallback onTap;

  const _TodayExperimentProgressRow({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.experiment.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AuroraColors.ink,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                Text(
                  '${item.progress.completedDays}/7',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AuroraColors.purple,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded,
                    color: AuroraColors.muted),
              ],
            ),
            if (item.experiment.suggestedAction.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                item.experiment.suggestedAction,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AuroraColors.muted,
                      height: 1.35,
                    ),
              ),
            ],
            if (item.experiment.sourceChanged) ...[
              const SizedBox(height: 5),
              const _SourceChangedLabel(),
            ],
            const SizedBox(height: 8),
            _CompactProgressCells(progress: item.progress),
          ],
        ),
      ),
    );
  }
}

class _CompactProgressCells extends StatelessWidget {
  final SevenDayProgressModel progress;

  const _CompactProgressCells({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < progress.cells.take(7).length; index++) ...[
          Expanded(child: _CompactCell(cell: progress.cells[index])),
          if (index != progress.cells.take(7).length - 1)
            const SizedBox(width: 5),
        ],
      ],
    );
  }
}

class _CompactCell extends StatelessWidget {
  final SevenDayProgressCell cell;

  const _CompactCell({required this.cell});

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (cell.state) {
      ProgressCellState.completed => (
          Icons.check_rounded,
          AuroraColors.mint,
          'completed'
        ),
      ProgressCellState.notCompleted => (
          Icons.close_rounded,
          AuroraColors.orange,
          'not completed'
        ),
      ProgressCellState.empty => (
          Icons.circle_outlined,
          AuroraColors.muted,
          'not recorded'
        ),
    };
    return Semantics(
      label: '${cell.localDate}, $label',
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          constraints: const BoxConstraints(minHeight: 34),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.34)),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    );
  }
}

class _SourceChangedLabel extends StatelessWidget {
  const _SourceChangedLabel();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.info_outline_rounded,
            size: 15, color: AuroraColors.orange),
        const SizedBox(width: 4),
        Text(
          AppLocaleText.tr(
            context,
            en: 'Source changed · adopted item is kept',
            zhHans: '来源已变化 · 已采纳内容继续保留',
            zhHant: '來源已變化 · 已採納內容繼續保留',
            ja: '根拠が変更 · 採用済み内容は保持',
          ),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AuroraColors.orange,
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}

class _TodayFeedbackButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  const _TodayFeedbackButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        side: BorderSide(color: color.withValues(alpha: 0.34)),
        foregroundColor: AuroraColors.ink.withValues(alpha: 0.78),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: color),
      label: Text(label),
    );
  }
}
