import 'package:flutter_test/flutter_test.dart';

import 'package:ai_opportunity_radar/core/api/repositories/advanced_energy_boundary_repository.dart';
import 'package:ai_opportunity_radar/core/api/repositories/calendar_schedule_density_repository.dart';
import 'package:ai_opportunity_radar/core/models/advanced_energy_boundary_models.dart';
import 'package:ai_opportunity_radar/core/models/calendar_schedule_density_models.dart';

void main() {
  group('CalendarScheduleDensityRepository privacy-safe prototype', () {
    const repository = CalendarScheduleDensityRepository();

    test('permission denied falls back to internal Energy Budget', () {
      final result = repository.evaluate(
        permissionStatus: ExternalEnergyPermissionStatus.denied,
        blocks: const [],
      );

      expect(result.status, 'calendar_consent_denied_internal_only');
      expect(result.usesInternalEnergyBudgetFallback, isTrue);
      expect(result.externalDataIsAuxiliary, isTrue);
      expect(result.canContributeToSignalLibrary, isFalse);
      expect(result.containsRawCalendarData, isFalse);
    });

    test('permission not requested and unavailable keep internal fallback', () {
      final notRequested = repository.evaluate(
        permissionStatus: ExternalEnergyPermissionStatus.notRequested,
        blocks: const [],
      );
      final unavailable = repository.evaluate(
        permissionStatus: ExternalEnergyPermissionStatus.unavailable,
        blocks: const [],
      );

      expect(notRequested.status, 'permission_not_requested_internal_only');
      expect(unavailable.status, 'calendar_unavailable_internal_only');
      expect(notRequested.usesInternalEnergyBudgetFallback, isTrue);
      expect(unavailable.usesInternalEnergyBudgetFallback, isTrue);
    });

    test('authorized with no calendar data uses internal fallback', () {
      final result = repository.evaluate(
        permissionStatus: ExternalEnergyPermissionStatus.authorized,
        blocks: const [],
      );

      expect(result.status, 'no_calendar_data_internal_only');
      expect(result.usesInternalEnergyBudgetFallback, isTrue);
      expect(result.abstractHints, isEmpty);
    });

    test('authorized schedule density generates abstract hints only', () {
      final day = DateTime(2026, 5, 30);
      final result = repository.evaluate(
        permissionStatus: ExternalEnergyPermissionStatus.authorized,
        blocks: [
          CalendarScheduleBlock(
            startAt: day.add(const Duration(hours: 9)),
            endAt: day.add(const Duration(hours: 10)),
          ),
          CalendarScheduleBlock(
            startAt: day.add(const Duration(hours: 10)),
            endAt: day.add(const Duration(hours: 11)),
          ),
          CalendarScheduleBlock(
            startAt: day.add(const Duration(hours: 11, minutes: 10)),
            endAt: day.add(const Duration(hours: 12)),
          ),
          CalendarScheduleBlock(
            startAt: day.add(const Duration(hours: 14)),
            endAt: day.add(const Duration(hours: 16)),
          ),
        ],
      );

      expect(result.status, 'calendar_schedule_density_ready');
      expect(result.usesInternalEnergyBudgetFallback, isFalse);
      expect(result.abstractHints.keys, contains('meeting_density_hint'));
      expect(result.abstractHints.keys, contains('schedule_density_hint'));
      expect(result.abstractHints.keys, contains('back_to_back_blocks_hint'));
      expect(result.abstractHints.keys, contains('switching_hint'));
      expect(result.abstractHints.keys, contains('missing_buffer_hint'));
      expect(result.abstractHints.keys, contains('long_deep_block_hint'));
      expect(result.abstractHints.keys, contains('recovery_gap_hint'));
      expect(result.containsRawCalendarData, isFalse);
    });

    test('raw title location attendees and notes are not downstream fields',
        () {
      final sanitized = repository.sanitizeLocalEventPayload({
        'start_at': '2026-05-30T09:00:00',
        'end_at': '2026-05-30T10:00:00',
        'title': 'Sensitive project meeting',
        'location': 'Private office',
        'attendees': ['person@example.com'],
        'notes': 'Private context',
        'description': 'More private context',
      });

      expect(sanitized, isNotNull);
      expect(sanitized!.durationMinutes, 60);
      expect(repository.canPassDownstreamCalendarField('title'), isFalse);
      expect(repository.canPassDownstreamCalendarField('location'), isFalse);
      expect(repository.canPassDownstreamCalendarField('attendees'), isFalse);
      expect(repository.canPassDownstreamCalendarField('notes'), isFalse);
      expect(repository.canPassDownstreamCalendarField('description'), isFalse);
      expect(repository.canPassDownstreamCalendarField('schedule_density_hint'),
          isTrue);
    });

    test('Calendar hint cannot enter Signal Library or override user evidence',
        () {
      final result = repository.evaluate(
        permissionStatus: ExternalEnergyPermissionStatus.authorized,
        blocks: [
          CalendarScheduleBlock(
            startAt: DateTime(2026, 5, 30, 9),
            endAt: DateTime(2026, 5, 30, 10),
          ),
        ],
      );

      expect(repository.canUseCalendarHintsForSignalLibrary(), isFalse);
      expect(result.canContributeToSignalLibrary, isFalse);
      expect(result.canOverrideUserConfirmedSignalCards, isFalse);
      expect(result.canShowEventLevelBusyEvidence, isFalse);
      expect(result.canOutputTimeSlotEvidence, isFalse);
      expect(result.externalDataIsAuxiliary, isTrue);
    });

    test('isBusy is only used for aggregate density calculation', () {
      final result = repository.evaluate(
        permissionStatus: ExternalEnergyPermissionStatus.authorized,
        blocks: [
          CalendarScheduleBlock(
            startAt: DateTime(2026, 5, 30, 9),
            endAt: DateTime(2026, 5, 30, 10),
            isBusy: true,
          ),
          CalendarScheduleBlock(
            startAt: DateTime(2026, 5, 30, 10),
            endAt: DateTime(2026, 5, 30, 11),
            isBusy: false,
          ),
        ],
      );

      expect(result.abstractHints.keys, contains('meeting_density_hint'));
      expect(result.abstractHints.keys, isNot(contains('busy_evidence')));
      expect(repository.canShowEventLevelBusyEvidence(), isFalse);
      expect(repository.canOutputTimeSlotEvidence(), isFalse);
    });

    test('Calendar read failure still allows internal Energy Budget boundary',
        () {
      const boundaryRepository = AdvancedEnergyBoundaryRepository();
      final calendar = repository.evaluate(
        permissionStatus: ExternalEnergyPermissionStatus.authorized,
        blocks: const [],
        readFailed: true,
      );
      final boundary = boundaryRepository.evaluate(
        consent: const AdvancedEnergyConsentState(
          calendar: ExternalEnergyPermissionStatus.authorized,
          healthKit: ExternalEnergyPermissionStatus.notRequested,
        ),
        externalSummary: calendar.toExternalSummary(),
      );

      expect(calendar.status, 'calendar_read_failed_internal_only');
      expect(calendar.usesInternalEnergyBudgetFallback, isTrue);
      expect(boundary.basicAppAvailable, isTrue);
      expect(boundary.usesInternalSignalCards, isTrue);
      expect(boundary.abstractExternalMetadata, isEmpty);
    });
  });
}
