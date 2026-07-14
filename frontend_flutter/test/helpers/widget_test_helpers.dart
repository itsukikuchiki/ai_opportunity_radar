import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_opportunity_radar/core/api/api_client.dart';
import 'package:ai_opportunity_radar/core/api/repositories/analytics_repository.dart';
import 'package:ai_opportunity_radar/core/api/repositories/ai_repository.dart';
import 'package:ai_opportunity_radar/core/api/repositories/energy_budget_repository.dart';
import 'package:ai_opportunity_radar/core/api/repositories/memory_repository.dart';
import 'package:ai_opportunity_radar/core/api/repositories/monthly_repository.dart';
import 'package:ai_opportunity_radar/core/api/repositories/self_review_repository.dart';
import 'package:ai_opportunity_radar/core/api/repositories/signal_library_repository.dart';
import 'package:ai_opportunity_radar/core/api/repositories/today_repository.dart';
import 'package:ai_opportunity_radar/core/api/repositories/weekly_repository.dart';
import 'package:ai_opportunity_radar/core/di/app_dependencies.dart';
import 'package:ai_opportunity_radar/core/i18n/app_locale_text.dart';
import 'package:ai_opportunity_radar/core/models/advanced_energy_boundary_models.dart';
import 'package:ai_opportunity_radar/core/local/local_capture_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_candidate_planning_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_daily_snapshot_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/local/local_feedback_event_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_journey_snapshot_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_life_experiment_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_monthly_snapshot_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_phase3_plus_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_weekly_snapshot_repository.dart';
import 'package:ai_opportunity_radar/core/models/energy_budget_models.dart';
import 'package:ai_opportunity_radar/core/models/memory_models.dart';
import 'package:ai_opportunity_radar/core/models/journey_pro_models.dart';
import 'package:ai_opportunity_radar/core/models/monthly_models.dart';
import 'package:ai_opportunity_radar/core/models/today_models.dart';
import 'package:ai_opportunity_radar/core/models/weekly_models.dart';
import 'package:ai_opportunity_radar/core/readiness/report_readiness.dart';
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
  final List<Map<String, dynamic>> savedDraftCaptures = [];
  final List<Map<String, dynamic>> submittedMicroActionChoices = [];
  final List<Map<String, dynamic>> submittedMicroActionFeedbacks = [];
  final List<Map<String, dynamic>> submittedLifeExperimentFeedbacks = [];
  final List<Map<String, dynamic>> confirmedSignals = [];
  final List<Map<String, dynamic>> aiJudgementResponses = [];
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
  Future<RecentSignalModel> saveLocalDraftCapture({
    required String content,
    String sourceType = 'text',
    String? tagHint,
    Map<String, dynamic> rawPayloadJson = const {},
  }) async {
    savedDraftCaptures.add({
      'content': content,
      'tagHint': tagHint,
      'sourceType': sourceType,
      'rawPayloadJson': rawPayloadJson,
    });
    return RecentSignalModel(
      id: 'draft-${savedDraftCaptures.length}',
      sourceType: sourceType,
      content: content,
      createdAt: DateTime.now(),
      acknowledgement: '草稿已保存在本机。',
      isLocalDraft: true,
      rawPayloadJson: rawPayloadJson,
    );
  }

  @override
  Future<Map<String, dynamic>> chooseMicroAction({
    required String microActionId,
    required String choice,
    AppLanguage language = AppLanguage.english,
  }) async {
    submittedMicroActionChoices.add({
      'microActionId': microActionId,
      'choice': choice,
    });
    return fetchTodayResult;
  }

  @override
  Future<Map<String, dynamic>> submitMicroActionFeedback({
    required String microActionId,
    required String feedback,
    String? userNote,
  }) async {
    submittedMicroActionFeedbacks.add({
      'microActionId': microActionId,
      'feedback': feedback,
      'userNote': userNote,
    });
    return fetchTodayResult;
  }

  @override
  Future<Map<String, dynamic>> submitTodayLifeExperimentFeedback({
    required String experimentId,
    required String status,
    required String feedbackText,
  }) async {
    submittedLifeExperimentFeedbacks.add({
      'experimentId': experimentId,
      'status': status,
      'feedbackText': feedbackText,
    });
    return fetchTodayResult;
  }

  @override
  Future<void> confirmSignalCard({
    required String signalCardId,
    required String userConfirmation,
    Map<String, dynamic> userCorrectionJson = const {},
  }) async {
    confirmedSignals.add({
      'signalCardId': signalCardId,
      'userConfirmation': userConfirmation,
      'userCorrectionJson': userCorrectionJson,
    });
  }

  @override
  Future<Map<String, dynamic>> respondToAiJudgement({
    required String judgementId,
    required String status,
    String? userAdjustmentText,
    bool addToTimeline = true,
    AppLanguage language = AppLanguage.english,
  }) async {
    aiJudgementResponses.add({
      'judgementId': judgementId,
      'status': status,
      'userAdjustmentText': userAdjustmentText,
      'addToTimeline': addToTimeline,
      'language': language.name,
    });
    return fetchTodayResult;
  }
}

Future<AppDependencies> buildTestDependencies({
  required TodayRepository todayRepository,
  WeeklyRepository? weeklyRepository,
  MemoryRepository? memoryRepository,
  EnergyBudgetRepository? energyBudgetRepository,
  LocalDatabase? localDatabaseOverride,
}) async {
  await seedMockPrefs();
  final apiClient = ApiClient(
    baseUrl: 'https://example.invalid',
    userId: 'widget-test-user',
  );
  final analyticsRepository = AnalyticsRepository(apiClient);
  final aiRepository = DummyAiRepository();
  final localDatabase = localDatabaseOverride ?? createDummyDatabase();
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
    localUserId: 'widget-test-user',
  );
  final localFeedbackEventRepository =
      LocalFeedbackEventRepository(localDatabase);
  final resolvedEnergyBudgetRepository = energyBudgetRepository ??
      EnergyBudgetRepository(
        localCaptureRepository: localCaptureRepository,
        localLifeExperimentRepository: localLifeExperimentRepository,
        feedbackEventRepository: localFeedbackEventRepository,
        localUserId: 'widget-test-user',
      );
  final localCandidatePlanningRepository = LocalCandidatePlanningRepository(
    localDatabase: localDatabase,
    localCaptureRepository: localCaptureRepository,
    localLifeExperimentRepository: localLifeExperimentRepository,
    feedbackEventRepository: localFeedbackEventRepository,
    energyBudgetRepository: resolvedEnergyBudgetRepository,
    localUserId: 'widget-test-user',
  );
  return AppDependencies(
    apiClient: apiClient,
    localUserId: 'widget-test-user',
    deviceId: 'widget-test-device',
    analyticsRepository: analyticsRepository,
    aiRepository: aiRepository,
    todayRepository: todayRepository,
    weeklyRepository: weeklyRepository ??
        WeeklyRepository(
          localCaptureRepository: localCaptureRepository,
          localWeeklySnapshotRepository: localWeeklySnapshotRepository,
          aiRepository: aiRepository,
        ),
    memoryRepository: memoryRepository ??
        MemoryRepository(
          localCaptureRepository: localCaptureRepository,
          localJourneySnapshotRepository: localJourneySnapshotRepository,
          aiRepository: aiRepository,
        ),
    energyBudgetRepository: resolvedEnergyBudgetRepository,
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
    localDatabase: localDatabase,
    localCaptureRepository: localCaptureRepository,
    localCandidatePlanningRepository: localCandidatePlanningRepository,
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
  final List<JourneyEvidenceItemModel> evidenceItems;
  final JourneyProReportModel? proReportResult;
  int fetchCallCount = 0;
  int evidenceCallCount = 0;
  int proReportCallCount = 0;

  StubMemoryRepository({
    required this.result,
    this.evidenceItems = const [],
    this.proReportResult,
  }) : super(
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

  @override
  Future<List<JourneyEvidenceItemModel>> fetchJourneyEvidence({
    JourneyTraceModel? trace,
  }) async {
    evidenceCallCount += 1;
    return evidenceItems;
  }

  @override
  Future<JourneyProReportModel> fetchJourneyProReport() async {
    proReportCallCount += 1;
    return proReportResult ??
        JourneyProReportModel(
          readiness: result.proReadiness ??
              ReportReadiness.empty(ReportReadinessEvaluator.journeyProRule),
          periodStart: '2026-01-01',
          periodEnd: '2026-01-28',
          currentWeek: const JourneyProWeekStats(
            weekStart: '2026-01-26',
            weekEnd: '2026-02-01',
            signalCount: 0,
            activeDayCount: 0,
          ),
          previousWeek: const JourneyProWeekStats(
            weekStart: '2026-01-19',
            weekEnd: '2026-01-25',
            signalCount: 0,
            activeDayCount: 0,
          ),
          evidence: const [],
        );
  }
}

class StubWeeklyRepository extends WeeklyRepository {
  final WeeklyInsightModel weekly;
  final LifeExperimentModel? experimentCandidate;
  final LifeExperimentModel? currentWeekExperiment;
  final List<String> feedbackValues = [];
  int fetchCallCount = 0;

  StubWeeklyRepository({
    required this.weekly,
    this.experimentCandidate,
    this.currentWeekExperiment,
  }) : super(
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
  Future<WeeklyReflectModel> fetchWeeklyReflect() async {
    return const WeeklyReflectModel(
      summary: 'Weekly Reflect keeps the deeper read tied to this week.',
      rootTension: 'Energy dropped when meetings compressed recovery.',
      hiddenPattern: 'Small recovery actions worked better than large plans.',
      nextFocus: 'Keep the next experiment light and observable.',
      riskNote: 'Use this as a hypothesis, not a judgement.',
      keyNodes: [
        'Meeting compression',
        'Recovery window',
        'Light experiment',
      ],
    );
  }

  @override
  Future<LifeExperimentModel?> fetchWeeklyExperimentCandidate({
    required String weekStart,
  }) async {
    return experimentCandidate ?? weekly.lifeExperiment;
  }

  @override
  Future<LifeExperimentModel?> fetchCurrentWeekLifeExperiment({
    required String weekStart,
  }) async {
    return currentWeekExperiment;
  }

  @override
  Future<LifeExperimentModel?> fetchNextWeekExperiment({
    required String weekStart,
  }) async {
    return experimentCandidate;
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
    final source = experimentCandidate;
    if (source == null) return null;
    final start = DateTime.parse(source.sourceWeekStart).add(
      const Duration(days: 7),
    );
    final end = DateTime.parse(source.sourceWeekEnd).add(
      const Duration(days: 7),
    );
    String key(DateTime value) => '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
    return LifeExperimentModel(
      id: 'exp_adopted_${source.id}',
      localUserId: source.localUserId,
      sourceWeekStart: key(start),
      sourceWeekEnd: key(end),
      title: source.title,
      hypothesis: source.hypothesis,
      suggestedAction: source.suggestedAction,
      linkedSignalCardIds: source.linkedSignalCardIds,
      status: 'saved',
    );
  }

  @override
  Future<LifeExperimentModel?> skipLifeExperiment(String experimentId) async {
    return (experimentCandidate ?? weekly.lifeExperiment)?.copyWith(
      status: 'skipped',
    );
  }

  @override
  Future<LifeExperimentModel?> submitLifeExperimentFeedback({
    required String experimentId,
    required String status,
    required String feedbackText,
  }) async {
    return (experimentCandidate ?? weekly.lifeExperiment)?.copyWith(
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
