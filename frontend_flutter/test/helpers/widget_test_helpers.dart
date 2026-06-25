import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_opportunity_radar/core/api/api_client.dart';
import 'package:ai_opportunity_radar/core/api/repositories/analytics_repository.dart';
import 'package:ai_opportunity_radar/core/api/repositories/ai_repository.dart';
import 'package:ai_opportunity_radar/core/api/repositories/cloud_backup_repository.dart';
import 'package:ai_opportunity_radar/core/api/repositories/energy_budget_repository.dart';
import 'package:ai_opportunity_radar/core/api/repositories/memory_repository.dart';
import 'package:ai_opportunity_radar/core/api/repositories/monthly_repository.dart';
import 'package:ai_opportunity_radar/core/api/repositories/self_review_repository.dart';
import 'package:ai_opportunity_radar/core/api/repositories/signal_library_repository.dart';
import 'package:ai_opportunity_radar/core/api/repositories/today_repository.dart';
import 'package:ai_opportunity_radar/core/api/repositories/weekly_repository.dart';
import 'package:ai_opportunity_radar/core/backup/backup_bundle_repository.dart';
import 'package:ai_opportunity_radar/core/di/app_dependencies.dart';
import 'package:ai_opportunity_radar/core/models/advanced_energy_boundary_models.dart';
import 'package:ai_opportunity_radar/core/local/local_capture_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_daily_snapshot_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/local/local_journey_snapshot_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_life_experiment_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_monthly_snapshot_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_phase3_plus_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_weekly_snapshot_repository.dart';
import 'package:ai_opportunity_radar/core/models/energy_budget_models.dart';
import 'package:ai_opportunity_radar/core/models/memory_models.dart';
import 'package:ai_opportunity_radar/core/models/phase3_plus_models.dart';
import 'package:ai_opportunity_radar/core/models/monthly_models.dart';
import 'package:ai_opportunity_radar/core/models/today_models.dart';
import 'package:ai_opportunity_radar/core/models/weekly_models.dart';
import 'package:ai_opportunity_radar/features/pages/me/me_view_model.dart';

class DummyAiRepository extends AiRepository {
  DummyAiRepository()
      : super(
          ApiClient(
            baseUrl: 'https://example.invalid',
            userId: 'widget-test-user',
          ),
        );
}

LocalDatabase createDummyDatabase() {
  return LocalDatabase(dbPathOverride: 'widget_test_dummy.db');
}

Future<void> seedMockPrefs({
  String? repeatArea = 'emotion_stress',
  String? responseStyle = 'gentle',
}) async {
  final values = <String, Object>{};
  if (repeatArea != null) {
    values['repeat_area_preference'] = repeatArea;
  }
  if (responseStyle != null) {
    values['response_style_preference'] = responseStyle;
  }
  SharedPreferences.setMockInitialValues(values);
}

Widget buildTestApp({
  required Widget child,
  required List<SingleChildWidget> providers,
  Locale locale = const Locale('en'),
}) {
  return MultiProvider(
    providers: providers,
    child: MaterialApp(
      locale: locale,
      supportedLocales: const [
        Locale('en'),
        Locale('ja'),
        Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
        Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      ],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: child,
    ),
  );
}

class StubTodayRepository extends TodayRepository {
  final Map<String, dynamic> fetchTodayResult;
  final Map<String, RecentSignalModel> captureById;
  final Future<void> Function()? onRetryPendingDrafts;
  final List<Map<String, String>> followupCalls = [];
  final List<Map<String, dynamic>> submittedCaptures = [];
  final List<Map<String, dynamic>> submittedSchedules = [];
  final List<String> lightDialogMessages = [];
  int fetchTodayCallCount = 0;
  int retryPendingDraftsCallCount = 0;

  StubTodayRepository({
    required this.fetchTodayResult,
    this.captureById = const {},
    this.onRetryPendingDrafts,
  }) : super(
          localCaptureRepository: LocalCaptureRepository(createDummyDatabase()),
          localDailySnapshotRepository: LocalDailySnapshotRepository(
            createDummyDatabase(),
          ),
          aiRepository: DummyAiRepository(),
        );

  @override
  Future<Map<String, dynamic>> fetchToday() async {
    fetchTodayCallCount += 1;
    return fetchTodayResult;
  }

  @override
  Future<void> retryPendingDrafts() async {
    retryPendingDraftsCallCount += 1;
    await onRetryPendingDrafts?.call();
  }

  @override
  Future<void> submitFollowup({
    required String followupId,
    required String answerValue,
  }) async {
    followupCalls.add({
      'followupId': followupId,
      'answerValue': answerValue,
    });
  }

  @override
  Future<RecentSignalModel?> getCaptureById(String captureId) async {
    return captureById[captureId];
  }

  @override
  Future<LightDialogResponseModel> continueLightDialog({
    required RecentSignalModel signal,
    required List<LightDialogTurnModel> history,
    required String userMessage,
  }) async {
    lightDialogMessages.add(userMessage);
    return const LightDialogResponseModel(
      reply: '我会先贴着这条记录看，不急着下结论。',
      suggestedPrompts: ['再往下想一步', '帮我整理成一句话'],
    );
  }

  @override
  Future<Map<String, dynamic>> submitCapture({
    required String content,
    String? tagHint,
    String sourceType = 'text',
    Map<String, dynamic> rawPayloadJson = const {},
  }) async {
    submittedCaptures.add({
      'content': content,
      'tagHint': tagHint,
      'sourceType': sourceType,
      'rawPayloadJson': rawPayloadJson,
    });
    return {
      'acknowledgement': '这条信号已经保存。',
    };
  }

  @override
  Future<ScheduleSignalModel> createScheduleSignal({
    required String title,
    DateTime? date,
    DateTime? time,
    DateTime? endTime,
    String? scene,
    String? note,
    String? expectedEnergyLoad,
    bool reminderEnabled = false,
  }) async {
    submittedSchedules.add({
      'title': title,
      'date': date,
      'time': time,
      'endTime': endTime,
      'scene': scene,
      'note': note,
      'expectedEnergyLoad': expectedEnergyLoad,
      'reminderEnabled': reminderEnabled,
    });
    return ScheduleSignalModel(
      id: 'schedule-${submittedSchedules.length}',
      title: title,
      anchorDate: date?.toIso8601String().split('T').first ?? 'unscheduled',
      datePrecision: date == null ? 'none' : 'date',
      timePrecision: time == null ? 'none' : 'time',
      startTime: time,
      endTime: endTime,
      scene: scene,
      note: note,
      expectedEnergyLoad: expectedEnergyLoad,
      reminderEnabled: reminderEnabled,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

Future<AppDependencies> buildTestDependencies({
  required TodayRepository todayRepository,
}) async {
  await seedMockPrefs();
  final apiClient = ApiClient(
    baseUrl: 'https://example.invalid',
    userId: 'widget-test-user',
  );
  final analyticsRepository = AnalyticsRepository(apiClient);
  final aiRepository = DummyAiRepository();
  final localDatabase = createDummyDatabase();
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
  return AppDependencies(
    apiClient: apiClient,
    localUserId: 'widget-test-user',
    deviceId: 'widget-test-device',
    analyticsRepository: analyticsRepository,
    aiRepository: aiRepository,
    todayRepository: todayRepository,
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
    energyBudgetRepository: EnergyBudgetRepository(
      localCaptureRepository: localCaptureRepository,
      localLifeExperimentRepository: localLifeExperimentRepository,
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
    signalLibraryRepository: SignalLibraryRepository(localDatabase),
    backupBundleRepository: BackupBundleRepository(
      localDatabase: localDatabase,
      preferences: await SharedPreferences.getInstance(),
    ),
    cloudBackupRepository: CloudBackupRepository(apiClient),
    localDatabase: localDatabase,
    localCaptureRepository: localCaptureRepository,
    localDailySnapshotRepository: localDailySnapshotRepository,
    localWeeklySnapshotRepository: localWeeklySnapshotRepository,
    localJourneySnapshotRepository: localJourneySnapshotRepository,
    localMonthlySnapshotRepository: localMonthlySnapshotRepository,
    localLifeExperimentRepository: localLifeExperimentRepository,
    localPhase3PlusRepository: localPhase3PlusRepository,
  );
}

class StubMemoryRepository extends MemoryRepository {
  final MemoryFetchResult result;
  int fetchCallCount = 0;

  StubMemoryRepository({required this.result})
      : super(
          localCaptureRepository: LocalCaptureRepository(createDummyDatabase()),
          localJourneySnapshotRepository: LocalJourneySnapshotRepository(
            createDummyDatabase(),
          ),
          aiRepository: DummyAiRepository(),
        );

  @override
  Future<MemoryFetchResult> fetchMemorySummaryResult() async {
    fetchCallCount += 1;
    return result;
  }
}

class StubWeeklyRepository extends WeeklyRepository {
  final WeeklyInsightModel weekly;
  final List<String> feedbackValues = [];
  int fetchCallCount = 0;

  StubWeeklyRepository({required this.weekly})
      : super(
          localCaptureRepository: LocalCaptureRepository(createDummyDatabase()),
          localWeeklySnapshotRepository: LocalWeeklySnapshotRepository(
            createDummyDatabase(),
          ),
          aiRepository: DummyAiRepository(),
        );

  @override
  Future<WeeklyInsightModel> fetchCurrentWeekly() async {
    fetchCallCount += 1;
    return weekly;
  }

  @override
  Future<void> submitWeeklyFeedback({
    required String weekStart,
    required String feedbackValue,
  }) async {
    feedbackValues.add(feedbackValue);
  }

  @override
  Future<LifeExperimentModel?> saveLifeExperiment(String experimentId) async {
    return weekly.lifeExperiment?.copyWith(status: 'saved');
  }

  @override
  Future<LifeExperimentModel?> skipLifeExperiment(String experimentId) async {
    return weekly.lifeExperiment?.copyWith(status: 'skipped');
  }

  @override
  Future<LifeExperimentModel?> submitLifeExperimentFeedback({
    required String experimentId,
    required String status,
    required String feedbackText,
  }) async {
    return weekly.lifeExperiment?.copyWith(
      status: status,
      feedbackText: feedbackText,
    );
  }
}

class StubEnergyBudgetRepository extends EnergyBudgetRepository {
  final EnergyBudgetModel budget;
  int fetchCallCount = 0;

  StubEnergyBudgetRepository({required this.budget})
      : super(
          localCaptureRepository: LocalCaptureRepository(createDummyDatabase()),
          localLifeExperimentRepository: LocalLifeExperimentRepository(
            createDummyDatabase(),
          ),
        );

  @override
  Future<EnergyBudgetModel> fetchBasicEnergyBudget({
    WeeklyInsightModel? weekly,
    MemorySummaryModel? journey,
    AdvancedEnergyExternalSummary? externalSummary,
    int limit = 1000,
  }) async {
    fetchCallCount += 1;
    return budget;
  }
}

class StubMonthlyRepository extends MonthlyRepository {
  final MonthlyReviewModel monthly;
  int fetchCallCount = 0;

  StubMonthlyRepository({required this.monthly})
      : super(
          localCaptureRepository: LocalCaptureRepository(createDummyDatabase()),
          localMonthlySnapshotRepository: LocalMonthlySnapshotRepository(
            createDummyDatabase(),
          ),
          aiRepository: DummyAiRepository(),
        );

  @override
  Future<MonthlyReviewModel> fetchCurrentMonthly() async {
    fetchCallCount += 1;
    return monthly;
  }
}

Future<MeViewModel> buildMeViewModel({
  String? repeatArea = 'emotion_stress',
  String? responseStyle = 'gentle',
}) async {
  await seedMockPrefs(
    repeatArea: repeatArea,
    responseStyle: responseStyle,
  );
  final vm = MeViewModel();
  await vm.load();
  return vm;
}
