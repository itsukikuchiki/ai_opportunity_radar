import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../debug/legacy_fallback_monitor.dart';
import '../models/today_models.dart';
import 'local_cache_invalidation_repository.dart';
import 'local_database.dart';
import 'local_trace_link_repository.dart';

class LocalCaptureRepository {
  static const Set<String> _terminalSignalConfirmations = {
    'confirmed',
    'accurate',
    'partial',
    'edited',
    'supplemented',
    'adjusted',
    'inaccurate',
  };

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
    await _backfillSplitTablesFromSignalCards(db);

    final todayKey = _dateKey(DateTime.now());
    final rows = await db.rawQuery(
      '${_signalCardSelectSql()} WHERE sc.local_date = ? ORDER BY sc.created_at DESC',
      [todayKey],
    );

    return rows.map(_mapSignalCardRowToSignal).toList();
  }

  Future<List<RecentSignalModel>> listSignalCards({int limit = 200}) async {
    final db = await localDatabase.database;
    await mirrorLegacyCapturesToSignalCards();
    await _backfillSplitTablesFromSignalCards(db);

    final rows = await db.rawQuery(
      '${_signalCardSelectSql()} ORDER BY sc.local_date DESC, sc.created_at DESC LIMIT ?',
      [limit],
    );

    return rows.map(_mapSignalCardRowToSignal).toList();
  }

  /// Loads only the Signal Cards linked by the currently visible objects.
  ///
  /// IDs are chunked because every identifier is bound twice (`id` and the
  /// remote-compatible `signal_card_id`) and SQLite commonly caps a statement
  /// at 999 bound parameters.
  Future<List<RecentSignalModel>> listSignalCardsByIds(
    Iterable<String> signalCardIds,
  ) async {
    final ids = signalCardIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (ids.isEmpty) return const [];

    final db = await localDatabase.database;
    await mirrorLegacyCapturesToSignalCards();
    await _backfillSplitTablesFromSignalCards(db);

    final byId = <String, RecentSignalModel>{};
    for (var start = 0; start < ids.length; start += 400) {
      final end = start + 400 < ids.length ? start + 400 : ids.length;
      final chunk = ids.sublist(start, end);
      final placeholders = List.filled(chunk.length, '?').join(', ');
      final rows = await db.rawQuery(
        '''
        ${_signalCardSelectSql()}
        WHERE sc.id IN ($placeholders)
           OR sc.signal_card_id IN ($placeholders)
        ORDER BY sc.local_date DESC, sc.created_at DESC
        ''',
        [...chunk, ...chunk],
      );
      for (final row in rows) {
        final signal = _mapSignalCardRowToSignal(row);
        final key = signal.id ?? signal.signalCardId ?? '';
        if (key.isNotEmpty) byId[key] = signal;
      }
    }
    final result = byId.values.toList()
      ..sort(
        (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
      );
    return result;
  }

  /// Reads one diary day without first loading an arbitrary recent-history
  /// window. This keeps every day reachable even after the account has more
  /// than a few thousand Signal Cards.
  Future<List<RecentSignalModel>> listSignalCardsForDate(
    String localDate,
  ) async {
    final db = await localDatabase.database;
    await mirrorLegacyCapturesToSignalCards();
    await _backfillSplitTablesFromSignalCards(db);

    final rows = await db.rawQuery(
      '${_signalCardSelectSql()} WHERE sc.local_date = ? ORDER BY sc.created_at DESC',
      [localDate],
    );
    return rows.map(_mapSignalCardRowToSignal).toList();
  }

  /// Lightweight, unbounded date index used by the diary calendar. Only date
  /// keys are read; full Signal Card payloads remain date-scoped.
  Future<Set<String>> listSignalCardDateKeys() async {
    final db = await localDatabase.database;
    await mirrorLegacyCapturesToSignalCards();
    await _backfillSplitTablesFromSignalCards(db);

    final rows = await db.rawQuery('''
      SELECT DISTINCT local_date
      FROM signal_cards
      WHERE local_date IS NOT NULL AND TRIM(local_date) != ''
      ORDER BY local_date ASC
    ''');
    return rows
        .map((row) => row['local_date']?.toString())
        .whereType<String>()
        .toSet();
  }

  Future<List<RecentSignalModel>> listSignalCardsBetween({
    required String startDate,
    required String endDate,
    int limit = 2000,
  }) async {
    final db = await localDatabase.database;
    await mirrorLegacyCapturesToSignalCards();
    await _backfillSplitTablesFromSignalCards(db);

    final rows = await db.rawQuery(
      '''
      ${_signalCardSelectSql()}
      WHERE sc.local_date >= ? AND sc.local_date <= ?
      ORDER BY sc.local_date ASC, sc.created_at ASC
      LIMIT ?
      ''',
      [startDate, endDate, limit],
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
    final clientId = draftId;
    final localDate = _dateKey(now);
    final tz = timezone ?? now.timeZoneName;

    await db.insert(
      'signal_card_drafts',
      {
        'draft_id': draftId,
        'client_id': clientId,
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
        'server_id': null,
        'updated_at': nowUtc.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await db.insert(
      'signal_cards',
      {
        'id': draftId,
        'signal_card_id': null,
        'client_id': clientId,
        'server_id': null,
        'raw_memory_id': null,
        'capture_id': null,
        'source_type': sourceType,
        'raw_text': content,
        'created_at': nowUtc.toIso8601String(),
        'local_date': localDate,
        'timezone': tz,
        'language': language,
        'ai_reply': _localDraftReply(language, content),
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
    await _upsertProcessingState(
      db,
      signalId: draftId,
      syncStatus: 'pending',
      isLocalDraft: true,
      syncFailed: false,
      updatedAt: nowUtc.toIso8601String(),
    );
    await _upsertAnalysisPolicy(
      db,
      signalId: draftId,
      privacyLevel: 'private',
      userConfirmation: 'unconfirmed',
      updatedAt: nowUtc.toIso8601String(),
    );
    await _upsertSyncIdentity(
      db,
      clientId: clientId,
      serverId: null,
      localSignalId: draftId,
      syncStatus: 'pending',
      updatedAt: nowUtc.toIso8601String(),
    );

    final rows = await db.query(
      'signal_cards',
      where: 'id = ?',
      whereArgs: [draftId],
      limit: 1,
    );
    return _mapSignalCardRowToSignal(rows.first);
  }

  Future<RecentSignalModel> insertConfirmedSignalCard({
    required String content,
    String? signalCardId,
    String sourceType = 'ai_predicted',
    String language = 'en',
    String? acknowledgement,
    String? observation,
    String? tryNext,
    String? scene,
    String? friction,
    String? positiveSignal,
    String? energyLoad,
    List<String> sceneTags = const [],
    List<String> intentTags = const [],
    Map<String, dynamic> rawPayloadJson = const {},
    String userConfirmation = 'confirmed',
    Map<String, dynamic> userCorrectionJson = const {},
    bool includedInSummary = true,
    bool includedInWeekly = true,
    bool includedInJourney = true,
  }) async {
    final db = await localDatabase.database;
    final now = DateTime.now();
    final nowUtc = now.toUtc();
    final id = signalCardId?.trim().isNotEmpty == true
        ? signalCardId!.trim()
        : 'sig_${_uuid.v4().replaceAll('-', '').substring(0, 12)}';
    final localDate = _dateKey(now);
    final existing = await db.query(
      'signal_cards',
      where: 'id = ? OR signal_card_id = ?',
      whereArgs: [id, id],
      limit: 1,
    );
    // A Signal Card is an immutable fact once it has been saved. Stable IDs
    // are intentionally reused by Signal Library and AI-prediction retries;
    // replaying the same confirmation must therefore be idempotent instead
    // of silently replacing the wording or structured payload.
    if (existing.isNotEmpty) {
      return _mapSignalCardRowToSignal(existing.first);
    }
    final createdAt = nowUtc.toIso8601String();

    await db.insert(
      'signal_cards',
      {
        'id': id,
        'signal_card_id': id,
        'client_id': id,
        'server_id': id,
        'raw_memory_id': null,
        'capture_id': null,
        'source_type': sourceType,
        'raw_text': content,
        'created_at': createdAt,
        'local_date': localDate,
        'timezone': now.timeZoneName,
        'language': language,
        'ai_reply': acknowledgement,
        'observation': observation,
        'try_next': tryNext,
        'emotion': null,
        'intensity': null,
        'scene': scene,
        'friction': friction,
        'positive_signal': positiveSignal,
        'energy_load': energyLoad,
        'linked_life_chain_stage': '[]',
        'raw_payload_json':
            rawPayloadJson.isEmpty ? null : jsonEncode(rawPayloadJson),
        'scene_tags_json': sceneTags.isEmpty ? null : jsonEncode(sceneTags),
        'intent_tags_json': intentTags.isEmpty ? null : jsonEncode(intentTags),
        'user_confirmation': userConfirmation,
        'user_correction_json': jsonEncode(userCorrectionJson),
        'included_in_summary': includedInSummary ? 1 : 0,
        'included_in_weekly': includedInWeekly ? 1 : 0,
        'included_in_journey': includedInJourney ? 1 : 0,
        'privacy_level': 'private',
        'is_legacy': 0,
        'migration_status': 'native',
        'is_local_draft': 0,
        'sync_failed': 0,
        'sync_status': 'local_only',
        'last_error': null,
        'updated_at': nowUtc.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _upsertProcessingState(
      db,
      signalId: id,
      syncStatus: 'local_only',
      isLocalDraft: false,
      syncFailed: false,
      includedInSummary: includedInSummary,
      includedInWeekly: includedInWeekly,
      includedInJourney: includedInJourney,
      updatedAt: nowUtc.toIso8601String(),
    );
    await _upsertAnalysisPolicy(
      db,
      signalId: id,
      privacyLevel: 'private',
      userConfirmation: userConfirmation,
      updatedAt: nowUtc.toIso8601String(),
    );
    await _upsertSyncIdentity(
      db,
      clientId: id,
      serverId: id,
      localSignalId: id,
      syncStatus: 'local_only',
      updatedAt: nowUtc.toIso8601String(),
    );

    final changed = existing.isEmpty ||
        _candidateSourceFingerprint(existing.first) !=
            _candidateSourceFingerprint({
              'id': id,
              'signal_card_id': id,
              'raw_text': content,
              'local_date': localDate,
              'user_confirmation': userConfirmation,
              'privacy_level': 'private',
              'is_local_draft': 0,
              'sync_failed': 0,
            });
    if (changed) {
      await _propagateSignalChanges(
        [
          if (existing.isNotEmpty) existing.first,
          {
            'id': id,
            'signal_card_id': id,
            'local_date': localDate,
          },
        ],
        reason: existing.isEmpty ? 'signal_added' : 'signal_content_changed',
      );
    }

    final rows = await db.query(
      'signal_cards',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return _mapSignalCardRowToSignal(rows.first);
  }

  String _localDraftReply(String language, String content) {
    final trimmed = content.trim();
    final isZhHans = language == 'zh-Hans';
    final isZhHant = language == 'zh-Hant';
    if (trimmed.contains('累') ||
        trimmed.contains('疲') ||
        trimmed.contains('耗')) {
      if (isZhHans) return '这更像一条能量信号，今天先把动作放轻一点。';
      if (isZhHant) return '這更像一條能量信號，今天先把動作放輕一點。';
    }
    if (trimmed.contains('睡') || trimmed.contains('休息')) {
      if (isZhHans) return '这可能在指向恢复，可以留意它是否反复出现。';
      if (isZhHant) return '這可能在指向恢復，可以留意它是否反覆出現。';
    }
    switch (language) {
      case 'zh-Hans':
        return '这是今天的一条生活信号。';
      case 'zh-Hant':
        return '這是今天的一條生活信號。';
      case 'ja':
        return 'これは今日の小さな生活シグナルです。';
      default:
        return 'This is one small signal from today.';
    }
  }

  Future<void> upsertRemoteSignalCards(
    List<RecentSignalModel> signals, {
    bool restoreTombstoned = false,
  }) async {
    final db = await localDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();

    for (final signal in signals) {
      final serverId = (signal.signalCardId ?? signal.id)?.trim();
      if (serverId == null || serverId.isEmpty) continue;
      final clientId = _clientIdForRemoteSignal(signal) ?? serverId;
      final stableId = await _resolveLocalSignalIdForRemote(
        db,
        clientId: clientId,
        serverId: serverId,
      );
      final tombstoneRows = await _activeTombstonesForRemote(
        db,
        stableId: stableId,
        serverId: serverId,
        clientId: clientId,
      );
      if (tombstoneRows.isNotEmpty && !restoreTombstoned) {
        continue;
      }
      final existing = await db.query(
        'signal_cards',
        where: 'id = ?',
        whereArgs: [stableId],
        limit: 1,
      );
      final row = _mergeRemoteSignalRow(
        existing.isEmpty ? null : existing.first,
        _signalToDbRow(signal, stableId, now,
            clientId: clientId, serverId: serverId),
      );
      final sourceChanged = existing.isEmpty ||
          _candidateSourceFingerprint(existing.first) !=
              _candidateSourceFingerprint(row);
      await db.insert(
        'signal_cards',
        row,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await _upsertProcessingState(
        db,
        signalId: stableId,
        syncStatus: 'synced',
        isLocalDraft: false,
        syncFailed: false,
        includedInSummary: signal.includedInSummary,
        includedInWeekly: signal.includedInWeekly,
        includedInJourney: signal.includedInJourney,
        updatedAt: now,
      );
      await _upsertAnalysisPolicy(
        db,
        signalId: stableId,
        privacyLevel: row['privacy_level']?.toString(),
        userConfirmation: row['user_confirmation']?.toString(),
        updatedAt: now,
      );
      await _upsertSyncIdentity(
        db,
        clientId: clientId,
        serverId: serverId,
        localSignalId: stableId,
        syncStatus: 'synced',
        updatedAt: now,
      );
      if (tombstoneRows.isNotEmpty) {
        await _restoreTombstones(
          db,
          tombstoneRows: tombstoneRows,
          restoredAt: now,
        );
        await _propagateSignalChanges(
          [
            {
              'id': stableId,
              'signal_card_id': serverId,
              'local_date': signal.localDateKey(),
            }
          ],
          reason: 'signal_restored',
        );
      } else if (sourceChanged) {
        await _propagateSignalChanges(
          [
            if (existing.isNotEmpty) existing.first,
            {
              'id': stableId,
              'signal_card_id': serverId,
              'local_date': signal.localDateKey(),
            },
          ],
          reason: existing.isEmpty ? 'signal_added' : 'signal_content_changed',
        );
      }
    }
  }

  Future<List<Map<String, Object?>>> listPendingDraftRows() async {
    final db = await localDatabase.database;
    final rows = await db.rawQuery(
      '''
      SELECT d.*, sc.raw_payload_json AS raw_payload_json
      FROM signal_card_drafts d
      LEFT JOIN signal_cards sc ON sc.id = d.draft_id
      WHERE d.status = ? OR d.status = ?
      ORDER BY d.created_at ASC
      ''',
      ['pending', 'failed'],
    );
    return rows
        .map(
          (row) => <String, Object?>{
            ...row,
            'raw_payload_json': _decodeJsonMap(row['raw_payload_json']),
          },
        )
        .toList(growable: false);
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
        'server_id': remoteSignalCardId,
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
    await _upsertSyncIdentity(
      db,
      clientId: draftId,
      serverId: null,
      localSignalId: draftId,
      syncStatus: 'failed',
      updatedAt: now,
    );
    await _upsertProcessingState(
      db,
      signalId: draftId,
      syncStatus: 'synced',
      isLocalDraft: remoteSignalCardId == null,
      syncFailed: false,
      lastError: null,
      updatedAt: now,
    );
    final draftRows = await db.query(
      'signal_card_drafts',
      columns: ['client_id'],
      where: 'draft_id = ?',
      whereArgs: [draftId],
      limit: 1,
    );
    final clientId = (draftRows.isEmpty
            ? null
            : draftRows.first['client_id']?.toString().trim()) ??
        draftId;
    await _upsertSyncIdentity(
      db,
      clientId: clientId.isEmpty ? draftId : clientId,
      serverId: remoteSignalCardId,
      localSignalId: remoteSignalCardId?.trim().isNotEmpty == true
          ? remoteSignalCardId!.trim()
          : draftId,
      syncStatus: remoteSignalCardId == null ? 'pending' : 'synced',
      updatedAt: now,
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
    await _upsertProcessingState(
      db,
      signalId: draftId,
      syncStatus: 'failed',
      isLocalDraft: true,
      syncFailed: true,
      lastError: error,
      updatedAt: now,
    );
  }

  Future<void> updateSignalCardConfirmation({
    required String signalCardId,
    required String userConfirmation,
    required Map<String, dynamic> userCorrectionJson,
  }) async {
    final db = await localDatabase.database;
    final currentRows = await db.query(
      'signal_cards',
      columns: ['id', 'signal_card_id', 'user_confirmation'],
      where: 'id = ? OR signal_card_id = ?',
      whereArgs: [signalCardId, signalCardId],
      limit: 1,
    );
    if (currentRows.isEmpty) {
      throw StateError('signal_card_not_found');
    }
    final currentConfirmation = currentRows.first['user_confirmation']
            ?.toString()
            .trim()
            .toLowerCase() ??
        'unconfirmed';
    if (currentConfirmation != 'unconfirmed') {
      throw StateError('saved_signal_card_is_immutable');
    }
    final normalizedConfirmation = userConfirmation.trim().toLowerCase();
    if (!_terminalSignalConfirmations.contains(normalizedConfirmation)) {
      throw ArgumentError.value(
        userConfirmation,
        'userConfirmation',
        'confirmation_must_be_terminal',
      );
    }
    final affectedBefore = await _affectedSignalRows(db, [signalCardId]);
    await db.update(
      'signal_cards',
      {
        'user_confirmation': normalizedConfirmation,
        'user_correction_json': jsonEncode(userCorrectionJson),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ? OR signal_card_id = ?',
      whereArgs: [signalCardId, signalCardId],
    );
    final resolvedIds = await _resolveSignalIds(db, [signalCardId]);
    final now = DateTime.now().toUtc().toIso8601String();
    for (final id in resolvedIds) {
      await _upsertAnalysisPolicy(
        db,
        signalId: id,
        userConfirmation: normalizedConfirmation,
        updatedAt: now,
      );
      if (normalizedConfirmation == 'inaccurate') {
        await LocalTraceLinkRepository(localDatabase).markInactiveForTarget(
          targetType: 'signal_card',
          targetId: id,
        );
      }
    }
    await _propagateSignalChanges(
      affectedBefore,
      reason: normalizedConfirmation == 'inaccurate'
          ? 'signal_marked_inaccurate'
          : 'signal_confirmation_changed',
    );
  }

  Future<void> updateSignalCardPrivacy({
    required String signalCardId,
    required String privacyLevel,
  }) async {
    final normalized = privacyLevel.trim().isEmpty
        ? 'private'
        : privacyLevel.trim().toLowerCase();
    final db = await localDatabase.database;
    final affectedBefore = await _affectedSignalRows(db, [signalCardId]);
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'signal_cards',
      {
        'privacy_level': normalized,
        'updated_at': now,
      },
      where: 'id = ? OR signal_card_id = ?',
      whereArgs: [signalCardId, signalCardId],
    );
    final resolvedIds = await _resolveSignalIds(db, [signalCardId]);
    for (final id in resolvedIds) {
      await _upsertAnalysisPolicy(
        db,
        signalId: id,
        privacyLevel: normalized,
        updatedAt: now,
      );
      if (_isPrivacyExcluded(normalized)) {
        await LocalTraceLinkRepository(localDatabase).markInactiveForTarget(
          targetType: 'signal_card',
          targetId: id,
        );
      }
    }
    await _propagateSignalChanges(
      affectedBefore,
      reason: _isPrivacyExcluded(normalized)
          ? 'signal_privacy_excluded'
          : 'signal_privacy_changed',
    );
  }

  Future<void> deleteSignalCard(
    String signalCardId, {
    String reason = 'user_deleted',
  }) async {
    final db = await localDatabase.database;
    final affectedBefore = await _affectedSignalRows(db, [signalCardId]);
    final resolvedIds = await _resolveSignalIds(db, [signalCardId]);
    final idsToDelete = {
      signalCardId,
      for (final row in affectedBefore) ...[
        if ((row['id'] as String?)?.trim().isNotEmpty == true)
          row['id'] as String,
        if ((row['signal_card_id'] as String?)?.trim().isNotEmpty == true)
          row['signal_card_id'] as String,
      ],
      ...resolvedIds,
    };
    await _writeTombstones(
      db,
      affectedRows: affectedBefore,
      fallbackSignalId: signalCardId,
      reason: reason,
    );
    for (final id in idsToDelete) {
      await LocalTraceLinkRepository(localDatabase).markInactiveForTarget(
        targetType: 'signal_card',
        targetId: id,
      );
    }
    await db.delete(
      'signal_cards',
      where: 'id = ? OR signal_card_id = ?',
      whereArgs: [signalCardId, signalCardId],
    );
    await db.delete(
      'signal_processing_state',
      where:
          'signal_id IN (${List.filled(idsToDelete.length, '?').join(', ')})',
      whereArgs: idsToDelete.toList(),
    );
    await db.delete(
      'signal_analysis_policy',
      where:
          'signal_id IN (${List.filled(idsToDelete.length, '?').join(', ')})',
      whereArgs: idsToDelete.toList(),
    );
    await _propagateSignalChanges(
      affectedBefore,
      reason: 'signal_deleted',
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
    final resolvedIds = await _resolveSignalIds(db, ids);
    for (final id in resolvedIds) {
      await _upsertProcessingState(
        db,
        signalId: id,
        includedInSummary: includedInSummary,
        includedInWeekly: includedInWeekly,
        includedInJourney: includedInJourney,
        updatedAt: values['updated_at'] as String,
      );
    }
  }

  Future<void> mirrorLegacyCapturesToSignalCards() async {
    final db = await localDatabase.database;
    final rows = await db.query('captures', orderBy: 'created_at DESC');
    if (rows.isNotEmpty) {
      LegacyFallbackMonitor.record(LegacyFallbackMonitor.capturesMirror);
    }
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
          'client_id': 'legacy_$id',
          'server_id': null,
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
    await _backfillSplitTablesFromSignalCards(db);
    await _backfillSyncIdentityFromSignalCards(db);
  }

  Future<List<RecentSignalModel>> listRecentSignals({int limit = 10}) async {
    final db = await localDatabase.database;

    final rows = await db.query(
      'captures',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    if (rows.isNotEmpty) {
      LegacyFallbackMonitor.record(LegacyFallbackMonitor.capturesRawRead);
    }

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
      clientId: row['client_id'] as String?,
      serverId: row['server_id'] as String? ?? row['signal_card_id'] as String?,
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
      includedInSummary: _stageIncluded(
        row['processing_daily_status'],
        row['included_in_summary'],
      ),
      includedInWeekly: _stageIncluded(
        row['processing_weekly_status'],
        row['included_in_weekly'],
      ),
      includedInJourney: _stageIncluded(
        row['processing_journey_status'],
        row['included_in_journey'],
      ),
      privacyLevel: _privacyLevelFromRow(row),
      isLegacy: _intBool(row['is_legacy']),
      migrationStatus: (row['migration_status'] as String?) ?? 'native',
      isLocalDraft:
          _intBool(row['processing_is_local_draft'] ?? row['is_local_draft']),
      syncFailed: _intBool(row['processing_sync_failed'] ?? row['sync_failed']),
    );
  }

  String _signalCardSelectSql() {
    return '''
      SELECT
        sc.*,
        sps.sync_status AS processing_sync_status,
        sps.daily_status AS processing_daily_status,
        sps.weekly_status AS processing_weekly_status,
        sps.journey_status AS processing_journey_status,
        sps.is_local_draft AS processing_is_local_draft,
        sps.sync_failed AS processing_sync_failed,
        sap.privacy_level AS policy_privacy_level,
        sap.inaccurate AS policy_inaccurate
      FROM signal_cards sc
      LEFT JOIN signal_processing_state sps ON sps.signal_id = sc.id
      LEFT JOIN signal_analysis_policy sap ON sap.signal_id = sc.id
    ''';
  }

  bool _stageIncluded(Object? stageStatus, Object? legacyIncluded) {
    final status = stageStatus?.toString().trim().toLowerCase();
    if (status == 'included' || status == 'processed') return true;
    if (status == 'excluded' || status == 'dirty') return false;
    if (legacyIncluded != null) {
      LegacyFallbackMonitor.record(
        LegacyFallbackMonitor.signalInclusionField,
      );
    }
    return _intBool(legacyIncluded);
  }

  String _privacyLevelFromRow(Map<String, Object?> row) {
    final policyPrivacy = (row['policy_privacy_level'] as String?)?.trim();
    if (policyPrivacy != null && policyPrivacy.isNotEmpty) {
      return policyPrivacy;
    }
    final legacyPrivacy = (row['privacy_level'] as String?)?.trim();
    if (legacyPrivacy != null && legacyPrivacy.isNotEmpty) {
      LegacyFallbackMonitor.record(LegacyFallbackMonitor.signalPrivacyField);
      return legacyPrivacy;
    }
    return 'private';
  }

  Future<void> _backfillSplitTablesFromSignalCards(Database db) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await db.rawInsert(
      '''
      INSERT OR IGNORE INTO signal_processing_state (
        signal_id,
        sync_status,
        daily_status,
        weekly_status,
        journey_status,
        is_local_draft,
        sync_failed,
        last_error,
        created_at,
        updated_at
      )
      SELECT
        id,
        COALESCE(sync_status, 'synced'),
        CASE WHEN included_in_summary = 1 THEN 'included' ELSE 'not_started' END,
        CASE WHEN included_in_weekly = 1 THEN 'included' ELSE 'not_started' END,
        CASE WHEN included_in_journey = 1 THEN 'included' ELSE 'not_started' END,
        COALESCE(is_local_draft, 0),
        COALESCE(sync_failed, 0),
        last_error,
        ?,
        COALESCE(updated_at, ?)
      FROM signal_cards
      ''',
      [now, now],
    );
    await db.rawInsert(
      '''
      INSERT OR IGNORE INTO signal_analysis_policy (
        signal_id,
        privacy_level,
        is_sensitive,
        is_excluded,
        do_not_analyze,
        confirmed_by_user,
        inaccurate,
        exclusion_reason,
        updated_at
      )
      SELECT
        id,
        COALESCE(privacy_level, 'private'),
        CASE WHEN privacy_level = 'sensitive' THEN 1 ELSE 0 END,
        CASE WHEN privacy_level = 'excluded' THEN 1 ELSE 0 END,
        CASE WHEN privacy_level = 'do_not_analyze' THEN 1 ELSE 0 END,
        CASE WHEN user_confirmation IN ('confirmed', 'edited', 'supplemented') THEN 1 ELSE 0 END,
        CASE WHEN user_confirmation = 'inaccurate' THEN 1 ELSE 0 END,
        CASE
          WHEN user_confirmation = 'inaccurate' THEN 'inaccurate'
          WHEN privacy_level IN ('sensitive', 'excluded', 'do_not_analyze') THEN privacy_level
          ELSE NULL
        END,
        COALESCE(updated_at, ?)
      FROM signal_cards
      ''',
      [now],
    );
  }

  Future<void> _backfillSyncIdentityFromSignalCards(Database db) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await db.rawUpdate('''
      UPDATE signal_cards
      SET
        client_id = COALESCE(client_id, id),
        server_id = COALESCE(server_id, signal_card_id)
      WHERE client_id IS NULL OR server_id IS NULL
    ''');
    await db.rawInsert(
      '''
      INSERT OR IGNORE INTO signal_sync_identity (
        client_id,
        server_id,
        local_signal_id,
        sync_status,
        last_synced_at,
        created_at,
        updated_at
      )
      SELECT
        COALESCE(client_id, id),
        COALESCE(server_id, signal_card_id),
        id,
        COALESCE(sync_status, 'synced'),
        CASE WHEN COALESCE(sync_status, 'synced') = 'synced' THEN COALESCE(updated_at, ?) ELSE NULL END,
        COALESCE(created_at, ?),
        COALESCE(updated_at, ?)
      FROM signal_cards
      ''',
      [now, now, now],
    );
  }

  Future<Set<String>> _resolveSignalIds(
    Database db,
    Iterable<String> signalCardIds,
  ) async {
    final ids = signalCardIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (ids.isEmpty) return {};
    final placeholders = List.filled(ids.length, '?').join(', ');
    final rows = await db.query(
      'signal_cards',
      columns: ['id'],
      where: 'id IN ($placeholders) OR signal_card_id IN ($placeholders)',
      whereArgs: [...ids, ...ids],
    );
    return rows
        .map((row) => row['id']?.toString().trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Future<List<Map<String, Object?>>> _activeTombstonesForRemote(
    Database db, {
    required String stableId,
    required String serverId,
    required String clientId,
  }) {
    return db.query(
      'signal_tombstones',
      where: '''
        status = ?
        AND (
          signal_id = ?
          OR signal_card_id = ?
          OR server_id = ?
          OR client_id = ?
        )
      ''',
      whereArgs: ['active', stableId, serverId, serverId, clientId],
    );
  }

  Future<void> _writeTombstones(
    Database db, {
    required Iterable<Map<String, Object?>> affectedRows,
    required String fallbackSignalId,
    required String reason,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = affectedRows.toList(growable: false);
    if (rows.isEmpty) {
      await db.insert(
        'signal_tombstones',
        {
          'signal_id': fallbackSignalId,
          'signal_card_id': fallbackSignalId,
          'client_id': null,
          'server_id': fallbackSignalId,
          'local_date': null,
          'reason': reason,
          'status': 'active',
          'deleted_at': now,
          'restored_at': null,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return;
    }

    for (final row in rows) {
      final signalId = (row['id'] as String?)?.trim();
      if (signalId == null || signalId.isEmpty) continue;
      await db.insert(
        'signal_tombstones',
        {
          'signal_id': signalId,
          'signal_card_id': row['signal_card_id'] as String?,
          'client_id': row['client_id'] as String?,
          'server_id': row['server_id'] as String?,
          'local_date': row['local_date'] as String?,
          'reason': reason,
          'status': 'active',
          'deleted_at': now,
          'restored_at': null,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> _restoreTombstones(
    Database db, {
    required Iterable<Map<String, Object?>> tombstoneRows,
    required String restoredAt,
  }) async {
    final ids = tombstoneRows
        .map((row) => (row['signal_id'] as String?)?.trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    if (ids.isEmpty) return;
    final placeholders = List.filled(ids.length, '?').join(', ');
    await db.update(
      'signal_tombstones',
      {
        'status': 'restored',
        'restored_at': restoredAt,
        'updated_at': restoredAt,
      },
      where: 'signal_id IN ($placeholders)',
      whereArgs: ids.toList(),
    );
  }

  Future<List<Map<String, Object?>>> _affectedSignalRows(
    Database db,
    Iterable<String> signalCardIds,
  ) async {
    final ids = signalCardIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (ids.isEmpty) return const [];
    final placeholders = List.filled(ids.length, '?').join(', ');
    return db.query(
      'signal_cards',
      columns: ['id', 'signal_card_id', 'client_id', 'server_id', 'local_date'],
      where: 'id IN ($placeholders) OR signal_card_id IN ($placeholders)',
      whereArgs: [...ids, ...ids],
    );
  }

  Future<void> _propagateSignalChanges(
    Iterable<Map<String, Object?>> affectedRows, {
    required String reason,
  }) async {
    final rows = affectedRows.toList(growable: false);
    if (rows.isEmpty) return;
    final ids = <String>{
      for (final row in rows)
        if ((row['id'] as String?)?.trim().isNotEmpty == true)
          row['id'] as String,
      for (final row in rows)
        if ((row['signal_card_id'] as String?)?.trim().isNotEmpty == true)
          row['signal_card_id'] as String,
    };
    final dates = <String>{
      for (final row in rows)
        if ((row['local_date'] as String?)?.trim().isNotEmpty == true)
          row['local_date'] as String,
    };
    for (final localDate in dates) {
      await LocalCacheInvalidationRepository(localDatabase).markSignalChanged(
        localDate: localDate,
        reason: reason,
        signalIds: ids,
      );
    }
  }

  String _candidateSourceFingerprint(Map<String, Object?> row) {
    return [
      row['raw_text']?.toString().trim() ?? '',
      row['local_date']?.toString().trim() ?? '',
      row['user_confirmation']?.toString().trim() ?? '',
      row['privacy_level']?.toString().trim() ?? '',
      row['is_local_draft']?.toString() ?? '0',
      row['sync_failed']?.toString() ?? '0',
    ].join('|');
  }

  bool _isPrivacyExcluded(String privacyLevel) {
    return privacyLevel == 'sensitive' ||
        privacyLevel == 'excluded' ||
        privacyLevel == 'do_not_analyze';
  }

  Future<void> _upsertProcessingState(
    Database db, {
    required String signalId,
    String? syncStatus,
    bool? isLocalDraft,
    bool? syncFailed,
    bool? includedInSummary,
    bool? includedInWeekly,
    bool? includedInJourney,
    String? lastError,
    required String updatedAt,
  }) async {
    final existing = await db.query(
      'signal_processing_state',
      where: 'signal_id = ?',
      whereArgs: [signalId],
      limit: 1,
    );
    String stage(bool? included) {
      if (included == null) return 'not_started';
      return included ? 'included' : 'not_started';
    }

    final values = <String, Object?>{
      'signal_id': signalId,
      'sync_status': syncStatus ?? 'synced',
      'assist_status': 'not_started',
      'reason_status': 'not_started',
      'daily_status': stage(includedInSummary),
      'weekly_status': stage(includedInWeekly),
      'journey_status': stage(includedInJourney),
      'is_local_draft': (isLocalDraft ?? false) ? 1 : 0,
      'sync_failed': (syncFailed ?? false) ? 1 : 0,
      'last_error': lastError,
      'retry_count': 0,
      'processing_version': 'v4_p0_02',
      'last_processed_at': null,
      'created_at': updatedAt,
      'updated_at': updatedAt,
    };

    if (existing.isEmpty) {
      await db.insert(
        'signal_processing_state',
        values,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return;
    }

    final updates = <String, Object?>{
      'updated_at': updatedAt,
    };
    if (syncStatus != null) updates['sync_status'] = syncStatus;
    if (isLocalDraft != null) updates['is_local_draft'] = isLocalDraft ? 1 : 0;
    if (syncFailed != null) updates['sync_failed'] = syncFailed ? 1 : 0;
    if (lastError != null || syncFailed == false) {
      updates['last_error'] = lastError;
    }
    if (includedInSummary != null) {
      updates['daily_status'] = stage(includedInSummary);
    }
    if (includedInWeekly != null) {
      updates['weekly_status'] = stage(includedInWeekly);
    }
    if (includedInJourney != null) {
      updates['journey_status'] = stage(includedInJourney);
    }

    await db.update(
      'signal_processing_state',
      updates,
      where: 'signal_id = ?',
      whereArgs: [signalId],
    );
  }

  Future<void> _upsertAnalysisPolicy(
    Database db, {
    required String signalId,
    String? privacyLevel,
    String? userConfirmation,
    required String updatedAt,
  }) async {
    final existing = await db.query(
      'signal_analysis_policy',
      where: 'signal_id = ?',
      whereArgs: [signalId],
      limit: 1,
    );
    final signalRows = await db.query(
      'signal_cards',
      columns: ['privacy_level', 'user_confirmation'],
      where: 'id = ? OR signal_card_id = ?',
      whereArgs: [signalId, signalId],
      limit: 1,
    );
    final existingPolicy = existing.isEmpty ? null : existing.first;
    final signalRow = signalRows.isEmpty ? null : signalRows.first;
    final resolvedPrivacy = privacyLevel ??
        existingPolicy?['privacy_level'] as String? ??
        signalRow?['privacy_level'] as String? ??
        'private';
    final resolvedConfirmation = userConfirmation ??
        signalRow?['user_confirmation'] as String? ??
        (existingPolicy?['confirmed_by_user'] == 1 ? 'confirmed' : null);
    final inaccurate = resolvedConfirmation == 'inaccurate';
    final confirmed = resolvedConfirmation != null &&
        _terminalSignalConfirmations.contains(resolvedConfirmation) &&
        resolvedConfirmation != 'inaccurate';
    final exclusionReason = inaccurate
        ? 'inaccurate'
        : _isPrivacyExcluded(resolvedPrivacy)
            ? resolvedPrivacy
            : null;

    final insertValues = <String, Object?>{
      'signal_id': signalId,
      'privacy_level': resolvedPrivacy,
      'is_sensitive': resolvedPrivacy == 'sensitive' ? 1 : 0,
      'is_excluded': resolvedPrivacy == 'excluded' ? 1 : 0,
      'do_not_analyze': resolvedPrivacy == 'do_not_analyze' ? 1 : 0,
      'requires_user_confirmation': 0,
      'confirmed_by_user': confirmed ? 1 : 0,
      'inaccurate': inaccurate ? 1 : 0,
      'exclusion_reason': exclusionReason,
      'updated_at': updatedAt,
    };

    if (existing.isEmpty) {
      await db.insert(
        'signal_analysis_policy',
        insertValues,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return;
    }

    final updates = <String, Object?>{
      'updated_at': updatedAt,
    };
    if (privacyLevel != null) {
      updates.addAll({
        'privacy_level': resolvedPrivacy,
        'is_sensitive': resolvedPrivacy == 'sensitive' ? 1 : 0,
        'is_excluded': resolvedPrivacy == 'excluded' ? 1 : 0,
        'do_not_analyze': resolvedPrivacy == 'do_not_analyze' ? 1 : 0,
      });
    }
    if (userConfirmation != null) {
      updates.addAll({
        'confirmed_by_user': confirmed ? 1 : 0,
        'inaccurate': inaccurate ? 1 : 0,
        'exclusion_reason': exclusionReason,
      });
    }
    if (privacyLevel != null && userConfirmation == null) {
      updates['exclusion_reason'] = exclusionReason;
    }

    await db.update(
      'signal_analysis_policy',
      updates,
      where: 'signal_id = ?',
      whereArgs: [signalId],
    );
  }

  Future<void> _upsertSyncIdentity(
    Database db, {
    required String clientId,
    required String? serverId,
    required String localSignalId,
    required String syncStatus,
    required String updatedAt,
  }) async {
    await db.insert(
      'signal_sync_identity',
      {
        'client_id': clientId,
        'server_id': serverId,
        'local_signal_id': localSignalId,
        'sync_status': syncStatus,
        'last_synced_at': syncStatus == 'synced' ? updatedAt : null,
        'created_at': updatedAt,
        'updated_at': updatedAt,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String> _resolveLocalSignalIdForRemote(
    Database db, {
    required String clientId,
    required String serverId,
  }) async {
    final byServer = await db.query(
      'signal_sync_identity',
      columns: ['local_signal_id'],
      where: 'server_id = ?',
      whereArgs: [serverId],
      limit: 1,
    );
    if (byServer.isNotEmpty) {
      return byServer.first['local_signal_id']?.toString() ?? serverId;
    }

    final byClient = await db.query(
      'signal_sync_identity',
      columns: ['local_signal_id'],
      where: 'client_id = ?',
      whereArgs: [clientId],
      limit: 1,
    );
    if (byClient.isNotEmpty) {
      final localId = byClient.first['local_signal_id']?.toString();
      if (localId != null && localId.startsWith('draft_')) {
        return serverId;
      }
      return localId ?? serverId;
    }

    return serverId;
  }

  String? _clientIdForRemoteSignal(RecentSignalModel signal) {
    final explicit = signal.rawPayloadJson['client_id'] ??
        signal.rawPayloadJson['clientId'] ??
        signal.rawPayloadJson['_client_id'];
    final text = explicit?.toString().trim();
    if (text != null && text.isNotEmpty) return text;
    final modelClientId = signal.clientId?.trim();
    if (modelClientId != null && modelClientId.isNotEmpty) {
      return modelClientId;
    }
    return null;
  }

  Map<String, Object?> _mergeRemoteSignalRow(
    Map<String, Object?>? existing,
    Map<String, Object?> remote,
  ) {
    if (existing == null) return remote;
    final merged = Map<String, Object?>.from(remote);
    final localUpdatedAt =
        DateTime.tryParse(existing['updated_at']?.toString() ?? '');
    final remoteUpdatedAt =
        DateTime.tryParse(remote['updated_at']?.toString() ?? '');
    final localIsNewer = localUpdatedAt != null &&
        remoteUpdatedAt != null &&
        localUpdatedAt.isAfter(remoteUpdatedAt);
    final localConfirmation =
        existing['user_confirmation']?.toString().trim() ?? '';
    final localIsFinal = _terminalSignalConfirmations.contains(
      localConfirmation.toLowerCase(),
    );

    // Remote refreshes may enrich AI-owned fields, but must never rewrite the
    // user-owned fact. This also keeps an already-final confirmation terminal
    // when an older server projection still says `unconfirmed`.
    for (final field in const [
      'raw_text',
      'source_type',
      'created_at',
      'local_date',
      'timezone',
      'language',
      'raw_payload_json',
    ]) {
      merged[field] = existing[field];
    }
    if (localIsFinal) {
      merged['user_confirmation'] = existing['user_confirmation'];
      merged['user_correction_json'] = existing['user_correction_json'];
    }
    if (localIsNewer) {
      merged['privacy_level'] = existing['privacy_level'];
    }
    return merged;
  }

  Map<String, Object?> _signalToDbRow(
    RecentSignalModel signal,
    String stableId,
    String updatedAt, {
    required String clientId,
    required String serverId,
  }) {
    return {
      'id': stableId,
      'signal_card_id': serverId,
      'client_id': clientId,
      'server_id': serverId,
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
      case 'time_use':
        return 'time_use';
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
