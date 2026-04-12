import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  static const _databaseName = 'ai_opportunity_radar_local.db';
  static const _databaseVersion = 3;

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

    await db.execute(
      'CREATE INDEX idx_captures_created_at ON captures(created_at DESC)',
    );
  }

  Future<String> _resolveDbPath() async {
    if (dbPathOverride != null && dbPathOverride!.trim().isNotEmpty) {
      return dbPathOverride!;
    }

    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, _databaseName);
  }
}
