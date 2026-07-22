import 'package:flutter_test/flutter_test.dart';

import 'package:ai_opportunity_radar/core/notifications/signal_reminder_rule.dart';

void main() {
  test('weekly rule materialises local weekday times inside its horizon', () {
    final rule = SignalReminderRule.weekly(
      id: 'signal-reminder.weekly',
      weekdays: {DateTime.monday, DateTime.wednesday},
      hour: 9,
      minute: 30,
      now: DateTime(2026, 7, 1, 8),
    );

    final occurrences = rule.upcomingOccurrences(
      now: DateTime(2026, 7, 6, 9),
      horizonDays: 8,
    );

    expect(
      occurrences,
      [
        DateTime(2026, 7, 6, 9, 30),
        DateTime(2026, 7, 8, 9, 30),
        DateTime(2026, 7, 13, 9, 30),
      ],
    );
  });

  test('one-time rule does not schedule a passed local time', () {
    final rule = SignalReminderRule.once(
      id: 'signal-reminder.once',
      localDate: DateTime(2026, 7, 6),
      hour: 9,
      minute: 30,
      now: DateTime(2026, 7, 1),
    );

    expect(
      rule.upcomingOccurrences(now: DateTime(2026, 7, 6, 9, 30)),
      isEmpty,
    );
  });

  test('rule round trips without storing any Signal content', () {
    final rule = SignalReminderRule.weekly(
      id: 'signal-reminder.roundtrip',
      weekdays: {DateTime.friday},
      hour: 20,
      minute: 5,
      now: DateTime.utc(2026, 7, 1),
    );

    final decoded = SignalReminderRule.tryParse(rule.encode());

    expect(decoded, isNotNull);
    expect(decoded!.id, rule.id);
    expect(decoded.weekdays, rule.weekdays);
    expect(decoded.toJson().keys, isNot(contains('signal_content')));
    expect(decoded.toJson().keys, isNot(contains('ai_response')));
  });
}
