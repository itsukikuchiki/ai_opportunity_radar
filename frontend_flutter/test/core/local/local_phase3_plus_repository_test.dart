import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/local/local_phase3_plus_repository.dart';
import 'package:ai_opportunity_radar/core/models/experiment_creation_source.dart';
import 'package:ai_opportunity_radar/core/models/experiment_evaluation_models.dart';
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

  test('small-try effect and round reviews are structured and append-only',
      () async {
    final action = MicroActionModel(
      id: 'micro-review-1',
      judgementId: '',
      title: '先留五分钟缓冲',
      reason: '看看切换是否更轻',
      status: 'active',
      plannedDurationMinutes: 5,
      localUserId: 'local',
      adoptedAt: DateTime(2026, 7, 20, 9),
      progressStartDate: '2026-07-20',
    );
    await repository.upsertMicroAction(action);
    expect(
      (await repository.getMicroActionById(action.id))?.plannedDurationMinutes,
      5,
    );
    for (final terminalStatus in const [
      'completed',
      'done',
      'finished',
      'stopped',
      'archived',
      'skipped',
      'effective',
      'not_effective',
    ]) {
      await repository.updateMicroActionStatus(
        id: action.id,
        status: terminalStatus,
      );
      expect(
        (await repository.getMicroActionById(action.id))?.status,
        'active',
        reason: 'generic writers cannot close a small experiment',
      );
    }
    await repository.updateMicroActionStatus(
      id: action.id,
      status: 'active',
      feedbackStatus: 'done',
    );
    expect(
      (await repository.getMicroActionById(action.id))?.feedbackStatus,
      'done',
    );
    await repository.updateMicroActionStatus(
      id: action.id,
      status: 'completed',
      feedbackStatus: 'helpful',
    );
    final feedbackOnlyUpdate = await repository.getMicroActionById(action.id);
    expect(feedbackOnlyUpdate?.status, 'active');
    expect(feedbackOnlyUpdate?.feedbackStatus, 'helpful');
    await expectLater(
      repository.upsertMicroAction(
        const MicroActionModel(
          id: 'micro-too-long',
          judgementId: '',
          title: '太长的项目',
          reason: '不应进入小实验数据层',
          plannedDurationMinutes: 11,
        ),
      ),
      throwsArgumentError,
    );

    final first = await repository.recordStructuredMicroActionFeedback(
      microActionId: action.id,
      localDate: '2026-07-20',
      completionStatus: 'completed',
      effect: SmallTryEffect.helpful,
      difficulty: SmallTryDifficulty.easy,
      durationMinutes: 5,
      note: '切换顺了一点',
      createdAt: DateTime(2026, 7, 20, 10),
    );
    expect(first.effect, SmallTryEffect.helpful);
    expect(first.difficulty, SmallTryDifficulty.easy);
    expect(first.durationMinutes, 5);
    expect(first.userNote, '切换顺了一点');

    expect(
      () => repository.recordStructuredMicroActionFeedback(
        microActionId: action.id,
        localDate: '2026-07-20',
        completionStatus: 'completed',
      ),
      throwsArgumentError,
    );
    await expectLater(
      repository.recordStructuredMicroActionFeedback(
        microActionId: action.id,
        localDate: '2026-07-20',
        completionStatus: 'completed',
        effect: SmallTryEffect.helpful,
        difficulty: SmallTryDifficulty.easy,
        durationMinutes: 11,
      ),
      throwsArgumentError,
    );

    // Same-day facts are never rewritten. Every completed attempt contributes
    // to the attempt snapshot; there is no daily collapse or seven-day cap.
    await repository.recordStructuredMicroActionFeedback(
      microActionId: action.id,
      localDate: '2026-07-20',
      completionStatus: 'not_completed',
      createdAt: DateTime(2026, 7, 20, 11),
    );
    await repository.recordStructuredMicroActionFeedback(
      microActionId: action.id,
      localDate: '2026-07-21',
      completionStatus: 'completed',
      effect: SmallTryEffect.somewhatHelpful,
      difficulty: SmallTryDifficulty.okay,
      durationMinutes: 4,
      createdAt: DateTime(2026, 7, 21, 10),
    );

    final review = await repository.recordMicroActionRoundReview(
      microActionId: action.id,
      result: SmallTryRoundResult.adjustAndRetry,
      effort: EvaluationEffort.acceptable,
      nextAdjustment: SmallTryNextAdjustment.makeLighter,
      note: '下次缩短一点',
      reviewedAt: DateTime(2026, 7, 21, 12),
    );
    expect(review, isNotNull);
    expect(review!.completedAttemptsAtReview, 2);
    expect(review.note, '下次缩短一点');

    await repository.recordMicroActionRoundReview(
      microActionId: action.id,
      result: SmallTryRoundResult.worthKeeping,
      effort: EvaluationEffort.easy,
      nextAdjustment: SmallTryNextAdjustment.keep,
      reviewedAt: DateTime(2026, 7, 22, 12),
    );
    final reviews = await repository.listMicroActionRoundReviews(
      microActionId: action.id,
    );
    expect(reviews, hasLength(2));
    expect(reviews.map((item) => item.result), [
      SmallTryRoundResult.adjustAndRetry,
      SmallTryRoundResult.worthKeeping,
    ]);
    expect(
      (await repository.getMicroActionById(action.id))?.status,
      'active',
      reason: 'saving a round review must not complete the lifecycle',
    );

    final db = await localDatabase.database;
    final feedbackRows = await db.query(
      'micro_action_feedback',
      where: 'micro_action_id = ?',
      whereArgs: [action.id],
      orderBy: 'created_at ASC',
    );
    expect(feedbackRows, hasLength(3));
    expect(feedbackRows[1]['effect'], '');
    expect(feedbackRows[1]['difficulty'], '');
  });

  test('user-created small experiment persists source and initial version',
      () async {
    final created = await repository.createUserSmallExperiment(
      title: '切换前先停两分钟',
      description: '看看下一件事是否更容易开始',
      durationMinutes: 2,
      startDate: DateTime.now(),
    );

    expect(created.creationSource, ExperimentCreationSource.userCreated);
    expect(created.originCandidateId, isNull);
    expect(created.linkedSignalCardIds, isEmpty);
    expect(created.progressEndDate, isNull);
    expect(created.plannedDurationMinutes, 2);

    final db = await localDatabase.database;
    final stored = (await db.query(
      'micro_actions',
      where: 'id = ?',
      whereArgs: [created.id],
    ))
        .single;
    expect(stored['creation_source'], 'user_created');
    expect(
      await db.query(
        'plan_content_versions',
        where: 'object_kind = ? AND object_id = ?',
        whereArgs: ['quick_try', created.id],
      ),
      hasLength(1),
    );
    expect(
      await db.query(
        'micro_action_feedback',
        where: 'micro_action_id = ?',
        whereArgs: [created.id],
      ),
      isEmpty,
    );

    await expectLater(
      repository.createUserSmallExperiment(
        title: '超过边界',
        description: '',
        durationMinutes: 11,
        startDate: DateTime.now(),
      ),
      throwsArgumentError,
    );
  });

  test(
      'user-created small experiment rolls back projection when initial version fails',
      () async {
    final db = await localDatabase.database;
    await db.execute('''
      CREATE TRIGGER reject_user_small_experiment_initial_version
      BEFORE INSERT ON plan_content_versions
      WHEN NEW.object_kind = 'quick_try'
      BEGIN
        SELECT RAISE(ABORT, 'forced initial version failure');
      END
    ''');

    await expectLater(
      repository.createUserSmallExperiment(
        title: '事务中断的小实验',
        description: '不应留下半成品',
        durationMinutes: 2,
        startDate: DateTime(2026, 7, 28),
      ),
      throwsA(isA<DatabaseException>()),
    );

    expect(
      await db.query(
        'micro_actions',
        where: 'title = ?',
        whereArgs: ['事务中断的小实验'],
      ),
      isEmpty,
    );
    expect(
      await db.query(
        'plan_content_versions',
        where: 'object_kind = ?',
        whereArgs: ['quick_try'],
      ),
      isEmpty,
    );
  });
}
