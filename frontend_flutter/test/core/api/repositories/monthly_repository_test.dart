import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_opportunity_radar/core/api/api_client.dart';
import 'package:ai_opportunity_radar/core/api/repositories/ai_repository.dart';
import 'package:ai_opportunity_radar/core/api/repositories/monthly_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_capture_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/local/local_monthly_snapshot_repository.dart';
import 'package:ai_opportunity_radar/core/models/monthly_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String dbPath;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ai_radar_monthly_test_');
    dbPath = p.join(tempDir.path, 'monthly_test.db');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('MonthlyRepository behavior', () {
    test('1) 第一个月且没有本地记录时，Monthly 返回 first_month_gate', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeMonthlyAiRepository(),
        installationDate: DateTime.now(),
      );

      final monthly = await harness.repository.fetchCurrentMonthly();

      expect(monthly.status, 'first_month_gate');
      expect(monthly.monthlySummary, isNull);

      await harness.close();
    });

    test('2) 第一个月只要有本地记录，Monthly 就正常展示', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeMonthlyAiRepository(),
        installationDate: DateTime.now(),
      );

      await harness.seedCapture(
        content: '今天开会被打断',
        createdAt: DateTime.now(),
      );

      final monthly = await harness.repository.fetchCurrentMonthly();

      expect(monthly.status, 'ready');
      expect(monthly.monthlySummary, isNotNull);

      await harness.close();
    });

    test('3) 再次进入 Monthly 时，结果能从本地缓存读取', () async {
      final countingAi = CountingMonthlyAiRepository();

      final harness1 = await _createHarness(
        dbPath: dbPath,
        aiRepository: countingAi,
        installationDate: DateTime.now().subtract(const Duration(days: 35)),
      );

      await harness1.seedCapture(
        content: '这个月开会很密',
        createdAt: DateTime.now(),
      );

      final monthly1 = await harness1.repository.fetchCurrentMonthly();
      expect(monthly1.status, 'ready');
      expect(countingAi.callCount, 1);

      await harness1.close();

      final harness2 = await _createHarness(
        dbPath: dbPath,
        aiRepository: countingAi,
        installationDate: DateTime.now().subtract(const Duration(days: 35)),
      );

      final monthly2 = await harness2.repository.fetchCurrentMonthly();
      expect(monthly2.status, 'ready');
      expect(countingAi.callCount, 1);

      await harness2.close();
    });

    test('4) 在线生成失败时，Monthly 仍然返回 fallback 结果', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FailingMonthlyAiRepository(),
        installationDate: DateTime.now().subtract(const Duration(days: 35)),
      );

      await harness.seedCapture(
        content: '今天上班一直被打断',
        createdAt: DateTime.now(),
      );

      final monthly = await harness.repository.fetchCurrentMonthly();

      expect(monthly.status, 'ready');
      expect(monthly.monthlySummary, isNotNull);
      expect(monthly.repeatedThemes, isNotEmpty);

      await harness.close();
    });
  });
}

class _Harness {
  final LocalDatabase localDatabase;
  final MonthlyRepository repository;

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

  final repository = MonthlyRepository(
    localCaptureRepository: LocalCaptureRepository(localDatabase),
    localMonthlySnapshotRepository: LocalMonthlySnapshotRepository(localDatabase),
    aiRepository: aiRepository,
    focusAreaLoader: () async => null,
    installationDateLoader: () async => installationDate,
  );

  return _Harness(
    localDatabase: localDatabase,
    repository: repository,
  );
}

class FakeMonthlyAiRepository extends AiRepository {
  FakeMonthlyAiRepository()
      : super(
          ApiClient(
            baseUrl: 'https://example.invalid',
            userId: 'test-user',
          ),
        );

  @override
  Future<MonthlyReviewModel> generateMonthlyReview({
    required String monthStart,
    required String monthEnd,
    required List<Map<String, dynamic>> entries,
    required List<String> topTokens,
    String? focusArea,
    required int totalDays,
  }) async {
    return MonthlyReviewModel(
      monthStart: monthStart,
      monthEnd: monthEnd,
      status: 'ready',
      monthlySummary: 'This month keeps circling around work interruptions.',
      repeatedThemes: const ['Work interruptions keep returning.'],
      improvingSignals: const ['Short recovery walks are helping a little more often.'],
      unresolvedPoints: const ['Meeting-heavy days still drain energy quickly.'],
      nextMonthWatch: 'Watch which situation triggers the first drop in energy.',
      weeklyBridges: const [
        MonthlyBridgeWeekModel(
          label: 'Week 1',
          summary: '3 entries landed here.',
        ),
      ],
    );
  }
}

class CountingMonthlyAiRepository extends FakeMonthlyAiRepository {
  int callCount = 0;

  @override
  Future<MonthlyReviewModel> generateMonthlyReview({
    required String monthStart,
    required String monthEnd,
    required List<Map<String, dynamic>> entries,
    required List<String> topTokens,
    String? focusArea,
    required int totalDays,
  }) async {
    callCount += 1;
    return super.generateMonthlyReview(
      monthStart: monthStart,
      monthEnd: monthEnd,
      entries: entries,
      topTokens: topTokens,
      focusArea: focusArea,
      totalDays: totalDays,
    );
  }
}

class FailingMonthlyAiRepository extends AiRepository {
  FailingMonthlyAiRepository()
      : super(
          ApiClient(
            baseUrl: 'https://example.invalid',
            userId: 'test-user',
          ),
        );

  @override
  Future<MonthlyReviewModel> generateMonthlyReview({
    required String monthStart,
    required String monthEnd,
    required List<Map<String, dynamic>> entries,
    required List<String> topTokens,
    String? focusArea,
    required int totalDays,
  }) async {
    throw Exception('monthly failed');
  }
}
