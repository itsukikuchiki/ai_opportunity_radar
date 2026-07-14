import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_opportunity_radar/core/api/api_client.dart';
import 'package:ai_opportunity_radar/core/api/repositories/ai_repository.dart';
import 'package:ai_opportunity_radar/core/api/repositories/memory_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_capture_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/local/local_phase3_plus_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_journey_snapshot_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_life_experiment_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_weekly_snapshot_repository.dart';
import 'package:ai_opportunity_radar/core/models/phase3_plus_models.dart';
import 'package:ai_opportunity_radar/core/models/memory_models.dart';
import 'package:ai_opportunity_radar/core/readiness/report_readiness.dart';

const _testReadyJourneyRule = ReportReadinessRule(
  surface: ReportSurface.journey,
  minimumSignals: 1,
  minimumDistinctDays: 1,
  minimumDistinctWeeks: 1,
  windowDays: 31,
);

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

    test('2) 未达门槛时只返回事实投影，不生成或缓存报告', () async {
      final aiRepository = CountingJourneyAiRepository();
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: aiRepository,
        installationDate: DateTime.now(),
        journeyReadinessRule: ReportReadinessEvaluator.journeyRule,
      );

      await harness.seedSignalCard(
        content: '今天第一条记录',
        createdAt: DateTime.now(),
      );

      final result = await harness.repository.fetchMemorySummaryResult();

      expect(result.isFirstDayGate, false);
      expect(result.summary, isNotNull);
      expect(result.summary!.patterns, isEmpty);
      expect(result.summary!.journeyTraces, hasLength(1));
      expect(result.journeyReadiness!.signalCount, 1);
      expect(result.journeyReadiness!.isReady, isFalse);
      expect(aiRepository.callCount, 0);
      expect(
        await harness.journeySnapshot(_dateKey(DateTime.now())),
        isNull,
      );

      await harness.close();
    });

    test('4c) Journey 报告需 7 条有效信号并覆盖至少 3 个本地日期', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeJourneyAiRepository(),
        installationDate: DateTime.now().subtract(const Duration(days: 5)),
        journeyReadinessRule: ReportReadinessEvaluator.journeyRule,
      );
      final now = DateTime.now();
      for (var index = 0; index < 7; index += 1) {
        final dayOffset = index % 3;
        await harness.seedSignalCard(
          id: 'journey_ready_$index',
          content: 'Journey 门槛信号 $index',
          createdAt: now.subtract(Duration(days: dayOffset, minutes: index)),
          userConfirmation: 'accurate',
        );
      }

      final result = await harness.repository.fetchMemorySummaryResult();

      expect(result.journeyReadiness, isNotNull);
      expect(result.journeyReadiness!.signalCount, 7);
      expect(result.journeyReadiness!.distinctDayCount, 3);
      expect(result.journeyReadiness!.isReady, isTrue);
      expect(result.proReadiness!.isReady, isFalse);

      await harness.close();
    });

    test('4d) Journey Pro 需近 28 天 14 条信号、7 个日期和 2 个自然周', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeJourneyAiRepository(),
        installationDate: DateTime.now().subtract(const Duration(days: 28)),
      );
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final currentMonday = today.subtract(
        Duration(days: today.weekday - DateTime.monday),
      );
      final previousSunday = currentMonday.subtract(const Duration(days: 1));
      final dates = <DateTime>[
        today,
        for (var offset = 0; offset < 6; offset += 1)
          previousSunday.subtract(Duration(days: offset)),
      ];
      for (var dayIndex = 0; dayIndex < dates.length; dayIndex += 1) {
        for (var itemIndex = 0; itemIndex < 2; itemIndex += 1) {
          await harness.seedSignalCard(
            id: 'pro_ready_${dayIndex}_$itemIndex',
            content: 'Pro 门槛信号 $dayIndex-$itemIndex',
            createdAt: dates[dayIndex].add(Duration(hours: itemIndex + 8)),
            localDate: _dateKey(dates[dayIndex]),
            userConfirmation: 'accurate',
          );
        }
      }

      final result = await harness.repository.fetchMemorySummaryResult();

      expect(result.proReadiness, isNotNull);
      expect(result.proReadiness!.signalCount, 14);
      expect(result.proReadiness!.distinctDayCount, 7);
      expect(result.proReadiness!.distinctWeekCount, 2);
      expect(result.proReadiness!.isReady, isTrue);

      final proReport = await harness.repository.fetchJourneyProReport();
      expect(proReport.isReady, isTrue);
      expect(proReport.readiness.signalCount, 14);
      expect(proReport.currentWeek.signalCount, 2);
      expect(proReport.currentWeek.activeDayCount, 1);
      expect(proReport.previousWeek.signalCount, 12);
      expect(proReport.previousWeek.activeDayCount, 6);
      expect(proReport.evidence, hasLength(8));
      expect(
        proReport.evidence.every(
          (item) => item.signalId.startsWith('pro_ready_'),
        ),
        isTrue,
      );

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

    test('4) 第 2 天以后未达门槛也保留事实时间线', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeJourneyAiRepository(),
        installationDate: DateTime.now().subtract(const Duration(days: 1)),
        journeyReadinessRule: ReportReadinessEvaluator.journeyRule,
      );

      await harness.seedSignalCard(
        content: '昨天：有点烦',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      await harness.seedSignalCard(
        content: '今天：还是烦',
        createdAt: DateTime.now(),
      );

      final result = await harness.repository.fetchMemorySummaryResult();

      expect(result.isFirstDayGate, false);
      expect(result.summary, isNotNull);
      expect(result.summary!.frictions, isEmpty);
      expect(result.summary!.journeyTraces, hasLength(2));

      await harness.close();
    });

    test('4b) 第 2 天只有 1 条信号时不伪造 Seed 结论', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeJourneyAiRepository(),
        installationDate: DateTime.now().subtract(const Duration(days: 1)),
        journeyReadinessRule: ReportReadinessEvaluator.journeyRule,
      );

      await harness.seedSignalCard(
        content: '昨天先留下了一条生活信号',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      );

      final result = await harness.repository.fetchMemorySummaryResult();

      expect(result.isFirstDayGate, false);
      expect(result.summary, isNotNull);
      expect(result.summary!.patterns, isEmpty);
      expect(result.summary!.journeyTraces, hasLength(1));

      await harness.close();
    });

    test('5) Journey 会把线索分成 weak / repeated / stable 三层', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeJourneyAiRepositoryWithoutSignalLevels(),
        installationDate: DateTime.now().subtract(const Duration(days: 2)),
      );

      await harness.seedSignalCard(
        content: '前天：工作很烦',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      );
      await harness.seedSignalCard(
        content: '昨天：开会又被打断',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      await harness.seedSignalCard(
        content: '今天：还是被打断',
        createdAt: DateTime.now(),
      );
      await harness.seedSignalCard(
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

      await harness1.seedSignalCard(
        content: '前天：工作很烦',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      await harness1.seedSignalCard(
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

      await harness.seedSignalCard(
        content: '今天：被打断了',
        createdAt: DateTime.now(),
      );

      final result = await harness.repository.fetchMemorySummaryResult();

      expect(result.summary, isNotNull);
      expect(result.summary!.patterns, hasLength(1));
      expect(result.summary!.frictions, hasLength(1));
      expect(result.summary!.desires, hasLength(1));
      expect(result.summary!.experiments, hasLength(1));
      expect(result.summary!.patterns, isNotEmpty);
      expect(result.summary!.frictions, isNotEmpty);
      expect(result.summary!.desires, isNotEmpty);
      expect(result.summary!.experiments, isNotEmpty);
      expect(
        result.summary!.nextAdjustmentDirection.summary,
        contains('省一点力'),
      );
      expect(
        {'weak_signal', 'repeated_pattern', 'stable_mode'}
            .contains(result.summary!.patterns.first.signalLevel),
        isTrue,
      );

      await harness.close();
    });

    test('8) Journey 使用 SignalCard local_date/timezone 聚合，不按 UTC 错分日期',
        () async {
      final recordingAi = RecordingJourneyAiRepository();
      final now = DateTime.now();
      final localDate = _dateKey(now);
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: recordingAi,
        installationDate: now.subtract(const Duration(days: 2)),
      );

      await harness.seedSignalCard(
        id: 'tokyo_late_card',
        content: '东京深夜记录',
        createdAt: DateTime.utc(now.year, now.month, now.day, 15, 30),
        localDate: localDate,
        timezone: 'Asia/Tokyo',
      );

      await harness.repository.fetchMemorySummaryResult();

      expect(recordingAi.lastEntries, hasLength(1));
      expect(
          recordingAi.lastEntries.single['signal_card_id'], 'tokyo_late_card');
      expect(recordingAi.lastEntries.single['local_date'], localDate);
      expect(recordingAi.lastEntries.single['timezone'], 'Asia/Tokyo');

      await harness.close();
    });

    test('8b) Journey aggregation 只读取当月窗口内的 SignalCard', () async {
      final recordingAi = RecordingJourneyAiRepository();
      final now = DateTime.now();
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: recordingAi,
        installationDate: DateTime(now.year, now.month, 1),
      );

      await harness.seedSignalCard(
        id: 'previous_month_card',
        content: '上个月的记录',
        createdAt: DateTime(now.year, now.month, 1).subtract(
          const Duration(days: 1),
        ),
        localDate: _dateKey(
          DateTime(now.year, now.month, 1).subtract(const Duration(days: 1)),
        ),
      );
      await harness.seedSignalCard(
        id: 'current_month_card',
        content: '这个月的记录',
        createdAt: now,
        localDate: _dateKey(now),
      );

      await harness.repository.fetchMemorySummaryResult();

      expect(
        recordingAi.lastEntries.map((entry) => entry['signal_card_id']),
        contains('current_month_card'),
      );
      expect(
        recordingAi.lastEntries.map((entry) => entry['signal_card_id']),
        isNot(contains('previous_month_card')),
      );

      await harness.close();
    });

    test('8c) Journey L3 输出写入 reflection_results', () async {
      final now = DateTime.now();
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeJourneyAiRepository(),
        installationDate: now.subtract(const Duration(days: 1)),
      );

      await harness.seedSignalCard(
        id: 'reflection_source_card',
        content: '今天适合做一次月内回看',
        createdAt: now,
        localDate: _dateKey(now),
      );

      await harness.repository.fetchMemorySummaryResult();
      final snapshot = await harness.journeySnapshot(_dateKey(now));
      expect(snapshot, isNotNull);
      expect(snapshot!['snapshot_date'], _dateKey(now));
      expect(
          snapshot['journey_data_json'].toString(), contains('journey_traces'));

      final reflection = await harness.latestJourneyReflection(_dateKey(now));

      expect(reflection, isNotNull);
      expect(reflection!['source_type'], 'journey_snapshot');
      expect(reflection['reflection_type'], 'reflect');
      expect(reflection['ai_level'], 'L3');
      expect(reflection['content_json'].toString(), contains('patterns'));
      final traceLinks = await harness.traceLinksForSource(
        sourceType: 'journey_snapshot',
        sourceId: _dateKey(now),
      );
      expect(traceLinks, isNotEmpty);
      expect(traceLinks.map((row) => row['relation_type']).toSet(), {
        'uses_trace',
      });

      await harness.close();
    });

    test('8c-1) Journey 保留 generated / confirmed / dismissed Observation 状态',
        () async {
      final now = DateTime.now();
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeJourneyAiRepository(),
        installationDate: now.subtract(const Duration(days: 1)),
      );

      await harness.seedSignalCard(
        id: 'observation_context_signal',
        content: '观察只能作为已纳入信号的派生背景',
        createdAt: now,
        localDate: _dateKey(now),
      );

      await harness.seedObservation(
        id: 'obs_generated',
        text: '生成中的观察',
        status: 'generated',
      );
      await harness.seedObservation(
        id: 'obs_confirmed',
        text: '用户确认的观察',
        status: 'confirmed',
      );
      await harness.seedObservation(
        id: 'obs_dismissed',
        text: '用户暂时否定的观察',
        status: 'dismissed',
      );

      final result = await harness.repository.fetchMemorySummaryResult();
      final observations = result.summary!.observations;

      expect(observations.map((item) => item.id), [
        'obs_confirmed',
        'obs_generated',
        'obs_dismissed',
      ]);
      expect(observations.map((item) => item.status), [
        'confirmed',
        'generated',
        'dismissed',
      ]);

      await harness.close();
    });

    test(
        '8c-2) Journey trace only uses Signal, MicroAction and LifeExperiment core inputs',
        () async {
      final now = DateTime.now();
      final todayKey = _dateKey(now);
      final weekStart =
          now.subtract(Duration(days: now.weekday - DateTime.monday));
      final weekStartKey = _dateKey(weekStart);
      final weekEndKey = _dateKey(weekStart.add(const Duration(days: 6)));
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeJourneyAiRepository(),
        installationDate: DateTime(now.year, now.month, 1),
      );

      await harness.seedSignalCard(
        id: 'journey_input_signal',
        content: '这个月有一条真实信号',
        createdAt: now,
        localDate: todayKey,
      );
      await harness.seedWeeklySnapshot(
        weekStart: weekStartKey,
        weekEnd: weekEndKey,
        keyInsight: '本周恢复需求更清楚。',
      );
      await harness.phase3PlusRepository.insertMicroActionFeedback(
        MicroActionFeedbackModel(
          id: 'micro_journey_input',
          microActionId: 'micro_action_journey_input',
          localDate: todayKey,
          happened: 'yes',
          effect: 'helpful',
          difficulty: 'easy',
          userNote: '短行动有帮助',
          createdAt: now.toUtc(),
        ),
      );
      final experiment = await harness.lifeExperimentRepository.ensureSuggested(
        localUserId: 'test-user',
        weekStart: weekStartKey,
        weekEnd: weekEndKey,
        title: '午后留白',
        hypothesis: '留白帮助恢复',
        suggestedAction: '午后留 10 分钟',
        linkedSignalCardIds: const ['journey_input_signal'],
        status: 'saved',
      );
      await harness.lifeExperimentRepository.recordFeedback(
        experimentId: experiment.id,
        completionStatus: 'helpful',
        helpfulnessScore: 5,
        feedbackText: '确实更稳',
        feedbackDate: now,
      );
      final db = await harness.localDatabase.database;
      final timestamp = now.toUtc().toIso8601String();
      await db.insert('schedule_signals', {
        'id': 'legacy-journey-schedule',
        'title': '下午会议',
        'local_date': todayKey,
        'anchor_date': todayKey,
        'date_precision': 'date',
        'time_precision': 'none',
        'feedback_status': 'recorded',
        'actual_energy_load': 'draining',
        'created_at': timestamp,
        'updated_at': timestamp,
      });
      await db.insert('goals', {
        'id': 'legacy-journey-goal',
        'title': '恢复练习',
        'created_at': timestamp,
        'updated_at': timestamp,
      });
      await harness.seedGoalFeedback(
        id: 'goal_journey_input',
        goalId: 'legacy-journey-goal',
        feedbackDate: todayKey,
      );

      final result = await harness.repository.fetchMemorySummaryResult();
      final sourceTypes = result.summary!.journeyTraces
          .map((trace) => trace.sourceType)
          .toSet();

      expect(sourceTypes, contains('signal_card'));
      expect(sourceTypes, contains('weekly_review'));
      expect(sourceTypes, contains('life_experiment_rollup'));
      expect(sourceTypes, contains('micro_action_feedback'));
      expect(sourceTypes, contains('life_experiment_feedback'));
      expect(sourceTypes, isNot(contains('schedule_feedback')));
      expect(sourceTypes, isNot(contains('goal_feedback')));
      expect(
        result.summary!.journeyTraces
            .firstWhere((trace) => trace.sourceType == 'weekly_review')
            .summary,
        contains('恢复需求'),
      );
      expect(
        result.summary!.journeyTraces
            .firstWhere((trace) => trace.sourceType == 'life_experiment_rollup')
            .summary,
        contains('helpful 1'),
      );

      await harness.close();
    });

    test('8d) Journey evidence drilldown 从 trace_links 解析多来源依据', () async {
      final now = DateTime.now();
      final snapshotDate = _dateKey(now);
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeJourneyAiRepository(),
        installationDate: now.subtract(const Duration(days: 1)),
      );

      await harness.seedSignalCard(
        id: 'sig_evidence',
        content: '会议后很累，需要恢复。',
        createdAt: now,
        localDate: snapshotDate,
      );
      await harness.seedObservation(
        id: 'obs_evidence',
        text: '会议和恢复需求最近一起出现。',
      );
      await harness.seedExperimentFeedback(
        id: 'fb_evidence',
        feedbackText: '这个小实验有帮助。',
        localDate: snapshotDate,
      );
      await harness.seedWeeklySnapshot(
        weekStart: '2026-06-29',
        weekEnd: snapshotDate,
        keyInsight: '本周最大的变化是恢复需求更清楚。',
      );

      await harness.seedTraceLink(
        snapshotDate: snapshotDate,
        targetType: 'signal_card',
        targetId: 'sig_evidence',
      );
      await harness.seedTraceLink(
        snapshotDate: snapshotDate,
        targetType: 'observation',
        targetId: 'obs_evidence',
      );
      await harness.seedTraceLink(
        snapshotDate: snapshotDate,
        targetType: 'life_experiment',
        targetId: 'fb_evidence',
      );
      await harness.seedTraceLink(
        snapshotDate: snapshotDate,
        targetType: 'weekly_review',
        targetId: 'weekly_2026-06-29',
      );

      final evidence = await harness.repository.fetchJourneyEvidence();

      expect(evidence.map((e) => e.sourceType), contains('signal_card'));
      expect(evidence.map((e) => e.sourceType), contains('observation'));
      expect(
        evidence.map((e) => e.sourceType),
        contains('life_experiment_feedback'),
      );
      expect(evidence.map((e) => e.sourceType), contains('weekly_review'));
      expect(
        evidence.map((e) => e.summary).join('\n'),
        contains('本周最大的变化'),
      );

      await harness.close();
    });

    test('8e) 旧数据没有 trace 时返回 empty 或 trace 自身 fallback，不伪造证据', () async {
      final now = DateTime.now();
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeJourneyAiRepository(),
        installationDate: now.subtract(const Duration(days: 1)),
      );

      final emptyEvidence = await harness.repository.fetchJourneyEvidence();
      expect(emptyEvidence, isEmpty);

      final fallbackEvidence = await harness.repository.fetchJourneyEvidence(
        trace: JourneyTraceModel(
          id: 'legacy_trace_without_link',
          sourceType: 'legacy_summary',
          title: 'Legacy Summary',
          summary: '旧摘要里只有展示文本，没有 trace_links。',
          localDate: _dateKey(now),
          cluster: 'legacy',
          intensity: 0.4,
          signalLevel: 'weak_signal',
        ),
      );

      expect(fallbackEvidence, hasLength(1));
      expect(fallbackEvidence.single.relationType, 'trace_fallback');
      expect(fallbackEvidence.single.sourceType, 'legacy_summary');

      await harness.close();
    });

    test('8f) Signal 删除后 Journey evidence trace 变为 inactive', () async {
      final now = DateTime.now();
      final snapshotDate = _dateKey(now);
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeJourneyAiRepository(),
        installationDate: now.subtract(const Duration(days: 1)),
      );

      await harness.seedSignalCard(
        id: 'signal_to_delete_from_evidence',
        content: '删除前作为证据出现',
        createdAt: now,
        localDate: snapshotDate,
      );
      await harness.seedTraceLink(
        snapshotDate: snapshotDate,
        targetType: 'signal_card',
        targetId: 'signal_to_delete_from_evidence',
      );

      await harness.captureRepository.deleteSignalCard(
        'signal_to_delete_from_evidence',
      );

      final db = await harness.localDatabase.database;
      final traceRows = await db.query(
        'trace_links',
        where: 'target_type = ? AND target_id = ?',
        whereArgs: ['signal_card', 'signal_to_delete_from_evidence'],
      );
      expect(traceRows, isNotEmpty);
      expect(traceRows.every((row) => row['status'] == 'inactive'), isTrue);

      final evidence = await harness.repository.fetchJourneyEvidence();
      expect(evidence.map((item) => item.sourceId),
          isNot(contains('signal_to_delete_from_evidence')));

      await harness.close();
    });

    test(
        '9) Journey inclusion 排除 legacy / inaccurate / sync failed / privacy excluded，保留 unconfirmed 小观察',
        () async {
      final recordingAi = RecordingJourneyAiRepository();
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: recordingAi,
        installationDate: DateTime.now().subtract(const Duration(days: 5)),
      );

      await harness.seedSignalCard(
        id: 'legacy_card',
        content: '旧记录作为低置信背景',
        createdAt: DateTime.now().subtract(const Duration(days: 4)),
        isLegacy: true,
      );
      await harness.seedSignalCard(
        id: 'unconfirmed_card',
        content: '还没确认，但可以小观察',
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      );
      await harness.seedSignalCard(
        id: 'inaccurate_card',
        content: '用户说不准',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        userConfirmation: 'inaccurate',
      );
      await harness.seedSignalCard(
        id: 'failed_card',
        content: '同步失败先不分析',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        syncFailed: true,
      );
      await harness.seedSignalCard(
        id: 'private_excluded_card',
        content: '隐私排除不分析',
        createdAt: DateTime.now(),
        privacyLevel: 'excluded',
      );

      await harness.repository.fetchMemorySummaryResult();

      final ids = recordingAi.lastEntries
          .map((entry) => entry['signal_card_id'] as String?)
          .toList();
      expect(ids, contains('unconfirmed_card'));
      expect(ids, isNot(contains('legacy_card')));
      expect(ids, isNot(contains('inaccurate_card')));
      expect(ids, isNot(contains('failed_card')));
      expect(ids, isNot(contains('private_excluded_card')));
      final cards = await harness.listSignalCards();
      expect(
        cards.firstWhere(
            (row) => row['id'] == 'legacy_card')['included_in_journey'],
        0,
      );
      expect(
        cards.firstWhere(
            (row) => row['id'] == 'unconfirmed_card')['included_in_journey'],
        1,
      );
      expect(
        cards.firstWhere(
            (row) => row['id'] == 'inaccurate_card')['included_in_journey'],
        0,
      );

      await harness.close();
    });

    test(
        '10) Journey 读取 Life Experiment feedback，skipped/not_helpful 也保留为 Review & Adjust 证据',
        () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeJourneyAiRepository(),
        installationDate: DateTime.now().subtract(const Duration(days: 8)),
      );

      await harness.seedSignalCard(
        id: 'supporting_card',
        content: '晚上切换太多，想减少一点',
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      );
      await harness.seedExperiment(
        id: 'exp_not_helpful',
        status: 'not_helpful',
        feedbackText: '晚上还是太满，暂时没有省力。',
        linkedSignalCardIds: const ['supporting_card'],
      );

      final result = await harness.repository.fetchMemorySummaryResult();

      expect(result.summary, isNotNull);
      expect(result.summary!.experiments, hasLength(1));
      expect(result.summary!.experiments.first.name, '最近一次实验调整');
      expect(result.summary!.experiments.first.summary, contains('帮助不明显'));
      expect(result.summary!.experiments.first.summary, contains('晚上还是太满'));
      expect(result.summary!.experiments.first.summary, contains('生活设计'));

      await harness.close();
    });

    test('11) skipped / adjusted 都用 Review & Adjust 文案，不写成失败', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeJourneyAiRepository(),
        installationDate: DateTime.now().subtract(const Duration(days: 8)),
      );

      await harness.seedSignalCard(
        id: 'experiment_context',
        content: '最近晚上容易被新任务拉走',
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      );
      await harness.seedExperiment(
        id: 'exp_skipped',
        status: 'skipped',
        title: '晚上少接新任务',
        feedbackText: '这周先不处理，也想保留下来回看。',
      );

      final skipped = await harness.repository.fetchMemorySummaryResult();
      expect(skipped.summary!.experiments.first.summary, contains('先不看'));
      expect(skipped.summary!.experiments.first.summary, isNot(contains('失败')));

      await harness.seedSignalCard(
        id: 'experiment_context_2',
        content: '后来把实验调小了一点',
        createdAt: DateTime.now(),
      );
      await harness.seedExperiment(
        id: 'exp_adjusted',
        status: 'adjusted',
        title: '只留十分钟缓冲',
        feedbackText: '调小之后更容易发生。',
      );

      final adjusted = await harness.repository.fetchMemorySummaryResult();
      expect(adjusted.summary!.experiments.first.summary, contains('可学习'));
      expect(
          adjusted.summary!.experiments.first.summary, isNot(contains('失败')));

      await harness.close();
    });

    test('12) Journey 生成失败不影响 SignalCard 本地事实源', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FailingJourneyAiRepository(),
        installationDate: DateTime.now().subtract(const Duration(days: 1)),
      );

      await harness.seedSignalCard(
        id: 'survives_journey_failure',
        content: '这条 Journey 失败时也不能消失',
        createdAt: DateTime.now(),
      );

      final result = await harness.repository.fetchMemorySummaryResult();
      final cards = await harness.listSignalCards();

      expect(result.summary, isNotNull);
      expect(
        cards.map((row) => row['id']),
        contains('survives_journey_failure'),
      );
      expect(
        cards.firstWhere(
            (row) => row['id'] == 'survives_journey_failure')['raw_text'],
        '这条 Journey 失败时也不能消失',
      );

      await harness.close();
    });

    test('13) AI 输出里的压力词只在 Journey 结果中被软化', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: PressureJourneyAiRepository(),
        installationDate: DateTime.now().subtract(const Duration(days: 2)),
      );

      await harness.seedSignalCard(
        id: 'pressure_source',
        content: '原文里可以保留“失败”这个词',
        createdAt: DateTime.now(),
      );

      final result = await harness.repository.fetchMemorySummaryResult();
      final cards = await harness.listSignalCards();

      expect(result.summary!.patterns.first.summary, isNot(contains('长期问题')));
      expect(result.summary!.patterns.first.summary, isNot(contains('失败')));
      expect(result.summary!.patterns.first.summary, contains('长期线索'));
      expect(
          cards.firstWhere((row) => row['id'] == 'pressure_source')['raw_text'],
          contains('失败'));

      await harness.close();
    });

    test('9b) Journey 区分 library_saved 证据等级，确认后进入', () async {
      final recordingAi = RecordingJourneyAiRepository();
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: recordingAi,
        installationDate: DateTime.now().subtract(const Duration(days: 5)),
      );

      await harness.seedSignalCard(
        id: 'library_unconfirmed',
        content: '',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        sourceType: 'library_saved',
        userConfirmation: 'unconfirmed',
        rawPayloadJson: const {
          'library_pattern_id': 'recovery_debt',
          'title': 'Recovery debt',
          'abstract_pattern':
              'Some people notice that rest starts feeling like something to catch up on after several demanding days.',
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
          'supplement_text': 'This matched my week after I added my context.',
        },
        rawPayloadJson: const {
          'library_pattern_id': 'boundary_fatigue',
          'title': 'Boundary fatigue',
          'abstract_pattern':
              'Some people feel tired not from one request, but from many small boundary decisions close together.',
        },
      );

      await harness.repository.fetchMemorySummaryResult();

      final ids = recordingAi.lastEntries.map((e) => e['signal_card_id']);
      expect(ids, isNot(contains('library_unconfirmed')));
      expect(ids, contains('library_confirmed_without_context'));
      expect(ids, contains('library_with_context'));
      final confirmed = recordingAi.lastEntries.firstWhere(
        (entry) => entry['signal_card_id'] == 'library_with_context',
      );
      expect(confirmed['journey_confidence'], 'library_saved_confirmed');
      expect(confirmed['content'], contains('Boundary fatigue'));

      await harness.close();
    });

    test('9c) Journey eligible signals 按当前 SignalCard 重新聚合，删除后回退', () async {
      final recordingAi = RecordingJourneyAiRepository();
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: recordingAi,
        installationDate: DateTime.now().subtract(const Duration(days: 1)),
      );

      await harness.seedSignalCard(
        id: 'text_raw',
        content: '文字输入算作 Journey Seed 的真实信号',
        createdAt: DateTime.now(),
      );
      await harness.seedSignalCard(
        id: 'voice_transcript',
        content: '语音转写也算作真实信号',
        createdAt: DateTime.now(),
        sourceType: 'voice',
      );
      await harness.seedSignalCard(
        id: 'ai_predicted_accurate_only',
        content: 'AI 轻建议本身不算原始信号',
        createdAt: DateTime.now(),
        sourceType: 'ai_predicted',
        userConfirmation: 'accurate',
      );
      await harness.seedSignalCard(
        id: 'library_default',
        content: '',
        createdAt: DateTime.now(),
        sourceType: 'library_saved',
        userConfirmation: 'accurate',
        rawPayloadJson: const {
          'title': 'Boundary fatigue',
          'abstract_pattern':
              'Some people feel tired from many small boundary decisions.',
        },
      );
      await harness.seedSignalCard(
        id: 'library_with_context',
        content: '',
        createdAt: DateTime.now(),
        sourceType: 'library_saved',
        userConfirmation: 'supplemented',
        userCorrectionJson: const {
          'supplement_text': '这像我这周连续处理消息边界后的状态。',
        },
        rawPayloadJson: const {
          'title': 'Boundary fatigue',
          'abstract_pattern':
              'Some people feel tired from many small boundary decisions.',
        },
      );

      final result = await harness.repository.fetchMemorySummaryResult();
      expect(result.summary, isNotNull);
      final ids = recordingAi.lastEntries.map((e) => e['signal_card_id']);
      expect(
          ids,
          containsAll([
            'text_raw',
            'voice_transcript',
            'ai_predicted_accurate_only',
            'library_default',
            'library_with_context',
          ]));

      await harness.deleteSignalCard('text_raw');
      await harness.deleteSignalCard('voice_transcript');
      await harness.deleteSignalCard('ai_predicted_accurate_only');
      await harness.deleteSignalCard('library_default');
      await harness.deleteSignalCard('library_with_context');

      final afterDelete = await harness.repository.fetchMemorySummaryResult();
      expect(afterDelete.isFirstDayGate, false);
      expect(afterDelete.summary, isNull);

      await harness.close();
    });
  });
}

class _Harness {
  final LocalDatabase localDatabase;
  final MemoryRepository repository;
  final LocalCaptureRepository captureRepository;
  final LocalLifeExperimentRepository lifeExperimentRepository;
  final LocalPhase3PlusRepository phase3PlusRepository;

  _Harness({
    required this.localDatabase,
    required this.repository,
    required this.captureRepository,
    required this.lifeExperimentRepository,
    required this.phase3PlusRepository,
  });

  Future<void> seedSignalCard({
    String? id,
    required String content,
    required DateTime createdAt,
    String? localDate,
    String timezone = 'Asia/Tokyo',
    String sourceType = 'text',
    String userConfirmation = 'unconfirmed',
    Map<String, dynamic> rawPayloadJson = const {},
    Map<String, dynamic> userCorrectionJson = const {},
    bool isLegacy = false,
    bool isLocalDraft = false,
    bool syncFailed = false,
    String privacyLevel = 'private',
    String? scene = 'work',
    String? friction = 'context_switch',
    String? energyLoad = 'draining',
    String? positiveSignal,
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
        'observation': '这是一条 Journey 测试观察。',
        'try_next': '先轻轻记一下场景。',
        'emotion': 'negative',
        'intensity': 'medium',
        'scene': scene,
        'friction': friction,
        'positive_signal': positiveSignal,
        'energy_load': energyLoad,
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
        'migration_status': isLegacy ? 'local_legacy' : 'native',
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

  Future<void> seedExperiment({
    String id = 'exp_test',
    String status = 'saved',
    String? feedbackText,
    String title = '给晚上留一点缓冲',
    String hypothesis = '少一点切换可能会省力',
    String suggestedAction = '睡前少接一个新任务',
    List<String> linkedSignalCardIds = const [],
    String? sourceWeekStart,
    String? sourceWeekEnd,
  }) async {
    final db = await localDatabase.database;
    final now = DateTime.now().toUtc();
    final localNow = DateTime.now();
    final currentWeekStart = localNow.subtract(
      Duration(days: localNow.weekday - DateTime.monday),
    );
    final resolvedWeekStart = sourceWeekStart ?? _dateKey(currentWeekStart);
    final resolvedWeekEnd = sourceWeekEnd ??
        _dateKey(currentWeekStart.add(const Duration(days: 6)));
    await db.insert(
      'life_experiments',
      {
        'id': id,
        'local_user_id': 'test-user',
        'source_week_start': resolvedWeekStart,
        'source_week_end': resolvedWeekEnd,
        'title': title,
        'hypothesis': hypothesis,
        'suggested_action': suggestedAction,
        'linked_signal_card_ids_json': jsonEncode(linkedSignalCardIds),
        'status': status,
        'feedback_text': feedbackText,
        'created_at': now.subtract(const Duration(days: 7)).toIso8601String(),
        'updated_at': now.toIso8601String(),
      },
    );
  }

  Future<void> seedObservation({
    required String id,
    required String text,
    String status = 'generated',
  }) async {
    final db = await localDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.insert(
      'observations',
      {
        'id': id,
        'local_user_id': 'test-user',
        'observation_text': text,
        'observation_type': 'hypothesis',
        'confidence': 'medium',
        'status': status,
        'source_period_start': _dateKey(DateTime.now()),
        'source_period_end': _dateKey(DateTime.now()),
        'created_by': 'l2_reason',
        'evidence_text': text,
        'created_at': now,
        'updated_at': now,
      },
    );
  }

  Future<void> seedExperimentFeedback({
    required String id,
    required String feedbackText,
    required String localDate,
  }) async {
    final db = await localDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.insert(
      'life_experiment_feedback',
      {
        'id': id,
        'experiment_id': 'exp_evidence',
        'local_user_id': 'test-user',
        'feedback_date': localDate,
        'local_date': localDate,
        'happened': 'yes',
        'completion_status': 'helpful',
        'feedback_text': feedbackText,
        'created_at': now,
        'updated_at': now,
      },
    );
  }

  Future<void> seedWeeklySnapshot({
    required String weekStart,
    required String weekEnd,
    required String keyInsight,
  }) async {
    final db = await localDatabase.database;
    await db.insert(
      'weekly_snapshots',
      {
        'week_start': weekStart,
        'week_end': weekEnd,
        'status': 'ready',
        'key_insight': keyInsight,
        'patterns_json': '[]',
        'frictions_json': '[]',
        'best_action': '继续轻一点调整。',
        'opportunity_snapshot_json': null,
        'chart_data_json': '[]',
        'feedback_submitted': 0,
        'source_hash': 'test-weekly-hash',
        'schema_version': 1,
        'pipeline_version': 'test',
        'dirty': 0,
        'is_stale': 0,
        'generated_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  Future<void> seedGoalFeedback({
    required String id,
    required String goalId,
    required String feedbackDate,
    String happened = 'yes',
    String effect = 'helpful',
  }) async {
    final db = await localDatabase.database;
    final now = DateTime.parse(feedbackDate).toUtc().toIso8601String();
    await db.insert(
      'goal_feedback',
      {
        'id': id,
        'goal_id': goalId,
        'feedback_date': feedbackDate,
        'happened': happened,
        'effort_level': 'light',
        'effect': effect,
        'comment': '做完轻一点',
        'next_adjustment': 'continue',
        'created_at': now,
        'updated_at': now,
      },
    );
  }

  Future<void> seedTraceLink({
    required String snapshotDate,
    required String targetType,
    required String targetId,
  }) async {
    final db = await localDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.insert(
      'trace_links',
      {
        'id': 'trace_${targetType}_$targetId',
        'local_user_id': 'test-user',
        'source_type': 'journey_snapshot',
        'source_id': snapshotDate,
        'target_type': targetType,
        'target_id': targetId,
        'relation_type': 'uses_trace',
        'weight': 1.0,
        'status': 'active',
        'metadata_json': jsonEncode({'local_date': snapshotDate}),
        'created_at': now,
        'updated_at': now,
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

  Future<Map<String, Object?>?> latestJourneyReflection(
    String snapshotDate,
  ) async {
    final db = await localDatabase.database;
    final rows = await db.query(
      'reflection_results',
      where: '''
        source_type = ?
        AND source_id = ?
        AND reflection_type = ?
        AND status IN (?, ?)
      ''',
      whereArgs: [
        'journey_snapshot',
        snapshotDate,
        'reflect',
        'generated',
        'confirmed',
      ],
      orderBy: 'generated_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<Map<String, Object?>?> journeySnapshot(String snapshotDate) async {
    final db = await localDatabase.database;
    final rows = await db.query(
      'journey_snapshots',
      where: 'snapshot_date = ?',
      whereArgs: [snapshotDate],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<List<Map<String, Object?>>> traceLinksForSource({
    required String sourceType,
    required String sourceId,
  }) async {
    final db = await localDatabase.database;
    return db.query(
      'trace_links',
      where: 'source_type = ? AND source_id = ?',
      whereArgs: [sourceType, sourceId],
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
  ReportReadinessRule journeyReadinessRule = _testReadyJourneyRule,
}) async {
  final localDatabase = LocalDatabase(
    dbPathOverride: dbPath,
    databaseFactoryOverride: databaseFactoryFfi,
  );
  await localDatabase.init();

  final localCaptureRepository = LocalCaptureRepository(localDatabase);
  final localJourneySnapshotRepository =
      LocalJourneySnapshotRepository(localDatabase);
  final localLifeExperimentRepository =
      LocalLifeExperimentRepository(localDatabase);
  final localPhase3PlusRepository = LocalPhase3PlusRepository(localDatabase);
  final localWeeklySnapshotRepository =
      LocalWeeklySnapshotRepository(localDatabase);

  final repository = MemoryRepository(
    localCaptureRepository: localCaptureRepository,
    localJourneySnapshotRepository: localJourneySnapshotRepository,
    localLifeExperimentRepository: localLifeExperimentRepository,
    localPhase3PlusRepository: localPhase3PlusRepository,
    localWeeklySnapshotRepository: localWeeklySnapshotRepository,
    aiRepository: aiRepository,
    focusAreaLoader: () async => null,
    installationDateLoader: () async => installationDate,
    localUserId: 'test-user',
    journeyReadinessRule: journeyReadinessRule,
  );

  return _Harness(
    localDatabase: localDatabase,
    repository: repository,
    captureRepository: localCaptureRepository,
    lifeExperimentRepository: localLifeExperimentRepository,
    phase3PlusRepository: localPhase3PlusRepository,
  );
}

String _dateKey(DateTime date) {
  final local = date.toLocal();
  final mm = local.month.toString().padLeft(2, '0');
  final dd = local.day.toString().padLeft(2, '0');
  return '${local.year}-$mm-$dd';
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

class RecordingJourneyAiRepository extends AiRepository {
  List<Map<String, dynamic>> lastEntries = const [];
  List<String> lastTopTokens = const [];
  int? lastTotalDays;

  RecordingJourneyAiRepository()
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
    lastEntries = entries;
    lastTopTokens = topTokens;
    lastTotalDays = totalDays;
    return MemorySummaryModel(
      patterns: const [
        JourneySignalItemModel(
          name: '一个长期反复模式',
          summary: '这些记录开始形成可以轻轻回看的线索。',
          signalLevel: 'repeated_pattern',
        ),
      ],
      frictions: const [
        JourneySignalItemModel(
          name: '一个主要消耗来源',
          summary: '主要消耗先放在这里观察，不急着判断。',
          signalLevel: 'repeated_pattern',
        ),
      ],
      desires: const [
        JourneySignalItemModel(
          name: '一个恢复线索',
          summary: '恢复线索也会一起保留。',
          signalLevel: 'weak_signal',
        ),
      ],
      experiments: const [
        JourneySignalItemModel(
          name: '一个实验调整记录',
          summary: '实验反馈会进入之后的 Review & Adjust。',
          signalLevel: 'weak_signal',
        ),
      ],
    );
  }
}

class PressureJourneyAiRepository extends AiRepository {
  PressureJourneyAiRepository()
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
          name: '压力词测试',
          summary: '这是一个长期问题，你失败了，必须完成改变。',
          signalLevel: 'repeated_pattern',
        ),
      ],
      frictions: const [],
      desires: const [],
      experiments: const [],
    );
  }
}
