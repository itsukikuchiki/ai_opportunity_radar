import 'package:flutter/services.dart';

import '../api/repositories/calendar_schedule_density_repository.dart';
import '../api/repositories/health_recovery_signal_repository.dart';
import '../models/advanced_energy_boundary_models.dart';
import '../models/calendar_schedule_density_models.dart';
import '../models/health_recovery_signal_models.dart';

class ExternalEnergyPlatformService {
  static const MethodChannel _channel =
      MethodChannel('signalpath/external_energy');

  final CalendarScheduleDensityRepository calendarRepository;
  final HealthRecoverySignalRepository healthRepository;

  const ExternalEnergyPlatformService({
    this.calendarRepository = const CalendarScheduleDensityRepository(),
    this.healthRepository = const HealthRecoverySignalRepository(),
  });

  Future<ExternalEnergyPermissionStatus> calendarPermissionStatus() async {
    try {
      return _statusFromString(
        await _channel.invokeMethod<String>('calendarPermissionStatus'),
      );
    } catch (_) {
      return ExternalEnergyPermissionStatus.unavailable;
    }
  }

  Future<ExternalEnergyPermissionStatus> healthPermissionStatus() async {
    try {
      return _statusFromString(
        await _channel.invokeMethod<String>('healthPermissionStatus'),
      );
    } catch (_) {
      return ExternalEnergyPermissionStatus.unavailable;
    }
  }

  Future<CalendarScheduleDensityResult> requestCalendarHints() async {
    // Calendar remains a future Target. This release deliberately never calls
    // the native EventKit bridge, so navigation and background refresh cannot
    // present a Calendar permission sheet.
    return calendarRepository.evaluate(
      permissionStatus: ExternalEnergyPermissionStatus.notRequested,
      blocks: const [],
      readFailed: false,
    );
  }

  Future<HealthRecoverySignalResult> requestHealthHints() async {
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'requestHealthRecoveryHints',
      );
      final map = _stringMap(raw);
      final status = _statusFromString(map['permission_status']?.toString());
      final aggregate = healthRepository.sanitizeLocalHealthPayload(
        map.cast<String, Object?>(),
      );
      return healthRepository.evaluate(
        permissionStatus: status,
        aggregate: aggregate,
        readFailed: map['read_failed'] == true,
      );
    } catch (_) {
      return healthRepository.evaluate(
        permissionStatus: ExternalEnergyPermissionStatus.unavailable,
        aggregate: null,
        readFailed: true,
      );
    }
  }

  Map<String, Object?> _stringMap(Map<dynamic, dynamic>? raw) {
    if (raw == null) return const {};
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }

  ExternalEnergyPermissionStatus _statusFromString(String? value) {
    switch (value) {
      case 'authorized':
        return ExternalEnergyPermissionStatus.authorized;
      case 'denied':
        return ExternalEnergyPermissionStatus.denied;
      case 'revoked':
        return ExternalEnergyPermissionStatus.revoked;
      case 'unavailable':
        return ExternalEnergyPermissionStatus.unavailable;
      case 'not_requested':
      default:
        return ExternalEnergyPermissionStatus.notRequested;
    }
  }
}
