import 'dart:convert';

import '../../energy/energy_signal_classifier.dart';
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
import '../../i18n/runtime_locale_text.dart';

class EnergyBudgetRepository {
  final LocalCaptureRepository localCaptureRepository;
  final LocalLifeExperimentRepository? localLifeExperimentRepository;
  final ExternalEnergyHintStore? externalEnergyHintStore;
  final LocalFeedbackEventRepository? feedbackEventRepository;
  final String localUserId;
  final SignalEligibilityService eligibilityService;
  final DateTime Function() nowLoader;
  final String Function() languageLoader;

  EnergyBudgetRepository({
    required this.localCaptureRepository,
    this.localLifeExperimentRepository,
    this.externalEnergyHintStore,
    this.feedbackEventRepository,
    this.localUserId = 'local',
    SignalEligibilityService? eligibilityService,
    DateTime Function()? nowLoader,
    String Function()? languageLoader,
  })  : eligibilityService =
            eligibilityService ?? const SignalEligibilityService(),
        nowLoader = nowLoader ?? DateTime.now,
        languageLoader = languageLoader ?? RuntimeLocaleText.deviceLanguageCode;

  /// Canonical five-state classifier shared by status, time-use and weekly
  /// read models. It is pure and never writes a Signal or budget snapshot.
  EnergySignalState classifySignal(RecentSignalModel signal) =>
      const EnergySignalClassifier().classify(signal, now: nowLoader());

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
      final energyState = classifySignal(signal);
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
    final labels = {
      'high_drain': _copy(
          en: 'high-drain block',
          zhHans: '高负担时段',
          zhHant: '高負擔時段',
          ja: '負担の大きい時間帯'),
      'high_switching': _copy(
          en: 'high-switching block',
          zhHans: '频繁切换时段',
          zhHant: '頻繁切換時段',
          ja: '切り替えの多い時間帯'),
      'deep': _copy(
          en: 'deep-focus block',
          zhHans: '深度投入时段',
          zhHant: '深度投入時段',
          ja: '深く集中する時間帯'),
      'recovery': _copy(
          en: 'recovery block', zhHans: '恢复时段', zhHant: '恢復時段', ja: '回復の時間帯'),
      'boundary': _copy(
          en: 'boundary block', zhHans: '边界与余地', zhHant: '邊界與餘地', ja: '境界と余白'),
      'buffer': _copy(
          en: 'buffer block', zhHans: '缓冲时段', zhHant: '緩衝時段', ja: '余白の時間帯'),
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
        return _copy(
            en: 'This may take energy. Notice whether it often appears with “${stats.topFrictionOrScene}”.',
            zhHans: '这个安排可能有点耗力，先看它是不是常和“${stats.topFrictionOrScene}”一起出现。',
            zhHant: '這個安排可能有點耗力，先看它是否常和「${stats.topFrictionOrScene}」一起出現。',
            ja: 'この予定は少し負担かもしれません。「${stats.topFrictionOrScene}」と一緒に現れやすいか見てみましょう。');
      case 'high_switching':
        return _copy(
            en: 'Switching looks demanding here; leave a little buffer.',
            zhHans: '这里像是切换负担比较重的位置，可以先给它留一点余地。',
            zhHant: '這裡像是切換負擔較重的位置，可以先留一點餘地。',
            ja: 'ここは切り替えの負担が大きそうです。少し余白を残しましょう。');
      case 'deep':
        return _copy(
            en: 'This seems to need uninterrupted attention and may not suit frequent interruptions.',
            zhHans: '这里更像需要完整注意力的投入，不一定适合被频繁插入。',
            zhHant: '這裡更像需要完整注意力的投入，不一定適合被頻繁插入。',
            ja: 'ここはまとまった注意が必要で、頻繁な割り込みには向かないかもしれません。');
      case 'recovery':
        return _copy(
            en: 'A recovery Signal appears here; notice how it usually happens.',
            zhHans: '这里出现了一点恢复 Signal，可以先留意它通常怎么发生。',
            zhHant: '這裡出現了一點恢復 Signal，可以先留意它通常如何發生。',
            ja: 'ここに回復の Signal が見えます。普段どのように起きるか見てみましょう。');
      case 'boundary':
        return _copy(
            en: 'This may need a boundary—not rejection, but less continuous pull.',
            zhHans: '这里可能需要一点边界，不是拒绝事情，而是减少被持续拉走。',
            zhHant: '這裡可能需要一點邊界，不是拒絕事情，而是減少被持續拉走。',
            ja: 'ここには少し境界が必要かもしれません。拒むのではなく、引っ張られ続ける状態を減らすためです。');
      default:
        return _copy(
            en: 'Leave some buffer so adjacent plans are not packed too tightly.',
            zhHans: '这里适合留一点缓冲，让前后安排不要贴得太紧。',
            zhHant: '這裡適合留一點緩衝，讓前後安排不要貼得太緊。',
            ja: '前後の予定が詰まりすぎないよう、少し余白を残す場所です。');
    }
  }

  String _mostDrainingSource(_EnergyStats stats) {
    final source = stats.topFrictionOrScene;
    if (source.isEmpty) {
      return _copy(
          en: 'There is no clear source of drain yet; gentle observation is enough.',
          zhHans: '这段时间还没有特别清楚的耗力来源，先保持小观察就好。',
          zhHant: '這段時間還沒有特別清楚的耗力來源，先保持小觀察就好。',
          ja: 'まだ明確な消耗源はありません。軽く観察するだけで十分です。');
    }
    return _copy(
        en: 'One possible source of drain is “$source”. It may take energy, without needing an immediate judgment.',
        zhHans: '这段时间最耗力的一个来源可能是“$source”。先不用急着评价它。',
        zhHant: '這段時間最耗力的一個來源可能是「$source」。先不用急著評價它。',
        ja: 'この期間の消耗源の一つは「$source」かもしれません。すぐに評価しなくて大丈夫です。');
  }

  String _recoveryClue(_EnergyStats stats, MemorySummaryModel? journey) {
    final positive = stats.topPositive;
    if (positive.isNotEmpty) {
      return _copy(
          en: 'A recovery Signal is “$positive”. Keep it as a possible source of ease.',
          zhHans: '一个恢复 Signal 是“$positive”。它可以先作为省力 Signal 保留下来。',
          zhHant: '一個恢復 Signal 是「$positive」。可以先作為省力 Signal 保留下來。',
          ja: '回復の Signal は「$positive」です。負担を減らす手がかりとして残せます。');
    }
    final journeyRecovery = journey?.recoverySignal?.summary.trim();
    if (journeyRecovery != null && journeyRecovery.isNotEmpty) {
      return journeyRecovery;
    }
    return _copy(
        en: 'Recovery Signals are not clear yet. Notice moments that feel slightly less demanding.',
        zhHans: '恢复 Signal 还不明显。现在先看哪些时刻让你稍微没那么耗力。',
        zhHant: '恢復 Signal 還不明顯。現在先看哪些時刻讓你稍微沒那麼耗力。',
        ja: '回復の Signal はまだ明確ではありません。少し負担が軽い瞬間を見てみましょう。');
  }

  String _bufferLocation(_EnergyStats stats) {
    final source = stats.topFrictionOrScene;
    if (source.isEmpty) {
      return _copy(
          en: 'No clear place needs a buffer yet.',
          zhHans: '暂时还没有明确需要留出缓冲的位置。',
          zhHant: '暫時還沒有明確需要留出緩衝的位置。',
          ja: 'まだ明確に余白が必要な場所はありません。');
    }
    return _copy(
        en: 'Treat “$source” as a place for buffer so adjacent plans are not too tight.',
        zhHans: '可以先把“$source”看作需要留出缓冲的位置，让它前后不要贴得太紧。',
        zhHant: '可以先把「$source」看作需要留出緩衝的位置，讓前後安排不要貼得太緊。',
        ja: '「$source」は余白を残す場所として、前後の予定を詰めすぎないようにできます。');
  }

  String _switchingAdjustment(_EnergyStats stats, WeeklyInsightModel? weekly) {
    final weeklyExperiment = weekly?.deriveV3CStructure().oneExperiment.trim();
    if (weeklyExperiment != null && weeklyExperiment.isNotEmpty) {
      return _copy(
          en: 'Leave a little room here: $weeklyExperiment',
          zhHans: '可以先给这里留一点余地：$weeklyExperiment',
          zhHant: '可以先給這裡留一點餘地：$weeklyExperiment',
          ja: 'ここに少し余白を残せます：$weeklyExperiment');
    }
    final source = stats.topFrictionOrScene;
    if (source.isEmpty) {
      return _copy(
          en: 'Try changing one fewer thing instead of many plans at once.',
          zhHans: '可以先试试少调整一件事，而不是同时改变很多安排。',
          zhHant: '可以先試試少調整一件事，而不是同時改變很多安排。',
          ja: '多くの予定を同時に変えず、変えるものを一つ減らしてみましょう。');
    }
    return _copy(
        en: 'Leave some room around “$source” to reduce switching burden.',
        zhHans: '可以先给“$source”留一点余地，减少来回切换的负担。',
        zhHant: '可以先給「$source」留一點餘地，減少來回切換的負擔。',
        ja: '「$source」の前後に余白を残し、切り替えの負担を減らせます。');
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
          ? _copy(
              en: 'No feedback yet is okay.',
              zhHans: '还没有反馈也没关系。',
              zhHant: '還沒有回饋也沒關係。',
              ja: 'まだフィードバックがなくても大丈夫です。')
          : _copy(
              en: 'Feedback: $feedback.',
              zhHans: '反馈是：$feedback。',
              zhHant: '回饋是：$feedback。',
              ja: 'フィードバック：$feedback。');
      return _copy(
          en:
              'Connected to the recent experiment “${latest.title}”. $feedbackText Review whether it reduced your burden.',
          zhHans:
              '可以连接到最近的小实验：“${latest.title}”。$feedbackText 这里看的是它有没有帮你省一点力。',
          zhHant:
              '可以連接到最近的小實驗：「${latest.title}」。$feedbackText 這裡看的是它是否幫你省了一點力。',
          ja: '直近の実験「${latest.title}」につながります。$feedbackText 負担が減ったかを見ます。');
    }
    final weeklyExperiment = weekly?.lifeExperiment;
    if (weeklyExperiment != null) {
      return _copy(
          en: 'Connected to this week’s goal “${weeklyExperiment.title}”. Review whether it reduced your burden.',
          zhHans: '可以连接到本周的目标：“${weeklyExperiment.title}”。先看它有没有帮你省一点力。',
          zhHant: '可以連接到本週的目標：「${weeklyExperiment.title}」。先看它是否幫你省了一點力。',
          ja: '今週の目標「${weeklyExperiment.title}」につながります。負担が減ったかを見てみましょう。');
    }
    final journeyAdjustment = journey?.nextAdjustmentDirection.summary.trim();
    if (journeyAdjustment != null && journeyAdjustment.isNotEmpty) {
      return journeyAdjustment;
    }
    return _copy(
        en: 'There is no experiment to connect yet. You can begin with one small adjustment later.',
        zhHans: '还没有可连接的小实验。之后可以从一个很小的调整开始。',
        zhHant: '還沒有可連接的小實驗。之後可以從一個很小的調整開始。',
        ja: 'まだつながる実験はありません。後から小さな調整一つから始められます。');
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
      mostDrainingSource: _copy(
          en: 'There are not enough internal Signals to read energy flow yet.',
          zhHans: '现在还没有足够的内部 Signal 来判断精力流向。',
          zhHant: '現在還沒有足夠的內部 Signal 來判斷精力流向。',
          ja: 'エネルギーの流れを見るには、まだ内部 Signal が足りません。'),
      recoveryClue: _copy(
          en: 'Record one moment today that felt slightly easier or more demanding.',
          zhHans: '可以先记录今天一个稍微省力或稍微耗力的片段。',
          zhHant: '可以先記錄今天一個稍微省力或稍微耗力的片段。',
          ja: '今日、少し楽だった瞬間か負担だった瞬間を一つ記録してみましょう。'),
      bufferLocation: _copy(
          en: 'No clear place needs a buffer yet.',
          zhHans: '暂时还没有明确需要留出缓冲的位置。',
          zhHant: '暫時還沒有明確需要留出緩衝的位置。',
          ja: 'まだ明確に余白が必要な場所はありません。'),
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
      externalConflictNote: _copy(
          en: 'External hints are only supporting Signals and never create conclusions on their own.',
          zhHans: '外部提示只是辅助 Signal，不会单独形成结论。',
          zhHant: '外部提示只是輔助 Signal，不會單獨形成結論。',
          ja: '外部のヒントは補助的な Signal であり、それだけで結論にはなりません。'),
      abstractExternalHints: externalHints,
      energyStateCounts: energyStateCounts,
      blocks: const [],
    );
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
    return _copy(
        en: 'The system calendar is not read; this overview only uses time Signals you enter.',
        zhHans: '不会读取系统日历；这里只使用你主动登记的时间 Signal。',
        zhHant: '不會讀取系統日曆；這裡只使用你主動登記的時間 Signal。',
        ja: 'システムのカレンダーは読み取りません。自分で登録した時間の Signal だけを使います。');
  }

  String _recoverySignalHint(Map<String, String> hints) {
    MapEntry<String, String>? selectedHint;
    for (final key in const [
      'low_recovery_hint',
      'recovery_gap_hint',
      'sleep_recovery_hint',
      'movement_recovery_hint',
      'workout_load_hint',
      'stable_recovery_hint',
    ]) {
      final value = hints[key]?.trim();
      if (value != null && value.isNotEmpty) {
        selectedHint = MapEntry(key, value);
        break;
      }
    }
    if (selectedHint == null) {
      return _copy(
          en: 'There is no additional recovery Signal; your own records remain primary.',
          zhHans: '还没有额外的恢复 Signal，会继续优先看你的内部记录。',
          zhHant: '還沒有額外的恢復 Signal，會繼續優先看你的內部記錄。',
          ja: '追加の回復 Signal はありません。自分の記録を優先して見ていきます。');
    }
    final source = _localizedRecoveryHint(
      selectedHint.key,
      selectedHint.value,
    );
    return _copy(
        en: 'Recovery Signal: $source This is not a health score or medical assessment.',
        zhHans: '恢复 Signal：$source 这不是健康评分，也不是健康评价。',
        zhHant: '恢復 Signal：$source 這不是健康評分，也不是健康評價。',
        ja: '回復の Signal：$source これは健康スコアや医学的評価ではありません。');
  }

  String _localizedRecoveryHint(String key, String source) {
    if (RuntimeLocaleText.normalize(languageLoader()) == 'en') return source;

    switch (key) {
      case 'low_recovery_hint':
        return _copy(
          en: source,
          zhHans: '这段时间的恢复线索可能偏弱。',
          zhHant: '這段時間的恢復線索可能偏弱。',
          ja: 'この期間は回復の手がかりが少し弱いかもしれません。',
        );
      case 'recovery_gap_hint':
        return _copy(
          en: source,
          zhHans: '这段时间可以多留一点恢复空间。',
          zhHant: '這段時間可以多留一點恢復空間。',
          ja: 'この期間は回復の余白を少し残せそうです。',
        );
      case 'sleep_recovery_hint':
        final isSteady = source.toLowerCase().contains('steady');
        return _copy(
          en: source,
          zhHans: isSteady ? '睡眠带来的恢复相对平稳。' : '睡眠带来的恢复可能有些不足。',
          zhHant: isSteady ? '睡眠帶來的恢復相對平穩。' : '睡眠帶來的恢復可能有些不足。',
          ja: isSteady ? '睡眠による回復は比較的安定しています。' : '睡眠による回復が少し弱いかもしれません。',
        );
      case 'movement_recovery_hint':
        final offersSupport =
            source.toLowerCase().contains('offering some recovery');
        return _copy(
          en: source,
          zhHans: offersSupport ? '活动可能正在帮助恢复。' : '这段时间，活动带来的恢复线索较少。',
          zhHant: offersSupport ? '活動可能正在幫助恢復。' : '這段時間，活動帶來的恢復線索較少。',
          ja: offersSupport
              ? '活動が回復を支えている可能性があります。'
              : 'この期間は、活動による回復の手がかりが少なめです。',
        );
      case 'workout_load_hint':
        final isNotMainPressure =
            source.toLowerCase().contains('does not look');
        return _copy(
          en: source,
          zhHans:
              isNotMainPressure ? '运动负担目前不像主要压力来源。' : '近期运动负担较高，可能需要多留一点恢复空间。',
          zhHant:
              isNotMainPressure ? '運動負擔目前不像主要壓力來源。' : '近期運動負擔較高，可能需要多留一點恢復空間。',
          ja: isNotMainPressure
              ? '運動負荷は今のところ主な負担ではなさそうです。'
              : '最近の運動負荷を考えると、回復の余白を少し増やせそうです。',
        );
      case 'stable_recovery_hint':
        return _copy(
          en: source,
          zhHans: '这段时间的恢复线索相对平稳。',
          zhHant: '這段時間的恢復線索相對平穩。',
          ja: 'この期間の回復の手がかりは比較的安定しています。',
        );
      default:
        return _copy(
          en: source,
          zhHans: '这里有一条辅助恢复提示。',
          zhHant: '這裡有一條輔助恢復提示。',
          ja: '回復についての補助的な手がかりがあります。',
        );
    }
  }

  String _externalConflictNote(
    _EnergyStats stats,
    Map<String, String> hints,
  ) {
    if (hints.isEmpty) {
      return _copy(
          en: 'Without external hints, the overview relies on your internal Signal Cards.',
          zhHans: '没有外部辅助提示时，会以内部 Signal 记录为准。',
          zhHant: '沒有外部輔助提示時，會以內部 Signal 記錄為準。',
          ja: '外部ヒントがない場合、自分の Signal 記録を基準にします。');
    }
    final hasConfirmedInternal = stats.signals.any(
      (signal) =>
          signal.userConfirmation == 'accurate' ||
          signal.userConfirmation == 'edited' ||
          signal.userConfirmation == 'supplemented',
    );
    if (hasConfirmedInternal) {
      return _copy(
          en: 'If external hints conflict with your records, confirmed Signal Cards and feedback take priority.',
          zhHans: '如果外部提示和你的确认记录不一致，以你确认过的 Signal 记录和反馈为准。',
          zhHant: '如果外部提示和你的確認記錄不一致，以你確認過的 Signal 記錄和回饋為準。',
          ja: '外部ヒントと記録が一致しない場合、確認済みの Signal 記録とフィードバックを優先します。');
    }
    return _copy(
        en: 'External hints are supporting Signals and may not represent how you actually feel.',
        zhHans: '外部提示只是辅助 Signal，不一定代表你的真实感受。',
        zhHant: '外部提示只是輔助 Signal，不一定代表你的真實感受。',
        ja: '外部ヒントは補助的な Signal であり、実際の感覚を表すとは限りません。');
  }

  String _copy({
    required String en,
    required String zhHans,
    required String zhHant,
    required String ja,
  }) =>
      RuntimeLocaleText.tr(
        language: languageLoader(),
        en: en,
        zhHans: zhHans,
        zhHant: zhHant,
        ja: ja,
      );

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
