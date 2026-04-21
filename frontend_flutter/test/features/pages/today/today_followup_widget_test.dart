import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ai_opportunity_radar/core/models/today_models.dart';
import 'package:ai_opportunity_radar/features/pages/me/me_view_model.dart';
import 'package:ai_opportunity_radar/features/pages/today/today_page.dart';
import 'package:ai_opportunity_radar/features/pages/today/today_view_model.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Today 页面会提交 follow-up 选项并清掉问题卡片', (tester) async {
    final repo = StubTodayRepository(
      fetchTodayResult: {
        'insight': TodayInsightModel(text: 'A small thread is starting to show.'),
        'pendingQuestion': FollowupQuestionModel(
          id: 'followup-1',
          question: 'Where did this friction show up most clearly?',
          options: [
            FollowupOptionModel(label: 'Work', value: 'work'),
            FollowupOptionModel(label: 'Home', value: 'home'),
          ],
        ),
        'bestAction': DailyBestActionModel(text: 'Stay with the first scene.'),
        'recentSignals': const <RecentSignalModel>[],
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

    expect(
      find.text('Where did this friction show up most clearly?'),
      findsOneWidget,
    );
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);

    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();

    expect(repo.followupCalls.length, 1);
    expect(repo.followupCalls.first['followupId'], 'followup-1');
    expect(repo.followupCalls.first['answerValue'], 'work');
    expect(
      find.text('Where did this friction show up most clearly?'),
      findsNothing,
    );
  });
}
