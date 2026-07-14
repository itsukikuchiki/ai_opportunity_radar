import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_opportunity_radar/core/local/local_candidate_planning_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_capture_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/local/local_life_experiment_repository.dart';
import 'package:ai_opportunity_radar/core/models/advanced_energy_boundary_models.dart';
import 'package:ai_opportunity_radar/core/models/candidate_models.dart';
import 'package:ai_opportunity_radar/core/models/energy_budget_models.dart';
import 'package:ai_opportunity_radar/core/state/app_data_refresh_coordinator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

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
    lifeExperimentRepository = LocalLifeExperimentRepository(localDatabase);
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

    final secondRead = await repository.refreshDailyWithGroundedSuggestions(
      day: now,
    );
    expect(
      secondRead.candidates.map((item) => item.id),
      ready.candidates.map((item) => item.id),
    );
  });

  test('adopts multiple actions and last valid same-day feedback wins X/7',
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
    expect(
        adopted.every((item) => item.progressEndDate == '2026-07-14'), isTrue);

    final afterAdoption = await repository.dailyCandidateSnapshot(now);
    expect(afterAdoption.generation.status, CandidateGenerationStatus.ready);
    expect(
        afterAdoption.candidates.where((item) => item.isAdopted), hasLength(2));

    final db = await localDatabase.database;
    final actionId = adopted.first.id;
    await db.insert('micro_action_feedback', {
      'id': 'feedback-first',
      'micro_action_id': actionId,
      'local_date': '2026-07-08',
      'happened': 'yes',
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
      'happened': 'not_suitable_today',
      'effect': 'unclear',
      'difficulty': 'not_suitable_today',
      'next_adjustment': 'try_another_day',
      'created_at': '2026-07-08T02:00:00Z',
      'updated_at': '2026-07-08T02:00:00Z',
      'is_valid': 1,
    });
    await db.insert('micro_action_feedback', {
      'id': 'feedback-day-two',
      'micro_action_id': actionId,
      'local_date': '2026-07-09',
      'happened': 'yes',
      'effect': 'helpful',
      'difficulty': 'okay',
      'next_adjustment': 'continue',
      'created_at': '2026-07-09T01:00:00Z',
      'updated_at': '2026-07-09T01:00:00Z',
      'is_valid': 1,
    });

    final progress = await repository.microActionProgress(actionId);
    expect(progress.cells, hasLength(7));
    expect(progress.cells.first.state, ProgressCellState.notCompleted);
    expect(progress.cells.first.latestEventId, 'feedback-last');
    expect(progress.cells[1].state, ProgressCellState.completed);
    expect(progress.completedDays, 1);

    final active = await repository.listActiveMicroActionsForDate(now);
    expect(active, hasLength(2));
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

    final adopted = await repository.adoptExperimentCandidates(
      snapshot.candidates.take(2).map((item) => item.id),
    );
    expect(adopted, hasLength(2));
    expect(adopted.map((item) => item.id).toSet(), hasLength(2));
    expect(adopted.every((item) => item.originCandidateId != null), isTrue);
    expect(adopted.every((item) => item.progressStartDate == '2026-07-13'),
        isTrue);
    expect(
        adopted.every((item) => item.progressEndDate == '2026-07-19'), isTrue);

    final afterAdoption = await repository.weeklyCandidateSnapshot(now);
    expect(afterAdoption.generation.status, CandidateGenerationStatus.ready);
    expect(
        afterAdoption.candidates.where((item) => item.isAdopted), hasLength(2));

    final idempotent = await repository.adoptExperimentCandidates(
      [snapshot.candidates.first.id],
    );
    expect(idempotent.single.id, adopted.first.id);
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

  test('MicroAction and LifeExperiment keep independent seven-day progress',
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
