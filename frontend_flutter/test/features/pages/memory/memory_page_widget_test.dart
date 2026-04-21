import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ai_opportunity_radar/core/api/repositories/memory_repository.dart';
import 'package:ai_opportunity_radar/core/models/memory_models.dart';
import 'package:ai_opportunity_radar/features/pages/me/me_view_model.dart';
import 'package:ai_opportunity_radar/features/pages/memory/memory_page.dart';
import 'package:ai_opportunity_radar/features/pages/memory/memory_view_model.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Journey 页面能加载并触发一次数据获取', (tester) async {
    final repo = StubMemoryRepository(
      result: MemoryFetchResult(
        isFirstDayGate: false,
        summary: MemorySummaryModel(
          patterns: const [
            JourneySignalItemModel(
              name: 'Needing a quiet reset after meetings',
              summary: 'A small need is starting to repeat.',
              signalLevel: 'weak_signal',
            ),
          ],
          frictions: const [
            JourneySignalItemModel(
              name: 'Interruptions during focused work',
              summary: 'This has already repeated enough to count as a pattern.',
              signalLevel: 'repeated_pattern',
            ),
          ],
          desires: const [],
          experiments: const [
            JourneySignalItemModel(
              name: 'A short evening reset walk',
              summary: 'This is starting to settle into a stable mode.',
              signalLevel: 'stable_mode',
            ),
          ],
        ),
      ),
    );

    final meVm = await buildMeViewModel(repeatArea: 'time_rhythm');

    await tester.pumpWidget(
      buildTestApp(
        child: const MemoryPage(),
        providers: [
          ChangeNotifierProvider<MemoryViewModel>(
            create: (_) => MemoryViewModel(repo),
          ),
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(MemoryPage), findsOneWidget);
    expect(find.text('Journey'), findsWidgets);
    expect(repo.fetchCallCount, 1);
  });

  testWidgets('Journey 第一天 gate 会显示对应空态', (tester) async {
    final repo = StubMemoryRepository(
      result: const MemoryFetchResult(
        isFirstDayGate: true,
        summary: null,
      ),
    );

    final meVm = await buildMeViewModel();

    await tester.pumpWidget(
      buildTestApp(
        child: const MemoryPage(),
        providers: [
          ChangeNotifierProvider<MemoryViewModel>(
            create: (_) => MemoryViewModel(repo),
          ),
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Journey starts on day 2'), findsOneWidget);
  });
}
