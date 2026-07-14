import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_opportunity_radar/core/api/api_client.dart';
import 'package:ai_opportunity_radar/core/api/repositories/self_review_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_capture_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(sqfliteFfiInit);

  test('Self Review 从统一 SignalCard 时间线读取真机新记录', () async {
    final tempDir = await Directory.systemTemp.createTemp('self_review_test_');
    final database = LocalDatabase(
      dbPathOverride: p.join(tempDir.path, 'self_review.db'),
      databaseFactoryOverride: databaseFactoryFfi,
    );
    await database.init();
    addTearDown(() async {
      await database.close();
      await tempDir.delete(recursive: true);
    });

    final captures = LocalCaptureRepository(database);
    await captures.insertConfirmedSignalCard(
      content: '状态补充：下午开始有点转不动。',
      sourceType: 'one_tap',
      language: 'zh-Hans',
      rawPayloadJson: const {
        'quick_status': 'tired',
        'energy_level': 0,
        'note': '下午开始有点转不动。',
      },
    );
    final api = _RecordingSelfReviewApiClient();
    final repository = SelfReviewRepository(
      localCaptureRepository: captures,
      apiClient: api,
      focusAreaLoader: () async => null,
    );

    final review = await repository.fetchSelfReview();

    expect(review.status, 'ready');
    expect(api.lastBody, isNotNull);
    final entries = api.lastBody!['entries'] as List;
    expect(entries, hasLength(1));
    expect(entries.single['content'], contains('下午开始有点转不动'));
  });
}

class _RecordingSelfReviewApiClient extends ApiClient {
  Map<String, dynamic>? lastBody;

  _RecordingSelfReviewApiClient()
      : super(
          baseUrl: 'https://example.invalid',
          userId: 'self-review-test-user',
        );

  @override
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    lastBody = body;
    return const {
      'data': {
        'status': 'ready',
        'reviewed_days': 1,
        'repeated_blockers': <String>[],
        'main_drains': <String>[],
        'helping_patterns': <String>[],
        'closing_note': '已读取统一时间线。',
      },
    };
  }
}
