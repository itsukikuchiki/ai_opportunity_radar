import 'advanced_energy_boundary_models.dart';

class CalendarScheduleBlock {
  final DateTime startAt;
  final DateTime endAt;
  final bool isBusy;

  const CalendarScheduleBlock({
    required this.startAt,
    required this.endAt,
    this.isBusy = true,
  });

  int get durationMinutes => endAt.difference(startAt).inMinutes;
}

class CalendarScheduleDensityResult {
  final String status;
  final bool usesInternalEnergyBudgetFallback;
  final bool externalDataIsAuxiliary;
  final bool canContributeToSignalLibrary;
  final bool containsRawCalendarData;
  final bool canOverrideUserConfirmedSignalCards;
  final bool canShowEventLevelBusyEvidence;
  final bool canOutputTimeSlotEvidence;
  final String fallbackMessage;
  final Map<String, String> abstractHints;

  const CalendarScheduleDensityResult({
    required this.status,
    required this.usesInternalEnergyBudgetFallback,
    required this.externalDataIsAuxiliary,
    required this.canContributeToSignalLibrary,
    required this.containsRawCalendarData,
    required this.canOverrideUserConfirmedSignalCards,
    required this.canShowEventLevelBusyEvidence,
    required this.canOutputTimeSlotEvidence,
    required this.fallbackMessage,
    required this.abstractHints,
  });

  AdvancedEnergyExternalSummary toExternalSummary() {
    return AdvancedEnergyExternalSummary(
      scheduleDensityHint: abstractHints['schedule_density_hint'],
      meetingDensityHint: abstractHints['meeting_density_hint'],
      backToBackBlocksHint: abstractHints['back_to_back_blocks_hint'],
      switchingHint: abstractHints['switching_hint'],
      missingBufferHint: abstractHints['missing_buffer_hint'],
      longDeepBlockHint: abstractHints['long_deep_block_hint'],
      recoveryGapHint: abstractHints['recovery_gap_hint'],
    );
  }
}
