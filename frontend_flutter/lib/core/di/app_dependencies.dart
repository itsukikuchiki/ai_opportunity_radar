import '../api/api_client.dart';
import '../api/repositories/today_repository.dart';
import '../api/repositories/weekly_repository.dart';
import '../api/repositories/opportunity_repository.dart';
import '../api/repositories/memory_repository.dart';

class AppDependencies {
  final ApiClient apiClient;
  final TodayRepository todayRepository;
  final WeeklyRepository weeklyRepository;
  final OpportunityRepository opportunityRepository;
  final MemoryRepository memoryRepository;

  AppDependencies._({
    required this.apiClient,
    required this.todayRepository,
    required this.weeklyRepository,
    required this.opportunityRepository,
    required this.memoryRepository,
  });

  factory AppDependencies.create() {
    final apiClient = ApiClient();
    return AppDependencies._(
      apiClient: apiClient,
      todayRepository: TodayRepository(apiClient),
      weeklyRepository: WeeklyRepository(apiClient),
      opportunityRepository: OpportunityRepository(apiClient),
      memoryRepository: MemoryRepository(apiClient),
    );
  }
}
