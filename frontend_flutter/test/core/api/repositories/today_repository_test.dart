import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_opportunity_radar/core/api/api_client.dart';
import 'package:ai_opportunity_radar/core/api/repositories/ai_repository.dart';
import 'package:ai_opportunity_radar/core/api/repositories/today_repository.dart';
import 'package:ai_opportunity_radar/core/i18n/app_locale_text.dart';
import 'package:ai_opportunity_radar/core/local/local_candidate_planning_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_capture_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_daily_snapshot_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/local/local_experiment_candidate_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_life_experiment_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_phase3_plus_repository.dart';
import 'package:ai_opportunity_radar/core/models/experiment_evaluation_models.dart';
import 'package:ai_opportunity_radar/core/models/phase3_plus_models.dart';
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
          todayObservationBuilder: (entries) =>
              '今天记录了 ${entries.length} 条，烦躁主要集中在工作里。',
          todaySuggestionBuilder: (entries) => '今天先试试：再出现一次同类情绪时补记一条。',
        ),
      );

      await harness.repository.submitCapture(content: '第一条：有点烦');
      var data = await harness.repository.fetchToday();

      expect(
          (data['insight'] as TodayInsightModel).text, contains('今天记录了 1 条'));
      expect(
          (data['bestAction'] as DailyBestActionModel).text, contains('今天先试试'));

      await harness.repository.submitCapture(content: '第二条：还是烦');
      data = await harness.repository.fetchToday();

      expect(
          (data['insight'] as TodayInsightModel).text, contains('今天记录了 2 条'));
      expect(
          (data['bestAction'] as DailyBestActionModel).text, contains('补记一条'));

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

    test('5) 会把 response style 传给 AI repository', () async {
      final ai = TrackingAiRepository();
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: ai,
        responseStyleLoader: () async => 'direct',
      );

      await harness.repository.submitCapture(content: '今天上班很烦');
      await harness.repository.fetchToday();

      expect(ai.captureReplyStyles, ['direct']);
      expect(ai.todaySummaryStyles, ['direct']);

      await harness.close();
    });

    test('6) 本地 time_use v2 保存统一关注领域与可选精力', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeAiRepository(),
      );

      await harness.repository.submitCapture(
        content: '09:00–10:30 · 自我边界 · 团队会议',
        sourceType: 'time_use',
        rawPayloadJson: const {
          'timeline_type': 'time_use',
          'schema_version': 2,
          'title': '团队会议',
          'record_status': 'completed',
          'focus_domain_id': 'self_boundary',
          'start_at': '2026-07-15T09:00:00+09:00',
          'end_at': '2026-07-15T10:30:00+09:00',
          'duration_minutes': 90,
          'energy_level': 0,
        },
      );

      final signals =
          await harness.localCaptureRepository.listSignalCards(limit: 10);
      final signal = signals.single;
      expect(signal.sourceType, 'time_use');
      expect(signal.isLegacy, isFalse);
      expect(signal.rawPayloadJson['focus_domain_id'], 'self_boundary');
      expect(signal.rawPayloadJson['category'], 'self_boundary');
      expect(signal.rawPayloadJson['duration_minutes'], 90);
      expect(signal.rawPayloadJson['energy_level'], 0);
      expect(signal.rawPayloadJson, isNot(contains('energy_effect')));
      expect(signal.scene, 'self_boundary');
      expect(signal.energyLoad, isNull);

      await harness.close();
    });

    test('7) planned time_use 省略精力，unknown 不落库', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeAiRepository(),
      );

      await harness.repository.submitCapture(
        content: '13:00–14:00 · 成长计划 · 阅读',
        sourceType: 'time_use',
        rawPayloadJson: const {
          'timeline_type': 'time_use',
          'schema_version': 2,
          'title': '阅读',
          'record_status': 'planned',
          'category': 'growth_plan',
          'start_at': '2026-07-15T13:00:00+09:00',
          'end_at': '2026-07-15T14:00:00+09:00',
          'duration_minutes': 60,
          'energy_level': 2,
          'energy_effect': 'unknown',
        },
      );

      final signal = (await harness.localCaptureRepository.listSignalCards(
        limit: 10,
      ))
          .single;
      expect(signal.rawPayloadJson['focus_domain_id'], 'growth_plan');
      expect(signal.rawPayloadJson['category'], 'growth_plan');
      expect(signal.rawPayloadJson, isNot(contains('energy_level')));
      expect(signal.rawPayloadJson, isNot(contains('energy_effect')));
      expect(signal.energyLoad, isNull);

      await harness.close();
    });

    test('8) time_use v1 的明确 energy_effect 保持兼容', () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeAiRepository(),
      );

      await harness.repository.submitCapture(
        content: '散步后缓过来一些',
        sourceType: 'time_use',
        rawPayloadJson: const {
          'timeline_type': 'time_use',
          'schema_version': 1,
          'title': '散步',
          'record_status': 'completed',
          'category': 'recovery',
          'energy_effect': 'restoring',
        },
      );

      final signal = (await harness.localCaptureRepository.listSignalCards(
        limit: 10,
      ))
          .single;
      expect(signal.rawPayloadJson['category'], 'recovery');
      expect(signal.rawPayloadJson, isNot(contains('focus_domain_id')));
      expect(signal.rawPayloadJson['energy_effect'], 'restoring');
      expect(signal.energyLoad, 'restoring');

      await harness.close();
    });
  });

  group('V3B SignalCard data loop', () {
    test('首次远端 SignalCard 提交携带本地 client_id 保证幂等', () async {
      final api = FakeSignalCardApiClient(recentSignals: const []);
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeAiRepository(),
        apiClient: api,
      );

      await harness.repository.submitCapture(
        content: '第一次提交也要带 client id',
        sourceType: 'voice',
        rawPayloadJson: const {'audio_uploaded': false},
      );

      expect(api.postCalls, isNotEmpty);
      final body = api.postCalls.single['body'] as Map<String, dynamic>;
      expect(body['client_id'], isA<String>());
      expect(body['client_id'], startsWith('draft_'));
      expect(body['input_mode'], 'voice');
      expect(body['raw_payload_json'], {'audio_uploaded': false});

      await harness.close();
    });

    test('Today 读取远端 SignalCard，并保留 legacy / local_date 状态', () async {
      final api = FakeSignalCardApiClient(
        recentSignals: [
          {
            'id': 'raw-old',
            'signal_card_id': 'sig-old',
            'content': '旧记录原文',
            'created_at': '2026-05-18T15:30:00Z',
            'local_date': '2026-05-19',
            'timezone': 'Asia/Tokyo',
            'acknowledgement': '旧 AI 回复',
            'emotion': 'negative',
            'scene': 'work',
            'friction': 'interruptions',
            'energy_load': 'drain',
            'user_confirmation': 'unconfirmed',
            'is_legacy': true,
            'migration_status': 'migrated',
            'included_in_weekly': true,
          },
        ],
      );
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeAiRepository(),
        apiClient: api,
      );

      final data = await harness.repository.fetchToday();
      final signals =
          data['recentSignals'] as List<RecentSignalModel>? ?? const [];

      expect(signals, hasLength(1));
      expect(signals.first.signalCardId, 'sig-old');
      expect(signals.first.content, '旧记录原文');
      expect(signals.first.acknowledgement, '旧 AI 回复');
      expect(signals.first.localDateKey(), '2026-05-19');
      expect(signals.first.isLegacy, true);
      expect(signals.first.migrationStatus, 'migrated');
      expect(signals.first.includedInWeekly, true);

      final dialogSignal = await harness.repository.getCaptureById('sig-old');
      expect(dialogSignal, isNotNull);
      expect(dialogSignal!.content, '旧记录原文');
      expect(dialogSignal.acknowledgement, '旧 AI 回复');

      await harness.close();
    });

    test('Timeline 分组使用 SignalCard local_date，不按 UTC 日期错分', () {
      final signal = RecentSignalModel.fromJson({
        'signal_card_id': 'sig-tz',
        'content': '深夜记录',
        'created_at': '2026-05-18T15:30:00Z',
        'local_date': '2026-05-19',
      });

      expect(signal.localDateKey(), '2026-05-19');
    });

    test('无时区标记的服务端 created_at 按 UTC 解析并正确写入缓存', () async {
      final api = FakeSignalCardApiClient(
        recentSignals: const [
          {
            'id': 'raw-naive-utc',
            'signal_card_id': 'sig-naive-utc',
            'content': '东京下午记录',
            'created_at': '2026-07-15T04:06:00',
            'local_date': '2026-07-15',
            'timezone': 'Asia/Tokyo',
          },
        ],
      );
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeAiRepository(),
        apiClient: api,
      );

      final data = await harness.repository.fetchToday();
      final signal = (data['recentSignals'] as List<RecentSignalModel>).single;
      final cached =
          (await harness.localCaptureRepository.listSignalCards()).single;
      final expectedLocal = DateTime.utc(2026, 7, 15, 4, 6).toLocal();

      expect(signal.createdAt!.toUtc(), DateTime.utc(2026, 7, 15, 4, 6));
      expect(signal.createdAt!.isUtc, isFalse);
      expect(signal.createdAt!.hour, expectedLocal.hour);
      expect(signal.createdAt!.minute, expectedLocal.minute);
      expect(cached.createdAt!.toUtc(), DateTime.utc(2026, 7, 15, 4, 6));

      await harness.close();
    });

    test('user_confirmation 和 user_correction_json 会先写入本地并同步 PATCH', () async {
      final api = FakeSignalCardApiClient(
        recentSignals: [
          {
            'id': 'raw-1',
            'signal_card_id': 'sig-1',
            'content': '需要修正的记录',
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'local_date': _testDateKey(DateTime.now()),
            'acknowledgement': '保存的回复',
          },
        ],
      );
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeAiRepository(),
        apiClient: api,
      );

      await harness.repository.fetchToday();
      await harness.repository.confirmSignalCard(
        signalCardId: 'sig-1',
        userConfirmation: 'edited',
        userCorrectionJson: {'edited_text': '修正后的内容'},
      );

      expect(api.patchCalls, hasLength(1));
      expect(api.patchCalls.first['path'],
          '/api/v1/captures/signal-cards/sig-1/confirmation');

      final cached = await harness.localCaptureRepository.listSignalCards();
      expect(cached.first.userConfirmation, 'edited');
      expect(cached.first.userCorrectionJson['edited_text'], '修正后的内容');

      await harness.close();
    });

    test('backend unreachable 时先保存 local draft，retry 后替换为 SignalCard',
        () async {
      final api = FakeSignalCardApiClient(
        failPost: true,
        recentSignals: const [],
      );
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeAiRepository(),
        apiClient: api,
      );

      const statusPayload = {
        'quick_status': 'tired',
        'energy_level': 0,
        'note': '下午开始有点转不动。',
      };
      await harness.repository.submitCapture(
        content: '断网时也不能丢',
        sourceType: 'one_tap',
        rawPayloadJson: statusPayload,
      );

      var cached = await harness.localCaptureRepository.listSignalCards();
      expect(cached.any((signal) => signal.content == '断网时也不能丢'), true);
      expect(cached.first.isLocalDraft, true);
      expect(cached.first.syncFailed, true);
      final draftClientId = cached.first.clientId;
      expect(draftClientId, isNotNull);
      expect(draftClientId, startsWith('draft_'));

      api
        ..failPost = false
        ..recentSignals = [
          {
            'id': 'raw-retry',
            'signal_card_id': 'sig-retry',
            'client_id': draftClientId,
            'source_type': 'one_tap',
            'raw_payload_json': statusPayload,
            'content': '断网时也不能丢',
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'local_date': _testDateKey(DateTime.now()),
            'acknowledgement': 'retry 后保存的 AI 回复',
          },
        ];

      await harness.repository.retryPendingDrafts();
      cached = await harness.localCaptureRepository.listSignalCards();

      expect(api.postCalls.last['body']['client_id'], draftClientId);
      expect(api.postCalls.last['body']['input_mode'], 'one_tap');
      expect(api.postCalls.last['body']['raw_payload_json'], statusPayload);
      expect(
          cached.where((signal) => signal.content == '断网时也不能丢'), hasLength(1));
      expect(cached.first.signalCardId, 'sig-retry');
      expect(cached.first.clientId, draftClientId);
      expect(cached.first.sourceType, 'one_tap');
      expect(cached.first.rawPayloadJson, statusPayload);
      expect(cached.first.acknowledgement, 'retry 后保存的 AI 回复');
      expect(cached.first.isLocalDraft, false);

      await harness.close();
    });

    test('Today Summary 读取 SignalCard，并把 eligible card 标记为 included_in_summary',
        () async {
      final ai = RecordingSummaryAiRepository();
      final api = FakeSignalCardApiClient(
        recentSignals: [
          {
            'id': 'raw-summary',
            'signal_card_id': 'sig-summary',
            'content': '今天完成了一个小任务',
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'local_date': _testDateKey(DateTime.now()),
            'acknowledgement': '保存的 AI 回复',
            'user_confirmation': 'unconfirmed',
          },
        ],
      );
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: ai,
        apiClient: api,
      );

      final data = await harness.repository.fetchToday();
      final signals =
          data['recentSignals'] as List<RecentSignalModel>? ?? const [];

      expect(
          ai.lastSummaryEntries.map((e) => e.content), contains('今天完成了一个小任务'));
      expect(signals.single.includedInSummary, true);
      expect(signals.single.userConfirmation, 'unconfirmed');

      await harness.close();
    });

    test('Today Summary failure 不影响 SignalCard 保存', () async {
      final api = FakeSignalCardApiClient(
        recentSignals: [
          {
            'id': 'raw-fallback',
            'signal_card_id': 'sig-fallback',
            'content': 'summary 失败也要保留',
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'local_date': _testDateKey(DateTime.now()),
            'acknowledgement': '保存的 AI 回复',
          },
        ],
      );
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FailingAiRepository(),
        apiClient: api,
      );

      await harness.repository.submitCapture(content: 'summary 失败也要保留');

      final data = await harness.repository.fetchToday();
      final signals =
          data['recentSignals'] as List<RecentSignalModel>? ?? const [];
      final insight = data['insight'] as TodayInsightModel;

      expect(signals.any((signal) => signal.content == 'summary 失败也要保留'), true);
      expect(insight.text.isNotEmpty, true);

      await harness.close();
    });

    test('只有本地 draft 时 Summary 延后整理，不把 draft 标记为 included', () async {
      final api = FakeSignalCardApiClient(
        failPost: true,
        recentSignals: const [],
      );
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FailingAiRepository(),
        apiClient: api,
      );

      await harness.repository.submitCapture(content: '断网先保存原文');

      final data = await harness.repository.fetchToday();
      final signals =
          data['recentSignals'] as List<RecentSignalModel>? ?? const [];
      final insight = data['insight'] as TodayInsightModel;

      expect(signals.single.content, '断网先保存原文');
      expect(signals.single.isLocalDraft, true);
      expect(signals.single.includedInSummary, false);
      expect(await harness.repository.createAiJudgementForToday(), isNull);
      expect(insight.text, contains('原文已经保存'));
      expect(insight.text, contains('同步'));

      await harness.close();
    });

    test(
        'legacy schedule stays stored but no longer enters Today or AI judgement',
        () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeAiRepository(),
      );
      final db = await harness.localDatabase.database;
      final now = DateTime.now();
      final today = _testDateKey(now);
      await db.insert('schedule_signals', {
        'id': 'legacy-schedule',
        'title': 'Legacy schedule',
        'local_date': today,
        'anchor_date': today,
        'date_precision': 'date',
        'time_precision': 'none',
        'created_at': now.toUtc().toIso8601String(),
        'updated_at': now.toUtc().toIso8601String(),
      });

      final data = await harness.repository.fetchToday();

      expect(data.containsKey('scheduleSignals'), isFalse);
      expect(data['aiJudgement'], isNull);
      expect(await db.query('schedule_signals'), hasLength(1));

      await harness.close();
    });

    test('legacy / inaccurate 不进入 Summary，unconfirmed 不被伪造成 confirmed',
        () async {
      final ai = RecordingSummaryAiRepository();
      final today = _testDateKey(DateTime.now());
      final api = FakeSignalCardApiClient(
        recentSignals: [
          {
            'id': 'raw-native',
            'signal_card_id': 'sig-native',
            'content': '原生未确认记录可以作为小观察',
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'local_date': today,
            'acknowledgement': '保存的 AI 回复',
            'user_confirmation': 'unconfirmed',
          },
          {
            'id': 'raw-legacy',
            'signal_card_id': 'sig-legacy',
            'content': '旧记录先只进入 Timeline',
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'local_date': today,
            'acknowledgement': '旧 AI 回复',
            'user_confirmation': 'unconfirmed',
            'is_legacy': true,
            'migration_status': 'migrated',
          },
          {
            'id': 'raw-inaccurate',
            'signal_card_id': 'sig-inaccurate',
            'content': '用户标记不准的记录',
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'local_date': today,
            'acknowledgement': '不该进入 summary 的回复',
            'user_confirmation': 'inaccurate',
          },
        ],
      );
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: ai,
        apiClient: api,
      );

      final data = await harness.repository.fetchToday();
      final signals =
          data['recentSignals'] as List<RecentSignalModel>? ?? const [];

      expect(ai.lastSummaryEntries.map((e) => e.content), ['原生未确认记录可以作为小观察']);

      final native =
          signals.firstWhere((signal) => signal.signalCardId == 'sig-native');
      final legacy =
          signals.firstWhere((signal) => signal.signalCardId == 'sig-legacy');
      final inaccurate = signals
          .firstWhere((signal) => signal.signalCardId == 'sig-inaccurate');

      expect(native.userConfirmation, 'unconfirmed');
      expect(native.includedInSummary, true);
      expect(legacy.isLegacy, true);
      expect(legacy.includedInSummary, false);
      expect(inaccurate.userConfirmation, 'inaccurate');
      expect(inaccurate.includedInSummary, false);

      await harness.close();
    });

    test('Today 有真实来源时自动生成预判，partial 不加入时零写入', () async {
      final today = _testDateKey(DateTime.now());
      final api = FakeSignalCardApiClient(
        recentSignals: [
          {
            'id': 'raw-auto-prediction',
            'signal_card_id': 'sig-auto-prediction',
            'source_type': 'text',
            'content': '连续会议以后有点累，脑子一直在切换。',
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'local_date': today,
            'acknowledgement': '已保存。',
            'user_confirmation': 'unconfirmed',
          },
        ],
      );
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeAiRepository(),
        apiClient: api,
      );

      final data = await harness.repository.fetchToday();
      final judgement = data['aiJudgement'] as AiJudgementModel?;
      expect(judgement, isNotNull);
      expect(judgement!.status, 'pending');
      final db = await harness.localDatabase.database;
      final before = await db.query(
        'observations',
        where: 'source_ai_judgement_id = ?',
        whereArgs: [judgement.id],
      );
      const persistedTables = <String>[
        'signal_cards',
        'observations',
        'ai_judgements',
        'daily_snapshots',
        'reflection_results',
        'pipeline_runs',
        'micro_action_feedback',
        'life_experiment_feedback',
        'trace_links',
      ];
      Future<Map<String, List<Map<String, Object?>>>> persistedState() async {
        final state = <String, List<Map<String, Object?>>>{};
        for (final table in persistedTables) {
          state[table] = await db.query(table, orderBy: 'rowid ASC');
        }
        return state;
      }

      final stateBeforeDismiss = await persistedState();

      final alternate = await harness.repository.createAiJudgementForToday(
        language: AppLanguage.simplifiedChinese,
        variationIndex: 1,
      );
      expect(alternate, isNotNull);
      expect(
          alternate!.predictedSignalText, isNot(judgement.predictedSignalText));
      expect(await persistedState(), stateBeforeDismiss);

      await harness.repository.respondToAiJudgement(
        judgementId: judgement.id,
        status: 'partial',
        userAdjustmentText: '有一点像，更接近频繁切换带来的消耗。',
        addToTimeline: false,
        language: AppLanguage.simplifiedChinese,
      );

      final signals = await harness.localCaptureRepository.listSignalCards();
      expect(signals.where((signal) => signal.sourceType == 'ai_predicted'),
          isEmpty);
      final observations = await db.query(
        'observations',
        where: 'source_ai_judgement_id = ?',
        whereArgs: [judgement.id],
      );
      expect(observations.single['status'], before.single['status']);
      expect(
        observations.single['observation_text'],
        before.single['observation_text'],
      );
      expect(await persistedState(), stateBeforeDismiss);

      await harness.close();
    });

    test('accurate 编辑后只写一条 ai_predicted 时间线，inaccurate 不写入', () async {
      final today = _testDateKey(DateTime.now());
      final api = FakeSignalCardApiClient(
        recentSignals: [
          {
            'id': 'raw-accurate-prediction',
            'signal_card_id': 'sig-accurate-prediction',
            'source_type': 'text',
            'content': '今天安排很密，晚上明显疲惫。',
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'local_date': today,
            'acknowledgement': '已保存。',
            'user_confirmation': 'unconfirmed',
          },
        ],
      );
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeAiRepository(),
        apiClient: api,
      );

      final data = await harness.repository.fetchToday();
      final judgement = data['aiJudgement'] as AiJudgementModel;
      await harness.repository.respondToAiJudgement(
        judgementId: judgement.id,
        status: 'accurate',
        userAdjustmentText: '连续会议以后，我确实需要先恢复十分钟。',
        addToTimeline: true,
        language: AppLanguage.simplifiedChinese,
      );
      await harness.repository.respondToAiJudgement(
        judgementId: judgement.id,
        status: 'accurate',
        userAdjustmentText: '连续会议以后，我确实需要先恢复十分钟。',
        addToTimeline: true,
        language: AppLanguage.simplifiedChinese,
      );

      var signals = await harness.localCaptureRepository.listSignalCards();
      final predicted =
          signals.where((signal) => signal.sourceType == 'ai_predicted');
      expect(predicted, hasLength(1));
      expect(predicted.single.content, '连续会议以后，我确实需要先恢复十分钟。');
      expect(predicted.single.acknowledgement, isNot(predicted.single.content));
      expect(predicted.single.acknowledgement, contains('加入时间线'));
      expect(
          predicted.single.rawPayloadJson['confirmation_status'], 'accurate');
      expect(predicted.single.rawPayloadJson['added_to_timeline'], isTrue);

      final secondHarness = await _createHarness(
        dbPath: p.join(tempDir.path, 'inaccurate_prediction.db'),
        aiRepository: FakeAiRepository(),
        apiClient: api,
      );
      final secondData = await secondHarness.repository.fetchToday();
      final secondJudgement = secondData['aiJudgement'] as AiJudgementModel;
      final secondDb = await secondHarness.localDatabase.database;
      final beforeDismiss = await secondDb.query(
        'observations',
        where: 'source_ai_judgement_id = ?',
        whereArgs: [secondJudgement.id],
      );
      await secondHarness.repository.respondToAiJudgement(
        judgementId: secondJudgement.id,
        status: 'inaccurate',
        addToTimeline: false,
        language: AppLanguage.simplifiedChinese,
      );
      signals = await secondHarness.localCaptureRepository.listSignalCards();
      expect(signals.where((signal) => signal.sourceType == 'ai_predicted'),
          isEmpty);
      final dismissed = await secondDb.query(
        'observations',
        where: 'source_ai_judgement_id = ?',
        whereArgs: [secondJudgement.id],
      );
      expect(dismissed.single['status'], beforeDismiss.single['status']);

      await secondHarness.close();
      await harness.close();
    });

    test('session replacement saves the exact AI prediction the user saw',
        () async {
      final today = _testDateKey(DateTime.now());
      final api = FakeSignalCardApiClient(
        recentSignals: [
          {
            'id': 'raw-replacement-prediction',
            'signal_card_id': 'sig-replacement-prediction',
            'source_type': 'text',
            'content': '今天来回切换了好几次任务。',
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'local_date': today,
            'user_confirmation': 'unconfirmed',
          },
        ],
      );
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeAiRepository(),
        apiClient: api,
      );

      final original = (await harness.repository.fetchToday())['aiJudgement']
          as AiJudgementModel;
      final replacement = await harness.repository.createAiJudgementForToday(
        language: AppLanguage.simplifiedChinese,
        variationIndex: 1,
      );
      expect(replacement, isNotNull);
      expect(replacement!.predictedSignalText,
          isNot(original.predictedSignalText));

      await harness.repository.respondToAiJudgement(
        judgementId: replacement.id,
        status: 'accurate',
        displayedJudgement: replacement,
        addToTimeline: true,
        language: AppLanguage.simplifiedChinese,
      );

      final signals = await harness.localCaptureRepository.listSignalCards();
      final saved =
          signals.singleWhere((signal) => signal.sourceType == 'ai_predicted');
      expect(saved.content, replacement.predictedSignalText);
      expect(saved.sceneTags, contains(replacement.suggestedPattern));
      expect(saved.sceneTags, isNot(contains(original.suggestedPattern)));

      await harness.close();
    });

    test('pending 预判随来源刷新，不加入时间线时不冻结或写反馈', () async {
      final today = _testDateKey(DateTime.now());
      final api = FakeSignalCardApiClient(
        recentSignals: [
          {
            'id': 'raw-refresh-1',
            'signal_card_id': 'sig-refresh-1',
            'source_type': 'text',
            'content': '上午连续切换了几个任务。',
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'local_date': today,
            'user_confirmation': 'unconfirmed',
          },
        ],
      );
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeAiRepository(),
        apiClient: api,
      );

      final first = (await harness.repository.fetchToday())['aiJudgement']
          as AiJudgementModel;
      expect(first.sourceSignalCardIds, ['sig-refresh-1']);

      api.recentSignals.insert(0, {
        'id': 'raw-refresh-2',
        'signal_card_id': 'sig-refresh-2',
        'source_type': 'text',
        'content': '下午的安排也很密。',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'local_date': today,
        'user_confirmation': 'unconfirmed',
      });
      final refreshed = (await harness.repository.fetchToday())['aiJudgement']
          as AiJudgementModel;
      expect(refreshed.id, isNot(first.id));
      expect(refreshed.sourceSignalCardIds.toSet(),
          {'sig-refresh-1', 'sig-refresh-2'});

      await harness.repository.respondToAiJudgement(
        judgementId: refreshed.id,
        status: 'accurate',
        addToTimeline: false,
      );
      api.recentSignals.insert(0, {
        'id': 'raw-refresh-3',
        'signal_card_id': 'sig-refresh-3',
        'source_type': 'text',
        'content': '晚上又多了一条记录。',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'local_date': today,
        'user_confirmation': 'unconfirmed',
      });
      final updated = (await harness.repository.fetchToday())['aiJudgement']
          as AiJudgementModel;
      expect(updated.status, 'pending');
      expect(updated.sourceSignalCardIds.toSet(),
          {'sig-refresh-1', 'sig-refresh-2', 'sig-refresh-3'});

      final db = await harness.localDatabase.database;
      final judgements = await db.query(
        'ai_judgements',
        where: 'local_date = ?',
        whereArgs: [today],
      );
      expect(judgements, hasLength(3));
      expect(
        judgements.map((row) => row['status']).toSet(),
        {'pending'},
      );
      final signals = await harness.localCaptureRepository.listSignalCards();
      expect(
        signals.where((signal) => signal.sourceType == 'ai_predicted'),
        isEmpty,
      );

      await harness.close();
    });

    test('each newly sourced confirmed AI prediction keeps its own SignalCard',
        () async {
      final today = _testDateKey(DateTime.now());
      final api = FakeSignalCardApiClient(
        recentSignals: [
          {
            'id': 'raw-versioned-1',
            'signal_card_id': 'sig-versioned-1',
            'source_type': 'text',
            'content': '上午连续切换任务。',
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'local_date': today,
            'user_confirmation': 'unconfirmed',
          },
        ],
      );
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeAiRepository(),
        apiClient: api,
      );

      final first = (await harness.repository.fetchToday())['aiJudgement']
          as AiJudgementModel;
      await harness.repository.respondToAiJudgement(
        judgementId: first.id,
        status: 'accurate',
        displayedJudgement: first,
        addToTimeline: true,
      );

      api.recentSignals.insert(0, {
        'id': 'raw-versioned-2',
        'signal_card_id': 'sig-versioned-2',
        'source_type': 'text',
        'content': '下午又多了一次临时切换。',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'local_date': today,
        'user_confirmation': 'unconfirmed',
      });
      final second = (await harness.repository.fetchToday())['aiJudgement']
          as AiJudgementModel;
      expect(second.id, isNot(first.id));
      await harness.repository.respondToAiJudgement(
        judgementId: second.id,
        status: 'accurate',
        displayedJudgement: second,
        addToTimeline: true,
      );

      final signals = await harness.localCaptureRepository.listSignalCards();
      final predictions = signals
          .where((signal) => signal.sourceType == 'ai_predicted')
          .toList();
      expect(predictions, hasLength(2));
      expect(
        predictions.map((signal) => signal.signalCardId).toSet(),
        {
          'ai_prediction_${first.id}',
          'ai_prediction_${second.id}',
        },
      );

      await harness.close();
    });

    test('ai_predicted 默认不进入 Summary，确认后可作为观察材料', () async {
      final ai = RecordingSummaryAiRepository();
      final today = _testDateKey(DateTime.now());
      final api = FakeSignalCardApiClient(
        recentSignals: [
          {
            'id': 'raw-predicted',
            'signal_card_id': 'sig-predicted',
            'source_type': 'ai_predicted',
            'content': 'AI 主动预判的信号需要用户确认',
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'local_date': today,
            'acknowledgement': '这只是建议，不会默认进入分析。',
            'user_confirmation': 'unconfirmed',
          },
        ],
      );
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: ai,
        apiClient: api,
      );

      await harness.repository.fetchToday();
      expect(ai.lastSummaryEntries, isEmpty);

      await harness.repository.confirmSignalCard(
        signalCardId: 'sig-predicted',
        userConfirmation: 'accurate',
      );
      api.recentSignals.first['user_confirmation'] = 'accurate';
      await harness.repository.fetchToday();
      expect(ai.lastSummaryEntries.map((e) => e.content), [
        'AI 主动预判的信号需要用户确认',
      ]);

      await expectLater(
        harness.repository.confirmSignalCard(
          signalCardId: 'sig-predicted',
          userConfirmation: 'supplemented',
          userCorrectionJson: const {
            'supplement_text': '这确实像我今天早上的会议切换。',
          },
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'saved_signal_card_is_immutable',
          ),
        ),
      );
      await harness.repository.fetchToday();
      expect(ai.lastSummaryEntries.map((e) => e.content), [
        'AI 主动预判的信号需要用户确认',
      ]);

      await harness.close();
    });

    test(
        'small-action completion writes canonical values and reads legacy aliases',
        () async {
      final harness = await _createHarness(
        dbPath: dbPath,
        aiRepository: FakeAiRepository(),
      );
      final now = DateTime.now();
      final todayKey = _testDateKey(now);
      final cases = <({
        String input,
        String expected,
        String expectedStatus,
      })>[
        (
          input: 'completed',
          expected: 'completed',
          expectedStatus: 'active',
        ),
        (
          input: 'not_completed',
          expected: 'not_completed',
          expectedStatus: 'active',
        ),
        (
          input: 'occurred',
          expected: 'completed',
          expectedStatus: 'active',
        ),
        (
          input: 'not_occurred',
          expected: 'not_completed',
          expectedStatus: 'active',
        ),
      ];

      for (var index = 0; index < cases.length; index++) {
        final item = cases[index];
        final actionId = 'completion-action-$index';
        await harness.localPhase3PlusRepository.upsertMicroAction(
          MicroActionModel(
            id: actionId,
            judgementId: '',
            title: '任务切换前留两分钟缓冲',
            reason: '记录完成情况。',
            status: 'active',
            adoptedAt: now,
            progressStartDate: todayKey,
            createdAt: now,
            updatedAt: now,
          ),
        );

        await harness.repository.submitMicroActionFeedback(
          microActionId: actionId,
          feedback: item.input,
          effect: item.expected == 'completed' ? SmallTryEffect.helpful : null,
          difficulty:
              item.expected == 'completed' ? SmallTryDifficulty.easy : null,
        );

        final action = await harness.localPhase3PlusRepository
            .getMicroActionById(actionId);
        expect(action?.feedbackStatus, item.expected);
        expect(action?.status, item.expectedStatus);
      }

      final feedbacks = await harness.localPhase3PlusRepository
          .listMicroActionFeedbacksBetween(
        startDate: todayKey,
        endDate: todayKey,
      );
      final storedByAction = {
        for (final item in feedbacks) item.microActionId: item.happened,
      };
      expect(storedByAction, {
        'completion-action-0': 'completed',
        'completion-action-1': 'not_completed',
        'completion-action-2': 'completed',
        'completion-action-3': 'not_completed',
      });

      const openEndedActionId = 'open-ended-action';
      final openEndedStart = now.subtract(const Duration(days: 30));
      await harness.localPhase3PlusRepository.upsertMicroAction(
        MicroActionModel(
          id: openEndedActionId,
          judgementId: '',
          title: '持续中的小尝试',
          reason: '没有明确结束日时仍可继续登记。',
          status: 'active',
          adoptedAt: openEndedStart,
          progressStartDate: _testDateKey(openEndedStart),
          createdAt: openEndedStart,
          updatedAt: openEndedStart,
        ),
      );
      await harness.repository.submitMicroActionFeedback(
        microActionId: openEndedActionId,
        feedback: 'completed',
        effect: SmallTryEffect.helpful,
        difficulty: SmallTryDifficulty.easy,
      );
      final openEnded = await harness.localPhase3PlusRepository
          .getMicroActionById(openEndedActionId);
      expect(openEnded?.feedbackStatus, 'completed');

      const outsideWindowActionId = 'outside-window-action';
      await harness.localPhase3PlusRepository.upsertMicroAction(
        MicroActionModel(
          id: outsideWindowActionId,
          judgementId: '',
          title: '已经结束的七日小尝试',
          reason: '窗口外不能继续写入看不见的进度。',
          status: 'active',
          adoptedAt: DateTime(2020, 1, 1),
          progressStartDate: '2020-01-01',
          progressEndDate: '2020-01-07',
          createdAt: DateTime(2020, 1, 1),
          updatedAt: DateTime(2020, 1, 1),
        ),
      );
      await harness.repository.submitMicroActionFeedback(
        microActionId: outsideWindowActionId,
        feedback: 'completed',
        effect: SmallTryEffect.helpful,
        difficulty: SmallTryDifficulty.easy,
      );
      final outsideWindow = await harness.localPhase3PlusRepository
          .getMicroActionById(outsideWindowActionId);
      expect(outsideWindow?.status, 'active');
      expect(outsideWindow?.feedbackStatus, 'none');
      final afterOutsideWindow = await harness.localPhase3PlusRepository
          .listMicroActionFeedbacksBetween(
        startDate: '2020-01-01',
        endDate: '2020-01-07',
      );
      expect(
        afterOutsideWindow.where(
          (item) => item.microActionId == outsideWindowActionId,
        ),
        isEmpty,
      );

      const appendOnlyActionId = 'same-day-append-only-action';
      await harness.localPhase3PlusRepository.upsertMicroAction(
        MicroActionModel(
          id: appendOnlyActionId,
          judgementId: '',
          title: '午后留一分钟离开屏幕',
          reason: '验证每次真实尝试都会保留，且不会结束小实验对象。',
          status: 'active',
          adoptedAt: now,
          progressStartDate: todayKey,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await harness.repository.submitMicroActionFeedback(
        microActionId: appendOnlyActionId,
        feedback: 'completed',
        effect: SmallTryEffect.helpful,
        difficulty: SmallTryDifficulty.easy,
      );
      await harness.repository.submitMicroActionFeedback(
        microActionId: appendOnlyActionId,
        feedback: 'not_completed',
      );

      final actionWithTwoAttempts = await harness.localPhase3PlusRepository
          .getMicroActionById(appendOnlyActionId);
      expect(actionWithTwoAttempts?.status, 'active');
      expect(actionWithTwoAttempts?.feedbackStatus, 'not_completed');

      // Restored backup rows may still carry the pre-canonical aliases. They
      // remain immutable facts and must project to the same attempt states.
      await harness.localPhase3PlusRepository.insertMicroActionFeedback(
        MicroActionFeedbackModel(
          id: 'legacy-completed-attempt',
          microActionId: appendOnlyActionId,
          localDate: todayKey,
          happened: 'occurred',
          createdAt: now.add(const Duration(minutes: 1)),
        ),
      );
      await harness.localPhase3PlusRepository.insertMicroActionFeedback(
        MicroActionFeedbackModel(
          id: 'legacy-not-completed-attempt',
          microActionId: appendOnlyActionId,
          localDate: todayKey,
          happened: 'not_occurred',
          createdAt: now.add(const Duration(minutes: 2)),
        ),
      );

      final planningRepository = LocalCandidatePlanningRepository(
        localDatabase: harness.localDatabase,
        localCaptureRepository: harness.localCaptureRepository,
        localLifeExperimentRepository:
            LocalLifeExperimentRepository(harness.localDatabase),
        localUserId: 'local',
        focusDomainIdsLoader: () async => const [],
        externalEnergySummaryLoader: () async => null,
      );
      final progress = await planningRepository.microActionProgress(
        appendOnlyActionId,
      );
      expect(progress.completedAttempts, 2);
      expect(progress.cells, hasLength(4));
      expect(
        progress.cells.map((attempt) => attempt.localDate).toSet(),
        {todayKey},
      );
      expect(
        progress.cells.map((attempt) => attempt.state.name),
        ['completed', 'notCompleted', 'completed', 'notCompleted'],
      );
      await planningRepository.dispose();

      await harness.close();
    });
  });

  test(
      'non-local user adopted experiment only appears in its next-week active period',
      () async {
    final localDatabase = LocalDatabase(
      dbPathOverride: dbPath,
      databaseFactoryOverride: databaseFactoryFfi,
    );
    await localDatabase.init();
    final lifeRepository = LocalLifeExperimentRepository(localDatabase);
    final candidateRepository =
        LocalExperimentCandidateRepository(localDatabase);
    const userId = 'device-user-uuid';
    final candidate = await candidateRepository.ensureWeeklyCandidate(
      localUserId: userId,
      weekStart: '2026-07-06',
      weekEnd: '2026-07-12',
      title: 'Protect one recovery window',
      hypothesis: 'A small buffer may help recovery.',
      suggestedAction: 'Keep ten minutes open.',
      linkedSignalCardIds: const ['sig_1', 'sig_2', 'sig_3'],
    );
    final adopted = await candidateRepository.adoptCandidate(
      candidateId: candidate.id,
      lifeExperimentRepository: lifeRepository,
    );
    expect(adopted?.sourceWeekStart, '2026-07-13');
    expect(adopted?.sourceWeekEnd, '2026-07-19');

    var now = DateTime(2026, 7, 10);
    final todayRepository = TodayRepository(
      localCaptureRepository: LocalCaptureRepository(localDatabase),
      localDailySnapshotRepository: LocalDailySnapshotRepository(localDatabase),
      localLifeExperimentRepository: lifeRepository,
      localPhase3PlusRepository: LocalPhase3PlusRepository(localDatabase),
      aiRepository: FakeAiRepository(),
      localUserId: userId,
      nowLoader: () => now,
    );

    expect((await todayRepository.fetchToday())['todayLifeExperiment'], isNull);
    now = DateTime(2026, 7, 14);
    expect(
      ((await todayRepository.fetchToday())['todayLifeExperiment'] as dynamic)
          ?.id,
      adopted?.id,
    );
    await localDatabase.close();
  });
}

class _Harness {
  final LocalDatabase localDatabase;
  final LocalCaptureRepository localCaptureRepository;
  final LocalPhase3PlusRepository localPhase3PlusRepository;
  final TodayRepository repository;

  _Harness({
    required this.localDatabase,
    required this.localCaptureRepository,
    required this.localPhase3PlusRepository,
    required this.repository,
  });

  Future<void> close() async {
    await localDatabase.close();
  }
}

Future<_Harness> _createHarness({
  required String dbPath,
  required AiRepository aiRepository,
  ApiClient? apiClient,
  ResponseStyleLoader? responseStyleLoader,
}) async {
  final localDatabase = LocalDatabase(
    dbPathOverride: dbPath,
    databaseFactoryOverride: databaseFactoryFfi,
  );
  await localDatabase.init();

  final localCaptureRepository = LocalCaptureRepository(localDatabase);
  final localDailySnapshotRepository =
      LocalDailySnapshotRepository(localDatabase);
  final localPhase3PlusRepository = LocalPhase3PlusRepository(localDatabase);

  final repository = TodayRepository(
    localCaptureRepository: localCaptureRepository,
    localDailySnapshotRepository: localDailySnapshotRepository,
    localPhase3PlusRepository: localPhase3PlusRepository,
    aiRepository: aiRepository,
    apiClient: apiClient,
    focusAreaLoader: () async => null,
    responseStyleLoader: responseStyleLoader,
  );

  return _Harness(
    localDatabase: localDatabase,
    localCaptureRepository: localCaptureRepository,
    localPhase3PlusRepository: localPhase3PlusRepository,
    repository: repository,
  );
}

class FakeSignalCardApiClient extends ApiClient {
  List<Map<String, dynamic>> recentSignals;
  bool failPost;
  final List<Map<String, dynamic>> postCalls = [];
  final List<Map<String, dynamic>> patchCalls = [];
  final List<Map<String, dynamic>> deleteCalls = [];

  FakeSignalCardApiClient({
    required this.recentSignals,
    this.failPost = false,
  }) : super(
          baseUrl: 'https://example.invalid',
          userId: 'test-user',
        );

  @override
  Future<Map<String, dynamic>> getJson(String path) async {
    return {
      'data': {'recent_signals': recentSignals},
    };
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    postCalls.add({'path': path, 'body': body});
    if (failPost) {
      throw Exception('backend unreachable');
    }
    return {
      'data': {
        'acknowledgement': recentSignals.isEmpty
            ? '已保存'
            : recentSignals.first['acknowledgement'],
        'followup': null,
        'recent_signals': recentSignals,
      },
    };
  }

  @override
  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    patchCalls.add({'path': path, 'body': body});
    return {'data': body};
  }

  @override
  Future<Map<String, dynamic>> deleteJson(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    deleteCalls.add({'path': path, 'body': body});
    return {'data': body ?? const <String, dynamic>{}};
  }
}

String _testDateKey(DateTime date) {
  final local = date.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

class FakeAiRepository extends AiRepository {
  final String captureReply;
  final String Function(List<Map<String, dynamic>> entries)?
      todayObservationBuilder;
  final String Function(List<Map<String, dynamic>> entries)?
      todaySuggestionBuilder;

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
    String? responseStyle,
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
    String? responseStyle,
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
      suggestion:
          todaySuggestionBuilder?.call(payload) ?? '今天先试试：再出现一次同类情况时补记一条。',
    );
  }
}

class RecordingSummaryAiRepository extends FakeAiRepository {
  List<RecentSignalModel> lastSummaryEntries = const [];

  @override
  Future<AiTodaySummaryResult> generateTodaySummary({
    required DateTime date,
    required List<RecentSignalModel> entries,
    String? focusArea,
    String? responseStyle,
  }) async {
    lastSummaryEntries = entries;
    return AiTodaySummaryResult(
      observation: '今天可以先这样看：${entries.length} 条 SignalCard 形成了小观察。',
      suggestion: '今天先把原文放好，再看它会不会重复出现。',
    );
  }
}

class TrackingAiRepository extends FakeAiRepository {
  final List<String?> captureReplyStyles = [];
  final List<String?> todaySummaryStyles = [];

  @override
  Future<AiCaptureReplyResult> generateCaptureReply({
    required String content,
    required List<String> recentAssistantTexts,
    String? focusArea,
    String? responseStyle,
  }) async {
    captureReplyStyles.add(responseStyle);
    return super.generateCaptureReply(
      content: content,
      recentAssistantTexts: recentAssistantTexts,
      focusArea: focusArea,
      responseStyle: responseStyle,
    );
  }

  @override
  Future<AiTodaySummaryResult> generateTodaySummary({
    required DateTime date,
    required List<RecentSignalModel> entries,
    String? focusArea,
    String? responseStyle,
  }) async {
    todaySummaryStyles.add(responseStyle);
    return super.generateTodaySummary(
      date: date,
      entries: entries,
      focusArea: focusArea,
      responseStyle: responseStyle,
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
    String? responseStyle,
  }) async {
    throw Exception('Simulated remote failure');
  }

  @override
  Future<AiTodaySummaryResult> generateTodaySummary({
    required DateTime date,
    required List<RecentSignalModel> entries,
    String? focusArea,
    String? responseStyle,
  }) async {
    throw Exception('Simulated remote failure');
  }
}
