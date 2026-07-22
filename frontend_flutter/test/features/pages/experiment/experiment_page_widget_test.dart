import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_opportunity_radar/core/di/app_dependencies.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/models/phase3_plus_models.dart';
import 'package:ai_opportunity_radar/core/models/weekly_models.dart';
import 'package:ai_opportunity_radar/features/pages/experiment/experiment_page.dart';
import 'package:ai_opportunity_radar/features/pages/weekly/weekly_view_model.dart';
import 'package:ai_opportunity_radar/shared/widgets/aurora_ui.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);

  testWidgets('生活小实验页用真实数据分区显示小实验和目标', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final today = _testDateOnly(DateTime.now());
    final activeStart = today.subtract(const Duration(days: 2));
    final expiredStart = today.subtract(const Duration(days: 12));
    final futureStart = today.add(const Duration(days: 2));
    final weeklyRepository = StubWeeklyRepository(weekly: _weeklyModel);
    late Directory tempDir;
    late LocalDatabase database;
    late AppDependencies dependencies;
    late StubTodayRepository todayRepository;
    late String activeGoalId;
    await tester.runAsync(() async {
      tempDir =
          await Directory.systemTemp.createTemp('life_experiment_tracks_');
      database = LocalDatabase(
        dbPathOverride: p.join(tempDir.path, 'tracks.db'),
        databaseFactoryOverride: databaseFactoryFfi,
      );
      await database.init();
      todayRepository = StubTodayRepository(fetchTodayResult: const {});
      dependencies = await buildTestDependencies(
        todayRepository: todayRepository,
        weeklyRepository: weeklyRepository,
        localDatabaseOverride: database,
      );
      await dependencies.localPhase3PlusRepository.upsertMicroAction(
        MicroActionModel(
          id: 'small_try_visible',
          judgementId: '',
          title: '现在留两分钟不切换',
          reason: '这是可以立即开始的轻行为。',
          status: 'active',
          localUserId: dependencies.localUserId,
          adoptedAt: today.add(const Duration(hours: 9)),
          progressStartDate: _testDateKey(activeStart),
          progressEndDate: _testDateKey(
            activeStart.add(const Duration(days: 6)),
          ),
          linkedSignalCardIds: const ['signal-1', 'signal-2'],
          sourceChanged: true,
          sourceChangeReason: '一条来源 Signal 已删除。',
        ),
      );
      await dependencies.localPhase3PlusRepository.upsertMicroAction(
        MicroActionModel(
          id: 'small_try_expired',
          judgementId: '',
          title: 'Expired small try',
          reason: 'History remains readable.',
          status: 'active',
          localUserId: dependencies.localUserId,
          adoptedAt: expiredStart.add(const Duration(hours: 9)),
          progressStartDate: _testDateKey(expiredStart),
          progressEndDate: _testDateKey(
            expiredStart.add(const Duration(days: 6)),
          ),
        ),
      );
      await dependencies.localPhase3PlusRepository.upsertMicroAction(
        MicroActionModel(
          id: 'small_try_future',
          judgementId: '',
          title: 'Upcoming small try',
          reason: 'The record window starts later.',
          status: 'active',
          localUserId: dependencies.localUserId,
          adoptedAt: futureStart.add(const Duration(hours: 9)),
          progressStartDate: _testDateKey(futureStart),
          progressEndDate: _testDateKey(
            futureStart.add(const Duration(days: 6)),
          ),
        ),
      );
      final activeGoal =
          await dependencies.localLifeExperimentRepository.ensureSuggested(
        localUserId: dependencies.localUserId,
        weekStart: _testDateKey(activeStart),
        weekEnd: _testDateKey(activeStart.add(const Duration(days: 20))),
        title: '连续一周观察恢复节奏',
        hypothesis: '连续记录后可以看见稳定变化。',
        suggestedAction: '每天记录一次恢复后的状态。',
        linkedSignalCardIds: const ['signal-5', 'signal-6'],
        status: 'active',
        adoptedAt: activeStart.add(const Duration(hours: 9)),
        progressStartDate: _testDateKey(activeStart),
        progressEndDate: _testDateKey(
          activeStart.add(const Duration(days: 20)),
        ),
        minimumObservationDays: 3,
      );
      activeGoalId = activeGoal.id;
      for (var day = 0; day < 3; day++) {
        await dependencies.localLifeExperimentRepository.recordFeedback(
          experimentId: activeGoal.id,
          completionStatus: 'completed',
          feedbackDate: activeStart.add(Duration(days: day, hours: 10)),
        );
      }
      final db = await database.database;
      final nowIso = DateTime.now().toUtc().toIso8601String();
      await db.insert('micro_action_candidates', {
        'id': 'considering_small_try',
        'candidate_group_id': 'considering_group',
        'local_user_id': dependencies.localUserId,
        'local_date': _testDateKey(today),
        'rank': 1,
        'title': '正在考虑的小实验',
        'reason': '先观察它是否适合现在的节奏。',
        'difficulty': 'very_light',
        'linked_signal_card_ids_json': jsonEncode(['signal-3']),
        'focus_domain_ids_json': jsonEncode(['growth_plan']),
        'status': 'generated',
        'decision_status': 'considering',
        'source_hash': 'considering-small-try-v1',
        'created_at': nowIso,
        'updated_at': nowIso,
      });
      await db.insert('experiment_candidates', {
        'id': 'considering_goal',
        'local_user_id': dependencies.localUserId,
        'source_type': 'weekly_candidate',
        'source_id': 'considering-goal-source',
        'source_week_start': _testDateKey(today),
        'source_week_end': _testDateKey(today.add(const Duration(days: 6))),
        'title': '正在观察的目标',
        'hypothesis': '连续观察一周后再判断是否值得坚持。',
        'suggested_action': '每天留意一次恢复后的变化。',
        'linked_signal_card_ids_json': jsonEncode(['signal-4']),
        'linked_observation_ids_json': '[]',
        'status': 'generated',
        'decision_status': 'considering',
        'confidence_level': 'medium',
        'metadata_json': '{}',
        'created_at': nowIso,
        'updated_at': nowIso,
      });
      final stored = await dependencies.localCandidatePlanningRepository
          .listAdoptedSmallTries();
      expect(
          stored.map((item) => item.action.id), contains('small_try_visible'));
    });
    addTearDown(() async {
      await dependencies.localCandidatePlanningRepository.dispose();
      await database.close();
      await tempDir.delete(recursive: true);
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppDependencies>.value(value: dependencies),
          ChangeNotifierProvider(
            create: (_) => WeeklyViewModel(weeklyRepository),
          ),
        ],
        child: const MaterialApp(home: ExperimentPage()),
      ),
    );
    await tester.pump();
    for (var attempt = 0; attempt < 30; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 60));
      if (find
          .byKey(const ValueKey('life-experiment-small-try-small_try_visible'))
          .evaluate()
          .isNotEmpty) {
        break;
      }
    }

    expect(find.text('Small experiments · within 10 minutes'), findsOneWidget);
    expect(find.text('现在留两分钟不切换'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('life-experiment-small-try-small_try_visible')),
      findsOneWidget,
    );
    expect(
        find.byKey(const ValueKey('small-try-branch-chart')), findsOneWidget);
    expect(find.byKey(const ValueKey('goal-timeline-matrix')), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey(
          'life-experiment-considering-small-try-considering_small_try',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('considering-goal-considering_goal')),
      findsOneWidget,
    );

    final searchField = find.descendant(
      of: find.byKey(const ValueKey('experiment-search-bar')),
      matching: find.byType(TextField),
    );
    await tester.enterText(searchField, '正在考虑的小实验');
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const ValueKey(
          'life-experiment-considering-small-try-considering_small_try',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('considering-goal-considering_goal')),
      findsNothing,
    );
    await tester.enterText(searchField, '正在观察的目标');
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const ValueKey(
          'life-experiment-considering-small-try-considering_small_try',
        ),
      ),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('considering-goal-considering_goal')),
      findsOneWidget,
    );
    await tester.enterText(searchField, '');
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(
        const ValueKey(
          'life-experiment-considering-small-try-considering_small_try',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Small experiment detail'), findsOneWidget);
    expect(find.text('正在考虑的小实验'), findsOneWidget);
    expect(find.text('Adopt'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.chevron_left_rounded).first);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('considering-goal-considering_goal')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Goal detail'), findsOneWidget);
    expect(find.text('正在观察的目标'), findsOneWidget);
    expect(find.text('Adopt'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.chevron_left_rounded).first);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('life-experiment-small-try-small_try_visible')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Small experiment detail'), findsOneWidget);
    expect(find.text('Within 10 minutes · try it now'), findsOneWidget);
    expect(find.text('Attempt history'), findsOneWidget);
    expect(find.text('Source Signals'), findsOneWidget);
    expect(find.text('Plan versions'), findsOneWidget);
    expect(find.text('Round-summary history'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^\d+/7$')), findsNothing);
    expect(
      find.text('Adopted ${today.year}/${today.month}/${today.day}'),
      findsOneWidget,
    );
    expect(find.text('Source Signals: 2'), findsOneWidget);
    expect(find.text('Source changed'), findsOneWidget);
    expect(find.text('一条来源 Signal 已删除。'), findsOneWidget);
    await tester.tap(find.text('Record one try'));
    await tester.pumpAndSettle();
    expect(find.text('Did you try it?'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('small-try-completed-choice')),
    );
    await tester.pump();
    expect(find.text('How did it feel right away?'), findsOneWidget);
    expect(find.text('How much effort did it take?'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('small-try-effect-helpful')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('small-try-difficulty-easy')),
    );
    await tester.pump();
    final saveAttempt = find.byKey(const ValueKey('small-try-feedback-save'));
    expect(tester.widget<FilledButton>(saveAttempt).onPressed, isNotNull);
    await tester.ensureVisible(saveAttempt);
    await tester.tap(saveAttempt);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('small-try-feedback-sheet')),
      findsNothing,
    );
    expect(todayRepository.submittedMicroActionFeedbacks, [
      {
        'microActionId': 'small_try_visible',
        'feedback': 'completed',
        'effect': 'helpful',
        'difficulty': 'easy',
        'userNote': null,
      },
    ]);
    await tester.pump(const Duration(seconds: 5));

    await tester.ensureVisible(find.text('Summarize this round'));
    await tester.tap(find.text('Summarize this round'));
    await tester.pumpAndSettle();
    expect(find.text('What should happen next?'), findsOneWidget);
    await tester.tap(find.text('Keep it'));
    await tester.pump();
    await tester.tap(find.text('Easy').last);
    await tester.pump();
    await tester.ensureVisible(find.text('Save this summary'));
    await tester.tap(find.text('Save this summary'));
    for (var attempt = 0; attempt < 20; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 20));
      if (find.text('Small experiment detail').evaluate().isNotEmpty) break;
    }
    expect(find.text('Small experiment detail'), findsOneWidget);
    late String completedStatus;
    await tester.runAsync(() async {
      final db = await database.database;
      final rows = await db.query(
        'micro_actions',
        columns: ['status'],
        where: 'id = ?',
        whereArgs: ['small_try_visible'],
      );
      completedStatus = rows.single['status']! as String;
    });
    expect(completedStatus, 'active');
    await tester.runAsync(() async {
      final reviews = await dependencies.localPhase3PlusRepository
          .listMicroActionRoundReviews(
        microActionId: 'small_try_visible',
      );
      expect(reviews, hasLength(1));
      expect(reviews.single.result, 'worth_keeping');
      expect(reviews.single.effort, 'easy');
    });
    await tester.ensureVisible(find.text('Complete this small experiment'));
    await tester.tap(find.text('Complete this small experiment'));
    await tester.pumpAndSettle();
    expect(find.text('Complete this small experiment?'), findsOneWidget);
    await tester.tap(find.text('Confirm completion'));
    for (var attempt = 0; attempt < 20; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 20));
      if (find.text('Small experiment detail').evaluate().isEmpty) break;
    }
    expect(find.text('Small experiment detail'), findsNothing);
    await tester.runAsync(() async {
      final db = await database.database;
      final rows = await db.query(
        'micro_actions',
        columns: ['status'],
        where: 'id = ?',
        whereArgs: ['small_try_visible'],
      );
      completedStatus = rows.single['status']! as String;
    });
    expect(completedStatus, 'completed');

    expect(find.textContaining('-day observation'), findsWidgets);
    await tester.tap(
      find.byKey(ValueKey('experiment-archive-card-$activeGoalId')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Goal detail'), findsOneWidget);
    expect(find.text('连续一周观察恢复节奏'), findsWidgets);
    expect(find.textContaining('3 completed days'), findsOneWidget);
    expect(find.text('What this goal observes'), findsOneWidget);
    expect(find.text('Long-term progress'), findsOneWidget);
    expect(find.text('Daily records'), findsOneWidget);
    expect(find.text('Source Signals'), findsOneWidget);
    expect(find.text('Plan versions'), findsOneWidget);
    expect(find.text('Weekly summaries'), findsOneWidget);
    expect(find.text('Overall summaries'), findsOneWidget);
    expect(find.text('Overview'), findsNothing);
    await tester.ensureVisible(find.text('Write an overall summary'));
    await tester.tap(find.text('Write an overall summary'));
    await tester.pumpAndSettle();
    expect(find.text('What changed?'), findsOneWidget);
    await tester.tap(find.text('A little'));
    await tester.pump();
    await tester.tap(find.text('Acceptable'));
    await tester.pump();
    await tester.ensureVisible(find.text('Save overall summary'));
    await tester.tap(find.text('Save overall summary'));
    await tester.pumpAndSettle();
    var savedGoalReview = false;
    for (var attempt = 0; attempt < 20 && !savedGoalReview; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(() async {
        final reviews = await dependencies.localLifeExperimentRepository
            .listOutcomeReviews(experimentId: activeGoalId);
        savedGoalReview = reviews.length == 1;
        if (savedGoalReview) {
          expect(reviews.single.outcomeResult, 'somewhat_improved');
          expect(reviews.single.burden, 'acceptable');
        }
      });
    }
    expect(savedGoalReview, isTrue);
    await tester.ensureVisible(find.text('Complete this goal'));
    await tester.tap(find.text('Complete this goal'));
    await tester.pumpAndSettle();
    expect(find.text('Complete this goal?'), findsOneWidget);
    await tester.tap(find.text('Confirm completion'));
    for (var attempt = 0; attempt < 20; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 20));
      if (find.text('Goal detail').evaluate().isEmpty) break;
    }
    expect(find.text('Goal detail'), findsNothing);
    await tester.runAsync(() async {
      final db = await database.database;
      final rows = await db.query(
        'life_experiments',
        columns: ['status'],
        where: 'id = ?',
        whereArgs: [activeGoalId],
      );
      completedStatus = rows.single['status']! as String;
    });
    expect(completedStatus, 'completed');
  });

  testWidgets('小实验与目标独立分页且加载第二页不会丢失第一页', (tester) async {
    final weeklyRepository = StubWeeklyRepository(weekly: _weeklyModel);
    late Directory tempDir;
    late LocalDatabase database;
    late AppDependencies dependencies;
    await tester.runAsync(() async {
      tempDir = await Directory.systemTemp.createTemp('experiment_paging_');
      database = LocalDatabase(
        dbPathOverride: p.join(tempDir.path, 'paging.db'),
        databaseFactoryOverride: databaseFactoryFfi,
      );
      await database.init();
      dependencies = await buildTestDependencies(
        todayRepository: StubTodayRepository(fetchTodayResult: const {}),
        weeklyRepository: weeklyRepository,
        localDatabaseOverride: database,
      );
      final db = await database.database;
      for (var index = 0; index < 3; index++) {
        await db.insert(
          'micro_actions',
          MicroActionModel(
            id: 'paged_small_try_$index',
            judgementId: '',
            title: 'Paged small try $index',
            reason: 'Small try pagination evidence.',
            status: 'active',
            localUserId: dependencies.localUserId,
            adoptedAt: DateTime(2026, 7, 10 + index, 9),
            progressStartDate: '2026-07-10',
            progressEndDate: '2026-07-16',
          ).toDb(),
        );
        await db.insert(
          'life_experiments',
          dependencies.localLifeExperimentRepository.toStorageRow(
            LifeExperimentModel(
              id: 'paged_goal_$index',
              localUserId: dependencies.localUserId,
              sourceWeekStart: '2026-07-${10 + index}',
              sourceWeekEnd: '2026-07-${16 + index}',
              title: 'Paged goal $index',
              hypothesis: 'Goal pagination evidence.',
              suggestedAction: 'Repeat for several days.',
              linkedSignalCardIds: const [],
              status: 'active',
              originCandidateId: 'candidate_goal_$index',
              adoptedAt: DateTime(2026, 7, 10 + index, 10),
              progressStartDate: '2026-07-${10 + index}',
              progressEndDate: '2026-07-${16 + index}',
              createdAt: DateTime(2026, 7, 10 + index, 10),
              updatedAt: DateTime(2026, 7, 10 + index, 10),
            ),
          ),
        );
      }
    });
    addTearDown(() async {
      await dependencies.localCandidatePlanningRepository.dispose();
      await database.close();
      await tempDir.delete(recursive: true);
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppDependencies>.value(value: dependencies),
          ChangeNotifierProvider(
            create: (_) => WeeklyViewModel(weeklyRepository),
          ),
        ],
        child: const MaterialApp(
          home: ExperimentPage(archivePageSize: 2),
        ),
      ),
    );
    await tester.pump();
    for (var attempt = 0; attempt < 20; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 30));
      if (find
          .byKey(
            const ValueKey('life-experiment-small-tries-load-more'),
          )
          .evaluate()
          .isNotEmpty) {
        break;
      }
    }

    expect(find.text('Paged small try 0'), findsNothing);
    final smallTryLoadMore =
        find.byKey(const ValueKey('life-experiment-small-tries-load-more'));
    await _bringIntoViewport(tester, smallTryLoadMore);
    await tester.tap(
      find.descendant(
        of: smallTryLoadMore,
        matching: find.byType(OutlinedButton),
      ),
    );
    await tester.pump();
    for (var attempt = 0; attempt < 20; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 30));
      if (smallTryLoadMore.evaluate().isEmpty) break;
    }
    expect(smallTryLoadMore, findsNothing);
    await _bringIntoViewport(
      tester,
      find.text('Paged small try 0'),
      searchDown: false,
    );
    expect(find.text('Paged small try 0'), findsOneWidget);
    await _bringIntoViewport(
      tester,
      find.text('Paged small try 2'),
      searchDown: false,
    );
    expect(find.text('Paged small try 2'), findsOneWidget);

    final goalLoadMore =
        find.byKey(const ValueKey('life-experiment-goals-load-more'));
    await _bringIntoViewport(tester, goalLoadMore);
    expect(find.text('Paged goal 0'), findsNothing);
    await tester.tap(
      find.descendant(
        of: goalLoadMore,
        matching: find.byType(OutlinedButton),
      ),
    );
    await tester.pump();
    for (var attempt = 0; attempt < 20; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 30));
      if (goalLoadMore.evaluate().isEmpty) break;
    }
    expect(goalLoadMore, findsNothing);
    await _bringIntoViewport(
      tester,
      find.text('Paged goal 0'),
      searchDown: false,
    );
    expect(find.text('Paged goal 0'), findsOneWidget);
    await _bringIntoViewport(
      tester,
      find.text('Paged goal 2'),
      searchDown: false,
    );
    expect(find.text('Paged goal 2'), findsOneWidget);
  });

  testWidgets('shows home summaries and keeps individual goal details',
      (tester) async {
    final repository = StubWeeklyRepository(weekly: _weeklyModel);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => WeeklyViewModel(repository),
        child: const MaterialApp(home: ExperimentPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Life Experiment'), findsOneWidget);
    expect(find.byType(AuroraHeroTitle), findsOneWidget);
    expect(find.byType(AuroraExperimentHeroPattern), findsOneWidget);
    expect(find.byType(AuroraHeroEmblem), findsNothing);
    expect(find.text('Record 10 minutes in the morning'), findsOneWidget);
    expect(find.text('Small experiments · within 10 minutes'), findsOneWidget);
    expect(find.text('Goals · long-term'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('life-experiment-small-tries-section')),
      findsOneWidget,
    );
    expect(
        find.byKey(const ValueKey('small-try-branch-chart')), findsOneWidget);
    expect(find.byKey(const ValueKey('goal-timeline-matrix')), findsOneWidget);
    expect(find.text('In progress'), findsWidgets);
    expect(find.textContaining(RegExp(r'^\d+/7$')), findsNothing);
    expect(find.byKey(const ValueKey('experiment-filter-tabs')), findsNothing);
    expect(find.text('Archive overview'), findsNothing);
    expect(find.text('Goal details'), findsNothing);
    final goalRow = find.byKey(
      const ValueKey('experiment-archive-card-exp_test'),
    );
    await tester.ensureVisible(goalRow);
    await tester.pumpAndSettle();
    await tester.tap(goalRow);
    await tester.pumpAndSettle();

    expect(find.text('Goal detail'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('experiment-detail-experiment-pattern')),
      findsOneWidget,
    );
    expect(find.byType(AuroraExperimentHeroPattern), findsOneWidget);
    expect(find.byType(AuroraHeroEmblem), findsNothing);
    expect(find.text('What this goal observes'), findsOneWidget);
    expect(find.text('Observation question'), findsOneWidget);
    expect(find.text('What to keep doing'), findsOneWidget);
    await _bringIntoViewport(
      tester,
      find.byKey(const ValueKey('goal-progress-detail-card')),
    );
    expect(find.text('Long-term progress'), findsOneWidget);
    await _bringIntoViewport(
      tester,
      find.byKey(const ValueKey('goal-daily-history-card')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Daily records'), findsOneWidget);
    await _bringIntoViewport(
      tester,
      find.byKey(const ValueKey('goal-review-history-weekly')),
    );
    expect(find.text('Weekly summaries'), findsOneWidget);
    await _bringIntoViewport(
      tester,
      find.byKey(const ValueKey('goal-review-history-overall')),
    );
    expect(find.text('Overall summaries'), findsOneWidget);
    expect(find.text('Overview'), findsNothing);
    expect(find.text('Feedback records'), findsNothing);
    expect(find.text('Conditions & patterns'), findsNothing);
    expect(find.text('Notes'), findsNothing);
    expect(find.text('Record new feedback'), findsNothing);
    await _bringIntoViewport(
      tester,
      find.byKey(
        const ValueKey('life-experiment-record-window-read-only'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const ValueKey('life-experiment-record-window-read-only'),
      ),
      findsOneWidget,
    );
    expect(
      find.text('This completed cycle is read-only.'),
      findsOneWidget,
    );
  });

  testWidgets('empty home hides aggregate route and keeps both empty states',
      (tester) async {
    final repository = StubWeeklyRepository(weekly: _emptyWeeklyModel);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => WeeklyViewModel(repository),
        child: const MaterialApp(home: ExperimentPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Small experiments · within 10 minutes'), findsOneWidget);
    expect(find.text('Goals · long-term'), findsOneWidget);
    expect(find.text('No small experiments yet'), findsOneWidget);
    expect(find.text('No goals yet'), findsOneWidget);
    expect(find.text('Search small experiments or goals...'), findsOneWidget);
    expect(find.byKey(const ValueKey('experiment-filter-tabs')), findsNothing);

    final emptyCta =
        find.byKey(const ValueKey('life-experiment-empty-record-today'));
    await _bringIntoViewport(tester, emptyCta);
    expect(emptyCta, findsOneWidget);

    expect(find.text('Archive overview'), findsNothing);
    expect(find.text('Goal details'), findsNothing);
  });

  testWidgets('experiment archive follows Today main-page density',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = StubWeeklyRepository(weekly: _weeklyModel);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => WeeklyViewModel(repository),
        child: const MaterialApp(home: ExperimentPage()),
      ),
    );
    await tester.pumpAndSettle();

    final scrollView = tester.widget<ListView>(
      find.byKey(const ValueKey('experiment-scroll-view')),
    );
    final padding = scrollView.padding! as EdgeInsets;
    expect(padding.left, AuroraMainPageSpec.horizontalPadding);
    expect(padding.top, AuroraMainPageSpec.topPadding);
    expect(padding.right, AuroraMainPageSpec.horizontalPadding);
    expect(padding.bottom, AuroraMainPageSpec.bottomNavigationClearance);
    expect(
      tester
          .widget<AuroraSafeTopMask>(find.byType(AuroraSafeTopMask))
          .extraHeight,
      4,
    );

    final hero = find.byKey(const ValueKey('experiment-hero-header'));
    expect(hero, findsOneWidget);
    expect(tester.getSize(hero).height, lessThanOrEqualTo(170));
    final title = tester.widget<Text>(find.text('Life Experiment'));
    expect(title.style?.fontSize, AuroraMainPageSpec.heroTitleSize);
    expect(title.style?.fontWeight, FontWeight.w700);
    expect(
      tester.getSize(find.byKey(const ValueKey('experiment-search-bar'))),
      const Size(354, 50),
    );
    final searchField = tester.widget<TextField>(find.byType(TextField));
    expect(searchField.decoration?.hintStyle?.fontSize, 14);

    // Search now sits directly below the hero, followed by the two lifecycle
    // charts. Scroll to the goal matrix before checking its row density.
    await tester.drag(
      find.byKey(const ValueKey('experiment-scroll-view')),
      const Offset(0, -420),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('experiment-filter-tabs')), findsNothing);
    expect(
        find.byKey(const ValueKey('small-try-branch-chart')), findsOneWidget);
    expect(find.byKey(const ValueKey('goal-timeline-matrix')), findsOneWidget);

    final archiveCard = find.byKey(
      const ValueKey('experiment-archive-card-exp_test'),
    );
    expect(archiveCard, findsOneWidget);
    final archiveTitle = tester.widget<Text>(
      find.text('Record 10 minutes in the morning').first,
    );
    expect(archiveTitle.style?.fontWeight, FontWeight.w700);
    expect(tester.getSize(archiveCard).height, greaterThanOrEqualTo(120));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'lifecycle charts fit supported phone widths with large text and 44pt targets',
      (tester) async {
    for (final surfaceSize in const [
      Size(320, 640),
      Size(390, 844),
      Size(440, 956),
    ]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.binding.setSurfaceSize(surfaceSize);
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => WeeklyViewModel(
            StubWeeklyRepository(weekly: _weeklyModel),
          ),
          child: const MaterialApp(
            locale: Locale.fromSubtags(
              languageCode: 'zh',
              scriptCode: 'Hans',
            ),
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
              child: ExperimentPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
          find.byKey(const ValueKey('experiment-filter-tabs')), findsNothing);
      expect(
          find.byKey(const ValueKey('small-try-branch-chart')), findsOneWidget);
      expect(
        tester
            .getSize(find.byKey(const ValueKey('experiment-search-bar')))
            .height,
        50,
      );

      final goalMatrix = find.byKey(const ValueKey('goal-timeline-matrix'));
      await _buildInScrollable(tester, goalMatrix);
      expect(goalMatrix, findsOneWidget);

      final goalRow = find.byKey(
        const ValueKey('experiment-archive-card-exp_test'),
      );
      await _buildInScrollable(tester, goalRow);
      expect(tester.getSize(goalRow).height, greaterThanOrEqualTo(44));
      final labeledSemantics = tester
          .widgetList<Semantics>(
            find.ancestor(of: goalRow, matching: find.byType(Semantics)),
          )
          .where(
            (semantics) =>
                semantics.properties.label?.trim().isNotEmpty ?? false,
          );
      expect(labeledSemantics, isNotEmpty);
      expect(labeledSemantics.first.properties.button, isTrue);

      expect(tester.takeException(), isNull);
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  testWidgets('compact archive and empty state stay dense without overflow',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => WeeklyViewModel(
          StubWeeklyRepository(weekly: _emptyWeeklyModel),
        ),
        child: const MaterialApp(
          locale: Locale.fromSubtags(
            languageCode: 'zh',
            scriptCode: 'Hans',
          ),
          home: ExperimentPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Life Experiment'), findsOneWidget);
    final hero = find.byKey(const ValueKey('experiment-hero-header'));
    expect(tester.getSize(hero).height, lessThanOrEqualTo(170));
    await tester.drag(
      find.byKey(const ValueKey('experiment-scroll-view')),
      const Offset(0, -420),
    );
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('small-try-branch-chart')), findsOneWidget);
    expect(find.byKey(const ValueKey('goal-timeline-matrix')), findsOneWidget);
    final emptyRecordToday =
        find.byKey(const ValueKey('life-experiment-empty-record-today'));
    await _bringIntoViewport(tester, emptyRecordToday);
    expect(
      tester.getSize(emptyRecordToday).height,
      greaterThanOrEqualTo(44),
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _bringIntoViewport(
  WidgetTester tester,
  Finder target, {
  bool searchDown = true,
}) async {
  final scrollable = find.byType(Scrollable).first;
  for (var attempt = 0; attempt < 30; attempt++) {
    if (target.evaluate().isNotEmpty) {
      final rect = tester.getRect(target.first);
      if (rect.top >= 8 && rect.bottom <= 592) return;
      await tester.drag(
        scrollable,
        Offset(0, rect.bottom > 592 ? -280 : 280),
      );
    } else {
      await tester.drag(scrollable, Offset(0, searchDown ? -280 : 280));
    }
    if (target.evaluate().isEmpty) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }
    await tester.pump();
  }
  expect(target, findsWidgets);
  final rect = tester.getRect(target.first);
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(rect.bottom, lessThanOrEqualTo(600));
}

Future<void> _buildInScrollable(
  WidgetTester tester,
  Finder target,
) async {
  final scrollable = find.byType(Scrollable).first;
  for (var attempt = 0; attempt < 30 && target.evaluate().isEmpty; attempt++) {
    await tester.drag(scrollable, const Offset(0, -240));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  expect(target, findsWidgets);
}

DateTime _testDateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _testDateKey(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)}';
}

final _weeklyModel = WeeklyInsightModel(
  weekStart: '2026-06-22',
  weekEnd: '2026-06-28',
  status: 'ready',
  keyInsight: 'Morning records make the day easier to see.',
  patterns: const [
    {'name': 'Morning rhythm', 'summary': 'A short record helps.'},
  ],
  frictions: const [
    {'name': 'Late switching', 'summary': 'Evenings get noisy.'},
  ],
  bestAction: 'Record 10 minutes each morning and observe the day’s changes.',
  opportunitySnapshot: {
    '_life_experiment': {
      'id': 'exp_test',
      'local_user_id': 'test-user',
      'source_week_start': '2026-06-22',
      'source_week_end': '2026-06-28',
      'title': 'Record 10 minutes in the morning',
      'hypothesis': 'Morning record may reduce switching load.',
      'suggested_action':
          'Record 10 minutes each morning and observe the day’s changes.',
      'feedback_text': 'Morning records helped me start with less switching.',
      'created_at': '2026-06-22T08:00:00.000',
      'updated_at': '2026-06-28T20:00:00.000',
      'linked_signal_card_ids': [
        'sig_1',
        'sig_2',
        'sig_3',
        'sig_4',
        'sig_5',
        'sig_6',
        'sig_7',
      ],
      'status': 'effective',
    },
    '_weekly_action_review': {
      'ai_judgement_count': 3,
      'confirmed_judgement_count': 2,
      'generated_action_count': 3,
      'tried_action_count': 1,
      'helpful_action_count': 1,
      'most_helpful_action': 'Morning record',
      'hardest_action': 'Late phone use',
      'next_adjustment': 'Keep it under 10 minutes',
      'linked_micro_action_ids': ['a1'],
    },
  },
  feedbackSubmitted: false,
);

final _emptyWeeklyModel = WeeklyInsightModel(
  weekStart: '2026-06-22',
  weekEnd: '2026-06-28',
  status: 'ready',
  keyInsight: 'Not enough signals yet.',
  patterns: const [],
  frictions: const [],
  bestAction: '',
  opportunitySnapshot: const {},
  feedbackSubmitted: false,
);
