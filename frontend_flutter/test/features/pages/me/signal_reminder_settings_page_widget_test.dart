import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_opportunity_radar/core/notifications/schedule_notification_service.dart';
import 'package:ai_opportunity_radar/core/notifications/signal_reminder_repository.dart';
import 'package:ai_opportunity_radar/core/notifications/signal_reminder_rule.dart';
import 'package:ai_opportunity_radar/features/pages/me/signal_reminder_settings_page.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'loads confirmed local rules without requesting permission or creating work',
      (tester) async {
    final rules = [
      _weeklyRule(id: 'signal-reminder.rule-a', enabled: true),
      _weeklyRule(id: 'signal-reminder.rule-b', enabled: false, hour: 8),
    ];
    final scheduler = _FakeSignalReminderScheduler();
    final repository = await _repository(rules, scheduler: scheduler);

    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        child: SignalReminderSettingsPage(repository: repository),
        providers: [Provider<String>.value(value: 'test')],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Signal 记录提醒'), findsOneWidget);
    expect(find.textContaining('不会创建信号卡'), findsOneWidget);
    expect(find.text('2 条提醒规则'), findsOneWidget);
    expect(find.byKey(const ValueKey('signal-reminder.rule-a')), findsNothing);
    expect(
      find.byKey(
        const ValueKey('signal-reminder-rule-signal-reminder.rule-a'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Calendar'), findsNothing);
    expect(scheduler.permissionRequests, 0);
    expect(scheduler.scheduleCalls, 0);

    final toggle = find.byKey(
      const ValueKey('signal-reminder-toggle-signal-reminder.rule-a'),
    );
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    final persisted = await repository.loadRules();
    expect(persisted.firstWhere((rule) => rule.id.endsWith('rule-a')).enabled,
        isFalse);
    expect(scheduler.permissionRequests, 0);
    expect(scheduler.scheduleCalls, 0);
    expect(scheduler.cancelCalls, greaterThan(0));
  });

  testWidgets('re-enabling a rule schedules notifications only after consent',
      (tester) async {
    final rule = _weeklyRule(
      id: 'signal-reminder.rule-disabled',
      enabled: false,
    );
    final scheduler = _FakeSignalReminderScheduler();
    final repository = await _repository([rule], scheduler: scheduler);

    await tester.pumpWidget(
      buildTestApp(
        child: SignalReminderSettingsPage(repository: repository),
        providers: [Provider<String>.value(value: 'test')],
      ),
    );
    await tester.pumpAndSettle();

    expect(scheduler.permissionRequests, 0);
    final toggle = find.byKey(
      const ValueKey(
        'signal-reminder-toggle-signal-reminder.rule-disabled',
      ),
    );
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(scheduler.permissionRequests, 1);
    expect(scheduler.scheduleCalls, greaterThan(0));
    final persisted = await repository.loadRules();
    expect(persisted.single.enabled, isTrue);
    expect(find.text('Reminder saved.'), findsOneWidget);
  });

  testWidgets('editing a weekly rule starts with its current weekdays',
      (tester) async {
    final rule = _weeklyRule(id: 'signal-reminder.rule-edit', enabled: true);
    final repository = await _repository(
      [rule],
      scheduler: _FakeSignalReminderScheduler(),
    );

    await tester.pumpWidget(
      buildTestApp(
        child: SignalReminderSettingsPage(repository: repository),
        providers: [Provider<String>.value(value: 'test')],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(
      const ValueKey('signal-reminder-edit-signal-reminder.rule-edit'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Repeat on'), findsOneWidget);
    expect(
      tester
          .widget<FilterChip>(
            find.byKey(const ValueKey('signal-reminder-weekday-1')),
          )
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<FilterChip>(
            find.byKey(const ValueKey('signal-reminder-weekday-7')),
          )
          .selected,
      isFalse,
    );
  });

  testWidgets('deleting removes only the selected reminder rule',
      (tester) async {
    final rules = [
      _weeklyRule(id: 'signal-reminder.rule-keep', enabled: false),
      _weeklyRule(id: 'signal-reminder.rule-delete', enabled: false, hour: 9),
    ];
    final repository = await _repository(
      rules,
      scheduler: _FakeSignalReminderScheduler(),
    );

    await tester.pumpWidget(
      buildTestApp(
        child: SignalReminderSettingsPage(repository: repository),
        providers: [Provider<String>.value(value: 'test')],
      ),
    );
    await tester.pumpAndSettle();

    final delete = find.byKey(
      const ValueKey('signal-reminder-delete-signal-reminder.rule-delete'),
    );
    await tester.ensureVisible(delete);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Your Signals and reports will not change'),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('signal-reminder-confirm-delete')),
    );
    await tester.pumpAndSettle();

    final persisted = await repository.loadRules();
    expect(persisted.map((rule) => rule.id), ['signal-reminder.rule-keep']);
    expect(find.text('1 reminder rule'), findsOneWidget);
  });
}

SignalReminderRule _weeklyRule({
  required String id,
  required bool enabled,
  int hour = 20,
}) {
  return SignalReminderRule.weekly(
    id: id,
    weekdays: const {DateTime.monday, DateTime.wednesday},
    hour: hour,
    minute: 30,
    enabled: enabled,
    now: DateTime(2026, 1, 1, 10),
  );
}

Future<SignalReminderRepository> _repository(
  List<SignalReminderRule> rules, {
  required _FakeSignalReminderScheduler scheduler,
}) async {
  SharedPreferences.setMockInitialValues({
    SignalReminderRepository.preferencesKey:
        jsonEncode(rules.map((rule) => rule.toJson()).toList()),
  });
  final preferences = await SharedPreferences.getInstance();
  return SignalReminderRepository(
    preferences: preferences,
    scheduler: scheduler,
    clock: () => DateTime(2026, 7, 22, 12),
  );
}

class _FakeSignalReminderScheduler implements SignalReminderScheduler {
  int permissionRequests = 0;
  int scheduleCalls = 0;
  int cancelCalls = 0;

  @override
  Future<bool> cancelAllSignalReminders() async => true;

  @override
  Future<bool> cancelSignalReminder(String notificationId) async {
    cancelCalls += 1;
    return true;
  }

  @override
  Future<SignalReminderPermissionResult>
      requestSignalReminderPermission() async {
    permissionRequests += 1;
    return const SignalReminderPermissionResult(
      SignalReminderPermissionStatus.granted,
    );
  }

  @override
  Future<bool> scheduleSignalReminder({
    required String notificationId,
    required DateTime scheduledAt,
    String? localeTag,
  }) async {
    scheduleCalls += 1;
    return true;
  }
}
