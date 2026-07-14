import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/di/app_dependencies.dart';
import '../../../core/i18n/app_locale_text.dart';
import '../../../core/local/local_candidate_planning_repository.dart';
import '../../../core/models/candidate_models.dart';
import '../../../shared/widgets/aurora_ui.dart';
import '../../../shared/widgets/candidate_planning_widgets.dart';

class CandidateHubPage extends StatefulWidget {
  final CandidateKind kind;
  final LocalCandidatePlanningRepository? repositoryOverride;
  final DateTime Function()? nowLoader;

  const CandidateHubPage({
    super.key,
    required this.kind,
    this.repositoryOverride,
    this.nowLoader,
  });

  @override
  State<CandidateHubPage> createState() => _CandidateHubPageState();
}

class _CandidateHubPageState extends State<CandidateHubPage> {
  LocalCandidatePlanningRepository? _repository;
  CandidateGateState? _gate;
  CandidateGenerationState? _generation;
  List<MicroActionCandidateModel> _microCandidates = const [];
  List<ExperimentCandidateRecord> _experimentCandidates = const [];
  List<AdoptedMicroActionProgress> _activeActions = const [];
  List<AdoptedLifeExperimentProgress> _activeExperiments = const [];
  final Set<String> _selectedIds = {};
  StreamSubscription<CandidateGenerationState>? _generationSubscription;
  bool _initialized = false;
  bool _loading = true;
  bool _adopting = false;
  bool _refreshingFromInvalidation = false;
  String? _error;

  DateTime get _today => (widget.nowLoader?.call() ?? DateTime.now()).toLocal();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _repository = widget.repositoryOverride ??
        context.read<AppDependencies>().localCandidatePlanningRepository;
    unawaited(_loadAndRefresh());
  }

  @override
  void dispose() {
    _generationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadAndRefresh() async {
    final repository = _repository;
    if (repository == null) return;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      if (widget.kind == CandidateKind.microAction) {
        final initial = await repository.dailyCandidateSnapshot(_today);
        if (!mounted) return;
        _applyMicroSnapshot(initial);
        _watchGeneration(initial.gate);
        final refreshed = await repository.refreshDailyWithGroundedSuggestions(
          day: _today,
          language: AppLocaleText.resolve(context),
          debounce: const Duration(milliseconds: 180),
        );
        if (!mounted) return;
        _applyMicroSnapshot(refreshed);
      } else {
        final initial = await repository.weeklyCandidateSnapshot(_today);
        if (!mounted) return;
        _applyExperimentSnapshot(initial);
        _watchGeneration(initial.gate);
        final refreshed = await repository.refreshWeeklyWithGroundedSuggestions(
          day: _today,
          language: AppLocaleText.resolve(context),
          debounce: const Duration(milliseconds: 180),
        );
        if (!mounted) return;
        _applyExperimentSnapshot(refreshed);
      }
      await _loadActiveProgress();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _watchGeneration(CandidateGateState gate) {
    _generationSubscription?.cancel();
    _generationSubscription = _repository
        ?.watchGenerationState(
      kind: widget.kind,
      periodStart: gate.periodStart,
      periodEnd: gate.periodEnd,
    )
        .listen((generation) {
      if (!mounted) return;
      setState(() => _generation = generation);
      if (generation.status == CandidateGenerationStatus.stale &&
          !_refreshingFromInvalidation) {
        _refreshingFromInvalidation = true;
        unawaited(_refreshAfterInvalidation());
      }
    });
  }

  Future<void> _refreshAfterInvalidation() async {
    try {
      await _loadAndRefresh();
    } finally {
      _refreshingFromInvalidation = false;
    }
  }

  void _applyMicroSnapshot(
    CandidateSnapshot<MicroActionCandidateModel> snapshot,
  ) {
    setState(() {
      _gate = snapshot.gate;
      _generation = snapshot.generation;
      _microCandidates = snapshot.candidates.take(3).toList(growable: false);
      _selectedIds.removeWhere(
        (id) => !_microCandidates.any((candidate) => candidate.id == id),
      );
      _loading = false;
      _error = null;
    });
  }

  void _applyExperimentSnapshot(
    CandidateSnapshot<ExperimentCandidateRecord> snapshot,
  ) {
    setState(() {
      _gate = snapshot.gate;
      _generation = snapshot.generation;
      _experimentCandidates =
          snapshot.candidates.take(3).toList(growable: false);
      _selectedIds.removeWhere(
        (id) => !_experimentCandidates.any((candidate) => candidate.id == id),
      );
      _loading = false;
      _error = null;
    });
  }

  Future<void> _adoptSelected() async {
    if (_adopting || _selectedIds.isEmpty || _repository == null) return;
    setState(() => _adopting = true);
    try {
      if (widget.kind == CandidateKind.microAction) {
        await _repository!.adoptMicroActionCandidates(_selectedIds);
        final snapshot = await _repository!.dailyCandidateSnapshot(_today);
        if (!mounted) return;
        _applyMicroSnapshot(snapshot);
      } else {
        await _repository!.adoptExperimentCandidates(_selectedIds);
        final snapshot = await _repository!.weeklyCandidateSnapshot(_today);
        if (!mounted) return;
        _applyExperimentSnapshot(snapshot);
      }
      _selectedIds.clear();
      await _loadActiveProgress();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              AppLocaleText.tr(
                context,
                en: widget.kind == CandidateKind.microAction
                    ? 'Your choices are adopted. Progress starts today.'
                    : 'Your choices are adopted. Progress starts next Monday.',
                zhHans: widget.kind == CandidateKind.microAction
                    ? '已采纳所选内容，七日进度从今天开始。'
                    : '已采纳所选实验，七日进度从下周一开始。',
                zhHant: widget.kind == CandidateKind.microAction
                    ? '已採納所選內容，七日進度從今天開始。'
                    : '已採納所選實驗，七日進度從下週一開始。',
                ja: widget.kind == CandidateKind.microAction
                    ? '選んだ内容を採用しました。7 日間の進捗は今日から始まります。'
                    : '選んだ実験を採用しました。7 日間の進捗は来週月曜日から始まります。',
              ),
            ),
          ),
        );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _adopting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMicroAction = widget.kind == CandidateKind.microAction;
    final gate = _gate;
    final generation = _generation;
    final candidatesDisabled =
        generation?.status == CandidateGenerationStatus.regenerating ||
            generation?.status == CandidateGenerationStatus.stale;

    return Scaffold(
      body: Stack(
        children: [
          AuroraPage(
            child: SafeArea(
              bottom: false,
              child: ListView(
                key: ValueKey(
                  isMicroAction
                      ? 'micro-action-candidate-scroll'
                      : 'experiment-candidate-scroll',
                ),
                padding: AuroraMainPageSpec.scrollPadding(context),
                children: [
                  _CandidateHubHeader(
                    kind: widget.kind,
                    onBack: () => Navigator.of(context).pop(true),
                  ),
                  const SizedBox(height: AuroraMainPageSpec.heroGap),
                  if (gate != null)
                    CandidateGateCard(
                      gate: gate,
                      icon: isMicroAction
                          ? Icons.spa_rounded
                          : Icons.science_rounded,
                      accent: isMicroAction
                          ? AuroraColors.mint
                          : AuroraColors.purple,
                    )
                  else if (_loading)
                    const Center(child: CircularProgressIndicator()),
                  if (generation != null &&
                      generation.status != CandidateGenerationStatus.gated) ...[
                    const SizedBox(height: AuroraMainPageSpec.sectionGap),
                    CandidateRefreshBanner(generation: generation),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: AuroraMainPageSpec.sectionGap),
                    _CandidateErrorCard(
                      onRetry: _loadAndRefresh,
                    ),
                  ],
                  if ((isMicroAction && _activeActions.isNotEmpty) ||
                      (!isMicroAction && _activeExperiments.isNotEmpty)) ...[
                    const SizedBox(height: AuroraMainPageSpec.sectionGap),
                    _AdoptedProgressSection(
                      kind: widget.kind,
                      actions: _activeActions,
                      experiments: _activeExperiments,
                      today: _today,
                      onActionProgress: _recordActionProgress,
                      onExperimentProgress: _recordExperimentProgress,
                    ),
                  ],
                  if (gate?.isOpen == true) ...[
                    const SizedBox(height: AuroraMainPageSpec.sectionGap),
                    _CandidateSectionIntro(kind: widget.kind),
                    const SizedBox(height: AuroraMainPageSpec.sectionGap),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: isMicroAction
                          ? _MicroCandidateList(
                              key: ValueKey(
                                _microCandidates
                                    .map((candidate) => candidate.id)
                                    .join('|'),
                              ),
                              candidates: _microCandidates,
                              selectedIds: _selectedIds,
                              disabled: candidatesDisabled || _adopting,
                              onSelected: _setSelected,
                              onEdit: _editMicroCandidate,
                            )
                          : _ExperimentCandidateList(
                              key: ValueKey(
                                _experimentCandidates
                                    .map((candidate) => candidate.id)
                                    .join('|'),
                              ),
                              candidates: _experimentCandidates,
                              selectedIds: _selectedIds,
                              disabled: candidatesDisabled || _adopting,
                              onSelected: _setSelected,
                              onEdit: _editExperimentCandidate,
                            ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      key: const ValueKey('candidate-adopt-selected'),
                      onPressed: candidatesDisabled ||
                              _adopting ||
                              _selectedIds.isEmpty
                          ? null
                          : _adoptSelected,
                      icon: _adopting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_outline_rounded),
                      label: Text(
                        _selectedIds.isEmpty
                            ? AppLocaleText.tr(
                                context,
                                en: 'Select what fits you',
                                zhHans: '选择适合你的内容',
                                zhHant: '選擇適合你的內容',
                                ja: '自分に合う内容を選ぶ',
                              )
                            : AppLocaleText.tr(
                                context,
                                en: 'Adopt ${_selectedIds.length} selected',
                                zhHans: '采纳已选 ${_selectedIds.length} 项',
                                zhHant: '採納已選 ${_selectedIds.length} 項',
                                ja: '選択した ${_selectedIds.length} 件を採用',
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      key: const ValueKey('candidate-adopt-none'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                      ),
                      onPressed: _adopting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: Text(
                        AppLocaleText.tr(
                          context,
                          en: 'Adopt none for now',
                          zhHans: '这次先不采纳',
                          zhHant: '這次先不採納',
                          ja: '今回は採用しない',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const AuroraSafeTopMask(extraHeight: 4),
        ],
      ),
    );
  }

  void _setSelected(String id, bool selected) {
    setState(() {
      if (selected) {
        _selectedIds.add(id);
      } else {
        _selectedIds.remove(id);
      }
    });
  }

  Future<void> _editMicroCandidate(
    MicroActionCandidateModel candidate,
  ) async {
    final title = await _showCandidateEditDialog(
      context,
      title: candidate.title,
    );
    if (title == null || _repository == null) return;
    await _repository!.updateMicroActionCandidate(
      candidateId: candidate.id,
      title: title.$1,
    );
    final snapshot = await _repository!.dailyCandidateSnapshot(_today);
    if (mounted) _applyMicroSnapshot(snapshot);
  }

  Future<void> _editExperimentCandidate(
    ExperimentCandidateRecord candidate,
  ) async {
    final result = await _showCandidateEditDialog(
      context,
      title: candidate.title,
      action: candidate.suggestedAction,
    );
    if (result == null || _repository == null) return;
    await _repository!.updateExperimentCandidate(
      candidateId: candidate.id,
      title: result.$1,
      suggestedAction: result.$2!,
    );
    final snapshot = await _repository!.weeklyCandidateSnapshot(_today);
    if (mounted) _applyExperimentSnapshot(snapshot);
  }

  Future<void> _loadActiveProgress() async {
    final repository = _repository;
    if (repository == null) return;
    if (widget.kind == CandidateKind.microAction) {
      final actions = await repository.listActiveMicroActionsForDate(_today);
      if (!mounted) return;
      setState(() => _activeActions = actions);
    } else {
      final experiments = await repository.listActiveExperimentsForDate(_today);
      if (!mounted) return;
      setState(() => _activeExperiments = experiments);
    }
  }

  Future<void> _recordActionProgress(
    AdoptedMicroActionProgress item,
    SevenDayProgressCell cell,
  ) async {
    if (!_isTodayCell(cell)) return;
    final feedback = await _showProgressChoiceSheet(context);
    if (feedback == null || !mounted) return;
    await context
        .read<AppDependencies>()
        .todayRepository
        .submitMicroActionFeedback(
          microActionId: item.action.id,
          feedback: feedback,
        );
    await _loadActiveProgress();
  }

  Future<void> _recordExperimentProgress(
    AdoptedLifeExperimentProgress item,
    SevenDayProgressCell cell,
  ) async {
    if (!_isTodayCell(cell)) return;
    final feedback = await _showProgressChoiceSheet(context);
    if (feedback == null || !mounted) return;
    final completionStatus = switch (feedback) {
      'occurred' => 'done',
      'not_occurred' => 'not_done',
      _ => 'not_suitable_today',
    };
    await context
        .read<AppDependencies>()
        .localLifeExperimentRepository
        .recordFeedback(
          experimentId: item.experiment.id,
          completionStatus: completionStatus,
          feedbackDate: _today,
        );
    await _loadActiveProgress();
  }

  bool _isTodayCell(SevenDayProgressCell cell) {
    final month = _today.month.toString().padLeft(2, '0');
    final day = _today.day.toString().padLeft(2, '0');
    return cell.localDate == '${_today.year}-$month-$day';
  }
}

Future<String?> _showProgressChoiceSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocaleText.tr(
              context,
              en: 'How did it go today?',
              zhHans: '今天的实际进度怎么样？',
              zhHant: '今天的實際進度怎麼樣？',
              ja: '今日の進捗はどうでしたか？',
            ),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AuroraColors.ink,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 12),
          _ProgressChoiceTile(
            icon: Icons.check_circle_rounded,
            color: AuroraColors.mint,
            label: AppLocaleText.tr(
              context,
              en: 'Happened',
              zhHans: '发生了',
              zhHant: '發生了',
              ja: 'できた',
            ),
            onTap: () => Navigator.pop(sheetContext, 'occurred'),
          ),
          const SizedBox(height: 8),
          _ProgressChoiceTile(
            icon: Icons.close_rounded,
            color: AuroraColors.orange,
            label: AppLocaleText.tr(
              context,
              en: 'Did not happen',
              zhHans: '没发生',
              zhHant: '沒發生',
              ja: 'できなかった',
            ),
            onTap: () => Navigator.pop(sheetContext, 'not_occurred'),
          ),
          const SizedBox(height: 8),
          _ProgressChoiceTile(
            icon: Icons.remove_circle_outline_rounded,
            color: AuroraColors.muted,
            label: AppLocaleText.tr(
              context,
              en: 'Not suitable today',
              zhHans: '今天不适合',
              zhHant: '今天不適合',
              ja: '今日は合わなかった',
            ),
            onTap: () => Navigator.pop(sheetContext, 'not_suitable_today'),
          ),
        ],
      ),
    ),
  );
}

Future<(String, String?)?> _showCandidateEditDialog(
  BuildContext context, {
  required String title,
  String? action,
}) async {
  final titleController = TextEditingController(text: title);
  final actionController = TextEditingController(text: action);
  final result = await showDialog<(String, String?)>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        AppLocaleText.tr(
          context,
          en: 'Edit before adopting',
          zhHans: '采纳前修改内容',
          zhHant: '採納前修改內容',
          ja: '採用前に編集',
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('candidate-edit-title'),
              controller: titleController,
              minLines: 1,
              maxLines: 3,
              maxLength: 120,
              decoration: InputDecoration(
                labelText: AppLocaleText.tr(
                  context,
                  en: 'Title',
                  zhHans: '标题',
                  zhHant: '標題',
                  ja: 'タイトル',
                ),
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('candidate-edit-action'),
                controller: actionController,
                minLines: 2,
                maxLines: 5,
                maxLength: 240,
                decoration: InputDecoration(
                  labelText: AppLocaleText.tr(
                    context,
                    en: 'How to try it',
                    zhHans: '怎么尝试',
                    zhHant: '怎麼嘗試',
                    ja: '試し方',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () {
            final updatedTitle = titleController.text.trim();
            final updatedAction = actionController.text.trim();
            if (updatedTitle.isEmpty ||
                (action != null && updatedAction.isEmpty)) {
              return;
            }
            Navigator.pop(
              dialogContext,
              (updatedTitle, action == null ? null : updatedAction),
            );
          },
          child: Text(
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
  );
  titleController.dispose();
  actionController.dispose();
  return result;
}

class _ProgressChoiceTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _ProgressChoiceTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 52,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.32)),
      ),
      tileColor: color.withValues(alpha: 0.08),
      leading: Icon(icon, color: color),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      onTap: onTap,
    );
  }
}

class _AdoptedProgressSection extends StatelessWidget {
  final CandidateKind kind;
  final List<AdoptedMicroActionProgress> actions;
  final List<AdoptedLifeExperimentProgress> experiments;
  final DateTime today;
  final void Function(
    AdoptedMicroActionProgress item,
    SevenDayProgressCell cell,
  ) onActionProgress;
  final void Function(
    AdoptedLifeExperimentProgress item,
    SevenDayProgressCell cell,
  ) onExperimentProgress;

  const _AdoptedProgressSection({
    required this.kind,
    required this.actions,
    required this.experiments,
    required this.today,
    required this.onActionProgress,
    required this.onExperimentProgress,
  });

  @override
  Widget build(BuildContext context) {
    final isMicro = kind == CandidateKind.microAction;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocaleText.tr(
            context,
            en: 'Adopted and in progress',
            zhHans: '已采纳与实际进度',
            zhHant: '已採納與實際進度',
            ja: '採用済みと実際の進捗',
          ),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AuroraColors.ink,
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: AuroraMainPageSpec.sectionGap),
        if (isMicro)
          for (var index = 0; index < actions.length; index++) ...[
            _AdoptedProgressCard(
              title: actions[index].action.title,
              reason: actions[index].action.reason,
              sourceChanged: actions[index].action.sourceChanged,
              progress: actions[index].progress,
              today: today,
              onCellTap: (cell) => onActionProgress(actions[index], cell),
            ),
            if (index != actions.length - 1)
              const SizedBox(height: AuroraMainPageSpec.sectionGap),
          ]
        else
          for (var index = 0; index < experiments.length; index++) ...[
            _AdoptedProgressCard(
              title: experiments[index].experiment.title,
              reason: experiments[index].experiment.suggestedAction,
              sourceChanged: experiments[index].experiment.sourceChanged,
              progress: experiments[index].progress,
              today: today,
              onCellTap: (cell) =>
                  onExperimentProgress(experiments[index], cell),
            ),
            if (index != experiments.length - 1)
              const SizedBox(height: AuroraMainPageSpec.sectionGap),
          ],
      ],
    );
  }
}

class _AdoptedProgressCard extends StatelessWidget {
  final String title;
  final String reason;
  final bool sourceChanged;
  final SevenDayProgressModel progress;
  final DateTime today;
  final ValueChanged<SevenDayProgressCell> onCellTap;

  const _AdoptedProgressCard({
    required this.title,
    required this.reason,
    required this.sourceChanged,
    required this.progress,
    required this.today,
    required this.onCellTap,
  });

  @override
  Widget build(BuildContext context) {
    final todayKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    return AuroraCard(
      padding: AuroraMainPageSpec.comfortableCardPadding,
      borderRadius: BorderRadius.circular(AuroraMainPageSpec.cardRadiusLarge),
      color: Colors.white.withValues(alpha: 0.74),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AuroraColors.mint),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AuroraColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
            ],
          ),
          if (reason.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              reason,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AuroraColors.muted,
                    height: 1.4,
                  ),
            ),
          ],
          if (sourceChanged) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AuroraColors.orange.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                AppLocaleText.tr(
                  context,
                  en: 'Source changed. This adopted item stays in your history.',
                  zhHans: '来源已变化；这个已采纳项目仍会保留在你的记录中。',
                  zhHant: '來源已變化；這個已採納項目仍會保留在你的記錄中。',
                  ja: '根拠が変更されました。採用済みの項目は履歴に残ります。',
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AuroraColors.ink.withValues(alpha: 0.76),
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SevenDayProgressGrid(
            progress: progress,
            onCellTap: onCellTap,
            isCellEnabled: (cell) => cell.localDate == todayKey,
          ),
        ],
      ),
    );
  }
}

class _CandidateHubHeader extends StatelessWidget {
  final CandidateKind kind;
  final VoidCallback onBack;

  const _CandidateHubHeader({required this.kind, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final isMicroAction = kind == CandidateKind.microAction;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AuroraIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: onBack,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocaleText.tr(
                  context,
                  en: isMicroAction ? 'Small actions' : 'Weekly experiments',
                  zhHans: isMicroAction ? '今日小行动' : '下周小实验',
                  zhHant: isMicroAction ? '今日小行動' : '下週小實驗',
                  ja: isMicroAction ? '今日の小さな行動' : '来週の小さな実験',
                ),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AuroraColors.ink,
                      fontSize:
                          AuroraMainPageSpec.responsiveHeroTitleSize(context),
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                AppLocaleText.tr(
                  context,
                  en: 'Choose only what feels useful. Suggestions are not tasks.',
                  zhHans: '只选择真正有用的建议；这里不是任务清单。',
                  zhHant: '只選擇真正有用的建議；這裡不是任務清單。',
                  ja: '役立ちそうな提案だけを選びます。タスクリストではありません。',
                ),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AuroraColors.muted,
                      height: 1.4,
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

class _CandidateSectionIntro extends StatelessWidget {
  final CandidateKind kind;

  const _CandidateSectionIntro({required this.kind});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            AppLocaleText.tr(
              context,
              en: 'Up to 3 options',
              zhHans: '最多 3 个候选',
              zhHant: '最多 3 個候選',
              ja: '最大 3 件の候補',
            ),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AuroraColors.ink,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
        Text(
          AppLocaleText.tr(
            context,
            en: '0–3 can be adopted',
            zhHans: '可采纳 0–3 个',
            zhHant: '可採納 0–3 個',
            ja: '0〜3 件を採用可能',
          ),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AuroraColors.muted,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _MicroCandidateList extends StatelessWidget {
  final List<MicroActionCandidateModel> candidates;
  final Set<String> selectedIds;
  final bool disabled;
  final void Function(String id, bool selected) onSelected;
  final ValueChanged<MicroActionCandidateModel> onEdit;

  const _MicroCandidateList({
    super.key,
    required this.candidates,
    required this.selectedIds,
    required this.disabled,
    required this.onSelected,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    if (candidates.isEmpty) return const _CandidateLoadingPlaceholder();
    return Column(
      children: [
        for (var index = 0; index < candidates.length; index++) ...[
          CandidateOptionCard(
            id: candidates[index].id,
            rank: candidates[index].rank,
            title: candidates[index].title,
            reason: candidates[index].reason,
            difficultyLabel: _difficultyLabel(
              context,
              candidates[index].difficulty,
            ),
            evidenceCount: candidates[index].linkedSignalCardIds.length,
            selected: selectedIds.contains(candidates[index].id),
            adopted: candidates[index].isAdopted,
            disabled: disabled || candidates[index].isStale,
            sourceChanged: candidates[index].isStale,
            energyCapacityBand: candidates[index].energyCapacityBand,
            energyAdaptationExplanation:
                candidates[index].energyAdaptationExplanation,
            onSelected: (value) => onSelected(candidates[index].id, value),
            onEdit: () => onEdit(candidates[index]),
          ),
          if (index != candidates.length - 1)
            const SizedBox(height: AuroraMainPageSpec.sectionGap),
        ],
      ],
    );
  }

  String _difficultyLabel(BuildContext context, String value) {
    return switch (value) {
      'very_light' || 'light' => AppLocaleText.tr(
          context,
          en: 'Very light',
          zhHans: '很轻',
          zhHant: '很輕',
          ja: 'とても軽い',
        ),
      'medium' => AppLocaleText.tr(
          context,
          en: 'Moderate',
          zhHans: '适中',
          zhHant: '適中',
          ja: 'ふつう',
        ),
      _ => AppLocaleText.tr(
          context,
          en: 'Light',
          zhHans: '轻量',
          zhHant: '輕量',
          ja: '軽め',
        ),
    };
  }
}

class _ExperimentCandidateList extends StatelessWidget {
  final List<ExperimentCandidateRecord> candidates;
  final Set<String> selectedIds;
  final bool disabled;
  final void Function(String id, bool selected) onSelected;
  final ValueChanged<ExperimentCandidateRecord> onEdit;

  const _ExperimentCandidateList({
    super.key,
    required this.candidates,
    required this.selectedIds,
    required this.disabled,
    required this.onSelected,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    if (candidates.isEmpty) return const _CandidateLoadingPlaceholder();
    return Column(
      children: [
        for (var index = 0; index < candidates.length; index++) ...[
          CandidateOptionCard(
            id: candidates[index].id,
            rank: candidates[index].rank,
            title: candidates[index].title,
            secondaryText: candidates[index].suggestedAction,
            reason: candidates[index].hypothesis,
            difficultyLabel: AppLocaleText.tr(
              context,
              en: '7-day experiment',
              zhHans: '七日实验',
              zhHant: '七日實驗',
              ja: '7 日間の実験',
            ),
            evidenceCount: candidates[index].linkedSignalCardIds.length,
            selected: selectedIds.contains(candidates[index].id),
            adopted: candidates[index].isAdopted,
            disabled: disabled || candidates[index].isStale,
            sourceChanged: candidates[index].isStale,
            energyCapacityBand: candidates[index].energyCapacityBand,
            energyAdaptationExplanation:
                candidates[index].energyAdaptationExplanation,
            onSelected: (value) => onSelected(candidates[index].id, value),
            onEdit: () => onEdit(candidates[index]),
          ),
          if (index != candidates.length - 1)
            const SizedBox(height: AuroraMainPageSpec.sectionGap),
        ],
      ],
    );
  }
}

class _CandidateLoadingPlaceholder extends StatelessWidget {
  const _CandidateLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return AuroraCard(
      key: const ValueKey('candidate-loading-placeholder'),
      padding: AuroraMainPageSpec.comfortableCardPadding,
      borderRadius: BorderRadius.circular(AuroraMainPageSpec.cardRadiusLarge),
      child: Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AppLocaleText.tr(
                context,
                en: 'Organizing a few options from your real signals…',
                zhHans: '正在从你的真实信号中整理几个候选……',
                zhHant: '正在從你的真實信號中整理幾個候選……',
                ja: '実際のシグナルから候補を整理しています…',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CandidateErrorCard extends StatelessWidget {
  final VoidCallback onRetry;

  const _CandidateErrorCard({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return AuroraCard(
      padding: AuroraMainPageSpec.comfortableCardPadding,
      borderRadius: BorderRadius.circular(AuroraMainPageSpec.cardRadiusLarge),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AuroraColors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppLocaleText.tr(
                context,
                en: 'Suggestions could not be refreshed. Adopted items are unchanged.',
                zhHans: '候选暂时无法更新，已经采纳的内容不会改变。',
                zhHant: '候選暫時無法更新，已經採納的內容不會改變。',
                ja: '候補を更新できませんでした。採用済みの内容は変わりません。',
              ),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 44),
            ),
            onPressed: onRetry,
            child: Text(
              AppLocaleText.tr(
                context,
                en: 'Retry',
                zhHans: '重试',
                zhHant: '重試',
                ja: '再試行',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
