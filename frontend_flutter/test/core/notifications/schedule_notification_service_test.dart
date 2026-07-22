import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_opportunity_radar/core/notifications/schedule_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('signalpath/local_notifications');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('legacy schedule cleanup uses the native bulk cancellation bridge',
      () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });

    final cleared =
        await ScheduleNotificationService().cancelAllLegacyScheduleReminders();

    expect(cleared, isTrue);
    expect(calls.map((call) => call.method), ['cancelAllScheduleReminders']);
  });

  test('Signal reminder permission is requested before scheduling', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'requestSignalReminderAuthorization') return true;
      return null;
    });

    final service = ScheduleNotificationService();
    final permission = await service.requestSignalReminderPermission();
    final scheduled = await service.scheduleSignalReminder(
      notificationId: 'signal-reminder.rule.0',
      scheduledAt: DateTime.utc(2026, 7, 7, 1, 30),
      localeTag: 'ja-JP',
    );

    expect(permission.granted, isTrue);
    expect(scheduled, isTrue);
    expect(calls.map((call) => call.method), [
      'requestSignalReminderAuthorization',
      'scheduleReminder',
    ]);
    final args = calls.last.arguments! as Map<Object?, Object?>;
    expect(args['destination'], 'today');
    expect(args['body'], '今のサインを少し残してみませんか。');
    expect(args.containsKey('signal_content'), isFalse);
  });

  test('Signal reminder copy supports all product languages', () {
    expect(
      SignalReminderCopy.forLocale('zh-Hans-CN').body,
      '现在方便的话，留下一点今天的信号。',
    );
    expect(
      SignalReminderCopy.forLocale('zh-Hant-TW').body,
      '方便的話，留下一點今天的信號。',
    );
    expect(
      SignalReminderCopy.forLocale('ja-JP').body,
      '今のサインを少し残してみませんか。',
    );
    expect(
      SignalReminderCopy.forLocale('en-US').body,
      "Leave a small signal from today when you're ready.",
    );
    expect(SignalReminderCopy.forLocale(null).title, 'Signal Path');
    expect(SignalReminderCopy.forLocale(null).body, isNotEmpty);
  });
}
