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

  group('MemoryRepository first-day and local-first behavior', () {
    test('1) 第 1 天且没有本地记录时，Journey 返回 firstDayGate', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeJourneyAiRepository(),
        installationDate: DateTime.now(),
      );

      final result = await harness.repository.fetchMemorySummaryResult();

      expect(result.isFirstDayGate, true);
      expect(result.summary, isNull);

      await harness.close();
    });

    test('2) 第 1 天只要有本地记录，Journey 就正常展示', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeJourneyAiRepository(),
        installationDate: DateTime.now(),
      );

      await harness.seedCapture(
        content: '今天第一条记录',
        createdAt: DateTime.now(),
      );

      final result = await harness.repository.fetchMemorySummaryResult();

      expect(result.isFirstDayGate, false);
      expect(result.summary, isNotNull);
      expect(result.summary!.patterns, isNotEmpty);

      await harness.close();
    });

    test('3) 第 2 天以后没有本地记录时，Journey 返回普通空态', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeJourneyAiRepository(),
        installationDate: DateTime.now().subtract(const Duration(days: 1)),
      );

      final result = await harness.repository.fetchMemorySummaryResult();

      expect(result.isFirstDayGate, false);
      expect(result.summary, isNull);

      await harness.close();
    });

    test('4) 第 2 天以后只要有本地记录，Journey 就正常展示', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeJourneyAiRepository(),
        installationDate: DateTime.now().subtract(const Duration(days: 1)),
      );

      await harness.seedCapture(
        content: '昨天：有点烦',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      await harness.seedCapture(
        content: '今天：还是烦',
        createdAt: DateTime.now(),
      );

      final result = await harness.repository.fetchMemorySummaryResult();

      expect(result.isFirstDayGate, false);
      expect(result.summary, isNotNull);
      expect(result.summary!.frictions, isNotEmpty);

      await harness.close();
    });

    test('5) Journey 会把线索分成 weak / repeated / stable 三层', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeJourneyAiRepositoryWithoutSignalLevels(),
        installationDate: DateTime.now().subtract(const Duration(days: 2)),
      );

      await harness.seedCapture(
        content: '前天：工作很烦',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      );
      await harness.seedCapture(
        content: '昨天：开会又被打断',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      await harness.seedCapture(
        content: '今天：还是被打断',
        createdAt: DateTime.now(),
      );
      await harness.seedCapture(
        content: '今天：下午也很烦',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      );

      final result = await harness.repository.fetchMemorySummaryResult();

      expect(result.summary, isNotNull);
      expect(result.summary!.patterns.first.signalLevel, 'stable_mode');
      expect(result.summary!.frictions.first.signalLevel, 'repeated_pattern');

      await harness.close();
    });

    test('6) 再次进入 Journey 时，结果能从本地缓存读取', () async {
      final countingAi = CountingJourneyAiRepository();

      final harness1 = await _createHarness(
        dbPath: dbPath,
        aiRepository: countingAi,
        installationDate: DateTime.now().subtract(const Duration(days: 1)),
      );

      await harness1.seedCapture(
        content: '前天：工作很烦',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      await harness1.seedCapture(
        content: '今天：又烦了',
        createdAt: DateTime.now(),
      );

      final result1 = await harness1.repository.fetchMemorySummaryResult();
      expect(result1.summary, isNotNull);
      expect(countingAi.callCount, 1);

      await harness1.close();

      final harness2 = await _createHarness(
        dbPath: dbPath,
        aiRepository: countingAi,
        installationDate: DateTime.now().subtract(const Duration(days: 1)),
      );

      final result2 = await harness2.repository.fetchMemorySummaryResult();
      expect(result2.summary, isNotNull);
      expect(countingAi.callCount, 1);

      await harness2.close();
    });

    test('7) 在线生成失败时，Journey 仍然返回 fallback 结果', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FailingJourneyAiRepository(),
        installationDate: DateTime.now().subtract(const Duration(days: 1)),
      );

      await harness.seedCapture(
        content: '今天：被打断了',
        createdAt: DateTime.now(),
      );

      final result = await harness.repository.fetchMemorySummaryResult();

      expect(result.summary, isNotNull);
      expect(result.summary!.patterns, isNotEmpty);
      expect(result.summary!.frictions, isNotEmpty);
      expect(result.summary!.desires, isNotEmpty);
      expect(result.summary!.experiments, isNotEmpty);
      expect(
        {'weak_signal', 'repeated_pattern', 'stable_mode'}
            .contains(result.summary!.patterns.first.signalLevel),
        isTrue,
      );

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
  final localJourneySnapshotRepository =
      LocalJourneySnapshotRepository(localDatabase);

  final repository = MemoryRepository(
    localCaptureRepository: localCaptureRepository,
    localJourneySnapshotRepository: localJourneySnapshotRepository,
    aiRepository: aiRepository,
    focusAreaLoader: () async => null,
    installationDateLoader: () async => installationDate,
  );

  return _Harness(
    localDatabase: localDatabase,
    repository: repository,
  );
}

class FakeJourneyAiRepository extends AiRepository {
  FakeJourneyAiRepository()
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
    return MemorySummaryModel(
      patterns: const [
        JourneySignalItemModel(
          name: '长期重复主题',
          summary: 'Journey 已经能从本地历史记录里看到重复线索。',
          signalLevel: 'repeated_pattern',
        ),
      ],
      frictions: const [
        JourneySignalItemModel(
          name: '持续摩擦',
          summary: '有些消耗已经不是一次性的，而在慢慢累积。',
          signalLevel: 'repeated_pattern',
        ),
      ],
      desires: const [
        JourneySignalItemModel(
          name: '还在浮现的方向',
          summary: '更长期真正重要的东西，开始慢慢浮出来。',
          signalLevel: 'weak_signal',
        ),
      ],
      experiments: const [
        JourneySignalItemModel(
          name: '开始有帮助的东西',
          summary: 'Journey 已经可以看到某些做法慢慢变得有帮助。',
          signalLevel: 'weak_signal',
        ),
      ],
    );
  }
}

class FakeJourneyAiRepositoryWithoutSignalLevels extends AiRepository {
  FakeJourneyAiRepositoryWithoutSignalLevels()
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
    return MemorySummaryModel(
      patterns: const [
        JourneySignalItemModel(
          name: '长期重复主题',
          summary: '已经开始出现重复线索。',
          signalLevel: '',
        ),
      ],
      frictions: const [
        JourneySignalItemModel(
          name: '持续摩擦',
          summary: '一些问题在慢慢累积。',
          signalLevel: '',
        ),
      ],
      desires: const [
        JourneySignalItemModel(
          name: '还在浮现的方向',
          summary: '慢慢浮出来了。',
          signalLevel: '',
        ),
      ],
      experiments: const [
        JourneySignalItemModel(
          name: '开始有帮助的东西',
          summary: '开始起作用。',
          signalLevel: '',
        ),
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
        JourneySignalItemModel(
          name: '缓存命中 pattern',
          summary: '第一次生成后，第二次进入应直接读取本地缓存。',
          signalLevel: 'repeated_pattern',
        ),
      ],
      frictions: const [
        JourneySignalItemModel(
          name: '缓存命中 friction',
          summary: 'Journey 结果会被本地缓存。',
          signalLevel: 'repeated_pattern',
        ),
      ],
      desires: const [
        JourneySignalItemModel(
          name: '缓存命中 desire',
          summary: '这里也来自第一次生成后的本地缓存。',
          signalLevel: 'weak_signal',
        ),
      ],
      experiments: const [
        JourneySignalItemModel(
          name: '缓存命中 experiment',
          summary: '第二次进入不应再次调用在线生成。',
          signalLevel: 'weak_signal',
        ),
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
