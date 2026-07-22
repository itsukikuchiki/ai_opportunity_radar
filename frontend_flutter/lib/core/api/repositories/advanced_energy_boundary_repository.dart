import '../../models/advanced_energy_boundary_models.dart';

class AdvancedEnergyBoundaryRepository {
  const AdvancedEnergyBoundaryRepository();

  AdvancedEnergyBoundaryModel evaluate({
    required AdvancedEnergyConsentState consent,
    AdvancedEnergyExternalSummary? externalSummary,
  }) {
    final summary = externalSummary;
    final canUseExternal = consent.hasAuthorizedExternalSource &&
        summary != null &&
        summary.hasAnyHint;

    return AdvancedEnergyBoundaryModel(
      status: canUseExternal
          ? 'advanced_auxiliary_ready'
          : _fallbackStatus(consent),
      basicAppAvailable: true,
      usesInternalSignalCards: true,
      externalDataIsAuxiliary: true,
      canContributeToSignalLibrary: false,
      storesRawExternalData: false,
      fallbackMessage: canUseExternal
          ? 'Health recovery hints can add gentle context, while your Signal Cards stay at the center.'
          : _fallbackMessage(consent),
      abstractExternalMetadata:
          canUseExternal ? summary.toAbstractMetadata() : const {},
    );
  }

  bool canRequestLater(ExternalEnergyPermissionStatus status) {
    return status == ExternalEnergyPermissionStatus.notRequested ||
        status == ExternalEnergyPermissionStatus.denied ||
        status == ExternalEnergyPermissionStatus.revoked;
  }

  bool canReadRawExternalField(String fieldName) {
    final normalized = fieldName.trim().toLowerCase();
    const allowedAbstractHints = {
      'schedule_density_hint',
      'meeting_density_hint',
      'back_to_back_blocks_hint',
      'switching_hint',
      'missing_buffer_hint',
      'long_deep_block_hint',
      'sleep_recovery_hint',
      'movement_recovery_hint',
      'workout_load_hint',
      'low_recovery_hint',
      'stable_recovery_hint',
      'sleep_trend_hint',
      'steps_trend_hint',
      'workout_trend_hint',
      'recovery_trend_hint',
      'recovery_gap_hint',
    };
    return allowedAbstractHints.contains(normalized);
  }

  bool canUseExternalDataForSignalLibrary() => false;

  bool canExternalHintsOverrideUserConfirmedSignalCards() => false;

  String _fallbackStatus(AdvancedEnergyConsentState consent) {
    if (consent.calendar == ExternalEnergyPermissionStatus.unavailable ||
        consent.healthKit == ExternalEnergyPermissionStatus.unavailable) {
      return 'external_unavailable_internal_only';
    }
    if (consent.calendar == ExternalEnergyPermissionStatus.denied ||
        consent.healthKit == ExternalEnergyPermissionStatus.denied ||
        consent.calendar == ExternalEnergyPermissionStatus.revoked ||
        consent.healthKit == ExternalEnergyPermissionStatus.revoked) {
      return 'consent_denied_internal_only';
    }
    return 'permission_not_requested_internal_only';
  }

  String _fallbackMessage(AdvancedEnergyConsentState consent) {
    if (consent.calendar == ExternalEnergyPermissionStatus.unavailable ||
        consent.healthKit == ExternalEnergyPermissionStatus.unavailable) {
      return 'Health recovery hints are unavailable right now. Energy Budget can still use your internal Signal Card observations.';
    }
    if (consent.calendar == ExternalEnergyPermissionStatus.denied ||
        consent.healthKit == ExternalEnergyPermissionStatus.denied ||
        consent.calendar == ExternalEnergyPermissionStatus.revoked ||
        consent.healthKit == ExternalEnergyPermissionStatus.revoked) {
      return 'You can keep Health access off. Energy Budget still works from your own Signal Card observations.';
    }
    return 'Health access is optional. Energy Budget works from internal Signal Card observations first.';
  }
}
