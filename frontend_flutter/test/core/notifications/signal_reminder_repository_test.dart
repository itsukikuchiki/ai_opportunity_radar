import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_opportunity_radar/core/notifications/schedule_notification_service.dart';
import 'package:ai_opportunity_radar/core/notifications/signal_reminder_repository.dart';
import 'package:ai_opportunity_radar/core/notifications/signal_reminder_rule.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
      'confirmed weekly reminder requests permission then schedules local days',
      () async {
    final scheduler = _FakeScheduler();
    final prefs = await SharedPreferences.getInstance();
    final repository = SignalReminderRepository(
      preferences: prefs,
      scheduler: scheduler,
      clock: () => DateTime(2026, 7, 6, 9),
    );
    final rule = SignalReminderRule.weekly(
      id: 'signal-reminder.weekly',
      weekdays: {DateTime.monday, DateTime.wednesday},
      hour: 9,
      minute: 30,
      localeTag: 'zh-Hant-TW',
      now: DateTime(2026, 7, 1),
    );

    final result = await repository.saveConfirmed(rule);

    expect(result.status, SignalReminderSaveStatus.scheduled);
    expect(scheduler.permissionRequests, 1);
    expect(scheduler.scheduled.map((entry) => entry.at),
        contains(DateTime(2026, 7, 6, 9, 30)));
    expect(scheduler.scheduled.every((entry) => entry.id.startsWith(rule.id)),
        isTrue);
    expect(
      scheduler.scheduled.every((entry) => entry.localeTag == 'zh-Hant-TW'),
      isTrue,
    );
    final saved = (await repository.loadRules()).single;
    expect(saved.enabled, isTrue);
    expect(saved.localeTag, 'zh-Hant-TW');
  });

  test('denied permission persists a disabled rule and leaves no reminder',
      () async {
    final scheduler = _FakeScheduler(
      permission: const SignalReminderPermissionResult(
        SignalReminderPermissionStatus.denied,
      ),
    );
    final prefs = await SharedPreferences.getInstance();
    final repository = SignalReminderRepository(
      preferences: prefs,
      scheduler: scheduler,
      clock: () => DateTime(2026, 7, 6, 9),
    );
    final rule = SignalReminderRule.once(
      id: 'signal-reminder.denied',
      localDate: DateTime(2026, 7, 7),
      hour: 9,
      minute: 30,
      now: DateTime(2026, 7, 1),
    );

    final result = await repository.saveConfirmed(rule);

    expect(result.status, SignalReminderSaveStatus.permissionDenied);
    expect(result.rule.enabled, isFalse);
    expect(scheduler.scheduled, isEmpty);
    expect((await repository.loadRules()).single.enabled, isFalse);
  });

  test('disable and delete cancel all materialised instances', () async {
    final scheduler = _FakeScheduler();
    final prefs = await SharedPreferences.getInstance();
    final repository = SignalReminderRepository(
      preferences: prefs,
      scheduler: scheduler,
      clock: () => DateTime(2026, 7, 6, 9),
    );
    final rule = SignalReminderRule.weekly(
      id: 'signal-reminder.cancel',
      weekdays: {DateTime.monday},
      hour: 10,
      minute: 0,
      now: DateTime(2026, 7, 1),
    );
    await repository.saveConfirmed(rule);

    await repository.disable(rule.id);
    expect((await repository.loadRules()).single.enabled, isFalse);
    expect(scheduler.cancelled, contains('${rule.id}.0'));

    await repository.delete(rule.id);
    expect(await repository.loadRules(), isEmpty);
  });

  test('launch rescheduling never asks notification permission', () async {
    final scheduler = _FakeScheduler();
    final prefs = await SharedPreferences.getInstance();
    final rule = SignalReminderRule.weekly(
      id: 'signal-reminder.rehydrate',
      weekdays: {DateTime.tuesday},
      hour: 8,
      minute: 0,
      now: DateTime(2026, 7, 1),
    );
    await prefs.setString(
      SignalReminderRepository.preferencesKey,
      '[${rule.encode()}]',
    );
    final repository = SignalReminderRepository(
      preferences: prefs,
      scheduler: scheduler,
      clock: () => DateTime(2026, 7, 6, 9),
    );

    await repository.rescheduleEnabledRules();

    expect(scheduler.permissionRequests, 0);
    expect(scheduler.scheduled, isNotEmpty);
  });
}

class _FakeScheduler implements SignalReminderScheduler {
  final SignalReminderPermissionResult permission;
  int permissionRequests = 0;
  final scheduled = <_Scheduled>[];
  final cancelled = <String>[];

  _FakeScheduler({
    this.permission = const SignalReminderPermissionResult(
      SignalReminderPermissionStatus.granted,
    ),
  });

  @override
  Future<bool> cancelAllSignalReminders() async => true;

  @override
  Future<bool> cancelSignalReminder(String notificationId) async {
    cancelled.add(notificationId);
    return true;
  }

  @override
  Future<SignalReminderPermissionResult>
      requestSignalReminderPermission() async {
    permissionRequests += 1;
    return permission;
  }

  @override
  Future<bool> scheduleSignalReminder({
    required String notificationId,
    required DateTime scheduledAt,
    String? localeTag,
  }) async {
    scheduled.add(_Scheduled(notificationId, scheduledAt, localeTag));
    return true;
  }
}

class _Scheduled {
  final String id;
  final DateTime at;
  final String? localeTag;

  const _Scheduled(this.id, this.at, this.localeTag);
}
