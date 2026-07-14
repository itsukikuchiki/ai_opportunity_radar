import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_opportunity_radar/core/local/local_capture_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/local/local_trace_link_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_weekly_snapshot_repository.dart';
import 'package:ai_opportunity_radar/core/models/today_models.dart';
import 'package:ai_opportunity_radar/core/models/weekly_models.dart';

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late LocalDatabase localDatabase;
  late LocalCaptureRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('capture_repo_test_');
    localDatabase = LocalDatabase(
      dbPathOverride: p.join(tempDir.path, 'local.db'),
      databaseFactoryOverride: databaseFactoryFfi,
    );
    await localDatabase.init();
    repository = LocalCaptureRepository(localDatabase);
  });

  tearDown(() async {
    await localDatabase.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('SignalCard processing state and analysis policy are split tables',
      () async {
    final signal = await repository.insertLocalDraftSignal(
      content: '今天会议很多，很累',
      language: 'zh-Hans',
    );
    final db = await localDatabase.database;

    final stateRows = await db.query(
      'signal_processing_state',
      where: 'signal_id = ?',
      whereArgs: [signal.signalCardId],
    );
    final policyRows = await db.query(
      'signal_analysis_policy',
      where: 'signal_id = ?',
      whereArgs: [signal.signalCardId],
    );

    expect(stateRows, hasLength(1));
    expect(stateRows.single['sync_status'], 'pending');
    expect(stateRows.single['is_local_draft'], 1);
    expect(policyRows, hasLength(1));
    expect(policyRows.single['privacy_level'], 'private');
    expect(policyRows.single['inaccurate'], 0);

    await repository.updateSignalCardConfirmation(
      signalCardId: signal.signalCardId!,
      userConfirmation: 'inaccurate',
      userCorrectionJson: const {'note': '不是有效记录'},
    );
    await repository.updateSignalCardInclusion(
      signalCardIds: [signal.signalCardId!],
      includedInSummary: true,
      includedInWeekly: true,
    );

    final updatedState = await db.query(
      'signal_processing_state',
      where: 'signal_id = ?',
      whereArgs: [signal.signalCardId],
      limit: 1,
    );
    final updatedPolicy = await db.query(
      'signal_analysis_policy',
      where: 'signal_id = ?',
      whereArgs: [signal.signalCardId],
      limit: 1,
    );

    expect(updatedState.single['daily_status'], 'included');
    expect(updatedState.single['weekly_status'], 'included');
    expect(updatedPolicy.single['inaccurate'], 1);
    expect(updatedPolicy.single['exclusion_reason'], 'inaccurate');
  });

  test('marking SignalCard inaccurate makes related trace links inactive',
      () async {
    final signal = await repository.insertLocalDraftSignal(
      content: '这条后面会被标记不准确',
      language: 'zh-Hans',
    );
    await LocalTraceLinkRepository(localDatabase).upsert(
      TraceLinkInput(
        sourceType: 'observation',
        sourceId: 'obs-test',
        targetType: 'signal_card',
        targetId: signal.signalCardId!,
        relationType: 'evidence_signal',
      ),
    );

    await repository.updateSignalCardConfirmation(
      signalCardId: signal.signalCardId!,
      userConfirmation: 'inaccurate',
      userCorrectionJson: const {},
    );

    final db = await localDatabase.database;
    final links = await db.query(
      'trace_links',
      where: 'target_type = ? AND target_id = ?',
      whereArgs: ['signal_card', signal.signalCardId],
    );

    expect(links, hasLength(1));
    expect(links.single['status'], 'inactive');
  });

  test('SignalCard confirmation changes dirty affected weekly cache', () async {
    final signal = await repository.insertLocalDraftSignal(
      content: '今天会议很多',
      language: 'zh-Hans',
    );
    final signalDate = DateTime.parse(signal.localDate!);
    final weekStart = signalDate.subtract(
      Duration(days: signalDate.weekday - DateTime.monday),
    );
    final weekStartKey = _dateKey(weekStart);
    final weeklyRepository = LocalWeeklySnapshotRepository(localDatabase);
    await weeklyRepository.upsert(
      weekly: WeeklyInsightModel(
        weekStart: weekStartKey,
        weekEnd: _dateKey(weekStart.add(const Duration(days: 6))),
        status: 'ready',
        keyInsight: '会议让能量下降。',
        patterns: const [],
        frictions: const [],
        bestAction: '实验调轻。',
        opportunitySnapshot: null,
        feedbackSubmitted: false,
      ),
      sourceHash: 'weekly-cache-before-confirmation-change',
    );
    final db = await localDatabase.database;
    await db.insert('experiment_candidates', {
      'id': 'cand_inaccurate_test',
      'local_user_id': 'local',
      'source_type': 'weekly_reflection',
      'source_id': weekStartKey,
      'source_week_start': weekStartKey,
      'source_week_end': _dateKey(weekStart.add(const Duration(days: 6))),
      'title': '不准确前候选',
      'hypothesis': '旧信号生成的假设',
      'suggested_action': '旧建议',
      'linked_signal_card_ids_json': '["${signal.signalCardId}"]',
      'linked_observation_ids_json': '[]',
      'status': 'generated',
      'confidence_level': 'medium',
      'metadata_json': '{}',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });

    await repository.updateSignalCardConfirmation(
      signalCardId: signal.signalCardId!,
      userConfirmation: 'inaccurate',
      userCorrectionJson: const {},
    );

    expect(await weeklyRepository.getSourceHash(weekStartKey), isNull);
    final rows = await db.query(
      'weekly_snapshots',
      where: 'week_start = ?',
      whereArgs: [weekStartKey],
      limit: 1,
    );
    final reflection = await db.query(
      'reflection_results',
      where: 'source_type = ? AND source_id = ?',
      whereArgs: ['weekly_snapshot', weekStartKey],
      limit: 1,
    );
    final candidate = await db.query(
      'experiment_candidates',
      where: 'id = ?',
      whereArgs: ['cand_inaccurate_test'],
      limit: 1,
    );
    expect(rows.single['dirty'], 1);
    expect(rows.single['is_stale'], 1);
    expect(rows.single['stale_reason'], 'signal_marked_inaccurate');
    expect(reflection.single['dirty'], 1);
    expect(reflection.single['is_stale'], 1);
    expect(reflection.single['stale_reason'], 'signal_marked_inaccurate');
    expect(candidate.single['dirty'], 1);
    expect(candidate.single['is_stale'], 1);
    expect(candidate.single['stale_reason'], 'signal_marked_inaccurate');
  });

  test('privacy exclusion propagates stale state to snapshots and candidates',
      () async {
    final signal = await repository.insertLocalDraftSignal(
      content: '这条之后会被设为不分析',
      language: 'zh-Hans',
    );
    final localDate = signal.localDate!;
    final parsed = DateTime.parse(localDate);
    final weekStart = parsed.subtract(
      Duration(days: parsed.weekday - DateTime.monday),
    );
    final weekStartKey = _dateKey(weekStart);
    final weeklyRepository = LocalWeeklySnapshotRepository(localDatabase);
    await weeklyRepository.upsert(
      weekly: WeeklyInsightModel(
        weekStart: weekStartKey,
        weekEnd: _dateKey(weekStart.add(const Duration(days: 6))),
        status: 'ready',
        keyInsight: '这条信号参与过周复盘。',
        patterns: const [],
        frictions: const [],
        bestAction: '先观察。',
        opportunitySnapshot: null,
        feedbackSubmitted: false,
      ),
      sourceHash: 'weekly-before-privacy-change',
    );
    final db = await localDatabase.database;
    await db.insert('experiment_candidates', {
      'id': 'cand_privacy_test',
      'local_user_id': 'local',
      'source_type': 'weekly_reflection',
      'source_id': weekStartKey,
      'source_week_start': weekStartKey,
      'source_week_end': _dateKey(weekStart.add(const Duration(days: 6))),
      'title': '隐私前候选',
      'hypothesis': '旧信号生成的假设',
      'suggested_action': '旧建议',
      'linked_signal_card_ids_json': '["${signal.signalCardId}"]',
      'linked_observation_ids_json': '[]',
      'status': 'generated',
      'confidence_level': 'medium',
      'metadata_json': '{}',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    await LocalTraceLinkRepository(localDatabase).upsert(
      TraceLinkInput(
        sourceType: 'weekly_snapshot',
        sourceId: weekStartKey,
        targetType: 'signal_card',
        targetId: signal.signalCardId!,
        relationType: 'uses_signal',
      ),
    );

    await repository.updateSignalCardPrivacy(
      signalCardId: signal.signalCardId!,
      privacyLevel: 'do_not_analyze',
    );

    expect(await weeklyRepository.getSourceHash(weekStartKey), isNull);
    final candidate = await db.query(
      'experiment_candidates',
      where: 'id = ?',
      whereArgs: ['cand_privacy_test'],
      limit: 1,
    );
    final links = await db.query(
      'trace_links',
      where: 'target_type = ? AND target_id = ?',
      whereArgs: ['signal_card', signal.signalCardId],
    );
    final policy = await db.query(
      'signal_analysis_policy',
      where: 'signal_id = ?',
      whereArgs: [signal.signalCardId],
      limit: 1,
    );

    expect(candidate.single['dirty'], 1);
    expect(candidate.single['is_stale'], 1);
    expect(candidate.single['stale_reason'], 'signal_privacy_excluded');
    expect(links.single['status'], 'inactive');
    expect(policy.single['do_not_analyze'], 1);
    expect(policy.single['exclusion_reason'], 'do_not_analyze');
  });

  test('deleting SignalCard writes tombstone and propagates stale state upward',
      () async {
    final signal = await repository.insertLocalDraftSignal(
      content: '这条之后会被删除',
      language: 'zh-Hans',
    );
    final localDate = signal.localDate!;
    final parsed = DateTime.parse(localDate);
    final weekStart = parsed.subtract(
      Duration(days: parsed.weekday - DateTime.monday),
    );
    final weekStartKey = _dateKey(weekStart);
    final weeklyRepository = LocalWeeklySnapshotRepository(localDatabase);
    await weeklyRepository.upsert(
      weekly: WeeklyInsightModel(
        weekStart: weekStartKey,
        weekEnd: _dateKey(weekStart.add(const Duration(days: 6))),
        status: 'ready',
        keyInsight: '删除前的周复盘。',
        patterns: const [],
        frictions: const [],
        bestAction: '先观察。',
        opportunitySnapshot: null,
        feedbackSubmitted: false,
      ),
      sourceHash: 'weekly-before-delete',
    );
    final db = await localDatabase.database;
    await db.insert('experiment_candidates', {
      'id': 'cand_delete_test',
      'local_user_id': 'local',
      'source_type': 'weekly_reflection',
      'source_id': weekStartKey,
      'source_week_start': weekStartKey,
      'source_week_end': _dateKey(weekStart.add(const Duration(days: 6))),
      'title': '删除前候选',
      'hypothesis': '旧信号生成的假设',
      'suggested_action': '旧建议',
      'linked_signal_card_ids_json': '["${signal.signalCardId}"]',
      'linked_observation_ids_json': '[]',
      'status': 'generated',
      'confidence_level': 'medium',
      'metadata_json': '{}',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });

    await repository.deleteSignalCard(
      signal.signalCardId!,
      reason: 'user_deleted',
    );

    expect(await weeklyRepository.getSourceHash(weekStartKey), isNull);
    final signals = await db.query(
      'signal_cards',
      where: 'id = ? OR signal_card_id = ?',
      whereArgs: [signal.signalCardId, signal.signalCardId],
    );
    final tombstones = await db.query(
      'signal_tombstones',
      where: 'signal_id = ?',
      whereArgs: [signal.signalCardId],
      limit: 1,
    );
    final candidate = await db.query(
      'experiment_candidates',
      where: 'id = ?',
      whereArgs: ['cand_delete_test'],
      limit: 1,
    );
    expect(signals, isEmpty);
    expect(tombstones, hasLength(1));
    expect(tombstones.single['status'], 'active');
    expect(tombstones.single['reason'], 'user_deleted');
    expect(tombstones.single['deleted_at'], isNotNull);
    expect(candidate.single['dirty'], 1);
    expect(candidate.single['is_stale'], 1);
    expect(candidate.single['stale_reason'], 'signal_deleted');
  });

  test('remote upsert respects tombstone until explicit restore', () async {
    final signal = await repository.insertLocalDraftSignal(
      content: '这条之后会被恢复',
      language: 'zh-Hans',
    );
    final localDate = signal.localDate!;
    final parsed = DateTime.parse(localDate);
    final weekStart = parsed.subtract(
      Duration(days: parsed.weekday - DateTime.monday),
    );
    final weekStartKey = _dateKey(weekStart);
    final weeklyRepository = LocalWeeklySnapshotRepository(localDatabase);

    await repository.deleteSignalCard(signal.signalCardId!);
    await repository.upsertRemoteSignalCards([
      RecentSignalModel(
        id: 'remote-after-delete',
        signalCardId: signal.signalCardId,
        clientId: signal.clientId,
        serverId: signal.signalCardId,
        content: '这条之后会被恢复',
        createdAt: DateTime.now(),
        localDate: localDate,
      ),
    ]);

    final db = await localDatabase.database;
    expect(await db.query('signal_cards'), isEmpty);

    await weeklyRepository.upsert(
      weekly: WeeklyInsightModel(
        weekStart: weekStartKey,
        weekEnd: _dateKey(weekStart.add(const Duration(days: 6))),
        status: 'ready',
        keyInsight: '恢复前的周复盘。',
        patterns: const [],
        frictions: const [],
        bestAction: '先观察。',
        opportunitySnapshot: null,
        feedbackSubmitted: false,
      ),
      sourceHash: 'weekly-before-restore',
    );
    await db.insert('experiment_candidates', {
      'id': 'cand_restore_test',
      'local_user_id': 'local',
      'source_type': 'weekly_reflection',
      'source_id': weekStartKey,
      'source_week_start': weekStartKey,
      'source_week_end': _dateKey(weekStart.add(const Duration(days: 6))),
      'title': '恢复前候选',
      'hypothesis': '旧信号生成的假设',
      'suggested_action': '旧建议',
      'linked_signal_card_ids_json': '["${signal.signalCardId}"]',
      'linked_observation_ids_json': '[]',
      'status': 'generated',
      'confidence_level': 'medium',
      'metadata_json': '{}',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });

    await repository.upsertRemoteSignalCards(
      [
        RecentSignalModel(
          id: 'remote-after-restore',
          signalCardId: signal.signalCardId,
          clientId: signal.clientId,
          serverId: signal.signalCardId,
          content: '这条之后会被恢复',
          createdAt: DateTime.now(),
          localDate: localDate,
        ),
      ],
      restoreTombstoned: true,
    );

    final restoredSignals = await db.query('signal_cards');
    final tombstones = await db.query(
      'signal_tombstones',
      where: 'signal_id = ?',
      whereArgs: [signal.signalCardId],
      limit: 1,
    );
    final snapshot = await db.query(
      'weekly_snapshots',
      where: 'week_start = ?',
      whereArgs: [weekStartKey],
      limit: 1,
    );
    final reflection = await db.query(
      'reflection_results',
      where: 'source_type = ? AND source_id = ?',
      whereArgs: ['weekly_snapshot', weekStartKey],
      limit: 1,
    );
    final candidate = await db.query(
      'experiment_candidates',
      where: 'id = ?',
      whereArgs: ['cand_restore_test'],
      limit: 1,
    );

    expect(restoredSignals, hasLength(1));
    expect(tombstones.single['status'], 'restored');
    expect(tombstones.single['restored_at'], isNotNull);
    expect(snapshot.single['dirty'], 1);
    expect(snapshot.single['is_stale'], 1);
    expect(snapshot.single['stale_reason'], 'signal_restored');
    expect(reflection.single['dirty'], 1);
    expect(reflection.single['is_stale'], 1);
    expect(reflection.single['stale_reason'], 'signal_restored');
    expect(candidate.single['dirty'], 1);
    expect(candidate.single['is_stale'], 1);
    expect(candidate.single['stale_reason'], 'signal_restored');
  });

  test('local draft keeps stable client identity when remote card arrives',
      () async {
    final draft = await repository.insertLocalDraftSignal(
      content: '断网时也不能丢',
      language: 'zh-Hans',
    );
    final db = await localDatabase.database;

    await repository.upsertRemoteSignalCards([
      RecentSignalModel(
        id: 'raw-retry',
        signalCardId: 'sig-retry',
        clientId: draft.clientId,
        serverId: 'sig-retry',
        content: '断网时也不能丢',
        createdAt: DateTime.now(),
        localDate: draft.localDate,
        acknowledgement: 'retry 后保存的 AI 回复',
      ),
    ]);
    await repository.markDraftSynced(
      draftId: draft.signalCardId!,
      remoteSignalCardId: 'sig-retry',
    );

    final signals = await repository.listSignalCards();
    final rows = await db.query('signal_sync_identity');

    expect(
        signals.where((signal) => signal.content == '断网时也不能丢'), hasLength(1));
    expect(signals.first.clientId, draft.clientId);
    expect(signals.first.serverId, 'sig-retry');
    expect(signals.first.isLocalDraft, false);
    expect(rows.single['client_id'], draft.clientId);
    expect(rows.single['server_id'], 'sig-retry');
    expect(rows.single['sync_status'], 'synced');
  });
}

String _dateKey(DateTime date) {
  final mm = date.month.toString().padLeft(2, '0');
  final dd = date.day.toString().padLeft(2, '0');
  return '${date.year}-$mm-$dd';
}
