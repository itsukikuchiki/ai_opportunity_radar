import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_opportunity_radar/core/api/api_client.dart';
import 'package:ai_opportunity_radar/core/api/repositories/ai_repository.dart';
import 'package:ai_opportunity_radar/core/api/repositories/memory_repository.dart';
import 'package:ai_opportunity_radar/core/api/repositories/today_repository.dart';
import 'package:ai_opportunity_radar/core/api/repositories/weekly_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_capture_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_daily_snapshot_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/local/local_feedback_event_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_journey_snapshot_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_life_experiment_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_phase3_plus_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_weekly_snapshot_repository.dart';
import 'package:ai_opportunity_radar/core/models/memory_models.dart';
import 'package:ai_opportunity_radar/core/models/today_models.dart';
import 'package:ai_opportunity_radar/core/models/weekly_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String dbPath;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ai_radar_chain_test_');
    dbPath = p.join(tempDir.path, 'core_chain_test.db');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('P2.1-14 integration main chains', () {
    test(
        'new user main chain: Signal -> Observation -> Weekly Reflect -> Candidate -> next-week Life Experiment -> Feedback -> Rollup',
        () async {
      final harness = await _createHarness(dbPath: dbPath);

      try {
        await harness.todayRepository.submitCapture(
          content: '今天连续开会以后明显变累，想找一个更轻的恢复方式。',
          tagHint: 'work',
        );
        await harness.todayRepository.submitCapture(
          content: '午后切换任务时又出现一次明显疲惫。',
          tagHint: 'work',
        );
        await harness.todayRepository.submitCapture(
          content: '留出十分钟空档后，恢复开始得更容易。',
          tagHint: 'recovery',
        );

        // Local Today first writes captures; reading SignalCards mirrors the
        // saved capture into the V4 fact table and split processing fields.
        final signalCards =
            await harness.localCaptureRepository.listSignalCards(limit: 20);
        expect(signalCards, isNotEmpty);
        final signalCard = signalCards.firstWhere(
          (signal) => (signal.signalCardId ?? signal.id) == 'sig_core_1',
        );
        final signalCardId = signalCard.signalCardId ?? signalCard.id;

        final db = await harness.localDatabase.database;
        expect(await _rowCount(db, 'signal_cards'), greaterThan(0));

        final judgement =
            await harness.todayRepository.createAiJudgementForToday();
        expect(judgement, isNotNull);
        await harness.todayRepository.respondToAiJudgement(
          judgementId: judgement!.id,
          status: 'confirmed',
        );

        final observationRows = await db.query(
          'observations',
          where: 'source_ai_judgement_id = ?',
          whereArgs: [judgement.id],
          limit: 1,
        );
        expect(observationRows, isNotEmpty);
        expect(observationRows.first['status'], 'confirmed');
        final observationId = observationRows.first['id'] as String;

        final observationTraceRows = await db.query(
          'trace_links',
          where: '''
            source_type = ?
            AND source_id = ?
            AND target_type = ?
            AND target_id = ?
          ''',
          whereArgs: [
            'observation',
            observationId,
            'signal_card',
            signalCardId,
          ],
        );
        expect(observationTraceRows, isNotEmpty);

        final weekly = await harness.weeklyRepository.fetchCurrentWeekly();
        expect(weekly.status, isNot('first_day_gate'));

        final reflectionRows = await db.query(
          'reflection_results',
          where: '''
            source_type = ?
            AND source_id = ?
            AND reflection_type = ?
          ''',
          whereArgs: ['weekly_snapshot', weekly.weekStart, 'reflect'],
        );
        expect(reflectionRows, isNotEmpty);

        final candidateRows = await db.query(
          'experiment_candidates',
          where: 'local_user_id = ? AND source_id = ?',
          whereArgs: ['local', weekly.weekStart],
        );
        expect(candidateRows, hasLength(1));

        final candidate = await harness.weeklyRepository
            .fetchWeeklyExperimentCandidate(weekStart: weekly.weekStart);
        expect(candidate, isNotNull);
        expect(candidate!.id, startsWith('cand_'));

        final savedExperiment =
            await harness.weeklyRepository.saveLifeExperiment(candidate.id);
        expect(savedExperiment, isNotNull);

        final experimentRows = await db.query(
          'life_experiments',
          where: 'id = ?',
          whereArgs: [savedExperiment!.id],
        );
        expect(experimentRows, hasLength(1));

        await db.update(
          'life_experiments',
          {
            'progress_start_date': weekly.weekStart,
            'progress_end_date': weekly.weekEnd,
          },
          where: 'id = ?',
          whereArgs: [savedExperiment.id],
        );
        await harness.weeklyRepository.submitLifeExperimentFeedback(
          experimentId: savedExperiment.id,
          status: 'helpful',
          feedbackText: '做完以后恢复更容易开始。',
        );

        final feedbackEvents =
            await harness.localFeedbackEventRepository.listBetween(
          localUserId: 'local',
          startDate: weekly.weekStart,
          endDate: weekly.weekEnd,
        );
        expect(
          feedbackEvents.any(
            (event) =>
                event.sourceType == 'life_experiment_feedback' &&
                event.subjectId == savedExperiment.id,
          ),
          isTrue,
        );

        final rollups = await harness.localLifeExperimentRepository
            .listRollups(localUserId: 'local');
        expect(rollups, isNotEmpty);
        expect(
          rollups.any((rollup) =>
              rollup['experiment_id'] == savedExperiment.id &&
              (rollup['helpful_count'] as num?)?.toInt() == 1),
          isTrue,
        );

        await _seedJourneyReportReadiness(harness);
        final journey =
            await harness.memoryRepository.fetchMemorySummaryResult();
        expect(journey.summary, isNotNull);

        final futureRollupTraceId =
            'life_experiment_rollup_${savedExperiment.id}';
        expect(
          journey.summary!.journeyTraces.any(
            (trace) =>
                trace.sourceType == 'life_experiment_rollup' &&
                trace.id == futureRollupTraceId,
          ),
          isFalse,
          reason:
              'A candidate adopted this week is not active Journey evidence until next week.',
        );

        final journeyTraceLinks = await db.query(
          'trace_links',
          where: '''
            source_type = ?
            AND target_type = ?
            AND target_id = ?
          ''',
          whereArgs: [
            'journey_snapshot',
            'life_experiment_rollup',
            futureRollupTraceId,
          ],
        );
        expect(journeyTraceLinks, isEmpty);

        final observation = journey.summary!.observations.firstWhere(
          (item) => item.id == observationId,
        );
        expect(observation.status, 'confirmed');

        final evidence = await harness.memoryRepository.fetchJourneyEvidence(
          trace: JourneyTraceModel(
            id: observation.id,
            sourceType: 'observation',
            title: 'Observation',
            summary: observation.text,
            localDate: observation.localDate,
            cluster: 'observation',
            intensity: 0.7,
            signalLevel: 'repeated_pattern',
          ),
        );

        expect(
          evidence.any(
            (item) =>
                item.sourceType == 'signal_card' &&
                item.sourceId == signalCardId,
          ),
          isTrue,
        );
      } finally {
        await harness.close();
      }
    });

    test('真机 local_user_id 写入的 Observation 能被 Journey 读取', () async {
      const localUserId = 'device-user-observation-chain';
      final harness = await _createHarness(
        dbPath: dbPath,
        localUserId: localUserId,
      );

      try {
        await harness.todayRepository.submitCapture(
          content: '今天下午有点转不动，先补一句真实状态。',
          sourceType: 'one_tap',
          rawPayloadJson: const {
            'quick_status': 'tired',
            'energy_level': 0,
            'note': '今天下午有点转不动。',
          },
        );
        final judgement =
            await harness.todayRepository.createAiJudgementForToday();
        expect(judgement, isNotNull);

        final db = await harness.localDatabase.database;
        final rows = await db.query(
          'observations',
          where: 'source_ai_judgement_id = ?',
          whereArgs: [judgement!.id],
        );
        expect(rows, hasLength(1));
        expect(rows.single['local_user_id'], localUserId);

        await _seedJourneyReportReadiness(harness);
        final journey =
            await harness.memoryRepository.fetchMemorySummaryResult();
        expect(
          journey.summary?.observations.any(
            (observation) => observation.id == 'obs_${judgement.id}',
          ),
          isTrue,
        );
      } finally {
        await harness.close();
      }
    });

    test(
        'legacy user migration chain: old weekly snapshot migrates to candidates, reflection_results, and UI-readable weekly data',
        () async {
      final localDatabase = LocalDatabase(
        dbPathOverride: dbPath,
        databaseFactoryOverride: databaseFactoryFfi,
      );
      await localDatabase.init();

      try {
        final db = await localDatabase.database;
        await db.insert('signal_cards', {
          'id': 'sig_legacy_chain_001',
          'signal_card_id': 'sig_legacy_chain_001',
          'client_id': 'sig_legacy_chain_001',
          'server_id': 'sig_legacy_chain_001',
          'source_type': 'text',
          'raw_text': '旧用户记录：会议后需要轻恢复。',
          'created_at': '2026-07-01T09:00:00.000Z',
          'local_date': '2026-07-01',
          'timezone': 'Asia/Tokyo',
          'language': 'zh-Hans',
          'ai_reply': '旧 AI 回复',
          'observation': '旧 observation mirror',
          'try_next': '旧 try next mirror',
          'scene_tags_json': jsonEncode(['work']),
          'intent_tags_json': jsonEncode(['energy']),
          'user_confirmation': 'confirmed',
          'raw_payload_json': '{}',
          'user_correction_json': '{}',
          'included_in_summary': 1,
          'included_in_weekly': 1,
          'included_in_journey': 1,
          'privacy_level': 'private',
          'is_legacy': 1,
          'migration_status': 'local_legacy',
          'is_local_draft': 0,
          'sync_failed': 0,
          'sync_status': 'synced',
          'updated_at': '2026-07-01T09:01:00.000Z',
        });
        await db.insert('weekly_snapshots', {
          'week_start': '2026-07-01',
          'week_end': '2026-07-07',
          'status': 'ready',
          'key_insight': '旧 snapshot AI mirror：会议后能量下降。',
          'patterns_json': jsonEncode([
            {'name': '旧模式', 'summary': '会议后恢复需求反复出现。'}
          ]),
          'frictions_json': jsonEncode([
            {'name': '旧摩擦', 'summary': '连续会议后很难启动恢复。'}
          ]),
          'best_action': '午后留 10 分钟恢复。',
          'opportunity_snapshot_json': jsonEncode({
            'energy_budget': 'low',
            '_life_experiment': {
              'title': '旧链路轻恢复实验',
              'hypothesis': '把恢复动作降到 10 分钟更容易开始。',
              'suggested_action': '会议后做 10 分钟散步。',
              'status': 'suggested',
              'linked_signal_card_ids': ['sig_legacy_chain_001'],
            },
          }),
          'chart_data_json': '[]',
          'feedback_submitted': 0,
          'source_hash': 'legacy-chain-source',
          'generated_at': '2026-07-07T00:00:00.000Z',
        });
        await db.execute('PRAGMA user_version = 29');

        await localDatabase.close();

        final upgraded = LocalDatabase(
          dbPathOverride: dbPath,
          databaseFactoryOverride: databaseFactoryFfi,
        );
        await upgraded.init();

        try {
          final upgradedDb = await upgraded.database;
          expect(await _userVersion(upgradedDb), 40);

          final candidates = await upgradedDb.query('experiment_candidates');
          expect(candidates, hasLength(1));
          expect(candidates.single['title'], '旧链路轻恢复实验');
          expect(candidates.single['source_type'], 'weekly_reflection');
          expect(candidates.single['source_id'], '2026-07-01');

          final weeklyRows = await upgradedDb.query('weekly_snapshots');
          final opportunity = jsonDecode(
            weeklyRows.single['opportunity_snapshot_json'] as String,
          ) as Map<String, dynamic>;
          expect(opportunity.containsKey('_life_experiment'), isFalse);

          final reflections = await upgradedDb.query(
            'reflection_results',
            where: 'source_type = ? AND source_id = ?',
            whereArgs: ['weekly_snapshot', '2026-07-01'],
          );
          expect(reflections, hasLength(1));
          final content =
              jsonDecode(reflections.single['content_json'] as String)
                  as Map<String, dynamic>;
          expect(content['key_insight'], contains('旧 snapshot AI mirror'));
          final reflectedOpportunity =
              content['opportunity_snapshot'] as Map<String, dynamic>;
          expect(reflectedOpportunity.containsKey('_life_experiment'), isFalse);

          final localWeeklySnapshotRepository =
              LocalWeeklySnapshotRepository(upgraded);
          final weeklyRepository = WeeklyRepository(
            localCaptureRepository: LocalCaptureRepository(upgraded),
            localWeeklySnapshotRepository: localWeeklySnapshotRepository,
            localLifeExperimentRepository:
                LocalLifeExperimentRepository(upgraded),
            localPhase3PlusRepository: LocalPhase3PlusRepository(upgraded),
            aiRepository: CoreDataChainAiRepository(),
            focusAreaLoader: () async => null,
            installationDateLoader: () async => DateTime(2026, 6, 1),
            localUserId: 'local',
          );
          final weekly =
              await localWeeklySnapshotRepository.getByWeekStart('2026-07-01');
          final candidate =
              await weeklyRepository.fetchWeeklyExperimentCandidate(
            weekStart: '2026-07-01',
          );

          expect(weekly, isNotNull);
          expect(weekly!.weekStart, '2026-07-01');
          expect(weekly.keyInsight, contains('旧 snapshot AI mirror'));
          expect(candidate?.title, '旧链路轻恢复实验');
        } finally {
          await upgraded.close();
        }
      } finally {
        await localDatabase.close();
      }
    });

    test(
        'delete/privacy/stale chain: excluded Signal inactivates traces, stales upper data, and disappears from active Journey evidence',
        () async {
      final harness = await _createHarness(dbPath: dbPath);

      try {
        await harness.todayRepository.submitCapture(
          content: '今天连续开会后很累，这条会先进入上层再被排除。',
          tagHint: 'work',
        );
        await harness.todayRepository.submitCapture(
          content: '午后切换任务时又出现一次明显疲惫。',
          tagHint: 'work',
        );
        await harness.todayRepository.submitCapture(
          content: '留出十分钟空档后，恢复开始得更容易。',
          tagHint: 'recovery',
        );
        final signalCards =
            await harness.localCaptureRepository.listSignalCards(limit: 20);
        final signalCard = signalCards.firstWhere(
          (signal) => (signal.signalCardId ?? signal.id) == 'sig_core_1',
        );
        final signalCardId = signalCard.signalCardId ?? signalCard.id;
        expect(signalCardId, isNotNull);

        await _seedJourneyReportReadiness(harness);
        final weekly = await harness.weeklyRepository.fetchCurrentWeekly();
        final journeyBefore =
            await harness.memoryRepository.fetchMemorySummaryResult();
        expect(journeyBefore.summary, isNotNull);

        final db = await harness.localDatabase.database;
        final activeEvidenceBefore = await db.query(
          'trace_links',
          where: 'target_type = ? AND target_id = ? AND status = ?',
          whereArgs: ['signal_card', signalCardId, 'active'],
        );
        expect(activeEvidenceBefore, isNotEmpty);

        await harness.localCaptureRepository.updateSignalCardPrivacy(
          signalCardId: signalCardId!,
          privacyLevel: 'do_not_analyze',
        );

        final inactiveLinks = await db.query(
          'trace_links',
          where: 'target_type = ? AND target_id = ?',
          whereArgs: ['signal_card', signalCardId],
        );
        expect(inactiveLinks, isNotEmpty);
        expect(
            inactiveLinks.every((row) => row['status'] == 'inactive'), isTrue);

        final weeklyRows = await db.query(
          'weekly_snapshots',
          where: 'week_start = ?',
          whereArgs: [weekly.weekStart],
        );
        expect(weeklyRows.single['is_stale'], 1);
        expect(weeklyRows.single['stale_reason'], 'signal_privacy_excluded');

        final reflectionRows = await db.query(
          'reflection_results',
          where: 'source_type = ? AND source_id = ?',
          whereArgs: ['weekly_snapshot', weekly.weekStart],
        );
        expect(reflectionRows, isNotEmpty);
        expect(reflectionRows.single['is_stale'], 1);
        expect(
            reflectionRows.single['stale_reason'], 'signal_privacy_excluded');

        final candidateRows = await db.query(
          'experiment_candidates',
          where: 'source_id = ?',
          whereArgs: [weekly.weekStart],
        );
        expect(candidateRows, isNotEmpty);
        expect(candidateRows.single['is_stale'], 1);
        expect(candidateRows.single['stale_reason'], 'signal_privacy_excluded');

        final journeyAfter =
            await harness.memoryRepository.fetchMemorySummaryResult();
        final activeEvidenceAfter = await db.query(
          'trace_links',
          where: 'target_type = ? AND target_id = ? AND status = ?',
          whereArgs: ['signal_card', signalCardId, 'active'],
        );
        expect(activeEvidenceAfter, isEmpty);
        expect(
          journeyAfter.summary?.journeyTraces.any(
                (trace) => trace.id == signalCardId,
              ) ??
              false,
          isFalse,
        );
      } finally {
        await harness.close();
      }
    });
  });
}

Future<void> _seedJourneyReportReadiness(_Harness harness) async {
  final now = DateTime.now();
  final db = await harness.localDatabase.database;
  for (var index = 0; index < 7; index += 1) {
    final id = 'journey_chain_gate_$index';
    await harness.localCaptureRepository.insertConfirmedSignalCard(
      signalCardId: id,
      sourceType: 'text',
      content: '用于验证 Journey 报告门槛的真实信号 $index',
      userConfirmation: 'confirmed',
    );
    final localDay = now.subtract(Duration(days: index % 3));
    await db.update(
      'signal_cards',
      {
        'local_date': _dateKey(localDay),
        'created_at': localDay.toUtc().toIso8601String(),
        'updated_at': localDay.toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

Future<_Harness> _createHarness({
  required String dbPath,
  String localUserId = 'local',
}) async {
  final localDatabase = LocalDatabase(
    dbPathOverride: dbPath,
    databaseFactoryOverride: databaseFactoryFfi,
  );
  await localDatabase.init();
  final localCaptureRepository = LocalCaptureRepository(localDatabase);
  final localDailySnapshotRepository =
      LocalDailySnapshotRepository(localDatabase);
  final localWeeklySnapshotRepository =
      LocalWeeklySnapshotRepository(localDatabase);
  final localJourneySnapshotRepository =
      LocalJourneySnapshotRepository(localDatabase);
  final localLifeExperimentRepository =
      LocalLifeExperimentRepository(localDatabase);
  final localPhase3PlusRepository = LocalPhase3PlusRepository(
    localDatabase,
    localUserId: localUserId,
  );
  final localFeedbackEventRepository =
      LocalFeedbackEventRepository(localDatabase);
  final aiRepository = CoreDataChainAiRepository();
  final signalCardApiClient = CoreDataChainApiClient();

  final todayRepository = TodayRepository(
    localCaptureRepository: localCaptureRepository,
    localDailySnapshotRepository: localDailySnapshotRepository,
    localLifeExperimentRepository: localLifeExperimentRepository,
    localPhase3PlusRepository: localPhase3PlusRepository,
    aiRepository: aiRepository,
    apiClient: signalCardApiClient,
    focusAreaLoader: () async => null,
    responseStyleLoader: () async => 'gentle',
  );
  final weeklyRepository = WeeklyRepository(
    localCaptureRepository: localCaptureRepository,
    localWeeklySnapshotRepository: localWeeklySnapshotRepository,
    localLifeExperimentRepository: localLifeExperimentRepository,
    localPhase3PlusRepository: localPhase3PlusRepository,
    aiRepository: aiRepository,
    focusAreaLoader: () async => null,
    installationDateLoader: () async =>
        DateTime.now().subtract(const Duration(days: 14)),
    localUserId: localUserId,
  );
  final memoryRepository = MemoryRepository(
    localCaptureRepository: localCaptureRepository,
    localJourneySnapshotRepository: localJourneySnapshotRepository,
    localLifeExperimentRepository: localLifeExperimentRepository,
    localPhase3PlusRepository: localPhase3PlusRepository,
    localWeeklySnapshotRepository: localWeeklySnapshotRepository,
    aiRepository: aiRepository,
    focusAreaLoader: () async => null,
    installationDateLoader: () async =>
        DateTime.now().subtract(const Duration(days: 40)),
    localUserId: localUserId,
  );

  return _Harness(
    localDatabase: localDatabase,
    localCaptureRepository: localCaptureRepository,
    localLifeExperimentRepository: localLifeExperimentRepository,
    localFeedbackEventRepository: localFeedbackEventRepository,
    todayRepository: todayRepository,
    weeklyRepository: weeklyRepository,
    memoryRepository: memoryRepository,
  );
}

Future<int> _rowCount(Database db, String table) async {
  final rows = await db.rawQuery('SELECT COUNT(*) AS count FROM $table');
  return (rows.first['count'] as num).toInt();
}

Future<int> _userVersion(Database db) async {
  final rows = await db.rawQuery('PRAGMA user_version');
  return rows.single.values.single as int;
}

class _Harness {
  final LocalDatabase localDatabase;
  final LocalCaptureRepository localCaptureRepository;
  final LocalLifeExperimentRepository localLifeExperimentRepository;
  final LocalFeedbackEventRepository localFeedbackEventRepository;
  final TodayRepository todayRepository;
  final WeeklyRepository weeklyRepository;
  final MemoryRepository memoryRepository;

  const _Harness({
    required this.localDatabase,
    required this.localCaptureRepository,
    required this.localLifeExperimentRepository,
    required this.localFeedbackEventRepository,
    required this.todayRepository,
    required this.weeklyRepository,
    required this.memoryRepository,
  });

  Future<void> close() => localDatabase.close();
}

class CoreDataChainAiRepository extends AiRepository {
  CoreDataChainAiRepository()
      : super(
          ApiClient(
            baseUrl: 'https://example.invalid',
            userId: 'local',
          ),
        );

  @override
  Future<AiCaptureReplyResult> generateCaptureReply({
    required String content,
    required List<String> recentAssistantTexts,
    String? focusArea,
    String? responseStyle,
  }) async {
    return AiCaptureReplyResult(
      acknowledgement: '先记下这条能量变化。',
      observation: '会议后的能量消耗偏高。',
      tryNext: '下一次会议后先做一个很轻的恢复动作。',
      emotion: 'tired',
      intensity: 'medium',
      sceneTags: ['work', 'meeting'],
      intentTags: ['energy', 'experiment'],
      followup: null,
    );
  }

  @override
  Future<AiTodaySummaryResult> generateTodaySummary({
    required DateTime date,
    required List<RecentSignalModel> entries,
    String? focusArea,
    String? responseStyle,
  }) async {
    return AiTodaySummaryResult(
      observation: '今天出现了 ${entries.length} 条可追踪的能量变化。',
      suggestion: '先把会议后的恢复动作做得更轻。',
    );
  }

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
      status: 'light_ready',
      keyInsight: '会议后的能量下降是本周最明确的线索。',
      patterns: const [
        {
          'name': '会议后恢复',
          'summary': '高消耗场景后更适合低强度实验。',
        },
      ],
      frictions: const [
        {
          'name': '连续会议',
          'summary': '切换成本让恢复更难开始。',
        },
      ],
      bestAction: '本周先追加一个 5 分钟恢复实验。',
      opportunitySnapshot: const {
        'name': '会议后的轻恢复',
        'summary': '把小实验强度压低，先验证能否开始。',
      },
      feedbackSubmitted: false,
    );
  }

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
          name: '能量变化正在变得稳定可见',
          summary: '会议后的恢复需求不再只是单次事件。',
          signalLevel: 'repeated_pattern',
        ),
      ],
      frictions: const [
        JourneySignalItemModel(
          name: '高密度切换',
          summary: '连续会议仍是主要消耗来源。',
          signalLevel: 'repeated_pattern',
        ),
      ],
      desires: const [
        JourneySignalItemModel(
          name: '更轻的恢复方式',
          summary: '用户正在寻找能实际开始的小动作。',
          signalLevel: 'weak_signal',
        ),
      ],
      experiments: const [
        JourneySignalItemModel(
          name: '5 分钟恢复实验',
          summary: '实验反馈开始进入长期路径。',
          signalLevel: 'weak_signal',
        ),
      ],
    );
  }
}

class CoreDataChainApiClient extends ApiClient {
  int _signalSequence = 0;

  CoreDataChainApiClient()
      : super(
          baseUrl: 'https://example.invalid',
          userId: 'local',
        );

  @override
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    if (path != '/api/v1/captures') {
      throw UnsupportedError('Unexpected POST $path in core data chain test');
    }
    final now = DateTime.now();
    final localDate = _dateKey(now);
    final signalId = 'sig_core_${++_signalSequence}';
    return {
      'data': {
        'recent_signals': [
          {
            'id': signalId,
            'signal_card_id': signalId,
            'content': body['content'] as String? ?? '',
            'raw_text': body['content'] as String? ?? '',
            'created_at': now.toUtc().toIso8601String(),
            'local_date': localDate,
            'timezone': now.timeZoneName,
            'acknowledgement': '先记下这条能量变化。',
            'observation': '会议后的能量消耗偏高。',
            'try_next': '下一次会议后先做一个很轻的恢复动作。',
            'emotion': 'tired',
            'intensity': 'medium',
            'scene': 'work',
            'friction': 'meeting_load',
            'energy_load': 'draining',
            'scene_tags': ['work', 'meeting'],
            'intent_tags': ['energy', 'experiment'],
            'user_confirmation': 'confirmed',
            'is_legacy': false,
            'migration_status': 'native',
            'is_local_draft': false,
            'sync_failed': false,
            'sync_status': 'synced',
            'privacy_level': 'private',
          },
        ],
      },
    };
  }
}

String _dateKey(DateTime date) {
  final local = date.toLocal();
  final mm = local.month.toString().padLeft(2, '0');
  final dd = local.day.toString().padLeft(2, '0');
  return '${local.year}-$mm-$dd';
}
