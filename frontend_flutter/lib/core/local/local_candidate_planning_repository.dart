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
import '../models/feedback_event_models.dart';
import '../models/phase3_plus_models.dart';
import '../models/today_models.dart';
import '../models/weekly_models.dart';
import '../preferences/focus_domains.dart';
import '../state/app_data_refresh_coordinator.dart';
import 'external_energy_hint_store.dart';
import 'local_capture_repository.dart';
import 'local_cache_invalidation_repository.dart';
import 'local_database.dart';
import 'local_feedback_event_repository.dart';
import 'local_life_experiment_repository.dart';
import 'local_trace_link_repository.dart';

typedef DailyCandidateGenerator = Future<List<MicroActionCandidateDraft>>
    Function(CandidatePlanningContext context);
typedef WeeklyCandidateGenerator = Future<List<ExperimentCandidateDraft>>
    Function(CandidatePlanningContext context);

/// Canonical local candidate/adoption/progress data layer.
///
/// Generation remains injected so this repository does not couple storage to
/// a model provider. A caller can observe `regenerating` immediately, await
/// its generator, and receive an idempotent replacement read model. Adopted
/// objects are never overwritten by source regeneration.
class LocalCandidatePlanningRepository {
  static const requiredSignalCount = 3;
  static const maxCandidatesPerGroup = 3;

  final LocalDatabase localDatabase;
  final LocalCaptureRepository localCaptureRepository;
  final LocalLifeExperimentRepository localLifeExperimentRepository;
  late final LocalFeedbackEventRepository feedbackEventRepository;
  late final EnergyBudgetRepository energyBudgetRepository;
  late final Future<List<String>> Function() focusDomainIdsLoader;
  late final Future<AdvancedEnergyExternalSummary?> Function()
      externalEnergySummaryLoader;
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
    EnergyBudgetRepository? energyBudgetRepository,
    Future<List<String>> Function()? focusDomainIdsLoader,
    Future<AdvancedEnergyExternalSummary?> Function()?
        externalEnergySummaryLoader,
    SignalEligibilityService? eligibilityService,
    DateTime Function()? nowLoader,
  })  : eligibilityService =
            eligibilityService ?? const SignalEligibilityService(),
        nowLoader = nowLoader ?? DateTime.now {
    this.feedbackEventRepository =
        feedbackEventRepository ?? LocalFeedbackEventRepository(localDatabase);
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

  Future<MicroActionCandidateModel?> updateMicroActionCandidate({
    required String candidateId,
    required String title,
  }) async {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) return null;
    final db = await localDatabase.database;
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
          final start = _dateOnly(now.toLocal());
          final end = start.add(const Duration(days: 6));
          final proposedId =
              'ma_${_uuid.v4().replaceAll('-', '').substring(0, 12)}';
          final proposed = MicroActionModel(
            id: proposedId,
            judgementId: '',
            title: candidate.title,
            reason: candidate.reason,
            actionType: 'today_try',
            difficulty: candidate.difficulty,
            plannedDate: _dateKey(start),
            status: 'accepted',
            feedbackStatus: 'none',
            localUserId: localUserId,
            originCandidateId: candidate.id,
            adoptedAt: now,
            progressStartDate: _dateKey(start),
            progressEndDate: _dateKey(end),
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
        await txn.update(
          'micro_action_candidates',
          {
            'status': 'adopted',
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
          final activeEnd = activeStart.add(const Duration(days: 6));
          final proposed = LifeExperimentModel(
            id: 'exp_${_uuid.v4().replaceAll('-', '').substring(0, 12)}',
            localUserId: localUserId,
            sourceWeekStart: _dateKey(activeStart),
            sourceWeekEnd: _dateKey(activeEnd),
            title: candidate.title,
            hypothesis: candidate.hypothesis,
            suggestedAction: candidate.suggestedAction,
            linkedSignalCardIds: candidate.linkedSignalCardIds,
            status: 'saved',
            plannedTotalDays: SevenDayProgressModel.totalDays,
            originCandidateId: candidate.id,
            adoptedAt: now,
            progressStartDate: _dateKey(activeStart),
            progressEndDate: _dateKey(activeEnd),
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
        await txn.update(
          'experiment_candidates',
          {
            'status': 'adopted',
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
    final db = await localDatabase.database;
    final key = _dateKey(day.toLocal());
    final rows = await db.query(
      'micro_actions',
      where: '''
        local_user_id = ?
        AND status IN (?, ?, ?, ?, ?)
        AND (
          (progress_start_date <= ? AND progress_end_date >= ?)
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
    final db = await localDatabase.database;
    final key = _dateKey(day.toLocal());
    final rows = await db.query(
      'life_experiments',
      where: '''
        local_user_id = ?
        AND status IN (?, ?, ?, ?)
        AND COALESCE(progress_start_date, source_week_start) <= ?
        AND COALESCE(progress_end_date, source_week_end) >= ?
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
      final experiment = LifeExperimentModel.fromJson(
        row.map((key, value) => MapEntry(key, value)),
      );
      result.add(AdoptedLifeExperimentProgress(
        experiment: experiment,
        progress: await lifeExperimentProgress(experiment.id),
      ));
    }
    return result;
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
    final end = start.add(const Duration(days: 6));
    final feedback = await db.query(
      'micro_action_feedback',
      where: '''
        micro_action_id = ? AND local_date >= ? AND local_date <= ?
        AND COALESCE(is_valid, 1) = 1
      ''',
      whereArgs: [actionId, _dateKey(start), _dateKey(end)],
      orderBy:
          'local_date ASC, COALESCE(updated_at, created_at) ASC, created_at ASC, id ASC',
    );
    return _buildProgress(
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
    final focusHash = _fnv1a(focusDomainIds.join('|'));
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
    final signals = _rankSignalsForFocus(
      await _eligibleSignalsForGate(gate),
      context.focusDomainIds,
    );
    if (signals.length < requiredSignalCount) return const [];
    final evidence = signals.take(maxCandidatesPerGroup).toList();
    return List.generate(maxCandidatesPerGroup, (index) {
      final signal = evidence[index % evidence.length];
      final snippet = _snippet(signal.content, language);
      final copy = _energyAdjustedDailyCopy(
        _dailySuggestionCopy(language, index, snippet),
        context.planningCapacityBand,
        index,
      );
      return MicroActionCandidateDraft(
        title: copy.$1,
        reason: copy.$2,
        difficulty: context.planningRecommendedIntensity.storageValue,
        recommendedIntensity: context.planningRecommendedIntensity.storageValue,
        energyAdaptationExplanation: _energyAdaptationText(
          context.planningCapacityBand,
          language,
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
    final signals = _rankSignalsForFocus(
      await _eligibleSignalsForGate(gate),
      context.focusDomainIds,
    );
    if (signals.length < requiredSignalCount) return const [];
    final evidence = signals.take(maxCandidatesPerGroup).toList();
    return List.generate(maxCandidatesPerGroup, (index) {
      final signal = evidence[index % evidence.length];
      final snippet = _snippet(signal.content, language);
      final suggestionIndex = switch (context.planningCapacityBand) {
        EnergyCapacityBand.veryLow || EnergyCapacityBand.low => const [
            1,
            0,
            2
          ][index],
        EnergyCapacityBand.high => const [2, 0, 1][index],
        _ => index,
      };
      var copy = _weeklySuggestionCopy(language, suggestionIndex, snippet);
      if (context.planningCapacityBand == EnergyCapacityBand.veryLow &&
          suggestionIndex == 1) {
        copy = (copy.$1, copy.$2, copy.$3.replaceFirst('10', '5'));
      }
      return ExperimentCandidateDraft(
        title: copy.$1,
        hypothesis: copy.$2,
        suggestedAction: copy.$3,
        recommendedIntensity: context.planningRecommendedIntensity.storageValue,
        energyAdaptationExplanation: _energyAdaptationText(
          context.planningCapacityBand,
          language,
        ),
        linkedSignalCardIds: [_signalId(signal)],
        metadata: {
          'generator': 'local_grounded_fallback_v1',
          'presentation_status': 'suggested',
          'focus_domain_ids': context.focusDomainIds,
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
    final events = await feedbackEventRepository.listActiveBetween(
      localUserId: localUserId,
      startDate: gate.periodStart,
      endDate: gate.periodEnd,
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
      latest['${event.subjectType}|${event.subjectId}|${event.localDate}'] =
          event;
    }
    final effective = latest.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    var helpfulCount = 0;
    var difficultCount = 0;
    var skippedCount = 0;
    for (final event in effective) {
      final text = [
        event.status,
        event.effect,
        event.note,
        ...event.metadata.values.map((value) => value?.toString()),
      ].whereType<String>().join(' ').toLowerCase();
      if (_hasAny(text, const [
        'not_suitable',
        'skipped',
        'not_done',
        'not_occurred',
      ])) {
        skippedCount += 1;
      } else if (_hasAny(text, const [
        'not_helpful',
        'too hard',
        'difficult',
        'draining',
        '困难',
        '耗力',
      ])) {
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

  String _energyAdaptationText(
    EnergyCapacityBand band,
    AppLanguage language,
  ) {
    return switch (language) {
      AppLanguage.simplifiedChinese => switch (band) {
          EnergyCapacityBand.veryLow =>
            '能量适配：最近的明确状态偏低，所以先给出 1–3 分钟、可暂停的恢复或观察型尝试。',
          EnergyCapacityBand.low => '能量适配：当前消耗线索较多，所以先控制在 3–5 分钟，并减少切换。',
          EnergyCapacityBand.medium => '能量适配：当前证据支持普通轻量强度，先用单一步骤验证。',
          EnergyCapacityBand.high => '能量适配：当前状态较稳定，可以尝试稍深一点的版本，同时保留轻量选项。',
          EnergyCapacityBand.unknown => '能量适配：当前能量证据还不明确，因此先保持很轻、可逆、无完成压力。',
        },
      AppLanguage.traditionalChinese => switch (band) {
          EnergyCapacityBand.veryLow =>
            '能量適配：最近的明確狀態偏低，所以先提供 1–3 分鐘、可暫停的恢復或觀察型嘗試。',
          EnergyCapacityBand.low => '能量適配：目前消耗線索較多，所以先控制在 3–5 分鐘，並減少切換。',
          EnergyCapacityBand.medium => '能量適配：目前證據支持一般輕量強度，先用單一步驟驗證。',
          EnergyCapacityBand.high => '能量適配：目前狀態較穩定，可以嘗試稍深一點的版本，同時保留輕量選項。',
          EnergyCapacityBand.unknown => '能量適配：目前能量證據還不明確，因此先保持很輕、可逆、沒有完成壓力。',
        },
      AppLanguage.japanese => switch (band) {
          EnergyCapacityBand.veryLow =>
            'エネルギー調整：明確な状態が低めなので、1〜3分で中断できる回復・観察案にしています。',
          EnergyCapacityBand.low =>
            'エネルギー調整：負荷の手がかりが多いため、3〜5分で切り替えの少ない案にしています。',
          EnergyCapacityBand.medium => 'エネルギー調整：通常の軽い強度で、まず一つの手順だけ試せる案です。',
          EnergyCapacityBand.high =>
            'エネルギー調整：状態が比較的安定しているため、軽い選択肢を残しつつ少し深めに試せます。',
          EnergyCapacityBand.unknown =>
            'エネルギー調整：手がかりがまだ十分でないため、軽く戻せて達成圧のない案にしています。',
        },
      AppLanguage.english => switch (band) {
          EnergyCapacityBand.veryLow =>
            'Energy fit: your latest explicit state is low, so this stays within 1–3 minutes and can be paused.',
          EnergyCapacityBand.low =>
            'Energy fit: current load signals are higher, so this stays within 3–5 minutes with fewer switches.',
          EnergyCapacityBand.medium =>
            'Energy fit: the current evidence supports a normal light option with one clear step.',
          EnergyCapacityBand.high =>
            'Energy fit: your state looks steadier, so a slightly deeper option is available alongside a light one.',
          EnergyCapacityBand.unknown =>
            'Energy fit: current capacity is not clear yet, so this stays very light, reversible, and pressure-free.',
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

  (String, String) _energyAdjustedDailyCopy(
    (String, String) copy,
    EnergyCapacityBand band,
    int index,
  ) {
    final replacement = switch ((band, index)) {
      (EnergyCapacityBand.veryLow, 1) => ('5', '3'),
      (EnergyCapacityBand.medium, 0) => ('2', '5'),
      (EnergyCapacityBand.medium, 1) => ('5', '10'),
      (EnergyCapacityBand.high, 0) => ('2', '10'),
      (EnergyCapacityBand.high, 1) => ('5', '10'),
      _ => null,
    };
    if (replacement == null) return copy;
    return (
      copy.$1.replaceFirst(replacement.$1, replacement.$2),
      copy.$2,
    );
  }

  (String, String) _dailySuggestionCopy(
    AppLanguage language,
    int index,
    String snippet,
  ) {
    switch (language) {
      case AppLanguage.simplifiedChinese:
        return switch (index) {
          0 => ('用 2 分钟补一句当时的场景', '来自今天的信号：“$snippet”'),
          1 => ('给相似时刻留 5 分钟缓冲', '今天的信号提示这个时刻值得先放轻一点：“$snippet”'),
          _ => ('睡前记下什么让状态轻了一点', '用一个很小的回看继续验证今天的信号：“$snippet”'),
        };
      case AppLanguage.traditionalChinese:
        return switch (index) {
          0 => ('用 2 分鐘補一句當時的情境', '來自今天的信號：「$snippet」'),
          1 => ('給相似時刻留 5 分鐘緩衝', '今天的信號提示這個時刻值得先放輕一點：「$snippet」'),
          _ => ('睡前記下什麼讓狀態輕了一點', '用一個很小的回看繼續驗證今天的信號：「$snippet」'),
        };
      case AppLanguage.japanese:
        return switch (index) {
          0 => ('2分だけ、その時の状況を一言足す', '今日のシグナル「$snippet」をもとにしています。'),
          1 => ('似た場面に5分の余白をつくる', 'このシグナルが、少し軽くする余地を示しています：「$snippet」'),
          _ => ('寝る前に、少し楽になったことを一言書く', '今日のシグナルを小さく確かめます：「$snippet」'),
        };
      case AppLanguage.english:
        return switch (index) {
          0 => (
              'Add one line of context for 2 minutes',
              'Grounded in today’s signal: “$snippet”'
            ),
          1 => (
              'Leave a 5-minute buffer for a similar moment',
              'This signal suggests a moment worth making lighter: “$snippet”'
            ),
          _ => (
              'Note what felt a little lighter before bed',
              'A small way to keep checking today’s signal: “$snippet”'
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
              '观察相似场景',
              '如果只记录一次相似场景，可能更容易看清“$snippet”是否会重复。',
              '下次相似情况出现时，只补一句发生了什么。',
            ),
          1 => (
              '预留一个低成本恢复块',
              '如果先留一点缓冲，“$snippet”带来的消耗可能更容易被看见。',
              '本周选择一个相似时刻，提前留 10 分钟空白。',
            ),
          _ => (
              '重复一次变轻的做法',
              '如果重复一个微小的有效做法，可能更容易判断“$snippet”的变化。',
              '挑一天重复一次让状态稍微变轻的做法，并记下结果。',
            ),
        };
      case AppLanguage.traditionalChinese:
        return switch (index) {
          0 => (
              '觀察相似情境',
              '如果只記錄一次相似情境，可能更容易看清「$snippet」是否重複。',
              '下次相似情況出現時，只補一句發生了什麼。'
            ),
          1 => (
              '預留一個低成本恢復塊',
              '如果先留一點緩衝，「$snippet」帶來的消耗可能更容易被看見。',
              '本週選一個相似時刻，提前留 10 分鐘空白。'
            ),
          _ => (
              '重複一次變輕的做法',
              '如果重複一個微小的有效做法，可能更容易判斷「$snippet」的變化。',
              '挑一天重複一次讓狀態稍微變輕的做法，並記下結果。'
            ),
        };
      case AppLanguage.japanese:
        return switch (index) {
          0 => (
              '似た場面を観察する',
              '一度だけ記録すると「$snippet」が繰り返すか見やすくなります。',
              '次に似た場面があれば、起きたことを一言だけ足します。'
            ),
          1 => (
              '小さな回復の余白をつくる',
              '少し余白を先に取ると「$snippet」の負荷を確かめやすくなります。',
              '似た場面の前に10分の空白を一度つくります。'
            ),
          _ => (
              '少し楽になった方法をもう一度試す',
              '小さく繰り返すと「$snippet」の変化を見つけやすくなります。',
              '少し楽になった方法を一度繰り返し、結果を記録します。'
            ),
        };
      case AppLanguage.english:
        return switch (index) {
          0 => (
              'Observe a similar moment',
              'One more observation can show whether “$snippet” repeats.',
              'When a similar moment happens, add one line about what occurred.'
            ),
          1 => (
              'Reserve a low-cost recovery block',
              'A little buffer may make the load around “$snippet” easier to see.',
              'Before one similar moment, leave a 10-minute buffer.'
            ),
          _ => (
              'Repeat one thing that felt lighter',
              'A small repeat can help test how “$snippet” changes.',
              'Repeat one thing that felt a little lighter and note the result.'
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
    }.contains(value)) {
      return ProgressCellState.completed;
    }
    if (const {
      'no',
      'not_happened',
      'not_occurred',
      'not_tried',
      'not_suitable_today',
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
