import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  static const _databaseName = 'ai_opportunity_radar_local.db';
  static const schemaVersion = 40;
  static const _databaseVersion = schemaVersion;

  final String? dbPathOverride;
  final DatabaseFactory? databaseFactoryOverride;

  Database? _database;

  LocalDatabase({
    this.dbPathOverride,
    this.databaseFactoryOverride,
  });

  Future<void> init() async {
    await database;
  }

  Future<void> runP2LegacyDataMigration() async {
    final db = await database;
    await _runP2LegacyDataMigration(db);
  }

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) return existing;

    final resolvedPath = await _resolveDbPath();
    final factory = databaseFactoryOverride ?? databaseFactory;

    _database = await factory.openDatabase(
      resolvedPath,
      options: OpenDatabaseOptions(
        version: _databaseVersion,
        onCreate: (db, version) async {
          await _createAllTables(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS weekly_snapshots (
                week_start TEXT PRIMARY KEY,
                week_end TEXT NOT NULL,
                status TEXT NOT NULL,
                key_insight TEXT,
                patterns_json TEXT,
                frictions_json TEXT,
                best_action TEXT,
                opportunity_snapshot_json TEXT,
                feedback_submitted INTEGER NOT NULL DEFAULT 0,
                source_hash TEXT,
                generated_at TEXT NOT NULL
              )
            ''');
          }

          if (oldVersion < 3) {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS journey_snapshots (
                snapshot_date TEXT PRIMARY KEY,
                patterns_json TEXT,
                frictions_json TEXT,
                desires_json TEXT,
                experiments_json TEXT,
                journey_data_json TEXT,
                source_hash TEXT,
                generated_at TEXT NOT NULL
              )
            ''');
          }

          if (oldVersion < 4) {
            await _addColumnIfNeeded(db, 'captures', 'ai_observation TEXT');
            await _addColumnIfNeeded(db, 'captures', 'ai_try_next TEXT');
            await _addColumnIfNeeded(db, 'captures', 'ai_emotion TEXT');
            await _addColumnIfNeeded(db, 'captures', 'ai_intensity TEXT');
            await _addColumnIfNeeded(db, 'captures', 'ai_scene_tags_json TEXT');
            await _addColumnIfNeeded(
                db, 'captures', 'ai_intent_tags_json TEXT');
          }

          if (oldVersion < 5) {
            await _addColumnIfNeeded(
                db, 'weekly_snapshots', 'chart_data_json TEXT');
          }

          if (oldVersion < 6) {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS monthly_snapshots (
                month_start TEXT PRIMARY KEY,
                month_end TEXT NOT NULL,
                status TEXT NOT NULL,
                monthly_summary TEXT,
                repeated_themes_json TEXT,
                improving_signals_json TEXT,
                unresolved_points_json TEXT,
                next_month_watch TEXT,
                weekly_bridges_json TEXT,
                source_hash TEXT,
                generated_at TEXT NOT NULL
              )
            ''');
          }

          if (oldVersion < 7) {
            await _createSignalCardTables(db);
          }

          if (oldVersion < 8) {
            await _addColumnIfNeeded(
              db,
              'signal_cards',
              "source_type TEXT NOT NULL DEFAULT 'text'",
            );
            await _addColumnIfNeeded(
              db,
              'signal_cards',
              "privacy_level TEXT NOT NULL DEFAULT 'private'",
            );
          }

          if (oldVersion < 9) {
            await _addColumnIfNeeded(
              db,
              'signal_cards',
              'linked_experiment_id TEXT',
            );
            await _createLifeExperimentTables(db);
          }

          if (oldVersion < 10) {
            await _addColumnIfNeeded(
              db,
              'signal_cards',
              "linked_life_chain_stage TEXT NOT NULL DEFAULT '[]'",
            );
          }

          if (oldVersion < 11) {
            await _addColumnIfNeeded(
              db,
              'signal_cards',
              'raw_payload_json TEXT',
            );
          }

          if (oldVersion < 12) {
            await _createSignalLibraryTables(db);
          }

          if (oldVersion < 13) {
            await _createPhase3PlusTables(db);
          }

          if (oldVersion < 14) {
            await _addColumnIfNeeded(db, 'schedule_signals', 'note TEXT');
          }

          if (oldVersion < 15) {
            await _createAiActionTables(db);
          }

          if (oldVersion < 16) {
            await _addColumnIfNeeded(
              db,
              'ai_judgements',
              "prediction_kind TEXT NOT NULL DEFAULT 'inferred_signal'",
            );
            await _addColumnIfNeeded(
              db,
              'ai_judgements',
              'predicted_signal_text TEXT',
            );
            await _addColumnIfNeeded(
              db,
              'ai_judgements',
              'confirmation_note TEXT',
            );
          }

          if (oldVersion < 18) {
            await _addColumnIfNeeded(
              db,
              'journey_snapshots',
              'journey_data_json TEXT',
            );
          }

          if (oldVersion < 19) {
            await _createSignalPolicyTables(db);
            await _backfillSignalPolicyTables(db);
          }

          if (oldVersion < 20) {
            await _createReflectionResultTables(db);
            await _backfillReflectionResults(db);
          }

          if (oldVersion < 21) {
            await _addColumnIfNeeded(
              db,
              'reflection_results',
              "pipeline_version TEXT NOT NULL DEFAULT 'v4_p0_05'",
            );
            await _createPipelineRunTables(db);
          }

          if (oldVersion < 22) {
            await _addSignalSyncIdentityColumns(db);
            await _createSignalSyncIdentityTables(db);
            await _backfillSignalSyncIdentity(db);
          }

          if (oldVersion < 23) {
            await _createObservationTables(db);
            await _backfillObservationsFromAiJudgements(db);
          }

          if (oldVersion < 24) {
            await _createExperimentCandidateTables(db);
          }

          if (oldVersion < 25) {
            await _createLifeExperimentLifecycleTables(db);
          }

          if (oldVersion < 26) {
            await _createTraceLinkTables(db);
          }

          if (oldVersion < 27) {
            await _addCacheVersioningColumns(db);
          }

          if (oldVersion < 28) {
            await _createPeriodQueryIndexes(db);
          }

          if (oldVersion < 29) {
            await _addExperimentCandidateInvalidationColumns(db);
          }

          if (oldVersion < 30) {
            await _runP2LegacyDataMigration(db);
          }

          if (oldVersion < 31) {
            await _createSignalTombstoneTables(db);
          }

          if (oldVersion < 32) {
            await _addLifeExperimentRollupInvalidationColumns(db);
          }

          if (oldVersion < 33) {
            await _repairObservationFeedbackState(db);
          }

          if (oldVersion < 34) {
            await _createCandidatePlanningTables(db);
            await _addCandidatePlanningColumns(db);
            await _backfillCandidatePlanningData(db);
          }

          if (oldVersion < 35) {
            await _repairLegacyDailyCompletionLifecycle(db);
          }

          if (oldVersion < 36) {
            await _createPlanContentVersionTables(db);
            await _backfillPlanContentVersions(db);
          }

          if (oldVersion < 37) {
            await _createDeepeningObservationPlanTables(db);
          }

          if (oldVersion < 38) {
            await _addCandidateDecisionColumns(db);
            await _backfillCandidateDecisions(db);
          }

          if (oldVersion < 39) {
            await _createExperimentEvaluationTables(db);
          }

          if (oldVersion < 40) {
            await _upgradeExperimentEvaluationV40(db);
          }
        },
      ),
    );

    return _database!;
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  Future<void> _createAllTables(Database db) async {
    await db.execute('''
      CREATE TABLE captures (
        id TEXT PRIMARY KEY,
        content TEXT NOT NULL,
        created_at TEXT NOT NULL,
        input_mode TEXT,
        tag_hint TEXT,
        ai_acknowledgement TEXT,
        ai_observation TEXT,
        ai_try_next TEXT,
        ai_emotion TEXT,
        ai_intensity TEXT,
        ai_scene_tags_json TEXT,
        ai_intent_tags_json TEXT,
        ai_status TEXT,
        followup_question_json TEXT,
        followup_answer TEXT,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE daily_snapshots (
        date TEXT PRIMARY KEY,
        entry_count INTEGER NOT NULL,
        observation_text TEXT,
        suggestion_text TEXT,
        source_hash TEXT,
        generated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE weekly_snapshots (
        week_start TEXT PRIMARY KEY,
        week_end TEXT NOT NULL,
        status TEXT NOT NULL,
        key_insight TEXT,
        patterns_json TEXT,
        frictions_json TEXT,
        best_action TEXT,
        opportunity_snapshot_json TEXT,
        chart_data_json TEXT,
        feedback_submitted INTEGER NOT NULL DEFAULT 0,
        source_hash TEXT,
        generated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE journey_snapshots (
        snapshot_date TEXT PRIMARY KEY,
        patterns_json TEXT,
        frictions_json TEXT,
        desires_json TEXT,
        experiments_json TEXT,
        journey_data_json TEXT,
        source_hash TEXT,
        generated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE monthly_snapshots (
        month_start TEXT PRIMARY KEY,
        month_end TEXT NOT NULL,
        status TEXT NOT NULL,
        monthly_summary TEXT,
        repeated_themes_json TEXT,
        improving_signals_json TEXT,
        unresolved_points_json TEXT,
        next_month_watch TEXT,
        weekly_bridges_json TEXT,
        source_hash TEXT,
        generated_at TEXT NOT NULL
      )
    ''');

    await _createSignalCardTables(db);
    await _createSignalTombstoneTables(db);
    await _createSignalPolicyTables(db);
    await _createSignalSyncIdentityTables(db);
    await _createObservationTables(db);
    await _createLifeExperimentTables(db);
    await _createSignalLibraryTables(db);
    await _createPhase3PlusTables(db);
    await _createAiActionTables(db);
    await _createReflectionResultTables(db);
    await _createPipelineRunTables(db);
    await _createExperimentCandidateTables(db);
    await _createLifeExperimentLifecycleTables(db);
    await _createExperimentEvaluationTables(db);
    await _createTraceLinkTables(db);
    await _addCacheVersioningColumns(db);
    await _addExperimentCandidateInvalidationColumns(db);
    await _addLifeExperimentRollupInvalidationColumns(db);
    await _createCandidatePlanningTables(db);
    await _addCandidatePlanningColumns(db);
    await _addCandidateDecisionColumns(db);
    // v40 reads candidate-planning columns such as progress_end_date, so it
    // must run after those columns exist on a fresh database. Upgrade paths
    // already reach the same state before oldVersion < 40 is evaluated.
    await _upgradeExperimentEvaluationV40(db);
    await _createPlanContentVersionTables(db);
    await _createDeepeningObservationPlanTables(db);
    await _createPeriodQueryIndexes(db);
    await _runP2LegacyDataMigration(db);
    await _backfillCandidatePlanningData(db);
    await _backfillCandidateDecisions(db);
    await _backfillPlanContentVersions(db);

    await db.execute(
      'CREATE INDEX idx_captures_created_at ON captures(created_at DESC)',
    );
  }

  Future<void> _createReflectionResultTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reflection_results (
        id TEXT PRIMARY KEY,
        source_type TEXT NOT NULL,
        source_id TEXT NOT NULL,
        reflection_type TEXT NOT NULL,
        ai_level TEXT NOT NULL,
        content_json TEXT NOT NULL DEFAULT '{}',
        status TEXT NOT NULL DEFAULT 'generated',
        schema_version INTEGER NOT NULL DEFAULT 1,
        prompt_version TEXT,
        model_version TEXT,
        pipeline_version TEXT NOT NULL DEFAULT 'v4_p0_05',
        source_hash TEXT,
        dirty INTEGER NOT NULL DEFAULT 0,
        is_stale INTEGER NOT NULL DEFAULT 0,
        stale_reason TEXT,
        invalidated_at TEXT,
        generated_at TEXT NOT NULL,
        confirmed_at TEXT,
        superseded_by TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_reflection_results_source ON reflection_results(source_type, source_id, reflection_type, status, generated_at DESC)',
    );
  }

  Future<void> _createPipelineRunTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pipeline_runs (
        id TEXT PRIMARY KEY,
        local_user_id TEXT NOT NULL DEFAULT 'local',
        pipeline_type TEXT NOT NULL,
        source_type TEXT NOT NULL,
        source_id TEXT NOT NULL,
        status TEXT NOT NULL,
        started_at TEXT NOT NULL,
        finished_at TEXT,
        error_code TEXT,
        error_message TEXT,
        input_hash TEXT,
        output_hash TEXT,
        pipeline_version TEXT NOT NULL DEFAULT 'v4_p0_05',
        retry_count INTEGER NOT NULL DEFAULT 0,
        can_retry INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_pipeline_runs_source ON pipeline_runs(source_type, source_id, pipeline_type, status, started_at DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_pipeline_runs_retry ON pipeline_runs(status, can_retry, updated_at DESC)',
    );
  }

  Future<void> _backfillReflectionResults(Database db) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final dailyRows = await db.query('daily_snapshots');
    for (final row in dailyRows) {
      final date = row['date'] as String?;
      if (date == null || date.isEmpty) continue;
      await db.insert(
        'reflection_results',
        {
          'id': 'refl_daily_snapshot_${_stableIdPart(date)}_assist_v1',
          'source_type': 'daily_snapshot',
          'source_id': date,
          'reflection_type': 'assist',
          'ai_level': 'L1',
          'content_json': jsonEncode({
            'observation_text': row['observation_text'],
            'suggestion_text': row['suggestion_text'],
          }),
          'status': 'generated',
          'schema_version': 1,
          'source_hash': row['source_hash'],
          'generated_at': row['generated_at'] ?? now,
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    final weeklyRows = await db.query('weekly_snapshots');
    for (final row in weeklyRows) {
      final weekStart = row['week_start'] as String?;
      if (weekStart == null || weekStart.isEmpty) continue;
      final opportunitySnapshot = _decodeJsonValue(
        row['opportunity_snapshot_json'] as String?,
      );
      await db.insert(
        'reflection_results',
        {
          'id': 'refl_weekly_snapshot_${_stableIdPart(weekStart)}_reflect_v1',
          'source_type': 'weekly_snapshot',
          'source_id': weekStart,
          'reflection_type': 'reflect',
          'ai_level': 'L3',
          'content_json': jsonEncode({
            'key_insight': row['key_insight'],
            'patterns': _decodeJsonValue(row['patterns_json'] as String?),
            'frictions': _decodeJsonValue(row['frictions_json'] as String?),
            'best_action': row['best_action'],
            'opportunity_snapshot': opportunitySnapshot is Map
                ? _withoutLegacyLifeExperiment(opportunitySnapshot)
                : opportunitySnapshot,
          }),
          'status': 'generated',
          'schema_version': 1,
          'source_hash': row['source_hash'],
          'generated_at': row['generated_at'] ?? now,
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    final journeyRows = await db.query('journey_snapshots');
    for (final row in journeyRows) {
      final snapshotDate = row['snapshot_date'] as String?;
      if (snapshotDate == null || snapshotDate.isEmpty) continue;
      await db.insert(
        'reflection_results',
        {
          'id':
              'refl_journey_snapshot_${_stableIdPart(snapshotDate)}_reflect_v1',
          'source_type': 'journey_snapshot',
          'source_id': snapshotDate,
          'reflection_type': 'reflect',
          'ai_level': 'L3',
          'content_json': jsonEncode({
            'patterns': _decodeJsonValue(row['patterns_json'] as String?),
            'frictions': _decodeJsonValue(row['frictions_json'] as String?),
            'desires': _decodeJsonValue(row['desires_json'] as String?),
            'experiments': _decodeJsonValue(row['experiments_json'] as String?),
            'journey_data': _decodeJsonValue(
              row['journey_data_json'] as String?,
            ),
          }),
          'status': 'generated',
          'schema_version': 1,
          'source_hash': row['source_hash'],
          'generated_at': row['generated_at'] ?? now,
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Object? _decodeJsonValue(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  String _stableIdPart(String raw) {
    return raw.replaceAll(RegExp(r'[^A-Za-z0-9_]+'), '_');
  }

  Future<void> _runP2LegacyDataMigration(Database db) async {
    await _backfillLegacyWeeklyLifeExperimentCandidates(db);
    await _backfillReflectionResults(db);
    await _backfillSignalPolicyTables(db);
    await _backfillObservationsFromAiJudgements(db);
    await _stripLegacyWeeklyLifeExperimentFromReflectionResults(db);
  }

  Future<void> _backfillLegacyWeeklyLifeExperimentCandidates(
    Database db,
  ) async {
    final rows = await db.query(
      'weekly_snapshots',
      where: 'opportunity_snapshot_json IS NOT NULL',
    );
    for (final row in rows) {
      final weekStart = row['week_start'] as String?;
      final weekEnd = row['week_end'] as String?;
      if (weekStart == null ||
          weekStart.trim().isEmpty ||
          weekEnd == null ||
          weekEnd.trim().isEmpty) {
        continue;
      }
      final opportunity = _decodeJsonValue(
        row['opportunity_snapshot_json'] as String?,
      );
      if (opportunity is! Map) continue;
      final rawExperiment = opportunity['_life_experiment'];
      if (rawExperiment is! Map) continue;

      final title = _stringFromMap(rawExperiment, ['title']);
      final hypothesis = _stringFromMap(rawExperiment, ['hypothesis']);
      final suggestedAction = _stringFromMap(
        rawExperiment,
        ['suggested_action', 'suggestedAction'],
      );
      if (title == null || hypothesis == null || suggestedAction == null) {
        continue;
      }

      final localUserId =
          _stringFromMap(rawExperiment, ['local_user_id', 'localUserId']) ??
              'local';
      final linkedSignalIds = _stringListFromMap(
        rawExperiment,
        ['linked_signal_card_ids', 'linkedSignalCardIds'],
      );
      final rowGeneratedAt = row['generated_at'] as String?;
      final createdAt = _stringFromMap(
            rawExperiment,
            ['created_at', 'createdAt'],
          ) ??
          rowGeneratedAt ??
          DateTime.now().toUtc().toIso8601String();
      final updatedAt = _stringFromMap(
            rawExperiment,
            ['updated_at', 'updatedAt'],
          ) ??
          rowGeneratedAt ??
          createdAt;
      final candidateId =
          'cand_${_stableIdPart(localUserId)}_${_stableIdPart(weekStart)}';

      await db.insert(
        'experiment_candidates',
        {
          'id': candidateId,
          'local_user_id': localUserId,
          'source_type': 'weekly_reflection',
          'source_id': weekStart,
          'source_week_start': weekStart,
          'source_week_end': weekEnd,
          'title': title,
          'hypothesis': hypothesis,
          'suggested_action': suggestedAction,
          'linked_signal_card_ids_json': jsonEncode(linkedSignalIds),
          'linked_observation_ids_json': '[]',
          'status': 'generated',
          'confidence_level': 'medium',
          'metadata_json': jsonEncode({
            'presentation_status':
                _stringFromMap(rawExperiment, ['status']) ?? 'suggested',
            'created_from': 'legacy_opportunity_snapshot_migration',
            'legacy_source': 'weekly_snapshot._life_experiment',
            'legacy_source_unknown': linkedSignalIds.isEmpty,
          }),
          'adopted_experiment_id': null,
          'dirty': 0,
          'is_stale': 0,
          'stale_reason': null,
          'invalidated_at': null,
          'created_at': createdAt,
          'updated_at': updatedAt,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      await _insertLegacyTraceLinksForCandidate(
        db,
        candidateId: candidateId,
        localUserId: localUserId,
        weekStart: weekStart,
        linkedSignalIds: linkedSignalIds,
        updatedAt: updatedAt,
      );

      await db.update(
        'weekly_snapshots',
        {
          'opportunity_snapshot_json': jsonEncode(
            _withoutLegacyLifeExperiment(opportunity),
          ),
        },
        where: 'week_start = ?',
        whereArgs: [weekStart],
      );
    }
  }

  Future<void> _stripLegacyWeeklyLifeExperimentFromReflectionResults(
    Database db,
  ) async {
    final rows = await db.query(
      'reflection_results',
      columns: ['id', 'content_json'],
      where: 'source_type = ?',
      whereArgs: ['weekly_snapshot'],
    );
    for (final row in rows) {
      final id = row['id'] as String?;
      final content = _decodeJsonValue(row['content_json'] as String?);
      if (id == null || content is! Map) continue;

      final opportunity = content['opportunity_snapshot'];
      if (opportunity is! Map || !opportunity.containsKey('_life_experiment')) {
        continue;
      }
      final sanitized = Map<String, dynamic>.from(content);
      sanitized['opportunity_snapshot'] =
          _withoutLegacyLifeExperiment(opportunity);
      await db.update(
        'reflection_results',
        {
          'content_json': jsonEncode(sanitized),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<void> _insertLegacyTraceLinksForCandidate(
    Database db, {
    required String candidateId,
    required String localUserId,
    required String weekStart,
    required List<String> linkedSignalIds,
    required String updatedAt,
  }) async {
    await db.insert(
      'trace_links',
      {
        'id':
            'trace_experiment_candidate_${_stableIdPart(candidateId)}_weekly_${_stableIdPart(weekStart)}_legacy_source',
        'local_user_id': localUserId,
        'source_type': 'experiment_candidate',
        'source_id': candidateId,
        'target_type': 'weekly_snapshot',
        'target_id': weekStart,
        'relation_type': 'legacy_migrated_from',
        'weight': 0.6,
        'status': 'active',
        'metadata_json': jsonEncode({
          'legacy_source': 'opportunity_snapshot._life_experiment',
          'legacy_source_unknown': linkedSignalIds.isEmpty,
        }),
        'created_at': updatedAt,
        'updated_at': updatedAt,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    for (final signalId in linkedSignalIds) {
      await db.insert(
        'trace_links',
        {
          'id':
              'trace_experiment_candidate_${_stableIdPart(candidateId)}_signal_card_${_stableIdPart(signalId)}_legacy_linked_signal',
          'local_user_id': localUserId,
          'source_type': 'experiment_candidate',
          'source_id': candidateId,
          'target_type': 'signal_card',
          'target_id': signalId,
          'relation_type': 'legacy_linked_signal',
          'weight': 0.8,
          'status': 'active',
          'metadata_json': jsonEncode({
            'legacy_source': 'opportunity_snapshot._life_experiment',
          }),
          'created_at': updatedAt,
          'updated_at': updatedAt,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  String? _stringFromMap(Map<dynamic, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  List<String> _stringListFromMap(
      Map<dynamic, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is List) {
        return value
            .map((item) => item?.toString().trim() ?? '')
            .where((item) => item.isNotEmpty)
            .toList(growable: false);
      }
      if (value is String && value.trim().isNotEmpty) {
        final decoded = _decodeStringList(value);
        if (decoded.isNotEmpty) return decoded;
      }
    }
    return const [];
  }

  Map<String, dynamic> _withoutLegacyLifeExperiment(Map<dynamic, dynamic> map) {
    return Map<String, dynamic>.from(map)..remove('_life_experiment');
  }

  Future<void> _createSignalCardTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS signal_cards (
        id TEXT PRIMARY KEY,
        signal_card_id TEXT,
        client_id TEXT,
        server_id TEXT,
        raw_memory_id TEXT,
        capture_id TEXT,
        source_type TEXT NOT NULL DEFAULT 'text',
        raw_text TEXT NOT NULL,
        created_at TEXT NOT NULL,
        local_date TEXT NOT NULL,
        timezone TEXT,
        language TEXT,
        ai_reply TEXT,
        observation TEXT,
        try_next TEXT,
        emotion TEXT,
        intensity TEXT,
        scene TEXT,
        friction TEXT,
        positive_signal TEXT,
        energy_load TEXT,
        linked_life_chain_stage TEXT NOT NULL DEFAULT '[]',
        raw_payload_json TEXT,
        scene_tags_json TEXT,
        intent_tags_json TEXT,
        user_confirmation TEXT NOT NULL DEFAULT 'unconfirmed',
        user_correction_json TEXT,
        included_in_summary INTEGER NOT NULL DEFAULT 0,
        included_in_weekly INTEGER NOT NULL DEFAULT 0,
        included_in_journey INTEGER NOT NULL DEFAULT 0,
        linked_experiment_id TEXT,
        privacy_level TEXT NOT NULL DEFAULT 'private',
        is_legacy INTEGER NOT NULL DEFAULT 0,
        migration_status TEXT NOT NULL DEFAULT 'native',
        is_local_draft INTEGER NOT NULL DEFAULT 0,
        sync_failed INTEGER NOT NULL DEFAULT 0,
        sync_status TEXT NOT NULL DEFAULT 'synced',
        last_error TEXT,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS signal_card_drafts (
        draft_id TEXT PRIMARY KEY,
        client_id TEXT NOT NULL,
        raw_text TEXT NOT NULL,
        source_type TEXT NOT NULL DEFAULT 'text',
        tag_hint TEXT,
        created_at TEXT NOT NULL,
        local_date TEXT NOT NULL,
        timezone TEXT,
        language TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        retry_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        remote_signal_card_id TEXT,
        server_id TEXT,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_signal_cards_local_date ON signal_cards(local_date DESC, created_at DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_signal_card_drafts_status ON signal_card_drafts(status, created_at ASC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_signal_cards_client_id ON signal_cards(client_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_signal_cards_server_id ON signal_cards(server_id)',
    );
  }

  Future<void> _createSignalTombstoneTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS signal_tombstones (
        signal_id TEXT PRIMARY KEY,
        signal_card_id TEXT,
        client_id TEXT,
        server_id TEXT,
        local_date TEXT,
        reason TEXT NOT NULL DEFAULT 'user_deleted',
        status TEXT NOT NULL DEFAULT 'active',
        deleted_at TEXT NOT NULL,
        restored_at TEXT,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_signal_tombstones_status ON signal_tombstones(status, updated_at DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_signal_tombstones_server ON signal_tombstones(server_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_signal_tombstones_client ON signal_tombstones(client_id)',
    );
  }

  Future<void> _addSignalSyncIdentityColumns(Database db) async {
    await _addColumnIfNeeded(db, 'signal_cards', 'client_id TEXT');
    await _addColumnIfNeeded(db, 'signal_cards', 'server_id TEXT');
    await _addColumnIfNeeded(db, 'signal_card_drafts', 'client_id TEXT');
    await _addColumnIfNeeded(db, 'signal_card_drafts', 'server_id TEXT');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_signal_cards_client_id ON signal_cards(client_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_signal_cards_server_id ON signal_cards(server_id)',
    );
  }

  Future<void> _createSignalSyncIdentityTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS signal_sync_identity (
        client_id TEXT PRIMARY KEY,
        server_id TEXT,
        local_signal_id TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        last_synced_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_signal_sync_identity_server ON signal_sync_identity(server_id) WHERE server_id IS NOT NULL',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_signal_sync_identity_local ON signal_sync_identity(local_signal_id)',
    );
  }

  Future<void> _createObservationTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS observations (
        id TEXT PRIMARY KEY,
        local_user_id TEXT NOT NULL DEFAULT 'local',
        observation_text TEXT NOT NULL,
        observation_type TEXT NOT NULL DEFAULT 'hypothesis',
        confidence TEXT NOT NULL DEFAULT 'medium',
        status TEXT NOT NULL DEFAULT 'generated',
        source_period_start TEXT,
        source_period_end TEXT,
        created_by TEXT NOT NULL DEFAULT 'l2_reason',
        source_ai_judgement_id TEXT,
        evidence_text TEXT,
        suggested_pattern TEXT,
        suggested_life_chain_stage TEXT,
        user_adjustment_text TEXT,
        confirmation_note TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        confirmed_at TEXT,
        dismissed_at TEXT,
        archived_at TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_observations_status_date ON observations(status, source_period_start, updated_at DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_observations_ai_judgement ON observations(source_ai_judgement_id)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS observation_signal_links (
        observation_id TEXT NOT NULL,
        signal_id TEXT NOT NULL,
        weight REAL NOT NULL DEFAULT 1.0,
        reason TEXT,
        created_at TEXT NOT NULL,
        PRIMARY KEY (observation_id, signal_id)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_observation_signal_links_signal ON observation_signal_links(signal_id)',
    );
  }

  Future<void> _backfillObservationsFromAiJudgements(Database db) async {
    final rows = await db.query('ai_judgements');
    for (final row in rows) {
      final id = row['id'] as String?;
      final text = row['judgement_text'] as String?;
      if (id == null || text == null || text.trim().isEmpty) continue;
      final status = _observationStatusFromJudgement(row['status'] as String?);
      final created = row['created_at'] as String? ??
          DateTime.now().toUtc().toIso8601String();
      final updated = row['updated_at'] as String? ?? created;
      await db.insert(
        'observations',
        {
          'id': 'obs_$id',
          'local_user_id': 'local',
          'observation_text': text,
          'observation_type':
              row['prediction_kind'] as String? ?? 'inferred_signal',
          'confidence': row['confidence_level'] as String? ?? 'medium',
          'status': status,
          'source_period_start': row['local_date'],
          'source_period_end': row['local_date'],
          'created_by': 'l2_reason',
          'source_ai_judgement_id': id,
          'evidence_text': row['evidence_text'],
          'suggested_pattern': row['suggested_pattern'],
          'suggested_life_chain_stage': row['suggested_life_chain_stage'],
          'user_adjustment_text': row['user_adjustment_text'],
          'confirmation_note': row['confirmation_note'],
          'created_at': created,
          'updated_at': updated,
          'confirmed_at': status == 'confirmed' ? updated : null,
          'dismissed_at': status == 'dismissed' ? updated : null,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      final signalIds = _decodeStringList(
        row['source_signal_card_ids_json'] as String?,
      );
      for (final signalId in signalIds) {
        await db.insert(
          'observation_signal_links',
          {
            'observation_id': 'obs_$id',
            'signal_id': signalId,
            'weight': 1.0,
            'reason': 'source_signal',
            'created_at': created,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }
  }

  String _observationStatusFromJudgement(String? raw) {
    final status = raw?.trim().toLowerCase();
    if (const {'confirmed', 'adjusted', 'accurate', 'partial'}
        .contains(status)) {
      return 'confirmed';
    }
    if (const {'inaccurate', 'ignored', 'dismissed'}.contains(status)) {
      return 'dismissed';
    }
    if (status == 'archived') return 'archived';
    return 'generated';
  }

  /// Builds 34 and earlier used `micro_actions.status = done` for a single
  /// day's completion feedback.  The final model keeps daily completion in
  /// `micro_action_feedback`; lifecycle status is independent from any one
  /// real attempt and no longer assumes a fixed seven-day window.
  Future<void> _repairLegacyDailyCompletionLifecycle(Database db) async {
    await db.rawUpdate('''
      UPDATE micro_actions
      SET status = 'active'
      WHERE LOWER(TRIM(COALESCE(status, ''))) = 'done'
        AND (
          adopted_at IS NOT NULL
          OR TRIM(COALESCE(origin_candidate_id, '')) != ''
        )
        AND EXISTS (
          SELECT 1
          FROM micro_action_feedback feedback
          WHERE feedback.micro_action_id = micro_actions.id
        )
      ''');
  }

  Future<void> _repairObservationFeedbackState(Database db) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await db.rawUpdate(
      '''
      UPDATE observations
      SET status = 'dismissed',
          dismissed_at = COALESCE(dismissed_at, updated_at, ?),
          confirmed_at = NULL
      WHERE source_ai_judgement_id IN (
        SELECT id FROM ai_judgements
        WHERE status IN ('inaccurate', 'ignored', 'dismissed')
      )
      ''',
      [now],
    );
    await db.rawUpdate(
      '''
      UPDATE observations
      SET status = 'confirmed',
          observation_text = CASE
            WHEN TRIM(COALESCE(user_adjustment_text, '')) != ''
              THEN TRIM(user_adjustment_text)
            ELSE observation_text
          END,
          confirmed_at = COALESCE(confirmed_at, updated_at, ?),
          dismissed_at = NULL
      WHERE source_ai_judgement_id IN (
        SELECT id FROM ai_judgements
        WHERE status IN ('confirmed', 'adjusted', 'accurate', 'partial')
      )
      ''',
      [now],
    );
  }

  List<String> _decodeStringList(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((e) => e?.toString().trim() ?? '')
            .where((e) => e.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  Future<void> _backfillSignalSyncIdentity(Database db) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await db.rawUpdate('''
      UPDATE signal_cards
      SET
        client_id = COALESCE(client_id, id),
        server_id = COALESCE(server_id, signal_card_id)
      WHERE client_id IS NULL OR server_id IS NULL
    ''');
    await db.rawUpdate('''
      UPDATE signal_card_drafts
      SET
        client_id = COALESCE(client_id, draft_id),
        server_id = COALESCE(server_id, remote_signal_card_id)
      WHERE client_id IS NULL OR server_id IS NULL
    ''');
    await db.rawInsert(
      '''
      INSERT OR IGNORE INTO signal_sync_identity (
        client_id,
        server_id,
        local_signal_id,
        sync_status,
        last_synced_at,
        created_at,
        updated_at
      )
      SELECT
        COALESCE(client_id, id),
        COALESCE(server_id, signal_card_id),
        id,
        COALESCE(sync_status, 'synced'),
        CASE WHEN COALESCE(sync_status, 'synced') = 'synced' THEN COALESCE(updated_at, ?) ELSE NULL END,
        COALESCE(created_at, ?),
        COALESCE(updated_at, ?)
      FROM signal_cards
      ''',
      [now, now, now],
    );
  }

  Future<void> _createSignalPolicyTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS signal_processing_state (
        signal_id TEXT PRIMARY KEY,
        sync_status TEXT NOT NULL DEFAULT 'synced',
        assist_status TEXT NOT NULL DEFAULT 'not_started',
        reason_status TEXT NOT NULL DEFAULT 'not_started',
        daily_status TEXT NOT NULL DEFAULT 'not_started',
        weekly_status TEXT NOT NULL DEFAULT 'not_started',
        journey_status TEXT NOT NULL DEFAULT 'not_started',
        is_local_draft INTEGER NOT NULL DEFAULT 0,
        sync_failed INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        retry_count INTEGER NOT NULL DEFAULT 0,
        processing_version TEXT NOT NULL DEFAULT 'v4_p0_02',
        last_processed_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS signal_analysis_policy (
        signal_id TEXT PRIMARY KEY,
        privacy_level TEXT NOT NULL DEFAULT 'private',
        is_sensitive INTEGER NOT NULL DEFAULT 0,
        is_excluded INTEGER NOT NULL DEFAULT 0,
        do_not_analyze INTEGER NOT NULL DEFAULT 0,
        requires_user_confirmation INTEGER NOT NULL DEFAULT 0,
        confirmed_by_user INTEGER NOT NULL DEFAULT 0,
        inaccurate INTEGER NOT NULL DEFAULT 0,
        exclusion_reason TEXT,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_signal_processing_stage ON signal_processing_state(daily_status, weekly_status, journey_status)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_signal_analysis_policy_flags ON signal_analysis_policy(privacy_level, inaccurate, do_not_analyze)',
    );
  }

  Future<void> _backfillSignalPolicyTables(Database db) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await db.rawInsert(
      '''
      INSERT OR IGNORE INTO signal_processing_state (
        signal_id,
        sync_status,
        daily_status,
        weekly_status,
        journey_status,
        is_local_draft,
        sync_failed,
        last_error,
        created_at,
        updated_at
      )
      SELECT
        id,
        COALESCE(sync_status, 'synced'),
        CASE WHEN included_in_summary = 1 THEN 'included' ELSE 'not_started' END,
        CASE WHEN included_in_weekly = 1 THEN 'included' ELSE 'not_started' END,
        CASE WHEN included_in_journey = 1 THEN 'included' ELSE 'not_started' END,
        COALESCE(is_local_draft, 0),
        COALESCE(sync_failed, 0),
        last_error,
        ?,
        COALESCE(updated_at, ?)
      FROM signal_cards
      ''',
      [now, now],
    );
    await db.rawInsert(
      '''
      INSERT OR IGNORE INTO signal_analysis_policy (
        signal_id,
        privacy_level,
        is_sensitive,
        is_excluded,
        do_not_analyze,
        confirmed_by_user,
        inaccurate,
        exclusion_reason,
        updated_at
      )
      SELECT
        id,
        COALESCE(privacy_level, 'private'),
        CASE WHEN privacy_level = 'sensitive' THEN 1 ELSE 0 END,
        CASE WHEN privacy_level = 'excluded' THEN 1 ELSE 0 END,
        CASE WHEN privacy_level = 'do_not_analyze' THEN 1 ELSE 0 END,
        CASE WHEN user_confirmation IN ('confirmed', 'edited', 'supplemented') THEN 1 ELSE 0 END,
        CASE WHEN user_confirmation = 'inaccurate' THEN 1 ELSE 0 END,
        CASE
          WHEN user_confirmation = 'inaccurate' THEN 'inaccurate'
          WHEN privacy_level IN ('sensitive', 'excluded', 'do_not_analyze') THEN privacy_level
          ELSE NULL
        END,
        COALESCE(updated_at, ?)
      FROM signal_cards
      ''',
      [now],
    );
  }

  Future<void> _createLifeExperimentTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS life_experiments (
        id TEXT PRIMARY KEY,
        local_user_id TEXT NOT NULL,
        source_week_start TEXT NOT NULL,
        source_week_end TEXT NOT NULL,
        title TEXT NOT NULL,
        hypothesis TEXT NOT NULL,
        suggested_action TEXT NOT NULL,
        linked_signal_card_ids_json TEXT NOT NULL DEFAULT '[]',
        status TEXT NOT NULL DEFAULT 'pending',
        feedback_text TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_life_experiments_week ON life_experiments(source_week_start, local_user_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_life_experiments_status ON life_experiments(status, updated_at DESC)',
    );
    await _addColumnIfNeeded(
      db,
      'life_experiments',
      "experiment_type TEXT NOT NULL DEFAULT 'life'",
    );
    await _addColumnIfNeeded(db, 'life_experiments', 'strategy_id TEXT');
    await _addColumnIfNeeded(db, 'life_experiments', 'target_pattern TEXT');
    await _addColumnIfNeeded(db, 'life_experiments', 'trigger_type TEXT');
    await _addColumnIfNeeded(db, 'life_experiments', 'planned_frequency TEXT');
    await _addColumnIfNeeded(
        db, 'life_experiments', 'planned_duration_minutes INTEGER');
    await _addColumnIfNeeded(
        db, 'life_experiments', 'parent_experiment_id TEXT');
    await _addColumnIfNeeded(db, 'life_experiments', 'focus_area_id TEXT');
    await _addColumnIfNeeded(db, 'life_experiments', 'pattern_id TEXT');
    await _addColumnIfNeeded(
        db, 'life_experiments', 'feedback_pattern_id TEXT');
    await _addColumnIfNeeded(db, 'life_experiments', 'icon_asset_id TEXT');
    await _addColumnIfNeeded(
        db, 'life_experiments', 'planned_total_days INTEGER');
    await _addColumnIfNeeded(db, 'life_experiments', 'difficulty TEXT');
    await _addColumnIfNeeded(
        db, 'life_experiments', 'linked_schedule_signal_ids_json TEXT');
    await _addColumnIfNeeded(
        db, 'life_experiments', 'linked_goal_ids_json TEXT');
    await _addColumnIfNeeded(db, 'life_experiments', 'review_result TEXT');
  }

  Future<void> _createExperimentCandidateTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS experiment_candidates (
        id TEXT PRIMARY KEY,
        local_user_id TEXT NOT NULL DEFAULT 'local',
        source_type TEXT NOT NULL,
        source_id TEXT NOT NULL,
        source_week_start TEXT NOT NULL,
        source_week_end TEXT NOT NULL,
        title TEXT NOT NULL,
        hypothesis TEXT NOT NULL,
        suggested_action TEXT NOT NULL,
        linked_signal_card_ids_json TEXT NOT NULL DEFAULT '[]',
        linked_observation_ids_json TEXT NOT NULL DEFAULT '[]',
        status TEXT NOT NULL DEFAULT 'generated',
        decision_status TEXT NOT NULL DEFAULT 'undecided'
          CHECK(decision_status IN ('undecided', 'considering', 'adopted')),
        confidence_level TEXT NOT NULL DEFAULT 'medium',
        metadata_json TEXT NOT NULL DEFAULT '{}',
        adopted_experiment_id TEXT,
        dirty INTEGER NOT NULL DEFAULT 0,
        is_stale INTEGER NOT NULL DEFAULT 0,
        stale_reason TEXT,
        invalidated_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_experiment_candidates_source ON experiment_candidates(source_type, source_id, local_user_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_experiment_candidates_week ON experiment_candidates(local_user_id, source_week_start, status)',
    );
  }

  Future<void> _createLifeExperimentLifecycleTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS life_experiment_lifecycle_events (
        id TEXT PRIMARY KEY,
        experiment_id TEXT NOT NULL,
        local_user_id TEXT NOT NULL DEFAULT 'local',
        event_type TEXT NOT NULL,
        event_date TEXT NOT NULL,
        local_date TEXT NOT NULL,
        source_type TEXT,
        source_id TEXT,
        status_from TEXT,
        status_to TEXT,
        payload_json TEXT NOT NULL DEFAULT '{}',
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_life_experiment_events_exp ON life_experiment_lifecycle_events(experiment_id, event_date DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_life_experiment_events_user_date ON life_experiment_lifecycle_events(local_user_id, local_date DESC)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS life_experiment_rollups (
        experiment_id TEXT PRIMARY KEY,
        local_user_id TEXT NOT NULL DEFAULT 'local',
        root_experiment_id TEXT NOT NULL,
        parent_experiment_id TEXT,
        source_week_start TEXT NOT NULL,
        source_week_end TEXT NOT NULL,
        current_status TEXT NOT NULL,
        title TEXT NOT NULL,
        hypothesis TEXT NOT NULL,
        suggested_action TEXT NOT NULL,
        total_feedback_count INTEGER NOT NULL DEFAULT 0,
        tried_count INTEGER NOT NULL DEFAULT 0,
        helpful_count INTEGER NOT NULL DEFAULT 0,
        not_helpful_count INTEGER NOT NULL DEFAULT 0,
        adjusted_count INTEGER NOT NULL DEFAULT 0,
        skipped_count INTEGER NOT NULL DEFAULT 0,
        active_week_count INTEGER NOT NULL DEFAULT 1,
        first_started_at TEXT,
        last_feedback_at TEXT,
        last_event_at TEXT,
        lineage_json TEXT NOT NULL DEFAULT '[]',
        dirty INTEGER NOT NULL DEFAULT 0,
        is_stale INTEGER NOT NULL DEFAULT 0,
        stale_reason TEXT,
        invalidated_at TEXT,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_life_experiment_rollups_user_week ON life_experiment_rollups(local_user_id, source_week_start DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_life_experiment_rollups_root ON life_experiment_rollups(root_experiment_id, source_week_start DESC)',
    );
  }

  /// v39 adds append-only effect reviews without rewriting historical daily
  /// feedback. Goal reviews reuse the lifecycle event stream; the additive
  /// column snapshots the minimum amount of observation required before the
  /// user is asked to summarize a round.
  Future<void> _createExperimentEvaluationTables(Database db) async {
    final lifeExperimentColumns =
        await _tableColumnNames(db, 'life_experiments');
    if (lifeExperimentColumns.isNotEmpty) {
      await _addColumnIfNeeded(
        db,
        'life_experiments',
        'minimum_observation_days INTEGER NOT NULL DEFAULT 3',
      );
      await db.rawUpdate('''
        UPDATE life_experiments
        SET minimum_observation_days = 3
        WHERE minimum_observation_days IS NULL OR minimum_observation_days < 1
      ''');
    }
    await db.execute('''
      CREATE TABLE IF NOT EXISTS micro_action_review_events (
        id TEXT PRIMARY KEY,
        micro_action_id TEXT NOT NULL,
        local_user_id TEXT NOT NULL DEFAULT 'local',
        reviewed_at TEXT NOT NULL,
        local_date TEXT NOT NULL,
        result TEXT NOT NULL,
        effort TEXT NOT NULL,
        next_adjustment TEXT NOT NULL,
        note TEXT,
        completed_days_at_review INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_micro_action_review_action ON micro_action_review_events(micro_action_id, reviewed_at ASC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_micro_action_review_user_date ON micro_action_review_events(local_user_id, local_date DESC)',
    );
  }

  /// v40 removes the legacy seven-day lifecycle from quick experiments,
  /// persists their ten-minute product boundary, and gives goal reviews an
  /// explicit writer surface. Existing facts remain append-only.
  Future<void> _upgradeExperimentEvaluationV40(Database db) async {
    final microActionColumns = await _tableColumnNames(db, 'micro_actions');
    if (microActionColumns.isNotEmpty) {
      await _addColumnIfNeeded(
        db,
        'micro_actions',
        'planned_duration_minutes INTEGER NOT NULL DEFAULT 10 '
            'CHECK(planned_duration_minutes BETWEEN 1 AND 10)',
      );
      // Candidate adoption previously materialized an artificial end exactly
      // six days after the start. Open lifecycle rows must remain available
      // until the user explicitly completes them. Terminal rows keep their
      // old end date so historical diary projections remain stable.
      final currentColumns = await _tableColumnNames(db, 'micro_actions');
      if (currentColumns.containsAll(
        const {'status', 'progress_start_date', 'progress_end_date'},
      )) {
        await db.rawUpdate('''
          UPDATE micro_actions
          SET progress_end_date = NULL
          WHERE progress_start_date IS NOT NULL
            AND progress_end_date = DATE(progress_start_date, '+6 days')
            AND LOWER(TRIM(COALESCE(status, ''))) IN (
              'planned', 'accepted', 'active', 'adjusted', 'paused', 'done'
            )
        ''');
      }
    }

    final feedbackColumns =
        await _tableColumnNames(db, 'micro_action_feedback');
    if (feedbackColumns.isNotEmpty) {
      await _addColumnIfNeeded(
        db,
        'micro_action_feedback',
        'duration_minutes INTEGER '
            'CHECK(duration_minutes IS NULL OR '
            'duration_minutes BETWEEN 1 AND 10)',
      );
    }

    final reviewColumns =
        await _tableColumnNames(db, 'micro_action_review_events');
    if (reviewColumns.isNotEmpty) {
      await _addColumnIfNeeded(
        db,
        'micro_action_review_events',
        'completed_attempts_at_review INTEGER NOT NULL DEFAULT 0',
      );
      if (reviewColumns.contains('completed_days_at_review')) {
        await db.rawUpdate('''
          UPDATE micro_action_review_events
          SET completed_attempts_at_review = completed_days_at_review
          WHERE completed_attempts_at_review = 0
            AND completed_days_at_review > 0
        ''');
      }
    }

    final lifecycleColumns =
        await _tableColumnNames(db, 'life_experiment_lifecycle_events');
    if (lifecycleColumns.isNotEmpty) {
      await _addColumnIfNeeded(
        db,
        'life_experiment_lifecycle_events',
        "review_type TEXT CHECK(review_type IS NULL OR "
            "review_type IN ('weekly', 'whole_round'))",
      );
      if (lifecycleColumns.contains('event_type')) {
        await db.rawUpdate('''
          UPDATE life_experiment_lifecycle_events
          SET review_type = 'whole_round'
          WHERE event_type = 'outcome_reviewed'
            AND (review_type IS NULL OR TRIM(review_type) = '')
        ''');
      }
      if (lifecycleColumns.containsAll(
        const {'experiment_id', 'event_date'},
      )) {
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_life_experiment_review_type '
          'ON life_experiment_lifecycle_events('
          'experiment_id, review_type, event_date DESC)',
        );
      }
    }
  }

  Future<void> _createPeriodQueryIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_signal_cards_weekly_period ON signal_cards(local_date, included_in_weekly, created_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_signal_cards_journey_period ON signal_cards(local_date, included_in_journey, created_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_life_experiments_user_period ON life_experiments(local_user_id, source_week_start, source_week_end, updated_at DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_life_experiment_feedback_period ON life_experiment_feedback(local_user_id, local_date, experiment_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_life_experiment_rollups_user_period ON life_experiment_rollups(local_user_id, source_week_start, source_week_end, updated_at DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_weekly_snapshots_period ON weekly_snapshots(week_start, week_end)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_journey_snapshots_period ON journey_snapshots(snapshot_date)',
    );
  }

  Future<void> _createTraceLinkTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS trace_links (
        id TEXT PRIMARY KEY,
        local_user_id TEXT NOT NULL DEFAULT 'local',
        source_type TEXT NOT NULL,
        source_id TEXT NOT NULL,
        target_type TEXT NOT NULL,
        target_id TEXT NOT NULL,
        relation_type TEXT NOT NULL,
        weight REAL NOT NULL DEFAULT 1.0,
        status TEXT NOT NULL DEFAULT 'active',
        metadata_json TEXT NOT NULL DEFAULT '{}',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_trace_links_source ON trace_links(source_type, source_id, relation_type, status)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_trace_links_target ON trace_links(target_type, target_id, relation_type, status)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_trace_links_unique ON trace_links(source_type, source_id, target_type, target_id, relation_type)',
    );
  }

  Future<void> _addCacheVersioningColumns(Database db) async {
    for (final table in const [
      'daily_snapshots',
      'weekly_snapshots',
      'journey_snapshots',
      'monthly_snapshots',
    ]) {
      await _addColumnIfNeeded(
        db,
        table,
        'schema_version INTEGER NOT NULL DEFAULT 1',
      );
      await _addColumnIfNeeded(
        db,
        table,
        "pipeline_version TEXT NOT NULL DEFAULT 'v4_p1_06'",
      );
      await _addColumnIfNeeded(db, table, 'prompt_version TEXT');
      await _addColumnIfNeeded(db, table, 'model_version TEXT');
      await _addColumnIfNeeded(
        db,
        table,
        'dirty INTEGER NOT NULL DEFAULT 0',
      );
      await _addColumnIfNeeded(
        db,
        table,
        'is_stale INTEGER NOT NULL DEFAULT 0',
      );
      await _addColumnIfNeeded(db, table, 'stale_reason TEXT');
      await _addColumnIfNeeded(db, table, 'invalidated_at TEXT');
    }

    await _addColumnIfNeeded(
      db,
      'reflection_results',
      'dirty INTEGER NOT NULL DEFAULT 0',
    );
    await _addColumnIfNeeded(
      db,
      'reflection_results',
      'is_stale INTEGER NOT NULL DEFAULT 0',
    );
    await _addColumnIfNeeded(db, 'reflection_results', 'stale_reason TEXT');
    await _addColumnIfNeeded(db, 'reflection_results', 'invalidated_at TEXT');
  }

  Future<void> _addExperimentCandidateInvalidationColumns(Database db) async {
    await _addColumnIfNeeded(
      db,
      'experiment_candidates',
      'dirty INTEGER NOT NULL DEFAULT 0',
    );
    await _addColumnIfNeeded(
      db,
      'experiment_candidates',
      'is_stale INTEGER NOT NULL DEFAULT 0',
    );
    await _addColumnIfNeeded(db, 'experiment_candidates', 'stale_reason TEXT');
    await _addColumnIfNeeded(
        db, 'experiment_candidates', 'invalidated_at TEXT');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_experiment_candidates_stale ON experiment_candidates(local_user_id, source_week_start, dirty, is_stale, status)',
    );
  }

  Future<void> _addLifeExperimentRollupInvalidationColumns(Database db) async {
    await _addColumnIfNeeded(
      db,
      'life_experiment_rollups',
      'dirty INTEGER NOT NULL DEFAULT 0',
    );
    await _addColumnIfNeeded(
      db,
      'life_experiment_rollups',
      'is_stale INTEGER NOT NULL DEFAULT 0',
    );
    await _addColumnIfNeeded(
      db,
      'life_experiment_rollups',
      'stale_reason TEXT',
    );
    await _addColumnIfNeeded(
      db,
      'life_experiment_rollups',
      'invalidated_at TEXT',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_life_experiment_rollups_stale ON life_experiment_rollups(local_user_id, source_week_start, dirty, is_stale)',
    );
  }

  Future<void> _createCandidatePlanningTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS candidate_groups (
        id TEXT PRIMARY KEY,
        local_user_id TEXT NOT NULL DEFAULT 'local',
        candidate_kind TEXT NOT NULL,
        period_start TEXT NOT NULL,
        period_end TEXT NOT NULL,
        source_hash TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'ready',
        required_signal_count INTEGER NOT NULL DEFAULT 3,
        eligible_signal_count INTEGER NOT NULL DEFAULT 0,
        dirty INTEGER NOT NULL DEFAULT 0,
        is_stale INTEGER NOT NULL DEFAULT 0,
        stale_reason TEXT,
        invalidated_at TEXT,
        generation_started_at TEXT,
        generation_finished_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_candidate_groups_source ON candidate_groups(local_user_id, candidate_kind, period_start, source_hash)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_candidate_groups_read ON candidate_groups(local_user_id, candidate_kind, period_start, status, updated_at DESC)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS micro_action_candidates (
        id TEXT PRIMARY KEY,
        candidate_group_id TEXT NOT NULL,
        local_user_id TEXT NOT NULL DEFAULT 'local',
        local_date TEXT NOT NULL,
        rank INTEGER NOT NULL,
        title TEXT NOT NULL,
        reason TEXT NOT NULL DEFAULT '',
        difficulty TEXT NOT NULL DEFAULT 'very_light',
        linked_signal_card_ids_json TEXT NOT NULL DEFAULT '[]',
        focus_domain_ids_json TEXT NOT NULL DEFAULT '[]',
        status TEXT NOT NULL DEFAULT 'generated',
        decision_status TEXT NOT NULL DEFAULT 'undecided'
          CHECK(decision_status IN ('undecided', 'considering', 'adopted')),
        adopted_micro_action_id TEXT,
        source_hash TEXT NOT NULL,
        dirty INTEGER NOT NULL DEFAULT 0,
        is_stale INTEGER NOT NULL DEFAULT 0,
        stale_reason TEXT,
        invalidated_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_micro_action_candidates_group ON micro_action_candidates(candidate_group_id, rank)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_micro_action_candidates_read ON micro_action_candidates(local_user_id, local_date, status, dirty, is_stale, rank)',
    );
  }

  /// Dedicated, bounded storage for an explicitly adopted deepening
  /// observation. This intentionally does not reuse the legacy observations
  /// table: a plan is a future-week question and must never become a Signal or
  /// an implicit task.
  Future<void> _createDeepeningObservationPlanTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS observation_plans (
        id TEXT PRIMARY KEY,
        local_user_id TEXT NOT NULL DEFAULT 'local',
        source_week_start TEXT NOT NULL,
        source_week_end TEXT NOT NULL,
        target_week_start TEXT NOT NULL,
        question TEXT NOT NULL,
        what_to_watch_json TEXT NOT NULL DEFAULT '[]',
        source_signal_card_ids_json TEXT NOT NULL DEFAULT '[]',
        source_hash TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'planned',
        result_status TEXT,
        result_summary TEXT,
        result_signal_card_ids_json TEXT NOT NULL DEFAULT '[]',
        created_at TEXT NOT NULL,
        resolved_at TEXT
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_observation_plans_source_week ON observation_plans(local_user_id, source_week_start)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_observation_plans_target_week ON observation_plans(local_user_id, target_week_start, status)',
    );
  }

  Future<void> _addCandidatePlanningColumns(Database db) async {
    await _addColumnIfNeeded(
        db, 'experiment_candidates', 'candidate_group_id TEXT');
    await _addColumnIfNeeded(
      db,
      'experiment_candidates',
      'candidate_rank INTEGER NOT NULL DEFAULT 1',
    );
    await _addColumnIfNeeded(db, 'experiment_candidates', 'source_hash TEXT');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_experiment_candidates_group ON experiment_candidates(candidate_group_id, candidate_rank)',
    );

    for (final definition in const [
      "local_user_id TEXT NOT NULL DEFAULT 'local'",
      'origin_candidate_id TEXT',
      'adopted_at TEXT',
      'progress_start_date TEXT',
      'progress_end_date TEXT',
      "linked_signal_card_ids_json TEXT NOT NULL DEFAULT '[]'",
      'source_changed INTEGER NOT NULL DEFAULT 0',
      'source_change_reason TEXT',
    ]) {
      await _addColumnIfNeeded(db, 'micro_actions', definition);
    }
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_micro_actions_user_progress ON micro_actions(local_user_id, progress_start_date, progress_end_date, status)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_micro_actions_origin_candidate ON micro_actions(origin_candidate_id) WHERE origin_candidate_id IS NOT NULL',
    );

    for (final definition in const [
      'origin_candidate_id TEXT',
      'adopted_at TEXT',
      'progress_start_date TEXT',
      'progress_end_date TEXT',
      'source_changed INTEGER NOT NULL DEFAULT 0',
      'source_change_reason TEXT',
    ]) {
      await _addColumnIfNeeded(db, 'life_experiments', definition);
    }
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_life_experiments_origin_candidate ON life_experiments(origin_candidate_id) WHERE origin_candidate_id IS NOT NULL',
    );

    await _addColumnIfNeeded(
      db,
      'micro_action_feedback',
      'updated_at TEXT',
    );
    await _addColumnIfNeeded(
      db,
      'micro_action_feedback',
      'is_valid INTEGER NOT NULL DEFAULT 1',
    );
    await _addColumnIfNeeded(
      db,
      'life_experiment_feedback',
      'is_valid INTEGER NOT NULL DEFAULT 1',
    );
  }

  /// v38 separates the user's explicit candidate decision from the existing
  /// generation/adoption lifecycle string. Keeping this additive preserves
  /// old backups and every legacy status value.
  Future<void> _addCandidateDecisionColumns(Database db) async {
    await _addColumnIfNeeded(
      db,
      'micro_action_candidates',
      "decision_status TEXT NOT NULL DEFAULT 'undecided'",
    );
    await _addColumnIfNeeded(
      db,
      'experiment_candidates',
      "decision_status TEXT NOT NULL DEFAULT 'undecided'",
    );
    final microColumns = await _tableColumnNames(
      db,
      'micro_action_candidates',
    );
    if (microColumns.containsAll(
      const {'local_user_id', 'decision_status', 'updated_at'},
    )) {
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_micro_action_candidates_decision
        ON micro_action_candidates(local_user_id, decision_status, updated_at DESC)
      ''');
    }
    final experimentColumns = await _tableColumnNames(
      db,
      'experiment_candidates',
    );
    if (experimentColumns.containsAll(
      const {'local_user_id', 'decision_status', 'updated_at'},
    )) {
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_experiment_candidates_decision
        ON experiment_candidates(local_user_id, decision_status, updated_at DESC)
      ''');
    }
  }

  Future<void> _backfillCandidateDecisions(Database db) async {
    final microColumns = await _tableColumnNames(
      db,
      'micro_action_candidates',
    );
    if (microColumns.containsAll(const {
      'status',
      'decision_status',
      'adopted_micro_action_id',
    })) {
      await db.rawUpdate('''
        UPDATE micro_action_candidates
        SET decision_status = CASE
          WHEN adopted_micro_action_id IS NOT NULL
            OR LOWER(COALESCE(status, '')) IN ('adopted', 'planned', 'active')
            THEN 'adopted'
          WHEN LOWER(COALESCE(status, '')) IN
            ('considering', 'observing', 'reviewing', 'saved')
            THEN 'considering'
          WHEN decision_status IN ('undecided', 'considering', 'adopted')
            THEN decision_status
          ELSE 'undecided'
        END
      ''');
    }
    final experimentColumns = await _tableColumnNames(
      db,
      'experiment_candidates',
    );
    if (experimentColumns.containsAll(const {
      'status',
      'decision_status',
      'adopted_experiment_id',
    })) {
      await db.rawUpdate('''
        UPDATE experiment_candidates
        SET decision_status = CASE
          WHEN adopted_experiment_id IS NOT NULL
            OR LOWER(COALESCE(status, '')) IN
              ('adopted', 'planned', 'active')
            THEN 'adopted'
          WHEN LOWER(COALESCE(status, '')) IN
            ('considering', 'observing', 'reviewing', 'saved')
            THEN 'considering'
          WHEN decision_status IN ('undecided', 'considering', 'adopted')
            THEN decision_status
          ELSE 'undecided'
        END
      ''');
    }
  }

  Future<void> _createPlanContentVersionTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS plan_content_versions (
        id TEXT PRIMARY KEY,
        local_user_id TEXT NOT NULL DEFAULT 'local',
        object_kind TEXT NOT NULL CHECK(object_kind IN ('quick_try', 'goal')),
        object_id TEXT NOT NULL,
        version_no INTEGER NOT NULL CHECK(version_no >= 1),
        effective_from_local_date TEXT NOT NULL,
        content_json TEXT NOT NULL DEFAULT '{}',
        created_at TEXT NOT NULL,
        UNIQUE(local_user_id, object_kind, object_id, version_no)
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_plan_content_versions_resolve
      ON plan_content_versions(
        local_user_id,
        object_kind,
        object_id,
        effective_from_local_date DESC,
        version_no DESC
      )
    ''');
  }

  Future<void> _backfillPlanContentVersions(Database db) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final microActionColumns = await _tableColumnNames(db, 'micro_actions');
    final microActions = microActionColumns.containsAll(const {
      'id',
      'title',
      'created_at',
    })
        ? await db.query('micro_actions')
        : const <Map<String, Object?>>[];
    for (final row in microActions) {
      if (!_isAdoptedPlanRow(row, goal: false)) continue;
      final objectId = (row['id'] as String?)?.trim() ?? '';
      final effectiveDate = _firstPlanLocalDate(row, const [
        'progress_start_date',
        'planned_date',
        'adopted_at',
        'created_at',
      ]);
      if (objectId.isEmpty || effectiveDate == null) continue;
      final localUserId =
          (row['local_user_id'] as String?)?.trim().isNotEmpty == true
              ? (row['local_user_id'] as String).trim()
              : 'local';
      await db.insert(
        'plan_content_versions',
        {
          'id': 'plan_v1_quick_try_$objectId',
          'local_user_id': localUserId,
          'object_kind': 'quick_try',
          'object_id': objectId,
          'version_no': 1,
          'effective_from_local_date': effectiveDate,
          'content_json': jsonEncode({
            'title': row['title'],
            'reason': row['reason'],
            'action_type': row['action_type'],
            'difficulty': row['difficulty'],
            'planned_duration_minutes': row['planned_duration_minutes'] ?? 10,
            'planned_date': row['planned_date'],
            'planned_time': row['planned_time'],
          }),
          'created_at': (row['created_at'] as String?) ?? now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    final goalColumns = await _tableColumnNames(db, 'life_experiments');
    final goals = goalColumns.containsAll(const {
      'id',
      'title',
      'hypothesis',
      'suggested_action',
      'created_at',
    })
        ? await db.query('life_experiments')
        : const <Map<String, Object?>>[];
    for (final row in goals) {
      if (!_isAdoptedPlanRow(row, goal: true)) continue;
      final objectId = (row['id'] as String?)?.trim() ?? '';
      final effectiveDate = _firstPlanLocalDate(row, const [
        'progress_start_date',
        'source_week_start',
        'adopted_at',
        'created_at',
      ]);
      if (objectId.isEmpty || effectiveDate == null) continue;
      final localUserId =
          (row['local_user_id'] as String?)?.trim().isNotEmpty == true
              ? (row['local_user_id'] as String).trim()
              : 'local';
      await db.insert(
        'plan_content_versions',
        {
          'id': 'plan_v1_goal_$objectId',
          'local_user_id': localUserId,
          'object_kind': 'goal',
          'object_id': objectId,
          'version_no': 1,
          'effective_from_local_date': effectiveDate,
          'content_json': jsonEncode({
            'title': row['title'],
            'hypothesis': row['hypothesis'],
            'suggested_action': row['suggested_action'],
            'focus_area_id': row['focus_area_id'],
            'pattern_id': row['pattern_id'],
            'feedback_pattern_id': row['feedback_pattern_id'],
            'icon_asset_id': row['icon_asset_id'],
            'planned_frequency': row['planned_frequency'],
            'planned_duration_minutes': row['planned_duration_minutes'],
            'planned_total_days': row['planned_total_days'],
          }),
          'created_at': (row['created_at'] as String?) ?? now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<Set<String>> _tableColumnNames(Database db, String table) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    return rows
        .map((row) => row['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toSet();
  }

  bool _isAdoptedPlanRow(
    Map<String, Object?> row, {
    required bool goal,
  }) {
    final adoptedAt = row['adopted_at']?.toString().trim() ?? '';
    final candidateId = row['origin_candidate_id']?.toString().trim() ?? '';
    if (adoptedAt.isNotEmpty || candidateId.isNotEmpty) return true;

    final status = row['status']?.toString().trim().toLowerCase() ?? '';
    final adoptedStatuses = goal
        ? const {
            'accepted',
            'saved',
            'active',
            'adjusted',
            'done',
            'completed',
            'paused',
            'stopped',
            'archived',
            'effective',
            'not_effective',
          }
        : const {
            'accepted',
            'active',
            'adjusted',
            'done',
            'completed',
            'paused',
            'stopped',
            'archived',
          };
    return adoptedStatuses.contains(status);
  }

  String? _firstPlanLocalDate(
    Map<String, Object?> row,
    List<String> columns,
  ) {
    for (final column in columns) {
      final normalized = _normalizePlanLocalDate(row[column]);
      if (normalized != null) return normalized;
    }
    return null;
  }

  String? _normalizePlanLocalDate(Object? raw) {
    final value = raw?.toString().trim() ?? '';
    if (value.isEmpty) return null;
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return DateTime.tryParse(value) == null ? null : value;
    }
    final parsed = DateTime.tryParse(value)?.toLocal();
    if (parsed == null) return null;
    return '${parsed.year.toString().padLeft(4, '0')}-'
        '${parsed.month.toString().padLeft(2, '0')}-'
        '${parsed.day.toString().padLeft(2, '0')}';
  }

  Future<void> _backfillCandidatePlanningData(Database db) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await db.rawUpdate('''
      UPDATE micro_action_feedback
      SET updated_at = COALESCE(updated_at, created_at)
      WHERE updated_at IS NULL OR updated_at = ''
    ''');
    await db.rawUpdate('''
      UPDATE micro_actions
      SET adopted_at = COALESCE(adopted_at, created_at),
          progress_start_date = COALESCE(progress_start_date, planned_date),
          progress_end_date = CASE
            WHEN progress_end_date IS NOT NULL THEN progress_end_date
            WHEN status IN ('done', 'completed') AND planned_date IS NOT NULL
              THEN date(planned_date, '+6 days')
            ELSE NULL
          END
      WHERE status IN ('accepted', 'active', 'done', 'completed')
    ''');
    await db.rawUpdate('''
      UPDATE life_experiments
      SET adopted_at = COALESCE(adopted_at, created_at),
          progress_start_date = COALESCE(progress_start_date, source_week_start),
          progress_end_date = COALESCE(progress_end_date, source_week_end)
      WHERE status IN ('saved', 'active', 'done', 'completed')
    ''');
    await db.rawUpdate('''
      UPDATE experiment_candidates
      SET candidate_group_id = COALESCE(
            candidate_group_id,
            'legacy_exp_group_' || replace(local_user_id || '_' || source_week_start, '-', '_')
          ),
          candidate_rank = CASE WHEN candidate_rank < 1 THEN 1 ELSE candidate_rank END,
          source_hash = COALESCE(source_hash, 'legacy')
      WHERE candidate_group_id IS NULL OR source_hash IS NULL
    ''');
    await db.rawInsert('''
      INSERT OR IGNORE INTO candidate_groups (
        id,
        local_user_id,
        candidate_kind,
        period_start,
        period_end,
        source_hash,
        status,
        required_signal_count,
        eligible_signal_count,
        dirty,
        is_stale,
        stale_reason,
        invalidated_at,
        generation_started_at,
        generation_finished_at,
        created_at,
        updated_at
      )
      SELECT
        candidate_group_id,
        local_user_id,
        'life_experiment',
        source_week_start,
        source_week_end,
        COALESCE(source_hash, 'legacy'),
        CASE
          WHEN MAX(is_stale) = 1 OR MAX(dirty) = 1 THEN 'stale'
          ELSE 'ready'
        END,
        3,
        3,
        MAX(dirty),
        MAX(is_stale),
        MAX(stale_reason),
        MAX(invalidated_at),
        NULL,
        MAX(updated_at),
        MIN(created_at),
        MAX(updated_at)
      FROM experiment_candidates
      WHERE candidate_group_id IS NOT NULL
      GROUP BY candidate_group_id, local_user_id, source_week_start,
               source_week_end, source_hash
    ''');
    // Keep the migration deterministic while recording when an old row was
    // first made readable by the new candidate planning projection.
    await db.rawUpdate(
      '''
      UPDATE experiment_candidates
      SET updated_at = COALESCE(updated_at, ?)
      WHERE updated_at IS NULL OR updated_at = ''
      ''',
      [now],
    );
  }

  Future<void> _createSignalLibraryTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS signal_library_actions (
        id TEXT PRIMARY KEY,
        pattern_id TEXT NOT NULL,
        action TEXT NOT NULL,
        is_private INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_signal_library_actions_pattern ON signal_library_actions(pattern_id, updated_at DESC)',
    );
  }

  Future<void> _createPhase3PlusTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS schedule_signals (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        schedule_status TEXT NOT NULL DEFAULT 'unscheduled',
        schedule_type TEXT NOT NULL DEFAULT 'manual',
        source_type TEXT NOT NULL DEFAULT 'manual_schedule',
        start_time TEXT,
        end_time TEXT,
        local_date TEXT,
        anchor_date TEXT NOT NULL,
        date_precision TEXT NOT NULL DEFAULT 'none',
        time_precision TEXT NOT NULL DEFAULT 'none',
        scene TEXT,
        note TEXT,
        expected_energy_load TEXT,
        actual_energy_load TEXT,
        pre_mood TEXT,
        post_mood TEXT,
        friction TEXT,
        recovery_signal TEXT,
        interruption_level TEXT,
        buffer_before_minutes INTEGER,
        buffer_after_minutes INTEGER,
        reminder_enabled INTEGER NOT NULL DEFAULT 0,
        reminder_time TEXT,
        feedback_status TEXT NOT NULL DEFAULT 'none',
        linked_signal_card_ids_json TEXT NOT NULL DEFAULT '[]',
        linked_experiment_id TEXT,
        linked_goal_id TEXT,
        linked_goal_task_instance_id TEXT,
        included_in_weekly INTEGER NOT NULL DEFAULT 0,
        included_in_journey INTEGER NOT NULL DEFAULT 0,
        privacy_level TEXT NOT NULL DEFAULT 'private',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_schedule_signals_date ON schedule_signals(local_date, anchor_date, updated_at DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_schedule_signals_status ON schedule_signals(schedule_status, feedback_status)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS life_experiment_strategies (
        id TEXT PRIMARY KEY,
        local_user_id TEXT NOT NULL,
        target_pattern TEXT NOT NULL,
        reason TEXT NOT NULL,
        evidence_json TEXT NOT NULL DEFAULT '{}',
        expected_change TEXT,
        scope TEXT,
        do_not_change TEXT,
        source_signal_card_ids_json TEXT NOT NULL DEFAULT '[]',
        source_schedule_signal_ids_json TEXT NOT NULL DEFAULT '[]',
        source_goal_ids_json TEXT NOT NULL DEFAULT '[]',
        source_weekly_snapshot_id TEXT,
        confidence_level TEXT NOT NULL DEFAULT 'medium',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS life_experiment_feedback (
        id TEXT PRIMARY KEY,
        experiment_id TEXT NOT NULL,
        feedback_date TEXT NOT NULL,
        happened TEXT NOT NULL DEFAULT 'unknown',
        trigger_context TEXT,
        difficulty TEXT,
        actual_duration_minutes INTEGER,
        before_state TEXT,
        after_state TEXT,
        effect TEXT,
        friction_after TEXT,
        recovery_after TEXT,
        comment TEXT,
        next_adjustment TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_life_experiment_feedback_exp ON life_experiment_feedback(experiment_id, feedback_date DESC)',
    );
    await _addColumnIfNeeded(
        db, 'life_experiment_feedback', 'local_user_id TEXT');
    await _addColumnIfNeeded(db, 'life_experiment_feedback', 'local_date TEXT');
    await _addColumnIfNeeded(
        db, 'life_experiment_feedback', 'completion_status TEXT');
    await _addColumnIfNeeded(
        db, 'life_experiment_feedback', 'helpfulness_score INTEGER');
    await _addColumnIfNeeded(
        db, 'life_experiment_feedback', 'feedback_text TEXT');
    await _addColumnIfNeeded(
        db, 'life_experiment_feedback', 'condition_tags_json TEXT');
    await _addColumnIfNeeded(
        db, 'life_experiment_feedback', 'duration_minutes INTEGER');
    await _addColumnIfNeeded(db, 'life_experiment_feedback', 'time_slot TEXT');
    await _addColumnIfNeeded(db, 'life_experiment_feedback', 'pattern_id TEXT');
    await _addColumnIfNeeded(
        db, 'life_experiment_feedback', 'feedback_pattern_id TEXT');
    await _addColumnIfNeeded(
        db, 'life_experiment_feedback', 'focus_area_id TEXT');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_life_experiment_feedback_user_date ON life_experiment_feedback(local_user_id, local_date)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS goals (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        goal_type TEXT NOT NULL DEFAULT 'personal',
        period TEXT NOT NULL DEFAULT 'weekly',
        desired_frequency TEXT,
        desired_duration_minutes INTEGER,
        deadline TEXT,
        reminder_enabled INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'active',
        privacy_level TEXT NOT NULL DEFAULT 'private',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS goal_plans (
        id TEXT PRIMARY KEY,
        goal_id TEXT NOT NULL,
        plan_level TEXT NOT NULL DEFAULT 'standard',
        minimum_task TEXT NOT NULL,
        standard_task TEXT NOT NULL,
        full_task TEXT NOT NULL,
        frequency TEXT,
        time_suggestion TEXT,
        user_adjustment TEXT,
        adopted INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS goal_task_instances (
        id TEXT PRIMARY KEY,
        goal_id TEXT NOT NULL,
        goal_plan_id TEXT,
        title TEXT NOT NULL,
        local_date TEXT NOT NULL,
        planned_time TEXT,
        duration_minutes INTEGER,
        schedule_signal_id TEXT,
        status TEXT NOT NULL DEFAULT 'suggested',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_goal_task_instances_date ON goal_task_instances(local_date, status)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS goal_feedback (
        id TEXT PRIMARY KEY,
        goal_id TEXT NOT NULL,
        goal_task_instance_id TEXT,
        feedback_date TEXT NOT NULL,
        happened TEXT NOT NULL DEFAULT 'unknown',
        effort_level TEXT,
        effect TEXT,
        comment TEXT,
        next_adjustment TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_goal_feedback_goal ON goal_feedback(goal_id, feedback_date DESC)',
    );
  }

  Future<void> _createAiActionTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ai_judgements (
        id TEXT PRIMARY KEY,
        source_signal_card_ids_json TEXT NOT NULL DEFAULT '[]',
        source_schedule_signal_ids_json TEXT NOT NULL DEFAULT '[]',
        source_goal_task_instance_ids_json TEXT NOT NULL DEFAULT '[]',
        local_date TEXT NOT NULL,
        judgement_text TEXT NOT NULL,
        evidence_text TEXT,
        prediction_kind TEXT NOT NULL DEFAULT 'inferred_signal',
        predicted_signal_text TEXT,
        suggested_pattern TEXT,
        suggested_life_chain_stage TEXT,
        confidence_level TEXT NOT NULL DEFAULT 'low',
        status TEXT NOT NULL DEFAULT 'suggested',
        user_adjustment_text TEXT,
        confirmation_note TEXT,
        linked_micro_action_id TEXT,
        included_in_weekly INTEGER NOT NULL DEFAULT 0,
        included_in_journey INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ai_judgements_date ON ai_judgements(local_date, updated_at DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ai_judgements_status ON ai_judgements(status, local_date)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS micro_actions (
        id TEXT PRIMARY KEY,
        judgement_id TEXT,
        title TEXT NOT NULL,
        reason TEXT,
        action_type TEXT NOT NULL DEFAULT 'today_try',
        difficulty TEXT NOT NULL DEFAULT 'very_light',
        planned_date TEXT,
        planned_time TEXT,
        linked_schedule_signal_id TEXT,
        linked_goal_id TEXT,
        linked_life_experiment_id TEXT,
        status TEXT NOT NULL DEFAULT 'suggested',
        feedback_status TEXT NOT NULL DEFAULT 'none',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_micro_actions_date ON micro_actions(planned_date, status)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_micro_actions_judgement ON micro_actions(judgement_id)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS micro_action_feedback (
        id TEXT PRIMARY KEY,
        micro_action_id TEXT NOT NULL,
        local_date TEXT NOT NULL,
        happened TEXT NOT NULL DEFAULT 'unknown',
        effect TEXT,
        difficulty TEXT,
        user_note TEXT,
        next_adjustment TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_micro_action_feedback_action ON micro_action_feedback(micro_action_id, local_date DESC)',
    );
  }

  Future<void> _addColumnIfNeeded(
    Database db,
    String tableName,
    String columnDefinition,
  ) async {
    try {
      await db.execute(
        'ALTER TABLE $tableName ADD COLUMN $columnDefinition',
      );
    } catch (_) {
      // 列已存在时忽略
    }
  }

  Future<String> _resolveDbPath() async {
    if (dbPathOverride != null && dbPathOverride!.trim().isNotEmpty) {
      return dbPathOverride!;
    }

    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, _databaseName);
  }
}
