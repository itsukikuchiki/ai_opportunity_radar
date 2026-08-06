import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/di/app_dependencies.dart';
import '../../../core/i18n/app_locale_text.dart';
import '../../../core/local/local_candidate_planning_repository.dart';
import '../../../core/models/candidate_models.dart';
import '../../../core/models/phase3_plus_models.dart';
import '../../../core/models/weekly_models.dart';
import '../../../core/navigation/app_back_navigation.dart';
import '../../../core/policies/planning_content_edit_policy.dart';
import '../../../shared/widgets/aurora_ui.dart';
import '../../../shared/widgets/candidate_planning_widgets.dart';
import '../../../shared/widgets/experiment_feedback_sheets.dart';

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
  List<MicroActionCandidateModel> _nextWeekSmallTryCandidates = const [];
  List<ExperimentCandidateRecord> _experimentCandidates = const [];
  List<AdoptedMicroActionProgress> _activeActions = const [];
  List<AdoptedMicroActionProgress> _continuableActions = const [];
  List<AdoptedLifeExperimentProgress> _continuableExperiments = const [];
  List<MicroActionModel> _plannedNextWeekActions = const [];
  List<LifeExperimentModel> _plannedNextWeekExperiments = const [];
  final Set<String> _selectedIds = {};
  final Set<String> _selectedActionContinuationIds = {};
  final Set<String> _selectedExperimentContinuationIds = {};
  StreamSubscription<CandidateGenerationState>? _generationSubscription;
  bool _initialized = false;
  bool _loading = true;
  bool _adopting = false;
  String? _withdrawingPlanId;
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
        await repository.refreshNextWeekPlanWithGroundedSuggestions(
          day: _today,
          language: AppLocaleText.resolve(context),
        );
        final refreshed = await repository.weeklyCandidateSnapshot(_today);
        final nextWeekPlan = await repository.nextWeekPlanCandidateSnapshot(
          _today,
        );
        if (!mounted) return;
        _applyExperimentSnapshot(refreshed);
        setState(() {
          _nextWeekSmallTryCandidates = nextWeekPlan.smallTryCandidates
              .where(
                (candidate) => !candidate.isAdopted && !candidate.isConsidering,
              )
              .toList(growable: false);
          _selectedIds.removeWhere(
            (id) =>
                !_experimentCandidates.any((candidate) => candidate.id == id) &&
                !_nextWeekSmallTryCandidates
                    .any((candidate) => candidate.id == id),
          );
        });
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
      _microCandidates = snapshot.candidates
          .where(
            (candidate) => !candidate.isAdopted && !candidate.isConsidering,
          )
          .take(3)
          .toList(growable: false);
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
      _experimentCandidates = snapshot.candidates
          .where(
            (candidate) => !candidate.isAdopted && !candidate.isConsidering,
          )
          .take(3)
          .toList(growable: false);
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
        final smallTryIds = _selectedIds
            .where((id) => _nextWeekSmallTryCandidates
                .any((candidate) => candidate.id == id))
            .toList(growable: false);
        final goalIds = _selectedIds
            .where((id) =>
                _experimentCandidates.any((candidate) => candidate.id == id))
            .toList(growable: false);
        if (smallTryIds.isNotEmpty) {
          await _repository!.adoptMicroActionCandidates(smallTryIds);
        }
        if (goalIds.isNotEmpty) {
          await _repository!.adoptExperimentCandidates(goalIds);
        }
        final snapshot = await _repository!.weeklyCandidateSnapshot(_today);
        final nextWeekPlan = await _repository!.nextWeekPlanCandidateSnapshot(
          _today,
        );
        if (!mounted) return;
        _applyExperimentSnapshot(snapshot);
        setState(() {
          _nextWeekSmallTryCandidates = nextWeekPlan.smallTryCandidates
              .where(
                (candidate) => !candidate.isAdopted && !candidate.isConsidering,
              )
              .toList(growable: false);
        });
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
                    ? 'Your Spot Tries are adopted. Progress starts today.'
                    : 'Your selected next-week items are saved. Progress starts next Monday.',
                zhHans: widget.kind == CandidateKind.microAction
                    ? '已采纳所选小实验，七日进度从今天开始。'
                    : '下周尝试已确认，七日进度从下周一开始。',
                zhHant: widget.kind == CandidateKind.microAction
                    ? '已採納所選小實驗，七日進度從今天開始。'
                    : '下週嘗試已確認，七日進度從下週一開始。',
                ja: widget.kind == CandidateKind.microAction
                    ? '選んだ小実験を採用しました。7 日間の進捗は今日から始まります。'
                    : '選んだ来週の試みを保存しました。7 日間の進捗は来週月曜日から始まります。',
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

  Future<void> _confirmContinuations() async {
    if (_adopting || _repository == null) return;
    setState(() => _adopting = true);
    try {
      await _repository!.continueMicroActionsForNextWeek(
        microActionIds: _selectedActionContinuationIds,
        day: _today,
      );
      await _repository!.continueExperimentsForNextWeek(
        experimentIds: _selectedExperimentContinuationIds,
        day: _today,
      );
      _selectedActionContinuationIds.clear();
      _selectedExperimentContinuationIds.clear();
      await _loadActiveProgress();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              AppLocaleText.tr(
                context,
                en: 'Next week is confirmed. Selected items continue; unselected items complete after this week.',
                zhHans: '下周续行已确认；所选项目继续，未选项目在本周结束后完成。',
                zhHant: '下週續行已確認；所選項目繼續，未選項目在本週結束後完成。',
                ja: '来週の継続を確定しました。選んだ項目は継続し、未選択の項目は今週末で完了します。',
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

  Future<void> _considerSelected() async {
    if (_adopting || _selectedIds.isEmpty || _repository == null) return;
    setState(() => _adopting = true);
    try {
      await _repository!.markCandidatesConsidering(_selectedIds);
      if (widget.kind == CandidateKind.microAction) {
        final snapshot = await _repository!.dailyCandidateSnapshot(_today);
        if (!mounted) return;
        _applyMicroSnapshot(snapshot);
      } else {
        final snapshot = await _repository!.weeklyCandidateSnapshot(_today);
        final nextWeekPlan = await _repository!.nextWeekPlanCandidateSnapshot(
          _today,
        );
        if (!mounted) return;
        _applyExperimentSnapshot(snapshot);
        setState(() {
          _nextWeekSmallTryCandidates = nextWeekPlan.smallTryCandidates
              .where(
                (candidate) => !candidate.isAdopted && !candidate.isConsidering,
              )
              .toList(growable: false);
        });
      }
      _selectedIds.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              AppLocaleText.tr(
                context,
                en: 'Saved for consideration / observation. No plan or progress was created.',
                zhHans: '已保存为考虑/观察，不会创建计划或进度。',
                zhHant: '已儲存為考慮/觀察，不會建立計畫或進度。',
                ja: '検討・観察として保存しました。計画や進捗は作成されません。',
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
    final fallbackRoute = isMicroAction ? AppRoutes.today : AppRoutes.weekly;
    final gate = _gate;
    final generation = _generation;
    final candidatesDisabled =
        generation?.status == CandidateGenerationStatus.regenerating ||
            generation?.status == CandidateGenerationStatus.stale;
    final selectedCount = _selectedIds.length;
    final selectedContinuationCount = _selectedActionContinuationIds.length +
        _selectedExperimentContinuationIds.length;
    final hasContinuations = !isMicroAction &&
        (_continuableActions.isNotEmpty || _continuableExperiments.isNotEmpty);
    final showExperimentProposals = !isMicroAction &&
        gate?.isOpen == true &&
        (_experimentCandidates.isNotEmpty ||
            _nextWeekSmallTryCandidates.isNotEmpty ||
            candidatesDisabled ||
            _loading);
    final showCandidateDecisionControls =
        isMicroAction ? gate?.isOpen == true : showExperimentProposals;
    final selectionBlockedByCandidateRefresh =
        candidatesDisabled && (isMicroAction || _selectedIds.isNotEmpty);

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
                    onBack: () => context.popOrGo<bool>(fallbackRoute, true),
                  ),
                  const SizedBox(height: AuroraMainPageSpec.heroGap),
                  if (!isMicroAction)
                    _NextWeekPeriodCard(
                      today: _today,
                      plannedActions: _plannedNextWeekActions,
                      plannedExperiments: _plannedNextWeekExperiments,
                      withdrawingPlanId: _withdrawingPlanId,
                      onWithdrawAction: _withdrawPlannedAction,
                      onWithdrawExperiment: _withdrawPlannedExperiment,
                    ),
                  if (!isMicroAction)
                    const SizedBox(height: AuroraMainPageSpec.sectionGap),
                  if (gate != null && (isMicroAction || gate.isOpen == false))
                    CandidateGateCard(
                      gate: gate,
                      icon: isMicroAction
                          ? Icons.spa_rounded
                          : Icons.science_rounded,
                      accent: isMicroAction
                          ? AuroraColors.mint
                          : AuroraColors.purple,
                    )
                  else if (gate == null && _loading)
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
                  if (isMicroAction && _activeActions.isNotEmpty) ...[
                    const SizedBox(height: AuroraMainPageSpec.sectionGap),
                    _AdoptedProgressSection(
                      kind: widget.kind,
                      actions: _activeActions,
                      experiments: const [],
                      today: _today,
                      onActionProgress: _recordActionProgress,
                      onExperimentProgress: _recordExperimentProgress,
                      onActionEdit: _editAdoptedAction,
                      onExperimentEdit: _editAdoptedExperiment,
                    ),
                  ],
                  if (hasContinuations) ...[
                    const SizedBox(height: AuroraMainPageSpec.sectionGap),
                    _ContinuingPlanSection(
                      actions: _continuableActions,
                      experiments: _continuableExperiments,
                      selectedActionIds: _selectedActionContinuationIds,
                      selectedExperimentIds: _selectedExperimentContinuationIds,
                      disabled: _adopting,
                      onActionSelected: _setActionContinuationSelected,
                      onExperimentSelected: _setExperimentContinuationSelected,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      AppLocaleText.tr(
                        context,
                        en: '$selectedContinuationCount selected to continue',
                        zhHans: '已选择 $selectedContinuationCount 项下周继续',
                        zhHant: '已選擇 $selectedContinuationCount 項下週繼續',
                        ja: '$selectedContinuationCount 件を来週も継続',
                      ),
                      key: const ValueKey(
                        'candidate-continuation-selected-count',
                      ),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AuroraColors.muted,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      key: const ValueKey('candidate-confirm-continuations'),
                      onPressed: _adopting ? null : _confirmContinuations,
                      icon: _adopting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.next_plan_outlined),
                      label: Text(
                        AppLocaleText.tr(
                          context,
                          en: 'Confirm next-week continuation',
                          zhHans: '确认下周续行',
                          zhHant: '確認下週續行',
                          ja: '来週の継続を確定',
                        ),
                      ),
                    ),
                  ],
                  if (isMicroAction && gate?.isOpen == true ||
                      showExperimentProposals) ...[
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
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_nextWeekSmallTryCandidates.isNotEmpty) ...[
                                  Text(
                                    AppLocaleText.tr(context,
                                        en: 'Spot Tries',
                                        zhHans: '小实验提案',
                                        zhHant: '小實驗提案',
                                        ja: '小実験の提案'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 8),
                                  _MicroCandidateList(
                                    key: ValueKey(_nextWeekSmallTryCandidates
                                        .map((candidate) => candidate.id)
                                        .join('|')),
                                    candidates: _nextWeekSmallTryCandidates,
                                    selectedIds: _selectedIds,
                                    disabled: candidatesDisabled || _adopting,
                                    onSelected: _setSelected,
                                    onEdit: _editMicroCandidate,
                                  ),
                                ],
                                if (_nextWeekSmallTryCandidates.isNotEmpty &&
                                    _experimentCandidates.isNotEmpty)
                                  const SizedBox(height: 16),
                                if (_experimentCandidates.isNotEmpty) ...[
                                  Text(
                                    AppLocaleText.tr(context,
                                        en: 'Goal proposals',
                                        zhHans: '目标提案',
                                        zhHant: '目標提案',
                                        ja: '目標の提案'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 8),
                                  _ExperimentCandidateList(
                                    key: ValueKey(_experimentCandidates
                                        .map((candidate) => candidate.id)
                                        .join('|')),
                                    candidates: _experimentCandidates,
                                    selectedIds: _selectedIds,
                                    disabled: candidatesDisabled || _adopting,
                                    onSelected: _setSelected,
                                    onEdit: _editExperimentCandidate,
                                  ),
                                ],
                              ],
                            ),
                    ),
                  ],
                  if (showCandidateDecisionControls) ...[
                    const SizedBox(height: 14),
                    Text(
                      AppLocaleText.tr(
                        context,
                        en: '$selectedCount selected',
                        zhHans: '已选择 $selectedCount 项',
                        zhHant: '已選擇 $selectedCount 項',
                        ja: '$selectedCount 件を選択中',
                      ),
                      key: const ValueKey('candidate-selected-count'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AuroraColors.muted,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            key: const ValueKey('candidate-adopt-selected'),
                            onPressed: selectionBlockedByCandidateRefresh ||
                                    _adopting ||
                                    selectedCount == 0
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
                                : const Icon(
                                    Icons.check_circle_outline_rounded,
                                  ),
                            label: Text(
                              AppLocaleText.tr(
                                context,
                                en: 'Adopt',
                                zhHans: '采纳',
                                zhHant: '採納',
                                ja: '採用',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const ValueKey(
                              'candidate-consider-selected',
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                            onPressed: selectionBlockedByCandidateRefresh ||
                                    _adopting ||
                                    selectedCount == 0
                                ? null
                                : _considerSelected,
                            icon: const Icon(Icons.visibility_outlined),
                            label: Text(
                              AppLocaleText.tr(
                                context,
                                en: 'Consider / observe',
                                zhHans: '考虑/观察',
                                zhHant: '考慮/觀察',
                                ja: '検討・観察',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
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

  void _setActionContinuationSelected(String id, bool selected) {
    setState(() {
      if (selected) {
        _selectedActionContinuationIds.add(id);
      } else {
        _selectedActionContinuationIds.remove(id);
      }
    });
  }

  void _setExperimentContinuationSelected(String id, bool selected) {
    setState(() {
      if (selected) {
        _selectedExperimentContinuationIds.add(id);
      } else {
        _selectedExperimentContinuationIds.remove(id);
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
    if (widget.kind == CandidateKind.microAction) {
      final snapshot = await _repository!.dailyCandidateSnapshot(_today);
      if (mounted) _applyMicroSnapshot(snapshot);
      return;
    }
    final snapshot = await _repository!.nextWeekPlanCandidateSnapshot(_today);
    if (!mounted) return;
    setState(() {
      _nextWeekSmallTryCandidates = snapshot.smallTryCandidates;
      _selectedIds.removeWhere(
        (id) =>
            !_experimentCandidates.any((candidate) => candidate.id == id) &&
            !_nextWeekSmallTryCandidates.any((candidate) => candidate.id == id),
      );
    });
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

  Future<void> _editAdoptedAction(AdoptedMicroActionProgress item) async {
    final result = await _showCandidateEditDialog(
      context,
      title: item.action.title,
      editingAdoptedContent: true,
    );
    if (result == null || _repository == null) return;
    final updated = await _repository!.updateAdoptedMicroActionContent(
      microActionId: item.action.id,
      title: result.$1,
    );
    if (!mounted) return;
    if (updated == null) {
      _showPlanningEditUnavailable(context);
      return;
    }
    await _loadActiveProgress();
  }

  Future<void> _editAdoptedExperiment(
    AdoptedLifeExperimentProgress item,
  ) async {
    final repository =
        context.read<AppDependencies>().localLifeExperimentRepository;
    final result = await _showCandidateEditDialog(
      context,
      title: item.experiment.title,
      action: item.experiment.suggestedAction,
      editingAdoptedContent: true,
    );
    if (result == null) return;
    final updated = await repository.updateDetails(
      experimentId: item.experiment.id,
      title: result.$1,
      suggestedAction: result.$2!,
    );
    if (!mounted) return;
    if (updated == null) {
      _showPlanningEditUnavailable(context);
      return;
    }
    await _loadActiveProgress();
  }

  Future<void> _loadActiveProgress() async {
    final repository = _repository;
    if (repository == null) return;
    if (widget.kind == CandidateKind.microAction) {
      final actions = await repository.listActiveMicroActionsForDate(_today);
      if (!mounted) return;
      setState(() => _activeActions = actions);
    } else {
      final results = await Future.wait<Object>([
        repository.listContinuableMicroActionsForNextWeek(_today),
        repository.listContinuableExperimentsForNextWeek(_today),
        repository.listPlannedMicroActionsForNextWeek(_today),
        repository.listPlannedExperimentsForNextWeek(_today),
      ]);
      if (!mounted) return;
      setState(() {
        _continuableActions = results[0] as List<AdoptedMicroActionProgress>;
        _continuableExperiments =
            results[1] as List<AdoptedLifeExperimentProgress>;
        _plannedNextWeekActions = results[2] as List<MicroActionModel>;
        _plannedNextWeekExperiments = results[3] as List<LifeExperimentModel>;
        _selectedActionContinuationIds.removeWhere(
          (id) => !_continuableActions.any((item) => item.action.id == id),
        );
        _selectedExperimentContinuationIds.removeWhere(
          (id) =>
              !_continuableExperiments.any((item) => item.experiment.id == id),
        );
      });
    }
  }

  Future<void> _withdrawPlannedAction(MicroActionModel action) async {
    final repository = _repository;
    if (repository == null || _withdrawingPlanId != null) return;
    setState(() => _withdrawingPlanId = action.id);
    try {
      final removed = await repository.withdrawPlannedMicroActionForNextWeek(
        microActionId: action.id,
        day: _today,
      );
      if (!mounted) return;
      if (!removed) {
        _showWithdrawUnavailable();
        return;
      }
      await _reloadNextWeekPlan();
      if (!mounted) return;
      _showWithdrawnMessage();
    } finally {
      if (mounted) setState(() => _withdrawingPlanId = null);
    }
  }

  Future<void> _withdrawPlannedExperiment(
    LifeExperimentModel experiment,
  ) async {
    final repository = _repository;
    if (repository == null || _withdrawingPlanId != null) return;
    setState(() => _withdrawingPlanId = experiment.id);
    try {
      final removed = await repository.withdrawPlannedExperimentForNextWeek(
        experimentId: experiment.id,
        day: _today,
      );
      if (!mounted) return;
      if (!removed) {
        _showWithdrawUnavailable();
        return;
      }
      await _reloadNextWeekPlan();
      if (!mounted) return;
      _showWithdrawnMessage();
    } finally {
      if (mounted) setState(() => _withdrawingPlanId = null);
    }
  }

  Future<void> _reloadNextWeekPlan() async {
    final repository = _repository;
    if (repository == null) return;
    final snapshot = await repository.weeklyCandidateSnapshot(_today);
    final nextWeekPlan = await repository.nextWeekPlanCandidateSnapshot(
      _today,
    );
    if (!mounted) return;
    _applyExperimentSnapshot(snapshot);
    setState(() {
      _nextWeekSmallTryCandidates = nextWeekPlan.smallTryCandidates
          .where(
            (candidate) => !candidate.isAdopted && !candidate.isConsidering,
          )
          .toList(growable: false);
    });
    await _loadActiveProgress();
  }

  void _showWithdrawnMessage() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            AppLocaleText.tr(
              context,
              en: 'Deleted from next week. This week’s history is unchanged.',
              zhHans: '已从下周计划删除，本周历史记录不会改变。',
              zhHant: '已從下週計畫刪除，本週歷史記錄不會改變。',
              ja: '来週の計画から削除しました。今週の履歴は変わりません。',
            ),
          ),
        ),
      );
  }

  void _showWithdrawUnavailable() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            AppLocaleText.tr(
              context,
              en: 'This item has already started and can no longer be deleted here.',
              zhHans: '这项内容已经开始，不能再从下周计划中删除。',
              zhHant: '這項內容已經開始，不能再從下週計畫中刪除。',
              ja: 'この項目はすでに開始しているため、ここでは削除できません。',
            ),
          ),
        ),
      );
  }

  Future<void> _recordActionProgress(
    AdoptedMicroActionProgress item,
    SevenDayProgressCell cell,
  ) async {
    if (!_isTodayCell(cell)) return;
    final feedback = await showSmallTryAttemptFeedbackSheet(
      context,
      title: item.action.title,
    );
    if (feedback == null || !mounted) return;
    await context
        .read<AppDependencies>()
        .todayRepository
        .submitMicroActionFeedback(
          microActionId: item.action.id,
          feedback: feedback.completionStatus,
          effect: feedback.effect,
          difficulty: feedback.difficulty,
          userNote: feedback.note,
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
    await context
        .read<AppDependencies>()
        .localLifeExperimentRepository
        .recordFeedback(
          experimentId: item.experiment.id,
          completionStatus: feedback,
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
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    barrierColor: AuroraColors.ink.withValues(alpha: 0.34),
    builder: (sheetContext) => AuroraModalSurface(
      key: const ValueKey('candidate-progress-aurora-sheet'),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      padding: EdgeInsets.fromLTRB(
        18,
        10,
        18,
        18 + MediaQuery.paddingOf(sheetContext).bottom,
      ),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AuroraColors.muted.withValues(alpha: 0.46),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              AppLocaleText.tr(
                context,
                en: 'Did you complete it today?',
                zhHans: '今天完成了吗？',
                zhHant: '今天完成了嗎？',
                ja: '今日は完了しましたか？',
              ),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AuroraColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            _ProgressChoiceTile(
              icon: Icons.check_circle_rounded,
              color: AuroraColors.mint,
              label: AppLocaleText.tr(
                context,
                en: 'Completed',
                zhHans: '已完成',
                zhHant: '已完成',
                ja: '完了',
              ),
              onTap: () => Navigator.pop(sheetContext, 'completed'),
            ),
            const SizedBox(height: 8),
            _ProgressChoiceTile(
              icon: Icons.close_rounded,
              color: AuroraColors.orange,
              label: AppLocaleText.tr(
                context,
                en: 'Not completed',
                zhHans: '未完成',
                zhHant: '未完成',
                ja: '未完了',
              ),
              onTap: () => Navigator.pop(sheetContext, 'not_completed'),
            ),
          ]),
    ),
  );
}

Future<(String, String?)?> _showCandidateEditDialog(
  BuildContext context, {
  required String title,
  String? action,
  bool editingAdoptedContent = false,
}) async {
  final titleController = TextEditingController(text: title);
  final actionController = TextEditingController(text: action);
  final result = await showDialog<(String, String?)>(
    context: context,
    builder: (dialogContext) => AuroraDialog(
      key: const ValueKey('candidate-edit-aurora-dialog'),
      title: Text(
        AppLocaleText.tr(
          context,
          en: editingAdoptedContent
              ? 'Edit this week’s content'
              : 'Edit before adopting',
          zhHans: editingAdoptedContent ? '修改本周内容' : '采纳前修改内容',
          zhHant: editingAdoptedContent ? '修改本週內容' : '採納前修改內容',
          ja: editingAdoptedContent ? '今週の内容を編集' : '採用前に編集',
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('candidate-edit-title'),
            controller: titleController,
            minLines: 1,
            maxLines: 3,
            maxLength: 120,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.72),
              labelText: AppLocaleText.tr(
                context,
                en: 'Title',
                zhHans: '标题',
                zhHant: '標題',
                ja: 'タイトル',
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
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
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.72),
                labelText: AppLocaleText.tr(
                  context,
                  en: 'How to try it',
                  zhHans: '怎么尝试',
                  zhHant: '怎麼嘗試',
                  ja: '試し方',
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
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

void _showPlanningEditUnavailable(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          AppLocaleText.tr(
            context,
            en: 'Past content and feedback records cannot be changed.',
            zhHans: '过去内容和反馈记录不能修改。',
            zhHant: '過去內容和回饋記錄不能修改。',
            ja: '過去の内容とフィードバック記録は変更できません。',
          ),
        ),
      ),
    );
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
  final ValueChanged<AdoptedMicroActionProgress> onActionEdit;
  final ValueChanged<AdoptedLifeExperimentProgress> onExperimentEdit;

  const _AdoptedProgressSection({
    required this.kind,
    required this.actions,
    required this.experiments,
    required this.today,
    required this.onActionProgress,
    required this.onExperimentProgress,
    required this.onActionEdit,
    required this.onExperimentEdit,
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
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: AuroraMainPageSpec.sectionGap),
        if (isMicro)
          for (var index = 0; index < actions.length; index++) ...[
            _AdoptedProgressCard(
              title: actions[index].action.title,
              reason: actions[index].action.reason,
              isSmallTry: true,
              sourceChanged: actions[index].action.sourceChanged,
              progress: actions[index].progress,
              today: today,
              onCellTap: (cell) => onActionProgress(actions[index], cell),
              onEdit: PlanningContentEditPolicy.canEditMicroAction(
                actions[index].action,
                now: today,
              )
                  ? () => onActionEdit(actions[index])
                  : null,
              editKey: 'adopted-small-try-${actions[index].action.id}-edit',
            ),
            if (index != actions.length - 1)
              const SizedBox(height: AuroraMainPageSpec.sectionGap),
          ]
        else
          for (var index = 0; index < experiments.length; index++) ...[
            _AdoptedProgressCard(
              title: experiments[index].experiment.title,
              reason: experiments[index].experiment.suggestedAction,
              isSmallTry: false,
              sourceChanged: experiments[index].experiment.sourceChanged,
              progress: experiments[index].progress,
              today: today,
              onCellTap: (cell) =>
                  onExperimentProgress(experiments[index], cell),
              onEdit: PlanningContentEditPolicy.canEditLifeExperiment(
                experiments[index].experiment,
                now: today,
              )
                  ? () => onExperimentEdit(experiments[index])
                  : null,
              editKey: 'adopted-goal-${experiments[index].experiment.id}-edit',
            ),
            if (index != experiments.length - 1)
              const SizedBox(height: AuroraMainPageSpec.sectionGap),
          ],
      ],
    );
  }
}

class _NextWeekPeriodCard extends StatelessWidget {
  final DateTime today;
  final List<MicroActionModel> plannedActions;
  final List<LifeExperimentModel> plannedExperiments;
  final String? withdrawingPlanId;
  final ValueChanged<MicroActionModel> onWithdrawAction;
  final ValueChanged<LifeExperimentModel> onWithdrawExperiment;

  const _NextWeekPeriodCard({
    required this.today,
    required this.plannedActions,
    required this.plannedExperiments,
    required this.withdrawingPlanId,
    required this.onWithdrawAction,
    required this.onWithdrawExperiment,
  });

  @override
  Widget build(BuildContext context) {
    final localDay = DateTime(today.year, today.month, today.day);
    final currentWeekStart = localDay.subtract(
      Duration(days: localDay.weekday - DateTime.monday),
    );
    final start = currentWeekStart.add(const Duration(days: 7));
    final end = start.add(const Duration(days: 6));
    final localizations = MaterialLocalizations.of(context);
    final range = '${localizations.formatShortMonthDay(start)}–'
        '${localizations.formatShortMonthDay(end)}';

    return AuroraCard(
      key: const ValueKey('next-week-period-card'),
      padding: AuroraMainPageSpec.comfortableCardPadding,
      borderRadius: BorderRadius.circular(AuroraMainPageSpec.cardRadiusLarge),
      color: Colors.white.withValues(alpha: 0.74),
      border: Border.all(
        color: AuroraColors.purple.withValues(alpha: 0.22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 54,
                decoration: BoxDecoration(
                  color: AuroraColors.purple.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocaleText.tr(
                        context,
                        en: 'Next week · $range',
                        zhHans: '下周 · $range',
                        zhHant: '下週 · $range',
                        ja: '来週 · $range',
                      ),
                      key: const ValueKey('next-week-period-label'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AuroraColors.ink,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLocaleText.tr(
                        context,
                        en: 'Choose only what you want to continue or begin next week.',
                        zhHans: '这里只选择下周要继续或开始的生活小实验。',
                        zhHant: '這裡只選擇下週要繼續或開始的生活小實驗。',
                        ja: '来週も続ける、または新しく始める生活実験だけを選びます。',
                      ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AuroraColors.muted,
                            height: 1.4,
                            fontWeight: FontWeight.w400,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (plannedActions.isNotEmpty || plannedExperiments.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text(
              AppLocaleText.tr(
                context,
                en: 'Selected for next week',
                zhHans: '已选下周计划',
                zhHant: '已選下週計畫',
                ja: '来週に選んだ内容',
              ),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AuroraColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            for (final action in plannedActions) ...[
              _NextWeekSelectedPlanRow(
                key: ValueKey('next-week-selected-small-${action.id}'),
                icon: Icons.spa_rounded,
                accent: AuroraColors.mint,
                typeLabel: AppLocaleText.tr(
                  context,
                  en: 'Spot Try',
                  zhHans: '小实验',
                  zhHant: '小實驗',
                  ja: '小実験',
                ),
                title: action.title,
                withdrawing: withdrawingPlanId == action.id,
                withdrawKey: 'next-week-withdraw-small-${action.id}',
                onWithdraw: () => onWithdrawAction(action),
              ),
              const SizedBox(height: 8),
            ],
            for (final experiment in plannedExperiments) ...[
              _NextWeekSelectedPlanRow(
                key: ValueKey('next-week-selected-goal-${experiment.id}'),
                icon: Icons.science_rounded,
                accent: AuroraColors.blue,
                typeLabel: AppLocaleText.tr(
                  context,
                  en: 'Goal',
                  zhHans: '目标',
                  zhHant: '目標',
                  ja: '目標',
                ),
                title: experiment.title,
                withdrawing: withdrawingPlanId == experiment.id,
                withdrawKey: 'next-week-withdraw-goal-${experiment.id}',
                onWithdraw: () => onWithdrawExperiment(experiment),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              AppLocaleText.tr(
                context,
                en: 'Delete only removes the next-week plan. This week’s history stays unchanged.',
                zhHans: '删除只会移除下周计划，本周历史记录不会改变。',
                zhHant: '刪除只會移除下週計畫，本週歷史記錄不會改變。',
                ja: '削除しても来週の計画だけが外れ、今週の履歴は変わりません。',
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AuroraColors.muted,
                    height: 1.4,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NextWeekSelectedPlanRow extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String typeLabel;
  final String title;
  final bool withdrawing;
  final String withdrawKey;
  final VoidCallback onWithdraw;

  const _NextWeekSelectedPlanRow({
    super.key,
    required this.icon,
    required this.accent,
    required this.typeLabel,
    required this.title,
    required this.withdrawing,
    required this.withdrawKey,
    required this.onWithdraw,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  typeLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AuroraColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          TextButton.icon(
            key: ValueKey(withdrawKey),
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              foregroundColor: AuroraColors.orange,
            ),
            onPressed: withdrawing ? null : onWithdraw,
            icon: withdrawing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline_rounded, size: 18),
            label: Text(
              AppLocaleText.tr(
                context,
                en: 'Delete',
                zhHans: '删除',
                zhHant: '刪除',
                ja: '削除',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinuingPlanSection extends StatelessWidget {
  final List<AdoptedMicroActionProgress> actions;
  final List<AdoptedLifeExperimentProgress> experiments;
  final Set<String> selectedActionIds;
  final Set<String> selectedExperimentIds;
  final bool disabled;
  final void Function(String id, bool selected) onActionSelected;
  final void Function(String id, bool selected) onExperimentSelected;

  const _ContinuingPlanSection({
    required this.actions,
    required this.experiments,
    required this.selectedActionIds,
    required this.selectedExperimentIds,
    required this.disabled,
    required this.onActionSelected,
    required this.onExperimentSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocaleText.tr(
            context,
            en: 'Spot Tries and goals in progress',
            zhHans: '进行中的小实验与目标',
            zhHant: '進行中的小實驗與目標',
            ja: '進行中の小実験と目標',
          ),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AuroraColors.ink,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          AppLocaleText.tr(
            context,
            en: 'Select the items to continue next week. Unselected items complete after this week; this week’s history stays unchanged.',
            zhHans: '勾选下周继续采纳的项目；未勾选的项目在本周结束后完成，本周历史不会改变。',
            zhHant: '勾選下週繼續採納的項目；未勾選的項目在本週結束後完成，本週歷史不會改變。',
            ja: '来週も続ける項目を選びます。未選択の項目は今週末で完了し、今週の履歴は変わりません。',
          ),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AuroraColors.muted,
                height: 1.4,
                fontWeight: FontWeight.w400,
              ),
        ),
        const SizedBox(height: AuroraMainPageSpec.sectionGap),
        for (var index = 0; index < actions.length; index++) ...[
          _ContinuingPlanCard(
            key: ValueKey(
              'continuation-small-experiment-${actions[index].action.id}',
            ),
            title: actions[index].action.title,
            description: actions[index].action.reason,
            typeLabel: AppLocaleText.tr(
              context,
              en: 'Spot Try',
              zhHans: '小实验',
              zhHant: '小實驗',
              ja: '小実験',
            ),
            accent: AuroraColors.mint,
            completedCount: actions[index].progress.completedDays,
            selected: selectedActionIds.contains(actions[index].action.id),
            disabled: disabled,
            onSelected: (selected) =>
                onActionSelected(actions[index].action.id, selected),
          ),
          if (index != actions.length - 1 || experiments.isNotEmpty)
            const SizedBox(height: AuroraMainPageSpec.sectionGap),
        ],
        for (var index = 0; index < experiments.length; index++) ...[
          _ContinuingPlanCard(
            key: ValueKey(
              'continuation-option-${experiments[index].experiment.id}',
            ),
            title: experiments[index].experiment.title,
            description: experiments[index].experiment.suggestedAction,
            typeLabel: AppLocaleText.tr(
              context,
              en: 'Goal',
              zhHans: '目标',
              zhHant: '目標',
              ja: '目標',
            ),
            accent: AuroraColors.purple,
            completedCount: experiments[index].progress.completedDays,
            selected: selectedExperimentIds
                .contains(experiments[index].experiment.id),
            disabled: disabled,
            onSelected: (selected) => onExperimentSelected(
              experiments[index].experiment.id,
              selected,
            ),
          ),
          if (index != experiments.length - 1)
            const SizedBox(height: AuroraMainPageSpec.sectionGap),
        ],
      ],
    );
  }
}

class _ContinuingPlanCard extends StatelessWidget {
  final String title;
  final String description;
  final String typeLabel;
  final Color accent;
  final int completedCount;
  final bool selected;
  final bool disabled;
  final ValueChanged<bool> onSelected;

  const _ContinuingPlanCard({
    super.key,
    required this.title,
    required this.description,
    required this.typeLabel,
    required this.accent,
    required this.completedCount,
    required this.selected,
    required this.disabled,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      selected: selected,
      enabled: !disabled,
      label: AppLocaleText.tr(
        context,
        en: '$typeLabel. $title. Continue next week.',
        zhHans: '$typeLabel。$title。下周继续采纳。',
        zhHant: '$typeLabel。$title。下週繼續採納。',
        ja: '$typeLabel。$title。来週も継続。',
      ),
      child: AuroraCard(
        padding: AuroraMainPageSpec.comfortableCardPadding,
        borderRadius: BorderRadius.circular(AuroraMainPageSpec.cardRadiusLarge),
        color: Colors.white.withValues(alpha: 0.74),
        border: Border.all(
          color: selected ? accent.withValues(alpha: 0.74) : AuroraColors.line,
          width: selected ? 1.8 : 1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        typeLabel,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        title,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AuroraColors.ink,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AuroraColors.ink.withValues(alpha: 0.76),
                              height: 1.4,
                              fontWeight: FontWeight.w400,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Checkbox(
                  value: selected,
                  onChanged: disabled
                      ? null
                      : (value) {
                          if (value != null) onSelected(value);
                        },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.insights_rounded,
                  size: 18,
                  color: accent,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    AppLocaleText.tr(
                      context,
                      en: 'This week $completedCount completed',
                      zhHans: '本周已完成 $completedCount 次',
                      zhHant: '本週已完成 $completedCount 次',
                      ja: '今週 $completedCount 回完了',
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AuroraColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Continue next week',
                    zhHans: '下周继续采纳',
                    zhHant: '下週繼續採納',
                    ja: '来週も継続',
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: selected ? accent : AuroraColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AdoptedProgressCard extends StatelessWidget {
  final String title;
  final String reason;
  final bool isSmallTry;
  final bool sourceChanged;
  final SevenDayProgressModel progress;
  final DateTime today;
  final ValueChanged<SevenDayProgressCell> onCellTap;
  final VoidCallback? onEdit;
  final String? editKey;

  const _AdoptedProgressCard({
    required this.title,
    required this.reason,
    required this.isSmallTry,
    required this.sourceChanged,
    required this.progress,
    required this.today,
    required this.onCellTap,
    this.onEdit,
    this.editKey,
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
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              if (onEdit != null)
                IconButton(
                  key: editKey == null ? null : ValueKey(editKey!),
                  tooltip: AppLocaleText.tr(
                    context,
                    en: 'Edit this week’s content',
                    zhHans: '修改本周内容',
                    zhHant: '修改本週內容',
                    ja: '今週の内容を編集',
                  ),
                  constraints: const BoxConstraints.tightFor(
                    width: 44,
                    height: 44,
                  ),
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
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
                  ja: 'Signal ソースが変更されました。採用済みの項目は履歴に残ります。',
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
          if (progress.cells.any((cell) => cell.localDate == todayKey)) ...[
            const SizedBox(height: 8),
            Text(
              isSmallTry
                  ? AppLocaleText.tr(
                      context,
                      en: 'Tap today’s cell to record whether you tried it.',
                      zhHans: '点击今天的格子，登记这次是否试了。',
                      zhHant: '點擊今天的格子，登記這次是否試了。',
                      ja: '今日のマスをタップして、今回試したかを記録します。',
                    )
                  : AppLocaleText.tr(
                      context,
                      en: 'Tap today’s cell to record “Completed” or “Not completed”.',
                      zhHans: '点击今天的格子，登记“已完成”或“未完成”。',
                      zhHant: '點擊今天的格子，登記「已完成」或「未完成」。',
                      ja: '今日のマスをタップして「完了」または「未完了」を記録します。',
                    ),
              key: ValueKey(
                'candidate-daily-completion-hint-${progress.subjectId}',
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AuroraColors.muted,
                    height: 1.4,
                  ),
            ),
          ],
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
    return AuroraCard(
      key: const ValueKey('candidate-hub-hero-card'),
      padding: const EdgeInsets.fromLTRB(12, 12, 10, 14),
      borderRadius: BorderRadius.circular(24),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFFFFFBF6).withValues(alpha: 0.94),
          const Color(0xFFF7F1FF).withValues(alpha: 0.86),
          const Color(0xFFEEF5FF).withValues(alpha: 0.80),
        ],
      ),
      child: Row(
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
                AuroraHeroTitle(
                  text: AppLocaleText.tr(
                    context,
                    en: isMicroAction
                        ? 'Life Experiment · Spot Tries'
                        : 'Next week’s tries',
                    zhHans: isMicroAction ? '生活小实验 · 小实验' : '下周尝试',
                    zhHant: isMicroAction ? '生活小實驗 · 小實驗' : '下週嘗試',
                    ja: isMicroAction ? '生活実験 · 小実験' : '来週の試み',
                  ),
                  fontSize: AuroraMainPageSpec.responsiveHeroTitleSize(context),
                ),
                const SizedBox(height: 6),
                Text(
                  AppLocaleText.tr(
                    context,
                    en: isMicroAction
                        ? 'Choose a Spot Try you can start right away, keep low-cost, and pause at any time.'
                        : 'Choose next week’s Spot Tries and goals. Selected items begin next Monday.',
                    zhHans: isMicroAction
                        ? '选择现在就能开始、成本很低、随时可以暂停的简单尝试。'
                        : '在这里统一选择下周的小实验和目标；选定内容下周一开始出现在今天。',
                    zhHant: isMicroAction
                        ? '選擇現在就能開始、成本很低、隨時可以暫停的簡單嘗試。'
                        : '在這裡統一選擇下週的小實驗和目標；選定內容下週一開始出現在今天。',
                    ja: isMicroAction
                        ? '今すぐ始められ、負担が少なく、いつでも止められるスポットトライを選びます。'
                        : '来週の小実験と目標をここで選びます。選んだ内容は月曜日から今日に表示されます。',
                  ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AuroraColors.muted,
                        height: 1.4,
                        fontWeight: FontWeight.w400,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 2),
          SizedBox(
            key: ValueKey(
              isMicroAction
                  ? 'candidate-hub-experiment-pattern'
                  : 'candidate-hub-review-pattern',
            ),
            width: isMicroAction ? 112 : 92,
            height: 86,
            child: IgnorePointer(
              child: isMicroAction
                  ? const AuroraExperimentHeroPattern(
                      opacity: 0.82,
                      alignment: Alignment.centerRight,
                      fit: BoxFit.cover,
                    )
                  : const AuroraReviewHeroPattern(opacity: 0.92),
            ),
          ),
        ],
      ),
    );
  }
}

class _CandidateSectionIntro extends StatelessWidget {
  final CandidateKind kind;

  const _CandidateSectionIntro({required this.kind});

  @override
  Widget build(BuildContext context) {
    if (kind == CandidateKind.lifeExperiment) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocaleText.tr(
              context,
              en: 'Goal proposals',
              zhHans: '目标提案',
              zhHant: '目標提案',
              ja: '目標の提案',
            ),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AuroraColors.ink,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            AppLocaleText.tr(
              context,
              en: 'Goals grounded in this week’s Signals. Spot Try proposals join this page when available.',
              zhHans: '基于本周 Signal 的目标提案；小实验提案准备好后也会显示在这里。',
              zhHant: '基於本週 Signal 的目標提案；小實驗提案準備好後也會顯示在這裡。',
              ja: '今週の Signal に基づく目標の提案です。小実験の提案も準備でき次第ここに表示されます。',
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AuroraColors.muted,
                  height: 1.4,
                  fontWeight: FontWeight.w400,
                ),
          ),
        ],
      );
    }
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
                  fontWeight: FontWeight.w700,
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
              en: '7-day goal',
              zhHans: '七日目标',
              zhHant: '七日目標',
              ja: '7 日間の目標',
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
