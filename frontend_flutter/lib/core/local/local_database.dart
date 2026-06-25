import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  static const _databaseName = 'ai_opportunity_radar_local.db';
  static const _databaseVersion = 15;

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
    await _createLifeExperimentTables(db);
    await _createSignalLibraryTables(db);
    await _createPhase3PlusTables(db);
    await _createAiActionTables(db);

    await db.execute(
      'CREATE INDEX idx_captures_created_at ON captures(created_at DESC)',
    );
  }

  Future<void> _createSignalCardTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS signal_cards (
        id TEXT PRIMARY KEY,
        signal_card_id TEXT,
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
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_signal_cards_local_date ON signal_cards(local_date DESC, created_at DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_signal_card_drafts_status ON signal_card_drafts(status, created_at ASC)',
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
    await _addColumnIfNeeded(db, 'life_experiments', 'difficulty TEXT');
    await _addColumnIfNeeded(
        db, 'life_experiments', 'linked_schedule_signal_ids_json TEXT');
    await _addColumnIfNeeded(
        db, 'life_experiments', 'linked_goal_ids_json TEXT');
    await _addColumnIfNeeded(db, 'life_experiments', 'review_result TEXT');
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
        suggested_pattern TEXT,
        suggested_life_chain_stage TEXT,
        confidence_level TEXT NOT NULL DEFAULT 'low',
        status TEXT NOT NULL DEFAULT 'suggested',
        user_adjustment_text TEXT,
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
