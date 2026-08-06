import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_opportunity_radar/core/di/app_dependencies.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/features/pages/today/today_experiment_feedback_page.dart';
import 'package:ai_opportunity_radar/shared/widgets/aurora_ui.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late LocalDatabase database;
  late AppDependencies dependencies;
  late String experimentId;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'experiment_feedback_widget_test_',
    );
    database = LocalDatabase(
      dbPathOverride: p.join(tempDir.path, 'feedback.db'),
      databaseFactoryOverride: databaseFactoryFfi,
    );
    await database.init();
    dependencies = await buildTestDependencies(
      todayRepository: StubTodayRepository(fetchTodayResult: const {}),
      localDatabaseOverride: database,
    );
    final today = _dateOnly(DateTime.now());
    final progressStart = today.subtract(const Duration(days: 2));
    final progressEnd = progressStart.add(const Duration(days: 6));
    final experiment =
        await dependencies.localLifeExperimentRepository.ensureSuggested(
      localUserId: dependencies.localUserId,
      weekStart: _dateKey(progressStart),
      weekEnd: _dateKey(progressEnd),
      title: 'Keep one small pause between switches',
      hypothesis: 'A short pause may make switching feel lighter.',
      suggestedAction: 'Pause for two minutes before the next task.',
      linkedSignalCardIds: const ['signal-1', 'signal-2', 'signal-3'],
      status: 'active',
    );
    experimentId = experiment.id;
  });

  tearDown(() async {
    await database.close();
    await tempDir.delete(recursive: true);
  });

  testWidgets('feedback page exposes canonical goal completion choices',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      Provider<AppDependencies>.value(
        value: dependencies,
        child: MaterialApp(
          home: TodayExperimentFeedbackPage(experimentId: experimentId),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pump();

    expect(find.text('Goal feedback'), findsOneWidget);
    expect(find.text('Keep one small pause between switches'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Not completed'), findsOneWidget);
    expect(find.text('Happened'), findsNothing);
    expect(find.text('Helpful'), findsNothing);
    expect(find.text('Want to adjust'), findsNothing);
    expect(find.text('Not today'), findsNothing);
    expect(
      find.byKey(const ValueKey('experiment-feedback-experiment-pattern')),
      findsOneWidget,
    );
    expect(find.byType(AuroraExperimentHeroPattern), findsOneWidget);
    expect(find.byType(AuroraSignalHeroPattern), findsNothing);
    expect(find.byType(AuroraHeroEmblem), findsNothing);
    expect(find.byType(AuroraSectionIcon), findsNWidgets(2));
    expect(find.byType(AuroraSafeTopMask), findsOneWidget);
    expect(
      find.byKey(const ValueKey('experiment-feedback-scroll-view')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Completed'));
    await tester.pump();
    final selected = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Completed'),
    );
    expect(selected.selected, isTrue);

    await tester.tap(find.text('Not completed'));
    await tester.pump();
    final notCompleted = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Not completed'),
    );
    expect(notCompleted.selected, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('goal with an explicit past end is read-only', (tester) async {
    final today = _dateOnly(DateTime.now());
    final expiredStart = today.subtract(const Duration(days: 14));
    final expiredEnd = expiredStart.add(const Duration(days: 6));
    late String expiredId;
    await tester.runAsync(() async {
      final expired =
          await dependencies.localLifeExperimentRepository.ensureSuggested(
        localUserId: dependencies.localUserId,
        weekStart: _dateKey(expiredStart),
        weekEnd: _dateKey(expiredEnd),
        title: 'An expired goal',
        hypothesis: 'Old evidence remains readable.',
        suggestedAction: 'Keep history without accepting new feedback.',
        linkedSignalCardIds: const [
          'signal-old-1',
          'signal-old-2',
          'signal-old-3'
        ],
        status: 'active',
        progressStartDate: _dateKey(expiredStart),
        progressEndDate: _dateKey(expiredEnd),
      );
      expiredId = expired.id;
    });

    await tester.pumpWidget(
      Provider<AppDependencies>.value(
        value: dependencies,
        child: MaterialApp(
          home: TodayExperimentFeedbackPage(experimentId: expiredId),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('goal-feedback-record-window-read-only')),
      findsOneWidget,
    );
    expect(find.text('The planned record period has ended.'), findsOneWidget);
    expect(find.text('Completed'), findsNothing);
    expect(find.text('Not completed'), findsNothing);
    expect(find.text('Save feedback'), findsNothing);
  });

  testWidgets(
      'past source week does not end a long-running goal without an explicit end',
      (tester) async {
    final today = _dateOnly(DateTime.now());
    final sourceWeekStart = today.subtract(const Duration(days: 35));
    final sourceWeekEnd = sourceWeekStart.add(const Duration(days: 6));
    late String longRunningId;
    await tester.runAsync(() async {
      final longRunning =
          await dependencies.localLifeExperimentRepository.ensureSuggested(
        localUserId: dependencies.localUserId,
        weekStart: _dateKey(sourceWeekStart),
        weekEnd: _dateKey(sourceWeekEnd),
        title: 'A long-running goal',
        hypothesis: 'A lasting practice needs more than one source week.',
        suggestedAction: 'Keep recording progress after the source week.',
        linkedSignalCardIds: const [
          'signal-long-1',
          'signal-long-2',
          'signal-long-3',
        ],
        status: 'active',
        progressStartDate: _dateKey(sourceWeekStart),
      );
      longRunningId = longRunning.id;
    });

    await tester.pumpWidget(
      Provider<AppDependencies>.value(
        value: dependencies,
        child: MaterialApp(
          home: TodayExperimentFeedbackPage(experimentId: longRunningId),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('goal-feedback-record-window-read-only')),
      findsNothing,
    );
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Not completed'), findsOneWidget);
    expect(find.text('Save feedback'), findsOneWidget);
  });

  testWidgets('future planned record period is read-only until its start',
      (tester) async {
    final today = _dateOnly(DateTime.now());
    final futureStart = today.add(const Duration(days: 14));
    final futureSourceEnd = futureStart.add(const Duration(days: 6));
    late String futureId;
    await tester.runAsync(() async {
      final future =
          await dependencies.localLifeExperimentRepository.ensureSuggested(
        localUserId: dependencies.localUserId,
        weekStart: _dateKey(futureStart),
        weekEnd: _dateKey(futureSourceEnd),
        title: 'A future goal',
        hypothesis: 'Feedback begins with the planned start.',
        suggestedAction: 'Wait until the planned record period starts.',
        linkedSignalCardIds: const [
          'signal-future-1',
          'signal-future-2',
          'signal-future-3',
        ],
        status: 'active',
        progressStartDate: _dateKey(futureStart),
      );
      futureId = future.id;
    });

    await tester.pumpWidget(
      Provider<AppDependencies>.value(
        value: dependencies,
        child: MaterialApp(
          home: TodayExperimentFeedbackPage(experimentId: futureId),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pump();

    expect(
      find.text('The planned record period has not started yet.'),
      findsOneWidget,
    );
    expect(find.text('Completed'), findsNothing);
    expect(find.text('Not completed'), findsNothing);
  });

  testWidgets('repository rejection never shows a saved message',
      (tester) async {
    await tester.pumpWidget(
      Provider<AppDependencies>.value(
        value: dependencies,
        child: MaterialApp(
          home: TodayExperimentFeedbackPage(experimentId: experimentId),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pump();
    await tester.tap(find.text('Completed'));
    await tester.pump();

    await tester.runAsync(() async {
      final db = await database.database;
      await db.update(
        'life_experiments',
        {
          // A direct fixture write simulates an already-closed historical row.
          // Production has no manual terminal-status writer.
          'status': 'completed',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [experimentId],
      );
    });
    await tester.tap(find.text('Save feedback'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pump();

    expect(
      find.text(
        'This goal is not currently within its planned record period.',
      ),
      findsOneWidget,
    );
    expect(find.text('Goal feedback saved.'), findsNothing);
    late bool hasFeedback;
    await tester.runAsync(() async {
      final feedbacks = await dependencies.localLifeExperimentRepository
          .listFeedbacks(experimentId: experimentId);
      hasFeedback = feedbacks.isNotEmpty;
    });
    expect(hasFeedback, isFalse);
  });

  test('empty feedback note remains empty instead of getting default copy', () {
    expect(TodayExperimentFeedbackPage.normalizedFeedbackText(''), '');
    expect(TodayExperimentFeedbackPage.normalizedFeedbackText('   '), '');
    expect(
      TodayExperimentFeedbackPage.normalizedFeedbackText('  real note  '),
      'real note',
    );
  });
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _dateKey(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)}';
}
