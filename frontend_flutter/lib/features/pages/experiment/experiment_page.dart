// ignore_for_file: unused_element, unused_field, prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/di/app_dependencies.dart';
import '../../../core/i18n/app_locale_text.dart';
import '../../../core/local/local_cache_invalidation_repository.dart';
import '../../../core/local/local_database.dart';
import '../../../core/models/candidate_models.dart';
import '../../../core/models/experiment_creation_source.dart';
import '../../../core/models/experiment_evaluation_models.dart';
import '../../../core/models/phase3_plus_models.dart';
import '../../../core/models/today_models.dart';
import '../../../core/models/weekly_models.dart';
import '../../../core/purchases/purchase_controller.dart';
import '../../../shared/states/load_state.dart';
import '../../../shared/utils/user_visible_text_sanitizer.dart';
import '../../../shared/widgets/aurora_ui.dart';
import '../../paywall/paywall_sheet.dart';
import '../weekly/weekly_view_model.dart';
import 'experiment_action_preference_report.dart';

class ExperimentPage extends StatefulWidget {
  final int archivePageSize;

  const ExperimentPage({
    super.key,
    this.archivePageSize = 20,
  }) : assert(archivePageSize > 0);

  @override
  State<ExperimentPage> createState() => _ExperimentPageState();
}

enum _ExperimentHomeTrack {
  smallExperiments,
  goals,
}

class _ExperimentPageState extends State<ExperimentPage> {
  int get _archivePageSize => widget.archivePageSize;

  final _titleController = TextEditingController();
  final _actionController = TextEditingController();
  final _reasonController = TextEditingController();
  final _searchController = TextEditingController();
  String? _loadedExperimentId;
  bool _isEditing = false;
  List<_TryOption> _editTryOptions = const [];
  final int _frequencyDays = 7;
  List<LifeExperimentModel> _history = const [];
  List<AdoptedMicroActionProgress> _smallTries = const [];
  List<MicroActionCandidateModel> _consideringSmallTries = const [];
  List<ExperimentCandidateRecord> _consideringGoals = const [];
  bool _smallTriesHasMore = false;
  bool _goalsHaveMore = false;
  bool _smallTriesLoadingMore = false;
  bool _goalsLoadingMore = false;
  bool _expandingGoalArchive = false;
  bool _historyLoaded = false;
  bool _historyLoading = false;
  bool _historyReloadRequested = false;
  bool _historyReloadResetRequested = false;
  StreamSubscription<CandidateInvalidationNotice>?
      _candidateInvalidationSubscription;
  Map<String, List<LifeExperimentFeedbackModel>> _feedbacksByExperiment =
      const {};
  Map<String, List<RecentSignalModel>> _signalsByExperiment = const {};
  Map<String, List<RecentSignalModel>> _signalsBySmallTry = const {};
  Map<String, _ExperimentRollup> _rollupsByExperiment = const {};
  Map<String, List<_ExperimentLifecycleEvent>> _lifecycleByExperiment =
      const {};
  Map<String, List<MicroActionFeedbackModel>> _smallTryFeedbacksByAction =
      const {};
  Map<String, List<MicroActionReviewEventModel>> _smallTryReviewsByAction =
      const {};
  Map<String, List<LifeExperimentOutcomeReviewModel>>
      _outcomeReviewsByExperiment = const {};
  _ExperimentFilter _filter = _ExperimentFilter.all;
  _ExperimentHomeTrack _homeTrack = _ExperimentHomeTrack.smallExperiments;
  AdoptedMicroActionProgress? _selectedSmallTry;
  MicroActionCandidateModel? _selectedSmallTryCandidate;
  ExperimentCandidateRecord? _selectedGoalCandidate;
  LifeExperimentModel? _selectedExperiment;
  // Legacy aggregate scaffold stays unreachable for compatibility while its
  // former entry point is removed from the Life Experiment home page.
  bool _showStatsDetail = false;
  bool _openingActionPreferenceReport = false;
  _ExperimentDetailTab _detailTab = _ExperimentDetailTab.overview;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (!mounted) return;
      setState(() {});
      if (_searchController.text.trim().isNotEmpty) {
        _ensureAllSmallTriesLoaded();
        _ensureAllGoalsLoaded();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _watchCandidateInvalidations();
      _loadExperimentHistory(reset: true);
    });
  }

  @override
  void dispose() {
    _candidateInvalidationSubscription?.cancel();
    _titleController.dispose();
    _actionController.dispose();
    _reasonController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _watchCandidateInvalidations() {
    if (_candidateInvalidationSubscription != null || !mounted) return;
    late final LocalDatabase localDatabase;
    try {
      localDatabase = context.read<AppDependencies>().localDatabase;
    } on ProviderNotFoundException {
      // Some lightweight previews render this page from WeeklyViewModel only.
      // The invalidation stream is an enhancement, not a page dependency.
      return;
    }
    _candidateInvalidationSubscription = CandidateInvalidationBus.stream
        .where((notice) => identical(notice.localDatabase, localDatabase))
        .listen((_) {
      if (mounted) unawaited(_loadExperimentHistory(reset: true));
    });
  }

  void _showHomeTrack(_ExperimentHomeTrack track) {
    if (_homeTrack == track) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _homeTrack = track;
    });
  }

  Future<void> _openCreateSmallExperiment() async {
    final deps = context.read<AppDependencies>();
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _CreateSmallExperimentPage(
          onSubmit: (draft) async {
            await deps.localPhase3PlusRepository.createUserSmallExperiment(
              title: draft.title,
              description: draft.description,
              durationMinutes: draft.durationMinutes,
              startDate: DateTime.now(),
            );
          },
        ),
      ),
    );
    if (created != true || !mounted) return;
    await _loadExperimentHistory(reset: true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocaleText.tr(
            context,
            en: 'Spot Try created.',
            zhHans: '小实验已创建。',
            zhHant: '小實驗已建立。',
            ja: '小実験を作成しました。',
          ),
        ),
      ),
    );
  }

  Future<void> _openCreateGoal() async {
    final deps = context.read<AppDependencies>();
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _CreateGoalPage(
          onSubmit: (draft) async {
            await deps.localLifeExperimentRepository.createUserGoal(
              localUserId: deps.localUserId,
              title: draft.title,
              hypothesis: draft.hypothesis,
              suggestedAction: draft.suggestedAction,
              startDate: DateTime.now(),
              plannedFrequency: draft.plannedFrequency,
              plannedTotalDays: draft.observationDays,
              minimumObservationDays: draft.observationDays,
            );
          },
        ),
      ),
    );
    if (created != true || !mounted) return;
    await _loadExperimentHistory(reset: true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocaleText.tr(
            context,
            en: 'Goal created.',
            zhHans: '目标已创建。',
            zhHant: '目標已建立。',
            ja: '目標を作成しました。',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WeeklyViewModel>();
    final purchase = context.watch<PurchaseController?>();
    final weekly = vm.weeklyInsight;
    final experiments = _experimentArchive(weekly);
    final selectedSmallTryCandidate = _selectedSmallTryCandidate;
    if (selectedSmallTryCandidate != null) {
      return _buildConsideringSmallTryDetailScaffold(
        context,
        selectedSmallTryCandidate,
      );
    }
    final selectedGoalCandidate = _selectedGoalCandidate;
    if (selectedGoalCandidate != null) {
      return _buildConsideringGoalDetailScaffold(
        context,
        selectedGoalCandidate,
      );
    }
    final selectedSmallTry = _selectedSmallTry;
    if (selectedSmallTry != null) {
      return _buildSmallTryDetailScaffold(context, selectedSmallTry);
    }
    final selected = _selectedExperiment;
    if (selected != null) {
      return _buildDetailScaffold(context, selected);
    }
    final hasAnyExperiments = experiments.isNotEmpty;
    final visibleSmallTries = _visibleSmallTries(_smallTries);
    final visibleConsideringSmallTries =
        _visibleConsideringSmallTries(_consideringSmallTries);
    final visibleConsideringGoals = _visibleConsideringGoals(_consideringGoals);
    final visibleExperiments = _visibleExperiments(experiments);
    final hasSearchQuery = _searchController.text.trim().isNotEmpty;
    final hasSearchResults = visibleSmallTries.isNotEmpty ||
        visibleConsideringSmallTries.isNotEmpty ||
        visibleExperiments.isNotEmpty ||
        visibleConsideringGoals.isNotEmpty;
    final activeCount = _smallTries
            .where(
              (item) =>
                  _smallTryLifecycleStage(item.action) ==
                  _ExperimentLifecycleStage.active,
            )
            .length +
        experiments
            .where(
              (experiment) =>
                  _experimentLifecycleStage(
                    experiment,
                    _rollupFor(experiment),
                  ) ==
                  _ExperimentLifecycleStage.active,
            )
            .length;
    final feedbackCount = _smallTryFeedbacksByAction.values
            .expand((feedbacks) => feedbacks)
            .where((feedback) => feedback.isValid)
            .length +
        _feedbacksByExperiment.values.fold<int>(
          0,
          (count, feedbacks) => count + feedbacks.length,
        );
    final conclusionCount = _smallTryReviewsByAction.values
            .where((reviews) => reviews.isNotEmpty)
            .length +
        _outcomeReviewsByExperiment.values
            .where((reviews) => reviews.isNotEmpty)
            .length;

    return Scaffold(
      body: Stack(
        children: [
          AuroraPage(
            child: Stack(
              children: [
                SafeArea(
                  bottom: false,
                  child: ListView(
                    key: const ValueKey('experiment-scroll-view'),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: AuroraMainPageSpec.scrollPadding(context),
                    children: [
                      _ExperimentArchiveHeroHeader(
                        canPop: Navigator.of(context).canPop(),
                        onBack: () => Navigator.of(context).maybePop(),
                        activeCount: activeCount,
                        feedbackCount: feedbackCount,
                        conclusionCount: conclusionCount,
                      ),
                      const SizedBox(height: AuroraMainPageSpec.heroGap),
                      _ExperimentSearchBar(controller: _searchController),
                      const SizedBox(height: 10),
                      _ExperimentCreateEntryCard(
                        onCreateSmallExperiment: _openCreateSmallExperiment,
                        onCreateGoal: _openCreateGoal,
                      ),
                      const SizedBox(height: 12),
                      ExperimentActionPreferenceEntryCard(
                        isPremium: purchase?.isPremium ?? false,
                        isLoading: _openingActionPreferenceReport,
                        onTap: () => _openActionPreferenceReport(purchase),
                      ),
                      const SizedBox(height: AuroraMainPageSpec.sectionGap),
                      if ((_historyLoading ||
                              vm.loadState == LoadState.loading) &&
                          experiments.isEmpty &&
                          _smallTries.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (hasSearchQuery && !hasSearchResults)
                        _ExperimentSearchEmptyState(
                          onClear: _searchController.clear,
                        )
                      else
                        _ExperimentTrackPager(
                          track: _homeTrack,
                          onShowSmallExperiments: () => _showHomeTrack(
                            _ExperimentHomeTrack.smallExperiments,
                          ),
                          onShowGoals: () => _showHomeTrack(
                            _ExperimentHomeTrack.goals,
                          ),
                          child: _homeTrack ==
                                  _ExperimentHomeTrack.smallExperiments
                              ? Column(
                                  key: const ValueKey(
                                    'experiment-track-small-experiments',
                                  ),
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _SmallTryBranchChart(
                                      items: visibleSmallTries,
                                      consideringCandidates:
                                          visibleConsideringSmallTries,
                                      feedbacksFor: (item) =>
                                          _smallTryFeedbacksByAction[
                                              item.action.id] ??
                                          const [],
                                      latestReviewFor: (item) {
                                        final reviews = _smallTryReviewsByAction[
                                                item.action.id] ??
                                            const <MicroActionReviewEventModel>[];
                                        return reviews.isEmpty
                                            ? null
                                            : reviews.last;
                                      },
                                      onOpenDetail: (item) => setState(() {
                                        _selectedSmallTry = item;
                                      }),
                                      onOpenCandidateDetail: (candidate) =>
                                          setState(() {
                                        _selectedSmallTryCandidate = candidate;
                                      }),
                                    ),
                                    if (_smallTriesHasMore ||
                                        _smallTriesLoadingMore) ...[
                                      const SizedBox(height: 10),
                                      _ArchiveLoadMoreButton(
                                        key: const ValueKey(
                                          'life-experiment-small-tries-load-more',
                                        ),
                                        isLoading: _smallTriesLoadingMore,
                                        onPressed: _smallTriesLoadingMore
                                            ? null
                                            : _loadMoreSmallTries,
                                      ),
                                    ],
                                  ],
                                )
                              : Column(
                                  key: const ValueKey(
                                    'experiment-track-goals',
                                  ),
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _GoalTimelineMatrix(
                                      experiments: visibleExperiments,
                                      consideringCandidates:
                                          visibleConsideringGoals,
                                      evidenceFor: _evidenceFor,
                                      rollupFor: _rollupFor,
                                      latestOutcomeFor: (experiment) {
                                        final reviews = _outcomeReviewsByExperiment[
                                                experiment.id] ??
                                            const <LifeExperimentOutcomeReviewModel>[];
                                        return reviews.isEmpty
                                            ? null
                                            : reviews.last;
                                      },
                                      onOpenDetail: (experiment) =>
                                          setState(() {
                                        _selectedExperiment = experiment;
                                        _detailTab =
                                            _ExperimentDetailTab.overview;
                                      }),
                                      onOpenCandidateDetail: (candidate) =>
                                          setState(() {
                                        _selectedGoalCandidate = candidate;
                                      }),
                                    ),
                                    if (_goalsHaveMore ||
                                        _goalsLoadingMore) ...[
                                      const SizedBox(height: 2),
                                      _ArchiveLoadMoreButton(
                                        key: const ValueKey(
                                          'life-experiment-goals-load-more',
                                        ),
                                        isLoading: _goalsLoadingMore,
                                        onPressed: _goalsLoadingMore
                                            ? null
                                            : _loadMoreGoals,
                                      ),
                                    ],
                                  ],
                                ),
                        ),
                      if (!hasAnyExperiments &&
                          _smallTries.isEmpty &&
                          _consideringSmallTries.isEmpty &&
                          _consideringGoals.isEmpty) ...[
                        const SizedBox(height: AuroraMainPageSpec.sectionGap),
                        const _ExperimentUnifiedEmptyState(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const AuroraSafeTopMask(extraHeight: 4),
        ],
      ),
    );
  }

  Future<void> _openActionPreferenceReport(
    PurchaseController? purchase,
  ) async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(purchase?.isPremium ?? false)) {
      await showPremiumPaywall(
        context,
        source: 'life_experiment_action_preferences',
      );
      return;
    }
    if (_openingActionPreferenceReport) return;
    setState(() => _openingActionPreferenceReport = true);
    try {
      await Future.wait([
        _ensureAllSmallTriesLoaded(),
        _ensureAllGoalsLoaded(),
      ]);
      if (!mounted) return;
      final report = buildExperimentActionPreferenceReport(
        smallExperiments: _smallTries,
        smallExperimentFeedbacks: _smallTryFeedbacksByAction,
        goals: _history,
        goalReviews: _outcomeReviewsByExperiment,
      );
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ExperimentActionPreferenceReportPage(
            report: report,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _openingActionPreferenceReport = false);
      }
    }
  }

  Widget _buildDetailScaffold(
    BuildContext context,
    LifeExperimentModel experiment,
  ) {
    final evidence = _evidenceFor(experiment);
    final rollup = _rollupFor(experiment);
    final completedObservationDays = _completedGoalObservationDays(evidence);
    final outcomeReviews =
        _outcomeReviewsByExperiment[experiment.id] ?? const [];
    final weeklyOutcomeReviews = outcomeReviews
        .where((review) => review.reviewType == GoalReviewType.weekly)
        .toList(growable: false);
    final overallOutcomeReviews = outcomeReviews
        .where((review) => review.reviewType != GoalReviewType.weekly)
        .toList(growable: false);
    final latestOutcome =
        overallOutcomeReviews.isEmpty ? null : overallOutcomeReviews.last;
    final lifecycleStage = _experimentLifecycleStage(experiment, rollup);
    return Scaffold(
      body: Stack(
        children: [
          AuroraPage(
            child: Stack(
              children: [
                const Positioned(
                  key: ValueKey('experiment-detail-experiment-pattern'),
                  right: -12,
                  top: 18,
                  width: 188,
                  height: 132,
                  child: IgnorePointer(
                    child: AuroraExperimentHeroPattern(opacity: 0.68),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      22,
                      12,
                      22,
                      MediaQuery.paddingOf(context).bottom + 150,
                    ),
                    children: [
                      Row(
                        children: [
                          _BackBubble(onTap: () {
                            setState(() => _selectedExperiment = null);
                          }),
                          Expanded(
                            child: Text(
                              AppLocaleText.tr(
                                context,
                                en: 'Goal detail',
                                zhHans: '目标详情',
                                zhHant: '目標詳情',
                                ja: '目標の詳細',
                              ),
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    color: AuroraColors.ink,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 52),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _LifeExperimentDetailHeroCard(
                        experiment: experiment,
                        evidence: evidence,
                        rollup: rollup,
                      ),
                      const SizedBox(height: 16),
                      _GoalDefinitionCard(experiment: experiment),
                      const SizedBox(height: 14),
                      _ExperimentOriginCard(
                        creationSource: experiment.creationSource,
                        adoptedAt: experiment.adoptedAt,
                      ),
                      const SizedBox(height: 14),
                      _ExperimentContentChangeGuide(
                        kind: _ExperimentContentKind.goal,
                        onCreateNew: _openCreateGoal,
                      ),
                      const SizedBox(height: 14),
                      _GoalWeeklySummaryCard(
                        experiment: experiment,
                        evidence: evidence,
                        reviews: weeklyOutcomeReviews,
                      ),
                      const SizedBox(height: 14),
                      _GoalFeedbackOverviewCard(
                        feedbacks: evidence.feedbacks,
                        reviews: overallOutcomeReviews,
                      ),
                      const SizedBox(height: 18),
                      if (lifecycleStage ==
                          _ExperimentLifecycleStage.active) ...[
                        if (completedObservationDays >=
                                experiment.minimumObservationDays ||
                            latestOutcome != null) ...[
                          OutlinedButton.icon(
                            key: const ValueKey('goal-overall-review-action'),
                            onPressed: () =>
                                _openGoalOutcomeReview(context, experiment),
                            icon: const Icon(Icons.insights_rounded),
                            label: Text(
                              latestOutcome == null
                                  ? AppLocaleText.tr(
                                      context,
                                      en: 'Write an overall summary',
                                      zhHans: '写整体总结',
                                      zhHant: '寫整體總結',
                                      ja: '全体まとめを書く',
                                    )
                                  : AppLocaleText.tr(
                                      context,
                                      en: 'Add another overall summary',
                                      zhHans: '补充整体总结',
                                      zhHant: '補充整體總結',
                                      ja: '全体まとめを追加',
                                    ),
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              foregroundColor: AuroraColors.purple,
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ] else ...[
                        _ExperimentArchiveReadOnlyNotice(
                          stage: lifecycleStage,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const AuroraSafeTopMask(extraHeight: 6),
        ],
      ),
    );
  }

  Widget _buildSmallTryDetailScaffold(
    BuildContext context,
    AdoptedMicroActionProgress item,
  ) {
    final stage = _smallTryLifecycleStage(item.action);
    final roundReviews = _smallTryReviewsByAction[item.action.id] ?? const [];
    return Scaffold(
      body: Stack(
        children: [
          AuroraPage(
            child: Stack(
              children: [
                const Positioned(
                  right: -12,
                  top: 18,
                  width: 188,
                  height: 132,
                  child: IgnorePointer(
                    child: AuroraExperimentHeroPattern(opacity: 0.68),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: ListView(
                    key: const ValueKey('small-try-detail-scroll-view'),
                    padding: EdgeInsets.fromLTRB(
                      22,
                      12,
                      22,
                      MediaQuery.paddingOf(context).bottom + 150,
                    ),
                    children: [
                      Row(
                        children: [
                          _BackBubble(onTap: () {
                            setState(() => _selectedSmallTry = null);
                          }),
                          Expanded(
                            child: Text(
                              AppLocaleText.tr(
                                context,
                                en: 'Spot Try details',
                                zhHans: '小实验详情',
                                zhHant: '小實驗詳情',
                                ja: '小実験の詳細',
                              ),
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    color: AuroraColors.ink,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 52),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _SmallTryDetailCard(
                        item: item,
                        stage: stage,
                        feedbacks: _smallTryFeedbacksByAction[item.action.id] ??
                            const [],
                        latestReview: () {
                          return roundReviews.isEmpty
                              ? null
                              : roundReviews.last;
                        }(),
                      ),
                      const SizedBox(height: 14),
                      _SmallExperimentOverviewCard(
                        action: item.action,
                        canonicalAttemptCount: item.progress.completedAttempts,
                        feedbacks: _smallTryFeedbacksByAction[item.action.id] ??
                            const [],
                        reviews: roundReviews,
                      ),
                      const SizedBox(height: 14),
                      _ExperimentOriginCard(
                        creationSource: item.action.creationSource,
                        adoptedAt: item.action.adoptedAt,
                      ),
                      const SizedBox(height: 14),
                      _ExperimentContentChangeGuide(
                        kind: _ExperimentContentKind.smallExperiment,
                        onCreateNew: _openCreateSmallExperiment,
                      ),
                      const SizedBox(height: 14),
                      _SmallExperimentFeedbackOverviewCard(
                        feedbacks: _smallTryFeedbacksByAction[item.action.id] ??
                            const [],
                        reviews: roundReviews,
                      ),
                      const SizedBox(height: 14),
                      if (stage == _ExperimentLifecycleStage.active)
                        OutlinedButton.icon(
                          key: const ValueKey(
                            'small-experiment-round-review-action',
                          ),
                          onPressed: () => _openSmallTryRoundReview(
                            context,
                            item,
                          ),
                          icon: const Icon(Icons.task_alt_rounded),
                          label: Text(
                            AppLocaleText.tr(
                              context,
                              en: 'Summarize this round',
                              zhHans: '总结这一轮',
                              zhHant: '總結這一輪',
                              ja: '今回をまとめる',
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            foregroundColor: AuroraColors.mint,
                            side: BorderSide(
                              color: AuroraColors.mint.withValues(alpha: 0.42),
                            ),
                          ),
                        ),
                      if (stage != _ExperimentLifecycleStage.active)
                        _ExperimentArchiveReadOnlyNotice(stage: stage),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const AuroraSafeTopMask(extraHeight: 6),
        ],
      ),
    );
  }

  Widget _buildConsideringSmallTryDetailScaffold(
    BuildContext context,
    MicroActionCandidateModel candidate,
  ) {
    return _buildConsideringDetailScaffold(
      context,
      pageTitle: AppLocaleText.tr(
        context,
        en: 'Spot Try details',
        zhHans: '小实验详情',
        zhHant: '小實驗詳情',
        ja: '小実験の詳細',
      ),
      title: candidate.title,
      description: candidate.reason,
      actionText: '',
      isStale: candidate.isStale,
      staleReason: candidate.staleReason,
      onBack: () => setState(() => _selectedSmallTryCandidate = null),
      onAdopt:
          candidate.isStale ? null : () => _adoptConsideringSmallTry(candidate),
    );
  }

  Widget _buildConsideringGoalDetailScaffold(
    BuildContext context,
    ExperimentCandidateRecord candidate,
  ) {
    return _buildConsideringDetailScaffold(
      context,
      pageTitle: AppLocaleText.tr(
        context,
        en: 'Goal detail',
        zhHans: '目标详情',
        zhHant: '目標詳情',
        ja: '目標の詳細',
      ),
      title: candidate.title,
      description: candidate.hypothesis,
      actionText: candidate.suggestedAction,
      isStale: candidate.isStale,
      staleReason: candidate.staleReason,
      onBack: () => setState(() => _selectedGoalCandidate = null),
      onAdopt:
          candidate.isStale ? null : () => _adoptConsideringGoal(candidate),
    );
  }

  Widget _buildConsideringDetailScaffold(
    BuildContext context, {
    required String pageTitle,
    required String title,
    required String description,
    required String actionText,
    required bool isStale,
    required String? staleReason,
    required VoidCallback onBack,
    required VoidCallback? onAdopt,
  }) {
    return Scaffold(
      body: Stack(
        children: [
          AuroraPage(
            child: Stack(
              children: [
                const Positioned(
                  right: -12,
                  top: 18,
                  width: 188,
                  height: 132,
                  child: IgnorePointer(
                    child: AuroraExperimentHeroPattern(opacity: 0.68),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      22,
                      12,
                      22,
                      MediaQuery.paddingOf(context).bottom + 150,
                    ),
                    children: [
                      Row(
                        children: [
                          _BackBubble(onTap: onBack),
                          Expanded(
                            child: Text(
                              pageTitle,
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    color: AuroraColors.ink,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 52),
                        ],
                      ),
                      const SizedBox(height: 24),
                      AuroraCard(
                        key: const ValueKey(
                          'considering-experiment-detail-card',
                        ),
                        padding: AuroraMainPageSpec.cardPadding,
                        color: Colors.white.withValues(alpha: 0.74),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const AuroraSoftIconCircle(
                                  icon: Icons.visibility_outlined,
                                  color: AuroraColors.gold,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: AuroraColors.ink,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                                _StatusPill(
                                  label: _lifecycleStageLabel(
                                    context,
                                    _ExperimentLifecycleStage.considering,
                                  ),
                                  color: AuroraColors.gold,
                                ),
                              ],
                            ),
                            if (description.trim().isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Text(
                                description.trim(),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: AuroraColors.muted,
                                      height: 1.5,
                                    ),
                              ),
                            ],
                            if (actionText.trim().isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Text(
                                AppLocaleText.tr(
                                  context,
                                  en: 'How to try',
                                  zhHans: '准备怎么试',
                                  zhHant: '準備怎麼試',
                                  ja: '試し方',
                                ),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      color: AuroraColors.purple,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                actionText.trim(),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: AuroraColors.ink,
                                      height: 1.45,
                                    ),
                              ),
                            ],
                            if (isStale) ...[
                              const SizedBox(height: 12),
                              const _ExperimentSourceChangedBadge(),
                              if (staleReason?.trim().isNotEmpty == true) ...[
                                const SizedBox(height: 5),
                                Text(
                                  staleReason!.trim(),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: AuroraColors.orange,
                                        height: 1.4,
                                      ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (onAdopt != null)
                        _ExperimentPrimaryButton(
                          label: AppLocaleText.tr(
                            context,
                            en: 'Adopt',
                            zhHans: '采纳',
                            zhHant: '採納',
                            ja: '採用',
                          ),
                          onTap: onAdopt,
                        ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: onBack,
                        icon: const Icon(Icons.visibility_outlined),
                        label: Text(
                          AppLocaleText.tr(
                            context,
                            en: 'Keep considering / observing',
                            zhHans: '继续考虑 / 观察',
                            zhHant: '繼續考慮 / 觀察',
                            ja: '検討・観察を続ける',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const AuroraSafeTopMask(extraHeight: 6),
        ],
      ),
    );
  }

  Widget _buildStatsDetailScaffold(
    BuildContext context,
    List<LifeExperimentModel> experiments,
  ) {
    final metrics = _summaryMetrics(
      experiments,
      _feedbacksByExperiment,
      _rollupsByExperiment,
    );
    final recentExperiments = experiments.take(5).toList();
    return Scaffold(
      body: Stack(
        children: [
          AuroraPage(
            child: Stack(
              children: [
                const Positioned(
                  key: ValueKey('experiment-stats-experiment-pattern'),
                  right: -12,
                  top: 18,
                  width: 188,
                  height: 132,
                  child: IgnorePointer(
                    child: AuroraExperimentHeroPattern(opacity: 0.68),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      22,
                      12,
                      22,
                      MediaQuery.paddingOf(context).bottom + 150,
                    ),
                    children: [
                      Row(
                        children: [
                          _BackBubble(onTap: () {
                            setState(() => _showStatsDetail = false);
                          }),
                          Expanded(
                            child: Text(
                              AppLocaleText.tr(
                                context,
                                en: 'Goal details',
                                zhHans: '目标详情',
                                zhHant: '目標詳情',
                                ja: '目標の詳細',
                              ),
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    color: AuroraColors.ink,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 52),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _ExperimentStatsHeroCard(metrics: metrics),
                      const SizedBox(height: 12),
                      _ExperimentStatusBreakdownCard(metrics: metrics),
                      const SizedBox(height: 12),
                      _ExperimentAttemptBreakdownCard(metrics: metrics),
                      const SizedBox(height: 12),
                      _ExperimentGlassCard(
                        title: AppLocaleText.tr(
                          context,
                          en: 'Recent goals',
                          zhHans: '最近的目标',
                          zhHant: '最近的目標',
                          ja: '最近の目標',
                        ),
                        child: Column(
                          children: [
                            if (recentExperiments.isEmpty)
                              Text(
                                AppLocaleText.tr(
                                  context,
                                  en: 'No goal data yet.',
                                  zhHans: '还没有目标数据。',
                                  zhHant: '還沒有目標資料。',
                                  ja: '目標データはまだありません。',
                                ),
                              )
                            else
                              for (final experiment in recentExperiments) ...[
                                _ExperimentStatsListItem(
                                  experiment: experiment,
                                  triedCount: _actualTriedCount(
                                    experiment,
                                    _evidenceFor(experiment),
                                    _rollupFor(experiment),
                                  ),
                                  onTap: () => setState(() {
                                    _showStatsDetail = false;
                                    _selectedExperiment = experiment;
                                    _detailTab = _ExperimentDetailTab.overview;
                                  }),
                                ),
                                if (experiment != recentExperiments.last)
                                  const Divider(height: 18),
                              ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const AuroraSafeTopMask(extraHeight: 6),
        ],
      ),
    );
  }

  Future<void> _loadExperimentHistory({bool reset = false}) async {
    if (_historyLoading) {
      _historyReloadRequested = true;
      _historyReloadResetRequested = _historyReloadResetRequested || reset;
      return;
    }
    setState(() => _historyLoading = true);
    try {
      final deps = context.read<AppDependencies>();
      final selectedSmallTryId = _selectedSmallTry?.action.id;
      final selectedGoalId = _selectedExperiment?.id;
      final smallTryTarget =
          reset || _smallTries.isEmpty ? _archivePageSize : _smallTries.length;
      final goalTarget =
          reset || _history.isEmpty ? _archivePageSize : _history.length;
      final smallTryRows = await deps.localCandidatePlanningRepository
          .listAdoptedSmallTries(limit: smallTryTarget + 1);
      final consideringSmallTries = await deps.localCandidatePlanningRepository
          .listConsideringMicroActionCandidates();
      final consideringGoals = await deps.localCandidatePlanningRepository
          .listConsideringExperimentCandidates();
      final goalRows =
          await deps.localLifeExperimentRepository.listAdoptedGoals(
        localUserId: deps.localUserId,
        limit: goalTarget + 1,
      );
      final smallTries = smallTryRows.take(smallTryTarget).toList();
      final rows = goalRows.take(goalTarget).toList();

      AdoptedMicroActionProgress? refreshedSelectedSmallTry;
      if (selectedSmallTryId != null) {
        for (final item in smallTries) {
          if (item.action.id == selectedSmallTryId) {
            refreshedSelectedSmallTry = item;
            break;
          }
        }
        if (refreshedSelectedSmallTry == null) {
          final action = await deps.localPhase3PlusRepository
              .getMicroActionById(selectedSmallTryId);
          if (action != null) {
            refreshedSelectedSmallTry = AdoptedMicroActionProgress(
              action: action,
              progress: await deps.localCandidatePlanningRepository
                  .microActionProgress(selectedSmallTryId),
            );
          }
        }
      }

      LifeExperimentModel? refreshedSelectedGoal;
      if (selectedGoalId != null) {
        for (final item in rows) {
          if (item.id == selectedGoalId) {
            refreshedSelectedGoal = item;
            break;
          }
        }
        refreshedSelectedGoal ??=
            await deps.localLifeExperimentRepository.getById(selectedGoalId);
      }

      final smallTriesForArtifacts = <AdoptedMicroActionProgress>[
        ...smallTries,
        if (refreshedSelectedSmallTry != null &&
            !smallTries.any(
              (item) => item.action.id == refreshedSelectedSmallTry!.action.id,
            ))
          refreshedSelectedSmallTry,
      ];
      final goalsForArtifacts = <LifeExperimentModel>[
        ...rows,
        if (refreshedSelectedGoal != null &&
            !rows.any((item) => item.id == refreshedSelectedGoal!.id))
          refreshedSelectedGoal,
      ];
      final artifacts = await _loadGoalArtifacts(deps, goalsForArtifacts);
      final smallTryFeedbacks =
          await _loadSmallTryFeedbacks(deps, smallTriesForArtifacts);
      final smallTryReviews =
          await _loadSmallTryReviews(deps, smallTriesForArtifacts);
      final outcomeReviews =
          await _loadGoalOutcomeReviews(deps, goalsForArtifacts);
      final smallTrySignals =
          await _loadSmallTrySignals(deps, smallTriesForArtifacts);
      if (!mounted) return;
      setState(() {
        _smallTries = smallTries;
        _consideringSmallTries = consideringSmallTries;
        _consideringGoals = consideringGoals;
        _history = rows;
        _smallTriesHasMore = smallTryRows.length > smallTryTarget;
        _goalsHaveMore = goalRows.length > goalTarget;
        _feedbacksByExperiment = artifacts.feedbacks;
        _signalsByExperiment = artifacts.signals;
        _signalsBySmallTry = smallTrySignals;
        _rollupsByExperiment = artifacts.rollups;
        _lifecycleByExperiment = artifacts.lifecycle;
        _smallTryFeedbacksByAction = smallTryFeedbacks;
        _smallTryReviewsByAction = smallTryReviews;
        _outcomeReviewsByExperiment = outcomeReviews;
        if (selectedSmallTryId != null) {
          _selectedSmallTry = refreshedSelectedSmallTry;
        }
        if (selectedGoalId != null) {
          _selectedExperiment = refreshedSelectedGoal;
        }
        _historyLoaded = true;
        _historyLoading = false;
      });
      _drainQueuedHistoryReload();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _historyLoaded = true;
        _historyLoading = false;
      });
      _drainQueuedHistoryReload();
    }
  }

  void _drainQueuedHistoryReload() {
    if (!_historyReloadRequested || !mounted) return;
    final reset = _historyReloadResetRequested;
    _historyReloadRequested = false;
    _historyReloadResetRequested = false;
    unawaited(_loadExperimentHistory(reset: reset));
  }

  Future<void> _loadMoreSmallTries() async {
    if (_smallTriesLoadingMore || !_smallTriesHasMore) return;
    setState(() => _smallTriesLoadingMore = true);
    try {
      final deps = context.read<AppDependencies>();
      final rows =
          await deps.localCandidatePlanningRepository.listAdoptedSmallTries(
        limit: _archivePageSize + 1,
        offset: _smallTries.length,
      );
      final page = rows.take(_archivePageSize);
      final feedbacks = await _loadSmallTryFeedbacks(
        deps,
        page.toList(growable: false),
      );
      final reviews = await _loadSmallTryReviews(
        deps,
        page.toList(growable: false),
      );
      final signals = await _loadSmallTrySignals(
        deps,
        page.toList(growable: false),
      );
      final byId = {
        for (final item in _smallTries) item.action.id: item,
        for (final item in page) item.action.id: item,
      };
      if (!mounted) return;
      setState(() {
        _smallTries = byId.values.toList(growable: false);
        _smallTriesHasMore = rows.length > _archivePageSize;
        _smallTryFeedbacksByAction = {
          ..._smallTryFeedbacksByAction,
          ...feedbacks,
        };
        _smallTryReviewsByAction = {
          ..._smallTryReviewsByAction,
          ...reviews,
        };
        _signalsBySmallTry = {..._signalsBySmallTry, ...signals};
        _smallTriesLoadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _smallTriesLoadingMore = false);
    }
  }

  Future<void> _loadMoreGoals() async {
    if (_goalsLoadingMore || !_goalsHaveMore) return;
    setState(() => _goalsLoadingMore = true);
    try {
      final deps = context.read<AppDependencies>();
      final rows = await deps.localLifeExperimentRepository.listAdoptedGoals(
        localUserId: deps.localUserId,
        limit: _archivePageSize + 1,
        offset: _history.length,
      );
      final page = rows.take(_archivePageSize).toList(growable: false);
      final artifacts = await _loadGoalArtifacts(deps, page);
      final outcomeReviews = await _loadGoalOutcomeReviews(deps, page);
      final byId = {
        for (final experiment in _history) experiment.id: experiment,
        for (final experiment in page) experiment.id: experiment,
      };
      if (!mounted) return;
      setState(() {
        _history = byId.values.toList(growable: false);
        _goalsHaveMore = rows.length > _archivePageSize;
        _feedbacksByExperiment = {
          ..._feedbacksByExperiment,
          ...artifacts.feedbacks,
        };
        _signalsByExperiment = {
          ..._signalsByExperiment,
          ...artifacts.signals,
        };
        _rollupsByExperiment = {
          ..._rollupsByExperiment,
          ...artifacts.rollups,
        };
        _lifecycleByExperiment = {
          ..._lifecycleByExperiment,
          ...artifacts.lifecycle,
        };
        _outcomeReviewsByExperiment = {
          ..._outcomeReviewsByExperiment,
          ...outcomeReviews,
        };
        _goalsLoadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _goalsLoadingMore = false);
    }
  }

  Future<_GoalArchiveArtifacts> _loadGoalArtifacts(
    AppDependencies deps,
    List<LifeExperimentModel> rows,
  ) async {
    if (rows.isEmpty) return const _GoalArchiveArtifacts();
    for (final experiment in rows) {
      await deps.localLifeExperimentRepository.refreshRollup(experiment.id);
    }
    final ids = rows.map((experiment) => experiment.id).toList();
    final rollupRows = await deps.localLifeExperimentRepository
        .listRollupsForExperiments(experimentIds: ids);
    final lifecycleRows = await deps.localLifeExperimentRepository
        .listLifecycleEventsForExperiments(experimentIds: ids);
    final feedbacks = await deps.localLifeExperimentRepository
        .listFeedbacksForExperiments(experimentIds: ids);
    final linkedSignalIds =
        rows.expand((experiment) => experiment.linkedSignalCardIds).toSet();
    final linkedSignals =
        await deps.localCaptureRepository.listSignalCardsByIds(linkedSignalIds);

    final feedbackMap = <String, List<LifeExperimentFeedbackModel>>{};
    for (final feedback in feedbacks) {
      feedbackMap.putIfAbsent(feedback.experimentId, () => []).add(feedback);
    }
    final signalMap = <String, List<RecentSignalModel>>{};
    for (final experiment in rows) {
      final linkedIds = experiment.linkedSignalCardIds.toSet();
      signalMap[experiment.id] = linkedSignals.where((signal) {
        final id = signal.id ?? '';
        final signalCardId = signal.signalCardId ?? '';
        return linkedIds.contains(id) || linkedIds.contains(signalCardId);
      }).toList(growable: false);
    }
    final rollupMap = {
      for (final row in rollupRows)
        if ((row['experiment_id'] as String?)?.trim().isNotEmpty == true)
          row['experiment_id'] as String: _ExperimentRollup.fromRow(row),
    };
    final lifecycleMap = <String, List<_ExperimentLifecycleEvent>>{};
    for (final row in lifecycleRows) {
      final event = _ExperimentLifecycleEvent.fromRow(row);
      lifecycleMap.putIfAbsent(event.experimentId, () => []).add(event);
    }
    return _GoalArchiveArtifacts(
      feedbacks: feedbackMap,
      signals: signalMap,
      rollups: rollupMap,
      lifecycle: lifecycleMap,
    );
  }

  Future<Map<String, List<MicroActionFeedbackModel>>> _loadSmallTryFeedbacks(
    AppDependencies deps,
    List<AdoptedMicroActionProgress> items,
  ) async {
    if (items.isEmpty) return const {};
    final ids = items.map((item) => item.action.id).toSet();
    final starts = items
        .map((item) =>
            _parseExperimentDate(item.action.progressStartDate ?? '') ??
            item.action.adoptedAt?.toLocal() ??
            item.action.createdAt?.toLocal())
        .whereType<DateTime>()
        .toList(growable: false);
    final earliest = starts.isEmpty
        ? DateTime.now().subtract(const Duration(days: 3650))
        : starts.reduce((a, b) => a.isBefore(b) ? a : b);
    final rows =
        await deps.localPhase3PlusRepository.listMicroActionFeedbacksBetween(
      startDate: _localDateKey(earliest),
      endDate: _localDateKey(DateTime.now().add(const Duration(days: 1))),
    );
    final grouped = <String, List<MicroActionFeedbackModel>>{};
    for (final feedback in rows) {
      if (!ids.contains(feedback.microActionId) || !feedback.isValid) continue;
      grouped.putIfAbsent(feedback.microActionId, () => []).add(feedback);
    }
    for (final feedbacks in grouped.values) {
      feedbacks.sort((a, b) {
        final aTime = a.updatedAt ?? a.createdAt ?? DateTime(1970);
        final bTime = b.updatedAt ?? b.createdAt ?? DateTime(1970);
        return aTime.compareTo(bTime);
      });
    }
    return grouped;
  }

  Future<Map<String, List<MicroActionReviewEventModel>>> _loadSmallTryReviews(
    AppDependencies deps,
    List<AdoptedMicroActionProgress> items,
  ) async {
    final result = <String, List<MicroActionReviewEventModel>>{};
    for (final item in items) {
      result[item.action.id] = await deps.localPhase3PlusRepository
          .listMicroActionRoundReviews(microActionId: item.action.id);
    }
    return result;
  }

  Future<Map<String, List<RecentSignalModel>>> _loadSmallTrySignals(
    AppDependencies deps,
    List<AdoptedMicroActionProgress> items,
  ) async {
    if (items.isEmpty) return const {};
    final linkedIds = items
        .expand((item) => item.action.linkedSignalCardIds)
        .where((id) => id.trim().isNotEmpty)
        .toSet();
    final signals =
        await deps.localCaptureRepository.listSignalCardsByIds(linkedIds);
    return {
      for (final item in items)
        item.action.id: signals.where((signal) {
          final ids = item.action.linkedSignalCardIds.toSet();
          return ids.contains(signal.id) || ids.contains(signal.signalCardId);
        }).toList(growable: false),
    };
  }

  Future<Map<String, List<LifeExperimentOutcomeReviewModel>>>
      _loadGoalOutcomeReviews(
    AppDependencies deps,
    List<LifeExperimentModel> items,
  ) async {
    final result = <String, List<LifeExperimentOutcomeReviewModel>>{};
    for (final item in items) {
      result[item.id] = await deps.localLifeExperimentRepository
          .listOutcomeReviews(experimentId: item.id);
    }
    return result;
  }

  Future<void> _ensureAllGoalsLoaded() async {
    if (_expandingGoalArchive) return;
    _expandingGoalArchive = true;
    try {
      while (mounted && _goalsHaveMore) {
        final previousCount = _history.length;
        await _loadMoreGoals();
        if (_history.length == previousCount) break;
      }
    } finally {
      _expandingGoalArchive = false;
    }
  }

  void _selectFilter(_ExperimentFilter value) {
    setState(() => _filter = value);
    _ensureAllGoalsLoaded();
  }

  _ExperimentEvidence _evidenceFor(LifeExperimentModel experiment) {
    return _ExperimentEvidence(
      feedbacks: _feedbacksByExperiment[experiment.id] ?? const [],
      signals: _signalsByExperiment[experiment.id] ?? const [],
    );
  }

  _ExperimentRollup? _rollupFor(LifeExperimentModel experiment) {
    return _rollupsByExperiment[experiment.id];
  }

  List<_ExperimentLifecycleEvent> _lifecycleFor(
    LifeExperimentModel experiment,
  ) {
    return _lifecycleByExperiment[experiment.id] ?? const [];
  }

  Future<void> _showExperimentFilterSheet(BuildContext context) async {
    final selected = await showModalBottomSheet<_ExperimentFilter>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
            children: [
              for (final filter in _ExperimentFilter.values)
                ListTile(
                  leading: Icon(_filterIcon(filter)),
                  title: Text(_filterLabel(sheetContext, filter)),
                  trailing: filter == _filter ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.of(sheetContext).pop(filter),
                ),
            ],
          ),
        );
      },
    );
    if (selected == null || !mounted) return;
    _selectFilter(selected);
  }

  List<LifeExperimentModel> _experimentArchive(WeeklyInsightModel? weekly) {
    final byId = <String, LifeExperimentModel>{};
    for (final experiment in _history) {
      if (experiment.title.trim().isNotEmpty &&
          _isAdoptedFormalExperiment(experiment)) {
        byId[experiment.id] = experiment;
      }
    }
    final weeklyViewModel = context.read<WeeklyViewModel>();
    final compatibilityExperiments = <LifeExperimentModel?>[
      weeklyViewModel.currentWeekExperiment,
      weeklyViewModel.nextWeekExperiment,
      weekly?.lifeExperiment,
    ];
    for (final experiment in compatibilityExperiments) {
      if (experiment != null &&
          experiment.title.trim().isNotEmpty &&
          _isAdoptedFormalExperiment(experiment)) {
        byId.putIfAbsent(experiment.id, () => experiment);
      }
    }
    final list = byId.values.toList()
      ..sort((a, b) => _sortDate(b).compareTo(_sortDate(a)));
    return list;
  }

  List<LifeExperimentModel> _visibleExperiments(
    List<LifeExperimentModel> experiments,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    return experiments.where((experiment) {
      if (query.isEmpty) return true;
      return [
        experiment.title,
        experiment.hypothesis,
        experiment.suggestedAction,
        experiment.feedbackText,
      ].join(' ').toLowerCase().contains(query);
    }).toList();
  }

  List<AdoptedMicroActionProgress> _visibleSmallTries(
    List<AdoptedMicroActionProgress> items,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return items;
    return items.where((item) {
      final action = item.action;
      return [
        action.title,
        action.reason,
        action.actionType,
        action.status,
      ].join(' ').toLowerCase().contains(query);
    }).toList(growable: false);
  }

  List<MicroActionCandidateModel> _visibleConsideringSmallTries(
    List<MicroActionCandidateModel> items,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return items;
    return items
        .where((item) => [
              item.title,
              item.reason,
              item.difficulty,
              ...item.focusDomainIds,
            ].join(' ').toLowerCase().contains(query))
        .toList(growable: false);
  }

  List<ExperimentCandidateRecord> _visibleConsideringGoals(
    List<ExperimentCandidateRecord> items,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return items;
    return items
        .where((item) => [
              item.title,
              item.hypothesis,
              item.suggestedAction,
            ].join(' ').toLowerCase().contains(query))
        .toList(growable: false);
  }

  bool _matchesFilter(LifeExperimentModel experiment) {
    if (_filter == _ExperimentFilter.all) return true;
    return _experimentStatusGroup(experiment, _rollupFor(experiment)) ==
        _filter;
  }

  Future<void> _ensureAllSmallTriesLoaded() async {
    if (_smallTriesLoadingMore) return;
    while (_smallTriesHasMore && mounted) {
      final before = _smallTries.length;
      await _loadMoreSmallTries();
      if (_smallTries.length == before) break;
    }
  }

  Future<void> _openSmallTryRoundReview(
    BuildContext context,
    AdoptedMicroActionProgress item,
  ) async {
    final noteController = TextEditingController();
    final review = await showModalBottomSheet<_SmallTryRoundReviewInput>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white.withValues(alpha: 0.97),
      builder: (sheetContext) {
        String? result;
        String? effort;
        return StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                4,
                20,
                22 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocaleText.tr(
                      context,
                      en: 'Summarize this Spot Try round',
                      zhHans: '总结这一轮小实验',
                      zhHant: '總結這一輪小實驗',
                      ja: '今回の小実験をまとめる',
                    ),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AuroraColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 16),
                  _FeedbackChoiceGroup(
                    title: AppLocaleText.tr(
                      context,
                      en: 'What should happen next?',
                      zhHans: '这一轮怎么处理？',
                      zhHant: '這一輪怎麼處理？',
                      ja: '次はどうしますか？',
                    ),
                    value: result,
                    options: [
                      _FeedbackChoice(
                        value: SmallTryRoundResult.worthKeeping,
                        label: AppLocaleText.tr(
                          context,
                          en: 'Keep it',
                          zhHans: '值得保留',
                          zhHant: '值得保留',
                          ja: '残す',
                        ),
                      ),
                      _FeedbackChoice(
                        value: SmallTryRoundResult.adjustAndRetry,
                        label: AppLocaleText.tr(
                          context,
                          en: 'Make lighter',
                          zhHans: '调轻再试',
                          zhHant: '調輕再試',
                          ja: '軽くして再試行',
                        ),
                      ),
                    ],
                    onChanged: (value) => setSheetState(() => result = value),
                  ),
                  const SizedBox(height: 16),
                  _FeedbackChoiceGroup(
                    title: AppLocaleText.tr(
                      context,
                      en: 'Overall effort',
                      zhHans: '整体做起来费力吗？',
                      zhHant: '整體做起來費力嗎？',
                      ja: '全体の負担は？',
                    ),
                    value: effort,
                    options: [
                      _FeedbackChoice(
                        value: EvaluationEffort.easy,
                        label: AppLocaleText.tr(
                          context,
                          en: 'Easy',
                          zhHans: '轻松',
                          zhHant: '輕鬆',
                          ja: '楽',
                        ),
                      ),
                      _FeedbackChoice(
                        value: EvaluationEffort.acceptable,
                        label: AppLocaleText.tr(
                          context,
                          en: 'Acceptable',
                          zhHans: '可接受',
                          zhHant: '可接受',
                          ja: '許容範囲',
                        ),
                      ),
                      _FeedbackChoice(
                        value: EvaluationEffort.tooDifficult,
                        label: AppLocaleText.tr(
                          context,
                          en: 'Too demanding',
                          zhHans: '太费力',
                          zhHant: '太費力',
                          ja: '負担が大きい',
                        ),
                      ),
                    ],
                    onChanged: (value) => setSheetState(() => effort = value),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: noteController,
                    maxLength: 160,
                    decoration: InputDecoration(
                      labelText: AppLocaleText.tr(
                        context,
                        en: 'Add a note (optional)',
                        zhHans: '补一句（可选）',
                        zhHant: '補一句（可選）',
                        ja: 'ひと言追加（任意）',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      key: const ValueKey('save-small-try-round-review'),
                      onPressed: result == null || effort == null
                          ? null
                          : () => Navigator.of(sheetContext).pop(
                                _SmallTryRoundReviewInput(
                                  result: result!,
                                  effort: effort!,
                                  note: noteController.text.trim().isEmpty
                                      ? null
                                      : noteController.text.trim(),
                                ),
                              ),
                      child: Text(
                        AppLocaleText.tr(
                          context,
                          en: 'Save this summary',
                          zhHans: '保存本轮总结',
                          zhHant: '儲存本輪總結',
                          ja: '今回のまとめを保存',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    noteController.dispose();
    if (review == null || !context.mounted) return;
    final nextAdjustment = switch (review.result) {
      SmallTryRoundResult.worthKeeping => SmallTryNextAdjustment.keep,
      SmallTryRoundResult.adjustAndRetry => SmallTryNextAdjustment.makeLighter,
      _ => SmallTryNextAdjustment.keep,
    };
    final deps = context.read<AppDependencies>();
    await deps.localPhase3PlusRepository.recordMicroActionRoundReview(
      microActionId: item.action.id,
      result: review.result,
      effort: review.effort,
      nextAdjustment: nextAdjustment,
      note: review.note,
    );
    if (!mounted) return;
    await _loadExperimentHistory(reset: true);
  }

  Future<void> _openGoalOutcomeReview(
    BuildContext context,
    LifeExperimentModel experiment,
  ) async {
    final noteController = TextEditingController();
    final evidence = _evidenceFor(experiment);
    final completed = _completedGoalObservationDays(evidence);
    final belowMinimum = completed < experiment.minimumObservationDays;
    final review = await showModalBottomSheet<_GoalOutcomeReviewInput>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white.withValues(alpha: 0.97),
      builder: (sheetContext) {
        String? outcome = belowMinimum ? GoalOutcomeResult.unclear : null;
        String? burden;
        return StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                4,
                20,
                22 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocaleText.tr(
                      context,
                      en: 'Overall goal summary',
                      zhHans: '目标整体总结',
                      zhHant: '目標整體總結',
                      ja: '目標の全体まとめ',
                    ),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AuroraColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    AppLocaleText.tr(
                      context,
                      en: '$completed completed days · minimum ${experiment.minimumObservationDays} observation days',
                      zhHans:
                          '已完成 $completed 天 · 至少观察 ${experiment.minimumObservationDays} 天再判断',
                      zhHant:
                          '已完成 $completed 天 · 至少觀察 ${experiment.minimumObservationDays} 天再判斷',
                      ja: '$completed 日完了 · 最低 ${experiment.minimumObservationDays} 日観察',
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AuroraColors.muted,
                          height: 1.4,
                        ),
                  ),
                  const SizedBox(height: 16),
                  if (belowMinimum) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AuroraColors.gold.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AuroraColors.gold.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Text(
                        AppLocaleText.tr(
                          context,
                          en: 'This goal has not reached its minimum observation period. The summary can only be saved as “Too early to tell” and will not change its in-progress status.',
                          zhHans: '这个目标还没达到最低观察天数。目前只能总结为“还看不出”，不会改变进行中状态。',
                          zhHant: '這個目標還沒達到最低觀察天數。目前只能總結為「還看不出」，不會改變進行中狀態。',
                          ja: 'この目標は最低観察日数に達していません。現時点では「まだ不明」とだけまとめられ、進行中の状態は変わりません。',
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AuroraColors.ink,
                              height: 1.42,
                            ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _FeedbackChoiceGroup(
                    title: AppLocaleText.tr(
                      context,
                      en: 'What changed?',
                      zhHans: '想观察的变化出现了吗？',
                      zhHant: '想觀察的變化出現了嗎？',
                      ja: '観察した変化はありましたか？',
                    ),
                    value: outcome,
                    options: [
                      if (!belowMinimum) ...[
                        _FeedbackChoice(
                          value: GoalOutcomeResult.improved,
                          label: AppLocaleText.tr(context,
                              en: 'Improved',
                              zhHans: '有改善',
                              zhHant: '有改善',
                              ja: '改善'),
                        ),
                        _FeedbackChoice(
                          value: GoalOutcomeResult.somewhatImproved,
                          label: AppLocaleText.tr(context,
                              en: 'A little',
                              zhHans: '有一点',
                              zhHant: '有一點',
                              ja: '少し'),
                        ),
                        _FeedbackChoice(
                          value: GoalOutcomeResult.noChange,
                          label: AppLocaleText.tr(context,
                              en: 'No change',
                              zhHans: '没变化',
                              zhHant: '沒變化',
                              ja: '変化なし'),
                        ),
                        _FeedbackChoice(
                          value: GoalOutcomeResult.worse,
                          label: AppLocaleText.tr(
                            context,
                            en: 'Worse',
                            zhHans: '变差',
                            zhHant: '變差',
                            ja: '悪化',
                          ),
                        ),
                      ],
                      _FeedbackChoice(
                        value: GoalOutcomeResult.unclear,
                        label: AppLocaleText.tr(context,
                            en: 'Too early to tell',
                            zhHans: '还看不出',
                            zhHant: '還看不出',
                            ja: 'まだ不明'),
                      ),
                    ],
                    onChanged: (value) => setSheetState(() => outcome = value),
                  ),
                  const SizedBox(height: 16),
                  _FeedbackChoiceGroup(
                    title: AppLocaleText.tr(
                      context,
                      en: 'How demanding was this cycle?',
                      zhHans: '这一轮做起来费力吗？',
                      zhHant: '這一輪做起來費力嗎？',
                      ja: '今回の負担は？',
                    ),
                    value: burden,
                    options: [
                      _FeedbackChoice(
                        value: EvaluationEffort.easy,
                        label: AppLocaleText.tr(context,
                            en: 'Easy', zhHans: '轻松', zhHant: '輕鬆', ja: '楽'),
                      ),
                      _FeedbackChoice(
                        value: EvaluationEffort.acceptable,
                        label: AppLocaleText.tr(context,
                            en: 'Acceptable',
                            zhHans: '可接受',
                            zhHant: '可接受',
                            ja: '許容範囲'),
                      ),
                      _FeedbackChoice(
                        value: EvaluationEffort.tooDifficult,
                        label: AppLocaleText.tr(context,
                            en: 'Too demanding',
                            zhHans: '太费力',
                            zhHant: '太費力',
                            ja: '負担が大きい'),
                      ),
                    ],
                    onChanged: (value) => setSheetState(() => burden = value),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: noteController,
                    maxLength: 240,
                    decoration: InputDecoration(
                      labelText: AppLocaleText.tr(
                        context,
                        en: 'Add a note (optional)',
                        zhHans: '补一句（可选）',
                        zhHant: '補一句（可選）',
                        ja: 'ひと言追加（任意）',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      key: const ValueKey('save-goal-outcome-review'),
                      onPressed: outcome == null || burden == null
                          ? null
                          : () => Navigator.of(sheetContext).pop(
                                _GoalOutcomeReviewInput(
                                  outcome: outcome!,
                                  burden: burden!,
                                  note: noteController.text.trim().isEmpty
                                      ? null
                                      : noteController.text.trim(),
                                ),
                              ),
                      child: Text(
                        AppLocaleText.tr(
                          context,
                          en: 'Save overall summary',
                          zhHans: '保存整体总结',
                          zhHant: '儲存整體總結',
                          ja: '全体まとめを保存',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    noteController.dispose();
    if (review == null || !context.mounted) return;
    final deps = context.read<AppDependencies>();
    try {
      await deps.localLifeExperimentRepository.recordWholeRoundReview(
        experimentId: experiment.id,
        outcomeResult: review.outcome,
        burden: review.burden,
        reviewNote: review.note,
      );
    } on StateError {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocaleText.tr(
              context,
              en: 'This summary could not be saved. Please refresh and try again.',
              zhHans: '这次总结暂时无法保存，请刷新后再试。',
              zhHant: '這次總結暫時無法儲存，請重新整理後再試。',
              ja: '今回のまとめを保存できませんでした。更新してからもう一度お試しください。',
            ),
          ),
        ),
      );
      return;
    }
    await _loadExperimentHistory(reset: true);
  }

  Future<void> _adoptConsideringSmallTry(
    MicroActionCandidateModel candidate,
  ) async {
    await context
        .read<AppDependencies>()
        .localCandidatePlanningRepository
        .adoptMicroActionCandidates([candidate.id]);
    if (!mounted) return;
    setState(() => _selectedSmallTryCandidate = null);
    await _loadExperimentHistory(reset: true);
    if (!mounted) return;
    _showExperimentHint(
      context,
      AppLocaleText.tr(
        context,
        en: 'Spot Try adopted. Progress starts from its planned day.',
        zhHans: '已采纳小实验，进度从计划开始日计算。',
        zhHant: '已採納小實驗，進度從計劃開始日計算。',
        ja: '小実験を採用しました。進捗は予定開始日から数えます。',
      ),
    );
  }

  Future<void> _adoptConsideringGoal(
    ExperimentCandidateRecord candidate,
  ) async {
    await context
        .read<AppDependencies>()
        .localCandidatePlanningRepository
        .adoptExperimentCandidates([candidate.id]);
    if (!mounted) return;
    setState(() => _selectedGoalCandidate = null);
    await _loadExperimentHistory(reset: true);
    if (!mounted) return;
    _showExperimentHint(
      context,
      AppLocaleText.tr(
        context,
        en: 'Goal adopted. It will enter Today on its planned start day.',
        zhHans: '已采纳目标，将在计划开始日进入今天页面。',
        zhHant: '已採納目標，將在計劃開始日進入今天頁面。',
        ja: '目標を採用しました。予定開始日に「今日」へ表示されます。',
      ),
    );
  }

  void _syncControllers(
    _NextExperimentDetail detail,
    LifeExperimentModel? experiment, {
    bool force = false,
  }) {
    final experimentId = experiment?.id ?? 'fallback';
    if (!force && (_isEditing || _loadedExperimentId == experimentId)) return;
    _loadedExperimentId = experimentId;
    _titleController.text = detail.title;
    _actionController.text = detail.description;
    _reasonController.text = detail.reason;
    _editTryOptions = detail.options.isEmpty
        ? [
            _TryOption(
              icon: _NextExperimentDetail._iconForOption(detail.description),
              label: detail.description,
              color: _NextExperimentDetail._colorForOption(detail.description),
            ),
          ]
        : detail.options;
  }

  Future<void> _saveNextExperiment(
    BuildContext context,
    WeeklyViewModel vm,
  ) async {
    await vm.saveExperiment();
    if (!context.mounted) return;
    _showExperimentHint(
      context,
      AppLocaleText.tr(
        context,
        en: 'This goal has been added for next week.',
        zhHans: '下周目标已加入。',
        zhHant: '下週目標已加入。',
        ja: '来週の目標に追加しました。',
      ),
    );
  }

  Future<void> _saveExperimentEdits(
    BuildContext context,
    WeeklyViewModel vm,
  ) async {
    final title = _titleController.text.trim();
    final action = _actionController.text.trim();
    final reason = _reasonController.text.trim();
    if (title.isEmpty || action.isEmpty) {
      _showExperimentHint(
        context,
        AppLocaleText.tr(
          context,
          en: 'Please keep a goal name and its daily practice.',
          zhHans: '请至少保留目标名称和每日做法。',
          zhHant: '請至少保留目標名稱和每日做法。',
          ja: '目標名と毎日の取り組みを残してください。',
        ),
      );
      return;
    }
    await vm.updateExperimentDetails(
      title: title,
      hypothesis: reason,
      suggestedAction: action,
    );
    if (!context.mounted) return;
    setState(() => _isEditing = false);
    _showExperimentHint(
      context,
      AppLocaleText.tr(
        context,
        en: 'Goal changes are saved.',
        zhHans: '目标修改已保存。',
        zhHant: '目標修改已保存。',
        ja: '目標の変更を保存しました。',
      ),
    );
  }
}

void _showExperimentHint(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
}

class _GoalArchiveArtifacts {
  final Map<String, List<LifeExperimentFeedbackModel>> feedbacks;
  final Map<String, List<RecentSignalModel>> signals;
  final Map<String, _ExperimentRollup> rollups;
  final Map<String, List<_ExperimentLifecycleEvent>> lifecycle;

  const _GoalArchiveArtifacts({
    this.feedbacks = const {},
    this.signals = const {},
    this.rollups = const {},
    this.lifecycle = const {},
  });
}

enum _ExperimentFilter { active, adjusted, completed, paused, stopped, all }

enum _ExperimentDetailTab { overview, feedback, conditions, notes }

enum _ExperimentLifecycleStage { considering, active, completed }

_ExperimentLifecycleStage _smallTryLifecycleStage(MicroActionModel action) {
  final status = action.status.trim().toLowerCase();
  if (status.contains('complete') ||
      status.contains('done') ||
      status.contains('finish') ||
      status.contains('stop') ||
      status.contains('archive')) {
    return _ExperimentLifecycleStage.completed;
  }
  if (status.contains('plan') ||
      status.contains('pause') ||
      status.contains('consider') ||
      status.contains('observ')) {
    return _ExperimentLifecycleStage.considering;
  }
  return _ExperimentLifecycleStage.active;
}

_ExperimentLifecycleStage _experimentLifecycleStage(
  LifeExperimentModel experiment,
  _ExperimentRollup? rollup,
) {
  final group = _experimentStatusGroup(experiment, rollup);
  if (_isUpcomingExperiment(experiment) || group == _ExperimentFilter.paused) {
    return _ExperimentLifecycleStage.considering;
  }
  if (group == _ExperimentFilter.completed ||
      group == _ExperimentFilter.stopped) {
    return _ExperimentLifecycleStage.completed;
  }
  return _ExperimentLifecycleStage.active;
}

String _lifecycleStageLabel(
  BuildContext context,
  _ExperimentLifecycleStage stage,
) {
  return switch (stage) {
    _ExperimentLifecycleStage.considering => AppLocaleText.tr(
        context,
        en: 'Considering / observing',
        zhHans: '考虑 / 观察',
        zhHant: '考慮 / 觀察',
        ja: '検討・観察中',
      ),
    _ExperimentLifecycleStage.active => AppLocaleText.tr(
        context,
        en: 'In progress',
        zhHans: '进行中',
        zhHant: '進行中',
        ja: '進行中',
      ),
    _ExperimentLifecycleStage.completed => AppLocaleText.tr(
        context,
        en: 'Completed',
        zhHans: '已完成',
        zhHant: '已完成',
        ja: '完了',
      ),
  };
}

Color _lifecycleStageColor(_ExperimentLifecycleStage stage) {
  return switch (stage) {
    _ExperimentLifecycleStage.considering => AuroraColors.gold,
    _ExperimentLifecycleStage.active => AuroraColors.purple,
    _ExperimentLifecycleStage.completed => AuroraColors.mint,
  };
}

IconData _lifecycleStageIcon(_ExperimentLifecycleStage stage) {
  return switch (stage) {
    _ExperimentLifecycleStage.considering => Icons.visibility_outlined,
    _ExperimentLifecycleStage.active => Icons.play_arrow_rounded,
    _ExperimentLifecycleStage.completed => Icons.check_rounded,
  };
}

String _filterLabel(BuildContext context, _ExperimentFilter filter) {
  switch (filter) {
    case _ExperimentFilter.all:
      return AppLocaleText.tr(
        context,
        en: 'All',
        zhHans: '全部',
        zhHant: '全部',
        ja: 'すべて',
      );
    case _ExperimentFilter.active:
      return AppLocaleText.tr(
        context,
        en: 'Active',
        zhHans: '进行中',
        zhHant: '進行中',
        ja: '進行中',
      );
    case _ExperimentFilter.adjusted:
      return AppLocaleText.tr(
        context,
        en: 'Adjusted',
        zhHans: '已调整',
        zhHant: '已調整',
        ja: '調整済み',
      );
    case _ExperimentFilter.completed:
      return AppLocaleText.tr(
        context,
        en: 'Completed',
        zhHans: '已完成',
        zhHant: '已完成',
        ja: '完了',
      );
    case _ExperimentFilter.paused:
      return AppLocaleText.tr(
        context,
        en: 'Paused',
        zhHans: '暂停',
        zhHant: '暫停',
        ja: '一時停止',
      );
    case _ExperimentFilter.stopped:
      return AppLocaleText.tr(
        context,
        en: 'Stopped',
        zhHans: '已停止',
        zhHant: '已停止',
        ja: '停止',
      );
  }
}

IconData _filterIcon(_ExperimentFilter filter) {
  switch (filter) {
    case _ExperimentFilter.all:
      return Icons.auto_awesome_rounded;
    case _ExperimentFilter.active:
      return Icons.hourglass_bottom_rounded;
    case _ExperimentFilter.adjusted:
      return Icons.tune_rounded;
    case _ExperimentFilter.completed:
      return Icons.check_circle_outline_rounded;
    case _ExperimentFilter.paused:
      return Icons.pause_circle_outline_rounded;
    case _ExperimentFilter.stopped:
      return Icons.archive_outlined;
  }
}

_ExperimentFilter _experimentStatusGroup(
  LifeExperimentModel experiment,
  _ExperimentRollup? rollup,
) {
  final status = (rollup?.currentStatus ?? experiment.status).toLowerCase();
  if (status.contains('pause')) return _ExperimentFilter.paused;
  if (status.contains('stop') ||
      status.contains('end') ||
      status.contains('archive') ||
      status.contains('skip') ||
      status.contains('dismiss')) {
    return _ExperimentFilter.stopped;
  }
  if (status.contains('complete') || status.contains('finished')) {
    return _ExperimentFilter.completed;
  }
  if (status.contains('adjust') || (rollup?.adjustedCount ?? 0) > 0) {
    return _ExperimentFilter.adjusted;
  }
  return _ExperimentFilter.active;
}

bool _isAdoptedFormalExperiment(LifeExperimentModel experiment) {
  final status = experiment.status.trim().toLowerCase();
  return status.isNotEmpty &&
      !status.contains('suggest') &&
      !status.contains('candidate') &&
      !status.contains('generated') &&
      !status.contains('gated') &&
      !status.contains('dismiss');
}

bool _isUpcomingExperiment(LifeExperimentModel experiment) {
  final start = _parseExperimentDate(experiment.progressStartDate ?? '') ??
      _parseExperimentDate(experiment.sourceWeekStart);
  if (start == null) return false;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final localStart = DateTime(start.year, start.month, start.day);
  return localStart.isAfter(today);
}

DateTime? _parseExperimentDate(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  return DateTime.tryParse(trimmed);
}

DateTime _sortDate(LifeExperimentModel experiment) {
  return experiment.updatedAt ??
      experiment.createdAt ??
      _parseExperimentDate(experiment.sourceWeekEnd) ??
      _parseExperimentDate(experiment.sourceWeekStart) ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime _startDate(LifeExperimentModel experiment) {
  return _parseExperimentDate(experiment.sourceWeekStart) ??
      experiment.createdAt ??
      _sortDate(experiment);
}

DateTime _endDate(LifeExperimentModel experiment) {
  final end = _sortDate(experiment);
  final start = _startDate(experiment);
  return end.isBefore(start) ? start : end;
}

String _dateLabel(DateTime date) => '${date.month}/${date.day}';

int _triedDays(LifeExperimentModel experiment) {
  final start = _startDate(experiment);
  final end = _endDate(experiment);
  final dateDays = end.difference(start).inDays + 1;
  final linkedDays = experiment.linkedSignalCardIds.length;
  final tried = linkedDays > dateDays ? linkedDays : dateDays;
  return tried < 0 ? 0 : tried;
}

int _actualTriedCount(
  LifeExperimentModel _,
  _ExperimentEvidence evidence,
  _ExperimentRollup? rollup,
) {
  if (rollup != null) return rollup.triedCount;
  if (evidence.feedbacks.isNotEmpty) return evidence.triedDays;
  return 0;
}

_ExperimentSummaryMetrics _summaryMetrics(
  List<LifeExperimentModel> experiments,
  Map<String, List<LifeExperimentFeedbackModel>> feedbacksByExperiment,
  Map<String, _ExperimentRollup> rollupsByExperiment,
) {
  var active = 0;
  var effective = 0;
  var ended = 0;
  var tried = 0;
  var helpful = 0;
  var adjusted = 0;
  var skipped = 0;
  for (final experiment in experiments) {
    final rollup = rollupsByExperiment[experiment.id];
    final feedbacks = feedbacksByExperiment[experiment.id] ?? const [];
    final status = (rollup?.currentStatus ?? experiment.status).toLowerCase();
    final isEnded = status.contains('end') ||
        status.contains('archive') ||
        status.contains('skip') ||
        status.contains('complete');
    if (isEnded) {
      ended += 1;
    } else {
      active += 1;
    }
    final hasHelpfulFeedback = feedbacks.any((feedback) {
      final status = feedback.completionStatus.toLowerCase();
      final text = (feedback.feedbackText ?? '').toLowerCase();
      return status.contains('help') ||
          status.contains('adjust') ||
          text.contains('help') ||
          text.contains('有帮助') ||
          text.contains('有效');
    });
    final rollupHelpful = rollup?.helpfulCount ?? 0;
    if (rollupHelpful > 0 ||
        hasHelpfulFeedback ||
        status.contains('effective')) {
      effective += 1;
    }
    tried += rollup?.triedCount ??
        (feedbacks.isNotEmpty
            ? feedbacks
                .where((feedback) =>
                    _feedbackCountsAsCompleted(feedback.completionStatus))
                .map((feedback) => feedback.localDate)
                .toSet()
                .length
            : 0);
    helpful += rollupHelpful;
    adjusted += rollup?.adjustedCount ??
        feedbacks
            .where((feedback) =>
                feedback.completionStatus.toLowerCase().contains('adjust'))
            .length;
    skipped += rollup?.skippedCount ??
        feedbacks
            .where((feedback) =>
                !_feedbackCountsAsCompleted(feedback.completionStatus))
            .length;
  }
  return _ExperimentSummaryMetrics(
    total: experiments.length,
    active: active,
    effective: effective,
    ended: ended,
    tried: tried,
    helpful: helpful,
    adjusted: adjusted,
    skipped: skipped,
  );
}

double _helpfulnessScore(LifeExperimentModel experiment) {
  final status = experiment.status.toLowerCase();
  final text = [
    experiment.title,
    experiment.hypothesis,
    experiment.suggestedAction,
    experiment.feedbackText ?? '',
    status,
  ].join(' ').toLowerCase();
  var score = 3.2;
  if (status.contains('effective') ||
      status.contains('complete') ||
      text.contains('有效') ||
      text.contains('有帮助') ||
      text.contains('help')) {
    score += 1.2;
  }
  if (status.contains('saved') || status.contains('active')) score += 0.4;
  if (status.contains('skip') ||
      status.contains('archive') ||
      text.contains('太难') ||
      text.contains('没帮助') ||
      text.contains('hard')) {
    score -= 0.9;
  }
  score += (experiment.linkedSignalCardIds.length.clamp(0, 4) * 0.15);
  return score.clamp(1.0, 5.0);
}

List<_TrendPoint> _trendPoints(
  LifeExperimentModel experiment,
  _ExperimentEvidence evidence,
) {
  if (evidence.feedbacks.isNotEmpty) {
    return evidence.feedbacks.map((feedback) {
      return _TrendPoint(
        label: _dateLabel(feedback.feedbackDate),
        value: evidence.valueForFeedback(feedback),
        date: feedback.feedbackDate,
      );
    }).toList();
  }

  final start = _startDate(experiment);
  final end = _endDate(experiment);
  final totalDays = math.max(1, end.difference(start).inDays + 1);
  final count = totalDays <= 7 ? totalDays : 7;
  final base = evidence.signalBackedValue;
  return List.generate(count, (index) {
    final offset =
        count == 1 ? 0 : ((totalDays - 1) * index / (count - 1)).round();
    final date = start.add(Duration(days: offset));
    final wave = math.sin(index * 1.35) * 0.35;
    final lift = count == 1 ? 0.0 : index / (count - 1) * 0.35;
    return _TrendPoint(
      label: _dateLabel(date),
      value: (base - 0.25 + wave + lift).clamp(1.0, 5.0),
      date: date,
    );
  });
}

String _statusLabel(
  BuildContext context,
  LifeExperimentModel experiment, {
  _ExperimentRollup? rollup,
}) {
  final group = _experimentStatusGroup(experiment, rollup);
  if (group == _ExperimentFilter.active &&
      experiment.status.toLowerCase().contains('effective')) {
    return AppLocaleText.tr(
      context,
      en: 'Helpful',
      zhHans: '有帮助',
      zhHant: '有幫助',
      ja: '役立つ',
    );
  }
  return _filterLabel(context, group);
}

String _lineageHint(
  BuildContext context,
  _ExperimentRollup? rollup,
  List<_ExperimentLifecycleEvent> lifecycle,
) {
  final eventTypes = lifecycle.map((event) => event.eventType).toSet();
  if (eventTypes.contains('appended_to_current_week') ||
      eventTypes.contains('appended_as')) {
    return AppLocaleText.tr(
      context,
      en: 'Append history visible',
      zhHans: '可见追加历史',
      zhHant: '可見追加歷史',
      ja: '追加履歴あり',
    );
  }
  if (eventTypes.contains('continued_next_week') ||
      eventTypes.contains('continued_as') ||
      rollup?.hasLineage == true) {
    return AppLocaleText.tr(
      context,
      en: 'Continued from earlier goal',
      zhHans: '可见延续关系',
      zhHant: '可見延續關係',
      ja: '継続関係あり',
    );
  }
  return AppLocaleText.tr(
    context,
    en: '${lifecycle.length} timeline event(s)',
    zhHans: '${lifecycle.length} 个时间线事件',
    zhHant: '${lifecycle.length} 個時間線事件',
    ja: '${lifecycle.length} 件のタイムライン',
  );
}

String _rollupEffectSummary(
  BuildContext context,
  LifeExperimentModel experiment,
  _ExperimentRollup? rollup,
) {
  if (rollup != null) {
    if (rollup.helpfulCount > 0) {
      return AppLocaleText.tr(
        context,
        en: '${rollup.helpfulCount} helpful result(s) appeared across ${rollup.triedCount} tried attempt(s). Keep the useful part small and repeatable.',
        zhHans:
            '${rollup.triedCount} 次尝试里有 ${rollup.helpfulCount} 次有效。可以先保留有效部分，让它保持小而可重复。',
        zhHant:
            '${rollup.triedCount} 次嘗試裡有 ${rollup.helpfulCount} 次有效。可以先保留有效部分，讓它保持小而可重複。',
        ja: '${rollup.triedCount} 回中 ${rollup.helpfulCount} 回が有効でした。有効な部分を小さく保ちます。',
      );
    }
    if (rollup.adjustedCount > 0) {
      return AppLocaleText.tr(
        context,
        en: 'This goal has been adjusted ${rollup.adjustedCount} time(s), so the current version should stay lighter.',
        zhHans: '这个目标已经调整 ${rollup.adjustedCount} 次，当前版本更适合继续调轻。',
        zhHant: '這個目標已經調整 ${rollup.adjustedCount} 次，目前版本更適合繼續調輕。',
        ja: '${rollup.adjustedCount} 回調整されているため、今は軽めが合いそうです。',
      );
    }
    if (rollup.skippedCount > 0 && rollup.triedCount == 0) {
      return AppLocaleText.tr(
        context,
        en: 'This was marked as not suitable before being tried. The next version can be smaller or timed differently.',
        zhHans: '它在真正尝试前被标记为不适合。下一个版本可以更小，或换一个时间点。',
        zhHant: '它在真正嘗試前被標記為不適合。下一個版本可以更小，或換一個時間點。',
        ja: '試す前に合わないと記録されました。次は小さくするか時間を変えます。',
      );
    }
    return AppLocaleText.tr(
      context,
      en: 'There is not enough helpful feedback yet, so keep comparing this across real attempts.',
      zhHans: '目前有效反馈还不多，先继续按真实尝试比较。',
      zhHant: '目前有效回饋還不多，先繼續按真實嘗試比較。',
      ja: '有効な反応はまだ少ないため、実際の試行で比べます。',
    );
  }
  return experiment.feedbackText?.trim().isNotEmpty == true
      ? experiment.feedbackText!.trim()
      : experiment.hypothesis;
}

IconData _lifecycleIcon(String eventType) {
  switch (eventType) {
    case 'created':
      return Icons.add_circle_outline_rounded;
    case 'feedback_recorded':
      return Icons.rate_review_rounded;
    case 'continued_next_week':
    case 'continued_as':
      return Icons.repeat_rounded;
    case 'appended_to_current_week':
    case 'appended_as':
      return Icons.playlist_add_rounded;
    case 'status_changed':
      return Icons.change_circle_outlined;
    default:
      return Icons.auto_awesome_rounded;
  }
}

Color _lifecycleColor(String eventType) {
  switch (eventType) {
    case 'feedback_recorded':
      return AuroraColors.mint;
    case 'continued_next_week':
    case 'continued_as':
      return AuroraColors.blue;
    case 'appended_to_current_week':
    case 'appended_as':
      return AuroraColors.orange;
    case 'status_changed':
      return AuroraColors.purple;
    default:
      return AuroraColors.muted;
  }
}

String _lifecycleLabel(
  BuildContext context,
  _ExperimentLifecycleEvent event,
) {
  switch (event.eventType) {
    case 'created':
      return AppLocaleText.tr(
        context,
        en: 'Created',
        zhHans: '创建',
        zhHant: '建立',
        ja: '作成',
      );
    case 'feedback_recorded':
      return AppLocaleText.tr(
        context,
        en: 'Feedback recorded',
        zhHans: '记录反馈',
        zhHant: '記錄回饋',
        ja: '反応を記録',
      );
    case 'continued_next_week':
    case 'continued_as':
      return AppLocaleText.tr(
        context,
        en: 'Continued',
        zhHans: '延续',
        zhHant: '延續',
        ja: '継続',
      );
    case 'appended_to_current_week':
    case 'appended_as':
      return AppLocaleText.tr(
        context,
        en: 'Appended',
        zhHans: '追加',
        zhHant: '追加',
        ja: '追加',
      );
    case 'status_changed':
      return AppLocaleText.tr(
        context,
        en: 'Status changed',
        zhHans: '状态变化',
        zhHant: '狀態變化',
        ja: '状態変更',
      );
    default:
      return event.eventType.replaceAll('_', ' ');
  }
}

String _eventMeta(BuildContext context, _ExperimentLifecycleEvent event) {
  final date =
      event.eventDate == null ? event.localDate : _dateLabel(event.eventDate!);
  final status = event.statusTo?.trim();
  final source = event.sourceType?.trim();
  return [
    if (date.trim().isNotEmpty) date,
    if (status != null && status.isNotEmpty)
      _lifecycleStatusLabel(context, status),
    if (source != null && source.isNotEmpty)
      _lifecycleSourceLabel(context, source),
  ].join(' · ');
}

String _lifecycleStatusLabel(BuildContext context, String raw) {
  return switch (raw.trim().toLowerCase()) {
    'active' || 'accepted' || 'saved' || 'in_progress' => AppLocaleText.tr(
        context,
        en: 'Active',
        zhHans: '进行中',
        zhHant: '進行中',
        ja: '進行中',
      ),
    'adjusted' => AppLocaleText.tr(
        context,
        en: 'Adjusted',
        zhHans: '已调整',
        zhHant: '已調整',
        ja: '調整済み',
      ),
    'completed' => AppLocaleText.tr(
        context,
        en: 'Completed',
        zhHans: '已完成',
        zhHant: '已完成',
        ja: '完了',
      ),
    'paused' => AppLocaleText.tr(
        context,
        en: 'Paused',
        zhHans: '暂停',
        zhHant: '暫停',
        ja: '一時停止',
      ),
    'stopped' => AppLocaleText.tr(
        context,
        en: 'Stopped',
        zhHans: '已停止',
        zhHant: '已停止',
        ja: '停止',
      ),
    _ => raw.replaceAll('_', ' '),
  };
}

String _lifecycleSourceLabel(BuildContext context, String raw) {
  return switch (raw.trim().toLowerCase()) {
    'life_experiment' || 'lifeexperiment' => AppLocaleText.tr(
        context,
        en: 'Life Experiment',
        zhHans: '生活小实验',
        zhHant: '生活小實驗',
        ja: '生活実験',
      ),
    'weekly' || 'weekly_review' => AppLocaleText.tr(
        context,
        en: 'Weekly Review',
        zhHans: '每周复盘',
        zhHant: '每週回顧',
        ja: '週間レビュー',
      ),
    _ => raw.replaceAll('_', ' '),
  };
}

Color _statusColor(LifeExperimentModel experiment) {
  final status = experiment.status.toLowerCase();
  if (status.contains('complete') || status.contains('finished')) {
    return const Color(0xFF35C58A);
  }
  if (status.contains('pause')) return AuroraColors.orange;
  if (status.contains('adjust')) return AuroraColors.purple;
  if (status.contains('end') ||
      status.contains('archive') ||
      status.contains('stop')) {
    return AuroraColors.muted;
  }
  if (status.contains('skip')) return AuroraColors.orange;
  if (status.contains('effective')) return AuroraColors.mint;
  return AuroraColors.blue;
}

IconData _experimentIcon(LifeExperimentModel experiment) {
  final text =
      '${experiment.title} ${experiment.suggestedAction}'.toLowerCase();
  if (text.contains('walk') || text.contains('散步') || text.contains('走')) {
    return Icons.directions_walk_rounded;
  }
  if (text.contains('phone') || text.contains('手机')) {
    return Icons.phone_iphone_rounded;
  }
  if (text.contains('write') || text.contains('写') || text.contains('记录')) {
    return Icons.edit_note_rounded;
  }
  if (text.contains('sleep') || text.contains('睡') || text.contains('晚')) {
    return Icons.nights_stay_rounded;
  }
  if (text.contains('breath') || text.contains('呼吸')) {
    return Icons.self_improvement_rounded;
  }
  return Icons.spa_rounded;
}

Color _experimentColor(LifeExperimentModel experiment) {
  final icon = _experimentIcon(experiment);
  if (icon == Icons.directions_walk_rounded) return AuroraColors.purple;
  if (icon == Icons.phone_iphone_rounded) return AuroraColors.blue;
  if (icon == Icons.edit_note_rounded) return AuroraColors.orange;
  if (icon == Icons.nights_stay_rounded) return AuroraColors.blue;
  if (icon == Icons.self_improvement_rounded) return AuroraColors.blue;
  return AuroraColors.mint;
}

List<_KeywordData> _keywordsFor(
  BuildContext context,
  LifeExperimentModel experiment,
) {
  final source = [
    experiment.title,
    experiment.hypothesis,
    experiment.suggestedAction,
    experiment.feedbackText ?? '',
  ].join(' ');
  final keywords = <_KeywordData>[];
  void add(String text, IconData icon, Color color) {
    if (keywords.any((item) => item.label == text)) return;
    keywords.add(_KeywordData(text, icon, color));
  }

  if (source.contains('睡') || source.toLowerCase().contains('sleep')) {
    add(
      AppLocaleText.tr(
        context,
        en: 'Sleep improved',
        zhHans: '睡眠改善',
        zhHant: '睡眠改善',
        ja: '睡眠の改善',
      ),
      Icons.nights_stay_rounded,
      AuroraColors.blue,
    );
  }
  if (source.contains('放松') ||
      source.contains('恢复') ||
      source.toLowerCase().contains('relax')) {
    add(
      AppLocaleText.tr(
        context,
        en: 'Relaxation',
        zhHans: '更放松',
        zhHant: '更放鬆',
        ja: 'リラックス',
      ),
      Icons.spa_rounded,
      AuroraColors.mint,
    );
  }
  if (source.contains('情绪') || source.toLowerCase().contains('mood')) {
    add(
      AppLocaleText.tr(
        context,
        en: 'Mood steadier',
        zhHans: '情绪更稳定',
        zhHant: '情緒更穩定',
        ja: '気分が安定',
      ),
      Icons.favorite_rounded,
      AuroraColors.gold,
    );
  }
  if (source.contains('压力') || source.toLowerCase().contains('pressure')) {
    add(
      AppLocaleText.tr(
        context,
        en: 'Pressure lower',
        zhHans: '负担降低',
        zhHant: '負擔降低',
        ja: '負担が軽減',
      ),
      Icons.cloud_queue_rounded,
      AuroraColors.orange,
    );
  }
  if (source.contains('记录') || source.toLowerCase().contains('record')) {
    add(
      AppLocaleText.tr(
        context,
        en: 'Observation',
        zhHans: '观察记录',
        zhHant: '觀察記錄',
        ja: '観察記録',
      ),
      Icons.edit_rounded,
      AuroraColors.blue,
    );
  }
  if (keywords.isEmpty) {
    add(
      AppLocaleText.tr(
        context,
        en: 'Rhythm clearer',
        zhHans: '节奏更清晰',
        zhHant: '節奏更清晰',
        ja: 'リズムが明確',
      ),
      Icons.auto_awesome_rounded,
      AuroraColors.purple,
    );
    add(
      AppLocaleText.tr(
        context,
        en: 'Easier to start',
        zhHans: '更容易开始',
        zhHant: '更容易開始',
        ja: '始めやすい',
      ),
      Icons.trending_up_rounded,
      AuroraColors.mint,
    );
  }
  return keywords.take(4).toList();
}

class _TrendPoint {
  final String label;
  final double value;
  final DateTime date;

  const _TrendPoint({
    required this.label,
    required this.value,
    required this.date,
  });
}

class _KeywordData {
  final String label;
  final IconData icon;
  final Color color;

  const _KeywordData(this.label, this.icon, this.color);
}

class _ExperimentSummaryMetrics {
  final int total;
  final int active;
  final int effective;
  final int ended;
  final int tried;
  final int helpful;
  final int adjusted;
  final int skipped;

  const _ExperimentSummaryMetrics({
    required this.total,
    required this.active,
    required this.effective,
    required this.ended,
    required this.tried,
    required this.helpful,
    required this.adjusted,
    required this.skipped,
  });
}

class _ExperimentEvidence {
  final List<LifeExperimentFeedbackModel> feedbacks;
  final List<RecentSignalModel> signals;

  const _ExperimentEvidence({
    required this.feedbacks,
    required this.signals,
  });

  bool get hasHelpfulFeedback {
    return feedbacks.any((feedback) {
      final status = feedback.completionStatus.toLowerCase();
      final text = (feedback.feedbackText ?? '').toLowerCase();
      return status.contains('help') ||
          status.contains('adjust') ||
          text.contains('help') ||
          text.contains('有帮助') ||
          text.contains('有效');
    });
  }

  int get evidenceCount => feedbacks.length + signals.length;

  int get triedDays {
    final days = <String>{};
    for (final feedback in feedbacks) {
      if (_feedbackCountsAsCompleted(feedback.completionStatus)) {
        days.add(feedback.localDate);
      }
    }
    return days.length;
  }

  double get signalBackedValue {
    if (feedbacks.isEmpty && signals.isEmpty) return 3.0;
    var value = 3.0;
    if (hasHelpfulFeedback) value += 0.8;
    if (signals.any((signal) => (signal.positiveSignal ?? '').isNotEmpty)) {
      value += 0.35;
    }
    if (feedbacks.any((feedback) =>
        feedback.completionStatus.toLowerCase().contains('hard') ||
        (feedback.feedbackText ?? '').contains('太难'))) {
      value -= 0.45;
    }
    return value.clamp(1.0, 5.0);
  }

  double valueForFeedback(LifeExperimentFeedbackModel feedback) {
    final score = feedback.helpfulnessScore;
    if (score != null) return score.clamp(1, 5).toDouble();
    final status = feedback.completionStatus.toLowerCase();
    final text = (feedback.feedbackText ?? '').toLowerCase();
    if (status.contains('help') ||
        status.contains('adjust') ||
        text.contains('help') ||
        text.contains('有帮助')) {
      return 4.2;
    }
    if (status.contains('hard') ||
        status.contains('not') ||
        text.contains('hard') ||
        text.contains('太难')) {
      return 2.4;
    }
    return 3.4;
  }

  List<_KeywordData> keywordsFor(
    BuildContext context,
    LifeExperimentModel experiment,
  ) {
    final counts = <String, int>{};
    void add(String? value) {
      final normalized = value?.trim();
      if (normalized == null || normalized.isEmpty) return;
      counts[normalized] = (counts[normalized] ?? 0) + 1;
    }

    for (final signal in signals) {
      add(signal.scene);
      add(signal.friction);
      add(signal.positiveSignal);
      add(signal.energyLoad);
      for (final tag in signal.sceneTags) {
        add(tag);
      }
    }
    for (final feedback in feedbacks) {
      for (final tag in feedback.conditionTags) {
        add(tag);
      }
      add(feedback.timeSlot);
      add(feedback.completionStatus);
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final keywords = sorted.take(4).map((entry) {
      final text = entry.key;
      return _KeywordData(
        _readableEvidenceLabel(context, text),
        _evidenceIcon(text),
        _evidenceColor(text),
      );
    }).toList();
    return keywords.isNotEmpty ? keywords : _keywordsFor(context, experiment);
  }

  List<_KeywordData> conditionKeywords(BuildContext context) {
    final source = <_KeywordData>[];
    final slots =
        feedbacks.map((f) => f.timeSlot ?? '').where((e) => e.isNotEmpty);
    final scenes = signals
        .expand((s) => [s.scene, ...s.sceneTags])
        .whereType<String>()
        .where((e) => e.trim().isNotEmpty);
    for (final value in [...slots, ...scenes]) {
      if (source.any(
          (item) => item.label == _readableEvidenceLabel(context, value))) {
        continue;
      }
      source.add(_KeywordData(
        _readableEvidenceLabel(context, value),
        _evidenceIcon(value),
        _evidenceColor(value),
      ));
      if (source.length >= 4) break;
    }
    if (source.isEmpty) {
      source.addAll([
        _KeywordData(
          AppLocaleText.tr(
            context,
            en: 'More feedback needed',
            zhHans: '还需要更多反馈',
            zhHant: '還需要更多回饋',
            ja: 'もう少し反応が必要',
          ),
          Icons.edit_note_rounded,
          AuroraColors.muted,
        ),
      ]);
    }
    return source;
  }

  List<_DurationBucket> durationBuckets(BuildContext context) {
    final durations = feedbacks
        .map((feedback) => feedback.durationMinutes)
        .whereType<int>()
        .where((value) => value > 0)
        .toList();
    if (durations.isEmpty) {
      return [
        _DurationBucket(
          AppLocaleText.tr(
            context,
            en: 'No duration yet',
            zhHans: '还没有时长记录',
            zhHant: '還沒有時長記錄',
            ja: '時間記録はまだありません',
          ),
          1,
          AuroraColors.muted,
        ),
      ];
    }
    final underTen = durations.where((value) => value <= 10).length;
    final tenToTwenty =
        durations.where((value) => value > 10 && value <= 20).length;
    final overTwenty = durations.where((value) => value > 20).length;
    return [
      _DurationBucket(
        AppLocaleText.tr(
          context,
          en: 'Under 10 min',
          zhHans: '10 分钟以内',
          zhHant: '10 分鐘以內',
          ja: '10分以内',
        ),
        underTen,
        AuroraColors.purple,
      ),
      _DurationBucket(
        AppLocaleText.tr(
          context,
          en: '10–20 min',
          zhHans: '10–20 分钟',
          zhHant: '10–20 分鐘',
          ja: '10〜20分',
        ),
        tenToTwenty,
        AuroraColors.orange,
      ),
      _DurationBucket(
        AppLocaleText.tr(
          context,
          en: 'Over 20 min',
          zhHans: '20 分钟以上',
          zhHant: '20 分鐘以上',
          ja: '20分以上',
        ),
        overTwenty,
        AuroraColors.mint,
      ),
    ].where((bucket) => bucket.count > 0).toList();
  }

  List<String> preferenceLines(BuildContext context) {
    final lines = <String>[];
    final hasRecovery = signals.any((signal) =>
        (signal.positiveSignal ?? '').trim().isNotEmpty ||
        (signal.energyLoad ?? '').contains('recover') ||
        (signal.energyLoad ?? '').contains('restore'));
    final hasShort = feedbacks.any((feedback) =>
        feedback.durationMinutes != null && feedback.durationMinutes! <= 10);
    if (hasRecovery) {
      lines.add(AppLocaleText.tr(
        context,
        en: 'Recovery-linked moments are more likely to support this goal.',
        zhHans: '和恢复感相连的时刻，更可能支持这个目标。',
        zhHant: '和恢復感相連的時刻，更可能支持這個目標。',
        ja: '回復感のある時間とつながると、この目標は続きやすそうです。',
      ));
    }
    if (hasShort) {
      lines.add(AppLocaleText.tr(
        context,
        en: 'Short attempts are showing up as the easier version.',
        zhHans: '较短的尝试更像是容易发生的版本。',
        zhHant: '較短的嘗試更像是容易發生的版本。',
        ja: '短い試行の方が起こりやすい形として見えています。',
      ));
    }
    if (hasHelpfulFeedback) {
      lines.add(AppLocaleText.tr(
        context,
        en: 'Helpful feedback is already appearing; keep the action small.',
        zhHans: '已经出现有帮助的反馈，先继续保持小一点。',
        zhHant: '已經出現有幫助的回饋，先繼續保持小一點。',
        ja: '役立つ反応が出ています。まずは小さく保ちます。',
      ));
    }
    if (lines.isEmpty) {
      lines.add(AppLocaleText.tr(
        context,
        en: 'This goal still needs a few real feedback records.',
        zhHans: '这个目标还需要几条真实反馈来归纳偏好。',
        zhHant: '這個目標還需要幾條真實回饋來歸納偏好。',
        ja: 'この目標は、好みを読むためにもう少し実際の反応が必要です。',
      ));
    }
    return lines.take(3).toList();
  }

  String insightText(BuildContext context) {
    if (feedbacks.isEmpty && signals.isEmpty) {
      return AppLocaleText.tr(
        context,
        en: 'This goal still needs real feedback before the app can summarize what fits you. Keep the next attempt small.',
        zhHans: '这个目标还需要真实反馈，之后才能总结什么更适合你。下一次先保持很小。',
        zhHant: '這個目標還需要真實回饋，之後才能總結什麼更適合你。下一次先保持很小。',
        ja: 'この目標は、合う形を読むために実際の反応がもう少し必要です。次は小さく試します。',
      );
    }
    if (hasHelpfulFeedback) {
      return AppLocaleText.tr(
        context,
        en: 'Helpful feedback has appeared. The safer template is to keep the useful part and avoid making the action bigger too quickly.',
        zhHans: '已经出现有帮助的反馈。更稳的模板是保留有效部分，不要太快把行动变大。',
        zhHant: '已經出現有幫助的回饋。更穩的模板是保留有效部分，不要太快把行動變大。',
        ja: '役立つ反応が出ています。有効な部分を残し、急に大きくしない形がよさそうです。',
      );
    }
    final hard = feedbacks.any((feedback) =>
        feedback.completionStatus.toLowerCase().contains('hard') ||
        (feedback.feedbackText ?? '').contains('太难'));
    if (hard) {
      return AppLocaleText.tr(
        context,
        en: 'Some feedback says this is costly. A better template is to reduce duration, steps, or timing pressure.',
        zhHans: '已有反馈显示它有点耗力。更合适的模板是减少时长、步骤或时间压力。',
        zhHant: '已有回饋顯示它有點耗力。更合適的模板是減少時長、步驟或時間壓力。',
        ja: '少し負荷が高い反応があります。時間・手順・タイミングの圧を減らす形が合いそうです。',
      );
    }
    return AppLocaleText.tr(
      context,
      en: 'Signals are still limited. Compare this goal across a few real days before turning it into a stable method.',
      zhHans: '目前 Signal 还比较少。先跨几个真实日期比较，再把它沉淀成稳定方法。',
      zhHant: '目前 Signal 還比較少。先跨幾個真實日期比較，再把它沉澱成穩定方法。',
      ja: 'Signal はまだ少なめです。数日分を比べてから、安定した方法として残します。',
    );
  }
}

class _ExperimentRollup {
  final String experimentId;
  final String rootExperimentId;
  final String? parentExperimentId;
  final String currentStatus;
  final String title;
  final String hypothesis;
  final String suggestedAction;
  final int totalFeedbackCount;
  final int triedCount;
  final int helpfulCount;
  final int notHelpfulCount;
  final int adjustedCount;
  final int skippedCount;
  final int activeWeekCount;
  final DateTime? firstStartedAt;
  final DateTime? lastFeedbackAt;
  final DateTime? lastEventAt;
  final List<Map<String, dynamic>> lineage;

  const _ExperimentRollup({
    required this.experimentId,
    required this.rootExperimentId,
    required this.parentExperimentId,
    required this.currentStatus,
    required this.title,
    required this.hypothesis,
    required this.suggestedAction,
    required this.totalFeedbackCount,
    required this.triedCount,
    required this.helpfulCount,
    required this.notHelpfulCount,
    required this.adjustedCount,
    required this.skippedCount,
    required this.activeWeekCount,
    required this.firstStartedAt,
    required this.lastFeedbackAt,
    required this.lastEventAt,
    required this.lineage,
  });

  factory _ExperimentRollup.fromRow(Map<String, dynamic> row) {
    return _ExperimentRollup(
      experimentId: (row['experiment_id'] as String?) ?? '',
      rootExperimentId: (row['root_experiment_id'] as String?) ?? '',
      parentExperimentId: row['parent_experiment_id'] as String?,
      currentStatus: (row['current_status'] as String?) ?? 'suggested',
      title: (row['title'] as String?) ?? '',
      hypothesis: (row['hypothesis'] as String?) ?? '',
      suggestedAction: (row['suggested_action'] as String?) ?? '',
      totalFeedbackCount: _intFrom(row['total_feedback_count']),
      triedCount: _intFrom(row['tried_count']),
      helpfulCount: _intFrom(row['helpful_count']),
      notHelpfulCount: _intFrom(row['not_helpful_count']),
      adjustedCount: _intFrom(row['adjusted_count']),
      skippedCount: _intFrom(row['skipped_count']),
      activeWeekCount: math.max(1, _intFrom(row['active_week_count'])),
      firstStartedAt: _dateFrom(row['first_started_at']),
      lastFeedbackAt: _dateFrom(row['last_feedback_at']),
      lastEventAt: _dateFrom(row['last_event_at']),
      lineage: _decodeMapList(row['lineage_json']),
    );
  }

  bool get hasLineage =>
      parentExperimentId?.trim().isNotEmpty == true || lineage.length > 1;
}

class _ExperimentLifecycleEvent {
  final String id;
  final String experimentId;
  final String eventType;
  final DateTime? eventDate;
  final String localDate;
  final String? sourceType;
  final String? sourceId;
  final String? statusFrom;
  final String? statusTo;
  final Map<String, dynamic> payload;

  const _ExperimentLifecycleEvent({
    required this.id,
    required this.experimentId,
    required this.eventType,
    required this.eventDate,
    required this.localDate,
    required this.sourceType,
    required this.sourceId,
    required this.statusFrom,
    required this.statusTo,
    required this.payload,
  });

  factory _ExperimentLifecycleEvent.fromRow(Map<String, dynamic> row) {
    return _ExperimentLifecycleEvent(
      id: (row['id'] as String?) ?? '',
      experimentId: (row['experiment_id'] as String?) ?? '',
      eventType: (row['event_type'] as String?) ?? 'updated',
      eventDate: _dateFrom(row['event_date']),
      localDate: (row['local_date'] as String?) ?? '',
      sourceType: row['source_type'] as String?,
      sourceId: row['source_id'] as String?,
      statusFrom: row['status_from'] as String?,
      statusTo: row['status_to'] as String?,
      payload: _decodeMap(row['payload_json']),
    );
  }
}

int _intFrom(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw) ?? 0;
  return 0;
}

DateTime? _dateFrom(Object? raw) {
  final text = raw?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return DateTime.tryParse(text);
}

Map<String, dynamic> _decodeMap(Object? raw) {
  final text = raw?.toString().trim();
  if (text == null || text.isEmpty) return const {};
  try {
    final decoded = jsonDecode(text);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry('$key', value));
    }
  } catch (_) {}
  return const {};
}

List<Map<String, dynamic>> _decodeMapList(Object? raw) {
  final text = raw?.toString().trim();
  if (text == null || text.isEmpty) return const [];
  try {
    final decoded = jsonDecode(text);
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((item) => item.map((key, value) => MapEntry('$key', value)))
          .toList();
    }
  } catch (_) {}
  return const [];
}

class _DurationBucket {
  final String label;
  final int count;
  final Color color;

  const _DurationBucket(this.label, this.count, this.color);
}

String _readableEvidenceLabel(BuildContext context, String value) =>
    localizeUserVisibleDynamicText(context, value);

IconData _evidenceIcon(String value) {
  final text = value.toLowerCase();
  if (text.contains('recover') ||
      text.contains('restore') ||
      text.contains('恢复')) {
    return Icons.spa_rounded;
  }
  if (text.contains('hard') || text.contains('drain') || text.contains('压力')) {
    return Icons.thunderstorm_rounded;
  }
  if (text.contains('help') || text.contains('有效') || text.contains('有帮助')) {
    return Icons.favorite_rounded;
  }
  if (text.contains('morning') ||
      text.contains('evening') ||
      text.contains('night')) {
    return Icons.schedule_rounded;
  }
  return Icons.auto_awesome_rounded;
}

Color _evidenceColor(String value) {
  final text = value.toLowerCase();
  if (text.contains('recover') ||
      text.contains('restore') ||
      text.contains('恢复')) {
    return AuroraColors.mint;
  }
  if (text.contains('hard') || text.contains('drain') || text.contains('压力')) {
    return AuroraColors.orange;
  }
  if (text.contains('help') || text.contains('有效') || text.contains('有帮助')) {
    return AuroraColors.gold;
  }
  return AuroraColors.purple;
}

class _ExperimentTrackPager extends StatefulWidget {
  final _ExperimentHomeTrack track;
  final VoidCallback onShowSmallExperiments;
  final VoidCallback onShowGoals;
  final Widget child;

  const _ExperimentTrackPager({
    required this.track,
    required this.onShowSmallExperiments,
    required this.onShowGoals,
    required this.child,
  });

  @override
  State<_ExperimentTrackPager> createState() => _ExperimentTrackPagerState();
}

class _ExperimentTrackPagerState extends State<_ExperimentTrackPager> {
  static const _switchThreshold = 48.0;
  static const _flingThreshold = 360.0;

  double _horizontalDragDistance = 0;

  void _handleHorizontalDragStart(DragStartDetails details) {
    _horizontalDragDistance = 0;
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    _horizontalDragDistance += details.primaryDelta ?? 0;
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final swipedLeft = _horizontalDragDistance <= -_switchThreshold ||
        velocity <= -_flingThreshold;
    final swipedRight = _horizontalDragDistance >= _switchThreshold ||
        velocity >= _flingThreshold;
    _horizontalDragDistance = 0;

    if (widget.track == _ExperimentHomeTrack.smallExperiments && swipedLeft) {
      widget.onShowGoals();
    } else if (widget.track == _ExperimentHomeTrack.goals && swipedRight) {
      widget.onShowSmallExperiments();
    }
  }

  void _handleHorizontalDragCancel() {
    _horizontalDragDistance = 0;
  }

  @override
  Widget build(BuildContext context) {
    final isSmallExperiment =
        widget.track == _ExperimentHomeTrack.smallExperiments;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ExperimentTrackSwitcher(
          track: widget.track,
          onShowSmallExperiments: widget.onShowSmallExperiments,
          onShowGoals: widget.onShowGoals,
        ),
        const SizedBox(height: 14),
        Semantics(
          container: true,
          label: AppLocaleText.tr(
            context,
            en: isSmallExperiment
                ? 'Page 1 of 2, Spot Tries. Swipe left for goals.'
                : 'Page 2 of 2, goals. Swipe right for Spot Tries.',
            zhHans: isSmallExperiment
                ? '第1页，共2页：小实验。向左滑查看目标。'
                : '第2页，共2页：目标。向右滑查看小实验。',
            zhHant: isSmallExperiment
                ? '第1頁，共2頁：小實驗。向左滑查看目標。'
                : '第2頁，共2頁：目標。向右滑查看小實驗。',
            ja: isSmallExperiment
                ? '全2ページ中1ページ目、小実験。左へスワイプすると目標を表示します。'
                : '全2ページ中2ページ目、目標。右へスワイプすると小実験を表示します。',
          ),
          child: GestureDetector(
            key: const ValueKey('experiment-track-pager'),
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: _handleHorizontalDragStart,
            onHorizontalDragUpdate: _handleHorizontalDragUpdate,
            onHorizontalDragEnd: _handleHorizontalDragEnd,
            onHorizontalDragCancel: _handleHorizontalDragCancel,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}

class _ExperimentTrackSwitcher extends StatelessWidget {
  final _ExperimentHomeTrack track;
  final VoidCallback onShowSmallExperiments;
  final VoidCallback onShowGoals;

  const _ExperimentTrackSwitcher({
    required this.track,
    required this.onShowSmallExperiments,
    required this.onShowGoals,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('experiment-track-switcher'),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.80),
            const Color(0xFFF6F3FF).withValues(alpha: 0.88),
            const Color(0xFFF1FBF8).withValues(alpha: 0.76),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.88),
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 24,
            offset: const Offset(0, 10),
            color: AuroraColors.purple.withValues(alpha: 0.10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _ExperimentTrackSwitchSegment(
              key: const ValueKey(
                'experiment-track-switch-small-experiments',
              ),
              selected: track == _ExperimentHomeTrack.smallExperiments,
              icon: Icons.spa_rounded,
              color: AuroraColors.mint,
              title: AppLocaleText.tr(
                context,
                en: 'Spot Try',
                zhHans: '小实验',
                zhHant: '小實驗',
                ja: '小実験',
              ),
              subtitle: AppLocaleText.tr(
                context,
                en: 'Quick & simple',
                zhHans: '简单尝试',
                zhHant: '簡單嘗試',
                ja: 'スポットトライ',
              ),
              onTap: onShowSmallExperiments,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _ExperimentTrackSwitchSegment(
              key: const ValueKey('experiment-track-switch-goals'),
              selected: track == _ExperimentHomeTrack.goals,
              icon: Icons.flag_rounded,
              color: AuroraColors.purple,
              title: AppLocaleText.tr(
                context,
                en: 'Goals',
                zhHans: '目标',
                zhHant: '目標',
                ja: '目標',
              ),
              subtitle: AppLocaleText.tr(
                context,
                en: 'Longer term',
                zhHans: '中长期',
                zhHant: '中長期',
                ja: '中長期',
              ),
              onTap: onShowGoals,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExperimentTrackSwitchSegment extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ExperimentTrackSwitchSegment({
    super.key,
    required this.selected,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = '$title${_experimentListSeparator(context)}$subtitle';
    final hint = AppLocaleText.tr(
      context,
      en: selected ? 'Currently shown' : 'Double tap to switch',
      zhHans: selected ? '当前显示' : '双击切换',
      zhHant: selected ? '目前顯示' : '點兩下切換',
      ja: selected ? '現在表示中' : 'ダブルタップして切り替え',
    );
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      hint: hint,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(19),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              constraints: const BoxConstraints(minHeight: 58),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: selected
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          color.withValues(alpha: 0.22),
                          Colors.white.withValues(alpha: 0.92),
                        ],
                      )
                    : null,
                borderRadius: BorderRadius.circular(19),
                border: Border.all(
                  color: selected
                      ? color.withValues(alpha: 0.58)
                      : Colors.transparent,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          blurRadius: 18,
                          offset: const Offset(0, 7),
                          color: color.withValues(alpha: 0.16),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? color.withValues(alpha: 0.18)
                          : const Color(0xFFEFEFF7),
                    ),
                    child: Icon(
                      icon,
                      size: 19,
                      color: selected ? color : AuroraColors.muted,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: selected
                                        ? AuroraColors.ink
                                        : AuroraColors.muted,
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                color: selected ? color : AuroraColors.muted,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallTryBranchChart extends StatelessWidget {
  final List<AdoptedMicroActionProgress> items;
  final List<MicroActionCandidateModel> consideringCandidates;
  final List<MicroActionFeedbackModel> Function(AdoptedMicroActionProgress)
      feedbacksFor;
  final MicroActionReviewEventModel? Function(AdoptedMicroActionProgress)
      latestReviewFor;
  final ValueChanged<AdoptedMicroActionProgress> onOpenDetail;
  final ValueChanged<MicroActionCandidateModel> onOpenCandidateDetail;

  const _SmallTryBranchChart({
    required this.items,
    required this.consideringCandidates,
    required this.feedbacksFor,
    required this.latestReviewFor,
    required this.onOpenDetail,
    required this.onOpenCandidateDetail,
  });

  @override
  Widget build(BuildContext context) {
    final grouped =
        <_ExperimentLifecycleStage, List<AdoptedMicroActionProgress>>{
      for (final stage in _ExperimentLifecycleStage.values) stage: [],
    };
    for (final item in items) {
      grouped[_smallTryLifecycleStage(item.action)]!.add(item);
    }
    final visibleStages = _ExperimentLifecycleStage.values
        .where(
          (stage) =>
              grouped[stage]!.isNotEmpty ||
              (stage == _ExperimentLifecycleStage.considering &&
                  consideringCandidates.isNotEmpty),
        )
        .toList(growable: false);
    return Column(
      key: const ValueKey('life-experiment-small-tries-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LifeExperimentTrackHeading(
          icon: Icons.spa_rounded,
          color: AuroraColors.mint,
          title: AppLocaleText.tr(
            context,
            en: 'Spot Tries · quick and simple',
            zhHans: '小实验 · 简单尝试',
            zhHant: '小實驗 · 簡單嘗試',
            ja: '小実験 · スポットトライ',
          ),
          description: AppLocaleText.tr(
            context,
            en: 'Review attempts, helpfulness, and effort collected from Today and Weekly.',
            zhHans: '汇总今天与每周复盘中的尝试次数、帮助程度和负担感。',
            zhHant: '彙總今天與每週復盤中的嘗試次數、幫助程度和負擔感。',
            ja: '「今日」と週次レビューから、試行回数・役立ち方・負担感をまとめます。',
          ),
          count: items.length + consideringCandidates.length,
        ),
        const SizedBox(height: 10),
        AuroraCard(
          key: const ValueKey('small-try-branch-chart'),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
          borderRadius:
              BorderRadius.circular(AuroraMainPageSpec.cardRadiusLarge),
          color: Colors.white.withValues(alpha: 0.68),
          child: items.isEmpty && consideringCandidates.isEmpty
              ? _ExperimentChartEmpty(
                  icon: Icons.hub_outlined,
                  color: AuroraColors.mint,
                  title: AppLocaleText.tr(
                    context,
                    en: 'No Spot Tries yet',
                    zhHans: '还没有小实验',
                    zhHant: '還沒有小實驗',
                    ja: '小実験はまだありません',
                  ),
                  body: AppLocaleText.tr(
                    context,
                    en: 'Adopted Spot Tries will branch into observing, in progress, and ended here.',
                    zhHans: '采纳或暂时观察的小实验，会在这里按状态展开。',
                    zhHant: '採納或暫時觀察的小實驗，會在這裡按狀態展開。',
                    ja: '採用または観察中の小実験が、状態ごとにここへ広がります。',
                  ),
                )
              : Column(
                  children: [
                    for (var index = 0;
                        index < visibleStages.length;
                        index++) ...[
                      _SmallTryLifecycleLane(
                        stage: visibleStages[index],
                        items: grouped[visibleStages[index]]!,
                        consideringCandidates: visibleStages[index] ==
                                _ExperimentLifecycleStage.considering
                            ? consideringCandidates
                            : const [],
                        onOpenDetail: onOpenDetail,
                        onOpenCandidateDetail: onOpenCandidateDetail,
                        feedbacksFor: feedbacksFor,
                        latestReviewFor: latestReviewFor,
                      ),
                      if (index != visibleStages.length - 1)
                        const SizedBox(height: 12),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _SmallTryLifecycleLane extends StatelessWidget {
  final _ExperimentLifecycleStage stage;
  final List<AdoptedMicroActionProgress> items;
  final List<MicroActionCandidateModel> consideringCandidates;
  final ValueChanged<AdoptedMicroActionProgress> onOpenDetail;
  final ValueChanged<MicroActionCandidateModel> onOpenCandidateDetail;
  final List<MicroActionFeedbackModel> Function(AdoptedMicroActionProgress)
      feedbacksFor;
  final MicroActionReviewEventModel? Function(AdoptedMicroActionProgress)
      latestReviewFor;

  const _SmallTryLifecycleLane({
    required this.stage,
    required this.items,
    required this.consideringCandidates,
    required this.onOpenDetail,
    required this.onOpenCandidateDetail,
    required this.feedbacksFor,
    required this.latestReviewFor,
  });

  @override
  Widget build(BuildContext context) {
    final color = _lifecycleStageColor(stage);
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.15),
                ),
                child: Icon(
                  _lifecycleStageIcon(stage),
                  color: color,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _lifecycleStageLabel(context, stage),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AuroraColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Text(
                '${items.length + consideringCandidates.length}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          if (items.isEmpty && consideringCandidates.isEmpty)
            Text(
              AppLocaleText.tr(
                context,
                en: 'Nothing here yet',
                zhHans: '暂时没有',
                zhHant: '暫時沒有',
                ja: 'まだありません',
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AuroraColors.muted,
                  ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  children: [
                    for (var index = 0;
                        index < consideringCandidates.length;
                        index++) ...[
                      SizedBox(
                        width: constraints.maxWidth,
                        child: _ConsideringSmallTryNode(
                          candidate: consideringCandidates[index],
                          onTap: () => onOpenCandidateDetail(
                            consideringCandidates[index],
                          ),
                        ),
                      ),
                      if (index != consideringCandidates.length - 1 ||
                          items.isNotEmpty)
                        const SizedBox(height: 9),
                    ],
                    for (var index = 0; index < items.length; index++) ...[
                      SizedBox(
                        width: constraints.maxWidth,
                        child: _SmallTryBranchNode(
                          item: items[index],
                          stage: stage,
                          feedbacks: feedbacksFor(items[index]),
                          latestReview: latestReviewFor(items[index]),
                          onTap: () => onOpenDetail(items[index]),
                        ),
                      ),
                      if (index != items.length - 1) const SizedBox(height: 9),
                    ],
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _SmallTryBranchNode extends StatelessWidget {
  final AdoptedMicroActionProgress item;
  final _ExperimentLifecycleStage stage;
  final List<MicroActionFeedbackModel> feedbacks;
  final MicroActionReviewEventModel? latestReview;
  final VoidCallback onTap;

  const _SmallTryBranchNode({
    required this.item,
    required this.stage,
    required this.feedbacks,
    required this.latestReview,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _lifecycleStageColor(stage);
    final attempts = _completedSmallTryAttemptFeedbacks(feedbacks);
    final attemptCount = item.progress.completedAttempts;
    final effectSummary = _smallTryEffectSummary(context, attempts);
    final effortSummary = _smallTryEffortSummary(context, attempts);
    final reviewLabel = latestReview == null
        ? null
        : _smallTryRoundResultLabel(context, latestReview!.result);
    final separator = _experimentListSeparator(context);
    return Semantics(
      button: true,
      label: [
        item.action.title,
        _lifecycleStageLabel(context, stage),
        AppLocaleText.tr(
          context,
          en: '$attemptCount attempts',
          zhHans: '尝试 $attemptCount 次',
          zhHant: '嘗試 $attemptCount 次',
          ja: '$attemptCount 回試行',
        ),
        effectSummary,
        effortSummary,
      ].join(separator),
      child: Material(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: ValueKey('life-experiment-small-try-${item.action.id}'),
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(11, 10, 10, 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.action.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AuroraColors.ink,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AuroraColors.muted,
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    _SmallTryAttemptPoints(feedbacks: attempts),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppLocaleText.tr(
                          context,
                          en: '$attemptCount attempts this round',
                          zhHans: '本轮尝试 $attemptCount 次',
                          zhHant: '本輪嘗試 $attemptCount 次',
                          ja: '今回 $attemptCount 回試行',
                        ),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _CompactSummaryPill(
                      icon: Icons.auto_awesome_rounded,
                      label: effectSummary,
                      color: AuroraColors.mint,
                    ),
                    _CompactSummaryPill(
                      icon: Icons.speed_rounded,
                      label: effortSummary,
                      color: AuroraColors.orange,
                    ),
                    if (reviewLabel != null)
                      _CompactSummaryPill(
                        icon: Icons.bookmark_added_rounded,
                        label: reviewLabel,
                        color: AuroraColors.purple,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallTryRoundReviewInput {
  final String result;
  final String effort;
  final String? note;

  const _SmallTryRoundReviewInput({
    required this.result,
    required this.effort,
    this.note,
  });
}

class _GoalOutcomeReviewInput {
  final String outcome;
  final String burden;
  final String? note;

  const _GoalOutcomeReviewInput({
    required this.outcome,
    required this.burden,
    this.note,
  });
}

class _FeedbackChoice {
  final String value;
  final String label;

  const _FeedbackChoice({required this.value, required this.label});
}

class _FeedbackChoiceGroup extends StatelessWidget {
  final String title;
  final String? value;
  final List<_FeedbackChoice> options;
  final ValueChanged<String> onChanged;

  const _FeedbackChoiceGroup({
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              ChoiceChip(
                label: Text(option.label),
                selected: value == option.value,
                onSelected: (_) => onChanged(option.value),
                materialTapTargetSize: MaterialTapTargetSize.padded,
                visualDensity: const VisualDensity(vertical: 1),
              ),
          ],
        ),
      ],
    );
  }
}

class _SmallTryAttemptPoints extends StatelessWidget {
  final List<MicroActionFeedbackModel> feedbacks;

  const _SmallTryAttemptPoints({required this.feedbacks});

  @override
  Widget build(BuildContext context) {
    final visible = feedbacks.length <= 5
        ? feedbacks
        : feedbacks.sublist(feedbacks.length - 5);
    return Semantics(
      label: AppLocaleText.tr(
        context,
        en: '${feedbacks.length} recorded attempts',
        zhHans: '已记录 ${feedbacks.length} 次尝试',
        zhHant: '已記錄 ${feedbacks.length} 次嘗試',
        ja: '${feedbacks.length} 回の試行を記録',
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (visible.isEmpty)
            for (var index = 0; index < 3; index++) ...[
              const Icon(
                Icons.circle_outlined,
                size: 15,
                color: Color(0xFFC8CEDA),
              ),
              if (index != 2) const SizedBox(width: 3),
            ]
          else
            for (var index = 0; index < visible.length; index++) ...[
              Icon(
                Icons.circle,
                size: 15,
                color: _smallTryEffectColor(visible[index].effect),
              ),
              if (index != visible.length - 1) const SizedBox(width: 3),
            ],
          if (feedbacks.length > visible.length) ...[
            const SizedBox(width: 4),
            Text(
              '+${feedbacks.length - visible.length}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AuroraColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompactSummaryPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _CompactSummaryPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.17)),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Icon(icon, size: 13, color: color),
            ),
            const WidgetSpan(child: SizedBox(width: 4)),
            TextSpan(text: label),
          ],
        ),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AuroraColors.ink,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

Color _smallTryEffectColor(String raw) =>
    switch (normalizeSmallTryEffect(raw)) {
      SmallTryEffect.helpful => AuroraColors.mint,
      SmallTryEffect.somewhatHelpful => AuroraColors.gold,
      SmallTryEffect.noEffect => AuroraColors.orange,
      _ => const Color(0xFFC8CEDA),
    };

List<MicroActionFeedbackModel> _completedSmallTryAttemptFeedbacks(
  Iterable<MicroActionFeedbackModel> feedbacks,
) {
  const completedAliases = {
    'yes',
    'happened',
    'occurred',
    'done',
    'completed',
    'true',
    'tried',
  };
  return feedbacks
      .where(
        (feedback) =>
            feedback.isValid &&
            completedAliases.contains(feedback.happened.trim().toLowerCase()),
      )
      .toList(growable: false);
}

String _smallTryEffectLabel(BuildContext context, String raw) {
  return switch (normalizeSmallTryEffect(raw)) {
    SmallTryEffect.helpful => AppLocaleText.tr(
        context,
        en: 'Helpful',
        zhHans: '有帮助',
        zhHant: '有幫助',
        ja: '役立った',
      ),
    SmallTryEffect.somewhatHelpful => AppLocaleText.tr(
        context,
        en: 'A little helpful',
        zhHans: '有一点',
        zhHant: '有一點',
        ja: '少し役立った',
      ),
    _ => AppLocaleText.tr(
        context,
        en: 'No difference',
        zhHans: '没感觉',
        zhHant: '沒感覺',
        ja: '変化なし',
      ),
  };
}

String _smallTryDifficultyLabel(BuildContext context, String raw) {
  return switch (normalizeSmallTryDifficulty(raw)) {
    SmallTryDifficulty.easy => AppLocaleText.tr(
        context,
        en: 'Effort: easy',
        zhHans: '负担：轻松',
        zhHant: '負擔：輕鬆',
        ja: '負担：軽い',
      ),
    SmallTryDifficulty.difficult => AppLocaleText.tr(
        context,
        en: 'Effort: demanding',
        zhHans: '负担：偏费力',
        zhHant: '負擔：偏費力',
        ja: '負担：やや重い',
      ),
    _ => AppLocaleText.tr(
        context,
        en: 'Effort: okay',
        zhHans: '负担：还好',
        zhHant: '負擔：還好',
        ja: '負担：普通',
      ),
  };
}

String _smallTryEffectSummary(
  BuildContext context,
  List<MicroActionFeedbackModel> feedbacks,
) {
  if (feedbacks.isEmpty) {
    return AppLocaleText.tr(
      context,
      en: 'Effect: awaiting feedback',
      zhHans: '效果：待评价',
      zhHant: '效果：待評價',
      ja: '効果：評価待ち',
    );
  }
  final helpful = feedbacks
      .where((item) =>
          normalizeSmallTryEffect(item.effect) == SmallTryEffect.helpful)
      .length;
  final somewhat = feedbacks
      .where((item) =>
          normalizeSmallTryEffect(item.effect) ==
          SmallTryEffect.somewhatHelpful)
      .length;
  final noEffect = feedbacks
      .where((item) =>
          normalizeSmallTryEffect(item.effect) == SmallTryEffect.noEffect)
      .length;
  if (helpful + somewhat + noEffect == 0) {
    return AppLocaleText.tr(
      context,
      en: 'Effect: awaiting feedback',
      zhHans: '效果：待评价',
      zhHant: '效果：待評價',
      ja: '効果：評価待ち',
    );
  }
  if (helpful >= somewhat && helpful >= noEffect) {
    return AppLocaleText.tr(
      context,
      en: '$helpful helpful',
      zhHans: '$helpful 次有帮助',
      zhHant: '$helpful 次有幫助',
      ja: '$helpful 回役立った',
    );
  }
  if (somewhat >= noEffect) {
    return AppLocaleText.tr(
      context,
      en: '$somewhat somewhat helpful',
      zhHans: '$somewhat 次有一点',
      zhHant: '$somewhat 次有一點',
      ja: '$somewhat 回少し役立った',
    );
  }
  return AppLocaleText.tr(
    context,
    en: '$noEffect no effect',
    zhHans: '$noEffect 次没感觉',
    zhHant: '$noEffect 次沒感覺',
    ja: '$noEffect 回変化なし',
  );
}

String _smallTryEffortSummary(
  BuildContext context,
  List<MicroActionFeedbackModel> feedbacks,
) {
  if (feedbacks.isEmpty) {
    return AppLocaleText.tr(
      context,
      en: 'Effort: awaiting feedback',
      zhHans: '负担：待评价',
      zhHant: '負擔：待評價',
      ja: '負担：評価待ち',
    );
  }
  final counts = <String, int>{
    SmallTryDifficulty.easy: 0,
    SmallTryDifficulty.okay: 0,
    SmallTryDifficulty.difficult: 0,
  };
  for (final feedback in feedbacks) {
    final normalized = normalizeSmallTryDifficulty(feedback.difficulty);
    if (counts.containsKey(normalized)) {
      counts[normalized] = counts[normalized]! + 1;
    }
  }
  final leading =
      counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  return switch (leading) {
    SmallTryDifficulty.easy => AppLocaleText.tr(
        context,
        en: 'Effort: mostly easy',
        zhHans: '负担：多数轻松',
        zhHant: '負擔：多數輕鬆',
        ja: '負担：多くは楽',
      ),
    SmallTryDifficulty.difficult => AppLocaleText.tr(
        context,
        en: 'Effort: demanding',
        zhHans: '负担：偏费力',
        zhHant: '負擔：偏費力',
        ja: '負担：やや重い',
      ),
    _ => AppLocaleText.tr(
        context,
        en: 'Effort: mostly okay',
        zhHans: '负担：多数还好',
        zhHant: '負擔：多數還好',
        ja: '負担：概ね普通',
      ),
  };
}

String _smallTryRoundResultLabel(BuildContext context, String result) {
  return switch (result) {
    SmallTryRoundResult.worthKeeping => AppLocaleText.tr(
        context,
        en: 'Worth keeping',
        zhHans: '值得保留',
        zhHant: '值得保留',
        ja: '続ける価値あり',
      ),
    SmallTryRoundResult.adjustAndRetry => AppLocaleText.tr(
        context,
        en: 'Adjust and retry',
        zhHans: '调轻再试',
        zhHant: '調輕再試',
        ja: '軽くして再試行',
      ),
    _ => AppLocaleText.tr(
        context,
        en: 'No help observed',
        zhHans: '暂未发现帮助',
        zhHant: '暫未發現幫助',
        ja: '効果は未確認',
      ),
  };
}

class _ConsideringSmallTryNode extends StatelessWidget {
  final MicroActionCandidateModel candidate;
  final VoidCallback onTap;

  const _ConsideringSmallTryNode({
    required this.candidate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const color = AuroraColors.gold;
    return Semantics(
      button: true,
      label: [
        candidate.title,
        _lifecycleStageLabel(
          context,
          _ExperimentLifecycleStage.considering,
        ),
      ].join(_experimentListSeparator(context)),
      child: Material(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: ValueKey(
            'life-experiment-considering-small-try-${candidate.id}',
          ),
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 68),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.10),
                      border: Border.all(
                        color: color.withValues(alpha: 0.52),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.visibility_outlined,
                      size: 18,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          candidate.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: AuroraColors.ink,
                                    fontWeight: FontWeight.w700,
                                    height: 1.25,
                                  ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          AppLocaleText.tr(
                            context,
                            en: 'Spot Try · not started',
                            zhHans: '简单尝试 · 尚未开始',
                            zhHant: '簡單嘗試 · 尚未開始',
                            ja: 'スポットトライ · 開始前',
                          ),
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: color,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AuroraColors.muted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoalTimelineMatrix extends StatelessWidget {
  final List<LifeExperimentModel> experiments;
  final List<ExperimentCandidateRecord> consideringCandidates;
  final _ExperimentEvidence Function(LifeExperimentModel) evidenceFor;
  final _ExperimentRollup? Function(LifeExperimentModel) rollupFor;
  final LifeExperimentOutcomeReviewModel? Function(LifeExperimentModel)
      latestOutcomeFor;
  final ValueChanged<LifeExperimentModel> onOpenDetail;
  final ValueChanged<ExperimentCandidateRecord> onOpenCandidateDetail;

  const _GoalTimelineMatrix({
    required this.experiments,
    required this.consideringCandidates,
    required this.evidenceFor,
    required this.rollupFor,
    required this.latestOutcomeFor,
    required this.onOpenDetail,
    required this.onOpenCandidateDetail,
  });

  @override
  Widget build(BuildContext context) {
    final ordered = [...experiments]..sort((a, b) {
        final stageA = _experimentLifecycleStage(a, rollupFor(a)).index;
        final stageB = _experimentLifecycleStage(b, rollupFor(b)).index;
        if (stageA != stageB) return stageA.compareTo(stageB);
        return _sortDate(b).compareTo(_sortDate(a));
      });
    final counts = <_ExperimentLifecycleStage, int>{
      for (final stage in _ExperimentLifecycleStage.values) stage: 0,
    };
    for (final experiment in experiments) {
      final stage =
          _experimentLifecycleStage(experiment, rollupFor(experiment));
      counts[stage] = counts[stage]! + 1;
    }
    counts[_ExperimentLifecycleStage.considering] =
        counts[_ExperimentLifecycleStage.considering]! +
            consideringCandidates.length;
    return Column(
      key: const ValueKey('life-experiment-goal-matrix-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LifeExperimentTrackHeading(
          icon: Icons.flag_rounded,
          color: AuroraColors.purple,
          title: AppLocaleText.tr(
            context,
            en: 'Goals · long-term',
            zhHans: '目标 · 中长期',
            zhHant: '目標 · 中長期',
            ja: '目標 · 中長期',
          ),
          description: AppLocaleText.tr(
            context,
            en: 'Review longer-term progress and the feedback collected over time.',
            zhHans: '查看中长期进展，以及连续多日留下的真实反馈。',
            zhHant: '查看中長期進展，以及連續多日留下的真實回饋。',
            ja: '中長期の進み方と、日々積み重なった反応を見返します。',
          ),
          count: experiments.length + consideringCandidates.length,
        ),
        const SizedBox(height: 10),
        AuroraCard(
          key: const ValueKey('goal-timeline-matrix'),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
          borderRadius:
              BorderRadius.circular(AuroraMainPageSpec.cardRadiusLarge),
          color: Colors.white.withValues(alpha: 0.68),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LifecycleLegend(counts: counts),
              const SizedBox(height: 10),
              if (ordered.isEmpty && consideringCandidates.isEmpty)
                _ExperimentChartEmpty(
                  icon: Icons.route_outlined,
                  color: AuroraColors.purple,
                  title: AppLocaleText.tr(
                    context,
                    en: 'No goals yet',
                    zhHans: '还没有目标',
                    zhHant: '還沒有目標',
                    ja: '目標はまだありません',
                  ),
                  body: AppLocaleText.tr(
                    context,
                    en: 'Adopted or observed goals will appear as a multi-day track here.',
                    zhHans: '采纳或暂时观察的目标，会在这里形成多日轨道。',
                    zhHant: '採納或暫時觀察的目標，會在這裡形成多日軌道。',
                    ja: '採用または観察中の目標が、複数日の軌道としてここに表示されます。',
                  ),
                )
              else ...[
                for (var index = 0;
                    index < consideringCandidates.length;
                    index++) ...[
                  _ConsideringGoalTimelineRow(
                    candidate: consideringCandidates[index],
                    onTap: () =>
                        onOpenCandidateDetail(consideringCandidates[index]),
                  ),
                  if (index != consideringCandidates.length - 1 ||
                      ordered.isNotEmpty)
                    const SizedBox(height: 10),
                ],
                for (var index = 0; index < ordered.length; index++) ...[
                  _GoalTimelineRow(
                    experiment: ordered[index],
                    evidence: evidenceFor(ordered[index]),
                    rollup: rollupFor(ordered[index]),
                    latestOutcome: latestOutcomeFor(ordered[index]),
                    onTap: () => onOpenDetail(ordered[index]),
                  ),
                  if (index != ordered.length - 1) const SizedBox(height: 10),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _LifecycleLegend extends StatelessWidget {
  final Map<_ExperimentLifecycleStage, int> counts;

  const _LifecycleLegend({required this.counts});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 7,
      children: [
        for (final stage in _ExperimentLifecycleStage.values)
          if ((counts[stage] ?? 0) > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: _lifecycleStageColor(stage).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Icon(
                        _lifecycleStageIcon(stage),
                        color: _lifecycleStageColor(stage),
                        size: 14,
                      ),
                    ),
                    const WidgetSpan(child: SizedBox(width: 4)),
                    TextSpan(
                      text:
                          '${_lifecycleStageLabel(context, stage)} ${counts[stage] ?? 0}',
                    ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AuroraColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
      ],
    );
  }
}

class _ConsideringGoalTimelineRow extends StatelessWidget {
  final ExperimentCandidateRecord candidate;
  final VoidCallback onTap;

  const _ConsideringGoalTimelineRow({
    required this.candidate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const color = AuroraColors.gold;
    return Semantics(
      button: true,
      label: [
        candidate.title,
        _lifecycleStageLabel(
          context,
          _ExperimentLifecycleStage.considering,
        ),
      ].join(_experimentListSeparator(context)),
      child: Material(
        color: color.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          key: ValueKey('considering-goal-${candidate.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 9, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        candidate.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AuroraColors.ink,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusPill(
                      label: _lifecycleStageLabel(
                        context,
                        _ExperimentLifecycleStage.considering,
                      ),
                      color: color,
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AuroraColors.muted,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Observe: ${candidate.hypothesis}',
                    zhHans: '想观察：${candidate.hypothesis}',
                    zhHant: '想觀察：${candidate.hypothesis}',
                    ja: '観察したい変化：${candidate.hypothesis}',
                  ),
                  key: ValueKey(
                    'considering-goal-${candidate.id}-hypothesis',
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AuroraColors.muted,
                        height: 1.35,
                      ),
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _CompactSummaryPill(
                      icon: Icons.route_rounded,
                      label: AppLocaleText.tr(
                        context,
                        en: 'Long-term observation',
                        zhHans: '中长期观察',
                        zhHant: '中長期觀察',
                        ja: '中長期の観察',
                      ),
                      color: AuroraColors.purple,
                    ),
                    _CompactSummaryPill(
                      icon: Icons.visibility_outlined,
                      label: AppLocaleText.tr(
                        context,
                        en: 'Not started',
                        zhHans: '尚未开始',
                        zhHant: '尚未開始',
                        ja: '開始前',
                      ),
                      color: color,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoalTimelineRow extends StatelessWidget {
  final LifeExperimentModel experiment;
  final _ExperimentEvidence evidence;
  final _ExperimentRollup? rollup;
  final LifeExperimentOutcomeReviewModel? latestOutcome;
  final VoidCallback onTap;

  const _GoalTimelineRow({
    required this.experiment,
    required this.evidence,
    required this.rollup,
    required this.latestOutcome,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final stage = _experimentLifecycleStage(experiment, rollup);
    final color = _lifecycleStageColor(stage);
    final completed = _completedGoalObservationDays(evidence);
    final window = _goalObservationWindow(experiment);
    return Semantics(
      button: true,
      label: [
        experiment.title,
        _lifecycleStageLabel(context, stage),
        AppLocaleText.tr(
          context,
          en: '$completed completed days',
          zhHans: '已完成 $completed 天',
          zhHant: '已完成 $completed 天',
          ja: '$completed 日完了',
        ),
      ].join(_experimentListSeparator(context)),
      child: Material(
        color: color.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          key: ValueKey('experiment-archive-card-${experiment.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 9, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        experiment.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AuroraColors.ink,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusPill(
                      label: _lifecycleStageLabel(context, stage),
                      color: color,
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AuroraColors.muted,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Observe: ${experiment.hypothesis}',
                    zhHans: '想观察：${experiment.hypothesis}',
                    zhHant: '想觀察：${experiment.hypothesis}',
                    ja: '観察したい変化：${experiment.hypothesis}',
                  ),
                  key: ValueKey(
                    'experiment-${experiment.id}-hypothesis',
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AuroraColors.muted,
                        height: 1.4,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _CompactSummaryPill(
                      icon: Icons.check_circle_outline_rounded,
                      label: AppLocaleText.tr(
                        context,
                        en: '$completed completed days',
                        zhHans: '已完成 $completed 天',
                        zhHant: '已完成 $completed 天',
                        ja: '$completed 日完了',
                      ),
                      color: color,
                    ),
                    _CompactSummaryPill(
                      icon: Icons.calendar_month_outlined,
                      label: AppLocaleText.tr(
                        context,
                        en: '${window.totalDays}-day observation',
                        zhHans: '观察期 ${window.totalDays} 天',
                        zhHant: '觀察期 ${window.totalDays} 天',
                        ja: '観察期間 ${window.totalDays} 日',
                      ),
                      color: AuroraColors.blue,
                    ),
                    if (latestOutcome != null)
                      _CompactSummaryPill(
                        icon: Icons.insights_rounded,
                        label: _goalOutcomeLabel(
                          context,
                          latestOutcome!.outcomeResult,
                          latestOutcome!.burden,
                        ),
                        color: _goalOutcomeColor(latestOutcome!.outcomeResult),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                _GoalObservationTimeline(
                  experiment: experiment,
                  evidence: evidence,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoalObservationWindow {
  final DateTime start;
  final DateTime end;
  final int totalDays;

  const _GoalObservationWindow({
    required this.start,
    required this.end,
    required this.totalDays,
  });
}

_GoalObservationWindow _goalObservationWindow(
  LifeExperimentModel experiment,
) {
  final rawStart = _experimentProgressStart(experiment);
  final start = _dateOnly(rawStart);
  final explicitEnd = _parseExperimentDate(experiment.progressEndDate ?? '');
  final minimumEnd = start.add(
    Duration(days: math.max(0, experiment.minimumObservationDays - 1)),
  );
  final today = _dateOnly(DateTime.now());
  final openEndedDisplayEnd = today.isAfter(minimumEnd) ? today : minimumEnd;
  final parsedEnd = explicitEnd ?? openEndedDisplayEnd;
  final end = _dateOnly(parsedEnd.isBefore(start) ? start : parsedEnd);
  final total = end.difference(start).inDays + 1;
  return _GoalObservationWindow(
    start: start,
    end: end,
    totalDays: total,
  );
}

int _completedGoalObservationDays(_ExperimentEvidence evidence) {
  final latestByDate = <String, LifeExperimentFeedbackModel>{};
  for (final feedback in evidence.feedbacks) {
    final current = latestByDate[feedback.localDate];
    final currentTime = current?.updatedAt ?? current?.feedbackDate;
    final nextTime = feedback.updatedAt ?? feedback.feedbackDate;
    if (current == null || nextTime.isAfter(currentTime!)) {
      latestByDate[feedback.localDate] = feedback;
    }
  }
  return latestByDate.values
      .where(
          (feedback) => _feedbackCountsAsCompleted(feedback.completionStatus))
      .length;
}

class _GoalObservationTimeline extends StatelessWidget {
  final LifeExperimentModel experiment;
  final _ExperimentEvidence evidence;

  const _GoalObservationTimeline({
    required this.experiment,
    required this.evidence,
  });

  @override
  Widget build(BuildContext context) {
    final window = _goalObservationWindow(experiment);
    final textScaler = MediaQuery.textScalerOf(context);
    final cellWidth = textScaler.scale(44).clamp(44.0, 60.0);
    final timelineHeight = textScaler.scale(58).clamp(58.0, 78.0);
    final latestByDate = <String, LifeExperimentFeedbackModel>{};
    for (final feedback in evidence.feedbacks) {
      latestByDate[feedback.localDate] = feedback;
    }
    return Semantics(
      label: AppLocaleText.tr(
        context,
        en: '${window.totalDays}-day goal observation timeline',
        zhHans: '${window.totalDays} 天目标观察时间轴',
        zhHant: '${window.totalDays} 天目標觀察時間軸',
        ja: '${window.totalDays} 日の目標観察タイムライン',
      ),
      child: SizedBox(
        key: ValueKey('goal-observation-timeline-${experiment.id}'),
        height: timelineHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: window.totalDays,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (context, index) {
            final date = window.start.add(Duration(days: index));
            final feedback = latestByDate[_localDateKey(date)];
            final completed = feedback != null &&
                _feedbackCountsAsCompleted(feedback.completionStatus);
            final recorded = feedback != null;
            final color = completed
                ? AuroraColors.mint
                : recorded
                    ? AuroraColors.orange
                    : const Color(0xFFDCE2EC);
            return Semantics(
              label: [
                _localDateKey(date),
                completed
                    ? AppLocaleText.tr(
                        context,
                        en: 'completed',
                        zhHans: '已完成',
                        zhHant: '已完成',
                        ja: '完了',
                      )
                    : recorded
                        ? AppLocaleText.tr(
                            context,
                            en: 'not completed',
                            zhHans: '未完成',
                            zhHant: '未完成',
                            ja: '未完了',
                          )
                        : AppLocaleText.tr(
                            context,
                            en: 'not recorded',
                            zhHans: '未登记',
                            zhHant: '未登記',
                            ja: '未記録',
                          ),
              ].join(_experimentListSeparator(context)),
              child: Container(
                width: cellWidth,
                padding: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: completed ? 0.14 : 0.32),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: color.withValues(alpha: 0.52),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${date.month}/${date.day}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AuroraColors.muted,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 1),
                    Icon(
                      completed
                          ? Icons.check_rounded
                          : recorded
                              ? Icons.remove_rounded
                              : Icons.circle_outlined,
                      size: 17,
                      color: completed || recorded ? color : AuroraColors.muted,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

Color _goalOutcomeColor(String outcome) => switch (outcome) {
      GoalOutcomeResult.improved => AuroraColors.mint,
      GoalOutcomeResult.somewhatImproved => AuroraColors.gold,
      GoalOutcomeResult.noChange => AuroraColors.blue,
      GoalOutcomeResult.worse => AuroraColors.orange,
      _ => AuroraColors.purple,
    };

String _goalOutcomeLabel(
  BuildContext context,
  String outcome,
  String burden,
) {
  final result = switch (outcome) {
    GoalOutcomeResult.improved => AppLocaleText.tr(
        context,
        en: 'This round looks helpful',
        zhHans: '本轮看起来有效',
        zhHant: '本輪看起來有效',
        ja: '今回は効果がありそう',
      ),
    GoalOutcomeResult.somewhatImproved => AppLocaleText.tr(
        context,
        en: 'Some improvement',
        zhHans: '有一点改善',
        zhHant: '有一點改善',
        ja: '少し改善',
      ),
    GoalOutcomeResult.noChange => AppLocaleText.tr(
        context,
        en: 'No change yet',
        zhHans: '暂未看到变化',
        zhHant: '暫未看到變化',
        ja: 'まだ変化なし',
      ),
    GoalOutcomeResult.worse => AppLocaleText.tr(
        context,
        en: 'May not fit now',
        zhHans: '当前做法可能不适合',
        zhHant: '目前做法可能不適合',
        ja: '今は合わない可能性',
      ),
    _ => AppLocaleText.tr(
        context,
        en: 'Not enough to tell',
        zhHans: '还不能判断',
        zhHant: '還不能判斷',
        ja: 'まだ判断できない',
      ),
  };
  if (burden != EvaluationEffort.tooDifficult) return result;
  return AppLocaleText.tr(
    context,
    en: '$result · too demanding',
    zhHans: '$result · 需要调轻',
    zhHant: '$result · 需要調輕',
    ja: '$result · 負担を軽く',
  );
}

String _goalBurdenLabel(BuildContext context, String burden) {
  return switch (burden) {
    EvaluationEffort.easy => AppLocaleText.tr(
        context,
        en: 'Burden: light',
        zhHans: '负担：轻松',
        zhHant: '負擔：輕鬆',
        ja: '負担：軽い',
      ),
    EvaluationEffort.tooDifficult => AppLocaleText.tr(
        context,
        en: 'Burden: too demanding',
        zhHans: '负担：偏重',
        zhHant: '負擔：偏重',
        ja: '負担：重い',
      ),
    _ => AppLocaleText.tr(
        context,
        en: 'Burden: acceptable',
        zhHans: '负担：可接受',
        zhHant: '負擔：可接受',
        ja: '負担：許容範囲',
      ),
  };
}

class _ExperimentChartEmpty extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const _ExperimentChartEmpty({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuroraSoftIconCircle(icon: icon, color: color),
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
                const SizedBox(height: 4),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AuroraColors.muted,
                        height: 1.4,
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

class _ExperimentSearchEmptyState extends StatelessWidget {
  final VoidCallback onClear;

  const _ExperimentSearchEmptyState({required this.onClear});

  @override
  Widget build(BuildContext context) {
    return AuroraCard(
      key: const ValueKey('experiment-search-empty-state'),
      padding: AuroraMainPageSpec.cardPadding,
      child: Column(
        children: [
          const AuroraSoftIconCircle(
            icon: Icons.search_off_rounded,
            color: AuroraColors.purple,
          ),
          const SizedBox(height: 10),
          Text(
            AppLocaleText.tr(
              context,
              en: 'No matching Spot Tries or goals',
              zhHans: '没有匹配的小实验或目标',
              zhHant: '沒有匹配的小實驗或目標',
              ja: '一致する小実験や目標はありません',
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AuroraColors.ink,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onClear,
            child: Text(
              AppLocaleText.tr(
                context,
                en: 'Clear search',
                zhHans: '清除搜索',
                zhHant: '清除搜尋',
                ja: '検索をクリア',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExperimentUnifiedEmptyState extends StatelessWidget {
  const _ExperimentUnifiedEmptyState();

  @override
  Widget build(BuildContext context) {
    return AuroraCard(
      key: const ValueKey('life-experiment-empty-state'),
      padding: const EdgeInsets.all(18),
      borderRadius: BorderRadius.circular(22),
      color: Colors.white.withValues(alpha: 0.68),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AuroraColors.mint.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: AuroraColors.mint,
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
                    en: 'Nothing to review yet',
                    zhHans: '还没有可回看的内容',
                    zhHant: '還沒有可回看的內容',
                    ja: '振り返る内容はまだありません',
                  ),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AuroraColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 5),
                Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Spot Tries or goals you adopt elsewhere will be collected here.',
                    zhHans: '在今天或每周复盘中采纳的小实验与目标，会汇总到这里。',
                    zhHant: '在今天或每週復盤中採納的小實驗與目標，會彙總到這裡。',
                    ja: '「今日」や週次レビューで採用した小実験と目標が、ここにまとまります。',
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AuroraColors.muted,
                        height: 1.4,
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

class _ExperimentArchiveReadOnlyNotice extends StatelessWidget {
  final _ExperimentLifecycleStage stage;

  const _ExperimentArchiveReadOnlyNotice({
    required this.stage,
  });

  @override
  Widget build(BuildContext context) {
    final isEnded = stage == _ExperimentLifecycleStage.completed;
    return Container(
      key: const ValueKey('experiment-archive-read-only-notice'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AuroraColors.mint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AuroraColors.mint.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            size: 19,
            color: AuroraColors.mint,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              isEnded
                  ? AppLocaleText.tr(
                      context,
                      en: 'This item is complete. Past records remain read-only.',
                      zhHans: '这个项目已完成，过去的记录保持只读。',
                      zhHant: '這個項目已完成，過去的記錄保持唯讀。',
                      ja: 'この項目は完了しました。過去の記録は読み取り専用です。',
                    )
                  : AppLocaleText.tr(
                      context,
                      en: 'This has not started yet. The plan stays read-only until it begins.',
                      zhHans: '这项观察还没有开始；开始前计划保持只读。',
                      zhHant: '這項觀察還沒有開始；開始前計劃保持唯讀。',
                      ja: 'この観察はまだ始まっていません。開始までは計画を読み取り専用で表示します。',
                    ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AuroraColors.ink.withValues(alpha: 0.72),
                    height: 1.4,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExperimentOriginCard extends StatelessWidget {
  final ExperimentCreationSource creationSource;
  final DateTime? adoptedAt;

  const _ExperimentOriginCard({
    required this.creationSource,
    required this.adoptedAt,
  });

  @override
  Widget build(BuildContext context) {
    final isUserCreated =
        creationSource == ExperimentCreationSource.userCreated;
    final color = isUserCreated ? AuroraColors.mint : AuroraColors.purple;
    final date = adoptedAt?.toLocal();
    final dateLabel =
        date == null ? null : '${date.year}/${date.month}/${date.day}';
    return _ExperimentGlassCard(
      key: const ValueKey('experiment-creation-origin'),
      title: AppLocaleText.tr(
        context,
        en: 'How this started',
        zhHans: '创建方式',
        zhHant: '建立方式',
        ja: '始め方',
      ),
      trailing: _StatusPill(
        label: _experimentCreationSourceLabel(context, creationSource),
        color: color,
      ),
      child: Text(
        isUserCreated
            ? AppLocaleText.tr(
                context,
                en: dateLabel == null
                    ? 'Created by you.'
                    : 'Created by you on $dateLabel.',
                zhHans: dateLabel == null ? '由你自己设定。' : '由你在 $dateLabel 自己设定。',
                zhHant: dateLabel == null ? '由你自己設定。' : '由你在 $dateLabel 自己設定。',
                ja: dateLabel == null ? '自分で設定しました。' : '$dateLabel に自分で設定しました。',
              )
            : creationSource == ExperimentCreationSource.legacyUnknown
                ? AppLocaleText.tr(
                    context,
                    en: 'This is an earlier saved plan. Its creation path was not recorded.',
                    zhHans: '这是较早保存的计划，当时没有记录创建方式。',
                    zhHant: '這是較早儲存的計劃，當時沒有記錄建立方式。',
                    ja: '以前保存した計画です。作成経路は記録されていません。',
                  )
                : AppLocaleText.tr(
                    context,
                    en: dateLabel == null
                        ? 'You adopted an AI suggestion.'
                        : 'You adopted an AI suggestion on $dateLabel.',
                    zhHans: dateLabel == null
                        ? '由智能助手提议，你确认采纳。'
                        : '智能助手提议后，由你在 $dateLabel 确认采纳。',
                    zhHant: dateLabel == null
                        ? '由智慧助手提議，你確認採納。'
                        : '智慧助手提議後，由你在 $dateLabel 確認採納。',
                    ja: dateLabel == null
                        ? '人工知能の提案をあなたが採用しました。'
                        : '$dateLabel に人工知能の提案を採用しました。',
                  ),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AuroraColors.muted,
              height: 1.45,
            ),
      ),
    );
  }
}

String _experimentCreationSourceLabel(
  BuildContext context,
  ExperimentCreationSource source,
) {
  return switch (source) {
    ExperimentCreationSource.userCreated => AppLocaleText.tr(
        context,
        en: 'Created by you',
        zhHans: '用户自建',
        zhHant: '使用者自建',
        ja: '自分で作成',
      ),
    ExperimentCreationSource.legacyUnknown => AppLocaleText.tr(
        context,
        en: 'Earlier record',
        zhHans: '历史记录',
        zhHant: '歷史記錄',
        ja: '以前の記録',
      ),
    _ => AppLocaleText.tr(
        context,
        en: 'AI suggestion · adopted',
        zhHans: '智能提议 · 已采纳',
        zhHant: '智慧提議 · 已採納',
        ja: '人工知能の提案・採用済み',
      ),
  };
}

enum _ExperimentContentKind { smallExperiment, goal }

class _ExperimentContentChangeGuide extends StatelessWidget {
  final _ExperimentContentKind kind;
  final Future<void> Function() onCreateNew;

  const _ExperimentContentChangeGuide({
    required this.kind,
    required this.onCreateNew,
  });

  @override
  Widget build(BuildContext context) {
    final isSmallExperiment = kind == _ExperimentContentKind.smallExperiment;
    return _ExperimentGlassCard(
      key: ValueKey('experiment-content-change-guide-${kind.name}'),
      title: AppLocaleText.tr(
        context,
        en: 'Want to change the content?',
        zhHans: '想调整内容？',
        zhHant: '想調整內容？',
        ja: '内容を変えたいとき',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isSmallExperiment
                ? AppLocaleText.tr(
                    context,
                    en: 'This Spot Try stays read-only so its feedback remains tied to the same action. Create a new Spot Try for a different approach.',
                    zhHans: '这条小实验保持只读，反馈才会一直对应同一种做法。想换一种做法时，请登记为新的小实验。',
                    zhHant: '這條小實驗保持唯讀，回饋才會一直對應同一種做法。想換一種做法時，請登記為新的小實驗。',
                    ja: 'この小実験は同じやり方のフィードバックを保つため読み取り専用です。別のやり方は新しい小実験として登録してください。',
                  )
                : AppLocaleText.tr(
                    context,
                    en: 'This goal stays read-only so its feedback remains tied to the same direction. Create a new goal when the direction or expected change is different.',
                    zhHans: '这条目标保持只读，反馈才会一直对应同一个观察方向。方向或想观察的变化不同，请登记为新的目标。',
                    zhHant: '這條目標保持唯讀，回饋才會一直對應同一個觀察方向。方向或想觀察的變化不同，請登記為新的目標。',
                    ja: 'この目標は同じ観察方向のフィードバックを保つため読み取り専用です。方向や見たい変化が違う場合は、新しい目標として登録してください。',
                  ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AuroraColors.muted,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: ValueKey('create-new-${kind.name}-from-detail'),
            onPressed: () => unawaited(onCreateNew()),
            icon: const Icon(Icons.add_rounded),
            label: Text(
              isSmallExperiment
                  ? AppLocaleText.tr(
                      context,
                      en: 'Create a new Spot Try',
                      zhHans: '新建小实验',
                      zhHant: '新增小實驗',
                      ja: '新しい小実験を作る',
                    )
                  : AppLocaleText.tr(
                      context,
                      en: 'Create a new goal',
                      zhHans: '新建目标',
                      zhHant: '新增目標',
                      ja: '新しい目標を作る',
                    ),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              foregroundColor:
                  isSmallExperiment ? AuroraColors.mint : AuroraColors.blue,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackOverviewEntry {
  final String id;
  final String kindLabel;
  final String overallLabel;
  final String localDate;
  final String content;
  final Color color;
  final IconData icon;
  final DateTime sortAt;

  const _FeedbackOverviewEntry({
    required this.id,
    required this.kindLabel,
    required this.overallLabel,
    required this.localDate,
    required this.content,
    required this.color,
    required this.icon,
    required this.sortAt,
  });
}

DateTime _feedbackSortTime(
  String localDate, {
  DateTime? recordedAt,
}) {
  return recordedAt ??
      DateTime.tryParse(localDate) ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

String _feedbackContentOrPlaceholder(BuildContext context, String? value) {
  final content = value?.trim() ?? '';
  if (content.isNotEmpty) return content;
  return AppLocaleText.tr(
    context,
    en: 'No additional note.',
    zhHans: '未补充内容。',
    zhHant: '未補充內容。',
    ja: '追加内容はありません。',
  );
}

class _ExperimentFeedbackOverviewCard extends StatelessWidget {
  final Key overviewKey;
  final List<_FeedbackOverviewEntry> entries;
  final String emptyText;

  const _ExperimentFeedbackOverviewCard({
    required this.overviewKey,
    required this.entries,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    final rows = [...entries]..sort((a, b) => b.sortAt.compareTo(a.sortAt));
    return _ExperimentGlassCard(
      key: overviewKey,
      title: AppLocaleText.tr(
        context,
        en: 'Feedback',
        zhHans: '反馈内容',
        zhHant: '回饋內容',
        ja: 'フィードバック',
      ),
      trailing: rows.isEmpty
          ? null
          : _StatusPill(
              label: AppLocaleText.tr(
                context,
                en: '${rows.length} item(s)',
                zhHans: '${rows.length} 条',
                zhHant: '${rows.length} 條',
                ja: '${rows.length} 件',
              ),
              color: AuroraColors.purple,
            ),
      child: rows.isEmpty
          ? Text(
              emptyText,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AuroraColors.muted,
                    height: 1.42,
                  ),
            )
          : Column(
              children: [
                for (var index = 0; index < rows.length; index++) ...[
                  _ExperimentFeedbackOverviewRow(entry: rows[index]),
                  if (index != rows.length - 1) const Divider(height: 18),
                ],
              ],
            ),
    );
  }
}

class _ExperimentFeedbackOverviewRow extends StatelessWidget {
  final _FeedbackOverviewEntry entry;

  const _ExperimentFeedbackOverviewRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: [
        entry.kindLabel,
        entry.overallLabel,
        entry.localDate,
        entry.content,
      ].join(_experimentListSeparator(context)),
      child: Row(
        key: ValueKey('feedback-overview-entry-${entry.id}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuroraSoftIconCircle(
            icon: entry.icon,
            color: entry.color,
            size: 38,
            iconSize: 19,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusPill(label: entry.kindLabel, color: entry.color),
                const SizedBox(height: 8),
                _FeedbackField(
                  label: AppLocaleText.tr(
                    context,
                    en: 'Overall',
                    zhHans: '总评',
                    zhHant: '總評',
                    ja: '総評',
                  ),
                  value: entry.overallLabel,
                ),
                const SizedBox(height: 5),
                _FeedbackField(
                  label: AppLocaleText.tr(
                    context,
                    en: 'Registered',
                    zhHans: '登记日期',
                    zhHant: '登記日期',
                    ja: '登録日',
                  ),
                  value: entry.localDate,
                ),
                const SizedBox(height: 5),
                _FeedbackField(
                  label: AppLocaleText.tr(
                    context,
                    en: 'Content',
                    zhHans: '内容',
                    zhHant: '內容',
                    ja: '内容',
                  ),
                  value: entry.content,
                  multiline: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackField extends StatelessWidget {
  final String label;
  final String value;
  final bool multiline;

  const _FeedbackField({
    required this.label,
    required this.value,
    this.multiline = false,
  });

  @override
  Widget build(BuildContext context) {
    final separator =
        AppLocaleText.resolve(context) == AppLanguage.english ? ': ' : '：';
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label$separator',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: value),
        ],
      ),
      maxLines: multiline ? null : 2,
      overflow: multiline ? TextOverflow.visible : TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AuroraColors.ink,
            height: 1.42,
          ),
    );
  }
}

class _SmallExperimentOverviewCard extends StatelessWidget {
  final MicroActionModel action;
  final int canonicalAttemptCount;
  final List<MicroActionFeedbackModel> feedbacks;
  final List<MicroActionReviewEventModel> reviews;

  const _SmallExperimentOverviewCard({
    required this.action,
    required this.canonicalAttemptCount,
    required this.feedbacks,
    required this.reviews,
  });

  @override
  Widget build(BuildContext context) {
    final completed = _completedSmallTryAttemptFeedbacks(feedbacks);
    final attemptedCount = math.max(canonicalAttemptCount, completed.length);
    final notAttemptedCount = _notAttemptedSmallTryFeedbacks(feedbacks).length;
    final rated = completed
        .where(
          (item) => SmallTryEffect.values.contains(
            normalizeSmallTryEffect(item.effect),
          ),
        )
        .toList()
      ..sort(
        (a, b) => _feedbackSortTime(
          a.localDate,
          recordedAt: a.updatedAt ?? a.createdAt,
        ).compareTo(
          _feedbackSortTime(
            b.localDate,
            recordedAt: b.updatedAt ?? b.createdAt,
          ),
        ),
      );
    final trendPoints = rated.skip(math.max(0, rated.length - 7)).map((item) {
      final date = _feedbackSortTime(
        item.localDate,
        recordedAt: item.updatedAt ?? item.createdAt,
      );
      return _TrendPoint(
        label: _dateLabel(date),
        value: _smallTryEffectChartValue(item.effect),
        date: date,
      );
    }).toList(growable: false);
    final helpful = rated
        .where(
          (item) =>
              normalizeSmallTryEffect(item.effect) == SmallTryEffect.helpful,
        )
        .length;
    final somewhat = rated
        .where(
          (item) =>
              normalizeSmallTryEffect(item.effect) ==
              SmallTryEffect.somewhatHelpful,
        )
        .length;
    final noEffect = rated
        .where(
          (item) =>
              normalizeSmallTryEffect(item.effect) == SmallTryEffect.noEffect,
        )
        .length;
    final keywords = _smallExperimentKeywords(
      context,
      action: action,
      completed: completed,
      reviews: reviews,
    );
    final summary = _smallExperimentFactualSummary(
      context,
      attemptedCount: attemptedCount,
      completed: completed,
      reviews: reviews,
    );

    return _ExperimentGlassCard(
      key: const ValueKey('small-experiment-detail-overview'),
      title: AppLocaleText.tr(
        context,
        en: 'Overview',
        zhHans: '概览',
        zhHant: '概覽',
        ja: '概要',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SmallExperimentOverviewPanel(
            key: const ValueKey('small-experiment-completion-chart'),
            title: AppLocaleText.tr(
              context,
              en: 'Attempts',
              zhHans: '完成情况',
              zhHant: '完成情況',
              ja: '実行状況',
            ),
            icon: Icons.donut_large_rounded,
            color: AuroraColors.mint,
            child: _SmallExperimentCompletionChart(
              attemptedCount: attemptedCount,
              notAttemptedCount: notAttemptedCount,
            ),
          ),
          const SizedBox(height: 12),
          _SmallExperimentOverviewPanel(
            key: const ValueKey('small-experiment-feedback-chart'),
            title: AppLocaleText.tr(
              context,
              en: 'Feedback',
              zhHans: '反馈情况',
              zhHant: '回饋情況',
              ja: 'フィードバック',
            ),
            icon: Icons.insights_rounded,
            color: AuroraColors.purple,
            child: rated.isEmpty
                ? _SmallExperimentOverviewEmpty(
                    text: AppLocaleText.tr(
                      context,
                      en: 'No effect rating has been registered yet. A chart will appear after your first rated attempt.',
                      zhHans: '还没有效果评价。完成第一次带评价的尝试后，这里会显示真实反馈图。',
                      zhHant: '還沒有效果評價。完成第一次帶評價的嘗試後，這裡會顯示真實回饋圖。',
                      ja: '効果の評価はまだありません。評価付きの試行後に、実際のフィードバック図が表示されます。',
                    ),
                  )
                : Column(
                    children: [
                      _TrendLineChart(points: trendPoints, height: 148),
                      const SizedBox(height: 8),
                      Wrap(
                        key: const ValueKey(
                          'small-experiment-feedback-count',
                        ),
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          _CompactSummaryPill(
                            icon: Icons.sentiment_satisfied_alt_rounded,
                            label: AppLocaleText.tr(
                              context,
                              en: '$helpful helpful',
                              zhHans: '有帮助 $helpful',
                              zhHant: '有幫助 $helpful',
                              ja: '役立った $helpful',
                            ),
                            color: AuroraColors.mint,
                          ),
                          _CompactSummaryPill(
                            icon: Icons.sentiment_neutral_rounded,
                            label: AppLocaleText.tr(
                              context,
                              en: '$somewhat a little',
                              zhHans: '有一点 $somewhat',
                              zhHant: '有一點 $somewhat',
                              ja: '少し $somewhat',
                            ),
                            color: AuroraColors.gold,
                          ),
                          _CompactSummaryPill(
                            icon: Icons.remove_circle_outline_rounded,
                            label: AppLocaleText.tr(
                              context,
                              en: '$noEffect no difference',
                              zhHans: '没感觉 $noEffect',
                              zhHant: '沒感覺 $noEffect',
                              ja: '変化なし $noEffect',
                            ),
                            color: AuroraColors.orange,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppLocaleText.tr(
                          context,
                          en: 'The three feedback choices are placed at high, middle, and low positions only for this chart; they are not an AI score.',
                          zhHans: '图中只把三档评价放在高、中、低位置，便于查看变化；不是智能评分。',
                          zhHant: '圖中只把三檔評價放在高、中、低位置，便於查看變化；不是智慧評分。',
                          ja: '3段階の評価を高・中・低の位置に置いて変化を示しています。人工知能による点数ではありません。',
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AuroraColors.muted,
                              height: 1.4,
                            ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          _SmallExperimentOverviewPanel(
            key: const ValueKey('small-experiment-overview-keywords'),
            title: AppLocaleText.tr(
              context,
              en: 'Keywords',
              zhHans: '关键词',
              zhHant: '關鍵詞',
              ja: 'キーワード',
            ),
            icon: Icons.auto_awesome_rounded,
            color: AuroraColors.gold,
            child: keywords.isEmpty
                ? _SmallExperimentOverviewEmpty(
                    text: AppLocaleText.tr(
                      context,
                      en: 'Keywords are still forming from the experiment content and your explicit feedback.',
                      zhHans: '关键词仍在形成，会从实验内容和你明确登记的反馈中提取。',
                      zhHant: '關鍵詞仍在形成，會從實驗內容和你明確登記的回饋中提取。',
                      ja: 'キーワードは、小実験の内容と明示的なフィードバックから形成されます。',
                    ),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final keyword in keywords)
                        _KeywordPill(
                          label: keyword.label,
                          icon: keyword.icon,
                          color: keyword.color,
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          _SmallExperimentOverviewPanel(
            key: const ValueKey('small-experiment-overview-summary'),
            title: AppLocaleText.tr(
              context,
              en: 'Summary',
              zhHans: '总结',
              zhHant: '總結',
              ja: 'まとめ',
            ),
            icon: Icons.notes_rounded,
            color: AuroraColors.blue,
            child: Text(
              summary,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AuroraColors.ink,
                    height: 1.55,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallExperimentOverviewPanel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;

  const _SmallExperimentOverviewPanel({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AuroraSoftIconCircle(
                icon: icon,
                color: color,
                size: 34,
                iconSize: 17,
              ),
              const SizedBox(width: 9),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AuroraColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SmallExperimentCompletionChart extends StatelessWidget {
  final int attemptedCount;
  final int notAttemptedCount;

  const _SmallExperimentCompletionChart({
    required this.attemptedCount,
    required this.notAttemptedCount,
  });

  @override
  Widget build(BuildContext context) {
    final total = attemptedCount + notAttemptedCount;
    if (total == 0) {
      return _SmallExperimentOverviewEmpty(
        text: AppLocaleText.tr(
          context,
          en: 'No attempt has been registered yet.',
          zhHans: '还没有登记尝试。',
          zhHant: '還沒有登記嘗試。',
          ja: '試行の登録はまだありません。',
        ),
      );
    }
    return Semantics(
      label: AppLocaleText.tr(
        context,
        en: '$attemptedCount tried, $notAttemptedCount not tried',
        zhHans: '已尝试 $attemptedCount 次，未尝试 $notAttemptedCount 次',
        zhHant: '已嘗試 $attemptedCount 次，未嘗試 $notAttemptedCount 次',
        ja: '試した $attemptedCount 回、試さなかった $notAttemptedCount 回',
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 18,
              child: Row(
                children: [
                  if (attemptedCount > 0)
                    Expanded(
                      flex: attemptedCount,
                      child: Container(color: AuroraColors.mint),
                    ),
                  if (notAttemptedCount > 0)
                    Expanded(
                      flex: notAttemptedCount,
                      child: Container(
                        color: AuroraColors.orange.withValues(alpha: 0.48),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: _SmallExperimentChartLegend(
                  color: AuroraColors.mint,
                  label: AppLocaleText.tr(
                    context,
                    en: 'Tried',
                    zhHans: '已尝试',
                    zhHant: '已嘗試',
                    ja: '試した',
                  ),
                  value: attemptedCount,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SmallExperimentChartLegend(
                  color: AuroraColors.orange,
                  label: AppLocaleText.tr(
                    context,
                    en: 'Not tried',
                    zhHans: '未尝试',
                    zhHant: '未嘗試',
                    ja: '試さなかった',
                  ),
                  value: notAttemptedCount,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              AppLocaleText.tr(
                context,
                en: 'Based on $total explicit registration(s); no seven-day denominator is added.',
                zhHans: '基于 $total 条明确登记，不再套用固定七日分母。',
                zhHant: '基於 $total 條明確登記，不再套用固定七日分母。',
                ja: '$total 件の明示的な登録に基づき、固定の7日分母は使いません。',
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AuroraColors.muted,
                    height: 1.4,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallExperimentChartLegend extends StatelessWidget {
  final Color color;
  final String label;
  final int value;

  const _SmallExperimentChartLegend({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AuroraColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Text(
            '$value',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AuroraColors.ink,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _SmallExperimentOverviewEmpty extends StatelessWidget {
  final String text;

  const _SmallExperimentOverviewEmpty({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AuroraColors.muted,
            height: 1.45,
          ),
    );
  }
}

List<MicroActionFeedbackModel> _notAttemptedSmallTryFeedbacks(
  Iterable<MicroActionFeedbackModel> feedbacks,
) {
  const aliases = {
    'no',
    'not_happened',
    'not_done',
    'not_completed',
    'not_attempted',
    'false',
    'skipped',
  };
  return feedbacks
      .where(
        (feedback) =>
            feedback.isValid &&
            aliases.contains(feedback.happened.trim().toLowerCase()),
      )
      .toList(growable: false);
}

double _smallTryEffectChartValue(String raw) {
  return switch (normalizeSmallTryEffect(raw)) {
    SmallTryEffect.helpful => 5,
    SmallTryEffect.somewhatHelpful => 3,
    SmallTryEffect.noEffect => 1,
    _ => 3,
  };
}

List<_KeywordData> _smallExperimentKeywords(
  BuildContext context, {
  required MicroActionModel action,
  required List<MicroActionFeedbackModel> completed,
  required List<MicroActionReviewEventModel> reviews,
}) {
  final keywords = <_KeywordData>[];
  void add(String label, IconData icon, Color color) {
    if (keywords.any((item) => item.label == label)) return;
    keywords.add(_KeywordData(label, icon, color));
  }

  final source = [
    action.title,
    action.reason,
    ...completed.map((item) => item.userNote ?? ''),
    ...reviews.map((item) => item.note ?? ''),
  ].join(' ').toLowerCase();

  void addSemantic({
    required List<String> matches,
    required String Function() label,
    required IconData icon,
    required Color color,
  }) {
    if (matches.any(source.contains)) add(label(), icon, color);
  }

  addSemantic(
    matches: const ['睡', 'sleep', '眠り', '睡眠'],
    label: () => AppLocaleText.tr(
      context,
      en: 'Sleep',
      zhHans: '睡眠',
      zhHant: '睡眠',
      ja: '睡眠',
    ),
    icon: Icons.nights_stay_rounded,
    color: AuroraColors.blue,
  );
  addSemantic(
    matches: const ['放松', '放鬆', '恢复', '恢復', '缓冲', '緩衝', 'relax', 'recover'],
    label: () => AppLocaleText.tr(
      context,
      en: 'Recovery',
      zhHans: '恢复',
      zhHant: '恢復',
      ja: '回復',
    ),
    icon: Icons.spa_rounded,
    color: AuroraColors.mint,
  );
  addSemantic(
    matches: const ['切换', '切換', 'switch', '转场', '轉場'],
    label: () => AppLocaleText.tr(
      context,
      en: 'Transition',
      zhHans: '切换缓冲',
      zhHant: '切換緩衝',
      ja: '切り替え',
    ),
    icon: Icons.swap_horiz_rounded,
    color: AuroraColors.purple,
  );
  addSemantic(
    matches: const ['开始', '開始', 'start', '着手', '始め'],
    label: () => AppLocaleText.tr(
      context,
      en: 'Easier to start',
      zhHans: '更容易开始',
      zhHant: '更容易開始',
      ja: '始めやすい',
    ),
    icon: Icons.play_arrow_rounded,
    color: AuroraColors.blue,
  );
  addSemantic(
    matches: const ['压力', '壓力', '负担', '負擔', 'pressure', 'stress'],
    label: () => AppLocaleText.tr(
      context,
      en: 'Effort',
      zhHans: '负担变化',
      zhHant: '負擔變化',
      ja: '負担の変化',
    ),
    icon: Icons.speed_rounded,
    color: AuroraColors.orange,
  );

  final helpful = completed.where(
    (item) => normalizeSmallTryEffect(item.effect) == SmallTryEffect.helpful,
  );
  final easy = completed.where(
    (item) =>
        normalizeSmallTryDifficulty(item.difficulty) == SmallTryDifficulty.easy,
  );
  if (helpful.isNotEmpty) {
    add(
      AppLocaleText.tr(
        context,
        en: 'Helpful',
        zhHans: '有帮助',
        zhHant: '有幫助',
        ja: '役立った',
      ),
      Icons.auto_awesome_rounded,
      AuroraColors.mint,
    );
  }
  if (easy.isNotEmpty) {
    add(
      AppLocaleText.tr(
        context,
        en: 'Light effort',
        zhHans: '负担较轻',
        zhHant: '負擔較輕',
        ja: '負担が軽い',
      ),
      Icons.air_rounded,
      AuroraColors.gold,
    );
  }
  return keywords.take(4).toList(growable: false);
}

String _smallExperimentFactualSummary(
  BuildContext context, {
  required int attemptedCount,
  required List<MicroActionFeedbackModel> completed,
  required List<MicroActionReviewEventModel> reviews,
}) {
  if (attemptedCount == 0) {
    return AppLocaleText.tr(
      context,
      en: 'There is no real attempt yet, so no result is inferred.',
      zhHans: '还没有真实尝试记录，暂时不推断结果。',
      zhHant: '還沒有真實嘗試記錄，暫時不推斷結果。',
      ja: '実際の試行記録がないため、結果はまだ推測しません。',
    );
  }

  final helpful = completed
      .where(
        (item) =>
            normalizeSmallTryEffect(item.effect) == SmallTryEffect.helpful,
      )
      .length;
  final somewhat = completed
      .where(
        (item) =>
            normalizeSmallTryEffect(item.effect) ==
            SmallTryEffect.somewhatHelpful,
      )
      .length;
  final noEffect = completed
      .where(
        (item) =>
            normalizeSmallTryEffect(item.effect) == SmallTryEffect.noEffect,
      )
      .length;
  final ratedCount = helpful + somewhat + noEffect;
  final difficultyCounts = <String, int>{
    SmallTryDifficulty.easy: 0,
    SmallTryDifficulty.okay: 0,
    SmallTryDifficulty.difficult: 0,
  };
  for (final item in completed.where(
    (entry) => SmallTryEffect.values.contains(
      normalizeSmallTryEffect(entry.effect),
    ),
  )) {
    final normalized = normalizeSmallTryDifficulty(item.difficulty);
    if (difficultyCounts.containsKey(normalized)) {
      difficultyCounts[normalized] = difficultyCounts[normalized]! + 1;
    }
  }
  final parts = <String>[
    AppLocaleText.tr(
      context,
      en: '$attemptedCount real attempt(s) have been recorded.',
      zhHans: '已记录 $attemptedCount 次真实尝试。',
      zhHant: '已記錄 $attemptedCount 次真實嘗試。',
      ja: '実際の試行を $attemptedCount 回記録しました。',
    ),
  ];
  if (ratedCount > 0) {
    parts.add(
      AppLocaleText.tr(
        context,
        en: 'Among explicit ratings: $helpful helpful, $somewhat a little helpful, and $noEffect no difference.',
        zhHans: '明确评价中：有帮助 $helpful 次、有一点 $somewhat 次、没感觉 $noEffect 次。',
        zhHant: '明確評價中：有幫助 $helpful 次、有一點 $somewhat 次、沒感覺 $noEffect 次。',
        ja: '明示的な評価は、役立った $helpful 回、少し役立った $somewhat 回、変化なし $noEffect 回です。',
      ),
    );
  } else {
    parts.add(
      AppLocaleText.tr(
        context,
        en: 'There is not enough explicit effect feedback to summarize the result.',
        zhHans: '明确的效果反馈还不足，暂不判断是否有效。',
        zhHant: '明確的效果回饋還不足，暫不判斷是否有效。',
        ja: '効果についての明示的なフィードバックが不足しているため、有効性はまだ判断しません。',
      ),
    );
  }
  if (difficultyCounts.values.any((count) => count > 0)) {
    final leading = difficultyCounts.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );
    parts.add(
      switch (leading.key) {
        SmallTryDifficulty.easy => AppLocaleText.tr(
            context,
            en: 'Most recorded effort ratings were easy.',
            zhHans: '已登记的负担反馈以轻松为主。',
            zhHant: '已登記的負擔回饋以輕鬆為主。',
            ja: '登録された負担評価は「軽い」が中心です。',
          ),
        SmallTryDifficulty.difficult => AppLocaleText.tr(
            context,
            en: 'Most recorded effort ratings were demanding.',
            zhHans: '已登记的负担反馈以偏费力为主。',
            zhHant: '已登記的負擔回饋以偏費力為主。',
            ja: '登録された負担評価は「やや重い」が中心です。',
          ),
        _ => AppLocaleText.tr(
            context,
            en: 'Most recorded effort ratings were manageable.',
            zhHans: '已登记的负担反馈以还好为主。',
            zhHant: '已登記的負擔回饋以還好為主。',
            ja: '登録された負担評価は「普通」が中心です。',
          ),
      },
    );
  }

  final reviewsByTime = [...reviews]
    ..sort((a, b) => a.reviewedAt.compareTo(b.reviewedAt));
  final latestReviewNote =
      reviewsByTime.isEmpty ? '' : (reviewsByTime.last.note?.trim() ?? '');
  if (latestReviewNote.isNotEmpty) {
    parts.add(
      AppLocaleText.tr(
        context,
        en: 'Latest round summary: $latestReviewNote',
        zhHans: '最近一轮总结：$latestReviewNote',
        zhHant: '最近一輪總結：$latestReviewNote',
        ja: '最新のラウンドまとめ：$latestReviewNote',
      ),
    );
  }
  return parts.join(' ');
}

class _SmallExperimentFeedbackOverviewCard extends StatelessWidget {
  final List<MicroActionFeedbackModel> feedbacks;
  final List<MicroActionReviewEventModel> reviews;

  const _SmallExperimentFeedbackOverviewCard({
    required this.feedbacks,
    required this.reviews,
  });

  @override
  Widget build(BuildContext context) {
    final entries = <_FeedbackOverviewEntry>[];
    for (final feedback in _completedSmallTryAttemptFeedbacks(feedbacks)) {
      final effect = normalizeSmallTryEffect(feedback.effect);
      final hasEffect = SmallTryEffect.values.contains(effect);
      final hasNote = feedback.userNote?.trim().isNotEmpty == true;
      if (!hasEffect && !hasNote) continue;
      final difficulty = normalizeSmallTryDifficulty(feedback.difficulty);
      final difficultyLabel = SmallTryDifficulty.values.contains(difficulty)
          ? _smallTryDifficultyLabel(context, difficulty)
          : AppLocaleText.tr(
              context,
              en: 'Effort not recorded',
              zhHans: '负担未记录',
              zhHant: '負擔未記錄',
              ja: '負担は未記録',
            );
      final effectLabel = hasEffect
          ? _smallTryEffectLabel(context, effect)
          : AppLocaleText.tr(
              context,
              en: 'No overall rating yet',
              zhHans: '尚未形成总评',
              zhHant: '尚未形成總評',
              ja: '総評はまだありません',
            );
      entries.add(
        _FeedbackOverviewEntry(
          id: 'attempt-${feedback.id}',
          kindLabel: AppLocaleText.tr(
            context,
            en: 'Immediate feedback',
            zhHans: '即时反馈',
            zhHant: '即時回饋',
            ja: 'その場のフィードバック',
          ),
          overallLabel: '$effectLabel · $difficultyLabel',
          localDate: feedback.localDate,
          content: _feedbackContentOrPlaceholder(context, feedback.userNote),
          color: hasEffect ? _smallTryEffectColor(effect) : AuroraColors.blue,
          icon: Icons.bolt_rounded,
          sortAt: _feedbackSortTime(
            feedback.localDate,
            recordedAt: feedback.updatedAt ?? feedback.createdAt,
          ),
        ),
      );
    }
    for (final review in reviews) {
      entries.add(
        _FeedbackOverviewEntry(
          id: 'review-${review.id}',
          kindLabel: AppLocaleText.tr(
            context,
            en: 'Round summary',
            zhHans: '轮次总评',
            zhHant: '輪次總評',
            ja: 'ラウンド総評',
          ),
          overallLabel:
              '${_smallTryRoundResultLabel(context, review.result)} · '
              '${_goalBurdenLabel(context, review.effort)}',
          localDate: review.localDate,
          content: _feedbackContentOrPlaceholder(context, review.note),
          color: AuroraColors.mint,
          icon: Icons.fact_check_outlined,
          sortAt: _feedbackSortTime(
            review.localDate,
            recordedAt: review.reviewedAt,
          ),
        ),
      );
    }
    return _ExperimentFeedbackOverviewCard(
      overviewKey: const ValueKey('small-experiment-feedback-overview'),
      entries: entries,
      emptyText: AppLocaleText.tr(
        context,
        en: 'No feedback has been registered yet. Daily progress without a rating remains in Today and Weekly Review.',
        zhHans: '还没有登记反馈。只有完成情况、没有评价的日常进度仍保留在今天和每周复盘。',
        zhHant: '還沒有登記回饋。只有完成情況、沒有評價的日常進度仍保留在今天和每週回顧。',
        ja: 'フィードバックはまだありません。評価のない日々の進捗は「今日」と「毎週の振り返り」に残ります。',
      ),
    );
  }
}

class _SmallTryDetailCard extends StatelessWidget {
  final AdoptedMicroActionProgress item;
  final _ExperimentLifecycleStage stage;
  final List<MicroActionFeedbackModel> feedbacks;
  final MicroActionReviewEventModel? latestReview;

  const _SmallTryDetailCard({
    required this.item,
    required this.stage,
    required this.feedbacks,
    required this.latestReview,
  });

  @override
  Widget build(BuildContext context) {
    final action = item.action;
    final color = _lifecycleStageColor(stage);
    final attempts = _completedSmallTryAttemptFeedbacks(feedbacks);
    final attemptCount = item.progress.completedAttempts;
    return AuroraCard(
      key: ValueKey('small-try-detail-${action.id}'),
      padding: AuroraMainPageSpec.cardPadding,
      borderRadius: BorderRadius.circular(AuroraMainPageSpec.cardRadiusLarge),
      color: Colors.white.withValues(alpha: 0.74),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AuroraSoftIconCircle(
                icon: _lifecycleStageIcon(stage),
                color: color,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  action.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AuroraColors.ink,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                ),
              ),
              _StatusPill(
                label: _lifecycleStageLabel(context, stage),
                color: color,
              ),
            ],
          ),
          if (action.reason.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              action.reason.trim(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AuroraColors.muted,
                    height: 1.5,
                  ),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            AppLocaleText.tr(
              context,
              en: 'Spot Try · start anytime',
              zhHans: '简单尝试 · 随时可试',
              zhHant: '簡單嘗試 · 隨時可試',
              ja: 'スポットトライ · いつでも始められる',
            ),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AuroraColors.mint,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _SmallTryAttemptPoints(feedbacks: attempts),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: '$attemptCount attempts this round',
                    zhHans: '本轮尝试 $attemptCount 次',
                    zhHant: '本輪嘗試 $attemptCount 次',
                    ja: '今回 $attemptCount 回試行',
                  ),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _CompactSummaryPill(
                icon: Icons.auto_awesome_rounded,
                label: _smallTryEffectSummary(context, attempts),
                color: AuroraColors.mint,
              ),
              _CompactSummaryPill(
                icon: Icons.speed_rounded,
                label: _smallTryEffortSummary(context, attempts),
                color: AuroraColors.orange,
              ),
              if (latestReview != null)
                _CompactSummaryPill(
                  icon: Icons.bookmark_added_rounded,
                  label: _smallTryRoundResultLabel(
                    context,
                    latestReview!.result,
                  ),
                  color: AuroraColors.purple,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallTryArchiveSection extends StatelessWidget {
  final List<AdoptedMicroActionProgress> items;
  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;

  const _SmallTryArchiveSection({
    required this.items,
    required this.hasMore,
    required this.isLoadingMore,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('life-experiment-small-tries-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LifeExperimentTrackHeading(
          icon: Icons.spa_rounded,
          color: AuroraColors.mint,
          title: AppLocaleText.tr(
            context,
            en: 'Spot Tries',
            zhHans: '小实验',
            zhHant: '小實驗',
            ja: '小実験',
          ),
          description: AppLocaleText.tr(
            context,
            en: 'Spot Tries can start right away, stay low-cost, and pause at any time.',
            zhHans: '简单尝试现在就能开始、成本很低，也可以随时暂停。',
            zhHant: '簡單嘗試現在就能開始、成本很低，也可以隨時暫停。',
            ja: 'スポットトライは今すぐ始められ、負担が少なく、いつでも止められます。',
          ),
          count: items.length,
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          AuroraCard(
            key: const ValueKey('life-experiment-small-tries-empty'),
            padding: AuroraMainPageSpec.cardPadding,
            borderRadius:
                BorderRadius.circular(AuroraMainPageSpec.cardRadiusLarge),
            color: Colors.white.withValues(alpha: 0.66),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AuroraSoftIconCircle(
                  icon: Icons.spa_outlined,
                  color: AuroraColors.mint,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppLocaleText.tr(
                      context,
                      en: 'No adopted Spot Tries yet. After 3 eligible signals today, you can choose one that fits.',
                      zhHans: '还没有采纳的小实验。今天积累 3 条有效信号后，可以选择适合当下的一项。',
                      zhHant: '還沒有採納的小實驗。今天累積 3 條有效信號後，可以選擇適合當下的一項。',
                      ja: '採用した小実験はまだありません。今日の有効なシグナルが3件になると、合うものを選べます。',
                    ),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AuroraColors.muted,
                          height: 1.45,
                        ),
                  ),
                ),
              ],
            ),
          )
        else
          for (var index = 0; index < items.length; index++) ...[
            _SmallTryArchiveCard(
              item: items[index],
            ),
            if (index != items.length - 1)
              const SizedBox(height: AuroraMainPageSpec.sectionGap),
          ],
        if (hasMore || isLoadingMore) ...[
          const SizedBox(height: 10),
          _ArchiveLoadMoreButton(
            key: const ValueKey('life-experiment-small-tries-load-more'),
            isLoading: isLoadingMore,
            onPressed: isLoadingMore ? null : onLoadMore,
          ),
        ],
      ],
    );
  }
}

class _ArchiveLoadMoreButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;

  const _ArchiveLoadMoreButton({
    super.key,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final label = isLoading
        ? AppLocaleText.tr(
            context,
            en: 'Loading…',
            zhHans: '正在加载…',
            zhHant: '正在載入…',
            ja: '読み込み中…',
          )
        : AppLocaleText.tr(
            context,
            en: 'Load more',
            zhHans: '加载更多',
            zhHant: '載入更多',
            ja: 'さらに読み込む',
          );
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: isLoading
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.expand_more_rounded),
        label: Text(label),
      ),
    );
  }
}

class _LifeExperimentGoalHeading extends StatelessWidget {
  const _LifeExperimentGoalHeading();

  @override
  Widget build(BuildContext context) {
    return _LifeExperimentTrackHeading(
      icon: Icons.flag_rounded,
      color: AuroraColors.purple,
      title: AppLocaleText.tr(
        context,
        en: 'Goals',
        zhHans: '目标',
        zhHant: '目標',
        ja: '目標',
      ),
      description: AppLocaleText.tr(
        context,
        en: 'Projects repeated for several days before you judge their effect.',
        zhHans: '需要连续多日坚持，再根据真实反馈判断效果的项目。',
        zhHant: '需要連續多日維持，再根據真實回饋判斷效果的項目。',
        ja: '数日続け、実際の記録から効果を確かめる取り組みです。',
      ),
    );
  }
}

class _LifeExperimentTrackHeading extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final int? count;

  const _LifeExperimentTrackHeading({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AuroraSectionIcon(icon: icon, color: color, size: 40),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AuroraColors.ink,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  if (count != null)
                    Text(
                      '$count',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AuroraColors.muted,
                      height: 1.4,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SmallTryArchiveCard extends StatelessWidget {
  final AdoptedMicroActionProgress item;

  const _SmallTryArchiveCard({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final action = item.action;
    return AuroraCard(
      key: ValueKey('life-experiment-small-try-${action.id}'),
      padding: AuroraMainPageSpec.cardPadding,
      borderRadius: BorderRadius.circular(AuroraMainPageSpec.cardRadiusLarge),
      color: Colors.white.withValues(alpha: 0.72),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AuroraSoftIconCircle(
                icon: Icons.spa_rounded,
                color: AuroraColors.mint,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AuroraColors.ink,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _smallTryStatusLabel(context, action),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AuroraColors.mint,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (action.reason.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              action.reason,
              key: ValueKey('life-experiment-small-try-${action.id}-reason'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AuroraColors.muted,
                    height: 1.4,
                  ),
            ),
          ],
          const SizedBox(height: 8),
          _SmallTryOriginMetadata(action: action),
        ],
      ),
    );
  }
}

class _SmallTryOriginMetadata extends StatelessWidget {
  final MicroActionModel action;

  const _SmallTryOriginMetadata({required this.action});

  @override
  Widget build(BuildContext context) {
    final adoptedAt = action.adoptedAt;
    final adoptedLabel = adoptedAt == null
        ? AppLocaleText.tr(
            context,
            en: 'Adoption date not recorded',
            zhHans: '采纳日未记录',
            zhHant: '採納日未記錄',
            ja: '採用日は未記録',
          )
        : AppLocaleText.tr(
            context,
            en: 'Adopted ${adoptedAt.toLocal().year}/${adoptedAt.toLocal().month}/${adoptedAt.toLocal().day}',
            zhHans:
                '采纳于 ${adoptedAt.toLocal().year}/${adoptedAt.toLocal().month}/${adoptedAt.toLocal().day}',
            zhHant:
                '採納於 ${adoptedAt.toLocal().year}/${adoptedAt.toLocal().month}/${adoptedAt.toLocal().day}',
            ja: '${adoptedAt.toLocal().year}/${adoptedAt.toLocal().month}/${adoptedAt.toLocal().day} に採用',
          );
    final sourceLabel =
        _experimentCreationSourceLabel(context, action.creationSource);
    return Wrap(
      spacing: 12,
      runSpacing: 5,
      children: [
        _SmallTryMetadataLabel(
          icon: Icons.event_available_rounded,
          label: adoptedLabel,
        ),
        _SmallTryMetadataLabel(
          icon: action.creationSource == ExperimentCreationSource.userCreated
              ? Icons.edit_note_rounded
              : Icons.auto_awesome_rounded,
          label: sourceLabel,
        ),
      ],
    );
  }
}

class _SmallTryMetadataLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SmallTryMetadataLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AuroraColors.muted),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AuroraColors.muted,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }
}

String _smallTryStatusLabel(
  BuildContext context,
  MicroActionModel action,
) {
  final status = action.status.trim().toLowerCase();
  final isEnded = status.contains('complete') ||
      status.contains('done') ||
      status.contains('archive') ||
      status.contains('stop');
  return AppLocaleText.tr(
    context,
    en: isEnded ? 'Completed Spot Try' : 'Spot Try in progress',
    zhHans: isEnded ? '已完成的小实验' : '进行中的小实验',
    zhHant: isEnded ? '已完成的小實驗' : '進行中的小實驗',
    ja: isEnded ? '完了した小実験' : '進行中の小実験',
  );
}

class _ExperimentArchiveHeroHeader extends StatelessWidget {
  final bool canPop;
  final VoidCallback onBack;
  final int activeCount;
  final int feedbackCount;
  final int conclusionCount;

  const _ExperimentArchiveHeroHeader({
    required this.canPop,
    required this.onBack,
    required this.activeCount,
    required this.feedbackCount,
    required this.conclusionCount,
  });

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < AuroraMainPageSpec.compactBreakpoint;
    final isEnglish = Localizations.localeOf(context).languageCode == 'en';
    final contentTop = canPop ? 46.0 : 0.0;

    return AuroraCard(
      key: const ValueKey('experiment-hero-header'),
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(24),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFFFFFBF6).withValues(alpha: 0.92),
          const Color(0xFFF5F0FF).withValues(alpha: 0.84),
          const Color(0xFFEEF5FF).withValues(alpha: 0.78),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: canPop ? 232 : 200,
          ),
          child: Stack(
            children: [
              Positioned(
                right: compact ? -16 : -12,
                top: canPop ? 34 : -10,
                width: compact ? 180 : 200,
                height: compact ? 128 : 142,
                child: const IgnorePointer(
                  child: AuroraExperimentHeroPattern(opacity: 0.82),
                ),
              ),
              if (canPop)
                Positioned(
                  left: 4,
                  top: 4,
                  child: IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    color: AuroraColors.ink,
                    tooltip: AppLocaleText.tr(
                      context,
                      en: 'Back',
                      zhHans: '返回',
                      zhHant: '返回',
                      ja: '戻る',
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 14 : 16,
                  contentTop + (compact ? 13 : 15),
                  compact ? 14 : 16,
                  compact ? 12 : 14,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(
                        right: isEnglish
                            ? (compact ? 40 : 56)
                            : (compact ? 78 : 108),
                      ),
                      child: AuroraHeroTitle(
                        text: AppLocaleText.tr(
                          context,
                          en: 'Life Experiment',
                          zhHans: '生活小实验',
                          zhHant: '生活小實驗',
                          ja: '生活実験',
                        ),
                        fontSize:
                            AuroraMainPageSpec.responsiveHeroTitleSize(context),
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: EdgeInsets.only(
                        right: compact ? 82 : 116,
                      ),
                      child: Text(
                        AppLocaleText.tr(
                          context,
                          en: 'See how Spot Tries and longer goals are unfolding.',
                          zhHans: '查看小实验与目标正在怎样展开，以及真实反馈留下了什么。',
                          zhHant: '查看小實驗與目標正在怎樣展開，以及真實回饋留下了什麼。',
                          ja: '小実験と目標の進み方、実際の反応を見返します。',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AuroraColors.ink.withValues(alpha: 0.72),
                              fontSize: AuroraMainPageSpec.heroSubtitleSize,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          child: _ExperimentHeroMetric(
                            key: const ValueKey(
                              'experiment-hero-active-count',
                            ),
                            icon: Icons.play_arrow_rounded,
                            label: AppLocaleText.tr(
                              context,
                              en: 'Active',
                              zhHans: '进行中',
                              zhHant: '進行中',
                              ja: '進行中',
                            ),
                            value: '$activeCount',
                            color: AuroraColors.purple,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ExperimentHeroMetric(
                            key: const ValueKey(
                              'experiment-hero-feedback-count',
                            ),
                            icon: Icons.bubble_chart_outlined,
                            label: AppLocaleText.tr(
                              context,
                              en: 'Feedback',
                              zhHans: '真实反馈',
                              zhHant: '真實回饋',
                              ja: '実際の反応',
                            ),
                            value: '$feedbackCount',
                            color: AuroraColors.mint,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ExperimentHeroMetric(
                            key: const ValueKey(
                              'experiment-hero-conclusion-count',
                            ),
                            icon: Icons.auto_awesome_rounded,
                            label: AppLocaleText.tr(
                              context,
                              en: 'Results',
                              zhHans: '已有结论',
                              zhHant: '已有結論',
                              ja: '結論あり',
                            ),
                            value: '$conclusionCount',
                            color: AuroraColors.gold,
                          ),
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

class _ExperimentHeroMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ExperimentHeroMetric({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;
    final isEnglish = languageCode == 'en';
    final isJapanese = languageCode == 'ja';
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: EdgeInsets.symmetric(
        horizontal: isEnglish
            ? 6
            : isJapanese
                ? 7
                : 9,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: isEnglish ? 24 : 28,
            height: isEnglish ? 24 : 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: isEnglish ? 14 : 16, color: color),
          ),
          SizedBox(
            width: isEnglish
                ? 4
                : isJapanese
                    ? 5
                    : 7,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AuroraColors.muted,
                        fontSize: isEnglish
                            ? 9.2
                            : isJapanese
                                ? 9.5
                                : 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: color,
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

class _ExperimentSearchBar extends StatelessWidget {
  final TextEditingController controller;

  const _ExperimentSearchBar({
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('experiment-search-bar'),
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
        boxShadow: [
          BoxShadow(
            color: AuroraColors.purple.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(Icons.search_rounded, color: AuroraColors.muted, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              onEditingComplete: () =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              decoration: InputDecoration(
                hintText: AppLocaleText.tr(
                  context,
                  en: 'Search Spot Tries or goals...',
                  zhHans: '搜索小实验或目标...',
                  zhHant: '搜尋小實驗或目標...',
                  ja: '小実験や目標を検索...',
                ),
                border: InputBorder.none,
                hintStyle: TextStyle(
                  color: AuroraColors.muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              onPressed: controller.clear,
              icon: const Icon(Icons.close_rounded),
              color: AuroraColors.muted,
              tooltip: AppLocaleText.tr(
                context,
                en: 'Clear search',
                zhHans: '清除搜索',
                zhHant: '清除搜尋',
                ja: '検索をクリア',
              ),
            )
          else
            const SizedBox(width: 14),
        ],
      ),
    );
  }
}

class _ExperimentCreateEntryCard extends StatelessWidget {
  final VoidCallback onCreateSmallExperiment;
  final VoidCallback onCreateGoal;

  const _ExperimentCreateEntryCard({
    required this.onCreateSmallExperiment,
    required this.onCreateGoal,
  });

  @override
  Widget build(BuildContext context) {
    return AuroraCard(
      key: const ValueKey('experiment-create-entry-card'),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      borderRadius: BorderRadius.circular(18),
      color: Colors.white.withValues(alpha: 0.64),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocaleText.tr(
              context,
              en: 'Start with your own idea',
              zhHans: '也可以从自己的想法开始',
              zhHant: '也可以從自己的想法開始',
              ja: '自分のアイデアから始める',
            ),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AuroraColors.ink,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              Widget smallExperimentButton() => FilledButton.tonalIcon(
                    key: const ValueKey('create-small-experiment-entry'),
                    onPressed: onCreateSmallExperiment,
                    icon: const Icon(Icons.spa_rounded, size: 18),
                    label: Text(
                      AppLocaleText.tr(
                        context,
                        en: 'New Spot Try',
                        zhHans: '新建小实验',
                        zhHant: '新增小實驗',
                        ja: '小実験を作る',
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      foregroundColor: AuroraColors.mint,
                      backgroundColor:
                          AuroraColors.mint.withValues(alpha: 0.11),
                    ),
                  );
              Widget goalButton() => FilledButton.tonalIcon(
                    key: const ValueKey('create-goal-entry'),
                    onPressed: onCreateGoal,
                    icon: const Icon(Icons.flag_rounded, size: 18),
                    label: Text(
                      AppLocaleText.tr(
                        context,
                        en: 'New goal',
                        zhHans: '新建目标',
                        zhHant: '新增目標',
                        ja: '目標を作る',
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      foregroundColor: AuroraColors.purple,
                      backgroundColor:
                          AuroraColors.purple.withValues(alpha: 0.10),
                    ),
                  );
              if (constraints.maxWidth < 330) {
                return Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: smallExperimentButton(),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(width: double.infinity, child: goalButton()),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: smallExperimentButton()),
                  const SizedBox(width: 8),
                  Expanded(child: goalButton()),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _UserSmallExperimentDraft {
  final String title;
  final String description;
  final int durationMinutes;

  const _UserSmallExperimentDraft({
    required this.title,
    required this.description,
    required this.durationMinutes,
  });
}

class _UserGoalDraft {
  final String title;
  final String hypothesis;
  final String suggestedAction;
  final String plannedFrequency;
  final int observationDays;

  const _UserGoalDraft({
    required this.title,
    required this.hypothesis,
    required this.suggestedAction,
    required this.plannedFrequency,
    required this.observationDays,
  });
}

class _CreateSmallExperimentPage extends StatefulWidget {
  final Future<void> Function(_UserSmallExperimentDraft draft) onSubmit;

  const _CreateSmallExperimentPage({required this.onSubmit});

  @override
  State<_CreateSmallExperimentPage> createState() =>
      _CreateSmallExperimentPageState();
}

class _CreateSmallExperimentPageState
    extends State<_CreateSmallExperimentPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  var _durationMinutes = 5;
  var _saving = false;
  String? _saveError;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false) || _saving) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await widget.onSubmit(
        _UserSmallExperimentDraft(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          durationMinutes: _durationMinutes,
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = AppLocaleText.tr(
          context,
          en: 'Could not create this Spot Try. Please try again.',
          zhHans: '暂时无法创建这个小实验，请再试一次。',
          zhHant: '暫時無法建立這個小實驗，請再試一次。',
          ja: '小実験を作成できませんでした。もう一度お試しください。',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ExperimentCreationScaffold(
      title: AppLocaleText.tr(
        context,
        en: 'New Spot Try',
        zhHans: '新建小实验',
        zhHant: '新增小實驗',
        ja: '小実験を作る',
      ),
      subtitle: AppLocaleText.tr(
        context,
        en: 'Define one Spot Try you can start right away.',
        zhHans: '设定一个现在就能开始的简单尝试。',
        zhHant: '設定一個現在就能開始的簡單嘗試。',
        ja: '今すぐ始められるスポットトライを設定します。',
      ),
      icon: Icons.spa_rounded,
      accent: AuroraColors.mint,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ExperimentCreationField(
              controller: _titleController,
              label: AppLocaleText.tr(
                context,
                en: 'What will you try?',
                zhHans: '想试什么？',
                zhHant: '想試什麼？',
                ja: '何を試しますか？',
              ),
              hint: AppLocaleText.tr(
                context,
                en: 'For example: pause for two minutes before switching tasks',
                zhHans: '例如：切换任务前停两分钟',
                zhHant: '例如：切換任務前停兩分鐘',
                ja: '例：タスクを切り替える前に2分休む',
              ),
              maxLength: 80,
              validator: (value) => value == null || value.trim().isEmpty
                  ? AppLocaleText.tr(
                      context,
                      en: 'Enter a name for this Spot Try.',
                      zhHans: '请填写小实验名称。',
                      zhHant: '請填寫小實驗名稱。',
                      ja: '小実験の名前を入力してください。',
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            _ExperimentCreationField(
              controller: _descriptionController,
              label: AppLocaleText.tr(
                context,
                en: 'What do you want to notice? (optional)',
                zhHans: '想留意什么？（可选）',
                zhHant: '想留意什麼？（可選）',
                ja: '何に注目しますか？（任意）',
              ),
              hint: AppLocaleText.tr(
                context,
                en: 'Add the situation or change you want to notice',
                zhHans: '补充想尝试的场景或想留意的变化',
                zhHant: '補充想嘗試的場景或想留意的變化',
                ja: '試す場面や、見ておきたい変化を追加',
              ),
              maxLength: 160,
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocaleText.tr(
                context,
                en: 'Time for one attempt',
                zhHans: '单次所需时间',
                zhHant: '單次所需時間',
                ja: '1回にかかる時間',
              ),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AuroraColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              key: const ValueKey('small-experiment-duration'),
              initialValue: _durationMinutes,
              decoration: _experimentCreationInputDecoration(context),
              items: [
                for (var minutes = 1; minutes <= 10; minutes++)
                  DropdownMenuItem(
                    value: minutes,
                    child: Text(
                      AppLocaleText.tr(
                        context,
                        en: '$minutes min',
                        zhHans: '$minutes 分钟',
                        zhHant: '$minutes 分鐘',
                        ja: '$minutes 分',
                      ),
                    ),
                  ),
              ],
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _durationMinutes = value);
                      }
                    },
            ),
            const SizedBox(height: 8),
            _CreationBoundaryNote(
              text: AppLocaleText.tr(
                context,
                en: 'A Spot Try must stay between 1 and 10 minutes per attempt.',
                zhHans: '小实验每次必须控制在 1–10 分钟内。',
                zhHant: '小實驗每次必須控制在 1–10 分鐘內。',
                ja: '小実験は1回1〜10分の範囲で設定します。',
              ),
              color: AuroraColors.mint,
            ),
            if (_saveError != null) ...[
              const SizedBox(height: 12),
              Text(
                _saveError!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AuroraColors.orange,
                    ),
              ),
            ],
            const SizedBox(height: 22),
            _ExperimentCreationSubmitButton(
              key: const ValueKey('save-user-small-experiment'),
              isSaving: _saving,
              color: AuroraColors.mint,
              label: AppLocaleText.tr(
                context,
                en: 'Create Spot Try',
                zhHans: '创建小实验',
                zhHant: '建立小實驗',
                ja: '小実験を作成',
              ),
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateGoalPage extends StatefulWidget {
  final Future<void> Function(_UserGoalDraft draft) onSubmit;

  const _CreateGoalPage({required this.onSubmit});

  @override
  State<_CreateGoalPage> createState() => _CreateGoalPageState();
}

class _CreateGoalPageState extends State<_CreateGoalPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _hypothesisController = TextEditingController();
  final _actionController = TextEditingController();
  final _daysController = TextEditingController(text: '14');
  var _frequency = 'flexible';
  var _saving = false;
  String? _saveError;

  @override
  void dispose() {
    _titleController.dispose();
    _hypothesisController.dispose();
    _actionController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  String? _requiredValidator(BuildContext context, String? value) {
    if (value?.trim().isNotEmpty == true) return null;
    return AppLocaleText.tr(
      context,
      en: 'This field is required.',
      zhHans: '请填写这一项。',
      zhHant: '請填寫這一項。',
      ja: 'この項目を入力してください。',
    );
  }

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false) || _saving) return;
    final observationDays = int.parse(_daysController.text.trim());
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await widget.onSubmit(
        _UserGoalDraft(
          title: _titleController.text.trim(),
          hypothesis: _hypothesisController.text.trim(),
          suggestedAction: _actionController.text.trim(),
          plannedFrequency: _frequency,
          observationDays: observationDays,
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = AppLocaleText.tr(
          context,
          en: 'Could not create this goal. Please try again.',
          zhHans: '暂时无法创建这个目标，请再试一次。',
          zhHant: '暫時無法建立這個目標，請再試一次。',
          ja: '目標を作成できませんでした。もう一度お試しください。',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ExperimentCreationScaffold(
      title: AppLocaleText.tr(
        context,
        en: 'New goal',
        zhHans: '新建目标',
        zhHant: '新增目標',
        ja: '目標を作る',
      ),
      subtitle: AppLocaleText.tr(
        context,
        en: 'Set a longer observation that can continue across days or weeks.',
        zhHans: '设定一个可以跨天或跨周持续观察的中长期项目。',
        zhHant: '設定一個可以跨天或跨週持續觀察的中長期項目。',
        ja: '数日から数週間続けて観察する中長期の取り組みを設定します。',
      ),
      icon: Icons.flag_rounded,
      accent: AuroraColors.purple,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ExperimentCreationField(
              controller: _titleController,
              label: AppLocaleText.tr(
                context,
                en: 'Goal name',
                zhHans: '目标名称',
                zhHant: '目標名稱',
                ja: '目標名',
              ),
              hint: AppLocaleText.tr(
                context,
                en: 'For example: protect a recovery break in the afternoon',
                zhHans: '例如：保留午后的恢复时间',
                zhHant: '例如：保留午後的恢復時間',
                ja: '例：午後の回復時間を確保する',
              ),
              maxLength: 80,
              validator: (value) => _requiredValidator(context, value),
            ),
            const SizedBox(height: 16),
            _ExperimentCreationField(
              controller: _hypothesisController,
              label: AppLocaleText.tr(
                context,
                en: 'What change do you want to observe?',
                zhHans: '想观察什么变化？',
                zhHant: '想觀察什麼變化？',
                ja: 'どんな変化を観察しますか？',
              ),
              hint: AppLocaleText.tr(
                context,
                en: 'Describe the change you hope to notice over time',
                zhHans: '写下希望经过一段时间后看到的变化',
                zhHant: '寫下希望經過一段時間後看到的變化',
                ja: '続けた先で確認したい変化を書きます',
              ),
              maxLength: 180,
              maxLines: 3,
              validator: (value) => _requiredValidator(context, value),
            ),
            const SizedBox(height: 16),
            _ExperimentCreationField(
              controller: _actionController,
              label: AppLocaleText.tr(
                context,
                en: 'How will you do it?',
                zhHans: '准备怎么做？',
                zhHant: '準備怎麼做？',
                ja: 'どのように続けますか？',
              ),
              hint: AppLocaleText.tr(
                context,
                en: 'Write a concrete action you can repeat',
                zhHans: '填写可以持续执行的具体做法',
                zhHant: '填寫可以持續執行的具體做法',
                ja: '繰り返せる具体的な行動を書きます',
              ),
              maxLength: 180,
              maxLines: 3,
              validator: (value) => _requiredValidator(context, value),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocaleText.tr(
                context,
                en: 'Rhythm',
                zhHans: '执行节奏',
                zhHant: '執行節奏',
                ja: '実行ペース',
              ),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AuroraColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: const ValueKey('goal-frequency'),
              initialValue: _frequency,
              decoration: _experimentCreationInputDecoration(context),
              items: [
                DropdownMenuItem(
                  value: 'daily',
                  child: Text(
                    AppLocaleText.tr(
                      context,
                      en: 'Every day',
                      zhHans: '每天',
                      zhHant: '每天',
                      ja: '毎日',
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: 'weekdays',
                  child: Text(
                    AppLocaleText.tr(
                      context,
                      en: 'Weekdays',
                      zhHans: '工作日',
                      zhHant: '平日',
                      ja: '平日',
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: 'weekly',
                  child: Text(
                    AppLocaleText.tr(
                      context,
                      en: 'Once a week',
                      zhHans: '每周一次',
                      zhHant: '每週一次',
                      ja: '週1回',
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: 'flexible',
                  child: Text(
                    AppLocaleText.tr(
                      context,
                      en: 'Flexible',
                      zhHans: '灵活安排',
                      zhHant: '彈性安排',
                      ja: '柔軟に',
                    ),
                  ),
                ),
              ],
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value != null) setState(() => _frequency = value);
                    },
            ),
            const SizedBox(height: 16),
            _ExperimentCreationField(
              controller: _daysController,
              label: AppLocaleText.tr(
                context,
                en: 'Minimum observation days',
                zhHans: '最少观察天数',
                zhHant: '最少觀察天數',
                ja: '最低観察日数',
              ),
              hint: '14',
              keyboardType: TextInputType.number,
              validator: (value) {
                final days = int.tryParse(value?.trim() ?? '');
                if (days == null || days < 3 || days > 3650) {
                  return AppLocaleText.tr(
                    context,
                    en: 'Enter a number from 3 to 3650.',
                    zhHans: '请输入 3–3650 之间的天数。',
                    zhHant: '請輸入 3–3650 之間的天數。',
                    ja: '3〜3650の日数を入力してください。',
                  );
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            _CreationBoundaryNote(
              text: AppLocaleText.tr(
                context,
                en: 'Goals can continue across days or weeks. You decide the observation period.',
                zhHans: '目标可以跨天或跨周持续观察，观察周期由你设定。',
                zhHant: '目標可以跨天或跨週持續觀察，觀察週期由你設定。',
                ja: '目標は数日から数週間続けられます。観察期間は自分で設定できます。',
              ),
              color: AuroraColors.purple,
            ),
            if (_saveError != null) ...[
              const SizedBox(height: 12),
              Text(
                _saveError!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AuroraColors.orange,
                    ),
              ),
            ],
            const SizedBox(height: 22),
            _ExperimentCreationSubmitButton(
              key: const ValueKey('save-user-goal'),
              isSaving: _saving,
              color: AuroraColors.purple,
              label: AppLocaleText.tr(
                context,
                en: 'Create goal',
                zhHans: '创建目标',
                zhHant: '建立目標',
                ja: '目標を作成',
              ),
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExperimentCreationScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Widget child;

  const _ExperimentCreationScaffold({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          AuroraPage(
            child: Stack(
              children: [
                const Positioned(
                  right: -14,
                  top: 12,
                  width: 210,
                  height: 150,
                  child: IgnorePointer(
                    child: AuroraExperimentHeroPattern(opacity: 0.72),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      22,
                      12,
                      22,
                      MediaQuery.paddingOf(context).bottom + 42,
                    ),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _BackBubble(
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AuroraSectionIcon(
                            icon: icon,
                            color: accent,
                            size: 48,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        color: AuroraColors.ink,
                                        fontWeight: FontWeight.w700,
                                        height: 1.15,
                                      ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  subtitle,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: AuroraColors.muted,
                                        height: 1.48,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      AuroraCard(
                        padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                        borderRadius: BorderRadius.circular(24),
                        color: Colors.white.withValues(alpha: 0.76),
                        child: child,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const AuroraSafeTopMask(extraHeight: 6),
        ],
      ),
    );
  }
}

class _ExperimentCreationField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int? maxLength;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _ExperimentCreationField({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLength,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textInputAction:
          maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      validator: validator,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AuroraColors.ink,
          ),
      decoration: _experimentCreationInputDecoration(context).copyWith(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: maxLines > 1,
      ),
    );
  }
}

InputDecoration _experimentCreationInputDecoration(BuildContext context) {
  return InputDecoration(
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.68),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: AuroraColors.line.withValues(alpha: 0.5)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: AuroraColors.line.withValues(alpha: 0.5)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AuroraColors.purple, width: 1.4),
    ),
  );
}

class _CreationBoundaryNote extends StatelessWidget {
  final String text;
  final Color color;

  const _CreationBoundaryNote({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AuroraColors.muted,
                    height: 1.4,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExperimentCreationSubmitButton extends StatelessWidget {
  final bool isSaving;
  final Color color;
  final String label;
  final VoidCallback onPressed;

  const _ExperimentCreationSubmitButton({
    super.key,
    required this.isSaving,
    required this.color,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: isSaving ? null : onPressed,
        icon: isSaving
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add_circle_outline_rounded),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

class _ExperimentFilterTabs extends StatelessWidget {
  static const _rowHeight = 46.0;
  static const _singleRowBreakpoint = 620.0;

  final _ExperimentFilter value;
  final Map<_ExperimentFilter, int> counts;
  final ValueChanged<_ExperimentFilter> onChanged;

  const _ExperimentFilterTabs({
    required this.value,
    required this.counts,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final filters = _ExperimentFilter.values
        .where((filter) => filter != _ExperimentFilter.all)
        .toList();
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final useTwoRows =
            constraints.maxWidth < _singleRowBreakpoint || textScale > 1.1;
        final rows = useTwoRows
            ? <List<_ExperimentFilter>>[
                filters.take(3).toList(),
                filters.skip(3).toList(),
              ]
            : <List<_ExperimentFilter>>[filters];

        return Container(
          key: const ValueKey('experiment-filter-tabs'),
          height: _rowHeight * rows.length,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
            boxShadow: [
              BoxShadow(
                color: AuroraColors.purple.withValues(alpha: 0.07),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              children: [
                for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) ...[
                  if (rowIndex > 0)
                    Container(
                      height: 1,
                      color: AuroraColors.line.withValues(alpha: 0.5),
                    ),
                  Expanded(
                    child: _ExperimentFilterRow(
                      filters: rows[rowIndex],
                      value: value,
                      counts: counts,
                      onChanged: onChanged,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ExperimentFilterRow extends StatelessWidget {
  final List<_ExperimentFilter> filters;
  final _ExperimentFilter value;
  final Map<_ExperimentFilter, int> counts;
  final ValueChanged<_ExperimentFilter> onChanged;

  const _ExperimentFilterRow({
    required this.filters,
    required this.value,
    required this.counts,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < filters.length; index++) ...[
          if (index > 0)
            Container(
              width: 1,
              margin: const EdgeInsets.symmetric(vertical: 11),
              color: AuroraColors.line.withValues(alpha: 0.5),
            ),
          Expanded(
            child: _ExperimentFilterTab(
              filter: filters[index],
              selected: filters[index] == value,
              count: counts[filters[index]] ?? 0,
              onTap: () => onChanged(filters[index]),
            ),
          ),
        ],
      ],
    );
  }
}

class _ExperimentFilterTab extends StatelessWidget {
  final _ExperimentFilter filter;
  final bool selected;
  final int count;
  final VoidCallback onTap;

  const _ExperimentFilterTab({
    required this.filter,
    required this.selected,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = _filterLabel(context, filter);
    return Semantics(
      button: true,
      selected: selected,
      label: '$label $count',
      child: InkWell(
        key: ValueKey('experiment-filter-${filter.name}'),
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withValues(alpha: 0.82)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: selected
                ? Border.all(
                    color: AuroraColors.purple.withValues(alpha: 0.48),
                  )
                : null,
          ),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: label),
                TextSpan(
                  text: '  $count',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? AuroraColors.purple.withValues(alpha: 0.9)
                        : AuroraColors.muted,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? AuroraColors.purple : AuroraColors.ink,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              fontSize: 13.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _ExperimentSectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final VoidCallback? onOpenOverview;

  const _ExperimentSectionHeader({
    required this.title,
    required this.count,
    required this.onOpenOverview,
  });

  @override
  Widget build(BuildContext context) {
    final countLabel = AppLocaleText.tr(
      context,
      en: '$count goal${count == 1 ? '' : 's'}',
      zhHans: '$count 个目标',
      zhHant: '$count 個目標',
      ja: '$count 件',
    );
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AuroraColors.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        if (onOpenOverview == null)
          Text(
            countLabel,
            style: const TextStyle(
              color: AuroraColors.muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          )
        else
          Semantics(
            label: countLabel,
            button: true,
            child: TextButton(
              onPressed: onOpenOverview,
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              child: Text(
                AppLocaleText.tr(
                  context,
                  en: 'Details',
                  zhHans: countLabel,
                  zhHant: countLabel,
                  ja: countLabel,
                ),
                style: const TextStyle(
                  color: AuroraColors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ExperimentProgressDay {
  final DateTime date;
  final _ExperimentProgressState state;

  const _ExperimentProgressDay(this.date, this.state);
}

enum _ExperimentProgressState { completed, notCompleted, empty }

DateTime _experimentProgressStart(LifeExperimentModel experiment) {
  return _parseExperimentDate(experiment.progressStartDate ?? '') ??
      _parseExperimentDate(experiment.sourceWeekStart) ??
      experiment.adoptedAt?.toLocal() ??
      experiment.createdAt?.toLocal() ??
      DateTime.now();
}

List<_ExperimentProgressDay> _experimentProgressDays(
  LifeExperimentModel experiment,
  _ExperimentEvidence evidence,
) {
  final startRaw = _experimentProgressStart(experiment);
  final start = DateTime(startRaw.year, startRaw.month, startRaw.day);
  final ordered = [...evidence.feedbacks]..sort((a, b) {
      final aTime = a.updatedAt ?? a.feedbackDate;
      final bTime = b.updatedAt ?? b.feedbackDate;
      return aTime.compareTo(bTime);
    });
  final effectiveByDate = <String, LifeExperimentFeedbackModel>{};
  for (final feedback in ordered) {
    effectiveByDate[feedback.localDate] = feedback;
  }
  return List.generate(7, (index) {
    final date = start.add(Duration(days: index));
    final key = _localDateKey(date);
    final feedback = effectiveByDate[key];
    if (feedback == null) {
      return _ExperimentProgressDay(date, _ExperimentProgressState.empty);
    }
    return _ExperimentProgressDay(
      date,
      _feedbackCountsAsCompleted(feedback.completionStatus)
          ? _ExperimentProgressState.completed
          : _ExperimentProgressState.notCompleted,
    );
  });
}

String _localDateKey(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)}';
}

String _experimentListSeparator(BuildContext context) {
  return AppLocaleText.tr(
    context,
    en: ', ',
    zhHans: '，',
    zhHant: '，',
    ja: '、',
  );
}

enum _SevenDayRecordAvailability { active, notStarted, ended }

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

bool _isWritableLifecycleStatus(String rawStatus) {
  final status = rawStatus.trim().toLowerCase();
  return const {'accepted', 'saved', 'active', 'in_progress'}.contains(status);
}

_SevenDayRecordAvailability _smallTryRecordAvailability(
  MicroActionModel action, {
  DateTime? now,
}) {
  if (!_isWritableLifecycleStatus(action.status)) {
    return _SevenDayRecordAvailability.ended;
  }
  final start = _parseExperimentDate(action.progressStartDate ?? '') ??
      _parseExperimentDate(action.plannedDate ?? '') ??
      action.adoptedAt?.toLocal() ??
      action.createdAt?.toLocal();
  if (start == null) return _SevenDayRecordAvailability.ended;
  final end = _parseExperimentDate(action.progressEndDate ?? '');
  return _recordAvailabilityFromStart(start, end: end, now: now);
}

_SevenDayRecordAvailability _goalRecordAvailability(
  LifeExperimentModel experiment, {
  String? lifecycleStatus,
  DateTime? now,
}) {
  if (!_isWritableLifecycleStatus(lifecycleStatus ?? experiment.status)) {
    return _SevenDayRecordAvailability.ended;
  }
  final start = _parseExperimentDate(experiment.progressStartDate ?? '') ??
      _parseExperimentDate(experiment.sourceWeekStart) ??
      experiment.adoptedAt?.toLocal() ??
      experiment.createdAt?.toLocal();
  if (start == null) return _SevenDayRecordAvailability.ended;
  final end = _parseExperimentDate(experiment.progressEndDate ?? '');
  return _recordAvailabilityFromStart(start, end: end, now: now);
}

_SevenDayRecordAvailability _recordAvailabilityFromStart(
  DateTime start, {
  DateTime? end,
  DateTime? now,
}) {
  final today = _dateOnly((now ?? DateTime.now()).toLocal());
  final localStart = _dateOnly(start.toLocal());
  if (today.isBefore(localStart)) {
    return _SevenDayRecordAvailability.notStarted;
  }
  if (end != null && today.isAfter(_dateOnly(end.toLocal()))) {
    return _SevenDayRecordAvailability.ended;
  }
  return _SevenDayRecordAvailability.active;
}

String _recordAvailabilityLabel(
  BuildContext context,
  _SevenDayRecordAvailability availability,
) {
  return availability == _SevenDayRecordAvailability.notStarted
      ? AppLocaleText.tr(
          context,
          en: 'The recording period has not started yet.',
          zhHans: '记录期尚未开始',
          zhHant: '記錄期尚未開始',
          ja: '記録期間はまだ始まっていません',
        )
      : AppLocaleText.tr(
          context,
          en: 'This completed cycle is read-only.',
          zhHans: '这一轮已完成，历史记录为只读。',
          zhHant: '這一輪已完成，歷史記錄為唯讀。',
          ja: 'このサイクルは完了し、履歴は読み取り専用です。',
        );
}

class _RecordAvailabilityNotice extends StatelessWidget {
  final _SevenDayRecordAvailability availability;

  const _RecordAvailabilityNotice({required this.availability});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('life-experiment-record-window-read-only'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AuroraColors.muted.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AuroraColors.line.withValues(alpha: 0.72)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.history_rounded,
            color: AuroraColors.muted,
            size: 18,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              _recordAvailabilityLabel(context, availability),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AuroraColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

bool _feedbackCountsAsCompleted(String rawStatus) {
  final status = rawStatus.trim().toLowerCase();
  if (status.isEmpty) return false;
  if (const {
    'no',
    'false',
    'not_completed',
    'not_done',
    'not_tried',
    'not_today',
    'missed',
  }.contains(status)) {
    return false;
  }
  return !status.contains('not_happened') &&
      !status.contains('not_occurred') &&
      !status.contains('not_suitable') &&
      !status.contains('skip');
}

String _weekdayLabel(BuildContext context, DateTime date) {
  const en = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  const zhHans = ['一', '二', '三', '四', '五', '六', '日'];
  const ja = ['月', '火', '水', '木', '金', '土', '日'];
  return AppLocaleText.tr(
    context,
    en: en[date.weekday - 1],
    zhHans: zhHans[date.weekday - 1],
    zhHant: zhHans[date.weekday - 1],
    ja: ja[date.weekday - 1],
  );
}

String _experimentDayLabel(
  BuildContext context,
  LifeExperimentModel experiment,
) {
  final start = _experimentProgressStart(experiment);
  final today = DateTime.now();
  final startDay = DateTime(start.year, start.month, start.day);
  final todayDay = DateTime(today.year, today.month, today.day);
  final day = todayDay.difference(startDay).inDays.clamp(0, 6) + 1;
  return AppLocaleText.tr(
    context,
    en: 'Day $day',
    zhHans: '第 $day 天',
    zhHant: '第 $day 天',
    ja: '$day 日目',
  );
}

String _experimentSourceLabel(
  BuildContext context,
  LifeExperimentModel experiment,
) {
  final start = _parseExperimentDate(experiment.sourceWeekStart);
  final end = _parseExperimentDate(experiment.sourceWeekEnd);
  if (start == null || end == null) {
    return AppLocaleText.tr(
      context,
      en: 'From Weekly',
      zhHans: '来自每周复盘',
      zhHant: '來自每週回顧',
      ja: '週間レビューから',
    );
  }
  final range = '${start.month}/${start.day}–${end.month}/${end.day}';
  return AppLocaleText.tr(
    context,
    en: 'From $range Weekly',
    zhHans: '来自 $range 每周复盘',
    zhHant: '來自 $range 每週回顧',
    ja: '$range の週間レビューから',
  );
}

class _ActiveExperimentCard extends StatelessWidget {
  final bool expanded;
  final LifeExperimentModel experiment;
  final _ExperimentEvidence evidence;
  final _ExperimentRollup? rollup;
  final VoidCallback onOpenDetail;

  const _ActiveExperimentCard({
    required this.expanded,
    required this.experiment,
    required this.evidence,
    required this.rollup,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    final days = _experimentProgressDays(experiment, evidence);
    final completed = days
        .where((day) => day.state == _ExperimentProgressState.completed)
        .length;
    return _ExperimentGlassCard(
      key: ValueKey('experiment-archive-card-${experiment.id}'),
      mainPageDensity: true,
      padding: const EdgeInsets.fromLTRB(15, 12, 15, 13),
      child: expanded
          ? _ExpandedExperimentContent(
              experiment: experiment,
              days: days,
              completed: completed,
              onOpenDetail: onOpenDetail,
            )
          : _CompactExperimentContent(
              experiment: experiment,
              completed: completed,
              onOpenDetail: onOpenDetail,
            ),
    );
  }
}

class _ExpandedExperimentContent extends StatelessWidget {
  final LifeExperimentModel experiment;
  final List<_ExperimentProgressDay> days;
  final int completed;
  final VoidCallback onOpenDetail;

  const _ExpandedExperimentContent({
    required this.experiment,
    required this.days,
    required this.completed,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ExperimentStatusLine(experiment: experiment),
        const SizedBox(height: 3),
        Text(
          experiment.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AuroraColors.ink,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
        ),
        if (experiment.hypothesis.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            experiment.hypothesis.trim(),
            key: ValueKey(
              'experiment-${experiment.id}-archive-hypothesis',
            ),
            style: const TextStyle(
              color: AuroraColors.muted,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ],
        const SizedBox(height: 7),
        Row(
          children: [
            const Icon(Icons.calendar_month_outlined,
                size: 17, color: AuroraColors.muted),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                _experimentSourceLabel(context, experiment),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AuroraColors.muted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const Divider(height: 18),
        Row(
          children: [
            Expanded(
              child: Text(
                AppLocaleText.tr(
                  context,
                  en: 'This week progress',
                  zhHans: '本周进度',
                  zhHant: '本週進度',
                  ja: '今週の進捗',
                ),
                style: const TextStyle(
                  color: AuroraColors.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '$completed/7',
              style: const TextStyle(
                color: AuroraColors.purple,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        _ExperimentSevenDayGrid(days: days),
        const SizedBox(height: 9),
        const _ExperimentProgressLegend(),
        const Divider(height: 18),
        _ExperimentActionButton(
          label: AppLocaleText.tr(
            context,
            en: 'View details',
            zhHans: '查看详情',
            zhHant: '查看詳情',
            ja: '詳細を見る',
          ),
          onTap: onOpenDetail,
        ),
      ],
    );
  }
}

class _CompactExperimentContent extends StatelessWidget {
  final LifeExperimentModel experiment;
  final int completed;
  final VoidCallback onOpenDetail;

  const _CompactExperimentContent({
    required this.experiment,
    required this.completed,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ExperimentStatusLine(experiment: experiment),
        const SizedBox(height: 2),
        Text(
          experiment.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AuroraColors.ink,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            Text(
              '$completed/7',
              style: const TextStyle(
                color: AuroraColors.purple,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.chevron_right_rounded,
              color: AuroraColors.muted,
            ),
          ],
        ),
        const Divider(height: 16),
        _ExperimentActionButton(
          label: AppLocaleText.tr(
            context,
            en: 'View details',
            zhHans: '查看详情',
            zhHant: '查看詳情',
            ja: '詳細を見る',
          ),
          onTap: onOpenDetail,
        ),
      ],
    );
  }
}

class _ExperimentStatusLine extends StatelessWidget {
  final LifeExperimentModel experiment;

  const _ExperimentStatusLine({required this.experiment});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox.square(
          key: ValueKey('experiment-archive-icon-${experiment.id}'),
          dimension: 48,
          child: const Align(
            alignment: Alignment.centerLeft,
            child: AuroraSectionIcon(
              icon: Icons.science_rounded,
              color: AuroraColors.purple,
              size: 40,
            ),
          ),
        ),
        Text(
          AppLocaleText.tr(
            context,
            en: 'Active',
            zhHans: '进行中',
            zhHant: '進行中',
            ja: '進行中',
          ),
          style: const TextStyle(
            color: AuroraColors.purple,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Text(
          '  ·  ',
          style: TextStyle(color: AuroraColors.muted),
        ),
        Expanded(
          child: Text(
            _experimentDayLabel(context, experiment),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AuroraColors.muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ExperimentSevenDayGrid extends StatelessWidget {
  final List<_ExperimentProgressDay> days;

  const _ExperimentSevenDayGrid({required this.days});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < days.length; index++) ...[
          Expanded(child: _ExperimentProgressCell(day: days[index])),
          if (index != days.length - 1) const SizedBox(width: 5),
        ],
      ],
    );
  }
}

class _ExperimentProgressCell extends StatelessWidget {
  final _ExperimentProgressDay day;

  const _ExperimentProgressCell({required this.day});

  @override
  Widget build(BuildContext context) {
    final (icon, background, foreground, semantic) = switch (day.state) {
      _ExperimentProgressState.completed => (
          Icons.check_rounded,
          AuroraColors.mint,
          Colors.white,
          'completed',
        ),
      _ExperimentProgressState.notCompleted => (
          Icons.remove_rounded,
          const Color(0xFFD6DCE7),
          Colors.white,
          'not completed',
        ),
      _ExperimentProgressState.empty => (
          null,
          const Color(0xFFDCE2EC),
          Colors.transparent,
          'not recorded',
        ),
    };
    return Semantics(
      label: '${_localDateKey(day.date)}, $semantic',
      child: Column(
        children: [
          Text(
            _weekdayLabel(context, day.date),
            style: const TextStyle(
              color: AuroraColors.ink,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 26,
            height: 26,
            decoration:
                BoxDecoration(color: background, shape: BoxShape.circle),
            child:
                icon == null ? null : Icon(icon, size: 16, color: foreground),
          ),
        ],
      ),
    );
  }
}

class _ExperimentProgressLegend extends StatelessWidget {
  const _ExperimentProgressLegend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        _ExperimentLegendItem(
          icon: Icons.check_rounded,
          color: AuroraColors.mint,
          label: AppLocaleText.tr(
            context,
            en: 'Completed',
            zhHans: '已完成',
            zhHant: '已完成',
            ja: '完了',
          ),
        ),
        _ExperimentLegendItem(
          icon: Icons.remove_rounded,
          color: const Color(0xFFB8C1D1),
          label: AppLocaleText.tr(
            context,
            en: 'Not completed',
            zhHans: '未完成',
            zhHant: '未完成',
            ja: '未完了',
          ),
        ),
        _ExperimentLegendItem(
          color: const Color(0xFFDCE2EC),
          label: AppLocaleText.tr(
            context,
            en: 'Not recorded',
            zhHans: '尚未登记',
            zhHant: '尚未登記',
            ja: '未記録',
          ),
        ),
      ],
    );
  }
}

class _ExperimentLegendItem extends StatelessWidget {
  final IconData? icon;
  final Color color;
  final String label;

  const _ExperimentLegendItem({
    this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child:
              icon == null ? null : Icon(icon, color: Colors.white, size: 12),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            softWrap: true,
            style: const TextStyle(
              color: AuroraColors.muted,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _ExperimentActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ExperimentActionButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AuroraColors.purple,
          side: BorderSide(
            color: AuroraColors.purple.withValues(alpha: 0.5),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _UpcomingExperimentCard extends StatelessWidget {
  final LifeExperimentModel experiment;
  final VoidCallback onTap;

  const _UpcomingExperimentCard({
    required this.experiment,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final start = _experimentProgressStart(experiment);
    final end = _parseExperimentDate(experiment.progressEndDate ?? '') ??
        start.add(const Duration(days: 6));
    final dateRange = '${start.month}/${start.day}–${end.month}/${end.day}';
    return InkWell(
      key: ValueKey('experiment-archive-card-${experiment.id}'),
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: _ExperimentGlassCard(
        mainPageDensity: true,
        padding: const EdgeInsets.fromLTRB(15, 12, 10, 13),
        child: Row(
          children: [
            SizedBox.square(
              key: ValueKey('experiment-archive-icon-${experiment.id}'),
              dimension: 48,
              child: const Align(
                alignment: Alignment.topLeft,
                child: AuroraSectionIcon(
                  icon: Icons.science_rounded,
                  color: AuroraColors.gold,
                  size: 40,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocaleText.tr(
                      context,
                      en: 'Adopted · starts next week',
                      zhHans: '已采纳 · 下周一开始',
                      zhHant: '已採納 · 下週一開始',
                      ja: '採用済み · 来週開始',
                    ),
                    style: const TextStyle(
                      color: Color(0xFFA2781B),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    experiment.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AuroraColors.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.calendar_month_outlined,
                          size: 16, color: AuroraColors.muted),
                      const SizedBox(width: 5),
                      Text(
                        dateRange,
                        style: const TextStyle(
                          color: AuroraColors.muted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppLocaleText.tr(
                      context,
                      en: 'Once it starts, daily feedback will update its progress.',
                      zhHans: '开始后，当天反馈会更新它的进度。',
                      zhHant: '開始後，當天回饋會更新它的進度。',
                      ja: '開始後は、その日のフィードバックで進捗が更新されます。',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AuroraColors.muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
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

class _ExperimentSourceChangedBadge extends StatelessWidget {
  const _ExperimentSourceChangedBadge();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.sync_problem_rounded,
            size: 15, color: AuroraColors.orange),
        const SizedBox(width: 4),
        Text(
          AppLocaleText.tr(
            context,
            en: 'Source changed',
            zhHans: '来源已变化',
            zhHant: '來源已變化',
            ja: '参照元が変わりました',
          ),
          style: const TextStyle(
            color: AuroraColors.orange,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ExperimentEmptyArchive extends StatelessWidget {
  final bool mainPageDensity;
  final bool historyLoaded;
  final _ExperimentFilter filter;

  const _ExperimentEmptyArchive({
    required this.mainPageDensity,
    required this.historyLoaded,
    required this.filter,
  });

  @override
  Widget build(BuildContext context) {
    return _ExperimentGlassCard(
      key: mainPageDensity ? const ValueKey('experiment-empty-archive') : null,
      mainPageDensity: mainPageDensity,
      padding: mainPageDensity ? AuroraMainPageSpec.cardPadding : null,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: mainPageDensity ? 0 : 24),
        child: Column(
          children: [
            AuroraSectionIcon(
              icon: Icons.science_rounded,
              color: AuroraColors.purple,
              size: mainPageDensity ? 34 : 44,
            ),
            SizedBox(height: mainPageDensity ? 6 : 12),
            Text(
              historyLoaded
                  ? _emptyText(context, filter)
                  : AppLocaleText.tr(
                      context,
                      en: 'Loading goals...',
                      zhHans: '正在加载目标...',
                      zhHant: '正在載入目標...',
                      ja: '目標を読み込み中...',
                    ),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AuroraColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if (historyLoaded) ...[
              SizedBox(height: mainPageDensity ? 6 : 8),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: mainPageDensity ? 0 : 18,
                ),
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'After 3 eligible signals this week, AI can organize goals worth repeating for several days.',
                    zhHans: '本周积累 3 条有效信号后，智能助手会整理值得连续多日尝试的目标。',
                    zhHant: '本週累積 3 條有效信號後，智慧助手會整理值得連續多日嘗試的目標。',
                    ja: '今週の有効なシグナルが3件になると、人工知能が数日続ける目標を整理します。',
                  ),
                  textAlign: TextAlign.center,
                  maxLines: mainPageDensity ? 3 : null,
                  overflow: mainPageDensity ? TextOverflow.ellipsis : null,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AuroraColors.muted,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _emptyText(BuildContext context, _ExperimentFilter filter) {
    return switch (filter) {
      _ExperimentFilter.all => AppLocaleText.tr(
          context,
          en: 'No goals yet',
          zhHans: '还没有目标',
          zhHant: '還沒有目標',
          ja: '目標はまだありません',
        ),
      _ExperimentFilter.active => AppLocaleText.tr(
          context,
          en: 'No active goals',
          zhHans: '暂无进行中的目标',
          zhHant: '暫無進行中的目標',
          ja: '進行中の目標はありません',
        ),
      _ExperimentFilter.adjusted => AppLocaleText.tr(
          context,
          en: 'No adjusted goals',
          zhHans: '暂无已调整的目标',
          zhHant: '暫無已調整的目標',
          ja: '調整済みの目標はありません',
        ),
      _ExperimentFilter.completed => AppLocaleText.tr(
          context,
          en: 'No completed goals',
          zhHans: '暂无已完成的目标',
          zhHant: '暫無已完成的目標',
          ja: '完了した目標はありません',
        ),
      _ExperimentFilter.paused => AppLocaleText.tr(
          context,
          en: 'No paused goals',
          zhHans: '暂无暂停的目标',
          zhHant: '暫無暫停的目標',
          ja: '一時停止中の目標はありません',
        ),
      _ExperimentFilter.stopped => AppLocaleText.tr(
          context,
          en: 'No stopped goals',
          zhHans: '暂无已停止的目标',
          zhHant: '暫無已停止的目標',
          ja: '停止した目標はありません',
        ),
    };
  }
}

class _LifeExperimentArchiveCard extends StatelessWidget {
  final bool mainPageDensity;
  final LifeExperimentModel experiment;
  final _ExperimentEvidence evidence;
  final _ExperimentRollup? rollup;
  final List<_ExperimentLifecycleEvent> lifecycle;
  final VoidCallback onTap;

  const _LifeExperimentArchiveCard({
    required this.mainPageDensity,
    required this.experiment,
    required this.evidence,
    required this.rollup,
    required this.lifecycle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _experimentColor(experiment);
    final label = _statusLabel(context, experiment, rollup: rollup);
    final statusColor = _statusColor(experiment);
    final tried = _actualTriedCount(experiment, evidence, rollup);
    final helpful = rollup?.helpfulCount ?? 0;
    final adjusted = rollup?.adjustedCount ?? 0;
    final skipped = rollup?.skippedCount ?? 0;
    final plannedDays = math.max(1, experiment.plannedTotalDays ?? 7);
    return InkWell(
      key: mainPageDensity
          ? ValueKey('experiment-archive-card-${experiment.id}')
          : null,
      borderRadius: BorderRadius.circular(mainPageDensity ? 20 : 26),
      onTap: onTap,
      child: _ExperimentGlassCard(
        mainPageDensity: mainPageDensity,
        padding: mainPageDensity
            ? AuroraMainPageSpec.comfortableCardPadding
            : const EdgeInsets.fromLTRB(16, 16, 14, 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 300;
            final iconSize = mainPageDensity
                ? (compact ? 44.0 : 48.0)
                : (compact ? 58.0 : 72.0);
            final icon = Container(
              key: mainPageDensity
                  ? ValueKey('experiment-archive-icon-${experiment.id}')
                  : null,
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.28),
                    color.withValues(alpha: 0.72),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.24),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                _experimentIcon(experiment),
                color: Colors.white,
                size: mainPageDensity ? 24 : (compact ? 30 : 34),
              ),
            );
            final stats = AppLocaleText.tr(
              context,
              en: '$tried tried · $helpful helpful · $adjusted adjusted · $skipped skipped',
              zhHans:
                  '$tried 次尝试 · $helpful 次有效 · $adjusted 次调整 · $skipped 次跳过',
              zhHant:
                  '$tried 次嘗試 · $helpful 次有效 · $adjusted 次調整 · $skipped 次跳過',
              ja: '$tried 回試行 · $helpful 回有効 · $adjusted 回調整 · $skipped 回スキップ',
            );
            final weekText = AppLocaleText.tr(
              context,
              en: '${rollup?.activeWeekCount ?? 1} week(s)',
              zhHans: '${rollup?.activeWeekCount ?? 1} 周',
              zhHant: '${rollup?.activeWeekCount ?? 1} 週',
              ja: '${rollup?.activeWeekCount ?? 1} 週',
            );
            final summary = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  experiment.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AuroraColors.ink,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        fontSize: mainPageDensity ? 17 : null,
                      ),
                ),
                SizedBox(height: mainPageDensity ? 6 : 8),
                Text(
                  stats,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AuroraColors.ink.withValues(alpha: 0.62),
                    fontSize: mainPageDensity ? 13 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: mainPageDensity ? 8 : 10),
                _ProgressBar(
                  value: (tried / plannedDays).clamp(0.0, 1.0),
                  color: color,
                  height: 8,
                ),
                if (rollup?.hasLineage == true || lifecycle.isNotEmpty) ...[
                  SizedBox(height: mainPageDensity ? 6 : 8),
                  Text(
                    _lineageHint(context, rollup, lifecycle),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AuroraColors.purple.withValues(alpha: 0.74),
                      fontSize: mainPageDensity ? 11.5 : 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            );
            final statusMeta = Text(
              weekText,
              style: TextStyle(
                color: AuroraColors.ink.withValues(alpha: 0.62),
                fontSize: mainPageDensity ? 12 : 13,
                fontWeight: FontWeight.w600,
              ),
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      icon,
                      SizedBox(width: mainPageDensity ? 10 : 12),
                      Expanded(child: summary),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AuroraColors.muted,
                        size: mainPageDensity ? 22 : 26,
                      ),
                    ],
                  ),
                  SizedBox(height: mainPageDensity ? 10 : 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _StatusPill(label: label, color: statusColor),
                      statusMeta,
                    ],
                  ),
                ],
              );
            }
            return Row(
              children: [
                icon,
                SizedBox(width: mainPageDensity ? 12 : 16),
                Expanded(child: summary),
                SizedBox(width: mainPageDensity ? 8 : 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _StatusPill(label: label, color: statusColor),
                    SizedBox(height: mainPageDensity ? 18 : 28),
                    statusMeta,
                  ],
                ),
                SizedBox(width: mainPageDensity ? 6 : 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AuroraColors.muted,
                  size: mainPageDensity ? 22 : 28,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ExperimentArchiveSummaryCard extends StatelessWidget {
  final bool mainPageDensity;
  final List<LifeExperimentModel> experiments;
  final Map<String, List<LifeExperimentFeedbackModel>> feedbacksByExperiment;
  final Map<String, _ExperimentRollup> rollupsByExperiment;
  final VoidCallback? onViewDetail;

  const _ExperimentArchiveSummaryCard({
    required this.mainPageDensity,
    required this.experiments,
    required this.feedbacksByExperiment,
    required this.rollupsByExperiment,
    required this.onViewDetail,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = _summaryMetrics(
      experiments,
      feedbacksByExperiment,
      rollupsByExperiment,
    );
    return _ExperimentGlassCard(
      key:
          mainPageDensity ? const ValueKey('experiment-archive-summary') : null,
      mainPageDensity: mainPageDensity,
      title: AppLocaleText.tr(
        context,
        en: 'Goal archive',
        zhHans: '目标归档',
        zhHant: '目標歸檔',
        ja: '目標アーカイブ',
      ),
      trailing: onViewDetail == null
          ? null
          : TextButton.icon(
              onPressed: onViewDetail,
              iconAlignment: IconAlignment.end,
              style: mainPageDensity
                  ? TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    )
                  : null,
              icon: Icon(
                Icons.chevron_right_rounded,
                size: mainPageDensity ? 20 : null,
              ),
              label: Text(
                AppLocaleText.tr(
                  context,
                  en: 'Archive overview',
                  zhHans: '归档概况',
                  zhHant: '歸檔概況',
                  ja: 'アーカイブ概要',
                ),
              ),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final cards = <Widget>[
                _ArchiveMetric(
                  mainPageDensity: mainPageDensity,
                  icon: Icons.hourglass_bottom_rounded,
                  color: AuroraColors.purple,
                  label: AppLocaleText.tr(
                    context,
                    en: 'Active',
                    zhHans: '进行中',
                    zhHant: '進行中',
                    ja: '進行中',
                  ),
                  value: '${metrics.active}',
                ),
                _ArchiveMetric(
                  mainPageDensity: mainPageDensity,
                  icon: Icons.star_rounded,
                  color: AuroraColors.mint,
                  label: AppLocaleText.tr(
                    context,
                    en: 'Effective',
                    zhHans: '有效',
                    zhHant: '有效',
                    ja: '有効',
                  ),
                  value: '${metrics.effective}',
                ),
                _ArchiveMetric(
                  mainPageDensity: mainPageDensity,
                  icon: Icons.bar_chart_rounded,
                  color: AuroraColors.blue,
                  label: AppLocaleText.tr(
                    context,
                    en: 'Total tries',
                    zhHans: '总尝试',
                    zhHant: '總嘗試',
                    ja: '合計',
                  ),
                  value: '${metrics.tried}',
                ),
              ];
              if (constraints.maxWidth < 300) {
                final itemWidth = (constraints.maxWidth - 8) / 2;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final card in cards)
                      SizedBox(width: itemWidth, child: card),
                  ],
                );
              }
              return Row(
                children: [
                  for (var index = 0; index < cards.length; index++) ...[
                    Expanded(child: cards[index]),
                    if (index != cards.length - 1) const SizedBox(width: 10),
                  ],
                ],
              );
            },
          ),
          if (metrics.total == 0) ...[
            const SizedBox(height: 12),
            Text(
              AppLocaleText.tr(
                context,
                en: 'Once you start a goal, its attempts and effect summary will appear here.',
                zhHans: '开始一个目标后，这里会显示你的尝试情况和效果总结。',
                zhHant: '開始一個目標後，這裡會顯示你的嘗試情況和效果總結。',
                ja: '目標を始めると、試行状況と効果の要約がここに表示されます。',
              ),
              style: TextStyle(
                color: AuroraColors.ink.withValues(alpha: 0.58),
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ArchiveMetric extends StatelessWidget {
  final bool mainPageDensity;
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _ArchiveMetric({
    this.mainPageDensity = false,
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(mainPageDensity ? 10 : 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(mainPageDensity ? 18 : 22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
      ),
      child: Column(
        children: [
          _IconBubble(
            icon: icon,
            color: color,
            size: mainPageDensity ? 34 : 42,
          ),
          SizedBox(height: mainPageDensity ? 8 : 10),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  fontSize: mainPageDensity ? 22 : null,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AuroraColors.ink.withValues(alpha: 0.62),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExperimentStatsHeroCard extends StatelessWidget {
  final _ExperimentSummaryMetrics metrics;

  const _ExperimentStatsHeroCard({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return _ExperimentGlassCard(
      child: Row(
        children: [
          _IconBubble(
            icon: Icons.science_rounded,
            color: AuroraColors.purple,
            size: 68,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metrics.total == 0
                      ? AppLocaleText.tr(
                          context,
                          en: 'No goal details yet',
                          zhHans: '还没有目标详情',
                          zhHant: '還沒有目標詳情',
                          ja: '目標の詳細はまだありません',
                        )
                      : AppLocaleText.tr(
                          context,
                          en: '${metrics.total} goal(s)',
                          zhHans: '${metrics.total} 个目标',
                          zhHant: '${metrics.total} 個目標',
                          ja: '${metrics.total} 件の目標',
                        ),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AuroraColors.purple,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  metrics.total == 0
                      ? AppLocaleText.tr(
                          context,
                          en: 'After you add a next-week goal from Weekly, its feedback, effect summary, linked signals, and timeline will appear here.',
                          zhHans: '当你从每周复盘加入一个下周目标后，这里会展示它的反馈、效果总结、关联信号和时间线。',
                          zhHant: '當你從每週復盤加入一個下週目標後，這裡會展示它的回饋、效果總結、關聯信號和時間線。',
                          ja: '毎週の振り返りから来週の目標を追加すると、フィードバック、効果の要約、関連シグナル、タイムラインがここに表示されます。',
                        )
                      : AppLocaleText.tr(
                          context,
                          en: 'This page uses the goal timeline, effect summary, feedback, and linked signals. Counts stay at 0 until real attempts appear.',
                          zhHans: '这里读取目标时间线、效果总结、反馈和关联信号。没有真实尝试时，数字会保持为 0。',
                          zhHant: '這裡讀取目標時間線、效果總結、回饋和關聯信號。沒有真實嘗試時，數字會保持為 0。',
                          ja: 'ここでは目標のタイムライン、効果の要約、フィードバック、関連シグナルを使います。実際の試行がなければ数値は 0 のままです。',
                        ),
                  style: TextStyle(
                    color: AuroraColors.ink.withValues(alpha: 0.66),
                    height: 1.45,
                    fontWeight: FontWeight.w700,
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

class _ExperimentStatusBreakdownCard extends StatelessWidget {
  final _ExperimentSummaryMetrics metrics;

  const _ExperimentStatusBreakdownCard({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return _ExperimentGlassCard(
      title: AppLocaleText.tr(
        context,
        en: 'Status breakdown',
        zhHans: '状态分布',
        zhHant: '狀態分布',
        ja: '状態分布',
      ),
      child: Row(
        children: [
          Expanded(
            child: _ArchiveMetric(
              icon: Icons.hourglass_bottom_rounded,
              color: AuroraColors.purple,
              label: AppLocaleText.tr(
                context,
                en: 'Active',
                zhHans: '进行中',
                zhHant: '進行中',
                ja: '進行中',
              ),
              value: '${metrics.active}',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ArchiveMetric(
              icon: Icons.star_rounded,
              color: AuroraColors.mint,
              label: AppLocaleText.tr(
                context,
                en: 'Effective',
                zhHans: '有效',
                zhHant: '有效',
                ja: '有効',
              ),
              value: '${metrics.effective}',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ArchiveMetric(
              icon: Icons.archive_outlined,
              color: AuroraColors.muted,
              label: AppLocaleText.tr(
                context,
                en: 'Completed',
                zhHans: '已完成',
                zhHant: '已完成',
                ja: '完了',
              ),
              value: '${metrics.ended}',
            ),
          ),
        ],
      ),
    );
  }
}

class _ExperimentAttemptBreakdownCard extends StatelessWidget {
  final _ExperimentSummaryMetrics metrics;

  const _ExperimentAttemptBreakdownCard({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return _ExperimentGlassCard(
      title: AppLocaleText.tr(
        context,
        en: 'Attempt summary',
        zhHans: '尝试汇总',
        zhHant: '嘗試彙總',
        ja: '試行集計',
      ),
      child: Row(
        children: [
          Expanded(
            child: _ArchiveMetric(
              icon: Icons.play_circle_outline_rounded,
              color: AuroraColors.blue,
              label: AppLocaleText.tr(
                context,
                en: 'Tried',
                zhHans: '尝试',
                zhHant: '嘗試',
                ja: '試行',
              ),
              value: '${metrics.tried}',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ArchiveMetric(
              icon: Icons.tune_rounded,
              color: AuroraColors.orange,
              label: AppLocaleText.tr(
                context,
                en: 'Adjusted',
                zhHans: '调整',
                zhHant: '調整',
                ja: '調整',
              ),
              value: '${metrics.adjusted}',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ArchiveMetric(
              icon: Icons.pause_circle_outline_rounded,
              color: AuroraColors.muted,
              label: AppLocaleText.tr(
                context,
                en: 'Skipped',
                zhHans: '跳过',
                zhHant: '跳過',
                ja: 'スキップ',
              ),
              value: '${metrics.skipped}',
            ),
          ),
        ],
      ),
    );
  }
}

class _ExperimentStatsListItem extends StatelessWidget {
  final LifeExperimentModel experiment;
  final int triedCount;
  final VoidCallback onTap;

  const _ExperimentStatsListItem({
    required this.experiment,
    required this.triedCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _experimentColor(experiment);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            _IconBubble(
              icon: _experimentIcon(experiment),
              color: color,
              size: 46,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    experiment.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AuroraColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppLocaleText.tr(
                      context,
                      en: '$triedCount tried',
                      zhHans: '$triedCount 次尝试',
                      zhHant: '$triedCount 次嘗試',
                      ja: '$triedCount 回試行',
                    ),
                    style: TextStyle(
                      color: AuroraColors.ink.withValues(alpha: 0.58),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AuroraColors.muted),
          ],
        ),
      ),
    );
  }
}

class _GoalDefinitionCard extends StatelessWidget {
  final LifeExperimentModel experiment;

  const _GoalDefinitionCard({required this.experiment});

  @override
  Widget build(BuildContext context) {
    final frequency = experiment.plannedFrequency?.trim() ?? '';
    final duration = experiment.plannedDurationMinutes;
    return _ExperimentGlassCard(
      key: const ValueKey('goal-definition-card'),
      title: AppLocaleText.tr(
        context,
        en: 'What this goal observes',
        zhHans: '这个目标要观察什么',
        zhHant: '這個目標要觀察什麼',
        ja: 'この目標で観察すること',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GoalDefinitionRow(
            icon: Icons.visibility_outlined,
            color: AuroraColors.purple,
            label: AppLocaleText.tr(
              context,
              en: 'Observation question',
              zhHans: '观察问题',
              zhHant: '觀察問題',
              ja: '観察する問い',
            ),
            value: experiment.hypothesis,
          ),
          const SizedBox(height: 12),
          _GoalDefinitionRow(
            icon: Icons.repeat_rounded,
            color: AuroraColors.blue,
            label: AppLocaleText.tr(
              context,
              en: 'What to keep doing',
              zhHans: '持续做什么',
              zhHant: '持續做什麼',
              ja: '続けること',
            ),
            value: experiment.suggestedAction,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CompactSummaryPill(
                icon: Icons.calendar_view_month_rounded,
                label: AppLocaleText.tr(
                  context,
                  en: 'Long-term · at least ${experiment.minimumObservationDays} days',
                  zhHans: '中长期 · 至少观察 ${experiment.minimumObservationDays} 天',
                  zhHant: '中長期 · 至少觀察 ${experiment.minimumObservationDays} 天',
                  ja: '中長期 · 最低 ${experiment.minimumObservationDays} 日観察',
                ),
                color: AuroraColors.purple,
              ),
              if (frequency.isNotEmpty)
                _CompactSummaryPill(
                  icon: Icons.event_repeat_rounded,
                  label: frequency,
                  color: AuroraColors.mint,
                ),
              if (duration != null && duration > 0)
                _CompactSummaryPill(
                  icon: Icons.timer_outlined,
                  label: AppLocaleText.tr(
                    context,
                    en: '$duration minutes each time',
                    zhHans: '每次约 $duration 分钟',
                    zhHant: '每次約 $duration 分鐘',
                    ja: '1回約 $duration 分',
                  ),
                  color: AuroraColors.orange,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalDefinitionRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _GoalDefinitionRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AuroraSoftIconCircle(icon: icon, color: color, size: 36, iconSize: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                value.trim().isEmpty
                    ? AppLocaleText.tr(
                        context,
                        en: 'Not specified yet',
                        zhHans: '暂未填写',
                        zhHant: '暫未填寫',
                        ja: '未設定',
                      )
                    : value.trim(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AuroraColors.ink,
                      height: 1.42,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GoalWeeklySummaryCard extends StatelessWidget {
  final LifeExperimentModel experiment;
  final _ExperimentEvidence evidence;
  final List<LifeExperimentOutcomeReviewModel> reviews;

  const _GoalWeeklySummaryCard({
    required this.experiment,
    required this.evidence,
    required this.reviews,
  });

  @override
  Widget build(BuildContext context) {
    final completed = _completedGoalObservationDays(evidence);
    final enough = completed >= experiment.minimumObservationDays;
    final entries = reviews
        .map(
          (review) => _FeedbackOverviewEntry(
            id: 'weekly-review-${review.id}',
            kindLabel: AppLocaleText.tr(
              context,
              en: 'Weekly summary',
              zhHans: '周次总结',
              zhHant: '週次總結',
              ja: '週次まとめ',
            ),
            overallLabel: '${_goalOutcomeLabel(
              context,
              review.outcomeResult,
              review.burden,
            )} · ${_goalBurdenLabel(context, review.burden)}',
            localDate: review.localDate,
            content: _feedbackContentOrPlaceholder(context, review.reviewNote),
            color: _goalOutcomeColor(review.outcomeResult),
            icon: Icons.calendar_view_week_rounded,
            sortAt: _feedbackSortTime(
              review.localDate,
              recordedAt: review.reviewedAt,
            ),
          ),
        )
        .toList(growable: false)
      ..sort((a, b) => b.sortAt.compareTo(a.sortAt));
    return _ExperimentGlassCard(
      key: const ValueKey('goal-weekly-summary-card'),
      title: AppLocaleText.tr(
        context,
        en: 'Weekly summaries',
        zhHans: '周次总结',
        zhHant: '週次總結',
        ja: '週次まとめ',
      ),
      trailing: _StatusPill(
        label: enough
            ? AppLocaleText.tr(
                context,
                en: 'Ready to review',
                zhHans: '可以总结',
                zhHant: '可以總結',
                ja: '振り返り可能',
              )
            : AppLocaleText.tr(
                context,
                en: '$completed/${experiment.minimumObservationDays} observed',
                zhHans: '已观察 $completed/${experiment.minimumObservationDays} 天',
                zhHant: '已觀察 $completed/${experiment.minimumObservationDays} 天',
                ja: '$completed/${experiment.minimumObservationDays} 日観察',
              ),
        color: enough ? AuroraColors.mint : AuroraColors.blue,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocaleText.tr(
              context,
              en: 'Observation progress',
              zhHans: '本周观察进度',
              zhHant: '本週觀察進度',
              ja: '今週の観察状況',
            ),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AuroraColors.ink,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          _GoalObservationTimeline(experiment: experiment, evidence: evidence),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Text(
              enough
                  ? AppLocaleText.tr(
                      context,
                      en: 'The minimum observation days are complete. Add the weekly result from Weekly Review.',
                      zhHans: '已经达到最低观察天数；周次结果需要从每周复盘登记。',
                      zhHant: '已經達到最低觀察天數；週次結果需要從每週複盤登記。',
                      ja: '最低観察日数に達しました。週次結果は毎週の振り返りから登録します。',
                    )
                  : AppLocaleText.tr(
                      context,
                      en: '$completed/${experiment.minimumObservationDays} observation days. Daily completion is a fact; it does not create a weekly conclusion automatically.',
                      zhHans:
                          '已观察 $completed/${experiment.minimumObservationDays} 天。每日完成只是事实，不会自动生成周次结论。',
                      zhHant:
                          '已觀察 $completed/${experiment.minimumObservationDays} 天。每日完成只是事實，不會自動生成週次結論。',
                      ja: '$completed/${experiment.minimumObservationDays} 日観察。毎日の完了は事実であり、週次結論を自動生成しません。',
                    ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AuroraColors.muted,
                    height: 1.42,
                  ),
            ),
          if (entries.isNotEmpty) ...[
            for (var index = 0; index < entries.length; index++) ...[
              _ExperimentFeedbackOverviewRow(entry: entries[index]),
              if (index != entries.length - 1) const Divider(height: 18),
            ],
          ],
        ],
      ),
    );
  }
}

class _GoalFeedbackOverviewCard extends StatelessWidget {
  final List<LifeExperimentFeedbackModel> feedbacks;
  final List<LifeExperimentOutcomeReviewModel> reviews;

  const _GoalFeedbackOverviewCard({
    required this.feedbacks,
    required this.reviews,
  });

  @override
  Widget build(BuildContext context) {
    final entries = <_FeedbackOverviewEntry>[];
    for (final feedback in feedbacks) {
      final content = feedback.feedbackText?.trim() ?? '';
      if (content.isEmpty) continue;
      final completed = _feedbackCountsAsCompleted(feedback.completionStatus);
      entries.add(
        _FeedbackOverviewEntry(
          id: 'daily-${feedback.id}',
          kindLabel: AppLocaleText.tr(
            context,
            en: 'Daily feedback',
            zhHans: '日常反馈',
            zhHant: '日常回饋',
            ja: '日々のフィードバック',
          ),
          overallLabel: completed
              ? AppLocaleText.tr(
                  context,
                  en: 'Completed',
                  zhHans: '已完成',
                  zhHant: '已完成',
                  ja: '完了',
                )
              : AppLocaleText.tr(
                  context,
                  en: 'Not completed',
                  zhHans: '未完成',
                  zhHant: '未完成',
                  ja: '未完了',
                ),
          localDate: feedback.localDate,
          content: content,
          color: completed ? AuroraColors.mint : AuroraColors.orange,
          icon: completed ? Icons.check_rounded : Icons.horizontal_rule_rounded,
          sortAt: _feedbackSortTime(
            feedback.localDate,
            recordedAt: feedback.updatedAt ??
                feedback.createdAt ??
                feedback.feedbackDate,
          ),
        ),
      );
    }
    for (final review in reviews) {
      final isWeekly = review.reviewType == GoalReviewType.weekly;
      entries.add(
        _FeedbackOverviewEntry(
          id: 'review-${review.id}',
          kindLabel: isWeekly
              ? AppLocaleText.tr(
                  context,
                  en: 'Weekly summary',
                  zhHans: '周次总评',
                  zhHant: '週次總評',
                  ja: '週次総評',
                )
              : AppLocaleText.tr(
                  context,
                  en: 'Overall summary',
                  zhHans: '整体总评',
                  zhHant: '整體總評',
                  ja: '全体総評',
                ),
          overallLabel: '${_goalOutcomeLabel(
            context,
            review.outcomeResult,
            review.burden,
          )} · ${_goalBurdenLabel(context, review.burden)}',
          localDate: review.localDate,
          content: _feedbackContentOrPlaceholder(context, review.reviewNote),
          color: _goalOutcomeColor(review.outcomeResult),
          icon: isWeekly
              ? Icons.calendar_view_week_rounded
              : Icons.insights_rounded,
          sortAt: _feedbackSortTime(
            review.localDate,
            recordedAt: review.reviewedAt,
          ),
        ),
      );
    }
    return _ExperimentFeedbackOverviewCard(
      overviewKey: const ValueKey('goal-feedback-overview'),
      entries: entries,
      emptyText: AppLocaleText.tr(
        context,
        en: 'No feedback has been registered yet. Daily completion without content remains in the progress timeline.',
        zhHans: '还没有登记反馈。没有补充内容的每日完成情况仍保留在进度轨迹中。',
        zhHant: '還沒有登記回饋。沒有補充內容的每日完成情況仍保留在進度軌跡中。',
        ja: 'フィードバックはまだありません。内容のない毎日の完了は進捗軌跡に残ります。',
      ),
    );
  }
}

class _LifeExperimentDetailHeroCard extends StatelessWidget {
  final LifeExperimentModel experiment;
  final _ExperimentEvidence evidence;
  final _ExperimentRollup? rollup;

  const _LifeExperimentDetailHeroCard({
    required this.experiment,
    required this.evidence,
    required this.rollup,
  });

  @override
  Widget build(BuildContext context) {
    final color = _experimentColor(experiment);
    final completedDays = _completedGoalObservationDays(evidence);
    final compact = MediaQuery.sizeOf(context).width <= 400;
    final artworkSize = compact ? 104.0 : 120.0;
    return _ExperimentGlassCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Row(
        children: [
          Container(
            width: artworkSize,
            height: artworkSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.88),
                  color.withValues(alpha: 0.38),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
            ),
            child: Icon(
              _experimentIcon(experiment),
              color: color,
              size: compact ? 50 : 58,
            ),
          ),
          SizedBox(width: compact ? 14 : 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  experiment.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AuroraColors.purple,
                        fontWeight: FontWeight.w700,
                        fontSize: compact ? 20 : null,
                        letterSpacing: compact ? -0.25 : null,
                        height: 1.16,
                      ),
                ),
                const SizedBox(height: 10),
                _StatusPill(
                  label: _statusLabel(context, experiment, rollup: rollup),
                  color: _statusColor(experiment),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.calendar_month_rounded,
                        color: AuroraColors.purple, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppLocaleText.tr(
                          context,
                          en: '$completedDays completed days · observe for at least ${experiment.minimumObservationDays} days',
                          zhHans:
                              '已完成 $completedDays 天 · 至少观察 ${experiment.minimumObservationDays} 天',
                          zhHant:
                              '已完成 $completedDays 天 · 至少觀察 ${experiment.minimumObservationDays} 天',
                          ja: '$completedDays 日完了 · 最低 ${experiment.minimumObservationDays} 日観察',
                        ),
                        style: TextStyle(
                          color: AuroraColors.ink.withValues(alpha: 0.68),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExperimentDetailTabBar extends StatelessWidget {
  final _ExperimentDetailTab value;
  final ValueChanged<_ExperimentDetailTab> onChanged;

  const _ExperimentDetailTabBar({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final labels = <_ExperimentDetailTab, String>{
      _ExperimentDetailTab.overview: AppLocaleText.tr(
        context,
        en: 'Overview',
        zhHans: '概览',
        zhHant: '概覽',
        ja: '概要',
      ),
      _ExperimentDetailTab.feedback: AppLocaleText.tr(
        context,
        en: 'Feedback records',
        zhHans: '反馈记录',
        zhHant: '回饋記錄',
        ja: 'フィードバック',
      ),
      _ExperimentDetailTab.conditions: AppLocaleText.tr(
        context,
        en: 'Conditions & patterns',
        zhHans: '条件与模式',
        zhHant: '條件與模式',
        ja: '条件とパターン',
      ),
      _ExperimentDetailTab.notes: AppLocaleText.tr(
        context,
        en: 'Notes',
        zhHans: '笔记',
        zhHant: '筆記',
        ja: 'メモ',
      ),
    };
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final tab = _ExperimentDetailTab.values[index];
          final selected = tab == value;
          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => onChanged(tab),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.9)
                    : Colors.white.withValues(alpha: 0.38),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected
                      ? AuroraColors.purple.withValues(alpha: 0.28)
                      : Colors.white.withValues(alpha: 0.62),
                ),
              ),
              child: Text(
                labels[tab]!,
                style: TextStyle(
                  color: selected ? AuroraColors.purple : AuroraColors.ink,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemCount: _ExperimentDetailTab.values.length,
      ),
    );
  }
}

class _ExperimentRollupStatsCard extends StatelessWidget {
  final LifeExperimentModel experiment;
  final _ExperimentRollup? rollup;
  final int triedCount;

  const _ExperimentRollupStatsCard({
    required this.experiment,
    required this.rollup,
    required this.triedCount,
  });

  @override
  Widget build(BuildContext context) {
    final tried = rollup?.triedCount ?? triedCount;
    final helpful = rollup?.helpfulCount ?? 0;
    final adjusted = rollup?.adjustedCount ?? 0;
    final skipped = rollup?.skippedCount ?? 0;
    return _ExperimentGlassCard(
      title: AppLocaleText.tr(
        context,
        en: 'Goal timeline summary',
        zhHans: '目标时间线汇总',
        zhHant: '目標時間線彙總',
        ja: '目標タイムライン集計',
      ),
      trailing: _StatusPill(
        label: _statusLabel(context, experiment, rollup: rollup),
        color: _statusColor(experiment),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _DetailMetric(
                  icon: Icons.play_circle_outline_rounded,
                  label: AppLocaleText.tr(
                    context,
                    en: 'Tried',
                    zhHans: '尝试',
                    zhHant: '嘗試',
                    ja: '試行',
                  ),
                  value: '$tried',
                  color: AuroraColors.purple,
                ),
              ),
              Expanded(
                child: _DetailMetric(
                  icon: Icons.thumb_up_alt_rounded,
                  label: AppLocaleText.tr(
                    context,
                    en: 'Helpful',
                    zhHans: '有效',
                    zhHant: '有效',
                    ja: '有効',
                  ),
                  value: '$helpful',
                  color: AuroraColors.mint,
                ),
              ),
              Expanded(
                child: _DetailMetric(
                  icon: Icons.tune_rounded,
                  label: AppLocaleText.tr(
                    context,
                    en: 'Adjusted',
                    zhHans: '调整',
                    zhHant: '調整',
                    ja: '調整',
                  ),
                  value: '$adjusted',
                  color: AuroraColors.orange,
                ),
              ),
              Expanded(
                child: _DetailMetric(
                  icon: Icons.pause_circle_outline_rounded,
                  label: AppLocaleText.tr(
                    context,
                    en: 'Skipped',
                    zhHans: '跳过',
                    zhHant: '跳過',
                    ja: 'スキップ',
                  ),
                  value: '$skipped',
                  color: AuroraColors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _rollupEffectSummary(context, experiment, rollup),
            style: TextStyle(
              color: AuroraColors.ink.withValues(alpha: 0.72),
              height: 1.48,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExperimentLifecycleTimelineCard extends StatelessWidget {
  final LifeExperimentModel experiment;
  final List<_ExperimentLifecycleEvent> lifecycle;

  const _ExperimentLifecycleTimelineCard({
    required this.experiment,
    required this.lifecycle,
  });

  @override
  Widget build(BuildContext context) {
    final events = lifecycle.isEmpty
        ? [
            _ExperimentLifecycleEvent(
              id: 'fallback_${experiment.id}',
              experimentId: experiment.id,
              eventType: 'created',
              eventDate: experiment.createdAt,
              localDate: experiment.sourceWeekStart,
              sourceType: 'life_experiment',
              sourceId: experiment.id,
              statusFrom: null,
              statusTo: experiment.status,
              payload: const {},
            ),
          ]
        : lifecycle;
    return _ExperimentGlassCard(
      title: AppLocaleText.tr(
        context,
        en: 'Lifecycle timeline',
        zhHans: '生命周期时间线',
        zhHant: '生命週期時間線',
        ja: 'ライフサイクル',
      ),
      child: Column(
        children: [
          for (var i = 0; i < events.length; i++)
            _LifecycleEventRow(
              event: events[i],
              isLast: i == events.length - 1,
            ),
        ],
      ),
    );
  }
}

class _LifecycleEventRow extends StatelessWidget {
  final _ExperimentLifecycleEvent event;
  final bool isLast;

  const _LifecycleEventRow({
    required this.event,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final color = _lifecycleColor(event.eventType);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child:
                  Icon(_lifecycleIcon(event.eventType), color: color, size: 17),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 34,
                color: color.withValues(alpha: 0.18),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _lifecycleLabel(context, event),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AuroraColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  _eventMeta(context, event),
                  style: TextStyle(
                    color: AuroraColors.ink.withValues(alpha: 0.58),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ExperimentLineageCard extends StatelessWidget {
  final _ExperimentRollup rollup;

  const _ExperimentLineageCard({required this.rollup});

  @override
  Widget build(BuildContext context) {
    final lineage = rollup.lineage;
    return _ExperimentGlassCard(
      title: AppLocaleText.tr(
        context,
        en: 'Append / continue history',
        zhHans: '追加 / 延续历史',
        zhHant: '追加 / 延續歷史',
        ja: '追加 / 継続履歴',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocaleText.tr(
              context,
              en: 'This goal belongs to a visible history chain. New weeks are appended or continued without overwriting the original.',
              zhHans: '这个目标属于一条可见的历史链。追加或延续到新周期时，不会覆盖原目标。',
              zhHant: '這個目標屬於一條可見的歷史鏈。追加或延續到新週期時，不會覆蓋原目標。',
              ja: 'この目標は見える履歴チェーンに属します。追加・継続しても元の目標は上書きしません。',
            ),
            style: TextStyle(
              color: AuroraColors.ink.withValues(alpha: 0.70),
              height: 1.45,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < lineage.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  _StatusPill(
                    label: i == 0
                        ? AppLocaleText.tr(
                            context,
                            en: 'Root',
                            zhHans: '原始',
                            zhHant: '原始',
                            ja: '元',
                          )
                        : AppLocaleText.tr(
                            context,
                            en: 'Continue',
                            zhHans: '延续',
                            zhHant: '延續',
                            ja: '継続',
                          ),
                    color: i == 0 ? AuroraColors.purple : AuroraColors.blue,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${lineage[i]['source_week_start'] ?? ''} · ${lineage[i]['title'] ?? rollup.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AuroraColors.ink.withValues(alpha: 0.72),
                        fontWeight: FontWeight.w800,
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

class _ExperimentOverviewTab extends StatelessWidget {
  final LifeExperimentModel experiment;
  final _ExperimentEvidence evidence;
  final _ExperimentRollup? rollup;
  final List<_ExperimentLifecycleEvent> lifecycle;
  final List<_TrendPoint> points;
  final int triedCount;

  const _ExperimentOverviewTab({
    required this.experiment,
    required this.evidence,
    required this.rollup,
    required this.lifecycle,
    required this.points,
    required this.triedCount,
  });

  @override
  Widget build(BuildContext context) {
    final keywords = evidence.keywordsFor(context, experiment);
    return Column(
      children: [
        _ExperimentRollupStatsCard(
          experiment: experiment,
          rollup: rollup,
          triedCount: triedCount,
        ),
        const SizedBox(height: 12),
        _ExperimentLifecycleTimelineCard(
          experiment: experiment,
          lifecycle: lifecycle,
        ),
        if (rollup?.hasLineage == true) ...[
          const SizedBox(height: 12),
          _ExperimentLineageCard(rollup: rollup!),
        ],
        const SizedBox(height: 12),
        _ExperimentGlassCard(
          child: Row(
            children: [
              SizedBox(
                width: 132,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocaleText.tr(
                        context,
                        en: 'Real records',
                        zhHans: '真实记录',
                        zhHant: '真實記錄',
                        ja: '実際の記録',
                      ),
                      style: TextStyle(
                        color: AuroraColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${evidence.evidenceCount}',
                      style: TextStyle(
                        color: AuroraColors.purple,
                        fontSize: 50,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      AppLocaleText.tr(
                        context,
                        en: '${evidence.feedbacks.length} feedback · ${evidence.signals.length} signals',
                        zhHans:
                            '${evidence.feedbacks.length} 条反馈 · ${evidence.signals.length} 条信号',
                        zhHant:
                            '${evidence.feedbacks.length} 條回饋 · ${evidence.signals.length} 條信號',
                        ja: '${evidence.feedbacks.length} 件の反応 · ${evidence.signals.length} 件のシグナル',
                      ),
                      style: TextStyle(
                        color: AuroraColors.ink.withValues(alpha: 0.55),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _TrendLineChart(points: points)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ExperimentGlassCard(
          title: AppLocaleText.tr(
            context,
            en: 'Keywords',
            zhHans: '关键词',
            zhHant: '關鍵詞',
            ja: 'キーワード',
          ),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final item in keywords)
                _KeywordPill(
                  label: item.label,
                  icon: item.icon,
                  color: item.color,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ExperimentGlassCard(
          title: AppLocaleText.tr(
            context,
            en: 'Summary',
            zhHans: '总结',
            zhHant: '總結',
            ja: 'まとめ',
          ),
          child: Text(
            _rollupEffectSummary(context, experiment, rollup),
            style: TextStyle(
              color: AuroraColors.ink.withValues(alpha: 0.76),
              fontSize: 16,
              height: 1.55,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _ExperimentGlassCard(
          title: AppLocaleText.tr(
            context,
            en: 'Add to this week',
            zhHans: '追加到本周',
            zhHant: '追加到本週',
            ja: '今週に追加',
          ),
          child: Row(
            children: [
              Expanded(
                child: _ReuseChoiceTile(
                  icon: Icons.refresh_rounded,
                  color: AuroraColors.purple,
                  title: AppLocaleText.tr(
                    context,
                    en: 'Keep original',
                    zhHans: '继续原方案',
                    zhHant: '繼續原方案',
                    ja: 'そのまま',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ReuseChoiceTile(
                  icon: Icons.access_time_rounded,
                  color: AuroraColors.blue,
                  title: AppLocaleText.tr(
                    context,
                    en: 'Adjust time',
                    zhHans: '调整时间',
                    zhHant: '調整時間',
                    ja: '時間調整',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ReuseChoiceTile(
                  icon: Icons.center_focus_strong_rounded,
                  color: AuroraColors.mint,
                  title: AppLocaleText.tr(
                    context,
                    en: 'Keep core',
                    zhHans: '保留核心',
                    zhHant: '保留核心',
                    ja: '核を残す',
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

class _ExperimentFeedbackTab extends StatelessWidget {
  final LifeExperimentModel experiment;
  final _ExperimentEvidence evidence;
  final List<_TrendPoint> points;
  final int triedCount;

  const _ExperimentFeedbackTab({
    required this.experiment,
    required this.evidence,
    required this.points,
    required this.triedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ExperimentGlassCard(
          title: AppLocaleText.tr(
            context,
            en: 'Overall trend',
            zhHans: '总体趋势',
            zhHant: '總體趨勢',
            ja: '全体傾向',
          ),
          trailing: _StatusPill(
            label: AppLocaleText.tr(
              context,
              en: 'Recent dates',
              zhHans: '近期日期',
              zhHant: '近期日期',
              ja: '最近',
            ),
            color: AuroraColors.purple,
          ),
          child: Column(
            children: [
              _TrendLineChart(points: points, height: 190),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _DetailMetric(
                      icon: Icons.star_rounded,
                      label: AppLocaleText.tr(
                        context,
                        en: 'Feedback',
                        zhHans: '反馈',
                        zhHant: '回饋',
                        ja: '反応',
                      ),
                      value: '${evidence.feedbacks.length}',
                      color: AuroraColors.purple,
                    ),
                  ),
                  Expanded(
                    child: _DetailMetric(
                      icon: Icons.trending_up_rounded,
                      label: AppLocaleText.tr(
                        context,
                        en: 'Signals',
                        zhHans: '信号',
                        zhHant: '信號',
                        ja: 'シグナル',
                      ),
                      value: '${evidence.signals.length}',
                      color: AuroraColors.mint,
                    ),
                  ),
                  Expanded(
                    child: _DetailMetric(
                      icon: Icons.favorite_rounded,
                      label: AppLocaleText.tr(
                        context,
                        en: 'Tried',
                        zhHans: '尝试',
                        zhHant: '嘗試',
                        ja: '試行',
                      ),
                      value: '$triedCount',
                      color: AuroraColors.gold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ExperimentGlassCard(
          title: AppLocaleText.tr(
            context,
            en: 'Feedback list',
            zhHans: '反馈列表',
            zhHant: '回饋列表',
            ja: 'フィードバック一覧',
          ),
          trailing: _StatusPill(
            label: AppLocaleText.tr(
              context,
              en: 'Latest',
              zhHans: '最新优先',
              zhHant: '最新優先',
              ja: '最新',
            ),
            color: AuroraColors.muted,
          ),
          child: Column(
            children: [
              if (evidence.feedbacks.isEmpty)
                Text(
                  AppLocaleText.tr(
                    context,
                    en: 'No feedback yet. Record one from Today to make this pattern more personal.',
                    zhHans: '还没有反馈。可以从今天记录一次，让这个模式更贴近你。',
                    zhHant: '還沒有回饋。可以從今天記錄一次，讓這個模式更貼近你。',
                    ja: 'まだ反応がありません。今日から一つ残すと、より自分に近い読みになります。',
                  ),
                )
              else
                for (final feedback in evidence.feedbacks.reversed.take(4))
                  _FeedbackRow(
                    date: feedback.feedbackDate,
                    score: evidence.valueForFeedback(feedback),
                    text: feedback.feedbackText?.trim().isNotEmpty == true
                        ? feedback.feedbackText!.trim()
                        : _readableEvidenceLabel(
                            context,
                            feedback.completionStatus,
                          ),
                  ),
              if (evidence.feedbacks.isEmpty)
                for (final point in points.reversed.take(3))
                  _FeedbackRow(
                    date: point.date,
                    score: point.value,
                    text: experiment.feedbackText?.trim().isNotEmpty == true
                        ? experiment.feedbackText!.trim()
                        : AppLocaleText.tr(
                            context,
                            en: 'This attempt added one more real signal to compare.',
                            zhHans: '这次尝试又增加了一条可以比较的真实信号。',
                            zhHant: '這次嘗試又增加了一條可以比較的真實信號。',
                            ja: 'この試行で比較できる信号が増えました。',
                          ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExperimentConditionsTab extends StatelessWidget {
  final LifeExperimentModel experiment;
  final _ExperimentEvidence evidence;

  const _ExperimentConditionsTab({
    required this.experiment,
    required this.evidence,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          AppLocaleText.tr(
            context,
            en: 'Current goal: ${experiment.title}',
            zhHans: '当前目标：${experiment.title}',
            zhHant: '當前目標：${experiment.title}',
            ja: '現在の目標：${experiment.title}',
          ),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AuroraColors.ink.withValues(alpha: 0.72),
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 12),
        _ExperimentGlassCard(
          title: AppLocaleText.tr(
            context,
            en: 'When does it work better?',
            zhHans: '什么时候更有效？',
            zhHant: '什麼時候更有效？',
            ja: 'いつ効きやすい？',
          ),
          child: Row(
            children: [
              for (final item in evidence.conditionKeywords(context).take(4))
                Expanded(
                  child: _ConditionTile(
                    icon: item.icon,
                    color: item.color,
                    label: item.label,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ExperimentGlassCard(
          title: AppLocaleText.tr(
            context,
            en: 'Environment conditions',
            zhHans: '环境条件',
            zhHant: '環境條件',
            ja: '環境条件',
          ),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final item
                  in evidence.keywordsFor(context, experiment).take(5))
                _KeywordPill(
                  icon: item.icon,
                  label: item.label,
                  color: item.color,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ExperimentGlassCard(
          title: AppLocaleText.tr(
            context,
            en: 'Duration distribution',
            zhHans: '持续时间分布',
            zhHant: '持續時間分布',
            ja: '時間分布',
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 130,
                height: 130,
                child: CustomPaint(painter: _DurationDonutPainter()),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    for (final bucket in evidence.durationBuckets(context))
                      _DurationLegend(
                        color: bucket.color,
                        text: bucket.label,
                        value: '${bucket.count}',
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ExperimentGlassCard(
          title: AppLocaleText.tr(
            context,
            en: 'My action preferences',
            zhHans: '我的行动偏好',
            zhHant: '我的行動偏好',
            ja: '行動の好み',
          ),
          child: Column(
            children: [
              for (final line in evidence.preferenceLines(context))
                _PreferenceLine(
                  icon: Icons.auto_awesome_rounded,
                  text: line,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ExperimentGlassCard(
          title: AppLocaleText.tr(
            context,
            en: 'AI insight',
            zhHans: '智能洞察',
            zhHant: '智慧洞察',
            ja: '人工知能による洞察',
          ),
          child: Text(
            evidence.insightText(context),
            style: TextStyle(
              color: AuroraColors.ink.withValues(alpha: 0.72),
              height: 1.55,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ExperimentNotesTab extends StatelessWidget {
  final LifeExperimentModel experiment;

  const _ExperimentNotesTab({required this.experiment});

  @override
  Widget build(BuildContext context) {
    return _ExperimentGlassCard(
      title: AppLocaleText.tr(
        context,
        en: 'Goal notes',
        zhHans: '目标笔记',
        zhHant: '目標筆記',
        ja: '目標メモ',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NotesLine(
            icon: Icons.science_rounded,
            label: AppLocaleText.tr(
              context,
              en: 'Goal',
              zhHans: '目标',
              zhHant: '目標',
              ja: '目標',
            ),
            value: experiment.title,
          ),
          _NotesLine(
            icon: Icons.flag_rounded,
            label: AppLocaleText.tr(
              context,
              en: 'Daily practice',
              zhHans: '每日做法',
              zhHant: '每日做法',
              ja: '毎日の取り組み',
            ),
            value: experiment.suggestedAction,
          ),
          _NotesLine(
            icon: Icons.lightbulb_rounded,
            label: AppLocaleText.tr(
              context,
              en: 'Why it matters',
              zhHans: '为什么做',
              zhHant: '為什麼做',
              ja: '理由',
            ),
            value: experiment.hypothesis,
          ),
        ],
      ),
    );
  }
}

class _MoreBubble extends StatelessWidget {
  const _MoreBubble();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.78),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
      ),
      child: Icon(Icons.more_horiz_rounded, color: AuroraColors.purple),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: (MediaQuery.sizeOf(context).width * 0.46)
            .clamp(116.0, 184.0)
            .toDouble(),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, color: color, size: 15),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBubble extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _IconBubble({
    required this.icon,
    required this.color,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.9),
            color.withValues(alpha: 0.28),
          ],
        ),
      ),
      child: Icon(icon, color: color, size: size * 0.52),
    );
  }
}

class _KeywordPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _KeywordPill({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: (MediaQuery.sizeOf(context).width - 96)
            .clamp(150.0, 248.0)
            .toDouble(),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _IconBubble(icon: icon, color: color, size: 30),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AuroraColors.ink.withValues(alpha: 0.74),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendLineChart extends StatelessWidget {
  final List<_TrendPoint> points;
  final double height;

  const _TrendLineChart({required this.points, this.height = 180});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _TrendLinePainter(points),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(left: 26, right: 10, bottom: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final point in points)
                  Expanded(
                    child: Text(
                      point.label,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      textAlign: TextAlign.center,
                      softWrap: false,
                      style: TextStyle(
                        color: AuroraColors.ink.withValues(alpha: 0.48),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrendLinePainter extends CustomPainter {
  final List<_TrendPoint> points;

  const _TrendLinePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final chart = Rect.fromLTWH(24, 10, size.width - 34, size.height - 38);
    final gridPaint = Paint()
      ..color = AuroraColors.line.withValues(alpha: 0.65)
      ..strokeWidth = 1;
    for (var i = 0; i < 5; i++) {
      final y = chart.top + chart.height * i / 4;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }
    if (points.isEmpty) return;
    Offset offsetFor(int index) {
      final x = points.length == 1
          ? chart.center.dx
          : chart.left + chart.width * index / (points.length - 1);
      final normalized = ((points[index].value - 1) / 4).clamp(0.0, 1.0);
      final y = chart.bottom - chart.height * normalized;
      return Offset(x, y);
    }

    final line = Path()..moveTo(offsetFor(0).dx, offsetFor(0).dy);
    for (var i = 1; i < points.length; i++) {
      line.lineTo(offsetFor(i).dx, offsetFor(i).dy);
    }
    final fill = Path.from(line)
      ..lineTo(offsetFor(points.length - 1).dx, chart.bottom)
      ..lineTo(offsetFor(0).dx, chart.bottom)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AuroraColors.purple.withValues(alpha: 0.22),
            AuroraColors.blue.withValues(alpha: 0.02),
          ],
        ).createShader(chart),
    );
    canvas.drawPath(
      line,
      Paint()
        ..shader = LinearGradient(
          colors: [AuroraColors.purple, AuroraColors.orange, AuroraColors.blue],
        ).createShader(chart)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    for (var i = 0; i < points.length; i++) {
      final point = offsetFor(i);
      canvas.drawCircle(point, 8, Paint()..color = Colors.white);
      canvas.drawCircle(
        point,
        6,
        Paint()
          ..shader = LinearGradient(
            colors: [AuroraColors.purple, AuroraColors.blue],
          ).createShader(Rect.fromCircle(center: point, radius: 8)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrendLinePainter oldDelegate) =>
      oldDelegate.points != points;
}

class _ReuseChoiceTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;

  const _ReuseChoiceTile({
    required this.icon,
    required this.color,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
      ),
      child: Column(
        children: [
          _IconBubble(icon: icon, color: color, size: 42),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AuroraColors.ink.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _DetailMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _IconBubble(icon: icon, color: color, size: 32),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AuroraColors.ink.withValues(alpha: 0.52),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _FeedbackRow extends StatelessWidget {
  final DateTime date;
  final double score;
  final String text;

  const _FeedbackRow({
    required this.date,
    required this.score,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final color = score >= 4
        ? AuroraColors.orange
        : score >= 3
            ? AuroraColors.mint
            : AuroraColors.blue;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.48),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
        ),
        child: Row(
          children: [
            _IconBubble(
                icon: Icons.sentiment_satisfied_alt_rounded,
                color: color,
                size: 46),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_dateLabel(date)}  •  ${score.round()}/5',
                    style: TextStyle(
                      color: AuroraColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AuroraColors.ink.withValues(alpha: 0.66),
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AuroraColors.muted),
          ],
        ),
      ),
    );
  }
}

class _ConditionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _ConditionTile({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
      ),
      child: Column(
        children: [
          _IconBubble(icon: icon, color: color, size: 48),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AuroraColors.ink.withValues(alpha: 0.72),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _DurationLegend extends StatelessWidget {
  final Color color;
  final String text;
  final String value;

  const _DurationLegend({
    required this.color,
    required this.text,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AuroraColors.ink.withValues(alpha: 0.7),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _DurationDonutPainter extends CustomPainter {
  const _DurationDonutPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = size.shortestSide / 2 - 10;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;
    var start = -math.pi / 2;
    final segments = [
      (AuroraColors.purple, 0.6),
      (AuroraColors.orange, 0.3),
      (AuroraColors.mint, 0.1),
    ];
    for (final segment in segments) {
      paint.color = segment.$1;
      final sweep = math.pi * 2 * segment.$2;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep - 0.08,
        false,
        paint,
      );
      start += sweep;
    }
    canvas.drawCircle(
      center,
      radius - 22,
      Paint()..color = Colors.white.withValues(alpha: 0.42),
    );
    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.access_time_rounded.codePoint),
        style: TextStyle(
          fontFamily: Icons.access_time_rounded.fontFamily,
          fontSize: 28,
          color: AuroraColors.purple.withValues(alpha: 0.72),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    iconPainter.paint(
      canvas,
      center - Offset(iconPainter.width / 2, iconPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PreferenceLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PreferenceLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _IconBubble(icon: icon, color: AuroraColors.purple, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AuroraColors.ink.withValues(alpha: 0.7),
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _NotesLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBubble(icon: icon, color: AuroraColors.purple, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AuroraColors.purple,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.trim().isEmpty ? '-' : value.trim(),
                  style: TextStyle(
                    color: AuroraColors.ink.withValues(alpha: 0.74),
                    height: 1.45,
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

class _NextExperimentDetail {
  final String title;
  final String description;
  final String reason;
  final String reviewTitle;
  final String reviewResult;
  final String reviewReflection;
  final List<_TryOption> options;

  const _NextExperimentDetail({
    required this.title,
    required this.description,
    required this.reason,
    required this.reviewTitle,
    required this.reviewResult,
    required this.reviewReflection,
    required this.options,
  });

  static _NextExperimentDetail fromWeekly(
    BuildContext context,
    WeeklyInsightModel? weekly,
  ) {
    final experiment = weekly?.lifeExperiment;
    final actionPlan = weekly?.deriveActionPlan();
    final structure = weekly?.deriveV3CStructure();
    final review = weekly?.actionReview ?? const WeeklyActionReviewModel();
    final title = actionPlan?.title.trim().isNotEmpty == true
        ? actionPlan!.title.trim()
        : experiment?.title.trim().isNotEmpty == true
            ? experiment!.title.trim()
            : AppLocaleText.tr(
                context,
                en: 'Let recovery happen before pushing forward',
                zhHans: '先让恢复发生，再谈推进',
                zhHant: '先讓恢復發生，再談推進',
                ja: '回復を先に起こしてから進める',
              );
    final description = actionPlan?.smallExperiment.trim().isNotEmpty == true
        ? actionPlan!.smallExperiment.trim()
        : experiment?.suggestedAction.trim().isNotEmpty == true
            ? experiment!.suggestedAction.trim()
            : AppLocaleText.tr(
                context,
                en: 'Next week, first let a 10-minute recovery action appear at night before deciding whether to continue pushing tasks.',
                zhHans: '下周优先让晚上出现一个 10 分钟恢复动作，再决定要不要继续推进任务。',
                zhHant: '下週優先讓晚上出現一個 10 分鐘恢復動作，再決定要不要繼續推進任務。',
                ja: '来週は夜に10分の回復行動を先に置き、続けて進めるか決めます。',
              );
    final reason = experiment?.hypothesis.trim().isNotEmpty == true
        ? experiment!.hypothesis.trim()
        : structure?.lightObservation.trim().isNotEmpty == true
            ? structure!.lightObservation.trim()
            : AppLocaleText.tr(
                context,
                en: 'This week, the issue was not simply “not doing it”; recovery was interrupted, making it hard to stabilize again. Letting recovery happen first can make later action easier.',
                zhHans: '这周你最常出现的不是“做不到”，而是恢复一被打断，就很难重新稳定下来。先让恢复发生，更容易带动后续行动。',
                zhHant: '這週你最常出現的不是「做不到」，而是恢復一被打斷，就很難重新穩定下來。先讓恢復發生，更容易帶動後續行動。',
                ja: '今週は「できない」より、回復が中断されると整い直しにくい流れが目立ちました。先に回復を置くと次の行動が楽になります。',
              );
    return _NextExperimentDetail(
      title: title,
      description: description,
      reason: reason,
      reviewTitle: structure?.onePattern.trim().isNotEmpty == true
          ? structure!.onePattern.trim()
          : AppLocaleText.tr(
              context,
              en: 'Give recovery a lighter structure',
              zhHans: '给休息加一个轻结构',
              zhHant: '給休息加一個輕結構',
              ja: '回復に軽い構造を足す',
            ),
      reviewResult: review.helpfulActionCount > 0
          ? AppLocaleText.tr(
              context,
              en: 'Partly helpful',
              zhHans: '部分有效',
              zhHant: '部分有效',
              ja: '一部有効',
            )
          : AppLocaleText.tr(
              context,
              en: 'Still forming',
              zhHans: '还在形成',
              zhHant: '還在形成',
              ja: '形成中',
            ),
      reviewReflection: review.nextAdjustment.trim().isNotEmpty
          ? review.nextAdjustment.trim()
          : AppLocaleText.tr(
              context,
              en: 'Low-pressure recovery at night is easier to start; when mornings are dense, it is harder to keep.',
              zhHans: '晚上 10 分钟的低压力恢复更容易发生；早上安排太多时不容易坚持。',
              zhHant: '晚上 10 分鐘的低壓力恢復更容易發生；早上安排太多時不容易堅持。',
              ja: '夜の10分の低負荷な回復は始めやすく、朝が詰まると続きにくい。',
            ),
      options: _buildOptions(
        primary: description,
        review: review,
        fallback: structure?.oneExperiment,
      ),
    );
  }

  static List<_TryOption> _buildOptions({
    required String primary,
    required WeeklyActionReviewModel review,
    required String? fallback,
  }) {
    final labels = <String>[
      primary,
      review.nextAdjustment,
      review.mostHelpfulAction,
      fallback ?? '',
    ]
        .map((label) => label.trim())
        .where((label) => label.isNotEmpty)
        .toSet()
        .take(4)
        .toList();
    return labels
        .map(
          (label) => _TryOption(
            icon: _iconForOption(label),
            label: label,
            color: _colorForOption(label),
          ),
        )
        .toList();
  }

  static IconData _iconForOption(String label) {
    if (label.contains('睡') || label.contains('晚')) {
      return Icons.nights_stay_rounded;
    }
    if (label.contains('写') || label.contains('记录')) return Icons.edit_rounded;
    if (label.contains('走') || label.contains('散步')) {
      return Icons.directions_walk_rounded;
    }
    if (label.contains('拉伸') || label.contains('身体')) {
      return Icons.accessibility_new_rounded;
    }
    if (label.contains('休息') || label.contains('恢复')) return Icons.spa_rounded;
    return Icons.star_rounded;
  }

  static Color _colorForOption(String label) {
    if (label.contains('写') || label.contains('记录')) return AuroraColors.blue;
    if (label.contains('走') || label.contains('散步')) {
      return const Color(0xFF35C5C9);
    }
    return AuroraColors.purple;
  }
}

class _TryOption {
  final IconData icon;
  final String label;
  final Color color;

  const _TryOption({
    required this.icon,
    required this.label,
    required this.color,
  });
}

class _NextExperimentHeroCard extends StatelessWidget {
  final _NextExperimentDetail detail;

  const _NextExperimentHeroCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    return _ExperimentGlassCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 390;
          const illustration = _FlaskBubble(size: 132);
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                detail.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AuroraColors.purple,
                      fontWeight: FontWeight.w700,
                      height: 1.16,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                detail.description,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF35415C),
                      height: 1.48,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Text(
                    AppLocaleText.tr(
                      context,
                      en: 'Progress',
                      zhHans: '目标进度',
                      zhHant: '目標進度',
                      ja: '進捗',
                    ),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AuroraColors.purple,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(child: _ProgressBar(value: 0)),
                  const SizedBox(width: 14),
                  Text(
                    '0/7',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: const Color(0xFF566078),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ],
          );
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: illustration),
                const SizedBox(height: 12),
                copy,
              ],
            );
          }
          return Row(
            children: [
              illustration,
              const SizedBox(width: 24),
              Expanded(child: copy),
            ],
          );
        },
      ),
    );
  }
}

class _TryThisWeekCard extends StatelessWidget {
  final List<_TryOption> options;

  const _TryThisWeekCard({required this.options});

  @override
  Widget build(BuildContext context) {
    return _ExperimentGlassCard(
      title: AppLocaleText.tr(
        context,
        en: 'How to try this week',
        zhHans: '这一周可以怎么试',
        zhHant: '這一週可以怎麼試',
        ja: '今週どう試すか',
      ),
      child: Column(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            _TryOptionTile(option: options[i]),
            if (i != options.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _NextExperimentEditCard extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController actionController;
  final List<_TryOption> options;
  final int frequencyDays;
  final ValueChanged<int> onFrequencyChanged;
  final ValueChanged<int> onDeleteOption;
  final VoidCallback onAddOption;

  const _NextExperimentEditCard({
    required this.titleController,
    required this.actionController,
    required this.options,
    required this.frequencyDays,
    required this.onFrequencyChanged,
    required this.onDeleteOption,
    required this.onAddOption,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ExperimentGlassCard(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          child: Column(
            children: [
              _ExperimentLabeledEditRow(
                icon: Icons.science_rounded,
                label: AppLocaleText.tr(
                  context,
                  en: 'Goal name',
                  zhHans: '目标名称',
                  zhHant: '目標名稱',
                  ja: '目標名',
                ),
                field: _ExperimentEditField(
                  controller: titleController,
                  label: AppLocaleText.tr(
                    context,
                    en: 'Goal name',
                    zhHans: '目标名称',
                    zhHant: '目標名稱',
                    ja: '目標名',
                  ),
                ),
              ),
              Divider(
                height: 26,
                color: AuroraColors.line.withValues(alpha: 0.62),
              ),
              _ExperimentLabeledEditRow(
                icon: Icons.track_changes_rounded,
                label: AppLocaleText.tr(
                  context,
                  en: 'Daily practice',
                  zhHans: '每日做法',
                  zhHant: '每日做法',
                  ja: '毎日の取り組み',
                ),
                field: _ExperimentEditField(
                  controller: actionController,
                  label: AppLocaleText.tr(
                    context,
                    en: 'Daily practice',
                    zhHans: '每日做法',
                    zhHant: '每日做法',
                    ja: '毎日の取り組み',
                  ),
                  minLines: 2,
                  maxLines: 3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _ExperimentGlassCard(
          title: AppLocaleText.tr(
            context,
            en: 'How to try this week',
            zhHans: '这一周可以怎么试',
            zhHant: '這一週可以怎麼試',
            ja: '今週どう試すか',
          ),
          child: Column(
            children: [
              for (var i = 0; i < options.length; i++) ...[
                _EditableTryOptionTile(
                  option: options[i],
                  onDelete: () => onDeleteOption(i),
                ),
                if (i != options.length - 1) const SizedBox(height: 8),
              ],
              const SizedBox(height: 12),
              _AddTryOptionButton(onTap: onAddOption),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _EditSettingRow(
          icon: Icons.calendar_month_rounded,
          label: AppLocaleText.tr(
            context,
            en: 'Goal frequency',
            zhHans: '目标频率',
            zhHant: '目標頻率',
            ja: '目標の頻度',
          ),
          trailing: _FrequencySegmentedControl(
            value: frequencyDays,
            onChanged: onFrequencyChanged,
          ),
        ),
        const SizedBox(height: 10),
        _EditSettingRow(
          icon: Icons.notifications_rounded,
          label: AppLocaleText.tr(
            context,
            en: 'Reminder time',
            zhHans: '提醒时间',
            zhHant: '提醒時間',
            ja: 'リマインダー',
          ),
          trailing: _ReminderPill(
            label: AppLocaleText.tr(
              context,
              en: 'Evening 9:30',
              zhHans: '晚上 9:30',
              zhHant: '晚上 9:30',
              ja: '夜 9:30',
            ),
          ),
        ),
        const SizedBox(height: 10),
        _ExperimentGlassCard(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const AuroraSoftIconCircle(
                    icon: Icons.favorite_rounded,
                    color: AuroraColors.purple,
                    size: 44,
                    iconSize: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    AppLocaleText.tr(
                      context,
                      en: 'If it is too hard, change it to',
                      zhHans: '如果太难，可以改成',
                      zhHant: '如果太難，可以改成',
                      ja: '難しければこう変える',
                    ),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: const Color(0xFF263653),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _FallbackChip(
                    icon: Icons.schedule_rounded,
                    label: AppLocaleText.tr(
                      context,
                      en: 'Only 5 minutes',
                      zhHans: '只做 5 分钟',
                      zhHant: '只做 5 分鐘',
                      ja: '5分だけ',
                    ),
                    color: AuroraColors.purple,
                  ),
                  _FallbackChip(
                    icon: Icons.check_circle_outline_rounded,
                    label: AppLocaleText.tr(
                      context,
                      en: 'Only one action',
                      zhHans: '只选一个动作',
                      zhHant: '只選一個動作',
                      ja: '一つだけ',
                    ),
                    color: const Color(0xFF35C5C9),
                  ),
                  _FallbackChip(
                    icon: Icons.do_not_disturb_on_outlined,
                    label: AppLocaleText.tr(
                      context,
                      en: 'No pushing today',
                      zhHans: '今天不推进',
                      zhHant: '今天不推進',
                      ja: '今日は進めない',
                    ),
                    color: AuroraColors.orange,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExperimentLabeledEditRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget field;

  const _ExperimentLabeledEditRow({
    required this.icon,
    required this.label,
    required this.field,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final labelBlock = Row(
          children: [
            AuroraSoftIconCircle(
              icon: icon,
              color: AuroraColors.purple,
              size: 58,
              iconSize: 30,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF223653),
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        );
        if (constraints.maxWidth < 420) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              labelBlock,
              const SizedBox(height: 12),
              field,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(width: 188, child: labelBlock),
            Expanded(child: field),
          ],
        );
      },
    );
  }
}

class _ExperimentEditField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int minLines;
  final int maxLines;

  const _ExperimentEditField({
    required this.controller,
    required this.label,
    this.minLines = 1,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      textInputAction: maxLines == 1 ? TextInputAction.next : null,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.edit_rounded, color: AuroraColors.purple),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.58),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: AuroraColors.purple.withValues(alpha: 0.18),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AuroraColors.purple, width: 1.4),
        ),
      ),
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: const Color(0xFF303A55),
            height: 1.42,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

class _EditableTryOptionTile extends StatelessWidget {
  final _TryOption option;
  final VoidCallback onDelete;

  const _EditableTryOptionTile({
    required this.option,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AuroraColors.line.withValues(alpha: 0.72)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.drag_indicator_rounded,
            color: AuroraColors.muted.withValues(alpha: 0.70),
            size: 24,
          ),
          const SizedBox(width: 12),
          AuroraSoftIconCircle(
            icon: option.icon,
            color: option.color,
            size: 44,
            iconSize: 25,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              option.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF263653),
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          IconButton(
            tooltip: AppLocaleText.tr(
              context,
              en: 'Delete',
              zhHans: '删除',
              zhHant: '刪除',
              ja: '削除',
            ),
            onPressed: onDelete,
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AuroraColors.purple,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddTryOptionButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddTryOptionButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: 58,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.34),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AuroraColors.purple.withValues(alpha: 0.42),
              style: BorderStyle.solid,
            ),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_circle_outline_rounded,
                    color: AuroraColors.purple),
                const SizedBox(width: 8),
                Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Add a try',
                    zhHans: '添加一个尝试',
                    zhHant: '添加一個嘗試',
                    ja: '試すことを追加',
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AuroraColors.purple,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditSettingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget trailing;

  const _EditSettingRow({
    required this.icon,
    required this.label,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return _ExperimentGlassCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Row(
        children: [
          AuroraSoftIconCircle(
            icon: icon,
            color: AuroraColors.purple,
            size: 44,
            iconSize: 24,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF263653),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Flexible(
              child: Align(alignment: Alignment.centerRight, child: trailing)),
        ],
      ),
    );
  }
}

class _FrequencySegmentedControl extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _FrequencySegmentedControl({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AuroraColors.line.withValues(alpha: 0.74)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final day in const [3, 5, 7])
            _FrequencySegment(day: day, value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _FrequencySegment extends StatelessWidget {
  final int day;
  final int value;
  final ValueChanged<int> onChanged;

  const _FrequencySegment({
    required this.day,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == day;
    return InkWell(
      onTap: () => onChanged(day),
      borderRadius: BorderRadius.circular(17),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 78,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFF8D55FF), Color(0xFFBE58E8)],
                )
              : null,
        ),
        child: Text(
          AppLocaleText.tr(
            context,
            en: '$day days',
            zhHans: '$day 天',
            zhHant: '$day 天',
            ja: '$day日',
          ),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected ? Colors.white : const Color(0xFF34405C),
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

class _ReminderPill extends StatelessWidget {
  final String label;

  const _ReminderPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AuroraColors.purple.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF263653),
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.edit_rounded, color: AuroraColors.purple, size: 20),
        ],
      ),
    );
  }
}

class _FallbackChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _FallbackChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 7),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _TryOptionTile extends StatelessWidget {
  final _TryOption option;

  const _TryOptionTile({required this.option});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 18, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.86)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AuroraColors.purple.withValues(alpha: 0.42),
                width: 2,
              ),
            ),
          ),
          const SizedBox(width: 16),
          AuroraSoftIconCircle(
            icon: option.icon,
            color: option.color,
            size: 52,
            iconSize: 28,
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Text(
              option.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF283451),
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WhyExperimentCard extends StatelessWidget {
  final String reason;

  const _WhyExperimentCard({required this.reason});

  @override
  Widget build(BuildContext context) {
    return _ExperimentGlassCard(
      title: AppLocaleText.tr(
        context,
        en: 'Why this goal',
        zhHans: '为什么是这个目标',
        zhHant: '為什麼是這個目標',
        ja: 'なぜこの目標か',
      ),
      trailing: Icon(
        Icons.auto_awesome_rounded,
        color: AuroraColors.gold.withValues(alpha: 0.40),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final text = Text(
            reason,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF40506D),
                  height: 1.55,
                  fontWeight: FontWeight.w500,
                ),
          );
          if (constraints.maxWidth < 390) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                text,
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerRight,
                  child: _SoftLeaves(),
                ),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: text),
              const SizedBox(width: 12),
              const _SoftLeaves(),
            ],
          );
        },
      ),
    );
  }
}

class _ExperimentReviewCard extends StatelessWidget {
  final String title;
  final String result;
  final String reflection;
  final int progress;

  const _ExperimentReviewCard({
    required this.title,
    required this.result,
    required this.reflection,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return _ExperimentGlassCard(
      title: AppLocaleText.tr(
        context,
        en: 'This week result and review',
        zhHans: '本周目标结果和复盘',
        zhHant: '本週目標結果和復盤',
        ja: '今週の結果と振り返り',
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final ring = _ExperimentProgressRing(progress: progress);
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ReviewLine(
                icon: Icons.science_rounded,
                label: AppLocaleText.tr(
                  context,
                  en: 'Goal',
                  zhHans: '目标',
                  zhHant: '目標',
                  ja: '目標',
                ),
                value: title,
              ),
              const SizedBox(height: 10),
              _ReviewLine(
                icon: Icons.mood_rounded,
                label: AppLocaleText.tr(
                  context,
                  en: 'Result',
                  zhHans: '结果',
                  zhHant: '結果',
                  ja: '結果',
                ),
                value: result,
              ),
              const SizedBox(height: 10),
              _ReviewLine(
                icon: Icons.insights_rounded,
                label: AppLocaleText.tr(
                  context,
                  en: 'Review',
                  zhHans: '复盘',
                  zhHant: '復盤',
                  ja: '振り返り',
                ),
                value: reflection,
              ),
            ],
          );
          if (constraints.maxWidth < 390) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ring,
                const SizedBox(height: 16),
                details,
              ],
            );
          }
          return Row(
            children: [
              ring,
              const SizedBox(width: 24),
              Expanded(child: details),
            ],
          );
        },
      ),
    );
  }
}

class _ReviewLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ReviewLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AuroraSoftIconCircle(
          icon: icon,
          color: AuroraColors.purple,
          size: 28,
          iconSize: 16,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              text: '$label:  ',
              style: const TextStyle(
                color: AuroraColors.purple,
                fontWeight: FontWeight.w700,
              ),
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    color: Color(0xFF44506A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            style:
                Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.45),
          ),
        ),
      ],
    );
  }
}

class _ExperimentPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ExperimentPrimaryButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          height: 62,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              colors: [Color(0xFF8D55FF), Color(0xFFB157E9), Color(0xFF6C8DFF)],
            ),
            boxShadow: [
              BoxShadow(
                color: AuroraColors.purple.withValues(alpha: 0.34),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const SizedBox(width: 18),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white,
                size: 34,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExperimentSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ExperimentSecondaryButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.34),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AuroraColors.purple),
          ),
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AuroraColors.purple,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExperimentGlassCard extends StatelessWidget {
  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool mainPageDensity;

  const _ExperimentGlassCard({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.padding,
    this.mainPageDensity = false,
  });

  @override
  Widget build(BuildContext context) {
    return AuroraCard(
      padding: padding ??
          (mainPageDensity
              ? AuroraMainPageSpec.comfortableCardPadding
              : const EdgeInsets.fromLTRB(18, 18, 18, 18)),
      borderRadius: BorderRadius.circular(
        mainPageDensity ? AuroraMainPageSpec.cardRadiusLarge : 24,
      ),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.86),
          const Color(0xFFFFF7F1).withValues(alpha: 0.70),
          const Color(0xFFF1F4FF).withValues(alpha: 0.74),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final titleWidget = Text(
                  title!,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF253453),
                        fontWeight: FontWeight.w700,
                        fontSize: mainPageDensity ? 17 : null,
                      ),
                );
                if (trailing != null && constraints.maxWidth < 360) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleWidget,
                      Align(
                        alignment: Alignment.centerRight,
                        child: trailing!,
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: titleWidget),
                    if (trailing != null) trailing!,
                  ],
                );
              },
            ),
            SizedBox(height: mainPageDensity ? 10 : 16),
          ],
          child,
        ],
      ),
    );
  }
}

class _FlaskBubble extends StatelessWidget {
  final double size;

  const _FlaskBubble({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.92),
                  AuroraColors.purple.withValues(alpha: 0.28),
                  AuroraColors.blue.withValues(alpha: 0.12),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AuroraColors.purple.withValues(alpha: 0.24),
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: SizedBox(width: size, height: size),
          ),
          Icon(
            Icons.science_rounded,
            size: size * 0.62,
            color: Colors.white.withValues(alpha: 0.96),
            shadows: [
              Shadow(
                color: AuroraColors.purple.withValues(alpha: 0.45),
                blurRadius: 16,
              ),
            ],
          ),
          Positioned(
            right: size * 0.22,
            bottom: size * 0.26,
            child: Icon(
              Icons.star_rounded,
              size: size * 0.28,
              color: AuroraColors.gold.withValues(alpha: 0.90),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExperimentProgressRing extends StatelessWidget {
  final int progress;

  const _ExperimentProgressRing({required this.progress});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 116,
      height: 116,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size.square(116),
            painter: _ExperimentProgressRingPainter(progress / 7),
          ),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$progress',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: AuroraColors.purple,
                        fontSize: 42,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                TextSpan(
                  text: '/7',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AuroraColors.purple.withValues(alpha: 0.70),
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

class _ExperimentProgressRingPainter extends CustomPainter {
  final double value;

  const _ExperimentProgressRingPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = size.shortestSide * 0.12;
    final inset = stroke / 2;
    final arcRect = rect.deflate(inset);
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = AuroraColors.purple.withValues(alpha: 0.14),
    );
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      math.pi * 2 * value.clamp(0, 1),
      false,
      Paint()
        ..shader = const SweepGradient(
          colors: [Color(0xFF9A5CFF), Color(0xFF6AA5FF), Color(0xFF9A5CFF)],
        ).createShader(arcRect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ExperimentProgressRingPainter oldDelegate) =>
      oldDelegate.value != value;
}

class _SoftLeaves extends StatelessWidget {
  const _SoftLeaves();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 72,
      child: CustomPaint(
        painter: _ExperimentLeafPainter(
          color: AuroraColors.purple.withValues(alpha: 0.26),
        ),
      ),
    );
  }
}

class _BackBubble extends StatelessWidget {
  final VoidCallback onTap;

  const _BackBubble({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AuroraIconButton(
      icon: Icons.chevron_left_rounded,
      onPressed: onTap,
      tooltip: AppLocaleText.tr(
        context,
        en: 'Back',
        zhHans: '返回',
        zhHant: '返回',
        ja: '戻る',
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double value;
  final Color? color;
  final double height;

  const _ProgressBar({
    required this.value,
    this.color,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: AuroraColors.line.withValues(alpha: 0.72)),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0, 1),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color ?? const Color(0xFF9B61FF),
                      (color ?? const Color(0xFF7A8BFF))
                          .withValues(alpha: 0.72),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExperimentHeroArt extends StatelessWidget {
  const _ExperimentHeroArt();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: CustomPaint(painter: _ExperimentRingPainter()),
        ),
        Positioned.fill(
          child: Align(
            alignment: const Alignment(0.08, -0.18),
            child: Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.58),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.science_outlined,
                size: 43,
                color: Colors.white.withValues(alpha: 0.82),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExperimentRingPainter extends CustomPainter {
  const _ExperimentRingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.54, size.height * 0.42);
    final radius = size.shortestSide * 0.34;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius * 1.35,
      Paint()
        ..color = AuroraColors.purple.withValues(alpha: 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );
    canvas.drawArc(
      rect,
      -math.pi * 0.20,
      math.pi * 1.58,
      false,
      Paint()
        ..shader = const SweepGradient(
          colors: [
            Color(0xFF7B6FF2),
            Color(0xFF68D8DF),
            Color(0xFFFFBD67),
            Color(0xFF7B6FF2),
          ],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 18,
    );
    canvas.drawCircle(
      center,
      radius * 0.72,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.78),
    );
    final path = Path()
      ..moveTo(center.dx - radius * 0.96, center.dy + radius * 0.08)
      ..cubicTo(
        center.dx - radius * 0.20,
        center.dy - radius * 0.14,
        center.dx + radius * 0.38,
        center.dy - radius * 0.02,
        center.dx + radius * 0.06,
        center.dy + radius * 0.22,
      )
      ..cubicTo(
        center.dx - radius * 0.26,
        center.dy + radius * 0.46,
        center.dx + radius * 0.10,
        center.dy + radius * 0.58,
        center.dx + radius * 0.94,
        center.dy + radius * 0.68,
      );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.82),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ExperimentLeafPainter extends CustomPainter {
  final Color color;

  const _ExperimentLeafPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final stem = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(size.width * 0.48, size.height),
      Offset(size.width * 0.52, size.height * 0.10),
      stem,
    );
    final fill = Paint()..color = color.withValues(alpha: 0.72);
    for (var i = 0; i < 4; i += 1) {
      final y = size.height * (0.28 + i * 0.16);
      final left = i.isEven;
      final cx = size.width * (left ? 0.28 : 0.72);
      final leaf = Path()
        ..moveTo(size.width * 0.50, y)
        ..quadraticBezierTo(
            cx, y - size.height * 0.11, cx, y + size.height * 0.05)
        ..quadraticBezierTo(
          size.width * 0.44,
          y + size.height * 0.06,
          size.width * 0.50,
          y,
        );
      canvas.drawPath(leaf, fill);
    }
  }

  @override
  bool shouldRepaint(covariant _ExperimentLeafPainter oldDelegate) =>
      oldDelegate.color != color;
}
