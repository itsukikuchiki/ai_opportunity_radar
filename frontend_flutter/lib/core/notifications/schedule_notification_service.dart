import 'dart:ui';

import 'package:flutter/services.dart';

/// Platform boundary for locally scheduled Signal reminders.
///
/// Scheduling is deliberately separate from creating a Signal: a notification
/// only points the user back to Today, and no capture is written until the user
/// actively saves one there.
abstract interface class SignalReminderScheduler {
  Future<SignalReminderPermissionResult> requestSignalReminderPermission();

  Future<bool> scheduleSignalReminder({
    required String notificationId,
    required DateTime scheduledAt,
    String? localeTag,
  });

  Future<bool> cancelSignalReminder(String notificationId);

  Future<bool> cancelAllSignalReminders();
}

enum SignalReminderPermissionStatus {
  granted,
  denied,
  unavailable,
  failed,
}

class SignalReminderPermissionResult {
  final SignalReminderPermissionStatus status;

  const SignalReminderPermissionResult(this.status);

  bool get granted => status == SignalReminderPermissionStatus.granted;
}

/// Locale-aware generic copy. It never includes inferred state, Signal text,
/// or AI output, so the notification stays safe on the lock screen.
class SignalReminderCopy {
  final String title;
  final String body;

  const SignalReminderCopy({required this.title, required this.body});

  static String systemLocaleTag() =>
      PlatformDispatcher.instance.locale.toLanguageTag();

  static SignalReminderCopy forLocale(String? localeTag) {
    final normalized = (localeTag ?? systemLocaleTag()).replaceAll('_', '-');
    final lower = normalized.toLowerCase();
    if (lower.startsWith('zh-hant') ||
        lower.startsWith('zh-tw') ||
        lower.startsWith('zh-hk') ||
        lower.startsWith('zh-mo')) {
      return const SignalReminderCopy(
        title: 'Signal Path',
        body: '方便的話，留下一點今天的信號。',
      );
    }
    if (lower.startsWith('zh')) {
      return const SignalReminderCopy(
        title: 'Signal Path',
        body: '现在方便的话，留下一点今天的信号。',
      );
    }
    if (lower.startsWith('ja')) {
      return const SignalReminderCopy(
        title: 'Signal Path',
        body: '今のサインを少し残してみませんか。',
      );
    }
    return const SignalReminderCopy(
      title: 'Signal Path',
      body: "Leave a small signal from today when you're ready.",
    );
  }
}

class ScheduleNotificationService implements SignalReminderScheduler {
  static const MethodChannel _channel =
      MethodChannel('signalpath/local_notifications');

  @override
  Future<SignalReminderPermissionResult>
      requestSignalReminderPermission() async {
    try {
      final granted = await _channel.invokeMethod<bool>(
        'requestSignalReminderAuthorization',
      );
      return SignalReminderPermissionResult(
        granted == true
            ? SignalReminderPermissionStatus.granted
            : SignalReminderPermissionStatus.denied,
      );
    } on MissingPluginException {
      return const SignalReminderPermissionResult(
        SignalReminderPermissionStatus.unavailable,
      );
    } on PlatformException {
      return const SignalReminderPermissionResult(
        SignalReminderPermissionStatus.failed,
      );
    }
  }

  @override
  Future<bool> scheduleSignalReminder({
    required String notificationId,
    required DateTime scheduledAt,
    String? localeTag,
  }) async {
    try {
      final copy = SignalReminderCopy.forLocale(localeTag);
      await _channel.invokeMethod<void>('scheduleReminder', {
        'id': notificationId,
        'title': copy.title,
        'body': copy.body,
        'scheduledAt': scheduledAt.toUtc().toIso8601String(),
        'destination': 'today',
      });
      return true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> cancelSignalReminder(String notificationId) async {
    try {
      await _channel.invokeMethod<void>('cancelReminder', {
        'id': notificationId,
      });
      return true;
    } on MissingPluginException {
      return true;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> cancelAllSignalReminders() async {
    try {
      await _channel.invokeMethod<void>('cancelAllSignalReminders');
      return true;
    } on MissingPluginException {
      return true;
    } on PlatformException {
      return false;
    }
  }

  /// Returns whether a user opened the app from a Signal reminder.
  ///
  /// Navigation stays outside this platform service; callers should route this
  /// one permitted destination to Today and must not create a Signal on tap.
  Future<bool> consumeTodayDestination() async {
    try {
      final destination = await _channel.invokeMethod<String>(
        'consumeSignalReminderDestination',
      );
      return destination == 'today';
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Compatibility cleanup for removed Schedule reminders only.
  ///
  /// Signal reminder identifiers use a different native prefix so this cannot
  /// delete a reminder the user explicitly accepted.
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
