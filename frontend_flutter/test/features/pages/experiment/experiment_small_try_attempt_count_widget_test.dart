import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_opportunity_radar/core/di/app_dependencies.dart';
import 'package:ai_opportunity_radar/core/local/local_cache_invalidation_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/models/experiment_creation_source.dart';
import 'package:ai_opportunity_radar/core/models/phase3_plus_models.dart';
import 'package:ai_opportunity_radar/core/models/weekly_models.dart';
import 'package:ai_opportunity_radar/features/pages/experiment/experiment_page.dart';
import 'package:ai_opportunity_radar/features/pages/weekly/weekly_view_model.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);

  testWidgets(
    '小实验详情按真实尝试计数，忽略未尝试，并在反馈失效通知后刷新',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final today = _dateOnly(DateTime.now());
      final weekStart = today.subtract(
        Duration(days: today.weekday - DateTime.monday),
      );
      final weeklyRepository = StubWeeklyRepository(
        weekly: _weeklyFixture(
          weekStart: weekStart,
          weekEnd: weekStart.add(const Duration(days: 6)),
        ),
      );

      late Directory tempDir;
      late LocalDatabase database;
      late AppDependencies dependencies;
      await tester.runAsync(() async {
        tempDir = await Directory.systemTemp.createTemp(
          'small_try_attempt_count_',
        );
        database = LocalDatabase(
          dbPathOverride: p.join(tempDir.path, 'attempt-count.db'),
          databaseFactoryOverride: databaseFactoryFfi,
        );
        await database.init();
        dependencies = await buildTestDependencies(
          todayRepository: StubTodayRepository(fetchTodayResult: const {}),
          weeklyRepository: weeklyRepository,
          localDatabaseOverride: database,
        );

        await dependencies.localPhase3PlusRepository.upsertMicroAction(
          MicroActionModel(
            id: 'attempt-count-small-try',
            judgementId: '',
            title: '任务切换前留两分钟缓冲',
            reason: '减少连续切换造成的精力下降。',
            status: 'active',
            localUserId: dependencies.localUserId,
            adoptedAt: weekStart.add(const Duration(hours: 9)),
            progressStartDate: _dateKey(weekStart),
            progressEndDate: _dateKey(
              weekStart.add(const Duration(days: 6)),
            ),
            creationSource: ExperimentCreationSource.candidateAdoption,
          ),
        );

        final db = await database.database;
        final createdAt = today.add(const Duration(hours: 9));
        await db.insert(
          'micro_action_feedback',
          _legacyFeedbackRow(
            id: 'legacy-completed',
            happened: 'completed',
            localDate: _dateKey(today),
            createdAt: createdAt,
          ),
        );
        await db.insert(
          'micro_action_feedback',
          _legacyFeedbackRow(
            id: 'legacy-done',
            happened: 'done',
            localDate: _dateKey(today),
            createdAt: createdAt.add(const Duration(minutes: 1)),
          ),
        );
        await db.insert(
          'micro_action_feedback',
          _legacyFeedbackRow(
            id: 'legacy-not-attempted',
            happened: 'not_completed',
            localDate: _dateKey(today),
            createdAt: createdAt.add(const Duration(minutes: 2)),
          ),
        );
      });
      addTearDown(() async {
        await dependencies.localCandidatePlanningRepository.dispose();
        await database.close();
        await tempDir.delete(recursive: true);
      });

      await tester.pumpWidget(
        buildTestApp(
          locale: const Locale.fromSubtags(
            languageCode: 'zh',
            scriptCode: 'Hans',
          ),
          providers: [
            Provider<AppDependencies>.value(value: dependencies),
            ChangeNotifierProvider(
              create: (_) => WeeklyViewModel(weeklyRepository),
            ),
          ],
          child: const ExperimentPage(),
        ),
      );
      await _pumpUntilFound(
        tester,
        find.byKey(
          const ValueKey(
            'life-experiment-small-try-attempt-count-small-try',
          ),
        ),
      );

      expect(find.text('本轮尝试 2 次'), findsOneWidget);
      await tester.tap(
        find.byKey(
          const ValueKey(
            'life-experiment-small-try-attempt-count-small-try',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('小实验详情'), findsOneWidget);
      expect(find.text('本轮尝试 2 次'), findsOneWidget);
      expect(find.text('本轮尝试 0 次'), findsNothing);
      expect(find.text('本轮尝试 3 次'), findsNothing);
      expect(
        find.byKey(
          const ValueKey('small-experiment-detail-overview'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('small-experiment-completion-chart'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('small-experiment-feedback-chart'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('已记录 2 次真实尝试'), findsOneWidget);
      expect(
        find.textContaining('明确的效果反馈还不足'),
        findsOneWidget,
      );
      expect(
        find.textContaining('图中只把三档评价'),
        findsNothing,
      );
      expect(find.text('创建方式'), findsOneWidget);
      expect(find.text('智能提议 · 已采纳'), findsOneWidget);
      expect(find.textContaining('来源 Signal'), findsNothing);
      expect(find.text('计划版本'), findsNothing);
      expect(find.text('每次尝试'), findsNothing);
      expect(
        find.byKey(
          const ValueKey(
            'experiment-content-change-guide-smallExperiment',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('small-experiment-feedback-overview'),
        ),
        findsOneWidget,
      );

      await tester.runAsync(() async {
        final db = await database.database;
        await db.transaction((txn) async {
          await txn.insert(
            'micro_action_feedback',
            _legacyFeedbackRow(
              id: 'feedback-while-detail-open-1',
              happened: 'completed',
              localDate: _dateKey(today),
              createdAt: today.add(const Duration(hours: 10)),
            ),
          );
          await txn.insert(
            'micro_action_feedback',
            _legacyFeedbackRow(
              id: 'feedback-while-detail-open-2',
              happened: 'completed',
              localDate: _dateKey(today),
              createdAt: today.add(const Duration(hours: 10, minutes: 1)),
            ),
          );
        });
        final notice = CandidateInvalidationNotice(
          localDatabase: database,
          candidateKind: 'micro_action',
          periodStart: _dateKey(today),
          periodEnd: _dateKey(today),
        );
        CandidateInvalidationBus.publish(notice);
      });
      await _pumpUntilFound(
        tester,
        find.text('本轮尝试 4 次'),
      );

      expect(find.text('小实验详情'), findsOneWidget);
      expect(find.text('本轮尝试 4 次'), findsOneWidget);
      expect(find.text('本轮尝试 5 次'), findsNothing);
      expect(find.textContaining('已记录 4 次真实尝试'), findsOneWidget);
      expect(find.textContaining('已记录 2 次真实尝试'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('生活小实验页可分别进入用户自建小实验和目标页面', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final today = _dateOnly(DateTime.now());
    final weekStart = today.subtract(
      Duration(days: today.weekday - DateTime.monday),
    );
    final weeklyRepository = StubWeeklyRepository(
      weekly: _weeklyFixture(
        weekStart: weekStart,
        weekEnd: weekStart.add(const Duration(days: 6)),
      ),
    );

    late Directory tempDir;
    late LocalDatabase database;
    late AppDependencies dependencies;
    await tester.runAsync(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'experiment_create_entry_',
      );
      database = LocalDatabase(
        dbPathOverride: p.join(tempDir.path, 'create-entry.db'),
        databaseFactoryOverride: databaseFactoryFfi,
      );
      await database.init();
      dependencies = await buildTestDependencies(
        todayRepository: StubTodayRepository(fetchTodayResult: const {}),
        weeklyRepository: weeklyRepository,
        localDatabaseOverride: database,
      );
    });
    addTearDown(() async {
      await dependencies.localCandidatePlanningRepository.dispose();
      await database.close();
      await tempDir.delete(recursive: true);
    });

    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        providers: [
          Provider<AppDependencies>.value(value: dependencies),
          ChangeNotifierProvider(
            create: (_) => WeeklyViewModel(weeklyRepository),
          ),
        ],
        child: const ExperimentPage(),
      ),
    );
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('experiment-create-entry-card')),
    );

    expect(
      find.byKey(const ValueKey('create-small-experiment-entry')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('create-goal-entry')), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('create-small-experiment-entry')),
    );
    await tester.pumpAndSettle();
    expect(find.text('新建小实验'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('small-experiment-duration')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('save-user-small-experiment')),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.chevron_left_rounded).first);
    await tester.pump();
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('create-goal-entry')),
    );
    await tester.tap(find.byKey(const ValueKey('create-goal-entry')));
    await tester.pump();
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('goal-frequency')),
    );
    expect(find.text('新建目标'), findsWidgets);
    expect(find.byKey(const ValueKey('goal-frequency')), findsOneWidget);
    expect(find.byKey(const ValueKey('save-user-goal')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}

Map<String, Object?> _legacyFeedbackRow({
  required String id,
  required String happened,
  required String localDate,
  required DateTime createdAt,
}) {
  final timestamp = createdAt.toUtc().toIso8601String();
  return {
    'id': id,
    'micro_action_id': 'attempt-count-small-try',
    'local_date': localDate,
    'happened': happened,
    // Legacy rows can predate the structured effect and burden evaluation.
    'effect': null,
    'difficulty': null,
    'user_note': null,
    'next_adjustment': null,
    'duration_minutes': null,
    'created_at': timestamp,
    'updated_at': timestamp,
    'is_valid': 1,
  };
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder,
) async {
  for (var attempt = 0; attempt < 40 && finder.evaluate().isEmpty; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump(const Duration(milliseconds: 40));
  }
  expect(finder, findsWidgets);
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _dateKey(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)}';
}

WeeklyInsightModel _weeklyFixture({
  required DateTime weekStart,
  required DateTime weekEnd,
}) {
  return WeeklyInsightModel(
    weekStart: _dateKey(weekStart),
    weekEnd: _dateKey(weekEnd),
    status: 'ready',
    keyInsight: '保持真实尝试记录。',
    patterns: const [],
    frictions: const [],
    bestAction: '',
    opportunitySnapshot: const {},
    feedbackSubmitted: false,
  );
}
