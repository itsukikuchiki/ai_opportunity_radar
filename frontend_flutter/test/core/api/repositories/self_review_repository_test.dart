import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_opportunity_radar/core/api/api_client.dart';
import 'package:ai_opportunity_radar/core/api/repositories/self_review_repository.dart';
import 'package:ai_opportunity_radar/core/i18n/app_locale_text.dart';
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
      languageLoader: () => AppLanguage.simplifiedChinese,
    );

    final review = await repository.fetchSelfReview();

    expect(review.status, 'ready');
    expect(api.lastBody, isNotNull);
    final entries = api.lastBody!['entries'] as List;
    expect(entries, hasLength(1));
    expect(entries.single['content'], contains('下午开始有点转不动'));
    expect(api.lastBody!['language'], 'zh-Hans');
  });

  test('Self Review fallback 会跟随四种界面语言并保留原文', () async {
    final expectations = <AppLanguage, String>{
      AppLanguage.english: 'no longer an isolated moment',
      AppLanguage.simplifiedChinese: '已经不是一次性的瞬间',
      AppLanguage.traditionalChinese: '已經不是一次性的片刻',
      AppLanguage.japanese: '一度きりの出来事ではなく',
    };

    for (final entry in expectations.entries) {
      final tempDir = await Directory.systemTemp.createTemp(
        'self_review_${entry.key.name}_',
      );
      final database = LocalDatabase(
        dbPathOverride: p.join(tempDir.path, 'self_review.db'),
        databaseFactoryOverride: databaseFactoryFfi,
      );
      await database.init();

      final captures = LocalCaptureRepository(database);
      await captures.insertConfirmedSignalCard(
        content: 'rap',
        sourceType: 'text',
        language: 'en',
      );
      final repository = SelfReviewRepository(
        localCaptureRepository: captures,
        apiClient: _ThrowingSelfReviewApiClient(),
        focusAreaLoader: () async => null,
        languageLoader: () => entry.key,
      );

      final review = await repository.fetchSelfReview();

      expect(review.status, 'ready');
      expect(review.repeatedBlockers.first, contains('rap'));
      expect(review.repeatedBlockers.first, contains(entry.value));

      await database.close();
      await tempDir.delete(recursive: true);
    }
  });

  test('Self Review API 返回错误语言时改用当前语言 fallback', () async {
    final tempDir =
        await Directory.systemTemp.createTemp('self_review_language_test_');
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
      content: '今日は会議が多かった',
      sourceType: 'text',
      language: 'ja',
    );
    final repository = SelfReviewRepository(
      localCaptureRepository: captures,
      apiClient: _RecordingSelfReviewApiClient(),
      focusAreaLoader: () async => null,
      languageLoader: () => AppLanguage.japanese,
    );

    final review = await repository.fetchSelfReview();

    expect(review.closingNote, contains('すべてを一度に解決しなくて大丈夫'));
    expect(review.closingNote, isNot(contains('已读取统一时间线')));
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

class _ThrowingSelfReviewApiClient extends ApiClient {
  _ThrowingSelfReviewApiClient()
      : super(
          baseUrl: 'https://example.invalid',
          userId: 'self-review-test-user',
        );

  @override
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    throw Exception('self review failed');
  }
}
