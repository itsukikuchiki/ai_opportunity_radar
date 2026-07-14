import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ai_opportunity_radar/core/models/weekly_models.dart';
import 'package:ai_opportunity_radar/features/pages/experiment/experiment_page.dart';
import 'package:ai_opportunity_radar/features/pages/weekly/weekly_view_model.dart';
import 'package:ai_opportunity_radar/shared/widgets/aurora_ui.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  testWidgets('shows all-time experiment archive and detail tabs',
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
    expect(find.text('Record 10 minutes in the morning'), findsOneWidget);
    expect(find.text('In progress this week'), findsOneWidget);
    expect(find.text('This week progress'), findsOneWidget);
    expect(find.text('0/7'), findsOneWidget);
    expect(find.text('Record today'), findsOneWidget);

    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    expect(find.text('Experiment details'), findsOneWidget);
    expect(find.text('Status breakdown'), findsOneWidget);
    expect(find.text('Attempt summary'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_left_rounded).first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('View details'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View details'));
    await tester.pumpAndSettle();

    expect(find.text('Experiment detail'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Experiment timeline summary'), findsOneWidget);
    expect(find.text('Lifecycle timeline'), findsOneWidget);
    expect(find.text('Real records'), findsOneWidget);
    expect(find.text('6/22'), findsOneWidget);
    expect(find.text('6/28'), findsOneWidget);

    await tester.tap(find.text('Feedback records'));
    await tester.pumpAndSettle();
    expect(find.text('Overall trend'), findsOneWidget);
    expect(find.text('Feedback list'), findsOneWidget);

    await tester.tap(find.text('Conditions & patterns'));
    await tester.pumpAndSettle();
    expect(find.text('When does it work better?'), findsOneWidget);
    expect(find.text('AI insight'), findsOneWidget);

    await tester.drag(
      find
          .byWidgetPredicate(
            (widget) =>
                widget is ListView && widget.scrollDirection == Axis.horizontal,
          )
          .first,
      const Offset(-260, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();
    expect(find.text('Experiment notes'), findsOneWidget);
  });

  testWidgets('empty archive hides search filters and keeps summary details',
      (tester) async {
    final repository = StubWeeklyRepository(weekly: _emptyWeeklyModel);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => WeeklyViewModel(repository),
        child: const MaterialApp(home: ExperimentPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No small experiments yet'), findsOneWidget);
    expect(find.text('Record today'), findsOneWidget);
    expect(find.text('Search my experiments...'), findsNothing);
    expect(find.text('Details'), findsOneWidget);

    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    expect(find.text('Experiment details'), findsOneWidget);
    expect(find.text('No experiment details yet'), findsOneWidget);
    expect(find.textContaining('After you add a next-week experiment'),
        findsOneWidget);
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

    expect(
      tester.getSize(find.byKey(const ValueKey('experiment-search-bar'))),
      const Size(354, 50),
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('experiment-filter-tabs')))
          .height,
      lessThanOrEqualTo(46),
    );
    final searchField = tester.widget<TextField>(find.byType(TextField));
    expect(searchField.decoration?.hintStyle?.fontSize, 14);

    final archiveCard = find.byKey(
      const ValueKey('experiment-archive-card-exp_test'),
    );
    expect(archiveCard, findsOneWidget);
    expect(
      tester.getSize(
        find.byKey(const ValueKey('experiment-archive-icon-exp_test')),
      ),
      const Size.square(48),
    );
    final archiveTitle = tester.widget<Text>(
      find.text('Record 10 minutes in the morning').first,
    );
    expect(archiveTitle.style?.fontSize, 17);
    final sectionTitle =
        tester.widget<Text>(find.text('In progress this week'));
    expect(sectionTitle.style?.fontSize, 17);
    expect(tester.takeException(), isNull);
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
    expect(
      tester
          .getSize(find.byKey(const ValueKey('experiment-empty-archive')))
          .height,
      lessThan(240),
    );
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('experiment-empty-primary-action')),
          )
          .height,
      48,
    );
    expect(find.byKey(const ValueKey('experiment-archive-summary')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
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
