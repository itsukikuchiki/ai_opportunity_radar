import 'dart:convert';
import 'dart:io';

import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('build P2.1-11 DB migration fixtures', () async {
    final dir = Directory(p.join(
      Directory.current.path,
      'test',
      'fixtures',
      'db_migrations',
    ));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    await _createFixture(
      dir,
      name: 'fresh_user_v30.db',
      userVersion: 30,
      seed: (_) async {},
    );
    await _createFixture(
      dir,
      name: 'legacy_v27_captures.db',
      userVersion: 27,
      seed: _seedLegacyCaptures,
    );
    await _createFixture(
      dir,
      name: 'legacy_v28_snapshot_ai_fields.db',
      userVersion: 28,
      seed: _seedLegacySnapshotAiFields,
    );
    await _createFixture(
      dir,
      name: 'legacy_v29_life_experiment_embedded.db',
      userVersion: 29,
      seed: _seedEmbeddedLifeExperiment,
    );
    await _createFixture(
      dir,
      name: 'legacy_signal_mirror_fields.db',
      userVersion: 29,
      seed: _seedLegacySignalMirrorFields,
    );
    await _createFixture(
      dir,
      name: 'legacy_no_trace_data.db',
      userVersion: 30,
      seed: _seedLegacyNoTraceData,
    );
    await _createFixture(
      dir,
      name: 'large_user_2000_signals.db',
      userVersion: 32,
      seed: _seedLargeUser,
    );
    await _createFixture(
      dir,
      name: 'deleted_signal_with_trace.db',
      userVersion: 32,
      seed: _seedDeletedSignalWithTrace,
    );
    await _createFixture(
      dir,
      name: 'old_prompt_version.db',
      userVersion: 32,
      seed: _seedOldPromptVersion,
    );
  });
}

Future<void> _createFixture(
  Directory dir, {
  required String name,
  required int userVersion,
  required Future<void> Function(LocalDatabase localDatabase) seed,
}) async {
  final file = File(p.join(dir.path, name));
  if (file.existsSync()) {
    file.deleteSync();
  }
  final localDatabase = LocalDatabase(
    dbPathOverride: file.path,
    databaseFactoryOverride: databaseFactoryFfi,
  );
  await localDatabase.init();
  await seed(localDatabase);
  final db = await localDatabase.database;
  await db.execute('PRAGMA user_version = $userVersion');
  await localDatabase.close();
  stdout
      .writeln('wrote ${p.relative(file.path, from: Directory.current.path)}');
}

Future<void> _seedLegacyCaptures(LocalDatabase localDatabase) async {
  final db = await localDatabase.database;
  await db.insert('captures', {
    'id': 'cap_legacy_001',
    'content': '旧 captures raw 记录，用于兼容读取和 mirror migration。',
    'created_at': '2026-07-01T09:00:00.000Z',
    'input_mode': 'quick_capture',
    'tag_hint': 'legacy',
    'ai_acknowledgement': '旧 AI 回复',
    'ai_observation': '旧 observation mirror',
    'ai_try_next': '旧 try next mirror',
    'ai_emotion': 'tired',
    'ai_intensity': 'medium',
    'ai_scene_tags_json': jsonEncode(['work']),
    'ai_intent_tags_json': jsonEncode(['observe']),
    'ai_status': 'done',
    'updated_at': '2026-07-01T09:01:00.000Z',
  });
}

Future<void> _seedLegacySnapshotAiFields(LocalDatabase localDatabase) async {
  final db = await localDatabase.database;
  await _insertWeeklySnapshot(
    db,
    weekStart: '2026-07-06',
    weekEnd: '2026-07-12',
    keyInsight: '旧 weekly snapshot 仍把 AI 文本存在 mirror 字段。',
    patternsJson: jsonEncode([
      {'name': '旧模式', 'summary': '旧 snapshot AI field'}
    ]),
    frictionsJson: jsonEncode([
      {'name': '旧摩擦', 'summary': '没有 reflection_results'}
    ]),
    bestAction: '旧 best action',
    opportunitySnapshotJson: jsonEncode({'energy_budget': 'low'}),
  );
}

Future<void> _seedEmbeddedLifeExperiment(LocalDatabase localDatabase) async {
  final db = await localDatabase.database;
  final opportunity = {
    'energy_budget': 'low',
    '_life_experiment': {
      'title': '旧内嵌实验',
      'hypothesis': '少安排会更容易恢复',
      'suggested_action': '午后留 10 分钟',
      'status': 'suggested',
      'linked_signal_card_ids': ['sig_embedded_001'],
    },
  };
  await _insertWeeklySnapshot(
    db,
    weekStart: '2026-07-06',
    weekEnd: '2026-07-12',
    keyInsight: '旧 weekly 内嵌 _life_experiment。',
    opportunitySnapshotJson: jsonEncode(opportunity),
  );
}

Future<void> _seedLegacySignalMirrorFields(LocalDatabase localDatabase) async {
  final db = await localDatabase.database;
  await _insertSignalCard(
    db,
    id: 'sig_legacy_mirror_001',
    rawText: '旧 SignalCard 只有 mirror fields，没有 split policy/state。',
    localDate: '2026-07-08',
    includedInSummary: 1,
    includedInWeekly: 1,
    includedInJourney: 1,
    privacyLevel: 'private',
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
}

Future<void> _seedLegacyNoTraceData(LocalDatabase localDatabase) async {
  final db = await localDatabase.database;
  await _insertSignalCard(
    db,
    id: 'sig_no_trace_001',
    rawText: '旧数据没有 trace_links。',
    localDate: '2026-07-08',
  );
  await db.insert('life_experiments', {
    'id': 'exp_no_trace_001',
    'local_user_id': 'local',
    'source_week_start': '2026-07-06',
    'source_week_end': '2026-07-12',
    'title': '无 trace 旧实验',
    'hypothesis': '旧实验缺 trace',
    'suggested_action': '继续轻量尝试',
    'linked_signal_card_ids_json': jsonEncode(['sig_no_trace_001']),
    'status': 'saved',
    'created_at': '2026-07-08T00:00:00.000Z',
    'updated_at': '2026-07-08T00:00:00.000Z',
  });
  await db.delete('trace_links');
}

Future<void> _seedLargeUser(LocalDatabase localDatabase) async {
  final db = await localDatabase.database;
  final batch = db.batch();
  for (var i = 0; i < 2000; i += 1) {
    final day = (i % 28) + 1;
    final id = 'sig_large_${i.toString().padLeft(4, '0')}';
    final date = '2026-07-${day.toString().padLeft(2, '0')}';
    batch.insert(
        'signal_cards', _signalCardRow(id, 'Large fixture signal $i', date));
    batch.insert('signal_processing_state', {
      'signal_id': id,
      'sync_status': 'synced',
      'daily_status': 'included',
      'weekly_status': 'included',
      'journey_status': 'included',
      'is_local_draft': 0,
      'sync_failed': 0,
      'retry_count': 0,
      'processing_version': 'fixture',
      'created_at': '${date}T00:00:00.000Z',
      'updated_at': '${date}T00:00:00.000Z',
    });
    batch.insert('signal_analysis_policy', {
      'signal_id': id,
      'privacy_level': 'private',
      'is_sensitive': 0,
      'is_excluded': 0,
      'do_not_analyze': 0,
      'requires_user_confirmation': 0,
      'confirmed_by_user': 1,
      'inaccurate': 0,
      'updated_at': '${date}T00:00:00.000Z',
    });
  }
  await batch.commit(noResult: true);
}

Future<void> _seedDeletedSignalWithTrace(LocalDatabase localDatabase) async {
  final db = await localDatabase.database;
  await _insertSignalCard(
    db,
    id: 'sig_deleted_trace_001',
    rawText: '删除前曾经作为 evidence。',
    localDate: '2026-07-08',
  );
  await db.insert('trace_links', {
    'id': 'trace_deleted_signal_001',
    'local_user_id': 'local',
    'source_type': 'journey_snapshot',
    'source_id': '2026-07-08',
    'target_type': 'signal_card',
    'target_id': 'sig_deleted_trace_001',
    'relation_type': 'uses_trace',
    'weight': 1.0,
    'status': 'inactive',
    'metadata_json': jsonEncode({'local_date': '2026-07-08'}),
    'created_at': '2026-07-08T00:00:00.000Z',
    'updated_at': '2026-07-08T01:00:00.000Z',
  });
  await db.insert('signal_tombstones', {
    'signal_id': 'sig_deleted_trace_001',
    'signal_card_id': 'sig_deleted_trace_001',
    'server_id': 'sig_deleted_trace_001',
    'client_id': 'sig_deleted_trace_001',
    'local_date': '2026-07-08',
    'reason': 'user_deleted',
    'status': 'active',
    'deleted_at': '2026-07-08T01:00:00.000Z',
    'updated_at': '2026-07-08T01:00:00.000Z',
  });
  await db.delete(
    'signal_cards',
    where: 'id = ?',
    whereArgs: ['sig_deleted_trace_001'],
  );
}

Future<void> _seedOldPromptVersion(LocalDatabase localDatabase) async {
  final db = await localDatabase.database;
  await _insertWeeklySnapshot(
    db,
    weekStart: '2026-07-06',
    weekEnd: '2026-07-12',
    keyInsight: '旧 prompt 生成的周复盘。',
  );
  await db.insert('reflection_results', {
    'id': 'refl_old_prompt_weekly_001',
    'source_type': 'weekly_snapshot',
    'source_id': '2026-07-06',
    'reflection_type': 'reflect',
    'ai_level': 'L3',
    'content_json': jsonEncode({'key_insight': '旧 prompt 生成的周复盘。'}),
    'status': 'generated',
    'schema_version': 1,
    'prompt_version': 'weekly_reflect_prompt_v1',
    'model_version': 'model_reflect_v1',
    'pipeline_version': 'v4_p1_06',
    'source_hash': 'old-prompt-hash',
    'dirty': 0,
    'is_stale': 0,
    'generated_at': '2026-07-12T00:00:00.000Z',
    'created_at': '2026-07-12T00:00:00.000Z',
    'updated_at': '2026-07-12T00:00:00.000Z',
  });
}

Future<void> _insertWeeklySnapshot(
  Database db, {
  required String weekStart,
  required String weekEnd,
  required String keyInsight,
  String patternsJson = '[]',
  String frictionsJson = '[]',
  String bestAction = '继续轻量观察。',
  String? opportunitySnapshotJson,
}) {
  return db.insert('weekly_snapshots', {
    'week_start': weekStart,
    'week_end': weekEnd,
    'status': 'ready',
    'key_insight': keyInsight,
    'patterns_json': patternsJson,
    'frictions_json': frictionsJson,
    'best_action': bestAction,
    'opportunity_snapshot_json': opportunitySnapshotJson,
    'chart_data_json': '[]',
    'feedback_submitted': 0,
    'source_hash': 'fixture-$weekStart',
    'schema_version': 1,
    'pipeline_version': 'fixture',
    'dirty': 0,
    'is_stale': 0,
    'generated_at': '${weekEnd}T00:00:00.000Z',
  });
}

Future<void> _insertSignalCard(
  Database db, {
  required String id,
  required String rawText,
  required String localDate,
  int includedInSummary = 1,
  int includedInWeekly = 1,
  int includedInJourney = 1,
  String privacyLevel = 'private',
  int isLegacy = 0,
}) {
  return db.insert(
    'signal_cards',
    _signalCardRow(
      id,
      rawText,
      localDate,
      includedInSummary: includedInSummary,
      includedInWeekly: includedInWeekly,
      includedInJourney: includedInJourney,
      privacyLevel: privacyLevel,
      isLegacy: isLegacy,
    ),
  );
}

Map<String, Object?> _signalCardRow(
  String id,
  String rawText,
  String localDate, {
  int includedInSummary = 1,
  int includedInWeekly = 1,
  int includedInJourney = 1,
  String privacyLevel = 'private',
  int isLegacy = 0,
}) {
  return {
    'id': id,
    'signal_card_id': id,
    'client_id': id,
    'server_id': id,
    'source_type': 'text',
    'raw_text': rawText,
    'created_at': '${localDate}T00:00:00.000Z',
    'local_date': localDate,
    'timezone': 'Asia/Tokyo',
    'language': 'zh-Hans',
    'ai_reply': 'fixture reply',
    'observation': 'fixture observation',
    'try_next': 'fixture try next',
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
    'is_local_draft': 0,
    'sync_failed': 0,
    'sync_status': 'synced',
    'updated_at': '${localDate}T00:00:00.000Z',
  };
}
