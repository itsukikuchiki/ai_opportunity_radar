import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/di/app_dependencies.dart';
import '../../../core/eligibility/signal_eligibility_service.dart';
import '../../../core/i18n/app_locale_text.dart';
import '../../../core/local/local_cache_invalidation_repository.dart';
import '../../../core/local/local_candidate_planning_repository.dart';
import '../../../core/models/candidate_models.dart';
import '../../../core/models/experiment_evaluation_models.dart';
import '../../../core/models/phase3_plus_models.dart';
import '../../../core/models/today_models.dart';
import '../../../core/models/weekly_models.dart';
import '../../../shared/widgets/aurora_ui.dart';
import '../../../shared/widgets/experiment_feedback_sheets.dart';

/// Compact Today projection of the two Life Experiment tracks.
///
/// Existing MicroAction and LifeExperiment storage remains intact. In the
/// user-facing model they are presented as "small experiments" and "goals". The
/// Life Experiment page owns the complete adopted list; the candidate hubs
/// are only selection surfaces. Today shows at most three adopted objects per
/// track. Small experiments show recent real attempt events; goals show recent
/// daily progress without implying that a long-running goal ends after seven
/// days.
class TodayAdoptedPlansSection extends StatefulWidget {
  final List<RecentSignalModel> signals;
  final MicroActionModel? compatibilityAction;
  final LifeExperimentModel? compatibilityExperiment;
  final bool isBusy;
  final Future<void> Function(
    MicroActionModel action,
    SmallTryAttemptFeedbackDraft feedback,
  ) onActionFeedback;
  final Future<void> Function(LifeExperimentModel experiment, String feedback)
      onExperimentFeedback;
  final VoidCallback onOpenAll;
  final VoidCallback onOpenActionHub;
  final VoidCallback onOpenExperimentHub;
  final LocalCandidatePlanningRepository? repositoryOverride;

  const TodayAdoptedPlansSection({
    super.key,
    required this.signals,
    required this.compatibilityAction,
    required this.compatibilityExperiment,
    required this.isBusy,
    required this.onActionFeedback,
    required this.onExperimentFeedback,
    required this.onOpenAll,
    required this.onOpenActionHub,
    required this.onOpenExperimentHub,
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
      onOpenAll: widget.onOpenAll,
      onOpenActionCandidates: widget.onOpenActionHub,
      onOpenGoalCandidates: widget.onOpenExperimentHub,
      onActionFeedback: (item, feedback) async {
        await widget.onActionFeedback(item.action, feedback);
        await _load();
      },
      onExperimentFeedback: (item, feedback) async {
        await widget.onExperimentFeedback(item.experiment, feedback);
        await _load();
      },
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
  final VoidCallback onOpenActionCandidates;
  final VoidCallback onOpenGoalCandidates;
  final Future<void> Function(
    AdoptedMicroActionProgress item,
    SmallTryAttemptFeedbackDraft feedback,
  ) onActionFeedback;
  final Future<void> Function(
    AdoptedLifeExperimentProgress item,
    String feedback,
  ) onExperimentFeedback;

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
    required this.onOpenActionCandidates,
    required this.onOpenGoalCandidates,
    required this.onActionFeedback,
    required this.onExperimentFeedback,
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
                _TodayAttemptTypeHeader(
                  icon: Icons.spa_rounded,
                  label: AppLocaleText.tr(
                    context,
                    en: 'Spot Tries',
                    zhHans: '小实验',
                    zhHant: '小實驗',
                    ja: '小実験',
                  ),
                  accent: AuroraColors.mint,
                ),
                const SizedBox(height: 8),
                if (actionItems.isEmpty)
                  _TodayGateSummary(
                    gate: dailyGate,
                    kind: CandidateKind.microAction,
                    onOpenCandidates: onOpenActionCandidates,
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
                      const Divider(height: 22, color: AuroraColors.line),
                  ],
                if (hiddenActionCount > 0) ...[
                  const SizedBox(height: 8),
                  _TodayHiddenAttemptCount(count: hiddenActionCount),
                ],
              ],
            ),
          ),
          const Divider(height: 24, color: AuroraColors.line),
          KeyedSubtree(
            key: const ValueKey('today-adopted-experiments'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TodayAttemptTypeHeader(
                  icon: Icons.science_rounded,
                  label: AppLocaleText.tr(
                    context,
                    en: 'Goals',
                    zhHans: '目标',
                    zhHant: '目標',
                    ja: '目標',
                  ),
                  accent: AuroraColors.blue,
                ),
                const SizedBox(height: 8),
                if (experimentItems.isEmpty)
                  _TodayGateSummary(
                    gate: weeklyGate,
                    kind: CandidateKind.lifeExperiment,
                    onOpenCandidates: onOpenGoalCandidates,
                  )
                else
                  for (var index = 0;
                      index < experimentItems.length;
                      index++) ...[
                    _TodayExperimentProgressRow(
                      item: experimentItems[index],
                      isBusy: isBusy,
                      onFeedback: (feedback) => onExperimentFeedback(
                        experimentItems[index],
                        feedback,
                      ),
                    ),
                    if (index != experimentItems.length - 1)
                      const Divider(height: 22, color: AuroraColors.line),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            softWrap: true,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AuroraColors.ink,
                  fontWeight: FontWeight.w800,
                ),
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
  final VoidCallback onOpenCandidates;

  const _TodayGateSummary({
    required this.gate,
    required this.kind,
    required this.onOpenCandidates,
  });

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
        if (gate.isOpen) ...[
          const SizedBox(height: 6),
          TextButton.icon(
            key: ValueKey(
              kind == CandidateKind.microAction
                  ? 'today-open-small-try-candidates'
                  : 'today-open-goal-candidates',
            ),
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            onPressed: onOpenCandidates,
            icon: Icon(
              kind == CandidateKind.microAction
                  ? Icons.spa_rounded
                  : Icons.science_rounded,
              size: 18,
            ),
            label: Text(
              AppLocaleText.tr(
                context,
                en: kind == CandidateKind.microAction
                    ? 'Choose Spot Tries'
                    : 'Choose goals',
                zhHans: kind == CandidateKind.microAction ? '选择小实验' : '选择目标',
                zhHant: kind == CandidateKind.microAction ? '選擇小實驗' : '選擇目標',
                ja: kind == CandidateKind.microAction ? '小実験を選ぶ' : '目標を選ぶ',
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TodayActionProgressRow extends StatefulWidget {
  final AdoptedMicroActionProgress item;
  final bool isBusy;
  final Future<void> Function(SmallTryAttemptFeedbackDraft feedback) onFeedback;

  const _TodayActionProgressRow({
    required this.item,
    required this.isBusy,
    required this.onFeedback,
  });

  @override
  State<_TodayActionProgressRow> createState() =>
      _TodayActionProgressRowState();
}

class _TodayActionProgressRowState extends State<_TodayActionProgressRow> {
  final TextEditingController _noteController = TextEditingController();
  String? _effect;
  String? _difficulty;
  bool _showCompletedDetails = false;

  bool get _canSaveCompleted =>
      SmallTryEffect.values.contains(_effect) &&
      SmallTryDifficulty.values.contains(_difficulty);

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recordedEntries = widget.item.progress.recordedEntries;
    final completedAttempts = widget.item.progress.completedAttempts;
    final notAttemptedEntries = widget.item.progress.notAttemptedEntries;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.item.action.title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AuroraColors.ink,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            Text(
              AppLocaleText.tr(
                context,
                en: '$completedAttempts tried · $notAttemptedEntries not tried',
                zhHans: '尝试 $completedAttempts 次 · 未尝试 $notAttemptedEntries 次',
                zhHant: '嘗試 $completedAttempts 次 · 未嘗試 $notAttemptedEntries 次',
                ja: '$completedAttempts 回試行 · $notAttemptedEntries 回未試行',
              ),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AuroraColors.mint,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ],
        ),
        if (widget.item.action.sourceChanged) ...[
          const SizedBox(height: 5),
          const _SourceChangedLabel(),
        ],
        const SizedBox(height: 8),
        Text(
          AppLocaleText.tr(
            context,
            en: 'A Spot Try you can start right away.',
            zhHans: '现在就能开始的一次简单尝试。',
            zhHant: '現在就能開始的一次簡單嘗試。',
            ja: '今すぐ始められるスポットトライです。',
          ),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AuroraColors.muted,
                height: 1.35,
              ),
        ),
        const SizedBox(height: 8),
        if (recordedEntries == 0)
          Text(
            AppLocaleText.tr(
              context,
              en: 'No attempts recorded yet.',
              zhHans: '还没有登记尝试。',
              zhHant: '還沒有登記嘗試。',
              ja: 'まだ試行の記録はありません。',
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AuroraColors.muted,
                  fontWeight: FontWeight.w600,
                ),
          )
        else ...[
          Text(
            AppLocaleText.tr(
              context,
              en: recordedEntries > 7
                  ? 'Latest 7 recorded attempts'
                  : 'Recorded attempts',
              zhHans: recordedEntries > 7 ? '最近 7 次登记' : '尝试记录',
              zhHant: recordedEntries > 7 ? '最近 7 次登記' : '嘗試記錄',
              ja: recordedEntries > 7 ? '直近 7 回の記録' : '試行記録',
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AuroraColors.muted,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          _CompactAttemptProgressCells(progress: widget.item.progress),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _TodayFeedbackButton(
              key: ValueKey(
                'today-small-experiment-completed-${widget.item.action.id}',
              ),
              icon: Icons.check_rounded,
              label: AppLocaleText.tr(
                context,
                en: 'Completed',
                zhHans: '已完成',
                zhHant: '已完成',
                ja: '完了',
              ),
              color: AuroraColors.mint,
              onPressed: widget.isBusy
                  ? null
                  : () {
                      setState(() {
                        _showCompletedDetails = true;
                      });
                    },
            ),
            _TodayFeedbackButton(
              key: ValueKey(
                'today-small-experiment-not-completed-${widget.item.action.id}',
              ),
              icon: Icons.close_rounded,
              label: AppLocaleText.tr(
                context,
                en: 'Not completed',
                zhHans: '未完成',
                zhHant: '未完成',
                ja: '未完了',
              ),
              color: AuroraColors.orange,
              onPressed: widget.isBusy
                  ? null
                  : () async {
                      await widget.onFeedback(
                        const SmallTryAttemptFeedbackDraft(
                          completionStatus: 'not_completed',
                        ),
                      );
                      _resetCompletedDetails();
                    },
            ),
          ],
        ),
        if (_showCompletedDetails) ...[
          const SizedBox(height: 10),
          _InlineCompletedSmallTryFeedback(
            effect: _effect,
            difficulty: _difficulty,
            noteController: _noteController,
            isBusy: widget.isBusy,
            canSave: _canSaveCompleted,
            onEffectChanged: (value) => setState(() => _effect = value),
            onDifficultyChanged: (value) => setState(() => _difficulty = value),
            onCancel: _resetCompletedDetails,
            onSave: _saveCompleted,
          ),
        ],
      ],
    );
  }

  Future<void> _saveCompleted() async {
    if (!_canSaveCompleted || widget.isBusy) return;
    final note = _noteController.text.trim();
    await widget.onFeedback(
      SmallTryAttemptFeedbackDraft(
        completionStatus: 'completed',
        effect: _effect,
        difficulty: _difficulty,
        note: note.isEmpty ? null : note,
      ),
    );
    _resetCompletedDetails();
  }

  void _resetCompletedDetails() {
    if (!mounted) return;
    setState(() {
      _showCompletedDetails = false;
      _effect = null;
      _difficulty = null;
      _noteController.clear();
    });
  }
}

class _CompactAttemptProgressCells extends StatelessWidget {
  final SevenDayProgressModel progress;

  const _CompactAttemptProgressCells({required this.progress});

  @override
  Widget build(BuildContext context) {
    final allCells = progress.cells;
    final cells =
        allCells.length > 7 ? allCells.sublist(allCells.length - 7) : allCells;
    final firstAttemptIndex = allCells.length - cells.length + 1;
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: [
        for (var index = 0; index < cells.length; index++)
          SizedBox.square(
            dimension: 42,
            child: _CompactCell(
              key: ValueKey(
                'today-small-experiment-attempt-'
                '${cells[index].latestEventId ?? firstAttemptIndex + index}',
              ),
              cell: cells[index],
              semanticPrefix: AppLocaleText.tr(
                context,
                en: 'Attempt ${firstAttemptIndex + index}',
                zhHans: '第 ${firstAttemptIndex + index} 次尝试',
                zhHant: '第 ${firstAttemptIndex + index} 次嘗試',
                ja: '${firstAttemptIndex + index} 回目',
              ),
            ),
          ),
      ],
    );
  }
}

class _InlineCompletedSmallTryFeedback extends StatelessWidget {
  final String? effect;
  final String? difficulty;
  final TextEditingController noteController;
  final bool isBusy;
  final bool canSave;
  final ValueChanged<String> onEffectChanged;
  final ValueChanged<String> onDifficultyChanged;
  final VoidCallback onCancel;
  final Future<void> Function() onSave;

  const _InlineCompletedSmallTryFeedback({
    required this.effect,
    required this.difficulty,
    required this.noteController,
    required this.isBusy,
    required this.canSave,
    required this.onEffectChanged,
    required this.onDifficultyChanged,
    required this.onCancel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('today-small-experiment-completed-details'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AuroraColors.mint.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AuroraColors.mint.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocaleText.tr(
              context,
              en: 'How was this attempt?',
              zhHans: '这次尝试怎么样？',
              zhHant: '這次嘗試怎麼樣？',
              ja: '今回の試行はどうでしたか？',
            ),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AuroraColors.ink,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          _InlineFeedbackLabel(
            text: AppLocaleText.tr(
              context,
              en: 'Did it help right away?',
              zhHans: '当下有帮助吗？',
              zhHant: '當下有幫助嗎？',
              ja: 'すぐに役立ちましたか？',
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _InlineFeedbackChoice(
                key: const ValueKey('today-small-experiment-effect-helpful'),
                label: AppLocaleText.tr(
                  context,
                  en: 'Helpful',
                  zhHans: '有帮助',
                  zhHant: '有幫助',
                  ja: '役立った',
                ),
                selected: effect == SmallTryEffect.helpful,
                onPressed: () => onEffectChanged(SmallTryEffect.helpful),
              ),
              _InlineFeedbackChoice(
                key: const ValueKey('today-small-experiment-effect-somewhat'),
                label: AppLocaleText.tr(
                  context,
                  en: 'A little',
                  zhHans: '有一点',
                  zhHant: '有一點',
                  ja: '少し',
                ),
                selected: effect == SmallTryEffect.somewhatHelpful,
                onPressed: () =>
                    onEffectChanged(SmallTryEffect.somewhatHelpful),
              ),
              _InlineFeedbackChoice(
                key: const ValueKey('today-small-experiment-effect-none'),
                label: AppLocaleText.tr(
                  context,
                  en: 'No difference',
                  zhHans: '没感觉',
                  zhHant: '沒感覺',
                  ja: '変化なし',
                ),
                selected: effect == SmallTryEffect.noEffect,
                onPressed: () => onEffectChanged(SmallTryEffect.noEffect),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _InlineFeedbackLabel(
            text: AppLocaleText.tr(
              context,
              en: 'How much effort did it take?',
              zhHans: '做起来费力吗？',
              zhHant: '做起來費力嗎？',
              ja: '負担はどのくらいでしたか？',
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _InlineFeedbackChoice(
                key: const ValueKey('today-small-experiment-difficulty-easy'),
                label: AppLocaleText.tr(
                  context,
                  en: 'Easy',
                  zhHans: '轻松',
                  zhHant: '輕鬆',
                  ja: '軽い',
                ),
                selected: difficulty == SmallTryDifficulty.easy,
                onPressed: () => onDifficultyChanged(SmallTryDifficulty.easy),
              ),
              _InlineFeedbackChoice(
                key: const ValueKey('today-small-experiment-difficulty-okay'),
                label: AppLocaleText.tr(
                  context,
                  en: 'Okay',
                  zhHans: '还好',
                  zhHant: '還好',
                  ja: '普通',
                ),
                selected: difficulty == SmallTryDifficulty.okay,
                onPressed: () => onDifficultyChanged(SmallTryDifficulty.okay),
              ),
              _InlineFeedbackChoice(
                key: const ValueKey('today-small-experiment-difficulty-hard'),
                label: AppLocaleText.tr(
                  context,
                  en: 'Took effort',
                  zhHans: '偏费力',
                  zhHant: '偏費力',
                  ja: 'やや重い',
                ),
                selected: difficulty == SmallTryDifficulty.difficult,
                onPressed: () =>
                    onDifficultyChanged(SmallTryDifficulty.difficult),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey('today-small-experiment-note'),
            controller: noteController,
            minLines: 1,
            maxLines: 2,
            maxLength: 160,
            decoration: InputDecoration(
              isDense: true,
              hintText: AppLocaleText.tr(
                context,
                en: 'Add a note (optional)',
                zhHans: '补一句（可选）',
                zhHant: '補一句（可選）',
                ja: 'ひとこと追加（任意）',
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.78),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AuroraColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AuroraColors.line),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: isBusy ? null : onCancel,
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Cancel',
                    zhHans: '取消',
                    zhHant: '取消',
                    ja: 'キャンセル',
                  ),
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                key: const ValueKey('today-small-experiment-save-completed'),
                onPressed: !isBusy && canSave ? () => onSave() : null,
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Save',
                    zhHans: '保存',
                    zhHant: '儲存',
                    ja: '保存',
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

class _InlineFeedbackLabel extends StatelessWidget {
  final String text;

  const _InlineFeedbackLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AuroraColors.ink,
            fontWeight: FontWeight.w800,
          ),
    );
  }
}

class _InlineFeedbackChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  const _InlineFeedbackChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      showCheckmark: true,
      label: Text(label),
      onSelected: (_) => onPressed(),
      side: BorderSide(
        color: selected ? AuroraColors.purple : AuroraColors.line,
      ),
      selectedColor: AuroraColors.purple.withValues(alpha: 0.12),
      backgroundColor: Colors.white.withValues(alpha: 0.76),
      labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: selected ? AuroraColors.purple : AuroraColors.ink,
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _TodayExperimentProgressRow extends StatelessWidget {
  final AdoptedLifeExperimentProgress item;
  final bool isBusy;
  final ValueChanged<String> onFeedback;

  const _TodayExperimentProgressRow({
    required this.item,
    required this.isBusy,
    required this.onFeedback,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
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
                    AppLocaleText.tr(
                      context,
                      en: '${item.progress.completedDays} days completed',
                      zhHans: '已完成 ${item.progress.completedDays} 天',
                      zhHant: '已完成 ${item.progress.completedDays} 天',
                      ja: '${item.progress.completedDays} 日完了',
                    ),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AuroraColors.purple,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
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
            ],
          ),
        ),
        const SizedBox(height: 8),
        _CompactProgressCells(progress: item.progress),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _TodayFeedbackButton(
              key: ValueKey(
                'today-goal-completed-${item.experiment.id}',
              ),
              icon: Icons.check_rounded,
              label: AppLocaleText.tr(
                context,
                en: 'Completed',
                zhHans: '已完成',
                zhHant: '已完成',
                ja: '完了',
              ),
              color: AuroraColors.mint,
              onPressed: isBusy ? null : () => onFeedback('completed'),
            ),
            _TodayFeedbackButton(
              key: ValueKey(
                'today-goal-not-completed-${item.experiment.id}',
              ),
              icon: Icons.close_rounded,
              label: AppLocaleText.tr(
                context,
                en: 'Not completed',
                zhHans: '未完成',
                zhHant: '未完成',
                ja: '未完了',
              ),
              color: AuroraColors.orange,
              onPressed: isBusy ? null : () => onFeedback('not_completed'),
            ),
          ],
        ),
      ],
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
  final String? semanticPrefix;

  const _CompactCell({
    super.key,
    required this.cell,
    this.semanticPrefix,
  });

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
      label: '${semanticPrefix ?? cell.localDate}, $label',
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
            ja: 'Signal の参照元が変更・採用済み内容は保持',
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
    super.key,
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
