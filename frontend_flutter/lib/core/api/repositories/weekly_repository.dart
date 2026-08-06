import 'package:shared_preferences/shared_preferences.dart';

import '../../backup/cloud_backup_sync_service.dart';
import '../../eligibility/signal_eligibility_service.dart';
import '../../local/local_capture_repository.dart';
import '../../local/local_experiment_candidate_repository.dart';
import '../../local/local_feedback_event_repository.dart';
import '../../local/local_life_experiment_repository.dart';
import '../../local/local_pipeline_run_repository.dart';
import '../../local/local_phase3_plus_repository.dart';
import '../../local/local_reflection_result_repository.dart';
import '../../local/local_weekly_snapshot_repository.dart';
import '../../models/experiment_evaluation_models.dart';
import '../../models/feedback_event_models.dart';
import '../../models/phase3_plus_models.dart';
import '../../models/today_models.dart';
import '../../models/weekly_models.dart';
import '../../i18n/runtime_locale_text.dart';
import '../../preferences/focus_domains.dart';
import '../../readiness/report_readiness.dart';
import 'ai_repository.dart';
import 'energy_budget_repository.dart';
import 'weekly_attempt_feedback_projector.dart';

typedef WeeklyFocusAreaLoader = Future<String?> Function();
typedef InstallationDateLoader = Future<DateTime> Function();
typedef WeeklyNowLoader = DateTime Function();

class WeeklyRepository {
  static const _generatedCopyCacheVersion = 'weekly_language_guard_v2';

  final LocalCaptureRepository localCaptureRepository;
  final LocalWeeklySnapshotRepository localWeeklySnapshotRepository;
  final LocalLifeExperimentRepository? localLifeExperimentRepository;
  final LocalPhase3PlusRepository? localPhase3PlusRepository;
  final AiRepository aiRepository;
  final WeeklyFocusAreaLoader? focusAreaLoader;
  final InstallationDateLoader? installationDateLoader;
  final CloudBackupSyncService? cloudBackupSyncService;
  final String localUserId;
  final SignalEligibilityService eligibilityService;
  final WeeklyNowLoader nowLoader;

  WeeklyRepository({
    required this.localCaptureRepository,
    required this.localWeeklySnapshotRepository,
    required this.aiRepository,
    this.localLifeExperimentRepository,
    this.localPhase3PlusRepository,
    this.focusAreaLoader,
    this.installationDateLoader,
    this.cloudBackupSyncService,
    this.localUserId = 'local',
    SignalEligibilityService? eligibilityService,
    WeeklyNowLoader? nowLoader,
  })  : eligibilityService =
            eligibilityService ?? const SignalEligibilityService(),
        nowLoader = nowLoader ?? DateTime.now;

  Future<WeeklyInsightModel> fetchCurrentWeekly() async {
    final installationDate = await _readOrCreateInstallationDate();
    final today = _dateOnly(nowLoader());
    final isFirstDay = _sameDay(installationDate, today);
    final range = _currentWeekRange();

    final weekRangeSignals =
        await localCaptureRepository.listSignalCardsBetween(
      startDate: _dateKey(range.start),
      endDate: _dateKey(range.end),
    );

    if (isFirstDay && weekRangeSignals.isEmpty) {
      final readiness = ReportReadiness.empty(
        ReportReadinessEvaluator.weeklyRule,
      );
      return _withWeeklyReviewProjections(
        WeeklyInsightModel(
          weekStart: _dateKey(range.start),
          weekEnd: _dateKey(range.end),
          status: 'first_day_gate',
          keyInsight: null,
          patterns: const [],
          frictions: const [],
          bestAction: null,
          opportunitySnapshot: {
            '_report_readiness': readiness.toMap(),
          },
          feedbackSubmitted: false,
          chartData: _buildChartDataForEmptyRange(
            start: range.start,
            end: range.end,
          ),
        ),
        range: range,
        currentSignals: const [],
        feedbackEvents: const [],
      );
    }

    final weekSignals = _weeklyEligibleSignals(weekRangeSignals);
    final readiness = const ReportReadinessEvaluator().evaluate(
      weekSignals,
      ReportReadinessEvaluator.weeklyRule,
    );
    final inclusionSummary = _buildInclusionSummary(
      weekRangeSignals: weekRangeSignals,
      eligibleSignals: weekSignals,
    );

    if (!readiness.isReady) {
      final feedbackEvents = await LocalFeedbackEventRepository(
        localWeeklySnapshotRepository.localDatabase,
      ).listActiveBetween(
        localUserId: localUserId,
        startDate: _dateKey(range.start),
        endDate: _dateKey(range.end),
      );
      return _withWeeklyReviewProjections(
        WeeklyInsightModel(
          weekStart: _dateKey(range.start),
          weekEnd: _dateKey(range.end),
          status: 'insufficient_data',
          keyInsight: null,
          patterns: const [],
          frictions: const [],
          bestAction: null,
          opportunitySnapshot: {
            '_weekly_inclusion': inclusionSummary,
            '_report_readiness': readiness.toMap(),
          },
          feedbackSubmitted: false,
          chartData: _buildChartDataForEmptyRange(
            start: range.start,
            end: range.end,
          ),
        ),
        range: range,
        currentSignals: weekSignals,
        feedbackEvents: feedbackEvents,
      );
    }

    final stats = _buildWeeklyStats(weekSignals);
    final weekStartKey = _dateKey(range.start);
    final weekEndKey = _dateKey(range.end);
    final feedbackEvents = await LocalFeedbackEventRepository(
      localWeeklySnapshotRepository.localDatabase,
    ).listActiveBetween(
      localUserId: localUserId,
      startDate: weekStartKey,
      endDate: weekEndKey,
    );
    final sourceEntries = [
      ...stats.entries,
      ..._feedbackEventEntries(feedbackEvents),
    ];
    final sourceHash = localWeeklySnapshotRepository.buildSourceHash(
      entries: sourceEntries,
      dayCounts: stats.dayCounts,
      topTokens: stats.topTokens,
      language:
          '${RuntimeLocaleText.normalize(aiRepository.languageLoader())}|$_generatedCopyCacheVersion',
    );

    final phase3ActionReview =
        await localPhase3PlusRepository?.summarizeActionLoop(
      startDate: weekStartKey,
      endDate: weekEndKey,
    );
    final cached = await localWeeklySnapshotRepository.getByWeekStart(
      weekStartKey,
    );
    final cachedHash = await localWeeklySnapshotRepository.getSourceHash(
      weekStartKey,
    );

    if (cached != null && cachedHash == sourceHash) {
      final hydrated = _withActionReview(
        _withWeeklySignalEntries(
          _withFeedbackEventSummary(
            cached,
            feedbackEvents,
          ),
          stats.entries,
        ),
        phase3ActionReview,
      );
      await _ensureSuggestedExperimentCandidate(
        hydrated,
        weekSignals: weekSignals,
      );
      return _withWeeklyReviewProjections(
        hydrated,
        range: range,
        currentSignals: weekSignals,
        feedbackEvents: feedbackEvents,
      );
    }

    final focusArea = await _readFocusArea();
    final activeAppDays = today.difference(installationDate).inDays + 1;
    final isLightWeekly = _isLightWeekly(
      stats,
      activeAppDays: activeAppDays,
    );

    WeeklyInsightModel generated;
    try {
      generated = await aiRepository.generateWeeklySummary(
        weekStart: weekStartKey,
        weekEnd: weekEndKey,
        entries: sourceEntries,
        dayCounts: stats.dayCounts,
        topTokens: stats.topTokens,
        focusArea: focusArea,
      );
      generated = _normalizeGeneratedWeekly(
        generated: generated,
        stats: stats,
        isLightWeekly: isLightWeekly,
        inclusionSummary: inclusionSummary,
      );
      if (!_generatedWeeklyMatchesLanguage(generated)) {
        generated = _buildFallbackWeeklyInsight(
          weekStart: weekStartKey,
          weekEnd: _dateKey(range.end),
          stats: stats,
          isLightWeekly: isLightWeekly,
          inclusionSummary: inclusionSummary,
        );
      }
    } catch (error) {
      await _recordPipelineFailure(
        pipelineType: 'reflect_generation',
        sourceType: 'weekly_snapshot',
        sourceId: weekStartKey,
        inputHash: sourceHash,
        error: error,
      );
      generated = _buildFallbackWeeklyInsight(
        weekStart: weekStartKey,
        weekEnd: _dateKey(range.end),
        stats: stats,
        isLightWeekly: isLightWeekly,
        inclusionSummary: inclusionSummary,
      );
    }

    await _markIncludedInWeekly(weekSignals);
    generated = _withActionReview(
      _withWeeklySignalEntries(
        _withFeedbackEventSummary(
          generated,
          feedbackEvents,
        ),
        stats.entries,
      ),
      phase3ActionReview,
    );
    await _ensureSuggestedExperimentCandidate(
      generated,
      weekSignals: weekSignals,
    );
    await localWeeklySnapshotRepository.upsert(
      weekly: generated,
      sourceHash: sourceHash,
    );

    return _withWeeklyReviewProjections(
      generated,
      range: range,
      currentSignals: weekSignals,
      feedbackEvents: feedbackEvents,
    );
  }

  List<Map<String, dynamic>> _feedbackEventEntries(
    List<FeedbackEventModel> events,
  ) {
    return events.map((event) {
      final content = [
        event.status,
        event.effect,
        event.note,
        event.metadata['title']?.toString(),
        event.metadata['next_adjustment']?.toString(),
      ]
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .join(' · ');

      return {
        'id': event.id,
        'source_type': event.sourceType,
        'subject_type': event.subjectType,
        'subject_id': event.subjectId,
        'content': content,
        'created_at': event.createdAt?.toUtc().toIso8601String() ??
            event.occurredAt?.toUtc().toIso8601String(),
        'local_date': event.localDate,
        'feedback_status': event.status,
        'effect': event.effect,
        'metadata': event.metadata,
      };
    }).toList(growable: false);
  }

  WeeklyInsightModel _withFeedbackEventSummary(
    WeeklyInsightModel weekly,
    List<FeedbackEventModel> feedbackEvents,
  ) {
    if (feedbackEvents.isEmpty) return weekly;

    final sourceCounts = <String, int>{};
    for (final event in feedbackEvents) {
      sourceCounts[event.sourceType] =
          (sourceCounts[event.sourceType] ?? 0) + 1;
    }

    return WeeklyInsightModel(
      weekStart: weekly.weekStart,
      weekEnd: weekly.weekEnd,
      status: weekly.status,
      keyInsight: weekly.keyInsight,
      patterns: weekly.patterns,
      frictions: weekly.frictions,
      bestAction: weekly.bestAction,
      opportunitySnapshot: {
        ...?weekly.opportunitySnapshot,
        '_feedback_event_summary': {
          'total_count': feedbackEvents.length,
          'source_counts': sourceCounts,
          'helpful_count': feedbackEvents
              .where(
                (event) =>
                    _isHelpfulFeedbackText(event.status) ||
                    _isHelpfulFeedbackText(event.effect),
              )
              .length,
          'events': feedbackEvents
              .take(12)
              .map((event) => event.toJson())
              .toList(growable: false),
        },
      },
      feedbackSubmitted: weekly.feedbackSubmitted,
      chartData: weekly.chartData,
      previousWeekSummary: weekly.previousWeekSummary,
      behaviorPatterns: weekly.behaviorPatterns,
      energyProjection: weekly.energyProjection,
    );
  }

  bool _isHelpfulFeedbackText(String? value) {
    final normalized = value?.trim().toLowerCase();
    return normalized == 'helpful' ||
        normalized == 'very_helpful' ||
        normalized == 'yes' ||
        normalized == 'positive' ||
        normalized == 'recovery' ||
        normalized == 'energizing';
  }

  Future<void> _recordPipelineFailure({
    required String pipelineType,
    required String sourceType,
    required String sourceId,
    required String inputHash,
    required Object error,
  }) async {
    final repository = LocalPipelineRunRepository(
      localWeeklySnapshotRepository.localDatabase,
    );
    final runId = await repository.start(
      pipelineType: pipelineType,
      sourceType: sourceType,
      sourceId: sourceId,
      inputHash: inputHash,
    );
    await repository.fail(
      runId: runId,
      errorCode: error.runtimeType.toString(),
      errorMessage: error.toString(),
    );
  }

  Future<WeeklyReflectModel> fetchWeeklyReflect() async {
    final weekly = await fetchCurrentWeekly();
    final focusArea = await _readFocusArea();
    final reflect = await aiRepository.generateWeeklyReflect(
      weekly: weekly,
      focusArea: focusArea,
    );
    // A standard Weekly snapshot is not a deep analysis. Persist only this
    // explicit L3 result so future planning can opt in to it without treating
    // a free/standard weekly summary as Pro context.
    await LocalReflectionResultRepository(
      localWeeklySnapshotRepository.localDatabase,
    ).saveCurrent(
      sourceType: 'weekly_snapshot',
      sourceId: weekly.weekStart,
      reflectionType: 'weekly_deep_analysis',
      aiLevel: 'L3',
      sourceHash: await localWeeklySnapshotRepository.getSourceHash(
        weekly.weekStart,
      ),
      content: {
        'summary': reflect.summary,
        'root_tension': reflect.rootTension,
        'hidden_pattern': reflect.hiddenPattern,
        'next_focus': reflect.nextFocus,
        'risk_note': reflect.riskNote,
        'pattern_label': reflect.patternLabel,
        'friction_label': reflect.frictionLabel,
        'impact_label': reflect.impactLabel,
        'relationship_summary': reflect.relationshipSummary,
        'timing_summary': reflect.timingSummary,
        'next_question': reflect.nextQuestion,
        'source_signal_card_ids': reflect.sourceSignalCardIds,
        'scope_note': reflect.scopeNote,
      },
    );
    return reflect;
  }

  Future<LifeExperimentModel?> fetchWeeklyExperimentCandidate({
    required String weekStart,
  }) {
    return _experimentCandidateRepository.getWeeklyCandidate(
      localUserId: localUserId,
      weekStart: weekStart,
    );
  }

  Future<LifeExperimentModel?> fetchCurrentWeekLifeExperiment({
    required String weekStart,
  }) {
    final start = DateTime.tryParse(weekStart);
    final repository = localLifeExperimentRepository;
    if (repository == null || start == null) return Future.value(null);
    return repository.getSavedForToday(
      localUserId: localUserId,
      today: start,
    );
  }

  Future<LifeExperimentModel?> fetchNextWeekExperiment({
    required String weekStart,
  }) async {
    final candidate = await fetchWeeklyExperimentCandidate(
      weekStart: weekStart,
    );
    if (candidate == null) return null;
    final repository = localLifeExperimentRepository;
    if (repository == null) return candidate;
    return await _experimentCandidateRepository.getAdoptedExperiment(
          candidateId: candidate.id,
          lifeExperimentRepository: repository,
        ) ??
        candidate;
  }

  Future<void> submitWeeklyFeedback({
    required String weekStart,
    required String feedbackValue,
  }) async {
    await localWeeklySnapshotRepository.markFeedbackSubmitted(weekStart);
  }

  Future<LifeExperimentModel?> saveLifeExperiment(String experimentId) async {
    final lifeRepo = localLifeExperimentRepository;
    if (lifeRepo == null) return null;

    final experiment = experimentId.startsWith('cand_')
        ? await _experimentCandidateRepository.adoptCandidate(
            candidateId: experimentId,
            lifeExperimentRepository: lifeRepo,
          )
        : await lifeRepo.updateStatus(
            experimentId: experimentId,
            status: 'saved',
          );
    if (experiment != null) {
      await lifeRepo.linkSignalCards(
        experimentId: experiment.id,
        signalCardIds: experiment.linkedSignalCardIds,
      );
      cloudBackupSyncService?.markDataChanged();
    }
    return experiment;
  }

  Future<LifeExperimentModel?> skipLifeExperiment(String experimentId) async {
    // This API is retained only for dismissing a not-yet-adopted candidate.
    // An adopted goal has no manual stop/end path: at the week boundary it is
    // continued when selected, otherwise its weekly projection completes.
    if (!experimentId.startsWith('cand_')) return null;
    final experiment = await _experimentCandidateRepository.updateStatus(
      candidateId: experimentId,
      status: 'skipped',
    );
    if (experiment != null) cloudBackupSyncService?.markDataChanged();
    return experiment;
  }

  Future<LifeExperimentModel?> submitLifeExperimentFeedback({
    required String experimentId,
    required String status,
    required String feedbackText,
  }) async {
    if (experimentId.startsWith('cand_')) {
      // A next-week candidate cannot receive progress feedback and feedback
      // must never implicitly adopt it. Adoption is an explicit user action.
      return _experimentCandidateRepository.getById(experimentId);
    }
    final resolvedExperimentId = experimentId;
    final feedback = await localLifeExperimentRepository?.recordFeedback(
      experimentId: resolvedExperimentId,
      completionStatus: status,
      feedbackText: feedbackText,
      feedbackDate: nowLoader(),
      enforceProgressWindow: true,
    );
    if (feedback == null) return null;
    cloudBackupSyncService?.markDataChanged();
    return localLifeExperimentRepository?.updateDetails(
      experimentId: resolvedExperimentId,
      feedbackText: feedbackText,
    );
  }

  Future<MicroActionModel?> submitMicroActionFeedback({
    required String microActionId,
    required String status,
    String? effect,
    String? difficulty,
    String? userNote,
  }) async {
    final repo = localPhase3PlusRepository;
    if (repo == null) return null;

    final action = await repo.getMicroActionById(microActionId);
    if (action == null) return null;

    final now = nowLoader();
    if (!_canRecordMicroActionFeedbackOn(action: action, date: now)) {
      return null;
    }

    final canonicalStatus = switch (status.trim().toLowerCase()) {
      'completed' || 'done' || 'occurred' || 'happened' => 'completed',
      'not_completed' ||
      'not_done' ||
      'not_occurred' ||
      'not_happened' =>
        'not_completed',
      _ => throw ArgumentError.value(status, 'status', 'unsupported_feedback'),
    };

    final isCompleted = canonicalStatus == 'completed';
    final normalizedEffect = isCompleted ? effect : null;
    final normalizedDifficulty = isCompleted ? difficulty : null;
    await repo.recordStructuredMicroActionFeedback(
      microActionId: action.id,
      localDate: _dateKey(now),
      completionStatus: canonicalStatus,
      effect: normalizedEffect,
      difficulty: normalizedDifficulty,
      note: userNote,
      nextAdjustment: normalizedDifficulty == SmallTryDifficulty.difficult
          ? SmallTryNextAdjustment.makeLighter
          : SmallTryNextAdjustment.keep,
      createdAt: now,
    );
    await repo.updateMicroActionStatus(
      id: action.id,
      status: action.status,
      feedbackStatus: canonicalStatus,
    );
    cloudBackupSyncService?.markDataChanged();
    return repo.getMicroActionById(action.id);
  }

  bool _canRecordMicroActionFeedbackOn({
    required MicroActionModel action,
    required DateTime date,
  }) {
    final lifecycle = action.status.trim().toLowerCase();
    if (lifecycle.contains('pause') ||
        lifecycle.contains('stop') ||
        lifecycle.contains('skip') ||
        lifecycle.contains('archive') ||
        lifecycle.contains('complete') ||
        lifecycle.contains('done') ||
        lifecycle.contains('finish') ||
        lifecycle.contains('dismiss')) {
      return false;
    }

    final start = DateTime.tryParse(
          action.progressStartDate ?? action.plannedDate ?? '',
        ) ??
        action.adoptedAt ??
        action.createdAt;
    if (start == null) return false;
    final configuredEnd = DateTime.tryParse(action.progressEndDate ?? '');
    final localDate = DateTime(date.year, date.month, date.day);
    final localStart = DateTime(start.year, start.month, start.day);
    if (localDate.isBefore(localStart)) return false;
    // Missing progress_end_date means an open-ended adopted small try, not an
    // implicit seven-day window. Lifecycle state remains the primary gate.
    if (configuredEnd == null) return true;
    final localEnd = DateTime(
      configuredEnd.year,
      configuredEnd.month,
      configuredEnd.day,
    );
    return !localDate.isAfter(localEnd);
  }

  Future<LifeExperimentModel?> updateLifeExperimentDetails({
    required String experimentId,
    required String title,
    required String hypothesis,
    required String suggestedAction,
  }) async {
    if (experimentId.startsWith('cand_')) {
      // Editing a current/next-week candidate must not implicitly adopt it.
      return _experimentCandidateRepository.updateContent(
        candidateId: experimentId,
        title: title,
        hypothesis: hypothesis,
        suggestedAction: suggestedAction,
      );
    }
    final experiment = await localLifeExperimentRepository?.updateDetails(
      experimentId: experimentId,
      title: title,
      hypothesis: hypothesis,
      suggestedAction: suggestedAction,
    );
    if (experiment != null) cloudBackupSyncService?.markDataChanged();
    return experiment;
  }

  List<RecentSignalModel> _weeklyEligibleSignals(
    List<RecentSignalModel> signals,
  ) {
    return eligibilityService.filter(
      signals,
      SignalEligibilityStage.weekly,
    );
  }

  Future<void> _markIncludedInWeekly(List<RecentSignalModel> signals) async {
    final ids = signals
        .where((signal) => !signal.isLegacy)
        .map((signal) => signal.signalCardId ?? signal.id ?? '')
        .where((id) => id.trim().isNotEmpty)
        .toSet();
    if (ids.isEmpty) return;
    await localCaptureRepository.updateSignalCardInclusion(
      signalCardIds: ids,
      includedInWeekly: true,
    );
  }

  Future<void> _ensureSuggestedExperimentCandidate(
    WeeklyInsightModel weekly, {
    required List<RecentSignalModel> weekSignals,
  }) async {
    final repo = localLifeExperimentRepository;
    if (repo == null) return;

    final structure = weekly.deriveV3CStructure();
    final linkedIds = weekSignals
        .where((signal) => !signal.isLegacy)
        .map((signal) => signal.signalCardId ?? signal.id ?? '')
        .where((id) => id.trim().isNotEmpty)
        .toSet()
        .toList();
    if (linkedIds.length < 3) return;
    final previous = await repo.getPreviousForWeek(
      localUserId: localUserId,
      beforeWeekStart: weekly.weekStart,
    );
    final feedbackNote = previous?.feedbackText?.trim();
    final hypothesisSuffix = feedbackNote == null || feedbackNote.isEmpty
        ? ''
        : _copy(
            en: ' Previous-round feedback will stay in the background for the next adjustment: $feedbackNote',
            zhHans: ' 上一轮反馈会作为下次调整的背景：$feedbackNote',
            zhHant: ' 上一輪回饋會作為下次調整的背景：$feedbackNote',
            ja: ' 前回のフィードバックは、次の調整の背景として残します：$feedbackNote',
          );

    await _experimentCandidateRepository.ensureWeeklyCandidate(
      localUserId: localUserId,
      weekStart: weekly.weekStart,
      weekEnd: weekly.weekEnd,
      title: structure.onePattern,
      hypothesis: _copy(
        en: 'Gently adjusting “${structure.onePattern}” this week may save you a little effort.$hypothesisSuffix',
        zhHans:
            '如果这周先轻轻调整“${structure.onePattern}”，可能会帮你省一点力。$hypothesisSuffix',
        zhHant:
            '如果這週先輕輕調整「${structure.onePattern}」，可能會幫你省一點力。$hypothesisSuffix',
        ja: '今週「${structure.onePattern}」を少しだけ調整すると、負担を軽くできるかもしれません。$hypothesisSuffix',
      ),
      suggestedAction: structure.oneExperiment,
      linkedSignalCardIds: linkedIds,
    );
  }

  LocalExperimentCandidateRepository get _experimentCandidateRepository {
    return LocalExperimentCandidateRepository(
      localWeeklySnapshotRepository.localDatabase,
    );
  }

  WeeklyInsightModel _withActionReview(
    WeeklyInsightModel weekly,
    Map<String, dynamic>? actionReview,
  ) {
    if (actionReview == null) return weekly;
    return WeeklyInsightModel(
      weekStart: weekly.weekStart,
      weekEnd: weekly.weekEnd,
      status: weekly.status,
      keyInsight: weekly.keyInsight,
      patterns: weekly.patterns,
      frictions: weekly.frictions,
      bestAction: weekly.bestAction,
      opportunitySnapshot: {
        ...?weekly.opportunitySnapshot,
        '_weekly_action_review': actionReview,
      },
      feedbackSubmitted: weekly.feedbackSubmitted,
      chartData: weekly.chartData,
      previousWeekSummary: weekly.previousWeekSummary,
      behaviorPatterns: weekly.behaviorPatterns,
      energyProjection: weekly.energyProjection,
    );
  }

  WeeklyInsightModel _withWeeklySignalEntries(
    WeeklyInsightModel weekly,
    List<Map<String, dynamic>> entries,
  ) {
    return WeeklyInsightModel(
      weekStart: weekly.weekStart,
      weekEnd: weekly.weekEnd,
      status: weekly.status,
      keyInsight: weekly.keyInsight,
      patterns: weekly.patterns,
      frictions: weekly.frictions,
      bestAction: weekly.bestAction,
      opportunitySnapshot: {
        ...?weekly.opportunitySnapshot,
        '_weekly_signal_entries': entries,
      },
      feedbackSubmitted: weekly.feedbackSubmitted,
      chartData: weekly.chartData,
      previousWeekSummary: weekly.previousWeekSummary,
      behaviorPatterns: weekly.behaviorPatterns,
      energyProjection: weekly.energyProjection,
    );
  }

  /// Adds the fact-backed Weekly projections which are intentionally not part
  /// of the generated prose snapshot. This keeps "上周回看" tied to the real
  /// preceding Monday--Sunday range, and keeps deep-analysis inputs read-only.
  Future<WeeklyInsightModel> _withWeeklyReviewProjections(
    WeeklyInsightModel weekly, {
    required _WeekRange range,
    required List<RecentSignalModel> currentSignals,
    required List<FeedbackEventModel> feedbackEvents,
  }) async {
    final previousSummary = await _buildPreviousWeekSummary(range);
    final attemptFeedbackSummaries =
        WeeklyAttemptFeedbackProjector.build(feedbackEvents);
    // Chart points are factual projections of the current Signal rows. Never
    // retain generated or cached chart points, which may be stale or may have
    // been returned as illustrative values by an older model response.
    final factualChartData = _buildWeeklyStats(currentSignals).chartData;
    return WeeklyInsightModel(
      weekStart: weekly.weekStart,
      weekEnd: weekly.weekEnd,
      status: weekly.status,
      keyInsight: weekly.keyInsight,
      patterns: weekly.patterns,
      frictions: weekly.frictions,
      bestAction: weekly.bestAction,
      opportunitySnapshot: {
        ...?weekly.opportunitySnapshot,
        '_weekly_attempt_feedback_summaries': attemptFeedbackSummaries
            .map((summary) => summary.toMap())
            .toList(growable: false),
      },
      feedbackSubmitted: weekly.feedbackSubmitted,
      chartData: factualChartData,
      previousWeekSummary: previousSummary,
      behaviorPatterns: _buildBehaviorPatterns(currentSignals),
      energyProjection: _buildEnergyProjection(
        range: range,
        signals: currentSignals,
        feedbackEvents: feedbackEvents,
      ),
    );
  }

  Future<PreviousWeekSummaryModel> _buildPreviousWeekSummary(
    _WeekRange currentRange,
  ) async {
    final start = currentRange.start.subtract(const Duration(days: 7));
    final end = currentRange.end.subtract(const Duration(days: 7));
    final rawSignals = await localCaptureRepository.listSignalCardsBetween(
      startDate: _dateKey(start),
      endDate: _dateKey(end),
    );
    final signals = _weeklyEligibleSignals(rawSignals);
    final readiness = const ReportReadinessEvaluator().evaluate(
      signals,
      ReportReadinessEvaluator.weeklyRule,
    );
    final stats = _buildWeeklyStats(signals);
    final sourceIds = signals
        .map((signal) => signal.signalCardId ?? signal.id ?? '')
        .where((id) => id.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final sourceHash = localWeeklySnapshotRepository.buildSourceHash(
      entries: stats.entries,
      dayCounts: stats.dayCounts,
      topTokens: stats.topTokens,
      language: aiRepository.languageLoader(),
    );
    final recordedDays = stats.dayCounts.length;
    final factualSummary = signals.isEmpty
        ? _copy(
            en: 'There were no Signals to review last week.',
            zhHans: '上周还没有可回看的 Signal。',
            zhHant: '上週還沒有可回看的 Signal。',
            ja: '先週は振り返れる Signal がありませんでした。',
          )
        : _copy(
            en: 'Last week included ${signals.length} Signals across $recordedDays days.',
            zhHans: '上周记录了 ${signals.length} 条 Signal，分布在 $recordedDays 天。',
            zhHant: '上週記錄了 ${signals.length} 條 Signal，分布在 $recordedDays 天。',
            ja: '先週は $recordedDays 日にわたり ${signals.length} 件の Signal を記録しました。',
          );
    final watchpoint = readiness.isReady
        ? _copy(
            en: 'This week, watch for: ${_previousWeekWatchpoint(signals, stats)}',
            zhHans: '本周可留意：${_previousWeekWatchpoint(signals, stats)}',
            zhHant: '本週可留意：${_previousWeekWatchpoint(signals, stats)}',
            ja: '今週の注目点：${_previousWeekWatchpoint(signals, stats)}',
          )
        : _copy(
            en: 'There are still few records; keep observing this week.',
            zhHans: '本周可留意：记录还少，先继续观察。',
            zhHant: '本週可留意：記錄還少，先繼續觀察。',
            ja: '記録はまだ少ないため、今週も観察を続けましょう。',
          );
    return PreviousWeekSummaryModel(
      weekStart: _dateKey(start),
      weekEnd: _dateKey(end),
      readiness: readiness,
      signalCount: signals.length,
      recordedDayCount: recordedDays,
      factualSummary: factualSummary,
      thisWeekWatchpoint: watchpoint,
      sourceSignalCardIds: sourceIds,
      sourceHash: sourceHash,
    );
  }

  String _previousWeekWatchpoint(
    List<RecentSignalModel> signals,
    _WeeklyStats stats,
  ) {
    final sceneCounts = <String, int>{};
    final frictionCounts = <String, int>{};
    for (final signal in signals) {
      final scene = _meaningfulSignalLabel(signal.scene);
      final friction = _meaningfulSignalLabel(signal.friction);
      if (scene != null) sceneCounts[scene] = (sceneCounts[scene] ?? 0) + 1;
      if (friction != null) {
        frictionCounts[friction] = (frictionCounts[friction] ?? 0) + 1;
      }
    }
    String? mostCommon(Map<String, int> values) {
      if (values.isEmpty) return null;
      final entries = values.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return entries.first.key;
    }

    final scene = mostCommon(sceneCounts);
    final friction = mostCommon(frictionCounts);
    if (scene != null && friction != null) {
      return _copy(
        en: 'whether “$friction” returns during “$scene”.',
        zhHans: '“$scene”时的“$friction”是否再次出现。',
        zhHant: '「$scene」時的「$friction」是否再次出現。',
        ja: '「$scene」のときに「$friction」が再び現れるか。',
      );
    }
    if (scene != null) {
      return _copy(
        en: 'whether the “$scene” setting returns.',
        zhHans: '“$scene”这个场景是否再次出现。',
        zhHant: '「$scene」這個情境是否再次出現。',
        ja: '「$scene」という場面が再び現れるか。',
      );
    }
    if (friction != null) {
      return _copy(
        en: 'whether “$friction” returns.',
        zhHans: '“$friction”是否再次出现。',
        zhHant: '「$friction」是否再次出現。',
        ja: '「$friction」が再び現れるか。',
      );
    }
    if (stats.topTokens.isNotEmpty) {
      final token = stats.topTokens.first;
      return _copy(
        en: 'whether situations related to “$token” return.',
        zhHans: '“$token”相关情况是否再次出现。',
        zhHant: '「$token」相關情況是否再次出現。',
        ja: '「$token」に関する状況が再び現れるか。',
      );
    }
    return _copy(
      en: 'which moments feel more draining or easier.',
      zhHans: '哪些时刻让你感觉更费力或更轻松。',
      zhHant: '哪些時刻讓你感覺更費力或更輕鬆。',
      ja: 'どの瞬間に負担が増えたり軽くなったりするか。',
    );
  }

  List<WeeklyBehaviorPatternModel> _buildBehaviorPatterns(
    List<RecentSignalModel> signals,
  ) {
    final buckets = <String, _PatternBucket>{};
    for (final signal in signals) {
      final scene = _meaningfulSignalLabel(signal.scene);
      final friction = _meaningfulSignalLabel(signal.friction);

      if (scene != null && friction != null) {
        _addPatternSignal(
          buckets,
          key: 'pair:$scene|$friction',
          label: _copy(
            en: 'Records about “$scene” included “$friction” together more than once',
            zhHans: '“$scene”的记录中，多次同时出现“$friction”',
            zhHant: '「$scene」的記錄中，多次同時出現「$friction」',
            ja: '「$scene」の記録で「$friction」が複数回一緒に現れた',
          ),
          kind: 'context_response',
          signal: signal,
        );
      }
    }
    _addContextDifferencePatterns(signals, buckets);
    _addRepeatedSequencePatterns(signals, buckets);
    _addTradeoffPatterns(signals, buckets);

    final candidates = buckets.entries.where((entry) {
      // A pattern must be supported by multiple actual Signals. A single
      // observation remains in the timeline, rather than becoming a label.
      return entry.value.signalIds.length >= 2 && entry.value.dates.length >= 2;
    }).toList()
      ..sort((a, b) {
        final priority = _behaviorPatternPriority(a.value.kind)
            .compareTo(_behaviorPatternPriority(b.value.kind));
        if (priority != 0) return priority;
        final support =
            b.value.signalIds.length.compareTo(a.value.signalIds.length);
        if (support != 0) return support;
        return b.value.dates.length.compareTo(a.value.dates.length);
      });
    final selected = <WeeklyBehaviorPatternModel>[];
    final usedSignalSets = <Set<String>>[];
    for (final entry in candidates) {
      if (selected.length >= 3) break;
      final ids = entry.value.signalIds.toList()..sort();
      final duplicate = usedSignalSets.any((used) =>
          ids.toSet().difference(used).isEmpty ||
          used.difference(ids.toSet()).isEmpty);
      if (duplicate) continue;
      final dates = entry.value.dates.toList()..sort();
      selected.add(WeeklyBehaviorPatternModel(
        id: _stableWeeklyId('${entry.key}:${ids.join(',')}'),
        label: entry.value.label,
        summary: _behaviorPatternSummary(entry.value.kind),
        kind: entry.value.kind,
        sourceSignalCardIds: ids,
        supportDates: dates,
        illustrationHint: _deriveWeeklyIllustrationHint(entry.value.label),
      ));
      usedSignalSets.add(ids.toSet());
    }
    return selected;
  }

  String _behaviorPatternSummary(String kind) {
    return switch (kind) {
      'context' => _copy(
          en: 'This setting repeated across several record days and was a relatively stable backdrop this week.',
          zhHans: '这个场景在多个记录日重复出现，是本周较稳定的行为背景。',
          zhHant: '這個情境在多個記錄日重複出現，是本週較穩定的行為背景。',
          ja: 'この場面は複数の記録日に繰り返し現れ、今週の比較的安定した背景になっていました。'),
      'response' => _copy(
          en: 'The same response appeared across several record days, rather than being a one-off feeling.',
          zhHans: '相同反应跨多个记录日出现，不只是一次性的感受。',
          zhHant: '相同反應跨多個記錄日出現，不只是一次性的感受。',
          ja: '同じ反応が複数の記録日に現れており、一度きりの感覚ではありません。'),
      'context_difference' => _copy(
          en: 'The same response appeared in different settings, rather than being limited to one situation.',
          zhHans: '相同反应出现在不同场景中，并不只局限于一种情境。',
          zhHant: '相同反應出現在不同情境中，並不只局限於一種情境。',
          ja: '同じ反応が異なる場面に現れ、一つの状況だけに限られていません。'),
      'sequence' => _copy(
          en: 'This order of events repeated across several record days.',
          zhHans: '这一先后顺序在多个记录日重复出现。',
          zhHant: '這一先後順序在多個記錄日重複出現。',
          ja: 'この順序が複数の記録日で繰り返されました。'),
      'tradeoff' => _copy(
          en: 'The same setting had different energy states on different dates, so its outcome was not fixed.',
          zhHans: '同一场景在不同日期呈现不同能量状态，结果并不固定。',
          zhHant: '同一情境在不同日期呈現不同能量狀態，結果並不固定。',
          ja: '同じ場面でも日によってエネルギー状態が異なり、結果は一定ではありません。'),
      _ => _copy(
          en: 'This setting and response appeared together across several record days, forming a recognizable combination.',
          zhHans: '这个场景与反应在多个记录日同时出现，形成了可辨认的组合。',
          zhHant: '這個情境與反應在多個記錄日同時出現，形成了可辨認的組合。',
          ja: 'この場面と反応が複数の記録日に一緒に現れ、識別できる組み合わせになっています。'),
    };
  }

  /// A context difference means the same explicitly recorded reaction was
  /// present in different named scenes on different dates. It describes a
  /// spread of facts only; it does not claim that either scene caused it.
  void _addContextDifferencePatterns(
    List<RecentSignalModel> signals,
    Map<String, _PatternBucket> buckets,
  ) {
    final byReaction = <String, List<RecentSignalModel>>{};
    final labels = <String, String>{};
    for (final signal in signals) {
      final scene = _meaningfulSignalLabel(signal.scene);
      final reaction = _reactionMarker(signal);
      if (scene == null || reaction == null) continue;
      (byReaction[reaction.key] ??= []).add(signal);
      labels[reaction.key] = reaction.label;
    }
    for (final entry in byReaction.entries) {
      final distinctScenes = entry.value
          .map((signal) => _meaningfulSignalLabel(signal.scene))
          .whereType<String>()
          .toSet();
      final dates = entry.value
          .map((signal) => signal.localDateKey())
          .where((date) => date.isNotEmpty)
          .toSet();
      if (distinctScenes.length < 2 || dates.length < 2) continue;
      for (final signal in entry.value) {
        _addPatternSignal(
          buckets,
          key: 'context_difference:${entry.key}',
          label: _copy(
            en: '“${labels[entry.key]}” appeared in records from different settings',
            zhHans: '“${labels[entry.key]}”出现在不同场景的记录中',
            zhHant: '「${labels[entry.key]}」出現在不同情境的記錄中',
            ja: '「${labels[entry.key]}」が異なる場面の記録に現れた',
          ),
          kind: 'context_difference',
          signal: signal,
        );
      }
    }
  }

  /// Uses only strict timestamps within a local date. The same ordered pair
  /// must be recorded on at least two dates before it can be shown.
  void _addRepeatedSequencePatterns(
    List<RecentSignalModel> signals,
    Map<String, _PatternBucket> buckets,
  ) {
    final byDate = <String, List<RecentSignalModel>>{};
    for (final signal in signals) {
      final date = signal.localDateKey();
      if (date.isEmpty || signal.createdAt == null) continue;
      (byDate[date] ??= []).add(signal);
    }

    for (final daySignals in byDate.values) {
      final ordered = [...daySignals]
        ..sort((a, b) => a.createdAt!.compareTo(b.createdAt!));
      for (var index = 0; index + 1 < ordered.length; index += 1) {
        final first = ordered[index];
        final second = ordered[index + 1];
        if (!first.createdAt!.isBefore(second.createdAt!)) continue;
        final firstLabel = _sequenceMarker(first);
        final secondLabel = _sequenceMarker(second);
        if (firstLabel == null ||
            secondLabel == null ||
            firstLabel == secondLabel) {
          continue;
        }
        final key = 'sequence:$firstLabel>$secondLabel';
        final label = _copy(
          en: 'The sequence “$firstLabel” followed by “$secondLabel” repeated across dates',
          zhHans: '记录中“$firstLabel”后出现“$secondLabel”的顺序跨日期重复出现',
          zhHant: '記錄中「$firstLabel」後出現「$secondLabel」的順序跨日期重複出現',
          ja: '記録で「$firstLabel」の後に「$secondLabel」が現れる順序が別の日にも繰り返された',
        );
        _addPatternSignal(
          buckets,
          key: key,
          label: label,
          kind: 'sequence',
          signal: first,
        );
        _addPatternSignal(
          buckets,
          key: key,
          label: label,
          kind: 'sequence',
          signal: second,
        );
      }
    }
  }

  /// A tradeoff is shown only when the same named scene has both an explicit
  /// draining record and an ease/recovery record on different dates.
  void _addTradeoffPatterns(
    List<RecentSignalModel> signals,
    Map<String, _PatternBucket> buckets,
  ) {
    final byScene = <String, List<RecentSignalModel>>{};
    for (final signal in signals) {
      final scene = _meaningfulSignalLabel(signal.scene);
      if (scene != null) (byScene[scene] ??= []).add(signal);
    }
    for (final entry in byScene.entries) {
      final draining = entry.value
          .where((signal) =>
              _energyClassifier.classifySignal(signal).storageValue ==
              'draining')
          .toList(growable: false);
      final easeOrRecovery = entry.value.where((signal) {
        final state = _energyClassifier.classifySignal(signal).storageValue;
        return state == 'ease' || state == 'recovery';
      }).toList(growable: false);
      final hasCrossDateSupport = draining.any((drainingSignal) {
        final drainingDate = drainingSignal.localDateKey();
        return drainingDate.isNotEmpty &&
            easeOrRecovery.any(
              (positiveSignal) =>
                  positiveSignal.localDateKey().isNotEmpty &&
                  positiveSignal.localDateKey() != drainingDate,
            );
      });
      if (!hasCrossDateSupport) continue;

      final key = 'tradeoff:${entry.key}';
      final label = _copy(
        en: '“${entry.key}” had both draining and easier or restorative records on different dates',
        zhHans: '“${entry.key}”在不同日期既有偏耗力，也有有余力或恢复的记录',
        zhHant: '「${entry.key}」在不同日期既有偏耗力，也有有餘力或恢復的記錄',
        ja: '「${entry.key}」には、日によって消耗した記録と余力や回復の記録の両方があった',
      );
      for (final signal in [...draining, ...easeOrRecovery]) {
        _addPatternSignal(
          buckets,
          key: key,
          label: label,
          kind: 'tradeoff',
          signal: signal,
        );
      }
    }
  }

  void _addPatternSignal(
    Map<String, _PatternBucket> buckets, {
    required String key,
    required String label,
    required String kind,
    required RecentSignalModel signal,
  }) {
    final bucket = buckets.putIfAbsent(
      key,
      () => _PatternBucket(label: label, kind: kind),
    );
    final id = (signal.signalCardId ?? signal.id ?? '').trim();
    final date = signal.localDateKey();
    if (id.isNotEmpty) bucket.signalIds.add(id);
    if (date.isNotEmpty) bucket.dates.add(date);
  }

  ({String key, String label})? _reactionMarker(RecentSignalModel signal) {
    final friction = _meaningfulSignalLabel(signal.friction);
    if (friction != null) return (key: 'friction:$friction', label: friction);
    final emotion = _meaningfulSignalLabel(signal.emotion);
    if (emotion != null) return (key: 'emotion:$emotion', label: emotion);
    return null;
  }

  String? _sequenceMarker(RecentSignalModel signal) {
    final scene = _meaningfulSignalLabel(signal.scene);
    final reaction = _reactionMarker(signal)?.label;
    if (scene != null && reaction != null) return '$scene／$reaction';
    return reaction ?? scene;
  }

  int _behaviorPatternPriority(String kind) => switch (kind) {
        'tradeoff' => 0,
        'context_difference' => 1,
        'sequence' => 2,
        'context_response' => 3,
        'response' => 4,
        'context' => 5,
        _ => 6,
      };

  WeeklyEnergyProjectionModel _buildEnergyProjection({
    required _WeekRange range,
    required List<RecentSignalModel> signals,
    required List<FeedbackEventModel> feedbackEvents,
  }) {
    const states = [
      'draining',
      'steady',
      'ease',
      'recovery',
      'boundary_buffer'
    ];
    final byDate = <String, List<RecentSignalModel>>{};
    for (final signal in signals) {
      final date = signal.localDateKey();
      if (date.isNotEmpty) (byDate[date] ??= []).add(signal);
    }
    final feedbackByDate = <String, int>{};
    for (final feedback in feedbackEvents) {
      feedbackByDate[feedback.localDate] =
          (feedbackByDate[feedback.localDate] ?? 0) + 1;
    }
    final totals = {for (final state in states) state: 0};
    final days = <WeeklyEnergyDayModel>[];
    for (var offset = 0; offset < 7; offset++) {
      final date = range.start.add(Duration(days: offset));
      final key = _dateKey(date);
      final counts = {for (final state in states) state: 0};
      for (final signal in byDate[key] ?? const <RecentSignalModel>[]) {
        final state = _energyClassifier.classifySignal(signal).storageValue;
        counts[state] = (counts[state] ?? 0) + 1;
        totals[state] = (totals[state] ?? 0) + 1;
      }
      final signalCount = byDate[key]?.length ?? 0;
      // Empty dates are chart placeholders, not an inferred draining state.
      // Only classify a dominant state when the date has actual Signal input.
      final dominant = signalCount == 0
          ? 'steady'
          : states.reduce((best, candidate) =>
              (counts[candidate] ?? 0) > (counts[best] ?? 0)
                  ? candidate
                  : best);
      days.add(WeeklyEnergyDayModel(
        date: key,
        signalCount: signalCount,
        feedbackCount: feedbackByDate[key] ?? 0,
        stateCounts: counts,
        dominantState: dominant,
      ));
    }
    final draining = totals['draining'] ?? 0;
    final recovery = totals['recovery'] ?? 0;
    final ease = totals['ease'] ?? 0;
    final helpfulFeedbacks = feedbackEvents
        .where((event) =>
            _isHelpfulFeedbackText(event.status) ||
            _isHelpfulFeedbackText(event.effect))
        .length;
    final recommendation = draining > recovery + ease
        ? 'reduce_load'
        : recovery + ease >= draining + 2 && helpfulFeedbacks > 0
            ? 'cautiously_increase'
            : 'maintain_load';
    final rationale = switch (recommendation) {
      'reduce_load' => _copy(
          en: 'More Signals felt draining this week, so next week’s candidates will prioritize lower-load options.',
          zhHans: '本周偏耗力的 Signal 较多，下周候选会优先排低负荷内容。',
          zhHant: '本週偏耗力的 Signal 較多，下週候選會優先安排低負荷內容。',
          ja: '今週は消耗寄りの Signal が多かったため、来週の候補では負担の小さい内容を優先します。'),
      'cautiously_increase' => _copy(
          en: 'Easier or restorative Signals and positive feedback were more common this week, so next week can include a small increase.',
          zhHans: '本周轻松或恢复的 Signal 与正向反馈较多，下周可以小幅增加尝试。',
          zhHant: '本週輕鬆或恢復的 Signal 與正向回饋較多，下週可以小幅增加嘗試。',
          ja: '今週は余力や回復の Signal、前向きなフィードバックが多かったため、来週は試す量を少しだけ増やせます。'),
      _ => _copy(
          en: 'The five energy states were relatively balanced this week, so keep the current load next week.',
          zhHans: '本周五类状态较为接近，下周先维持当前负荷。',
          zhHant: '本週五類狀態較為接近，下週先維持當前負荷。',
          ja: '今週は5つのエネルギー状態が比較的近かったため、来週も現在の負荷を維持します。'),
    };
    return WeeklyEnergyProjectionModel(
      days: days,
      totals: totals,
      recommendation: recommendation,
      rationale: rationale,
    );
  }

  late final EnergyBudgetRepository _energyClassifier = EnergyBudgetRepository(
    localCaptureRepository: localCaptureRepository,
    localLifeExperimentRepository: localLifeExperimentRepository,
    localUserId: localUserId,
    eligibilityService: eligibilityService,
    nowLoader: nowLoader,
  );

  String? _meaningfulSignalLabel(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    const placeholders = {
      'unknown',
      'other',
      'none',
      '未分类',
      '不确定',
      'unknown_scene'
    };
    return placeholders.contains(value.toLowerCase()) ? null : value;
  }

  String _stableWeeklyId(String input) {
    var hash = 2166136261;
    for (final code in input.codeUnits) {
      hash ^= code;
      hash = (hash * 16777619) & 0x7fffffff;
    }
    return 'weekly_pattern_${hash.toRadixString(16)}';
  }

  Map<String, int> _buildInclusionSummary({
    required List<RecentSignalModel> weekRangeSignals,
    required List<RecentSignalModel> eligibleSignals,
  }) {
    final eligibleIds = eligibleSignals
        .map((signal) => signal.signalCardId ?? signal.id ?? '')
        .where((id) => id.trim().isNotEmpty)
        .toSet();
    final excludedCount = weekRangeSignals.where((signal) {
      final id = signal.signalCardId ?? signal.id ?? '';
      return !eligibleIds.contains(id);
    }).length;
    final legacyReferenceCount =
        eligibleSignals.where((signal) => signal.isLegacy).length;

    return {
      'used_count': eligibleSignals.length,
      'timeline_only_count': weekRangeSignals.length - eligibleSignals.length,
      'excluded_count': excludedCount,
      'legacy_reference_count': legacyReferenceCount,
    };
  }

  _WeeklyStats _buildWeeklyStats(List<RecentSignalModel> signals) {
    final entries = <Map<String, dynamic>>[];
    final dayCounts = <String, int>{};
    final tokenCounts = <String, int>{};
    final chartDataMap = <String, _ChartAccumulator>{};

    for (final signal in signals) {
      final dayKey = signal.localDateKey();
      if (dayKey.isEmpty) continue;
      final createdAt = signal.createdAt?.toLocal();
      dayCounts[dayKey] = (dayCounts[dayKey] ?? 0) + 1;

      entries.add({
        'id': signal.id,
        'signal_card_id': signal.signalCardId,
        'source_type': signal.sourceType,
        'content': _analysisContent(signal),
        'created_at': createdAt?.toUtc().toIso8601String(),
        'local_date': dayKey,
        'timezone': signal.timezone,
        'acknowledgement': signal.acknowledgement,
        'observation': signal.observation,
        'try_next': signal.tryNext,
        'emotion': signal.emotion,
        'intensity': signal.intensity,
        'scene': signal.scene,
        'friction': signal.friction,
        'positive_signal': signal.positiveSignal,
        'energy_load': signal.energyLoad,
        'focus_domain_id': signal.rawPayloadJson['focus_domain_id'],
        'scene_tags': signal.sceneTags,
        'intent_tags': signal.intentTags,
        'user_confirmation': signal.userConfirmation,
        'is_legacy': signal.isLegacy,
        'weekly_confidence': _weeklyEvidenceLevel(signal),
      });

      for (final token in _tokenize(_analysisContent(signal))) {
        tokenCounts[token] = (tokenCounts[token] ?? 0) + 1;
      }

      final bucket =
          chartDataMap.putIfAbsent(dayKey, () => _ChartAccumulator());
      bucket.signalCount += 1;
      bucket.moodScore += _emotionToMoodScore(signal.emotion);
      bucket.frictionScore += _emotionToFrictionScore(signal.emotion);
      if ((signal.emotion ?? '') == 'positive' ||
          (signal.emotion ?? '') == 'mixed') {
        bucket.hasPositiveSignal = true;
      }
    }

    final sortedTokens = tokenCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final chartData = chartDataMap.entries.map((entry) {
      final bucket = entry.value;
      final count = bucket.signalCount == 0 ? 1 : bucket.signalCount;
      return WeeklyChartPointModel(
        date: entry.key,
        signalCount: bucket.signalCount,
        moodScore: double.parse((bucket.moodScore / count).toStringAsFixed(3)),
        frictionScore:
            double.parse((bucket.frictionScore / count).toStringAsFixed(3)),
        hasPositiveSignal: bucket.hasPositiveSignal,
      );
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return _WeeklyStats(
      entries: entries,
      dayCounts: dayCounts,
      topTokens: sortedTokens.take(8).map((e) => e.key).toList(),
      chartData: chartData,
    );
  }

  String _analysisContent(RecentSignalModel signal) {
    if (!signal.isLibrarySaved) return signal.content;
    return [
      signal.libraryPatternTitle,
      signal.libraryAbstractPattern,
      signal.userCorrectionJson['edited_text']?.toString(),
      signal.userCorrectionJson['supplement_text']?.toString(),
    ]
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .join(' ');
  }

  String _weeklyEvidenceLevel(RecentSignalModel signal) {
    if (signal.isLegacy) return 'legacy_reference';
    if (signal.isLibrarySaved) return 'library_saved_confirmed';
    if (signal.userConfirmation == 'unconfirmed') return 'light_observation';
    return 'standard';
  }

  List<String> _tokenize(String content) {
    final normalized = content
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
        .trim();

    if (normalized.isEmpty) return const [];

    final rawParts = normalized.split(RegExp(r'\s+'));
    const stopWords = {
      'the',
      'and',
      'for',
      'that',
      'this',
      'with',
      'have',
      'just',
      'today',
      'then',
      '又',
      '还是',
      '今天',
      '就是',
      '一个',
      '有点',
      '然后',
      'して',
      'いる',
      'こと',
      'もの',
      'これ',
      'それ',
      'ただ',
    };

    return rawParts
        .where((e) => e.trim().isNotEmpty)
        .where((e) => e.runes.length >= 2)
        .where((e) => !stopWords.contains(e))
        .toList();
  }

  bool _isLightWeekly(
    _WeeklyStats stats, {
    required int activeAppDays,
  }) {
    final signalCount = stats.entries.length;
    final activeDays = stats.dayCounts.keys.length;
    return signalCount > 0 &&
        (activeAppDays < 7 || signalCount < 4 || activeDays < 2);
  }

  WeeklyInsightModel _normalizeGeneratedWeekly({
    required WeeklyInsightModel generated,
    required _WeeklyStats stats,
    required bool isLightWeekly,
    required Map<String, int> inclusionSummary,
  }) {
    if (!isLightWeekly) {
      return WeeklyInsightModel(
        weekStart: generated.weekStart,
        weekEnd: generated.weekEnd,
        status: 'ready',
        keyInsight: generated.keyInsight,
        patterns: _oneItem(
          generated.patterns,
          fallbackName: _copy(
            en: 'The clearest draining pattern this week',
            zhHans: '本周最消耗的一个模式',
            zhHant: '本週最消耗的一個模式',
            ja: '今週もっとも消耗が目立ったパターン',
          ),
          fallbackSummary: _copy(
            en: 'For now, focus on the clearest recurring direction and leave the rest in the observation area.',
            zhHans: '这周先只看一个最明显的重复方向，其他内容先放在观察区。',
            zhHant: '這週先只看一個最明顯的重複方向，其他內容先放在觀察區。',
            ja: 'まずは最も明確に繰り返している方向だけを見て、その他は観察のまま残します。',
          ),
        ),
        frictions: _oneItem(
          generated.frictions,
          fallbackName: _copy(
            en: 'A drain to notice this week',
            zhHans: '本周先留意的消耗点',
            zhHant: '本週先留意的消耗點',
            ja: '今週まず注意したい消耗',
          ),
          fallbackSummary: _copy(
            en: 'It does not mean you did anything wrong; it is simply the area most worth a small adjustment this week.',
            zhHans: '它不代表你哪里做错了，只是这周比较值得少量调整的地方。',
            zhHant: '它不代表你哪裡做錯了，只是這週比較值得少量調整的地方。',
            ja: 'あなたが何かを間違えたという意味ではなく、今週少しだけ調整する価値がある箇所です。',
          ),
        ),
        bestAction: _softExperimentText(generated.bestAction),
        opportunitySnapshot: _withWeeklyMetadata(
          generated.opportunitySnapshot,
          inclusionSummary: inclusionSummary,
        ),
        feedbackSubmitted: generated.feedbackSubmitted,
        chartData: stats.chartData,
      );
    }

    return WeeklyInsightModel(
      weekStart: generated.weekStart,
      weekEnd: generated.weekEnd,
      status: 'light_ready',
      keyInsight: _lightenKeyInsight(
        generated.keyInsight,
        topToken: stats.topTokens.isEmpty ? null : stats.topTokens.first,
      ),
      patterns: _oneItem(
        _lightenItems(
          generated.patterns,
          fallbackName: _copy(
            en: 'An emerging Signal this week',
            zhHans: '这周先冒头的线索',
            zhHant: '這週剛冒頭的線索',
            ja: '今週見え始めた Signal',
          ),
        ),
        fallbackName: _copy(
          en: 'An emerging Signal this week',
          zhHans: '这周先冒头的线索',
          zhHant: '這週剛冒頭的線索',
          ja: '今週見え始めた Signal',
        ),
        fallbackSummary: _copy(
          en: 'There are not many records yet, but one direction is beginning to repeat.',
          zhHans: '记录还不多，但已经能看见一个开始重复的方向。',
          zhHant: '記錄還不多，但已經能看見一個開始重複的方向。',
          ja: '記録はまだ多くありませんが、繰り返し始めた方向が一つ見えています。',
        ),
      ),
      frictions: _oneItem(
        _lightenItems(
          generated.frictions,
          fallbackName: _copy(
            en: 'A possible drain this week',
            zhHans: '这周先看到的消耗点',
            zhHant: '這週先看到的消耗點',
            ja: '今週見え始めた消耗',
          ),
        ),
        fallbackName: _copy(
          en: 'A possible drain this week',
          zhHans: '这周先看到的消耗点',
          zhHant: '這週先看到的消耗點',
          ja: '今週見え始めた消耗',
        ),
        fallbackSummary: _copy(
          en: 'For now, it is better to observe gently rather than draw a strong conclusion.',
          zhHans: '现在更适合先轻轻看着，还不急着下太重的判断。',
          zhHant: '現在更適合先輕輕觀察，還不急著下太重的判斷。',
          ja: '今は強い結論を出さず、軽く見守る段階です。',
        ),
      ),
      bestAction: _softExperimentText(generated.bestAction),
      opportunitySnapshot: _withWeeklyMetadata(
        generated.opportunitySnapshot ??
            {
              'name': _copy(
                en: 'Keep the Signal',
                zhHans: '先把线索留住',
                zhHant: '先把線索留住',
                ja: 'Signal を残す',
              ),
              'summary': _copy(
                en: 'Keep collecting Signals for now. When the outline is clearer, you can decide whether it is worth organizing further.',
                zhHans: '现在更适合先继续收集线索，等轮廓再清楚一点，再判断值不值得进一步整理。',
                zhHant: '現在更適合先繼續收集線索，等輪廓再清楚一點，再判斷是否值得進一步整理。',
                ja: '今は Signal を集め続けましょう。輪郭がもう少し明確になったら、さらに整理する価値があるか判断できます。',
              ),
            },
        inclusionSummary: inclusionSummary,
      ),
      feedbackSubmitted: generated.feedbackSubmitted,
      chartData: stats.chartData,
    );
  }

  bool _generatedWeeklyMatchesLanguage(WeeklyInsightModel weekly) {
    final language = RuntimeLocaleText.normalize(
      aiRepository.languageLoader(),
    );
    if (language != 'en' && language != 'ja') return true;
    final prose = <String>[
      weekly.keyInsight ?? '',
      weekly.bestAction ?? '',
      ...weekly.patterns.expand(_generatedWeeklyProseParts),
      ...weekly.frictions.expand(_generatedWeeklyProseParts),
      ..._generatedWeeklyProseParts(weekly.opportunitySnapshot),
    ].where((value) => value.trim().isNotEmpty).toList(growable: false);
    final text = <String>[
      ...prose,
      ...weekly.patterns.expand(_generatedWeeklyTextParts),
      ...weekly.frictions.expand(_generatedWeeklyTextParts),
      ..._generatedWeeklyTextParts(weekly.opportunitySnapshot),
    ].join(' ');
    final hasHan = RegExp(r'[\u3400-\u9fff]').hasMatch(text);
    final hasKana = RegExp(r'[\u3040-\u30ff]').hasMatch(text);
    if (language == 'en') {
      return !hasHan && !hasKana && RegExp(r'[A-Za-z]').hasMatch(text);
    }
    final hasChineseOnlyForms = RegExp(
      r'[这们么还没为个录复续觉验這們麼還沒]',
    ).hasMatch(text);
    final generatedNames = <String>[
      ...weekly.patterns.expand(_generatedWeeklyNameParts),
      ...weekly.frictions.expand(_generatedWeeklyNameParts),
      ..._generatedWeeklyNameParts(weekly.opportunitySnapshot),
    ].where((value) => value.trim().isNotEmpty).toList(growable: false);
    return !hasChineseOnlyForms &&
        prose.isNotEmpty &&
        prose.every((value) => RegExp(r'[\u3040-\u30ff]').hasMatch(value)) &&
        generatedNames
            .every((value) => RegExp(r'[\u3040-\u30ff]').hasMatch(value));
  }

  Iterable<String> _generatedWeeklyTextParts(Object? value) sync* {
    if (value is Map) {
      for (final key in const ['name', 'title', 'summary', 'description']) {
        final text = value[key]?.toString().trim();
        if (text != null && text.isNotEmpty) yield text;
      }
    }
  }

  Iterable<String> _generatedWeeklyProseParts(Object? value) sync* {
    if (value is Map) {
      for (final key in const ['summary', 'description']) {
        final text = value[key]?.toString().trim();
        if (text != null && text.isNotEmpty) yield text;
      }
    }
  }

  Iterable<String> _generatedWeeklyNameParts(Object? value) sync* {
    if (value is Map) {
      for (final key in const ['name', 'title']) {
        final text = value[key]?.toString().trim();
        if (text != null && text.isNotEmpty) yield text;
      }
    }
  }

  Future<String?> _readFocusArea() async {
    if (focusAreaLoader != null) {
      return focusAreaLoader!();
    }

    final prefs = await SharedPreferences.getInstance();
    final focusDomainIds = FocusDomains.normalizeIds(
      prefs.getStringList(FocusDomains.productPreferenceKey) ??
          prefs.getStringList(FocusDomains.preferenceKey) ??
          const [],
    );
    if (focusDomainIds.isNotEmpty) {
      return focusDomainIds.join(',');
    }
    return prefs.getString('repeat_area_preference') ??
        prefs.getString('selected_repeat_area');
  }

  Future<DateTime> _readOrCreateInstallationDate() async {
    if (installationDateLoader != null) {
      return _dateOnly(await installationDateLoader!());
    }

    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString('local_app_started_date');
    if (existing != null && existing.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(existing);
      if (parsed != null) {
        return _dateOnly(parsed);
      }
    }

    final today = _dateOnly(nowLoader());
    await prefs.setString('local_app_started_date', today.toIso8601String());
    return today;
  }

  _WeekRange _currentWeekRange() {
    final now = nowLoader();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(
      Duration(days: today.weekday - DateTime.monday),
    );
    final end = start.add(const Duration(days: 6));
    return _WeekRange(start: start, end: end);
  }

  DateTime _dateOnly(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  bool _sameDay(DateTime a, DateTime b) {
    final aa = _dateOnly(a);
    final bb = _dateOnly(b);
    return aa.year == bb.year && aa.month == bb.month && aa.day == bb.day;
  }

  String _dateKey(DateTime date) {
    final local = date.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd';
  }

  WeeklyInsightModel _buildFallbackWeeklyInsight({
    required String weekStart,
    required String weekEnd,
    required _WeeklyStats stats,
    required bool isLightWeekly,
    required Map<String, int> inclusionSummary,
  }) {
    final topToken = stats.topTokens.isEmpty
        ? _copy(
            en: 'this week’s records',
            zhHans: '本周记录',
            zhHant: '本週記錄',
            ja: '今週の記録',
          )
        : stats.topTokens.first;
    final peakDay = _resolvePeakDay(stats.dayCounts);
    final patternHint = _deriveWeeklyIllustrationHint(topToken);
    final frictionHint = _deriveWeeklyIllustrationHint(
      '$topToken $peakDay 消耗 负担',
      fallback: _copy(
        en: 'Tasks accumulated and became harder to start',
        zhHans: '任务堆积，开始变困难',
        zhHant: '任務堆積，開始變得困難',
        ja: 'タスクが重なり、始めにくくなった',
      ),
    );

    if (isLightWeekly) {
      return WeeklyInsightModel(
        weekStart: weekStart,
        weekEnd: weekEnd,
        status: 'light_ready',
        keyInsight: _copy(
          en: 'One Signal is starting to stand out this week: “$topToken”.',
          zhHans: '这周可以先轻轻看一个 Signal：目前最明显的是“$topToken”。',
          zhHant: '這週可以先輕輕看一個 Signal：目前最明顯的是「$topToken」。',
          ja: '今週はまず一つの Signal を見てみましょう。今もっとも目立つのは「$topToken」です。',
        ),
        patterns: [
          {
            'name': _copy(
                en: 'An emerging Signal',
                zhHans: '这周先冒头的 Signal',
                zhHant: '這週剛出現的 Signal',
                ja: '今週見え始めた Signal'),
            'summary': _copy(
                en: 'There are not many records yet, but one direction is beginning to repeat.',
                zhHans: '记录还不多，但已经能看见一个开始重复的方向。',
                zhHant: '記錄還不多，但已經能看見一個開始重複的方向。',
                ja: '記録はまだ多くありませんが、繰り返し始めた方向が見えています。'),
            'illustration_hint': patternHint,
          },
        ],
        frictions: [
          {
            'name': _copy(
                en: 'A possible drain',
                zhHans: '这周先看到的消耗点',
                zhHant: '這週先看到的消耗點',
                ja: '今週見え始めた消耗'),
            'summary': _copy(
                en: 'For now, it is better to observe gently rather than draw a strong conclusion.',
                zhHans: '现在更适合先轻轻看着，还不急着下太重的判断。',
                zhHant: '現在更適合先輕輕觀察，還不急著下太重的判斷。',
                ja: '今は強い結論を出さず、軽く見守る段階です。'),
            'illustration_hint': frictionHint,
          },
        ],
        bestAction: _copy(
            en: 'Next week, try one small step: when a similar situation returns, add one line about where it happened.',
            zhHans: '下周先试一个很小的方向：同类场景再出现时，只补一句它发生在哪里。',
            zhHant: '下週先試一個很小的方向：同類情境再次出現時，只補一句它發生在哪裡。',
            ja: '来週は小さく試してみましょう。同じ場面が起きたら、どこで起きたかを一言足します。'),
        opportunitySnapshot: _withWeeklyMetadata(
          {
            'name': _copy(
                en: 'Keep the Signal',
                zhHans: '先把 Signal 留住',
                zhHant: '先把 Signal 留住',
                ja: 'Signal を残す'),
            'summary': _copy(
                en: 'Notice which moments restore you a little; they may become useful Signals next week.',
                zhHans: '也可以留意一下哪些时刻让你稍微恢复一点，它们可能是下周的小 Signal。',
                zhHant: '也可以留意哪些時刻讓你稍微恢復一點，它們可能是下週的小 Signal。',
                ja: '少し回復できた瞬間にも目を向けると、来週の Signal になるかもしれません。'),
            'illustration_hint': _copy(
                en: 'Observation itself can help',
                zhHans: '只是观察也有帮助',
                zhHant: '只是觀察也有幫助',
                ja: '観察するだけでも役立つ'),
          },
          inclusionSummary: inclusionSummary,
        ),
        feedbackSubmitted: false,
        chartData: stats.chartData,
      );
    }

    return WeeklyInsightModel(
      weekStart: weekStart,
      weekEnd: weekEnd,
      status: 'ready',
      keyInsight: _copy(
          en: 'A recurring drain around “$topToken” stands out this week; Signals were denser on $peakDay.',
          zhHans: '这周最值得先看的，是围绕“$topToken”反复出现的一个消耗模式；$peakDay 的 Signal 更密集。',
          zhHant: '這週最值得先看的，是圍繞「$topToken」反覆出現的消耗模式；$peakDay 的 Signal 更密集。',
          ja: '今週は「$topToken」をめぐる消耗の繰り返しが目立ち、$peakDay に Signal が集中しました。'),
      patterns: [
        {
          'name': _copy(
              en: 'Recurring pattern around “$topToken”',
              zhHans: '围绕“$topToken”的行为模式',
              zhHant: '圍繞「$topToken」的行為模式',
              ja: '「$topToken」をめぐる行動パターン'),
          'summary': _copy(
              en: 'This is the clearest direction this week; other Signals can remain on the timeline.',
              zhHans: '这周先只看这个最明显的方向，其他 Signal 可以继续留在时间线里。',
              zhHant: '這週先看這個最明顯的方向，其他 Signal 可以繼續留在時間線裡。',
              ja: '今週はこの最も明確な方向を見て、ほかの Signal はタイムラインに残しておけます。'),
          'illustration_hint': patternHint,
        },
      ],
      frictions: [
        {
          'name': _copy(
              en: 'Main drain this week',
              zhHans: '本周的主要消耗',
              zhHant: '本週的主要消耗',
              ja: '今週の主な消耗'),
          'summary': _copy(
              en: 'The main burden looks more like similar events returning than one isolated event.',
              zhHans: '当前最大的负担，更像是同类事情反复回来，而不是单次事件。',
              zhHant: '目前最大的負擔，更像是同類事情反覆出現，而不是單次事件。',
              ja: '大きな負担は、一度きりの出来事より、似たことが繰り返し戻ってくる形に見えます。'),
          'illustration_hint': frictionHint,
        },
      ],
      bestAction: _copy(
          en: 'Next week, try a small experiment: when a similar situation appears, note the setting in one line.',
          zhHans: '下周先试一个小实验：同类情况出现时，用一句话补记它发生在什么场景。',
          zhHant: '下週先試一個小實驗：同類情況出現時，用一句話補記它發生在哪個情境。',
          ja: '来週は小さな実験を一つ。似た状況が起きたら、どんな場面だったかを一言残します。'),
      opportunitySnapshot: _withWeeklyMetadata(
        {
          'name': _copy(
              en: 'Keep the recurring Signal',
              zhHans: '把重复 Signal 留下来',
              zhHant: '把重複 Signal 留下來',
              ja: '繰り返す Signal を残す'),
          'summary': _copy(
              en: 'Also notice moments that restore you a little; they may be recovery Signals.',
              zhHans: '也留意一下哪些时刻让状态稍微往回收一点，它们可能是恢复 Signal。',
              zhHant: '也留意哪些時刻讓狀態稍微恢復，它們可能是恢復 Signal。',
              ja: '少し状態が戻る瞬間にも注目すると、回復の Signal になるかもしれません。'),
          'illustration_hint': _copy(
              en: 'Observation itself can help',
              zhHans: '只是观察也有帮助',
              zhHant: '只是觀察也有幫助',
              ja: '観察するだけでも役立つ'),
        },
        inclusionSummary: inclusionSummary,
      ),
      feedbackSubmitted: false,
      chartData: stats.chartData,
    );
  }

  String _lightenKeyInsight(String? input, {String? topToken}) {
    if (input != null && input.trim().isNotEmpty) {
      return input;
    }
    if (topToken != null && topToken.trim().isNotEmpty) {
      return _copy(
          en: 'One Signal is starting to stand out this week: “$topToken”.',
          zhHans: '这周可以先轻轻看一个 Signal：目前最明显的是“$topToken”。',
          zhHant: '這週可以先輕輕看一個 Signal：目前最明顯的是「$topToken」。',
          ja: '今週はまず一つの Signal を見てみましょう。今もっとも目立つのは「$topToken」です。');
    }
    return _copy(
        en: 'Signals are beginning to emerge this week; for now, gentle observation is enough.',
        zhHans: '这周已经开始有 Signal 冒出来了，不过现在更适合先轻轻看着。',
        zhHant: '這週已經開始有 Signal 出現，不過現在更適合先輕輕觀察。',
        ja: '今週は Signal が見え始めました。今はまだ軽く見守るだけで十分です。');
  }

  List<dynamic> _lightenItems(
    List<dynamic> items, {
    required String fallbackName,
  }) {
    if (items.isEmpty) {
      return [
        {
          'name': fallbackName,
          'summary': _copy(
              en: 'There are not many records yet, but one direction is beginning to repeat.',
              zhHans: '记录还不多，但已经能看见一个开始重复的方向。',
              zhHant: '記錄還不多，但已經能看見一個開始重複的方向。',
              ja: '記録はまだ多くありませんが、繰り返し始めた方向が見えています。'),
          'illustration_hint': _deriveWeeklyIllustrationHint(fallbackName),
        },
      ];
    }

    return items.take(2).map((item) {
      if (item is Map<String, dynamic>) {
        final name = (item['name'] as String?) ?? fallbackName;
        final summary = (item['summary'] as String?) ??
            _copy(
                en: 'A Signal has appeared, but it is too early for a strong conclusion.',
                zhHans: 'Signal 已经出现了，但还不适合下太重的判断。',
                zhHant: 'Signal 已經出現，但還不適合下太重的判斷。',
                ja: 'Signal は現れていますが、強い結論を出すにはまだ早い段階です。');
        return {
          ...item,
          'name': name,
          'summary': summary,
          'illustration_hint': _textFromDynamic(
                item['illustration_hint'] ??
                    item['illustrationHint'] ??
                    item['visual_hint'] ??
                    item['visualHint'],
              ) ??
              _deriveWeeklyIllustrationHint('$name $summary'),
        };
      }
      if (item is Map) {
        final normalized = item.map((key, value) => MapEntry('$key', value));
        final name = item['name']?.toString() ?? fallbackName;
        final summary = item['summary']?.toString() ??
            _copy(
              en: 'A Signal has appeared, but it is too early for a strong conclusion.',
              zhHans: 'Signal 已经出现了，但还不适合下太重的判断。',
              zhHant: 'Signal 已經出現，但還不適合下太重的判斷。',
              ja: 'Signal は現れていますが、強い結論を出すにはまだ早い段階です。',
            );
        return {
          ...normalized,
          'name': name,
          'summary': summary,
          'illustration_hint': _textFromDynamic(
                normalized['illustration_hint'] ??
                    normalized['illustrationHint'] ??
                    normalized['visual_hint'] ??
                    normalized['visualHint'],
              ) ??
              _deriveWeeklyIllustrationHint('$name $summary'),
        };
      }
      return {
        'name': fallbackName,
        'summary': _copy(
          en: 'A Signal has appeared, but it is too early for a strong conclusion.',
          zhHans: 'Signal 已经出现了，但还不适合下太重的判断。',
          zhHant: 'Signal 已經出現，但還不適合下太重的判斷。',
          ja: 'Signal は現れていますが、強い結論を出すにはまだ早い段階です。',
        ),
        'illustration_hint': _deriveWeeklyIllustrationHint(fallbackName),
      };
    }).toList();
  }

  String _copy({
    required String en,
    required String zhHans,
    required String zhHant,
    required String ja,
  }) =>
      RuntimeLocaleText.tr(
        language: aiRepository.languageLoader(),
        en: en,
        zhHans: zhHans,
        zhHant: zhHant,
        ja: ja,
      );

  List<dynamic> _oneItem(
    List<dynamic> items, {
    required String fallbackName,
    required String fallbackSummary,
  }) {
    if (items.isEmpty) {
      return [
        {
          'name': fallbackName,
          'summary': fallbackSummary,
          'illustration_hint':
              _deriveWeeklyIllustrationHint('$fallbackName $fallbackSummary'),
        },
      ];
    }

    final item = items.first;
    if (item is Map<String, dynamic>) {
      final name = (item['name'] as String?) ?? fallbackName;
      final summary = (item['summary'] as String?) ?? fallbackSummary;
      return [
        {
          ...item,
          'name': name,
          'summary': summary,
          'illustration_hint': _textFromDynamic(
                item['illustration_hint'] ??
                    item['illustrationHint'] ??
                    item['visual_hint'] ??
                    item['visualHint'],
              ) ??
              _deriveWeeklyIllustrationHint('$name $summary'),
        },
      ];
    }
    if (item is Map) {
      final normalized = item.map((key, value) => MapEntry('$key', value));
      final name = item['name']?.toString() ?? fallbackName;
      final summary = item['summary']?.toString() ?? fallbackSummary;
      return [
        {
          ...normalized,
          'name': name,
          'summary': summary,
          'illustration_hint': _textFromDynamic(
                normalized['illustration_hint'] ??
                    normalized['illustrationHint'] ??
                    normalized['visual_hint'] ??
                    normalized['visualHint'],
              ) ??
              _deriveWeeklyIllustrationHint('$name $summary'),
        },
      ];
    }
    return [
      {
        'name': fallbackName,
        'summary': fallbackSummary,
        'illustration_hint':
            _deriveWeeklyIllustrationHint('$fallbackName $fallbackSummary'),
      },
    ];
  }

  String? _textFromDynamic(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  String _deriveWeeklyIllustrationHint(
    String text, {
    String fallback = '只是观察也有帮助',
  }) {
    if (_containsAny(text, const ['任务', '堆', '太多', 'todo'])) {
      return '任务堆积，开始变困难';
    }
    if (_containsAny(text, const ['会议', '开会'])) {
      return '会议密集，注意力被切碎';
    }
    if (_containsAny(text, const ['临时', '变化', '打断'])) {
      return '临时变化打断原本节奏';
    }
    if (_containsAny(text, const ['休息', '恢复', '挤'])) {
      return '休息时间被任务挤掉';
    }
    if (_containsAny(text, const ['空转', '停不下来'])) {
      return '想休息，但停下来后反而空转';
    }
    if (_containsAny(text, const ['手机', '短视频', '刷'])) {
      return '晚上刷手机变多';
    }
    if (_containsAny(text, const ['早上', '启动'])) return '早上启动困难';
    if (_containsAny(text, const ['中午', '午后', '下午', '精力'])) {
      return '中午以后精力明显下降';
    }
    if (_containsAny(text, const ['日程', '安排', '密度'])) {
      return '情绪被日程密度带着走';
    }
    if (_containsAny(text, const ['焦虑', '紧张', '还没开始'])) {
      return '焦虑提前出现，还没开始就紧张';
    }
    if (_containsAny(text, const ['完成', '做完', '更累'])) {
      return '做完事后更累，不是更轻松';
    }
    if (_containsAny(text, const ['计划', '目标', '太大'])) {
      return '计划越大，越容易不开始';
    }
    if (_containsAny(text, const ['分散', '目标太多'])) {
      return '目标太多，注意力分散';
    }
    if (_containsAny(text, const ['创作', '创造', '工作'])) {
      return '创作被工作挤掉';
    }
    if (_containsAny(text, const ['拒绝', '边界', '自己的时间'])) {
      return '不敢拒绝，自己的时间被挤占';
    }
    if (_containsAny(text, const ['迎合', '疲惫'])) {
      return '过度迎合后感到疲惫';
    }
    if (_containsAny(text, const ['表达', '说不清'])) return '想表达，但说不清';
    if (_containsAny(text, const ['独处'])) return '独处不足，恢复变慢';
    if (_containsAny(text, const ['环境', '房间', '混乱'])) {
      return '生活环境混乱，心情也乱';
    }
    if (_containsAny(text, const ['关系', '对话', '内耗'])) {
      return '关系对话后反复内耗';
    }
    if (_containsAny(text, const ['金钱', '钱', '现实压力'])) {
      return '金钱或现实压力牵动安全感';
    }
    if (_containsAny(text, const ['身体', '累'])) return '身体信号先出现，才意识到累';
    if (_containsAny(text, const ['有效', '稳定'])) return '小实验有效，节奏开始稳定';
    if (_containsAny(text, const ['兴趣', '爱好'])) return '兴趣活动带来恢复感';
    return fallback;
  }

  bool _containsAny(String text, List<String> tokens) {
    final lower = text.toLowerCase();
    return tokens.any((token) => lower.contains(token.toLowerCase()));
  }

  String _softExperimentText(String? input) {
    final trimmed = input?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return _copy(
        en: 'Next week, try one small step: when a similar situation returns, add one line about where it happened.',
        zhHans: '下周可以先试一个生活小实验目标：同类场景出现时，只补一句它发生在哪里。',
        zhHant: '下週可以先試一個生活小實驗目標：同類情境出現時，只補一句它發生在哪裡。',
        ja: '来週は小さな一歩を試しましょう。同じような場面が起きたら、どこで起きたかを一言残します。',
      );
    }

    return trimmed
        .replaceAll('必须', '可以试试')
        .replaceAll('应该', '可以先')
        .replaceAll('完成', '试一小步')
        .replaceAll('失败', '没有明显帮助');
  }

  Map<String, dynamic> _withWeeklyMetadata(
    Map<String, dynamic>? source, {
    required Map<String, int> inclusionSummary,
  }) {
    return {
      ...?source,
      '_weekly_inclusion': inclusionSummary,
    };
  }

  String _resolvePeakDay(Map<String, int> dayCounts) {
    if (dayCounts.isEmpty) {
      return _copy(
        en: 'this week',
        zhHans: '这周',
        zhHant: '這週',
        ja: '今週',
      );
    }
    final entries = dayCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.first.key;
  }

  double _emotionToMoodScore(String? emotion) {
    switch (emotion) {
      case 'positive':
        return 1.0;
      case 'mixed':
        return 0.2;
      case 'negative':
        return -1.0;
      default:
        return 0.0;
    }
  }

  double _emotionToFrictionScore(String? emotion) {
    switch (emotion) {
      case 'negative':
        return 1.0;
      case 'mixed':
        return 0.6;
      case 'positive':
        return 0.0;
      default:
        return 0.2;
    }
  }

  List<WeeklyChartPointModel> _buildChartDataForEmptyRange({
    required DateTime start,
    required DateTime end,
  }) {
    final result = <WeeklyChartPointModel>[];
    var cursor = start;
    while (!cursor.isAfter(end)) {
      result.add(
        WeeklyChartPointModel(
          date: _dateKey(cursor),
          signalCount: 0,
          moodScore: 0,
          frictionScore: 0,
          hasPositiveSignal: false,
        ),
      );
      cursor = cursor.add(const Duration(days: 1));
    }
    return result;
  }
}

class _WeeklyStats {
  final List<Map<String, dynamic>> entries;
  final Map<String, int> dayCounts;
  final List<String> topTokens;
  final List<WeeklyChartPointModel> chartData;

  _WeeklyStats({
    required this.entries,
    required this.dayCounts,
    required this.topTokens,
    required this.chartData,
  });
}

class _WeekRange {
  final DateTime start;
  final DateTime end;

  _WeekRange({
    required this.start,
    required this.end,
  });
}

class _ChartAccumulator {
  int signalCount = 0;
  double moodScore = 0;
  double frictionScore = 0;
  bool hasPositiveSignal = false;
}

class _PatternBucket {
  final String label;
  final String kind;
  final Set<String> signalIds = <String>{};
  final Set<String> dates = <String>{};

  _PatternBucket({
    required this.label,
    required this.kind,
  });
}
