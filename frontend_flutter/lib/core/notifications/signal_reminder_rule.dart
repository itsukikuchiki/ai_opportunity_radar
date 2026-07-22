import 'dart:convert';

enum SignalReminderCadence { once, weekly }

/// A user-approved local reminder. It contains no Signal text or AI output.
///
/// Weekdays use [DateTime.monday] through [DateTime.sunday]. A weekly rule is
/// materialised into one-time local notifications so its local clock time stays
/// correct across daylight-saving and timezone changes after rescheduling.
class SignalReminderRule {
  static const String idPrefix = 'signal-reminder.';

  final String id;
  final SignalReminderCadence cadence;
  final int hour;
  final int minute;
  final Set<int> weekdays;
  final DateTime? localDate;
  final bool enabled;
  final String? localeTag;
  final String timeZoneName;
  final DateTime createdAt;
  final DateTime updatedAt;

  SignalReminderRule({
    required this.id,
    required this.cadence,
    required this.hour,
    required this.minute,
    required Set<int> weekdays,
    required this.localDate,
    required this.enabled,
    required this.localeTag,
    required this.timeZoneName,
    required this.createdAt,
    required this.updatedAt,
  }) : weekdays = Set.unmodifiable(weekdays) {
    if (!id.startsWith(idPrefix)) {
      throw ArgumentError.value(
          id, 'id', 'must use the Signal reminder prefix');
    }
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      throw ArgumentError('hour/minute are outside a local clock range');
    }
    if (weekdays.any((day) => day < DateTime.monday || day > DateTime.sunday)) {
      throw ArgumentError('weekdays must use DateTime weekday values');
    }
    if (cadence == SignalReminderCadence.once && localDate == null) {
      throw ArgumentError('one-time reminders need a local date');
    }
    if (cadence == SignalReminderCadence.weekly && weekdays.isEmpty) {
      throw ArgumentError('weekly reminders need at least one weekday');
    }
  }

  factory SignalReminderRule.once({
    required DateTime localDate,
    required int hour,
    required int minute,
    String? id,
    bool enabled = true,
    String? localeTag,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    return SignalReminderRule(
      id: id ?? '$idPrefix${timestamp.microsecondsSinceEpoch}',
      cadence: SignalReminderCadence.once,
      hour: hour,
      minute: minute,
      weekdays: const {},
      localDate: DateTime(localDate.year, localDate.month, localDate.day),
      enabled: enabled,
      localeTag: localeTag,
      timeZoneName: timestamp.timeZoneName,
      createdAt: timestamp.toUtc(),
      updatedAt: timestamp.toUtc(),
    );
  }

  factory SignalReminderRule.weekly({
    required Set<int> weekdays,
    required int hour,
    required int minute,
    String? id,
    bool enabled = true,
    String? localeTag,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    return SignalReminderRule(
      id: id ?? '$idPrefix${timestamp.microsecondsSinceEpoch}',
      cadence: SignalReminderCadence.weekly,
      hour: hour,
      minute: minute,
      weekdays: weekdays,
      localDate: null,
      enabled: enabled,
      localeTag: localeTag,
      timeZoneName: timestamp.timeZoneName,
      createdAt: timestamp.toUtc(),
      updatedAt: timestamp.toUtc(),
    );
  }

  SignalReminderRule copyWith({
    SignalReminderCadence? cadence,
    int? hour,
    int? minute,
    Set<int>? weekdays,
    DateTime? localDate,
    bool clearLocalDate = false,
    bool? enabled,
    String? localeTag,
    bool clearLocaleTag = false,
    String? timeZoneName,
    DateTime? updatedAt,
  }) {
    return SignalReminderRule(
      id: id,
      cadence: cadence ?? this.cadence,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      weekdays: weekdays ?? this.weekdays,
      localDate: clearLocalDate ? null : (localDate ?? this.localDate),
      enabled: enabled ?? this.enabled,
      localeTag: clearLocaleTag ? null : (localeTag ?? this.localeTag),
      timeZoneName: timeZoneName ?? this.timeZoneName,
      createdAt: createdAt,
      updatedAt: (updatedAt ?? DateTime.now()).toUtc(),
    );
  }

  List<DateTime> upcomingOccurrences({
    required DateTime now,
    int horizonDays = 21,
  }) {
    if (!enabled) return const [];
    if (cadence == SignalReminderCadence.once) {
      final date = localDate!;
      final occurrence =
          DateTime(date.year, date.month, date.day, hour, minute);
      return occurrence.isAfter(now) ? [occurrence] : const [];
    }

    final firstDate = DateTime(now.year, now.month, now.day);
    final occurrences = <DateTime>[];
    for (var offset = 0; offset < horizonDays; offset += 1) {
      final date = firstDate.add(Duration(days: offset));
      if (!weekdays.contains(date.weekday)) continue;
      final occurrence =
          DateTime(date.year, date.month, date.day, hour, minute);
      if (occurrence.isAfter(now)) occurrences.add(occurrence);
    }
    return occurrences;
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'cadence': cadence.name,
        'hour': hour,
        'minute': minute,
        'weekdays': weekdays.toList()..sort(),
        'local_date': localDate?.toIso8601String(),
        'enabled': enabled,
        'locale': localeTag,
        'timezone': timeZoneName,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  String encode() => jsonEncode(toJson());

  static SignalReminderRule? tryParse(Object? raw) {
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is! Map) return null;
      final id = decoded['id']?.toString() ?? '';
      final cadence = SignalReminderCadence.values.firstWhere(
        (value) => value.name == decoded['cadence']?.toString(),
      );
      final hour = int.parse(decoded['hour'].toString());
      final minute = int.parse(decoded['minute'].toString());
      final rawWeekdays = decoded['weekdays'];
      final weekdays = rawWeekdays is List
          ? rawWeekdays.map((value) => int.parse(value.toString())).toSet()
          : <int>{};
      final rawDate = decoded['local_date']?.toString();
      final rawCreatedAt = decoded['created_at']?.toString();
      final rawUpdatedAt = decoded['updated_at']?.toString();
      return SignalReminderRule(
        id: id,
        cadence: cadence,
        hour: hour,
        minute: minute,
        weekdays: weekdays,
        localDate: rawDate == null ? null : DateTime.parse(rawDate).toLocal(),
        enabled: decoded['enabled'] == true,
        localeTag: decoded['locale']?.toString(),
        timeZoneName: decoded['timezone']?.toString() ?? '',
        createdAt: DateTime.parse(rawCreatedAt!).toUtc(),
        updatedAt: DateTime.parse(rawUpdatedAt!).toUtc(),
      );
    } catch (_) {
      return null;
    }
  }
}
