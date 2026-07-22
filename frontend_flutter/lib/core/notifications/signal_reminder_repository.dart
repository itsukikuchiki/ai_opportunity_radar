import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'schedule_notification_service.dart';
import 'signal_reminder_rule.dart';

enum SignalReminderSaveStatus {
  scheduled,
  disabled,
  permissionDenied,
  unavailable,
  schedulingFailed,
}

class SignalReminderSaveResult {
  final SignalReminderSaveStatus status;
  final SignalReminderRule rule;

  const SignalReminderSaveResult({required this.status, required this.rule});

  bool get scheduled => status == SignalReminderSaveStatus.scheduled;
}

/// Local-only persistence and platform scheduling for explicit Signal reminders.
///
/// [saveConfirmed] is the sole write API that can request notification
/// permission. Call it only after the user accepts or edits a reminder.
class SignalReminderRepository {
  static const preferencesKey = 'signal_reminder_rules_v1';
  static const _scheduledHorizonDays = 21;

  final SharedPreferences preferences;
  final SignalReminderScheduler scheduler;
  final DateTime Function() _clock;

  SignalReminderRepository({
    required this.preferences,
    SignalReminderScheduler? scheduler,
    DateTime Function()? clock,
  })  : scheduler = scheduler ?? ScheduleNotificationService(),
        _clock = clock ?? DateTime.now;

  Future<List<SignalReminderRule>> loadRules() async {
    final raw = preferences.getString(preferencesKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final rules = decoded
          .map(SignalReminderRule.tryParse)
          .whereType<SignalReminderRule>()
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return List.unmodifiable(rules);
    } catch (_) {
      return const [];
    }
  }

  Future<SignalReminderSaveResult> saveConfirmed(
    SignalReminderRule input,
  ) async {
    final now = _clock();
    final rule = input.copyWith(
      localeTag: input.localeTag ?? SignalReminderCopy.systemLocaleTag(),
      timeZoneName: now.timeZoneName,
      updatedAt: now,
    );

    if (!rule.enabled) {
      await _cancelRuleOccurrences(rule.id);
      await _upsert(rule);
      return SignalReminderSaveResult(
        status: SignalReminderSaveStatus.disabled,
        rule: rule,
      );
    }

    final permission = await scheduler.requestSignalReminderPermission();
    if (!permission.granted) {
      final disabled = rule.copyWith(enabled: false, updatedAt: now);
      await _cancelRuleOccurrences(rule.id);
      await _upsert(disabled);
      return SignalReminderSaveResult(
        status: switch (permission.status) {
          SignalReminderPermissionStatus.denied =>
            SignalReminderSaveStatus.permissionDenied,
          SignalReminderPermissionStatus.unavailable =>
            SignalReminderSaveStatus.unavailable,
          _ => SignalReminderSaveStatus.schedulingFailed,
        },
        rule: disabled,
      );
    }

    final scheduled = await _schedule(rule, now: now);
    if (!scheduled) {
      final disabled = rule.copyWith(enabled: false, updatedAt: now);
      await _upsert(disabled);
      return SignalReminderSaveResult(
        status: SignalReminderSaveStatus.schedulingFailed,
        rule: disabled,
      );
    }

    await _upsert(rule);
    return SignalReminderSaveResult(
      status: SignalReminderSaveStatus.scheduled,
      rule: rule,
    );
  }

  Future<void> disable(String ruleId) async {
    final rules = await loadRules();
    final rule = _findRule(rules, ruleId);
    if (rule == null) return;
    await _cancelRuleOccurrences(rule.id);
    await _upsert(rule.copyWith(enabled: false, updatedAt: _clock()));
  }

  Future<void> delete(String ruleId) async {
    final rules = await loadRules();
    await _cancelRuleOccurrences(ruleId);
    await _saveRules(rules.where((rule) => rule.id != ruleId));
  }

  /// Refreshes future local-clock instances after launch or a timezone change.
  /// This never asks notification permission.
  Future<void> rescheduleEnabledRules() async {
    final now = _clock();
    for (final rule in await loadRules()) {
      if (!rule.enabled) continue;
      await _schedule(rule.copyWith(timeZoneName: now.timeZoneName), now: now);
    }
  }

  Future<void> clearAll() async {
    await scheduler.cancelAllSignalReminders();
    await preferences.remove(preferencesKey);
  }

  Future<bool> _schedule(
    SignalReminderRule rule, {
    required DateTime now,
  }) async {
    await _cancelRuleOccurrences(rule.id);
    final occurrences = rule.upcomingOccurrences(
      now: now,
      horizonDays: _scheduledHorizonDays,
    );
    if (occurrences.isEmpty) return false;
    for (var index = 0; index < occurrences.length; index += 1) {
      final scheduled = await scheduler.scheduleSignalReminder(
        notificationId: _notificationId(rule.id, index),
        scheduledAt: occurrences[index],
        localeTag: rule.localeTag,
      );
      if (!scheduled) {
        await _cancelOccurrences(rule.id, occurrences.length);
        return false;
      }
    }
    return true;
  }

  Future<void> _cancelOccurrences(String ruleId, int count) async {
    for (var index = 0; index < count; index += 1) {
      await scheduler.cancelSignalReminder(_notificationId(ruleId, index));
    }
  }

  Future<void> _cancelRuleOccurrences(String ruleId) {
    return _cancelOccurrences(ruleId, _scheduledHorizonDays);
  }

  Future<void> _upsert(SignalReminderRule next) async {
    final current = await loadRules();
    final updated = [
      for (final rule in current)
        if (rule.id != next.id) rule,
      next,
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    await _saveRules(updated);
  }

  Future<void> _saveRules(Iterable<SignalReminderRule> rules) {
    return preferences.setString(
      preferencesKey,
      jsonEncode(rules.map((rule) => rule.toJson()).toList()),
    );
  }

  SignalReminderRule? _findRule(
    Iterable<SignalReminderRule> rules,
    String ruleId,
  ) {
    for (final rule in rules) {
      if (rule.id == ruleId) return rule;
    }
    return null;
  }

  String _notificationId(String ruleId, int index) => '$ruleId.$index';
}
