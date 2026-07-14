import 'dart:async';

import '../state/app_data_refresh_coordinator.dart';
import 'local_database.dart';

class CandidateInvalidationNotice {
  final LocalDatabase localDatabase;
  final String candidateKind;
  final String periodStart;
  final String periodEnd;

  const CandidateInvalidationNotice({
    required this.localDatabase,
    required this.candidateKind,
    required this.periodStart,
    required this.periodEnd,
  });
}

/// Process-local bridge from storage invalidation to an already-open
/// candidate surface. The database remains the source of truth; this stream
/// only removes the need to leave and re-enter a page before seeing `stale`.
class CandidateInvalidationBus {
  static final StreamController<CandidateInvalidationNotice> _controller =
      StreamController<CandidateInvalidationNotice>.broadcast();

  static Stream<CandidateInvalidationNotice> get stream => _controller.stream;

  static void publish(CandidateInvalidationNotice notice) {
    if (!_controller.isClosed) _controller.add(notice);
  }
}

class LocalCacheInvalidationRepository {
  final LocalDatabase localDatabase;

  const LocalCacheInvalidationRepository(this.localDatabase);

  Future<void> markSignalChanged({
    required String localDate,
    required String reason,
    Iterable<String> signalIds = const [],
  }) async {
    final parsed = DateTime.tryParse(localDate);
    if (parsed == null) return;
    final weekStart = _dateKey(
      DateTime(parsed.year, parsed.month, parsed.day).subtract(
        Duration(days: parsed.weekday - DateTime.monday),
      ),
    );
    final monthStart = _dateKey(DateTime(parsed.year, parsed.month));

    await markSnapshotStale(
      table: 'daily_snapshots',
      keyColumn: 'date',
      keyValue: localDate,
      reason: reason,
    );
    final affectedWeekStarts = await markWeeklySnapshotsStaleForDate(
      localDate: localDate,
      fallbackWeekStart: weekStart,
      reason: reason,
    );
    await markSnapshotStale(
      table: 'monthly_snapshots',
      keyColumn: 'month_start',
      keyValue: monthStart,
      reason: reason,
    );
    await markJourneySnapshotsStaleForMonth(
      monthStart: monthStart,
      reason: reason,
    );
    for (final affectedWeekStart in affectedWeekStarts) {
      await markExperimentCandidatesStaleForWeek(
        weekStart: affectedWeekStart,
        reason: reason,
        signalIds: signalIds,
      );
      await _markCandidateGroupsStale(
        candidateKind: 'life_experiment',
        periodStart: affectedWeekStart,
        reason: reason,
      );
    }
    await _markMicroActionCandidatesStaleForDate(
      localDate: localDate,
      reason: reason,
      signalIds: signalIds,
    );
    await _markCandidateGroupsStale(
      candidateKind: 'micro_action',
      periodStart: localDate,
      reason: reason,
    );
    await _markAdoptedObjectSourcesChanged(
      signalIds: signalIds,
      reason: reason,
    );
    CandidateInvalidationBus.publish(
      CandidateInvalidationNotice(
        localDatabase: localDatabase,
        candidateKind: 'micro_action',
        periodStart: localDate,
        periodEnd: localDate,
      ),
    );
    for (final affectedWeekStart in affectedWeekStarts) {
      final parsedWeekStart = DateTime.tryParse(affectedWeekStart);
      final periodEnd = parsedWeekStart == null
          ? affectedWeekStart
          : _dateKey(parsedWeekStart.add(const Duration(days: 6)));
      CandidateInvalidationBus.publish(
        CandidateInvalidationNotice(
          localDatabase: localDatabase,
          candidateKind: 'life_experiment',
          periodStart: affectedWeekStart,
          periodEnd: periodEnd,
        ),
      );
    }
    AppDataMutationBus.publish(
      kind: AppDataMutationKind.signalCard,
      reason: reason,
    );
  }

  Future<List<String>> markWeeklySnapshotsStaleForDate({
    required String localDate,
    required String fallbackWeekStart,
    required String reason,
  }) async {
    final db = await localDatabase.database;
    final rows = await db.query(
      'weekly_snapshots',
      columns: ['week_start'],
      where: 'week_start <= ? AND week_end >= ?',
      whereArgs: [localDate, localDate],
    );
    final weekStarts = {
      for (final row in rows)
        if ((row['week_start'] as String?)?.trim().isNotEmpty == true)
          row['week_start'] as String,
      if (rows.isEmpty) fallbackWeekStart,
    };
    for (final weekStart in weekStarts) {
      await markSnapshotStale(
        table: 'weekly_snapshots',
        keyColumn: 'week_start',
        keyValue: weekStart,
        reason: reason,
      );
    }
    return weekStarts.toList(growable: false);
  }

  Future<void> markExperimentChanged({
    required String weekStart,
    required DateTime eventDate,
    required String reason,
  }) async {
    final eventLocalDate = _dateKey(
      DateTime(eventDate.year, eventDate.month, eventDate.day),
    );
    final eventWeekStart = _dateKey(
      DateTime(eventDate.year, eventDate.month, eventDate.day).subtract(
        Duration(days: eventDate.weekday - DateTime.monday),
      ),
    );
    final monthStart = _dateKey(DateTime(eventDate.year, eventDate.month));
    await markSnapshotStale(
      table: 'weekly_snapshots',
      keyColumn: 'week_start',
      keyValue: weekStart,
      reason: reason,
    );
    await markSnapshotStale(
      table: 'monthly_snapshots',
      keyColumn: 'month_start',
      keyValue: monthStart,
      reason: reason,
    );
    await markJourneySnapshotsStaleForMonth(
      monthStart: monthStart,
      reason: reason,
    );
    if (_affectsCandidatePlanning(reason)) {
      await markExperimentCandidatesStaleForWeek(
        weekStart: weekStart,
        reason: reason,
      );
      if (eventWeekStart != weekStart) {
        await markExperimentCandidatesStaleForWeek(
          weekStart: eventWeekStart,
          reason: reason,
        );
      }
      await _markMicroActionCandidatesStaleForDate(
        localDate: eventLocalDate,
        reason: reason,
      );
      await _markCandidateGroupsStale(
        candidateKind: 'micro_action',
        periodStart: eventLocalDate,
        reason: reason,
      );
      for (final affectedWeek in {weekStart, eventWeekStart}) {
        await _markCandidateGroupsStale(
          candidateKind: 'life_experiment',
          periodStart: affectedWeek,
          reason: reason,
        );
        final parsedWeek = DateTime.tryParse(affectedWeek);
        CandidateInvalidationBus.publish(CandidateInvalidationNotice(
          localDatabase: localDatabase,
          candidateKind: 'life_experiment',
          periodStart: affectedWeek,
          periodEnd: parsedWeek == null
              ? affectedWeek
              : _dateKey(parsedWeek.add(const Duration(days: 6))),
        ));
      }
      CandidateInvalidationBus.publish(CandidateInvalidationNotice(
        localDatabase: localDatabase,
        candidateKind: 'micro_action',
        periodStart: eventLocalDate,
        periodEnd: eventLocalDate,
      ));
    }
    AppDataMutationBus.publish(
      kind: AppDataMutationKind.candidatePlanning,
      reason: reason,
    );
  }

  Future<void> markMicroActionChanged({
    required String localDate,
    required String reason,
  }) async {
    final parsed = DateTime.tryParse(localDate);
    if (parsed == null) return;
    final fallbackWeekStart = _dateKey(
      DateTime(parsed.year, parsed.month, parsed.day).subtract(
        Duration(days: parsed.weekday - DateTime.monday),
      ),
    );
    final monthStart = _dateKey(DateTime(parsed.year, parsed.month));
    await markWeeklySnapshotsStaleForDate(
      localDate: localDate,
      fallbackWeekStart: fallbackWeekStart,
      reason: reason,
    );
    await markSnapshotStale(
      table: 'monthly_snapshots',
      keyColumn: 'month_start',
      keyValue: monthStart,
      reason: reason,
    );
    await markJourneySnapshotsStaleForMonth(
      monthStart: monthStart,
      reason: reason,
    );
    if (_affectsCandidatePlanning(reason)) {
      await _markMicroActionCandidatesStaleForDate(
        localDate: localDate,
        reason: reason,
      );
      await markExperimentCandidatesStaleForWeek(
        weekStart: fallbackWeekStart,
        reason: reason,
      );
      await _markCandidateGroupsStale(
        candidateKind: 'micro_action',
        periodStart: localDate,
        reason: reason,
      );
      await _markCandidateGroupsStale(
        candidateKind: 'life_experiment',
        periodStart: fallbackWeekStart,
        reason: reason,
      );
      CandidateInvalidationBus.publish(CandidateInvalidationNotice(
        localDatabase: localDatabase,
        candidateKind: 'micro_action',
        periodStart: localDate,
        periodEnd: localDate,
      ));
      CandidateInvalidationBus.publish(CandidateInvalidationNotice(
        localDatabase: localDatabase,
        candidateKind: 'life_experiment',
        periodStart: fallbackWeekStart,
        periodEnd: _dateKey(
          DateTime.parse(fallbackWeekStart).add(const Duration(days: 6)),
        ),
      ));
    }
    AppDataMutationBus.publish(
      kind: AppDataMutationKind.candidatePlanning,
      reason: reason,
    );
  }

  Future<void> markExperimentCandidatesStaleForWeek({
    required String weekStart,
    required String reason,
    Iterable<String> signalIds = const [],
  }) async {
    final db = await localDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'experiment_candidates',
      {
        'dirty': 1,
        'is_stale': 1,
        'stale_reason': reason,
        'invalidated_at': now,
      },
      where: 'source_week_start = ? AND status IN (?, ?, ?)',
      whereArgs: [weekStart, 'generated', 'edited', 'dismissed'],
    );

    final ids =
        signalIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
    for (final id in ids) {
      await db.update(
        'experiment_candidates',
        {
          'dirty': 1,
          'is_stale': 1,
          'stale_reason': reason,
          'invalidated_at': now,
        },
        where: 'linked_signal_card_ids_json LIKE ? AND status IN (?, ?, ?)',
        whereArgs: ['%$id%', 'generated', 'edited', 'dismissed'],
      );
    }
  }

  Future<void> _markMicroActionCandidatesStaleForDate({
    required String localDate,
    required String reason,
    Iterable<String> signalIds = const [],
  }) async {
    final db = await localDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'micro_action_candidates',
      {
        'dirty': 1,
        'is_stale': 1,
        'stale_reason': reason,
        'invalidated_at': now,
        'updated_at': now,
      },
      where: 'local_date = ? AND status IN (?, ?, ?)',
      whereArgs: [localDate, 'generated', 'edited', 'dismissed'],
    );
    for (final id in signalIds
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)) {
      await db.update(
        'micro_action_candidates',
        {
          'dirty': 1,
          'is_stale': 1,
          'stale_reason': reason,
          'invalidated_at': now,
          'updated_at': now,
        },
        where: '''
          linked_signal_card_ids_json LIKE ?
          AND status IN (?, ?, ?)
        ''',
        whereArgs: ['%"$id"%', 'generated', 'edited', 'dismissed'],
      );
    }
  }

  Future<void> _markCandidateGroupsStale({
    required String candidateKind,
    required String periodStart,
    required String reason,
  }) async {
    final db = await localDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'candidate_groups',
      {
        'status': 'stale',
        'dirty': 1,
        'is_stale': 1,
        'stale_reason': reason,
        'invalidated_at': now,
        'updated_at': now,
      },
      where: '''
        local_user_id IS NOT NULL AND candidate_kind = ? AND period_start = ?
        AND status IN (?, ?, ?, ?)
      ''',
      whereArgs: [
        candidateKind,
        periodStart,
        'ready',
        'regenerating',
        'failed',
        'gated',
      ],
    );
  }

  Future<void> _markAdoptedObjectSourcesChanged({
    required Iterable<String> signalIds,
    required String reason,
  }) async {
    final ids = signalIds
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet();
    if (ids.isEmpty) return;
    final db = await localDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();
    for (final id in ids) {
      final values = {
        'source_changed': 1,
        'source_change_reason': reason,
        'updated_at': now,
      };
      await db.update(
        'micro_actions',
        values,
        where: '''
          linked_signal_card_ids_json LIKE ?
          AND status IN (?, ?, ?, ?, ?)
        ''',
        whereArgs: [
          '%"$id"%',
          'accepted',
          'active',
          'adjusted',
          'done',
          'completed',
        ],
      );
      await db.update(
        'life_experiments',
        values,
        where: '''
          linked_signal_card_ids_json LIKE ?
          AND status IN (?, ?, ?, ?)
        ''',
        whereArgs: ['%"$id"%', 'saved', 'active', 'done', 'completed'],
      );
    }
  }

  Future<void> markSnapshotStale({
    required String table,
    required String keyColumn,
    required String keyValue,
    required String reason,
  }) async {
    final db = await localDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      table,
      {
        'dirty': 1,
        'is_stale': 1,
        'stale_reason': reason,
        'invalidated_at': now,
      },
      where: '$keyColumn = ?',
      whereArgs: [keyValue],
    );

    final sourceType = _sourceTypeForTable(table);
    if (sourceType != null) {
      await markReflectionStale(
        sourceType: sourceType,
        sourceId: keyValue,
        reason: reason,
      );
    }
  }

  Future<void> markJourneySnapshotsStaleForMonth({
    required String monthStart,
    required String reason,
  }) async {
    final db = await localDatabase.database;
    final month = DateTime.tryParse(monthStart);
    if (month == null) return;
    final nextMonth = DateTime(month.year, month.month + 1);
    final start = _dateKey(month);
    final end = _dateKey(nextMonth.subtract(const Duration(days: 1)));
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = await db.query(
      'journey_snapshots',
      columns: ['snapshot_date'],
      where: 'snapshot_date >= ? AND snapshot_date <= ?',
      whereArgs: [start, end],
    );
    await db.update(
      'journey_snapshots',
      {
        'dirty': 1,
        'is_stale': 1,
        'stale_reason': reason,
        'invalidated_at': now,
      },
      where: 'snapshot_date >= ? AND snapshot_date <= ?',
      whereArgs: [start, end],
    );
    for (final row in rows) {
      final snapshotDate = row['snapshot_date'] as String?;
      if (snapshotDate == null) continue;
      await markReflectionStale(
        sourceType: 'journey_snapshot',
        sourceId: snapshotDate,
        reason: reason,
      );
    }
  }

  Future<void> markReflectionStale({
    required String sourceType,
    required String sourceId,
    required String reason,
  }) async {
    final db = await localDatabase.database;
    await db.update(
      'reflection_results',
      {
        'dirty': 1,
        'is_stale': 1,
        'stale_reason': reason,
        'invalidated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'source_type = ? AND source_id = ? AND status IN (?, ?)',
      whereArgs: [sourceType, sourceId, 'generated', 'confirmed'],
    );
  }

  Future<int> markSnapshotsStaleForSchemaVersionChange({
    required String table,
    required int currentSchemaVersion,
    String reason = 'schema_version_changed',
  }) async {
    final sourceType = _sourceTypeForTable(table);
    final keyColumn = _keyColumnForTable(table);
    if (sourceType == null || keyColumn == null) return 0;

    final db = await localDatabase.database;
    final rows = await db.query(
      table,
      columns: [keyColumn],
      where: 'schema_version != ? AND dirty = 0 AND is_stale = 0',
      whereArgs: [currentSchemaVersion],
    );
    if (rows.isEmpty) return 0;

    final now = DateTime.now().toUtc().toIso8601String();
    final affected = await db.update(
      table,
      {
        'dirty': 1,
        'is_stale': 1,
        'stale_reason': reason,
        'invalidated_at': now,
      },
      where: 'schema_version != ? AND dirty = 0 AND is_stale = 0',
      whereArgs: [currentSchemaVersion],
    );

    for (final row in rows) {
      final sourceId = row[keyColumn] as String?;
      if (sourceId == null || sourceId.trim().isEmpty) continue;
      await markReflectionStale(
        sourceType: sourceType,
        sourceId: sourceId,
        reason: reason,
      );
    }
    return affected;
  }

  Future<String?> validSourceHash({
    required String table,
    required String keyColumn,
    required String keyValue,
  }) async {
    final db = await localDatabase.database;
    final rows = await db.query(
      table,
      columns: ['source_hash', 'dirty', 'is_stale'],
      where: '$keyColumn = ?',
      whereArgs: [keyValue],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    if ((row['dirty'] as int? ?? 0) == 1) return null;
    if ((row['is_stale'] as int? ?? 0) == 1) return null;
    return row['source_hash'] as String?;
  }

  String? _sourceTypeForTable(String table) {
    switch (table) {
      case 'daily_snapshots':
        return 'daily_snapshot';
      case 'weekly_snapshots':
        return 'weekly_snapshot';
      case 'journey_snapshots':
        return 'journey_snapshot';
      case 'monthly_snapshots':
        return 'monthly_snapshot';
      default:
        return null;
    }
  }

  bool _affectsCandidatePlanning(String reason) {
    final normalized = reason.trim().toLowerCase();
    return normalized.contains('feedback');
  }

  String? _keyColumnForTable(String table) {
    switch (table) {
      case 'daily_snapshots':
        return 'date';
      case 'weekly_snapshots':
        return 'week_start';
      case 'journey_snapshots':
        return 'snapshot_date';
      case 'monthly_snapshots':
        return 'month_start';
      default:
        return null;
    }
  }

  String _dateKey(DateTime date) {
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '${date.year}-$mm-$dd';
  }
}
