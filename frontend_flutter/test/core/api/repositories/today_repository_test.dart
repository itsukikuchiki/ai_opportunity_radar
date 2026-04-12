import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_opportunity_radar/core/api/api_client.dart';
import 'package:ai_opportunity_radar/core/api/repositories/ai_repository.dart';
import 'package:ai_opportunity_radar/core/api/repositories/today_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_capture_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_daily_snapshot_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/models/today_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String dbPath;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ai_radar_today_test_');
    dbPath = p.join(tempDir.path, 'today_test.db');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('TodayRepository local-first behavior', () {
    test('1) 输入一条后，重建 repository（模拟重启）后今天记录仍在', () async {
      final harness1 = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeAiRepository(),
      );

      await harness1.repository.submitCapture(content: '今天上班很烦');

      final firstRead = await harness1.repository.fetchToday();
      final firstSignals =
          (firstRead['recentSignals'] as List<RecentSignalModel>? ?? const []);
      expect(firstSignals.length, 1);
      expect(firstSignals.first.content, '今天上班很烦');

      await harness1.close();

      final harness2 = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeAiRepository(),
      );

      final secondRead = await harness2.repository.fetchToday();
      final secondSignals =
          (secondRead['recentSignals'] as List<RecentSignalModel>? ?? const []);
      expect(secondSignals.length, 1);
      expect(secondSignals.first.content, '今天上班很烦');

      await harness2.close();
    });

    test('2) 每条记录的 AI 回复会保存下来', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeAiRepository(
          captureReply: '我看见你今天已经很用力了，先把这条放在这里。',
        ),
      );

      await harness.repository.submitCapture(content: '今天上班很烦');

      final data = await harness.repository.fetchToday();
      final signals =
          (data['recentSignals'] as List<RecentSignalModel>? ?? const []);

      expect(signals, isNotEmpty);
      expect(
        signals.first.acknowledgement,
        '我看见你今天已经很用力了，先把这条放在这里。',
      );

      await harness.close();
    });

    test('3) 今天的小观察 / 今天可以先试试会跟着更新', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeAiRepository(
          captureReply: '先记下来了。',
          todayObservationBuilder: (entries) => '今天记录了 ${entries.length} 条，烦躁主要集中在工作里。',
          todaySuggestionBuilder: (entries) => '今天先试试：再出现一次同类情绪时补记一条。',
        ),
      );

      await harness.repository.submitCapture(content: '第一条：有点烦');
      var data = await harness.repository.fetchToday();

      expect((data['insight'] as TodayInsightModel).text, contains('今天记录了 1 条'));
      expect((data['bestAction'] as DailyBestActionModel).text, contains('今天先试试'));

      await harness.repository.submitCapture(content: '第二条：还是烦');
      data = await harness.repository.fetchToday();

      expect((data['insight'] as TodayInsightModel).text, contains('今天记录了 2 条'));
      expect((data['bestAction'] as DailyBestActionModel).text, contains('补记一条'));

      await harness.close();
    });

    test('4) 即使线上数据库是空的 / 在线生成失败，Today 仍然正常', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FailingAiRepository(),
      );

      await harness.repository.submitCapture(content: '今天开会很累');

      final data = await harness.repository.fetchToday();
      final signals =
          (data['recentSignals'] as List<RecentSignalModel>? ?? const []);

      expect(signals.length, 1);
      expect(signals.first.content, '今天开会很累');

      final insight = data['insight'] as TodayInsightModel;
      final bestAction = data['bestAction'] as DailyBestActionModel;

      expect(insight.text.isNotEmpty, true);
      expect(bestAction.text.isNotEmpty, true);

      await harness.close();
    });
  });
}

class _Harness {
  final LocalDatabase localDatabase;
  final TodayRepository repository;

  _Harness({
    required this.localDatabase,
    required this.repository,
  });

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
  final localDailySnapshotRepository =
      LocalDailySnapshotRepository(localDatabase);

  final repository = TodayRepository(
    localCaptureRepository: localCaptureRepository,
    localDailySnapshotRepository: localDailySnapshotRepository,
    aiRepository: aiRepository,
    focusAreaLoader: () async => null,
  );

  return _Harness(
    localDatabase: localDatabase,
    repository: repository,
  );
}

class FakeAiRepository extends AiRepository {
  final String captureReply;
  final String Function(List<Map<String, dynamic>> entries)? todayObservationBuilder;
  final String Function(List<Map<String, dynamic>> entries)? todaySuggestionBuilder;

  FakeAiRepository({
    this.captureReply = '默认 AI 回复：我先陪你把这条放在这里。',
    this.todayObservationBuilder,
    this.todaySuggestionBuilder,
  }) : super(
          ApiClient(
            baseUrl: 'https://example.invalid',
            userId: 'test-user',
          ),
        );

  @override
  Future<AiCaptureReplyResult> generateCaptureReply({
    required String content,
    required List<String> recentAssistantTexts,
    String? focusArea,
  }) async {
    return AiCaptureReplyResult(
      acknowledgement: captureReply,
      followup: null,
    );
  }

  @override
  Future<AiTodaySummaryResult> generateTodaySummary({
    required DateTime date,
    required List<RecentSignalModel> entries,
    String? focusArea,
  }) async {
    final payload = entries
        .map(
          (e) => {
            'id': e.id,
            'content': e.content,
            'createdAt': e.createdAt?.toIso8601String(),
            'acknowledgement': e.acknowledgement,
          },
        )
        .toList();

    return AiTodaySummaryResult(
      observation: todayObservationBuilder?.call(payload) ??
          '今天记录了 ${entries.length} 条，已经开始形成线索。',
      suggestion: todaySuggestionBuilder?.call(payload) ??
          '今天先试试：再出现一次同类情况时补记一条。',
    );
  }
}

class FailingAiRepository extends AiRepository {
  FailingAiRepository()
      : super(
          ApiClient(
            baseUrl: 'https://example.invalid',
            userId: 'test-user',
          ),
        );

  @override
  Future<AiCaptureReplyResult> generateCaptureReply({
    required String content,
    required List<String> recentAssistantTexts,
    String? focusArea,
  }) async {
    throw Exception('Simulated remote failure');
  }

  @override
  Future<AiTodaySummaryResult> generateTodaySummary({
    required DateTime date,
    required List<RecentSignalModel> entries,
    String? focusArea,
  }) async {
    throw Exception('Simulated remote failure');
  }
}
