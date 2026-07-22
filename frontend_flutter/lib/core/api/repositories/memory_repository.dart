import 'package:shared_preferences/shared_preferences.dart';

import '../../eligibility/signal_eligibility_service.dart';
import '../../local/local_capture_repository.dart';
import '../../local/local_journey_aggregation_repository.dart';
import '../../local/local_journey_snapshot_repository.dart';
import '../../local/local_life_experiment_repository.dart';
import '../../local/local_pipeline_run_repository.dart';
import '../../local/local_phase3_plus_repository.dart';
import '../../local/local_trace_link_repository.dart';
import '../../local/local_weekly_snapshot_repository.dart';
import '../../models/feedback_event_models.dart';
import '../../models/memory_models.dart';
import '../../models/today_models.dart';
import '../../models/weekly_models.dart';
import '../../preferences/focus_domains.dart';
import '../../readiness/report_readiness.dart';
import 'ai_repository.dart';
import 'monthly_repository.dart';

typedef MemoryFocusAreaLoader = Future<String?> Function();
typedef JourneyInstallationDateLoader = Future<DateTime> Function();

class MemoryFetchResult {
  final MemorySummaryModel? summary;
  final bool isFirstDayGate;
  final ReportReadiness? journeyReadiness;

  const MemoryFetchResult({
    required this.summary,
    required this.isFirstDayGate,
    this.journeyReadiness,
  });
}

class MemoryRepository {
  final LocalCaptureRepository localCaptureRepository;
  final LocalJourneySnapshotRepository localJourneySnapshotRepository;
  final LocalLifeExperimentRepository? localLifeExperimentRepository;
  final LocalPhase3PlusRepository? localPhase3PlusRepository;
  final LocalWeeklySnapshotRepository? localWeeklySnapshotRepository;
  final AiRepository aiRepository;
  final MonthlyRepository? monthlyRepository;
  final MemoryFocusAreaLoader? focusAreaLoader;
  final JourneyInstallationDateLoader? installationDateLoader;
  final String localUserId;
  final SignalEligibilityService eligibilityService;
  final ReportReadinessRule journeyReadinessRule;

  MemoryRepository({
    required this.localCaptureRepository,
    required this.localJourneySnapshotRepository,
    required this.aiRepository,
    this.monthlyRepository,
    this.localLifeExperimentRepository,
    this.localPhase3PlusRepository,
    this.localWeeklySnapshotRepository,
    this.focusAreaLoader,
    this.installationDateLoader,
    this.localUserId = 'local',
    SignalEligibilityService? eligibilityService,
    this.journeyReadinessRule = ReportReadinessEvaluator.journeyRule,
  }) : eligibilityService =
            eligibilityService ?? const SignalEligibilityService();

  Future<MemoryFetchResult> fetchMemorySummaryResult({DateTime? month}) async {
    final installationDate = await _readOrCreateInstallationDate();
    final today = _dateOnly(DateTime.now());
    final requestedMonth = _dateOnly(month ?? today);
    final selectedMonth = DateTime(requestedMonth.year, requestedMonth.month);
    final currentMonth = DateTime(today.year, today.month);
    final effectiveMonth =
        selectedMonth.isAfter(currentMonth) ? currentMonth : selectedMonth;
    final isCurrentMonth = effectiveMonth == currentMonth;
    final isFirstDay = isCurrentMonth && _sameDay(installationDate, today);

    final aggregation = await LocalJourneyAggregationRepository(
      localCaptureRepository: localCaptureRepository,
      localLifeExperimentRepository: localLifeExperimentRepository,
      localPhase3PlusRepository: localPhase3PlusRepository,
      localWeeklySnapshotRepository: localWeeklySnapshotRepository,
      eligibilityService: eligibilityService,
    ).fetchMonth(
      localUserId: localUserId,
      selectedMonth: effectiveMonth,
      today: today,
      installationDate: installationDate,
    );
    const readinessEvaluator = ReportReadinessEvaluator();
    final journeyReadiness = readinessEvaluator.evaluate(
      aggregation.signals,
      journeyReadinessRule,
    );
    if (!aggregation.hasMaterial) {
      return MemoryFetchResult(
        summary: null,
        isFirstDayGate: isFirstDay,
        journeyReadiness: journeyReadiness,
      );
    }

    final stats = _buildJourneyStats(
      aggregation.signals,
      experimentHistory: aggregation.experimentHistory,
      feedbackEvents: aggregation.feedbackEvents,
      subjectTitles: aggregation.subjectTitles,
      sourceSignals: aggregation.sourceSignals,
      sourceExperimentHistory: aggregation.sourceExperimentHistory,
      sourceExperimentRollups: aggregation.sourceExperimentRollups,
      sourcePlanContentVersions: aggregation.sourcePlanContentVersions,
      sourceFeedbackEvents: aggregation.sourceFeedbackEvents,
      sourceWeeklyReviews: aggregation.sourceWeeklyReviews,
      sourceSubjectTitles: aggregation.sourceSubjectTitles,
      monthStart: aggregation.periodStart,
      periodEnd: aggregation.periodEnd,
    );

    // Sparse Journey data remains available as a factual free projection, but
    // it must not trigger or cache an interpretive report. This keeps the
    // user's timeline/calendar/curve/evidence visible without turning one
    // moment into a pattern.
    if (!journeyReadiness.isReady) {
      final factualSummary = _attachJourneyData(
        MemorySummaryModel(
          patterns: const [],
          frictions: const [],
          desires: const [],
          experiments: const [],
        ),
        stats,
      );
      return MemoryFetchResult(
        summary: factualSummary,
        isFirstDayGate: false,
        journeyReadiness: journeyReadiness,
      );
    }

    final observations = await _loadJourneyObservations(
      startDate: _dateKey(installationDate),
      endDate: aggregation.endDate,
    );
    final journeyStats = stats.copyWith(observations: observations);
    final snapshotDate = aggregation.endDate;
    final sourceHash = localJourneySnapshotRepository.buildSourceHash(
      entries: journeyStats.entries,
      topTokens: journeyStats.topTokens,
      totalDays: journeyStats.totalDays,
      experimentHistory: journeyStats.experimentEntries,
      traceEntries: journeyStats.traceEntries,
      observationEntries: journeyStats.observationEntries,
    );
    await _markJourneyInclusion(journeyStats);

    final cached = await localJourneySnapshotRepository.getByDate(snapshotDate);
    final cachedHash =
        await localJourneySnapshotRepository.getSourceHash(snapshotDate);

    if (cached != null && cachedHash == sourceHash) {
      return MemoryFetchResult(
        summary: await _attachMonthlyReview(
          cached.copyWith(observations: observations),
          includeCurrentMonthly: isCurrentMonth,
        ),
        isFirstDayGate: false,
        journeyReadiness: journeyReadiness,
      );
    }

    final focusArea = await _readFocusArea();

    MemorySummaryModel generated;
    try {
      generated = await aiRepository.generateJourneySummary(
        snapshotDate: snapshotDate,
        entries: journeyStats.entries,
        topTokens: journeyStats.topTokens,
        totalDays: journeyStats.totalDays,
        focusArea: focusArea,
      );
      generated = _normalizeJourneySummary(
        generated: generated,
        stats: journeyStats,
      );
    } catch (error) {
      await _recordPipelineFailure(
        pipelineType: 'reflect_generation',
        sourceType: 'journey_snapshot',
        sourceId: snapshotDate,
        inputHash: sourceHash,
        error: error,
      );
      generated = _buildFallbackJourneySummary(journeyStats);
    }
    generated = _attachJourneyData(generated, journeyStats);

    await localJourneySnapshotRepository.upsert(
      snapshotDate: snapshotDate,
      summary: generated,
      sourceHash: sourceHash,
    );

    return MemoryFetchResult(
      summary: await _attachMonthlyReview(
        generated,
        includeCurrentMonthly: isCurrentMonth,
      ),
      isFirstDayGate: false,
      journeyReadiness: journeyReadiness,
    );
  }

  Future<void> _recordPipelineFailure({
    required String pipelineType,
    required String sourceType,
    required String sourceId,
    required String inputHash,
    required Object error,
  }) async {
    final repository = LocalPipelineRunRepository(
      localJourneySnapshotRepository.localDatabase,
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

  Future<MemorySummaryModel> _attachMonthlyReview(
    MemorySummaryModel summary, {
    bool includeCurrentMonthly = true,
  }) async {
    final repository = monthlyRepository;
    if (repository == null || !includeCurrentMonthly) return summary;
    try {
      final monthly = await repository.fetchCurrentMonthly();
      return summary.copyWith(monthlyReview: monthly);
    } catch (_) {
      return summary;
    }
  }

  Future<MemorySummaryModel?> fetchMemorySummary({DateTime? month}) async {
    final result = await fetchMemorySummaryResult(month: month);
    return result.summary;
  }

  Future<List<JourneyObservationModel>> _loadJourneyObservations({
    required String startDate,
    required String endDate,
  }) async {
    final db = await localJourneySnapshotRepository.localDatabase.database;
    final rows = await db.query(
      'observations',
      where: '''
        local_user_id IN (?, ?)
        AND status IN (?, ?, ?)
        AND (
          (source_period_start IS NOT NULL AND source_period_start <= ?)
          OR (source_period_start IS NULL AND updated_at >= ?)
        )
        AND (
          (source_period_end IS NOT NULL AND source_period_end >= ?)
          OR (source_period_end IS NULL AND updated_at <= ?)
        )
      ''',
      whereArgs: [
        localUserId,
        'local',
        'generated',
        'confirmed',
        'dismissed',
        endDate,
        startDate,
        startDate,
        '${endDate}T23:59:59',
      ],
      orderBy: '''
        CASE status
          WHEN 'confirmed' THEN 0
          WHEN 'generated' THEN 1
          ELSE 2
        END,
        updated_at DESC
      ''',
      limit: 12,
    );

    return rows.map((row) {
      final updatedDate = _dateFromIso((row['updated_at'] as String?) ?? '');
      return JourneyObservationModel(
        id: (row['id'] as String?) ?? '',
        text: _firstNonEmpty([
          row['observation_text'],
          row['suggested_pattern'],
          row['evidence_text'],
        ]),
        status: (row['status'] as String?) ?? 'generated',
        confidence: (row['confidence'] as String?) ?? 'medium',
        observationType: (row['observation_type'] as String?) ?? 'hypothesis',
        evidenceText: (row['evidence_text'] as String?) ?? '',
        suggestedPattern: (row['suggested_pattern'] as String?) ?? '',
        localDate: (row['source_period_end'] as String?) ??
            (row['source_period_start'] as String?) ??
            updatedDate ??
            '',
      );
    }).toList(growable: false);
  }

  Future<List<JourneyEvidenceItemModel>> fetchJourneyEvidence({
    JourneyTraceModel? trace,
  }) async {
    if (trace?.sourceType == 'observation') {
      return _fetchObservationEvidence(trace!);
    }

    final snapshotDate = _dateKey(_dateOnly(DateTime.now()));
    final links = await LocalTraceLinkRepository(
      localJourneySnapshotRepository.localDatabase,
    ).listForSource(
      sourceType: 'journey_snapshot',
      sourceId: snapshotDate,
    );
    final matchedLinks = trace == null
        ? links
        : links.where((link) {
            return link['target_type'] == trace.sourceType &&
                link['target_id'] == trace.id;
          }).toList(growable: false);

    final items = <JourneyEvidenceItemModel>[];
    for (final link in matchedLinks) {
      final item = await _resolveJourneyEvidenceLink(link);
      if (item != null) items.add(item);
    }

    if (items.isEmpty && trace != null) {
      return [
        JourneyEvidenceItemModel(
          sourceType: trace.sourceType,
          sourceId: trace.id,
          title: trace.title,
          summary: trace.summary,
          localDate: trace.localDate,
          relationType: 'trace_fallback',
        ),
      ];
    }
    return items;
  }

  Future<List<JourneyEvidenceItemModel>> _fetchObservationEvidence(
    JourneyTraceModel trace,
  ) async {
    final items = <JourneyEvidenceItemModel>[
      JourneyEvidenceItemModel(
        sourceType: 'observation',
        sourceId: trace.id,
        title: trace.title,
        summary: trace.summary,
        localDate: trace.localDate,
        relationType: 'observation_self',
      ),
    ];
    final links = await LocalTraceLinkRepository(
      localJourneySnapshotRepository.localDatabase,
    ).listForSource(
      sourceType: 'observation',
      sourceId: trace.id,
    );
    for (final link in links) {
      final item = await _resolveJourneyEvidenceLink(link);
      if (item != null) items.add(item);
    }
    return items;
  }

  Future<JourneyEvidenceItemModel?> _resolveJourneyEvidenceLink(
    Map<String, Object?> link,
  ) async {
    final targetType = (link['target_type'] as String?) ?? '';
    final targetId = (link['target_id'] as String?) ?? '';
    final relationType = (link['relation_type'] as String?) ?? 'uses_trace';
    if (targetType.isEmpty || targetId.isEmpty) return null;

    switch (targetType) {
      case 'signal_card':
      case 'manual_reflection':
        return _signalEvidenceItem(
          targetType: targetType,
          targetId: targetId,
          relationType: relationType,
        );
      case 'observation':
        return _observationEvidenceItem(targetId, relationType);
      case 'micro_action_feedback':
        return _microActionEvidenceItem(targetId, relationType);
      case 'life_experiment':
      case 'life_experiment_feedback':
        return _lifeExperimentEvidenceItem(targetId, relationType);
      case 'weekly_review':
        return _weeklyEvidenceItem(targetId, relationType);
      default:
        return JourneyEvidenceItemModel(
          sourceType: targetType,
          sourceId: targetId,
          title: _evidenceSourceTitle(targetType),
          summary: 'This trace link points to $targetType:$targetId.',
          localDate: _metadataDate(link),
          relationType: relationType,
        );
    }
  }

  Future<JourneyEvidenceItemModel?> _signalEvidenceItem({
    required String targetType,
    required String targetId,
    required String relationType,
  }) async {
    final db = await localJourneySnapshotRepository.localDatabase.database;
    final rows = await db.query(
      'signal_cards',
      where: 'id = ? OR signal_card_id = ?',
      whereArgs: [targetId, targetId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final scene = (row['scene'] as String?)?.trim();
    final sourceType = (row['source_type'] as String?)?.trim();
    final title = targetType == 'manual_reflection'
        ? 'Manual Reflection'
        : (scene?.isNotEmpty == true ? scene! : 'Signal Card');
    return JourneyEvidenceItemModel(
      sourceType: targetType,
      sourceId: targetId,
      title: title,
      summary: _firstNonEmpty([
        row['observation'],
        row['raw_text'],
        row['ai_reply'],
        row['try_next'],
      ]),
      localDate: (row['local_date'] as String?) ?? '',
      relationType: relationType,
      metadata: {
        'source_type': sourceType,
        'energy_load': row['energy_load'],
        'friction': row['friction'],
      },
    );
  }

  Future<JourneyEvidenceItemModel?> _observationEvidenceItem(
    String targetId,
    String relationType,
  ) async {
    final db = await localJourneySnapshotRepository.localDatabase.database;
    final rows = await db.query(
      'observations',
      where: 'id = ?',
      whereArgs: [targetId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return JourneyEvidenceItemModel(
      sourceType: 'observation',
      sourceId: targetId,
      title: 'Observation',
      summary: _firstNonEmpty([
        row['observation_text'],
        row['evidence_text'],
        row['suggested_pattern'],
      ]),
      localDate: _dateFromIso((row['updated_at'] as String?) ?? '') ??
          (row['source_period_end'] as String? ?? ''),
      relationType: relationType,
      metadata: {
        'confidence': row['confidence'],
        'status': row['status'],
      },
    );
  }

  Future<JourneyEvidenceItemModel?> _microActionEvidenceItem(
    String targetId,
    String relationType,
  ) async {
    final db = await localJourneySnapshotRepository.localDatabase.database;
    final rows = await db.query(
      'micro_action_feedback',
      where: 'id = ?',
      whereArgs: [targetId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return JourneyEvidenceItemModel(
      sourceType: 'micro_action_feedback',
      sourceId: targetId,
      title: 'Micro Action Feedback',
      summary: _firstNonEmpty([
        row['user_note'],
        row['effect'],
        row['happened'],
        row['next_adjustment'],
      ]),
      localDate: (row['local_date'] as String?) ?? '',
      relationType: relationType,
      metadata: {
        'effect': row['effect'],
        'difficulty': row['difficulty'],
      },
    );
  }

  Future<JourneyEvidenceItemModel?> _lifeExperimentEvidenceItem(
    String targetId,
    String relationType,
  ) async {
    final db = await localJourneySnapshotRepository.localDatabase.database;
    final feedbackRows = await db.query(
      'life_experiment_feedback',
      where: 'id = ?',
      whereArgs: [targetId],
      limit: 1,
    );
    if (feedbackRows.isNotEmpty) {
      final row = feedbackRows.first;
      return JourneyEvidenceItemModel(
        sourceType: 'life_experiment_feedback',
        sourceId: targetId,
        title: 'Experiment Feedback',
        summary: _firstNonEmpty([
          row['feedback_text'],
          row['comment'],
          row['effect'],
          row['completion_status'],
          row['happened'],
        ]),
        localDate: (row['local_date'] as String?) ??
            (row['feedback_date'] as String? ?? ''),
        relationType: relationType,
        metadata: {
          'experiment_id': row['experiment_id'],
          'completion_status': row['completion_status'],
        },
      );
    }

    final experimentRows = await db.query(
      'life_experiments',
      where: 'id = ?',
      whereArgs: [targetId],
      limit: 1,
    );
    if (experimentRows.isEmpty) return null;
    final row = experimentRows.first;
    return JourneyEvidenceItemModel(
      sourceType: 'life_experiment',
      sourceId: targetId,
      title: (row['title'] as String?) ?? 'Life Experiment',
      summary: _firstNonEmpty([
        row['feedback_text'],
        row['suggested_action'],
        row['hypothesis'],
      ]),
      localDate: (row['source_week_end'] as String?) ??
          (row['source_week_start'] as String? ?? ''),
      relationType: relationType,
      metadata: {'status': row['status']},
    );
  }

  Future<JourneyEvidenceItemModel?> _weeklyEvidenceItem(
    String targetId,
    String relationType,
  ) async {
    final weekStart =
        targetId.startsWith('weekly_') ? targetId.substring(7) : targetId;
    final db = await localJourneySnapshotRepository.localDatabase.database;
    final rows = await db.query(
      'weekly_snapshots',
      where: 'week_start = ?',
      whereArgs: [weekStart],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return JourneyEvidenceItemModel(
      sourceType: 'weekly_review',
      sourceId: targetId,
      title: 'Weekly Reflection',
      summary: _firstNonEmpty([
        row['key_insight'],
        row['best_action'],
        row['status'],
      ]),
      localDate: (row['week_end'] as String?) ?? weekStart,
      relationType: relationType,
      metadata: {'week_start': weekStart},
    );
  }

  String _firstNonEmpty(List<Object?> values) {
    for (final value in values) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return '';
  }

  String? _dateFromIso(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    return _dateKey(parsed);
  }

  String _metadataDate(Map<String, Object?> link) {
    final metadata = link['metadata_json']?.toString() ?? '';
    final match = RegExp(r'"local_date"\s*:\s*"([^"]+)"').firstMatch(metadata);
    return match?.group(1) ?? '';
  }

  String _evidenceSourceTitle(String sourceType) {
    switch (sourceType) {
      case 'signal_card':
        return 'Signal';
      case 'manual_reflection':
        return 'Manual Reflection';
      case 'observation':
        return 'Observation';
      case 'life_experiment':
      case 'life_experiment_feedback':
        return 'Experiment Feedback';
      case 'weekly_review':
        return 'Weekly Reflection';
      default:
        return sourceType;
    }
  }

  _JourneyStats _buildJourneyStats(
    List<RecentSignalModel> signals, {
    required List<LifeExperimentModel> experimentHistory,
    required List<FeedbackEventModel> feedbackEvents,
    required Map<String, String> subjectTitles,
    required List<RecentSignalModel> sourceSignals,
    required List<LifeExperimentModel> sourceExperimentHistory,
    required List<Map<String, dynamic>> sourceExperimentRollups,
    required List<Map<String, dynamic>> sourcePlanContentVersions,
    required List<FeedbackEventModel> sourceFeedbackEvents,
    required List<WeeklyInsightModel> sourceWeeklyReviews,
    required Map<String, String> sourceSubjectTitles,
    required DateTime monthStart,
    required DateTime periodEnd,
  }) {
    final signalEntries = <Map<String, dynamic>>[];
    final entries = <Map<String, dynamic>>[];
    final tokenCounts = <String, int>{};
    final sourceDayKeys = <String>{};
    final selectedDayKeys = <String>{};
    final sceneCounts = <String, int>{};
    final frictionCounts = <String, int>{};
    final energyLoadCounts = <String, int>{};
    final positiveSignalCounts = <String, int>{};
    final energyStateCounts = _emptyEnergyStateCounts();
    final dayFacts = <String, _JourneyDayAccumulator>{};

    // Interpretive generation uses every privacy-eligible fact from first use
    // through the selected month end. It must never include a later fact.
    for (final signal in sourceSignals) {
      final dayKey = signal.localDateKey();
      if (dayKey.isEmpty) continue;
      sourceDayKeys.add(dayKey);
      final entry = _signalAnalysisEntry(signal);
      signalEntries.add(entry);
      entries.add(entry);

      for (final token in _tokenize(_analysisContent(signal))) {
        tokenCounts[token] = (tokenCounts[token] ?? 0) + 1;
      }
      for (final tag in signal.sceneTags) {
        final normalized = tag.trim();
        if (normalized.isNotEmpty) {
          tokenCounts[normalized] = (tokenCounts[normalized] ?? 0) + 1;
        }
      }
      _countIfPresent(sceneCounts, signal.scene);
      _countIfPresent(frictionCounts, signal.friction);
      _countIfPresent(energyLoadCounts, signal.energyLoad);
      _countIfPresent(positiveSignalCounts, signal.positiveSignal);
    }

    // The free trajectory and the 7 Signal / 3 day readiness gate stay
    // strictly bounded to the selected local calendar month.
    for (final signal in signals) {
      final dayKey = signal.localDateKey();
      if (dayKey.isEmpty) continue;
      selectedDayKeys.add(dayKey);
      final energyState = _journeyEnergyState(signal);
      energyStateCounts[energyState] =
          (energyStateCounts[energyState] ?? 0) + 1;
      final daily = dayFacts.putIfAbsent(
        dayKey,
        () => _JourneyDayAccumulator(dayKey),
      );
      daily.signalCount += 1;
      daily.energyStateCounts[energyState] =
          (daily.energyStateCounts[energyState] ?? 0) + 1;
    }

    final sourceEffectiveGoalEventIds =
        _effectiveGoalDailyEventIds(sourceFeedbackEvents);
    for (final event in sourceFeedbackEvents) {
      entries.add(
        _feedbackEventAnalysisEntry(
          event,
          isEffective: sourceEffectiveGoalEventIds.contains(event.id),
          subjectTitle: sourceSubjectTitles[event.subjectId],
        ),
      );
      for (final token in _tokenize(_eventSummary(event))) {
        tokenCounts[token] = (tokenCounts[token] ?? 0) + 1;
      }
    }

    final effectiveGoalEventIds = _effectiveGoalDailyEventIds(feedbackEvents);
    final trackAccumulators = <String, _JourneyTrackAccumulator>{};
    for (final experiment in experimentHistory.where(_isAdoptedGoal)) {
      final key = 'life_experiment:${experiment.id}';
      final track = trackAccumulators.putIfAbsent(
        key,
        () => _JourneyTrackAccumulator(
          subjectId: experiment.id,
          kind: 'goal',
          title: experiment.title,
        ),
      );
      track.latestResult = experiment.status;
      track.latestLocalDate =
          experiment.progressStartDate ?? experiment.sourceWeekStart;
    }
    for (final event in feedbackEvents) {
      final key = '${event.subjectType}:${event.subjectId}';
      final isQuick = event.subjectType == 'micro_action';
      final isGoal =
          event.subjectType == 'life_experiment' || event.subjectType == 'goal';
      if (isQuick) {
        final track = trackAccumulators.putIfAbsent(
          key,
          () => _JourneyTrackAccumulator(
            subjectId: event.subjectId,
            kind: 'small_experiment',
            title: subjectTitles[event.subjectId] ?? '小实验',
          ),
        );
        if (event.sourceType == 'micro_action_feedback') {
          track.feedbackCount += 1;
          if (_isCompletedSmallExperiment(event.status)) {
            // Every completed row is one real attempt. Multiple attempts on
            // the same local day intentionally remain distinct.
            track.attemptCount += 1;
            final daily = dayFacts.putIfAbsent(
              event.localDate,
              () => _JourneyDayAccumulator(event.localDate),
            );
            daily.smallExperimentAttemptCount += 1;
          }
        } else if (event.sourceType == 'micro_action_round_review') {
          track.roundReviewCount += 1;
        }
        track.observe(event);
      } else if (isGoal) {
        final track = trackAccumulators.putIfAbsent(
          key,
          () => _JourneyTrackAccumulator(
            subjectId: event.subjectId,
            kind: 'goal',
            title: subjectTitles[event.subjectId] ?? '目标',
          ),
        );
        if (_isGoalDailyEvent(event)) {
          if (effectiveGoalEventIds.contains(event.id)) {
            track.feedbackCount += 1;
            final daily = dayFacts.putIfAbsent(
              event.localDate,
              () => _JourneyDayAccumulator(event.localDate),
            );
            daily.goalFeedbackCount += 1;
          }
        } else if (event.sourceType == 'life_experiment_outcome_review') {
          final reviewType = event.metadata['review_type']?.toString();
          if (reviewType == 'weekly') {
            track.weeklyReviewCount += 1;
          } else if (reviewType == 'whole_round') {
            track.wholeRoundReviewCount += 1;
          }
        }
        track.observe(event);
      }
    }

    // Finalized Weekly snapshots and adopted goal definitions are valid
    // report sources, but they do not become eligible Signal Cards and are
    // not placed on the free monthly path as standalone milestones.
    for (final weekly in sourceWeeklyReviews) {
      entries.add({
        'id': 'weekly_${weekly.weekStart}',
        'source_type': 'weekly_review',
        'content': weekly.keyInsight ?? weekly.bestAction ?? '',
        'local_date': weekly.weekEnd,
        'week_start': weekly.weekStart,
        'week_end': weekly.weekEnd,
      });
    }
    for (final experiment in sourceExperimentHistory) {
      entries.add({
        'id': experiment.id,
        'source_type': 'life_experiment',
        'content': [experiment.title, experiment.hypothesis]
            .where((value) => value.trim().isNotEmpty)
            .join(' · '),
        'local_date':
            experiment.progressStartDate ?? experiment.sourceWeekStart,
      });
    }
    final boundedRollups = sourceExperimentRollups
        .map(
          (rollup) => _boundedExperimentRollupEntry(
            rollup,
            sourceFeedbackEvents,
          ),
        )
        .toList(growable: false);
    entries.addAll(boundedRollups);
    for (final version in sourcePlanContentVersions) {
      entries.add({
        'id': version['id'],
        'source_type': 'plan_content_version',
        'object_kind': version['object_kind'],
        'object_id': version['object_id'],
        'version_no': version['version_no'],
        'local_date': version['effective_from_local_date'],
        'content': version['content_json'],
      });
    }

    final traceModels = _buildJourneyTraces(
      signals: signals,
      feedbackEvents: feedbackEvents,
      subjectTitles: subjectTitles,
      effectiveGoalEventIds: effectiveGoalEventIds,
      monthStart: monthStart,
      periodEnd: periodEnd,
    );

    final sortedTokens = tokenCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final sortedDayKeys = sourceDayKeys.toList()..sort();
    final first =
        sortedDayKeys.isEmpty ? null : DateTime.tryParse(sortedDayKeys.first);
    final last =
        sortedDayKeys.isEmpty ? null : DateTime.tryParse(sortedDayKeys.last);
    final totalDays =
        (first == null || last == null) ? 1 : last.difference(first).inDays + 1;

    return _JourneyStats(
      entries: entries,
      topTokens: sortedTokens.take(10).map((e) => e.key).toList(),
      topScenes: _topKeys(sceneCounts),
      topFrictions: _topKeys(frictionCounts),
      topEnergyLoads: _topKeys(energyLoadCounts),
      topPositiveSignals: _topKeys(positiveSignalCounts),
      totalDays: totalDays,
      activeDays: sourceDayKeys.length,
      entryCount: signalEntries.length,
      signalEntries: signalEntries,
      experimentHistory: sourceExperimentHistory,
      experimentEntries: [
        ...sourceExperimentHistory.map(_experimentHashEntry),
        ...boundedRollups,
        ...sourcePlanContentVersions.map((version) => {
              'id': version['id'],
              'source_type': 'plan_content_version',
              'object_kind': version['object_kind'],
              'object_id': version['object_id'],
              'version_no': version['version_no'],
              'effective_from_local_date': version['effective_from_local_date'],
              'content_json': version['content_json'],
            }),
        ...sourceFeedbackEvents.map((event) => event.toJson()),
        ...sourceWeeklyReviews.map((weekly) => {
              'id': 'weekly_${weekly.weekStart}',
              'source_type': 'weekly_review',
              'week_start': weekly.weekStart,
              'week_end': weekly.weekEnd,
              'key_insight': weekly.keyInsight,
              'best_action': weekly.bestAction,
            }),
      ],
      journeyTraces: traceModels,
      traceEntries: traceModels.map((e) => e.toJson()).toList(),
      periodFacts: JourneyPeriodFactsModel(
        periodStart: _dateKey(monthStart),
        periodEnd: _dateKey(periodEnd),
        signalCount: signals.length,
        activeDayCount: selectedDayKeys.length,
        smallExperimentAttemptCount: trackAccumulators.values.fold(
          0,
          (sum, track) => sum + track.attemptCount,
        ),
        smallExperimentRoundReviewCount: trackAccumulators.values.fold(
          0,
          (sum, track) => sum + track.roundReviewCount,
        ),
        goalFeedbackCount: dayFacts.values.fold(
          0,
          (sum, day) => sum + day.goalFeedbackCount,
        ),
        goalWeeklyReviewCount: trackAccumulators.values.fold(
          0,
          (sum, track) => sum + track.weeklyReviewCount,
        ),
        goalWholeRoundReviewCount: trackAccumulators.values.fold(
          0,
          (sum, track) => sum + track.wholeRoundReviewCount,
        ),
        energyStateCounts: energyStateCounts,
        days: (dayFacts.values.toList()
              ..sort((a, b) => a.localDate.compareTo(b.localDate)))
            .map((day) => day.toModel())
            .toList(growable: false),
        experimentTracks: (trackAccumulators.values.toList()
              ..sort((a, b) => b.latestLocalDate.compareTo(a.latestLocalDate)))
            .map((track) => track.toModel())
            .toList(growable: false),
      ),
      monthKey:
          '${periodEnd.year}-${periodEnd.month.toString().padLeft(2, '0')}',
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

  Map<String, dynamic> _signalAnalysisEntry(RecentSignalModel signal) {
    final dayKey = signal.localDateKey();
    final createdAt = signal.createdAt?.toLocal();
    return <String, dynamic>{
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
      'energy_load': signal.energyLoad,
      'energy_state': _journeyEnergyState(signal),
      'positive_signal': signal.positiveSignal,
      'scene_tags': signal.sceneTags,
      'intent_tags': signal.intentTags,
      'user_confirmation': signal.userConfirmation,
      'is_legacy': signal.isLegacy,
      'journey_confidence': _journeyEvidenceLevel(signal),
    };
  }

  String _journeyEvidenceLevel(RecentSignalModel signal) {
    if (signal.isLegacy) return 'legacy_context';
    if (signal.isLibrarySaved) return 'library_saved_confirmed';
    if (signal.userConfirmation == 'unconfirmed') return 'light_observation';
    return 'standard';
  }

  Map<String, dynamic> _experimentHashEntry(LifeExperimentModel experiment) {
    return {
      'id': experiment.id,
      'source_type': 'life_experiment_definition',
      'title': experiment.title,
      'hypothesis': experiment.hypothesis,
      'suggested_action': experiment.suggestedAction,
      'source_week_start': experiment.sourceWeekStart,
      'source_week_end': experiment.sourceWeekEnd,
      'planned_frequency': experiment.plannedFrequency,
      'planned_duration_minutes': experiment.plannedDurationMinutes,
      'planned_total_days': experiment.plannedTotalDays,
      'minimum_observation_days': experiment.minimumObservationDays,
    };
  }

  /// Legacy rollups remain source-compatible, but their persisted counters
  /// may already include feedback after a historical selected month. Rebuild
  /// dynamic counts from the bounded event stream and keep only stable rollup
  /// identity fields so a past report cannot see future feedback.
  Map<String, dynamic> _boundedExperimentRollupEntry(
    Map<String, dynamic> rollup,
    Iterable<FeedbackEventModel> boundedEvents,
  ) {
    final experimentId = rollup['experiment_id']?.toString() ?? '';
    final events = boundedEvents
        .where((event) => event.subjectId == experimentId)
        .toList(growable: false);
    final dailyFeedbacks = events.where(_isGoalDailyEvent).toList();
    final effectiveDailyIds = _effectiveGoalDailyEventIds(dailyFeedbacks);
    final reviews = events
        .where(
          (event) => event.sourceType == 'life_experiment_outcome_review',
        )
        .toList(growable: false);
    return <String, dynamic>{
      'id': experimentId,
      'source_type': 'life_experiment_rollup',
      'root_experiment_id': rollup['root_experiment_id'],
      'parent_experiment_id': rollup['parent_experiment_id'],
      'source_week_start': rollup['source_week_start'],
      'source_week_end': rollup['source_week_end'],
      'feedback_day_count': effectiveDailyIds.length,
      'weekly_review_count': reviews
          .where((event) => event.metadata['review_type'] == 'weekly')
          .length,
      'whole_round_review_count': reviews
          .where((event) => event.metadata['review_type'] == 'whole_round')
          .length,
      'last_source_local_date': events.isEmpty
          ? null
          : (events.map((event) => event.localDate).toList()..sort()).last,
    };
  }

  Map<String, int> _emptyEnergyStateCounts() => {
        'draining': 0,
        'steady': 0,
        'ease': 0,
        'recovery': 0,
        'boundary_buffer': 0,
      };

  /// Uses the canonical structured state when present and deterministic
  /// fallbacks from real Signal fields otherwise. It never invents a numeric
  /// curve and never emits an unknown bucket.
  String _journeyEnergyState(RecentSignalModel signal) {
    final serverState = signal.energyState?.trim().toLowerCase();
    if (const {
      'draining',
      'steady',
      'ease',
      'recovery',
      'boundary_buffer',
    }.contains(serverState)) {
      return serverState!;
    }
    final payload = signal.rawPayloadJson;
    final explicitState =
        payload['energy_state']?.toString().trim().toLowerCase();
    if (const {
      'draining',
      'steady',
      'ease',
      'recovery',
      'boundary_buffer',
    }.contains(explicitState)) {
      return explicitState!;
    }
    final level = int.tryParse('${payload['energy_level'] ?? ''}');
    if (level == 0) return 'draining';
    if (level == 1) return 'steady';
    if (level == 2) return 'ease';
    final effect =
        payload['energy_effect']?.toString().trim().toLowerCase() ?? '';
    if (const {'restoring', 'recovery'}.contains(effect)) return 'recovery';
    if (const {'ease', 'resourced'}.contains(effect)) return 'ease';
    if (effect == 'draining') return 'draining';

    final load = signal.energyLoad?.trim().toLowerCase() ?? '';
    final friction = signal.friction?.trim().toLowerCase() ?? '';
    if (load.contains('boundary') ||
        load.contains('buffer') ||
        friction.contains('boundary') ||
        friction.contains('overcommit') ||
        friction.contains('capacity_limit')) {
      return 'boundary_buffer';
    }
    if (load.contains('recover') ||
        load.contains('restor') ||
        signal.linkedLifeChainStages.contains('recovery')) {
      return 'recovery';
    }
    if (load.contains('drain') || load.contains('exhaust')) return 'draining';
    if (load.contains('ease') ||
        load.contains('easy') ||
        load.contains('light') ||
        load.contains('resourced') ||
        (signal.positiveSignal?.trim().isNotEmpty ?? false)) {
      return 'ease';
    }
    return 'steady';
  }

  Map<String, dynamic> _feedbackEventAnalysisEntry(
    FeedbackEventModel event, {
    required bool isEffective,
    String? subjectTitle,
  }) {
    return {
      'id': event.id,
      'event_id': event.id,
      'source_id': event.sourceId,
      'source_type': event.sourceType,
      'subject_type': event.subjectType,
      'subject_id': event.subjectId,
      if (subjectTitle?.trim().isNotEmpty == true)
        'subject_title': subjectTitle!.trim(),
      'content': _eventSummary(event),
      'local_date': event.localDate,
      'occurred_at': event.occurredAt?.toUtc().toIso8601String(),
      'created_at': event.createdAt?.toUtc().toIso8601String(),
      'status': event.status,
      'effect': event.effect,
      'is_effective': isEffective,
      'metadata': event.metadata,
    };
  }

  String _eventSummary(FeedbackEventModel event) {
    return [
      event.status,
      event.effect,
      event.note,
      event.metadata['next_adjustment'],
      event.metadata['burden'],
    ]
        .whereType<Object>()
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .join(' · ');
  }

  String _feedbackEventTitle(FeedbackEventModel event) {
    return switch (event.sourceType) {
      'micro_action_feedback' => '小实验尝试',
      'micro_action_round_review' => '小实验整轮总结',
      'life_experiment_feedback' || 'goal_feedback' => '目标进展',
      'life_experiment_outcome_review' =>
        event.metadata['review_type'] == 'weekly' ? '目标周次总结' : '目标整轮总结',
      'schedule_feedback' => event.metadata['title']?.toString() ?? '时间安排',
      _ => event.subjectType,
    };
  }

  bool _isGoalDailyEvent(FeedbackEventModel event) {
    return event.sourceType == 'life_experiment_feedback' ||
        event.sourceType == 'goal_feedback';
  }

  bool _isAdoptedGoal(LifeExperimentModel experiment) {
    if (experiment.adoptedAt != null) return true;
    return const {
      'saved',
      'active',
      'done',
      'completed',
      'adjusted',
      'paused',
      'stopped',
    }.contains(experiment.status.trim().toLowerCase());
  }

  bool _isCompletedSmallExperiment(String status) {
    return const {
      'completed',
      'done',
      'occurred',
      'happened',
      'true',
      'yes',
      '1',
    }.contains(status.trim().toLowerCase());
  }

  Set<String> _effectiveGoalDailyEventIds(
    Iterable<FeedbackEventModel> events,
  ) {
    final latest = <String, FeedbackEventModel>{};
    for (final event in events.where(_isGoalDailyEvent)) {
      final key = '${event.subjectType}:${event.subjectId}:${event.localDate}';
      final current = latest[key];
      if (current == null || _compareFeedbackEvents(current, event) <= 0) {
        latest[key] = event;
      }
    }
    return latest.values.map((event) => event.id).toSet();
  }

  int _compareFeedbackEvents(
    FeedbackEventModel left,
    FeedbackEventModel right,
  ) {
    final leftTime = left.createdAt ?? left.occurredAt ?? DateTime(0);
    final rightTime = right.createdAt ?? right.occurredAt ?? DateTime(0);
    final timeCompare = leftTime.compareTo(rightTime);
    return timeCompare != 0 ? timeCompare : left.id.compareTo(right.id);
  }

  List<JourneyTraceModel> _buildJourneyTraces({
    required List<RecentSignalModel> signals,
    required List<FeedbackEventModel> feedbackEvents,
    required Map<String, String> subjectTitles,
    required Set<String> effectiveGoalEventIds,
    required DateTime monthStart,
    required DateTime periodEnd,
  }) {
    final traces = <JourneyTraceModel>[];

    bool inMonth(String dateKey) {
      final parsed = DateTime.tryParse(dateKey);
      if (parsed == null) return false;
      final day = DateTime(parsed.year, parsed.month, parsed.day);
      return !day.isBefore(monthStart) && !day.isAfter(periodEnd);
    }

    for (final signal in signals) {
      final dayKey = signal.localDateKey();
      if (dayKey.isEmpty || !inMonth(dayKey)) continue;
      final isReflection = _isManualReflectionSignal(signal);
      traces.add(JourneyTraceModel(
        id: signal.signalCardId ?? signal.id ?? 'signal_$dayKey',
        sourceType: isReflection ? 'manual_reflection' : 'signal_card',
        title:
            isReflection ? 'Manual reflection' : _traceTitleForSignal(signal),
        summary: _analysisContent(signal),
        localDate: dayKey,
        cluster: _traceCluster(
          signal.scene ??
              (signal.sceneTags.isEmpty ? null : signal.sceneTags.first) ??
              signal.sourceType,
        ),
        intensity: _signalIntensity(signal),
        signalLevel: _journeyEvidenceLevel(signal) == 'standard'
            ? 'repeated_pattern'
            : 'weak_signal',
        metadata: {
          'display_lane': 'monthly_path',
          'energy_state': _journeyEnergyState(signal),
          'signal_card_id': signal.signalCardId ?? signal.id,
        },
      ));
    }

    for (final event in feedbackEvents) {
      if (!inMonth(event.localDate)) continue;
      final isGoalDaily = _isGoalDailyEvent(event);
      final isEffective = effectiveGoalEventIds.contains(event.id);
      final isRoundReview = event.sourceType == 'micro_action_round_review';
      final isOutcomeReview =
          event.sourceType == 'life_experiment_outcome_review';
      final kind = event.subjectType == 'micro_action'
          ? 'small_experiment'
          : event.subjectType == 'life_experiment' ||
                  event.subjectType == 'goal'
              ? 'goal'
              : event.subjectType;
      traces.add(JourneyTraceModel(
        // Keep the source type in the identity so append-only rows from
        // different event tables can never collapse when their raw ids match.
        id: event.id,
        sourceType: event.sourceType,
        title: subjectTitles[event.subjectId] ?? _feedbackEventTitle(event),
        summary: _eventSummary(event),
        localDate: event.localDate,
        cluster: kind == 'small_experiment' || kind == 'goal'
            ? 'experiment'
            : _traceCluster(event.effect ?? event.status),
        intensity: _feedbackIntensity(
          event.effect ?? event.status,
          event.note,
        ),
        signalLevel: _isHelpfulText(event.effect) || _isHelpfulText(event.note)
            ? 'repeated_pattern'
            : 'weak_signal',
        metadata: {
          'display_lane': kind == 'small_experiment' || kind == 'goal'
              ? 'experiment_goal_track'
              : 'source_only',
          'event_id': event.id,
          'source_id': event.sourceId,
          'subject_type': event.subjectType,
          'subject_id': event.subjectId,
          'kind': kind,
          if (isGoalDaily) 'is_effective': isEffective,
          if (isRoundReview) 'review_type': 'whole_round',
          if (isOutcomeReview)
            'review_type': event.metadata['review_type'] ?? 'whole_round',
          ...event.metadata,
        },
      ));
    }

    traces.sort((a, b) {
      final dateCompare = a.localDate.compareTo(b.localDate);
      if (dateCompare != 0) return dateCompare;
      return a.id.compareTo(b.id);
    });
    return traces.take(240).toList(growable: false);
  }

  MemorySummaryModel _attachJourneyData(
    MemorySummaryModel summary,
    _JourneyStats stats,
  ) {
    final themes = _journeyThemes(stats.journeyTraces);
    final direction = LifeDirectionModel(
      title: summary.longTermPattern?.name ?? 'Life direction',
      summary: summary.longTermPattern?.summary ??
          'Your current direction is forming from the real traces you leave.',
    );
    return summary.copyWith(
      lifeDirection: direction,
      journeyThemes: themes,
      journeyTraces: stats.journeyTraces,
      observations: stats.observations,
      phaseMemory: PhaseMemoryModel(
        monthKey: stats.monthKey,
        traces: stats.journeyTraces,
        themes: themes,
      ),
      periodFacts: stats.periodFacts,
    );
  }

  List<JourneyThemeModel> _journeyThemes(List<JourneyTraceModel> traces) {
    final counts = <String, int>{};
    for (final trace in traces) {
      counts[trace.cluster] = (counts[trace.cluster] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted
        .take(6)
        .map((entry) => JourneyThemeModel(
              id: entry.key,
              title: entry.key,
              count: entry.value,
            ))
        .toList(growable: false);
  }

  bool _isManualReflectionSignal(RecentSignalModel signal) {
    final source = signal.sourceType.toLowerCase();
    if (source.contains('reflection') || source.contains('diary')) return true;
    return signal.intentTags.any((tag) => tag.toLowerCase() == 'reflection');
  }

  String _traceTitleForSignal(RecentSignalModel signal) {
    final scene = signal.scene?.trim();
    if (scene != null && scene.isNotEmpty) return scene;
    if (signal.sceneTags.isNotEmpty) return signal.sceneTags.first;
    return 'Signal Card';
  }

  String _traceCluster(String? value) {
    final text = (value ?? '').toLowerCase();
    if (text.contains('recover') ||
        text.contains('rest') ||
        text.contains('恢复') ||
        text.contains('calm')) {
      return 'recovery';
    }
    if (text.contains('work') ||
        text.contains('focus') ||
        text.contains('安排') ||
        text.contains('schedule')) {
      return 'work';
    }
    if (text.contains('hard') ||
        text.contains('drain') ||
        text.contains('压力') ||
        text.contains('friction')) {
      return 'friction';
    }
    if (text.contains('help') || text.contains('有效') || text.contains('有帮助')) {
      return 'helpful';
    }
    if (text.contains('weekly')) return 'weekly';
    return 'life';
  }

  double _signalIntensity(RecentSignalModel signal) {
    final intensity = signal.intensity?.toLowerCase();
    if (intensity == 'high' || intensity == 'strong') return 0.9;
    if (intensity == 'low' || intensity == 'light') return 0.35;
    if ((signal.friction ?? '').trim().isNotEmpty) return 0.72;
    if ((signal.positiveSignal ?? '').trim().isNotEmpty) return 0.66;
    return 0.5;
  }

  double _feedbackIntensity(String? status, String? note) {
    final text = '${status ?? ''} ${note ?? ''}'.toLowerCase();
    if (_isHelpfulText(text)) return 0.82;
    if (text.contains('hard') || text.contains('too') || text.contains('太难')) {
      return 0.76;
    }
    if (text.contains('skip') || text.contains('not')) return 0.42;
    return 0.58;
  }

  bool _isHelpfulText(String? value) {
    final text = (value ?? '').toLowerCase();
    return text.contains('help') ||
        text.contains('effective') ||
        text.contains('有帮助') ||
        text.contains('有效');
  }

  Future<void> _markJourneyInclusion(_JourneyStats stats) async {
    final ids = stats.signalEntries
        .map((entry) =>
            (entry['signal_card_id'] as String?) ?? (entry['id'] as String?))
        .whereType<String>();
    await localCaptureRepository.updateSignalCardInclusion(
      signalCardIds: ids,
      includedInJourney: true,
    );
  }

  void _countIfPresent(Map<String, int> counts, String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return;
    counts[normalized] = (counts[normalized] ?? 0) + 1;
  }

  List<String> _topKeys(Map<String, int> counts) {
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(5).map((e) => e.key).toList();
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
      '今天',
      '就是',
      '一个',
      '有点',
      '然后',
      '最近',
      '一直',
      'また',
      'もう',
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

  MemorySummaryModel _normalizeJourneySummary({
    required MemorySummaryModel generated,
    required _JourneyStats stats,
  }) {
    return MemorySummaryModel(
      patterns: _normalizeSignalItems(
        items: generated.patterns,
        fallbackLabel: '反复出现的主题',
        stats: stats,
        preferStable: true,
      ),
      frictions: _normalizeSignalItems(
        items: generated.frictions,
        fallbackLabel: '持续性的摩擦',
        stats: stats,
        preferStable: false,
      ),
      desires: _normalizeSignalItems(
        items: generated.desires,
        fallbackLabel: '一个恢复线索',
        stats: stats,
        preferStable: false,
      ),
      experiments: _normalizeSignalItems(
        items: _experimentItems(
          generated.experiments,
          stats,
        ),
        fallbackLabel: '一个实验调整记录',
        stats: stats,
        preferStable: false,
      ),
    );
  }

  List<JourneySignalItemModel> _normalizeSignalItems({
    required List<JourneySignalItemModel> items,
    required String fallbackLabel,
    required _JourneyStats stats,
    required bool preferStable,
  }) {
    if (items.isEmpty) {
      return [
        JourneySignalItemModel(
          name: fallbackLabel,
          summary: _defaultSignalSummary(
            fallbackLabel: fallbackLabel,
            stats: stats,
          ),
          signalLevel: _resolveSignalLevel(
            entryCount: stats.entryCount,
            activeDays: stats.activeDays,
            preferStable: preferStable,
          ),
        ),
      ];
    }

    return items.take(1).map((item) {
      final signalLevel = item.signalLevel.trim().isEmpty
          ? _resolveSignalLevel(
              entryCount: stats.entryCount,
              activeDays: stats.activeDays,
              preferStable: preferStable,
            )
          : item.signalLevel;

      return JourneySignalItemModel(
        name: item.name.trim().isEmpty ? fallbackLabel : item.name,
        summary: _softJourneyText(
          item.summary.trim().isEmpty
              ? _defaultSignalSummary(
                  fallbackLabel: fallbackLabel,
                  stats: stats,
                )
              : item.summary,
        ),
        signalLevel: signalLevel,
      );
    }).toList();
  }

  String _resolveSignalLevel({
    required int entryCount,
    required int activeDays,
    required bool preferStable,
  }) {
    if (entryCount >= 4 && activeDays >= 3 && preferStable) {
      return 'stable_mode';
    }
    if (entryCount >= 3 || activeDays >= 2) {
      return 'repeated_pattern';
    }
    return 'weak_signal';
  }

  String _defaultSignalSummary({
    required String fallbackLabel,
    required _JourneyStats stats,
  }) {
    final topToken = stats.topTokens.isEmpty
        ? '最近的记录'
        : _readableToken(stats.topTokens.first);

    if (stats.entryCount <= 1) {
      return '现在还只是一个刚刚冒头的线索，先继续看看它会不会再出现。';
    }
    if (stats.entryCount < 4 || stats.activeDays < 2) {
      return '这个方向已经不止一次出现了，开始值得继续留意。';
    }
    return '一路看下来，“$topToken”已经不只是偶然，而开始形成更稳定的节奏。';
  }

  MemorySummaryModel _buildFallbackJourneySummary(_JourneyStats stats) {
    final topToken = stats.topTokens.isEmpty
        ? '最近的记录'
        : _readableToken(stats.topTokens.first);
    final weakOrRepeated = _resolveSignalLevel(
      entryCount: stats.entryCount,
      activeDays: stats.activeDays,
      preferStable: false,
    );
    final stableOrRepeated = _resolveSignalLevel(
      entryCount: stats.entryCount,
      activeDays: stats.activeDays,
      preferStable: true,
    );

    return MemorySummaryModel(
      patterns: [
        JourneySignalItemModel(
          name: '反复出现的主题',
          summary: stats.entryCount <= 1
              ? '“$topToken”刚刚出现一次，先把它作为一个值得继续留意的线索放着。'
              : stats.entryCount < 4 || stats.activeDays < 2
                  ? '一路看下来，“$topToken”已经不止一次出现，开始像一个重复主题了。'
                  : '一路看下来，“$topToken”已经不止一次地出现，正在慢慢形成稳定模式。',
          signalLevel: stableOrRepeated,
        ),
      ],
      frictions: [
        JourneySignalItemModel(
          name: '持续性的摩擦',
          summary: stats.entryCount <= 1
              ? '现在还只是一个初步摩擦点，先继续看它会不会在别的场景里再出现。'
              : stats.entryCount < 4 || stats.activeDays < 2
                  ? '这段时间里，有些消耗已经不是一次性的，而是在开始重复回来。'
                  : '这段时间里，某些同类问题已经不是一次性，而是在慢慢累积成稳定摩擦。',
          signalLevel: weakOrRepeated,
        ),
      ],
      desires: [
        JourneySignalItemModel(
          name: '一个恢复线索',
          summary: _recoverySummary(stats),
          signalLevel: weakOrRepeated,
        ),
      ],
      experiments: [
        _fallbackExperimentItem(stats, weakOrRepeated),
      ],
    );
  }

  List<JourneySignalItemModel> _experimentItems(
    List<JourneySignalItemModel> generated,
    _JourneyStats stats,
  ) {
    if (stats.experimentHistory.isEmpty) return generated;
    final latest = stats.experimentHistory.first;
    return [
      JourneySignalItemModel(
        name: '最近一次实验调整',
        summary:
            '“${latest.title}”现在是 ${_experimentStatusText(latest.status)}。${_feedbackText(latest.feedbackText)}可以把它当作一个生活设计来回看：这个设计有没有帮你省一点力。',
        signalLevel: 'weak_signal',
      ),
    ];
  }

  JourneySignalItemModel _fallbackExperimentItem(
    _JourneyStats stats,
    String signalLevel,
  ) {
    if (stats.experimentHistory.isNotEmpty) {
      final latest = stats.experimentHistory.first;
      return JourneySignalItemModel(
        name: '最近一次实验调整',
        summary:
            '“${latest.title}”现在是 ${_experimentStatusText(latest.status)}。${_feedbackText(latest.feedbackText)}可以把它当作一个生活设计来回看：这个设计有没有帮你省一点力。',
        signalLevel: signalLevel,
      );
    }
    return JourneySignalItemModel(
      name: '一个实验调整记录',
      summary: stats.entryCount <= 1
          ? '现在还太早，不过之后会更容易看见什么正在慢慢对你起作用。'
          : '继续记录下去，会更容易看见什么做法不是偶然有效，而是在慢慢变得有帮助。',
      signalLevel: signalLevel,
    );
  }

  String _recoverySummary(_JourneyStats stats) {
    if (stats.topPositiveSignals.isNotEmpty) {
      return '最近反复出现的恢复线索是“${stats.topPositiveSignals.first}”，可以先把它当作轻一点的观察方向。';
    }
    if (stats.topEnergyLoads.contains('restoring') ||
        stats.topEnergyLoads.contains('recovery')) {
      return '记录里已经出现一些恢复感，先看看它通常和什么场景一起出现。';
    }
    if (stats.totalDays <= 1) {
      return '现在还只是一个很轻的方向感，继续记录会更清楚。';
    }
    return '记录已经跨越 ${stats.totalDays} 天，一些让你稍微省力的线索会逐渐更清楚。';
  }

  String _experimentStatusText(String status) {
    switch (status) {
      case 'saved':
        return '已保存，之后可以再试';
      case 'skipped':
        return '这次先不看，也会作为回看背景保留';
      case 'tried':
        return '已经试过，可以继续看它是否省力';
      case 'not_helpful':
        return '这次帮助不明显';
      case 'adjusted':
        return '已经提供了可学习的调整线索';
      default:
        return '一个可以试试的方向';
    }
  }

  String _softJourneyText(String input) {
    return input
        .replaceAll('长期问题', '长期线索')
        .replaceAll('严重', '值得留意')
        .replaceAll('失败', '帮助不明显')
        .replaceAll('你应该', '可以先')
        .replaceAll('必须', '可以试试')
        .replaceAll('完成', '试一小步');
  }

  String _readableToken(String token) {
    final normalized = token
        .replaceAll(RegExp(r'^[\[\("“]+|[\]\)"”]+$'), '')
        .replaceAll('_', ' ')
        .trim()
        .toLowerCase();
    const labels = {
      'planning': '安排',
      'work': '工作',
      'relationship': '关系',
      'relations': '关系',
      'boundary': '边界',
      'boundaries': '边界',
      'recovery': '恢复',
      'rest': '休息',
      'sleep': '睡眠',
      'body': '身体',
      'energy': '能量',
      'attention': '注意力',
      'switching': '切换',
      'schedule': '日程',
      'schedule density': '安排密度',
      'care load': '照顾负荷',
      'limited buffer': '缓冲不足',
      'buffer': '缓冲',
      'weather': '天气',
      'commute': '通勤',
      'home': '家里',
      'daily friction': '日常摩擦',
      'daily life': '日常生活',
    };
    return labels[normalized] ?? token.trim();
  }

  String _feedbackText(String? feedbackText) {
    final text = feedbackText?.trim();
    if (text == null || text.isEmpty) {
      return '没有反馈也没关系，不会影响长期回看。';
    }
    return '反馈是：$text。';
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

    final today = _dateOnly(DateTime.now());
    await prefs.setString('local_app_started_date', today.toIso8601String());
    return today;
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
}

class _JourneyStats {
  final List<Map<String, dynamic>> entries;
  final List<Map<String, dynamic>> signalEntries;
  final List<String> topTokens;
  final List<String> topScenes;
  final List<String> topFrictions;
  final List<String> topEnergyLoads;
  final List<String> topPositiveSignals;
  final int totalDays;
  final int activeDays;
  final int entryCount;
  final List<LifeExperimentModel> experimentHistory;
  final List<Map<String, dynamic>> experimentEntries;
  final List<JourneyTraceModel> journeyTraces;
  final List<Map<String, dynamic>> traceEntries;
  final List<JourneyObservationModel> observations;
  final List<Map<String, dynamic>> observationEntries;
  final String monthKey;
  final JourneyPeriodFactsModel periodFacts;

  _JourneyStats({
    required this.entries,
    required this.signalEntries,
    required this.topTokens,
    required this.topScenes,
    required this.topFrictions,
    required this.topEnergyLoads,
    required this.topPositiveSignals,
    required this.totalDays,
    required this.activeDays,
    required this.entryCount,
    required this.experimentHistory,
    required this.experimentEntries,
    required this.journeyTraces,
    required this.traceEntries,
    this.observations = const [],
    this.observationEntries = const [],
    required this.monthKey,
    required this.periodFacts,
  });

  _JourneyStats copyWith({
    List<JourneyObservationModel>? observations,
  }) {
    final nextObservations = observations ?? this.observations;
    final nextObservationEntries = nextObservations.map((observation) {
      return <String, dynamic>{
        'id': observation.id,
        'source_type': 'observation',
        'content': observation.text,
        'status': observation.status,
        'local_date': observation.localDate,
      };
    }).toList(growable: false);
    return _JourneyStats(
      entries: [
        ...entries.where((entry) => entry['source_type'] != 'observation'),
        ...nextObservationEntries,
      ],
      signalEntries: signalEntries,
      topTokens: topTokens,
      topScenes: topScenes,
      topFrictions: topFrictions,
      topEnergyLoads: topEnergyLoads,
      topPositiveSignals: topPositiveSignals,
      totalDays: totalDays,
      activeDays: activeDays,
      entryCount: entryCount,
      experimentHistory: experimentHistory,
      experimentEntries: experimentEntries,
      journeyTraces: journeyTraces,
      traceEntries: traceEntries,
      observations: nextObservations,
      observationEntries: nextObservationEntries,
      monthKey: monthKey,
      periodFacts: periodFacts,
    );
  }
}

class _JourneyDayAccumulator {
  final String localDate;
  int signalCount = 0;
  final Map<String, int> energyStateCounts = {
    'draining': 0,
    'steady': 0,
    'ease': 0,
    'recovery': 0,
    'boundary_buffer': 0,
  };
  int smallExperimentAttemptCount = 0;
  int goalFeedbackCount = 0;

  _JourneyDayAccumulator(this.localDate);

  JourneyDayFactModel toModel() => JourneyDayFactModel(
        localDate: localDate,
        signalCount: signalCount,
        energyStateCounts: Map.unmodifiable(energyStateCounts),
        smallExperimentAttemptCount: smallExperimentAttemptCount,
        goalFeedbackCount: goalFeedbackCount,
      );
}

class _JourneyTrackAccumulator {
  final String subjectId;
  final String kind;
  final String title;
  int attemptCount = 0;
  int feedbackCount = 0;
  int roundReviewCount = 0;
  int weeklyReviewCount = 0;
  int wholeRoundReviewCount = 0;
  String latestResult = '';
  String latestLocalDate = '';
  DateTime? _latestTimestamp;
  String _latestIdentity = '';

  _JourneyTrackAccumulator({
    required this.subjectId,
    required this.kind,
    required this.title,
  });

  void observe(FeedbackEventModel event) {
    final timestamp = event.createdAt ?? event.occurredAt ?? DateTime(0);
    if (_latestTimestamp == null ||
        timestamp.isAfter(_latestTimestamp!) ||
        (timestamp == _latestTimestamp &&
            event.id.compareTo(_latestIdentity) > 0)) {
      _latestTimestamp = timestamp;
      _latestIdentity = event.id;
      latestResult = event.effect?.trim().isNotEmpty == true
          ? event.effect!.trim()
          : event.status;
      latestLocalDate = event.localDate;
    }
  }

  JourneyExperimentTrackModel toModel() => JourneyExperimentTrackModel(
        subjectId: subjectId,
        kind: kind,
        title: title,
        attemptCount: attemptCount,
        feedbackCount: feedbackCount,
        roundReviewCount: roundReviewCount,
        weeklyReviewCount: weeklyReviewCount,
        wholeRoundReviewCount: wholeRoundReviewCount,
        latestResult: latestResult,
        latestLocalDate: latestLocalDate,
      );
}
