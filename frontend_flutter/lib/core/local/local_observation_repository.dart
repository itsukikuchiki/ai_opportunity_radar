import 'package:sqflite/sqflite.dart';

import '../models/phase3_plus_models.dart';
import 'local_database.dart';
import 'local_trace_link_repository.dart';

class LocalObservationRepository {
  final LocalDatabase localDatabase;
  final String localUserId;

  LocalObservationRepository(
    this.localDatabase, {
    this.localUserId = 'local',
  });

  Future<void> upsertFromAiJudgement(AiJudgementModel judgement) async {
    final db = await localDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final created = judgement.createdAt?.toUtc().toIso8601String() ?? now;
    final updated = judgement.updatedAt?.toUtc().toIso8601String() ?? now;
    final observationId = observationIdForJudgement(judgement.id);
    final status = _statusFromJudgement(judgement.status);

    await db.transaction((txn) async {
      await txn.insert(
        'observations',
        {
          'id': observationId,
          'local_user_id': localUserId,
          'observation_text': judgement.judgementText,
          'observation_type': judgement.predictionKind,
          'confidence': judgement.confidenceLevel,
          'status': status,
          'source_period_start': judgement.localDate,
          'source_period_end': judgement.localDate,
          'created_by': 'l2_reason',
          'source_ai_judgement_id': judgement.id,
          'evidence_text': judgement.evidenceText,
          'suggested_pattern': judgement.suggestedPattern,
          'suggested_life_chain_stage': judgement.suggestedLifeChainStage,
          'user_adjustment_text': judgement.userAdjustmentText,
          'confirmation_note': judgement.confirmationNote,
          'created_at': created,
          'updated_at': updated,
          'confirmed_at': status == 'confirmed' ? updated : null,
          'dismissed_at': status == 'dismissed' ? updated : null,
          'archived_at': status == 'archived' ? updated : null,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete(
        'observation_signal_links',
        where: 'observation_id = ?',
        whereArgs: [observationId],
      );
      for (final signalId in judgement.sourceSignalCardIds) {
        await txn.insert(
          'observation_signal_links',
          {
            'observation_id': observationId,
            'signal_id': signalId,
            'weight': 1.0,
            'reason': 'source_signal',
            'created_at': created,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    await LocalTraceLinkRepository(localDatabase).replaceForSource(
      sourceType: 'observation',
      sourceId: observationId,
      links: judgement.sourceSignalCardIds.map(
        (signalId) => TraceLinkInput(
          sourceType: 'observation',
          sourceId: observationId,
          targetType: 'signal_card',
          targetId: signalId,
          relationType: 'evidence_signal',
          localUserId: localUserId,
          metadata: {
            'source_ai_judgement_id': judgement.id,
            'confidence': judgement.confidenceLevel,
          },
        ),
      ),
    );
  }

  Future<void> syncStatusFromAiJudgement({
    required AiJudgementModel judgement,
    required String status,
    String? userAdjustmentText,
    String? confirmationNote,
  }) async {
    final db = await localDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final observationStatus = _statusFromJudgement(status);
    await db.update(
      'observations',
      {
        'status': observationStatus,
        if (userAdjustmentText != null) ...{
          'user_adjustment_text': userAdjustmentText,
          if (userAdjustmentText.trim().isNotEmpty)
            'observation_text': userAdjustmentText.trim(),
        },
        if (confirmationNote != null) 'confirmation_note': confirmationNote,
        'updated_at': now,
        'confirmed_at': observationStatus == 'confirmed' ? now : null,
        'dismissed_at': observationStatus == 'dismissed' ? now : null,
      },
      where: 'source_ai_judgement_id = ?',
      whereArgs: [judgement.id],
    );
  }

  Future<List<Map<String, Object?>>> listForPeriod({
    required String startDate,
    required String endDate,
    List<String> statuses = const ['generated', 'confirmed'],
  }) async {
    final db = await localDatabase.database;
    final placeholders = List.filled(statuses.length, '?').join(', ');
    return db.query(
      'observations',
      where:
          'source_period_start >= ? AND source_period_start <= ? AND status IN ($placeholders)',
      whereArgs: [startDate, endDate, ...statuses],
      orderBy: 'source_period_start DESC, updated_at DESC',
    );
  }

  String observationIdForJudgement(String judgementId) => 'obs_$judgementId';

  String _statusFromJudgement(String raw) {
    final status = raw.trim().toLowerCase();
    if (const {'confirmed', 'adjusted', 'accurate', 'partial'}
        .contains(status)) {
      return 'confirmed';
    }
    if (const {'inaccurate', 'ignored', 'dismissed'}.contains(status)) {
      return 'dismissed';
    }
    if (status == 'archived') return 'archived';
    return 'generated';
  }
}
