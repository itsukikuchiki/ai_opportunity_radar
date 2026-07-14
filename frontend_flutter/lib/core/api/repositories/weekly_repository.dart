import 'package:shared_preferences/shared_preferences.dart';

import '../../backup/cloud_backup_sync_service.dart';
import '../../eligibility/signal_eligibility_service.dart';
import '../../local/local_capture_repository.dart';
import '../../local/local_experiment_candidate_repository.dart';
import '../../local/local_feedback_event_repository.dart';
import '../../local/local_life_experiment_repository.dart';
import '../../local/local_pipeline_run_repository.dart';
import '../../local/local_phase3_plus_repository.dart';
import '../../local/local_weekly_snapshot_repository.dart';
import '../../models/feedback_event_models.dart';
import '../../models/today_models.dart';
import '../../models/weekly_models.dart';
import '../../preferences/focus_domains.dart';
import '../../readiness/report_readiness.dart';
import 'ai_repository.dart';

typedef WeeklyFocusAreaLoader = Future<String?> Function();
typedef InstallationDateLoader = Future<DateTime> Function();
typedef WeeklyNowLoader = DateTime Function();

class WeeklyRepository {
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
      return WeeklyInsightModel(
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
      return WeeklyInsightModel(
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
      return hydrated;
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

    return generated;
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
    return aiRepository.generateWeeklyReflect(
      weekly: weekly,
      focusArea: focusArea,
    );
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
    final lifeRepo = localLifeExperimentRepository;
    if (lifeRepo == null) return null;

    final experiment = experimentId.startsWith('cand_')
        ? await _experimentCandidateRepository.updateStatus(
            candidateId: experimentId,
            status: 'skipped',
          )
        : await lifeRepo.updateStatus(
            experimentId: experimentId,
            status: 'skipped',
            feedbackText: 'Skipped for now',
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
    );
    if (feedback != null) cloudBackupSyncService?.markDataChanged();
    return localLifeExperimentRepository?.updateDetails(
      experimentId: resolvedExperimentId,
      feedbackText: feedbackText,
    );
  }

  Future<LifeExperimentModel?> updateLifeExperimentDetails({
    required String experimentId,
    required String title,
    required String hypothesis,
    required String suggestedAction,
  }) async {
    final adopted = experimentId.startsWith('cand_')
        ? await saveLifeExperiment(experimentId)
        : null;
    final resolvedExperimentId = adopted?.id ?? experimentId;
    final experiment = await localLifeExperimentRepository?.updateDetails(
      experimentId: resolvedExperimentId,
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
        : ' 上一轮反馈会作为下次调整的背景：$feedbackNote';

    await _experimentCandidateRepository.ensureWeeklyCandidate(
      localUserId: localUserId,
      weekStart: weekly.weekStart,
      weekEnd: weekly.weekEnd,
      title: structure.onePattern,
      hypothesis:
          '如果这周先轻轻调整“${structure.onePattern}”，可能会帮你省一点力。$hypothesisSuffix',
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
    );
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
          fallbackName: '本周最消耗的一个模式',
          fallbackSummary: '这周先只看一个最明显的重复方向，其他内容先放在观察区。',
        ),
        frictions: _oneItem(
          generated.frictions,
          fallbackName: '本周先留意的消耗点',
          fallbackSummary: '它不代表你哪里做错了，只是这周比较值得少量调整的地方。',
        ),
        bestAction: _softExperimentText(generated.bestAction),
        opportunitySnapshot: _withWeeklyMetadata(
          generated.opportunitySnapshot,
          inclusionSummary: inclusionSummary,
        ),
        feedbackSubmitted: generated.feedbackSubmitted,
        chartData: generated.chartData.isNotEmpty
            ? generated.chartData
            : stats.chartData,
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
          fallbackName: '这周先冒头的线索',
        ),
        fallbackName: '这周先冒头的线索',
        fallbackSummary: '记录还不多，但已经能看见一个开始重复的方向。',
      ),
      frictions: _oneItem(
        _lightenItems(
          generated.frictions,
          fallbackName: '这周先看到的消耗点',
        ),
        fallbackName: '这周先看到的消耗点',
        fallbackSummary: '现在更适合先轻轻看着，还不急着下太重的判断。',
      ),
      bestAction: _softExperimentText(generated.bestAction),
      opportunitySnapshot: _withWeeklyMetadata(
        generated.opportunitySnapshot ??
            const {
              'name': '先把线索留住',
              'summary': '现在更适合先继续收集线索，等轮廓再清楚一点，再判断值不值得进一步整理。',
            },
        inclusionSummary: inclusionSummary,
      ),
      feedbackSubmitted: generated.feedbackSubmitted,
      chartData: generated.chartData.isNotEmpty
          ? generated.chartData
          : stats.chartData,
    );
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
    final topToken = stats.topTokens.isEmpty ? '本周记录' : stats.topTokens.first;
    final peakDay = _resolvePeakDay(stats.dayCounts);
    final patternHint = _deriveWeeklyIllustrationHint(topToken);
    final frictionHint = _deriveWeeklyIllustrationHint(
      '$topToken $peakDay 消耗 负担',
      fallback: '任务堆积，开始变困难',
    );

    if (isLightWeekly) {
      return WeeklyInsightModel(
        weekStart: weekStart,
        weekEnd: weekEnd,
        status: 'light_ready',
        keyInsight: '这周可以先轻轻看一个线索：目前最明显的是“$topToken”。',
        patterns: [
          {
            'name': '这周先冒头的线索',
            'summary': '记录还不多，但已经能看见一个开始重复的方向。',
            'illustration_hint': patternHint,
          },
        ],
        frictions: [
          {
            'name': '这周先看到的消耗点',
            'summary': '现在更适合先轻轻看着，还不急着下太重的判断。',
            'illustration_hint': frictionHint,
          },
        ],
        bestAction: '下周先试一个很小的方向：同类场景再出现时，只补一句它发生在哪里。',
        opportunitySnapshot: _withWeeklyMetadata(
          const {
            'name': '先把线索留住',
            'summary': '也可以留意一下哪些时刻让你稍微恢复一点，它们可能是下周的小线索。',
            'illustration_hint': '只是观察也有帮助',
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
      keyInsight: '这周最值得先看的，是围绕“$topToken”反复出现的一个消耗模式；$peakDay 的信号更密集。',
      patterns: [
        {
          'name': '围绕“$topToken”的重复模式',
          'summary': '这周先只看这个最明显的方向，其他线索可以继续留在时间线里。',
          'illustration_hint': patternHint,
        },
      ],
      frictions: [
        {
          'name': '本周的主要消耗',
          'summary': '当前最大的摩擦，更像是同类事情反复回来，而不是单次事件。',
          'illustration_hint': frictionHint,
        },
      ],
      bestAction: '下周只试一个小实验：同类情况出现时，用一句话补记它发生在什么场景。',
      opportunitySnapshot: _withWeeklyMetadata(
        const {
          'name': '把重复信号固定下来',
          'summary': '也留意一下哪些时刻让状态稍微往回收一点，它们可能是恢复线索。',
          'illustration_hint': '只是观察也有帮助',
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
      return '这周可以先轻轻看一个线索：目前最明显的是“$topToken”。';
    }
    return '这周已经开始有线索冒出来了，不过现在更适合先轻轻看着。';
  }

  List<dynamic> _lightenItems(
    List<dynamic> items, {
    required String fallbackName,
  }) {
    if (items.isEmpty) {
      return [
        {
          'name': fallbackName,
          'summary': '记录还不多，但已经能看见一个开始重复的方向。',
          'illustration_hint': _deriveWeeklyIllustrationHint(fallbackName),
        },
      ];
    }

    return items.take(2).map((item) {
      if (item is Map<String, dynamic>) {
        final name = (item['name'] as String?) ?? fallbackName;
        final summary = (item['summary'] as String?) ?? '线索已经出现了，但还不适合下太重的判断。';
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
        final summary = item['summary']?.toString() ?? '线索已经出现了，但还不适合下太重的判断。';
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
        'summary': '线索已经出现了，但还不适合下太重的判断。',
        'illustration_hint': _deriveWeeklyIllustrationHint(fallbackName),
      };
    }).toList();
  }

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
    if (_containsAny(text, const ['有效', '稳定'])) return '小行动有效，节奏开始稳定';
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
      return '下周可以试试一个很小的实验：同类场景出现时，只补一句它发生在哪里。';
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
    if (dayCounts.isEmpty) return '这周';
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
