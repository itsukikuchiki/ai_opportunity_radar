import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_opportunity_radar/core/local/local_feedback_event_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/local/local_experiment_candidate_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_life_experiment_repository.dart';
import 'package:ai_opportunity_radar/core/models/experiment_evaluation_models.dart';
import 'package:ai_opportunity_radar/core/models/weekly_models.dart';

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late LocalDatabase localDatabase;
  late LocalLifeExperimentRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('life_exp_repo_test_');
    localDatabase = LocalDatabase(
      dbPathOverride: p.join(tempDir.path, 'local.db'),
      databaseFactoryOverride: databaseFactoryFfi,
    );
    await localDatabase.init();
    repository = LocalLifeExperimentRepository(localDatabase);
  });

  tearDown(() async {
    await localDatabase.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('save and feedback write lifecycle events plus rollup', () async {
    final experiment = await repository.ensureSuggested(
      localUserId: 'local',
      weekStart: '2026-06-01',
      weekEnd: '2026-06-07',
      title: '晚间留白',
      hypothesis: '少接一个任务会更容易恢复',
      suggestedAction: '睡前不再开启新任务',
      linkedSignalCardIds: const ['sig-1'],
    );

    await repository.updateStatus(
      experimentId: experiment.id,
      status: 'saved',
    );
    await repository.recordFeedback(
      experimentId: experiment.id,
      completionStatus: 'helpful',
      helpfulnessScore: 5,
      feedbackText: '确实更轻一点',
      feedbackDate: DateTime(2026, 6, 3),
    );

    final db = await localDatabase.database;
    final events = await db.query(
      'life_experiment_lifecycle_events',
      where: 'experiment_id = ?',
      whereArgs: [experiment.id],
      orderBy: 'created_at ASC',
    );
    expect(events.map((row) => row['event_type']), contains('created'));
    expect(events.map((row) => row['event_type']), contains('status_changed'));
    expect(
        events.map((row) => row['event_type']), contains('feedback_recorded'));

    final rollups = await repository.listRollups(localUserId: 'local');
    expect(rollups, hasLength(1));
    expect(rollups.single['experiment_id'], experiment.id);
    expect(rollups.single['current_status'], 'active');
    expect(rollups.single['total_feedback_count'], 1);
    expect(rollups.single['tried_count'], 1);
    expect(rollups.single['helpful_count'], 1);
    expect(rollups.single['last_feedback_at'], isNotNull);

    final traceLinks = await db.query('trace_links');
    expect(
      traceLinks.where((row) =>
          row['source_type'] == 'life_experiment' &&
          row['source_id'] == experiment.id &&
          row['target_type'] == 'signal_card' &&
          row['target_id'] == 'sig-1' &&
          row['relation_type'] == 'evidence_signal'),
      hasLength(1),
    );
    expect(
      traceLinks.where((row) =>
          row['source_type'] == 'life_experiment_feedback' &&
          row['target_type'] == 'life_experiment' &&
          row['target_id'] == experiment.id &&
          row['relation_type'] == 'feedback_for'),
      hasLength(1),
    );
  });

  test('not suitable feedback is not counted as tried or failed', () async {
    final experiment = await repository.ensureSuggested(
      localUserId: 'local',
      weekStart: '2026-06-01',
      weekEnd: '2026-06-07',
      title: '晚间留白',
      hypothesis: '少接一个任务会更容易恢复',
      suggestedAction: '睡前不再开启新任务',
      linkedSignalCardIds: const ['sig-1'],
      status: 'saved',
    );

    await repository.recordFeedback(
      experimentId: experiment.id,
      completionStatus: 'not_suitable_today',
      feedbackText: '今天不适合，不代表失败。',
      feedbackDate: DateTime(2026, 6, 3),
    );

    final rollups = await repository.listRollups(localUserId: 'local');
    expect(rollups, hasLength(1));
    expect(rollups.single['total_feedback_count'], 1);
    expect(rollups.single['tried_count'], 0);
    expect(rollups.single['helpful_count'], 0);
    expect(rollups.single['not_helpful_count'], 0);
    expect(rollups.single['skipped_count'], 1);
  });

  test('source week does not end feedback; only explicit progress end does',
      () async {
    final experiment = await repository.ensureSuggested(
      localUserId: 'local',
      weekStart: '2026-06-01',
      weekEnd: '2026-06-07',
      title: '午后离开屏幕十分钟',
      hypothesis: '连续几天观察恢复变化。',
      suggestedAction: '午后离开屏幕十分钟。',
      linkedSignalCardIds: const ['sig-1'],
      status: 'active',
    );

    expect(
      await repository.recordFeedback(
        experimentId: experiment.id,
        completionStatus: 'completed',
        feedbackDate: DateTime(2026, 5, 31),
        enforceProgressWindow: true,
      ),
      isNull,
    );
    expect(
      await repository.recordFeedback(
        experimentId: experiment.id,
        completionStatus: 'completed',
        feedbackDate: DateTime(2026, 6, 3),
        enforceProgressWindow: true,
      ),
      isNotNull,
    );
    expect(
      await repository.recordFeedback(
        experimentId: experiment.id,
        completionStatus: 'completed',
        feedbackDate: DateTime(2026, 6, 8),
        enforceProgressWindow: true,
      ),
      isNotNull,
    );
    expect(
      await repository.listFeedbacks(experimentId: experiment.id),
      hasLength(2),
    );
    expect(
      (await repository.getSavedForToday(
        localUserId: 'local',
        today: DateTime(2026, 6, 20),
      ))
          ?.id,
      experiment.id,
    );

    final explicitlyEnded = await repository.ensureSuggested(
      localUserId: 'ended-user',
      weekStart: '2026-06-01',
      weekEnd: '2026-06-07',
      title: '只观察一周的目标',
      hypothesis: '明确周期结束后不再登记。',
      suggestedAction: '观察到 6 月 7 日。',
      linkedSignalCardIds: const ['sig-ended'],
      status: 'active',
      progressStartDate: '2026-06-01',
      progressEndDate: '2026-06-07',
    );
    expect(
      await repository.recordFeedback(
        experimentId: explicitlyEnded.id,
        completionStatus: 'completed',
        feedbackDate: DateTime(2026, 6, 8),
        enforceProgressWindow: true,
      ),
      isNull,
    );
  });

  test(
      'canonical completion rolls up completed as tried and not_completed as skipped',
      () async {
    final experiment = await repository.ensureSuggested(
      localUserId: 'local',
      weekStart: '2026-06-01',
      weekEnd: '2026-06-07',
      title: '午后离开屏幕十分钟',
      hypothesis: '短暂离开屏幕可能帮助恢复。',
      suggestedAction: '午后起身离开屏幕十分钟。',
      linkedSignalCardIds: const ['sig-1'],
      status: 'active',
    );

    final completed = await repository.recordFeedback(
      experimentId: experiment.id,
      completionStatus: 'completed',
      feedbackDate: DateTime(2026, 6, 3, 9),
    );
    await Future<void>.delayed(const Duration(milliseconds: 2));
    final notCompleted = await repository.recordFeedback(
      experimentId: experiment.id,
      completionStatus: 'not_completed',
      feedbackDate: DateTime(2026, 6, 3, 20),
    );
    final nextDayCompleted = await repository.recordFeedback(
      experimentId: experiment.id,
      completionStatus: 'completed',
      feedbackDate: DateTime(2026, 6, 4, 20),
    );

    expect(completed, isNotNull);
    expect(notCompleted, isNotNull);
    expect(nextDayCompleted, isNotNull);
    final rollups = await repository.listRollups(localUserId: 'local');
    expect(rollups, hasLength(1));
    expect(rollups.single['total_feedback_count'], 3);
    expect(rollups.single['tried_count'], 1);
    expect(rollups.single['skipped_count'], 1);
    expect(rollups.single['helpful_count'], 0);
    expect(rollups.single['not_helpful_count'], 0);

    final events =
        await LocalFeedbackEventRepository(localDatabase).listBetween(
      localUserId: 'local',
      startDate: '2026-06-01',
      endDate: '2026-06-30',
    );
    expect(
      events
          .where((event) => event.subjectId == experiment.id)
          .map((event) => event.status)
          .toSet(),
      {'completed', 'not_completed'},
    );
  });

  test('invalid feedback is excluded from page reads and rollups', () async {
    final experiment = await repository.ensureSuggested(
      localUserId: 'local',
      weekStart: '2026-06-01',
      weekEnd: '2026-06-07',
      title: '午后离开屏幕十分钟',
      hypothesis: '短暂离开屏幕可能帮助恢复。',
      suggestedAction: '午后起身离开屏幕十分钟。',
      linkedSignalCardIds: const ['sig-1'],
      status: 'active',
    );
    final feedback = await repository.recordFeedback(
      experimentId: experiment.id,
      completionStatus: 'completed',
      feedbackText: '这条后来被撤销。',
      feedbackDate: DateTime(2026, 6, 3, 9),
    );
    expect(feedback, isNotNull);
    final db = await localDatabase.database;
    await db.update(
      'life_experiment_feedback',
      {'is_valid': 0},
      where: 'id = ?',
      whereArgs: [feedback!.id],
    );
    await repository.refreshRollup(experiment.id);

    expect(
      await repository.listFeedbacks(experimentId: experiment.id),
      isEmpty,
    );
    expect(
      await repository.listFeedbacksForExperiments(
        experimentIds: [experiment.id],
      ),
      isEmpty,
    );
    final rollup = (await repository.listRollups(localUserId: 'local'))
        .singleWhere((row) => row['experiment_id'] == experiment.id);
    expect(rollup['total_feedback_count'], 0);
    expect(rollup['tried_count'], 0);
    expect(rollup['helpful_count'], 0);
    expect(rollup['last_feedback_at'], isNull);
  });

  test('an intentionally empty feedback note stays empty in storage', () async {
    final experiment = await repository.ensureSuggested(
      localUserId: 'local',
      weekStart: '2026-06-01',
      weekEnd: '2026-06-07',
      title: '午后离开屏幕十分钟',
      hypothesis: '短暂离开屏幕可能帮助恢复。',
      suggestedAction: '午后起身离开屏幕十分钟。',
      linkedSignalCardIds: const ['sig-1'],
      status: 'active',
    );
    final feedback = await repository.recordFeedback(
      experimentId: experiment.id,
      completionStatus: 'completed',
      feedbackText: '',
      feedbackDate: DateTime(2026, 6, 3, 9),
    );
    expect(feedback, isNotNull);

    final db = await localDatabase.database;
    final row = (await db.query(
      'life_experiment_feedback',
      where: 'id = ?',
      whereArgs: [feedback!.id],
      limit: 1,
    ))
        .single;
    expect(row['feedback_text'], '');
    expect(row['comment'], '');
  });

  test('adopting candidate creates formal life experiment', () async {
    final candidateRepository = LocalExperimentCandidateRepository(
      localDatabase,
    );
    final candidate = await candidateRepository.ensureWeeklyCandidate(
      localUserId: 'local',
      weekStart: '2026-06-01',
      weekEnd: '2026-06-07',
      title: '午后散步',
      hypothesis: '短散步可以降低下午卡住的感觉',
      suggestedAction: '下午出门走 8 分钟',
      linkedSignalCardIds: const ['sig-1'],
    );

    final experiment = await candidateRepository.adoptCandidate(
      candidateId: candidate.id,
      lifeExperimentRepository: repository,
    );

    expect(experiment, isNotNull);
    expect(experiment!.status, 'saved');
    expect(experiment.id, isNot(candidate.id));
    expect(experiment.sourceWeekStart, '2026-06-08');
    expect(experiment.sourceWeekEnd, '2026-06-14');
    expect(experiment.progressStartDate, '2026-06-08');
    expect(experiment.plannedTotalDays, isNull);
    expect(experiment.progressEndDate, isNull);
    expect(await repository.getById(experiment.id), isNotNull);

    final fixedDurationCandidate =
        await candidateRepository.ensureWeeklyCandidate(
      localUserId: 'fixed-duration-user',
      weekStart: '2026-06-08',
      weekEnd: '2026-06-14',
      title: '持续十天观察午后恢复',
      hypothesis: '连续观察可能看见恢复变化',
      suggestedAction: '每天午后记录一次恢复感受',
      linkedSignalCardIds: const ['sig-duration'],
      plannedTotalDays: 10,
    );
    final fixedDurationExperiment = await candidateRepository.adoptCandidate(
      candidateId: fixedDurationCandidate.id,
      lifeExperimentRepository: repository,
    );
    expect(fixedDurationExperiment, isNotNull);
    expect(fixedDurationExperiment!.sourceWeekStart, '2026-06-15');
    expect(fixedDurationExperiment.sourceWeekEnd, '2026-06-21');
    expect(fixedDurationExperiment.progressStartDate, '2026-06-15');
    expect(fixedDurationExperiment.plannedTotalDays, 10);
    expect(fixedDurationExperiment.progressEndDate, '2026-06-24');

    final db = await localDatabase.database;
    final rows = await db.query(
      'experiment_candidates',
      columns: ['status', 'decision_status', 'adopted_experiment_id'],
      where: 'id = ?',
      whereArgs: [candidate.id],
      limit: 1,
    );
    expect(rows.single['status'], 'adopted');
    expect(rows.single['decision_status'], 'adopted');
    expect(rows.single['adopted_experiment_id'], experiment.id);

    final rollups = await repository.listRollups(localUserId: 'local');
    expect(
      rollups.map((row) => row['experiment_id']),
      contains(experiment.id),
    );
  });

  test('append to current week keeps original and records lineage rollup',
      () async {
    final original = await repository.ensureSuggested(
      localUserId: 'local',
      weekStart: '2026-06-01',
      weekEnd: '2026-06-07',
      title: '午后散步',
      hypothesis: '短散步可以降低下午卡住的感觉',
      suggestedAction: '下午出门走 8 分钟',
      linkedSignalCardIds: const ['sig-1'],
      status: 'saved',
    );

    final clone = await repository.appendToCurrentWeek(
      experiment: original,
      fromDate: DateTime(2026, 6, 16),
    );

    expect(clone.id, isNot(original.id));
    expect(clone.parentExperimentId, original.id);
    expect(clone.sourceWeekStart, '2026-06-15');

    final all = await repository.listRecent(localUserId: 'local');
    expect(all.map((item) => item.id), contains(original.id));
    expect(all.map((item) => item.id), contains(clone.id));

    final db = await localDatabase.database;
    final cloneEvents = await db.query(
      'life_experiment_lifecycle_events',
      where: 'experiment_id = ?',
      whereArgs: [clone.id],
    );
    expect(
      cloneEvents.map((row) => row['event_type']),
      contains('appended_to_current_week'),
    );

    final rollups = await repository.listRollups(localUserId: 'local');
    final cloneRollup = rollups.firstWhere(
      (row) => row['experiment_id'] == clone.id,
    );
    expect(cloneRollup['root_experiment_id'], original.id);
    expect(cloneRollup['active_week_count'], 2);
    expect(cloneRollup['lineage_json'].toString(), contains(original.id));

    final traceLinks = await db.query('trace_links');
    expect(
      traceLinks.where((row) =>
          row['source_type'] == 'life_experiment' &&
          row['source_id'] == clone.id &&
          row['target_type'] == 'life_experiment' &&
          row['target_id'] == original.id &&
          row['relation_type'] == 'continued_from'),
      hasLength(1),
    );
    expect(
      traceLinks.where((row) =>
          row['source_type'] == 'life_experiment_rollup' &&
          row['source_id'] == clone.id &&
          row['target_id'] == original.id),
      isNotEmpty,
    );
  });

  test('reuse keeps an open goal open and respects an explicit duration',
      () async {
    final openGoal = await repository.ensureSuggested(
      localUserId: 'open-goal-user',
      weekStart: '2026-07-06',
      weekEnd: '2026-07-12',
      title: '持续观察恢复节奏',
      hypothesis: '长期记录后可能看见变化',
      suggestedAction: '每天记录一次恢复体感',
      linkedSignalCardIds: const ['sig-open'],
      status: 'active',
    );
    final continuedOpen = await repository.reuseForNextWeek(
      experiment: openGoal,
      fromDate: DateTime(2026, 7, 8),
    );
    expect(continuedOpen.sourceWeekStart, '2026-07-13');
    expect(continuedOpen.sourceWeekEnd, '2026-07-19');
    expect(continuedOpen.progressStartDate, '2026-07-13');
    expect(continuedOpen.plannedTotalDays, isNull);
    expect(continuedOpen.progressEndDate, isNull);

    final fixedGoal = await repository.ensureSuggested(
      localUserId: 'fixed-goal-user',
      weekStart: '2026-07-06',
      weekEnd: '2026-07-12',
      title: '观察十二天的切换节奏',
      hypothesis: '十二天足以覆盖不同工作日',
      suggestedAction: '每天记录一次切换后的体感',
      linkedSignalCardIds: const ['sig-fixed'],
      status: 'active',
      plannedTotalDays: 12,
    );
    final continuedFixed = await repository.reuseForNextWeek(
      experiment: fixedGoal,
      fromDate: DateTime(2026, 7, 8),
    );
    expect(continuedFixed.sourceWeekStart, '2026-07-13');
    expect(continuedFixed.sourceWeekEnd, '2026-07-19');
    expect(continuedFixed.progressStartDate, '2026-07-13');
    expect(continuedFixed.plannedTotalDays, 12);
    expect(continuedFixed.progressEndDate, '2026-07-24');
  });

  test(
      'status changes write lifecycle events for active pause complete archive',
      () async {
    final experiment = await repository.ensureSuggested(
      localUserId: 'local',
      weekStart: '2026-06-01',
      weekEnd: '2026-06-07',
      title: '午间暂停',
      hypothesis: '午间暂停能减少下午耗竭',
      suggestedAction: '午饭后离开屏幕 10 分钟',
      linkedSignalCardIds: const ['sig-1'],
      status: 'saved',
    );

    for (final status in const ['active', 'paused', 'completed', 'archived']) {
      await repository.updateStatus(
        experimentId: experiment.id,
        status: status,
      );
    }

    final db = await localDatabase.database;
    final events = await db.query(
      'life_experiment_lifecycle_events',
      where: 'experiment_id = ? AND event_type = ?',
      whereArgs: [experiment.id, 'status_changed'],
      orderBy: 'created_at ASC',
    );

    expect(events, hasLength(4));
    expect(events.map((row) => row['status_to']), [
      'active',
      'paused',
      'completed',
      'archived',
    ]);

    final rollups = await repository.listRollups(localUserId: 'local');
    final rollup = rollups.singleWhere(
      (row) => row['experiment_id'] == experiment.id,
    );
    expect(rollup['current_status'], 'archived');
  });

  test('feedback writes FeedbackEvent and updates rollup', () async {
    final experiment = await repository.ensureSuggested(
      localUserId: 'local',
      weekStart: '2026-06-01',
      weekEnd: '2026-06-07',
      title: '晚间留白',
      hypothesis: '少接一个任务会更容易恢复',
      suggestedAction: '睡前不再开启新任务',
      linkedSignalCardIds: const ['sig-1'],
      status: 'saved',
    );

    final feedback = await repository.recordFeedback(
      experimentId: experiment.id,
      completionStatus: 'adjusted',
      helpfulnessScore: 4,
      feedbackText: '需要把时间提前一点',
      feedbackDate: DateTime(2026, 6, 4),
      durationMinutes: 12,
    );

    expect(feedback, isNotNull);

    final events =
        await LocalFeedbackEventRepository(localDatabase).listBetween(
      localUserId: 'local',
      startDate: '2026-06-01',
      endDate: '2026-06-30',
    );
    final feedbackEvent = events.singleWhere(
      (event) => event.sourceId == feedback!.id,
    );
    expect(feedbackEvent.sourceType, 'life_experiment_feedback');
    expect(feedbackEvent.subjectType, 'life_experiment');
    expect(feedbackEvent.subjectId, experiment.id);
    expect(feedbackEvent.status, 'adjusted');

    final rollups = await repository.listRollups(localUserId: 'local');
    final rollup = rollups.singleWhere(
      (row) => row['experiment_id'] == experiment.id,
    );
    expect(rollup['total_feedback_count'], 1);
    expect(rollup['tried_count'], 1);
    expect(rollup['helpful_count'], 1);
    expect(rollup['adjusted_count'], 1);
  });

  test('feedback rows are append-only and same-day correction keeps old row',
      () async {
    final experiment = await repository.ensureSuggested(
      localUserId: 'local',
      weekStart: '2026-06-01',
      weekEnd: '2026-06-07',
      title: '晚间留白',
      hypothesis: '少接一个任务会更容易恢复',
      suggestedAction: '睡前不再开启新任务',
      linkedSignalCardIds: const ['sig-1'],
      status: 'saved',
    );
    final feedback = await repository.recordFeedback(
      experimentId: experiment.id,
      completionStatus: 'helpful',
      helpfulnessScore: 5,
      feedbackText: '确实更轻一点',
      feedbackDate: DateTime(2026, 6, 3),
    );
    expect(feedback, isNotNull);
    final originalFeedbackId = feedback!.id;

    final correction = await repository.recordFeedback(
      experimentId: experiment.id,
      completionStatus: 'not_completed',
      feedbackText: '今天没有完成',
      feedbackDate: DateTime(2026, 6, 3, 20),
    );
    expect(correction, isNotNull);

    expect(
      () => repository.updateFeedback(
        feedbackId: originalFeedbackId,
        completionStatus: 'adjusted',
      ),
      throwsUnsupportedError,
    );
    expect(
      () => repository.deleteFeedback(originalFeedbackId),
      throwsUnsupportedError,
    );

    final events =
        await LocalFeedbackEventRepository(localDatabase).listBetween(
      localUserId: 'local',
      startDate: '2026-06-01',
      endDate: '2026-06-30',
    );
    expect(events.map((event) => event.sourceId), contains(originalFeedbackId));
    expect(events.map((event) => event.sourceId), contains(correction!.id));

    final db = await localDatabase.database;
    final storedFeedbacks = await db.query(
      'life_experiment_feedback',
      where: 'experiment_id = ?',
      whereArgs: [experiment.id],
      orderBy: 'created_at ASC',
    );
    expect(storedFeedbacks, hasLength(2));
    expect(storedFeedbacks.first['completion_status'], 'helpful');
    expect(storedFeedbacks.last['completion_status'], 'not_completed');

    final rollup = (await db.query(
      'life_experiment_rollups',
      where: 'experiment_id = ?',
      whereArgs: [experiment.id],
      limit: 1,
    ))
        .single;
    expect(rollup['total_feedback_count'], 2);
    // Both rows remain for audit, while the later same-day result is the
    // effective completion state used by the rollup.
    expect(rollup['tried_count'], 0);

    final traceLinks = await db.query(
      'trace_links',
      where: 'source_type = ? AND source_id = ?',
      whereArgs: ['life_experiment_feedback', originalFeedbackId],
    );
    expect(traceLinks, isNotEmpty);
    expect(traceLinks.every((row) => row['status'] == 'active'), isTrue);
  });

  test('goal edit keeps feedback day on v1 and applies v2 to future Diary',
      () async {
    final fixedRepository = LocalLifeExperimentRepository(
      localDatabase,
      nowLoader: () => DateTime(2026, 7, 8, 12),
    );
    final experiment = await fixedRepository.ensureSuggested(
      localUserId: 'local',
      weekStart: '2026-07-06',
      weekEnd: '2026-07-12',
      title: '原来的本周目标',
      hypothesis: '原假设',
      suggestedAction: '原做法',
      linkedSignalCardIds: const [],
      status: 'saved',
      progressStartDate: '2026-07-06',
      progressEndDate: '2026-07-12',
    );
    await fixedRepository.recordFeedback(
      experimentId: experiment.id,
      completionStatus: 'completed',
      feedbackDate: DateTime(2026, 7, 8, 10),
    );

    final updated = await fixedRepository.updateDetails(
      experimentId: experiment.id,
      title: '明天开始的新版目标',
      suggestedAction: '明天开始采用新版做法',
    );
    expect(updated?.title, '明天开始的新版目标');
    expect(
      (await fixedRepository.getById(
        experiment.id,
        selectedLocalDate: '2026-07-08',
      ))
          ?.title,
      '原来的本周目标',
    );
    expect(
      (await fixedRepository.getById(
        experiment.id,
        selectedLocalDate: '2026-07-09',
      ))
          ?.title,
      '明天开始的新版目标',
    );

    final db = await localDatabase.database;
    final versions = await db.query(
      'plan_content_versions',
      where: 'object_kind = ? AND object_id = ?',
      whereArgs: ['goal', experiment.id],
      orderBy: 'version_no ASC',
    );
    expect(versions, hasLength(2));
    expect(versions.first['effective_from_local_date'], '2026-07-06');
    expect(versions.last['effective_from_local_date'], '2026-07-09');
  });

  test('content edit is rejected when feedback pushes it past period end',
      () async {
    final endOfPeriodRepository = LocalLifeExperimentRepository(
      localDatabase,
      nowLoader: () => DateTime(2026, 7, 12, 12),
    );
    final experiment = await endOfPeriodRepository.ensureSuggested(
      localUserId: 'period-end-user',
      weekStart: '2026-07-06',
      weekEnd: '2026-07-12',
      title: '截止日目标',
      hypothesis: '原假设',
      suggestedAction: '原做法',
      linkedSignalCardIds: const [],
      status: 'saved',
      progressStartDate: '2026-07-06',
      progressEndDate: '2026-07-12',
    );
    await endOfPeriodRepository.recordFeedback(
      experimentId: experiment.id,
      completionStatus: 'completed',
      feedbackDate: DateTime(2026, 7, 12, 10),
    );

    expect(
      await endOfPeriodRepository.updateDetails(
        experimentId: experiment.id,
        title: '不能越过周期生效',
      ),
      isNull,
    );
    expect(
        (await endOfPeriodRepository.getById(experiment.id))?.title, '截止日目标');
  });

  test('goal content can change only when it belongs to this or next week',
      () async {
    final fixedRepository = LocalLifeExperimentRepository(
      localDatabase,
      nowLoader: () => DateTime(2026, 7, 8, 12),
    );
    Future<LifeExperimentModel> seed(String start, String end, String title) {
      return fixedRepository.ensureSuggested(
        localUserId: 'local',
        weekStart: start,
        weekEnd: end,
        title: title,
        hypothesis: '原假设',
        suggestedAction: '原做法',
        linkedSignalCardIds: const [],
        status: 'saved',
      );
    }

    final past = await seed('2026-06-29', '2026-07-05', '过去目标');
    final current = await seed('2026-07-06', '2026-07-12', '本周目标');
    final next = await seed('2026-07-13', '2026-07-19', '下周目标');
    final future = await seed('2026-07-20', '2026-07-26', '以后目标');

    expect(
      await fixedRepository.updateDetails(
        experimentId: past.id,
        title: '不能修改',
      ),
      isNull,
    );
    expect(
      (await fixedRepository.updateDetails(
        experimentId: current.id,
        title: '本周已修改',
      ))
          ?.title,
      '本周已修改',
    );
    expect(
      (await fixedRepository.updateDetails(
        experimentId: next.id,
        title: '下周已修改',
      ))
          ?.title,
      '下周已修改',
    );
    final db = await localDatabase.database;
    final nextVersions = await db.query(
      'plan_content_versions',
      columns: const ['effective_from_local_date'],
      where: 'object_kind = ? AND object_id = ?',
      whereArgs: ['goal', next.id],
      orderBy: 'version_no ASC',
    );
    expect(
      nextVersions.map((row) => row['effective_from_local_date']),
      ['2026-07-13', '2026-07-13'],
    );
    expect(
      await fixedRepository.updateDetails(
        experimentId: future.id,
        title: '不能提前修改',
      ),
      isNull,
    );
    expect((await fixedRepository.getById(past.id))?.title, '过去目标');
    expect((await fixedRepository.getById(future.id))?.title, '以后目标');
  });

  test(
      'deleting experiment removes main reads, inactivates traces, stales upper caches',
      () async {
    final experiment = await repository.ensureSuggested(
      localUserId: 'local',
      weekStart: '2026-06-01',
      weekEnd: '2026-06-07',
      title: '午后散步',
      hypothesis: '短散步可以降低下午卡住的感觉',
      suggestedAction: '下午出门走 8 分钟',
      linkedSignalCardIds: const ['sig-1'],
      status: 'saved',
    );
    final feedback = await repository.recordFeedback(
      experimentId: experiment.id,
      completionStatus: 'helpful',
      feedbackDate: DateTime(2026, 6, 4),
    );
    await _seedWeeklySnapshot(
      localDatabase,
      weekStart: '2026-06-01',
      weekEnd: '2026-06-07',
    );
    await _seedJourneySnapshot(
      localDatabase,
      snapshotDate: '2026-06-30',
    );

    await repository.deleteExperiment(experiment.id);

    expect(await repository.getById(experiment.id), isNull);
    expect(
        await repository.listFeedbacks(experimentId: experiment.id), isEmpty);

    final db = await localDatabase.database;
    final rollups = await db.query(
      'life_experiment_rollups',
      where: 'experiment_id = ?',
      whereArgs: [experiment.id],
    );
    expect(rollups, isEmpty);
    expect(
      await db.query(
        'plan_content_versions',
        where: 'object_kind = ? AND object_id = ?',
        whereArgs: ['goal', experiment.id],
      ),
      isEmpty,
    );

    final traceLinks = await db.query(
      'trace_links',
      where:
          '(source_id = ? OR target_id = ? OR source_id = ?) AND status != ?',
      whereArgs: [experiment.id, experiment.id, feedback!.id, 'inactive'],
    );
    expect(traceLinks, isEmpty);

    final weekly = (await db.query(
      'weekly_snapshots',
      where: 'week_start = ?',
      whereArgs: ['2026-06-01'],
      limit: 1,
    ))
        .single;
    expect(weekly['dirty'], 1);
    expect(weekly['is_stale'], 1);
    expect(weekly['stale_reason'], 'life_experiment_deleted');

    final journey = (await db.query(
      'journey_snapshots',
      where: 'snapshot_date = ?',
      whereArgs: ['2026-06-30'],
      limit: 1,
    ))
        .single;
    expect(journey['dirty'], 1);
    expect(journey['is_stale'], 1);
    expect(journey['stale_reason'], 'life_experiment_deleted');
  });

  test('period queries only return overlapping experiments and rollups',
      () async {
    final june = await repository.ensureSuggested(
      localUserId: 'local',
      weekStart: '2026-06-01',
      weekEnd: '2026-06-07',
      title: '六月实验',
      hypothesis: '六月的节奏可以轻一点',
      suggestedAction: '六月先少排一个任务',
      linkedSignalCardIds: const ['sig-june'],
      status: 'saved',
    );
    final july = await repository.ensureSuggested(
      localUserId: 'local',
      weekStart: '2026-07-06',
      weekEnd: '2026-07-12',
      title: '七月实验',
      hypothesis: '七月需要新的恢复动作',
      suggestedAction: '七月午后留 10 分钟',
      linkedSignalCardIds: const ['sig-july'],
      status: 'saved',
    );

    await repository.recordFeedback(
      experimentId: june.id,
      completionStatus: 'helpful',
      feedbackDate: DateTime(2026, 6, 3),
    );
    await repository.recordFeedback(
      experimentId: july.id,
      completionStatus: 'adjusted',
      feedbackDate: DateTime(2026, 7, 8),
    );

    final juneExperiments = await repository.listRecentForPeriod(
      localUserId: 'local',
      startDate: '2026-06-01',
      endDate: '2026-06-30',
    );
    expect(juneExperiments.map((item) => item.id), contains(june.id));
    expect(juneExperiments.map((item) => item.id), isNot(contains(july.id)));

    final julyRollups = await repository.listRollupsForPeriod(
      localUserId: 'local',
      startDate: '2026-07-01',
      endDate: '2026-07-31',
    );
    expect(julyRollups.map((row) => row['experiment_id']), contains(july.id));
    expect(julyRollups.map((row) => row['experiment_id']),
        isNot(contains(june.id)));
  });

  test('typed goal reviews keep weekly and whole-round rules independent',
      () async {
    final experiment = await repository.ensureSuggested(
      localUserId: 'local',
      weekStart: '2026-07-20',
      weekEnd: '2026-08-20',
      title: '午后恢复目标',
      hypothesis: '持续留白后恢复可能更容易开始',
      suggestedAction: '每天午后离屏十分钟',
      linkedSignalCardIds: const ['sig-long-goal'],
      status: 'saved',
      plannedTotalDays: 32,
      minimumObservationDays: 5,
      progressStartDate: '2026-07-20',
      progressEndDate: '2026-08-20',
    );
    expect(experiment.minimumObservationDays, 5);
    expect(
        (await repository.getById(experiment.id))?.minimumObservationDays, 5);

    await repository.recordFeedback(
      experimentId: experiment.id,
      completionStatus: 'completed',
      feedbackDate: DateTime(2026, 7, 20, 10),
    );
    // A later same-day entry remains a separate fact and wins the daily
    // projection without rewriting the earlier completion.
    await repository.recordFeedback(
      experimentId: experiment.id,
      completionStatus: 'not_completed',
      feedbackDate: DateTime(2026, 7, 20, 11),
    );
    await repository.recordFeedback(
      experimentId: experiment.id,
      completionStatus: 'completed',
      feedbackDate: DateTime(2026, 7, 21, 10),
    );

    await expectLater(
      repository.recordWeeklyReview(
        experimentId: experiment.id,
        outcomeResult: GoalOutcomeResult.somewhatImproved,
        burden: EvaluationEffort.acceptable,
        reviewedAt: DateTime(2026, 7, 22, 11),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('goal_weekly_review_below_minimum_requires_unclear'),
        ),
      ),
    );
    final weeklyReview = await repository.recordWeeklyReview(
      experimentId: experiment.id,
      outcomeResult: GoalOutcomeResult.unclear,
      burden: EvaluationEffort.acceptable,
      reviewNote: '目前还不能判断',
      reviewedAt: DateTime(2026, 7, 22, 12),
    );
    expect(weeklyReview, isNotNull);
    expect(weeklyReview!.reviewType, GoalReviewType.weekly);
    expect(weeklyReview.completedDaysAtReview, 1);
    expect(weeklyReview.minimumObservationDays, 5);
    expect(weeklyReview.reviewNote, '目前还不能判断');

    await expectLater(
      repository.recordWeeklyReview(
        experimentId: experiment.id,
        outcomeResult: GoalOutcomeResult.unclear,
        burden: EvaluationEffort.easy,
        reviewedAt: DateTime(2026, 8, 5, 12),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'goal_weekly_review_requires_feedback_in_week',
        ),
      ),
    );

    await expectLater(
      repository.recordWholeRoundReview(
        experimentId: experiment.id,
        outcomeResult: GoalOutcomeResult.unclear,
        burden: EvaluationEffort.easy,
        reviewedAt: DateTime(2026, 7, 23, 12),
      ),
      throwsA(isA<StateError>()),
    );
    final explicitEndReview = await repository.recordWholeRoundReview(
      experimentId: experiment.id,
      outcomeResult: GoalOutcomeResult.unclear,
      burden: EvaluationEffort.easy,
      userConfirmedRoundEnd: true,
      reviewedAt: DateTime(2026, 7, 23, 12),
    );
    expect(explicitEndReview?.reviewType, GoalReviewType.wholeRound);
    expect(explicitEndReview?.outcomeResult, GoalOutcomeResult.unclear);
    await expectLater(
      repository.recordWholeRoundReview(
        experimentId: experiment.id,
        outcomeResult: GoalOutcomeResult.improved,
        burden: EvaluationEffort.easy,
        userConfirmedRoundEnd: true,
        reviewedAt: DateTime(2026, 7, 23, 13),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('below_minimum_requires_unclear'),
        ),
      ),
    );

    for (final day in const [22, 23, 24, 25]) {
      await repository.recordFeedback(
        experimentId: experiment.id,
        completionStatus: 'completed',
        feedbackDate: DateTime(2026, 7, day, 10),
      );
    }
    final thresholdReview = await repository.recordWholeRoundReview(
      experimentId: experiment.id,
      outcomeResult: GoalOutcomeResult.somewhatImproved,
      burden: EvaluationEffort.acceptable,
      reviewedAt: DateTime(2026, 7, 25, 12),
    );
    expect(thresholdReview?.completedDaysAtReview, 5);

    final reviews = await repository.listOutcomeReviews(
      experimentId: experiment.id,
    );
    expect(reviews, hasLength(3));
    expect(reviews.map((item) => item.outcomeResult), [
      GoalOutcomeResult.unclear,
      GoalOutcomeResult.unclear,
      GoalOutcomeResult.somewhatImproved,
    ]);
    expect(reviews.map((item) => item.reviewType), [
      GoalReviewType.weekly,
      GoalReviewType.wholeRound,
      GoalReviewType.wholeRound,
    ]);
    expect(
      await repository.listOutcomeReviews(
        experimentId: experiment.id,
        reviewType: GoalReviewType.weekly,
      ),
      hasLength(1),
    );

    final db = await localDatabase.database;
    final dailyFacts = await db.query(
      'life_experiment_feedback',
      where: 'experiment_id = ?',
      whereArgs: [experiment.id],
    );
    expect(dailyFacts, hasLength(7));
    final reviewEvents = await db.query(
      'life_experiment_lifecycle_events',
      where: 'experiment_id = ? AND event_type = ?',
      whereArgs: [experiment.id, 'outcome_reviewed'],
    );
    expect(reviewEvents, hasLength(3));
    expect(
      reviewEvents.map((row) => row['review_type']),
      [
        GoalReviewType.weekly,
        GoalReviewType.wholeRound,
        GoalReviewType.wholeRound,
      ],
    );
  });

  test('whole-round review accepts explicit period end or terminal lifecycle',
      () async {
    final ended = await repository.ensureSuggested(
      localUserId: 'local',
      weekStart: '2026-07-01',
      weekEnd: '2026-07-31',
      title: '有边界的目标',
      hypothesis: '观察到周期末',
      suggestedAction: '每天留白',
      linkedSignalCardIds: const [],
      status: 'active',
      minimumObservationDays: 5,
      progressStartDate: '2026-07-01',
      progressEndDate: '2026-07-10',
    );
    final endedReview = await repository.recordWholeRoundReview(
      experimentId: ended.id,
      outcomeResult: GoalOutcomeResult.unclear,
      burden: EvaluationEffort.acceptable,
      reviewedAt: DateTime(2026, 7, 10, 18),
    );
    expect(endedReview?.completedDaysAtReview, 0);
    await expectLater(
      repository.recordWholeRoundReview(
        experimentId: ended.id,
        outcomeResult: GoalOutcomeResult.noChange,
        burden: EvaluationEffort.acceptable,
        reviewedAt: DateTime(2026, 7, 10, 19),
      ),
      throwsA(isA<StateError>()),
    );

    final terminal = await repository.ensureSuggested(
      localUserId: 'local',
      weekStart: '2026-06-01',
      weekEnd: '2026-06-30',
      title: '已停止目标',
      hypothesis: '停止后仍可留下整轮事实',
      suggestedAction: '每周观察',
      linkedSignalCardIds: const [],
      status: 'stopped',
      minimumObservationDays: 5,
      progressStartDate: '2026-06-01',
    );
    final terminalReview = await repository.recordWholeRoundReview(
      experimentId: terminal.id,
      outcomeResult: GoalOutcomeResult.unclear,
      burden: EvaluationEffort.tooDifficult,
      reviewedAt: DateTime(2026, 7, 8, 18),
    );
    expect(terminalReview?.reviewType, GoalReviewType.wholeRound);
  });

  test('legacy goal models default to three minimum observation days', () {
    final legacy = LifeExperimentModel.fromJson(const {
      'id': 'legacy-goal',
      'local_user_id': 'local',
      'source_week_start': '2026-07-20',
      'source_week_end': '2026-07-26',
      'title': '旧目标',
      'hypothesis': '旧假设',
      'suggested_action': '旧动作',
      'linked_signal_card_ids': <String>[],
      'status': 'saved',
    });
    expect(legacy.minimumObservationDays, 3);
  });
}

Future<void> _seedWeeklySnapshot(
  LocalDatabase localDatabase, {
  required String weekStart,
  required String weekEnd,
}) async {
  final db = await localDatabase.database;
  await db.insert('weekly_snapshots', {
    'week_start': weekStart,
    'week_end': weekEnd,
    'status': 'ready',
    'patterns_json': '[]',
    'frictions_json': '[]',
    'chart_data_json': '[]',
    'feedback_submitted': 0,
    'source_hash': 'weekly-hash',
    'schema_version': 1,
    'pipeline_version': 'test',
    'dirty': 0,
    'is_stale': 0,
    'generated_at': DateTime.now().toUtc().toIso8601String(),
  });
}

Future<void> _seedJourneySnapshot(
  LocalDatabase localDatabase, {
  required String snapshotDate,
}) async {
  final db = await localDatabase.database;
  await db.insert('journey_snapshots', {
    'snapshot_date': snapshotDate,
    'patterns_json': '[]',
    'frictions_json': '[]',
    'desires_json': '[]',
    'experiments_json': '[]',
    'journey_data_json': '{}',
    'source_hash': 'journey-hash',
    'schema_version': 1,
    'pipeline_version': 'test',
    'dirty': 0,
    'is_stale': 0,
    'generated_at': DateTime.now().toUtc().toIso8601String(),
  });
}
