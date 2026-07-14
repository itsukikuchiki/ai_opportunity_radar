import '../models/feedback_event_models.dart';
import '../models/phase3_plus_models.dart';
import '../models/weekly_models.dart';
import 'local_database.dart';

class LocalFeedbackEventRepository {
  final LocalDatabase localDatabase;

  const LocalFeedbackEventRepository(this.localDatabase);

  Future<List<FeedbackEventModel>> listBetween({
    required String localUserId,
    required String startDate,
    required String endDate,
  }) async {
    final db = await localDatabase.database;
    final microRows = await db.query(
      'micro_action_feedback',
      where: '''
        local_date >= ? AND local_date <= ?
        AND COALESCE(is_valid, 1) = 1
      ''',
      whereArgs: [startDate, endDate],
      orderBy: 'local_date ASC, created_at ASC',
    );
    final experimentRows = await db.query(
      'life_experiment_feedback',
      where: '''
        local_user_id = ?
        AND local_date >= ?
        AND local_date <= ?
        AND COALESCE(is_valid, 1) = 1
      ''',
      whereArgs: [localUserId, startDate, endDate],
      orderBy: 'local_date ASC, created_at ASC',
    );
    final scheduleRows = await db.query(
      'schedule_signals',
      where: '''
        deleted_at IS NULL
        AND feedback_status != ?
        AND privacy_level NOT IN (?, ?, ?)
        AND (
          (local_date >= ? AND local_date <= ?)
          OR (local_date IS NULL AND anchor_date >= ? AND anchor_date <= ?)
        )
      ''',
      whereArgs: [
        'not_started',
        'sensitive',
        'excluded',
        'do_not_analyze',
        startDate,
        endDate,
        startDate,
        endDate,
      ],
      orderBy: 'COALESCE(local_date, anchor_date) ASC, updated_at ASC',
    );
    final goalRows = await db.rawQuery(
      '''
      SELECT gf.*
      FROM goal_feedback gf
      INNER JOIN goals g ON g.id = gf.goal_id
      WHERE gf.feedback_date >= ?
        AND gf.feedback_date <= ?
        AND g.deleted_at IS NULL
        AND g.privacy_level NOT IN (?, ?, ?)
      ORDER BY gf.feedback_date ASC, gf.created_at ASC
      ''',
      [startDate, endDate, 'sensitive', 'excluded', 'do_not_analyze'],
    );

    final events = <FeedbackEventModel>[
      for (final row in microRows)
        FeedbackEventModel.fromMicroActionFeedback(
          MicroActionFeedbackModel.fromDb(row),
          localUserId: localUserId,
        ),
      for (final row in experimentRows)
        FeedbackEventModel.fromLifeExperimentFeedback(
          LifeExperimentFeedbackModel.fromJson(
            row.map((key, value) => MapEntry(key, value)),
          ),
        ),
      for (final row in scheduleRows)
        FeedbackEventModel.fromScheduleFeedback(
          ScheduleSignalModel.fromDb(row),
          localUserId: localUserId,
        ),
      for (final row in goalRows)
        FeedbackEventModel.fromGoalFeedbackRow(
          row,
          localUserId: localUserId,
        ),
    ];

    events.sort((a, b) {
      final dateCompare = a.localDate.compareTo(b.localDate);
      if (dateCompare != 0) return dateCompare;
      final aCreated = a.createdAt ?? a.occurredAt ?? DateTime(0);
      final bCreated = b.createdAt ?? b.occurredAt ?? DateTime(0);
      final createdCompare = aCreated.compareTo(bCreated);
      if (createdCompare != 0) return createdCompare;
      return a.id.compareTo(b.id);
    });
    return events;
  }

  Future<List<FeedbackEventModel>> listActiveBetween({
    required String localUserId,
    required String startDate,
    required String endDate,
  }) async {
    final events = await listBetween(
      localUserId: localUserId,
      startDate: startDate,
      endDate: endDate,
    );
    return events
        .where((event) =>
            event.sourceType == 'micro_action_feedback' ||
            event.sourceType == 'life_experiment_feedback')
        .toList(growable: false);
  }

  List<MicroActionFeedbackModel> microActionFeedbacksFrom(
    Iterable<FeedbackEventModel> events,
  ) {
    return events
        .map((event) => event.toMicroActionFeedback())
        .whereType<MicroActionFeedbackModel>()
        .toList(growable: false);
  }

  List<LifeExperimentFeedbackModel> lifeExperimentFeedbacksFrom(
    Iterable<FeedbackEventModel> events,
  ) {
    return events
        .map((event) => event.toLifeExperimentFeedback())
        .whereType<LifeExperimentFeedbackModel>()
        .toList(growable: false);
  }

  List<FeedbackEventModel> scheduleFeedbacksFrom(
    Iterable<FeedbackEventModel> events,
  ) {
    return events
        .where((event) => event.sourceType == 'schedule_feedback')
        .toList(growable: false);
  }

  List<FeedbackEventModel> goalFeedbacksFrom(
    Iterable<FeedbackEventModel> events,
  ) {
    return events
        .where((event) => event.sourceType == 'goal_feedback')
        .toList(growable: false);
  }
}
