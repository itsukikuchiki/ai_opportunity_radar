import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  static const _databaseName = 'ai_opportunity_radar_local.db';
  static const _databaseVersion = 1;

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

          await db.execute(
            'CREATE INDEX idx_captures_created_at ON captures(created_at DESC)',
          );
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

  Future<String> _resolveDbPath() async {
    if (dbPathOverride != null && dbPathOverride!.trim().isNotEmpty) {
      return dbPathOverride!;
    }

    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, _databaseName);
  }
}
