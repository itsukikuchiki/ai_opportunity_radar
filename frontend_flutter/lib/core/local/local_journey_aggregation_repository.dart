import '../eligibility/signal_eligibility_service.dart';
import '../models/feedback_event_models.dart';
import '../models/phase3_plus_models.dart';
import '../models/today_models.dart';
import '../models/weekly_models.dart';
import 'local_capture_repository.dart';
import 'local_feedback_event_repository.dart';
import 'local_life_experiment_repository.dart';
import 'local_phase3_plus_repository.dart';
import 'local_weekly_snapshot_repository.dart';

class JourneyAggregationModel {
  final DateTime periodStart;
  final DateTime periodEnd;
  final String startDate;
  final String endDate;
  final List<RecentSignalModel> signals;
  final List<LifeExperimentModel> experimentHistory;
  final List<Map<String, dynamic>> experimentRollups;
  final List<FeedbackEventModel> feedbackEvents;
  final List<MicroActionFeedbackModel> microActionFeedbacks;
  final List<LifeExperimentFeedbackModel> experimentFeedbacks;
  final List<WeeklyInsightModel> weeklyReviews;
  final Map<String, String> subjectTitles;

  /// Privacy-eligible source history from first app use through periodEnd.
  /// Period facts above remain bounded to the selected calendar month.
  final List<RecentSignalModel> sourceSignals;
  final List<LifeExperimentModel> sourceExperimentHistory;
  final List<Map<String, dynamic>> sourceExperimentRollups;
  final List<Map<String, dynamic>> sourcePlanContentVersions;
  final List<FeedbackEventModel> sourceFeedbackEvents;
  final List<WeeklyInsightModel> sourceWeeklyReviews;
  final Map<String, String> sourceSubjectTitles;

  const JourneyAggregationModel({
    required this.periodStart,
    required this.periodEnd,
    required this.startDate,
    required this.endDate,
    required this.signals,
    required this.experimentHistory,
    required this.experimentRollups,
    required this.feedbackEvents,
    required this.microActionFeedbacks,
    required this.experimentFeedbacks,
    required this.weeklyReviews,
    this.subjectTitles = const {},
    this.sourceSignals = const [],
    this.sourceExperimentHistory = const [],
    this.sourceExperimentRollups = const [],
    this.sourcePlanContentVersions = const [],
    this.sourceFeedbackEvents = const [],
    this.sourceWeeklyReviews = const [],
    this.sourceSubjectTitles = const {},
  });

  bool get hasMaterial {
    return signals.isNotEmpty ||
        experimentHistory.isNotEmpty ||
        experimentRollups.isNotEmpty ||
        feedbackEvents.isNotEmpty ||
        weeklyReviews.isNotEmpty;
  }
}

class LocalJourneyAggregationRepository {
  final LocalCaptureRepository localCaptureRepository;
  final LocalLifeExperimentRepository? localLifeExperimentRepository;
  final LocalPhase3PlusRepository? localPhase3PlusRepository;
  final LocalWeeklySnapshotRepository? localWeeklySnapshotRepository;
  final LocalFeedbackEventRepository? localFeedbackEventRepository;
  final SignalEligibilityService eligibilityService;

  const LocalJourneyAggregationRepository({
    required this.localCaptureRepository,
    this.localLifeExperimentRepository,
    this.localPhase3PlusRepository,
    this.localWeeklySnapshotRepository,
    this.localFeedbackEventRepository,
    this.eligibilityService = const SignalEligibilityService(),
  });

  Future<JourneyAggregationModel> fetchCurrentMonth({
    required String localUserId,
    required DateTime today,
    required DateTime installationDate,
  }) async {
    return fetchMonth(
      localUserId: localUserId,
      selectedMonth: today,
      today: today,
      installationDate: installationDate,
    );
  }

  /// Builds a factual projection for any selected user-local calendar month.
  ///
  /// The current month is clipped at today. Past months use their complete
  /// local calendar boundary. Months before first app use return an empty
  /// projection instead of leaking current-month data into history.
  Future<JourneyAggregationModel> fetchMonth({
    required String localUserId,
    required DateTime selectedMonth,
    required DateTime today,
    required DateTime installationDate,
  }) async {
    final localToday = _dateOnly(today);
    final requested = _dateOnly(selectedMonth);
    final requestedMonth = DateTime(requested.year, requested.month);
    final currentMonth = DateTime(localToday.year, localToday.month);
    final effectiveMonth =
        requestedMonth.isAfter(currentMonth) ? currentMonth : requestedMonth;
    final monthStart = effectiveMonth;
    final monthEnd = DateTime(effectiveMonth.year, effectiveMonth.month + 1, 0);
    final periodEnd = effectiveMonth == currentMonth ? localToday : monthEnd;
    final installed = _dateOnly(installationDate);
    final isBeforeFirstUse = periodEnd.isBefore(installed);
    final periodStart = isBeforeFirstUse
        ? monthStart
        : (installed.isAfter(monthStart) ? installed : monthStart);
    final startDate = _dateKey(periodStart);
    final endDate = _dateKey(periodEnd);

    if (isBeforeFirstUse) {
      return JourneyAggregationModel(
        periodStart: periodStart,
        periodEnd: periodEnd,
        startDate: startDate,
        endDate: endDate,
        signals: const [],
        experimentHistory: const [],
        experimentRollups: const [],
        feedbackEvents: const [],
        microActionFeedbacks: const [],
        experimentFeedbacks: const [],
        weeklyReviews: const [],
        subjectTitles: const {},
      );
    }

    final rawSignals = await localCaptureRepository.listSignalCardsBetween(
      startDate: startDate,
      endDate: endDate,
    );
    final signals = eligibilityService.filter(
      rawSignals,
      SignalEligibilityStage.journey,
    )..sort((a, b) {
        final dateCompare = a.localDateKey().compareTo(b.localDateKey());
        if (dateCompare != 0) return dateCompare;
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aTime.compareTo(bTime);
      });

    final experimentHistory =
        await localLifeExperimentRepository?.listRecentForPeriod(
              localUserId: localUserId,
              startDate: startDate,
              endDate: endDate,
            ) ??
            const <LifeExperimentModel>[];
    final experimentRollups =
        await localLifeExperimentRepository?.listRollupsForPeriod(
              localUserId: localUserId,
              startDate: startDate,
              endDate: endDate,
            ) ??
            const <Map<String, dynamic>>[];
    final feedbackRepository = localFeedbackEventRepository ??
        _feedbackRepositoryFromAvailableLocalDatabase();
    // Journey may use every privacy-eligible app fact in the selected period
    // as source material. Readiness still evaluates only `signals` above.
    final feedbackEvents = await feedbackRepository?.listBetween(
          localUserId: localUserId,
          startDate: startDate,
          endDate: endDate,
        ) ??
        const <FeedbackEventModel>[];
    final microActionFeedbacks =
        feedbackRepository?.microActionFeedbacksFrom(feedbackEvents) ??
            const <MicroActionFeedbackModel>[];
    final experimentFeedbacks =
        feedbackRepository?.lifeExperimentFeedbacksFrom(feedbackEvents) ??
            const <LifeExperimentFeedbackModel>[];
    final weeklyReviews = await _loadWeeklyReviews(periodStart, periodEnd);
    final subjectTitles = await _loadSubjectTitles(
      feedbackEvents,
      experimentHistory: experimentHistory,
    );

    final sourceStartDate = _dateKey(installed);
    final sourceSignals = sourceStartDate == startDate
        ? signals
        : eligibilityService.filter(
            await localCaptureRepository.listSignalCardsBetween(
              startDate: sourceStartDate,
              endDate: endDate,
            ),
            SignalEligibilityStage.journey,
          );
    sourceSignals.sort((a, b) {
      final dateCompare = a.localDateKey().compareTo(b.localDateKey());
      if (dateCompare != 0) return dateCompare;
      final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aTime.compareTo(bTime);
    });
    final sourceExperimentHistory = sourceStartDate == startDate
        ? experimentHistory
        : await localLifeExperimentRepository?.listRecentForPeriod(
              localUserId: localUserId,
              startDate: sourceStartDate,
              endDate: endDate,
            ) ??
            const <LifeExperimentModel>[];
    final sourceExperimentRollups = sourceStartDate == startDate
        ? experimentRollups
        : await localLifeExperimentRepository?.listRollupsForPeriod(
              localUserId: localUserId,
              startDate: sourceStartDate,
              endDate: endDate,
            ) ??
            const <Map<String, dynamic>>[];
    final sourcePlanContentVersions = await _loadPlanContentVersions(
      localUserId: localUserId,
      startDate: sourceStartDate,
      endDate: endDate,
    );
    final sourceFeedbackEvents = sourceStartDate == startDate
        ? feedbackEvents
        : await feedbackRepository?.listBetween(
              localUserId: localUserId,
              startDate: sourceStartDate,
              endDate: endDate,
            ) ??
            const <FeedbackEventModel>[];
    final sourceWeeklyReviews = sourceStartDate == startDate
        ? weeklyReviews
        : await _loadWeeklyReviews(installed, periodEnd);
    final sourceSubjectTitles = sourceStartDate == startDate
        ? subjectTitles
        : await _loadSubjectTitles(
            sourceFeedbackEvents,
            experimentHistory: sourceExperimentHistory,
          );

    return JourneyAggregationModel(
      periodStart: periodStart,
      periodEnd: periodEnd,
      startDate: startDate,
      endDate: endDate,
      signals: signals,
      experimentHistory: experimentHistory,
      experimentRollups: experimentRollups,
      feedbackEvents: feedbackEvents,
      microActionFeedbacks: microActionFeedbacks,
      experimentFeedbacks: experimentFeedbacks,
      weeklyReviews: weeklyReviews,
      subjectTitles: subjectTitles,
      sourceSignals: sourceSignals,
      sourceExperimentHistory: sourceExperimentHistory,
      sourceExperimentRollups: sourceExperimentRollups,
      sourcePlanContentVersions: sourcePlanContentVersions,
      sourceFeedbackEvents: sourceFeedbackEvents,
      sourceWeeklyReviews: sourceWeeklyReviews,
      sourceSubjectTitles: sourceSubjectTitles,
    );
  }

  DateTime _dateOnly(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  Future<Map<String, String>> _loadSubjectTitles(
    Iterable<FeedbackEventModel> events, {
    required Iterable<LifeExperimentModel> experimentHistory,
  }) async {
    final result = <String, String>{
      for (final experiment in experimentHistory)
        experiment.id: experiment.title,
    };
    final microActionIds = events
        .where((event) => event.subjectType == 'micro_action')
        .map((event) => event.subjectId)
        .where((id) => id.isNotEmpty)
        .toSet();
    for (final id in microActionIds) {
      final action = await localPhase3PlusRepository?.getMicroActionById(id);
      if (action != null && action.title.trim().isNotEmpty) {
        result[id] = action.title.trim();
      }
    }

    final legacyGoalIds = events
        .where((event) => event.subjectType == 'goal')
        .map((event) => event.subjectId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final database = localLifeExperimentRepository?.localDatabase ??
        localPhase3PlusRepository?.localDatabase;
    if (database != null && legacyGoalIds.isNotEmpty) {
      final db = await database.database;
      for (var start = 0; start < legacyGoalIds.length; start += 400) {
        final end = (start + 400).clamp(0, legacyGoalIds.length);
        final chunk = legacyGoalIds.sublist(start, end);
        final placeholders = List.filled(chunk.length, '?').join(', ');
        final rows = await db.query(
          'goals',
          columns: const ['id', 'title'],
          where: 'id IN ($placeholders)',
          whereArgs: chunk,
        );
        for (final row in rows) {
          final id = row['id']?.toString() ?? '';
          final title = row['title']?.toString().trim() ?? '';
          if (id.isNotEmpty && title.isNotEmpty) result[id] = title;
        }
      }
    }
    return result;
  }

  LocalFeedbackEventRepository?
      _feedbackRepositoryFromAvailableLocalDatabase() {
    final lifeDatabase = localLifeExperimentRepository?.localDatabase;
    if (lifeDatabase != null) return LocalFeedbackEventRepository(lifeDatabase);
    final phase3Database = localPhase3PlusRepository?.localDatabase;
    if (phase3Database != null) {
      return LocalFeedbackEventRepository(phase3Database);
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _loadPlanContentVersions({
    required String localUserId,
    required String startDate,
    required String endDate,
  }) async {
    final database = localLifeExperimentRepository?.localDatabase ??
        localPhase3PlusRepository?.localDatabase;
    if (database == null) return const [];
    final db = await database.database;
    final rows = await db.query(
      'plan_content_versions',
      where: '''
        local_user_id = ?
        AND effective_from_local_date >= ?
        AND effective_from_local_date <= ?
      ''',
      whereArgs: [localUserId, startDate, endDate],
      orderBy:
          'effective_from_local_date ASC, object_kind ASC, object_id ASC, version_no ASC',
    );
    return rows
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  Future<List<WeeklyInsightModel>> _loadWeeklyReviews(
    DateTime periodStart,
    DateTime periodEnd,
  ) async {
    final repository = localWeeklySnapshotRepository;
    if (repository == null) return const [];
    final reviews = <WeeklyInsightModel>[];
    var cursor = periodStart.subtract(
      Duration(days: periodStart.weekday - DateTime.monday),
    );
    while (!cursor.isAfter(periodEnd)) {
      final weekly = await repository.getByWeekStart(_dateKey(cursor));
      final weeklyEnd =
          weekly == null ? null : DateTime.tryParse(weekly.weekEnd);
      if (weekly != null &&
          weekly.status != 'insufficient_data' &&
          weeklyEnd != null &&
          !weeklyEnd.isAfter(periodEnd)) {
        reviews.add(weekly);
      }
      cursor = cursor.add(const Duration(days: 7));
    }
    return reviews;
  }

  String _dateKey(DateTime date) {
    final local = date.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd';
  }
}
