import 'dart:convert';

import '../../eligibility/signal_eligibility_service.dart';
import '../../local/local_capture_repository.dart';
import '../../local/external_energy_hint_store.dart';
import '../../local/local_feedback_event_repository.dart';
import '../../local/local_life_experiment_repository.dart';
import '../../models/advanced_energy_boundary_models.dart';
import '../../models/energy_budget_models.dart';
import '../../models/feedback_event_models.dart';
import '../../models/memory_models.dart';
import '../../models/today_models.dart';
import '../../models/weekly_models.dart';

class EnergyBudgetRepository {
  final LocalCaptureRepository localCaptureRepository;
  final LocalLifeExperimentRepository? localLifeExperimentRepository;
  final ExternalEnergyHintStore? externalEnergyHintStore;
  final LocalFeedbackEventRepository? feedbackEventRepository;
  final String localUserId;
  final SignalEligibilityService eligibilityService;
  final DateTime Function() nowLoader;

  EnergyBudgetRepository({
    required this.localCaptureRepository,
    this.localLifeExperimentRepository,
    this.externalEnergyHintStore,
    this.feedbackEventRepository,
    this.localUserId = 'local',
    SignalEligibilityService? eligibilityService,
    DateTime Function()? nowLoader,
  })  : eligibilityService =
            eligibilityService ?? const SignalEligibilityService(),
        nowLoader = nowLoader ?? DateTime.now;

  /// Canonical five-state classifier shared by status, time-use and weekly
  /// read models. It is pure and never writes a Signal or budget snapshot.
  EnergySignalState classifySignal(RecentSignalModel signal) =>
      _energyStateFor(signal);

  Future<EnergyBudgetModel> fetchBasicEnergyBudget({
    WeeklyInsightModel? weekly,
    MemorySummaryModel? journey,
    AdvancedEnergyExternalSummary? externalSummary,
    int limit = 1000,
  }) async {
    final snapshot = await fetchWeeklySnapshot(
      day: nowLoader(),
      weekly: weekly,
      journey: journey,
      externalSummary: externalSummary,
      limit: limit,
    );
    return snapshot.budget;
  }

  Future<EnergyBudgetSnapshot> fetchDailySnapshot({
    required DateTime day,
    WeeklyInsightModel? weekly,
    MemorySummaryModel? journey,
    AdvancedEnergyExternalSummary? externalSummary,
    int limit = 1000,
  }) {
    final localDay = _dateOnly(day.toLocal());
    return _fetchSnapshot(
      periodKind: EnergyBudgetPeriodKind.daily,
      periodStart: localDay,
      periodEnd: localDay,
      weekly: weekly,
      journey: journey,
      externalSummary: externalSummary,
      limit: limit,
    );
  }

  Future<EnergyBudgetSnapshot> fetchWeeklySnapshot({
    required DateTime day,
    WeeklyInsightModel? weekly,
    MemorySummaryModel? journey,
    AdvancedEnergyExternalSummary? externalSummary,
    int limit = 1000,
  }) {
    final localDay = _dateOnly(day.toLocal());
    final start = localDay.subtract(
      Duration(days: localDay.weekday - DateTime.monday),
    );
    return _fetchSnapshot(
      periodKind: EnergyBudgetPeriodKind.weekly,
      periodStart: start,
      periodEnd: start.add(const Duration(days: 6)),
      weekly: weekly,
      journey: journey,
      externalSummary: externalSummary,
      limit: limit,
    );
  }

  Future<EnergyBudgetSnapshot> _fetchSnapshot({
    required EnergyBudgetPeriodKind periodKind,
    required DateTime periodStart,
    required DateTime periodEnd,
    WeeklyInsightModel? weekly,
    MemorySummaryModel? journey,
    AdvancedEnergyExternalSummary? externalSummary,
    int limit = 1000,
  }) async {
    final startKey = _dateKey(periodStart);
    final endKey = _dateKey(periodEnd);
    final resolvedExternalSummary =
        externalSummary ?? externalEnergyHintStore?.loadHealthSummary();
    final signals = await localCaptureRepository.listSignalCardsBetween(
      startDate: startKey,
      endDate: endKey,
    );
    final eligibleSignals = eligibilityService.filter(
      signals.take(limit),
      SignalEligibilityStage.energyBudget,
    );
    final experimentHistory = (await localLifeExperimentRepository?.listRecent(
              localUserId: localUserId,
            ) ??
            const <LifeExperimentModel>[])
        .where((experiment) => _overlapsPeriod(
              experiment.progressStartDate ?? experiment.sourceWeekStart,
              experiment.progressEndDate ?? experiment.sourceWeekEnd,
              startKey,
              endKey,
            ))
        .toList(growable: false);
    final feedbackEvents = _effectiveFeedbackEvents(
      await feedbackEventRepository?.listActiveBetween(
            localUserId: localUserId,
            startDate: startKey,
            endDate: endKey,
          ) ??
          const <FeedbackEventModel>[],
    );
    final externalHints = _safeExternalHints(resolvedExternalSummary);

    final hasInternalEvidence = eligibleSignals.isNotEmpty ||
        experimentHistory.isNotEmpty ||
        feedbackEvents.isNotEmpty;
    final stats = _buildStats(eligibleSignals);
    final capacityBand = _deriveCapacityBand(
      periodKind: periodKind,
      signals: eligibleSignals,
      feedbackEvents: feedbackEvents,
      stats: stats,
      externalHints: externalHints,
    );
    final meetsAnalysisThreshold = periodKind == EnergyBudgetPeriodKind.daily ||
        eligibleSignals.length >= 3;
    final readiness = !hasInternalEvidence
        ? 'unknown'
        : !meetsAnalysisThreshold
            ? 'light_ready'
            : 'ready';
    final budget = !hasInternalEvidence || !meetsAnalysisThreshold
        ? _emptyBudget(
            weekly: weekly,
            journey: journey,
            externalSummary: resolvedExternalSummary,
            energyStateCounts: stats.energyStateCounts,
          )
        : EnergyBudgetModel(
            status: readiness,
            mostDrainingSource: _mostDrainingSource(stats),
            recoveryClue: _recoveryClue(stats, journey),
            bufferLocation: _bufferLocation(stats),
            switchingAdjustment: _switchingAdjustment(stats, weekly),
            experimentConnection: _experimentConnection(
              experimentHistory,
              weekly: weekly,
              journey: journey,
            ),
            scheduleDensityHint: _scheduleDensityHint(externalHints),
            recoverySignalHint: _recoverySignalHint(externalHints),
            externalConflictNote: _externalConflictNote(stats, externalHints),
            abstractExternalHints: externalHints,
            energyStateCounts: stats.energyStateCounts,
            blocks: _blocks(stats),
          );
    final evidenceIds = eligibleSignals
        .map((signal) => (signal.signalCardId ?? signal.id ?? '').trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort();
    final feedbackIds = feedbackEvents.map((event) => event.id).toList()
      ..sort();
    final sourceHash = _snapshotSourceHash(
      periodKind: periodKind,
      startKey: startKey,
      endKey: endKey,
      signals: eligibleSignals,
      feedbackEvents: feedbackEvents,
      externalHints: externalHints,
      capacityBand: capacityBand,
    );
    final timezone = _snapshotTimezone(eligibleSignals, periodStart);
    final updatedAt = nowLoader().toUtc();
    return EnergyBudgetSnapshot(
      id: 'energy_${periodKind.storageValue}_${startKey.replaceAll('-', '')}_$sourceHash',
      periodKind: periodKind,
      periodStart: startKey,
      periodEnd: endKey,
      timezone: timezone,
      capacityBand: capacityBand,
      recommendedIntensity:
          EnergyRecommendedIntensity.fromCapacity(capacityBand),
      evidenceSignalIds: evidenceIds,
      feedbackEventIds: feedbackIds,
      sourceHash: sourceHash,
      readiness: readiness,
      confidence: _snapshotConfidence(
        eligibleSignals.length,
        feedbackEvents.length,
        eligibleSignals.any((signal) => _budgetEnergyLevel(signal) != null),
      ),
      updatedAt: updatedAt,
      budget: budget,
    );
  }

  _EnergyStats _buildStats(List<RecentSignalModel> signals) {
    final counts = <String, int>{};
    final scenes = <String, int>{};
    final frictions = <String, int>{};
    final positives = <String, int>{};
    final stages = <String, int>{};
    final evidenceLevels = <String, String>{};
    final energyStateCounts = <String, int>{
      for (final state in EnergySignalState.values) state.storageValue: 0,
    };

    for (final signal in signals) {
      final energyState = _energyStateFor(signal);
      energyStateCounts[energyState.storageValue] =
          (energyStateCounts[energyState.storageValue] ?? 0) + 1;
      final evidenceLevel = _evidenceLevel(signal);
      _countIfPresent(scenes, signal.scene);
      if (signal.sourceType == 'time_use') {
        final category = (signal.rawPayloadJson['focus_domain_id'] ??
                signal.rawPayloadJson['category'])
            ?.toString();
        if ((category ?? '').trim().toLowerCase() !=
            (signal.scene ?? '').trim().toLowerCase()) {
          _countIfPresent(scenes, category);
        }
      }
      _countIfPresent(frictions, signal.friction);
      _countIfPresent(positives, signal.positiveSignal);
      for (final stage in signal.linkedLifeChainStages) {
        _countIfPresent(stages, stage);
      }

      for (final type in _blockTypesFor(signal)) {
        counts[type] = (counts[type] ?? 0) + 1;
        evidenceLevels[type] = _mergeEvidenceLevel(
          evidenceLevels[type],
          evidenceLevel,
        );
      }
    }

    return _EnergyStats(
      signals: signals,
      blockCounts: counts,
      blockEvidenceLevels: evidenceLevels,
      energyStateCounts: energyStateCounts,
      topScene: _topKey(scenes),
      topFriction: _topKey(frictions),
      topPositive: _topKey(positives),
      topStage: _topKey(stages),
    );
  }

  String _evidenceLevel(RecentSignalModel signal) {
    if (signal.isLegacy) return 'legacy_context';
    if (signal.isLibrarySaved) return 'library_saved_confirmed';
    if (signal.userConfirmation == 'unconfirmed') return 'light_observation';
    return signal.userConfirmation;
  }

  List<String> _blockTypesFor(RecentSignalModel signal) {
    final types = <String>{};
    final ignoresTimeUseEnergy =
        signal.sourceType == 'time_use' && !_isCompletedTimeUse(signal);
    final energyLoad =
        ignoresTimeUseEnergy ? '' : (signal.energyLoad ?? '').toLowerCase();
    final friction = (signal.friction ?? '').toLowerCase();
    final scene = (signal.scene ?? '').toLowerCase();
    final positive = (signal.positiveSignal ?? '').toLowerCase();
    final structuredEnergy = ignoresTimeUseEnergy
        ? ''
        : (signal.rawPayloadJson['energy_effect']?.toString() ?? '')
            .toLowerCase();
    final stages =
        signal.linkedLifeChainStages.map((stage) => stage.toLowerCase());

    if (_containsAny(energyLoad, const ['drain', 'draining', 'high']) ||
        structuredEnergy == 'draining' ||
        _containsAny(friction, const ['pressure', 'overload', 'meeting'])) {
      types.add('high_drain');
    }
    if (_containsAny(
          friction,
          const ['switch', 'context', 'interrupt', 'message', 'meeting'],
        ) ||
        stages.contains('attention_switching')) {
      types.add('high_switching');
    }
    if (_containsAny(scene, const ['focus', 'deep', 'creative', 'creation']) ||
        stages.contains('deep_work')) {
      types.add('deep');
    }
    if (_containsAny(
          energyLoad,
          const ['restore', 'restoring', 'recovery'],
        ) ||
        positive.isNotEmpty ||
        structuredEnergy == 'restoring' ||
        stages.contains('recovery')) {
      types.add('recovery');
    }
    if (_containsAny(
          friction,
          const ['boundary', 'relationship', 'message', 'responsibility'],
        ) ||
        stages.contains('boundary')) {
      types.add('boundary');
    }
    if (_containsAny(
          friction,
          const ['schedule', 'overload', 'switch', 'context', 'meeting'],
        ) ||
        stages.contains('buffer')) {
      types.add('buffer');
    }

    return types.toList();
  }

  List<EnergyBlockModel> _blocks(_EnergyStats stats) {
    const labels = {
      'high_drain': 'high-drain block',
      'high_switching': 'high-switching block',
      'deep': 'deep block',
      'recovery': 'recovery block',
      'boundary': 'boundary block',
      'buffer': 'buffer block',
    };

    return labels.entries
        .map(
          (entry) => EnergyBlockModel(
            type: entry.key,
            label: entry.value,
            summary: _blockSummary(entry.key, stats),
            count: stats.blockCounts[entry.key] ?? 0,
            evidenceLevel: stats.blockEvidenceLevels[entry.key] ?? 'none',
          ),
        )
        .where((block) => block.count > 0)
        .toList();
  }

  String _blockSummary(String type, _EnergyStats stats) {
    switch (type) {
      case 'high_drain':
        return '这个安排可能有点耗力，先看它是不是常和“${stats.topFrictionOrScene}”一起出现。';
      case 'high_switching':
        return '这里像是切换负担比较重的位置，可以先给它留一点余地。';
      case 'deep':
        return '这里更像需要完整注意力的投入，不一定适合被频繁插入。';
      case 'recovery':
        return '这里出现了一点恢复线索，可以先留意它通常怎么发生。';
      case 'boundary':
        return '这里可能需要一点边界，不是拒绝事情，而是减少被持续拉走。';
      default:
        return '这里适合留一点 buffer，让前后安排不要贴得太紧。';
    }
  }

  String _mostDrainingSource(_EnergyStats stats) {
    final source = stats.topFrictionOrScene;
    if (source.isEmpty) {
      return '这段时间还没有特别清楚的耗能来源，先保持小观察就好。';
    }
    return '这段时间最耗能的一个来源可能是“$source”。这个安排可能有点耗力，先不用急着评价它。';
  }

  String _recoveryClue(_EnergyStats stats, MemorySummaryModel? journey) {
    final positive = stats.topPositive;
    if (positive.isNotEmpty) {
      return '一个恢复线索是“$positive”。它可以先被当作省力线索保留下来。';
    }
    final journeyRecovery = journey?.recoverySignal?.summary.trim();
    if (journeyRecovery != null && journeyRecovery.isNotEmpty) {
      return journeyRecovery;
    }
    return '恢复线索还不明显。现在先看哪些时刻让你稍微没那么耗力。';
  }

  String _bufferLocation(_EnergyStats stats) {
    final source = stats.topFrictionOrScene;
    if (source.isEmpty) {
      return '暂时还没有明确需要 buffer 的位置。';
    }
    return '可以先把“$source”看作需要 buffer 的位置，让它前后不要贴得太紧。';
  }

  String _switchingAdjustment(_EnergyStats stats, WeeklyInsightModel? weekly) {
    final weeklyExperiment = weekly?.deriveV3CStructure().oneExperiment.trim();
    if (weeklyExperiment != null && weeklyExperiment.isNotEmpty) {
      return '可以先给这里留一点余地：$weeklyExperiment';
    }
    final source = stats.topFrictionOrScene;
    if (source.isEmpty) {
      return '可以先试试少调整一件事，而不是同时改变很多安排。';
    }
    return '可以先给“$source”留一点余地，减少来回切换的负担。';
  }

  String _experimentConnection(
    List<LifeExperimentModel> experiments, {
    WeeklyInsightModel? weekly,
    MemorySummaryModel? journey,
  }) {
    if (experiments.isNotEmpty) {
      final latest = experiments.first;
      final feedback = latest.feedbackText?.trim();
      final feedbackText = feedback == null || feedback.isEmpty
          ? '还没有反馈也没关系。'
          : '反馈是：$feedback。';
      return '可以连接到最近的生活小实验：“${latest.title}”。$feedbackText 这里看的不是完成度，而是这个设计有没有帮你省一点力。';
    }
    final weeklyExperiment = weekly?.lifeExperiment;
    if (weeklyExperiment != null) {
      return '可以连接到本周的生活小实验目标：“${weeklyExperiment.title}”。先看它有没有帮你省一点力。';
    }
    final journeyAdjustment = journey?.nextAdjustmentDirection.summary.trim();
    if (journeyAdjustment != null && journeyAdjustment.isNotEmpty) {
      return journeyAdjustment;
    }
    return '还没有可连接的生活小实验。之后可以从一个很小的调整开始。';
  }

  EnergyBudgetModel _emptyBudget({
    WeeklyInsightModel? weekly,
    MemorySummaryModel? journey,
    AdvancedEnergyExternalSummary? externalSummary,
    Map<String, int> energyStateCounts = const {},
  }) {
    final externalHints = _safeExternalHints(externalSummary);
    return EnergyBudgetModel(
      status: 'insufficient_data',
      mostDrainingSource: '现在还没有足够的内部信号来判断能量流向。',
      recoveryClue: '可以先从今天里记录一个稍微省力或稍微耗力的片段。',
      bufferLocation: '暂时还没有明确需要 buffer 的位置。',
      switchingAdjustment: _switchingAdjustment(
        const _EnergyStats.empty(),
        weekly,
      ),
      experimentConnection: _experimentConnection(
        const [],
        weekly: weekly,
        journey: journey,
      ),
      scheduleDensityHint: _scheduleDensityHint(externalHints),
      recoverySignalHint: _recoverySignalHint(externalHints),
      externalConflictNote: '外部提示只是辅助线索。内部 Signal Card 不足时，不自动下结论。',
      abstractExternalHints: externalHints,
      energyStateCounts: energyStateCounts,
      blocks: const [],
    );
  }

  /// Projects one eligible Signal into exactly one user-facing energy state.
  ///
  /// Explicit user input wins over derived markers. A planned time-use Signal
  /// is still a real Signal, but its prospective energy selection is not an
  /// observed fact, so it is projected as steady. The semantic fallback order
  /// is boundary/buffer -> recovery -> draining -> ease. Directionless or
  /// unsupported values resolve to steady; there is no unknown bucket.
  EnergySignalState _energyStateFor(RecentSignalModel signal) {
    if (signal.sourceType == 'time_use' && !_isCompletedTimeUse(signal)) {
      return EnergySignalState.steady;
    }

    final explicitLevel = _parsedEnergyLevel(signal, state: '');
    if (explicitLevel != null) {
      if (explicitLevel.$1 <= 0) return EnergySignalState.draining;
      if (explicitLevel.$1 >= 2) return EnergySignalState.ease;
      return EnergySignalState.steady;
    }

    final legacyEffect = signal.rawPayloadJson['energy_effect']
            ?.toString()
            .trim()
            .toLowerCase() ??
        '';
    switch (legacyEffect) {
      case 'draining':
        return EnergySignalState.draining;
      case 'restoring':
      case 'recovery':
        return EnergySignalState.recovery;
      case 'ease':
      case 'resourced':
        return EnergySignalState.ease;
      case 'neutral':
      case 'steady':
        return EnergySignalState.steady;
    }

    final serverState = signal.energyState?.trim().toLowerCase();
    if (serverState != null &&
        EnergySignalState.values
            .any((state) => state.storageValue == serverState)) {
      return EnergySignalState.fromStorage(serverState);
    }

    final energyLoad = (signal.energyLoad ?? '').trim().toLowerCase();
    final friction = (signal.friction ?? '').trim().toLowerCase();
    final positive = (signal.positiveSignal ?? '').trim().toLowerCase();
    final content = signal.content.trim().toLowerCase();
    final stages = signal.linkedLifeChainStages
        .map((stage) => stage.trim().toLowerCase())
        .toSet();

    final hasBoundaryBufferMarker =
        _containsAny(energyLoad, const ['boundary_buffer', 'buffer']) ||
            _containsAny(
              friction,
              const [
                'boundary',
                'self_boundary',
                'boundary_load',
                'overcommit',
                'capacity_limit',
              ],
            ) ||
            stages.any(
              const {
                'boundary',
                'boundary_load',
                'buffer',
                'boundary_buffer',
              }.contains,
            ) ||
            _containsAny(
              content,
              const [
                '留出余地',
                '留一点余地',
                '留了余地',
                '留出空间',
                '留了空间',
                '留出缓冲',
                '留了缓冲',
                '设了边界',
                '守住边界',
                '拒绝了',
                '说了不',
                'made room',
                'left room',
                'left a buffer',
                'set a boundary',
                'said no',
                '余白を残',
                '境界を守',
                '断った',
              ],
            );
    if (hasBoundaryBufferMarker) return EnergySignalState.boundaryBuffer;

    final hasRecoveryMarker = _containsAny(
          energyLoad,
          const ['restore', 'restoring', 'restorative', 'recovery'],
        ) ||
        stages.contains('recovery') ||
        _containsAny(
          content,
          const [
            '恢复了一点',
            '恢复过来',
            '缓过来',
            '补回精力',
            '休息后',
            '散步后',
            '睡了一觉',
            '充上电',
            'recovered',
            'felt restored',
            'after resting',
            'after a walk',
            '回復した',
            '休んだ後',
            '散歩の後',
          ],
        );
    if (hasRecoveryMarker) return EnergySignalState.recovery;

    final hasDrainingMarker = _containsAny(
          energyLoad,
          const ['drain', 'draining', 'high_drain', 'exhaust'],
        ) ||
        stages.contains('energy_drain') ||
        _containsAny(
          content,
          const [
            '很耗力',
            '有点耗力',
            '特别消耗',
            '精疲力尽',
            '很累',
            '疲惫',
            'exhausted',
            'draining',
            'worn out',
            '疲れた',
            '消耗した',
          ],
        );
    if (hasDrainingMarker) return EnergySignalState.draining;

    final hasEaseMarker = _containsAny(
          energyLoad,
          const [
            'ease',
            'easy',
            'light',
            'resourced',
          ],
        ) ||
        positive.isNotEmpty ||
        _containsAny(
          content,
          const [
            '有余力',
            '很轻松',
            '比较轻松',
            '很顺畅',
            '精力很足',
            '状态很好',
            'felt easy',
            'felt light',
            'had energy left',
            'went smoothly',
            '余力がある',
            '楽だった',
            '順調だった',
          ],
        );
    if (hasEaseMarker) return EnergySignalState.ease;

    return EnergySignalState.steady;
  }

  Map<String, String> _safeExternalHints(
    AdvancedEnergyExternalSummary? externalSummary,
  ) {
    final metadata = externalSummary?.toAbstractMetadata() ?? const {};
    // Calendar abstractions are intentionally excluded from the current
    // Energy Budget contract. Only abstract Health recovery hints can affect
    // capacity, copy, or the planning source hash.
    const allowed = {
      'sleep_recovery_hint',
      'movement_recovery_hint',
      'workout_load_hint',
      'recovery_gap_hint',
      'low_recovery_hint',
      'stable_recovery_hint',
    };
    return {
      for (final entry in metadata.entries)
        if (allowed.contains(entry.key) && entry.value.trim().isNotEmpty)
          entry.key: entry.value.trim(),
    };
  }

  String _scheduleDensityHint(Map<String, String> hints) {
    return '不会读取系统日历；能量预算只使用你主动登记的时间信号。';
  }

  String _recoverySignalHint(Map<String, String> hints) {
    final source = hints['low_recovery_hint'] ??
        hints['recovery_gap_hint'] ??
        hints['sleep_recovery_hint'] ??
        hints['movement_recovery_hint'] ??
        hints['workout_load_hint'] ??
        hints['stable_recovery_hint'];
    if (source == null || source.isEmpty) {
      return '还没有额外的恢复信号提示。能量预算会继续先看你的内部记录。';
    }
    return '恢复信号提示：$source 这不是健康评分，也不是健康评价。';
  }

  String _externalConflictNote(
    _EnergyStats stats,
    Map<String, String> hints,
  ) {
    if (hints.isEmpty) {
      return '没有外部辅助提示时，能量预算会回到内部 Signal Card。';
    }
    final hasConfirmedInternal = stats.signals.any(
      (signal) =>
          signal.userConfirmation == 'accurate' ||
          signal.userConfirmation == 'edited' ||
          signal.userConfirmation == 'supplemented',
    );
    if (hasConfirmedInternal) {
      return '如果外部提示和你的确认记录不一致，以你确认过的 Signal Card 和反馈为准。';
    }
    return '外部提示只是辅助线索，不一定代表你的真实感受。';
  }

  List<FeedbackEventModel> _effectiveFeedbackEvents(
    Iterable<FeedbackEventModel> events,
  ) {
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
      final key = '${event.subjectType}|${event.subjectId}|${event.localDate}';
      latest[key] = event;
    }
    final result = latest.values.toList()
      ..sort((a, b) {
        final dateCompare = a.localDate.compareTo(b.localDate);
        if (dateCompare != 0) return dateCompare;
        return a.id.compareTo(b.id);
      });
    return result;
  }

  EnergyCapacityBand _deriveCapacityBand({
    required EnergyBudgetPeriodKind periodKind,
    required List<RecentSignalModel> signals,
    required List<FeedbackEventModel> feedbackEvents,
    required _EnergyStats stats,
    required Map<String, String> externalHints,
  }) {
    final explicitLevel = _latestOneTapEnergyLevel(signals);
    if (periodKind == EnergyBudgetPeriodKind.daily) {
      if (explicitLevel != null) {
        // A direct status check-in is the current-state anchor. A completed
        // time-use observation can add context, but it must never replace a
        // user's latest explicit one-tap state for the day.
        return _capacityFromExplicitLevel(explicitLevel.$1, explicitLevel.$2);
      }
      final contextualLevels = signals
          .map(_completedTimeUseEnergyLevel)
          .whereType<(int, String)>()
          .toList(growable: false);
      return _capacityFromTimeUseContext(contextualLevels);
    }

    final explicitLevels = signals
        .map(_budgetEnergyLevel)
        .whereType<(int, String)>()
        .toList(growable: false);
    final hasCapacityEvidence = explicitLevels.isNotEmpty ||
        stats.blockCounts.isNotEmpty ||
        feedbackEvents.isNotEmpty;
    if (!hasCapacityEvidence) return EnergyCapacityBand.unknown;

    var score = 0;
    for (final value in explicitLevels) {
      score += switch (_capacityFromExplicitLevel(value.$1, value.$2)) {
        EnergyCapacityBand.veryLow => -3,
        EnergyCapacityBand.low => -2,
        EnergyCapacityBand.medium => 1,
        EnergyCapacityBand.high => 2,
        EnergyCapacityBand.unknown => 0,
      };
    }
    score -= (stats.blockCounts['high_drain'] ?? 0) * 2;
    score -= stats.blockCounts['high_switching'] ?? 0;
    score += stats.blockCounts['recovery'] ?? 0;
    for (final event in feedbackEvents) {
      score += _feedbackCapacityDelta(event);
    }

    // External hints may only make a plan more conservative. They never
    // create a positive capacity state or override explicit user evidence.
    final externalText = externalHints.values.join(' ').toLowerCase();
    if (_containsAny(
      externalText,
      const ['low', 'weak', 'dense', 'back-to-back', 'missing', 'gap'],
    )) {
      score -= 1;
    }

    if (score <= -4) return EnergyCapacityBand.veryLow;
    if (score <= -1) return EnergyCapacityBand.low;
    if (score >= 5 && explicitLevels.isNotEmpty) {
      return EnergyCapacityBand.high;
    }
    return EnergyCapacityBand.medium;
  }

  (int, String)? _latestOneTapEnergyLevel(
    Iterable<RecentSignalModel> signals,
  ) {
    final explicit = signals
        .map((signal) => (signal, value: _oneTapEnergyLevel(signal)))
        .where((entry) => entry.value != null)
        .toList()
      ..sort((a, b) {
        final aTime = a.$1.createdAt ?? DateTime(0);
        final bTime = b.$1.createdAt ?? DateTime(0);
        final timeCompare = aTime.compareTo(bTime);
        if (timeCompare != 0) return timeCompare;
        return (a.$1.signalCardId ?? a.$1.id ?? '')
            .compareTo(b.$1.signalCardId ?? b.$1.id ?? '');
      });
    return explicit.isEmpty ? null : explicit.last.value;
  }

  (int, String)? _oneTapEnergyLevel(RecentSignalModel signal) {
    if (signal.sourceType != 'one_tap') return null;
    return _parsedEnergyLevel(
      signal,
      state: signal.rawPayloadJson['quick_status']?.toString() ?? '',
    );
  }

  (int, String)? _completedTimeUseEnergyLevel(RecentSignalModel signal) {
    if (!_isCompletedTimeUse(signal)) return null;
    final level = _parsedEnergyLevel(signal, state: '');
    if (level != null) return level;

    // v1 compatibility: the old three-way effect was an explicit user
    // selection. Preserve all three values (including neutral) as contextual
    // evidence while v2 writes the shared 0/1/2 energy scale.
    final legacyEffect = signal.rawPayloadJson['energy_effect']
            ?.toString()
            .trim()
            .toLowerCase() ??
        '';
    return switch (legacyEffect) {
      'draining' => (0, ''),
      'neutral' => (1, ''),
      'restoring' => (2, ''),
      _ => null,
    };
  }

  (int, String)? _budgetEnergyLevel(RecentSignalModel signal) {
    return _oneTapEnergyLevel(signal) ?? _completedTimeUseEnergyLevel(signal);
  }

  (int, String)? _parsedEnergyLevel(
    RecentSignalModel signal, {
    required String state,
  }) {
    final raw = signal.rawPayloadJson['energy_level'];
    final level = switch (raw) {
      final int value => value,
      final num value when value == value.roundToDouble() => value.toInt(),
      _ => int.tryParse(raw?.toString() ?? ''),
    };
    if (level == null || level < 0 || level > 2) return null;
    return (level, state);
  }

  bool _isCompletedTimeUse(RecentSignalModel signal) {
    if (signal.sourceType != 'time_use') return false;
    final status = signal.rawPayloadJson['record_status']
            ?.toString()
            .trim()
            .toLowerCase() ??
        '';
    final schemaVersionRaw = signal.rawPayloadJson['schema_version'];
    final schemaVersion = schemaVersionRaw is num
        ? schemaVersionRaw.toInt()
        : int.tryParse(schemaVersionRaw?.toString() ?? '');
    final legacyEffect = signal.rawPayloadJson['energy_effect']
            ?.toString()
            .trim()
            .toLowerCase() ??
        '';
    final explicitlyCompleted =
        const {'completed', 'occurred', 'actual'}.contains(status);
    final legacyCompletedWithoutStatus = status.isEmpty &&
        (schemaVersion ?? 1) < 2 &&
        const {'draining', 'neutral', 'restoring'}.contains(legacyEffect);
    if (!explicitlyCompleted && !legacyCompletedWithoutStatus) return false;
    final rawEndAt = signal.rawPayloadJson['end_at']?.toString().trim() ?? '';
    final endAt = DateTime.tryParse(rawEndAt);
    if (endAt != null && endAt.toUtc().isAfter(nowLoader().toUtc())) {
      return false;
    }
    return true;
  }

  EnergyCapacityBand _capacityFromTimeUseContext(
    List<(int, String)> levels,
  ) {
    if (levels.isEmpty) return EnergyCapacityBand.unknown;
    final average =
        levels.fold<int>(0, (sum, value) => sum + value.$1) / levels.length;
    if (average < 0.75) return EnergyCapacityBand.low;
    if (average > 1.5) return EnergyCapacityBand.high;
    return EnergyCapacityBand.medium;
  }

  EnergyCapacityBand _capacityFromExplicitLevel(int level, String state) {
    if (level <= 0) {
      final normalized = state.trim().toLowerCase();
      if (const {'tired', 'anxious', 'exhausted', '疲惫', '焦虑'}
          .contains(normalized)) {
        return EnergyCapacityBand.veryLow;
      }
      return EnergyCapacityBand.low;
    }
    if (level == 1) return EnergyCapacityBand.medium;
    return EnergyCapacityBand.high;
  }

  int _feedbackCapacityDelta(FeedbackEventModel event) {
    final text = [
      event.status,
      event.effect,
      event.note,
      ...event.metadata.values.map((value) => value?.toString()),
    ].whereType<String>().join(' ').toLowerCase();
    if (_containsAny(
      text,
      const [
        'not_suitable',
        'not helpful',
        'not_helpful',
        'too hard',
        'difficult',
        'draining',
        'exhaust',
        '不适合',
        '困难',
        '耗力',
      ],
    )) {
      return -1;
    }
    if (_containsAny(
      text,
      const [
        'helpful',
        'lighter',
        'restor',
        'easy',
        '有帮助',
        '轻松',
        '恢复',
      ],
    )) {
      return 1;
    }
    return 0;
  }

  String _snapshotSourceHash({
    required EnergyBudgetPeriodKind periodKind,
    required String startKey,
    required String endKey,
    required List<RecentSignalModel> signals,
    required List<FeedbackEventModel> feedbackEvents,
    required Map<String, String> externalHints,
    required EnergyCapacityBand capacityBand,
  }) {
    final sortedSignals = signals.toList()
      ..sort((a, b) => (a.signalCardId ?? a.id ?? '')
          .compareTo(b.signalCardId ?? b.id ?? ''));
    final sortedHints = externalHints.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final canonical = <String>[
      EnergyBudgetSnapshot.policyVersion,
      periodKind.storageValue,
      startKey,
      endKey,
      capacityBand.storageValue,
      for (final signal in sortedSignals)
        [
          signal.signalCardId ?? signal.id ?? '',
          signal.localDateKey(),
          signal.content.trim(),
          signal.energyLoad ?? '',
          signal.friction ?? '',
          signal.positiveSignal ?? '',
          signal.userConfirmation,
          signal.privacyLevel,
          jsonEncode(signal.rawPayloadJson),
        ].join('|'),
      for (final event in feedbackEvents)
        [
          event.id,
          event.subjectType,
          event.subjectId,
          event.localDate,
          event.status,
          event.effect ?? '',
          event.note ?? '',
          jsonEncode(event.metadata),
        ].join('|'),
      for (final hint in sortedHints) '${hint.key}=${hint.value}',
    ].join('\n');
    return _fnv1a(canonical);
  }

  String _snapshotConfidence(
    int signalCount,
    int feedbackCount,
    bool hasExplicitState,
  ) {
    if (signalCount == 0 && feedbackCount == 0 && !hasExplicitState) {
      return 'unknown';
    }
    if (hasExplicitState && signalCount + feedbackCount >= 3) return 'high';
    if (signalCount + feedbackCount >= 2) return 'medium';
    return 'low';
  }

  String _snapshotTimezone(
    Iterable<RecentSignalModel> signals,
    DateTime fallback,
  ) {
    for (final signal in signals) {
      final timezone = signal.timezone?.trim();
      if (timezone != null && timezone.isNotEmpty) return timezone;
    }
    return fallback.timeZoneName;
  }

  bool _overlapsPeriod(
    String start,
    String end,
    String periodStart,
    String periodEnd,
  ) {
    if (start.trim().isEmpty || end.trim().isEmpty) return false;
    return start.compareTo(periodEnd) <= 0 && end.compareTo(periodStart) >= 0;
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _fnv1a(String value) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(value)) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  bool _containsAny(String value, List<String> needles) {
    return needles.any(value.contains);
  }

  void _countIfPresent(Map<String, int> counts, String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return;
    counts[normalized] = (counts[normalized] ?? 0) + 1;
  }

  String _topKey(Map<String, int> counts) {
    if (counts.isEmpty) return '';
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.first.key;
  }

  String _mergeEvidenceLevel(String? current, String next) {
    const rank = {
      'accurate': 4,
      'edited': 4,
      'supplemented': 4,
      'unconfirmed': 2,
      'legacy_context': 1,
    };
    final currentRank = rank[current] ?? 0;
    final nextRank = rank[next] ?? 0;
    return nextRank > currentRank ? next : (current ?? next);
  }
}

class _EnergyStats {
  final List<RecentSignalModel> signals;
  final Map<String, int> blockCounts;
  final Map<String, String> blockEvidenceLevels;
  final Map<String, int> energyStateCounts;
  final String topScene;
  final String topFriction;
  final String topPositive;
  final String topStage;

  const _EnergyStats({
    required this.signals,
    required this.blockCounts,
    required this.blockEvidenceLevels,
    required this.energyStateCounts,
    required this.topScene,
    required this.topFriction,
    required this.topPositive,
    required this.topStage,
  });

  const _EnergyStats.empty()
      : signals = const [],
        blockCounts = const {},
        blockEvidenceLevels = const {},
        energyStateCounts = const {
          'draining': 0,
          'steady': 0,
          'ease': 0,
          'recovery': 0,
          'boundary_buffer': 0,
        },
        topScene = '',
        topFriction = '',
        topPositive = '',
        topStage = '';

  String get topFrictionOrScene {
    if (topFriction.isNotEmpty) return topFriction;
    if (topScene.isNotEmpty) return topScene;
    return topStage;
  }
}
