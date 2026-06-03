import '../../models/advanced_energy_boundary_models.dart';
import '../../models/health_recovery_signal_models.dart';

class HealthRecoverySignalRepository {
  const HealthRecoverySignalRepository();

  HealthRecoverySignalResult evaluate({
    required ExternalEnergyPermissionStatus permissionStatus,
    required HealthRecoveryAggregate? aggregate,
    bool readFailed = false,
  }) {
    if (permissionStatus != ExternalEnergyPermissionStatus.authorized) {
      return _fallback(_statusForPermission(permissionStatus));
    }
    if (readFailed) {
      return _fallback('healthkit_read_failed_internal_only');
    }
    if (aggregate == null || !aggregate.hasUsableSignal) {
      return _fallback('no_health_data_internal_only');
    }

    final hints = _buildHints(aggregate);
    return HealthRecoverySignalResult(
      status: 'healthkit_recovery_signal_ready',
      usesInternalEnergyBudgetFallback: false,
      externalDataIsAuxiliary: true,
      canContributeToSignalLibrary: false,
      containsRawHealthData: false,
      canOverrideUserConfirmedSignalCards: false,
      canShowRawHealthTimeline: false,
      canDiagnoseOrScoreHealth: false,
      fallbackMessage:
          'Health hints are only gentle recovery context. SignalCard remains the main evidence.',
      abstractHints: hints,
    );
  }

  HealthRecoveryAggregate? sanitizeLocalHealthPayload(
    Map<String, Object?> payload,
  ) {
    return HealthRecoveryAggregate(
      sleepRecoveryScore: _score(payload['sleep_recovery_score']),
      movementRecoveryScore: _score(payload['movement_recovery_score']),
      workoutLoadScore: _score(payload['workout_load_score']),
      recoveryScore: _score(payload['recovery_score']),
      daysCovered: _intValue(payload['days_covered']) ?? 0,
    );
  }

  bool canUseHealthHintsForSignalLibrary() => false;

  bool canPassDownstreamHealthField(String fieldName) {
    final normalized = fieldName.trim().toLowerCase();
    const allowed = {
      'sleep_recovery_hint',
      'movement_recovery_hint',
      'workout_load_hint',
      'recovery_gap_hint',
      'low_recovery_hint',
      'stable_recovery_hint',
    };
    return allowed.contains(normalized);
  }

  bool canShowRawHealthTimeline() => false;

  bool canDiagnoseOrScoreHealth() => false;

  Map<String, String> _buildHints(HealthRecoveryAggregate aggregate) {
    final hints = <String, String>{};

    final sleep = aggregate.sleepRecoveryScore;
    if (sleep != null) {
      hints['sleep_recovery_hint'] = sleep < 0.45
          ? 'Sleep recovery signals may be a little light.'
          : 'Sleep recovery signals look relatively steady.';
    }

    final movement = aggregate.movementRecoveryScore;
    if (movement != null) {
      hints['movement_recovery_hint'] = movement < 0.45
          ? 'Movement recovery signals may be quieter in this period.'
          : 'Movement may be offering some recovery support.';
    }

    final workout = aggregate.workoutLoadScore;
    if (workout != null) {
      hints['workout_load_hint'] = workout > 0.7
          ? 'Workout load may ask for a little more recovery room.'
          : 'Workout load does not look like the main pressure signal.';
    }

    final recovery = aggregate.recoveryScore;
    if (recovery != null) {
      if (recovery < 0.45) {
        hints['low_recovery_hint'] =
            'Recovery signals may be a little weak in this stretch.';
        hints['recovery_gap_hint'] =
            'This period may be a good place to leave some recovery space.';
      } else {
        hints['stable_recovery_hint'] =
            'Recovery signals look relatively stable in this stretch.';
      }
    }

    return hints;
  }

  String _statusForPermission(ExternalEnergyPermissionStatus status) {
    switch (status) {
      case ExternalEnergyPermissionStatus.notRequested:
        return 'permission_not_requested_internal_only';
      case ExternalEnergyPermissionStatus.denied:
      case ExternalEnergyPermissionStatus.revoked:
        return 'healthkit_consent_denied_internal_only';
      case ExternalEnergyPermissionStatus.unavailable:
        return 'healthkit_unavailable_internal_only';
      case ExternalEnergyPermissionStatus.authorized:
        return 'no_health_data_internal_only';
    }
  }

  HealthRecoverySignalResult _fallback(String status) {
    return HealthRecoverySignalResult(
      status: status,
      usesInternalEnergyBudgetFallback: true,
      externalDataIsAuxiliary: true,
      canContributeToSignalLibrary: false,
      containsRawHealthData: false,
      canOverrideUserConfirmedSignalCards: false,
      canShowRawHealthTimeline: false,
      canDiagnoseOrScoreHealth: false,
      fallbackMessage:
          'Health access is optional. Energy Budget can keep using your internal SignalCard observations.',
      abstractHints: const {},
    );
  }

  double? _score(Object? value) {
    if (value is num) return value.toDouble().clamp(0.0, 1.0);
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed?.clamp(0.0, 1.0);
    }
    return null;
  }

  int? _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
