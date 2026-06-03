enum ExternalEnergyPermissionStatus {
  notRequested,
  denied,
  authorized,
  revoked,
  unavailable,
}

enum ExternalEnergySource {
  calendar,
  healthKit,
}

class AdvancedEnergyConsentState {
  final ExternalEnergyPermissionStatus calendar;
  final ExternalEnergyPermissionStatus healthKit;

  const AdvancedEnergyConsentState({
    required this.calendar,
    required this.healthKit,
  });

  const AdvancedEnergyConsentState.notRequested()
      : calendar = ExternalEnergyPermissionStatus.notRequested,
        healthKit = ExternalEnergyPermissionStatus.notRequested;

  bool get hasAuthorizedExternalSource =>
      calendar == ExternalEnergyPermissionStatus.authorized ||
      healthKit == ExternalEnergyPermissionStatus.authorized;

  bool get appCanRunWithoutExternalConsent => true;
}

class AdvancedEnergyExternalSummary {
  final String? scheduleDensityHint;
  final String? meetingDensityHint;
  final String? backToBackBlocksHint;
  final String? switchingHint;
  final String? missingBufferHint;
  final String? longDeepBlockHint;
  final String? sleepRecoveryHint;
  final String? movementRecoveryHint;
  final String? workoutLoadHint;
  final String? lowRecoveryHint;
  final String? stableRecoveryHint;
  final String? sleepTrendHint;
  final String? stepsTrendHint;
  final String? workoutTrendHint;
  final String? recoveryTrendHint;
  final String? recoveryGapHint;

  const AdvancedEnergyExternalSummary({
    this.scheduleDensityHint,
    this.meetingDensityHint,
    this.backToBackBlocksHint,
    this.switchingHint,
    this.missingBufferHint,
    this.longDeepBlockHint,
    this.sleepRecoveryHint,
    this.movementRecoveryHint,
    this.workoutLoadHint,
    this.lowRecoveryHint,
    this.stableRecoveryHint,
    this.sleepTrendHint,
    this.stepsTrendHint,
    this.workoutTrendHint,
    this.recoveryTrendHint,
    this.recoveryGapHint,
  });

  bool get hasAnyHint =>
      _hasText(scheduleDensityHint) ||
      _hasText(meetingDensityHint) ||
      _hasText(backToBackBlocksHint) ||
      _hasText(switchingHint) ||
      _hasText(missingBufferHint) ||
      _hasText(longDeepBlockHint) ||
      _hasText(sleepRecoveryHint) ||
      _hasText(movementRecoveryHint) ||
      _hasText(workoutLoadHint) ||
      _hasText(lowRecoveryHint) ||
      _hasText(stableRecoveryHint) ||
      _hasText(sleepTrendHint) ||
      _hasText(stepsTrendHint) ||
      _hasText(workoutTrendHint) ||
      _hasText(recoveryTrendHint) ||
      _hasText(recoveryGapHint);

  Map<String, String> toAbstractMetadata() {
    return {
      if (_hasText(scheduleDensityHint))
        'schedule_density_hint': scheduleDensityHint!.trim(),
      if (_hasText(meetingDensityHint))
        'meeting_density_hint': meetingDensityHint!.trim(),
      if (_hasText(backToBackBlocksHint))
        'back_to_back_blocks_hint': backToBackBlocksHint!.trim(),
      if (_hasText(switchingHint)) 'switching_hint': switchingHint!.trim(),
      if (_hasText(missingBufferHint))
        'missing_buffer_hint': missingBufferHint!.trim(),
      if (_hasText(longDeepBlockHint))
        'long_deep_block_hint': longDeepBlockHint!.trim(),
      if (_hasText(sleepRecoveryHint))
        'sleep_recovery_hint': sleepRecoveryHint!.trim(),
      if (_hasText(movementRecoveryHint))
        'movement_recovery_hint': movementRecoveryHint!.trim(),
      if (_hasText(workoutLoadHint))
        'workout_load_hint': workoutLoadHint!.trim(),
      if (_hasText(lowRecoveryHint))
        'low_recovery_hint': lowRecoveryHint!.trim(),
      if (_hasText(stableRecoveryHint))
        'stable_recovery_hint': stableRecoveryHint!.trim(),
      if (_hasText(sleepTrendHint)) 'sleep_trend_hint': sleepTrendHint!.trim(),
      if (_hasText(stepsTrendHint)) 'steps_trend_hint': stepsTrendHint!.trim(),
      if (_hasText(workoutTrendHint))
        'workout_trend_hint': workoutTrendHint!.trim(),
      if (_hasText(recoveryTrendHint))
        'recovery_trend_hint': recoveryTrendHint!.trim(),
      if (_hasText(recoveryGapHint))
        'recovery_gap_hint': recoveryGapHint!.trim(),
    };
  }

  static bool _hasText(String? value) =>
      value != null && value.trim().isNotEmpty;
}

class AdvancedEnergyBoundaryModel {
  final String status;
  final bool basicAppAvailable;
  final bool usesInternalSignalCards;
  final bool externalDataIsAuxiliary;
  final bool canContributeToSignalLibrary;
  final bool storesRawExternalData;
  final String fallbackMessage;
  final Map<String, String> abstractExternalMetadata;

  const AdvancedEnergyBoundaryModel({
    required this.status,
    required this.basicAppAvailable,
    required this.usesInternalSignalCards,
    required this.externalDataIsAuxiliary,
    required this.canContributeToSignalLibrary,
    required this.storesRawExternalData,
    required this.fallbackMessage,
    required this.abstractExternalMetadata,
  });
}
