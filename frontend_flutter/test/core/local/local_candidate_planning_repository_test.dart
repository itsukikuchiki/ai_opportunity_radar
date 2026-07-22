import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_opportunity_radar/core/local/local_candidate_planning_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_capture_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/local/local_life_experiment_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_phase3_plus_repository.dart';
import 'package:ai_opportunity_radar/core/models/advanced_energy_boundary_models.dart';
import 'package:ai_opportunity_radar/core/models/candidate_models.dart';
import 'package:ai_opportunity_radar/core/models/energy_budget_models.dart';
import 'package:ai_opportunity_radar/core/models/experiment_evaluation_models.dart';
import 'package:ai_opportunity_radar/core/models/phase3_plus_models.dart';
import 'package:ai_opportunity_radar/core/state/app_data_refresh_coordinator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test('product tracks reuse the existing migration-safe storage kinds', () {
    expect(CandidateKind.microAction.storageValue, 'micro_action');
    expect(CandidateKind.microAction.lifeExperimentTrack,
        LifeExperimentTrack.smallTry);
    expect(CandidateKind.lifeExperiment.storageValue, 'life_experiment');
    expect(CandidateKind.lifeExperiment.lifeExperimentTrack,
        LifeExperimentTrack.goal);
  });

  test('small tries have a hard ten-minute planning ceiling', () {
    expect(SmallTryPlanningLimits.maxDurationMinutes, 10);
  });

  late Directory tempDir;
  late LocalDatabase localDatabase;
  late LocalCaptureRepository captureRepository;
  late LocalLifeExperimentRepository lifeExperimentRepository;
  late LocalCandidatePlanningRepository repository;
  final now = DateTime(2026, 7, 8, 12);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('candidate_planning_test_');
    localDatabase = LocalDatabase(
      dbPathOverride: p.join(tempDir.path, 'local.db'),
      databaseFactoryOverride: databaseFactoryFfi,
    );
    await localDatabase.init();
    captureRepository = LocalCaptureRepository(localDatabase);
    lifeExperimentRepository = LocalLifeExperimentRepository(
      localDatabase,
      nowLoader: () => now,
    );
    repository = LocalCandidatePlanningRepository(
      localDatabase: localDatabase,
      localCaptureRepository: captureRepository,
      localLifeExperimentRepository: lifeExperimentRepository,
      localUserId: 'local',
      nowLoader: () => now,
      focusDomainIdsLoader: () async => const [
        'emotional_stability',
        'growth_plan',
        'food_sleep',
      ],
      externalEnergySummaryLoader: () async => null,
    );
  });

  tearDown(() async {
    await repository.dispose();
    await localDatabase.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('daily gate opens at three distinct eligible SignalCards and caps at 3',
      () async {
    await _insertSignals(
      captureRepository,
      localDatabase,
      date: '2026-07-08',
      count: 2,
    );

    final gated = await repository.refreshDailyWithGroundedSuggestions(
      day: now,
    );
    expect(gated.gate.eligibleSignalCount, 2);
    expect(gated.gate.isOpen, isFalse);
    expect(gated.generation.status, CandidateGenerationStatus.gated);
    expect(gated.candidates, isEmpty);

    await _insertSignals(
      captureRepository,
      localDatabase,
      date: '2026-07-08',
      count: 1,
      offset: 2,
    );
    final ready = await repository.refreshDailyWithGroundedSuggestions(
      day: now,
    );
    expect(ready.gate.eligibleSignalCount, 3);
    expect(ready.generation.status, CandidateGenerationStatus.ready);
    expect(ready.candidates, hasLength(3));
    expect(ready.candidates.map((item) => item.rank), [1, 2, 3]);
    expect(
      ready.candidates.every((item) => item.title.startsWith('现在')),
      isTrue,
    );
    expect(
      ready.candidates.any(
          (item) => item.title.contains('睡前') || item.title.contains('下次')),
      isFalse,
    );
    expect(
      ready.candidates
          .every((item) => item.energyAdaptationExplanation.contains('小实验')),
      isTrue,
    );

    final secondRead = await repository.refreshDailyWithGroundedSuggestions(
      day: now,
    );
    expect(
      secondRead.candidates.map((item) => item.id),
      ready.candidates.map((item) => item.id),
    );
  });

  test('adopted small experiments keep every real attempt without a 7-day end',
      () async {
    await _insertSignals(
      captureRepository,
      localDatabase,
      date: '2026-07-08',
      count: 3,
    );
    final snapshot = await repository.refreshDailyWithGroundedSuggestions(
      day: now,
    );
    final adopted = await repository.adoptMicroActionCandidates(
      snapshot.candidates.take(2).map((item) => item.id),
    );
    expect(adopted, hasLength(2));
    expect(adopted.every((item) => item.progressStartDate == '2026-07-08'),
        isTrue);
    expect(adopted.every((item) => item.progressEndDate == null), isTrue);
    expect(
      adopted.every((item) => item.plannedDurationMinutes == 10),
      isTrue,
    );

    final afterAdoption = await repository.dailyCandidateSnapshot(now);
    expect(afterAdoption.generation.status, CandidateGenerationStatus.ready);
    expect(
        afterAdoption.candidates.where((item) => item.isAdopted), hasLength(2));
    expect(
      afterAdoption.candidates.where((item) => item.isAdopted).every(
          (item) => item.decisionStatus == CandidateDecisionStatus.adopted),
      isTrue,
    );

    final db = await localDatabase.database;
    final actionId = adopted.first.id;
    await db.insert('micro_action_feedback', {
      'id': 'feedback-first',
      'micro_action_id': actionId,
      'local_date': '2026-07-08',
      'happened': 'completed',
      'effect': 'helpful',
      'difficulty': 'okay',
      'next_adjustment': 'continue',
      'created_at': '2026-07-08T01:00:00Z',
      'updated_at': '2026-07-08T01:00:00Z',
      'is_valid': 1,
    });
    await db.insert('micro_action_feedback', {
      'id': 'feedback-last',
      'micro_action_id': actionId,
      'local_date': '2026-07-08',
      'happened': 'not_completed',
      'effect': 'unclear',
      'difficulty': 'okay',
      'next_adjustment': 'continue',
      'created_at': '2026-07-08T02:00:00Z',
      'updated_at': '2026-07-08T02:00:00Z',
      'is_valid': 1,
    });
    await db.insert('micro_action_feedback', {
      'id': 'feedback-day-two',
      'micro_action_id': actionId,
      'local_date': '2026-07-09',
      'happened': 'completed',
      'effect': 'helpful',
      'difficulty': 'okay',
      'next_adjustment': 'continue',
      'created_at': '2026-07-09T01:00:00Z',
      'updated_at': '2026-07-09T01:00:00Z',
      'is_valid': 1,
    });
    await db.insert('micro_action_feedback', {
      'id': 'feedback-invalid-later',
      'micro_action_id': actionId,
      'local_date': '2026-07-08',
      'happened': 'completed',
      'effect': 'helpful',
      'difficulty': 'okay',
      'next_adjustment': 'continue',
      'created_at': '2026-07-08T03:00:00Z',
      'updated_at': '2026-07-08T03:00:00Z',
      'is_valid': 0,
    });

    final progress = await repository.microActionProgress(actionId);
    expect(progress.cells, hasLength(3));
    expect(
      progress.cells.map((cell) => cell.state),
      [
        ProgressCellState.completed,
        ProgressCellState.notCompleted,
        ProgressCellState.completed,
      ],
    );
    expect(
      progress.cells.map((cell) => cell.latestEventId),
      ['feedback-first', 'feedback-last', 'feedback-day-two'],
    );
    expect(progress.completedAttempts, 2);

    final active = await repository.listActiveMicroActionsForDate(now);
    expect(active, hasLength(2));
    expect(
      await repository.listActiveMicroActionsForDate(DateTime(2026, 7, 20)),
      hasLength(2),
    );

    final adoptedRow = (await db.query(
      'micro_actions',
      where: 'id = ?',
      whereArgs: [actionId],
      limit: 1,
    ))
        .single;
    for (final entry in const [
      ('not-adopted-active', 'active'),
      ('not-adopted-dismissed', 'dismissed'),
    ]) {
      await db.insert('micro_actions', {
        ...adoptedRow,
        'id': entry.$1,
        'status': entry.$2,
        'adopted_at': null,
        'origin_candidate_id': null,
      });
    }
    final archive = await repository.listAdoptedSmallTries();
    expect(archive.map((item) => item.action.id).toSet(),
        adopted.map((item) => item.id).toSet());
    final diaryFirstDay = await repository.listAdoptedSmallTriesForDate(
      DateTime(2026, 7, 8),
    );
    final diarySecondDay = await repository.listAdoptedSmallTriesForDate(
      DateTime(2026, 7, 9),
    );
    final diaryWithoutAttempt = await repository.listAdoptedSmallTriesForDate(
      DateTime(2026, 7, 14),
    );
    expect(
      diaryFirstDay.map((item) => item.action.id).toSet(),
      {actionId},
    );
    expect(
      diarySecondDay.map((item) => item.action.id).toSet(),
      {actionId},
    );
    expect(diaryWithoutAttempt, isEmpty);
    expect(
      await repository.listAdoptedPlanContentDateKeys(),
      {'2026-07-08', '2026-07-09'},
    );
  });

  test('weekly plural adoption preserves origin and starts next Monday',
      () async {
    await _insertSignals(
      captureRepository,
      localDatabase,
      date: '2026-07-06',
      count: 3,
    );
    final snapshot = await repository.refreshWeeklyWithGroundedSuggestions(
      day: now,
    );
    expect(snapshot.gate.periodStart, '2026-07-06');
    expect(snapshot.gate.periodEnd, '2026-07-12');
    expect(snapshot.candidates, hasLength(3));
    expect(
      snapshot.candidates.every(
        (item) => item.suggestedAction.contains('从下周开始'),
      ),
      isTrue,
    );
    expect(
      snapshot.candidates.every(
        (item) => item.metadata['life_experiment_track'] == 'goal',
      ),
      isTrue,
    );
    expect(
      snapshot.candidates.every(
        (item) => !item.metadata.containsKey('observation_window_days'),
      ),
      isTrue,
    );
    expect(
      snapshot.candidates
          .every((item) => item.energyAdaptationExplanation.contains('目标')),
      isTrue,
    );

    final adopted = await repository.adoptExperimentCandidates(
      snapshot.candidates.take(2).map((item) => item.id),
    );
    expect(adopted, hasLength(2));
    expect(adopted.map((item) => item.id).toSet(), hasLength(2));
    expect(adopted.every((item) => item.originCandidateId != null), isTrue);
    expect(adopted.every((item) => item.progressStartDate == '2026-07-13'),
        isTrue);
    expect(adopted.every((item) => item.sourceWeekEnd == '2026-07-19'), isTrue);
    expect(adopted.every((item) => item.plannedTotalDays == null), isTrue);
    expect(adopted.every((item) => item.progressEndDate == null), isTrue);

    final laterWeekly = await repository.listAdoptedGoalsForWeek(
      weekStart: DateTime(2026, 8, 3),
      weekEnd: DateTime(2026, 8, 9),
    );
    expect(
      laterWeekly.map((item) => item.experiment.id).toSet(),
      adopted.map((item) => item.id).toSet(),
      reason: 'an open long-term goal must remain visible after source week',
    );

    final db = await localDatabase.database;
    final adoptedRow = (await db.query(
      'life_experiments',
      where: 'id = ?',
      whereArgs: [adopted.first.id],
      limit: 1,
    ))
        .single;
    await db.insert('life_experiments', {
      ...adoptedRow,
      'id': 'not-adopted-goal',
      'status': 'active',
      'adopted_at': null,
      'origin_candidate_id': null,
    });

    final diaryFirstDay = await repository.listAdoptedGoalsForDate(
      DateTime(2026, 7, 13),
    );
    final diaryLastDay = await repository.listAdoptedGoalsForDate(
      DateTime(2026, 7, 19),
    );
    final diaryAfterWindow = await repository.listAdoptedGoalsForDate(
      DateTime(2026, 7, 20),
    );
    expect(
      diaryFirstDay.map((item) => item.experiment.id).toSet(),
      adopted.map((item) => item.id).toSet(),
    );
    expect(
      diaryLastDay.map((item) => item.experiment.id).toSet(),
      adopted.map((item) => item.id).toSet(),
    );
    expect(
      diaryAfterWindow.map((item) => item.experiment.id).toSet(),
      adopted.map((item) => item.id).toSet(),
    );
    expect(
      await repository.listAdoptedPlanContentDateKeys(),
      {
        '2026-07-13',
        '2026-07-14',
        '2026-07-15',
        '2026-07-16',
        '2026-07-17',
        '2026-07-18',
        '2026-07-19',
      },
    );

    final afterAdoption = await repository.weeklyCandidateSnapshot(now);
    expect(afterAdoption.generation.status, CandidateGenerationStatus.ready);
    expect(
        afterAdoption.candidates.where((item) => item.isAdopted), hasLength(2));

    final idempotent = await repository.adoptExperimentCandidates(
      [snapshot.candidates.first.id],
    );
    expect(idempotent.single.id, adopted.first.id);
  });

  test('continuing a current experiment creates one idempotent next-week row',
      () async {
    final current = await lifeExperimentRepository.ensureSuggested(
      localUserId: 'local',
      weekStart: '2026-07-06',
      weekEnd: '2026-07-12',
      title: '午后留十分钟恢复',
      hypothesis: '短暂恢复可能减少下午耗竭。',
      suggestedAction: '午后离开屏幕十分钟。',
      linkedSignalCardIds: const ['signal-current-1'],
      status: 'active',
      adoptedAt: now,
      progressStartDate: '2026-07-06',
      progressEndDate: '2026-07-12',
    );
    await lifeExperimentRepository.recordFeedback(
      experimentId: current.id,
      completionStatus: 'completed',
      feedbackDate: DateTime(2026, 7, 8, 9),
    );

    final before = await repository.listContinuableExperimentsForNextWeek(now);
    expect(before.map((item) => item.experiment.id), [current.id]);

    final concurrent = await Future.wait([
      repository.continueExperimentsForNextWeek(
        experimentIds: [current.id],
        day: now,
      ),
      repository.continueExperimentsForNextWeek(
        experimentIds: [current.id],
        day: now,
      ),
    ]);
    expect(concurrent.expand((items) => items).map((item) => item.id).toSet(),
        hasLength(1));
    final continued = concurrent.first.single;
    expect(continued.parentExperimentId, current.id);
    expect(continued.sourceWeekStart, '2026-07-13');
    expect(continued.sourceWeekEnd, '2026-07-19');
    expect(continued.progressStartDate, '2026-07-13');
    expect(continued.plannedTotalDays, isNull);
    expect(continued.progressEndDate, isNull);
    expect(continued.adoptedAt, isNotNull);
    expect(continued.linkedSignalCardIds, current.linkedSignalCardIds);
    expect(
      await lifeExperimentRepository.listFeedbacks(
        experimentId: continued.id,
      ),
      isEmpty,
    );
    expect(
      await lifeExperimentRepository.listFeedbacks(experimentId: current.id),
      hasLength(1),
    );

    final second = await repository.continueExperimentsForNextWeek(
      experimentIds: [current.id],
      day: now,
    );
    expect(second.single.id, continued.id);
    expect(
        await repository.listContinuableExperimentsForNextWeek(now), isEmpty);

    final nextWeek = await repository.listActiveExperimentsForDate(
      DateTime(2026, 7, 13),
    );
    expect(nextWeek.map((item) => item.experiment.id), [continued.id]);

    final db = await localDatabase.database;
    final continuations = await db.query(
      'life_experiments',
      where: 'parent_experiment_id = ? AND source_week_start = ?',
      whereArgs: [current.id, '2026-07-13'],
    );
    expect(continuations, hasLength(1));
    final trace = await db.query(
      'trace_links',
      where: '''
        source_type = ? AND source_id = ?
        AND target_type = ? AND target_id = ?
        AND relation_type = ?
      ''',
      whereArgs: [
        'life_experiment',
        continued.id,
        'life_experiment',
        current.id,
        'continued_from',
      ],
    );
    expect(trace, hasLength(1));
  });

  test('life experiment UI feedback statuses map to the real seven-day grid',
      () async {
    final experiment = await lifeExperimentRepository.ensureSuggested(
      localUserId: 'local',
      weekStart: '2026-07-06',
      weekEnd: '2026-07-12',
      title: '晚间留十分钟恢复',
      hypothesis: '减少继续硬撑。',
      suggestedAction: '睡前做一个低要求恢复动作。',
      linkedSignalCardIds: const [],
      status: 'active',
      adoptedAt: DateTime(2026, 7, 6, 9),
      progressStartDate: '2026-07-06',
      progressEndDate: '2026-07-12',
    );
    await lifeExperimentRepository.recordFeedback(
      experimentId: experiment.id,
      completionStatus: 'helpful',
      feedbackDate: DateTime(2026, 7, 6, 20),
    );
    await lifeExperimentRepository.recordFeedback(
      experimentId: experiment.id,
      completionStatus: 'adjusted',
      feedbackDate: DateTime(2026, 7, 7, 20),
    );
    await lifeExperimentRepository.recordFeedback(
      experimentId: experiment.id,
      completionStatus: 'not_today',
      feedbackDate: DateTime(2026, 7, 8, 20),
    );

    final progress = await repository.lifeExperimentProgress(experiment.id);

    expect(progress.completedDays, 2);
    expect(progress.cells[0].state, ProgressCellState.completed);
    expect(progress.cells[1].state, ProgressCellState.completed);
    expect(progress.cells[2].state, ProgressCellState.notCompleted);
  });

  test(
      'life experiment canonical completion uses the last valid same-day feedback for X/7',
      () async {
    final experiment = await lifeExperimentRepository.ensureSuggested(
      localUserId: 'local',
      weekStart: '2026-07-06',
      weekEnd: '2026-07-12',
      title: '午后离开屏幕十分钟',
      hypothesis: '短暂离开屏幕可能帮助恢复。',
      suggestedAction: '午后起身离开屏幕十分钟。',
      linkedSignalCardIds: const [],
      status: 'active',
      adoptedAt: DateTime(2026, 7, 6, 9),
      progressStartDate: '2026-07-06',
      progressEndDate: '2026-07-12',
    );

    final first = await lifeExperimentRepository.recordFeedback(
      experimentId: experiment.id,
      completionStatus: 'completed',
      feedbackDate: DateTime(2026, 7, 6, 9),
    );
    await Future<void>.delayed(const Duration(milliseconds: 2));
    final last = await lifeExperimentRepository.recordFeedback(
      experimentId: experiment.id,
      completionStatus: 'not_completed',
      feedbackDate: DateTime(2026, 7, 6, 20),
    );
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await lifeExperimentRepository.recordFeedback(
      experimentId: experiment.id,
      completionStatus: 'completed',
      feedbackDate: DateTime(2026, 7, 7, 20),
    );

    expect(first, isNotNull);
    expect(last, isNotNull);
    final progress = await repository.lifeExperimentProgress(experiment.id);
    expect(progress.cells.first.state, ProgressCellState.notCompleted);
    expect(progress.cells.first.latestEventId, last!.id);
    expect(progress.cells[1].state, ProgressCellState.completed);
    expect(progress.completedDays, 1);

    final db = await localDatabase.database;
    final rows = await db.query(
      'life_experiment_feedback',
      where: 'experiment_id = ? AND is_valid = 1',
      whereArgs: [experiment.id],
    );
    expect(rows, hasLength(3));
  });

  test(
      'natural-week projections include ended adopted items and keep the last valid same-day feedback',
      () async {
    const weekDates = [
      '2026-07-06',
      '2026-07-07',
      '2026-07-08',
      '2026-07-09',
      '2026-07-10',
      '2026-07-11',
      '2026-07-12',
    ];
    final feedbackWriter = LocalPhase3PlusRepository(
      localDatabase,
      localUserId: 'local',
    );
    const actionId = 'ended-action-in-week';
    await feedbackWriter.upsertMicroAction(
      MicroActionModel(
        id: actionId,
        judgementId: 'judgement-ended-action',
        title: '周一留两分钟缓冲',
        reason: '本周早些时候采纳的小尝试',
        status: 'completed',
        localUserId: 'local',
        originCandidateId: 'candidate-ended-action',
        adoptedAt: DateTime(2026, 7, 6, 9),
        progressStartDate: '2026-07-06',
        progressEndDate: '2026-07-07',
        createdAt: DateTime(2026, 7, 6, 9),
        updatedAt: DateTime(2026, 7, 7, 21),
      ),
    );
    await feedbackWriter.insertMicroActionFeedback(
      MicroActionFeedbackModel(
        id: 'ended-action-first-valid',
        microActionId: actionId,
        localDate: '2026-07-06',
        happened: 'completed',
        createdAt: DateTime.utc(2026, 7, 6, 9),
      ),
    );
    await feedbackWriter.insertMicroActionFeedback(
      MicroActionFeedbackModel(
        id: 'ended-action-last-valid',
        microActionId: actionId,
        localDate: '2026-07-06',
        happened: 'not_completed',
        createdAt: DateTime.utc(2026, 7, 6, 20),
      ),
    );
    await feedbackWriter.insertMicroActionFeedback(
      MicroActionFeedbackModel(
        id: 'ended-action-later-invalid',
        microActionId: actionId,
        localDate: '2026-07-06',
        happened: 'completed',
        createdAt: DateTime.utc(2026, 7, 6, 21),
        isValid: false,
      ),
    );

    final experiment = await lifeExperimentRepository.ensureSuggested(
      localUserId: 'local',
      weekStart: '2026-07-06',
      weekEnd: '2026-07-07',
      title: '周一开始的恢复目标',
      hypothesis: '连续留出缓冲可能帮助恢复。',
      suggestedAction: '每天留出一个低要求恢复段。',
      linkedSignalCardIds: const [],
      status: 'completed',
      originCandidateId: 'candidate-ended-goal',
      adoptedAt: DateTime(2026, 7, 6, 9),
      progressStartDate: '2026-07-06',
      progressEndDate: '2026-07-07',
    );
    await lifeExperimentRepository.recordFeedback(
      experimentId: experiment.id,
      completionStatus: 'completed',
      feedbackDate: DateTime(2026, 7, 6, 9),
    );
    await Future<void>.delayed(const Duration(milliseconds: 2));
    final goalLastValid = await lifeExperimentRepository.recordFeedback(
      experimentId: experiment.id,
      completionStatus: 'not_completed',
      feedbackDate: DateTime(2026, 7, 6, 20),
    );
    await Future<void>.delayed(const Duration(milliseconds: 2));
    final goalLaterInvalid = await lifeExperimentRepository.recordFeedback(
      experimentId: experiment.id,
      completionStatus: 'completed',
      feedbackDate: DateTime(2026, 7, 6, 21),
    );
    expect(goalLastValid, isNotNull);
    expect(goalLaterInvalid, isNotNull);
    final db = await localDatabase.database;
    await db.update(
      'life_experiment_feedback',
      {'is_valid': 0},
      where: 'id = ?',
      whereArgs: [goalLaterInvalid!.id],
    );

    expect(await repository.listActiveMicroActionsForDate(now), isEmpty);
    expect(await repository.listActiveExperimentsForDate(now), isEmpty);

    final actions = await repository.listAdoptedSmallTriesForWeek(
      weekStart: DateTime(2026, 7, 6),
      weekEnd: DateTime(2026, 7, 12),
    );
    expect(actions, hasLength(1));
    expect(actions.single.action.id, actionId);
    expect(actions.single.action.status, 'completed');
    expect(actions.single.progress.startDate, weekDates.first);
    expect(actions.single.progress.endDate, weekDates.last);
    expect(
      actions.single.progress.cells.map((cell) => cell.localDate).toList(),
      ['2026-07-06', '2026-07-06'],
    );
    expect(actions.single.progress.cells, hasLength(2));
    expect(
      actions.single.progress.cells.first.state,
      ProgressCellState.completed,
    );
    expect(
      actions.single.progress.cells.first.latestEventId,
      'ended-action-first-valid',
    );
    expect(
      actions.single.progress.cells.last.latestEventId,
      'ended-action-last-valid',
    );
    expect(actions.single.progress.completedAttempts, 1);

    final goals = await repository.listAdoptedGoalsForWeek(
      weekStart: DateTime(2026, 7, 6),
      weekEnd: DateTime(2026, 7, 12),
    );
    expect(goals, hasLength(1));
    expect(goals.single.experiment.id, experiment.id);
    expect(goals.single.experiment.status, 'completed');
    expect(goals.single.progress.startDate, weekDates.first);
    expect(goals.single.progress.endDate, weekDates.last);
    expect(
      goals.single.progress.cells.map((cell) => cell.localDate).toList(),
      weekDates,
    );
    expect(goals.single.progress.cells, hasLength(7));
    expect(
      goals.single.progress.cells.first.state,
      ProgressCellState.notCompleted,
    );
    expect(
      goals.single.progress.cells.first.latestEventId,
      goalLastValid!.id,
    );
    expect(goals.single.progress.completedDays, 0);
  });

  test('adopting zero candidates is a zero-write choice for both object types',
      () async {
    await _insertSignals(
      captureRepository,
      localDatabase,
      date: '2026-07-08',
      count: 3,
    );
    final daily = await repository.refreshDailyWithGroundedSuggestions(
      day: now,
    );
    final weekly = await repository.refreshWeeklyWithGroundedSuggestions(
      day: now,
    );
    expect(daily.candidates, hasLength(3));
    expect(weekly.candidates, hasLength(3));

    expect(await repository.adoptMicroActionCandidates(const []), isEmpty);
    expect(await repository.adoptExperimentCandidates(const []), isEmpty);

    final db = await localDatabase.database;
    expect(await db.query('micro_actions'), isEmpty);
    expect(await db.query('life_experiments'), isEmpty);
    expect(
      (await repository.dailyCandidateSnapshot(now))
          .candidates
          .every((candidate) => !candidate.isAdopted),
      isTrue,
    );
    expect(
      (await repository.weeklyCandidateSnapshot(now))
          .candidates
          .every((candidate) => !candidate.isAdopted),
      isTrue,
    );
  });

  test(
      'consider decision persists across both tracks without creating plans and can later be adopted',
      () async {
    await _insertSignals(
      captureRepository,
      localDatabase,
      date: '2026-07-08',
      count: 3,
    );
    final daily = await repository.refreshDailyWithGroundedSuggestions(
      day: now,
    );
    final weekly = await repository.refreshWeeklyWithGroundedSuggestions(
      day: now,
    );
    final microId = daily.candidates.first.id;
    final experimentId = weekly.candidates.first.id;

    expect(
      await repository.markCandidatesConsidering([microId, experimentId]),
      2,
    );
    final db = await localDatabase.database;
    expect(await db.query('micro_actions'), isEmpty);
    expect(await db.query('life_experiments'), isEmpty);
    expect(
      (await repository.listConsideringMicroActionCandidates())
          .map((item) => item.id),
      contains(microId),
    );
    expect(
      (await repository.listConsideringExperimentCandidates())
          .map((item) => item.id),
      contains(experimentId),
    );

    // A source change must not erase the historical observation snapshot.
    await db.update(
      'micro_action_candidates',
      {'dirty': 1, 'is_stale': 1, 'stale_reason': 'source_changed'},
      where: 'id = ?',
      whereArgs: [microId],
    );
    expect(
      (await repository.listConsideringMicroActionCandidates())
          .map((item) => item.id),
      contains(microId),
    );

    final adopted = await repository.adoptExperimentCandidates([experimentId]);
    expect(adopted, hasLength(1));
    final adoptedCandidate = (await repository.weeklyCandidateSnapshot(now))
        .candidates
        .singleWhere((item) => item.id == experimentId);
    expect(adoptedCandidate.decisionStatus, CandidateDecisionStatus.adopted);
    expect(adoptedCandidate.isAdopted, isTrue);
    expect(
      await repository.markCandidatesConsidering([experimentId]),
      0,
      reason: 'an adopted candidate cannot be downgraded to considering',
    );
  });

  test('explicitly completing a small try does not synthesize daily feedback',
      () async {
    await _insertSignals(
      captureRepository,
      localDatabase,
      date: '2026-07-08',
      count: 3,
    );
    final daily = await repository.refreshDailyWithGroundedSuggestions(
      day: now,
    );
    final action = (await repository.adoptMicroActionCandidates(
      [daily.candidates.first.id],
    ))
        .single;
    final db = await localDatabase.database;
    await db.insert('micro_action_feedback', {
      'id': 'feedback-before-lifecycle-completion',
      'micro_action_id': action.id,
      'local_date': '2026-07-08',
      'happened': 'completed',
      'created_at': '2026-07-08T01:00:00Z',
      'updated_at': '2026-07-08T01:00:00Z',
      'is_valid': 1,
    });

    final completed = await repository.completeMicroAction(action.id);
    expect(completed?.status, 'completed');
    expect(
      await db.query(
        'micro_action_feedback',
        where: 'micro_action_id = ?',
        whereArgs: [action.id],
      ),
      hasLength(1),
      reason: 'lifecycle completion must not create a progress cell',
    );
    expect(
        (await repository.completeMicroAction(action.id))?.status, 'completed',
        reason: 'completion is idempotent');

    final nextWeek =
        await repository.refreshNextWeekPlanWithGroundedSuggestions(day: now);
    final planned = (await repository.adoptMicroActionCandidates(
      [nextWeek.smallTryCandidates.first.id],
    ))
        .single;
    expect(planned.status, 'planned');
    expect(await repository.completeMicroAction(planned.id), isNull,
        reason: 'a future plan has not started and cannot be completed');
  });

  test('small-experiment attempts and goal daily progress stay independent',
      () async {
    await _insertSignals(
      captureRepository,
      localDatabase,
      date: '2026-07-08',
      count: 3,
    );
    final daily = await repository.refreshDailyWithGroundedSuggestions(
      day: now,
    );
    final action = (await repository.adoptMicroActionCandidates(
      [daily.candidates.first.id],
    ))
        .single;
    final weekly = await repository.refreshWeeklyWithGroundedSuggestions(
      day: now,
    );
    final experiment = (await repository.adoptExperimentCandidates(
      [weekly.candidates.first.id],
    ))
        .single;

    final db = await localDatabase.database;
    for (final date in const ['2026-07-08', '2026-07-09']) {
      await db.insert('micro_action_feedback', {
        'id': 'action-$date',
        'micro_action_id': action.id,
        'local_date': date,
        'happened': 'yes',
        'effect': 'helpful',
        'created_at': '${date}T01:00:00Z',
        'updated_at': '${date}T01:00:00Z',
        'is_valid': 1,
      });
    }

    expect((await repository.microActionProgress(action.id)).completedDays, 2);
    expect(
      (await repository.lifeExperimentProgress(experiment.id)).completedDays,
      0,
      reason: 'action feedback must not increment experiment progress',
    );

    await lifeExperimentRepository.recordFeedback(
      experimentId: experiment.id,
      completionStatus: 'completed',
      feedbackDate: DateTime(2026, 7, 13),
    );

    expect((await repository.microActionProgress(action.id)).completedDays, 2);
    expect(
      (await repository.lifeExperimentProgress(experiment.id)).completedDays,
      1,
    );
  });

  test(
      'source change stales proposals but preserves adopted object with warning',
      () async {
    final signalIds = await _insertSignals(
      captureRepository,
      localDatabase,
      date: '2026-07-08',
      count: 3,
    );
    final snapshot = await repository.refreshDailyWithGroundedSuggestions(
      day: now,
    );
    final adopted = await repository.adoptMicroActionCandidates(
      [snapshot.candidates.first.id],
    );

    final staleNotice = repository
        .watchGenerationState(
          kind: CandidateKind.microAction,
          periodStart: '2026-07-08',
          periodEnd: '2026-07-08',
        )
        .firstWhere(
          (state) => state.status == CandidateGenerationStatus.stale,
        );
    await captureRepository.deleteSignalCard(signalIds.first);
    expect(
      (await staleNotice.timeout(const Duration(seconds: 2))).status,
      CandidateGenerationStatus.stale,
    );

    final afterDelete = await repository.dailyCandidateSnapshot(now);
    expect(afterDelete.generation.status, CandidateGenerationStatus.gated);
    expect(afterDelete.gate.eligibleSignalCount, 2);
    expect(afterDelete.candidates, isEmpty);

    final db = await localDatabase.database;
    final adoptedRows = await db.query(
      'micro_actions',
      where: 'id = ?',
      whereArgs: [adopted.single.id],
    );
    expect(adoptedRows.single['source_changed'], 1);
    expect(adoptedRows.single['source_change_reason'], 'signal_deleted');

    final candidateRows = await db.query(
      'micro_action_candidates',
      where: 'candidate_group_id = ?',
      whereArgs: [snapshot.candidates.first.candidateGroupId],
    );
    expect(
      candidateRows
          .where((row) => row['status'] != 'adopted')
          .every((row) => row['is_stale'] == 1),
      isTrue,
    );
  });

  test('edited candidate keeps provenance and can be adopted', () async {
    await _insertSignals(
      captureRepository,
      localDatabase,
      date: '2026-07-08',
      count: 3,
    );
    final snapshot = await repository.refreshDailyWithGroundedSuggestions(
      day: now,
    );
    final original = snapshot.candidates.first;
    final edited = await repository.updateMicroActionCandidate(
      candidateId: original.id,
      title: '我自己的两分钟行动',
    );
    expect(edited?.status, 'edited');
    expect(edited?.title, '我自己的两分钟行动');
    expect(edited?.linkedSignalCardIds, original.linkedSignalCardIds);
    expect(edited?.sourceHash, original.sourceHash);

    final adopted = await repository.adoptMicroActionCandidates([original.id]);
    expect(adopted.single.title, '我自己的两分钟行动');
  });

  test('small-try edit keeps past Diary on v1 and applies v2 tomorrow',
      () async {
    await _insertSignals(
      captureRepository,
      localDatabase,
      date: '2026-07-08',
      count: 3,
    );
    final snapshot = await repository.refreshDailyWithGroundedSuggestions(
      day: now,
    );
    final adopted = (await repository.adoptMicroActionCandidates(
      [snapshot.candidates.first.id],
    ))
        .single;
    final originalTitle = adopted.title;
    final db = await localDatabase.database;
    await db.insert('micro_action_feedback', {
      'id': 'feedback-before-content-edit',
      'micro_action_id': adopted.id,
      'local_date': '2026-07-08',
      'happened': 'completed',
      'effect': 'helpful',
      'difficulty': 'okay',
      'next_adjustment': 'continue',
      'created_at': '2026-07-08T03:00:00Z',
      'updated_at': '2026-07-08T03:00:00Z',
      'is_valid': 1,
    });

    final updated = await repository.updateAdoptedMicroActionContent(
      microActionId: adopted.id,
      title: '明天开始的新版小尝试',
    );
    expect(updated?.title, '明天开始的新版小尝试');
    await db.insert('micro_action_feedback', {
      'id': 'feedback-after-content-edit',
      'micro_action_id': adopted.id,
      'local_date': '2026-07-09',
      'happened': 'completed',
      'effect': 'helpful',
      'difficulty': 'okay',
      'next_adjustment': 'continue',
      'created_at': '2026-07-09T03:00:00Z',
      'updated_at': '2026-07-09T03:00:00Z',
      'is_valid': 1,
    });

    final pastDiary = await repository.listAdoptedSmallTriesForDate(
      DateTime(2026, 7, 8),
    );
    final futureDiary = await repository.listAdoptedSmallTriesForDate(
      DateTime(2026, 7, 9),
    );
    final pastToday = await repository.listActiveMicroActionsForDate(
      DateTime(2026, 7, 8),
    );
    final futureToday = await repository.listActiveMicroActionsForDate(
      DateTime(2026, 7, 9),
    );
    expect(pastDiary.single.action.title, originalTitle);
    expect(futureDiary.single.action.title, '明天开始的新版小尝试');
    expect(pastToday.single.action.title, originalTitle);
    expect(futureToday.single.action.title, '明天开始的新版小尝试');

    final versions = await db.query(
      'plan_content_versions',
      where: 'object_kind = ? AND object_id = ?',
      whereArgs: ['quick_try', adopted.id],
      orderBy: 'version_no ASC',
    );
    expect(versions, hasLength(2));
    expect(versions.first['effective_from_local_date'], '2026-07-08');
    expect(versions.last['effective_from_local_date'], '2026-07-09');
  });

  test('failed small-try projection update rolls back appended version',
      () async {
    await _insertSignals(
      captureRepository,
      localDatabase,
      date: '2026-07-08',
      count: 3,
    );
    final snapshot = await repository.refreshDailyWithGroundedSuggestions(
      day: now,
    );
    final adopted = (await repository.adoptMicroActionCandidates(
      [snapshot.candidates.first.id],
    ))
        .single;
    final db = await localDatabase.database;
    await db.execute('''
      CREATE TRIGGER reject_atomic_micro_action_update
      BEFORE UPDATE OF title ON micro_actions
      WHEN NEW.title = '强制事务失败'
      BEGIN
        SELECT RAISE(ABORT, 'forced projection failure');
      END
    ''');

    expect(
      () => repository.updateAdoptedMicroActionContent(
        microActionId: adopted.id,
        title: '强制事务失败',
      ),
      throwsA(isA<DatabaseException>()),
    );

    final versions = await db.query(
      'plan_content_versions',
      where: 'object_kind = ? AND object_id = ?',
      whereArgs: ['quick_try', adopted.id],
      orderBy: 'version_no ASC',
    );
    expect(versions, hasLength(1));
    expect(
      (await db.query(
        'micro_actions',
        columns: const ['title'],
        where: 'id = ?',
        whereArgs: [adopted.id],
        limit: 1,
      ))
          .single['title'],
      adopted.title,
    );
  });

  test('goal Today and Diary reads resolve content at the selected date',
      () async {
    final experiment = await lifeExperimentRepository.ensureSuggested(
      localUserId: 'local',
      weekStart: '2026-07-06',
      weekEnd: '2026-07-12',
      title: '原来的目标',
      hypothesis: '原假设',
      suggestedAction: '原做法',
      linkedSignalCardIds: const [],
      status: 'saved',
      adoptedAt: now,
      progressStartDate: '2026-07-06',
      progressEndDate: '2026-07-12',
    );
    await lifeExperimentRepository.recordFeedback(
      experimentId: experiment.id,
      completionStatus: 'completed',
      feedbackDate: DateTime(2026, 7, 8, 10),
    );
    expect(
      (await lifeExperimentRepository.updateDetails(
        experimentId: experiment.id,
        title: '明天开始的新版目标',
      ))
          ?.title,
      '明天开始的新版目标',
    );

    final pastToday = await repository.listActiveExperimentsForDate(
      DateTime(2026, 7, 8),
    );
    final futureToday = await repository.listActiveExperimentsForDate(
      DateTime(2026, 7, 9),
    );
    final pastDiary = await repository.listAdoptedGoalsForDate(
      DateTime(2026, 7, 8),
    );
    final futureDiary = await repository.listAdoptedGoalsForDate(
      DateTime(2026, 7, 9),
    );
    expect(pastToday.single.experiment.title, '原来的目标');
    expect(futureToday.single.experiment.title, '明天开始的新版目标');
    expect(pastDiary.single.experiment.title, '原来的目标');
    expect(futureDiary.single.experiment.title, '明天开始的新版目标');
  });

  test('past candidate and adopted small-try content cannot be edited',
      () async {
    await _insertSignals(
      captureRepository,
      localDatabase,
      date: '2026-07-08',
      count: 3,
    );
    final snapshot = await repository.refreshDailyWithGroundedSuggestions(
      day: now,
    );
    final currentCandidate = snapshot.candidates.first;
    final adopted = (await repository.adoptMicroActionCandidates(
      [currentCandidate.id],
    ))
        .single;

    final currentEdit = await repository.updateAdoptedMicroActionContent(
      microActionId: adopted.id,
      title: '本周可以修改的小尝试',
    );
    expect(currentEdit?.title, '本周可以修改的小尝试');

    final db = await localDatabase.database;
    await db.update(
      'micro_actions',
      {
        'progress_start_date': '2026-06-22',
        'progress_end_date': '2026-06-28',
      },
      where: 'id = ?',
      whereArgs: [adopted.id],
    );
    final pastEdit = await repository.updateAdoptedMicroActionContent(
      microActionId: adopted.id,
      title: '过去内容不能修改',
    );
    expect(pastEdit, isNull);
    expect(
      (await db.query(
        'micro_actions',
        columns: const ['title'],
        where: 'id = ?',
        whereArgs: [adopted.id],
      ))
          .single['title'],
      '本周可以修改的小尝试',
    );

    final pastCandidateId = snapshot.candidates[1].id;
    await db.update(
      'micro_action_candidates',
      {'local_date': '2026-06-28'},
      where: 'id = ?',
      whereArgs: [pastCandidateId],
    );
    expect(
      await repository.updateMicroActionCandidate(
        candidateId: pastCandidateId,
        title: '过去候选也不能修改',
      ),
      isNull,
    );
  });

  test('next-week goal candidate can be edited but an old candidate cannot',
      () async {
    await _insertSignals(
      captureRepository,
      localDatabase,
      date: '2026-07-06',
      count: 3,
    );
    final snapshot = await repository.refreshWeeklyWithGroundedSuggestions(
      day: now,
    );
    final editable = snapshot.candidates.first;
    expect(
      (await repository.updateExperimentCandidate(
        candidateId: editable.id,
        title: '下周可修改目标',
        suggestedAction: '下周每天做一次',
      ))
          ?.title,
      '下周可修改目标',
    );

    final oldCandidateId = snapshot.candidates[1].id;
    final db = await localDatabase.database;
    await db.update(
      'experiment_candidates',
      {
        'source_week_start': '2026-06-15',
        'source_week_end': '2026-06-21',
      },
      where: 'id = ?',
      whereArgs: [oldCandidateId],
    );
    expect(
      await repository.updateExperimentCandidate(
        candidateId: oldCandidateId,
        title: '过去目标不能修改',
        suggestedAction: '不能修改',
      ),
      isNull,
    );
  });

  test('source changes during generation discard old drafts and regenerate',
      () async {
    final signalIds = await _insertSignals(
      captureRepository,
      localDatabase,
      date: '2026-07-08',
      count: 3,
    );
    final generationStarted = Completer<void>();
    final releaseFirstGeneration = Completer<void>();
    var generationCount = 0;

    final refresh = repository.refreshDailyIfSourceChanged(
      day: now,
      generate: (gate) async {
        generationCount += 1;
        final generation = generationCount;
        if (generation == 1) {
          generationStarted.complete();
          await releaseFirstGeneration.future;
        }
        return [
          MicroActionCandidateDraft(
            title: 'generation-$generation',
            reason: 'Uses the current source set only.',
            difficulty: 'very_light',
            linkedSignalCardIds: gate.eligibleSignalCardIds,
          ),
        ];
      },
    );

    await generationStarted.future;
    await captureRepository.deleteSignalCard(signalIds.first);
    final replacement = await _insertSignals(
      captureRepository,
      localDatabase,
      date: '2026-07-08',
      count: 1,
      offset: 3,
    );
    releaseFirstGeneration.complete();

    final snapshot = await refresh;
    expect(generationCount, 2);
    expect(snapshot.generation.status, CandidateGenerationStatus.ready);
    expect(snapshot.candidates.single.title, 'generation-2');
    expect(
      snapshot.candidates.single.linkedSignalCardIds,
      contains(replacement.single),
    );
    expect(
      snapshot.candidates.single.linkedSignalCardIds,
      isNot(contains(signalIds.first)),
    );
  });

  test(
      'multi-adoption rolls back as one batch and concurrent retry is idempotent',
      () async {
    await _insertSignals(
      captureRepository,
      localDatabase,
      date: '2026-07-08',
      count: 3,
    );
    final snapshot = await repository.refreshDailyWithGroundedSuggestions(
      day: now,
    );

    await expectLater(
      repository.adoptMicroActionCandidates([
        snapshot.candidates.first.id,
        'missing-candidate',
      ]),
      throwsStateError,
    );
    final db = await localDatabase.database;
    expect(await db.query('micro_actions'), isEmpty);

    final concurrent = await Future.wait([
      repository.adoptMicroActionCandidates([snapshot.candidates.first.id]),
      repository.adoptMicroActionCandidates([snapshot.candidates.first.id]),
    ]);
    expect(concurrent[0].single.id, concurrent[1].single.id);
    expect(await db.query('micro_actions'), hasLength(1));
  });

  test('planning context 同时带入当日/当周能量、关注重点与有效反馈', () async {
    await repository.dispose();
    await _insertSignals(
      captureRepository,
      localDatabase,
      date: '2026-07-08',
      count: 3,
    );
    final db = await localDatabase.database;
    await db.update(
      'signal_cards',
      {
        'source_type': 'one_tap',
        'raw_payload_json': '{"quick_status":"tired","energy_level":0}',
      },
      where: 'id = ?',
      whereArgs: ['signal-2026-07-08-0'],
    );
    final experiment = await lifeExperimentRepository.ensureSuggested(
      localUserId: 'local',
      weekStart: '2026-07-06',
      weekEnd: '2026-07-12',
      title: '留一点缓冲',
      hypothesis: '减少切换可能更省力',
      suggestedAction: '留五分钟空白',
      linkedSignalCardIds: const [],
      status: 'saved',
    );
    await lifeExperimentRepository.recordFeedback(
      experimentId: experiment.id,
      completionStatus: 'not_helpful',
      helpfulnessScore: 2,
      feedbackText: '当天还是太耗力',
      feedbackDate: now,
    );

    CandidatePlanningContext? received;
    repository = LocalCandidatePlanningRepository(
      localDatabase: localDatabase,
      localCaptureRepository: captureRepository,
      localLifeExperimentRepository: lifeExperimentRepository,
      localUserId: 'local',
      nowLoader: () => now,
      focusDomainIdsLoader: () async => const ['creative_expression'],
      externalEnergySummaryLoader: () async =>
          const AdvancedEnergyExternalSummary(
        lowRecoveryHint: 'recovery may be low',
      ),
    );

    final snapshot = await repository.refreshDailyIfSourceChanged(
      day: now,
      generate: (context) async {
        received = context;
        return [
          MicroActionCandidateDraft(
            title: '可暂停的两分钟小行动',
            reason: '结合当日状态与近期反馈',
            linkedSignalCardIds: context.eligibleSignalCardIds,
            focusDomainIds: context.focusDomainIds,
            recommendedIntensity:
                context.planningRecommendedIntensity.storageValue,
            energyAdaptationExplanation: '能量适配：当前保持可暂停。',
          ),
        ];
      },
    );

    expect(received, isNotNull);
    expect(received!.weeklyEnergySnapshot, isNotNull);
    expect(received!.planningCapacityBand, EnergyCapacityBand.veryLow);
    expect(received!.focusDomainIds, ['creative_expression']);
    expect(received!.feedback.effectiveEventIds, isNotEmpty);
    expect(received!.feedback.difficultCount, 1);
    expect(snapshot.candidates.single.energyCapacityBand,
        EnergyCapacityBand.veryLow);
    expect(snapshot.candidates.single.energyAdaptationExplanation,
        contains('当前保持可暂停'));
    expect(
        CandidatePlanningFingerprint.tryParse(
          snapshot.generation.sourceHash!,
        ),
        isNotNull);
  });

  test('小尝试候选实质消费有效、耗力与显式跳过反馈，而不只改变指纹', () async {
    await _insertSignals(
      captureRepository,
      localDatabase,
      date: '2026-07-08',
      count: 3,
    );
    final feedbackWriter = LocalPhase3PlusRepository(
      localDatabase,
      localUserId: 'local',
    );

    final neutral = await repository.refreshDailyWithGroundedSuggestions(
      day: now,
    );
    expect(neutral.candidates, hasLength(3));

    await feedbackWriter.insertMicroActionFeedback(
      MicroActionFeedbackModel(
        id: 'planning-feedback-helpful',
        microActionId: 'planning-feedback-subject',
        localDate: '2026-07-07',
        happened: 'completed',
        effect: 'helpful',
        difficulty: 'easy',
        createdAt: DateTime.utc(2026, 7, 8, 1),
      ),
    );
    final helpful = await repository.refreshDailyWithGroundedSuggestions(
      day: now,
    );
    expect(helpful.generation.sourceHash, isNot(neutral.generation.sourceHash));
    expect(helpful.candidates.first.title, contains('延续有效做法'));
    expect(helpful.candidates.first.reason, contains('有帮助'));
    expect(
      helpful.candidates.map((item) => '${item.title}|${item.reason}').toList(),
      isNot(equals(
        neutral.candidates
            .map((item) => '${item.title}|${item.reason}')
            .toList(),
      )),
    );

    await feedbackWriter.insertMicroActionFeedback(
      MicroActionFeedbackModel(
        id: 'planning-feedback-difficult',
        microActionId: 'planning-feedback-subject',
        localDate: '2026-07-07',
        happened: 'completed',
        effect: 'difficult',
        difficulty: 'hard',
        userNote: '当天还是太耗力',
        createdAt: DateTime.utc(2026, 7, 8, 2),
      ),
    );
    final difficult = await repository.refreshDailyWithGroundedSuggestions(
      day: now,
    );
    expect(
        difficult.generation.sourceHash, isNot(helpful.generation.sourceHash));
    expect(difficult.candidates.first.title, contains('再缩小一点'));
    expect(difficult.candidates.first.reason, contains('偏耗力'));
    expect(difficult.candidates.first.title, contains('1 分钟'));
    expect(
      difficult.candidates.every(
        (item) => item.recommendedIntensity == 'very_light',
      ),
      isTrue,
    );

    await feedbackWriter.insertMicroActionFeedback(
      MicroActionFeedbackModel(
        id: 'planning-feedback-skipped',
        microActionId: 'planning-feedback-subject',
        localDate: '2026-07-07',
        happened: 'not_completed',
        effect: 'unclear',
        difficulty: 'okay',
        nextAdjustment: 'skip',
        createdAt: DateTime.utc(2026, 7, 8, 3),
      ),
    );
    final skipped = await repository.refreshDailyWithGroundedSuggestions(
      day: now,
    );
    expect(
        skipped.generation.sourceHash, isNot(difficult.generation.sourceHash));
    expect(skipped.candidates.first.title, contains('换个方向'));
    expect(skipped.candidates.first.reason, contains('没有完成'));
    expect(skipped.candidates.first.title, contains('1 分钟'));
    expect(
      skipped.candidates.map((item) => '${item.title}|${item.reason}').toList(),
      isNot(equals(
        difficult.candidates
            .map((item) => '${item.title}|${item.reason}')
            .toList(),
      )),
    );
  });

  test('单纯 not_completed 只记录当天未完成，不推断困难或换方向', () async {
    await _insertSignals(
      captureRepository,
      localDatabase,
      date: '2026-07-08',
      count: 3,
    );
    final feedbackWriter = LocalPhase3PlusRepository(
      localDatabase,
      localUserId: 'local',
    );
    final neutral = await repository.refreshDailyWithGroundedSuggestions(
      day: now,
    );

    await feedbackWriter.insertMicroActionFeedback(
      MicroActionFeedbackModel(
        id: 'planning-feedback-not-completed-only',
        microActionId: 'planning-feedback-not-completed-subject',
        localDate: '2026-07-07',
        happened: 'not_completed',
        effect: 'unclear',
        difficulty: 'okay',
        createdAt: DateTime.utc(2026, 7, 7, 3),
      ),
    );
    final afterNotCompleted =
        await repository.refreshDailyWithGroundedSuggestions(day: now);

    expect(
      afterNotCompleted.generation.sourceHash,
      isNot(neutral.generation.sourceHash),
    );
    expect(
      afterNotCompleted.candidates.map((item) => item.title).toList(),
      neutral.candidates.map((item) => item.title).toList(),
    );
    expect(
      afterNotCompleted.candidates.map((item) => item.reason).toList(),
      neutral.candidates.map((item) => item.reason).toList(),
    );
    expect(
      afterNotCompleted.candidates.any(
        (item) => item.title.contains('缩小') || item.title.contains('换个方向'),
      ),
      isFalse,
    );
  });

  test('目标候选按反馈延续、缩小或换方向，并始终带缩小暂停边界', () async {
    await _insertSignals(
      captureRepository,
      localDatabase,
      date: '2026-07-08',
      count: 3,
    );
    final feedbackWriter = LocalPhase3PlusRepository(
      localDatabase,
      localUserId: 'local',
    );

    final neutral = await repository.refreshWeeklyWithGroundedSuggestions(
      day: now,
    );
    expect(neutral.candidates, hasLength(3));
    expect(
      neutral.candidates.every(
        (item) => item.suggestedAction.contains('缩小或暂停，不算失败'),
      ),
      isTrue,
    );

    await feedbackWriter.insertMicroActionFeedback(
      MicroActionFeedbackModel(
        id: 'weekly-planning-feedback-helpful',
        microActionId: 'weekly-planning-feedback-subject',
        localDate: '2026-06-20',
        happened: 'completed',
        effect: 'helpful',
        difficulty: 'easy',
        createdAt: DateTime.utc(2026, 7, 8, 1),
      ),
    );
    final helpful = await repository.refreshWeeklyWithGroundedSuggestions(
      day: now,
    );
    expect(helpful.generation.sourceHash, isNot(neutral.generation.sourceHash));
    expect(helpful.candidates.first.title, contains('延续有效方向'));
    expect(helpful.candidates.first.hypothesis, contains('有帮助'));
    expect(helpful.candidates.first.suggestedAction, contains('沿用最近有效'));

    await feedbackWriter.insertMicroActionFeedback(
      MicroActionFeedbackModel(
        id: 'weekly-planning-feedback-difficult',
        microActionId: 'weekly-planning-feedback-subject',
        localDate: '2026-06-20',
        happened: 'completed',
        effect: 'difficult',
        difficulty: 'hard',
        userNote: '做起来太耗力',
        createdAt: DateTime.utc(2026, 7, 8, 2),
      ),
    );
    final difficult = await repository.refreshWeeklyWithGroundedSuggestions(
      day: now,
    );
    expect(
        difficult.generation.sourceHash, isNot(helpful.generation.sourceHash));
    expect(difficult.candidates.first.title, contains('缩小后再观察'));
    expect(difficult.candidates.first.hypothesis, contains('偏耗力'));
    expect(difficult.candidates.first.suggestedAction, contains('先缩到最低要求'));
    expect(
      difficult.candidates.every(
        (item) => item.recommendedIntensity == 'very_light',
      ),
      isTrue,
    );

    await feedbackWriter.insertMicroActionFeedback(
      MicroActionFeedbackModel(
        id: 'weekly-planning-feedback-skipped',
        microActionId: 'weekly-planning-feedback-subject',
        localDate: '2026-06-20',
        happened: 'not_completed',
        effect: 'unclear',
        nextAdjustment: 'skip',
        createdAt: DateTime.utc(2026, 7, 8, 3),
      ),
    );
    final skipped = await repository.refreshWeeklyWithGroundedSuggestions(
      day: now,
    );
    expect(
        skipped.generation.sourceHash, isNot(difficult.generation.sourceHash));
    expect(skipped.candidates.first.title, contains('换一个方向观察'));
    expect(skipped.candidates.first.hypothesis, contains('没有完成'));
    expect(skipped.candidates.first.suggestedAction, contains('不要求完成原做法'));
    expect(
      skipped.candidates
          .map(
            (item) =>
                '${item.title}|${item.hypothesis}|${item.suggestedAction}',
          )
          .toList(),
      isNot(equals(
        difficult.candidates
            .map(
              (item) =>
                  '${item.title}|${item.hypothesis}|${item.suggestedAction}',
            )
            .toList(),
      )),
    );
  });

  test('Calendar 变化不影响候选指纹，Health 变化立即使当前组过期', () async {
    await repository.dispose();
    await _insertSignals(
      captureRepository,
      localDatabase,
      date: '2026-07-08',
      count: 3,
    );
    var summary = const AdvancedEnergyExternalSummary(
      scheduleDensityHint: 'calendar-a',
    );
    repository = LocalCandidatePlanningRepository(
      localDatabase: localDatabase,
      localCaptureRepository: captureRepository,
      localLifeExperimentRepository: lifeExperimentRepository,
      localUserId: 'local',
      nowLoader: () => now,
      focusDomainIdsLoader: () async => const ['growth_plan'],
      externalEnergySummaryLoader: () async => summary,
    );
    final first = await repository.refreshDailyWithGroundedSuggestions(
      day: now,
    );
    summary = const AdvancedEnergyExternalSummary(
      scheduleDensityHint: 'calendar-b',
    );
    final calendarChanged =
        await repository.refreshDailyWithGroundedSuggestions(day: now);
    expect(calendarChanged.generation.sourceHash, first.generation.sourceHash);
    expect(calendarChanged.candidates.first.id, first.candidates.first.id);

    AppDataMutationBus.publish(
      kind: AppDataMutationKind.externalEnergyHints,
      reason: 'calendar_energy_hints_changed',
    );
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect((await repository.dailyCandidateSnapshot(now)).generation.status,
        CandidateGenerationStatus.ready);

    final stale = repository
        .watchGenerationState(
          kind: CandidateKind.microAction,
          periodStart: '2026-07-08',
          periodEnd: '2026-07-08',
        )
        .firstWhere((state) => state.status == CandidateGenerationStatus.stale);
    summary = const AdvancedEnergyExternalSummary(
      lowRecoveryHint: 'recovery may be low',
    );
    AppDataMutationBus.publish(
      kind: AppDataMutationKind.externalEnergyHints,
      reason: 'health_energy_hints_changed',
    );
    expect(
      (await stale.timeout(const Duration(seconds: 2))).status,
      CandidateGenerationStatus.stale,
    );
    final refreshed =
        await repository.refreshDailyWithGroundedSuggestions(day: now);
    expect(refreshed.generation.sourceHash, isNot(first.generation.sourceHash));
  });

  test('关注重点调整候选依据排序，但不改变三信号门槛', () async {
    await repository.dispose();
    await _insertSignals(
      captureRepository,
      localDatabase,
      date: '2026-07-08',
      count: 3,
    );
    final db = await localDatabase.database;
    await db.update(
      'signal_cards',
      {'raw_text': '今天写作时出现了一个很清楚的创作灵感'},
      where: 'id = ?',
      whereArgs: ['signal-2026-07-08-0'],
    );
    repository = LocalCandidatePlanningRepository(
      localDatabase: localDatabase,
      localCaptureRepository: captureRepository,
      localLifeExperimentRepository: lifeExperimentRepository,
      localUserId: 'local',
      nowLoader: () => now,
      focusDomainIdsLoader: () async => const ['creative_expression'],
      externalEnergySummaryLoader: () async => null,
    );

    final snapshot = await repository.refreshDailyWithGroundedSuggestions(
      day: now,
    );

    expect(snapshot.gate.eligibleSignalCount, 3);
    expect(snapshot.candidates.first.linkedSignalCardIds,
        contains('signal-2026-07-08-0'));
    expect(snapshot.candidates.first.focusDomainIds, ['creative_expression']);
  });

  test('下周尝试混排最多三项，采纳的小尝试在下周一才进入 Today', () async {
    await _insertSignals(
      captureRepository,
      localDatabase,
      date: '2026-07-08',
      count: 3,
    );

    final planned = await repository.refreshNextWeekPlanWithGroundedSuggestions(
      day: now,
    );
    expect(
      planned.smallTryCandidates.length + planned.goalCandidates.length,
      lessThanOrEqualTo(3),
    );
    expect(planned.smallTryCandidates, isNotEmpty);
    expect(planned.targetWeekStart, '2026-07-13');
    expect(
      planned.smallTryCandidates.every(
        (candidate) => candidate.localDate == '2026-07-13',
      ),
      isTrue,
    );

    final adopted = await repository.adoptMicroActionCandidates(
      [planned.smallTryCandidates.first.id],
    );
    expect(adopted.single.status, 'planned');
    expect(
      await repository.listActiveMicroActionsForDate(DateTime(2026, 7, 12)),
      isEmpty,
    );
    final active = await repository.listActiveMicroActionsForDate(
      DateTime(2026, 7, 13),
    );
    expect(active.map((item) => item.action.id), contains(adopted.single.id));
  });

  test('深度分析是下周候选的可选参考，不会成为生成门槛', () async {
    await repository.dispose();
    await _insertSignals(
      captureRepository,
      localDatabase,
      date: '2026-07-08',
      count: 3,
    );
    repository = LocalCandidatePlanningRepository(
      localDatabase: localDatabase,
      localCaptureRepository: captureRepository,
      localLifeExperimentRepository: lifeExperimentRepository,
      localUserId: 'local',
      nowLoader: () => now,
      focusDomainIdsLoader: () async => const ['growth_plan'],
      externalEnergySummaryLoader: () async => null,
      deepPlanningReferenceLoader: (_) async => const DeepPlanningReference(
        id: 'weekly:2026-07-06',
        sourceHash: 'deep-source-hash',
        summary: '任务切换后需要留一点缓冲',
        observationPlanId: 'observation-plan-1',
      ),
    );

    final snapshot =
        await repository.refreshNextWeekPlanWithGroundedSuggestions(
      day: now,
    );

    expect(snapshot.smallTryCandidates, isNotEmpty);
    expect(snapshot.smallTryCandidates.first.reason, contains('深度分析'));
    expect(snapshot.goalCandidates, isNotEmpty);
    final reference = snapshot.goalCandidates.first
        .metadata['deep_planning_reference'] as Map<String, dynamic>?;
    expect(reference?['id'], 'weekly:2026-07-06');
    expect(reference?['observation_plan_id'], 'observation-plan-1');
  });

  test('普通 Weekly 快照不能被当作深度分析候选参考', () async {
    await _insertSignals(
      captureRepository,
      localDatabase,
      date: '2026-07-08',
      count: 3,
    );
    final db = await localDatabase.database;
    await db.insert('weekly_snapshots', {
      'week_start': '2026-07-06',
      'week_end': '2026-07-12',
      'status': 'ready',
      'key_insight': '这只是普通每周复盘。',
      'patterns_json': '[]',
      'frictions_json': '[]',
      'feedback_submitted': 0,
      'generated_at': DateTime.utc(2026, 7, 8).toIso8601String(),
      'source_hash': 'standard-weekly-only',
    });

    final snapshot =
        await repository.refreshNextWeekPlanWithGroundedSuggestions(
      day: now,
    );

    expect(snapshot.smallTryCandidates, isNotEmpty);
    expect(snapshot.smallTryCandidates.first.reason, isNot(contains('深度分析')));
    expect(snapshot.goalCandidates, isNotEmpty);
    expect(
      snapshot.goalCandidates.first.metadata
          .containsKey('deep_planning_reference'),
      isFalse,
    );
  });
}

Future<List<String>> _insertSignals(
  LocalCaptureRepository repository,
  LocalDatabase localDatabase, {
  required String date,
  required int count,
  int offset = 0,
}) async {
  final ids = <String>[];
  final db = await localDatabase.database;
  for (var index = 0; index < count; index++) {
    final number = index + offset;
    final id = 'signal-$date-$number';
    await repository.insertConfirmedSignalCard(
      signalCardId: id,
      content: '第 $number 条生活信号，记录一个真实场景',
      sourceType: 'text',
      userConfirmation: 'confirmed',
    );
    await db.update(
      'signal_cards',
      {
        'local_date': date,
        'created_at': '${date}T0${number % 9}:00:00Z',
        'updated_at': '${date}T0${number % 9}:00:00Z',
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    ids.add(id);
  }
  return ids;
}
