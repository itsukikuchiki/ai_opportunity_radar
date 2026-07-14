import 'package:flutter_test/flutter_test.dart';

import 'package:ai_opportunity_radar/core/api/repositories/advanced_energy_boundary_repository.dart';
import 'package:ai_opportunity_radar/core/api/repositories/health_recovery_signal_repository.dart';
import 'package:ai_opportunity_radar/core/models/advanced_energy_boundary_models.dart';
import 'package:ai_opportunity_radar/core/models/health_recovery_signal_models.dart';

void main() {
  group('HealthRecoverySignalRepository privacy-safe prototype', () {
    const repository = HealthRecoverySignalRepository();

    test('permission denied falls back to internal Energy Budget', () {
      final result = repository.evaluate(
        permissionStatus: ExternalEnergyPermissionStatus.denied,
        aggregate: null,
      );

      expect(result.status, 'healthkit_consent_denied_internal_only');
      expect(result.usesInternalEnergyBudgetFallback, isTrue);
      expect(result.permissionStatus, ExternalEnergyPermissionStatus.denied);
      expect(result.externalDataIsAuxiliary, isTrue);
      expect(result.canContributeToSignalLibrary, isFalse);
      expect(result.containsRawHealthData, isFalse);
    });

    test('permission not requested and unavailable keep internal fallback', () {
      final notRequested = repository.evaluate(
        permissionStatus: ExternalEnergyPermissionStatus.notRequested,
        aggregate: null,
      );
      final unavailable = repository.evaluate(
        permissionStatus: ExternalEnergyPermissionStatus.unavailable,
        aggregate: null,
      );

      expect(notRequested.status, 'permission_not_requested_internal_only');
      expect(unavailable.status, 'healthkit_unavailable_internal_only');
      expect(notRequested.usesInternalEnergyBudgetFallback, isTrue);
      expect(unavailable.usesInternalEnergyBudgetFallback, isTrue);
    });

    test('authorized with no health data uses internal fallback', () {
      final result = repository.evaluate(
        permissionStatus: ExternalEnergyPermissionStatus.authorized,
        aggregate: const HealthRecoveryAggregate(),
      );

      expect(result.status, 'no_health_data_internal_only');
      expect(result.usesInternalEnergyBudgetFallback, isTrue);
      expect(result.abstractHints, isEmpty);
    });

    test('authorized recovery data generates abstract hints only', () {
      final result = repository.evaluate(
        permissionStatus: ExternalEnergyPermissionStatus.authorized,
        aggregate: const HealthRecoveryAggregate(
          sleepRecoveryScore: 0.35,
          movementRecoveryScore: 0.4,
          workoutLoadScore: 0.82,
          recoveryScore: 0.32,
          daysCovered: 7,
        ),
      );

      expect(result.status, 'healthkit_recovery_signal_ready');
      expect(
          result.permissionStatus, ExternalEnergyPermissionStatus.authorized);
      expect(result.usesInternalEnergyBudgetFallback, isFalse);
      expect(result.abstractHints.keys, contains('sleep_recovery_hint'));
      expect(result.abstractHints.keys, contains('movement_recovery_hint'));
      expect(result.abstractHints.keys, contains('workout_load_hint'));
      expect(result.abstractHints.keys, contains('low_recovery_hint'));
      expect(result.abstractHints.keys, contains('recovery_gap_hint'));
      expect(result.containsRawHealthData, isFalse);
      expect(result.canShowRawHealthTimeline, isFalse);
      expect(result.canDiagnoseOrScoreHealth, isFalse);
    });

    test('stable recovery data generates stable recovery hint', () {
      final result = repository.evaluate(
        permissionStatus: ExternalEnergyPermissionStatus.authorized,
        aggregate: const HealthRecoveryAggregate(
          sleepRecoveryScore: 0.8,
          movementRecoveryScore: 0.75,
          workoutLoadScore: 0.2,
          recoveryScore: 0.82,
        ),
      );

      expect(result.abstractHints.keys, contains('stable_recovery_hint'));
      expect(result.abstractHints.keys, isNot(contains('low_recovery_hint')));
    });

    test('raw health samples and precise timeline are not downstream fields',
        () {
      final sanitized = repository.sanitizeLocalHealthPayload({
        'sleep_recovery_score': 0.3,
        'movement_recovery_score': 0.4,
        'workout_load_score': 0.6,
        'recovery_score': 0.35,
        'raw_sleep_samples': ['private sample'],
        'raw_heart_rate': [72, 88],
        'raw_workout_details': {'route': 'private route'},
        'precise_health_timeline': ['2026-05-30T01:00:00'],
      });

      expect(sanitized, isNotNull);
      expect(sanitized!.hasUsableSignal, isTrue);
      expect(repository.canPassDownstreamHealthField('raw_sleep_samples'),
          isFalse);
      expect(
          repository.canPassDownstreamHealthField('raw_heart_rate'), isFalse);
      expect(repository.canPassDownstreamHealthField('raw_workout_details'),
          isFalse);
      expect(repository.canPassDownstreamHealthField('precise_health_timeline'),
          isFalse);
      expect(repository.canPassDownstreamHealthField('sleep_recovery_hint'),
          isTrue);
    });

    test('HealthKit hint cannot enter Signal Library or override user evidence',
        () {
      final result = repository.evaluate(
        permissionStatus: ExternalEnergyPermissionStatus.authorized,
        aggregate: const HealthRecoveryAggregate(recoveryScore: 0.3),
      );

      expect(repository.canUseHealthHintsForSignalLibrary(), isFalse);
      expect(result.canContributeToSignalLibrary, isFalse);
      expect(result.canOverrideUserConfirmedSignalCards, isFalse);
      expect(result.externalDataIsAuxiliary, isTrue);
    });

    test('HealthKit read failure still allows internal Energy Budget boundary',
        () {
      const boundaryRepository = AdvancedEnergyBoundaryRepository();
      final health = repository.evaluate(
        permissionStatus: ExternalEnergyPermissionStatus.authorized,
        aggregate: const HealthRecoveryAggregate(recoveryScore: 0.4),
        readFailed: true,
      );
      final boundary = boundaryRepository.evaluate(
        consent: const AdvancedEnergyConsentState(
          calendar: ExternalEnergyPermissionStatus.notRequested,
          healthKit: ExternalEnergyPermissionStatus.authorized,
        ),
        externalSummary: health.toExternalSummary(),
      );

      expect(health.status, 'healthkit_read_failed_internal_only');
      expect(health.usesInternalEnergyBudgetFallback, isTrue);
      expect(boundary.basicAppAvailable, isTrue);
      expect(boundary.usesInternalSignalCards, isTrue);
      expect(boundary.abstractExternalMetadata, isEmpty);
    });
  });
}
