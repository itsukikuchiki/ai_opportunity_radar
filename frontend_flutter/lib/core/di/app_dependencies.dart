import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../api/api_client.dart';
import '../api/repositories/memory_repository.dart';
import '../api/repositories/opportunity_repository.dart';
import '../api/repositories/today_repository.dart';
import '../api/repositories/weekly_repository.dart';

class AppDependencies {
  static const String _userIdKey = 'app_user_id';
  static const Uuid _uuid = Uuid();

  final String userId;
  final ApiClient apiClient;
  final TodayRepository todayRepository;
  final WeeklyRepository weeklyRepository;
  final OpportunityRepository opportunityRepository;
  final MemoryRepository memoryRepository;

  AppDependencies._({
    required this.userId,
    required this.apiClient,
    required this.todayRepository,
    required this.weeklyRepository,
    required this.opportunityRepository,
    required this.memoryRepository,
  });

  static Future<AppDependencies> create() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = await _loadOrCreateUserId(prefs);

    final apiClient = ApiClient(userId: userId);

    return AppDependencies._(
      userId: userId,
      apiClient: apiClient,
      todayRepository: TodayRepository(apiClient),
      weeklyRepository: WeeklyRepository(apiClient),
      opportunityRepository: OpportunityRepository(apiClient),
      memoryRepository: MemoryRepository(apiClient),
    );
  }

  static Future<String> _loadOrCreateUserId(SharedPreferences prefs) async {
    final existing = prefs.getString(_userIdKey)?.trim();
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final newUserId = _uuid.v4();
    final saved = await prefs.setString(_userIdKey, newUserId);
    if (!saved) {
      throw StateError('Failed to persist app user id.');
    }
    return newUserId;
  }
}
