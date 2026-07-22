import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../debug/legacy_fallback_monitor.dart';
import '../local/local_database.dart';
import '../notifications/signal_reminder_repository.dart';

class BackupBundleRepository {
  static const int schemaVersion = 6;

  final LocalDatabase localDatabase;
  final SharedPreferences preferences;
  final SignalReminderRepository? signalReminderRepository;

  const BackupBundleRepository({
    required this.localDatabase,
    required this.preferences,
    this.signalReminderRepository,
  });

  Future<Map<String, dynamic>> exportBundle({
    required String localUserId,
    required String deviceId,
  }) async {
    LegacyFallbackMonitor.record(LegacyFallbackMonitor.backupExport);
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
    LegacyFallbackMonitor.record(LegacyFallbackMonitor.backupImport);
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
        final supportedColumns = await _tableColumnNames(txn, table);
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
          // Older bundles simply lack additive candidate-decision and effect
          // review fields, so database defaults apply. Conversely, filtering
          // unknown columns lets a newer additive bundle restore safely into
          // this schema.
          final compatibleRow = <String, Object?>{
            for (final entry in row.entries)
              if (supportedColumns.contains(entry.key)) entry.key: entry.value,
          };
          if (compatibleRow.isEmpty) {
            skipped += 1;
            continue;
          }
          await txn.insert(
            table,
            compatibleRow,
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
    // Reminders are local-only and must not survive a local-data/account
    // deletion. Clearing through the repository cancels native notifications
    // before removing the persisted rule set.
    await (signalReminderRepository ??
            SignalReminderRepository(preferences: preferences))
        .clearAll();
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

  Future<Set<String>> _tableColumnNames(
    DatabaseExecutor db,
    String table,
  ) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    return rows
        .map((row) => row['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toSet();
  }

  Map<String, Object?> _exportPreferences() {
    const keys = [
      'focus_domain_ids',
      'selected_focus_domains',
      'repeat_area_preference',
      'selected_repeat_area',
      'response_style_preference',
      'me_profile_display_name',
      'me_life_direction',
      'me_life_direction_created_at',
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
      'focus_domain_ids',
      'selected_focus_domains',
      'repeat_area_preference',
      'selected_repeat_area',
      'response_style_preference',
      'external_calendar_abstract_hints_json',
      'external_health_abstract_hints_json',
      'installation_date',
      'local_app_started_date',
      'me_profile_photo_path',
      'me_profile_display_name',
      'me_life_direction',
      'me_life_direction_created_at',
      'onboarding_completed',
      'onboardingCompleted',
      SignalReminderRepository.preferencesKey,
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
  'signal_tombstones',
  'signal_sync_identity',
  'signal_processing_state',
  'signal_analysis_policy',
  'daily_snapshots',
  'weekly_snapshots',
  'journey_snapshots',
  'monthly_snapshots',
  'reflection_results',
  'observation_plans',
  'pipeline_runs',
  'candidate_groups',
  'micro_action_candidates',
  'micro_actions',
  'micro_action_feedback',
  'micro_action_review_events',
  'experiment_candidates',
  'life_experiments',
  'plan_content_versions',
  'life_experiment_strategies',
  'life_experiment_feedback',
  'life_experiment_lifecycle_events',
  'life_experiment_rollups',
  'schedule_signals',
  'goals',
  'goal_plans',
  'goal_task_instances',
  'goal_feedback',
  'ai_judgements',
  'observations',
  'observation_signal_links',
  'trace_links',
  'signal_library_actions',
];

const _localDeleteTables = [
  'signal_library_actions',
  'trace_links',
  'observation_signal_links',
  'observations',
  'ai_judgements',
  'goal_feedback',
  'goal_task_instances',
  'goal_plans',
  'goals',
  'schedule_signals',
  'life_experiment_rollups',
  'life_experiment_lifecycle_events',
  'life_experiment_feedback',
  'life_experiment_strategies',
  'plan_content_versions',
  'life_experiments',
  'experiment_candidates',
  'micro_action_feedback',
  'micro_action_review_events',
  'micro_actions',
  'micro_action_candidates',
  'candidate_groups',
  'observation_plans',
  'pipeline_runs',
  'reflection_results',
  'monthly_snapshots',
  'journey_snapshots',
  'weekly_snapshots',
  'daily_snapshots',
  'signal_analysis_policy',
  'signal_processing_state',
  'signal_sync_identity',
  'signal_tombstones',
  'signal_card_drafts',
  'signal_cards',
  'captures',
];
