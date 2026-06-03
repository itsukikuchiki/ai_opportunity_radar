import 'advanced_energy_boundary_models.dart';

class HealthRecoveryAggregate {
  final double? sleepRecoveryScore;
  final double? movementRecoveryScore;
  final double? workoutLoadScore;
  final double? recoveryScore;
  final int daysCovered;

  const HealthRecoveryAggregate({
    this.sleepRecoveryScore,
    this.movementRecoveryScore,
    this.workoutLoadScore,
    this.recoveryScore,
    this.daysCovered = 0,
  });

  bool get hasUsableSignal =>
      _hasScore(sleepRecoveryScore) ||
      _hasScore(movementRecoveryScore) ||
      _hasScore(workoutLoadScore) ||
      _hasScore(recoveryScore);

  static bool _hasScore(double? value) => value != null && value >= 0;
}

class HealthRecoverySignalResult {
  final String status;
  final bool usesInternalEnergyBudgetFallback;
  final bool externalDataIsAuxiliary;
  final bool canContributeToSignalLibrary;
  final bool containsRawHealthData;
  final bool canOverrideUserConfirmedSignalCards;
  final bool canShowRawHealthTimeline;
  final bool canDiagnoseOrScoreHealth;
  final String fallbackMessage;
  final Map<String, String> abstractHints;

  const HealthRecoverySignalResult({
    required this.status,
    required this.usesInternalEnergyBudgetFallback,
    required this.externalDataIsAuxiliary,
    required this.canContributeToSignalLibrary,
    required this.containsRawHealthData,
    required this.canOverrideUserConfirmedSignalCards,
    required this.canShowRawHealthTimeline,
    required this.canDiagnoseOrScoreHealth,
    required this.fallbackMessage,
    required this.abstractHints,
  });

  AdvancedEnergyExternalSummary toExternalSummary() {
    return AdvancedEnergyExternalSummary(
      sleepRecoveryHint: abstractHints['sleep_recovery_hint'],
      movementRecoveryHint: abstractHints['movement_recovery_hint'],
      workoutLoadHint: abstractHints['workout_load_hint'],
      recoveryGapHint: abstractHints['recovery_gap_hint'],
      lowRecoveryHint: abstractHints['low_recovery_hint'],
      stableRecoveryHint: abstractHints['stable_recovery_hint'],
    );
  }
}
