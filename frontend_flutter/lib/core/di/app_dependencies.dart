import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../api/api_client.dart';
import '../api/repositories/ai_repository.dart';
import '../api/repositories/memory_repository.dart';
import '../api/repositories/opportunity_repository.dart';
import '../api/repositories/today_repository.dart';
import '../api/repositories/weekly_repository.dart';
import '../local/local_capture_repository.dart';
import '../local/local_daily_snapshot_repository.dart';
import '../local/local_database.dart';

class AppDependencies {
  final ApiClient apiClient;
  final AiRepository aiRepository;
  final TodayRepository todayRepository;
  final WeeklyRepository weeklyRepository;
  final MemoryRepository memoryRepository;
  final OpportunityRepository opportunityRepository;
  final LocalDatabase localDatabase;
  final LocalCaptureRepository localCaptureRepository;
  final LocalDailySnapshotRepository localDailySnapshotRepository;

  AppDependencies({
    required this.apiClient,
    required this.aiRepository,
    required this.todayRepository,
    required this.weeklyRepository,
    required this.memoryRepository,
    required this.opportunityRepository,
    required this.localDatabase,
    required this.localCaptureRepository,
    required this.localDailySnapshotRepository,
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
    final localDailySnapshotRepository =
        LocalDailySnapshotRepository(localDatabase);
    final aiRepository = AiRepository(apiClient);

    return AppDependencies(
      apiClient: apiClient,
      aiRepository: aiRepository,
      localDatabase: localDatabase,
      localCaptureRepository: localCaptureRepository,
      localDailySnapshotRepository: localDailySnapshotRepository,
      todayRepository: TodayRepository(
        localCaptureRepository: localCaptureRepository,
        localDailySnapshotRepository: localDailySnapshotRepository,
        aiRepository: aiRepository,
      ),
      weeklyRepository: WeeklyRepository(apiClient),
      memoryRepository: MemoryRepository(apiClient),
      opportunityRepository: OpportunityRepository(apiClient),
    );
  }
}
