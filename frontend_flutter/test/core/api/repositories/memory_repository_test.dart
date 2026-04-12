import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_opportunity_radar/core/api/api_client.dart';
import 'package:ai_opportunity_radar/core/api/repositories/ai_repository.dart';
import 'package:ai_opportunity_radar/core/api/repositories/memory_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_capture_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/local/local_journey_snapshot_repository.dart';
import 'package:ai_opportunity_radar/core/models/memory_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String dbPath;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ai_radar_memory_test_');
    dbPath = p.join(tempDir.path, 'memory_test.db');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('MemoryRepository local-first behavior', () {
    test('1) Journey 不再因为 Railway 空数据库而直接空掉', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeJourneyAiRepository(),
      );

      await harness.seedCapture(
        content: '第一天：上班很烦',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      );
      await harness.seedCapture(
        content: '第二天：还是很烦',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      );

      final summary = await harness.repository.fetchMemorySummary();

      expect(summary, isNotNull);
      expect(summary!.patterns, isNotEmpty);

      await harness.close();
    });

    test('2) 从第 2 天开始，只要本地有历史记录，Journey 就能生成', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeJourneyAiRepository(
          builder: ({
            required String snapshotDate,
            required List<Map<String, dynamic>> entries,
            required List<String> topTokens,
            required int totalDays,
          }) {
            return MemorySummaryModel(
              patterns: [
                {
                  'name': '长期重复的主题',
                  'summary': '已经跨越 $totalDays 天，长期线索开始形成。',
                },
              ],
              frictions: const [
                {
                  'name': '持续摩擦',
                  'summary': '有一些内容不是一次性，而是在积累。',
                },
              ],
              desires: const [
                {
                  'name': '还在浮现的方向',
                  'summary': '真正长期在意的东西开始浮出来。',
                },
              ],
              experiments: const [
                {
                  'name': '开始有帮助的东西',
                  'summary': '某些做法已经不像随机波动，而开始显得有帮助。',
                },
              ],
            );
          },
        ),
      );

      await harness.seedCapture(
        content: '两天前：有点烦',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      );
      await harness.seedCapture(
        content: '今天：还是烦',
        createdAt: DateTime.now(),
      );

      final summary = await harness.repository.fetchMemorySummary();

      expect(summary, isNotNull);
      expect(summary!.patterns, isNotEmpty);
      expect(summary.frictions, isNotEmpty);

      await harness.close();
    });

    test('3) 再次进入 Journey 时，结果能从本地缓存读取', () async {
      final countingAi = CountingJourneyAiRepository();

      final harness1 = await _createHarness(
        dbPath: dbPath,
        aiRepository: countingAi,
      );

      await harness1.seedCapture(
        content: '前天：工作很烦',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      );
      await harness1.seedCapture(
        content: '今天：又烦了',
        createdAt: DateTime.now(),
      );

      final summary1 = await harness1.repository.fetchMemorySummary();
      expect(summary1, isNotNull);
      expect(countingAi.callCount, 1);

      await harness1.close();

      final harness2 = await _createHarness(
        dbPath: dbPath,
        aiRepository: countingAi,
      );

      final summary2 = await harness2.repository.fetchMemorySummary();
      expect(summary2, isNotNull);
      expect(countingAi.callCount, 1, reason: '第二次应直接命中 Journey 本地缓存');

      await harness2.close();
    });

    test('4) 在线生成失败时，Journey 仍然能显示 fallback 结果', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FailingJourneyAiRepository(),
      );

      await harness.seedCapture(
        content: '前天：开会很烦',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      );
      await harness.seedCapture(
        content: '今天：还是被打断',
        createdAt: DateTime.now(),
      );

      final summary = await harness.repository.fetchMemorySummary();

      expect(summary, isNotNull);
      expect(summary!.patterns, isNotEmpty);
      expect(summary.frictions, isNotEmpty);
      expect(summary.desires, isNotEmpty);
      expect(summary.experiments, isNotEmpty);

      await harness.close();
    });

    test('5) 第 1 天不展示 Journey（返回 null）', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeJourneyAiRepository(),
      );

      await harness.seedCapture(
        content: '今天第一条记录',
        createdAt: DateTime.now(),
      );

      final summary = await harness.repository.fetchMemorySummary();
      expect(summary, isNull);

      await harness.close();
    });
  });
}

class _Harness {
  final LocalDatabase localDatabase;
  final MemoryRepository repository;

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
}) async {
  final localDatabase = LocalDatabase(
    dbPathOverride: dbPath,
    databaseFactoryOverride: databaseFactoryFfi,
  );
  await localDatabase.init();

  final localCaptureRepository = LocalCaptureRepository(localDatabase);
  final localJourneySnapshotRepository =
      LocalJourneySnapshotRepository(localDatabase);

  final repository = MemoryRepository(
    localCaptureRepository: localCaptureRepository,
    localJourneySnapshotRepository: localJourneySnapshotRepository,
    aiRepository: aiRepository,
    focusAreaLoader: () async => null,
  );

  return _Harness(
    localDatabase: localDatabase,
    repository: repository,
  );
}

typedef JourneyBuilder =
    MemorySummaryModel Function({
      required String snapshotDate,
      required List<Map<String, dynamic>> entries,
      required List<String> topTokens,
      required int totalDays,
    });

class FakeJourneyAiRepository extends AiRepository {
  final JourneyBuilder? builder;

  FakeJourneyAiRepository({
    this.builder,
  }) : super(
          ApiClient(
            baseUrl: 'https://example.invalid',
            userId: 'test-user',
          ),
        );

  @override
  Future<MemorySummaryModel> generateJourneySummary({
    required String snapshotDate,
    required List<Map<String, dynamic>> entries,
    required List<String> topTokens,
    required int totalDays,
    String? focusArea,
  }) async {
    if (builder != null) {
      return builder!(
        snapshotDate: snapshotDate,
        entries: entries,
        topTokens: topTokens,
        totalDays: totalDays,
      );
    }

    return MemorySummaryModel(
      patterns: const [
        {
          'name': '长期重复主题',
          'summary': 'Journey 已经能从本地历史记录里看到重复线索。',
        },
      ],
      frictions: const [
        {
          'name': '持续摩擦',
          'summary': '有些消耗已经不是一次性的，而在慢慢累积。',
        },
      ],
      desires: const [
        {
          'name': '还在浮现的方向',
          'summary': '更长期真正重要的东西，开始慢慢浮出来。',
        },
      ],
      experiments: const [
        {
          'name': '开始有帮助的东西',
          'summary': 'Journey 已经可以看到某些做法慢慢变得有帮助。',
        },
      ],
    );
  }
}

class CountingJourneyAiRepository extends AiRepository {
  int callCount = 0;

  CountingJourneyAiRepository()
      : super(
          ApiClient(
            baseUrl: 'https://example.invalid',
            userId: 'test-user',
          ),
        );

  @override
  Future<MemorySummaryModel> generateJourneySummary({
    required String snapshotDate,
    required List<Map<String, dynamic>> entries,
    required List<String> topTokens,
    required int totalDays,
    String? focusArea,
  }) async {
    callCount += 1;

    return MemorySummaryModel(
      patterns: const [
        {
          'name': '缓存命中 pattern',
          'summary': '第一次生成后，第二次进入应直接读取本地缓存。',
        },
      ],
      frictions: const [
        {
          'name': '缓存命中 friction',
          'summary': 'Journey 结果会被本地缓存。',
        },
      ],
      desires: const [
        {
          'name': '缓存命中 desire',
          'summary': '这里也来自第一次生成后的本地缓存。',
        },
      ],
      experiments: const [
        {
          'name': '缓存命中 experiment',
          'summary': '第二次进入不应再次调用在线生成。',
        },
      ],
    );
  }
}

class FailingJourneyAiRepository extends AiRepository {
  FailingJourneyAiRepository()
      : super(
          ApiClient(
            baseUrl: 'https://example.invalid',
            userId: 'test-user',
          ),
        );

  @override
  Future<MemorySummaryModel> generateJourneySummary({
    required String snapshotDate,
    required List<Map<String, dynamic>> entries,
    required List<String> topTokens,
    required int totalDays,
    String? focusArea,
  }) async {
    throw Exception('Simulated journey remote failure');
  }
}
