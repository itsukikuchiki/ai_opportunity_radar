import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_opportunity_radar/core/di/app_dependencies.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/features/pages/memory/journal_page.dart';
import 'package:ai_opportunity_radar/shared/widgets/aurora_ui.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late LocalDatabase database;
  late AppDependencies dependencies;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('journal_widget_test_');
    database = LocalDatabase(
      dbPathOverride: p.join(tempDir.path, 'journal.db'),
      databaseFactoryOverride: databaseFactoryFfi,
    );
    await database.init();
    dependencies = await buildTestDependencies(
      todayRepository: StubTodayRepository(fetchTodayResult: const {}),
      localDatabaseOverride: database,
    );
  });

  tearDown(() async {
    await database.close();
    await tempDir.delete(recursive: true);
  });

  testWidgets('Journal 空状态不再展示硬编码示例记录', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        child: const JournalPage(),
        providers: [Provider<AppDependencies>.value(value: dependencies)],
      ),
    );
    await tester.runAsync(
      () => dependencies.localCaptureRepository.listSignalCards(limit: 2000),
    );
    await tester.pump();

    expect(find.textContaining('本月还没有片段'), findsOneWidget);
    expect(find.text('第一次把想说的话写出来'), findsNothing);
    expect(find.byKey(const ValueKey('journey-journal-hero')), findsOneWidget);
    expect(find.byType(AuroraHeroTitle), findsOneWidget);
    expect(find.byType(AuroraHeroEmblem), findsOneWidget);
  });

  testWidgets('Journal 从统一 SignalCard 时间线读取真机新记录', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.runAsync(
      () => dependencies.localCaptureRepository.insertConfirmedSignalCard(
        content: '状态补充：下午开始有点转不动。',
        sourceType: 'one_tap',
        language: 'zh-Hans',
        rawPayloadJson: const {
          'quick_status': 'tired',
          'energy_level': 0,
          'note': '下午开始有点转不动。',
        },
      ),
    );

    await tester.pumpWidget(
      buildTestApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        child: const JournalPage(),
        providers: [Provider<AppDependencies>.value(value: dependencies)],
      ),
    );
    await tester.runAsync(
      () => dependencies.localCaptureRepository.listSignalCards(limit: 2000),
    );
    await tester.pump();

    expect(find.text('状态补充：下午开始有点转不动。'), findsOneWidget);
    expect(find.textContaining('本月还没有片段'), findsNothing);
  });
}
