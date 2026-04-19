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

      expect(weekly.status, 'light_ready');
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

    test('4) 第 2 天以后只有 1 条本地记录时，Weekly 返回 light_ready', () async {
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

      expect(weekly.status, 'light_ready');
      expect(weekly.patterns, isNotEmpty);

      await harness.close();
    });

    test('5) 第 2 天以后达到较完整数据时，Weekly 返回 ready', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeWeeklyAiRepository(),
        installationDate: DateTime.now().subtract(const Duration(days: 1)),
      );

      final now = DateTime.now();
      await harness.seedCapture(
        content: '今天上班很烦',
        createdAt: now,
      );
      await harness.seedCapture(
        content: '下午又被打断',
        createdAt: now.subtract(const Duration(hours: 1)),
      );
      await harness.seedCapture(
        content: '昨天还是烦',
        createdAt: now.subtract(const Duration(days: 1)),
      );
      await harness.seedCapture(
        content: '昨天开会也很累',
        createdAt: now.subtract(const Duration(days: 1, hours: 2)),
      );

      final weekly = await harness.repository.fetchCurrentWeekly();

      expect(weekly.status, 'ready');
      expect(weekly.patterns, isNotEmpty);

      await harness.close();
    });

    test('6) 再次进入 Weekly 时，结果能从本地缓存读取', () async {
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
      expect(weekly1.status, 'light_ready');
      expect(countingAi.callCount, 1);

      await harness1.close();

      final harness2 = await _createHarness(
        dbPath: dbPath,
        aiRepository: countingAi,
        installationDate: DateTime.now().subtract(const Duration(days: 1)),
      );

      final weekly2 = await harness2.repository.fetchCurrentWeekly();
      expect(weekly2.status, 'light_ready');
      expect(countingAi.callCount, 1);

      await harness2.close();
    });

    test('7) 在线生成失败时，Weekly 仍然返回 fallback 结果', () async {
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

      expect(weekly.status, 'light_ready');
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
        'ai_observation': null,
        'ai_try_next': null,
        'ai_emotion': null,
        'ai_intensity': null,
        'ai_scene_tags_json': null,
        'ai_intent_tags_json': null,
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
          'name': '轻量摩擦',
          'summary': '当前只是轻量判断，不会太早下结论。',
        },
      ],
      bestAction: '先继续记录重复出现的场景。',
      opportunitySnapshot: const {
        'name': '保留线索',
        'summary': '当前先把线索留住就够了。',
      },
      feedbackSubmitted: false,
    );
  }
}

class CountingWeeklyAiRepository extends FakeWeeklyAiRepository {
  int callCount = 0;

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
    return super.generateWeeklySummary(
      weekStart: weekStart,
      weekEnd: weekEnd,
      entries: entries,
      dayCounts: dayCounts,
      topTokens: topTokens,
      focusArea: focusArea,
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
    throw Exception('network failed');
  }
}
