import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/today_models.dart';
import 'local_database.dart';

class LocalCaptureRepository {
  final LocalDatabase localDatabase;
  final Uuid _uuid = const Uuid();

  LocalCaptureRepository(this.localDatabase);

  Future<RecentSignalModel> insertCapture({
    required String content,
    String inputMode = 'quick_capture',
    String? tagHint,
  }) async {
    final db = await localDatabase.database;
    final now = DateTime.now().toUtc();
    final id = 'cap_${_uuid.v4().replaceAll('-', '').substring(0, 12)}';

    await db.insert(
      'captures',
      {
        'id': id,
        'content': content,
        'created_at': now.toIso8601String(),
        'input_mode': inputMode,
        'tag_hint': tagHint,
        'ai_acknowledgement': null,
        'ai_observation': null,
        'ai_try_next': null,
        'ai_emotion': null,
        'ai_intensity': null,
        'ai_scene_tags_json': null,
        'ai_intent_tags_json': null,
        'ai_status': 'pending',
        'followup_question_json': null,
        'followup_answer': null,
        'updated_at': now.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return RecentSignalModel(
      id: id,
      content: content,
      createdAt: now.toLocal(),
      acknowledgement: null,
      observation: null,
      tryNext: null,
      emotion: null,
      intensity: null,
      sceneTags: const [],
      intentTags: const [],
    );
  }

  Future<void> updateAiReply({
    required String captureId,
    required String? acknowledgement,
    required String? observation,
    required String? tryNext,
    required String? emotion,
    required String? intensity,
    required List<String> sceneTags,
    required List<String> intentTags,
  }) async {
    final db = await localDatabase.database;
    await db.update(
      'captures',
      {
        'ai_acknowledgement': acknowledgement,
        'ai_observation': observation,
        'ai_try_next': tryNext,
        'ai_emotion': emotion,
        'ai_intensity': intensity,
        'ai_scene_tags_json': jsonEncode(sceneTags),
        'ai_intent_tags_json': jsonEncode(intentTags),
        'ai_status': acknowledgement == null ? 'failed' : 'done',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [captureId],
    );
  }

  Future<void> updateAcknowledgement({
    required String captureId,
    required String? acknowledgement,
  }) async {
    final db = await localDatabase.database;
    await db.update(
      'captures',
      {
        'ai_acknowledgement': acknowledgement,
        'ai_status': acknowledgement == null ? 'failed' : 'done',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [captureId],
    );
  }

  Future<RecentSignalModel?> getCaptureById(String captureId) async {
    final db = await localDatabase.database;
    final signalCardRows = await db.query(
      'signal_cards',
      where: 'id = ? OR signal_card_id = ?',
      whereArgs: [captureId, captureId],
      limit: 1,
    );
    if (signalCardRows.isNotEmpty) {
      return _mapSignalCardRowToSignal(signalCardRows.first);
    }

    final rows = await db.query(
      'captures',
      where: 'id = ?',
      whereArgs: [captureId],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return _mapRowToSignal(rows.first);
  }

  Future<List<RecentSignalModel>> listTodaySignals() async {
    final db = await localDatabase.database;

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    final rows = await db.query(
      'captures',
      where: 'created_at >= ? AND created_at < ?',
      whereArgs: [
        start.toUtc().toIso8601String(),
        end.toUtc().toIso8601String(),
      ],
      orderBy: 'created_at DESC',
    );

    return rows.map(_mapRowToSignal).toList();
  }

  Future<List<RecentSignalModel>> listTodaySignalCards() async {
    final db = await localDatabase.database;
    await mirrorLegacyCapturesToSignalCards();

    final todayKey = _dateKey(DateTime.now());
    final rows = await db.query(
      'signal_cards',
      where: 'local_date = ?',
      whereArgs: [todayKey],
      orderBy: 'created_at DESC',
    );

    return rows.map(_mapSignalCardRowToSignal).toList();
  }

  Future<List<RecentSignalModel>> listSignalCards({int limit = 200}) async {
    final db = await localDatabase.database;
    await mirrorLegacyCapturesToSignalCards();

    final rows = await db.query(
      'signal_cards',
      orderBy: 'local_date DESC, created_at DESC',
      limit: limit,
    );

    return rows.map(_mapSignalCardRowToSignal).toList();
  }

  Future<RecentSignalModel> insertLocalDraftSignal({
    required String content,
    String sourceType = 'text',
    String? tagHint,
    String language = 'en',
    String? timezone,
    Map<String, dynamic> rawPayloadJson = const {},
  }) async {
    final db = await localDatabase.database;
    final now = DateTime.now();
    final nowUtc = now.toUtc();
    final draftId = 'draft_${_uuid.v4().replaceAll('-', '').substring(0, 12)}';
    final localDate = _dateKey(now);
    final tz = timezone ?? now.timeZoneName;

    await db.insert(
      'signal_card_drafts',
      {
        'draft_id': draftId,
        'raw_text': content,
        'source_type': sourceType,
        'tag_hint': tagHint,
        'created_at': nowUtc.toIso8601String(),
        'local_date': localDate,
        'timezone': tz,
        'language': language,
        'status': 'pending',
        'retry_count': 0,
        'last_error': null,
        'remote_signal_card_id': null,
        'updated_at': nowUtc.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await db.insert(
      'signal_cards',
      {
        'id': draftId,
        'signal_card_id': null,
        'raw_memory_id': null,
        'capture_id': null,
        'source_type': sourceType,
        'raw_text': content,
        'created_at': nowUtc.toIso8601String(),
        'local_date': localDate,
        'timezone': tz,
        'language': language,
        'ai_reply': _localDraftReply(language),
        'observation': null,
        'try_next': null,
        'emotion': null,
        'intensity': null,
        'scene': null,
        'friction': null,
        'positive_signal': null,
        'energy_load': null,
        'linked_life_chain_stage': '[]',
        'raw_payload_json':
            rawPayloadJson.isEmpty ? null : jsonEncode(rawPayloadJson),
        'scene_tags_json': null,
        'intent_tags_json': null,
        'user_confirmation': 'unconfirmed',
        'user_correction_json': '{}',
        'included_in_summary': 0,
        'included_in_weekly': 0,
        'included_in_journey': 0,
        'privacy_level': 'private',
        'is_legacy': 0,
        'migration_status': 'local_draft',
        'is_local_draft': 1,
        'sync_failed': 0,
        'sync_status': 'pending',
        'last_error': null,
        'updated_at': nowUtc.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    final rows = await db.query(
      'signal_cards',
      where: 'id = ?',
      whereArgs: [draftId],
      limit: 1,
    );
    return _mapSignalCardRowToSignal(rows.first);
  }

  String _localDraftReply(String language) {
    switch (language) {
      case 'zh-Hans':
        return '已先保存在本机，网络恢复后会同步。';
      case 'zh-Hant':
        return '已先保存在本機，網路恢復後會同步。';
      case 'ja':
        return '端末に保存しました。ネットワークが戻ると同期できます。';
      default:
        return 'Saved on this device. It can sync when the network returns.';
    }
  }

  Future<void> upsertRemoteSignalCards(List<RecentSignalModel> signals) async {
    final db = await localDatabase.database;
    final batch = db.batch();
    final now = DateTime.now().toUtc().toIso8601String();

    for (final signal in signals) {
      final stableId = signal.signalCardId ?? signal.id;
      if (stableId == null || stableId.trim().isEmpty) continue;
      batch.insert(
        'signal_cards',
        _signalToDbRow(signal, stableId, now),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<List<Map<String, Object?>>> listPendingDraftRows() async {
    final db = await localDatabase.database;
    return db.query(
      'signal_card_drafts',
      where: 'status = ? OR status = ?',
      whereArgs: ['pending', 'failed'],
      orderBy: 'created_at ASC',
    );
  }

  Future<void> markDraftSynced({
    required String draftId,
    required String? remoteSignalCardId,
  }) async {
    final db = await localDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'signal_card_drafts',
      {
        'status': 'synced',
        'remote_signal_card_id': remoteSignalCardId,
        'last_error': null,
        'updated_at': now,
      },
      where: 'draft_id = ?',
      whereArgs: [draftId],
    );
    await db.update(
      'signal_cards',
      {
        'sync_status': 'synced',
        'sync_failed': 0,
        'is_local_draft': remoteSignalCardId == null ? 1 : 0,
        'last_error': null,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [draftId],
    );
    if (remoteSignalCardId != null && remoteSignalCardId.trim().isNotEmpty) {
      await db.delete(
        'signal_cards',
        where: 'id = ?',
        whereArgs: [draftId],
      );
    }
  }

  Future<void> markDraftFailed({
    required String draftId,
    required String error,
  }) async {
    final db = await localDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.rawUpdate(
      '''
      UPDATE signal_card_drafts
      SET status = ?, retry_count = retry_count + 1, last_error = ?, updated_at = ?
      WHERE draft_id = ?
      ''',
      ['failed', error, now, draftId],
    );
    await db.update(
      'signal_cards',
      {
        'sync_status': 'failed',
        'sync_failed': 1,
        'last_error': error,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [draftId],
    );
  }

  Future<void> updateSignalCardConfirmation({
    required String signalCardId,
    required String userConfirmation,
    required Map<String, dynamic> userCorrectionJson,
  }) async {
    final db = await localDatabase.database;
    await db.update(
      'signal_cards',
      {
        'user_confirmation': userConfirmation,
        'user_correction_json': jsonEncode(userCorrectionJson),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ? OR signal_card_id = ?',
      whereArgs: [signalCardId, signalCardId],
    );
  }

  Future<void> updateSignalCardInclusion({
    required Iterable<String> signalCardIds,
    bool? includedInSummary,
    bool? includedInWeekly,
    bool? includedInJourney,
  }) async {
    final ids = signalCardIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (ids.isEmpty) return;

    final values = <String, Object?>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (includedInSummary != null) {
      values['included_in_summary'] = includedInSummary ? 1 : 0;
    }
    if (includedInWeekly != null) {
      values['included_in_weekly'] = includedInWeekly ? 1 : 0;
    }
    if (includedInJourney != null) {
      values['included_in_journey'] = includedInJourney ? 1 : 0;
    }

    if (values.length == 1) return;

    final db = await localDatabase.database;
    final placeholders = List.filled(ids.length, '?').join(', ');
    await db.update(
      'signal_cards',
      values,
      where: 'id IN ($placeholders) OR signal_card_id IN ($placeholders)',
      whereArgs: [...ids, ...ids],
    );
  }

  Future<void> mirrorLegacyCapturesToSignalCards() async {
    final db = await localDatabase.database;
    final rows = await db.query('captures', orderBy: 'created_at DESC');
    final batch = db.batch();
    for (final row in rows) {
      final id = row['id'] as String?;
      final content = row['content'] as String?;
      final createdAtRaw = row['created_at'] as String?;
      if (id == null || content == null || createdAtRaw == null) continue;
      final createdAt = DateTime.tryParse(createdAtRaw)?.toLocal();
      batch.insert(
        'signal_cards',
        {
          'id': 'legacy_$id',
          'signal_card_id': null,
          'raw_memory_id': id,
          'capture_id': id,
          'source_type': _sourceTypeFromInputMode(row['input_mode'] as String?),
          'raw_text': content,
          'created_at': createdAtRaw,
          'local_date': _dateKey(createdAt ?? DateTime.now()),
          'timezone': DateTime.now().timeZoneName,
          'language': null,
          'ai_reply': row['ai_acknowledgement'] as String?,
          'observation': row['ai_observation'] as String?,
          'try_next': row['ai_try_next'] as String?,
          'emotion': row['ai_emotion'] as String?,
          'intensity': row['ai_intensity'] as String?,
          'scene': null,
          'friction': null,
          'positive_signal': null,
          'energy_load': null,
          'linked_life_chain_stage': '[]',
          'raw_payload_json': null,
          'scene_tags_json': row['ai_scene_tags_json'] as String?,
          'intent_tags_json': row['ai_intent_tags_json'] as String?,
          'user_confirmation': 'unconfirmed',
          'user_correction_json': '{}',
          'included_in_summary': 0,
          'included_in_weekly': 0,
          'included_in_journey': 0,
          'privacy_level': 'private',
          'is_legacy': 1,
          'migration_status': 'local_legacy',
          'is_local_draft': 0,
          'sync_failed': 0,
          'sync_status': 'synced',
          'last_error': null,
          'updated_at': row['updated_at'] as String? ?? createdAtRaw,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<RecentSignalModel>> listRecentSignals({int limit = 10}) async {
    final db = await localDatabase.database;

    final rows = await db.query(
      'captures',
      orderBy: 'created_at DESC',
      limit: limit,
    );

    return rows.map(_mapRowToSignal).toList();
  }

  Future<List<String>> listRecentAcknowledgements({int limit = 10}) async {
    final db = await localDatabase.database;

    final rows = await db.query(
      'captures',
      columns: ['ai_acknowledgement'],
      where: 'ai_acknowledgement IS NOT NULL AND ai_acknowledgement != ?',
      whereArgs: [''],
      orderBy: 'created_at DESC',
      limit: limit,
    );

    return rows
        .map((row) => (row['ai_acknowledgement'] as String?)?.trim())
        .whereType<String>()
        .where((text) => text.isNotEmpty)
        .toList();
  }

  RecentSignalModel _mapRowToSignal(Map<String, Object?> row) {
    return RecentSignalModel(
      id: row['id'] as String?,
      content: (row['content'] as String?) ?? '',
      createdAt:
          DateTime.tryParse((row['created_at'] as String?) ?? '')?.toLocal(),
      acknowledgement: row['ai_acknowledgement'] as String?,
      observation: row['ai_observation'] as String?,
      tryNext: row['ai_try_next'] as String?,
      emotion: row['ai_emotion'] as String?,
      intensity: row['ai_intensity'] as String?,
      sceneTags: _decodeJsonStringList(row['ai_scene_tags_json']),
      intentTags: _decodeJsonStringList(row['ai_intent_tags_json']),
    );
  }

  RecentSignalModel _mapSignalCardRowToSignal(Map<String, Object?> row) {
    return RecentSignalModel(
      id: row['raw_memory_id'] as String? ?? row['id'] as String?,
      signalCardId: row['signal_card_id'] as String? ?? row['id'] as String?,
      sourceType: (row['source_type'] as String?) ?? 'text',
      content: (row['raw_text'] as String?) ?? '',
      createdAt:
          DateTime.tryParse((row['created_at'] as String?) ?? '')?.toLocal(),
      localDate: row['local_date'] as String?,
      timezone: row['timezone'] as String?,
      acknowledgement: row['ai_reply'] as String?,
      observation: row['observation'] as String?,
      tryNext: row['try_next'] as String?,
      emotion: row['emotion'] as String?,
      intensity: row['intensity'] as String?,
      scene: row['scene'] as String?,
      friction: row['friction'] as String?,
      positiveSignal: row['positive_signal'] as String?,
      energyLoad: row['energy_load'] as String?,
      linkedLifeChainStages:
          _decodeJsonStringList(row['linked_life_chain_stage']),
      rawPayloadJson: _decodeJsonMap(row['raw_payload_json']),
      sceneTags: _decodeJsonStringList(row['scene_tags_json']),
      intentTags: _decodeJsonStringList(row['intent_tags_json']),
      userConfirmation: (row['user_confirmation'] as String?) ?? 'unconfirmed',
      userCorrectionJson: _decodeJsonMap(row['user_correction_json']),
      includedInSummary: _intBool(row['included_in_summary']),
      includedInWeekly: _intBool(row['included_in_weekly']),
      includedInJourney: _intBool(row['included_in_journey']),
      privacyLevel: (row['privacy_level'] as String?) ?? 'private',
      isLegacy: _intBool(row['is_legacy']),
      migrationStatus: (row['migration_status'] as String?) ?? 'native',
      isLocalDraft: _intBool(row['is_local_draft']),
      syncFailed: _intBool(row['sync_failed']),
    );
  }

  Map<String, Object?> _signalToDbRow(
    RecentSignalModel signal,
    String stableId,
    String updatedAt,
  ) {
    return {
      'id': stableId,
      'signal_card_id': signal.signalCardId,
      'raw_memory_id': signal.id,
      'capture_id': null,
      'source_type': signal.sourceType,
      'raw_text': signal.content,
      'created_at':
          (signal.createdAt ?? DateTime.now()).toUtc().toIso8601String(),
      'local_date': signal.localDateKey(),
      'timezone': signal.timezone,
      'language': null,
      'ai_reply': signal.acknowledgement,
      'observation': signal.observation,
      'try_next': signal.tryNext,
      'emotion': signal.emotion,
      'intensity': signal.intensity,
      'scene': signal.scene,
      'friction': signal.friction,
      'positive_signal': signal.positiveSignal,
      'energy_load': signal.energyLoad,
      'linked_life_chain_stage': jsonEncode(signal.linkedLifeChainStages),
      'raw_payload_json': jsonEncode(signal.rawPayloadJson),
      'scene_tags_json': jsonEncode(signal.sceneTags),
      'intent_tags_json': jsonEncode(signal.intentTags),
      'user_confirmation': signal.userConfirmation,
      'user_correction_json': jsonEncode(signal.userCorrectionJson),
      'included_in_summary': signal.includedInSummary ? 1 : 0,
      'included_in_weekly': signal.includedInWeekly ? 1 : 0,
      'included_in_journey': signal.includedInJourney ? 1 : 0,
      'privacy_level': signal.privacyLevel,
      'is_legacy': signal.isLegacy ? 1 : 0,
      'migration_status': signal.migrationStatus,
      'is_local_draft': signal.isLocalDraft ? 1 : 0,
      'sync_failed': signal.syncFailed ? 1 : 0,
      'sync_status': signal.isLocalDraft ? 'pending' : 'synced',
      'last_error': null,
      'updated_at': updatedAt,
    };
  }

  List<String> _decodeJsonStringList(Object? raw) {
    if (raw == null) return const [];
    if (raw is List) {
      return raw
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return const [];
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          return decoded
              .map((e) => e?.toString().trim() ?? '')
              .where((e) => e.isNotEmpty)
              .toList();
        }
      } catch (_) {
        return trimmed
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    }
    return const [];
  }

  Map<String, dynamic> _decodeJsonMap(Object? raw) {
    if (raw == null) return const {};
    if (raw is Map<String, dynamic>) return raw;
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) {
          return decoded.map((key, value) => MapEntry(key.toString(), value));
        }
      } catch (_) {}
    }
    return const {};
  }

  bool _intBool(Object? raw) {
    if (raw is bool) return raw;
    if (raw is int) return raw != 0;
    if (raw is String) return raw == '1' || raw.toLowerCase() == 'true';
    return false;
  }

  String _sourceTypeFromInputMode(String? inputMode) {
    switch (inputMode) {
      case 'voice':
        return 'voice';
      case 'one_tap':
      case 'one_tap_state':
        return 'one_tap';
      case 'library_saved':
        return 'library_saved';
      case 'ai_predicted':
        return 'ai_predicted';
      default:
        return 'text';
    }
  }

  String _dateKey(DateTime date) {
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}
