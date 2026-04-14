import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_opportunity_radar/core/api/api_client.dart';
import 'package:ai_opportunity_radar/core/api/repositories/ai_repository.dart';
import 'package:ai_opportunity_radar/core/api/repositories/weekly_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_capture_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/local/local_weekly_snapshot_repository.dart';
import 'package:ai_opportunity_radar/core/models/weekly_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String dbPath;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ai_radar_weekly_test_');
    dbPath = p.join(tempDir.path, 'weekly_test.db');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('WeeklyRepository first-day and local-first behavior', () {
    test('1) 第 1 天且没有本地记录时，Weekly 返回 first_day_gate', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeWeeklyAiRepository(),
        installationDate: DateTime.now(),
      );

      final weekly = await harness.repository.fetchCurrentWeekly();

      expect(weekly.status, 'first_day_gate');
      expect(weekly.keyInsight, isNull);

      await harness.close();
    });

    test('2) 第 1 天只要有本地记录，Weekly 就正常展示', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeWeeklyAiRepository(),
        installationDate: DateTime.now(),
      );

      await harness.seedCapture(
        content: '今天上班很烦',
        createdAt: DateTime.now(),
      );

      final weekly = await harness.repository.fetchCurrentWeekly();

      expect(weekly.status, 'ready');
      expect(weekly.keyInsight, isNotNull);

      await harness.close();
    });

    test('3) 第 2 天以后没有本地记录时，Weekly 返回 insufficient_data', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeWeeklyAiRepository(),
        installationDate: DateTime.now().subtract(const Duration(days: 1)),
      );

      final weekly = await harness.repository.fetchCurrentWeekly();

      expect(weekly.status, 'insufficient_data');
      expect(weekly.keyInsight, isNull);

      await harness.close();
    });

    test('4) 第 2 天以后有本地记录时，Weekly 正常展示', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeWeeklyAiRepository(),
        installationDate: DateTime.now().subtract(const Duration(days: 1)),
      );

      await harness.seedCapture(
        content: '今天开会被打断',
        createdAt: DateTime.now(),
      );

      final weekly = await harness.repository.fetchCurrentWeekly();

      expect(weekly.status, 'ready');
      expect(weekly.patterns, isNotEmpty);

      await harness.close();
    });

    test('5) 再次进入 Weekly 时，结果能从本地缓存读取', () async {
      final countingAi = CountingWeeklyAiRepository();

      final harness1 = await _createHarness(
        dbPath: dbPath,
        aiRepository: countingAi,
        installationDate: DateTime.now().subtract(const Duration(days: 1)),
      );

      await harness1.seedCapture(
        content: '今天有点烦',
        createdAt: DateTime.now(),
      );

      final weekly1 = await harness1.repository.fetchCurrentWeekly();
      expect(weekly1.status, 'ready');
      expect(countingAi.callCount, 1);

      await harness1.close();

      final harness2 = await _createHarness(
        dbPath: dbPath,
        aiRepository: countingAi,
        installationDate: DateTime.now().subtract(const Duration(days: 1)),
      );

      final weekly2 = await harness2.repository.fetchCurrentWeekly();
      expect(weekly2.status, 'ready');
      expect(countingAi.callCount, 1);

      await harness2.close();
    });

    test('6) 在线生成失败时，Weekly 仍然返回 fallback 结果', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FailingWeeklyAiRepository(),
        installationDate: DateTime.now().subtract(const Duration(days: 1)),
      );

      await harness.seedCapture(
        content: '今天上班很烦',
        createdAt: DateTime.now(),
      );

      final weekly = await harness.repository.fetchCurrentWeekly();

      expect(weekly.status, 'ready');
      expect(weekly.keyInsight, isNotNull);
      expect(weekly.patterns, isNotEmpty);
      expect(weekly.bestAction, isNotNull);

      await harness.close();
    });
  });
}

class _Harness {
  final LocalDatabase localDatabase;
  final WeeklyRepository repository;

  _Harness({
    required this.localDatabase,
    required this.repository,
  });

  Future<void> seedCapture({
    required String content,
    required DateTime createdAt,
  }) async {
    final db = await localDatabase.database;
    final id = 'seed_${createdAt.microsecondsSinceEpoch}_${content.hashCode}';

    await db.insert(
      'captures',
      {
        'id': id,
        'content': content,
        'created_at': createdAt.toUtc().toIso8601String(),
        'input_mode': 'quick_capture',
        'tag_hint': null,
        'ai_acknowledgement': null,
        'ai_status': 'done',
        'followup_question_json': null,
        'followup_answer': null,
        'updated_at': createdAt.toUtc().toIso8601String(),
      },
    );
  }

  Future<void> close() async {
    await localDatabase.close();
  }
}

Future<_Harness> _createHarness({
  required String dbPath,
  required AiRepository aiRepository,
  required DateTime installationDate,
}) async {
  final localDatabase = LocalDatabase(
    dbPathOverride: dbPath,
    databaseFactoryOverride: databaseFactoryFfi,
  );
  await localDatabase.init();

  final localCaptureRepository = LocalCaptureRepository(localDatabase);
  final localWeeklySnapshotRepository =
      LocalWeeklySnapshotRepository(localDatabase);

  final repository = WeeklyRepository(
    localCaptureRepository: localCaptureRepository,
    localWeeklySnapshotRepository: localWeeklySnapshotRepository,
    aiRepository: aiRepository,
    focusAreaLoader: () async => null,
    installationDateLoader: () async => installationDate,
  );

  return _Harness(
    localDatabase: localDatabase,
    repository: repository,
  );
}

class FakeWeeklyAiRepository extends AiRepository {
  FakeWeeklyAiRepository()
      : super(
          ApiClient(
            baseUrl: 'https://example.invalid',
            userId: 'test-user',
          ),
        );

  @override
  Future<WeeklyInsightModel> generateWeeklySummary({
    required String weekStart,
    required String weekEnd,
    required List<Map<String, dynamic>> entries,
    required Map<String, int> dayCounts,
    required List<String> topTokens,
    String? focusArea,
  }) async {
    return WeeklyInsightModel(
      weekStart: weekStart,
      weekEnd: weekEnd,
      status: 'ready',
      keyInsight: '这周本地统计到了 ${entries.length} 条记录。',
      patterns: [
        {
          'name': '本地统计已生效',
          'summary': 'Weekly 已经从本地 captures 生成，不再依赖线上数据库。',
        },
      ],
      frictions: [
        {
          'name': '重复信号开始形成',
          'summary': '同类内容在本周开始重复出现。',
        },
      ],
      bestAction: '这周先补记一次重复出现的场景。',
      opportunitySnapshot: const {
        'name': '把重复信号结构化',
        'summary': 'Weekly 已经能基于本地记录生成最小建议。',
      },
      feedbackSubmitted: false,
    );
  }
}

class CountingWeeklyAiRepository extends AiRepository {
  int callCount = 0;

  CountingWeeklyAiRepository()
      : super(
          ApiClient(
            baseUrl: 'https://example.invalid',
            userId: 'test-user',
          ),
        );

  @override
  Future<WeeklyInsightModel> generateWeeklySummary({
    required String weekStart,
    required String weekEnd,
    required List<Map<String, dynamic>> entries,
    required Map<String, int> dayCounts,
    required List<String> topTokens,
    String? focusArea,
  }) async {
    callCount += 1;

    return WeeklyInsightModel(
      weekStart: weekStart,
      weekEnd: weekEnd,
      status: 'ready',
      keyInsight: '缓存测试：本周 ${entries.length} 条记录。',
      patterns: [
        {
          'name': '缓存测试 pattern',
          'summary': '第一次生成后，第二次应直接读取本地缓存。',
        },
      ],
      frictions: [
        {
          'name': '缓存测试 friction',
          'summary': '这个结果应被缓存下来。',
        },
      ],
      bestAction: '缓存命中后不再重新生成。',
      opportunitySnapshot: const {
        'name': '缓存命中',
        'summary': '第二次进入 Weekly 不需要再调在线生成。',
      },
      feedbackSubmitted: false,
    );
  }
}

class FailingWeeklyAiRepository extends AiRepository {
  FailingWeeklyAiRepository()
      : super(
          ApiClient(
            baseUrl: 'https://example.invalid',
            userId: 'test-user',
          ),
        );

  @override
  Future<WeeklyInsightModel> generateWeeklySummary({
    required String weekStart,
    required String weekEnd,
    required List<Map<String, dynamic>> entries,
    required Map<String, int> dayCounts,
    required List<String> topTokens,
    String? focusArea,
  }) async {
    throw Exception('Simulated weekly remote failure');
  }
}
