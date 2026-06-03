import 'package:flutter_test/flutter_test.dart';

import 'package:ai_opportunity_radar/core/api/repositories/advanced_energy_boundary_repository.dart';
import 'package:ai_opportunity_radar/core/models/advanced_energy_boundary_models.dart';

void main() {
  group('AdvancedEnergyBoundaryRepository consent and privacy rules', () {
    const repository = AdvancedEnergyBoundaryRepository();

    test('permission not requested keeps basic app and internal Energy Budget',
        () {
      final boundary = repository.evaluate(
        consent: const AdvancedEnergyConsentState.notRequested(),
      );

      expect(boundary.status, 'permission_not_requested_internal_only');
      expect(boundary.basicAppAvailable, isTrue);
      expect(boundary.usesInternalSignalCards, isTrue);
      expect(boundary.externalDataIsAuxiliary, isTrue);
      expect(boundary.canContributeToSignalLibrary, isFalse);
      expect(boundary.storesRawExternalData, isFalse);
      expect(boundary.fallbackMessage, contains('optional'));
    });

    test('consent denied falls back without reducing Today Weekly Journey', () {
      final boundary = repository.evaluate(
        consent: const AdvancedEnergyConsentState(
          calendar: ExternalEnergyPermissionStatus.denied,
          healthKit: ExternalEnergyPermissionStatus.denied,
        ),
      );

      expect(boundary.status, 'consent_denied_internal_only');
      expect(boundary.basicAppAvailable, isTrue);
      expect(boundary.usesInternalSignalCards, isTrue);
      expect(boundary.fallbackMessage, contains('still works'));
      expect(repository.canRequestLater(ExternalEnergyPermissionStatus.denied),
          isTrue);
    });

    test('external data unavailable falls back to SignalCard evidence', () {
      final boundary = repository.evaluate(
        consent: const AdvancedEnergyConsentState(
          calendar: ExternalEnergyPermissionStatus.unavailable,
          healthKit: ExternalEnergyPermissionStatus.authorized,
        ),
      );

      expect(boundary.status, 'external_unavailable_internal_only');
      expect(boundary.basicAppAvailable, isTrue);
      expect(boundary.usesInternalSignalCards, isTrue);
      expect(boundary.abstractExternalMetadata, isEmpty);
    });

    test('authorized external data is abstract auxiliary metadata only', () {
      final boundary = repository.evaluate(
        consent: const AdvancedEnergyConsentState(
          calendar: ExternalEnergyPermissionStatus.authorized,
          healthKit: ExternalEnergyPermissionStatus.authorized,
        ),
        externalSummary: const AdvancedEnergyExternalSummary(
          scheduleDensityHint: 'dense afternoon',
          meetingDensityHint: 'many adjacent blocks',
          switchingHint: 'frequent transitions',
          sleepTrendHint: 'lighter sleep trend',
          stepsTrendHint: 'lower movement trend',
          recoveryTrendHint: 'recovery may need more buffer',
        ),
      );

      expect(boundary.status, 'advanced_auxiliary_ready');
      expect(boundary.externalDataIsAuxiliary, isTrue);
      expect(boundary.usesInternalSignalCards, isTrue);
      expect(boundary.storesRawExternalData, isFalse);
      expect(repository.canExternalHintsOverrideUserConfirmedSignalCards(),
          isFalse);
      expect(
          boundary.abstractExternalMetadata.keys,
          containsAll([
            'schedule_density_hint',
            'meeting_density_hint',
            'switching_hint',
            'sleep_trend_hint',
            'steps_trend_hint',
            'recovery_trend_hint',
          ]));
      expect(boundary.abstractExternalMetadata.keys,
          isNot(contains('event_title')));
      expect(
          boundary.abstractExternalMetadata.keys, isNot(contains('location')));
    });

    test('raw Calendar and HealthKit fields are not allowed downstream', () {
      expect(repository.canReadRawExternalField('event_title'), isFalse);
      expect(repository.canReadRawExternalField('event_notes'), isFalse);
      expect(repository.canReadRawExternalField('location'), isFalse);
      expect(repository.canReadRawExternalField('attendees'), isFalse);
      expect(repository.canReadRawExternalField('raw_sleep_sample'), isFalse);
      expect(repository.canReadRawExternalField('heart_rate_sample'), isFalse);
      expect(repository.canReadRawExternalField('unknown_external_field'),
          isFalse);
      expect(
          repository.canReadRawExternalField('schedule_density_hint'), isTrue);
      expect(repository.canReadRawExternalField('recovery_trend_hint'), isTrue);
      expect(repository.canUseExternalDataForSignalLibrary(), isFalse);
    });
  });
}
