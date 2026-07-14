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
import 'package:ai_opportunity_radar/core/local/local_phase3_plus_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_reflection_result_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_weekly_snapshot_repository.dart';
import 'package:ai_opportunity_radar/core/models/weekly_models.dart';

String _dateKeyForTest(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

final DateTime _testNow = DateTime(2026, 7, 8, 12);

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
        installationDate: _testNow,
      );

      final weekly = await harness.repository.fetchCurrentWeekly();

      expect(weekly.status, 'first_day_gate');
      expect(weekly.keyInsight, isNull);
      final today = _testNow;
      final localToday = DateTime(today.year, today.month, today.day);
      final monday = localToday.subtract(
        Duration(days: localToday.weekday - DateTime.monday),
      );
      expect(weekly.weekStart, _dateKey(monday));
      expect(weekly.weekEnd, _dateKey(monday.add(const Duration(days: 6))));

      await harness.close();
    });

    test('2) 第 1 天只有 1 条本地记录时，Weekly 显示明确进度空态', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeWeeklyAiRepository(),
        installationDate: _testNow,
      );

      await harness.seedSignalCard(
        content: '今天上班很烦',
        createdAt: _testNow,
      );

      final weekly = await harness.repository.fetchCurrentWeekly();

      expect(weekly.status, 'insufficient_data');
      expect(weekly.keyInsight, isNull);
      expect(weekly.reportReadiness.signalCount, 1);
      expect(weekly.reportReadiness.remainingSignals, 2);

      await harness.close();
    });

    test('3) 第 2 天以后没有本地记录时，Weekly 返回 insufficient_data', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeWeeklyAiRepository(),
        installationDate: _testNow.subtract(const Duration(days: 1)),
      );

      final weekly = await harness.repository.fetchCurrentWeekly();

      expect(weekly.status, 'insufficient_data');
      expect(weekly.keyInsight, isNull);

      await harness.close();
    });

    test('4) 第 2 天以后只有 1 条本地记录时，Weekly 仍不生成报告', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeWeeklyAiRepository(),
        installationDate: _testNow.subtract(const Duration(days: 1)),
      );

      await harness.seedSignalCard(
        content: '今天开会被打断',
        createdAt: _testNow,
      );

      final weekly = await harness.repository.fetchCurrentWeekly();

      expect(weekly.status, 'insufficient_data');
      expect(weekly.patterns, isEmpty);
      expect(weekly.reportReadiness.signalCount, 1);

      await harness.close();
    });

    test('4a) Weekly 只把当前周 SignalCard 交给 AI 输入', () async {
      final aiRepository = RecordingWeeklyAiRepository();
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: aiRepository,
        installationDate: _testNow.subtract(const Duration(days: 30)),
      );

      await harness.seedSignalCard(
        id: 'sig_old',
        content: '很久以前的旧周期记录',
        createdAt: DateTime(2020, 1, 1),
        localDate: '2020-01-01',
      );
      await harness.seedSignalCard(
        id: 'sig_current',
        content: '本周的有效记录',
        createdAt: _testNow,
      );
      await harness.seedReadinessFillers(2);

      await harness.repository.fetchCurrentWeekly();

      expect(aiRepository.lastEntries.map((entry) => entry['id']),
          contains('sig_current'));
      expect(aiRepository.lastEntries.map((entry) => entry['id']),
          isNot(contains('sig_old')));

      await harness.close();
    });

    test('4a-0) Weekly 按 period 取数，不全量扫最近 500 条', () async {
      final aiRepository = RecordingWeeklyAiRepository();
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: aiRepository,
        installationDate: _testNow.subtract(const Duration(days: 30)),
      );

      for (var i = 0; i < 520; i += 1) {
        await harness.seedSignalCard(
          id: 'old_$i',
          content: '很久以前的旧记录 $i',
          createdAt: _testNow.subtract(Duration(days: 40 + i)),
        );
      }
      await harness.seedSignalCard(
        id: 'current_period_only',
        content: '本周唯一有效记录',
        createdAt: _testNow,
      );
      await harness.seedReadinessFillers(2);

      await harness.repository.fetchCurrentWeekly();

      expect(
        aiRepository.lastEntries.map((entry) => entry['signal_card_id']),
        contains('current_period_only'),
      );
      expect(aiRepository.lastEntries, hasLength(3));

      await harness.close();
    });

    test('4a-1) Weekly excludes legacy schedule / goal feedback from core flow',
        () async {
      final aiRepository = RecordingWeeklyAiRepository();
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: aiRepository,
        installationDate: _testNow.subtract(const Duration(days: 1)),
      );
      final now = _testNow;

      await harness.seedSignalCard(
        id: 'sig_feedback_context',
        content: '今天下午会议之后明显变累',
        createdAt: now,
      );
      await harness.seedReadinessFillers(2);
      final db = await harness.localDatabase.database;
      final date = _dateKey(now);
      final timestamp = now.toUtc().toIso8601String();
      await db.insert('schedule_signals', {
        'id': 'legacy-weekly-schedule',
        'title': '下午会议',
        'local_date': date,
        'anchor_date': date,
        'date_precision': 'date',
        'time_precision': 'time',
        'feedback_status': 'recorded',
        'actual_energy_load': 'draining',
        'post_mood': 'tired',
        'friction': 'context_switching',
        'created_at': timestamp,
        'updated_at': timestamp,
      });
      await db.insert('goals', {
        'id': 'legacy-weekly-goal',
        'title': '恢复练习',
        'created_at': timestamp,
        'updated_at': timestamp,
      });
      await db.insert('goal_feedback', {
        'id': 'legacy-weekly-goal-feedback',
        'goal_id': 'legacy-weekly-goal',
        'feedback_date': date,
        'happened': 'yes',
        'effort_level': 'light',
        'effect': 'helpful',
        'comment': '做完轻一点',
        'next_adjustment': 'continue',
        'created_at': timestamp,
        'updated_at': timestamp,
      });

      final weekly = await harness.repository.fetchCurrentWeekly();
      final summary = weekly.opportunitySnapshot?['_feedback_event_summary']
          as Map<String, dynamic>?;
      final sourceTypes =
          aiRepository.lastEntries.map((entry) => entry['source_type']);

      expect(sourceTypes, isNot(contains('schedule_feedback')));
      expect(sourceTypes, isNot(contains('goal_feedback')));
      expect(summary, isNull);

      await harness.close();
    });

    test('4b) 第 2 天只有前一天 1 条信号时，Weekly 仍保持门槛空态', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeWeeklyAiRepository(),
        installationDate: _testNow.subtract(const Duration(days: 1)),
      );

      await harness.seedSignalCard(
        content: '昨天先留下了一条信号',
        createdAt: _testNow.subtract(const Duration(days: 1)),
      );

      final weekly = await harness.repository.fetchCurrentWeekly();

      expect(weekly.status, 'insufficient_data');
      expect(weekly.keyInsight, isNull);
      expect(weekly.bestAction, isNull);

      await harness.close();
    });

    test('5) 第 2 天即使达到较完整数据，Weekly 仍保持 light_ready', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeWeeklyAiRepository(),
        installationDate: _testNow.subtract(const Duration(days: 1)),
      );

      final now = _testNow;
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
        installationDate: _testNow.subtract(const Duration(days: 6)),
      );

      final now = _testNow;
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
        installationDate: _testNow.subtract(const Duration(days: 1)),
      );

      await harness1.seedSignalCard(
        content: '今天有点烦',
        createdAt: _testNow,
      );
      await harness1.seedReadinessFillers(2);

      final weekly1 = await harness1.repository.fetchCurrentWeekly();
      expect(weekly1.status, 'light_ready');
      expect(countingAi.callCount, 1);

      await harness1.close();

      final harness2 = await _createHarness(
        dbPath: dbPath,
        aiRepository: countingAi,
        installationDate: _testNow.subtract(const Duration(days: 1)),
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
        installationDate: _testNow.subtract(const Duration(days: 1)),
      );

      await harness.seedSignalCard(
        content: '今天上班很烦',
        createdAt: _testNow,
      );
      await harness.seedReadinessFillers(2);

      final weekly = await harness.repository.fetchCurrentWeekly();

      expect(weekly.status, 'light_ready');
      expect(weekly.keyInsight, isNotNull);
      expect(weekly.patterns, isNotEmpty);
      expect(weekly.bestAction, isNotNull);

      final cards = await harness.listSignalCards();
      expect(cards.map((row) => row['raw_text']), contains('今天上班很烦'));

      await harness.close();
    });

    test('8) Weekly 读取 SignalCard，并标记 native eligible card', () async {
      final recordingAi = RecordingWeeklyAiRepository();
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: recordingAi,
        installationDate: _testNow.subtract(const Duration(days: 1)),
      );

      await harness.seedSignalCard(
        id: 'sig_native',
        content: '今天被消息打断很多次',
        createdAt: _testNow,
        userConfirmation: 'accurate',
      );
      await harness.seedReadinessFillers(2);

      final weekly = await harness.repository.fetchCurrentWeekly();

      expect(weekly.status, 'light_ready');
      expect(recordingAi.lastEntries.map((e) => e['signal_card_id']),
          contains('sig_native'));
      expect(await harness.includedInWeekly('sig_native'), isTrue);

      await harness.close();
    });

    test('9) Weekly 按 SignalCard.local_date 计算本周边界，不按 UTC 错分', () async {
      final recordingAi = RecordingWeeklyAiRepository();
      final now = _testNow;
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: recordingAi,
        installationDate: now.subtract(const Duration(days: 1)),
      );

      final localToday = DateTime(now.year, now.month, now.day);
      final localWeekStart = localToday.subtract(
        Duration(days: localToday.weekday - DateTime.monday),
      );
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
      await harness.seedReadinessFillers(2);

      await harness.repository.fetchCurrentWeekly();

      expect(recordingAi.lastDayCounts[_dateKey(localWeekStart)], 1);
      expect(
        recordingAi.lastEntries
            .where((entry) => entry['signal_card_id'] == 'sig_boundary')
            .single['local_date'],
        _dateKey(localWeekStart),
      );

      await harness.close();
    });

    test('10) legacy/inaccurate 不进入 Weekly，unconfirmed 保留', () async {
      final recordingAi = RecordingWeeklyAiRepository();
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: recordingAi,
        installationDate: _testNow.subtract(const Duration(days: 1)),
      );

      await harness.seedSignalCard(
        id: 'sig_legacy',
        content: '旧记录里的反复消耗',
        createdAt: _testNow,
        isLegacy: true,
        migrationStatus: 'local_legacy',
      );
      await harness.seedSignalCard(
        id: 'sig_unconfirmed',
        content: '还没确认但可以小观察',
        createdAt: _testNow,
      );
      await harness.seedSignalCard(
        id: 'sig_inaccurate',
        content: '用户说不准的解析',
        createdAt: _testNow,
        userConfirmation: 'inaccurate',
      );
      await harness.seedReadinessFillers(2);

      await harness.repository.fetchCurrentWeekly();

      final ids = recordingAi.lastEntries.map((e) => e['signal_card_id']);
      expect(ids, isNot(contains('sig_legacy')));
      expect(ids, contains('sig_unconfirmed'));
      expect(ids, isNot(contains('sig_inaccurate')));
      expect(await harness.includedInWeekly('sig_legacy'), isFalse);
      expect(await harness.includedInWeekly('sig_unconfirmed'), isTrue);

      await harness.close();
    });

    test('11) local draft、sync failed、隐私排除项不进入 Weekly', () async {
      final recordingAi = RecordingWeeklyAiRepository();
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: recordingAi,
        installationDate: _testNow.subtract(const Duration(days: 1)),
      );

      await harness.seedSignalCard(
        id: 'sig_draft',
        content: '本地 draft',
        createdAt: _testNow,
        isLocalDraft: true,
      );
      await harness.seedSignalCard(
        id: 'sig_failed',
        content: '同步失败',
        createdAt: _testNow,
        syncFailed: true,
      );
      await harness.seedSignalCard(
        id: 'sig_private_excluded',
        content: '不参与分析的敏感记录',
        createdAt: _testNow,
        privacyLevel: 'do_not_analyze',
      );

      final weekly = await harness.repository.fetchCurrentWeekly();

      expect(weekly.status, 'insufficient_data');
      expect(recordingAi.callCount, 0);

      await harness.close();
    });

    test('11b) library_saved 需要用户确认后才进入 Weekly', () async {
      final recordingAi = RecordingWeeklyAiRepository();
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: recordingAi,
        installationDate: _testNow.subtract(const Duration(days: 1)),
      );

      await harness.seedSignalCard(
        id: 'library_unconfirmed',
        content: '',
        createdAt: _testNow,
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
        createdAt: _testNow,
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
        createdAt: _testNow,
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
      await harness.seedReadinessFillers(1);

      await harness.repository.fetchCurrentWeekly();

      final ids = recordingAi.lastEntries.map((e) => e['signal_card_id']);
      expect(ids, isNot(contains('library_unconfirmed')));
      expect(ids, contains('library_confirmed_without_context'));
      expect(ids, contains('library_with_context'));
      final confirmed = recordingAi.lastEntries.firstWhere(
        (entry) => entry['signal_card_id'] == 'library_with_context',
      );
      expect(confirmed['weekly_confidence'], 'library_saved_confirmed');
      expect(confirmed['content'], contains('Attention switching fatigue'));
      expect(await harness.includedInWeekly('library_unconfirmed'), isFalse);
      expect(
        await harness.includedInWeekly('library_confirmed_without_context'),
        isTrue,
      );
      expect(await harness.includedInWeekly('library_with_context'), isTrue);

      await harness.close();
    });

    test('11c) eligible signals 定义覆盖文字、语音、AI 失败、预测和删除回退', () async {
      final recordingAi = RecordingWeeklyAiRepository();
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: recordingAi,
        installationDate: _testNow.subtract(const Duration(days: 1)),
      );

      await harness.seedSignalCard(
        id: 'text_raw',
        content: '文字输入算作真实信号',
        createdAt: _testNow,
      );
      await harness.seedSignalCard(
        id: 'voice_transcript',
        content: '语音转写也算作真实信号',
        createdAt: _testNow,
        sourceType: 'voice',
      );
      await harness.seedSignalCard(
        id: 'ai_failed_raw_saved',
        content: 'AI 失败但原文已经保存也算',
        createdAt: _testNow,
      );
      await harness.seedSignalCard(
        id: 'ai_predicted_accurate_only',
        content: 'AI 轻建议本身不算原始信号',
        createdAt: _testNow,
        sourceType: 'ai_predicted',
        userConfirmation: 'accurate',
      );
      await harness.seedSignalCard(
        id: 'ai_predicted_with_context',
        content: 'AI 预测加上自己的语境后才算',
        createdAt: _testNow,
        sourceType: 'ai_predicted',
        userConfirmation: 'supplemented',
        userCorrectionJson: const {
          'supplement_text': '我补充了自己的具体情况。',
        },
      );
      await harness.seedSignalCard(
        id: 'library_default',
        content: '',
        createdAt: _testNow,
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
        createdAt: _testNow,
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
            'ai_predicted_accurate_only',
            'ai_predicted_with_context',
            'library_default',
            'library_with_context',
          ]));

      await harness.deleteSignalCard('text_raw');
      await harness.deleteSignalCard('voice_transcript');
      await harness.deleteSignalCard('ai_failed_raw_saved');
      await harness.deleteSignalCard('ai_predicted_accurate_only');
      await harness.deleteSignalCard('ai_predicted_with_context');
      await harness.deleteSignalCard('library_default');
      await harness.deleteSignalCard('library_with_context');

      final weeklyAfterDelete = await harness.repository.fetchCurrentWeekly();
      expect(weeklyAfterDelete.status, 'insufficient_data');

      await harness.close();
    });

    test('12) Weekly 输出只保留一个 pattern 和一个小实验', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: MultiPatternWeeklyAiRepository(),
        installationDate: _testNow.subtract(const Duration(days: 6)),
      );

      final now = _testNow;
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
        installationDate: _testNow.subtract(const Duration(days: 1)),
      );

      await harness.seedSignalCard(
        id: 'sig_used',
        content: '今天安排过密',
        createdAt: _testNow,
      );
      await harness.seedSignalCard(
        id: 'sig_excluded',
        content: '这条只留在时间线',
        createdAt: _testNow,
        userConfirmation: 'inaccurate',
      );

      final weekly = await harness.repository.fetchCurrentWeekly();
      final inclusion = weekly.inclusionSummary;

      expect(inclusion.usedCount, 1);
      expect(inclusion.timelineOnlyCount, 1);
      expect(inclusion.excludedCount, 1);

      await harness.close();
    });

    test('14) Weekly 满三条 eligible signal 后才创建 experiment candidate', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeWeeklyAiRepository(),
        installationDate: _testNow.subtract(const Duration(days: 1)),
      );

      await harness.seedSignalCard(
        id: 'sig_experiment_1',
        content: '今天被消息打断很多次',
        createdAt: _testNow,
      );
      await harness.seedSignalCard(
        id: 'sig_experiment_2',
        content: '下午切换任务时很难重新进入状态',
        createdAt: _testNow,
      );

      final beforeThreshold = await harness.repository.fetchCurrentWeekly();
      expect(
        await harness.repository.fetchWeeklyExperimentCandidate(
          weekStart: beforeThreshold.weekStart,
        ),
        isNull,
      );
      expect(await harness.tableCount('experiment_candidates'), 0);

      await harness.seedSignalCard(
        id: 'sig_experiment_3',
        content: '晚上留出缓冲以后恢复得更快',
        createdAt: _testNow,
      );

      final weekly = await harness.repository.fetchCurrentWeekly();
      final experiment =
          await harness.repository.fetchWeeklyExperimentCandidate(
        weekStart: weekly.weekStart,
      );

      expect(experiment, isNotNull);
      expect(experiment!.id, startsWith('cand_'));
      expect(experiment.status, 'suggested');
      expect(experiment.sourceWeekStart, weekly.weekStart);
      expect(experiment.suggestedAction, isNotEmpty);
      expect(
        experiment.linkedSignalCardIds,
        containsAll(
            ['sig_experiment_1', 'sig_experiment_2', 'sig_experiment_3']),
      );
      expect(await harness.tableCount('experiment_candidates'), 1);
      expect(await harness.tableCount('life_experiments'), 0);
      expect(await harness.tableCount('weekly_snapshots'), 1);
      expect(await harness.tableCount('reflection_results'), 1);
      expect(weekly.lifeExperiment, isNull);
      expect(
        await harness.weeklySnapshotContainsLifeExperiment(weekly.weekStart),
        isFalse,
      );

      await harness.close();
    });

    test('14a) skip candidate 只更新 candidate 状态，不创建正式实验', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeWeeklyAiRepository(),
        installationDate: _testNow.subtract(const Duration(days: 1)),
      );

      await harness.seedSignalCard(
        id: 'sig_skip_candidate',
        content: '今天安排过密',
        createdAt: _testNow,
      );
      await harness.seedSignalCard(
        id: 'sig_skip_candidate_2',
        content: '切换之后很难回来',
        createdAt: _testNow,
      );
      await harness.seedSignalCard(
        id: 'sig_skip_candidate_3',
        content: '晚上留一点空白会轻松些',
        createdAt: _testNow,
      );

      final weekly = await harness.repository.fetchCurrentWeekly();
      final candidate =
          (await harness.repository.fetchWeeklyExperimentCandidate(
        weekStart: weekly.weekStart,
      ))!;

      final skipped = await harness.repository.skipLifeExperiment(candidate.id);

      expect(skipped?.id, candidate.id);
      expect(skipped?.status, 'skipped');
      expect(await harness.experimentCandidateStatus(candidate.id), 'skipped');
      expect(await harness.tableCount('life_experiments'), 0);

      await harness.close();
    });

    test('14b) P2-02 stops writing legacy _life_experiment snapshot cache',
        () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: LegacyLifeExperimentWeeklyAiRepository(),
        installationDate: _testNow.subtract(const Duration(days: 1)),
      );

      await harness.seedSignalCard(
        id: 'sig_legacy_life_experiment',
        content: '今天安排过密',
        createdAt: _testNow,
      );

      final weekly = await harness.repository.fetchCurrentWeekly();

      expect(
        await harness.weeklySnapshotContainsLifeExperiment(weekly.weekStart),
        isFalse,
      );
      expect(
        await harness.weeklyReflectionContainsLifeExperiment(weekly.weekStart),
        isFalse,
      );

      await harness.close();
    });

    test('15) Experiment save / skip / feedback 会写入本地', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeWeeklyAiRepository(),
        installationDate: _testNow.subtract(const Duration(days: 1)),
      );

      await harness.seedSignalCard(
        id: 'sig_save',
        content: '今天安排过密',
        createdAt: _testNow,
      );
      await harness.seedSignalCard(
        id: 'sig_save_2',
        content: '下午切换太频繁',
        createdAt: _testNow,
      );
      await harness.seedSignalCard(
        id: 'sig_save_3',
        content: '留出十分钟后恢复更快',
        createdAt: _testNow,
      );

      final weekly = await harness.repository.fetchCurrentWeekly();
      final experiment =
          (await harness.repository.fetchWeeklyExperimentCandidate(
        weekStart: weekly.weekStart,
      ))!;

      final saved = await harness.repository.saveLifeExperiment(experiment.id);
      expect(saved?.status, 'saved');
      expect(saved?.id, isNot(experiment.id));
      expect(await harness.linkedExperimentId('sig_save'), saved?.id);
      expect(
        await harness.experimentCandidateStatus(experiment.id),
        'adopted',
      );
      expect(await harness.tableCount('life_experiments'), 1);
      final sourceStart = DateTime.parse(experiment.sourceWeekStart);
      final sourceEnd = DateTime.parse(experiment.sourceWeekEnd);
      expect(
        saved?.sourceWeekStart,
        _dateKeyForTest(sourceStart.add(const Duration(days: 7))),
      );
      expect(
        saved?.sourceWeekEnd,
        _dateKeyForTest(sourceEnd.add(const Duration(days: 7))),
      );
      expect(
        await harness.localLifeExperimentRepository.getSavedForToday(
          localUserId: 'test-user',
          today: sourceStart,
        ),
        isNull,
      );
      expect(
        (await harness.localLifeExperimentRepository.getSavedForToday(
          localUserId: 'test-user',
          today: sourceStart.add(const Duration(days: 7)),
        ))
            ?.id,
        saved?.id,
      );
      expect(
        (await harness.repository.fetchNextWeekExperiment(
          weekStart: weekly.weekStart,
        ))
            ?.id,
        saved?.id,
      );
      expect(
        await harness.repository.fetchCurrentWeekLifeExperiment(
          weekStart: weekly.weekStart,
        ),
        isNull,
      );

      final savedAgain =
          await harness.repository.saveLifeExperiment(experiment.id);
      expect(savedAgain?.id, saved?.id);
      expect(await harness.tableCount('life_experiments'), 1);

      final reloaded = await harness.repository.fetchCurrentWeekly();
      final reloadedCandidate =
          await harness.repository.fetchWeeklyExperimentCandidate(
        weekStart: reloaded.weekStart,
      );
      expect(reloaded.lifeExperiment, isNull);
      expect(reloadedCandidate?.id, experiment.id);
      expect(await harness.tableCount('life_experiments'), 1);

      final feedback = await harness.repository.submitLifeExperimentFeedback(
        experimentId: saved!.id,
        status: 'not_helpful',
        feedbackText: 'Not helpful this time',
      );
      expect(feedback?.status, 'active');
      expect(feedback?.feedbackText, 'Not helpful this time');
      final feedbackRows = await harness.localLifeExperimentRepository
          .listFeedbacks(experimentId: saved.id);
      expect(feedbackRows, hasLength(1));
      expect(feedbackRows.single.completionStatus, 'not_helpful');
      expect(feedbackRows.single.feedbackText, 'Not helpful this time');

      final skipped = await harness.repository.skipLifeExperiment(saved.id);
      expect(skipped?.status, 'skipped');

      await harness.close();
    });

    test('16) excluded / inaccurate / sync failed 不进入 experiment linkage',
        () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeWeeklyAiRepository(),
        installationDate: _testNow.subtract(const Duration(days: 1)),
      );

      await harness.seedSignalCard(
        id: 'sig_used_for_exp',
        content: '今天开会很累',
        createdAt: _testNow,
      );
      await harness.seedSignalCard(
        id: 'sig_used_for_exp_2',
        content: '午后恢复得比较慢',
        createdAt: _testNow,
      );
      await harness.seedSignalCard(
        id: 'sig_used_for_exp_3',
        content: '散步以后清楚一点',
        createdAt: _testNow,
      );
      await harness.seedSignalCard(
        id: 'sig_bad_parse',
        content: '不准的解析',
        createdAt: _testNow,
        userConfirmation: 'inaccurate',
      );
      await harness.seedSignalCard(
        id: 'sig_sync_failed',
        content: '同步失败记录',
        createdAt: _testNow,
        syncFailed: true,
      );
      await harness.seedSignalCard(
        id: 'sig_legacy_ref',
        content: '旧记录只作背景',
        createdAt: _testNow,
        isLegacy: true,
      );

      final weekly = await harness.repository.fetchCurrentWeekly();
      final candidate = await harness.repository.fetchWeeklyExperimentCandidate(
        weekStart: weekly.weekStart,
      );
      final linked = candidate!.linkedSignalCardIds;

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
        installationDate: _testNow.subtract(const Duration(days: 1)),
      );

      await harness.seedSignalCard(
        id: 'sig_kept',
        content: '原始记录不能消失',
        createdAt: _testNow,
      );
      await harness.seedSignalCard(
        id: 'sig_kept_2',
        content: '下午很容易被打断',
        createdAt: _testNow,
      );
      await harness.seedSignalCard(
        id: 'sig_kept_3',
        content: '晚上恢复了一些',
        createdAt: _testNow,
      );

      final weekly = await harness.repository.fetchCurrentWeekly();
      final candidate = await harness.repository.fetchWeeklyExperimentCandidate(
        weekStart: weekly.weekStart,
      );
      await harness.repository.submitLifeExperimentFeedback(
        experimentId: candidate!.id,
        status: 'adjusted',
        feedbackText: 'Needs adjustment',
      );
      expect(await harness.tableCount('life_experiments'), 0);
      expect(
        await harness.experimentCandidateStatus(candidate.id),
        'generated',
      );

      final cards = await harness.listSignalCards();
      expect(
        cards.singleWhere((row) => row['id'] == 'sig_kept')['raw_text'],
        '原始记录不能消失',
      );

      await harness.close();
    });

    test('18) prompt/model rollout marks old weekly reflection stale',
        () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeWeeklyAiRepository(),
        installationDate: _testNow.subtract(const Duration(days: 1)),
      );

      await harness.seedSignalCard(
        id: 'sig_rollout',
        content: '今天安排过密',
        createdAt: _testNow,
      );
      await harness.seedReadinessFillers(2);

      final weekly = await harness.repository.fetchCurrentWeekly();
      await harness.stampWeeklyReflectionVersion(
        weekStart: weekly.weekStart,
        promptVersion: 'weekly_reflect_prompt_v1',
        modelVersion: 'model_reflect_v1',
      );

      expect(
        await harness.markWeeklyReflectionStaleForRollout(
          weekStart: weekly.weekStart,
          promptVersion: 'weekly_reflect_prompt_v1',
          modelVersion: 'model_reflect_v1',
        ),
        0,
      );

      expect(
        await harness.markWeeklyReflectionStaleForRollout(
          weekStart: weekly.weekStart,
          promptVersion: 'weekly_reflect_prompt_v2',
          modelVersion: 'model_reflect_v1',
        ),
        1,
      );
      final rows = await harness.weeklyReflectionRows(weekly.weekStart);
      expect(rows.single['dirty'], 1);
      expect(rows.single['is_stale'], 1);
      expect(rows.single['stale_reason'], 'prompt_model_version_changed');
      expect(rows.single['invalidated_at'], isNotNull);

      await harness.close();
    });
  });
}

class _Harness {
  final LocalDatabase localDatabase;
  final WeeklyRepository repository;
  final LocalLifeExperimentRepository localLifeExperimentRepository;
  final LocalPhase3PlusRepository localPhase3PlusRepository;

  _Harness({
    required this.localDatabase,
    required this.repository,
    required this.localLifeExperimentRepository,
    required this.localPhase3PlusRepository,
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

  Future<void> seedReadinessFillers(int count) async {
    final now = _testNow;
    for (var index = 0; index < count; index += 1) {
      await seedSignalCard(
        id: 'readiness_filler_${now.microsecondsSinceEpoch}_$index',
        content: '用于满足报告门槛的有效信号 $index',
        createdAt: now.subtract(Duration(minutes: index + 1)),
        userConfirmation: 'accurate',
      );
    }
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

  Future<int> tableCount(String tableName) async {
    final db = await localDatabase.database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS count FROM $tableName');
    return (rows.first['count'] as int?) ?? 0;
  }

  Future<String?> experimentCandidateStatus(String candidateId) async {
    final db = await localDatabase.database;
    final rows = await db.query(
      'experiment_candidates',
      columns: ['status'],
      where: 'id = ?',
      whereArgs: [candidateId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['status'] as String?;
  }

  Future<bool> weeklySnapshotContainsLifeExperiment(String weekStart) async {
    final db = await localDatabase.database;
    final rows = await db.query(
      'weekly_snapshots',
      columns: ['opportunity_snapshot_json'],
      where: 'week_start = ?',
      whereArgs: [weekStart],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    final raw = rows.first['opportunity_snapshot_json'];
    if (raw is! String || raw.trim().isEmpty) return false;
    final decoded = jsonDecode(raw);
    return decoded is Map && decoded.containsKey('_life_experiment');
  }

  Future<bool> weeklyReflectionContainsLifeExperiment(String weekStart) async {
    final db = await localDatabase.database;
    final rows = await db.query(
      'reflection_results',
      columns: ['content_json'],
      where: 'source_type = ? AND source_id = ? AND reflection_type = ?',
      whereArgs: ['weekly_snapshot', weekStart, 'reflect'],
      orderBy: 'generated_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return false;
    final raw = rows.first['content_json'];
    if (raw is! String || raw.trim().isEmpty) return false;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return false;
    final opportunity = decoded['opportunity_snapshot'];
    return opportunity is Map && opportunity.containsKey('_life_experiment');
  }

  Future<List<Map<String, Object?>>> weeklyReflectionRows(
      String weekStart) async {
    final db = await localDatabase.database;
    return db.query(
      'reflection_results',
      where: 'source_type = ? AND source_id = ? AND reflection_type = ?',
      whereArgs: ['weekly_snapshot', weekStart, 'reflect'],
      orderBy: 'generated_at DESC',
    );
  }

  Future<void> stampWeeklyReflectionVersion({
    required String weekStart,
    required String promptVersion,
    required String modelVersion,
  }) async {
    final db = await localDatabase.database;
    await db.update(
      'reflection_results',
      {
        'prompt_version': promptVersion,
        'model_version': modelVersion,
      },
      where: 'source_type = ? AND source_id = ? AND reflection_type = ?',
      whereArgs: ['weekly_snapshot', weekStart, 'reflect'],
    );
  }

  Future<int> markWeeklyReflectionStaleForRollout({
    required String weekStart,
    required String promptVersion,
    required String modelVersion,
  }) {
    return LocalReflectionResultRepository(
      localDatabase,
    ).markStaleForPromptModelChange(
      sourceType: 'weekly_snapshot',
      sourceId: weekStart,
      reflectionType: 'reflect',
      promptVersion: promptVersion,
      modelVersion: modelVersion,
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
  final localLifeExperimentRepository =
      LocalLifeExperimentRepository(localDatabase);
  final localPhase3PlusRepository = LocalPhase3PlusRepository(localDatabase);

  final repository = WeeklyRepository(
    localCaptureRepository: localCaptureRepository,
    localWeeklySnapshotRepository: localWeeklySnapshotRepository,
    localLifeExperimentRepository: localLifeExperimentRepository,
    aiRepository: aiRepository,
    focusAreaLoader: () async => null,
    installationDateLoader: () async => installationDate,
    localUserId: 'test-user',
    nowLoader: () => _testNow,
  );

  return _Harness(
    localDatabase: localDatabase,
    repository: repository,
    localLifeExperimentRepository: localLifeExperimentRepository,
    localPhase3PlusRepository: localPhase3PlusRepository,
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

class LegacyLifeExperimentWeeklyAiRepository extends FakeWeeklyAiRepository {
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
      keyInsight: 'Legacy payload should be sanitized.',
      patterns: const [
        {'name': 'Legacy pattern', 'summary': 'Generated by legacy test.'},
      ],
      frictions: const [
        {'name': 'Legacy friction', 'summary': 'Generated by legacy test.'},
      ],
      bestAction: 'Try a small buffer.',
      opportunitySnapshot: const {
        'name': 'Legacy opportunity',
        'summary':
            'This object must remain, but the embedded experiment must not.',
        '_life_experiment': {
          'id': 'legacy_embedded_experiment',
          'title': 'Old embedded experiment',
          'hypothesis': 'Old path',
          'suggested_action': 'Old action',
          'status': 'suggested',
          'source_week_start': '2026-07-01',
          'source_week_end': '2026-07-07',
          'linked_signal_card_ids': [],
        },
      },
      feedbackSubmitted: false,
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
