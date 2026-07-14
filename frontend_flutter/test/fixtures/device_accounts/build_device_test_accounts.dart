import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_opportunity_radar/core/local/local_database.dart';

void main() {
  sqfliteFfiInit();

  final dir = Directory(
    p.join(Directory.current.path, 'test', 'fixtures', 'device_accounts'),
  );

  test('build P2.1-17 device test account fixtures', () async {
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final manifest = <Map<String, Object?>>[];
    manifest.add(await _createAccount(
      dir,
      fileName: 'fresh_user.db',
      accountId: 'fresh_user',
      description: 'New user with an empty current-schema database.',
      highlights: ['empty current schema', 'no fallback expected'],
      seed: _seedFreshUser,
    ));
    manifest.add(await _createAccount(
      dir,
      fileName: 'legacy_user.db',
      accountId: 'legacy_user',
      description: 'Legacy compatibility account covering old mirrors.',
      highlights: [
        'old captures',
        'old weekly snapshot',
        'embedded _life_experiment',
        'old DeepWeekly result',
        'old life experiment feedback',
        'snapshot AI mirror',
        'SignalCard mirror fields',
        'Journey data without trace_links',
      ],
      seed: _seedLegacyUser,
    ));
    manifest.add(await _createAccount(
      dir,
      fileName: 'heavy_user.db',
      accountId: 'heavy_user',
      description: 'Large local dataset for period query and UI load tests.',
      highlights: ['2000 signal_cards', 'weekly cache', 'monthly journey'],
      seed: _seedHeavyUser,
    ));
    manifest.add(await _createAccount(
      dir,
      fileName: 'offline_user.db',
      accountId: 'offline_user',
      description: 'Offline and retry identity scenarios.',
      highlights: [
        'local draft client_id',
        'sync_failed signal',
        'retry-safe identity'
      ],
      seed: _seedOfflineUser,
    ));
    manifest.add(await _createAccount(
      dir,
      fileName: 'experiment_user.db',
      accountId: 'experiment_user',
      description: 'Candidate to experiment to feedback to rollup chain.',
      highlights: [
        'experiment_candidate adopted',
        'life_experiment lifecycle',
        'life_experiment_feedback',
        'rollup consumed by Journey',
        'four feedback source types',
        'active trace_links',
      ],
      seed: _seedExperimentUser,
    ));
    manifest.add(await _createAccount(
      dir,
      fileName: 'privacy_user.db',
      accountId: 'privacy_user',
      description:
          'Privacy exclusion, inaccurate signal, deletion, and stale propagation.',
      highlights: [
        'do_not_analyze signal',
        'inaccurate signal',
        'privacy excluded signal',
        'signal tombstone',
        'inactive trace_links',
        'stale reflection and candidate',
      ],
      seed: _seedPrivacyUser,
    ));

    final manifestFile = File(p.join(dir.path, 'manifest.json'));
    manifestFile.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'generated_at': DateTime.now().toUtc().toIso8601String(),
        'stage': 'P2.1-17',
        'accounts': manifest,
      }),
    );

    stdout.writeln(
      'wrote ${p.relative(manifestFile.path, from: Directory.current.path)}',
    );
  }, timeout: const Timeout(Duration(minutes: 2)));
}

Future<Map<String, Object?>> _createAccount(
  Directory dir, {
  required String fileName,
  required String accountId,
  required String description,
  required List<String> highlights,
  required Future<void> Function(LocalDatabase localDatabase, String accountId)
      seed,
}) async {
  final file = File(p.join(dir.path, fileName));
  if (file.existsSync()) {
    file.deleteSync();
  }
  final localDatabase = LocalDatabase(
    dbPathOverride: file.path,
    databaseFactoryOverride: databaseFactoryFfi,
  );
  await localDatabase.init();
  await seed(localDatabase, accountId);
  final db = await localDatabase.database;
  await db.execute('PRAGMA user_version = 32');
  await localDatabase.close();
  stdout
      .writeln('wrote ${p.relative(file.path, from: Directory.current.path)}');
  return {
    'account_id': accountId,
    'db_file': fileName,
    'description': description,
    'highlights': highlights,
  };
}

Future<void> _seedFreshUser(LocalDatabase localDatabase, String userId) async {}

Future<void> _seedLegacyUser(LocalDatabase localDatabase, String userId) async {
  final db = await localDatabase.database;
  await db.insert('captures', {
    'id': 'cap_legacy_001',
    'content': '旧 captures raw 记录，用于兼容读取和 migration QA。',
    'created_at': '2026-06-01T09:00:00.000Z',
    'input_mode': 'quick_capture',
    'tag_hint': 'legacy',
    'ai_acknowledgement': '旧 AI acknowledgement',
    'ai_observation': '旧 snapshot AI mirror observation',
    'ai_try_next': '旧 snapshot AI mirror try next',
    'ai_emotion': 'tired',
    'ai_intensity': 'medium',
    'ai_scene_tags_json': jsonEncode(['work']),
    'ai_intent_tags_json': jsonEncode(['observe']),
    'ai_status': 'done',
    'updated_at': '2026-06-01T09:01:00.000Z',
  });
  await _insertSignalCard(
    db,
    id: 'sig_legacy_mirror_001',
    rawText: '旧 SignalCard mirror 字段承载 AI 结果。',
    localDate: '2026-06-02',
    isLegacy: 1,
  );
  await db.delete(
    'signal_processing_state',
    where: 'signal_id = ?',
    whereArgs: ['sig_legacy_mirror_001'],
  );
  await db.delete(
    'signal_analysis_policy',
    where: 'signal_id = ?',
    whereArgs: ['sig_legacy_mirror_001'],
  );
  await _insertWeeklySnapshot(
    db,
    weekStart: '2026-06-01',
    weekEnd: '2026-06-07',
    keyInsight: '旧 weekly snapshot 仍带 AI mirror 和内嵌实验。',
    opportunitySnapshot: {
      '_life_experiment': {
        'title': '旧内嵌实验',
        'hypothesis': '减少会议后恢复更快。',
        'suggested_action': '本周两次会议后散步 8 分钟。',
      },
      'legacy_ai_summary': '旧 snapshot AI mirror summary',
    },
  );
  await db.insert('reflection_results', {
    'id': 'refl_legacy_deep_weekly_001',
    'source_type': 'weekly_snapshot',
    'source_id': '2026-06-01',
    'reflection_type': 'deep_weekly',
    'ai_level': 'L3',
    'content_json': jsonEncode({
      'legacy_deep_weekly_result': true,
      'summary': '旧 DeepWeekly result。',
    }),
    'status': 'generated',
    'schema_version': 1,
    'prompt_version': 'deep_weekly_prompt_legacy',
    'model_version': 'deep_weekly_model_legacy',
    'pipeline_version': 'legacy_deep_weekly',
    'source_hash': 'legacy-deep-weekly-hash',
    'dirty': 0,
    'is_stale': 0,
    'generated_at': '2026-06-07T10:00:00.000Z',
    'created_at': '2026-06-07T10:00:00.000Z',
    'updated_at': '2026-06-07T10:00:00.000Z',
  });
  await _insertLifeExperiment(db, userId, id: 'exp_legacy_feedback_001');
  await _insertLifeExperimentFeedback(
    db,
    userId,
    id: 'lef_legacy_001',
    experimentId: 'exp_legacy_feedback_001',
    localDate: '2026-06-05',
  );
  await _insertJourneySnapshot(
    db,
    snapshotDate: '2026-06',
    sourceHash: 'legacy-no-trace',
    data: {
      'title': '缺 trace 的 Journey 旧数据',
      'fragments': ['旧 Journey fragment'],
      'trace_status': 'missing',
    },
  );
  await db.delete('trace_links');
}

Future<void> _seedHeavyUser(LocalDatabase localDatabase, String userId) async {
  final db = await localDatabase.database;
  final batch = db.batch();
  for (var i = 0; i < 2000; i += 1) {
    final day = (i % 28) + 1;
    final date = '2026-06-${day.toString().padLeft(2, '0')}';
    final id = 'sig_heavy_${i.toString().padLeft(4, '0')}';
    _batchSignal(batch, id, 'Heavy user signal $i', date);
  }
  await batch.commit(noResult: true);
  await _insertWeeklySnapshot(
    db,
    weekStart: '2026-06-15',
    weekEnd: '2026-06-21',
    keyInsight: 'heavy_user 周数据用于验证按 period 查询。',
  );
  await _insertJourneySnapshot(
    db,
    snapshotDate: '2026-06',
    sourceHash: 'heavy-2000',
    data: {'signal_count': 2000, 'query_scope': 'month'},
  );
}

Future<void> _seedOfflineUser(
    LocalDatabase localDatabase, String userId) async {
  final db = await localDatabase.database;
  await _insertSignalCard(
    db,
    id: 'sig_offline_draft_001',
    rawText: '离线创建的本地 draft，retry 必须保留同一个 client_id。',
    localDate: '2026-06-10',
    clientId: 'client_offline_retry_001',
    syncStatus: 'pending',
    isLocalDraft: 1,
    includedInSummary: 0,
    includedInWeekly: 0,
    includedInJourney: 0,
  );
  await _insertProcessingPolicy(
    db,
    'sig_offline_draft_001',
    syncStatus: 'pending',
    isLocalDraft: 1,
    confirmedByUser: 0,
    requiresConfirmation: 1,
  );
  await _insertSignalCard(
    db,
    id: 'sig_offline_failed_001',
    rawText: '同步失败记录，不应进入高层分析。',
    localDate: '2026-06-11',
    clientId: 'client_offline_failed_001',
    syncStatus: 'failed',
    syncFailed: 1,
    includedInSummary: 0,
    includedInWeekly: 0,
    includedInJourney: 0,
  );
  await _insertProcessingPolicy(
    db,
    'sig_offline_failed_001',
    syncStatus: 'failed',
    syncFailed: 1,
    lastError: 'fixture network timeout',
    confirmedByUser: 1,
  );
}

Future<void> _seedExperimentUser(
  LocalDatabase localDatabase,
  String userId,
) async {
  final db = await localDatabase.database;
  await _insertSignalCard(
    db,
    id: 'sig_exp_001',
    rawText: '会议后散步时恢复明显更快。',
    localDate: '2026-06-17',
  );
  await db.insert('observations', {
    'id': 'obs_exp_001',
    'local_user_id': userId,
    'observation_text': '会议后短恢复动作对能量有帮助。',
    'observation_type': 'hypothesis',
    'confidence': 'high',
    'status': 'confirmed',
    'source_period_start': '2026-06-15',
    'source_period_end': '2026-06-21',
    'created_by': 'l2_reason',
    'evidence_text': 'Signal + feedback repeated twice.',
    'suggested_pattern': 'meeting_recovery',
    'created_at': '2026-06-18T00:00:00.000Z',
    'updated_at': '2026-06-18T00:00:00.000Z',
    'confirmed_at': '2026-06-18T00:05:00.000Z',
  });
  await _insertWeeklySnapshot(
    db,
    weekStart: '2026-06-15',
    weekEnd: '2026-06-21',
    keyInsight: '能量低谷集中在会议后。',
  );
  await db.insert('experiment_candidates', {
    'id': 'cand_exp_001',
    'local_user_id': userId,
    'source_type': 'weekly_reflection',
    'source_id': '2026-06-15',
    'source_week_start': '2026-06-15',
    'source_week_end': '2026-06-21',
    'title': '会议后 8 分钟恢复',
    'hypothesis': '轻量恢复能降低会议后的能量下滑。',
    'suggested_action': '每次长会议后散步或拉伸 8 分钟。',
    'linked_signal_card_ids_json': jsonEncode(['sig_exp_001']),
    'linked_observation_ids_json': jsonEncode(['obs_exp_001']),
    'status': 'adopted',
    'confidence_level': 'high',
    'metadata_json': jsonEncode({'energy_budget': 'low'}),
    'adopted_experiment_id': 'exp_active_001',
    'dirty': 0,
    'is_stale': 0,
    'created_at': '2026-06-21T00:00:00.000Z',
    'updated_at': '2026-06-21T00:10:00.000Z',
  });
  await _insertLifeExperiment(db, userId, id: 'exp_active_001');
  for (final event in [
    ['life_event_start', 'started', 'pending', 'active', '2026-06-22'],
    ['life_event_pause', 'paused', 'active', 'paused', '2026-06-25'],
    ['life_event_resume', 'resumed', 'paused', 'active', '2026-06-26'],
  ]) {
    await db.insert('life_experiment_lifecycle_events', {
      'id': event[0],
      'experiment_id': 'exp_active_001',
      'local_user_id': userId,
      'event_type': event[1],
      'event_date': '${event[4]}T00:00:00.000Z',
      'local_date': event[4],
      'source_type': 'user_action',
      'source_id': 'exp_active_001',
      'status_from': event[2],
      'status_to': event[3],
      'payload_json': '{}',
      'created_at': '${event[4]}T00:00:00.000Z',
    });
  }
  await _insertLifeExperimentFeedback(
    db,
    userId,
    id: 'lef_active_001',
    experimentId: 'exp_active_001',
    localDate: '2026-06-24',
  );
  await db.insert('life_experiment_rollups', {
    'experiment_id': 'exp_active_001',
    'local_user_id': userId,
    'root_experiment_id': 'exp_active_001',
    'source_week_start': '2026-06-15',
    'source_week_end': '2026-06-21',
    'current_status': 'active',
    'title': '会议后 8 分钟恢复',
    'hypothesis': '轻量恢复能降低会议后的能量下滑。',
    'suggested_action': '每次长会议后散步或拉伸 8 分钟。',
    'total_feedback_count': 1,
    'tried_count': 1,
    'helpful_count': 1,
    'not_helpful_count': 0,
    'adjusted_count': 0,
    'skipped_count': 0,
    'active_week_count': 1,
    'first_started_at': '2026-06-22T00:00:00.000Z',
    'last_feedback_at': '2026-06-24T00:00:00.000Z',
    'last_event_at': '2026-06-26T00:00:00.000Z',
    'lineage_json': jsonEncode(['exp_active_001']),
    'dirty': 0,
    'is_stale': 0,
    'updated_at': '2026-06-26T00:00:00.000Z',
  });
  await _insertFeedbackSources(db, userId);
  await _insertTrace(db, userId,
      sourceType: 'journey_snapshot',
      sourceId: '2026-06',
      targetType: 'signal_card',
      targetId: 'sig_exp_001');
  await _insertTrace(db, userId,
      sourceType: 'journey_snapshot',
      sourceId: '2026-06',
      targetType: 'observation',
      targetId: 'obs_exp_001');
  await _insertTrace(db, userId,
      sourceType: 'journey_snapshot',
      sourceId: '2026-06',
      targetType: 'life_experiment_rollup',
      targetId: 'exp_active_001');
  await _insertTrace(db, userId,
      sourceType: 'journey_snapshot',
      sourceId: '2026-06',
      targetType: 'life_experiment_feedback',
      targetId: 'lef_active_001');
  await _insertJourneySnapshot(
    db,
    snapshotDate: '2026-06',
    sourceHash: 'experiment-chain',
    data: {
      'rollup_ids': ['exp_active_001'],
      'feedback_sources': 4
    },
  );
}

Future<void> _seedPrivacyUser(
    LocalDatabase localDatabase, String userId) async {
  final db = await localDatabase.database;
  await _insertSignalCard(
    db,
    id: 'sig_privacy_excluded_001',
    rawText: '隐私排除记录，不进入 Weekly / Journey。',
    localDate: '2026-06-13',
    privacyLevel: 'excluded',
    includedInSummary: 0,
    includedInWeekly: 0,
    includedInJourney: 0,
  );
  await _insertProcessingPolicy(
    db,
    'sig_privacy_excluded_001',
    privacyLevel: 'excluded',
    isExcluded: 1,
    exclusionReason: 'user_privacy',
  );
  await _insertSignalCard(
    db,
    id: 'sig_privacy_inaccurate_001',
    rawText: '用户标记 AI 判断不准确。',
    localDate: '2026-06-14',
    includedInSummary: 0,
    includedInWeekly: 0,
    includedInJourney: 0,
  );
  await _insertProcessingPolicy(
    db,
    'sig_privacy_inaccurate_001',
    inaccurate: 1,
    exclusionReason: 'inaccurate',
  );
  await _insertSignalCard(
    db,
    id: 'sig_privacy_do_not_analyze_001',
    rawText: '用户明确选择不参与分析。',
    localDate: '2026-06-15',
    includedInSummary: 0,
    includedInWeekly: 0,
    includedInJourney: 0,
  );
  await _insertProcessingPolicy(
    db,
    'sig_privacy_do_not_analyze_001',
    doNotAnalyze: 1,
    exclusionReason: 'do_not_analyze',
  );
  await db.insert('signal_tombstones', {
    'signal_id': 'sig_privacy_deleted_001',
    'signal_card_id': 'sig_privacy_deleted_001',
    'server_id': 'server_deleted_001',
    'client_id': 'client_deleted_001',
    'local_date': '2026-06-15',
    'reason': 'user_deleted',
    'status': 'active',
    'deleted_at': '2026-06-15T08:00:00.000Z',
    'updated_at': '2026-06-15T08:00:00.000Z',
  });
  await _insertTrace(
    db,
    userId,
    sourceType: 'journey_snapshot',
    sourceId: '2026-06',
    targetType: 'signal_card',
    targetId: 'sig_privacy_deleted_001',
    status: 'inactive',
  );
  await _insertWeeklySnapshot(
    db,
    weekStart: '2026-06-08',
    weekEnd: '2026-06-14',
    keyInsight: '包含隐私排除后应 stale。',
    dirty: 1,
    isStale: 1,
  );
  await db.insert('reflection_results', {
    'id': 'refl_privacy_stale_001',
    'source_type': 'weekly_snapshot',
    'source_id': '2026-06-08',
    'reflection_type': 'reflect',
    'ai_level': 'L3',
    'content_json': jsonEncode({'summary': '旧反思包含被排除数据。'}),
    'status': 'generated',
    'schema_version': 1,
    'prompt_version': 'weekly_reflect_prompt_v2',
    'model_version': 'model_reflect_v2',
    'pipeline_version': 'v4_p1_06',
    'source_hash': 'privacy-old-hash',
    'dirty': 0,
    'is_stale': 1,
    'stale_reason': 'privacy_excluded',
    'invalidated_at': '2026-06-15T08:00:00.000Z',
    'generated_at': '2026-06-14T00:00:00.000Z',
    'created_at': '2026-06-14T00:00:00.000Z',
    'updated_at': '2026-06-15T08:00:00.000Z',
  });
  await db.insert('experiment_candidates', {
    'id': 'cand_privacy_stale_001',
    'local_user_id': userId,
    'source_type': 'weekly_reflection',
    'source_id': '2026-06-08',
    'source_week_start': '2026-06-08',
    'source_week_end': '2026-06-14',
    'title': '应 stale 的候选实验',
    'hypothesis': '源数据已被排除。',
    'suggested_action': '不应继续展示为 active 建议。',
    'linked_signal_card_ids_json': jsonEncode(['sig_privacy_excluded_001']),
    'linked_observation_ids_json': '[]',
    'status': 'generated',
    'confidence_level': 'low',
    'metadata_json': '{}',
    'dirty': 0,
    'is_stale': 1,
    'stale_reason': 'privacy_excluded',
    'invalidated_at': '2026-06-15T08:00:00.000Z',
    'created_at': '2026-06-14T00:00:00.000Z',
    'updated_at': '2026-06-15T08:00:00.000Z',
  });
}

Future<void> _insertFeedbackSources(Database db, String userId) async {
  await db.insert('micro_actions', {
    'id': 'ma_exp_001',
    'title': '会后拉伸',
    'reason': '降低能量波动',
    'action_type': 'today_try',
    'difficulty': 'very_light',
    'planned_date': '2026-06-24',
    'status': 'done',
    'feedback_status': 'done',
    'created_at': '2026-06-24T00:00:00.000Z',
    'updated_at': '2026-06-24T00:10:00.000Z',
  });
  await db.insert('micro_action_feedback', {
    'id': 'maf_exp_001',
    'micro_action_id': 'ma_exp_001',
    'local_date': '2026-06-24',
    'happened': 'yes',
    'effect': 'helpful',
    'difficulty': 'easy',
    'user_note': '拉伸后没有继续下坠。',
    'created_at': '2026-06-24T00:20:00.000Z',
  });
  await db.insert('schedule_signals', {
    'id': 'sch_exp_001',
    'title': '长会议',
    'schedule_status': 'completed',
    'schedule_type': 'manual',
    'source_type': 'manual_schedule',
    'local_date': '2026-06-24',
    'anchor_date': '2026-06-24',
    'date_precision': 'day',
    'time_precision': 'none',
    'scene': 'work',
    'note': '会议后能量下降。',
    'expected_energy_load': 'high',
    'actual_energy_load': 'high',
    'pre_mood': 'neutral',
    'post_mood': 'tired',
    'friction': 'context_switching',
    'feedback_status': 'done',
    'linked_signal_card_ids_json': jsonEncode(['sig_exp_001']),
    'included_in_weekly': 1,
    'included_in_journey': 1,
    'privacy_level': 'private',
    'created_at': '2026-06-24T00:00:00.000Z',
    'updated_at': '2026-06-24T00:30:00.000Z',
  });
  await db.insert('goals', {
    'id': 'goal_exp_001',
    'title': '保持会议日恢复',
    'goal_type': 'personal',
    'period': 'weekly',
    'status': 'active',
    'privacy_level': 'private',
    'created_at': '2026-06-20T00:00:00.000Z',
    'updated_at': '2026-06-24T00:00:00.000Z',
  });
  await db.insert('goal_feedback', {
    'id': 'gf_exp_001',
    'goal_id': 'goal_exp_001',
    'feedback_date': '2026-06-24',
    'happened': 'yes',
    'effort_level': 'light',
    'effect': 'helpful',
    'comment': '目标反馈能被 FeedbackEvent 统一读取。',
    'created_at': '2026-06-24T00:40:00.000Z',
    'updated_at': '2026-06-24T00:40:00.000Z',
  });
}

Future<void> _insertWeeklySnapshot(
  Database db, {
  required String weekStart,
  required String weekEnd,
  required String keyInsight,
  Map<String, Object?> opportunitySnapshot = const {},
  int dirty = 0,
  int isStale = 0,
}) {
  return db.insert('weekly_snapshots', {
    'week_start': weekStart,
    'week_end': weekEnd,
    'status': 'ready',
    'key_insight': keyInsight,
    'patterns_json': jsonEncode(['energy_pattern']),
    'frictions_json': jsonEncode(['meeting_load']),
    'best_action': '保持轻量实验。',
    'opportunity_snapshot_json': jsonEncode(opportunitySnapshot),
    'chart_data_json': jsonEncode([
      {'date': weekStart, 'energy': 42},
      {'date': weekEnd, 'energy': 58},
    ]),
    'feedback_submitted': 0,
    'source_hash': 'fixture-$weekStart',
    'schema_version': 1,
    'pipeline_version': 'p2_1_17_fixture',
    'dirty': dirty,
    'is_stale': isStale,
    if (isStale == 1) 'stale_reason': 'fixture_stale',
    'generated_at': '${weekEnd}T00:00:00.000Z',
  });
}

Future<void> _insertJourneySnapshot(
  Database db, {
  required String snapshotDate,
  required String sourceHash,
  required Map<String, Object?> data,
}) {
  return db.insert('journey_snapshots', {
    'snapshot_date': snapshotDate,
    'patterns_json': jsonEncode(['energy_recovery']),
    'frictions_json': jsonEncode(['meeting_load']),
    'desires_json': jsonEncode(['more_buffer']),
    'experiments_json': jsonEncode(['exp_active_001']),
    'journey_data_json': jsonEncode(data),
    'source_hash': sourceHash,
    'schema_version': 1,
    'pipeline_version': 'p2_1_17_fixture',
    'dirty': 0,
    'is_stale': 0,
    'generated_at':
        '${snapshotDate.length == 7 ? '$snapshotDate-28' : snapshotDate}T00:00:00.000Z',
  });
}

Future<void> _insertLifeExperiment(
  Database db,
  String userId, {
  required String id,
}) {
  return db.insert('life_experiments', {
    'id': id,
    'local_user_id': userId,
    'source_week_start': '2026-06-15',
    'source_week_end': '2026-06-21',
    'title': id.contains('legacy') ? '旧实验反馈样本' : '会议后 8 分钟恢复',
    'hypothesis': '短恢复动作能改善会议后的能量变化。',
    'suggested_action': '会议后散步或拉伸 8 分钟。',
    'linked_signal_card_ids_json': jsonEncode(['sig_exp_001']),
    'status': 'active',
    'created_at': '2026-06-21T00:00:00.000Z',
    'updated_at': '2026-06-24T00:00:00.000Z',
    'experiment_type': 'life',
    'planned_frequency': '2x_week',
    'planned_duration_minutes': 8,
    'planned_total_days': 7,
    'difficulty': 'light',
  });
}

Future<void> _insertLifeExperimentFeedback(
  Database db,
  String userId, {
  required String id,
  required String experimentId,
  required String localDate,
}) {
  return db.insert('life_experiment_feedback', {
    'id': id,
    'experiment_id': experimentId,
    'feedback_date': '${localDate}T00:00:00.000Z',
    'local_user_id': userId,
    'local_date': localDate,
    'happened': 'yes',
    'completion_status': 'tried',
    'helpfulness_score': 4,
    'feedback_text': '做了以后恢复更快。',
    'condition_tags_json': jsonEncode(['after_meeting']),
    'duration_minutes': 8,
    'time_slot': 'afternoon',
    'effect': 'helpful',
    'comment': 'legacy/current feedback fixture',
    'created_at': '${localDate}T00:00:00.000Z',
    'updated_at': '${localDate}T00:00:00.000Z',
  });
}

Future<void> _insertSignalCard(
  Database db, {
  required String id,
  required String rawText,
  required String localDate,
  String? clientId,
  String privacyLevel = 'private',
  String syncStatus = 'synced',
  int isLocalDraft = 0,
  int syncFailed = 0,
  int includedInSummary = 1,
  int includedInWeekly = 1,
  int includedInJourney = 1,
  int isLegacy = 0,
}) async {
  await db.insert(
      'signal_cards',
      _signalRow(
        id: id,
        clientId: clientId ?? id,
        rawText: rawText,
        localDate: localDate,
        privacyLevel: privacyLevel,
        syncStatus: syncStatus,
        isLocalDraft: isLocalDraft,
        syncFailed: syncFailed,
        includedInSummary: includedInSummary,
        includedInWeekly: includedInWeekly,
        includedInJourney: includedInJourney,
        isLegacy: isLegacy,
      ));
  if (isLegacy == 0) {
    await _insertProcessingPolicy(
      db,
      id,
      privacyLevel: privacyLevel,
      syncStatus: syncStatus,
      isLocalDraft: isLocalDraft,
      syncFailed: syncFailed,
    );
  }
}

void _batchSignal(Batch batch, String id, String rawText, String localDate) {
  batch.insert(
    'signal_cards',
    _signalRow(id: id, rawText: rawText, localDate: localDate),
  );
  batch.insert('signal_processing_state', _processingRow(id, localDate));
  batch.insert('signal_analysis_policy', _policyRow(id));
}

Map<String, Object?> _signalRow({
  required String id,
  required String rawText,
  required String localDate,
  String? clientId,
  String privacyLevel = 'private',
  String syncStatus = 'synced',
  int isLocalDraft = 0,
  int syncFailed = 0,
  int includedInSummary = 1,
  int includedInWeekly = 1,
  int includedInJourney = 1,
  int isLegacy = 0,
}) {
  return {
    'id': id,
    'signal_card_id': id,
    'client_id': clientId ?? id,
    'server_id': syncStatus == 'synced' ? 'server_$id' : null,
    'source_type': 'text',
    'raw_text': rawText,
    'created_at': '${localDate}T00:00:00.000Z',
    'local_date': localDate,
    'timezone': 'Asia/Tokyo',
    'language': 'zh-Hans',
    'ai_reply': 'fixture reply',
    'observation': 'fixture observation',
    'try_next': 'fixture try next',
    'emotion': 'tired',
    'intensity': 'medium',
    'scene_tags_json': jsonEncode(['work']),
    'intent_tags_json': jsonEncode(['observe']),
    'user_confirmation': 'confirmed',
    'raw_payload_json': '{}',
    'user_correction_json': '{}',
    'included_in_summary': includedInSummary,
    'included_in_weekly': includedInWeekly,
    'included_in_journey': includedInJourney,
    'privacy_level': privacyLevel,
    'is_legacy': isLegacy,
    'migration_status': isLegacy == 1 ? 'local_legacy' : 'native',
    'is_local_draft': isLocalDraft,
    'sync_failed': syncFailed,
    'sync_status': syncStatus,
    'last_error': syncFailed == 1 ? 'fixture sync failed' : null,
    'updated_at': '${localDate}T00:00:00.000Z',
  };
}

Future<void> _insertProcessingPolicy(
  Database db,
  String signalId, {
  String localDate = '2026-06-01',
  String privacyLevel = 'private',
  String syncStatus = 'synced',
  int isLocalDraft = 0,
  int syncFailed = 0,
  int isExcluded = 0,
  int doNotAnalyze = 0,
  int requiresConfirmation = 0,
  int confirmedByUser = 1,
  int inaccurate = 0,
  String? exclusionReason,
  String? lastError,
}) async {
  await db.insert(
    'signal_processing_state',
    _processingRow(
      signalId,
      localDate,
      syncStatus: syncStatus,
      isLocalDraft: isLocalDraft,
      syncFailed: syncFailed,
      lastError: lastError,
    ),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
  await db.insert(
    'signal_analysis_policy',
    _policyRow(
      signalId,
      privacyLevel: privacyLevel,
      isExcluded: isExcluded,
      doNotAnalyze: doNotAnalyze,
      requiresConfirmation: requiresConfirmation,
      confirmedByUser: confirmedByUser,
      inaccurate: inaccurate,
      exclusionReason: exclusionReason,
    ),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

Map<String, Object?> _processingRow(
  String id,
  String localDate, {
  String syncStatus = 'synced',
  int isLocalDraft = 0,
  int syncFailed = 0,
  String? lastError,
}) {
  return {
    'signal_id': id,
    'sync_status': syncStatus,
    'assist_status': 'completed',
    'reason_status': 'completed',
    'daily_status':
        isLocalDraft == 1 || syncFailed == 1 ? 'excluded' : 'included',
    'weekly_status':
        isLocalDraft == 1 || syncFailed == 1 ? 'excluded' : 'included',
    'journey_status':
        isLocalDraft == 1 || syncFailed == 1 ? 'excluded' : 'included',
    'is_local_draft': isLocalDraft,
    'sync_failed': syncFailed,
    'last_error': lastError,
    'retry_count': syncFailed == 1 ? 1 : 0,
    'processing_version': 'p2_1_17_fixture',
    'last_processed_at': '${localDate}T00:00:00.000Z',
    'created_at': '${localDate}T00:00:00.000Z',
    'updated_at': '${localDate}T00:00:00.000Z',
  };
}

Map<String, Object?> _policyRow(
  String id, {
  String privacyLevel = 'private',
  int isExcluded = 0,
  int doNotAnalyze = 0,
  int requiresConfirmation = 0,
  int confirmedByUser = 1,
  int inaccurate = 0,
  String? exclusionReason,
}) {
  return {
    'signal_id': id,
    'privacy_level': privacyLevel,
    'is_sensitive': privacyLevel == 'sensitive' ? 1 : 0,
    'is_excluded': isExcluded,
    'do_not_analyze': doNotAnalyze,
    'requires_user_confirmation': requiresConfirmation,
    'confirmed_by_user': confirmedByUser,
    'inaccurate': inaccurate,
    'exclusion_reason': exclusionReason,
    'updated_at': '2026-06-01T00:00:00.000Z',
  };
}

Future<void> _insertTrace(
  Database db,
  String userId, {
  required String sourceType,
  required String sourceId,
  required String targetType,
  required String targetId,
  String status = 'active',
}) {
  return db.insert('trace_links', {
    'id': 'trace_${sourceType}_${sourceId}_${targetType}_$targetId',
    'local_user_id': userId,
    'source_type': sourceType,
    'source_id': sourceId,
    'target_type': targetType,
    'target_id': targetId,
    'relation_type': 'evidence',
    'weight': 1.0,
    'status': status,
    'metadata_json': '{}',
    'created_at': '2026-06-24T00:00:00.000Z',
    'updated_at': '2026-06-24T00:00:00.000Z',
  });
}
