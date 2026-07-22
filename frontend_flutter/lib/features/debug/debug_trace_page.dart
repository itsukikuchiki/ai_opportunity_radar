import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_router.dart';
import '../../core/debug/legacy_fallback_monitor.dart';
import '../../core/config/build_environment.dart';
import '../../core/di/app_dependencies.dart';
import '../../core/navigation/app_back_navigation.dart';
import '../../shared/widgets/aurora_ui.dart';

class DebugTracePage extends StatefulWidget {
  final String? initialSignalId;
  final bool useSampleDataForTest;

  const DebugTracePage({
    super.key,
    this.initialSignalId,
    @visibleForTesting this.useSampleDataForTest = false,
  });

  @override
  State<DebugTracePage> createState() => _DebugTracePageState();
}

class _DebugTracePageState extends State<DebugTracePage> {
  late final TextEditingController _signalController;
  late Future<_DebugTraceBundle> _future;

  @override
  void initState() {
    super.initState();
    _signalController = TextEditingController(
      text: widget.initialSignalId?.trim() ?? '',
    );
    _future = _load();
  }

  @override
  void dispose() {
    _signalController.dispose();
    super.dispose();
  }

  Future<_DebugTraceBundle> _load() async {
    if (widget.useSampleDataForTest) {
      return const _DebugTraceBundle(
        signal: {
          'id': 'sig_debug_sample',
          'signal_card_id': 'sig_debug_sample',
          'local_date': '2026-07-05',
          'source_type': 'text',
          'raw_text': 'Debug trace source signal',
          'user_confirmation': 'confirmed',
          'included_in_weekly': 1,
          'included_in_journey': 1,
          'updated_at': '2026-07-05T00:00:00.000Z',
        },
        traceLinks: [
          {
            'id': 'trace_debug_sample',
            'source_type': 'journey_snapshot',
            'source_id': '2026-07',
            'target_type': 'signal_card',
            'target_id': 'sig_debug_sample',
            'relation_type': 'uses_trace',
            'status': 'active',
          },
        ],
        pipelineRuns: [
          {
            'id': 'pipe_debug_sample',
            'pipeline_type': 'journey_reflection',
            'source_type': 'journey_snapshot',
            'source_id': '2026-07',
            'status': 'completed',
          },
        ],
        syncIdentities: [
          {
            'client_id': 'client_debug_sample',
            'server_id': 'server_debug_sample',
            'local_signal_id': 'sig_debug_sample',
            'sync_status': 'synced',
          },
        ],
        tombstones: [
          {
            'signal_id': 'sig_debug_deleted',
            'signal_card_id': 'sig_debug_deleted',
            'status': 'active',
            'reason': 'user_deleted',
          },
        ],
      );
    }
    final deps = context.read<AppDependencies>();
    return _DebugTraceReader(deps).load(
      signalId: _signalController.text.trim(),
    );
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  void _selectSignal(String signalId) {
    _signalController.text = signalId;
    _refresh();
  }

  void _resetLegacyCounters() {
    LegacyFallbackMonitor.reset();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (!BuildEnvironment.debugToolsVisible) {
      return const Scaffold(
        body: Center(
          child: Text('Debug tools are only available in debug builds.'),
        ),
      );
    }

    return Scaffold(
      body: AuroraPage(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => context.popOrGo(AppRoutes.me),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Trace Debug',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: _refresh,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _DebugPanel(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _signalController,
                        decoration: const InputDecoration(
                          labelText: 'Signal id',
                          hintText: 'signal_cards.id / signal_card_id',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _refresh(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.search_rounded),
                      label: const Text('Trace'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _LegacyCountersPanel(onReset: _resetLegacyCounters),
              const SizedBox(height: 12),
              FutureBuilder<_DebugTraceBundle>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return _DebugPanel(
                      child:
                          Text('Failed to load debug trace: ${snapshot.error}'),
                    );
                  }
                  final bundle = snapshot.data!;
                  if (bundle.signal == null) {
                    return _RecentSignalsPanel(
                      signals: bundle.recentSignals,
                      onSelect: _selectSignal,
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SignalPanel(signal: bundle.signal!),
                      const SizedBox(height: 12),
                      _RowsPanel(
                        title: 'Sync identity',
                        subtitle:
                            'signal_sync_identity rows for client/server/local ids',
                        rows: bundle.syncIdentities,
                        emptyText: 'No signal_sync_identity rows found.',
                      ),
                      const SizedBox(height: 12),
                      _RowsPanel(
                        title: 'Tombstone state',
                        subtitle:
                            'signal_tombstones rows that can block remote resurrection or show restore state',
                        rows: bundle.tombstones,
                        emptyText: 'No signal_tombstones rows found.',
                      ),
                      const SizedBox(height: 12),
                      _SnapshotPanel(bundle: bundle),
                      const SizedBox(height: 12),
                      _RowsPanel(
                        title: 'Trace links',
                        subtitle:
                            'target/source rows that connect this Signal to Journey, reflections, and downstream objects',
                        rows: bundle.traceLinks,
                        emptyText: 'No trace_links rows found for this Signal.',
                      ),
                      const SizedBox(height: 12),
                      _RowsPanel(
                        title: 'Experiment impact',
                        subtitle:
                            'experiment_candidates / life_experiments linked by signal id',
                        rows: bundle.experiments,
                        emptyText: 'No experiment linkage found.',
                      ),
                      const SizedBox(height: 12),
                      _RowsPanel(
                        title: 'Reflection sources',
                        subtitle:
                            'reflection_results for related Weekly / Journey snapshots',
                        rows: bundle.reflections,
                        emptyText: 'No reflection_results rows found.',
                      ),
                      const SizedBox(height: 12),
                      _RowsPanel(
                        title: 'Pipeline runs',
                        subtitle:
                            'aggregation / reflection pipeline state for related sources',
                        rows: bundle.pipelineRuns,
                        emptyText: 'No pipeline_runs rows found.',
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DebugTraceReader {
  final AppDependencies deps;

  const _DebugTraceReader(this.deps);

  Future<_DebugTraceBundle> load({required String signalId}) async {
    final db = await deps.localDatabase.database;
    final recentSignals = await db.query(
      'signal_cards',
      columns: [
        'id',
        'signal_card_id',
        'local_date',
        'source_type',
        'raw_text',
        'user_confirmation',
        'included_in_weekly',
        'included_in_journey',
        'linked_experiment_id',
        'updated_at',
      ],
      orderBy: 'COALESCE(local_date, created_at) DESC, updated_at DESC',
      limit: 24,
    );

    if (signalId.trim().isEmpty) {
      return _DebugTraceBundle(recentSignals: recentSignals);
    }

    final signalRows = await db.query(
      'signal_cards',
      where: 'id = ? OR signal_card_id = ? OR client_id = ? OR server_id = ?',
      whereArgs: [signalId, signalId, signalId, signalId],
      limit: 1,
    );
    if (signalRows.isEmpty) {
      final lookupIds = {signalId}..removeWhere((id) => id.trim().isEmpty);
      final syncIdentities = await _syncIdentitiesForSignal(lookupIds);
      final tombstones = await _tombstonesForSignal(lookupIds);
      if (syncIdentities.isEmpty && tombstones.isEmpty) {
        return _DebugTraceBundle(recentSignals: recentSignals);
      }
      return _DebugTraceBundle(
        signal: {
          'id': signalId,
          'raw_text': 'Signal not present in signal_cards.',
          'source_type': 'debug_lookup',
          'local_date': tombstones.isEmpty
              ? null
              : tombstones.first['local_date']?.toString(),
        },
        recentSignals: recentSignals,
        syncIdentities: syncIdentities.map(_compactSyncIdentityRow).toList(),
        tombstones: tombstones.map(_compactTombstoneRow).toList(),
      );
    }

    final signal = signalRows.first;
    final resolvedSignalIds = {
      signal['id']?.toString() ?? '',
      signal['signal_card_id']?.toString() ?? '',
      signal['client_id']?.toString() ?? '',
      signal['server_id']?.toString() ?? '',
      signalId,
    }..removeWhere((id) => id.trim().isEmpty);
    final localDate = signal['local_date']?.toString() ?? '';

    final weeklySnapshots = localDate.isEmpty
        ? <Map<String, Object?>>[]
        : await db.query(
            'weekly_snapshots',
            where: 'week_start <= ? AND week_end >= ?',
            whereArgs: [localDate, localDate],
            orderBy: 'generated_at DESC',
            limit: 8,
          );
    final journeySnapshots = await db.query(
      'journey_snapshots',
      orderBy: 'snapshot_date DESC',
      limit: 8,
    );
    final relatedSnapshotKeys = <_SourceKey>{
      for (final row in weeklySnapshots)
        _SourceKey('weekly_snapshot', row['week_start']?.toString() ?? ''),
      for (final row in journeySnapshots)
        _SourceKey('journey_snapshot', row['snapshot_date']?.toString() ?? ''),
    }..removeWhere((key) => key.id.isEmpty);

    final traceLinks = await _traceLinksForSignal(resolvedSignalIds);
    for (final row in traceLinks) {
      final sourceType = row['source_type']?.toString() ?? '';
      final sourceId = row['source_id']?.toString() ?? '';
      if (sourceType == 'weekly_snapshot' || sourceType == 'journey_snapshot') {
        relatedSnapshotKeys.add(_SourceKey(sourceType, sourceId));
      }
      if (sourceType == 'reflection_result') {
        final reflection = await _reflectionById(sourceId);
        final reflectionSourceType = reflection?['source_type']?.toString();
        final reflectionSourceId = reflection?['source_id']?.toString();
        if (reflectionSourceType != null && reflectionSourceId != null) {
          relatedSnapshotKeys.add(
            _SourceKey(reflectionSourceType, reflectionSourceId),
          );
        }
      }
    }

    final experiments = await _experimentsForSignal(resolvedSignalIds);
    final reflections = await _reflectionsForSources(relatedSnapshotKeys);
    final syncIdentities = await _syncIdentitiesForSignal(resolvedSignalIds);
    final tombstones = await _tombstonesForSignal(resolvedSignalIds);
    final pipelineRuns = await _pipelineRunsFor(
      snapshotKeys: relatedSnapshotKeys,
      experimentRows: experiments,
      signalIds: resolvedSignalIds,
    );

    return _DebugTraceBundle(
      signal: signal,
      recentSignals: recentSignals,
      weeklySnapshots: weeklySnapshots.map(_snapshotDebugRow).toList(),
      journeySnapshots: journeySnapshots.map(_snapshotDebugRow).toList(),
      traceLinks: traceLinks.map(_compactTraceRow).toList(),
      experiments: experiments,
      reflections: reflections.map(_compactReflectionRow).toList(),
      pipelineRuns: pipelineRuns.map(_compactPipelineRow).toList(),
      syncIdentities: syncIdentities.map(_compactSyncIdentityRow).toList(),
      tombstones: tombstones.map(_compactTombstoneRow).toList(),
    );
  }

  Future<List<Map<String, Object?>>> _syncIdentitiesForSignal(
    Set<String> signalIds,
  ) async {
    if (signalIds.isEmpty) return const [];
    final db = await deps.localDatabase.database;
    final placeholders = List.filled(signalIds.length, '?').join(', ');
    return db.rawQuery(
      '''
      SELECT *
      FROM signal_sync_identity
      WHERE client_id IN ($placeholders)
        OR server_id IN ($placeholders)
        OR local_signal_id IN ($placeholders)
      ORDER BY updated_at DESC
      LIMIT 40
      ''',
      [...signalIds, ...signalIds, ...signalIds],
    );
  }

  Future<List<Map<String, Object?>>> _tombstonesForSignal(
    Set<String> signalIds,
  ) async {
    if (signalIds.isEmpty) return const [];
    final db = await deps.localDatabase.database;
    final placeholders = List.filled(signalIds.length, '?').join(', ');
    return db.rawQuery(
      '''
      SELECT *
      FROM signal_tombstones
      WHERE signal_id IN ($placeholders)
        OR signal_card_id IN ($placeholders)
        OR client_id IN ($placeholders)
        OR server_id IN ($placeholders)
      ORDER BY updated_at DESC
      LIMIT 40
      ''',
      [...signalIds, ...signalIds, ...signalIds, ...signalIds],
    );
  }

  Future<List<Map<String, Object?>>> _traceLinksForSignal(
    Set<String> signalIds,
  ) async {
    if (signalIds.isEmpty) return const [];
    final db = await deps.localDatabase.database;
    final placeholders = List.filled(signalIds.length, '?').join(', ');
    return db.rawQuery(
      '''
      SELECT *
      FROM trace_links
      WHERE
        (target_type IN ('signal_card', 'manual_reflection')
          AND target_id IN ($placeholders))
        OR (source_type IN ('signal_card', 'manual_reflection')
          AND source_id IN ($placeholders))
      ORDER BY updated_at DESC
      LIMIT 80
      ''',
      [...signalIds, ...signalIds],
    );
  }

  Future<Map<String, Object?>?> _reflectionById(String id) async {
    if (id.trim().isEmpty) return null;
    final db = await deps.localDatabase.database;
    final rows = await db.query(
      'reflection_results',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, Object?>>> _experimentsForSignal(
    Set<String> signalIds,
  ) async {
    if (signalIds.isEmpty) return const [];
    final db = await deps.localDatabase.database;
    final rows = <Map<String, Object?>>[];
    for (final id in signalIds) {
      rows.addAll(await db.query(
        'experiment_candidates',
        where: 'linked_signal_card_ids_json LIKE ?',
        whereArgs: ['%$id%'],
        orderBy: 'updated_at DESC',
        limit: 20,
      ));
      rows.addAll(await db.query(
        'life_experiments',
        where: 'linked_signal_card_ids_json LIKE ? OR id = ?',
        whereArgs: ['%$id%', id],
        orderBy: 'updated_at DESC',
        limit: 20,
      ));
    }
    return rows.map((row) {
      final table = row.containsKey('source_type')
          ? 'experiment_candidates'
          : 'life_experiments';
      return {
        'table': table,
        'id': row['id'],
        'status': row['status'],
        'title': row['title'],
        'source': row['source_type'] ?? 'weekly',
        'source_id': row['source_id'] ?? row['source_week_start'],
        'adopted_experiment_id': row['adopted_experiment_id'],
        'parent_experiment_id': row['parent_experiment_id'],
        'linked_signal_card_ids_json': row['linked_signal_card_ids_json'],
        'updated_at': row['updated_at'],
      };
    }).toList(growable: false);
  }

  Future<List<Map<String, Object?>>> _reflectionsForSources(
    Set<_SourceKey> sources,
  ) async {
    if (sources.isEmpty) return const [];
    final db = await deps.localDatabase.database;
    final rows = <Map<String, Object?>>[];
    for (final source in sources) {
      rows.addAll(await db.query(
        'reflection_results',
        where: 'source_type = ? AND source_id = ?',
        whereArgs: [source.type, source.id],
        orderBy: 'generated_at DESC',
        limit: 8,
      ));
    }
    return rows;
  }

  Future<List<Map<String, Object?>>> _pipelineRunsFor({
    required Set<_SourceKey> snapshotKeys,
    required List<Map<String, Object?>> experimentRows,
    required Set<String> signalIds,
  }) async {
    final db = await deps.localDatabase.database;
    final sources = <_SourceKey>{
      for (final signalId in signalIds) _SourceKey('signal_card', signalId),
      ...snapshotKeys,
      for (final row in experimentRows)
        _SourceKey(row['table']?.toString() ?? '', row['id']?.toString() ?? ''),
    }..removeWhere((source) => source.type.isEmpty || source.id.isEmpty);

    final rows = <Map<String, Object?>>[];
    for (final source in sources) {
      rows.addAll(await db.query(
        'pipeline_runs',
        where: 'source_type = ? AND source_id = ?',
        whereArgs: [source.type, source.id],
        orderBy: 'started_at DESC',
        limit: 12,
      ));
    }
    return rows;
  }

  Map<String, Object?> _snapshotDebugRow(Map<String, Object?> row) {
    final isWeekly = row.containsKey('week_start');
    return {
      'table': isWeekly ? 'weekly_snapshots' : 'journey_snapshots',
      'id': isWeekly ? row['week_start'] : row['snapshot_date'],
      'status': row['status'],
      'source_hash': row['source_hash'],
      'pipeline_version': row['pipeline_version'],
      'dirty': row['dirty'],
      'is_stale': row['is_stale'],
      'stale_reason': row['stale_reason'],
      'generated_at': row['generated_at'],
    };
  }

  Map<String, Object?> _compactTraceRow(Map<String, Object?> row) {
    return {
      'source': '${row['source_type']}:${row['source_id']}',
      'target': '${row['target_type']}:${row['target_id']}',
      'relation': row['relation_type'],
      'status': row['status'],
      'weight': row['weight'],
      'metadata': _decodeJson(row['metadata_json']),
      'updated_at': row['updated_at'],
    };
  }

  Map<String, Object?> _compactReflectionRow(Map<String, Object?> row) {
    return {
      'id': row['id'],
      'source': '${row['source_type']}:${row['source_id']}',
      'type': row['reflection_type'],
      'ai_level': row['ai_level'],
      'status': row['status'],
      'prompt_version': row['prompt_version'],
      'model_version': row['model_version'],
      'pipeline_version': row['pipeline_version'],
      'source_hash': row['source_hash'],
      'dirty': row['dirty'],
      'is_stale': row['is_stale'],
      'stale_reason': row['stale_reason'],
      'generated_at': row['generated_at'],
    };
  }

  Map<String, Object?> _compactPipelineRow(Map<String, Object?> row) {
    return {
      'id': row['id'],
      'pipeline': row['pipeline_type'],
      'source': '${row['source_type']}:${row['source_id']}',
      'status': row['status'],
      'input_hash': row['input_hash'],
      'output_hash': row['output_hash'],
      'pipeline_version': row['pipeline_version'],
      'error': row['error_message'] ?? row['error_code'],
      'can_retry': row['can_retry'],
      'started_at': row['started_at'],
      'finished_at': row['finished_at'],
    };
  }

  Map<String, Object?> _compactSyncIdentityRow(Map<String, Object?> row) {
    return {
      'client_id': row['client_id'],
      'server_id': row['server_id'],
      'local_signal_id': row['local_signal_id'],
      'sync_status': row['sync_status'],
      'last_synced_at': row['last_synced_at'],
      'created_at': row['created_at'],
      'updated_at': row['updated_at'],
    };
  }

  Map<String, Object?> _compactTombstoneRow(Map<String, Object?> row) {
    return {
      'signal_id': row['signal_id'],
      'signal_card_id': row['signal_card_id'],
      'client_id': row['client_id'],
      'server_id': row['server_id'],
      'local_date': row['local_date'],
      'reason': row['reason'],
      'status': row['status'],
      'deleted_at': row['deleted_at'],
      'restored_at': row['restored_at'],
      'updated_at': row['updated_at'],
    };
  }

  Object? _decodeJson(Object? raw) {
    if (raw is! String || raw.trim().isEmpty) return raw;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return raw;
    }
  }
}

class _DebugTraceBundle {
  final Map<String, Object?>? signal;
  final List<Map<String, Object?>> recentSignals;
  final List<Map<String, Object?>> weeklySnapshots;
  final List<Map<String, Object?>> journeySnapshots;
  final List<Map<String, Object?>> traceLinks;
  final List<Map<String, Object?>> experiments;
  final List<Map<String, Object?>> reflections;
  final List<Map<String, Object?>> pipelineRuns;
  final List<Map<String, Object?>> syncIdentities;
  final List<Map<String, Object?>> tombstones;

  const _DebugTraceBundle({
    this.signal,
    this.recentSignals = const [],
    this.weeklySnapshots = const [],
    this.journeySnapshots = const [],
    this.traceLinks = const [],
    this.experiments = const [],
    this.reflections = const [],
    this.pipelineRuns = const [],
    this.syncIdentities = const [],
    this.tombstones = const [],
  });
}

class _SourceKey {
  final String type;
  final String id;

  const _SourceKey(this.type, this.id);

  @override
  bool operator ==(Object other) {
    return other is _SourceKey && other.type == type && other.id == id;
  }

  @override
  int get hashCode => Object.hash(type, id);
}

class _RecentSignalsPanel extends StatelessWidget {
  final List<Map<String, Object?>> signals;
  final ValueChanged<String> onSelect;

  const _RecentSignalsPanel({
    required this.signals,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return _DebugPanel(
      title: 'Recent signals',
      child: Column(
        children: [
          for (final signal in signals)
            ListTile(
              dense: true,
              title: Text(signal['raw_text']?.toString() ?? ''),
              subtitle: Text(
                '${signal['local_date']} · ${signal['source_type']} · ${signal['id']}',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => onSelect(signal['id']?.toString() ?? ''),
            ),
        ],
      ),
    );
  }
}

class _LegacyCountersPanel extends StatelessWidget {
  final VoidCallback onReset;

  const _LegacyCountersPanel({required this.onReset});

  @override
  Widget build(BuildContext context) {
    final counts = LegacyFallbackMonitor.snapshot();
    return _DebugPanel(
      title: 'Legacy fallback counters',
      subtitle:
          'Reset, reproduce a flow, then refresh. Non-zero counters mean that fallback path is still being read.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Reset counters'),
            ),
          ),
          const SizedBox(height: 4),
          for (final entry in counts.entries)
            _DebugRow(
              row: {
                'counter': entry.key,
                'count': entry.value,
              },
            ),
        ],
      ),
    );
  }
}

class _SignalPanel extends StatelessWidget {
  final Map<String, Object?> signal;

  const _SignalPanel({required this.signal});

  @override
  Widget build(BuildContext context) {
    return _RowsPanel(
      title: 'Signal',
      subtitle: '${signal['id']} · ${signal['local_date']}',
      rows: [
        {
          'raw_text': signal['raw_text'],
          'signal_card_id': signal['signal_card_id'],
          'client_id': signal['client_id'],
          'server_id': signal['server_id'],
          'sync_status': signal['sync_status'],
          'is_local_draft': signal['is_local_draft'],
          'sync_failed': signal['sync_failed'],
          'last_error': signal['last_error'],
          'source_type': signal['source_type'],
          'user_confirmation': signal['user_confirmation'],
          'included_in_weekly': signal['included_in_weekly'],
          'included_in_journey': signal['included_in_journey'],
          'privacy_level': signal['privacy_level'],
          'linked_experiment_id': signal['linked_experiment_id'],
          'energy_load': signal['energy_load'],
          'friction': signal['friction'],
          'updated_at': signal['updated_at'],
        }
      ],
      emptyText: 'Signal not found.',
    );
  }
}

class _SnapshotPanel extends StatelessWidget {
  final _DebugTraceBundle bundle;

  const _SnapshotPanel({required this.bundle});

  @override
  Widget build(BuildContext context) {
    return _DebugPanel(
      title: 'Snapshot source hashes',
      subtitle:
          'Weekly is matched by local_date; Journey shows recent snapshots plus trace-linked snapshots.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MiniSection(title: 'Weekly', rows: bundle.weeklySnapshots),
          const SizedBox(height: 10),
          _MiniSection(title: 'Journey', rows: bundle.journeySnapshots),
        ],
      ),
    );
  }
}

class _RowsPanel extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Map<String, Object?>> rows;
  final String emptyText;

  const _RowsPanel({
    required this.title,
    this.subtitle,
    required this.rows,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    return _DebugPanel(
      title: title,
      subtitle: subtitle,
      child: rows.isEmpty
          ? Text(emptyText)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final row in rows) _DebugRow(row: row),
              ],
            ),
    );
  }
}

class _MiniSection extends StatelessWidget {
  final String title;
  final List<Map<String, Object?>> rows;

  const _MiniSection({
    required this.title,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        if (rows.isEmpty)
          const Text('No rows.')
        else
          for (final row in rows) _DebugRow(row: row),
      ],
    );
  }
}

class _DebugPanel extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget child;

  const _DebugPanel({
    this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xE6FFFFFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E7F4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(
                title!,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF667085),
                      ),
                ),
              ],
              const SizedBox(height: 12),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class _DebugRow extends StatelessWidget {
  final Map<String, Object?> row;

  const _DebugRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final fallback = row.isEmpty ? 'row' : row.entries.first.value;
    final title = row['id'] ??
        row['source'] ??
        row['table'] ??
        row['raw_text'] ??
        fallback ??
        'row';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE6EAF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toString(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 6),
          SelectableText(
            const JsonEncoder.withIndent('  ').convert(row),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: const Color(0xFF344054),
                ),
          ),
        ],
      ),
    );
  }
}
