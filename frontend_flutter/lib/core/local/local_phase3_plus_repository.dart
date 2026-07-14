import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/phase3_plus_models.dart';
import 'local_cache_invalidation_repository.dart';
import 'local_database.dart';
import 'local_observation_repository.dart';
import 'local_trace_link_repository.dart';

class LocalPhase3PlusRepository {
  final LocalDatabase localDatabase;
  final String localUserId;
  final Uuid _uuid = const Uuid();

  LocalPhase3PlusRepository(
    this.localDatabase, {
    this.localUserId = 'local',
  });

  String createId(String prefix) => _id(prefix);

  String todayKey() => _dateKey(DateTime.now());

  Future<AiJudgementModel?> getAiJudgementForDate(String localDate) async {
    final db = await localDatabase.database;
    final rows = await db.query(
      'ai_judgements',
      where: 'local_date = ?',
      whereArgs: [localDate],
      orderBy: 'updated_at DESC, created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AiJudgementModel.fromDb(rows.first);
  }

  Future<AiJudgementModel?> getAiJudgementById(String id) async {
    final db = await localDatabase.database;
    final rows = await db.query(
      'ai_judgements',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AiJudgementModel.fromDb(rows.first);
  }

  Future<void> upsertAiJudgement(AiJudgementModel model) async {
    final db = await localDatabase.database;
    await db.insert(
      'ai_judgements',
      model.toDb(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await LocalObservationRepository(
      localDatabase,
      localUserId: localUserId,
    ).upsertFromAiJudgement(model);
  }

  Future<void> updateAiJudgementStatus({
    required String id,
    required String status,
    String? userAdjustmentText,
    String? confirmationNote,
    String? linkedMicroActionId,
    bool? includedInWeekly,
    bool? includedInJourney,
  }) async {
    final db = await localDatabase.database;
    final values = <String, Object?>{
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (userAdjustmentText != null) {
      values['user_adjustment_text'] = userAdjustmentText;
    }
    if (confirmationNote != null) {
      values['confirmation_note'] = confirmationNote;
    }
    if (linkedMicroActionId != null) {
      values['linked_micro_action_id'] = linkedMicroActionId;
    }
    if (includedInWeekly != null) {
      values['included_in_weekly'] = includedInWeekly ? 1 : 0;
    }
    if (includedInJourney != null) {
      values['included_in_journey'] = includedInJourney ? 1 : 0;
    }
    await db.update(
      'ai_judgements',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
    final judgement = await getAiJudgementById(id);
    if (judgement != null) {
      await LocalObservationRepository(
        localDatabase,
        localUserId: localUserId,
      ).syncStatusFromAiJudgement(
        judgement: judgement,
        status: status,
        userAdjustmentText: userAdjustmentText,
        confirmationNote: confirmationNote,
      );
    }
  }

  Future<List<MicroActionModel>> listMicroActionsForDate(
    String localDate,
  ) async {
    final db = await localDatabase.database;
    final rows = await db.query(
      'micro_actions',
      where: 'planned_date = ?',
      whereArgs: [localDate],
      orderBy: 'updated_at DESC, created_at DESC',
    );
    return rows.map(MicroActionModel.fromDb).toList();
  }

  Future<MicroActionModel?> getMicroActionById(String id) async {
    final db = await localDatabase.database;
    final rows = await db.query(
      'micro_actions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MicroActionModel.fromDb(rows.first);
  }

  Future<void> upsertMicroAction(MicroActionModel model) async {
    final db = await localDatabase.database;
    await db.insert(
      'micro_actions',
      model.toDb(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateMicroActionStatus({
    required String id,
    required String status,
    String? feedbackStatus,
  }) async {
    final db = await localDatabase.database;
    final values = <String, Object?>{
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (feedbackStatus != null) {
      values['feedback_status'] = feedbackStatus;
    }
    await db.update(
      'micro_actions',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> insertMicroActionFeedback(
    MicroActionFeedbackModel feedback,
  ) async {
    final db = await localDatabase.database;
    await db.insert(
      'micro_action_feedback',
      feedback.toDb(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await LocalTraceLinkRepository(localDatabase).upsert(
      TraceLinkInput(
        sourceType: 'micro_action_feedback',
        sourceId: feedback.id,
        targetType: 'micro_action',
        targetId: feedback.microActionId,
        relationType: 'feedback_for',
        localUserId: localUserId,
        metadata: {
          'local_date': feedback.localDate,
          'happened': feedback.happened,
        },
      ),
    );
    await LocalCacheInvalidationRepository(localDatabase)
        .markMicroActionChanged(
      localDate: feedback.localDate,
      reason: 'micro_action_feedback_changed',
    );
  }

  Future<List<MicroActionFeedbackModel>> listMicroActionFeedbacksBetween({
    required String startDate,
    required String endDate,
  }) async {
    final db = await localDatabase.database;
    final rows = await db.query(
      'micro_action_feedback',
      where: 'local_date >= ? AND local_date <= ?',
      whereArgs: [startDate, endDate],
      orderBy: 'local_date ASC, created_at ASC',
    );
    return rows.map(MicroActionFeedbackModel.fromDb).toList(growable: false);
  }

  Future<Map<String, dynamic>> summarizeActionLoop({
    required String startDate,
    required String endDate,
  }) async {
    final db = await localDatabase.database;
    final judgementRows = await db.query(
      'ai_judgements',
      where: 'local_date >= ? AND local_date <= ?',
      whereArgs: [startDate, endDate],
      orderBy: 'created_at DESC',
    );
    final observationRows = await LocalObservationRepository(localDatabase)
        .listForPeriod(startDate: startDate, endDate: endDate);
    final actionRows = await db.query(
      'micro_actions',
      where:
          '(planned_date >= ? AND planned_date <= ?) OR planned_date IS NULL',
      whereArgs: [startDate, endDate],
      orderBy: 'created_at DESC',
    );
    final feedbackRows = await db.query(
      'micro_action_feedback',
      where: 'local_date >= ? AND local_date <= ?',
      whereArgs: [startDate, endDate],
      orderBy: 'created_at DESC',
    );

    final judgements =
        judgementRows.map(AiJudgementModel.fromDb).toList(growable: false);
    final actions =
        actionRows.map(MicroActionModel.fromDb).toList(growable: false);
    final feedbacks = feedbackRows
        .map(MicroActionFeedbackModel.fromDb)
        .toList(growable: false);
    final actionsById = {for (final action in actions) action.id: action};

    final confirmedJudgementCount = judgements
        .where((judgement) => _isConfirmedJudgementStatus(judgement.status))
        .length;
    final triedActionIds = <String>{
      for (final action in actions)
        if (_isTriedActionStatus(action.status) ||
            _isHelpfulFeedbackStatus(action.feedbackStatus))
          action.id,
      for (final feedback in feedbacks)
        if (_isHappenedFeedback(feedback.happened)) feedback.microActionId,
    };
    final helpfulFeedbacks = feedbacks
        .where((feedback) => _isHelpfulFeedbackStatus(feedback.effect))
        .toList(growable: false);
    final helpfulActionIds = <String>{
      for (final action in actions)
        if (_isHelpfulFeedbackStatus(action.feedbackStatus)) action.id,
      for (final feedback in helpfulFeedbacks) feedback.microActionId,
    };
    final hardFeedback = _firstOrNull(feedbacks.where(_isHardFeedback));
    final helpfulAction = _firstOrNull(
          helpfulFeedbacks
              .map((feedback) => actionsById[feedback.microActionId])
              .whereType<MicroActionModel>(),
        ) ??
        _firstOrNull(
          actions.where((action) =>
              _isHelpfulFeedbackStatus(action.feedbackStatus) ||
              action.isActive),
        );
    final hardAction = hardFeedback == null
        ? _firstOrNull(
            actions.where((action) =>
                action.feedbackStatus == 'not_helpful' ||
                action.status == 'skipped'),
          )
        : actionsById[hardFeedback.microActionId];

    return {
      'ai_judgement_count': judgements.length,
      'confirmed_judgement_count': confirmedJudgementCount,
      'observation_count': observationRows.length,
      'confirmed_observation_count':
          observationRows.where((row) => row['status'] == 'confirmed').length,
      'observation_ids': observationRows
          .map((row) => row['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList(),
      'observation_texts': observationRows
          .map((row) => row['observation_text']?.toString().trim() ?? '')
          .where((text) => text.isNotEmpty)
          .take(5)
          .toList(),
      'generated_action_count': actions.length,
      'tried_action_count': triedActionIds.length,
      'helpful_action_count': helpfulActionIds.length,
      'most_helpful_action': helpfulAction?.title ?? '',
      'hardest_action': hardAction?.title ?? '',
      'next_adjustment': _deriveNextAdjustment(
        feedbacks: feedbacks,
        helpfulActionCount: helpfulActionIds.length,
        triedActionCount: triedActionIds.length,
      ),
      'linked_micro_action_ids': actions.map((action) => action.id).toList(),
    };
  }

  bool _isConfirmedJudgementStatus(String status) {
    return const {
      'confirmed',
      'accurate',
      'partial',
      'adjusted',
      'accepted',
    }.contains(status);
  }

  bool _isTriedActionStatus(String status) {
    return const {
      'accepted',
      'active',
      'tried',
      'done',
      'completed',
    }.contains(status);
  }

  bool _isHappenedFeedback(String happened) {
    return const {
      'yes',
      'happened',
      'partial',
      'tried',
    }.contains(happened);
  }

  bool _isHelpfulFeedbackStatus(String status) {
    return const {
      'helpful',
      'helped',
      'lighter',
      'better',
      'yes',
      'somewhat',
    }.contains(status);
  }

  bool _isHardFeedback(MicroActionFeedbackModel feedback) {
    return const {'hard', 'too_hard', 'not_helpful', 'no'}
            .contains(feedback.difficulty) ||
        const {'not_helpful', 'worse', 'no'}.contains(feedback.effect) ||
        const {'lighter', 'adjust', 'switch', 'pause'}
            .contains(feedback.nextAdjustment);
  }

  String _deriveNextAdjustment({
    required List<MicroActionFeedbackModel> feedbacks,
    required int helpfulActionCount,
    required int triedActionCount,
  }) {
    final explicit = _firstOrNull(feedbacks
        .map((feedback) => feedback.nextAdjustment)
        .where((value) => value != 'continue'));
    switch (explicit) {
      case 'lighter':
        return '调轻一点';
      case 'switch':
        return '换一个策略';
      case 'pause':
        return '暂时不做';
      case 'adjust':
        return '调整后再试';
    }
    if (triedActionCount == 0) return '先选一个很小的尝试';
    if (helpfulActionCount > 0) return '继续这个方向';
    return '调轻一点';
  }

  T? _firstOrNull<T>(Iterable<T> values) {
    final iterator = values.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }

  String _id(String prefix) =>
      '${prefix}_${_uuid.v4().replaceAll('-', '').substring(0, 12)}';

  String _dateKey(DateTime date) {
    final local = date.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}
