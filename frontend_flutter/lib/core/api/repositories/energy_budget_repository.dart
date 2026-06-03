import '../../local/local_capture_repository.dart';
import '../../local/local_life_experiment_repository.dart';
import '../../models/advanced_energy_boundary_models.dart';
import '../../models/energy_budget_models.dart';
import '../../models/memory_models.dart';
import '../../models/today_models.dart';
import '../../models/weekly_models.dart';

class EnergyBudgetRepository {
  final LocalCaptureRepository localCaptureRepository;
  final LocalLifeExperimentRepository? localLifeExperimentRepository;
  final String localUserId;

  EnergyBudgetRepository({
    required this.localCaptureRepository,
    this.localLifeExperimentRepository,
    this.localUserId = 'local',
  });

  Future<EnergyBudgetModel> fetchBasicEnergyBudget({
    WeeklyInsightModel? weekly,
    MemorySummaryModel? journey,
    AdvancedEnergyExternalSummary? externalSummary,
    int limit = 1000,
  }) async {
    final signals = await localCaptureRepository.listSignalCards(limit: limit);
    final eligibleSignals = signals.where(_isEnergyEligible).toList();
    final experimentHistory = await localLifeExperimentRepository?.listRecent(
          localUserId: localUserId,
        ) ??
        const <LifeExperimentModel>[];

    if (eligibleSignals.isEmpty && experimentHistory.isEmpty) {
      return _emptyBudget(
        weekly: weekly,
        journey: journey,
        externalSummary: externalSummary,
      );
    }

    final stats = _buildStats(eligibleSignals);
    final externalHints = _safeExternalHints(externalSummary);
    return EnergyBudgetModel(
      status: eligibleSignals.length < 2 ? 'light_ready' : 'ready',
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
      blocks: _blocks(stats),
    );
  }

  bool _isEnergyEligible(RecentSignalModel signal) {
    if (signal.isLocalDraft || signal.syncFailed) return false;
    if (signal.userConfirmation == 'inaccurate') return false;
    if (signal.isLibrarySaved && !signal.hasUserConfirmedLibrarySaved) {
      return false;
    }
    if (signal.isAiPredicted && !signal.hasUserConfirmedAiPrediction) {
      return false;
    }
    final privacy = signal.privacyLevel.trim().toLowerCase();
    if (privacy == 'do_not_analyze' ||
        privacy == 'excluded' ||
        privacy == 'sensitive') {
      return false;
    }
    return true;
  }

  _EnergyStats _buildStats(List<RecentSignalModel> signals) {
    final counts = <String, int>{};
    final scenes = <String, int>{};
    final frictions = <String, int>{};
    final positives = <String, int>{};
    final stages = <String, int>{};
    final evidenceLevels = <String, String>{};

    for (final signal in signals) {
      final evidenceLevel = _evidenceLevel(signal);
      _countIfPresent(scenes, signal.scene);
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
    final energyLoad = (signal.energyLoad ?? '').toLowerCase();
    final friction = (signal.friction ?? '').toLowerCase();
    final scene = (signal.scene ?? '').toLowerCase();
    final positive = (signal.positiveSignal ?? '').toLowerCase();
    final stages =
        signal.linkedLifeChainStages.map((stage) => stage.toLowerCase());

    if (_containsAny(energyLoad, const ['drain', 'draining', 'high']) ||
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

    if (types.isEmpty && energyLoad == 'neutral') {
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
      return '可以连接到最近的 Life Experiment：“${latest.title}”。$feedbackText 这里看的不是完成度，而是这个设计有没有帮你省一点力。';
    }
    final weeklyExperiment = weekly?.lifeExperiment;
    if (weeklyExperiment != null) {
      return '可以连接到本周的小实验：“${weeklyExperiment.title}”。先看它有没有帮你省一点力。';
    }
    final journeyAdjustment = journey?.nextAdjustmentDirection.summary.trim();
    if (journeyAdjustment != null && journeyAdjustment.isNotEmpty) {
      return journeyAdjustment;
    }
    return '还没有可连接的 Life Experiment。之后可以从一个很小的调整开始。';
  }

  EnergyBudgetModel _emptyBudget({
    WeeklyInsightModel? weekly,
    MemorySummaryModel? journey,
    AdvancedEnergyExternalSummary? externalSummary,
  }) {
    final externalHints = _safeExternalHints(externalSummary);
    return EnergyBudgetModel(
      status: 'insufficient_data',
      mostDrainingSource: '现在还没有足够的内部信号来判断能量流向。',
      recoveryClue: '可以先从 Today 里记录一个稍微省力或稍微耗力的片段。',
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
      externalConflictNote: '外部提示只是辅助线索。内部 SignalCard 不足时，不自动下结论。',
      abstractExternalHints: externalHints,
      blocks: const [],
    );
  }

  Map<String, String> _safeExternalHints(
    AdvancedEnergyExternalSummary? externalSummary,
  ) {
    final metadata = externalSummary?.toAbstractMetadata() ?? const {};
    const allowed = {
      'meeting_density_hint',
      'schedule_density_hint',
      'back_to_back_blocks_hint',
      'switching_hint',
      'missing_buffer_hint',
      'long_deep_block_hint',
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
    final source = hints['schedule_density_hint'] ??
        hints['meeting_density_hint'] ??
        hints['back_to_back_blocks_hint'] ??
        hints['switching_hint'];
    if (source == null || source.isEmpty) {
      return '还没有额外的日程密度提示。Energy Budget 会继续先看你的内部记录。';
    }
    return '日程密度提示：$source 这只是辅助 context，不一定代表你的真实感受。';
  }

  String _recoverySignalHint(Map<String, String> hints) {
    final source = hints['low_recovery_hint'] ??
        hints['recovery_gap_hint'] ??
        hints['sleep_recovery_hint'] ??
        hints['movement_recovery_hint'] ??
        hints['workout_load_hint'] ??
        hints['stable_recovery_hint'];
    if (source == null || source.isEmpty) {
      return '还没有额外的恢复信号提示。Energy Budget 会继续先看你的内部记录。';
    }
    return '恢复信号提示：$source 这不是健康评分，也不是健康评价。';
  }

  String _externalConflictNote(
    _EnergyStats stats,
    Map<String, String> hints,
  ) {
    if (hints.isEmpty) {
      return '没有外部辅助提示时，Energy Budget 会回到内部 SignalCard。';
    }
    final hasConfirmedInternal = stats.signals.any(
      (signal) =>
          signal.userConfirmation == 'accurate' ||
          signal.userConfirmation == 'edited' ||
          signal.userConfirmation == 'supplemented',
    );
    if (hasConfirmedInternal) {
      return '如果外部提示和你的确认记录不一致，以你确认过的 SignalCard 和反馈为准。';
    }
    return '外部提示只是辅助线索，不一定代表你的真实感受。';
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
  final String topScene;
  final String topFriction;
  final String topPositive;
  final String topStage;

  const _EnergyStats({
    required this.signals,
    required this.blockCounts,
    required this.blockEvidenceLevels,
    required this.topScene,
    required this.topFriction,
    required this.topPositive,
    required this.topStage,
  });

  const _EnergyStats.empty()
      : signals = const [],
        blockCounts = const {},
        blockEvidenceLevels = const {},
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
