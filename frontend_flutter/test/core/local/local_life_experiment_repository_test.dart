import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_opportunity_radar/core/local/local_feedback_event_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/local/local_experiment_candidate_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_life_experiment_repository.dart';

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
    expect(await repository.getById(experiment.id), isNotNull);

    final db = await localDatabase.database;
    final rows = await db.query(
      'experiment_candidates',
      columns: ['status', 'adopted_experiment_id'],
      where: 'id = ?',
      whereArgs: [candidate.id],
      limit: 1,
    );
    expect(rows.single['status'], 'adopted');
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

  test('deleting feedback marks rollup stale and removes FeedbackEvent',
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

    await repository.deleteFeedback(feedback!.id);

    final events =
        await LocalFeedbackEventRepository(localDatabase).listBetween(
      localUserId: 'local',
      startDate: '2026-06-01',
      endDate: '2026-06-30',
    );
    expect(events.map((event) => event.sourceId), isNot(contains(feedback.id)));

    final db = await localDatabase.database;
    final rollup = (await db.query(
      'life_experiment_rollups',
      where: 'experiment_id = ?',
      whereArgs: [experiment.id],
      limit: 1,
    ))
        .single;
    expect(rollup['total_feedback_count'], 0);
    expect(rollup['dirty'], 1);
    expect(rollup['is_stale'], 1);
    expect(rollup['stale_reason'], 'life_experiment_feedback_deleted');

    final traceLinks = await db.query(
      'trace_links',
      where: 'source_type = ? AND source_id = ?',
      whereArgs: ['life_experiment_feedback', feedback.id],
    );
    expect(traceLinks, isNotEmpty);
    expect(traceLinks.every((row) => row['status'] == 'inactive'), isTrue);
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
