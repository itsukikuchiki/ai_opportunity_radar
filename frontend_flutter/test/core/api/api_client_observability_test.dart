import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:ai_opportunity_radar/core/api/api_client.dart';
import 'package:ai_opportunity_radar/core/api/repositories/cloud_backup_repository.dart';
import 'package:ai_opportunity_radar/core/diagnostics/privacy_safe_logger.dart';

void main() {
  test('every API request carries a caller-visible request id', () async {
    http.Request? captured;
    final client = ApiClient(
      baseUrl: 'https://example.test',
      userId: 'local-user',
      requestIdFactory: () => 'request-123',
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response('{"data": {"ok": true}}', 200);
      }),
      logger: PrivacySafeLogger(sink: (_) {}),
    );

    await client.getJson('/api/v1/example');

    expect(captured?.headers['X-Request-Id'], 'request-123');
    expect(captured?.headers['X-User-Id'], 'local-user');
    client.close();
  });

  test('session requests keep request id without exposing response bodies',
      () async {
    final records = <PrivacySafeLogRecord>[];
    http.Request? captured;
    final client = ApiClient(
      baseUrl: 'https://example.test',
      userId: 'local-user',
      requestIdFactory: () => 'request-private-safe',
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          '{"detail": {"code": "backup_failed", '
          '"message": "raw diary: private sentence"}}',
          500,
        );
      }),
      logger: PrivacySafeLogger(
        sink: records.add,
        idFactory: () => 'event-api',
      ),
    );
    final repository = CloudBackupRepository(client);

    late ApiException failure;
    try {
      await repository.fetchLatestBackup(sessionToken: 'session-secret');
      fail('Expected the request to fail.');
    } on ApiException catch (error) {
      failure = error;
    }

    expect(captured?.headers['X-Request-Id'], 'request-private-safe');
    expect(captured?.headers['X-Account-Session'], 'session-secret');
    expect(failure.requestId, 'request-private-safe');
    expect(failure.code, 'backup_failed');
    expect(failure.toString(), isNot(contains('raw diary')));
    expect(failure.toString(), isNot(contains('private sentence')));
    expect(failure.toString(), isNot(contains('session-secret')));
    expect(records, hasLength(1));
    expect(records.single.requestId, 'request-private-safe');
    expect(records.single.toSafeLine(), isNot(contains('raw diary')));
    client.close();
  });

  test('unexpected server error codes cannot become user-visible payloads',
      () async {
    final client = ApiClient(
      baseUrl: 'https://example.test',
      userId: 'local-user',
      requestIdFactory: () => 'request-malformed-code',
      httpClient: MockClient((_) async {
        return http.Response(
          '{"detail": {"code": "private diary /Users/person", '
          '"message": "another private sentence"}}',
          500,
        );
      }),
      logger: PrivacySafeLogger(sink: (_) {}),
    );

    late ApiException failure;
    try {
      await client.getJson('/api/v1/example');
      fail('Expected the request to fail.');
    } on ApiException catch (error) {
      failure = error;
    }

    expect(failure.code, isNull);
    expect(failure.toString(), isNot(contains('private diary')));
    expect(failure.toString(), isNot(contains('/Users/person')));
    expect(failure.requestId, 'request-malformed-code');
    client.close();
  });
}
