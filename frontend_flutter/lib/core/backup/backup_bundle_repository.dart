import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../local/local_database.dart';

class BackupBundleRepository {
  static const int schemaVersion = 1;

  final LocalDatabase localDatabase;
  final SharedPreferences preferences;

  const BackupBundleRepository({
    required this.localDatabase,
    required this.preferences,
  });

  Future<Map<String, dynamic>> exportBundle({
    required String localUserId,
    required String deviceId,
  }) async {
    final db = await localDatabase.database;
    final tables = <String, List<Map<String, Object?>>>{};
    for (final table in _backupTables) {
      tables[table] = await _exportTable(db, table);
    }

    final counts = <String, int>{
      for (final entry in tables.entries) entry.key: entry.value.length,
    };

    return {
      'schema_version': schemaVersion,
      'backup_version': DateTime.now().toUtc().toIso8601String(),
      'local_user_id': localUserId,
      'device_id': deviceId,
      'generated_at': DateTime.now().toUtc().toIso8601String(),
      'tables': tables,
      'preferences': _exportPreferences(),
      'counts': counts,
    };
  }

  Future<BackupRestoreResult> importBundle(
    Map<String, dynamic> bundle, {
    BackupRestoreMode mode = BackupRestoreMode.merge,
  }) async {
    final db = await localDatabase.database;
    final rawTables = bundle['tables'];
    if (rawTables is! Map) {
      return const BackupRestoreResult(importedRows: 0, skippedRows: 0);
    }

    var imported = 0;
    var skipped = 0;

    await db.transaction((txn) async {
      if (mode == BackupRestoreMode.replaceLocal) {
        for (final table in _backupTables.reversed) {
          await txn.delete(table);
        }
      }

      for (final table in _backupTables) {
        final rawRows = rawTables[table];
        if (rawRows is! List) continue;
        for (final rawRow in rawRows) {
          if (rawRow is! Map) {
            skipped += 1;
            continue;
          }
          final row = rawRow.map((key, value) => MapEntry('$key', value));
          if (table == 'signal_cards' &&
              row['privacy_level']?.toString() == 'local_only') {
            skipped += 1;
            continue;
          }
          await txn.insert(
            table,
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          imported += 1;
        }
      }
    });

    await _importPreferences(bundle['preferences']);
    return BackupRestoreResult(importedRows: imported, skippedRows: skipped);
  }

  Future<int> deleteAllLocalData() async {
    final db = await localDatabase.database;
    var deletedRows = 0;
    await db.transaction((txn) async {
      for (final table in _localDeleteTables) {
        deletedRows += await txn.delete(table);
      }
    });
    await _deleteLocalAccountPreferences();
    return deletedRows;
  }

  Future<List<Map<String, Object?>>> _exportTable(
    Database db,
    String table,
  ) {
    if (table == 'signal_cards') {
      return db.query(
        table,
        where: "privacy_level != ?",
        whereArgs: const ['local_only'],
      );
    }
    return db.query(table);
  }

  Map<String, Object?> _exportPreferences() {
    const keys = [
      'repeat_area_preference',
      'selected_repeat_area',
      'response_style_preference',
      'onboarding_completed',
    ];
    return {
      for (final key in keys)
        if (preferences.containsKey(key)) key: preferences.get(key),
    };
  }

  Future<void> _importPreferences(Object? raw) async {
    if (raw is! Map) return;
    for (final entry in raw.entries) {
      final key = entry.key.toString();
      final value = entry.value;
      if (value is String) {
        await preferences.setString(key, value);
      } else if (value is bool) {
        await preferences.setBool(key, value);
      } else if (value is int) {
        await preferences.setInt(key, value);
      } else if (value is double) {
        await preferences.setDouble(key, value);
      } else if (value is List) {
        await preferences.setStringList(
          key,
          value.map((item) => item.toString()).toList(),
        );
      }
    }
  }

  Future<void> _deleteLocalAccountPreferences() async {
    const keys = [
      'cloud_account_session_token',
      'cloud_account_id',
      'cloud_latest_backup_version',
      'local_user_id',
      'device_id',
      'repeat_area_preference',
      'selected_repeat_area',
      'response_style_preference',
      'onboarding_completed',
    ];
    for (final key in keys) {
      await preferences.remove(key);
    }
  }
}

enum BackupRestoreMode {
  merge,
  replaceLocal,
}

class BackupRestoreResult {
  final int importedRows;
  final int skippedRows;

  const BackupRestoreResult({
    required this.importedRows,
    required this.skippedRows,
  });
}

const _backupTables = [
  'captures',
  'signal_cards',
  'daily_snapshots',
  'weekly_snapshots',
  'journey_snapshots',
  'monthly_snapshots',
  'life_experiments',
  'life_experiment_strategies',
  'life_experiment_feedback',
  'schedule_signals',
  'goals',
  'goal_plans',
  'goal_task_instances',
  'goal_feedback',
  'signal_library_actions',
];

const _localDeleteTables = [
  'signal_library_actions',
  'goal_feedback',
  'goal_task_instances',
  'goal_plans',
  'goals',
  'schedule_signals',
  'life_experiment_feedback',
  'life_experiment_strategies',
  'life_experiments',
  'monthly_snapshots',
  'journey_snapshots',
  'weekly_snapshots',
  'daily_snapshots',
  'signal_card_drafts',
  'signal_cards',
  'captures',
];
