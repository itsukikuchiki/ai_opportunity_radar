import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  static const _databaseName = 'ai_opportunity_radar_local.db';
  static const _databaseVersion = 6;

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
            await _addColumnIfNeeded(db, 'captures', 'ai_intent_tags_json TEXT');
          }

          if (oldVersion < 5) {
            await _addColumnIfNeeded(db, 'weekly_snapshots', 'chart_data_json TEXT');
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

    await db.execute(
      'CREATE INDEX idx_captures_created_at ON captures(created_at DESC)',
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
