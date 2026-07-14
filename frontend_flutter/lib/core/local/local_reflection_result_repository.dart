import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'local_database.dart';
import 'local_trace_link_repository.dart';

class LocalReflectionResultRepository {
  final LocalDatabase localDatabase;

  LocalReflectionResultRepository(this.localDatabase);

  Future<void> saveCurrent({
    required String sourceType,
    required String sourceId,
    required String reflectionType,
    required String aiLevel,
    required Map<String, dynamic> content,
    String status = 'generated',
    int schemaVersion = 1,
    String? promptVersion,
    String? modelVersion,
    String pipelineVersion = 'v4_p0_05',
    String? sourceHash,
    DateTime? generatedAt,
  }) async {
    final db = await localDatabase.database;
    final now = DateTime.now().toUtc();
    final generated = (generatedAt ?? now).toUtc().toIso8601String();
    final id = [
      'refl',
      _stableIdPart(sourceType),
      _stableIdPart(sourceId),
      _stableIdPart(reflectionType),
      now.microsecondsSinceEpoch,
    ].join('_');

    await db.transaction((txn) async {
      await txn.update(
        'reflection_results',
        {
          'status': 'superseded',
          'superseded_by': id,
          'updated_at': now.toIso8601String(),
        },
        where:
            'source_type = ? AND source_id = ? AND reflection_type = ? AND status IN (?, ?)',
        whereArgs: [
          sourceType,
          sourceId,
          reflectionType,
          'generated',
          'confirmed',
        ],
      );

      await txn.insert(
        'reflection_results',
        {
          'id': id,
          'source_type': sourceType,
          'source_id': sourceId,
          'reflection_type': reflectionType,
          'ai_level': aiLevel,
          'content_json': jsonEncode(content),
          'status': status,
          'schema_version': schemaVersion,
          'prompt_version': promptVersion,
          'model_version': modelVersion,
          'pipeline_version': pipelineVersion,
          'source_hash': sourceHash,
          'dirty': 0,
          'is_stale': 0,
          'stale_reason': null,
          'invalidated_at': null,
          'generated_at': generated,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
    await _writeTraceLinks(
      reflectionId: id,
      localUserId: 'local',
      sourceType: sourceType,
      sourceId: sourceId,
      content: content,
    );
  }

  Future<Map<String, dynamic>?> getLatestContent({
    required String sourceType,
    required String sourceId,
    required String reflectionType,
  }) async {
    final db = await localDatabase.database;
    final rows = await db.query(
      'reflection_results',
      columns: ['content_json'],
      where:
          'source_type = ? AND source_id = ? AND reflection_type = ? AND status IN (?, ?) AND dirty = 0 AND is_stale = 0',
      whereArgs: [
        sourceType,
        sourceId,
        reflectionType,
        'generated',
        'confirmed',
      ],
      orderBy: 'generated_at DESC',
      limit: 1,
    );

    if (rows.isEmpty) return null;
    final raw = rows.first['content_json'] as String?;
    if (raw == null || raw.trim().isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry('$key', value));
    }
    return null;
  }

  Future<int> markStaleForPromptModelChange({
    required String sourceType,
    required String reflectionType,
    String? sourceId,
    String? promptVersion,
    String? modelVersion,
    String reason = 'prompt_model_version_changed',
  }) async {
    final db = await localDatabase.database;
    final clauses = <String>[
      'source_type = ?',
      'reflection_type = ?',
      'status IN (?, ?)',
      'dirty = 0',
      'is_stale = 0',
    ];
    final args = <Object?>[
      sourceType,
      reflectionType,
      'generated',
      'confirmed',
    ];
    if (sourceId != null) {
      clauses.add('source_id = ?');
      args.add(sourceId);
    }

    final versionClauses = <String>[];
    if (promptVersion != null) {
      versionClauses.add('(prompt_version IS NULL OR prompt_version != ?)');
      args.add(promptVersion);
    }
    if (modelVersion != null) {
      versionClauses.add('(model_version IS NULL OR model_version != ?)');
      args.add(modelVersion);
    }
    if (versionClauses.isEmpty) return 0;
    clauses.add('(${versionClauses.join(' OR ')})');

    return db.update(
      'reflection_results',
      {
        'dirty': 1,
        'is_stale': 1,
        'stale_reason': reason,
        'invalidated_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: clauses.join(' AND '),
      whereArgs: args,
    );
  }

  String _stableIdPart(String raw) {
    return raw.replaceAll(RegExp(r'[^A-Za-z0-9_]+'), '_');
  }

  Future<void> _writeTraceLinks({
    required String reflectionId,
    required String localUserId,
    required String sourceType,
    required String sourceId,
    required Map<String, dynamic> content,
  }) async {
    final links = <TraceLinkInput>[
      TraceLinkInput(
        sourceType: 'reflection_result',
        sourceId: reflectionId,
        targetType: sourceType,
        targetId: sourceId,
        relationType: 'derived_from',
        localUserId: localUserId,
      ),
    ];

    final journeyData = content['journey_data'];
    if (journeyData is Map) {
      final traces = journeyData['journey_traces'];
      if (traces is List) {
        for (final trace in traces.whereType<Map>()) {
          final targetType = trace['source_type']?.toString().trim() ?? '';
          final targetId = trace['id']?.toString().trim() ?? '';
          if (targetType.isEmpty || targetId.isEmpty) continue;
          links.add(
            TraceLinkInput(
              sourceType: 'reflection_result',
              sourceId: reflectionId,
              targetType: targetType,
              targetId: targetId,
              relationType: 'uses_trace',
              localUserId: localUserId,
              metadata: {
                'local_date': trace['local_date'],
                'cluster': trace['cluster'],
                'signal_level': trace['signal_level'],
              },
            ),
          );
        }
      }
    }

    await LocalTraceLinkRepository(localDatabase).replaceForSource(
      sourceType: 'reflection_result',
      sourceId: reflectionId,
      links: links,
    );
  }
}
