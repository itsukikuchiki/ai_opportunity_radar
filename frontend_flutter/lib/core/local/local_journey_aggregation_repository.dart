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
  });

  bool get hasMaterial {
    return signals.isNotEmpty ||
        experimentHistory.isNotEmpty ||
        experimentRollups.isNotEmpty ||
        feedbackEvents.isNotEmpty;
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
    final monthStart = DateTime(today.year, today.month);
    final periodStart =
        installationDate.isAfter(monthStart) ? installationDate : monthStart;
    final periodEnd = DateTime(today.year, today.month, today.day);
    final startDate = _dateKey(periodStart);
    final endDate = _dateKey(periodEnd);

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
    final feedbackEvents = await feedbackRepository?.listActiveBetween(
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
    );
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
      if (weekly != null && weekly.status != 'insufficient_data') {
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
