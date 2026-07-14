import 'package:flutter/services.dart';

class ScheduleNotificationService {
  static const MethodChannel _channel =
      MethodChannel('signalpath/local_notifications');

  Future<bool> cancelAllLegacyScheduleReminders() async {
    try {
      await _channel.invokeMethod<void>('cancelAllScheduleReminders');
      return true;
    } on MissingPluginException {
      // No native bridge in this runtime.
      return true;
    } on PlatformException {
      // Best-effort cleanup; the active product no longer schedules these.
      return false;
    }
  }
}
