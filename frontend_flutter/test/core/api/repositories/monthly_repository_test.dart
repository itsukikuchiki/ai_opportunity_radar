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
import 'package:ai_opportunity_radar/core/i18n/app_locale_text.dart';
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

      await harness.seedSignalCard(content: '今天开会被打断');

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

      await harness1.seedSignalCard(content: '这个月开会很密');

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

      await harness.seedSignalCard(content: '今天上班一直被打断');

      final monthly = await harness.repository.fetchCurrentMonthly();

      expect(monthly.status, 'ready');
      expect(monthly.monthlySummary, isNotNull);
      expect(monthly.repeatedThemes, isNotEmpty);

      await harness.close();
    });

    test('5) fallback 会跟随四种界面语言，并保留原始内容', () async {
      final expectations = <AppLanguage, String>{
        AppLanguage.english: 'kept returning this month',
        AppLanguage.simplifiedChinese: '这个月反复回来',
        AppLanguage.traditionalChinese: '這個月反覆出現',
        AppLanguage.japanese: '繰り返し現れ',
      };

      for (final entry in expectations.entries) {
        final harness = await _createHarness(
          dbPath: p.join(tempDir.path, 'monthly_${entry.key.name}.db'),
          aiRepository: FailingMonthlyAiRepository(),
          installationDate: DateTime.now().subtract(const Duration(days: 35)),
          language: entry.key,
        );

        await harness.seedSignalCard(content: 'rap');
        final monthly = await harness.repository.fetchCurrentMonthly();

        expect(monthly.monthlySummary, contains('rap'));
        expect(monthly.monthlySummary, contains(entry.value));
        expect(monthly.repeatedThemes, isNotEmpty);

        await harness.close();
      }
    });

    test('6) AI 返回错误语言时改用当前语言 fallback', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeMonthlyAiRepository(),
        installationDate: DateTime.now().subtract(const Duration(days: 35)),
        language: AppLanguage.japanese,
      );

      await harness.seedSignalCard(content: '今日は会議が多かった');
      final monthly = await harness.repository.fetchCurrentMonthly();

      expect(monthly.monthlySummary, contains('繰り返し現れ'));
      expect(monthly.monthlySummary, isNot(contains('kept returning')));

      await harness.close();
    });

    test('7) 切换界面语言后不会复用旧语言缓存', () async {
      final countingAi = CountingMonthlyAiRepository();
      final installationDate =
          DateTime.now().subtract(const Duration(days: 35));

      final englishHarness = await _createHarness(
        dbPath: dbPath,
        aiRepository: countingAi,
        installationDate: installationDate,
        language: AppLanguage.english,
      );
      await englishHarness.seedSignalCard(content: 'rap');
      final english = await englishHarness.repository.fetchCurrentMonthly();
      expect(english.monthlySummary, contains('keeps circling'));
      expect(countingAi.callCount, 1);
      await englishHarness.close();

      final japaneseHarness = await _createHarness(
        dbPath: dbPath,
        aiRepository: countingAi,
        installationDate: installationDate,
        language: AppLanguage.japanese,
      );
      final japanese = await japaneseHarness.repository.fetchCurrentMonthly();

      expect(japanese.monthlySummary, contains('繰り返し現れ'));
      expect(countingAi.callCount, 2);
      await japaneseHarness.close();
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

  Future<void> seedSignalCard({required String content}) async {
    await LocalCaptureRepository(localDatabase).insertConfirmedSignalCard(
      content: content,
      sourceType: 'text',
      language: 'zh-Hans',
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
  AppLanguage language = AppLanguage.english,
}) async {
  final localDatabase = LocalDatabase(
    dbPathOverride: dbPath,
    databaseFactoryOverride: databaseFactoryFfi,
  );
  await localDatabase.init();

  final repository = MonthlyRepository(
    localCaptureRepository: LocalCaptureRepository(localDatabase),
    localMonthlySnapshotRepository:
        LocalMonthlySnapshotRepository(localDatabase),
    aiRepository: aiRepository,
    focusAreaLoader: () async => null,
    installationDateLoader: () async => installationDate,
    languageLoader: () => language,
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
      improvingSignals: const [
        'Short recovery walks are helping a little more often.'
      ],
      unresolvedPoints: const [
        'Meeting-heavy days still drain energy quickly.'
      ],
      nextMonthWatch:
          'Watch which situation triggers the first drop in energy.',
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
