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

  group('WeeklyRepository local-first behavior', () {
    test('1) Weekly 不再因为 Railway 空数据库而直接空掉', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeWeeklyAiRepository(),
      );

      await harness.seedCapture(
        content: '今天上班很烦',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      await harness.seedCapture(
        content: '下午开会被打断',
        createdAt: DateTime.now(),
      );

      final weekly = await harness.repository.fetchCurrentWeekly();

      expect(weekly.status, 'ready');
      expect(weekly.keyInsight, isNotNull);
      expect(weekly.patterns, isNotEmpty);

      await harness.close();
    });

    test('2) 最近 7 天只要 Today 有本地记录，Weekly 就能生成', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeWeeklyAiRepository(
          weeklyBuilder: ({
            required String weekStart,
            required String weekEnd,
            required List<Map<String, dynamic>> entries,
            required Map<String, int> dayCounts,
            required List<String> topTokens,
          }) {
            return WeeklyInsightModel(
              weekStart: weekStart,
              weekEnd: weekEnd,
              status: 'ready',
              keyInsight: '最近 7 天共记录了 ${entries.length} 条。',
              patterns: [
                {
                  'name': '本地记录已形成',
                  'summary': '最近 7 天的记录已经足够支持一份 weekly。',
                },
              ],
              frictions: [
                {
                  'name': '重复摩擦开始出现',
                  'summary': '同类内容开始在本周重复出现。',
                },
              ],
              bestAction: '这周先试一步：继续补记同类情况出现的场景。',
              opportunitySnapshot: const {
                'name': '形成 weekly 的最小结构',
                'summary': '只要最近 7 天有本地记录，weekly 就可以开始生成。',
              },
              feedbackSubmitted: false,
            );
          },
        ),
      );

      await harness.seedCapture(
        content: '第一天：上班很烦',
        createdAt: DateTime.now().subtract(const Duration(days: 6)),
      );
      await harness.seedCapture(
        content: '第三天：还是烦',
        createdAt: DateTime.now().subtract(const Duration(days: 4)),
      );
      await harness.seedCapture(
        content: '今天：又被打断',
        createdAt: DateTime.now(),
      );

      final weekly = await harness.repository.fetchCurrentWeekly();

      expect(weekly.status, 'ready');
      expect(weekly.keyInsight, contains('最近 7 天共记录了 3 条'));
      expect(weekly.bestAction, isNotNull);

      await harness.close();
    });

    test('3) 再次进入 Weekly 时，结果能从本地缓存读取', () async {
      final countingAi = CountingWeeklyAiRepository();

      final harness1 = await _createHarness(
        dbPath: dbPath,
        aiRepository: countingAi,
      );

      await harness1.seedCapture(
        content: '今天有点烦',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      );
      await harness1.seedCapture(
        content: '今天还是有点烦',
        createdAt: DateTime.now(),
      );

      final weekly1 = await harness1.repository.fetchCurrentWeekly();
      expect(weekly1.status, 'ready');
      expect(countingAi.callCount, 1);

      await harness1.close();

      final harness2 = await _createHarness(
        dbPath: dbPath,
        aiRepository: countingAi,
      );

      final weekly2 = await harness2.repository.fetchCurrentWeekly();
      expect(weekly2.status, 'ready');
      expect(countingAi.callCount, 1, reason: '第二次应直接命中本地缓存，不应再次调用在线生成');

      await harness2.close();
    });

    test('4) 没网或在线生成失败时，Weekly 至少还能显示 fallback 结果', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FailingWeeklyAiRepository(),
      );

      await harness.seedCapture(
        content: '今天上班很烦',
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      );
      await harness.seedCapture(
        content: '今天开会又被打断',
        createdAt: DateTime.now(),
      );

      final weekly = await harness.repository.fetchCurrentWeekly();

      expect(weekly.status, 'ready');
      expect(weekly.keyInsight, isNotNull);
      expect(weekly.keyInsight!.isNotEmpty, true);
      expect(weekly.patterns, isNotEmpty);
      expect(weekly.bestAction, isNotNull);
      expect(weekly.bestAction!.isNotEmpty, true);

      await harness.close();
    });

    test('5) 最近 7 天完全没有记录时，Weekly 返回 insufficient_data', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeWeeklyAiRepository(),
      );

      await harness.seedCapture(
        content: '这是 10 天前的记录',
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      );

      final weekly = await harness.repository.fetchCurrentWeekly();

      expect(weekly.status, 'insufficient_data');
      expect(weekly.keyInsight, isNull);
      expect(weekly.patterns, isEmpty);

      await harness.close();
    });
  });
}

class _Harness {
  final LocalDatabase localDatabase;
  final LocalCaptureRepository localCaptureRepository;
  final WeeklyRepository repository;

  _Harness({
    required this.localDatabase,
    required this.localCaptureRepository,
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
  );

  return _Harness(
    localDatabase: localDatabase,
    localCaptureRepository: localCaptureRepository,
    repository: repository,
  );
}

typedef WeeklyBuilder =
    WeeklyInsightModel Function({
      required String weekStart,
      required String weekEnd,
      required List<Map<String, dynamic>> entries,
      required Map<String, int> dayCounts,
      required List<String> topTokens,
    });

class FakeWeeklyAiRepository extends AiRepository {
  final WeeklyBuilder? weeklyBuilder;

  FakeWeeklyAiRepository({
    this.weeklyBuilder,
  }) : super(
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
    if (weeklyBuilder != null) {
      return weeklyBuilder!(
        weekStart: weekStart,
        weekEnd: weekEnd,
        entries: entries,
        dayCounts: dayCounts,
        topTokens: topTokens,
      );
    }

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
