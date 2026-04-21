import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ai_opportunity_radar/core/models/today_models.dart';
import 'package:ai_opportunity_radar/features/pages/me/me_view_model.dart';
import 'package:ai_opportunity_radar/features/pages/today/today_page.dart';
import 'package:ai_opportunity_radar/features/pages/today/today_view_model.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Today 页面能加载并触发一次数据获取', (tester) async {
    final repo = StubTodayRepository(
      fetchTodayResult: {
        'insight': TodayInsightModel(
          text: 'Today, the tension seems to gather around work interruptions.',
        ),
        'pendingQuestion': null,
        'bestAction': DailyBestActionModel(
          text: 'Try noticing the exact moment the pressure first rises.',
        ),
        'recentSignals': [
          RecentSignalModel(
            id: 'signal-1',
            content: 'The meeting kept getting interrupted and I felt drained.',
            createdAt: DateTime.now(),
            acknowledgement: 'That sounds genuinely draining.',
            observation: 'Work interruptions are taking up more space than they seem.',
            tryNext: 'Write down the first interruption next time.',
            emotion: 'negative',
            intensity: 'medium',
            sceneTags: const ['work'],
          ),
        ],
      },
    );

    final meVm = await buildMeViewModel();

    await tester.pumpWidget(
      buildTestApp(
        child: const TodayPage(),
        providers: [
          ChangeNotifierProvider<TodayViewModel>(
            create: (_) => TodayViewModel(repo),
          ),
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(TodayPage), findsOneWidget);
    expect(find.text('Today'), findsWidgets);
    expect(find.text('Today’s entries'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(repo.fetchTodayCallCount, 1);
  });
}
