import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ai_opportunity_radar/core/models/today_models.dart';
import 'package:ai_opportunity_radar/features/pages/me/me_view_model.dart';
import 'package:ai_opportunity_radar/features/pages/today/today_page.dart';
import 'package:ai_opportunity_radar/features/pages/today/today_view_model.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Today 不展示旧 capture follow-up 问题或创建第二写入路径', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = StubTodayRepository(
      fetchTodayResult: {
        'insight':
            TodayInsightModel(text: 'A small thread is starting to show.'),
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
      findsNothing,
    );
    expect(find.text('Work'), findsNothing);
    expect(find.text('Home'), findsNothing);
    expect(repo.followupCalls, isEmpty);
  });
}
