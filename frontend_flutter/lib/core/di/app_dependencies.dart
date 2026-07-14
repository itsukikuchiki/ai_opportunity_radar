import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../api/api_client.dart';
import '../api/repositories/analytics_repository.dart';
import '../api/repositories/ai_repository.dart';
import '../api/repositories/energy_budget_repository.dart';
import '../api/repositories/memory_repository.dart';
import '../api/repositories/monthly_repository.dart';
import '../api/repositories/self_review_repository.dart';
import '../api/repositories/signal_library_repository.dart';
import '../api/repositories/today_repository.dart';
import '../api/repositories/weekly_repository.dart';
import '../local/external_energy_hint_store.dart';
import '../local/local_capture_repository.dart';
import '../local/local_candidate_planning_repository.dart';
import '../local/local_daily_snapshot_repository.dart';
import '../local/local_database.dart';
import '../local/local_feedback_event_repository.dart';
import '../local/local_journey_snapshot_repository.dart';
import '../local/local_life_experiment_repository.dart';
import '../local/local_monthly_snapshot_repository.dart';
import '../local/local_phase3_plus_repository.dart';
import '../local/local_weekly_snapshot_repository.dart';

class AppDependencies {
  final ApiClient apiClient;
  final String localUserId;
  final String deviceId;
  final AnalyticsRepository analyticsRepository;
  final AiRepository aiRepository;
  final TodayRepository todayRepository;
  final WeeklyRepository weeklyRepository;
  final MemoryRepository memoryRepository;
  final EnergyBudgetRepository energyBudgetRepository;
  final MonthlyRepository monthlyRepository;
  final SelfReviewRepository selfReviewRepository;
  final SignalLibraryRepository signalLibraryRepository;
  final LocalDatabase localDatabase;
  final LocalCaptureRepository localCaptureRepository;
  final LocalCandidatePlanningRepository localCandidatePlanningRepository;
  final LocalDailySnapshotRepository localDailySnapshotRepository;
  final LocalWeeklySnapshotRepository localWeeklySnapshotRepository;
  final LocalJourneySnapshotRepository localJourneySnapshotRepository;
  final LocalMonthlySnapshotRepository localMonthlySnapshotRepository;
  final LocalLifeExperimentRepository localLifeExperimentRepository;
  final LocalPhase3PlusRepository localPhase3PlusRepository;

  AppDependencies({
    required this.apiClient,
    required this.localUserId,
    required this.deviceId,
    required this.analyticsRepository,
    required this.aiRepository,
    required this.todayRepository,
    required this.weeklyRepository,
    required this.memoryRepository,
    required this.energyBudgetRepository,
    required this.monthlyRepository,
    required this.selfReviewRepository,
    required this.signalLibraryRepository,
    required this.localDatabase,
    required this.localCaptureRepository,
    required this.localCandidatePlanningRepository,
    required this.localDailySnapshotRepository,
    required this.localWeeklySnapshotRepository,
    required this.localJourneySnapshotRepository,
    required this.localMonthlySnapshotRepository,
    required this.localLifeExperimentRepository,
    required this.localPhase3PlusRepository,
  });

  static Future<AppDependencies> create({
    LocalDatabase? localDatabaseOverride,
    bool trackNewUserRegistration = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    var createdNewUser = false;
    var localUserId = prefs.getString('local_user_id');
    if (localUserId == null || localUserId.trim().isEmpty) {
      localUserId = const Uuid().v4();
      await prefs.setString('local_user_id', localUserId);
      createdNewUser = true;
    }
    var deviceId = prefs.getString('device_id');
    if (deviceId == null || deviceId.trim().isEmpty) {
      deviceId = const Uuid().v4();
      await prefs.setString('device_id', deviceId);
    }

    final apiClient = ApiClient(userId: localUserId);
    final analyticsRepository = AnalyticsRepository(apiClient);
    if (createdNewUser && trackNewUserRegistration) {
      unawaited(analyticsRepository.track('user_registered'));
    }

    final localDatabase = localDatabaseOverride ?? LocalDatabase();
    await localDatabase.init();

    final localCaptureRepository = LocalCaptureRepository(localDatabase);
    final localDailySnapshotRepository =
        LocalDailySnapshotRepository(localDatabase);
    final localWeeklySnapshotRepository =
        LocalWeeklySnapshotRepository(localDatabase);
    final localJourneySnapshotRepository =
        LocalJourneySnapshotRepository(localDatabase);
    final localMonthlySnapshotRepository =
        LocalMonthlySnapshotRepository(localDatabase);
    final localLifeExperimentRepository =
        LocalLifeExperimentRepository(localDatabase);
    final localPhase3PlusRepository = LocalPhase3PlusRepository(
      localDatabase,
      localUserId: localUserId,
    );
    final externalEnergyHintStore = ExternalEnergyHintStore(prefs);
    final localFeedbackEventRepository =
        LocalFeedbackEventRepository(localDatabase);
    final energyBudgetRepository = EnergyBudgetRepository(
      localCaptureRepository: localCaptureRepository,
      localLifeExperimentRepository: localLifeExperimentRepository,
      externalEnergyHintStore: externalEnergyHintStore,
      feedbackEventRepository: localFeedbackEventRepository,
      localUserId: localUserId,
    );
    final localCandidatePlanningRepository = LocalCandidatePlanningRepository(
      localDatabase: localDatabase,
      localCaptureRepository: localCaptureRepository,
      localLifeExperimentRepository: localLifeExperimentRepository,
      feedbackEventRepository: localFeedbackEventRepository,
      energyBudgetRepository: energyBudgetRepository,
      localUserId: localUserId,
    );
    final signalLibraryRepository = SignalLibraryRepository(localDatabase);

    final aiRepository = AiRepository(apiClient);

    final monthlyRepository = MonthlyRepository(
      localCaptureRepository: localCaptureRepository,
      localMonthlySnapshotRepository: localMonthlySnapshotRepository,
      aiRepository: aiRepository,
    );

    return AppDependencies(
      apiClient: apiClient,
      localUserId: localUserId,
      deviceId: deviceId,
      analyticsRepository: analyticsRepository,
      aiRepository: aiRepository,
      localDatabase: localDatabase,
      localCaptureRepository: localCaptureRepository,
      localCandidatePlanningRepository: localCandidatePlanningRepository,
      localDailySnapshotRepository: localDailySnapshotRepository,
      localWeeklySnapshotRepository: localWeeklySnapshotRepository,
      localJourneySnapshotRepository: localJourneySnapshotRepository,
      localMonthlySnapshotRepository: localMonthlySnapshotRepository,
      localLifeExperimentRepository: localLifeExperimentRepository,
      localPhase3PlusRepository: localPhase3PlusRepository,
      todayRepository: TodayRepository(
        localCaptureRepository: localCaptureRepository,
        localDailySnapshotRepository: localDailySnapshotRepository,
        localLifeExperimentRepository: localLifeExperimentRepository,
        localPhase3PlusRepository: localPhase3PlusRepository,
        aiRepository: aiRepository,
        apiClient: apiClient,
        analyticsRepository: analyticsRepository,
        localUserId: localUserId,
      ),
      weeklyRepository: WeeklyRepository(
        localCaptureRepository: localCaptureRepository,
        localWeeklySnapshotRepository: localWeeklySnapshotRepository,
        localLifeExperimentRepository: localLifeExperimentRepository,
        localPhase3PlusRepository: localPhase3PlusRepository,
        aiRepository: aiRepository,
        localUserId: localUserId,
      ),
      memoryRepository: MemoryRepository(
        localCaptureRepository: localCaptureRepository,
        localJourneySnapshotRepository: localJourneySnapshotRepository,
        localLifeExperimentRepository: localLifeExperimentRepository,
        localPhase3PlusRepository: localPhase3PlusRepository,
        localWeeklySnapshotRepository: localWeeklySnapshotRepository,
        aiRepository: aiRepository,
        monthlyRepository: monthlyRepository,
        localUserId: localUserId,
      ),
      energyBudgetRepository: energyBudgetRepository,
      monthlyRepository: monthlyRepository,
      selfReviewRepository: SelfReviewRepository(
        localCaptureRepository: localCaptureRepository,
        apiClient: apiClient,
      ),
      signalLibraryRepository: signalLibraryRepository,
    );
  }
}
