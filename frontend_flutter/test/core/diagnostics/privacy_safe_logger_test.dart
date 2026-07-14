import 'package:flutter_test/flutter_test.dart';

import 'package:ai_opportunity_radar/core/diagnostics/privacy_safe_logger.dart';

void main() {
  test('exception records never retain messages, user text, or stack paths',
      () {
    final emitted = <PrivacySafeLogRecord>[];
    final logger = PrivacySafeLogger(
      sink: emitted.add,
      idFactory: () => 'event-001',
      clock: () => DateTime.utc(2026, 7, 14),
    );

    final record = logger.capture(
      StateError('private diary text: I feel overwhelmed'),
      StackTrace.fromString(
        '#0 savePrivateText (/Users/person/private/diary.dart:12:3)',
      ),
      operation: 'app initialization',
      requestId: 'request-001',
      fatal: true,
    );

    expect(emitted, [record]);
    expect(record.eventId, 'event-001');
    expect(record.operation, 'app_initialization');
    expect(record.errorType, 'StateError');
    expect(record.requestId, 'request-001');
    expect(record.fingerprint, matches(RegExp(r'^[0-9a-f]{8}$')));

    final safeOutput = record.toSafeLine();
    expect(safeOutput, isNot(contains('I feel overwhelmed')));
    expect(safeOutput, isNot(contains('/Users/person')));
    expect(safeOutput, isNot(contains('diary.dart')));
    expect(safeOutput, isNot(contains('private diary text')));
  });

  test('in-memory diagnostics are bounded and contain safe metadata only', () {
    var nextId = 0;
    final logger = PrivacySafeLogger(
      sink: (_) {},
      idFactory: () => 'event-${nextId++}',
      maxBufferedRecords: 2,
    );

    for (var index = 0; index < 3; index += 1) {
      logger.capture(
        Exception('secret-$index'),
        StackTrace.fromString('#0 frame$index (private.dart:1:1)'),
        operation: 'test',
      );
    }

    expect(logger.records.map((record) => record.eventId), [
      'event-1',
      'event-2',
    ]);
    expect(
      logger.records.map((record) => record.toSafeLine()).join(' '),
      isNot(contains('secret-')),
    );
  });
}
