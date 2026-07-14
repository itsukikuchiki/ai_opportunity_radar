import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/advanced_energy_boundary_models.dart';
import '../state/app_data_refresh_coordinator.dart';

class ExternalEnergyHintStore {
  static const _calendarHintsKey = 'external_calendar_abstract_hints_json';
  static const _healthHintsKey = 'external_health_abstract_hints_json';

  final SharedPreferences prefs;

  const ExternalEnergyHintStore(this.prefs);

  Future<void> saveCalendarHints(Map<String, String> hints) async {
    await _save(_calendarHintsKey, _sanitize(hints, _calendarAllowed));
    AppDataMutationBus.publish(
      kind: AppDataMutationKind.externalEnergyHints,
      reason: 'calendar_energy_hints_changed',
    );
  }

  Future<void> saveHealthHints(Map<String, String> hints) async {
    await _save(_healthHintsKey, _sanitize(hints, _healthAllowed));
    AppDataMutationBus.publish(
      kind: AppDataMutationKind.externalEnergyHints,
      reason: 'health_energy_hints_changed',
    );
  }

  Future<void> clearHealthHints() async {
    await prefs.remove(_healthHintsKey);
    AppDataMutationBus.publish(
      kind: AppDataMutationKind.externalEnergyHints,
      reason: 'health_energy_hints_cleared',
    );
  }

  AdvancedEnergyExternalSummary loadSummary() {
    final hints = <String, String>{
      ..._load(_calendarHintsKey, _calendarAllowed),
      ..._load(_healthHintsKey, _healthAllowed),
    };
    return AdvancedEnergyExternalSummary(
      scheduleDensityHint: hints['schedule_density_hint'],
      meetingDensityHint: hints['meeting_density_hint'],
      backToBackBlocksHint: hints['back_to_back_blocks_hint'],
      switchingHint: hints['switching_hint'],
      missingBufferHint: hints['missing_buffer_hint'],
      longDeepBlockHint: hints['long_deep_block_hint'],
      sleepRecoveryHint: hints['sleep_recovery_hint'],
      movementRecoveryHint: hints['movement_recovery_hint'],
      workoutLoadHint: hints['workout_load_hint'],
      recoveryGapHint: hints['recovery_gap_hint'],
      lowRecoveryHint: hints['low_recovery_hint'],
      stableRecoveryHint: hints['stable_recovery_hint'],
    );
  }

  /// Current Energy Budget planning consumes Health abstractions only.
  ///
  /// Calendar support remains persisted for a future Target, but exposing a
  /// dedicated reader prevents those hints from silently entering today's
  /// planning snapshot or its invalidation fingerprint.
  AdvancedEnergyExternalSummary loadHealthSummary() {
    final hints = _load(_healthHintsKey, _healthAllowed);
    return AdvancedEnergyExternalSummary(
      sleepRecoveryHint: hints['sleep_recovery_hint'],
      movementRecoveryHint: hints['movement_recovery_hint'],
      workoutLoadHint: hints['workout_load_hint'],
      recoveryGapHint: hints['recovery_gap_hint'],
      lowRecoveryHint: hints['low_recovery_hint'],
      stableRecoveryHint: hints['stable_recovery_hint'],
    );
  }

  Future<void> _save(String key, Map<String, String> hints) async {
    await prefs.setString(key, jsonEncode(hints));
  }

  Map<String, String> _load(String key, Set<String> allowed) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      return _sanitize(
        decoded.map((key, value) => MapEntry(key.toString(), value.toString())),
        allowed,
      );
    } catch (_) {
      return const {};
    }
  }

  Map<String, String> _sanitize(
    Map<String, String> hints,
    Set<String> allowed,
  ) {
    return {
      for (final entry in hints.entries)
        if (allowed.contains(entry.key) && entry.value.trim().isNotEmpty)
          entry.key: entry.value.trim(),
    };
  }

  static const _calendarAllowed = {
    'meeting_density_hint',
    'schedule_density_hint',
    'back_to_back_blocks_hint',
    'switching_hint',
    'missing_buffer_hint',
    'long_deep_block_hint',
    'recovery_gap_hint',
  };

  static const _healthAllowed = {
    'sleep_recovery_hint',
    'movement_recovery_hint',
    'workout_load_hint',
    'recovery_gap_hint',
    'low_recovery_hint',
    'stable_recovery_hint',
  };
}
