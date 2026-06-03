import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_opportunity_radar/core/api/api_client.dart';
import 'package:ai_opportunity_radar/core/api/repositories/ai_repository.dart';
import 'package:ai_opportunity_radar/core/api/repositories/weekly_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_capture_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/local/local_life_experiment_repository.dart';
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

      await harness.seedSignalCard(
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

      await harness.seedSignalCard(
        content: '今天开会被打断',
        createdAt: DateTime.now(),
      );

      final weekly = await harness.repository.fetchCurrentWeekly();

      expect(weekly.status, 'light_ready');
      expect(weekly.patterns, isNotEmpty);

      await harness.close();
    });

    test('4b) 第 2 天只有前一天 1 条信号时，Weekly 仍必须返回 light_ready', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeWeeklyAiRepository(),
        installationDate: DateTime.now().subtract(const Duration(days: 1)),
      );

      await harness.seedSignalCard(
        content: '昨天先留下了一条信号',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      );

      final weekly = await harness.repository.fetchCurrentWeekly();

      expect(weekly.status, 'light_ready');
      expect(weekly.keyInsight, isNotNull);
      expect(weekly.bestAction, isNotNull);

      await harness.close();
    });

    test('5) 第 2 天即使达到较完整数据，Weekly 仍保持 light_ready', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeWeeklyAiRepository(),
        installationDate: DateTime.now().subtract(const Duration(days: 1)),
      );

      final now = DateTime.now();
      await harness.seedSignalCard(
        content: '今天上班很烦',
        createdAt: now,
      );
      await harness.seedSignalCard(
        content: '下午又被打断',
        createdAt: now.subtract(const Duration(hours: 1)),
      );
      await harness.seedSignalCard(
        content: '昨天还是烦',
        createdAt: now.subtract(const Duration(days: 1)),
      );
      await harness.seedSignalCard(
        content: '昨天开会也很累',
        createdAt: now.subtract(const Duration(days: 1, hours: 2)),
      );

      final weekly = await harness.repository.fetchCurrentWeekly();

      expect(weekly.status, 'light_ready');
      expect(weekly.patterns, isNotEmpty);

      await harness.close();
    });

    test('5b) 满 7 天且达到较完整数据时，Weekly 返回 ready', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeWeeklyAiRepository(),
        installationDate: DateTime.now().subtract(const Duration(days: 6)),
      );

      final now = DateTime.now();
      await harness.seedSignalCard(content: '今天上班很烦', createdAt: now);
      await harness.seedSignalCard(
        content: '下午又被打断',
        createdAt: now.subtract(const Duration(hours: 1)),
      );
      await harness.seedSignalCard(
        content: '昨天还是烦',
        createdAt: now.subtract(const Duration(days: 1)),
      );
      await harness.seedSignalCard(
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

      await harness1.seedSignalCard(
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

      await harness.seedSignalCard(
        content: '今天上班很烦',
        createdAt: DateTime.now(),
      );

      final weekly = await harness.repository.fetchCurrentWeekly();

      expect(weekly.status, 'light_ready');
      expect(weekly.keyInsight, isNotNull);
      expect(weekly.patterns, isNotEmpty);
      expect(weekly.bestAction, isNotNull);

      final cards = await harness.listSignalCards();
      expect(cards.single['raw_text'], '今天上班很烦');

      await harness.close();
    });

    test('8) Weekly 读取 SignalCard，并标记 native eligible card', () async {
      final recordingAi = RecordingWeeklyAiRepository();
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: recordingAi,
        installationDate: DateTime.now().subtract(const Duration(days: 1)),
      );

      await harness.seedSignalCard(
        id: 'sig_native',
        content: '今天被消息打断很多次',
        createdAt: DateTime.now(),
        userConfirmation: 'accurate',
      );

      final weekly = await harness.repository.fetchCurrentWeekly();

      expect(weekly.status, 'light_ready');
      expect(recordingAi.lastEntries.map((e) => e['signal_card_id']),
          contains('sig_native'));
      expect(await harness.includedInWeekly('sig_native'), isTrue);

      await harness.close();
    });

    test('9) Weekly 按 SignalCard.local_date 计算本周边界，不按 UTC 错分', () async {
      final recordingAi = RecordingWeeklyAiRepository();
      final now = DateTime.now();
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: recordingAi,
        installationDate: now.subtract(const Duration(days: 1)),
      );

      final localWeekStart = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 6));
      await harness.seedSignalCard(
        id: 'sig_boundary',
        content: '午夜前后还有工作消息',
        createdAt: DateTime.utc(
          localWeekStart.year,
          localWeekStart.month,
          localWeekStart.day,
        ).subtract(const Duration(hours: 3)),
        localDate: _dateKey(localWeekStart),
        timezone: 'Asia/Tokyo',
      );

      await harness.repository.fetchCurrentWeekly();

      expect(recordingAi.lastDayCounts[_dateKey(localWeekStart)], 1);
      expect(recordingAi.lastEntries.single['local_date'],
          _dateKey(localWeekStart));

      await harness.close();
    });

    test('10) legacy/unconfirmed 可作为低置信参考，inaccurate 不进入 Weekly', () async {
      final recordingAi = RecordingWeeklyAiRepository();
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: recordingAi,
        installationDate: DateTime.now().subtract(const Duration(days: 1)),
      );

      await harness.seedSignalCard(
        id: 'sig_legacy',
        content: '旧记录里的反复消耗',
        createdAt: DateTime.now(),
        isLegacy: true,
        migrationStatus: 'local_legacy',
      );
      await harness.seedSignalCard(
        id: 'sig_unconfirmed',
        content: '还没确认但可以小观察',
        createdAt: DateTime.now(),
      );
      await harness.seedSignalCard(
        id: 'sig_inaccurate',
        content: '用户说不准的解析',
        createdAt: DateTime.now(),
        userConfirmation: 'inaccurate',
      );

      await harness.repository.fetchCurrentWeekly();

      final ids = recordingAi.lastEntries.map((e) => e['signal_card_id']);
      expect(ids, contains('sig_legacy'));
      expect(ids, contains('sig_unconfirmed'));
      expect(ids, isNot(contains('sig_inaccurate')));
      final legacy = recordingAi.lastEntries
          .firstWhere((entry) => entry['signal_card_id'] == 'sig_legacy');
      expect(legacy['weekly_confidence'], 'legacy_reference');
      expect(await harness.includedInWeekly('sig_legacy'), isFalse);
      expect(await harness.includedInWeekly('sig_unconfirmed'), isTrue);

      await harness.close();
    });

    test('11) local draft、sync failed、隐私排除项不进入 Weekly', () async {
      final recordingAi = RecordingWeeklyAiRepository();
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: recordingAi,
        installationDate: DateTime.now().subtract(const Duration(days: 1)),
      );

      await harness.seedSignalCard(
        id: 'sig_draft',
        content: '本地 draft',
        createdAt: DateTime.now(),
        isLocalDraft: true,
      );
      await harness.seedSignalCard(
        id: 'sig_failed',
        content: '同步失败',
        createdAt: DateTime.now(),
        syncFailed: true,
      );
      await harness.seedSignalCard(
        id: 'sig_private_excluded',
        content: '不参与分析的敏感记录',
        createdAt: DateTime.now(),
        privacyLevel: 'do_not_analyze',
      );

      final weekly = await harness.repository.fetchCurrentWeekly();

      expect(weekly.status, 'insufficient_data');
      expect(recordingAi.callCount, 0);

      await harness.close();
    });

    test('11b) library_saved 需要用户补充个人语境后才进入 Weekly', () async {
      final recordingAi = RecordingWeeklyAiRepository();
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: recordingAi,
        installationDate: DateTime.now().subtract(const Duration(days: 1)),
      );

      await harness.seedSignalCard(
        id: 'library_unconfirmed',
        content: '',
        createdAt: DateTime.now(),
        sourceType: 'library_saved',
        userConfirmation: 'unconfirmed',
        rawPayloadJson: const {
          'library_pattern_id': 'over_scheduled_weeks',
          'title': 'Over-scheduled weeks',
          'abstract_pattern':
              'Some people encounter a similar structure when the week has many fixed commitments and very little space between them.',
        },
      );
      await harness.seedSignalCard(
        id: 'library_confirmed_without_context',
        content: '',
        createdAt: DateTime.now(),
        sourceType: 'library_saved',
        userConfirmation: 'accurate',
        rawPayloadJson: const {
          'library_pattern_id': 'boundary_fatigue',
          'title': 'Boundary fatigue',
          'abstract_pattern':
              'Some people feel tired not from one request, but from many small boundary decisions close together.',
        },
      );
      await harness.seedSignalCard(
        id: 'library_with_context',
        content: '',
        createdAt: DateTime.now(),
        sourceType: 'library_saved',
        userConfirmation: 'supplemented',
        userCorrectionJson: const {
          'supplement_text': 'This matched my week after I added context.',
        },
        rawPayloadJson: const {
          'library_pattern_id': 'attention_switching_fatigue',
          'title': 'Attention switching fatigue',
          'abstract_pattern':
              'Some people feel more worn down by frequent switching than by any single task.',
        },
      );

      await harness.repository.fetchCurrentWeekly();

      final ids = recordingAi.lastEntries.map((e) => e['signal_card_id']);
      expect(ids, isNot(contains('library_unconfirmed')));
      expect(ids, isNot(contains('library_confirmed_without_context')));
      expect(ids, contains('library_with_context'));
      final confirmed = recordingAi.lastEntries.firstWhere(
        (entry) => entry['signal_card_id'] == 'library_with_context',
      );
      expect(confirmed['weekly_confidence'], 'library_saved_confirmed');
      expect(confirmed['content'], contains('Attention switching fatigue'));
      expect(await harness.includedInWeekly('library_unconfirmed'), isFalse);
      expect(
        await harness.includedInWeekly('library_confirmed_without_context'),
        isFalse,
      );
      expect(await harness.includedInWeekly('library_with_context'), isTrue);

      await harness.close();
    });

    test('11c) eligible signals 定义覆盖文字、语音、AI 失败、预测和删除回退', () async {
      final recordingAi = RecordingWeeklyAiRepository();
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: recordingAi,
        installationDate: DateTime.now().subtract(const Duration(days: 1)),
      );

      await harness.seedSignalCard(
        id: 'text_raw',
        content: '文字输入算作真实信号',
        createdAt: DateTime.now(),
      );
      await harness.seedSignalCard(
        id: 'voice_transcript',
        content: '语音转写也算作真实信号',
        createdAt: DateTime.now(),
        sourceType: 'voice',
      );
      await harness.seedSignalCard(
        id: 'ai_failed_raw_saved',
        content: 'AI 失败但原文已经保存也算',
        createdAt: DateTime.now(),
      );
      await harness.seedSignalCard(
        id: 'ai_predicted_accurate_only',
        content: 'AI 轻建议本身不算原始信号',
        createdAt: DateTime.now(),
        sourceType: 'ai_predicted',
        userConfirmation: 'accurate',
      );
      await harness.seedSignalCard(
        id: 'ai_predicted_with_context',
        content: 'AI 预测加上自己的语境后才算',
        createdAt: DateTime.now(),
        sourceType: 'ai_predicted',
        userConfirmation: 'supplemented',
        userCorrectionJson: const {
          'supplement_text': '我补充了自己的具体情况。',
        },
      );
      await harness.seedSignalCard(
        id: 'library_default',
        content: '',
        createdAt: DateTime.now(),
        sourceType: 'library_saved',
        userConfirmation: 'accurate',
        rawPayloadJson: const {
          'title': 'Recovery debt',
          'abstract_pattern':
              'Some people notice rest starts feeling like something to catch up on.',
        },
      );
      await harness.seedSignalCard(
        id: 'library_with_context',
        content: '',
        createdAt: DateTime.now(),
        sourceType: 'library_saved',
        userConfirmation: 'edited',
        userCorrectionJson: const {
          'edited_text': '这个模式像我这周连续晚睡后的状态。',
        },
        rawPayloadJson: const {
          'title': 'Recovery debt',
          'abstract_pattern':
              'Some people notice rest starts feeling like something to catch up on.',
        },
      );

      await harness.repository.fetchCurrentWeekly();
      final ids = recordingAi.lastEntries.map((e) => e['signal_card_id']);

      expect(
          ids,
          containsAll([
            'text_raw',
            'voice_transcript',
            'ai_failed_raw_saved',
            'ai_predicted_with_context',
            'library_with_context',
          ]));
      expect(ids, isNot(contains('ai_predicted_accurate_only')));
      expect(ids, isNot(contains('library_default')));

      await harness.deleteSignalCard('text_raw');
      await harness.deleteSignalCard('voice_transcript');
      await harness.deleteSignalCard('ai_failed_raw_saved');
      await harness.deleteSignalCard('ai_predicted_with_context');
      await harness.deleteSignalCard('library_with_context');

      final weeklyAfterDelete = await harness.repository.fetchCurrentWeekly();
      expect(weeklyAfterDelete.status, 'insufficient_data');

      await harness.close();
    });

    test('12) Weekly 输出只保留一个 pattern 和一个小实验', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: MultiPatternWeeklyAiRepository(),
        installationDate: DateTime.now().subtract(const Duration(days: 6)),
      );

      final now = DateTime.now();
      await harness.seedSignalCard(content: '上午开会很累', createdAt: now);
      await harness.seedSignalCard(
        content: '下午消息切换很多',
        createdAt: now.subtract(const Duration(hours: 2)),
      );
      await harness.seedSignalCard(
        content: '昨天安排过密',
        createdAt: now.subtract(const Duration(days: 1)),
      );
      await harness.seedSignalCard(
        content: '昨天晚上散步之后恢复一点',
        createdAt: now.subtract(const Duration(days: 1, hours: 2)),
      );

      final weekly = await harness.repository.fetchCurrentWeekly();

      expect(weekly.status, 'ready');
      expect(weekly.patterns, hasLength(1));
      expect(weekly.frictions, hasLength(1));
      expect(weekly.bestAction, contains('可以'));
      expect(weekly.bestAction, isNot(contains('必须')));
      expect(weekly.bestAction, isNot(contains('失败')));
      expect(weekly.deriveV3CStructure().oneExperiment, contains('可以'));

      await harness.close();
    });

    test('13) Weekly metadata 带 inclusion summary 给用户侧说明', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeWeeklyAiRepository(),
        installationDate: DateTime.now().subtract(const Duration(days: 1)),
      );

      await harness.seedSignalCard(
        id: 'sig_used',
        content: '今天安排过密',
        createdAt: DateTime.now(),
      );
      await harness.seedSignalCard(
        id: 'sig_excluded',
        content: '这条只留在时间线',
        createdAt: DateTime.now(),
        userConfirmation: 'inaccurate',
      );

      final weekly = await harness.repository.fetchCurrentWeekly();
      final inclusion = weekly.inclusionSummary;

      expect(inclusion.usedCount, 1);
      expect(inclusion.timelineOnlyCount, 1);
      expect(inclusion.excludedCount, 1);

      await harness.close();
    });

    test('14) Weekly one-experiment 会创建 suggested Life Experiment', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeWeeklyAiRepository(),
        installationDate: DateTime.now().subtract(const Duration(days: 1)),
      );

      await harness.seedSignalCard(
        id: 'sig_experiment',
        content: '今天被消息打断很多次',
        createdAt: DateTime.now(),
      );

      final weekly = await harness.repository.fetchCurrentWeekly();
      final experiment = weekly.lifeExperiment;

      expect(experiment, isNotNull);
      expect(experiment!.status, 'suggested');
      expect(experiment.sourceWeekStart, weekly.weekStart);
      expect(experiment.suggestedAction, isNotEmpty);
      expect(experiment.linkedSignalCardIds, contains('sig_experiment'));

      await harness.close();
    });

    test('15) Experiment save / skip / feedback 会写入本地', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeWeeklyAiRepository(),
        installationDate: DateTime.now().subtract(const Duration(days: 1)),
      );

      await harness.seedSignalCard(
        id: 'sig_save',
        content: '今天安排过密',
        createdAt: DateTime.now(),
      );

      final weekly = await harness.repository.fetchCurrentWeekly();
      final experiment = weekly.lifeExperiment!;

      final saved = await harness.repository.saveLifeExperiment(experiment.id);
      expect(saved?.status, 'saved');
      expect(await harness.linkedExperimentId('sig_save'), experiment.id);

      final feedback = await harness.repository.submitLifeExperimentFeedback(
        experimentId: experiment.id,
        status: 'not_helpful',
        feedbackText: 'Not helpful this time',
      );
      expect(feedback?.status, 'not_helpful');
      expect(feedback?.feedbackText, 'Not helpful this time');

      final skipped =
          await harness.repository.skipLifeExperiment(experiment.id);
      expect(skipped?.status, 'skipped');

      await harness.close();
    });

    test('16) excluded / inaccurate / sync failed 不进入 experiment linkage',
        () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeWeeklyAiRepository(),
        installationDate: DateTime.now().subtract(const Duration(days: 1)),
      );

      await harness.seedSignalCard(
        id: 'sig_used_for_exp',
        content: '今天开会很累',
        createdAt: DateTime.now(),
      );
      await harness.seedSignalCard(
        id: 'sig_bad_parse',
        content: '不准的解析',
        createdAt: DateTime.now(),
        userConfirmation: 'inaccurate',
      );
      await harness.seedSignalCard(
        id: 'sig_sync_failed',
        content: '同步失败记录',
        createdAt: DateTime.now(),
        syncFailed: true,
      );
      await harness.seedSignalCard(
        id: 'sig_legacy_ref',
        content: '旧记录只作背景',
        createdAt: DateTime.now(),
        isLegacy: true,
      );

      final weekly = await harness.repository.fetchCurrentWeekly();
      final linked = weekly.lifeExperiment!.linkedSignalCardIds;

      expect(linked, contains('sig_used_for_exp'));
      expect(linked, isNot(contains('sig_bad_parse')));
      expect(linked, isNot(contains('sig_sync_failed')));
      expect(linked, isNot(contains('sig_legacy_ref')));

      await harness.close();
    });

    test('17) Experiment feedback 不影响 SignalCard 保存', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeWeeklyAiRepository(),
        installationDate: DateTime.now().subtract(const Duration(days: 1)),
      );

      await harness.seedSignalCard(
        id: 'sig_kept',
        content: '原始记录不能消失',
        createdAt: DateTime.now(),
      );

      final weekly = await harness.repository.fetchCurrentWeekly();
      await harness.repository.submitLifeExperimentFeedback(
        experimentId: weekly.lifeExperiment!.id,
        status: 'adjusted',
        feedbackText: 'Needs adjustment',
      );

      final cards = await harness.listSignalCards();
      expect(
        cards.singleWhere((row) => row['id'] == 'sig_kept')['raw_text'],
        '原始记录不能消失',
      );

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

  Future<void> seedSignalCard({
    String? id,
    required String content,
    required DateTime createdAt,
    String? localDate,
    String timezone = 'Asia/Tokyo',
    String sourceType = 'text',
    String userConfirmation = 'unconfirmed',
    Map<String, dynamic> userCorrectionJson = const {},
    Map<String, dynamic> rawPayloadJson = const {},
    bool isLegacy = false,
    String migrationStatus = 'native',
    bool isLocalDraft = false,
    bool syncFailed = false,
    String privacyLevel = 'private',
  }) async {
    final db = await localDatabase.database;
    final stableId =
        id ?? 'sig_${createdAt.microsecondsSinceEpoch}_${content.hashCode}';

    await db.insert(
      'signal_cards',
      {
        'id': stableId,
        'signal_card_id': stableId,
        'raw_memory_id': null,
        'capture_id': null,
        'source_type': sourceType,
        'raw_text': content,
        'created_at': createdAt.toUtc().toIso8601String(),
        'local_date': localDate ?? _dateKey(createdAt),
        'timezone': timezone,
        'language': 'zh-Hans',
        'ai_reply': '我听见了，这条先保存下来。',
        'observation': '这是一条 Weekly 测试观察。',
        'try_next': '先轻轻记一下场景。',
        'emotion': 'negative',
        'intensity': 'medium',
        'scene': 'work',
        'friction': 'context_switch',
        'positive_signal': null,
        'energy_load': 'draining',
        'scene_tags_json': '["work"]',
        'intent_tags_json': '["observe"]',
        'user_confirmation': userConfirmation,
        'raw_payload_json': jsonEncode(rawPayloadJson),
        'user_correction_json': jsonEncode(userCorrectionJson),
        'included_in_summary': 0,
        'included_in_weekly': 0,
        'included_in_journey': 0,
        'linked_experiment_id': null,
        'privacy_level': privacyLevel,
        'is_legacy': isLegacy ? 1 : 0,
        'migration_status': migrationStatus,
        'is_local_draft': isLocalDraft ? 1 : 0,
        'sync_failed': syncFailed ? 1 : 0,
        'sync_status': syncFailed
            ? 'failed'
            : isLocalDraft
                ? 'pending'
                : 'synced',
        'last_error': syncFailed ? 'network failed' : null,
        'updated_at': createdAt.toUtc().toIso8601String(),
      },
    );
  }

  Future<List<Map<String, Object?>>> listSignalCards() async {
    final db = await localDatabase.database;
    return db.query('signal_cards', orderBy: 'id ASC');
  }

  Future<void> deleteSignalCard(String id) async {
    final db = await localDatabase.database;
    await db.delete(
      'signal_cards',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<bool> includedInWeekly(String id) async {
    final db = await localDatabase.database;
    final rows = await db.query(
      'signal_cards',
      columns: ['included_in_weekly'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isNotEmpty && rows.first['included_in_weekly'] == 1;
  }

  Future<String?> linkedExperimentId(String id) async {
    final db = await localDatabase.database;
    final rows = await db.query(
      'signal_cards',
      columns: ['linked_experiment_id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['linked_experiment_id'] as String?;
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
  final localLifeExperimentRepository =
      LocalLifeExperimentRepository(localDatabase);

  final repository = WeeklyRepository(
    localCaptureRepository: localCaptureRepository,
    localWeeklySnapshotRepository: localWeeklySnapshotRepository,
    localLifeExperimentRepository: localLifeExperimentRepository,
    aiRepository: aiRepository,
    focusAreaLoader: () async => null,
    installationDateLoader: () async => installationDate,
    localUserId: 'test-user',
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
          'summary': 'Weekly 已经从本地 SignalCard 生成，不再依赖旧 captures 主链路。',
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

class RecordingWeeklyAiRepository extends FakeWeeklyAiRepository {
  int callCount = 0;
  List<Map<String, dynamic>> lastEntries = const [];
  Map<String, int> lastDayCounts = const {};

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
    lastEntries = entries;
    lastDayCounts = dayCounts;
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

class MultiPatternWeeklyAiRepository extends FakeWeeklyAiRepository {
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
      keyInsight: '这周可以先这样看：安排密度和切换感一起出现。',
      patterns: const [
        {
          'name': '安排过密',
          'summary': '几个记录都围绕安排太满展开。',
        },
        {
          'name': '晚间恢复不足',
          'summary': '另一个线索先放在观察区。',
        },
      ],
      frictions: const [
        {
          'name': '频繁切换',
          'summary': '切换让一天变得更散。',
        },
        {
          'name': '临时插入',
          'summary': '这一项这周先不展开。',
        },
      ],
      bestAction: '下周必须完成每天一次复盘，失败也要补上。',
      opportunitySnapshot: const {
        'name': '散步后的恢复',
        'summary': '晚上散步之后状态有一点往回收。',
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
    throw Exception('network failed');
  }
}

String _dateKey(DateTime date) {
  final local = date.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}
