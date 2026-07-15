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
    final experiment =
        await dependencies.localLifeExperimentRepository.ensureSuggested(
      localUserId: dependencies.localUserId,
      weekStart: '2026-07-13',
      weekEnd: '2026-07-19',
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

  testWidgets('feedback page follows Today visual system without overflow',
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

    expect(find.text('Experiment feedback'), findsOneWidget);
    expect(find.text('Keep one small pause between switches'), findsOneWidget);
    expect(find.text('What happened today?'), findsOneWidget);
    expect(find.byType(AuroraHeroEmblem), findsOneWidget);
    expect(find.byType(AuroraSectionIcon), findsNWidgets(2));
    expect(find.byType(AuroraSafeTopMask), findsOneWidget);
    expect(
      find.byKey(const ValueKey('experiment-feedback-scroll-view')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Helpful'));
    await tester.pump();
    final selected = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Helpful'),
    );
    expect(selected.selected, isTrue);
    expect(tester.takeException(), isNull);
  });
}
