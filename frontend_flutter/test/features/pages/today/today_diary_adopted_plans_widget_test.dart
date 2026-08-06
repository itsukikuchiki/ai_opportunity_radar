import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ai_opportunity_radar/core/local/local_candidate_planning_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_capture_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/local/local_life_experiment_repository.dart';
import 'package:ai_opportunity_radar/core/models/candidate_models.dart';
import 'package:ai_opportunity_radar/core/models/phase3_plus_models.dart';
import 'package:ai_opportunity_radar/core/models/today_models.dart';
import 'package:ai_opportunity_radar/core/models/weekly_models.dart';
import 'package:ai_opportunity_radar/features/pages/today/today_diary_page.dart';
import 'package:ai_opportunity_radar/features/pages/today/today_view_model.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('手帐从本地 Signal Card 历史读取所选日期而不只依赖 Today 投影', (tester) async {
    final selected = DateTime.now().subtract(const Duration(days: 12));
    final dateKey = _dateKey(selected);
    final captureRepository = _TimelineCaptureRepository([
      RecentSignalModel(
        id: 'historical-signal',
        signalCardId: 'historical-signal',
        sourceType: 'text',
        content: '这是一条只存在于本地历史库的信号',
        localDate: dateKey,
        createdAt: DateTime(
          selected.year,
          selected.month,
          selected.day,
          8,
          45,
        ),
        userConfirmation: 'confirmed',
      ),
    ]);
    final todayRepository = StubTodayRepository(
      fetchTodayResult: {
        'insight': TodayInsightModel(text: '今天的投影不包含历史。'),
        'pendingQuestion': null,
        'bestAction': DailyBestActionModel(text: '先留一点余地。'),
        'recentSignals': const <RecentSignalModel>[],
      },
    );
    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        child: TodayDiaryPage(
          initialDateKey: dateKey,
          captureRepositoryOverride: captureRepository,
        ),
        providers: [
          ChangeNotifierProvider<TodayViewModel>(
            create: (_) => TodayViewModel(todayRepository),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('这是一条只存在于本地历史库的信号'), findsOneWidget);
    expect(find.text('08:45'), findsOneWidget);
    expect(
      find.byKey(ValueKey('today-diary-day-$dateKey')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('today-diary-open-calendar')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('today-diary-month-picker')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('today-diary-calendar-day-$dateKey')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('today-diary-calendar-content-$dateKey')),
      findsNothing,
    );
    await tester.tap(
      find.byKey(ValueKey('today-diary-calendar-day-$dateKey')),
    );
    await tester.pumpAndSettle();
    expect(find.text('这是一条只存在于本地历史库的信号'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('手帐按日合并真实小行动和生活小实验并使用各自的有效进度', (tester) async {
    final repository = _TimelineCandidateRepository(
      actions: [
        AdoptedMicroActionProgress(
          action: MicroActionModel(
            id: 'action-real-1',
            judgementId: 'judgement-1',
            title: '切换任务前留两分钟缓冲',
            reason: '最近的切换比较密集。',
            plannedDate: '2026-07-14',
            status: 'active',
            localUserId: 'local',
            adoptedAt: DateTime(2026, 7, 14, 9),
            progressStartDate: '2026-07-14',
            progressEndDate: '2026-07-20',
          ),
          progress: const SevenDayProgressModel(
            subjectId: 'action-real-1',
            startDate: '2026-07-14',
            endDate: '2026-07-20',
            cells: [
              SevenDayProgressCell(
                localDate: '2026-07-14',
                state: ProgressCellState.empty,
              ),
              SevenDayProgressCell(
                localDate: '2026-07-15',
                state: ProgressCellState.completed,
              ),
              SevenDayProgressCell(
                localDate: '2026-07-16',
                state: ProgressCellState.notCompleted,
              ),
            ],
          ),
        ),
      ],
      experiments: [
        AdoptedLifeExperimentProgress(
          experiment: LifeExperimentModel(
            id: 'experiment-real-1',
            localUserId: 'local',
            sourceWeekStart: '2026-07-13',
            sourceWeekEnd: '2026-07-19',
            title: '晚间留十分钟低要求恢复',
            hypothesis: '减少晚间继续硬撑。',
            suggestedAction: '睡前留十分钟做一个低要求恢复动作。',
            linkedSignalCardIds: const [],
            status: 'active',
            adoptedAt: DateTime(2026, 7, 13, 18),
            progressStartDate: '2026-07-13',
            progressEndDate: '2026-07-19',
          ),
          progress: SevenDayProgressModel(
            subjectId: 'experiment-real-1',
            startDate: '2026-07-13',
            endDate: '2026-07-19',
            cells: [
              const SevenDayProgressCell(
                localDate: '2026-07-13',
                state: ProgressCellState.empty,
              ),
              const SevenDayProgressCell(
                localDate: '2026-07-14',
                state: ProgressCellState.completed,
              ),
              const SevenDayProgressCell(
                localDate: '2026-07-15',
                state: ProgressCellState.completed,
              ),
              SevenDayProgressCell(
                localDate: '2026-07-16',
                state: ProgressCellState.notCompleted,
                latestEventAt: DateTime(2026, 7, 16, 11),
              ),
            ],
          ),
        ),
        AdoptedLifeExperimentProgress(
          experiment: LifeExperimentModel(
            id: 'experiment-real-2',
            localUserId: 'local',
            sourceWeekStart: '2026-07-13',
            sourceWeekEnd: '2026-07-19',
            title: '午后离开屏幕十分钟',
            hypothesis: '短暂离开屏幕可能帮助恢复。',
            suggestedAction: '午后起身离开屏幕十分钟。',
            linkedSignalCardIds: const [],
            status: 'active',
            adoptedAt: DateTime(2026, 7, 13, 18),
            progressStartDate: '2026-07-13',
            progressEndDate: '2026-07-19',
          ),
          progress: const SevenDayProgressModel(
            subjectId: 'experiment-real-2',
            startDate: '2026-07-13',
            endDate: '2026-07-19',
            cells: [
              SevenDayProgressCell(
                localDate: '2026-07-13',
                state: ProgressCellState.completed,
              ),
              SevenDayProgressCell(
                localDate: '2026-07-14',
                state: ProgressCellState.completed,
              ),
              SevenDayProgressCell(
                localDate: '2026-07-15',
                state: ProgressCellState.empty,
              ),
              SevenDayProgressCell(
                localDate: '2026-07-16',
                state: ProgressCellState.completed,
              ),
            ],
          ),
        ),
      ],
    );
    addTearDown(repository.dispose);

    final todayRepository = StubTodayRepository(
      fetchTodayResult: {
        'insight': TodayInsightModel(text: '今天的真实读模。'),
        'pendingQuestion': null,
        'bestAction': DailyBestActionModel(text: '先留一点余地。'),
        'recentSignals': <RecentSignalModel>[
          RecentSignalModel(
            id: 'signal-real-1',
            sourceType: 'text',
            content: '上午连续切换了三个任务',
            localDate: '2026-07-16',
            createdAt: DateTime(2026, 7, 16, 10),
          ),
        ],
      },
    );

    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        child: TodayDiaryPage(
          initialDateKey: '2026-07-16',
          repositoryOverride: repository,
        ),
        providers: [
          ChangeNotifierProvider<TodayViewModel>(
            create: (_) => TodayViewModel(todayRepository),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.requestedDates, [DateTime(2026, 7, 16)]);
    expect(find.text('上午连续切换了三个任务'), findsOneWidget);
    expect(find.text('切换任务前留两分钟缓冲'), findsOneWidget);
    expect(find.text('晚间留十分钟低要求恢复'), findsOneWidget);
    expect(find.text('进度 1/7'), findsOneWidget);
    expect(find.text('进度 2/7'), findsOneWidget);
    expect(find.text('今天未完成'), findsNWidgets(2));
    expect(find.text('今天不适合'), findsNothing);
    expect(find.text('聊聊'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('午后离开屏幕十分钟'),
      find.byKey(const ValueKey('today-diary-scroll-view')),
      const Offset(0, -220),
    );
    expect(find.text('午后离开屏幕十分钟'), findsOneWidget);
    expect(find.text('进度 3/7'), findsOneWidget);
    expect(find.text('今天已完成'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('today-diary-filter-action')),
    );
    await tester.tap(
      find.byKey(const ValueKey('today-diary-filter-action')),
    );
    await tester.pumpAndSettle();
    expect(find.text('切换任务前留两分钟缓冲'), findsOneWidget);
    expect(find.text('晚间留十分钟低要求恢复'), findsNothing);
    expect(find.text('午后离开屏幕十分钟'), findsNothing);
    expect(find.text('上午连续切换了三个任务'), findsNothing);
    expect(find.text('AI'), findsNothing);
    expect(find.text('今天未完成'), findsOneWidget);
    expect(find.text('今天已完成'), findsNothing);
    expect(find.text('今天不适合'), findsNothing);

    await tester.ensureVisible(
      find.byKey(const ValueKey('today-diary-filter-experiment')),
    );
    await tester.tap(
      find.byKey(const ValueKey('today-diary-filter-experiment')),
    );
    await tester.pumpAndSettle();
    expect(find.text('晚间留十分钟低要求恢复'), findsOneWidget);
    expect(find.text('午后离开屏幕十分钟'), findsOneWidget);
    expect(find.text('切换任务前留两分钟缓冲'), findsNothing);
    expect(find.text('上午连续切换了三个任务'), findsNothing);
    expect(find.text('AI'), findsNothing);
    expect(find.text('今天未完成'), findsOneWidget);
    expect(find.text('今天已完成'), findsOneWidget);
    expect(find.text('今天不适合'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('today-diary-previous-day')),
    );
    await tester.pumpAndSettle();
    expect(repository.requestedDates.last, DateTime(2026, 7, 15));
    expect(find.textContaining('7月15日'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('today-diary-back-to-today')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

String _dateKey(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

class _TimelineCandidateRepository extends LocalCandidatePlanningRepository {
  final List<AdoptedMicroActionProgress> actions;
  final List<AdoptedLifeExperimentProgress> experiments;
  final List<DateTime> requestedDates = [];

  factory _TimelineCandidateRepository({
    required List<AdoptedMicroActionProgress> actions,
    required List<AdoptedLifeExperimentProgress> experiments,
  }) {
    final database = LocalDatabase(dbPathOverride: 'timeline_widget_stub.db');
    return _TimelineCandidateRepository._withDatabase(
      database,
      actions: actions,
      experiments: experiments,
    );
  }

  _TimelineCandidateRepository._withDatabase(
    LocalDatabase database, {
    required this.actions,
    required this.experiments,
  }) : super(
          localDatabase: database,
          localCaptureRepository: LocalCaptureRepository(database),
          localLifeExperimentRepository:
              LocalLifeExperimentRepository(database),
          localUserId: 'local',
        );

  @override
  Future<List<AdoptedMicroActionProgress>> listAdoptedSmallTriesForDate(
    DateTime day,
  ) async {
    requestedDates.add(DateTime(day.year, day.month, day.day));
    return actions;
  }

  @override
  Future<List<AdoptedLifeExperimentProgress>> listAdoptedGoalsForDate(
    DateTime day,
  ) async {
    return experiments;
  }

  @override
  Future<Set<String>> listAdoptedPlanContentDateKeys() async {
    return {
      for (final item in actions)
        for (final cell in item.progress.cells) cell.localDate,
      for (final item in experiments)
        for (final cell in item.progress.cells) cell.localDate,
    };
  }
}

class _TimelineCaptureRepository extends LocalCaptureRepository {
  final List<RecentSignalModel> signals;

  _TimelineCaptureRepository(this.signals)
      : super(LocalDatabase(dbPathOverride: 'timeline_capture_stub.db'));

  @override
  Future<List<RecentSignalModel>> listSignalCardsForDate(
    String localDate,
  ) async {
    return signals
        .where((signal) => signal.localDateKey() == localDate)
        .toList(growable: false);
  }

  @override
  Future<Set<String>> listSignalCardDateKeys() async {
    return signals.map((signal) => signal.localDateKey()).toSet();
  }
}
