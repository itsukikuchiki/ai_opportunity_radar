import '../eligibility/signal_eligibility_service.dart';
import '../eligibility/today_signal_scope.dart';
import '../models/energy_budget_models.dart';
import '../models/today_models.dart';
import 'energy_signal_classifier.dart';

enum TodayEnergyStatus { waiting, low, steady, capacity, mixed }

enum TodayLoadStatus { waiting, light, moderate, heavy, attention }

enum TodayRecoveryStatus { waiting, notSeen, appearing, clear }

/// Read-only Today projection for 精力 / 负担 / 恢复.
///
/// Explicit status is a high-weight anchor, not an override. All real
/// same-day Signal Cards and completed time-use feedback can contribute.
class TodayStatusOverview {
  static const policyVersion = 'today_overview_v2_composite';

  final TodayEnergyStatus energy;
  final TodayLoadStatus load;
  final TodayRecoveryStatus recovery;
  final int eligibleSignalCount;
  final int burdenSignalCount;
  final int recoverySignalCount;
  final Map<EnergySignalState, int> stateCounts;
  final List<String> includedSignalIds;

  const TodayStatusOverview({
    required this.energy,
    required this.load,
    required this.recovery,
    required this.eligibleSignalCount,
    required this.burdenSignalCount,
    required this.recoverySignalCount,
    required this.stateCounts,
    required this.includedSignalIds,
  });

  bool get hasEvidence => eligibleSignalCount > 0;

  factory TodayStatusOverview.fromSignals(
    Iterable<RecentSignalModel> signals, {
    DateTime? now,
    EnergySignalClassifier classifier = const EnergySignalClassifier(),
    SignalEligibilityService eligibilityService =
        const SignalEligibilityService(),
  }) {
    final referenceTime = now ?? DateTime.now();
    final liveSignals = TodaySignalScope.liveOnly(signals);
    final eligible = eligibilityService
        .filter(liveSignals, SignalEligibilityStage.daily)
        .where(
          (signal) =>
              signal.sourceType != 'time_use' ||
              classifier.isCompletedTimeUse(signal, now: referenceTime),
        )
        .toList(growable: false);

    if (eligible.isEmpty) {
      return const TodayStatusOverview(
        energy: TodayEnergyStatus.waiting,
        load: TodayLoadStatus.waiting,
        recovery: TodayRecoveryStatus.waiting,
        eligibleSignalCount: 0,
        burdenSignalCount: 0,
        recoverySignalCount: 0,
        stateCounts: {},
        includedSignalIds: [],
      );
    }

    final newestExplicitOneTap = _newestExplicitOneTap(
      eligible,
      classifier,
    );
    final stateCounts = <EnergySignalState, int>{};
    var totalWeight = 0.0;
    var score = 0.0;
    var positiveWeight = 0.0;
    var negativeWeight = 0.0;
    var burdenWeight = 0.0;
    var contextWeight = 0.0;
    var contextSignalCount = 0;
    var burdenCount = 0;
    var recoveryWeight = 0.0;
    var recoveryCount = 0;
    var directEvidenceCount = 0;

    for (final signal in eligible) {
      final state = classifier.classify(signal, now: referenceTime);
      stateCounts[state] = (stateCounts[state] ?? 0) + 1;
      final explicitLevel = classifier.explicitEnergyLevel(signal);
      final isDirectOneTap =
          signal.sourceType == 'one_tap' && explicitLevel != null;
      final isCompletedTimeUse = signal.sourceType == 'time_use' &&
          classifier.isCompletedTimeUse(signal, now: referenceTime);
      final isDirectTimeUse = isCompletedTimeUse && explicitLevel != null;
      if (isDirectOneTap || isDirectTimeUse) directEvidenceCount += 1;

      final weight = identical(signal, newestExplicitOneTap)
          ? 3.0
          : isDirectTimeUse
              ? 2.0
              : 1.0;
      totalWeight += weight;
      final supportsLoadAndRecovery = signal.sourceType != 'one_tap';
      if (supportsLoadAndRecovery) {
        contextWeight += weight;
        contextSignalCount += 1;
      }

      switch (state) {
        case EnergySignalState.draining:
          score -= weight;
          negativeWeight += weight;
        case EnergySignalState.ease:
          score += weight;
          positiveWeight += weight;
        case EnergySignalState.recovery:
          score += 0.5 * weight;
          positiveWeight += weight;
          recoveryWeight += weight;
          recoveryCount += 1;
        case EnergySignalState.steady:
        case EnergySignalState.boundaryBuffer:
          break;
      }

      if (supportsLoadAndRecovery && _isBurdenSignal(signal, state)) {
        burdenWeight += weight;
        burdenCount += 1;
      }
    }

    final onlyOneIndirect = eligible.length == 1 && directEvidenceCount == 0;
    final directionalWeight = positiveWeight + negativeWeight;
    final hasMeaningfulConflict = positiveWeight >= 2 &&
        negativeWeight >= 2 &&
        directionalWeight > 0 &&
        positiveWeight / directionalWeight >= 0.25 &&
        negativeWeight / directionalWeight >= 0.25;
    final mean = totalWeight == 0 ? 0.0 : score / totalWeight;

    final energy = onlyOneIndirect
        ? TodayEnergyStatus.waiting
        : hasMeaningfulConflict
            ? TodayEnergyStatus.mixed
            : mean <= -0.25
                ? TodayEnergyStatus.low
                : mean >= 0.25
                    ? TodayEnergyStatus.capacity
                    : TodayEnergyStatus.steady;

    final burdenRatio = contextWeight == 0 ? 0.0 : burdenWeight / contextWeight;
    final load = contextSignalCount < 2
        ? TodayLoadStatus.waiting
        : burdenCount >= 3 && burdenRatio >= 2 / 3
            ? TodayLoadStatus.attention
            : burdenRatio > 0.5
                ? TodayLoadStatus.heavy
                : burdenRatio > 0.2
                    ? TodayLoadStatus.moderate
                    : TodayLoadStatus.light;

    final recoveryRatio =
        contextWeight == 0 ? 0.0 : recoveryWeight / contextWeight;
    final recovery = recoveryCount > 0
        ? recoveryCount >= 2 && recoveryRatio >= 1 / 3
            ? TodayRecoveryStatus.clear
            : TodayRecoveryStatus.appearing
        : contextSignalCount == 0
            ? TodayRecoveryStatus.waiting
            : TodayRecoveryStatus.notSeen;

    return TodayStatusOverview(
      energy: energy,
      load: load,
      recovery: recovery,
      eligibleSignalCount: eligible.length,
      burdenSignalCount: burdenCount,
      recoverySignalCount: recoveryCount,
      stateCounts: Map.unmodifiable(stateCounts),
      includedSignalIds: List.unmodifiable(
        eligible
            .map(
              (signal) =>
                  signal.signalCardId ??
                  signal.id ??
                  signal.clientId ??
                  signal.serverId ??
                  '',
            )
            .where((id) => id.isNotEmpty),
      ),
    );
  }

  static RecentSignalModel? _newestExplicitOneTap(
    Iterable<RecentSignalModel> signals,
    EnergySignalClassifier classifier,
  ) {
    final candidates = signals
        .where(
          (signal) =>
              signal.sourceType == 'one_tap' &&
              classifier.explicitEnergyLevel(signal) != null,
        )
        .toList()
      ..sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
    return candidates.isEmpty ? null : candidates.first;
  }

  static bool _isBurdenSignal(
    RecentSignalModel signal,
    EnergySignalState state,
  ) {
    // A low one-tap energy check-in describes capacity, not its cause.
    // It must not manufacture a burden Signal by itself.
    if (state == EnergySignalState.draining && signal.sourceType != 'one_tap') {
      return true;
    }
    if (state != EnergySignalState.steady) return false;
    final friction = (signal.friction ?? '').trim().toLowerCase();
    return friction.isNotEmpty &&
        !const {'unknown', 'none', 'neutral'}.contains(friction);
  }
}
