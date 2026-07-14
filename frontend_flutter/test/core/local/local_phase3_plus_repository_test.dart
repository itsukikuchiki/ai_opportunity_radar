import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/local/local_phase3_plus_repository.dart';
import 'package:ai_opportunity_radar/core/models/phase3_plus_models.dart';

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late LocalDatabase localDatabase;
  late LocalPhase3PlusRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('phase3_plus_repo_test_');
    localDatabase = LocalDatabase(
      dbPathOverride: p.join(tempDir.path, 'local.db'),
      databaseFactoryOverride: databaseFactoryFfi,
    );
    await localDatabase.init();
    repository = LocalPhase3PlusRepository(localDatabase);
  });

  tearDown(() async {
    await localDatabase.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('AI prediction stores candidate signal fields before micro actions',
      () async {
    final now = DateTime.now();
    final judgement = AiJudgementModel(
      id: 'aj_prediction_001',
      sourceSignalCardIds: const ['sig_001'],
      localDate: '2026-06-25',
      judgementText: '你可能正在靠近一个恢复信号。',
      evidenceText: '线索来自今天的记录。',
      predictionKind: 'inferred_signal',
      predictedSignalText: '今天的低能量可能是在提醒你先恢复。',
      suggestedPattern: '恢复空间不足',
      suggestedLifeChainStage: 'recovery_gap',
      confidenceLevel: 'low',
      createdAt: now,
      updatedAt: now,
    );

    await repository.upsertAiJudgement(judgement);
    final stored = await repository.getAiJudgementForDate('2026-06-25');

    expect(stored, isNotNull);
    expect(stored!.predictionKind, 'inferred_signal');
    expect(stored.predictedSignalText, '今天的低能量可能是在提醒你先恢复。');
    expect(stored.linkedMicroActionId, isNull);

    await repository.updateAiJudgementStatus(
      id: judgement.id,
      status: 'confirmed',
      confirmationNote: '用户确认这条预判信号更接近。',
      includedInWeekly: true,
      includedInJourney: true,
    );
    final confirmed = await repository.getAiJudgementById(judgement.id);

    expect(confirmed?.status, 'confirmed');
    expect(confirmed?.confirmationNote, '用户确认这条预判信号更接近。');
    expect(confirmed?.linkedMicroActionId, isNull);
    expect(confirmed?.includedInWeekly, isTrue);
    expect(confirmed?.includedInJourney, isTrue);
  });

  test('AI judgement is persisted as Observation with signal links', () async {
    final today = repository.todayKey();
    final judgement = AiJudgementModel(
      id: repository.createId('aj'),
      sourceSignalCardIds: const ['sig-a', 'sig-b'],
      localDate: today,
      judgementText: '最近会议后能量下降更明显。',
      evidenceText: '三条记录都提到了会议和疲惫。',
      suggestedPattern: 'meeting_energy_drop',
      suggestedLifeChainStage: 'energy_drain',
      confidenceLevel: 'medium',
    );

    await repository.upsertAiJudgement(judgement);
    final db = await localDatabase.database;
    var observations = await db.query('observations');
    var links = await db.query('observation_signal_links');
    var traceLinks = await db.query('trace_links');

    expect(observations, hasLength(1));
    expect(observations.single['source_ai_judgement_id'], judgement.id);
    expect(observations.single['observation_text'], judgement.judgementText);
    expect(observations.single['status'], 'generated');
    expect(links, hasLength(2));
    expect(traceLinks, hasLength(2));
    expect(traceLinks.map((row) => row['source_type']).toSet(), {
      'observation',
    });
    expect(traceLinks.map((row) => row['target_type']).toSet(), {
      'signal_card',
    });
    expect(traceLinks.map((row) => row['relation_type']).toSet(), {
      'evidence_signal',
    });

    await repository.updateAiJudgementStatus(
      id: judgement.id,
      status: 'confirmed',
      confirmationNote: '确认这个判断。',
      includedInWeekly: true,
      includedInJourney: true,
    );
    observations = await db.query('observations');
    expect(observations.single['status'], 'confirmed');
    expect(observations.single['confirmed_at'], isNotNull);

    await repository.updateAiJudgementStatus(
      id: judgement.id,
      status: 'inaccurate',
      confirmationNote: '这个判断不准确。',
      includedInWeekly: false,
      includedInJourney: false,
    );
    observations = await db.query('observations');
    expect(observations.single['status'], 'dismissed');
    expect(observations.single['dismissed_at'], isNotNull);

    final summary = await repository.summarizeActionLoop(
      startDate: today,
      endDate: today,
    );
    expect(summary['observation_count'], 0);
    expect(summary['confirmed_observation_count'], 0);
    expect(summary['observation_ids'], isEmpty);
  });
}
