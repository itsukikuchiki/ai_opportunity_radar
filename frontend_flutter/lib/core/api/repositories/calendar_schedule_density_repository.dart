import '../../models/advanced_energy_boundary_models.dart';
import '../../models/calendar_schedule_density_models.dart';

class CalendarScheduleDensityRepository {
  const CalendarScheduleDensityRepository();

  CalendarScheduleDensityResult evaluate({
    required ExternalEnergyPermissionStatus permissionStatus,
    required List<CalendarScheduleBlock> blocks,
    bool readFailed = false,
  }) {
    if (permissionStatus != ExternalEnergyPermissionStatus.authorized) {
      return _fallback(_statusForPermission(permissionStatus));
    }
    if (readFailed) {
      return _fallback('calendar_read_failed_internal_only');
    }

    final busyBlocks = blocks
        .where((block) => block.isBusy && block.durationMinutes > 0)
        .toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));

    if (busyBlocks.isEmpty) {
      return _fallback('no_calendar_data_internal_only');
    }

    final hints = _buildHints(busyBlocks);
    return CalendarScheduleDensityResult(
      status: 'calendar_schedule_density_ready',
      usesInternalEnergyBudgetFallback: false,
      externalDataIsAuxiliary: true,
      canContributeToSignalLibrary: false,
      containsRawCalendarData: false,
      canOverrideUserConfirmedSignalCards: false,
      canShowEventLevelBusyEvidence: false,
      canOutputTimeSlotEvidence: false,
      fallbackMessage:
          'Calendar hints are only gentle context. Your Signal Cards stay at the center.',
      abstractHints: hints,
    );
  }

  CalendarScheduleBlock? sanitizeLocalEventPayload(
    Map<String, Object?> payload,
  ) {
    final start = _parseDate(payload['start_at'] ?? payload['startAt']);
    final end = _parseDate(payload['end_at'] ?? payload['endAt']);
    if (start == null || end == null || !end.isAfter(start)) {
      return null;
    }
    return CalendarScheduleBlock(
      startAt: start,
      endAt: end,
      isBusy: payload['is_busy'] is bool ? payload['is_busy']! as bool : true,
    );
  }

  bool canUseCalendarHintsForSignalLibrary() => false;

  bool canShowEventLevelBusyEvidence() => false;

  bool canOutputTimeSlotEvidence() => false;

  bool canPassDownstreamCalendarField(String fieldName) {
    final normalized = fieldName.trim().toLowerCase();
    const allowed = {
      'meeting_density_hint',
      'schedule_density_hint',
      'back_to_back_blocks_hint',
      'switching_hint',
      'switching_load_hint',
      'missing_buffer_hint',
      'long_deep_block_hint',
      'recovery_gap_hint',
    };
    return allowed.contains(normalized);
  }

  Map<String, String> _buildHints(List<CalendarScheduleBlock> blocks) {
    final totalBusyMinutes = blocks.fold<int>(
      0,
      (total, block) => total + block.durationMinutes,
    );
    final backToBackCount = _backToBackCount(blocks);
    final shortGapCount = _shortGapCount(blocks);
    final longDeepBlock = blocks
        .where((block) => block.durationMinutes >= 90)
        .fold<int>(0, (max, block) {
      return block.durationMinutes > max ? block.durationMinutes : max;
    });

    return {
      'meeting_density_hint': _meetingDensity(blocks.length),
      'schedule_density_hint': _scheduleDensity(totalBusyMinutes),
      if (backToBackCount > 0)
        'back_to_back_blocks_hint':
            '$backToBackCount adjacent blocks may leave little room between plans.',
      if (blocks.length >= 3 || backToBackCount > 0)
        'switching_hint':
            'Several transitions may make this period feel a little dense.',
      if (shortGapCount > 0)
        'missing_buffer_hint':
            'There may be a spot where a small buffer would help.',
      if (longDeepBlock > 0)
        'long_deep_block_hint':
            'There is a longer block that may need protected attention.',
      if (shortGapCount > 0 || totalBusyMinutes >= 240)
        'recovery_gap_hint':
            'A recovery gap may be worth leaving somewhere near this stretch.',
    };
  }

  int _backToBackCount(List<CalendarScheduleBlock> blocks) {
    var count = 0;
    for (var i = 1; i < blocks.length; i += 1) {
      final gap = blocks[i].startAt.difference(blocks[i - 1].endAt).inMinutes;
      if (gap >= 0 && gap <= 5) count += 1;
    }
    return count;
  }

  int _shortGapCount(List<CalendarScheduleBlock> blocks) {
    var count = 0;
    for (var i = 1; i < blocks.length; i += 1) {
      final gap = blocks[i].startAt.difference(blocks[i - 1].endAt).inMinutes;
      if (gap >= 0 && gap < 15) count += 1;
    }
    return count;
  }

  String _meetingDensity(int count) {
    if (count >= 5) {
      return 'Meeting density looks high in this period.';
    }
    if (count >= 3) {
      return 'Meeting density looks moderate in this period.';
    }
    return 'Meeting density looks light in this period.';
  }

  String _scheduleDensity(int totalBusyMinutes) {
    if (totalBusyMinutes >= 300) {
      return 'This period may be fairly full.';
    }
    if (totalBusyMinutes >= 150) {
      return 'This period may be somewhat dense.';
    }
    return 'This period looks relatively open.';
  }

  String _statusForPermission(ExternalEnergyPermissionStatus status) {
    switch (status) {
      case ExternalEnergyPermissionStatus.notRequested:
        return 'permission_not_requested_internal_only';
      case ExternalEnergyPermissionStatus.denied:
      case ExternalEnergyPermissionStatus.revoked:
        return 'calendar_consent_denied_internal_only';
      case ExternalEnergyPermissionStatus.unavailable:
        return 'calendar_unavailable_internal_only';
      case ExternalEnergyPermissionStatus.authorized:
        return 'no_calendar_data_internal_only';
    }
  }

  CalendarScheduleDensityResult _fallback(String status) {
    return CalendarScheduleDensityResult(
      status: status,
      usesInternalEnergyBudgetFallback: true,
      externalDataIsAuxiliary: true,
      canContributeToSignalLibrary: false,
      containsRawCalendarData: false,
      canOverrideUserConfirmedSignalCards: false,
      canShowEventLevelBusyEvidence: false,
      canOutputTimeSlotEvidence: false,
      fallbackMessage:
          'Calendar access is optional. Energy Budget can keep using your internal Signal Card observations.',
      abstractHints: const {},
    );
  }

  DateTime? _parseDate(Object? value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
