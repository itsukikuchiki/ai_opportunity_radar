import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  static const _databaseName = 'ai_opportunity_radar_local.db';
  static const _databaseVersion = 12;

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
        status TEXT NOT NULL DEFAULT 'suggested',
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
