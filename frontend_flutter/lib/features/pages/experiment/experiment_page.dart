// ignore_for_file: unused_element, unused_field, prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/di/app_dependencies.dart';
import '../../../core/i18n/app_locale_text.dart';
import '../../../core/models/today_models.dart';
import '../../../core/models/weekly_models.dart';
import '../../../shared/states/load_state.dart';
import '../../../shared/widgets/aurora_ui.dart';
import '../weekly/weekly_view_model.dart';

class ExperimentPage extends StatefulWidget {
  const ExperimentPage({super.key});

  @override
  State<ExperimentPage> createState() => _ExperimentPageState();
}

class _ExperimentPageState extends State<ExperimentPage> {
  final _titleController = TextEditingController();
  final _actionController = TextEditingController();
  final _reasonController = TextEditingController();
  final _searchController = TextEditingController();
  String? _loadedExperimentId;
  bool _isEditing = false;
  List<_TryOption> _editTryOptions = const [];
  final int _frequencyDays = 7;
  List<LifeExperimentModel> _history = const [];
  bool _historyLoaded = false;
  bool _historyLoading = false;
  Map<String, List<LifeExperimentFeedbackModel>> _feedbacksByExperiment =
      const {};
  Map<String, List<RecentSignalModel>> _signalsByExperiment = const {};
  Map<String, _ExperimentRollup> _rollupsByExperiment = const {};
  Map<String, List<_ExperimentLifecycleEvent>> _lifecycleByExperiment =
      const {};
  _ExperimentFilter _filter = _ExperimentFilter.active;
  LifeExperimentModel? _selectedExperiment;
  bool _showStatsDetail = false;
  _ExperimentDetailTab _detailTab = _ExperimentDetailTab.overview;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _loadExperimentHistory());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _actionController.dispose();
    _reasonController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WeeklyViewModel>();
    final weekly = vm.weeklyInsight;
    final experiments = _experimentArchive(weekly);
    final selected = _selectedExperiment;
    if (selected != null) {
      return _buildDetailScaffold(context, vm, selected, experiments);
    }
    if (_showStatsDetail) {
      return _buildStatsDetailScaffold(context, experiments);
    }
    final hasAnyExperiments = experiments.isNotEmpty;
    final visibleExperiments = _visibleExperiments(experiments);
    final activeExperiments = _filter == _ExperimentFilter.active
        ? visibleExperiments
        : experiments
            .where((experiment) =>
                _experimentStatusGroup(experiment, _rollupFor(experiment)) ==
                _ExperimentFilter.active)
            .toList();
    final currentExperiments = activeExperiments
        .where((experiment) => !_isUpcomingExperiment(experiment))
        .toList();
    final upcomingExperiments =
        activeExperiments.where(_isUpcomingExperiment).toList();
    final statusCounts = <_ExperimentFilter, int>{
      for (final filter in _ExperimentFilter.values)
        filter: filter == _ExperimentFilter.all
            ? experiments.length
            : filter == _ExperimentFilter.active
                ? experiments
                    .where((experiment) =>
                        _experimentStatusGroup(
                              experiment,
                              _rollupFor(experiment),
                            ) ==
                            _ExperimentFilter.active &&
                        !_isUpcomingExperiment(experiment))
                    .length
                : experiments
                    .where((experiment) =>
                        _experimentStatusGroup(
                          experiment,
                          _rollupFor(experiment),
                        ) ==
                        filter)
                    .length,
    };

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
                    padding: AuroraMainPageSpec.scrollPadding(context),
                    children: [
                      _ExperimentArchiveHeroHeader(
                        canPop: Navigator.of(context).canPop(),
                        onBack: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(height: AuroraMainPageSpec.heroGap),
                      if (hasAnyExperiments) ...[
                        _ExperimentFilterTabs(
                          value: _filter,
                          counts: statusCounts,
                          onChanged: (value) => setState(() => _filter = value),
                        ),
                        const SizedBox(height: AuroraMainPageSpec.sectionGap),
                      ],
                      if ((_historyLoading ||
                              vm.loadState == LoadState.loading) &&
                          experiments.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (!hasAnyExperiments) ...[
                        _ExperimentSectionHeader(
                          title: AppLocaleText.tr(
                            context,
                            en: 'My experiments',
                            zhHans: '我的小实验',
                            zhHant: '我的小實驗',
                            ja: '自分の実験',
                          ),
                          count: 0,
                          onOpenOverview: () =>
                              setState(() => _showStatsDetail = true),
                        ),
                        const SizedBox(height: 8),
                        _ExperimentEmptyArchive(
                          mainPageDensity: true,
                          historyLoaded: _historyLoaded,
                          filter: _ExperimentFilter.all,
                          onRecordToday: () => context.go(AppRoutes.today),
                        ),
                      ] else if (_filter == _ExperimentFilter.active) ...[
                        _ExperimentSectionHeader(
                          title: AppLocaleText.tr(
                            context,
                            en: 'In progress this week',
                            zhHans: '本周进行中',
                            zhHant: '本週進行中',
                            ja: '今週進行中',
                          ),
                          count: currentExperiments.length,
                          onOpenOverview: () =>
                              setState(() => _showStatsDetail = true),
                        ),
                        const SizedBox(height: 8),
                        if (currentExperiments.isEmpty)
                          _ExperimentEmptyArchive(
                            mainPageDensity: true,
                            historyLoaded: _historyLoaded,
                            filter: _ExperimentFilter.active,
                            onRecordToday: () => context.go(AppRoutes.today),
                          )
                        else ...[
                          for (var index = 0;
                              index < currentExperiments.length;
                              index++) ...[
                            _ActiveExperimentCard(
                              expanded: index == 0,
                              experiment: currentExperiments[index],
                              evidence: _evidenceFor(currentExperiments[index]),
                              rollup: _rollupFor(currentExperiments[index]),
                              onRecordToday: () => _openExperimentFeedback(
                                context,
                                currentExperiments[index],
                              ),
                              onOpenDetail: () => setState(() {
                                _selectedExperiment = currentExperiments[index];
                                _detailTab = _ExperimentDetailTab.overview;
                              }),
                            ),
                            const SizedBox(
                              height: AuroraMainPageSpec.sectionGap,
                            ),
                          ],
                        ],
                        if (upcomingExperiments.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          _ExperimentSectionHeader(
                            title: AppLocaleText.tr(
                              context,
                              en: 'Starting soon',
                              zhHans: '即将开始',
                              zhHant: '即將開始',
                              ja: 'まもなく開始',
                            ),
                            count: upcomingExperiments.length,
                          ),
                          const SizedBox(height: 8),
                          for (final experiment in upcomingExperiments) ...[
                            _UpcomingExperimentCard(
                              experiment: experiment,
                              onTap: () => setState(() {
                                _selectedExperiment = experiment;
                                _detailTab = _ExperimentDetailTab.overview;
                              }),
                            ),
                            const SizedBox(
                              height: AuroraMainPageSpec.sectionGap,
                            ),
                          ],
                        ],
                      ] else ...[
                        _ExperimentSectionHeader(
                          title: _filterLabel(context, _filter),
                          count: visibleExperiments.length,
                          onOpenOverview: () =>
                              setState(() => _showStatsDetail = true),
                        ),
                        const SizedBox(height: 8),
                        if (visibleExperiments.isEmpty)
                          _ExperimentEmptyArchive(
                            mainPageDensity: true,
                            historyLoaded: _historyLoaded,
                            filter: _filter,
                            onRecordToday: () => context.go(AppRoutes.today),
                          )
                        else
                          for (final experiment in visibleExperiments) ...[
                            _LifeExperimentArchiveCard(
                              mainPageDensity: true,
                              experiment: experiment,
                              evidence: _evidenceFor(experiment),
                              rollup: _rollupFor(experiment),
                              lifecycle: _lifecycleFor(experiment),
                              onTap: () => setState(() {
                                _selectedExperiment = experiment;
                                _detailTab = _ExperimentDetailTab.overview;
                              }),
                            ),
                            const SizedBox(
                              height: AuroraMainPageSpec.sectionGap,
                            ),
                          ],
                      ],
                      if (hasAnyExperiments) ...[
                        const SizedBox(height: 2),
                        _ExperimentSearchBar(
                          controller: _searchController,
                          onFilterTap: () =>
                              _showExperimentFilterSheet(context),
                        ),
                        const SizedBox(height: AuroraMainPageSpec.sectionGap),
                      ],
                      _ExperimentArchiveSummaryCard(
                        mainPageDensity: true,
                        experiments: experiments,
                        feedbacksByExperiment: _feedbacksByExperiment,
                        rollupsByExperiment: _rollupsByExperiment,
                        onViewDetail: () =>
                            setState(() => _showStatsDetail = true),
                      ),
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

  Widget _buildDetailScaffold(
    BuildContext context,
    WeeklyViewModel vm,
    LifeExperimentModel experiment,
    List<LifeExperimentModel> experiments,
  ) {
    final evidence = _evidenceFor(experiment);
    final rollup = _rollupFor(experiment);
    final lifecycle = _lifecycleFor(experiment);
    final points = _trendPoints(experiment, evidence);
    return Scaffold(
      body: Stack(
        children: [
          AuroraPage(
            child: Stack(
              children: [
                const Positioned(
                  right: -22,
                  top: 42,
                  width: 178,
                  height: 178,
                  child: IgnorePointer(child: _ExperimentHeroArt()),
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
                                en: 'Experiment detail',
                                zhHans: '实验详情',
                                zhHant: '實驗詳情',
                                ja: '実験詳細',
                              ),
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    color: AuroraColors.ink,
                                    fontWeight: FontWeight.w900,
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
                      _ExperimentDetailTabBar(
                        value: _detailTab,
                        onChanged: (value) =>
                            setState(() => _detailTab = value),
                      ),
                      const SizedBox(height: 14),
                      if (_detailTab == _ExperimentDetailTab.overview)
                        _ExperimentOverviewTab(
                          experiment: experiment,
                          evidence: evidence,
                          rollup: rollup,
                          lifecycle: lifecycle,
                          points: points,
                          triedCount:
                              _actualTriedCount(experiment, evidence, rollup),
                        )
                      else if (_detailTab == _ExperimentDetailTab.feedback)
                        _ExperimentFeedbackTab(
                          experiment: experiment,
                          evidence: evidence,
                          points: points,
                          triedCount:
                              _actualTriedCount(experiment, evidence, rollup),
                          onRecordFeedback: () =>
                              _openExperimentFeedback(context, experiment),
                        )
                      else if (_detailTab == _ExperimentDetailTab.conditions)
                        _ExperimentConditionsTab(
                          experiment: experiment,
                          evidence: evidence,
                        )
                      else
                        _ExperimentNotesTab(experiment: experiment),
                      const SizedBox(height: 18),
                      _ExperimentPrimaryButton(
                        label: AppLocaleText.tr(
                          context,
                          en: 'Add to this week',
                          zhHans: '追加到本周',
                          zhHant: '追加到本週',
                          ja: '今週に追加',
                        ),
                        onTap: () => _reuseExperiment(context, vm, experiment),
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
                  right: -22,
                  top: 42,
                  width: 178,
                  height: 178,
                  child: IgnorePointer(child: _ExperimentHeroArt()),
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
                                en: 'Experiment details',
                                zhHans: '小实验详情',
                                zhHant: '小實驗詳情',
                                ja: '実験の詳細',
                              ),
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    color: AuroraColors.ink,
                                    fontWeight: FontWeight.w900,
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
                          en: 'Recent experiments',
                          zhHans: '最近的小实验',
                          zhHant: '最近的小實驗',
                          ja: '最近の実験',
                        ),
                        child: Column(
                          children: [
                            if (recentExperiments.isEmpty)
                              Text(
                                AppLocaleText.tr(
                                  context,
                                  en: 'No experiment data yet.',
                                  zhHans: '还没有小实验数据。',
                                  zhHant: '還沒有小實驗資料。',
                                  ja: '実験データはまだありません。',
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

  Future<void> _loadExperimentHistory() async {
    if (_historyLoading) return;
    setState(() => _historyLoading = true);
    try {
      final deps = context.read<AppDependencies>();
      final rows = await deps.localLifeExperimentRepository.listRecent(
        localUserId: deps.localUserId,
        limit: 500,
      );
      for (final experiment in rows) {
        await deps.localLifeExperimentRepository.refreshRollup(experiment.id);
      }
      final rollupRows = await deps.localLifeExperimentRepository.listRollups(
        localUserId: deps.localUserId,
        limit: 500,
      );
      final lifecycleRows = await deps.localLifeExperimentRepository
          .listLifecycleEventsForExperiments(
        experimentIds: rows.map((e) => e.id),
      );
      final feedbacks = await deps.localLifeExperimentRepository
          .listFeedbacksForExperiments(experimentIds: rows.map((e) => e.id));
      final allSignals = await deps.localCaptureRepository.listSignalCards(
        limit: 2000,
      );
      final feedbackMap = <String, List<LifeExperimentFeedbackModel>>{};
      for (final feedback in feedbacks) {
        feedbackMap.putIfAbsent(feedback.experimentId, () => []).add(feedback);
      }
      final signalMap = <String, List<RecentSignalModel>>{};
      for (final experiment in rows) {
        final linkedIds = experiment.linkedSignalCardIds.toSet();
        signalMap[experiment.id] = allSignals.where((signal) {
          final id = signal.id ?? '';
          final signalCardId = signal.signalCardId ?? '';
          return linkedIds.contains(id) || linkedIds.contains(signalCardId);
        }).toList();
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
      if (!mounted) return;
      setState(() {
        _history = rows;
        _feedbacksByExperiment = feedbackMap;
        _signalsByExperiment = signalMap;
        _rollupsByExperiment = rollupMap;
        _lifecycleByExperiment = lifecycleMap;
        _historyLoaded = true;
        _historyLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _historyLoaded = true;
        _historyLoading = false;
      });
    }
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
    setState(() => _filter = selected);
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
      if (!_matchesFilter(experiment)) return false;
      if (query.isEmpty) return true;
      return [
        experiment.title,
        experiment.hypothesis,
        experiment.suggestedAction,
        experiment.feedbackText,
      ].join(' ').toLowerCase().contains(query);
    }).toList();
  }

  bool _matchesFilter(LifeExperimentModel experiment) {
    if (_filter == _ExperimentFilter.all) return true;
    return _experimentStatusGroup(experiment, _rollupFor(experiment)) ==
        _filter;
  }

  Future<void> _reuseExperiment(
    BuildContext context,
    WeeklyViewModel vm,
    LifeExperimentModel experiment,
  ) async {
    try {
      final deps = context.read<AppDependencies>();
      await deps.localLifeExperimentRepository.appendToCurrentWeek(
        experiment: experiment,
      );
      await _loadExperimentHistory();
    } catch (_) {
      // The archive page can be opened before weekly data is ready.
    }
    if (!context.mounted) return;
    _showExperimentHint(
      context,
      AppLocaleText.tr(
        context,
        en: 'This experiment has been added to this week.',
        zhHans: '已追加到本周，不会覆盖原有实验。',
        zhHant: '已追加到本週，不會覆蓋原有實驗。',
        ja: '今週に追加しました。既存の実験は上書きしません。',
      ),
    );
  }

  void _openExperimentFeedback(
    BuildContext context,
    LifeExperimentModel experiment,
  ) {
    context.go('${AppRoutes.todayExperimentFeedback}/${experiment.id}');
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
        en: 'This experiment has been added for next week.',
        zhHans: '下周小实验已加入。',
        zhHant: '下週小實驗已加入。',
        ja: '来週の小さな実験に追加しました。',
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
          en: 'Please keep a title and one small action.',
          zhHans: '请至少保留标题和一个小行动。',
          zhHant: '請至少保留標題和一個小行動。',
          ja: 'タイトルと小さな行動を残してください。',
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
        en: 'Experiment changes are saved.',
        zhHans: '小实验修改已保存。',
        zhHant: '小實驗修改已保存。',
        ja: '実験の変更を保存しました。',
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

enum _ExperimentFilter { active, adjusted, completed, paused, stopped, all }

enum _ExperimentDetailTab { overview, feedback, conditions, notes }

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
  LifeExperimentModel experiment,
  _ExperimentEvidence evidence,
  _ExperimentRollup? rollup,
) {
  if (rollup != null) return rollup.triedCount;
  if (evidence.feedbacks.isNotEmpty) return evidence.triedDays;
  return experiment.linkedSignalCardIds.length;
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
            ? feedbacks.map((feedback) => feedback.localDate).toSet().length
            : experiment.linkedSignalCardIds.length);
    helpful += rollupHelpful;
    adjusted += rollup?.adjustedCount ??
        feedbacks
            .where((feedback) =>
                feedback.completionStatus.toLowerCase().contains('adjust'))
            .length;
    skipped += rollup?.skippedCount ??
        feedbacks
            .where((feedback) =>
                feedback.completionStatus.toLowerCase().contains('skip'))
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
      en: 'Continued from earlier experiment',
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
        en: 'This experiment has been adjusted ${rollup.adjustedCount} time(s), so the current version should stay lighter.',
        zhHans: '这个实验已经调整 ${rollup.adjustedCount} 次，当前版本更适合继续调轻。',
        zhHant: '這個實驗已經調整 ${rollup.adjustedCount} 次，目前版本更適合繼續調輕。',
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
    if (status != null && status.isNotEmpty) status,
    if (source != null && source.isNotEmpty) source.replaceAll('_', ' '),
  ].join(' · ');
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

List<_KeywordData> _keywordsFor(LifeExperimentModel experiment) {
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
    add('Sleep improved', Icons.nights_stay_rounded, AuroraColors.blue);
  }
  if (source.contains('放松') ||
      source.contains('恢复') ||
      source.toLowerCase().contains('relax')) {
    add('Relaxation', Icons.spa_rounded, AuroraColors.mint);
  }
  if (source.contains('情绪') || source.toLowerCase().contains('mood')) {
    add('Mood steadier', Icons.favorite_rounded, AuroraColors.gold);
  }
  if (source.contains('压力') || source.toLowerCase().contains('pressure')) {
    add('Pressure lower', Icons.cloud_queue_rounded, AuroraColors.orange);
  }
  if (source.contains('记录') || source.toLowerCase().contains('record')) {
    add('Observation', Icons.edit_rounded, AuroraColors.blue);
  }
  if (keywords.isEmpty) {
    add('Rhythm clearer', Icons.auto_awesome_rounded, AuroraColors.purple);
    add('Easier to start', Icons.trending_up_rounded, AuroraColors.mint);
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
      days.add(feedback.localDate);
    }
    for (final signal in signals) {
      final day = signal.localDateKey();
      if (day.isNotEmpty) days.add(day);
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

  List<_KeywordData> keywordsFor(LifeExperimentModel experiment) {
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
        _readableEvidenceLabel(text),
        _evidenceIcon(text),
        _evidenceColor(text),
      );
    }).toList();
    return keywords.isNotEmpty ? keywords : _keywordsFor(experiment);
  }

  List<_KeywordData> conditionKeywords() {
    final source = <_KeywordData>[];
    final slots =
        feedbacks.map((f) => f.timeSlot ?? '').where((e) => e.isNotEmpty);
    final scenes = signals
        .expand((s) => [s.scene, ...s.sceneTags])
        .whereType<String>()
        .where((e) => e.trim().isNotEmpty);
    for (final value in [...slots, ...scenes]) {
      if (source.any((item) => item.label == _readableEvidenceLabel(value))) {
        continue;
      }
      source.add(_KeywordData(
        _readableEvidenceLabel(value),
        _evidenceIcon(value),
        _evidenceColor(value),
      ));
      if (source.length >= 4) break;
    }
    if (source.isEmpty) {
      source.addAll([
        const _KeywordData('More feedback needed', Icons.edit_note_rounded,
            AuroraColors.muted),
      ]);
    }
    return source;
  }

  List<_DurationBucket> durationBuckets() {
    final durations = feedbacks
        .map((feedback) => feedback.durationMinutes)
        .whereType<int>()
        .where((value) => value > 0)
        .toList();
    if (durations.isEmpty) {
      return const [
        _DurationBucket('No duration yet', 1, AuroraColors.muted),
      ];
    }
    final underTen = durations.where((value) => value <= 10).length;
    final tenToTwenty =
        durations.where((value) => value > 10 && value <= 20).length;
    final overTwenty = durations.where((value) => value > 20).length;
    return [
      _DurationBucket('Under 10 min', underTen, AuroraColors.purple),
      _DurationBucket('10-20 min', tenToTwenty, AuroraColors.orange),
      _DurationBucket('Over 20 min', overTwenty, AuroraColors.mint),
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
        en: 'Recovery-linked moments are more likely to support this experiment.',
        zhHans: '和恢复感相连的时刻，更可能支持这个实验。',
        zhHant: '和恢復感相連的時刻，更可能支持這個實驗。',
        ja: '回復感のある時間とつながると、この実験は続きやすそうです。',
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
        en: 'This experiment still needs a few real feedback records.',
        zhHans: '这个实验还需要几条真实反馈来归纳偏好。',
        zhHant: '這個實驗還需要幾條真實回饋來歸納偏好。',
        ja: 'この実験は、好みを読むためにもう少し実際の反応が必要です。',
      ));
    }
    return lines.take(3).toList();
  }

  String insightText(BuildContext context) {
    if (feedbacks.isEmpty && signals.isEmpty) {
      return AppLocaleText.tr(
        context,
        en: 'This experiment still needs real feedback before the app can summarize what fits you. Keep the next attempt small.',
        zhHans: '这个实验还需要真实反馈，之后才能总结什么更适合你。下一次先保持很小。',
        zhHant: '這個實驗還需要真實回饋，之後才能總結什麼更適合你。下一次先保持很小。',
        ja: 'この実験は、合う形を読むために実際の反応がもう少し必要です。次は小さく試します。',
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
      en: 'The current evidence is still light. Compare this experiment across a few real days before turning it into a stable method.',
      zhHans: '目前证据还比较轻。先跨几个真实日期比较，再把它沉淀成稳定方法。',
      zhHant: '目前證據還比較輕。先跨幾個真實日期比較，再把它沉澱成穩定方法。',
      ja: '根拠はまだ軽めです。数日分を比べてから、安定した方法として残します。',
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

String _readableEvidenceLabel(String value) {
  final normalized = value.trim();
  const labels = {
    'tried': 'Happened',
    'helpful': 'Helpful',
    'too_hard': 'Want to adjust',
    'adjusted': 'Want to adjust',
    'not_today': 'Not today',
    'high_draining': 'High drain',
    'restoring': 'Recovery',
    'recovery': 'Recovery',
  };
  return labels[normalized] ?? normalized;
}

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

class _ExperimentArchiveHeroHeader extends StatelessWidget {
  final bool canPop;
  final VoidCallback onBack;

  const _ExperimentArchiveHeroHeader({
    required this.canPop,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < AuroraMainPageSpec.compactBreakpoint;
    final contentTop = canPop ? 46.0 : 0.0;

    return ConstrainedBox(
      key: const ValueKey('experiment-hero-header'),
      constraints: const BoxConstraints(minHeight: 164, maxHeight: 170),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: compact ? -16 : -12,
            top: canPop ? 30 : -10,
            width: compact ? 148 : 166,
            height: compact ? 148 : 166,
            child: const IgnorePointer(child: _ExperimentHeroArt()),
          ),
          if (canPop)
            Positioned(
              left: -8,
              top: -4,
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
            padding: EdgeInsets.only(
              top: contentTop,
              right: compact ? 90 : 116,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Life Experiment',
                    zhHans: '小实验',
                    zhHant: '小實驗',
                    ja: '小さな実験',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: AuroraColors.ink,
                        fontSize:
                            AuroraMainPageSpec.responsiveHeroTitleSize(context),
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  AppLocaleText.tr(
                    context,
                    en: 'See what you have started, and slowly find what truly fits.',
                    zhHans: '看看已经开始的尝试，慢慢找到真正适合你的方式。',
                    zhHant: '看看已經開始的嘗試，慢慢找到真正適合你的方式。',
                    ja: '始めた試みを眺めながら、本当に合う形をゆっくり探します。',
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
  final VoidCallback onFilterTap;

  const _ExperimentSearchBar({
    required this.controller,
    required this.onFilterTap,
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
              decoration: InputDecoration(
                hintText: AppLocaleText.tr(
                  context,
                  en: 'Search my experiments...',
                  zhHans: '搜索我的实验...',
                  zhHant: '搜尋我的實驗...',
                  ja: '実験を検索...',
                ),
                border: InputBorder.none,
                hintStyle: TextStyle(
                  color: AuroraColors.muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onFilterTap,
            icon: const Icon(Icons.filter_alt_outlined),
            color: AuroraColors.purple,
            tooltip: 'Filter',
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _ExperimentFilterTabs extends StatelessWidget {
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
    return Container(
      key: const ValueKey('experiment-filter-tabs'),
      height: 46,
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
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.zero,
          itemCount: filters.length,
          separatorBuilder: (_, __) => Container(
            width: 1,
            margin: const EdgeInsets.symmetric(vertical: 11),
            color: AuroraColors.line.withValues(alpha: 0.5),
          ),
          itemBuilder: (context, index) {
            final item = filters[index];
            final selected = item == value;
            return InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => onChanged(item),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: index < 3 ? 120 : 108,
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
                      TextSpan(text: _filterLabel(context, item)),
                      TextSpan(
                        text: '  ${counts[item] ?? 0}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? AuroraColors.purple.withValues(alpha: 0.9)
                              : AuroraColors.muted,
                        ),
                      ),
                    ],
                  ),
                  style: TextStyle(
                    color: selected ? AuroraColors.purple : AuroraColors.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
              ),
            );
          },
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
    this.onOpenOverview,
  });

  @override
  Widget build(BuildContext context) {
    final countLabel = AppLocaleText.tr(
      context,
      en: '$count experiment${count == 1 ? '' : 's'}',
      zhHans: '$count 个实验',
      zhHant: '$count 個實驗',
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
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
        if (onOpenOverview == null)
          Text(
            countLabel,
            style: const TextStyle(
              color: AuroraColors.muted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
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
                  fontWeight: FontWeight.w700,
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

bool _feedbackCountsAsCompleted(String rawStatus) {
  final status = rawStatus.trim().toLowerCase();
  if (status.isEmpty) return false;
  return !status.contains('not_occurred') &&
      !status.contains('not_suitable') &&
      !status.contains('skip') &&
      status != 'not_today' &&
      status != 'missed';
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
      zhHans: '来自 Weekly',
      zhHant: '來自 Weekly',
      ja: 'Weekly から',
    );
  }
  final range = '${start.month}/${start.day}–${end.month}/${end.day}';
  return AppLocaleText.tr(
    context,
    en: 'From $range Weekly',
    zhHans: '来自 $range Weekly',
    zhHant: '來自 $range Weekly',
    ja: '$range の Weekly から',
  );
}

class _ActiveExperimentCard extends StatelessWidget {
  final bool expanded;
  final LifeExperimentModel experiment;
  final _ExperimentEvidence evidence;
  final _ExperimentRollup? rollup;
  final VoidCallback onRecordToday;
  final VoidCallback onOpenDetail;

  const _ActiveExperimentCard({
    required this.expanded,
    required this.experiment,
    required this.evidence,
    required this.rollup,
    required this.onRecordToday,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    final days = _experimentProgressDays(experiment, evidence);
    final completed = days
        .where((day) => day.state == _ExperimentProgressState.completed)
        .length;
    final todayKey = _localDateKey(DateTime.now());
    final todayRecorded = evidence.feedbacks.any(
      (feedback) => feedback.localDate == todayKey,
    );
    return _ExperimentGlassCard(
      key: ValueKey('experiment-archive-card-${experiment.id}'),
      mainPageDensity: true,
      padding: const EdgeInsets.fromLTRB(15, 12, 15, 13),
      child: expanded
          ? _ExpandedExperimentContent(
              experiment: experiment,
              days: days,
              completed: completed,
              todayRecorded: todayRecorded,
              onRecordToday: onRecordToday,
              onOpenDetail: onOpenDetail,
            )
          : _CompactExperimentContent(
              experiment: experiment,
              completed: completed,
              todayRecorded: todayRecorded,
              onRecordToday: onRecordToday,
              onOpenDetail: onOpenDetail,
            ),
    );
  }
}

class _ExpandedExperimentContent extends StatelessWidget {
  final LifeExperimentModel experiment;
  final List<_ExperimentProgressDay> days;
  final int completed;
  final bool todayRecorded;
  final VoidCallback onRecordToday;
  final VoidCallback onOpenDetail;

  const _ExpandedExperimentContent({
    required this.experiment,
    required this.days,
    required this.completed,
    required this.todayRecorded,
    required this.onRecordToday,
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
                fontWeight: FontWeight.w900,
                height: 1.25,
              ),
        ),
        if (experiment.hypothesis.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            experiment.hypothesis.trim(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        if (experiment.sourceChanged) ...[
          const SizedBox(height: 6),
          const _ExperimentSourceChangedBadge(),
        ],
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
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              '$completed/7',
              style: const TextStyle(
                color: AuroraColors.purple,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        _ExperimentSevenDayGrid(days: days),
        const SizedBox(height: 9),
        const _ExperimentProgressLegend(),
        const Divider(height: 18),
        Row(
          children: [
            Expanded(
              flex: 5,
              child: _ExperimentActionButton(
                filled: true,
                label: todayRecorded
                    ? AppLocaleText.tr(
                        context,
                        en: 'Edit today',
                        zhHans: '修改今天',
                        zhHant: '修改今天',
                        ja: '今日を修正',
                      )
                    : AppLocaleText.tr(
                        context,
                        en: 'Record today',
                        zhHans: '登记今天',
                        zhHant: '登記今天',
                        ja: '今日を記録',
                      ),
                onTap: onRecordToday,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 4,
              child: _ExperimentActionButton(
                label: AppLocaleText.tr(
                  context,
                  en: 'View details',
                  zhHans: '查看详情',
                  zhHant: '查看詳情',
                  ja: '詳細を見る',
                ),
                onTap: onOpenDetail,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CompactExperimentContent extends StatelessWidget {
  final LifeExperimentModel experiment;
  final int completed;
  final bool todayRecorded;
  final VoidCallback onRecordToday;
  final VoidCallback onOpenDetail;

  const _CompactExperimentContent({
    required this.experiment,
    required this.completed,
    required this.todayRecorded,
    required this.onRecordToday,
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
                fontWeight: FontWeight.w900,
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
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            Text(
              todayRecorded
                  ? AppLocaleText.tr(
                      context,
                      en: 'Recorded today',
                      zhHans: '今天已登记',
                      zhHant: '今天已登記',
                      ja: '今日は記録済み',
                    )
                  : AppLocaleText.tr(
                      context,
                      en: 'Not recorded yet',
                      zhHans: '尚未登记',
                      zhHant: '尚未登記',
                      ja: '未記録',
                    ),
              style: const TextStyle(
                color: AuroraColors.muted,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        if (experiment.sourceChanged) ...[
          const SizedBox(height: 6),
          const _ExperimentSourceChangedBadge(),
        ],
        const Divider(height: 16),
        Row(
          children: [
            Expanded(
              child: _ExperimentActionButton(
                label: todayRecorded
                    ? AppLocaleText.tr(
                        context,
                        en: 'Edit today',
                        zhHans: '修改今天',
                        zhHant: '修改今天',
                        ja: '今日を修正',
                      )
                    : AppLocaleText.tr(
                        context,
                        en: 'Record today',
                        zhHans: '登记今天',
                        zhHant: '登記今天',
                        ja: '今日を記録',
                      ),
                onTap: onRecordToday,
              ),
            ),
            IconButton(
              onPressed: onOpenDetail,
              tooltip: AppLocaleText.tr(
                context,
                en: 'View details',
                zhHans: '查看详情',
                zhHant: '查看詳情',
                ja: '詳細を見る',
              ),
              icon: const Icon(Icons.chevron_right_rounded),
              color: AuroraColors.muted,
            ),
          ],
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
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AuroraColors.purple,
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(dimension: 10),
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
            fontWeight: FontWeight.w800,
          ),
        ),
        const Text(
          '  ·  ',
          style: TextStyle(color: AuroraColors.muted),
        ),
        Text(
          _experimentDayLabel(context, experiment),
          style: const TextStyle(
            color: AuroraColors.muted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
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
              fontWeight: FontWeight.w700,
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
            en: 'Happened',
            zhHans: '已发生',
            zhHant: '已發生',
            ja: '実施',
          ),
        ),
        _ExperimentLegendItem(
          icon: Icons.remove_rounded,
          color: const Color(0xFFB8C1D1),
          label: AppLocaleText.tr(
            context,
            en: 'Not suitable / did not happen',
            zhHans: '不适合 / 未发生',
            zhHant: '不適合 / 未發生',
            ja: '合わない / 未実施',
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
              fontWeight: FontWeight.w700,
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
  final bool filled;

  const _ExperimentActionButton({
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: filled
          ? FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: AuroraColors.purple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            )
          : OutlinedButton(
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
                style: const TextStyle(fontWeight: FontWeight.w900),
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
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFFD8AA3D),
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(dimension: 10),
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
                      fontWeight: FontWeight.w800,
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
                          fontWeight: FontWeight.w900,
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
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppLocaleText.tr(
                      context,
                      en: 'You can record what actually happened once it starts.',
                      zhHans: '开始后可以按天登记实际情况。',
                      zhHant: '開始後可以按天登記實際情況。',
                      ja: '開始後は日ごとに実際の様子を記録できます。',
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
            fontWeight: FontWeight.w800,
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
  final VoidCallback onRecordToday;

  const _ExperimentEmptyArchive({
    this.mainPageDensity = false,
    required this.historyLoaded,
    required this.filter,
    required this.onRecordToday,
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
            Icon(
              Icons.science_rounded,
              color: AuroraColors.purple,
              size: mainPageDensity ? 30 : 44,
            ),
            SizedBox(height: mainPageDensity ? 6 : 12),
            Text(
              historyLoaded
                  ? _emptyText(context, filter)
                  : AppLocaleText.tr(
                      context,
                      en: 'Loading experiments...',
                      zhHans: '正在加载小实验...',
                      zhHant: '正在載入小實驗...',
                      ja: '実験を読み込み中...',
                    ),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AuroraColors.ink,
                    fontWeight: FontWeight.w800,
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
                    en: 'After you save more signals, AI can help organize small experiments that fit you.',
                    zhHans: '当你保存更多信号后，AI 会帮你整理适合尝试的小实验。',
                    zhHant: '當你保存更多信號後，AI 會幫你整理適合嘗試的小實驗。',
                    ja: '記録が増えると、AI が試しやすい小さな実験を整理します。',
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
              SizedBox(height: mainPageDensity ? 10 : 18),
              _ExperimentPrimaryButton(
                key: mainPageDensity
                    ? const ValueKey('experiment-empty-primary-action')
                    : null,
                compact: mainPageDensity,
                label: AppLocaleText.tr(
                  context,
                  en: 'Record today',
                  zhHans: '去记录今天',
                  zhHant: '去記錄今天',
                  ja: '今日を記録',
                ),
                onTap: onRecordToday,
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
          en: 'No small experiments yet',
          zhHans: '还没有小实验',
          zhHant: '還沒有小實驗',
          ja: '小さな実験はまだありません',
        ),
      _ExperimentFilter.active => AppLocaleText.tr(
          context,
          en: 'No active experiments',
          zhHans: '暂无进行中的小实验',
          zhHant: '暫無進行中的小實驗',
          ja: '進行中の実験はありません',
        ),
      _ExperimentFilter.adjusted => AppLocaleText.tr(
          context,
          en: 'No adjusted experiments',
          zhHans: '暂无已调整的小实验',
          zhHant: '暫無已調整的小實驗',
          ja: '調整済みの実験はありません',
        ),
      _ExperimentFilter.completed => AppLocaleText.tr(
          context,
          en: 'No completed experiments',
          zhHans: '暂无已完成的小实验',
          zhHant: '暫無已完成的小實驗',
          ja: '完了した実験はありません',
        ),
      _ExperimentFilter.paused => AppLocaleText.tr(
          context,
          en: 'No paused experiments',
          zhHans: '暂无暂停的小实验',
          zhHant: '暫無暫停的小實驗',
          ja: '一時停止中の実験はありません',
        ),
      _ExperimentFilter.stopped => AppLocaleText.tr(
          context,
          en: 'No stopped experiments',
          zhHans: '暂无已停止的小实验',
          zhHant: '暫無已停止的小實驗',
          ja: '停止した実験はありません',
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
    this.mainPageDensity = false,
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
                        fontWeight: FontWeight.w900,
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
                      fontWeight: FontWeight.w800,
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
                fontWeight: FontWeight.w700,
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
    this.mainPageDensity = false,
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
        en: 'Experiment archive',
        zhHans: '小实验归档',
        zhHant: '小實驗歸檔',
        ja: '実験アーカイブ',
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
                en: 'Once you start a small experiment, its attempts and effect summary will appear here.',
                zhHans: '开始一个小实验后，这里会显示你的尝试情况和效果总结。',
                zhHant: '開始一個小實驗後，這裡會顯示你的嘗試情況和效果總結。',
                ja: '小さな実験を始めると、試行状況と効果の要約がここに表示されます。',
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
                  fontWeight: FontWeight.w900,
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
                          en: 'No experiment details yet',
                          zhHans: '还没有小实验详情',
                          zhHant: '還沒有小實驗詳情',
                          ja: '実験の詳細はまだありません',
                        )
                      : AppLocaleText.tr(
                          context,
                          en: '${metrics.total} experiment(s)',
                          zhHans: '${metrics.total} 个小实验',
                          zhHant: '${metrics.total} 個小實驗',
                          ja: '${metrics.total} 件の実験',
                        ),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AuroraColors.purple,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  metrics.total == 0
                      ? AppLocaleText.tr(
                          context,
                          en: 'After you add a next-week experiment from Weekly, its feedback, effect summary, linked signals, and timeline will appear here.',
                          zhHans:
                              '当你从 Weekly 加入一个下周小实验后，这里会展示它的反馈、效果总结、关联信号和时间线。',
                          zhHant:
                              '當你從 Weekly 加入一個下週小實驗後，這裡會展示它的回饋、效果總結、關聯信號和時間線。',
                          ja: 'Weekly から来週の実験を追加すると、フィードバック、効果の要約、関連シグナル、タイムラインがここに表示されます。',
                        )
                      : AppLocaleText.tr(
                          context,
                          en: 'This page uses the experiment timeline, effect summary, feedback, and linked signals. Counts stay at 0 until real attempts appear.',
                          zhHans: '这里读取小实验时间线、效果总结、反馈和关联信号。没有真实尝试时，数字会保持为 0。',
                          zhHant: '這裡讀取小實驗時間線、效果總結、回饋和關聯信號。沒有真實嘗試時，數字會保持為 0。',
                          ja: 'ここでは実験のタイムライン、効果の要約、フィードバック、関連シグナルを使います。実際の試行がなければ数値は 0 のままです。',
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
                en: 'Ended',
                zhHans: '已结束',
                zhHant: '已結束',
                ja: '終了',
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
                          fontWeight: FontWeight.w900,
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
    final tried = _actualTriedCount(experiment, evidence, rollup);
    return _ExperimentGlassCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Row(
        children: [
          Container(
            width: 120,
            height: 120,
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
            child: Icon(_experimentIcon(experiment), color: color, size: 58),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  experiment.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AuroraColors.purple,
                        fontWeight: FontWeight.w900,
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
                          en: '$tried tried · ${rollup?.helpfulCount ?? 0} helpful · ${rollup?.adjustedCount ?? 0} adjusted · ${rollup?.skippedCount ?? 0} skipped',
                          zhHans:
                              '$tried 次尝试 · ${rollup?.helpfulCount ?? 0} 次有效 · ${rollup?.adjustedCount ?? 0} 次调整 · ${rollup?.skippedCount ?? 0} 次跳过',
                          zhHant:
                              '$tried 次嘗試 · ${rollup?.helpfulCount ?? 0} 次有效 · ${rollup?.adjustedCount ?? 0} 次調整 · ${rollup?.skippedCount ?? 0} 次跳過',
                          ja: '$tried 回試行 · ${rollup?.helpfulCount ?? 0} 回有効 · ${rollup?.adjustedCount ?? 0} 回調整 · ${rollup?.skippedCount ?? 0} 回スキップ',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
                  fontWeight: FontWeight.w900,
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
        en: 'Experiment timeline summary',
        zhHans: '小实验时间线汇总',
        zhHant: '小實驗時間線彙總',
        ja: '実験タイムライン集計',
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
                        fontWeight: FontWeight.w900,
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
              en: 'This experiment belongs to a visible history chain. New weeks are appended or continued without overwriting the original.',
              zhHans: '这个实验属于一条可见的历史链。追加或延续到新周期时，不会覆盖原实验。',
              zhHant: '這個實驗屬於一條可見的歷史鏈。追加或延續到新週期時，不會覆蓋原實驗。',
              ja: 'この実験は見える履歴チェーンに属します。追加・継続しても元の実験は上書きしません。',
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
    final keywords = evidence.keywordsFor(experiment);
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
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${evidence.evidenceCount}',
                      style: TextStyle(
                        color: AuroraColors.purple,
                        fontSize: 50,
                        fontWeight: FontWeight.w900,
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
  final VoidCallback onRecordFeedback;

  const _ExperimentFeedbackTab({
    required this.experiment,
    required this.evidence,
    required this.points,
    required this.triedCount,
    required this.onRecordFeedback,
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
                    zhHans: '还没有反馈。可以从 Today 记录一次，让这个模式更贴近你。',
                    zhHant: '還沒有回饋。可以從 Today 記錄一次，讓這個模式更貼近你。',
                    ja: 'まだ反応がありません。Todayから一つ残すと、より自分に近い読みになります。',
                  ),
                )
              else
                for (final feedback in evidence.feedbacks.reversed.take(4))
                  _FeedbackRow(
                    date: feedback.feedbackDate,
                    score: evidence.valueForFeedback(feedback),
                    text: feedback.feedbackText?.trim().isNotEmpty == true
                        ? feedback.feedbackText!.trim()
                        : _readableEvidenceLabel(feedback.completionStatus),
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
        const SizedBox(height: 12),
        _ExperimentPrimaryButton(
          label: AppLocaleText.tr(
            context,
            en: 'Record new feedback',
            zhHans: '记录新的反馈',
            zhHant: '記錄新的回饋',
            ja: '新しいフィードバック',
          ),
          onTap: onRecordFeedback,
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
            en: 'Current experiment: ${experiment.title}',
            zhHans: '当前实验：${experiment.title}',
            zhHant: '當前實驗：${experiment.title}',
            ja: '現在の実験：${experiment.title}',
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
              for (final item in evidence.conditionKeywords().take(4))
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
              for (final item in evidence.keywordsFor(experiment).take(5))
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
                    for (final bucket in evidence.durationBuckets())
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
            zhHans: 'AI 洞察',
            zhHant: 'AI 洞察',
            ja: 'AI洞察',
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
        en: 'Experiment notes',
        zhHans: '实验笔记',
        zhHant: '實驗筆記',
        ja: '実験メモ',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NotesLine(
            icon: Icons.science_rounded,
            label: AppLocaleText.tr(
              context,
              en: 'Experiment',
              zhHans: '实验',
              zhHant: '實驗',
              ja: '実験',
            ),
            value: experiment.title,
          ),
          _NotesLine(
            icon: Icons.flag_rounded,
            label: AppLocaleText.tr(
              context,
              en: 'Small action',
              zhHans: '小行动',
              zhHant: '小行動',
              ja: '小さな行動',
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
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w900,
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
          Text(
            label,
            style: TextStyle(
              color: AuroraColors.ink.withValues(alpha: 0.74),
              fontWeight: FontWeight.w800,
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
                  Text(
                    point.label,
                    style: TextStyle(
                      color: AuroraColors.ink.withValues(alpha: 0.48),
                      fontSize: 11,
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _IconBubble(icon: icon, color: color, size: 36),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: AuroraColors.ink.withValues(alpha: 0.52),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
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
                      fontWeight: FontWeight.w900,
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
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
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
                    fontWeight: FontWeight.w900,
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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AuroraColors.purple,
                      fontWeight: FontWeight.w900,
                      height: 1.16,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                detail.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
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
                      zhHans: '实验进度',
                      zhHant: '實驗進度',
                      ja: '進捗',
                    ),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AuroraColors.purple,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(child: _ProgressBar(value: 0)),
                  const SizedBox(width: 14),
                  Text(
                    '0/7',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: const Color(0xFF566078),
                          fontWeight: FontWeight.w900,
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
                  en: 'Experiment name',
                  zhHans: '实验名称',
                  zhHant: '實驗名稱',
                  ja: '実験名',
                ),
                field: _ExperimentEditField(
                  controller: titleController,
                  label: AppLocaleText.tr(
                    context,
                    en: 'Experiment name',
                    zhHans: '实验名称',
                    zhHant: '實驗名稱',
                    ja: '実験名',
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
                  en: 'Experiment goal',
                  zhHans: '实验目标',
                  zhHant: '實驗目標',
                  ja: '実験目標',
                ),
                field: _ExperimentEditField(
                  controller: actionController,
                  label: AppLocaleText.tr(
                    context,
                    en: 'Experiment goal',
                    zhHans: '实验目标',
                    zhHant: '實驗目標',
                    ja: '実験目標',
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
            en: 'Experiment frequency',
            zhHans: '实验频率',
            zhHant: '實驗頻率',
            ja: '実験頻度',
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
                          fontWeight: FontWeight.w900,
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
                      fontWeight: FontWeight.w900,
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
                        fontWeight: FontWeight.w900,
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
                    fontWeight: FontWeight.w900,
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
                fontWeight: FontWeight.w900,
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
                  fontWeight: FontWeight.w900,
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
        en: 'Why this experiment',
        zhHans: '为什么是这个实验',
        zhHant: '為什麼是這個實驗',
        ja: 'なぜこの実験か',
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
        zhHans: '本周实验结果和复盘',
        zhHant: '本週實驗結果和復盤',
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
                  en: 'Experiment',
                  zhHans: '实验',
                  zhHant: '實驗',
                  ja: '実験',
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
                fontWeight: FontWeight.w900,
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
  final bool compact;

  const _ExperimentPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(compact ? 18 : 28),
        child: Ink(
          height: compact ? 48 : 62,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(compact ? 18 : 28),
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
                        fontWeight: FontWeight.w900,
                        fontSize: compact ? 16 : null,
                      ),
                ),
              ),
              SizedBox(width: compact ? 8 : 18),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white,
                size: compact ? 20 : 34,
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
                    fontWeight: FontWeight.w900,
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
    return Container(
      padding: padding ??
          (mainPageDensity
              ? AuroraMainPageSpec.comfortableCardPadding
              : const EdgeInsets.fromLTRB(18, 18, 18, 18)),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(
          mainPageDensity ? AuroraMainPageSpec.cardRadiusLarge : 24,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.88)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7863AA).withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
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
                        fontWeight: FontWeight.w900,
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
                        fontWeight: FontWeight.w900,
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
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.white.withValues(alpha: 0.62),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: const SizedBox(
            width: 54,
            height: 54,
            child: Icon(Icons.chevron_left_rounded, size: 34),
          ),
        ),
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
