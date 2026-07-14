import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_opportunity_radar/core/local/local_cache_invalidation_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_capture_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_daily_snapshot_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/local/local_journey_snapshot_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_life_experiment_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_reflection_result_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_weekly_snapshot_repository.dart';
import 'package:ai_opportunity_radar/core/models/memory_models.dart';
import 'package:ai_opportunity_radar/core/models/weekly_models.dart';

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late LocalDatabase localDatabase;
  late LocalCaptureRepository captureRepository;
  late LocalLifeExperimentRepository lifeExperimentRepository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cache_stale_test_');
    localDatabase = LocalDatabase(
      dbPathOverride: p.join(tempDir.path, 'local.db'),
      databaseFactoryOverride: databaseFactoryFfi,
    );
    await localDatabase.init();
    captureRepository = LocalCaptureRepository(localDatabase);
    lifeExperimentRepository = LocalLifeExperimentRepository(localDatabase);
  });

  tearDown(() async {
    await localDatabase.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('Signal 修改 propagates Daily / Weekly / Journey dirty', () async {
    const localDate = '2026-07-08';
    final weekStart = _weekStart(localDate);
    await _seedDailyWeeklyJourney(
      localDatabase,
      localDate: localDate,
      weekStart: weekStart,
      journeyDate: localDate,
    );

    await LocalCacheInvalidationRepository(localDatabase).markSignalChanged(
      localDate: localDate,
      reason: 'signal_content_changed',
      signalIds: const ['sig_changed'],
    );

    await _expectStale(
      localDatabase,
      table: 'daily_snapshots',
      where: 'date = ?',
      whereArgs: [localDate],
      reason: 'signal_content_changed',
    );
    await _expectStale(
      localDatabase,
      table: 'weekly_snapshots',
      where: 'week_start = ?',
      whereArgs: [weekStart],
      reason: 'signal_content_changed',
    );
    await _expectStale(
      localDatabase,
      table: 'journey_snapshots',
      where: 'snapshot_date = ?',
      whereArgs: [localDate],
      reason: 'signal_content_changed',
    );
  });

  test('Signal 删除 propagates snapshot / reflection / candidate stale',
      () async {
    final signal = await captureRepository.insertLocalDraftSignal(
      content: '这条之后会被删除',
      language: 'zh-Hans',
    );
    final localDate = signal.localDate!;
    final weekStart = _weekStart(localDate);
    await _seedDailyWeeklyJourney(
      localDatabase,
      localDate: localDate,
      weekStart: weekStart,
      journeyDate: localDate,
    );
    await _seedCandidate(
      localDatabase,
      id: 'cand_delete_stale',
      weekStart: weekStart,
      signalId: signal.signalCardId!,
    );

    await captureRepository.deleteSignalCard(signal.signalCardId!);

    await _expectStale(
      localDatabase,
      table: 'weekly_snapshots',
      where: 'week_start = ?',
      whereArgs: [weekStart],
      reason: 'signal_deleted',
    );
    await _expectReflectionStale(
      localDatabase,
      sourceType: 'weekly_snapshot',
      sourceId: weekStart,
      reason: 'signal_deleted',
    );
    await _expectStale(
      localDatabase,
      table: 'experiment_candidates',
      where: 'id = ?',
      whereArgs: ['cand_delete_stale'],
      reason: 'signal_deleted',
    );
  });

  test('inaccurate propagates upper stale', () async {
    final signal = await captureRepository.insertLocalDraftSignal(
      content: '这条之后标记不准确',
      language: 'zh-Hans',
    );
    final localDate = signal.localDate!;
    final weekStart = _weekStart(localDate);
    await _seedDailyWeeklyJourney(
      localDatabase,
      localDate: localDate,
      weekStart: weekStart,
      journeyDate: localDate,
    );

    await captureRepository.updateSignalCardConfirmation(
      signalCardId: signal.signalCardId!,
      userConfirmation: 'inaccurate',
      userCorrectionJson: const {},
    );

    await _expectStale(
      localDatabase,
      table: 'weekly_snapshots',
      where: 'week_start = ?',
      whereArgs: [weekStart],
      reason: 'signal_marked_inaccurate',
    );
    await _expectStale(
      localDatabase,
      table: 'journey_snapshots',
      where: 'snapshot_date = ?',
      whereArgs: [localDate],
      reason: 'signal_marked_inaccurate',
    );
  });

  test('privacy excluded propagates upper stale', () async {
    final signal = await captureRepository.insertLocalDraftSignal(
      content: '这条之后设为隐私排除',
      language: 'zh-Hans',
    );
    final localDate = signal.localDate!;
    final weekStart = _weekStart(localDate);
    await _seedDailyWeeklyJourney(
      localDatabase,
      localDate: localDate,
      weekStart: weekStart,
      journeyDate: localDate,
    );

    await captureRepository.updateSignalCardPrivacy(
      signalCardId: signal.signalCardId!,
      privacyLevel: 'excluded',
    );

    await _expectStale(
      localDatabase,
      table: 'weekly_snapshots',
      where: 'week_start = ?',
      whereArgs: [weekStart],
      reason: 'signal_privacy_excluded',
    );
    await _expectStale(
      localDatabase,
      table: 'journey_snapshots',
      where: 'snapshot_date = ?',
      whereArgs: [localDate],
      reason: 'signal_privacy_excluded',
    );
  });

  test('feedback 修改 propagates rollup / Weekly / Journey stale', () async {
    const weekStart = '2026-07-06';
    const localDate = '2026-07-08';
    final experiment = await lifeExperimentRepository.ensureSuggested(
      localUserId: 'local',
      weekStart: weekStart,
      weekEnd: '2026-07-12',
      title: '午后留白',
      hypothesis: '留白帮助恢复',
      suggestedAction: '午后留 10 分钟',
      linkedSignalCardIds: const [],
      status: 'saved',
    );
    final feedback = await lifeExperimentRepository.recordFeedback(
      experimentId: experiment.id,
      completionStatus: 'helpful',
      helpfulnessScore: 5,
      feedbackDate: DateTime.parse(localDate),
    );
    await _seedWeeklyJourneyOnly(
      localDatabase,
      weekStart: weekStart,
      journeyDate: localDate,
    );

    await lifeExperimentRepository.updateFeedback(
      feedbackId: feedback!.id,
      completionStatus: 'adjusted',
      helpfulnessScore: 3,
      feedbackText: '需要调轻一点',
      durationMinutes: 8,
    );

    await _expectStale(
      localDatabase,
      table: 'life_experiment_rollups',
      where: 'experiment_id = ?',
      whereArgs: [experiment.id],
      reason: 'life_experiment_feedback_changed',
    );
    await _expectStale(
      localDatabase,
      table: 'weekly_snapshots',
      where: 'week_start = ?',
      whereArgs: [weekStart],
      reason: 'life_experiment_feedback_changed',
    );
    await _expectStale(
      localDatabase,
      table: 'journey_snapshots',
      where: 'snapshot_date = ?',
      whereArgs: [localDate],
      reason: 'life_experiment_feedback_changed',
    );
  });

  test('prompt version 变化 marks reflection stale', () async {
    final repository = LocalReflectionResultRepository(localDatabase);
    await repository.saveCurrent(
      sourceType: 'weekly_snapshot',
      sourceId: '2026-07-06',
      reflectionType: 'reflect',
      aiLevel: 'L3',
      content: const {'key_insight': '旧 prompt'},
      promptVersion: 'prompt_v1',
      modelVersion: 'model_v1',
    );

    final affected = await repository.markStaleForPromptModelChange(
      sourceType: 'weekly_snapshot',
      sourceId: '2026-07-06',
      reflectionType: 'reflect',
      promptVersion: 'prompt_v2',
      modelVersion: 'model_v1',
    );

    expect(affected, 1);
    await _expectReflectionStale(
      localDatabase,
      sourceType: 'weekly_snapshot',
      sourceId: '2026-07-06',
      reason: 'prompt_model_version_changed',
    );
  });

  test('model version 变化 marks reflection stale', () async {
    final repository = LocalReflectionResultRepository(localDatabase);
    await repository.saveCurrent(
      sourceType: 'journey_snapshot',
      sourceId: '2026-07-08',
      reflectionType: 'reflect',
      aiLevel: 'L3',
      content: const {'patterns': []},
      promptVersion: 'prompt_v1',
      modelVersion: 'model_v1',
    );

    final affected = await repository.markStaleForPromptModelChange(
      sourceType: 'journey_snapshot',
      sourceId: '2026-07-08',
      reflectionType: 'reflect',
      promptVersion: 'prompt_v1',
      modelVersion: 'model_v2',
    );

    expect(affected, 1);
    await _expectReflectionStale(
      localDatabase,
      sourceType: 'journey_snapshot',
      sourceId: '2026-07-08',
      reason: 'prompt_model_version_changed',
    );
  });

  test('schema version 变化 marks corresponding snapshot / reflection stale',
      () async {
    const localDate = '2026-07-08';
    await _seedDailyWeeklyJourney(
      localDatabase,
      localDate: localDate,
      weekStart: _weekStart(localDate),
      journeyDate: localDate,
    );
    final db = await localDatabase.database;
    await db.update(
      'daily_snapshots',
      {'schema_version': 0},
      where: 'date = ?',
      whereArgs: [localDate],
    );

    final affected = await LocalCacheInvalidationRepository(localDatabase)
        .markSnapshotsStaleForSchemaVersionChange(
      table: 'daily_snapshots',
      currentSchemaVersion: 1,
    );

    expect(affected, 1);
    await _expectStale(
      localDatabase,
      table: 'daily_snapshots',
      where: 'date = ?',
      whereArgs: [localDate],
      reason: 'schema_version_changed',
    );
    await _expectReflectionStale(
      localDatabase,
      sourceType: 'daily_snapshot',
      sourceId: localDate,
      reason: 'schema_version_changed',
    );
  });
}

Future<void> _seedDailyWeeklyJourney(
  LocalDatabase localDatabase, {
  required String localDate,
  required String weekStart,
  required String journeyDate,
}) async {
  await LocalDailySnapshotRepository(localDatabase).upsert(
    date: DateTime.parse(localDate),
    entryCount: 1,
    observationText: '今天有一条变化。',
    suggestionText: '先轻一点。',
    sourceHash: 'daily-$localDate',
  );
  await _seedWeeklyJourneyOnly(
    localDatabase,
    weekStart: weekStart,
    journeyDate: journeyDate,
  );
}

Future<void> _seedWeeklyJourneyOnly(
  LocalDatabase localDatabase, {
  required String weekStart,
  required String journeyDate,
}) async {
  await LocalWeeklySnapshotRepository(localDatabase).upsert(
    weekly: WeeklyInsightModel(
      weekStart: weekStart,
      weekEnd: _dateKey(DateTime.parse(weekStart).add(const Duration(days: 6))),
      status: 'ready',
      keyInsight: '本周先轻一点。',
      patterns: const [],
      frictions: const [],
      bestAction: '降低实验强度。',
      opportunitySnapshot: null,
      feedbackSubmitted: false,
    ),
    sourceHash: 'weekly-$weekStart',
  );
  await LocalJourneySnapshotRepository(localDatabase).upsert(
    snapshotDate: journeyDate,
    summary: MemorySummaryModel(
      patterns: const [
        JourneySignalItemModel(
          name: '一个模式',
          summary: 'Journey cache',
          signalLevel: 'weak_signal',
        ),
      ],
      frictions: const [],
      desires: const [],
      experiments: const [],
    ),
    sourceHash: 'journey-$journeyDate',
  );
}

Future<void> _seedCandidate(
  LocalDatabase localDatabase, {
  required String id,
  required String weekStart,
  required String signalId,
}) async {
  final db = await localDatabase.database;
  await db.insert('experiment_candidates', {
    'id': id,
    'local_user_id': 'local',
    'source_type': 'weekly_reflection',
    'source_id': weekStart,
    'source_week_start': weekStart,
    'source_week_end': _dateKey(
      DateTime.parse(weekStart).add(const Duration(days: 6)),
    ),
    'title': '候选实验',
    'hypothesis': '旧信号生成的假设',
    'suggested_action': '旧建议',
    'linked_signal_card_ids_json': '["$signalId"]',
    'linked_observation_ids_json': '[]',
    'status': 'generated',
    'confidence_level': 'medium',
    'metadata_json': '{}',
    'dirty': 0,
    'is_stale': 0,
    'created_at': DateTime.now().toUtc().toIso8601String(),
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  });
}

Future<void> _expectStale(
  LocalDatabase localDatabase, {
  required String table,
  required String where,
  required List<Object?> whereArgs,
  required String reason,
}) async {
  final db = await localDatabase.database;
  final rows = await db.query(
    table,
    where: where,
    whereArgs: whereArgs,
    limit: 1,
  );
  expect(rows, hasLength(1), reason: '$table row should exist');
  expect(rows.single['dirty'], 1, reason: '$table dirty');
  expect(rows.single['is_stale'], 1, reason: '$table is_stale');
  expect(rows.single['stale_reason'], reason, reason: '$table stale_reason');
  expect(rows.single['invalidated_at'], isNotNull);
}

Future<void> _expectReflectionStale(
  LocalDatabase localDatabase, {
  required String sourceType,
  required String sourceId,
  required String reason,
}) async {
  final db = await localDatabase.database;
  final rows = await db.query(
    'reflection_results',
    where: 'source_type = ? AND source_id = ? AND status IN (?, ?)',
    whereArgs: [sourceType, sourceId, 'generated', 'confirmed'],
    limit: 1,
  );
  expect(rows, hasLength(1), reason: '$sourceType reflection should exist');
  expect(rows.single['dirty'], 1);
  expect(rows.single['is_stale'], 1);
  expect(rows.single['stale_reason'], reason);
  expect(rows.single['invalidated_at'], isNotNull);
}

String _weekStart(String localDate) {
  final parsed = DateTime.parse(localDate);
  return _dateKey(
    parsed.subtract(Duration(days: parsed.weekday - DateTime.monday)),
  );
}

String _dateKey(DateTime date) {
  final mm = date.month.toString().padLeft(2, '0');
  final dd = date.day.toString().padLeft(2, '0');
  return '${date.year}-$mm-$dd';
}
