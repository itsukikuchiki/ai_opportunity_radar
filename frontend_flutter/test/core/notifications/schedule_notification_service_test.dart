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
}
