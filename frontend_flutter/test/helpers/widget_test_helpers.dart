import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_opportunity_radar/core/api/api_client.dart';
import 'package:ai_opportunity_radar/core/api/repositories/ai_repository.dart';
import 'package:ai_opportunity_radar/core/api/repositories/energy_budget_repository.dart';
import 'package:ai_opportunity_radar/core/api/repositories/memory_repository.dart';
import 'package:ai_opportunity_radar/core/api/repositories/monthly_repository.dart';
import 'package:ai_opportunity_radar/core/api/repositories/today_repository.dart';
import 'package:ai_opportunity_radar/core/api/repositories/weekly_repository.dart';
import 'package:ai_opportunity_radar/core/models/advanced_energy_boundary_models.dart';
import 'package:ai_opportunity_radar/core/local/local_capture_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_daily_snapshot_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/local/local_journey_snapshot_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_life_experiment_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_monthly_snapshot_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_weekly_snapshot_repository.dart';
import 'package:ai_opportunity_radar/core/models/energy_budget_models.dart';
import 'package:ai_opportunity_radar/core/models/memory_models.dart';
import 'package:ai_opportunity_radar/core/models/monthly_models.dart';
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
  final Future<void> Function()? onRetryPendingDrafts;
  final List<Map<String, String>> followupCalls = [];
  int fetchTodayCallCount = 0;
  int retryPendingDraftsCallCount = 0;

  StubTodayRepository({
    required this.fetchTodayResult,
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
