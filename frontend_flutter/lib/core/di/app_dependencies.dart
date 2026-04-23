import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../api/api_client.dart';
import '../api/repositories/ai_repository.dart';
import '../api/repositories/memory_repository.dart';
import '../api/repositories/monthly_repository.dart';
import '../api/repositories/opportunity_repository.dart';
import '../api/repositories/self_review_repository.dart';
import '../api/repositories/today_repository.dart';
import '../api/repositories/weekly_repository.dart';
import '../local/local_capture_repository.dart';
import '../local/local_daily_snapshot_repository.dart';
import '../local/local_database.dart';
import '../local/local_journey_snapshot_repository.dart';
import '../local/local_monthly_snapshot_repository.dart';
import '../local/local_weekly_snapshot_repository.dart';

class AppDependencies {
  final ApiClient apiClient;
  final AiRepository aiRepository;
  final TodayRepository todayRepository;
  final WeeklyRepository weeklyRepository;
  final MemoryRepository memoryRepository;
  final MonthlyRepository monthlyRepository;
  final SelfReviewRepository selfReviewRepository;
  final OpportunityRepository opportunityRepository;
  final LocalDatabase localDatabase;
  final LocalCaptureRepository localCaptureRepository;
  final LocalDailySnapshotRepository localDailySnapshotRepository;
  final LocalWeeklySnapshotRepository localWeeklySnapshotRepository;
  final LocalJourneySnapshotRepository localJourneySnapshotRepository;
  final LocalMonthlySnapshotRepository localMonthlySnapshotRepository;

  AppDependencies({
    required this.apiClient,
    required this.aiRepository,
    required this.todayRepository,
    required this.weeklyRepository,
    required this.memoryRepository,
    required this.monthlyRepository,
    required this.selfReviewRepository,
    required this.opportunityRepository,
    required this.localDatabase,
    required this.localCaptureRepository,
    required this.localDailySnapshotRepository,
    required this.localWeeklySnapshotRepository,
    required this.localJourneySnapshotRepository,
    required this.localMonthlySnapshotRepository,
  });

  static Future<AppDependencies> create() async {
    final prefs = await SharedPreferences.getInstance();

    var localUserId = prefs.getString('local_user_id');
    if (localUserId == null || localUserId.trim().isEmpty) {
      localUserId = const Uuid().v4();
      await prefs.setString('local_user_id', localUserId);
    }

    final apiClient = ApiClient(userId: localUserId);

    final localDatabase = LocalDatabase();
    await localDatabase.init();

    final localCaptureRepository = LocalCaptureRepository(localDatabase);
    final localDailySnapshotRepository = LocalDailySnapshotRepository(localDatabase);
    final localWeeklySnapshotRepository = LocalWeeklySnapshotRepository(localDatabase);
    final localJourneySnapshotRepository = LocalJourneySnapshotRepository(localDatabase);
    final localMonthlySnapshotRepository = LocalMonthlySnapshotRepository(localDatabase);

    final aiRepository = AiRepository(apiClient);

    return AppDependencies(
      apiClient: apiClient,
      aiRepository: aiRepository,
      localDatabase: localDatabase,
      localCaptureRepository: localCaptureRepository,
      localDailySnapshotRepository: localDailySnapshotRepository,
      localWeeklySnapshotRepository: localWeeklySnapshotRepository,
      localJourneySnapshotRepository: localJourneySnapshotRepository,
      localMonthlySnapshotRepository: localMonthlySnapshotRepository,
      todayRepository: TodayRepository(
        localCaptureRepository: localCaptureRepository,
        localDailySnapshotRepository: localDailySnapshotRepository,
        aiRepository: aiRepository,
      ),
      weeklyRepository: WeeklyRepository(
        localCaptureRepository: localCaptureRepository,
        localWeeklySnapshotRepository: localWeeklySnapshotRepository,
        aiRepository: aiRepository,
      ),
      memoryRepository: MemoryRepository(
        localCaptureRepository: localCaptureRepository,
        localJourneySnapshotRepository: localJourneySnapshotRepository,
        aiRepository: aiRepository,
      ),
      monthlyRepository: MonthlyRepository(
        localCaptureRepository: localCaptureRepository,
        localMonthlySnapshotRepository: localMonthlySnapshotRepository,
        aiRepository: aiRepository,
      ),
      selfReviewRepository: SelfReviewRepository(
        localCaptureRepository: localCaptureRepository,
        apiClient: apiClient,
      ),
      opportunityRepository: OpportunityRepository(apiClient),
    );
  }
}
