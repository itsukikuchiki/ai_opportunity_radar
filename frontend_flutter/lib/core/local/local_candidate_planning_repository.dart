import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../api/repositories/energy_budget_repository.dart';
import '../eligibility/signal_eligibility_service.dart';
import '../i18n/app_locale_text.dart';
import '../models/advanced_energy_boundary_models.dart';
import '../models/candidate_models.dart';
import '../models/energy_budget_models.dart';
import '../models/experiment_evaluation_models.dart';
import '../models/feedback_event_models.dart';
import '../models/phase3_plus_models.dart';
import '../models/today_models.dart';
import '../models/weekly_models.dart';
import '../policies/planning_content_edit_policy.dart';
import '../preferences/focus_domains.dart';
import '../state/app_data_refresh_coordinator.dart';
import 'external_energy_hint_store.dart';
import 'local_capture_repository.dart';
import 'local_cache_invalidation_repository.dart';
import 'local_database.dart';
import 'local_feedback_event_repository.dart';
import 'local_life_experiment_repository.dart';
import 'local_plan_content_version_repository.dart';
import 'local_trace_link_repository.dart';

typedef DailyCandidateGenerator = Future<List<MicroActionCandidateDraft>>
    Function(CandidatePlanningContext context);
typedef WeeklyCandidateGenerator = Future<List<ExperimentCandidateDraft>>
    Function(CandidatePlanningContext context);
typedef DeepPlanningReferenceLoader = Future<DeepPlanningReference?> Function(
  CandidateGateState gate,
);

enum _FeedbackPlanningMode {
  neutral('neutral'),
  reinforce('reinforce_helpful'),
  reduce('reduce_difficult'),
  redirect('redirect_explicit_skip');

  final String storageValue;
  const _FeedbackPlanningMode(this.storageValue);
}

class _PlanProjectionMissing implements Exception {
  const _PlanProjectionMissing();
}

/// Canonical local candidate/adoption/progress data layer.
///
/// Generation remains injected so this repository does not couple storage to
/// a model provider. A caller can observe `regenerating` immediately, await
/// its generator, and receive an idempotent replacement read model. Adopted
/// objects are never overwritten by source regeneration.
class LocalCandidatePlanningRepository {
  static const requiredSignalCount = 3;
  static const maxCandidatesPerGroup = 3;
  static const _nextWeekSmallTryKind = 'next_week_small_try';

  final LocalDatabase localDatabase;
  final LocalCaptureRepository localCaptureRepository;
  final LocalLifeExperimentRepository localLifeExperimentRepository;
  late final LocalFeedbackEventRepository feedbackEventRepository;
  late final LocalPlanContentVersionRepository planContentVersionRepository;
  late final EnergyBudgetRepository energyBudgetRepository;
  late final Future<List<String>> Function() focusDomainIdsLoader;
  late final Future<AdvancedEnergyExternalSummary?> Function()
      externalEnergySummaryLoader;
  late final DeepPlanningReferenceLoader deepPlanningReferenceLoader;
  final SignalEligibilityService eligibilityService;
  final String localUserId;
  final DateTime Function() nowLoader;
  final Uuid _uuid = const Uuid();
  final StreamController<CandidateGenerationState> _stateEvents =
      StreamController<CandidateGenerationState>.broadcast();
  bool _disposed = false;
  late final StreamSubscription<CandidateInvalidationNotice>
      _invalidationSubscription;
  late final StreamSubscription<AppDataMutation> _planningInputSubscription;

  LocalCandidatePlanningRepository({
    required this.localDatabase,
    required this.localCaptureRepository,
    required this.localLifeExperimentRepository,
    required this.localUserId,
    LocalFeedbackEventRepository? feedbackEventRepository,
    LocalPlanContentVersionRepository? planContentVersionRepository,
    EnergyBudgetRepository? energyBudgetRepository,
    Future<List<String>> Function()? focusDomainIdsLoader,
    Future<AdvancedEnergyExternalSummary?> Function()?
        externalEnergySummaryLoader,
    DeepPlanningReferenceLoader? deepPlanningReferenceLoader,
    SignalEligibilityService? eligibilityService,
    DateTime Function()? nowLoader,
  })  : eligibilityService =
            eligibilityService ?? const SignalEligibilityService(),
        nowLoader = nowLoader ?? DateTime.now {
    this.feedbackEventRepository =
        feedbackEventRepository ?? LocalFeedbackEventRepository(localDatabase);
    this.planContentVersionRepository = planContentVersionRepository ??
        LocalPlanContentVersionRepository(localDatabase);
    this.energyBudgetRepository = energyBudgetRepository ??
        EnergyBudgetRepository(
          localCaptureRepository: localCaptureRepository,
          localLifeExperimentRepository: localLifeExperimentRepository,
          feedbackEventRepository: this.feedbackEventRepository,
          localUserId: localUserId,
          eligibilityService: this.eligibilityService,
          nowLoader: this.nowLoader,
        );
    this.focusDomainIdsLoader =
        focusDomainIdsLoader ?? _loadPersistedFocusDomainIds;
    this.externalEnergySummaryLoader =
        externalEnergySummaryLoader ?? _loadPersistedExternalEnergySummary;
    this.deepPlanningReferenceLoader =
        deepPlanningReferenceLoader ?? _loadStoredDeepPlanningReference;
    _invalidationSubscription = CandidateInvalidationBus.stream
        .where((notice) => identical(notice.localDatabase, localDatabase))
        .listen((notice) {
      final kind =
          notice.candidateKind == CandidateKind.lifeExperiment.storageValue
              ? CandidateKind.lifeExperiment
              : CandidateKind.microAction;
      unawaited(
        _emitState(kind, notice.periodStart, notice.periodEnd),
      );
    });
    _planningInputSubscription = AppDataMutationBus.stream
        .where((mutation) =>
            mutation.kind == AppDataMutationKind.focusDomains ||
            (mutation.kind == AppDataMutationKind.externalEnergyHints &&
                !mutation.reason.startsWith('calendar_')))
        .listen((mutation) {
      unawaited(_invalidateCurrentPlanningContexts(mutation.reason));
    });
  }

  Future<void> dispose() async {
    _disposed = true;
    await _invalidationSubscription.cancel();
    await _planningInputSubscription.cancel();
    await _stateEvents.close();
  }

  Future<CandidateGateState> dailyGate(DateTime day) async {
    final localDay = _dateOnly(day.toLocal());
    final key = _dateKey(localDay);
    final signals = await localCaptureRepository.listSignalCardsBetween(
      startDate: key,
      endDate: key,
    );
    final eligible = _distinctEligible(
      signals,
      SignalEligibilityStage.daily,
    );
    return CandidateGateState(
      kind: CandidateKind.microAction,
      periodStart: key,
      periodEnd: key,
      eligibleSignalCount: eligible.length,
      eligibleSignalCardIds: eligible.map(_signalId).toList(growable: false),
    );
  }

  Future<CandidateGateState> weeklyGate(DateTime day) async {
    final start = _startOfWeek(day.toLocal());
    final end = start.add(const Duration(days: 6));
    final signals = await localCaptureRepository.listSignalCardsBetween(
      startDate: _dateKey(start),
      endDate: _dateKey(end),
    );
    final eligible = _distinctEligible(
      signals,
      SignalEligibilityStage.weekly,
    );
    return CandidateGateState(
      kind: CandidateKind.lifeExperiment,
      periodStart: _dateKey(start),
      periodEnd: _dateKey(end),
      eligibleSignalCount: eligible.length,
      eligibleSignalCardIds: eligible.map(_signalId).toList(growable: false),
    );
  }

  Future<CandidateSnapshot<MicroActionCandidateModel>> dailyCandidateSnapshot(
      DateTime day) async {
    final gate = await dailyGate(day);
    final generation = await getGenerationState(
      kind: CandidateKind.microAction,
      periodStart: gate.periodStart,
      periodEnd: gate.periodEnd,
      eligibleSignalCount: gate.eligibleSignalCount,
    );
    final candidates = generation.canDisplayCandidates
        ? await listDailyMicroActionCandidates(day)
        : const <MicroActionCandidateModel>[];
    return CandidateSnapshot(
      gate: gate,
      generation: gate.isOpen
          ? generation
          : CandidateGenerationState(
              kind: CandidateKind.microAction,
              periodStart: gate.periodStart,
              periodEnd: gate.periodEnd,
              status: CandidateGenerationStatus.gated,
              eligibleSignalCount: gate.eligibleSignalCount,
              updatedAt: generation.updatedAt,
            ),
      candidates: candidates,
    );
  }

  Future<CandidateSnapshot<ExperimentCandidateRecord>> weeklyCandidateSnapshot(
      DateTime day) async {
    final gate = await weeklyGate(day);
    final generation = await getGenerationState(
      kind: CandidateKind.lifeExperiment,
      periodStart: gate.periodStart,
      periodEnd: gate.periodEnd,
      eligibleSignalCount: gate.eligibleSignalCount,
    );
    final candidates = generation.canDisplayCandidates
        ? await listWeeklyExperimentCandidates(day)
        : const <ExperimentCandidateRecord>[];
    return CandidateSnapshot(
      gate: gate,
      generation: gate.isOpen
          ? generation
          : CandidateGenerationState(
              kind: CandidateKind.lifeExperiment,
              periodStart: gate.periodStart,
              periodEnd: gate.periodEnd,
              status: CandidateGenerationStatus.gated,
              eligibleSignalCount: gate.eligibleSignalCount,
              updatedAt: generation.updatedAt,
            ),
      candidates: candidates,
    );
  }

  /// A combined, future-only selection surface. It deliberately reads this
  /// week's source range while assigning the small tries to next Monday; no
  /// selected item is eligible for Today before that date.
  Future<NextWeekPlanCandidateSnapshot> nextWeekPlanCandidateSnapshot(
    DateTime day,
  ) async {
    final gate = await weeklyGate(day);
    final start = _startOfWeek(day.toLocal()).add(const Duration(days: 7));
    final end = start.add(const Duration(days: 6));
    return NextWeekPlanCandidateSnapshot(
      gate: gate,
      targetWeekStart: _dateKey(start),
      targetWeekEnd: _dateKey(end),
      smallTryCandidates: gate.isOpen
          ? await listNextWeekSmallTryCandidates(day)
          : const <MicroActionCandidateModel>[],
      goalCandidates: gate.isOpen
          ? await listWeeklyExperimentCandidates(day)
          : const <ExperimentCandidateRecord>[],
    );
  }

  Future<List<MicroActionCandidateModel>> listNextWeekSmallTryCandidates(
    DateTime day,
  ) async {
    final db = await localDatabase.database;
    final sourceWeekStart = _dateKey(_startOfWeek(day.toLocal()));
    final groups = await db.query(
      'candidate_groups',
      columns: const ['id'],
      where: '''
        local_user_id = ? AND candidate_kind = ? AND period_start = ?
        AND status = ? AND dirty = 0 AND is_stale = 0
      ''',
      whereArgs: [
        localUserId,
        _nextWeekSmallTryKind,
        sourceWeekStart,
        'ready',
      ],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    if (groups.isEmpty) return const [];
    final rows = await db.query(
      'micro_action_candidates',
      where: 'candidate_group_id = ? AND dirty = 0 AND is_stale = 0',
      whereArgs: [groups.first['id']],
      orderBy: 'rank ASC',
      limit: maxCandidatesPerGroup,
    );
    return rows.map(_mapMicroCandidate).toList(growable: false);
  }

  /// Persists explicitly generated weekly small-try candidates.  This is a
  /// separate group from the daily candidates so a future selection cannot be
  /// replaced by the next daily Signal refresh.
  Future<List<MicroActionCandidateModel>> replaceNextWeekSmallTryCandidates({
    required DateTime day,
    required List<MicroActionCandidateDraft> drafts,
    String? expectedSourceHash,
  }) async {
    final gate = await weeklyGate(day);
    final context = await _planningContextForGate(gate);
    if (!gate.isOpen ||
        (expectedSourceHash != null &&
            context.sourceHash != expectedSourceHash)) {
      return const [];
    }
    final sourceHash = 'next_week_small_try:${context.sourceHash}';
    final db = await localDatabase.database;
    final existing = await db.query(
      'candidate_groups',
      columns: const ['id'],
      where: '''
        local_user_id = ? AND candidate_kind = ? AND period_start = ?
        AND source_hash = ? AND status = ? AND dirty = 0 AND is_stale = 0
      ''',
      whereArgs: [
        localUserId,
        _nextWeekSmallTryKind,
        gate.periodStart,
        sourceHash,
        'ready',
      ],
      limit: 1,
    );
    if (existing.isNotEmpty) return listNextWeekSmallTryCandidates(day);

    final now = nowLoader().toUtc();
    final groupId = 'nws_${_uuid.v4().replaceAll('-', '').substring(0, 16)}';
    final targetMonday =
        _startOfWeek(day.toLocal()).add(const Duration(days: 7));
    final allowedIds = gate.eligibleSignalCardIds.toSet();
    final limited = drafts
        .where((draft) => draft.title.trim().isNotEmpty)
        .take(maxCandidatesPerGroup)
        .toList(growable: false);
    await db.transaction((txn) async {
      final previous = await txn.query(
        'candidate_groups',
        columns: const ['id'],
        where: '''
          local_user_id = ? AND candidate_kind = ? AND period_start = ?
          AND status != ?
        ''',
        whereArgs: [
          localUserId,
          _nextWeekSmallTryKind,
          gate.periodStart,
          'stale'
        ],
      );
      if (previous.isNotEmpty) {
        final ids = previous.map((row) => row['id'] as String).toList();
        final placeholders = List.filled(ids.length, '?').join(', ');
        await txn.update(
          'candidate_groups',
          {
            'status': 'stale',
            'dirty': 1,
            'is_stale': 1,
            'stale_reason': 'superseded_by_source_change',
            'invalidated_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          },
          where: 'id IN ($placeholders) AND status IN (?, ?)',
          whereArgs: [...ids, 'ready', 'regenerating'],
        );
        await txn.update(
          'micro_action_candidates',
          {
            'dirty': 1,
            'is_stale': 1,
            'stale_reason': 'superseded_by_source_change',
            'invalidated_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          },
          where: '''
            candidate_group_id IN ($placeholders)
            AND status IN (?, ?, ?)
          ''',
          whereArgs: [...ids, 'generated', 'edited', 'dismissed'],
        );
      }
      await txn.insert(
        'candidate_groups',
        {
          ..._groupRow(
            id: groupId,
            gate: gate,
            sourceHash: sourceHash,
            status: 'ready',
            now: now,
          ),
          'candidate_kind': _nextWeekSmallTryKind,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      for (var index = 0; index < limited.length; index++) {
        final draft = limited[index];
        final linked = draft.linkedSignalCardIds.isEmpty
            ? gate.eligibleSignalCardIds
            : draft.linkedSignalCardIds.where(allowedIds.contains).toList();
        await txn.insert(
          'micro_action_candidates',
          {
            'id': _candidateId('nwmac', groupId, index + 1),
            'candidate_group_id': groupId,
            'local_user_id': localUserId,
            'local_date': _dateKey(targetMonday),
            'rank': index + 1,
            'title': draft.title.trim(),
            'reason': _encodeMicroCandidateReason(
              draft.reason,
              draft.energyAdaptationExplanation,
            ),
            'difficulty': draft.recommendedIntensity.trim().isEmpty
                ? draft.difficulty
                : draft.recommendedIntensity,
            'linked_signal_card_ids_json': jsonEncode(linked),
            'focus_domain_ids_json': jsonEncode(
              draft.focusDomainIds.isEmpty
                  ? context.focusDomainIds
                  : draft.focusDomainIds,
            ),
            'status': 'generated',
            'adopted_micro_action_id': null,
            'source_hash': sourceHash,
            'dirty': 0,
            'is_stale': 0,
            'stale_reason': null,
            'invalidated_at': null,
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    return listNextWeekSmallTryCandidates(day);
  }

  Future<List<MicroActionCandidateModel>> listDailyMicroActionCandidates(
    DateTime day,
  ) async {
    final db = await localDatabase.database;
    final key = _dateKey(day.toLocal());
    final groups = await db.query(
      'candidate_groups',
      columns: const ['id'],
      where: '''
        local_user_id = ? AND candidate_kind = ? AND period_start = ?
        AND status = ? AND dirty = 0 AND is_stale = 0
      ''',
      whereArgs: [
        localUserId,
        CandidateKind.microAction.storageValue,
        key,
        'ready'
      ],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    if (groups.isEmpty) return const [];
    final rows = await db.query(
      'micro_action_candidates',
      where: 'candidate_group_id = ? AND dirty = 0 AND is_stale = 0',
      whereArgs: [groups.first['id']],
      orderBy: 'rank ASC',
      limit: maxCandidatesPerGroup,
    );
    return rows.map(_mapMicroCandidate).toList(growable: false);
  }

  Future<List<ExperimentCandidateRecord>> listWeeklyExperimentCandidates(
    DateTime day,
  ) async {
    final db = await localDatabase.database;
    final weekStart = _dateKey(_startOfWeek(day.toLocal()));
    final groups = await db.query(
      'candidate_groups',
      columns: const ['id'],
      where: '''
        local_user_id = ? AND candidate_kind = ? AND period_start = ?
        AND status = ? AND dirty = 0 AND is_stale = 0
      ''',
      whereArgs: [
        localUserId,
        CandidateKind.lifeExperiment.storageValue,
        weekStart,
        'ready',
      ],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    if (groups.isEmpty) return const [];
    final rows = await db.query(
      'experiment_candidates',
      where: 'candidate_group_id = ? AND dirty = 0 AND is_stale = 0',
      whereArgs: [groups.first['id']],
      orderBy: 'candidate_rank ASC',
      limit: maxCandidatesPerGroup,
    );
    return rows.map(_mapExperimentCandidate).toList(growable: false);
  }

  /// Returns the user's saved "consider / observe" small-try candidates.
  /// Stale rows are intentionally included: they are historical observation
  /// snapshots, not active generation results and never enter Today progress.
  Future<List<MicroActionCandidateModel>> listConsideringMicroActionCandidates({
    int limit = 500,
    int offset = 0,
  }) async {
    final db = await localDatabase.database;
    final rows = await db.query(
      'micro_action_candidates',
      where: 'local_user_id = ? AND decision_status = ?',
      whereArgs: [localUserId, CandidateDecisionStatus.considering.name],
      orderBy: 'updated_at DESC, created_at DESC',
      limit: limit.clamp(1, 500),
      offset: offset < 0 ? 0 : offset,
    );
    return rows.map(_mapMicroCandidate).toList(growable: false);
  }

  /// Returns the user's saved "consider / observe" goal candidates. As with
  /// small tries, source-stale rows remain readable but cannot be adopted.
  Future<List<ExperimentCandidateRecord>> listConsideringExperimentCandidates({
    int limit = 500,
    int offset = 0,
  }) async {
    final db = await localDatabase.database;
    final rows = await db.query(
      'experiment_candidates',
      where: 'local_user_id = ? AND decision_status = ?',
      whereArgs: [localUserId, CandidateDecisionStatus.considering.name],
      orderBy: 'updated_at DESC, created_at DESC',
      limit: limit.clamp(1, 500),
      offset: offset < 0 ? 0 : offset,
    );
    return rows.map(_mapExperimentCandidate).toList(growable: false);
  }

  /// Persists the second explicit candidate decision without creating a
  /// canonical plan. Candidate ids may span both tracks; adopted or stale
  /// candidates are never downgraded. The return value is the number of rows
  /// changed across both candidate tables.
  Future<int> markCandidatesConsidering(
    Iterable<String> candidateIds,
  ) async {
    final ids = _normalizedIds(candidateIds);
    if (ids.isEmpty) return 0;
    final db = await localDatabase.database;
    final now = nowLoader().toUtc().toIso8601String();
    final placeholders = List.filled(ids.length, '?').join(', ');
    return db.transaction<int>((txn) async {
      final microCount = await txn.update(
        'micro_action_candidates',
        {
          'decision_status': CandidateDecisionStatus.considering.name,
          'updated_at': now,
        },
        where: '''
          id IN ($placeholders)
          AND local_user_id = ?
          AND dirty = 0 AND is_stale = 0
          AND adopted_micro_action_id IS NULL
          AND decision_status != ?
        ''',
        whereArgs: [
          ...ids,
          localUserId,
          CandidateDecisionStatus.adopted.name,
        ],
      );
      final experimentCount = await txn.update(
        'experiment_candidates',
        {
          'decision_status': CandidateDecisionStatus.considering.name,
          'updated_at': now,
        },
        where: '''
          id IN ($placeholders)
          AND local_user_id = ?
          AND dirty = 0 AND is_stale = 0
          AND adopted_experiment_id IS NULL
          AND decision_status != ?
        ''',
        whereArgs: [
          ...ids,
          localUserId,
          CandidateDecisionStatus.adopted.name,
        ],
      );
      return microCount + experimentCount;
    });
  }

  Future<MicroActionCandidateModel?> updateMicroActionCandidate({
    required String candidateId,
    required String title,
  }) async {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) return null;
    final db = await localDatabase.database;
    final currentRows = await db.query(
      'micro_action_candidates',
      where: 'id = ?',
      whereArgs: [candidateId],
      limit: 1,
    );
    if (currentRows.isEmpty) return null;
    final candidate = _mapMicroCandidate(currentRows.first);
    final candidateDate = DateTime.tryParse(candidate.localDate);
    final today = _dateOnly(nowLoader().toLocal());
    if (candidateDate == null ||
        _dateOnly(candidateDate).isBefore(today) ||
        !PlanningContentEditPolicy.canEditRange(
          start: candidateDate,
          end: candidateDate,
          now: nowLoader(),
        )) {
      return null;
    }
    final now = nowLoader().toUtc().toIso8601String();
    final affected = await db.update(
      'micro_action_candidates',
      {
        'title': normalizedTitle,
        'status': 'edited',
        'updated_at': now,
      },
      where: '''
        id = ? AND dirty = 0 AND is_stale = 0
        AND status IN (?, ?)
      ''',
      whereArgs: [candidateId, 'generated', 'edited'],
    );
    if (affected == 0) return null;
    final rows = await db.query(
      'micro_action_candidates',
      where: 'id = ?',
      whereArgs: [candidateId],
      limit: 1,
    );
    return rows.isEmpty ? null : _mapMicroCandidate(rows.first);
  }

  Future<ExperimentCandidateRecord?> updateExperimentCandidate({
    required String candidateId,
    required String title,
    required String suggestedAction,
  }) async {
    final normalizedTitle = title.trim();
    final normalizedAction = suggestedAction.trim();
    if (normalizedTitle.isEmpty || normalizedAction.isEmpty) return null;
    final db = await localDatabase.database;
    final currentRows = await db.query(
      'experiment_candidates',
      where: 'id = ?',
      whereArgs: [candidateId],
      limit: 1,
    );
    if (currentRows.isEmpty) return null;
    final candidate = _mapExperimentCandidate(currentRows.first);
    final sourceStart = DateTime.tryParse(candidate.weekStart);
    final sourceEnd = DateTime.tryParse(candidate.weekEnd);
    if (sourceStart == null ||
        sourceEnd == null ||
        !PlanningContentEditPolicy.canEditRange(
          // Weekly candidates describe the following week's goal.
          start: sourceStart.add(const Duration(days: 7)),
          end: sourceEnd.add(const Duration(days: 7)),
          now: nowLoader(),
        )) {
      return null;
    }
    final now = nowLoader().toUtc().toIso8601String();
    final affected = await db.update(
      'experiment_candidates',
      {
        'title': normalizedTitle,
        'suggested_action': normalizedAction,
        'status': 'edited',
        'updated_at': now,
      },
      where: '''
        id = ? AND dirty = 0 AND is_stale = 0
        AND status IN (?, ?)
      ''',
      whereArgs: [candidateId, 'generated', 'edited'],
    );
    if (affected == 0) return null;
    final rows = await db.query(
      'experiment_candidates',
      where: 'id = ?',
      whereArgs: [candidateId],
      limit: 1,
    );
    return rows.isEmpty ? null : _mapExperimentCandidate(rows.first);
  }

  /// Changes only the current/next-week plan text. Progress feedback remains
  /// append-only and is never rewritten by this method.
  Future<MicroActionModel?> updateAdoptedMicroActionContent({
    required String microActionId,
    required String title,
    String? reason,
    int? plannedDurationMinutes,
  }) async {
    final normalizedTitle = title.trim();
    final normalizedReason = reason?.trim();
    if (normalizedTitle.isEmpty) return null;
    final db = await localDatabase.database;
    final rows = await db.query(
      'micro_actions',
      where: 'id = ?',
      whereArgs: [microActionId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final action = MicroActionModel.fromDb(rows.first);
    final nextDuration =
        plannedDurationMinutes ?? action.plannedDurationMinutes;
    _validateSmallExperimentDuration(nextDuration);
    if (!PlanningContentEditPolicy.canEditMicroAction(
      action,
      now: nowLoader(),
    )) {
      return null;
    }
    final effectiveDate = await _microActionEditEffectiveDate(action);
    if (effectiveDate == null) return null;

    final nextReason = normalizedReason != null && normalizedReason.isNotEmpty
        ? normalizedReason
        : action.reason;
    final updatedAt = nowLoader();
    final updates = <String, Object?>{
      'title': normalizedTitle,
      'updated_at': updatedAt.toUtc().toIso8601String(),
      if (normalizedReason != null && normalizedReason.isNotEmpty)
        'reason': normalizedReason,
      'planned_duration_minutes': nextDuration,
    };
    late final MicroActionModel updated;
    try {
      updated = await db.transaction((txn) async {
        await planContentVersionRepository.ensureInitialWithExecutor(
          txn,
          localUserId: action.localUserId,
          objectKind: PlanContentObjectKind.quickTry,
          objectId: action.id,
          effectiveFromLocalDate: _microActionStartDate(action),
          content: _microActionContent(action),
          createdAt: action.createdAt,
        );
        await planContentVersionRepository.appendWithExecutor(
          txn,
          localUserId: action.localUserId,
          objectKind: PlanContentObjectKind.quickTry,
          objectId: action.id,
          effectiveFromLocalDate: effectiveDate,
          content: _microActionContent(
            action,
            title: normalizedTitle,
            reason: nextReason,
            plannedDurationMinutes: nextDuration,
          ),
          createdAt: updatedAt,
        );
        final affected = await txn.update(
          'micro_actions',
          updates,
          where: 'id = ?',
          whereArgs: [microActionId],
        );
        if (affected == 0) throw const _PlanProjectionMissing();
        final updatedRows = await txn.query(
          'micro_actions',
          where: 'id = ?',
          whereArgs: [microActionId],
          limit: 1,
        );
        if (updatedRows.isEmpty) throw const _PlanProjectionMissing();
        return MicroActionModel.fromDb(updatedRows.first);
      });
    } on _PlanProjectionMissing {
      return null;
    }
    await LocalCacheInvalidationRepository(localDatabase)
        .markMicroActionChanged(
      localDate: action.progressStartDate ?? action.plannedDate ?? '',
      reason: 'micro_action_content_changed',
    );
    return updated;
  }

  /// Explicitly closes an adopted small experiment. This is deliberately separate
  /// from daily `completed` feedback: all feedback rows stay append-only and
  /// no synthetic day cell is created by finishing the lifecycle.
  Future<MicroActionModel?> completeMicroAction(String id) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) return null;
    final db = await localDatabase.database;
    final rows = await db.query(
      'micro_actions',
      where: 'id = ? AND local_user_id = ?',
      whereArgs: [normalizedId, localUserId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final before = MicroActionModel.fromDb(rows.first);
    final status = before.status.trim().toLowerCase();
    if (status == 'completed') return before;
    const completableStatuses = {
      'accepted',
      'active',
      'adjusted',
      'paused',
      'done',
    };
    final hasAdoptionEvidence = before.adoptedAt != null ||
        (before.originCandidateId?.trim().isNotEmpty ?? false);
    if (!hasAdoptionEvidence || !completableStatuses.contains(status)) {
      return null;
    }
    final completionDate = _dateKey(nowLoader().toLocal());
    final now = nowLoader().toUtc().toIso8601String();
    final affected = await db.update(
      'micro_actions',
      {
        'status': 'completed',
        'progress_end_date': completionDate,
        'updated_at': now,
      },
      where: '''
        id = ? AND local_user_id = ?
        AND status IN (?, ?, ?, ?, ?)
      ''',
      whereArgs: [
        normalizedId,
        localUserId,
        'accepted',
        'active',
        'adjusted',
        'paused',
        'done',
      ],
    );
    if (affected == 0) return null;
    final updatedRows = await db.query(
      'micro_actions',
      where: 'id = ?',
      whereArgs: [normalizedId],
      limit: 1,
    );
    if (updatedRows.isEmpty) return null;
    final completed = MicroActionModel.fromDb(updatedRows.first);
    await LocalCacheInvalidationRepository(localDatabase)
        .markMicroActionChanged(
      localDate: completed.progressStartDate ?? completed.plannedDate ?? '',
      reason: 'micro_action_lifecycle_completed',
    );
    return completed;
  }

  Future<CandidateSnapshot<MicroActionCandidateModel>>
      refreshDailyIfSourceChanged({
    required DateTime day,
    required DailyCandidateGenerator generate,
    Duration debounce = Duration.zero,
  }) async {
    final gate = await dailyGate(day);
    return _refreshDaily(gate: gate, generate: generate, debounce: debounce);
  }

  /// Local, evidence-grounded fallback used until a remote plural-candidate
  /// endpoint is available. It never bypasses the three-signal gate.
  Future<CandidateSnapshot<MicroActionCandidateModel>>
      refreshDailyWithGroundedSuggestions({
    required DateTime day,
    AppLanguage language = AppLanguage.simplifiedChinese,
    Duration debounce = Duration.zero,
  }) {
    return refreshDailyIfSourceChanged(
      day: day,
      debounce: debounce,
      generate: (gate) async => _groundedDailyDrafts(gate, language),
    );
  }

  Future<CandidateSnapshot<ExperimentCandidateRecord>>
      refreshWeeklyIfSourceChanged({
    required DateTime day,
    required WeeklyCandidateGenerator generate,
    Duration debounce = Duration.zero,
  }) async {
    final gate = await weeklyGate(day);
    return _refreshWeekly(gate: gate, generate: generate, debounce: debounce);
  }

  Future<CandidateSnapshot<ExperimentCandidateRecord>>
      refreshWeeklyWithGroundedSuggestions({
    required DateTime day,
    AppLanguage language = AppLanguage.simplifiedChinese,
    Duration debounce = Duration.zero,
  }) {
    return refreshWeeklyIfSourceChanged(
      day: day,
      debounce: debounce,
      generate: (gate) async => _groundedWeeklyDrafts(gate, language),
    );
  }

  /// Generates one mixed next-week selection set. The total number of fresh
  /// AI candidates is capped at three across small tries and goals (ongoing
  /// goals that the user may continue are intentionally a separate choice).
  /// Source changes replace only unadopted rows; planned/adopted objects stay
  /// intact through the normal candidate lifecycle.
  Future<NextWeekPlanCandidateSnapshot>
      refreshNextWeekPlanWithGroundedSuggestions({
    required DateTime day,
    AppLanguage language = AppLanguage.simplifiedChinese,
  }) async {
    final gate = await weeklyGate(day);
    if (!gate.isOpen) return nextWeekPlanCandidateSnapshot(day);
    final context = await _planningContextForGate(gate);
    final allSmallTries = await _groundedDailyDrafts(context, language);
    final allGoals = await _groundedWeeklyDrafts(context, language);
    final prefersLowerLoad =
        context.planningCapacityBand == EnergyCapacityBand.veryLow ||
            context.planningCapacityBand == EnergyCapacityBand.low;
    final smallTryCount = prefersLowerLoad ? 2 : 1;
    final goalCount = maxCandidatesPerGroup - smallTryCount;
    await replaceNextWeekSmallTryCandidates(
      day: day,
      drafts: allSmallTries.take(smallTryCount).toList(growable: false),
      expectedSourceHash: context.sourceHash,
    );
    await replaceWeeklyCandidates(
      day: day,
      drafts: allGoals.take(goalCount).toList(growable: false),
      expectedSourceHash: context.sourceHash,
      planningContext: context,
    );
    return nextWeekPlanCandidateSnapshot(day);
  }

  Future<CandidateSnapshot<MicroActionCandidateModel>> _refreshDaily({
    required CandidateGateState gate,
    required DailyCandidateGenerator generate,
    required Duration debounce,
    int sourceChangeRetry = 0,
  }) async {
    final planningContext = await _planningContextForGate(gate);
    final sourceHash = planningContext.sourceHash;
    if (!gate.isOpen) {
      await _setGated(gate, sourceHash: sourceHash);
      return dailyCandidateSnapshot(DateTime.parse(gate.periodStart));
    }
    final current = await getGenerationState(
      kind: gate.kind,
      periodStart: gate.periodStart,
      periodEnd: gate.periodEnd,
      eligibleSignalCount: gate.eligibleSignalCount,
    );
    if (current.status == CandidateGenerationStatus.ready &&
        current.sourceHash == sourceHash) {
      return dailyCandidateSnapshot(DateTime.parse(gate.periodStart));
    }
    await beginRegeneration(
      kind: gate.kind,
      periodStart: gate.periodStart,
      periodEnd: gate.periodEnd,
      sourceHash: sourceHash,
      eligibleSignalCount: gate.eligibleSignalCount,
      reason: 'signal_source_changed',
    );
    if (debounce > Duration.zero) await Future<void>.delayed(debounce);
    try {
      final drafts = await generate(planningContext);
      final latestGate = await dailyGate(DateTime.parse(gate.periodStart));
      final latestPlanningContext = await _planningContextForGate(latestGate);
      final latestSourceHash = latestPlanningContext.sourceHash;
      if (latestSourceHash != sourceHash) {
        if (sourceChangeRetry < 2) {
          return _refreshDaily(
            gate: latestGate,
            generate: generate,
            debounce: debounce,
            sourceChangeRetry: sourceChangeRetry + 1,
          );
        }
        await beginRegeneration(
          kind: latestGate.kind,
          periodStart: latestGate.periodStart,
          periodEnd: latestGate.periodEnd,
          sourceHash: latestSourceHash,
          eligibleSignalCount: latestGate.eligibleSignalCount,
          reason: 'source_changed_during_generation',
        );
        return dailyCandidateSnapshot(
          DateTime.parse(latestGate.periodStart),
        );
      }
      await replaceDailyCandidates(
        day: DateTime.parse(gate.periodStart),
        drafts: drafts,
        expectedSourceHash: sourceHash,
        planningContext: planningContext,
      );
    } catch (_) {
      await _markGenerationFailed(gate, sourceHash: sourceHash);
      rethrow;
    }
    return dailyCandidateSnapshot(DateTime.parse(gate.periodStart));
  }

  Future<CandidateSnapshot<ExperimentCandidateRecord>> _refreshWeekly({
    required CandidateGateState gate,
    required WeeklyCandidateGenerator generate,
    required Duration debounce,
    int sourceChangeRetry = 0,
  }) async {
    final planningContext = await _planningContextForGate(gate);
    final sourceHash = planningContext.sourceHash;
    if (!gate.isOpen) {
      await _setGated(gate, sourceHash: sourceHash);
      return weeklyCandidateSnapshot(DateTime.parse(gate.periodStart));
    }
    final current = await getGenerationState(
      kind: gate.kind,
      periodStart: gate.periodStart,
      periodEnd: gate.periodEnd,
      eligibleSignalCount: gate.eligibleSignalCount,
    );
    if (current.status == CandidateGenerationStatus.ready &&
        current.sourceHash == sourceHash) {
      return weeklyCandidateSnapshot(DateTime.parse(gate.periodStart));
    }
    await beginRegeneration(
      kind: gate.kind,
      periodStart: gate.periodStart,
      periodEnd: gate.periodEnd,
      sourceHash: sourceHash,
      eligibleSignalCount: gate.eligibleSignalCount,
      reason: 'signal_source_changed',
    );
    if (debounce > Duration.zero) await Future<void>.delayed(debounce);
    try {
      final drafts = await generate(planningContext);
      final latestGate = await weeklyGate(DateTime.parse(gate.periodStart));
      final latestPlanningContext = await _planningContextForGate(latestGate);
      final latestSourceHash = latestPlanningContext.sourceHash;
      if (latestSourceHash != sourceHash) {
        if (sourceChangeRetry < 2) {
          return _refreshWeekly(
            gate: latestGate,
            generate: generate,
            debounce: debounce,
            sourceChangeRetry: sourceChangeRetry + 1,
          );
        }
        await beginRegeneration(
          kind: latestGate.kind,
          periodStart: latestGate.periodStart,
          periodEnd: latestGate.periodEnd,
          sourceHash: latestSourceHash,
          eligibleSignalCount: latestGate.eligibleSignalCount,
          reason: 'source_changed_during_generation',
        );
        return weeklyCandidateSnapshot(
          DateTime.parse(latestGate.periodStart),
        );
      }
      await replaceWeeklyCandidates(
        day: DateTime.parse(gate.periodStart),
        drafts: drafts,
        expectedSourceHash: sourceHash,
        planningContext: planningContext,
      );
    } catch (_) {
      await _markGenerationFailed(gate, sourceHash: sourceHash);
      rethrow;
    }
    return weeklyCandidateSnapshot(DateTime.parse(gate.periodStart));
  }

  Future<List<MicroActionCandidateModel>> replaceDailyCandidates({
    required DateTime day,
    required List<MicroActionCandidateDraft> drafts,
    String? expectedSourceHash,
    CandidatePlanningContext? planningContext,
  }) async {
    final gate = await dailyGate(day);
    final resolvedPlanningContext =
        planningContext ?? await _planningContextForGate(gate);
    if (!gate.isOpen) {
      await _setGated(gate, sourceHash: resolvedPlanningContext.sourceHash);
      return const [];
    }
    final sourceHash = resolvedPlanningContext.sourceHash;
    if (expectedSourceHash != null && sourceHash != expectedSourceHash) {
      return const [];
    }
    final db = await localDatabase.database;
    final existing = await _readyGroup(
      db,
      kind: gate.kind,
      periodStart: gate.periodStart,
      sourceHash: sourceHash,
    );
    if (existing != null) {
      return listDailyMicroActionCandidates(day);
    }
    final now = nowLoader().toUtc();
    final groupId = _groupId(gate.kind, gate.periodStart, sourceHash);
    final allowedIds = gate.eligibleSignalCardIds.toSet();
    final limited = drafts
        .where((draft) => draft.title.trim().isNotEmpty)
        .take(maxCandidatesPerGroup)
        .toList(growable: false);
    await db.transaction((txn) async {
      await _stalePreviousGroups(
        txn,
        kind: gate.kind,
        periodStart: gate.periodStart,
        reason: 'superseded_by_source_change',
        invalidatedAt: now,
      );
      await txn.insert(
        'candidate_groups',
        _groupRow(
          id: groupId,
          gate: gate,
          sourceHash: sourceHash,
          status: 'ready',
          now: now,
        ),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      for (var index = 0; index < limited.length; index++) {
        final draft = limited[index];
        final linked = draft.linkedSignalCardIds.isEmpty
            ? gate.eligibleSignalCardIds
            : draft.linkedSignalCardIds.where(allowedIds.contains).toList();
        await txn.insert(
          'micro_action_candidates',
          {
            'id': _candidateId('mac', groupId, index + 1),
            'candidate_group_id': groupId,
            'local_user_id': localUserId,
            'local_date': gate.periodStart,
            'rank': index + 1,
            'title': draft.title.trim(),
            'reason': _encodeMicroCandidateReason(
              draft.reason,
              draft.energyAdaptationExplanation,
            ),
            'difficulty': draft.recommendedIntensity.trim().isEmpty
                ? draft.difficulty != 'very_light'
                    ? draft.difficulty
                    : resolvedPlanningContext
                        .planningRecommendedIntensity.storageValue
                : draft.recommendedIntensity,
            'linked_signal_card_ids_json': jsonEncode(linked),
            'focus_domain_ids_json': jsonEncode(
              draft.focusDomainIds.isEmpty
                  ? resolvedPlanningContext.focusDomainIds
                  : draft.focusDomainIds,
            ),
            'status': 'generated',
            'adopted_micro_action_id': null,
            'source_hash': sourceHash,
            'dirty': 0,
            'is_stale': 0,
            'stale_reason': null,
            'invalidated_at': null,
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    await _emitState(gate.kind, gate.periodStart, gate.periodEnd);
    return listDailyMicroActionCandidates(day);
  }

  Future<List<ExperimentCandidateRecord>> replaceWeeklyCandidates({
    required DateTime day,
    required List<ExperimentCandidateDraft> drafts,
    String? expectedSourceHash,
    CandidatePlanningContext? planningContext,
  }) async {
    final gate = await weeklyGate(day);
    final resolvedPlanningContext =
        planningContext ?? await _planningContextForGate(gate);
    if (!gate.isOpen) {
      await _setGated(gate, sourceHash: resolvedPlanningContext.sourceHash);
      return const [];
    }
    final sourceHash = resolvedPlanningContext.sourceHash;
    if (expectedSourceHash != null && sourceHash != expectedSourceHash) {
      return const [];
    }
    final db = await localDatabase.database;
    final existing = await _readyGroup(
      db,
      kind: gate.kind,
      periodStart: gate.periodStart,
      sourceHash: sourceHash,
    );
    if (existing != null) {
      return listWeeklyExperimentCandidates(day);
    }
    final now = nowLoader().toUtc();
    final groupId = _groupId(gate.kind, gate.periodStart, sourceHash);
    final allowedIds = gate.eligibleSignalCardIds.toSet();
    final limited = drafts
        .where((draft) => draft.title.trim().isNotEmpty)
        .take(maxCandidatesPerGroup)
        .toList(growable: false);
    await db.transaction((txn) async {
      await _stalePreviousGroups(
        txn,
        kind: gate.kind,
        periodStart: gate.periodStart,
        reason: 'superseded_by_source_change',
        invalidatedAt: now,
      );
      await txn.insert(
        'candidate_groups',
        _groupRow(
          id: groupId,
          gate: gate,
          sourceHash: sourceHash,
          status: 'ready',
          now: now,
        ),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      for (var index = 0; index < limited.length; index++) {
        final draft = limited[index];
        final linked = draft.linkedSignalCardIds.isEmpty
            ? gate.eligibleSignalCardIds
            : draft.linkedSignalCardIds.where(allowedIds.contains).toList();
        await txn.insert(
          'experiment_candidates',
          {
            'id': _candidateId('ec', groupId, index + 1),
            'local_user_id': localUserId,
            'source_type': 'weekly_reflection',
            'source_id': gate.periodStart,
            'source_week_start': gate.periodStart,
            'source_week_end': gate.periodEnd,
            'title': draft.title.trim(),
            'hypothesis': draft.hypothesis.trim(),
            'suggested_action': draft.suggestedAction.trim(),
            'linked_signal_card_ids_json': jsonEncode(linked),
            'linked_observation_ids_json':
                jsonEncode(draft.linkedObservationIds),
            'status': 'generated',
            'confidence_level': draft.confidenceLevel,
            'metadata_json': jsonEncode({
              ...draft.metadata,
              'energy_snapshot_id': resolvedPlanningContext.energySnapshot.id,
              'energy_snapshot_hash':
                  CandidatePlanningFingerprint.tryParse(sourceHash)
                          ?.energySnapshotHash ??
                      resolvedPlanningContext.energySnapshot.sourceHash,
              'energy_capacity_band':
                  resolvedPlanningContext.planningCapacityBand.storageValue,
              'recommended_intensity': draft.recommendedIntensity.trim().isEmpty
                  ? resolvedPlanningContext
                      .planningRecommendedIntensity.storageValue
                  : draft.recommendedIntensity,
              'energy_adaptation_explanation':
                  draft.energyAdaptationExplanation,
              'focus_domain_ids': resolvedPlanningContext.focusDomainIds,
              'feedback_event_ids':
                  resolvedPlanningContext.feedback.effectiveEventIds,
              if (resolvedPlanningContext.deepReference != null)
                'deep_planning_reference': {
                  'id': resolvedPlanningContext.deepReference!.id,
                  'source_hash':
                      resolvedPlanningContext.deepReference!.sourceHash,
                  'summary': resolvedPlanningContext.deepReference!.summary,
                  'observation_plan_id':
                      resolvedPlanningContext.deepReference!.observationPlanId,
                },
            }),
            'adopted_experiment_id': null,
            'dirty': 0,
            'is_stale': 0,
            'stale_reason': null,
            'invalidated_at': null,
            'candidate_group_id': groupId,
            'candidate_rank': index + 1,
            'source_hash': sourceHash,
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    await _emitState(gate.kind, gate.periodStart, gate.periodEnd);
    return listWeeklyExperimentCandidates(day);
  }

  Future<List<MicroActionModel>> adoptMicroActionCandidates(
    Iterable<String> candidateIds,
  ) async {
    final ids = _normalizedIds(candidateIds);
    if (ids.isEmpty) return const [];
    final db = await localDatabase.database;
    final now = nowLoader();
    final adopted = await db.transaction<List<MicroActionModel>>((txn) async {
      final result = <MicroActionModel>[];
      for (final candidateId in ids) {
        final rows = await txn.query(
          'micro_action_candidates',
          where: 'id = ? AND dirty = 0 AND is_stale = 0',
          whereArgs: [candidateId],
          limit: 1,
        );
        if (rows.isEmpty) {
          throw StateError('micro_action_candidate_unavailable:$candidateId');
        }
        final candidate = _mapMicroCandidate(rows.first);
        var existingRows = await txn.query(
          'micro_actions',
          where: 'origin_candidate_id = ?',
          whereArgs: [candidateId],
          limit: 1,
        );
        if (existingRows.isEmpty) {
          final candidateStart = DateTime.tryParse(candidate.localDate);
          final today = _dateOnly(now.toLocal());
          // Daily candidates use today, while the planned weekly small-try
          // group carries next Monday in local_date.  Do not pull a future
          // choice into Today merely because it was adopted early.
          final start = candidateStart == null
              ? today
              : _dateOnly(candidateStart).isAfter(today)
                  ? _dateOnly(candidateStart)
                  : today;
          final isFuture = start.isAfter(today);
          final proposedId =
              'ma_${_uuid.v4().replaceAll('-', '').substring(0, 12)}';
          final proposed = MicroActionModel(
            id: proposedId,
            judgementId: '',
            title: candidate.title,
            reason: candidate.reason,
            actionType: 'today_try',
            difficulty: candidate.difficulty,
            plannedDurationMinutes: SmallTryPlanningLimits.maxDurationMinutes,
            plannedDate: _dateKey(start),
            status: isFuture ? 'planned' : 'accepted',
            feedbackStatus: 'none',
            localUserId: localUserId,
            originCandidateId: candidate.id,
            adoptedAt: now,
            progressStartDate: _dateKey(start),
            progressEndDate: null,
            linkedSignalCardIds: candidate.linkedSignalCardIds,
            createdAt: now,
            updatedAt: now,
          );
          await txn.insert(
            'micro_actions',
            proposed.toDb(),
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          existingRows = await txn.query(
            'micro_actions',
            where: 'origin_candidate_id = ?',
            whereArgs: [candidateId],
            limit: 1,
          );
        }
        if (existingRows.isEmpty) {
          throw StateError('micro_action_adoption_failed:$candidateId');
        }
        final actual = MicroActionModel.fromDb(existingRows.first);
        final isFuture = (DateTime.tryParse(actual.progressStartDate ?? '') ??
                    DateTime.tryParse(actual.plannedDate ?? ''))
                ?.isAfter(_dateOnly(now.toLocal())) ??
            false;
        await txn.update(
          'micro_action_candidates',
          {
            'status': isFuture ? 'planned' : 'adopted',
            'decision_status': CandidateDecisionStatus.adopted.name,
            'adopted_micro_action_id': actual.id,
            'updated_at': now.toUtc().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [candidateId],
        );
        result.add(actual);
      }
      return result;
    });

    for (final action in adopted) {
      await planContentVersionRepository.ensureInitial(
        localUserId: action.localUserId,
        objectKind: PlanContentObjectKind.quickTry,
        objectId: action.id,
        effectiveFromLocalDate: _microActionStartDate(action),
        content: _microActionContent(action),
        createdAt: action.createdAt,
      );
      final traceRepository = LocalTraceLinkRepository(localDatabase);
      await traceRepository.upsert(
        TraceLinkInput(
          sourceType: 'micro_action',
          sourceId: action.id,
          targetType: 'micro_action_candidate',
          targetId: action.originCandidateId!,
          relationType: 'origin_candidate',
          localUserId: localUserId,
        ),
      );
      for (final signalId in action.linkedSignalCardIds) {
        await traceRepository.upsert(
          TraceLinkInput(
            sourceType: 'micro_action',
            sourceId: action.id,
            targetType: 'signal_card',
            targetId: signalId,
            relationType: 'evidence_signal',
            localUserId: localUserId,
          ),
        );
      }
      await LocalCacheInvalidationRepository(localDatabase)
          .markMicroActionChanged(
        localDate: action.progressStartDate ?? action.plannedDate ?? '',
        reason: 'micro_action_adopted',
      );
    }
    return adopted;
  }

  Future<List<LifeExperimentModel>> adoptExperimentCandidates(
    Iterable<String> candidateIds,
  ) async {
    final ids = _normalizedIds(candidateIds);
    if (ids.isEmpty) return const [];
    final db = await localDatabase.database;
    final now = nowLoader();
    final adopted =
        await db.transaction<List<LifeExperimentModel>>((txn) async {
      final result = <LifeExperimentModel>[];
      for (final candidateId in ids) {
        final rows = await txn.query(
          'experiment_candidates',
          where: 'id = ? AND dirty = 0 AND is_stale = 0',
          whereArgs: [candidateId],
          limit: 1,
        );
        if (rows.isEmpty) {
          throw StateError('experiment_candidate_unavailable:$candidateId');
        }
        final candidate = _mapExperimentCandidate(rows.first);
        var experimentRows = await txn.query(
          'life_experiments',
          where: 'origin_candidate_id = ?',
          whereArgs: [candidateId],
          limit: 1,
        );
        if (experimentRows.isEmpty) {
          final sourceWeekStart = DateTime.parse(candidate.weekStart);
          final activeStart = sourceWeekStart.add(const Duration(days: 7));
          final displayWeekEnd = activeStart.add(const Duration(days: 6));
          final plannedTotalDays = _positiveInt(
            candidate.metadata['planned_total_days'],
          );
          final activeEnd = plannedTotalDays == null
              ? null
              : activeStart.add(Duration(days: plannedTotalDays - 1));
          final isFuture = activeStart.isAfter(_dateOnly(now.toLocal()));
          final proposed = LifeExperimentModel(
            id: 'exp_${_uuid.v4().replaceAll('-', '').substring(0, 12)}',
            localUserId: localUserId,
            sourceWeekStart: _dateKey(activeStart),
            sourceWeekEnd: _dateKey(displayWeekEnd),
            title: candidate.title,
            hypothesis: candidate.hypothesis,
            suggestedAction: candidate.suggestedAction,
            linkedSignalCardIds: candidate.linkedSignalCardIds,
            status: isFuture ? 'planned' : 'saved',
            plannedTotalDays: plannedTotalDays,
            originCandidateId: candidate.id,
            adoptedAt: now,
            progressStartDate: _dateKey(activeStart),
            progressEndDate: activeEnd == null ? null : _dateKey(activeEnd),
            createdAt: now,
            updatedAt: now,
          );
          await txn.insert(
            'life_experiments',
            localLifeExperimentRepository.toStorageRow(proposed),
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          experimentRows = await txn.query(
            'life_experiments',
            where: 'origin_candidate_id = ?',
            whereArgs: [candidateId],
            limit: 1,
          );
        }
        if (experimentRows.isEmpty) {
          throw StateError('experiment_adoption_failed:$candidateId');
        }
        final actual = localLifeExperimentRepository.fromStorageRow(
          experimentRows.first,
        );
        final activeStart = DateTime.tryParse(
          actual.progressStartDate ?? actual.sourceWeekStart,
        );
        final isFuture =
            activeStart?.isAfter(_dateOnly(now.toLocal())) ?? false;
        await txn.update(
          'experiment_candidates',
          {
            'status': isFuture ? 'planned' : 'adopted',
            'decision_status': CandidateDecisionStatus.adopted.name,
            'adopted_experiment_id': actual.id,
            'updated_at': now.toUtc().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [candidate.id],
        );
        result.add(actual);
      }
      return result;
    });

    for (final experiment in adopted) {
      await localLifeExperimentRepository.ensureAdoptionArtifacts(experiment);
      await LocalTraceLinkRepository(localDatabase).upsert(
        TraceLinkInput(
          sourceType: 'life_experiment',
          sourceId: experiment.id,
          targetType: 'experiment_candidate',
          targetId: experiment.originCandidateId!,
          relationType: 'origin_candidate',
          localUserId: localUserId,
        ),
      );
      await LocalCacheInvalidationRepository(localDatabase)
          .markExperimentChanged(
        weekStart: experiment.sourceWeekStart,
        eventDate: DateTime.parse(experiment.sourceWeekStart),
        reason: 'life_experiment_adopted',
      );
    }
    return adopted;
  }

  Future<List<AdoptedMicroActionProgress>> listActiveMicroActionsForDate(
    DateTime day,
  ) async {
    await _activatePlansDueOn(day);
    final db = await localDatabase.database;
    final key = _dateKey(day.toLocal());
    final rows = await db.query(
      'micro_actions',
      where: '''
        local_user_id = ?
        AND status IN (?, ?, ?, ?, ?)
        AND (
          (progress_start_date <= ? AND (
            progress_end_date IS NULL OR TRIM(progress_end_date) = ''
            OR progress_end_date >= ?
          ))
          OR (progress_start_date IS NULL AND planned_date = ?)
        )
      ''',
      whereArgs: [
        localUserId,
        'accepted',
        'active',
        'adjusted',
        'done',
        'completed',
        key,
        key,
        key,
      ],
      orderBy: 'source_changed DESC, adopted_at DESC, updated_at DESC',
    );
    final result = <AdoptedMicroActionProgress>[];
    for (final row in rows) {
      final action = await _microActionForDate(row, key);
      result.add(AdoptedMicroActionProgress(
        action: action,
        progress: await microActionProgress(action.id),
      ));
    }
    return result;
  }

  /// Planned next-week selections become active only when their local start
  /// date arrives. The transition is idempotent and does not create feedback,
  /// Signals, or a new candidate selection.
  Future<void> _activatePlansDueOn(DateTime day) async {
    final db = await localDatabase.database;
    final key = _dateKey(day.toLocal());
    final now = nowLoader().toUtc().toIso8601String();
    await db.transaction((txn) async {
      final microRows = await txn.query(
        'micro_actions',
        columns: const ['id'],
        where: '''
          local_user_id = ? AND status = ?
          AND COALESCE(progress_start_date, planned_date) <= ?
        ''',
        whereArgs: [localUserId, 'planned', key],
      );
      if (microRows.isNotEmpty) {
        final ids = microRows.map((row) => row['id'] as String).toList();
        final placeholders = List.filled(ids.length, '?').join(', ');
        await txn.update(
          'micro_actions',
          {'status': 'accepted', 'updated_at': now},
          where: 'id IN ($placeholders)',
          whereArgs: ids,
        );
        await txn.update(
          'micro_action_candidates',
          {'status': 'active', 'updated_at': now},
          where: '''
            adopted_micro_action_id IN ($placeholders) AND status = ?
          ''',
          whereArgs: [...ids, 'planned'],
        );
      }

      final experimentRows = await txn.query(
        'life_experiments',
        columns: const ['id'],
        where: '''
          local_user_id = ? AND status = ?
          AND COALESCE(progress_start_date, source_week_start) <= ?
        ''',
        whereArgs: [localUserId, 'planned', key],
      );
      if (experimentRows.isNotEmpty) {
        final ids = experimentRows.map((row) => row['id'] as String).toList();
        final placeholders = List.filled(ids.length, '?').join(', ');
        await txn.update(
          'life_experiments',
          {'status': 'saved', 'updated_at': now},
          where: 'id IN ($placeholders)',
          whereArgs: ids,
        );
        await txn.update(
          'experiment_candidates',
          {'status': 'active', 'updated_at': now},
          where: 'adopted_experiment_id IN ($placeholders) AND status = ?',
          whereArgs: [...ids, 'planned'],
        );
      }
    });
  }

  /// All adopted small tries shown inside the Life Experiment archive.
  ///
  /// The existing `micro_actions` table remains canonical. A row needs real
  /// adoption evidence (`adopted_at` or a non-empty candidate origin); status
  /// alone is not enough. Older accepted/completed rows are covered by the
  /// candidate-planning adoption backfill.
  Future<List<AdoptedMicroActionProgress>> listAdoptedSmallTries({
    int limit = 500,
    int offset = 0,
  }) async {
    final db = await localDatabase.database;
    final rows = await db.query(
      'micro_actions',
      where: '''
        local_user_id = ?
        AND (
          adopted_at IS NOT NULL
          OR (
            origin_candidate_id IS NOT NULL
            AND TRIM(origin_candidate_id) != ''
          )
        )
      ''',
      whereArgs: [localUserId],
      orderBy: '''
        CASE WHEN status IN ('accepted', 'active', 'adjusted') THEN 0 ELSE 1 END,
        source_changed DESC,
        COALESCE(adopted_at, updated_at, created_at) DESC
      ''',
      limit: limit,
      offset: offset,
    );
    final result = <AdoptedMicroActionProgress>[];
    for (final row in rows) {
      final action = MicroActionModel.fromDb(row);
      result.add(AdoptedMicroActionProgress(
        action: action,
        progress: await microActionProgress(action.id),
      ));
    }
    return result;
  }

  Future<List<AdoptedLifeExperimentProgress>> listActiveExperimentsForDate(
    DateTime day,
  ) async {
    await _activatePlansDueOn(day);
    final db = await localDatabase.database;
    final key = _dateKey(day.toLocal());
    final rows = await db.query(
      'life_experiments',
      where: '''
        local_user_id = ?
        AND status IN (?, ?, ?, ?)
        AND COALESCE(progress_start_date, source_week_start) <= ?
        AND (progress_end_date IS NULL OR progress_end_date >= ?)
      ''',
      whereArgs: [
        localUserId,
        'saved',
        'active',
        'done',
        'completed',
        key,
        key
      ],
      orderBy: 'source_changed DESC, adopted_at DESC, updated_at DESC',
    );
    final result = <AdoptedLifeExperimentProgress>[];
    for (final row in rows) {
      final experiment = await _lifeExperimentForDate(row, key);
      result.add(AdoptedLifeExperimentProgress(
        experiment: experiment,
        progress: await lifeExperimentProgress(experiment.id),
      ));
    }
    return result;
  }

  /// Current-week experiments that can still be explicitly continued into
  /// next week. Experiments that already have a child for the target week are
  /// omitted so reopening the picker cannot create duplicate continuations.
  Future<List<AdoptedLifeExperimentProgress>>
      listContinuableExperimentsForNextWeek(DateTime day) async {
    final active = await listActiveExperimentsForDate(day);
    if (active.isEmpty) return const [];

    final nextWeekStart = _startOfWeek(day.toLocal()).add(
      const Duration(days: 7),
    );
    final nextWeekStartKey = _dateKey(nextWeekStart);
    final db = await localDatabase.database;
    final result = <AdoptedLifeExperimentProgress>[];
    for (final item in active) {
      final status = item.experiment.status.trim().toLowerCase();
      if (status != 'saved' && status != 'active') continue;
      final existing = await db.query(
        'life_experiments',
        columns: const ['id'],
        where: '''
          local_user_id = ?
          AND parent_experiment_id = ?
          AND source_week_start = ?
        ''',
        whereArgs: [localUserId, item.experiment.id, nextWeekStartKey],
        limit: 1,
      );
      if (existing.isEmpty) result.add(item);
    }
    return result;
  }

  /// Continues selected current experiments into the next local Monday–Sunday
  /// period. [LocalLifeExperimentRepository.reuseForNextWeek] is idempotent,
  /// so repeated taps or a retry after an interrupted UI transition are safe.
  Future<List<LifeExperimentModel>> continueExperimentsForNextWeek({
    required Iterable<String> experimentIds,
    required DateTime day,
  }) async {
    final ids = _normalizedIds(experimentIds);
    if (ids.isEmpty) return const [];
    final continuable = await listContinuableExperimentsForNextWeek(day);
    final byId = {
      for (final item in continuable) item.experiment.id: item.experiment,
    };
    final result = <LifeExperimentModel>[];
    for (final id in ids) {
      final experiment =
          byId[id] ?? await localLifeExperimentRepository.getById(id);
      if (experiment == null) continue;
      final status = experiment.status.trim().toLowerCase();
      if (status != 'saved' && status != 'active') continue;
      final currentKey = _dateKey(day.toLocal());
      final currentStart =
          experiment.progressStartDate ?? experiment.sourceWeekStart;
      final currentEnd = experiment.progressEndDate;
      if (currentStart.compareTo(currentKey) > 0 ||
          (currentEnd != null && currentEnd.compareTo(currentKey) < 0)) {
        continue;
      }
      result.add(
        await localLifeExperimentRepository.reuseForNextWeek(
          experiment: experiment,
          fromDate: day,
        ),
      );
    }
    return result;
  }

  /// Read-only Monday-to-Sunday projection used by Weekly.
  ///
  /// Unlike the Today projection, this includes every adopted small experiment
  /// that has lifecycle activity or real feedback in the requested natural
  /// week, including one archived earlier in that week. Feedback remains
  /// append-only; this method only projects real attempts into the week.
  Future<List<AdoptedMicroActionProgress>> listAdoptedSmallTriesForWeek({
    required DateTime weekStart,
    required DateTime weekEnd,
  }) async {
    final start = _dateOnly(weekStart.toLocal());
    final end = _dateOnly(weekEnd.toLocal());
    final startKey = _dateKey(start);
    final endKey = _dateKey(end);
    final projectionDay =
        _clampDate(_dateOnly(nowLoader().toLocal()), start, end);
    final db = await localDatabase.database;
    final rows = await db.query(
      'micro_actions',
      where: '''
        local_user_id = ?
        AND (
          adopted_at IS NOT NULL
          OR (origin_candidate_id IS NOT NULL AND TRIM(origin_candidate_id) != '')
        )
        AND COALESCE(
          progress_start_date,
          planned_date,
          SUBSTR(adopted_at, 1, 10),
          SUBSTR(created_at, 1, 10)
        ) <= ?
        AND (
          progress_end_date IS NULL OR TRIM(progress_end_date) = ''
          OR progress_end_date >= ?
        )
      ''',
      whereArgs: [localUserId, endKey, startKey],
      orderBy: 'source_changed DESC, adopted_at DESC, updated_at DESC',
    );
    final result = <AdoptedMicroActionProgress>[];
    for (final row in rows) {
      final action = await _microActionForDate(row, _dateKey(projectionDay));
      final canonical = await microActionProgress(action.id);
      result.add(AdoptedMicroActionProgress(
        action: action,
        progress: _attemptProgressProjectedToPeriod(
          canonical,
          periodStart: start,
          periodEnd: end,
        ),
      ));
    }
    return result;
  }

  /// Read-only Monday-to-Sunday projection used by Weekly goals.
  Future<List<AdoptedLifeExperimentProgress>> listAdoptedGoalsForWeek({
    required DateTime weekStart,
    required DateTime weekEnd,
  }) async {
    final start = _dateOnly(weekStart.toLocal());
    final end = _dateOnly(weekEnd.toLocal());
    final startKey = _dateKey(start);
    final endKey = _dateKey(end);
    final projectionDay =
        _clampDate(_dateOnly(nowLoader().toLocal()), start, end);
    final db = await localDatabase.database;
    final rows = await db.query(
      'life_experiments',
      where: '''
        local_user_id = ?
        AND (
          adopted_at IS NOT NULL
          OR (origin_candidate_id IS NOT NULL AND TRIM(origin_candidate_id) != '')
        )
        AND COALESCE(
          progress_start_date,
          source_week_start,
          SUBSTR(adopted_at, 1, 10),
          SUBSTR(created_at, 1, 10)
        ) <= ?
        AND (
          progress_end_date >= ?
          OR (
            (progress_end_date IS NULL OR TRIM(progress_end_date) = '')
            AND LOWER(TRIM(status)) IN (
              'planned', 'saved', 'accepted', 'active', 'adjusted', 'paused'
            )
          )
          OR (
            (progress_end_date IS NULL OR TRIM(progress_end_date) = '')
            AND source_week_end >= ?
          )
        )
      ''',
      whereArgs: [localUserId, endKey, startKey, startKey],
      orderBy: 'source_changed DESC, adopted_at DESC, updated_at DESC',
    );
    final result = <AdoptedLifeExperimentProgress>[];
    for (final row in rows) {
      final experiment =
          await _lifeExperimentForDate(row, _dateKey(projectionDay));
      final canonical = await lifeExperimentProgress(experiment.id);
      result.add(AdoptedLifeExperimentProgress(
        experiment: experiment,
        progress: _progressProjectedToWeek(
          canonical,
          weekStart: start,
          weekEnd: end,
        ),
      ));
    }
    return result;
  }

  /// Diary projection for a selected day. Unlike the Today projection this
  /// intentionally includes paused, archived and completed adopted objects,
  /// because a later status change must not rewrite a past diary page.
  Future<List<AdoptedMicroActionProgress>> listAdoptedSmallTriesForDate(
    DateTime day,
  ) async {
    final db = await localDatabase.database;
    final key = _dateKey(day.toLocal());
    final rows = await db.query(
      'micro_actions',
      where: '''
        local_user_id = ?
        AND (
          adopted_at IS NOT NULL
          OR (origin_candidate_id IS NOT NULL AND TRIM(origin_candidate_id) != '')
        )
        AND EXISTS (
          SELECT 1
          FROM micro_action_feedback feedback
          WHERE feedback.micro_action_id = micro_actions.id
            AND feedback.local_date = ?
            AND COALESCE(feedback.is_valid, 1) = 1
        )
      ''',
      whereArgs: [localUserId, key],
      orderBy: 'adopted_at DESC, updated_at DESC',
    );
    final result = <AdoptedMicroActionProgress>[];
    for (final row in rows) {
      final action = await _microActionForDate(row, key);
      result.add(AdoptedMicroActionProgress(
        action: action,
        progress: await microActionProgress(action.id),
      ));
    }
    return result;
  }

  /// Diary projection for adopted multi-day goals on a selected day.
  Future<List<AdoptedLifeExperimentProgress>> listAdoptedGoalsForDate(
    DateTime day,
  ) async {
    final db = await localDatabase.database;
    final key = _dateKey(day.toLocal());
    final rows = await db.query(
      'life_experiments',
      where: '''
        local_user_id = ?
        AND (
          adopted_at IS NOT NULL
          OR (origin_candidate_id IS NOT NULL AND TRIM(origin_candidate_id) != '')
        )
        AND COALESCE(progress_start_date, source_week_start) <= ?
        AND (progress_end_date IS NULL OR progress_end_date >= ?)
      ''',
      whereArgs: [localUserId, key, key],
      orderBy: 'adopted_at DESC, updated_at DESC',
    );
    final result = <AdoptedLifeExperimentProgress>[];
    for (final row in rows) {
      final experiment = await _lifeExperimentForDate(row, key);
      result.add(AdoptedLifeExperimentProgress(
        experiment: experiment,
        progress: await lifeExperimentProgress(experiment.id),
      ));
    }
    return result;
  }

  /// Lightweight date index for the diary month sheet. Ranges are expanded in
  /// Dart so SQLite only returns adoption metadata, not full candidate cards.
  Future<Set<String>> listAdoptedPlanContentDateKeys() async {
    final db = await localDatabase.database;
    final keys = <String>{};

    // A quick experiment enters the diary only on dates when a real attempt
    // was recorded. Adoption and an artificial date range are planning facts,
    // not a claim that the experiment happened on every intervening day.
    final actionDates = await db.rawQuery('''
      SELECT DISTINCT feedback.local_date
      FROM micro_action_feedback feedback
      INNER JOIN micro_actions action ON action.id = feedback.micro_action_id
      WHERE action.local_user_id = ?
        AND COALESCE(feedback.is_valid, 1) = 1
        AND (
          action.adopted_at IS NOT NULL
          OR (
            action.origin_candidate_id IS NOT NULL
            AND TRIM(action.origin_candidate_id) != ''
          )
        )
    ''', [localUserId]);
    for (final row in actionDates) {
      final key = row['local_date']?.toString().trim() ?? '';
      if (DateTime.tryParse(key) != null) keys.add(key);
    }

    final experimentRows = await db.query(
      'life_experiments',
      columns: const [
        'source_week_start',
        'source_week_end',
        'progress_start_date',
        'progress_end_date',
      ],
      where: '''
        local_user_id = ?
        AND (
          adopted_at IS NOT NULL
          OR (origin_candidate_id IS NOT NULL AND TRIM(origin_candidate_id) != '')
        )
      ''',
      whereArgs: [localUserId],
    );
    for (final row in experimentRows) {
      _addDiaryRange(
        keys,
        row['progress_start_date']?.toString() ??
            row['source_week_start']?.toString(),
        row['progress_end_date']?.toString() ??
            row['source_week_end']?.toString(),
      );
    }

    return keys;
  }

  void _addDiaryRange(Set<String> output, String? startRaw, String? endRaw) {
    final start = DateTime.tryParse(startRaw ?? '');
    final end = DateTime.tryParse(endRaw ?? '');
    if (start == null || end == null || end.isBefore(start)) return;
    for (var day = DateTime(start.year, start.month, start.day);
        !day.isAfter(DateTime(end.year, end.month, end.day));
        day = day.add(const Duration(days: 1))) {
      output.add(_dateKey(day));
    }
  }

  Future<SevenDayProgressModel> microActionProgress(String actionId) async {
    final db = await localDatabase.database;
    final actions = await db.query(
      'micro_actions',
      where: 'id = ?',
      whereArgs: [actionId],
      limit: 1,
    );
    if (actions.isEmpty) return _emptyProgress(actionId, nowLoader());
    final row = actions.first;
    final start = _progressStart(
      row['progress_start_date'],
      fallbackDate: row['planned_date'],
      fallbackDateTime: row['adopted_at'] ?? row['created_at'],
    );
    final feedback = await db.query(
      'micro_action_feedback',
      where: '''
        micro_action_id = ? AND COALESCE(is_valid, 1) = 1
      ''',
      whereArgs: [actionId],
      orderBy:
          'local_date ASC, COALESCE(updated_at, created_at) ASC, created_at ASC, id ASC',
    );
    return _buildAttemptProgress(
      subjectId: actionId,
      start: start,
      feedbackRows: feedback,
      dateOf: (row) => row['local_date'] as String?,
      idOf: (row) => row['id'] as String?,
      timeOf: (row) => row['updated_at'] ?? row['created_at'],
      stateOf: (row) => _microProgressState(row['happened']),
    );
  }

  Future<SevenDayProgressModel> lifeExperimentProgress(
    String experimentId,
  ) async {
    final db = await localDatabase.database;
    final experiments = await db.query(
      'life_experiments',
      where: 'id = ?',
      whereArgs: [experimentId],
      limit: 1,
    );
    if (experiments.isEmpty) {
      return _emptyProgress(experimentId, nowLoader());
    }
    final row = experiments.first;
    final start = _progressStart(
      row['progress_start_date'],
      fallbackDate: row['source_week_start'],
      fallbackDateTime: row['adopted_at'] ?? row['created_at'],
    );
    final end = start.add(const Duration(days: 6));
    final feedback = await db.query(
      'life_experiment_feedback',
      where: '''
        experiment_id = ? AND local_date >= ? AND local_date <= ?
        AND COALESCE(is_valid, 1) = 1
      ''',
      whereArgs: [experimentId, _dateKey(start), _dateKey(end)],
      orderBy:
          'local_date ASC, COALESCE(updated_at, created_at) ASC, created_at ASC, id ASC',
    );
    return _buildProgress(
      subjectId: experimentId,
      start: start,
      feedbackRows: feedback,
      dateOf: (item) => item['local_date'] as String?,
      idOf: (item) => item['id'] as String?,
      timeOf: (item) => item['updated_at'] ?? item['created_at'],
      stateOf: (item) => _experimentProgressState(
        item['completion_status'] ?? item['happened'],
      ),
    );
  }

  Stream<CandidateGenerationState> watchGenerationState({
    required CandidateKind kind,
    required String periodStart,
    required String periodEnd,
  }) async* {
    yield await getGenerationState(
      kind: kind,
      periodStart: periodStart,
      periodEnd: periodEnd,
    );
    yield* _stateEvents.stream.where(
      (state) => state.kind == kind && state.periodStart == periodStart,
    );
  }

  Future<CandidateGenerationState> getGenerationState({
    required CandidateKind kind,
    required String periodStart,
    required String periodEnd,
    int eligibleSignalCount = 0,
  }) async {
    final db = await localDatabase.database;
    final rows = await db.query(
      'candidate_groups',
      where: 'local_user_id = ? AND candidate_kind = ? AND period_start = ?',
      whereArgs: [localUserId, kind.storageValue, periodStart],
      orderBy: '''
        CASE status
          WHEN 'ready' THEN 0
          WHEN 'regenerating' THEN 1
          WHEN 'gated' THEN 2
          WHEN 'failed' THEN 3
          ELSE 4
        END ASC,
        updated_at DESC
      ''',
      limit: 1,
    );
    if (rows.isEmpty) {
      return CandidateGenerationState(
        kind: kind,
        periodStart: periodStart,
        periodEnd: periodEnd,
        status: eligibleSignalCount < requiredSignalCount
            ? CandidateGenerationStatus.gated
            : CandidateGenerationStatus.stale,
        eligibleSignalCount: eligibleSignalCount,
      );
    }
    return _mapGenerationState(rows.first);
  }

  Future<void> beginRegeneration({
    required CandidateKind kind,
    required String periodStart,
    required String periodEnd,
    required String sourceHash,
    required int eligibleSignalCount,
    String reason = 'source_changed',
  }) async {
    final db = await localDatabase.database;
    final now = nowLoader().toUtc();
    await db.transaction((txn) async {
      await _stalePreviousGroups(
        txn,
        kind: kind,
        periodStart: periodStart,
        reason: reason,
        invalidatedAt: now,
      );
      await txn.insert(
        'candidate_groups',
        _groupRow(
          id: _groupId(kind, periodStart, sourceHash),
          gate: CandidateGateState(
            kind: kind,
            periodStart: periodStart,
            periodEnd: periodEnd,
            eligibleSignalCount: eligibleSignalCount,
          ),
          sourceHash: sourceHash,
          status: 'regenerating',
          now: now,
        ),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
    await _emitState(kind, periodStart, periodEnd);
  }

  Future<void> _setGated(
    CandidateGateState gate, {
    required String sourceHash,
  }) async {
    final db = await localDatabase.database;
    final now = nowLoader().toUtc();
    await db.transaction((txn) async {
      await _stalePreviousGroups(
        txn,
        kind: gate.kind,
        periodStart: gate.periodStart,
        reason: 'below_three_signal_gate',
        invalidatedAt: now,
      );
      await txn.insert(
        'candidate_groups',
        _groupRow(
          id: _groupId(gate.kind, gate.periodStart, sourceHash),
          gate: gate,
          sourceHash: sourceHash,
          status: 'gated',
          now: now,
        ),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
    await _emitState(gate.kind, gate.periodStart, gate.periodEnd);
  }

  Future<void> _markGenerationFailed(
    CandidateGateState gate, {
    required String sourceHash,
  }) async {
    final db = await localDatabase.database;
    final now = nowLoader().toUtc().toIso8601String();
    await db.update(
      'candidate_groups',
      {
        'status': 'failed',
        'stale_reason': 'generation_failed',
        'generation_finished_at': now,
        'updated_at': now,
      },
      where: '''
        local_user_id = ? AND candidate_kind = ?
        AND period_start = ? AND source_hash = ?
      ''',
      whereArgs: [
        localUserId,
        gate.kind.storageValue,
        gate.periodStart,
        sourceHash
      ],
    );
    await _emitState(gate.kind, gate.periodStart, gate.periodEnd);
  }

  Future<CandidatePlanningContext> _planningContextForGate(
    CandidateGateState gate,
  ) async {
    final signalHash = await _signalSourceHashForGate(gate);
    final externalSummary = await externalEnergySummaryLoader();
    final anchorDay = DateTime.parse(gate.periodStart);
    final energySnapshot = gate.kind == CandidateKind.microAction
        ? await energyBudgetRepository.fetchDailySnapshot(
            day: anchorDay,
            externalSummary: externalSummary,
          )
        : await energyBudgetRepository.fetchWeeklySnapshot(
            day: anchorDay,
            externalSummary: externalSummary,
          );
    final weeklyEnergySnapshot = gate.kind == CandidateKind.microAction
        ? await energyBudgetRepository.fetchWeeklySnapshot(
            day: anchorDay,
            externalSummary: externalSummary,
          )
        : null;
    final focusDomainIds = FocusDomains.normalizeIds(
      await focusDomainIdsLoader(),
    );
    final feedback = await _feedbackSummaryForGate(gate);
    final deepReference = await deepPlanningReferenceLoader(gate);
    final focusHash = _fnv1a(focusDomainIds.join('|'));
    final deepReferenceHash = deepReference == null
        ? 'none'
        : _fnv1a(
            '${deepReference.id}|${deepReference.sourceHash}|${deepReference.observationPlanId ?? ''}',
          );
    final planningCapacityBand = CandidatePlanningContext.resolveCapacity(
      energySnapshot.capacityBand,
      weeklyEnergySnapshot?.capacityBand,
    );
    final planningEnergyHash = weeklyEnergySnapshot == null
        ? energySnapshot.sourceHash
        : _fnv1a(
            '${energySnapshot.sourceHash}|${weeklyEnergySnapshot.sourceHash}',
          );
    final combinedHash = _fnv1a([
      CandidatePlanningFingerprint.version,
      signalHash,
      planningEnergyHash,
      planningCapacityBand.storageValue,
      focusHash,
      feedback.sourceHash,
      deepReferenceHash,
    ].join('|'));
    final fingerprint = CandidatePlanningFingerprint(
      combinedHash: combinedHash,
      signalHash: signalHash,
      energySnapshotHash: planningEnergyHash,
      capacityBand: planningCapacityBand,
      focusHash: focusHash,
      feedbackHash: feedback.sourceHash,
    );
    return CandidatePlanningContext(
      gate: gate,
      energySnapshot: energySnapshot,
      weeklyEnergySnapshot: weeklyEnergySnapshot,
      focusDomainIds: focusDomainIds,
      feedback: feedback,
      sourceHash: fingerprint.encode(),
      deepReference: deepReference,
    );
  }

  /// Reads an optional *persisted L3* reference. A standard Weekly snapshot is
  /// intentionally not enough: only `weekly_deep_analysis` plus an explicitly
  /// adopted observation plan can affect candidate ranking. Missing deep data
  /// is normal and must never block generation.
  Future<DeepPlanningReference?> _loadStoredDeepPlanningReference(
    CandidateGateState gate,
  ) async {
    final db = await localDatabase.database;
    final deepRows = await db.query(
      'reflection_results',
      columns: const ['id', 'source_hash', 'content_json'],
      where: '''
        source_type = ? AND source_id = ? AND reflection_type = ?
        AND status IN (?, ?) AND dirty = 0 AND is_stale = 0
      ''',
      whereArgs: [
        'weekly_snapshot',
        gate.periodStart,
        'weekly_deep_analysis',
        'generated',
        'confirmed',
      ],
      orderBy: 'generated_at DESC',
      limit: 1,
    );
    // A standard weekly report is deliberately never promoted to a Pro/deep
    // reference. Without an explicit deep result, planning remains grounded
    // only in Signal, feedback, focus and energy inputs.
    if (deepRows.isEmpty) return null;
    final observationRows = await db.query(
      'observation_plans',
      columns: const ['id', 'source_hash', 'question', 'result_summary'],
      where: 'local_user_id = ? AND source_week_start = ?',
      whereArgs: [localUserId, gate.periodStart],
      limit: 1,
    );
    final deep = deepRows.first;
    final observation = observationRows.isEmpty ? null : observationRows.first;
    final deepContent = _decodeMap(deep['content_json']);
    final deepHash = deep['source_hash']?.toString() ?? '';
    final observationHash = observation?['source_hash']?.toString() ?? '';
    final summary = (observation?['result_summary'] ??
                observation?['question'] ??
                deepContent['relationship_summary'] ??
                deepContent['summary'] ??
                deepContent['next_question'])
            ?.toString()
            .trim() ??
        '';
    return DeepPlanningReference(
      id: deep['id']?.toString() ?? 'weekly_deep:${gate.periodStart}',
      sourceHash: _fnv1a('$deepHash|$observationHash|$summary'),
      summary: summary,
      observationPlanId: observation?['id']?.toString(),
    );
  }

  Future<String> _signalSourceHashForGate(CandidateGateState gate) async {
    final signals = await localCaptureRepository.listSignalCardsBetween(
      startDate: gate.periodStart,
      endDate: gate.periodEnd,
    );
    final stage = gate.kind == CandidateKind.microAction
        ? SignalEligibilityStage.daily
        : SignalEligibilityStage.weekly;
    final eligible = _distinctEligible(signals, stage)
      ..sort((a, b) => _signalId(a).compareTo(_signalId(b)));
    final canonical = eligible.map((signal) {
      return [
        _signalId(signal),
        signal.content.trim(),
        signal.userConfirmation,
        signal.privacyLevel,
        signal.localDateKey(),
      ].join('|');
    }).join('\n');
    return _fnv1a(canonical);
  }

  Future<List<MicroActionCandidateDraft>> _groundedDailyDrafts(
    CandidatePlanningContext context,
    AppLanguage language,
  ) async {
    final gate = context.gate;
    final signals = _rankSignalsForPlanning(
      await _eligibleSignalsForGate(gate),
      context,
    );
    if (signals.length < requiredSignalCount) return const [];
    final evidence = signals.take(maxCandidatesPerGroup).toList();
    final feedbackMode = _feedbackPlanningMode(context.feedback);
    final baseMinutes = _smallTryDurationMinutes(
      context.planningCapacityBand,
    );
    final minutes = _feedbackAdjustedSmallTryMinutes(
      baseMinutes,
      feedbackMode,
    );
    final recommendedIntensity = _feedbackAdjustedIntensity(
      context.planningRecommendedIntensity,
      feedbackMode,
    );
    return List.generate(maxCandidatesPerGroup, (index) {
      final signal = evidence[index % evidence.length];
      final snippet = _snippet(signal.content, language);
      final suggestionIndex = feedbackMode == _FeedbackPlanningMode.redirect
          ? (index + 1) % maxCandidatesPerGroup
          : index;
      final baseCopy = _dailySuggestionCopy(
        language,
        suggestionIndex,
        snippet,
        minutes,
      );
      final copy = _feedbackAdjustedDailyCopy(
        language,
        feedbackMode,
        baseCopy,
        minutes,
      );
      return MicroActionCandidateDraft(
        title: copy.$1,
        reason: '${copy.$2}${_deepReferenceNote(context, language)}',
        difficulty: recommendedIntensity.storageValue,
        recommendedIntensity: recommendedIntensity.storageValue,
        energyAdaptationExplanation: _energyAdaptationText(
          context.planningCapacityBand,
          language,
          kind: CandidateKind.microAction,
        ),
        linkedSignalCardIds: [_signalId(signal)],
        focusDomainIds: context.focusDomainIds,
      );
    });
  }

  Future<List<ExperimentCandidateDraft>> _groundedWeeklyDrafts(
    CandidatePlanningContext context,
    AppLanguage language,
  ) async {
    final gate = context.gate;
    final signals = _rankSignalsForPlanning(
      await _eligibleSignalsForGate(gate),
      context,
    );
    if (signals.length < requiredSignalCount) return const [];
    final evidence = signals.take(maxCandidatesPerGroup).toList();
    final feedbackMode = _feedbackPlanningMode(context.feedback);
    final recommendedIntensity = _feedbackAdjustedIntensity(
      context.planningRecommendedIntensity,
      feedbackMode,
    );
    return List.generate(maxCandidatesPerGroup, (index) {
      final signal = evidence[index % evidence.length];
      final snippet = _snippet(signal.content, language);
      final suggestionIndex = _weeklySuggestionIndex(
        context.planningCapacityBand,
        feedbackMode,
        index,
      );
      var copy = _weeklySuggestionCopy(language, suggestionIndex, snippet);
      if (context.planningCapacityBand == EnergyCapacityBand.veryLow &&
          suggestionIndex == 1) {
        copy = (copy.$1, copy.$2, copy.$3.replaceFirst('10', '5'));
      }
      copy = _feedbackAdjustedWeeklyCopy(
        language,
        feedbackMode,
        copy,
      );
      return ExperimentCandidateDraft(
        title: copy.$1,
        hypothesis: '${copy.$2}${_deepReferenceNote(context, language)}',
        suggestedAction: copy.$3,
        recommendedIntensity: recommendedIntensity.storageValue,
        energyAdaptationExplanation: _energyAdaptationText(
          context.planningCapacityBand,
          language,
          kind: CandidateKind.lifeExperiment,
        ),
        linkedSignalCardIds: [_signalId(signal)],
        metadata: {
          'generator': 'local_grounded_fallback_v2',
          'presentation_status': 'suggested',
          'life_experiment_track': 'goal',
          'requires_repetition': true,
          'focus_domain_ids': context.focusDomainIds,
          'feedback_adaptation': feedbackMode.storageValue,
          'feedback_event_ids': context.feedback.effectiveEventIds,
          if (context.deepReference != null)
            'deep_planning_reference': {
              'id': context.deepReference!.id,
              'source_hash': context.deepReference!.sourceHash,
              'summary': context.deepReference!.summary,
              'observation_plan_id': context.deepReference!.observationPlanId,
            },
        },
      );
    });
  }

  Future<List<RecentSignalModel>> _eligibleSignalsForGate(
    CandidateGateState gate,
  ) async {
    final signals = await localCaptureRepository.listSignalCardsBetween(
      startDate: gate.periodStart,
      endDate: gate.periodEnd,
    );
    return _distinctEligible(
      signals,
      gate.kind == CandidateKind.microAction
          ? SignalEligibilityStage.daily
          : SignalEligibilityStage.weekly,
    );
  }

  List<RecentSignalModel> _rankSignalsForFocus(
    List<RecentSignalModel> signals,
    List<String> focusDomainIds,
  ) {
    final originalOrder = <String, int>{
      for (var index = 0; index < signals.length; index++)
        _signalId(signals[index]): index,
    };
    final ranked = signals.toList(growable: false);
    ranked.sort((a, b) {
      final scoreCompare = _focusScore(b, focusDomainIds)
          .compareTo(_focusScore(a, focusDomainIds));
      if (scoreCompare != 0) return scoreCompare;
      return (originalOrder[_signalId(a)] ?? 0)
          .compareTo(originalOrder[_signalId(b)] ?? 0);
    });
    return ranked;
  }

  List<RecentSignalModel> _rankSignalsForPlanning(
    List<RecentSignalModel> signals,
    CandidatePlanningContext context,
  ) {
    final focusRanked = _rankSignalsForFocus(signals, context.focusDomainIds);
    final reference = context.deepReference;
    if (reference == null || reference.summary.trim().isEmpty) {
      return focusRanked;
    }
    final originalOrder = <String, int>{
      for (var index = 0; index < focusRanked.length; index++)
        _signalId(focusRanked[index]): index,
    };
    focusRanked.sort((a, b) {
      final deepCompare = _deepReferenceScore(b, reference)
          .compareTo(_deepReferenceScore(a, reference));
      if (deepCompare != 0) return deepCompare;
      return (originalOrder[_signalId(a)] ?? 0)
          .compareTo(originalOrder[_signalId(b)] ?? 0);
    });
    return focusRanked;
  }

  int _deepReferenceScore(
    RecentSignalModel signal,
    DeepPlanningReference reference,
  ) {
    final text = [
      signal.content,
      signal.scene,
      signal.friction,
      signal.positiveSignal,
    ].whereType<String>().join(' ').toLowerCase();
    final phrases = reference.summary
        .toLowerCase()
        .split(RegExp(r'[\s，。；、：,:;]+'))
        .map((value) => value.trim())
        .where((value) => value.runes.length >= 2)
        .take(8);
    return phrases.where(text.contains).length;
  }

  String _deepReferenceNote(
    CandidatePlanningContext context,
    AppLanguage language,
  ) {
    final summary = context.deepReference?.summary.trim() ?? '';
    if (summary.isEmpty) return '';
    final snippet = _snippet(summary, language);
    return switch (language) {
      AppLanguage.simplifiedChinese => '；也参考了深度分析中的“$snippet”',
      AppLanguage.traditionalChinese => '；也參考了深度分析中的「$snippet」',
      AppLanguage.japanese => '。深度分析の「$snippet」も参考にしています',
      AppLanguage.english =>
        '. It also references the deep analysis: “$snippet”',
    };
  }

  int _focusScore(RecentSignalModel signal, List<String> focusDomainIds) {
    final text = [
      signal.content,
      signal.scene,
      signal.friction,
      signal.positiveSignal,
    ].whereType<String>().join(' ').toLowerCase();
    const keywords = <String, List<String>>{
      'emotional_stability': ['情绪', '焦虑', '紧绷', 'emotion', 'anxious', 'stress'],
      'relationship_connection': ['关系', '沟通', '被理解', 'relationship', 'connect'],
      'meaning_value': ['意义', '价值', '被看见', 'meaning', 'value'],
      'self_boundary': ['边界', '拒绝', '真实需要', 'boundary'],
      'growth_plan': ['成长', '目标', '下一步', '练习', 'goal', 'learn'],
      'creative_expression': ['创作', '表达', '写作', '灵感', 'creative', 'write'],
      'food_sleep': ['睡眠', '饮食', '疲惫', '恢复', 'sleep', 'food', 'tired'],
      'living_environment': ['居住', '环境', '金钱', '秩序', 'home', 'money'],
      'interests_hobbies': [
        '兴趣',
        '旅行',
        '自然',
        '运动',
        'hobby',
        'travel',
        'nature'
      ],
    };
    var score = 0;
    for (var index = 0; index < focusDomainIds.length; index++) {
      final matches = keywords[focusDomainIds[index]] ?? const <String>[];
      if (matches.any(text.contains)) {
        score += focusDomainIds.length - index;
      }
    }
    return score;
  }

  Future<CandidateFeedbackSummary> _feedbackSummaryForGate(
    CandidateGateState gate,
  ) async {
    final gateStart = DateTime.parse(gate.periodStart);
    final gateEnd = DateTime.parse(gate.periodEnd);
    final today = _dateOnly(nowLoader().toLocal());
    final feedbackWindowEnd =
        !today.isBefore(gateStart) && !today.isAfter(gateEnd) ? today : gateEnd;
    final feedbackWindowStart = feedbackWindowEnd.subtract(
      const Duration(days: 27),
    );
    final events = await feedbackEventRepository.listActiveBetween(
      localUserId: localUserId,
      startDate: _dateKey(feedbackWindowStart),
      endDate: _dateKey(feedbackWindowEnd),
    );
    final sorted = events.toList()
      ..sort((a, b) {
        final aTime = a.createdAt ?? a.occurredAt ?? DateTime(0);
        final bTime = b.createdAt ?? b.occurredAt ?? DateTime(0);
        final timeCompare = aTime.compareTo(bTime);
        if (timeCompare != 0) return timeCompare;
        return a.id.compareTo(b.id);
      });
    final latest = <String, FeedbackEventModel>{};
    for (final event in sorted) {
      // Goal/schedule facts keep the latest daily projection. A quick
      // experiment is attempt-based, so several same-day attempts remain
      // independent inputs to later candidate planning.
      final key = event.sourceType == 'micro_action_feedback'
          ? event.id
          : '${event.subjectType}|${event.subjectId}|${event.localDate}';
      latest[key] = event;
    }
    final effective = latest.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    var completedCount = 0;
    var notCompletedCount = 0;
    var helpfulCount = 0;
    var difficultCount = 0;
    var skippedCount = 0;
    for (final event in effective) {
      final normalizedStatus = _normalized(event.status);
      final text = [
        event.status,
        event.effect,
        event.note,
        ...event.metadata.values.map((value) => value?.toString()),
      ].whereType<String>().join(' ').toLowerCase();
      final normalizedDifficulty = _normalized(
        event.metadata['difficulty']?.toString() ?? '',
      );
      final normalizedAdjustment = _normalized(
        event.metadata['next_adjustment']?.toString() ?? '',
      );
      if (const {
        'completed',
        'yes',
        'done',
        'happened',
        'occurred',
        'tried',
      }.contains(normalizedStatus)) {
        completedCount += 1;
      } else if (const {
        'no',
        'not_completed',
        'not_done',
        'not_happened',
        'not_occurred',
        'not_suitable_today',
      }.contains(normalizedStatus)) {
        notCompletedCount += 1;
      }
      final isExplicitSkip = normalizedStatus == 'skipped' ||
          const {'skip', 'skipped', 'change_direction'}
              .contains(normalizedAdjustment) ||
          _hasAny(text, const [
            'explicit_skip',
            'skip_this',
            'skipped_by_user',
            '明确跳过',
          ]);
      final hasExplicitDifficulty = const {
            'hard',
            'very_hard',
            'too_hard',
            'difficult',
            'draining',
          }.contains(normalizedDifficulty) ||
          _hasAny(text, const [
            'not_helpful',
            'too hard',
            'too_hard',
            'difficult',
            'draining',
            '困难',
            '太难',
            '耗力',
          ]);
      if (isExplicitSkip) {
        skippedCount += 1;
      } else if (hasExplicitDifficulty) {
        difficultCount += 1;
      } else if (_hasAny(text, const [
        'helpful',
        'lighter',
        'restor',
        'easy',
        '有帮助',
        '恢复',
      ])) {
        helpfulCount += 1;
      }
    }
    final canonical = effective.map((event) {
      return [
        event.id,
        event.subjectType,
        event.subjectId,
        event.localDate,
        event.status,
        event.effect ?? '',
        event.note ?? '',
        jsonEncode(event.metadata),
      ].join('|');
    }).join('\n');
    return CandidateFeedbackSummary(
      effectiveEventIds:
          effective.map((event) => event.id).toList(growable: false),
      completedCount: completedCount,
      notCompletedCount: notCompletedCount,
      helpfulCount: helpfulCount,
      difficultCount: difficultCount,
      skippedCount: skippedCount,
      sourceHash: _fnv1a(canonical),
    );
  }

  Future<List<String>> _loadPersistedFocusDomainIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final direct = prefs.getStringList(FocusDomains.productPreferenceKey) ??
          prefs.getStringList(FocusDomains.preferenceKey);
      final normalized = FocusDomains.normalizeIds(direct ?? const []);
      if (normalized.isNotEmpty) return normalized;
      return FocusDomains.normalizeIds([
        prefs.getString(FocusDomains.legacyRepeatAreaKey),
        prefs.getString(FocusDomains.legacySelectedRepeatAreaKey),
        ...FocusDomains.defaultIds,
      ]);
    } catch (_) {
      return FocusDomains.normalizeIds(FocusDomains.defaultIds);
    }
  }

  Future<AdvancedEnergyExternalSummary?>
      _loadPersistedExternalEnergySummary() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return ExternalEnergyHintStore(prefs).loadHealthSummary();
    } catch (_) {
      return null;
    }
  }

  String _energyAdaptationText(EnergyCapacityBand band, AppLanguage language,
      {required CandidateKind kind}) {
    if (kind == CandidateKind.lifeExperiment) {
      final description = switch (language) {
        AppLanguage.simplifiedChinese => switch (band) {
            EnergyCapacityBand.veryLow => '能量适配：目标可以持续观察，但把每天的要求降到 5 分钟以内。',
            EnergyCapacityBand.low => '能量适配：目标持续观察，每天只保留一个低切换步骤。',
            EnergyCapacityBand.medium => '能量适配：目标持续观察，用每天一次的真实反馈判断效果。',
            EnergyCapacityBand.high => '能量适配：目标可以长期观察；可以稍深一点，但每天仍只做一个明确步骤。',
            EnergyCapacityBand.unknown =>
              '能量适配：当前能量 Signal 不明确，目标保持可暂停、低要求，并持续观察。',
          },
        AppLanguage.traditionalChinese => switch (band) {
            EnergyCapacityBand.veryLow => '能量適配：目標可以持續觀察，但把每天的要求降到 5 分鐘以內。',
            EnergyCapacityBand.low => '能量適配：目標持續觀察，每天只保留一個低切換步驟。',
            EnergyCapacityBand.medium => '能量適配：目標持續觀察，用每天一次的真實回饋判斷效果。',
            EnergyCapacityBand.high => '能量適配：目標可以長期觀察；可以稍深一點，但每天仍只做一個明確步驟。',
            EnergyCapacityBand.unknown =>
              '能量適配：目前能量 Signal 不明確，目標保持可暫停、低要求，並持續觀察。',
          },
        AppLanguage.japanese => switch (band) {
            EnergyCapacityBand.veryLow =>
              'エネルギー調整：目標は継続して観察しつつ、1日の負担を5分以内にします。',
            EnergyCapacityBand.low =>
              'エネルギー調整：目標は継続して観察し、毎日は切り替えの少ない一つの手順だけにします。',
            EnergyCapacityBand.medium =>
              'エネルギー調整：目標は継続して観察し、1日1回の実際の記録で効果を確かめます。',
            EnergyCapacityBand.high =>
              'エネルギー調整：目標は長期的に観察でき、少し深めでも毎日は一つの明確な手順にします。',
            EnergyCapacityBand.unknown =>
              'エネルギー調整：状態がまだ不明なため、目標は中断できる低負担の形で継続して観察します。',
          },
        AppLanguage.english => switch (band) {
            EnergyCapacityBand.veryLow =>
              'Energy fit: the goal can stay ongoing, but each day stays within 5 minutes.',
            EnergyCapacityBand.low =>
              'Energy fit: the goal stays ongoing with only one low-switch step each day.',
            EnergyCapacityBand.medium =>
              'Energy fit: the goal stays ongoing and uses one real check-in each day to judge its effect.',
            EnergyCapacityBand.high =>
              'Energy fit: the goal can be observed long-term; it may go slightly deeper, but still has one clear step each day.',
            EnergyCapacityBand.unknown =>
              'Energy fit: capacity is unclear, so the ongoing goal stays pausable and low-demand.',
          },
      };
      final boundary = switch (language) {
        AppLanguage.simplifiedChinese => '当天负担过高时可以缩小或暂停，不算失败。',
        AppLanguage.traditionalChinese => '當天負擔過高時可以縮小或暫停，不算失敗。',
        AppLanguage.japanese => 'その日の負担が大きい場合は縮小・中断でき、失敗にはなりません。',
        AppLanguage.english =>
          'On a high-load day it can be reduced or paused without counting as failure.',
      };
      return '$description $boundary';
    }
    return switch (language) {
      AppLanguage.simplifiedChinese => switch (band) {
          EnergyCapacityBand.veryLow => '能量适配：最近的明确状态偏低，所以小实验保持在 1 分钟、可暂停。',
          EnergyCapacityBand.low => '能量适配：当前消耗线索较多，所以小实验控制在 2 分钟，并减少切换。',
          EnergyCapacityBand.medium => '能量适配：当前 Signal 支持 5 分钟以内、单一步骤的小实验。',
          EnergyCapacityBand.high => '能量适配：当前状态较稳定，小实验仍控制在 10 分钟以内，避免变成任务。',
          EnergyCapacityBand.unknown =>
            '能量适配：当前能量 Signal 还不明确，因此小实验保持在 2 分钟、可逆、无完成压力。',
        },
      AppLanguage.traditionalChinese => switch (band) {
          EnergyCapacityBand.veryLow => '能量適配：最近的明確狀態偏低，所以小實驗保持在 1 分鐘、可暫停。',
          EnergyCapacityBand.low => '能量適配：目前消耗線索較多，所以小實驗控制在 2 分鐘，並減少切換。',
          EnergyCapacityBand.medium => '能量適配：目前 Signal 支持 5 分鐘以內、單一步驟的小實驗。',
          EnergyCapacityBand.high => '能量適配：目前狀態較穩定，小實驗仍控制在 10 分鐘以內，避免變成任務。',
          EnergyCapacityBand.unknown =>
            '能量適配：目前能量 Signal 還不明確，因此小實驗保持在 2 分鐘、可逆、沒有完成壓力。',
        },
      AppLanguage.japanese => switch (band) {
          EnergyCapacityBand.veryLow =>
            'エネルギー調整：明確な状態が低めなので、1分で中断できる短い実験にしています。',
          EnergyCapacityBand.low =>
            'エネルギー調整：負荷の手がかりが多いため、2分で切り替えの少ない短い実験にしています。',
          EnergyCapacityBand.medium => 'エネルギー調整：5分以内で一つの手順だけ試せる案です。',
          EnergyCapacityBand.high =>
            'エネルギー調整：状態が比較的安定していても、タスクにならないよう10分以内にしています。',
          EnergyCapacityBand.unknown =>
            'エネルギー調整：手がかりがまだ十分でないため、2分で戻せて達成圧のない案にしています。',
        },
      AppLanguage.english => switch (band) {
          EnergyCapacityBand.veryLow =>
            'Energy fit: your latest explicit state is low, so this quick experiment stays within 1 minute and can be paused.',
          EnergyCapacityBand.low =>
            'Energy fit: current load signals are higher, so this quick experiment stays within 2 minutes with fewer switches.',
          EnergyCapacityBand.medium =>
            'Energy fit: the current Signals support one clear quick experiment within 5 minutes.',
          EnergyCapacityBand.high =>
            'Energy fit: even with steadier capacity, this stays within 10 minutes so it does not become a task.',
          EnergyCapacityBand.unknown =>
            'Energy fit: current capacity is not clear yet, so this stays within 2 minutes, reversible, and pressure-free.',
        },
    };
  }

  Future<void> _invalidateCurrentPlanningContexts(String reason) async {
    final now = nowLoader().toLocal();
    final day = _dateOnly(now);
    final weekStart = _startOfWeek(now);
    final dayKey = _dateKey(day);
    final weekStartKey = _dateKey(weekStart);
    final weekEndKey = _dateKey(weekStart.add(const Duration(days: 6)));
    final invalidatedAt = now.toUtc();
    final db = await localDatabase.database;
    await db.transaction((txn) async {
      await _stalePreviousGroups(
        txn,
        kind: CandidateKind.microAction,
        periodStart: dayKey,
        reason: reason,
        invalidatedAt: invalidatedAt,
      );
      await _stalePreviousGroups(
        txn,
        kind: CandidateKind.lifeExperiment,
        periodStart: weekStartKey,
        reason: reason,
        invalidatedAt: invalidatedAt,
      );
    });
    CandidateInvalidationBus.publish(CandidateInvalidationNotice(
      localDatabase: localDatabase,
      candidateKind: CandidateKind.microAction.storageValue,
      periodStart: dayKey,
      periodEnd: dayKey,
    ));
    CandidateInvalidationBus.publish(CandidateInvalidationNotice(
      localDatabase: localDatabase,
      candidateKind: CandidateKind.lifeExperiment.storageValue,
      periodStart: weekStartKey,
      periodEnd: weekEndKey,
    ));
  }

  int _smallTryDurationMinutes(EnergyCapacityBand band) => switch (band) {
        EnergyCapacityBand.veryLow => 1,
        EnergyCapacityBand.low => 2,
        EnergyCapacityBand.unknown => 3,
        EnergyCapacityBand.medium => 5,
        EnergyCapacityBand.high => SmallTryPlanningLimits.maxDurationMinutes,
      };

  _FeedbackPlanningMode _feedbackPlanningMode(
    CandidateFeedbackSummary feedback,
  ) {
    final adverseCount = feedback.difficultCount + feedback.skippedCount;
    if (feedback.helpfulCount > adverseCount) {
      return _FeedbackPlanningMode.reinforce;
    }
    if (feedback.skippedCount > 0 &&
        feedback.skippedCount >= feedback.difficultCount) {
      return _FeedbackPlanningMode.redirect;
    }
    if (feedback.difficultCount > 0 &&
        feedback.difficultCount >= feedback.skippedCount) {
      return _FeedbackPlanningMode.reduce;
    }
    if (feedback.helpfulCount > 0) {
      return _FeedbackPlanningMode.reinforce;
    }
    return _FeedbackPlanningMode.neutral;
  }

  int _feedbackAdjustedSmallTryMinutes(
    int baseMinutes,
    _FeedbackPlanningMode mode,
  ) {
    final adjusted = switch (mode) {
      _FeedbackPlanningMode.reduce => baseMinutes - 1,
      _FeedbackPlanningMode.redirect => 1,
      _ => baseMinutes,
    };
    return adjusted.clamp(1, SmallTryPlanningLimits.maxDurationMinutes).toInt();
  }

  EnergyRecommendedIntensity _feedbackAdjustedIntensity(
    EnergyRecommendedIntensity base,
    _FeedbackPlanningMode mode,
  ) {
    return switch (mode) {
      _FeedbackPlanningMode.reduce ||
      _FeedbackPlanningMode.redirect =>
        EnergyRecommendedIntensity.veryLight,
      _ => base,
    };
  }

  int _weeklySuggestionIndex(
    EnergyCapacityBand band,
    _FeedbackPlanningMode feedbackMode,
    int index,
  ) {
    final order = switch (feedbackMode) {
      _FeedbackPlanningMode.reinforce => const [2, 0, 1],
      _FeedbackPlanningMode.reduce => const [1, 0, 2],
      _FeedbackPlanningMode.redirect => const [0, 2, 1],
      _FeedbackPlanningMode.neutral => switch (band) {
          EnergyCapacityBand.veryLow || EnergyCapacityBand.low => const [
              1,
              0,
              2,
            ],
          EnergyCapacityBand.high => const [2, 0, 1],
          _ => const [0, 1, 2],
        },
    };
    return order[index % order.length];
  }

  (String, String) _feedbackAdjustedDailyCopy(
    AppLanguage language,
    _FeedbackPlanningMode mode,
    (String, String) base,
    int minutes,
  ) {
    if (mode == _FeedbackPlanningMode.neutral) return base;
    return switch (language) {
      AppLanguage.simplifiedChinese => switch (mode) {
          _FeedbackPlanningMode.reinforce => (
              '延续有效做法：${base.$1}',
              '最近反馈显示轻做法有帮助；先保留同样的低负担方式，不加码。${base.$2}',
            ),
          _FeedbackPlanningMode.reduce => (
              '再缩小一点：${base.$1}',
              '最近反馈显示之前的做法偏耗力，因此已降到 $minutes 分钟，并保留随时暂停。${base.$2}',
            ),
          _FeedbackPlanningMode.redirect => (
              '换个方向：${base.$1}',
              '最近一次没有完成，因此不重复原做法，改用另一种 1 分钟轻尝试。${base.$2}',
            ),
          _FeedbackPlanningMode.neutral => base,
        },
      AppLanguage.traditionalChinese => switch (mode) {
          _FeedbackPlanningMode.reinforce => (
              '延續有效做法：${base.$1}',
              '最近回饋顯示輕做法有幫助；先保留同樣的低負擔方式，不加碼。${base.$2}',
            ),
          _FeedbackPlanningMode.reduce => (
              '再縮小一點：${base.$1}',
              '最近回饋顯示先前的做法偏耗力，因此已降到 $minutes 分鐘，並保留隨時暫停。${base.$2}',
            ),
          _FeedbackPlanningMode.redirect => (
              '換個方向：${base.$1}',
              '最近一次沒有完成，因此不重複原做法，改用另一種 1 分鐘輕嘗試。${base.$2}',
            ),
          _FeedbackPlanningMode.neutral => base,
        },
      AppLanguage.japanese => switch (mode) {
          _FeedbackPlanningMode.reinforce => (
              '役立った方法を続ける：${base.$1}',
              '最近の記録では小さな方法が役立っています。同じ低負担の形を保ち、増やしません。${base.$2}',
            ),
          _FeedbackPlanningMode.reduce => (
              'もう少し小さくする：${base.$1}',
              '前の方法は負担が大きかったため、$minutes分に縮め、いつでも中断できます。${base.$2}',
            ),
          _FeedbackPlanningMode.redirect => (
              '別の方向を試す：${base.$1}',
              '最近は完了しなかったため、同じ方法を繰り返さず、別の1分の短い実験に変えます。${base.$2}',
            ),
          _FeedbackPlanningMode.neutral => base,
        },
      AppLanguage.english => switch (mode) {
          _FeedbackPlanningMode.reinforce => (
              'Continue what helped: ${base.$1}',
              'Recent feedback says a small approach helped, so this keeps the same low-demand shape without adding more. ${base.$2}',
            ),
          _FeedbackPlanningMode.reduce => (
              'Make it smaller: ${base.$1}',
              'Recent feedback says the earlier approach felt difficult, so this is reduced to $minutes minute${minutes == 1 ? '' : 's'} and can be paused. ${base.$2}',
            ),
          _FeedbackPlanningMode.redirect => (
              'Try a different direction: ${base.$1}',
              'The latest attempt was not completed, so this changes direction instead of repeating it and stays within 1 minute. ${base.$2}',
            ),
          _FeedbackPlanningMode.neutral => base,
        },
    };
  }

  (String, String, String) _feedbackAdjustedWeeklyCopy(
    AppLanguage language,
    _FeedbackPlanningMode mode,
    (String, String, String) base,
  ) {
    final boundary = _goalPauseBoundary(language);
    return switch (language) {
      AppLanguage.simplifiedChinese => switch (mode) {
          _FeedbackPlanningMode.neutral => (
              base.$1,
              base.$2,
              '${base.$3} $boundary',
            ),
          _FeedbackPlanningMode.reinforce => (
              '延续有效方向：${base.$1}',
              '最近反馈显示某种低负担做法有帮助，因此保留有效部分并延长观察。${base.$2}',
              '沿用最近有效的低负担方式：${base.$3} $boundary',
            ),
          _FeedbackPlanningMode.reduce => (
              '缩小后再观察：${base.$1}',
              '最近反馈显示原做法偏耗力，因此先降低每日要求，再判断是否有效。${base.$2}',
              '先缩到最低要求：${base.$3.replaceFirst('10', '5')} $boundary',
            ),
          _FeedbackPlanningMode.redirect => (
              '换一个方向观察：${base.$1}',
              '最近一次没有完成，因此不继续复制原做法，先改为更低要求的观察。${base.$2}',
              '持续观察，每天只记录一次相似场景是否出现；不要求完成原做法。$boundary',
            ),
        },
      AppLanguage.traditionalChinese => switch (mode) {
          _FeedbackPlanningMode.neutral => (
              base.$1,
              base.$2,
              '${base.$3} $boundary',
            ),
          _FeedbackPlanningMode.reinforce => (
              '延續有效方向：${base.$1}',
              '最近回饋顯示某種低負擔做法有幫助，因此保留有效部分並延長觀察。${base.$2}',
              '沿用最近有效的低負擔方式：${base.$3} $boundary',
            ),
          _FeedbackPlanningMode.reduce => (
              '縮小後再觀察：${base.$1}',
              '最近回饋顯示原做法偏耗力，因此先降低每日要求，再判斷是否有效。${base.$2}',
              '先縮到最低要求：${base.$3.replaceFirst('10', '5')} $boundary',
            ),
          _FeedbackPlanningMode.redirect => (
              '換一個方向觀察：${base.$1}',
              '最近一次沒有完成，因此不繼續複製原做法，先改為更低要求的觀察。${base.$2}',
              '持續觀察，每天只記錄一次相似情境是否出現；不要求完成原做法。$boundary',
            ),
        },
      AppLanguage.japanese => switch (mode) {
          _FeedbackPlanningMode.neutral => (
              base.$1,
              base.$2,
              '${base.$3} $boundary',
            ),
          _FeedbackPlanningMode.reinforce => (
              '役立った方向を続ける：${base.$1}',
              '最近の記録で低負担の方法が役立ったため、有効な部分を保って観察を延ばします。${base.$2}',
              '最近役立った低負担の形を続けます：${base.$3} $boundary',
            ),
          _FeedbackPlanningMode.reduce => (
              '小さくして観察する：${base.$1}',
              '前の方法は負担が大きかったため、1日の要求を下げてから効果を確かめます。${base.$2}',
              'まず最低限まで縮めます：${base.$3.replaceFirst('10', '5')} $boundary',
            ),
          _FeedbackPlanningMode.redirect => (
              '別の方向を観察する：${base.$1}',
              '最近は完了しなかったため、同じ方法を繰り返さず、より低負担の観察に変えます。${base.$2}',
              '継続して、似た場面が現れたかを毎日一度だけ記録し、元の方法の完了は求めません。$boundary',
            ),
        },
      AppLanguage.english => switch (mode) {
          _FeedbackPlanningMode.neutral => (
              base.$1,
              base.$2,
              '${base.$3} $boundary',
            ),
          _FeedbackPlanningMode.reinforce => (
              'Continue an effective direction: ${base.$1}',
              'Recent feedback says a low-demand approach helped, so this keeps what worked and extends the observation. ${base.$2}',
              'Keep the recently helpful low-demand shape: ${base.$3} $boundary',
            ),
          _FeedbackPlanningMode.reduce => (
              'Reduce it before observing: ${base.$1}',
              'Recent feedback says the earlier approach felt difficult, so this lowers the daily demand before judging the effect. ${base.$2}',
              'Start with the minimum version: ${base.$3.replaceFirst('10-minute', '5-minute')} $boundary',
            ),
          _FeedbackPlanningMode.redirect => (
              'Observe a different direction: ${base.$1}',
              'The latest attempt was not completed, so this switches to a lower-demand observation instead of repeating it. ${base.$2}',
              'Keep observing and note once a day whether a similar moment appeared; completing the earlier approach is not required. $boundary',
            ),
        },
    };
  }

  String _goalPauseBoundary(AppLanguage language) => switch (language) {
        AppLanguage.simplifiedChinese => '当天负担过高时可以缩小或暂停，不算失败。',
        AppLanguage.traditionalChinese => '當天負擔過高時可以縮小或暫停，不算失敗。',
        AppLanguage.japanese => 'その日の負担が大きい場合は縮小・中断でき、失敗にはなりません。',
        AppLanguage.english =>
          'On a high-load day, reduce or pause it without counting that as failure.',
      };

  (String, String) _dailySuggestionCopy(
    AppLanguage language,
    int index,
    String snippet,
    int minutes,
  ) {
    switch (language) {
      case AppLanguage.simplifiedChinese:
        return switch (index) {
          0 => ('现在用 $minutes 分钟补一句具体场景', '来自今天的信号：“$snippet”'),
          1 => ('现在留 $minutes 分钟不切换的缓冲', '今天的信号提示这个时刻值得先放轻一点：“$snippet”'),
          _ => (
              '现在做一个 $minutes 分钟的低要求恢复',
              '用一个可以立即开始、随时暂停的轻行为回应今天的信号：“$snippet”'
            ),
        };
      case AppLanguage.traditionalChinese:
        return switch (index) {
          0 => ('現在用 $minutes 分鐘補一句具體情境', '來自今天的信號：「$snippet」'),
          1 => ('現在留 $minutes 分鐘不切換的緩衝', '今天的信號提示這個時刻值得先放輕一點：「$snippet」'),
          _ => (
              '現在做一個 $minutes 分鐘的低要求恢復',
              '用一個可以立即開始、隨時暫停的輕行為回應今天的信號：「$snippet」'
            ),
        };
      case AppLanguage.japanese:
        return switch (index) {
          0 => ('今、$minutes分で具体的な状況を一言足す', '今日のシグナル「$snippet」をもとにしています。'),
          1 => (
              '今、$minutes分だけ切り替えない余白をつくる',
              'このシグナルが、少し軽くする余地を示しています：「$snippet」'
            ),
          _ => (
              '今、$minutes分の負担が少ない回復をする',
              'すぐ始められて、いつでも止められる軽い行動です：「$snippet」'
            ),
        };
      case AppLanguage.english:
        return switch (index) {
          0 => (
              'Add one concrete line now for $minutes minute${minutes == 1 ? '' : 's'}',
              'Grounded in today’s signal: “$snippet”'
            ),
          1 => (
              'Take a $minutes-minute no-switch buffer now',
              'This signal suggests a moment worth making lighter: “$snippet”'
            ),
          _ => (
              'Take a $minutes-minute low-demand recovery now',
              'An immediate, pausable quick experiment grounded in today’s signal: “$snippet”'
            ),
        };
    }
  }

  (String, String, String) _weeklySuggestionCopy(
    AppLanguage language,
    int index,
    String snippet,
  ) {
    switch (language) {
      case AppLanguage.simplifiedChinese:
        return switch (index) {
          0 => (
              '连续观察相似场景',
              '如果连续多日记录相似场景，可能更容易看清“$snippet”是否会重复。',
              '从下周开始，每天遇到相似情况时补一句发生了什么，持续到能看出变化。',
            ),
          1 => (
              '预留一个低成本恢复块',
              '如果先留一点缓冲，“$snippet”带来的消耗可能更容易被看见。',
              '从下周开始，每天在一个相似时刻前留 10 分钟空白，并持续记录体感变化。',
            ),
          _ => (
              '重复一次变轻的做法',
              '如果重复一个微小的有效做法，可能更容易判断“$snippet”的变化。',
              '从下周开始，每天重复一次让状态稍微变轻的做法，并持续记录结果。',
            ),
        };
      case AppLanguage.traditionalChinese:
        return switch (index) {
          0 => (
              '連續觀察相似情境',
              '如果連續多日記錄相似情境，可能更容易看清「$snippet」是否重複。',
              '從下週開始，每天遇到相似情況時補一句發生了什麼，持續到能看出變化。'
            ),
          1 => (
              '預留一個低成本恢復塊',
              '如果先留一點緩衝，「$snippet」帶來的消耗可能更容易被看見。',
              '從下週開始，每天在一個相似時刻前留 10 分鐘空白，並持續記錄體感變化。'
            ),
          _ => (
              '重複一次變輕的做法',
              '如果重複一個微小的有效做法，可能更容易判斷「$snippet」的變化。',
              '從下週開始，每天重複一次讓狀態稍微變輕的做法，並持續記錄結果。'
            ),
        };
      case AppLanguage.japanese:
        return switch (index) {
          0 => (
              '似た場面を続けて観察する',
              '数日続けて記録すると「$snippet」が繰り返すか見やすくなります。',
              '来週から、似た場面があれば毎日一言だけ記録し、変化が見えるまで続けます。'
            ),
          1 => (
              '小さな回復の余白をつくる',
              '少し余白を先に取ると「$snippet」の負荷を確かめやすくなります。',
              '来週から、毎日一度、似た場面の前に10分の余白をつくり、体感の変化を記録します。'
            ),
          _ => (
              '少し楽になった方法をもう一度試す',
              '小さく繰り返すと「$snippet」の変化を見つけやすくなります。',
              '来週から、少し楽になった方法を毎日一度繰り返し、結果を継続して記録します。'
            ),
        };
      case AppLanguage.english:
        return switch (index) {
          0 => (
              'Keep observing similar moments',
              'Repeated observations can show whether “$snippet” is a pattern.',
              'Starting next week, add one line each day when a similar moment occurs and continue until a change is visible.'
            ),
          1 => (
              'Reserve a low-cost recovery block',
              'A little buffer may make the load around “$snippet” easier to see.',
              'Starting next week, leave a 10-minute buffer before one similar moment each day and keep noting how it feels.'
            ),
          _ => (
              'Repeat one thing that felt lighter',
              'A small repeat can help test how “$snippet” changes.',
              'Starting next week, repeat one thing that felt a little lighter each day and keep noting the result.'
            ),
        };
    }
  }

  String _snippet(String value, AppLanguage language) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) {
      return switch (language) {
        AppLanguage.simplifiedChinese => '今天记录的生活信号',
        AppLanguage.traditionalChinese => '今天記錄的生活信號',
        AppLanguage.japanese => '今日記録した生活シグナル',
        AppLanguage.english => 'a signal you recorded today',
      };
    }
    const maxLength = 28;
    return normalized.length <= maxLength
        ? normalized
        : '${normalized.substring(0, maxLength)}…';
  }

  List<RecentSignalModel> _distinctEligible(
    Iterable<RecentSignalModel> signals,
    SignalEligibilityStage stage,
  ) {
    final seen = <String>{};
    final result = <RecentSignalModel>[];
    for (final signal in eligibilityService.filter(signals, stage)) {
      final id = _signalId(signal);
      if (id.isEmpty || !seen.add(id)) continue;
      result.add(signal);
    }
    return result;
  }

  Future<Map<String, Object?>?> _readyGroup(
    DatabaseExecutor db, {
    required CandidateKind kind,
    required String periodStart,
    required String sourceHash,
  }) async {
    final rows = await db.query(
      'candidate_groups',
      where: '''
        local_user_id = ? AND candidate_kind = ? AND period_start = ?
        AND source_hash = ? AND status = ? AND dirty = 0 AND is_stale = 0
      ''',
      whereArgs: [
        localUserId,
        kind.storageValue,
        periodStart,
        sourceHash,
        'ready',
      ],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> _stalePreviousGroups(
    DatabaseExecutor db, {
    required CandidateKind kind,
    required String periodStart,
    required String reason,
    required DateTime invalidatedAt,
  }) async {
    final rows = await db.query(
      'candidate_groups',
      columns: const ['id'],
      where: '''
        local_user_id = ? AND candidate_kind = ? AND period_start = ?
        AND status != ?
      ''',
      whereArgs: [localUserId, kind.storageValue, periodStart, 'stale'],
    );
    if (rows.isEmpty) return;
    final ids = rows.map((row) => row['id'] as String).toList();
    final placeholders = List.filled(ids.length, '?').join(', ');
    final values = {
      'status': 'stale',
      'dirty': 1,
      'is_stale': 1,
      'stale_reason': reason,
      'invalidated_at': invalidatedAt.toIso8601String(),
      'updated_at': invalidatedAt.toIso8601String(),
    };
    await db.update(
      'candidate_groups',
      values,
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
    if (kind == CandidateKind.microAction) {
      await db.update(
        'micro_action_candidates',
        {
          'dirty': 1,
          'is_stale': 1,
          'stale_reason': reason,
          'invalidated_at': invalidatedAt.toIso8601String(),
          'updated_at': invalidatedAt.toIso8601String(),
        },
        where: '''
          candidate_group_id IN ($placeholders)
          AND status IN (?, ?, ?)
        ''',
        whereArgs: [...ids, 'generated', 'edited', 'dismissed'],
      );
    } else {
      await db.update(
        'experiment_candidates',
        {
          'dirty': 1,
          'is_stale': 1,
          'stale_reason': reason,
          'invalidated_at': invalidatedAt.toIso8601String(),
          'updated_at': invalidatedAt.toIso8601String(),
        },
        where: '''
          candidate_group_id IN ($placeholders)
          AND status IN (?, ?, ?)
        ''',
        whereArgs: [...ids, 'generated', 'edited', 'dismissed'],
      );
    }
  }

  Map<String, Object?> _groupRow({
    required String id,
    required CandidateGateState gate,
    required String sourceHash,
    required String status,
    required DateTime now,
  }) {
    return {
      'id': id,
      'local_user_id': localUserId,
      'candidate_kind': gate.kind.storageValue,
      'period_start': gate.periodStart,
      'period_end': gate.periodEnd,
      'source_hash': sourceHash,
      'status': status,
      'required_signal_count': requiredSignalCount,
      'eligible_signal_count': gate.eligibleSignalCount,
      'dirty': status == 'stale' ? 1 : 0,
      'is_stale': status == 'stale' ? 1 : 0,
      'stale_reason': null,
      'invalidated_at': null,
      'generation_started_at':
          status == 'regenerating' ? now.toIso8601String() : null,
      'generation_finished_at':
          status == 'ready' ? now.toIso8601String() : null,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    };
  }

  Future<void> _emitState(
    CandidateKind kind,
    String periodStart,
    String periodEnd,
  ) async {
    if (_disposed || _stateEvents.isClosed) return;
    try {
      final state = await getGenerationState(
        kind: kind,
        periodStart: periodStart,
        periodEnd: periodEnd,
      );
      if (_disposed || _stateEvents.isClosed) return;
      _stateEvents.add(state);
    } catch (_) {
      if (!_disposed) rethrow;
    }
  }

  SevenDayProgressModel _buildProgress({
    required String subjectId,
    required DateTime start,
    required List<Map<String, Object?>> feedbackRows,
    required String? Function(Map<String, Object?> row) dateOf,
    required String? Function(Map<String, Object?> row) idOf,
    required Object? Function(Map<String, Object?> row) timeOf,
    required ProgressCellState? Function(Map<String, Object?> row) stateOf,
  }) {
    final effective = <String, SevenDayProgressCell>{};
    for (final row in feedbackRows) {
      final date = dateOf(row)?.trim();
      final state = stateOf(row);
      if (date == null || date.isEmpty || state == null) continue;
      effective[date] = SevenDayProgressCell(
        localDate: date,
        state: state,
        latestEventId: idOf(row),
        latestEventAt: _parseDate(timeOf(row)),
      );
    }
    final cells = <SevenDayProgressCell>[];
    for (var index = 0; index < SevenDayProgressModel.totalDays; index++) {
      final date = _dateKey(start.add(Duration(days: index)));
      cells.add(effective[date] ??
          SevenDayProgressCell(
            localDate: date,
            state: ProgressCellState.empty,
          ));
    }
    return SevenDayProgressModel(
      subjectId: subjectId,
      startDate: _dateKey(start),
      endDate: _dateKey(start.add(const Duration(days: 6))),
      cells: cells,
    );
  }

  /// Compatibility container with attempt semantics. Every valid feedback
  /// row becomes one cell, including several attempts on the same local day.
  /// There are no synthetic empty days and no seven-entry ceiling.
  SevenDayProgressModel _buildAttemptProgress({
    required String subjectId,
    required DateTime start,
    required List<Map<String, Object?>> feedbackRows,
    required String? Function(Map<String, Object?> row) dateOf,
    required String? Function(Map<String, Object?> row) idOf,
    required Object? Function(Map<String, Object?> row) timeOf,
    required ProgressCellState? Function(Map<String, Object?> row) stateOf,
  }) {
    final cells = <SevenDayProgressCell>[];
    for (final row in feedbackRows) {
      final date = dateOf(row)?.trim();
      final state = stateOf(row);
      if (date == null || date.isEmpty || state == null) continue;
      cells.add(SevenDayProgressCell(
        localDate: date,
        state: state,
        latestEventId: idOf(row),
        latestEventAt: _parseDate(timeOf(row)),
      ));
    }
    final endDate = cells.isEmpty ? _dateKey(start) : cells.last.localDate;
    return SevenDayProgressModel(
      subjectId: subjectId,
      startDate: _dateKey(start),
      endDate: endDate,
      cells: cells,
    );
  }

  SevenDayProgressModel _emptyProgress(String subjectId, DateTime date) {
    return _buildProgress(
      subjectId: subjectId,
      start: _dateOnly(date.toLocal()),
      feedbackRows: const [],
      dateOf: (_) => null,
      idOf: (_) => null,
      timeOf: (_) => null,
      stateOf: (_) => null,
    );
  }

  ProgressCellState? _microProgressState(Object? raw) {
    final value = _normalized(raw);
    if (const {'yes', 'happened', 'occurred', 'done', 'completed', 'true'}
        .contains(value)) {
      return ProgressCellState.completed;
    }
    if (const {
      'no',
      'not_completed',
      'not_happened',
      'not_occurred',
      'not_suitable_today',
      'skipped',
      'false',
    }.contains(value)) {
      return ProgressCellState.notCompleted;
    }
    return null;
  }

  ProgressCellState? _experimentProgressState(Object? raw) {
    final value = _normalized(raw);
    if (const {
      'yes',
      'happened',
      'occurred',
      'done',
      'completed',
      'partial_happened',
      'tried',
      'helpful',
      'adjusted',
    }.contains(value)) {
      return ProgressCellState.completed;
    }
    if (const {
      'no',
      'not_completed',
      'not_done',
      'not_happened',
      'not_occurred',
      'not_tried',
      'not_suitable_today',
      'not_today',
      'skipped',
    }.contains(value)) {
      return ProgressCellState.notCompleted;
    }
    return null;
  }

  CandidateGenerationState _mapGenerationState(Map<String, Object?> row) {
    final kind =
        row['candidate_kind'] == CandidateKind.lifeExperiment.storageValue
            ? CandidateKind.lifeExperiment
            : CandidateKind.microAction;
    return CandidateGenerationState(
      kind: kind,
      periodStart: row['period_start'] as String? ?? '',
      periodEnd: row['period_end'] as String? ?? '',
      status: CandidateGenerationStatus.fromStorage(row['status']),
      sourceHash: row['source_hash'] as String?,
      staleReason: row['stale_reason'] as String?,
      eligibleSignalCount: _toInt(row['eligible_signal_count']),
      generationStartedAt: _parseDate(row['generation_started_at']),
      generationFinishedAt: _parseDate(row['generation_finished_at']),
      updatedAt: _parseDate(row['updated_at']),
    );
  }

  MicroActionCandidateModel _mapMicroCandidate(Map<String, Object?> row) {
    final sourceHash = row['source_hash'] as String? ?? '';
    final fingerprint = CandidatePlanningFingerprint.tryParse(sourceHash);
    final reasonParts = _decodeMicroCandidateReason(
      row['reason'] as String? ?? '',
    );
    final recommendedIntensity = row['difficulty'] as String? ?? 'very_light';
    return MicroActionCandidateModel(
      id: row['id'] as String? ?? '',
      candidateGroupId: row['candidate_group_id'] as String? ?? '',
      localUserId: row['local_user_id'] as String? ?? localUserId,
      localDate: row['local_date'] as String? ?? '',
      rank: _toInt(row['rank']),
      title: row['title'] as String? ?? '',
      reason: reasonParts.$1,
      difficulty: recommendedIntensity,
      linkedSignalCardIds: _decodeStringList(
        row['linked_signal_card_ids_json'],
      ),
      focusDomainIds: _decodeStringList(row['focus_domain_ids_json']),
      status: row['status'] as String? ?? 'generated',
      decisionStatus: CandidateDecisionStatus.fromStorage(
        row['decision_status'],
      ),
      adoptedMicroActionId: row['adopted_micro_action_id'] as String?,
      sourceHash: sourceHash,
      energySnapshotHash: fingerprint?.energySnapshotHash ?? '',
      energyCapacityBand:
          fingerprint?.capacityBand ?? EnergyCapacityBand.unknown,
      energyAdaptationExplanation: reasonParts.$2,
      recommendedIntensity: recommendedIntensity,
      isStale: _toBool(row['is_stale']),
      staleReason: row['stale_reason'] as String?,
      createdAt: _parseDate(row['created_at']),
      updatedAt: _parseDate(row['updated_at']),
    );
  }

  ExperimentCandidateRecord _mapExperimentCandidate(
    Map<String, Object?> row,
  ) {
    final sourceHash = row['source_hash'] as String? ?? '';
    final fingerprint = CandidatePlanningFingerprint.tryParse(sourceHash);
    final metadata = _decodeMap(row['metadata_json']);
    final recommendedIntensity =
        metadata['recommended_intensity']?.toString().trim();
    return ExperimentCandidateRecord(
      id: row['id'] as String? ?? '',
      candidateGroupId: row['candidate_group_id'] as String? ?? '',
      localUserId: row['local_user_id'] as String? ?? localUserId,
      weekStart: row['source_week_start'] as String? ?? '',
      weekEnd: row['source_week_end'] as String? ?? '',
      rank: _toInt(row['candidate_rank']).clamp(1, maxCandidatesPerGroup),
      title: row['title'] as String? ?? '',
      hypothesis: row['hypothesis'] as String? ?? '',
      suggestedAction: row['suggested_action'] as String? ?? '',
      linkedSignalCardIds: _decodeStringList(
        row['linked_signal_card_ids_json'],
      ),
      linkedObservationIds: _decodeStringList(
        row['linked_observation_ids_json'],
      ),
      confidenceLevel: row['confidence_level'] as String? ?? 'medium',
      metadata: metadata,
      status: row['status'] as String? ?? 'generated',
      decisionStatus: CandidateDecisionStatus.fromStorage(
        row['decision_status'],
      ),
      adoptedExperimentId: row['adopted_experiment_id'] as String?,
      sourceHash: sourceHash,
      energySnapshotHash: metadata['energy_snapshot_hash']?.toString() ??
          fingerprint?.energySnapshotHash ??
          '',
      energyCapacityBand: EnergyCapacityBand.fromStorage(
        metadata['energy_capacity_band'] ??
            fingerprint?.capacityBand.storageValue,
      ),
      energyAdaptationExplanation:
          metadata['energy_adaptation_explanation']?.toString() ?? '',
      recommendedIntensity:
          recommendedIntensity == null || recommendedIntensity.isEmpty
              ? 'very_light'
              : recommendedIntensity,
      isStale: _toBool(row['is_stale']),
      staleReason: row['stale_reason'] as String?,
      createdAt: _parseDate(row['created_at']),
      updatedAt: _parseDate(row['updated_at']),
    );
  }

  Future<MicroActionModel> _microActionForDate(
    Map<String, Object?> row,
    String selectedLocalDate,
  ) async {
    final current = MicroActionModel.fromDb(row);
    final content = await planContentVersionRepository.resolveContent(
      localUserId: current.localUserId,
      objectKind: PlanContentObjectKind.quickTry,
      objectId: current.id,
      selectedLocalDate: selectedLocalDate,
    );
    if (content == null) return current;
    return MicroActionModel.fromDb(<String, Object?>{
      ...row,
      ...content,
    });
  }

  Future<LifeExperimentModel> _lifeExperimentForDate(
    Map<String, Object?> row,
    String selectedLocalDate,
  ) async {
    final current = LifeExperimentModel.fromJson(
      row.map((key, value) => MapEntry(key, value)),
    );
    final content = await planContentVersionRepository.resolveContent(
      localUserId: current.localUserId,
      objectKind: PlanContentObjectKind.goal,
      objectId: current.id,
      selectedLocalDate: selectedLocalDate,
    );
    if (content == null) return current;
    return LifeExperimentModel.fromJson(<String, dynamic>{
      ...row.map((key, value) => MapEntry(key, value)),
      ...content,
    });
  }

  Future<String?> _microActionEditEffectiveDate(
    MicroActionModel action,
  ) async {
    final today = _dateOnly(nowLoader().toLocal());
    final start = DateTime.tryParse(_microActionStartDate(action));
    final rawEnd = action.progressEndDate?.trim() ?? '';
    final end = DateTime.tryParse(rawEnd);
    if (start == null || (end != null && end.isBefore(start))) return null;
    final localStart = _dateOnly(start);
    final localEnd = end == null ? null : _dateOnly(end);
    if (localEnd != null && localEnd.isBefore(today)) return null;

    final nextWeekStart = _startOfWeek(today).add(const Duration(days: 7));
    final nextWeekEnd = nextWeekStart.add(const Duration(days: 6));
    if (localStart.isAfter(nextWeekEnd)) return null;

    late DateTime effective;
    if (!localStart.isBefore(nextWeekStart)) {
      effective = localStart;
    } else {
      final db = await localDatabase.database;
      final feedback = await db.query(
        'micro_action_feedback',
        columns: const ['id'],
        where: '''
          micro_action_id = ? AND local_date = ?
          AND COALESCE(is_valid, 1) = 1
        ''',
        whereArgs: [action.id, _dateKey(today)],
        limit: 1,
      );
      effective = feedback.isNotEmpty
          ? today.add(const Duration(days: 1))
          : (localStart.isAfter(today) ? localStart : today);
    }
    if (localEnd != null && effective.isAfter(localEnd)) return null;
    return _dateKey(effective);
  }

  String _microActionStartDate(MicroActionModel action) {
    final explicit = action.progressStartDate?.trim() ?? '';
    if (DateTime.tryParse(explicit) != null) return explicit;
    final planned = action.plannedDate?.trim() ?? '';
    if (DateTime.tryParse(planned) != null) return planned;
    final fallback = action.adoptedAt?.toLocal() ??
        action.createdAt?.toLocal() ??
        nowLoader().toLocal();
    return _dateKey(fallback);
  }

  Map<String, dynamic> _microActionContent(
    MicroActionModel action, {
    String? title,
    String? reason,
    int? plannedDurationMinutes,
  }) {
    return {
      'title': title ?? action.title,
      'reason': reason ?? action.reason,
      'action_type': action.actionType,
      'difficulty': action.difficulty,
      'planned_duration_minutes':
          plannedDurationMinutes ?? action.plannedDurationMinutes,
      'planned_date': action.plannedDate,
      'planned_time': action.plannedTime?.toUtc().toIso8601String(),
    };
  }

  DateTime _progressStart(
    Object? primary, {
    required Object? fallbackDate,
    required Object? fallbackDateTime,
  }) {
    final primaryDate = _parseDate(primary);
    if (primaryDate != null) return _dateOnly(primaryDate.toLocal());
    final fallback = _parseDate(fallbackDate);
    if (fallback != null) return _dateOnly(fallback.toLocal());
    final dateTime = _parseDate(fallbackDateTime)?.toLocal() ?? nowLoader();
    return _dateOnly(dateTime);
  }

  List<String> _normalizedIds(Iterable<String> values) {
    return values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  String _signalId(RecentSignalModel signal) {
    return (signal.signalCardId ?? signal.id ?? '').trim();
  }

  DateTime _startOfWeek(DateTime date) {
    final local = _dateOnly(date);
    return local.subtract(Duration(days: local.weekday - DateTime.monday));
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  DateTime _clampDate(DateTime value, DateTime minimum, DateTime maximum) {
    if (value.isBefore(minimum)) return minimum;
    if (value.isAfter(maximum)) return maximum;
    return value;
  }

  SevenDayProgressModel _progressProjectedToWeek(
    SevenDayProgressModel canonical, {
    required DateTime weekStart,
    required DateTime weekEnd,
  }) {
    final canonicalByDate = {
      for (final cell in canonical.cells) cell.localDate: cell,
    };
    final cells = <SevenDayProgressCell>[];
    for (var day = _dateOnly(weekStart);
        !day.isAfter(_dateOnly(weekEnd));
        day = day.add(const Duration(days: 1))) {
      final key = _dateKey(day);
      cells.add(
        canonicalByDate[key] ??
            SevenDayProgressCell(
              localDate: key,
              state: ProgressCellState.empty,
            ),
      );
    }
    return SevenDayProgressModel(
      subjectId: canonical.subjectId,
      startDate: _dateKey(weekStart),
      endDate: _dateKey(weekEnd),
      cells: cells,
    );
  }

  SevenDayProgressModel _attemptProgressProjectedToPeriod(
    SevenDayProgressModel canonical, {
    required DateTime periodStart,
    required DateTime periodEnd,
  }) {
    final start = _dateOnly(periodStart);
    final end = _dateOnly(periodEnd);
    final cells = canonical.cells.where((cell) {
      final date = DateTime.tryParse(cell.localDate);
      if (date == null) return false;
      final local = _dateOnly(date);
      return !local.isBefore(start) && !local.isAfter(end);
    }).toList(growable: false);
    return SevenDayProgressModel(
      subjectId: canonical.subjectId,
      startDate: _dateKey(start),
      endDate: _dateKey(end),
      cells: cells,
    );
  }

  void _validateSmallExperimentDuration(int value) {
    if (value < 1 || value > SmallTryPlanningLimits.maxDurationMinutes) {
      throw ArgumentError.value(
        value,
        'plannedDurationMinutes',
        'small_experiment_duration_must_be_between_1_and_10_minutes',
      );
    }
  }

  String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _groupId(CandidateKind kind, String periodStart, String sourceHash) {
    return 'cg_${kind.storageValue}_${periodStart.replaceAll('-', '')}_$sourceHash';
  }

  String _candidateId(String prefix, String groupId, int rank) {
    return '${prefix}_${_fnv1a('$groupId|$rank')}';
  }

  static const _energyReasonMarker = '\n\n[[energy_fit]]';

  String _encodeMicroCandidateReason(String reason, String energyExplanation) {
    final normalizedReason = reason.trim();
    final normalizedEnergy = energyExplanation.trim();
    if (normalizedEnergy.isEmpty) return normalizedReason;
    return '$normalizedReason$_energyReasonMarker$normalizedEnergy';
  }

  (String, String) _decodeMicroCandidateReason(String raw) {
    final markerIndex = raw.indexOf(_energyReasonMarker);
    if (markerIndex < 0) return (raw.trim(), '');
    return (
      raw.substring(0, markerIndex).trim(),
      raw.substring(markerIndex + _energyReasonMarker.length).trim(),
    );
  }

  String _fnv1a(String value) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(value)) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  String _normalized(Object? raw) => raw?.toString().trim().toLowerCase() ?? '';

  bool _hasAny(String value, Iterable<String> tokens) {
    return tokens.any(value.contains);
  }

  DateTime? _parseDate(Object? raw) {
    if (raw is DateTime) return raw;
    if (raw is String && raw.trim().isNotEmpty) return DateTime.tryParse(raw);
    return null;
  }

  int _toInt(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  int? _positiveInt(Object? raw) {
    final value = _toInt(raw);
    return value > 0 ? value : null;
  }

  bool _toBool(Object? raw) {
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    return raw?.toString() == '1' || raw?.toString().toLowerCase() == 'true';
  }

  List<String> _decodeStringList(Object? raw) {
    if (raw is! String || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((item) => item?.toString().trim() ?? '')
            .where((item) => item.isNotEmpty)
            .toList(growable: false);
      }
    } catch (_) {}
    return const [];
  }

  Map<String, dynamic> _decodeMap(Object? raw) {
    if (raw is! String || raw.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {}
    return const {};
  }
}
