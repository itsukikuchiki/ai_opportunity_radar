import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/local/local_feedback_event_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_life_experiment_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_phase3_plus_repository.dart';
import 'package:ai_opportunity_radar/core/models/experiment_evaluation_models.dart';
import 'package:ai_opportunity_radar/core/models/phase3_plus_models.dart';

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late LocalDatabase localDatabase;
  late LocalFeedbackEventRepository repository;
  late LocalLifeExperimentRepository lifeExperimentRepository;
  late LocalPhase3PlusRepository phase3PlusRepository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('feedback_event_test_');
    localDatabase = LocalDatabase(
      dbPathOverride: p.join(tempDir.path, 'local.db'),
      databaseFactoryOverride: databaseFactoryFfi,
    );
    await localDatabase.init();
    repository = LocalFeedbackEventRepository(localDatabase);
    lifeExperimentRepository = LocalLifeExperimentRepository(localDatabase);
    phase3PlusRepository = LocalPhase3PlusRepository(localDatabase);
  });

  tearDown(() async {
    await localDatabase.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
      'listBetween unifies micro action, experiment, schedule and goal feedback',
      () async {
    await phase3PlusRepository.insertMicroActionFeedback(
      MicroActionFeedbackModel(
        id: 'micro_fb_1',
        microActionId: 'micro_1',
        localDate: '2026-07-02',
        happened: 'yes',
        effect: 'helpful',
        difficulty: 'easy',
        userNote: '走出去之后轻一点',
        nextAdjustment: 'continue',
        createdAt: DateTime.utc(2026, 7, 2, 1),
      ),
    );
    await phase3PlusRepository.insertMicroActionFeedback(
      MicroActionFeedbackModel(
        id: 'micro_fb_old',
        microActionId: 'micro_old',
        localDate: '2026-06-25',
        happened: 'yes',
        effect: 'helpful',
        createdAt: DateTime.utc(2026, 6, 25, 1),
      ),
    );

    final experiment = await lifeExperimentRepository.ensureSuggested(
      localUserId: 'local',
      weekStart: '2026-07-01',
      weekEnd: '2026-07-07',
      title: '午后留白',
      hypothesis: '少一点安排会更容易恢复',
      suggestedAction: '午后留 10 分钟',
      linkedSignalCardIds: const [],
      status: 'saved',
    );
    final otherUserExperiment = await lifeExperimentRepository.ensureSuggested(
      localUserId: 'other',
      weekStart: '2026-07-01',
      weekEnd: '2026-07-07',
      title: '其他用户实验',
      hypothesis: '不应该进入 local',
      suggestedAction: '忽略',
      linkedSignalCardIds: const [],
      status: 'saved',
    );
    await lifeExperimentRepository.recordFeedback(
      experimentId: experiment.id,
      completionStatus: 'helpful',
      helpfulnessScore: 5,
      feedbackText: '确实更稳',
      feedbackDate: DateTime(2026, 7, 3),
    );
    await lifeExperimentRepository.recordFeedback(
      experimentId: otherUserExperiment.id,
      localUserId: 'other',
      completionStatus: 'helpful',
      feedbackDate: DateTime(2026, 7, 3),
    );
    final scheduleId = await _seedLegacySchedule(
      localDatabase,
      id: 'schedule_unified',
      localDate: '2026-07-04',
      actualEnergyLoad: 'draining',
      postMood: 'tired',
      friction: 'context_switching',
    );
    final goalId = await _seedLegacyGoal(
      localDatabase,
      id: 'goal_unified',
    );
    await _seedGoalFeedback(
      localDatabase,
      id: 'goal_unified_feedback',
      goalId: goalId,
      feedbackDate: '2026-07-04',
    );

    final events = await repository.listBetween(
      localUserId: 'local',
      startDate: '2026-07-01',
      endDate: '2026-07-31',
    );

    expect(events.map((event) => event.sourceType).toSet(), {
      'micro_action_feedback',
      'life_experiment_feedback',
      'schedule_feedback',
      'goal_feedback',
    });
    expect(
        events.map((event) => event.sourceId), isNot(contains('micro_fb_old')));
    expect(events.map((event) => event.localUserId).toSet(), {'local'});
    expect(events.first.subjectType, 'micro_action');
    expect(events[1].subjectType, 'life_experiment');
    expect(
      events
          .singleWhere((event) => event.sourceType == 'schedule_feedback')
          .subjectType,
      'schedule_signal',
    );
    expect(
      events
          .singleWhere((event) => event.sourceType == 'goal_feedback')
          .subjectType,
      'goal',
    );

    final microFeedbacks = repository.microActionFeedbacksFrom(events);
    expect(microFeedbacks, hasLength(1));
    expect(microFeedbacks.single.microActionId, 'micro_1');
    expect(microFeedbacks.single.effect, 'helpful');

    final experimentFeedbacks = repository.lifeExperimentFeedbacksFrom(events);
    expect(experimentFeedbacks, hasLength(1));
    expect(experimentFeedbacks.single.experimentId, experiment.id);
    expect(experimentFeedbacks.single.feedbackText, '确实更稳');

    final scheduleFeedbacks = repository.scheduleFeedbacksFrom(events);
    expect(scheduleFeedbacks, hasLength(1));
    expect(scheduleFeedbacks.single.subjectId, scheduleId);
    expect(scheduleFeedbacks.single.effect, 'draining');
    expect(scheduleFeedbacks.single.metadata['friction'], 'context_switching');

    final goalFeedbacks = repository.goalFeedbacksFrom(events);
    expect(goalFeedbacks, hasLength(1));
    expect(goalFeedbacks.single.subjectId, goalId);
    expect(goalFeedbacks.single.status, 'yes');
    expect(goalFeedbacks.single.effect, 'helpful');

    final activeEvents = await repository.listActiveBetween(
      localUserId: 'local',
      startDate: '2026-07-01',
      endDate: '2026-07-31',
    );
    expect(activeEvents.map((event) => event.sourceType), [
      'micro_action_feedback',
      'life_experiment_feedback',
    ]);
  });

  test('weekly and monthly windows read feedback through one repository',
      () async {
    await _seedMicroFeedback(
      localDatabase,
      id: 'micro_week',
      localDate: '2026-07-02',
    );
    await _seedMicroFeedback(
      localDatabase,
      id: 'micro_later_month',
      localDate: '2026-07-20',
    );
    await _seedMicroFeedback(
      localDatabase,
      id: 'micro_next_month',
      localDate: '2026-08-01',
    );

    final weeklyEvents = await repository.listBetween(
      localUserId: 'local',
      startDate: '2026-07-01',
      endDate: '2026-07-07',
    );
    expect(weeklyEvents.map((event) => event.sourceId), ['micro_week']);

    final journeyMonthEvents = await repository.listBetween(
      localUserId: 'local',
      startDate: '2026-07-01',
      endDate: '2026-07-31',
    );
    expect(journeyMonthEvents.map((event) => event.sourceId), [
      'micro_week',
      'micro_later_month',
    ]);
  });

  test(
      'round and outcome reviews enter feedback projection but not Signal data',
      () async {
    await phase3PlusRepository.upsertMicroAction(
      MicroActionModel(
        id: 'micro_review_projection',
        judgementId: '',
        title: '留两分钟缓冲',
        reason: '观察切换感受',
        status: 'active',
        localUserId: 'local',
        adoptedAt: DateTime(2026, 7, 2),
        progressStartDate: '2026-07-02',
      ),
    );
    await phase3PlusRepository.recordMicroActionRoundReview(
      microActionId: 'micro_review_projection',
      result: SmallTryRoundResult.adjustAndRetry,
      effort: EvaluationEffort.acceptable,
      nextAdjustment: SmallTryNextAdjustment.makeLighter,
      reviewedAt: DateTime(2026, 7, 5, 10),
    );

    final experiment = await lifeExperimentRepository.ensureSuggested(
      localUserId: 'local',
      weekStart: '2026-07-01',
      weekEnd: '2026-08-31',
      title: '午后留白',
      hypothesis: '观察长期恢复变化',
      suggestedAction: '每周三次留白',
      linkedSignalCardIds: const [],
      status: 'active',
      minimumObservationDays: 3,
      progressStartDate: '2026-07-01',
      progressEndDate: '2026-07-06',
    );
    await lifeExperimentRepository.recordWholeRoundReview(
      experimentId: experiment.id,
      outcomeResult: GoalOutcomeResult.unclear,
      burden: EvaluationEffort.acceptable,
      reviewedAt: DateTime(2026, 7, 6, 18),
    );

    final events = await repository.listActiveBetween(
      localUserId: 'local',
      startDate: '2026-07-01',
      endDate: '2026-07-31',
    );
    expect(events.map((event) => event.sourceType), [
      'micro_action_round_review',
      'life_experiment_outcome_review',
    ]);
    expect(events.first.effect, SmallTryRoundResult.adjustAndRetry);
    expect(events.last.effect, GoalOutcomeResult.unclear);
    expect(events.last.metadata['review_type'], GoalReviewType.wholeRound);
    expect(events.last.metadata['minimum_observation_days'], 3);
  });

  test(
      'whole-chain experiment deletion removes feedback and inactivates its trace',
      () async {
    final experiment = await lifeExperimentRepository.ensureSuggested(
      localUserId: 'local',
      weekStart: '2026-07-01',
      weekEnd: '2026-07-07',
      title: '午后留白',
      hypothesis: '留白帮助恢复',
      suggestedAction: '午后留 10 分钟',
      linkedSignalCardIds: const [],
      status: 'saved',
    );
    final feedback = await lifeExperimentRepository.recordFeedback(
      experimentId: experiment.id,
      completionStatus: 'helpful',
      feedbackDate: DateTime(2026, 7, 2),
    );
    expect(feedback, isNotNull);
    final feedbackId = feedback!.id;
    final scheduleId = await _seedLegacySchedule(
      localDatabase,
      id: 'schedule_deleted',
      localDate: '2026-07-03',
      actualEnergyLoad: 'draining',
    );
    final goalId = await _seedLegacyGoal(
      localDatabase,
      id: 'goal_deleted',
    );
    await _seedGoalFeedback(
      localDatabase,
      id: 'goal_deleted_feedback',
      goalId: goalId,
      feedbackDate: '2026-07-04',
    );

    await lifeExperimentRepository.deleteExperiment(experiment.id);
    final db = await localDatabase.database;
    final deletedAt = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'schedule_signals',
      {'deleted_at': deletedAt, 'updated_at': deletedAt},
      where: 'id = ?',
      whereArgs: [scheduleId],
    );
    await db.update(
      'goals',
      {'deleted_at': deletedAt},
      where: 'id = ?',
      whereArgs: [goalId],
    );

    final events = await repository.listBetween(
      localUserId: 'local',
      startDate: '2026-07-01',
      endDate: '2026-07-31',
    );
    expect(events, isEmpty);

    final traceLinks = await db.query(
      'trace_links',
      where: 'source_type = ? AND source_id = ?',
      whereArgs: ['life_experiment_feedback', feedbackId],
    );
    expect(traceLinks, isNotEmpty);
    expect(traceLinks.every((row) => row['status'] == 'inactive'), isTrue);
  });

  test('privacy excluded schedule and goal feedback do not enter Journey read',
      () async {
    await _seedLegacySchedule(
      localDatabase,
      id: 'schedule_private',
      localDate: '2026-07-05',
      actualEnergyLoad: 'draining',
      privacyLevel: 'excluded',
    );
    final goalId = await _seedLegacyGoal(
      localDatabase,
      id: 'goal_private',
      privacyLevel: 'do_not_analyze',
    );
    await _seedGoalFeedback(
      localDatabase,
      id: 'goal_private_feedback',
      goalId: goalId,
      feedbackDate: '2026-07-05',
    );

    final journeyEvents = await repository.listBetween(
      localUserId: 'local',
      startDate: '2026-07-01',
      endDate: '2026-07-31',
    );

    expect(journeyEvents, isEmpty);
  });

  test('duration helpfulness and status fields map consistently', () async {
    await phase3PlusRepository.insertMicroActionFeedback(
      MicroActionFeedbackModel(
        id: 'micro_fields',
        microActionId: 'micro_fields_action',
        localDate: '2026-07-02',
        happened: 'yes',
        effect: 'lighter',
        difficulty: 'easy',
        userNote: '短行动刚好',
        nextAdjustment: 'continue',
        createdAt: DateTime.utc(2026, 7, 2),
      ),
    );
    final experiment = await lifeExperimentRepository.ensureSuggested(
      localUserId: 'local',
      weekStart: '2026-07-01',
      weekEnd: '2026-07-07',
      title: '午后留白',
      hypothesis: '留白帮助恢复',
      suggestedAction: '午后留 10 分钟',
      linkedSignalCardIds: const [],
      status: 'saved',
    );
    await lifeExperimentRepository.recordFeedback(
      experimentId: experiment.id,
      completionStatus: 'adjusted',
      helpfulnessScore: 4,
      feedbackText: '时间需要更早',
      feedbackDate: DateTime(2026, 7, 3),
      durationMinutes: 12,
    );
    await _seedLegacySchedule(
      localDatabase,
      id: 'schedule_fields',
      localDate: '2026-07-04',
      actualEnergyLoad: 'draining',
      friction: 'context_switching',
    );
    final goalId = await _seedLegacyGoal(
      localDatabase,
      id: 'goal_fields',
    );
    await _seedGoalFeedback(
      localDatabase,
      id: 'goal_fields',
      goalId: goalId,
      feedbackDate: '2026-07-05',
      happened: 'no',
      effect: 'neutral',
      effortLevel: 'light',
    );

    final events = await repository.listBetween(
      localUserId: 'local',
      startDate: '2026-07-01',
      endDate: '2026-07-31',
    );

    final micro = events.singleWhere(
      (event) => event.sourceType == 'micro_action_feedback',
    );
    expect(micro.status, 'yes');
    expect(micro.effect, 'lighter');
    expect(micro.metadata['difficulty'], 'easy');

    final experimentEvent = events.singleWhere(
      (event) => event.sourceType == 'life_experiment_feedback',
    );
    expect(experimentEvent.status, 'adjusted');
    expect(experimentEvent.effect, '4');
    expect(experimentEvent.metadata['helpfulness_score'], 4);
    expect(experimentEvent.metadata['duration_minutes'], 12);

    final scheduleEvent = events.singleWhere(
      (event) => event.sourceType == 'schedule_feedback',
    );
    expect(scheduleEvent.status, 'recorded');
    expect(scheduleEvent.effect, 'draining');
    expect(scheduleEvent.metadata['friction'], 'context_switching');

    final goalEvent = events.singleWhere(
      (event) => event.sourceType == 'goal_feedback',
    );
    expect(goalEvent.status, 'no');
    expect(goalEvent.effect, 'neutral');
    expect(goalEvent.metadata['effort_level'], 'light');
  });
}

Future<void> _seedMicroFeedback(
  LocalDatabase localDatabase, {
  required String id,
  required String localDate,
}) async {
  final db = await localDatabase.database;
  await db.insert('micro_action_feedback', {
    'id': id,
    'micro_action_id': '${id}_action',
    'local_date': localDate,
    'happened': 'yes',
    'effect': 'helpful',
    'difficulty': 'easy',
    'user_note': '轻一点',
    'next_adjustment': 'continue',
    'created_at': DateTime.parse(localDate).toUtc().toIso8601String(),
  });
}

Future<String> _seedLegacySchedule(
  LocalDatabase localDatabase, {
  required String id,
  required String localDate,
  String? actualEnergyLoad,
  String? postMood,
  String? friction,
  String privacyLevel = 'private',
}) async {
  final db = await localDatabase.database;
  final now = DateTime.parse(localDate).toUtc().toIso8601String();
  await db.insert('schedule_signals', {
    'id': id,
    'title': '旧版安排反馈',
    'local_date': localDate,
    'anchor_date': localDate,
    'date_precision': 'date',
    'time_precision': 'none',
    'feedback_status': 'recorded',
    'actual_energy_load': actualEnergyLoad,
    'post_mood': postMood,
    'friction': friction,
    'privacy_level': privacyLevel,
    'created_at': now,
    'updated_at': now,
  });
  return id;
}

Future<String> _seedLegacyGoal(
  LocalDatabase localDatabase, {
  required String id,
  String privacyLevel = 'private',
}) async {
  final db = await localDatabase.database;
  const now = '2026-07-01T00:00:00.000Z';
  await db.insert('goals', {
    'id': id,
    'title': '旧版目标',
    'privacy_level': privacyLevel,
    'created_at': now,
    'updated_at': now,
  });
  return id;
}

Future<void> _seedGoalFeedback(
  LocalDatabase localDatabase, {
  required String id,
  required String goalId,
  required String feedbackDate,
  String happened = 'yes',
  String? effect = 'helpful',
  String? effortLevel = 'light',
}) async {
  final db = await localDatabase.database;
  final now = DateTime.parse(feedbackDate).toUtc().toIso8601String();
  await db.insert('goal_feedback', {
    'id': id,
    'goal_id': goalId,
    'feedback_date': feedbackDate,
    'happened': happened,
    'effort_level': effortLevel,
    'effect': effect,
    'comment': '做完轻一点',
    'next_adjustment': 'continue',
    'created_at': now,
    'updated_at': now,
  });
}
