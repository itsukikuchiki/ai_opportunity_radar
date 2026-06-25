import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../api/api_client.dart';
import '../api/repositories/cloud_backup_repository.dart';
import '../api/repositories/analytics_repository.dart';
import '../api/repositories/ai_repository.dart';
import '../api/repositories/energy_budget_repository.dart';
import '../api/repositories/memory_repository.dart';
import '../api/repositories/monthly_repository.dart';
import '../api/repositories/self_review_repository.dart';
import '../api/repositories/signal_library_repository.dart';
import '../api/repositories/today_repository.dart';
import '../api/repositories/weekly_repository.dart';
import '../backup/backup_bundle_repository.dart';
import '../backup/cloud_backup_sync_service.dart';
import '../local/external_energy_hint_store.dart';
import '../local/local_capture_repository.dart';
import '../local/local_daily_snapshot_repository.dart';
import '../local/local_database.dart';
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
  final BackupBundleRepository backupBundleRepository;
  final CloudBackupRepository cloudBackupRepository;
  final LocalDatabase localDatabase;
  final LocalCaptureRepository localCaptureRepository;
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
    required this.backupBundleRepository,
    required this.cloudBackupRepository,
    required this.localDatabase,
    required this.localCaptureRepository,
    required this.localDailySnapshotRepository,
    required this.localWeeklySnapshotRepository,
    required this.localJourneySnapshotRepository,
    required this.localMonthlySnapshotRepository,
    required this.localLifeExperimentRepository,
    required this.localPhase3PlusRepository,
  });

  static Future<AppDependencies> create() async {
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
    if (createdNewUser) {
      unawaited(analyticsRepository.track('user_registered'));
    }

    final localDatabase = LocalDatabase();
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
    final localPhase3PlusRepository = LocalPhase3PlusRepository(localDatabase);
    final externalEnergyHintStore = ExternalEnergyHintStore(prefs);
    final backupBundleRepository = BackupBundleRepository(
      localDatabase: localDatabase,
      preferences: prefs,
    );
    final cloudBackupRepository = CloudBackupRepository(apiClient);
    final cloudBackupSyncService = CloudBackupSyncService(
      backupBundleRepository: backupBundleRepository,
      cloudBackupRepository: cloudBackupRepository,
      preferences: prefs,
      localUserId: localUserId,
      deviceId: deviceId,
    );
    final signalLibraryRepository = SignalLibraryRepository(
      localDatabase,
      cloudBackupSyncService: cloudBackupSyncService,
    );

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
      localDailySnapshotRepository: localDailySnapshotRepository,
      localWeeklySnapshotRepository: localWeeklySnapshotRepository,
      localJourneySnapshotRepository: localJourneySnapshotRepository,
      localMonthlySnapshotRepository: localMonthlySnapshotRepository,
      localLifeExperimentRepository: localLifeExperimentRepository,
      localPhase3PlusRepository: localPhase3PlusRepository,
      todayRepository: TodayRepository(
        localCaptureRepository: localCaptureRepository,
        localDailySnapshotRepository: localDailySnapshotRepository,
        localPhase3PlusRepository: localPhase3PlusRepository,
        aiRepository: aiRepository,
        apiClient: apiClient,
        analyticsRepository: analyticsRepository,
        cloudBackupSyncService: cloudBackupSyncService,
      ),
      weeklyRepository: WeeklyRepository(
        localCaptureRepository: localCaptureRepository,
        localWeeklySnapshotRepository: localWeeklySnapshotRepository,
        localLifeExperimentRepository: localLifeExperimentRepository,
        localPhase3PlusRepository: localPhase3PlusRepository,
        aiRepository: aiRepository,
        localUserId: localUserId,
        cloudBackupSyncService: cloudBackupSyncService,
      ),
      memoryRepository: MemoryRepository(
        localCaptureRepository: localCaptureRepository,
        localJourneySnapshotRepository: localJourneySnapshotRepository,
        localLifeExperimentRepository: localLifeExperimentRepository,
        localPhase3PlusRepository: localPhase3PlusRepository,
        aiRepository: aiRepository,
        monthlyRepository: monthlyRepository,
        localUserId: localUserId,
      ),
      energyBudgetRepository: EnergyBudgetRepository(
        localCaptureRepository: localCaptureRepository,
        localLifeExperimentRepository: localLifeExperimentRepository,
        externalEnergyHintStore: externalEnergyHintStore,
        localUserId: localUserId,
      ),
      monthlyRepository: monthlyRepository,
      selfReviewRepository: SelfReviewRepository(
        localCaptureRepository: localCaptureRepository,
        apiClient: apiClient,
      ),
      signalLibraryRepository: signalLibraryRepository,
      backupBundleRepository: backupBundleRepository,
      cloudBackupRepository: cloudBackupRepository,
    );
  }
}
