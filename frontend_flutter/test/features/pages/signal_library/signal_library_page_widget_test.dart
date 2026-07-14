import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ai_opportunity_radar/core/api/repositories/signal_library_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/models/signal_library_models.dart';
import 'package:ai_opportunity_radar/core/models/today_models.dart';
import 'package:ai_opportunity_radar/features/pages/signal_library/signal_library_page.dart';
import 'package:ai_opportunity_radar/features/pages/signal_library/signal_library_view_model.dart';

void main() {
  testWidgets('shows privacy-safe official abstract patterns', (tester) async {
    await tester.pumpWidget(_buildWidget());
    await tester.pump();

    expect(find.text('Signal Library'), findsOneWidget);
    expect(find.text('Search a signal...'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('emotional stability'), findsOneWidget);
    expect(find.text('self boundary'), findsOneWidget);
    expect(find.textContaining('fixed commitments'), findsOneWidget);
    expect(find.text('Does this match me?'), findsOneWidget);
    expect(find.text('Save'), findsNothing);
    expect(find.text('Make it mine'), findsNothing);
    expect(find.textContaining('observation'), findsNothing);
    expect(find.textContaining('you are this kind of person'), findsNothing);
  });

  testWidgets('accurate can edit and add one SignalCard to the timeline',
      (tester) async {
    final repository = _FakeSignalLibraryRepository();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_buildWidget(repository: repository));
    await tester.pump();

    final review = find.byKey(
      const ValueKey('library-review-over_scheduled_weeks'),
    );
    await tester.ensureVisible(review);
    await tester.tap(review);
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('library-signal-accurate')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('library-signal-partial')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('library-signal-inaccurate')),
      findsOneWidget,
    );
    expect(find.text('Try today'), findsNothing);
    expect(find.text('Save'), findsNothing);
    expect(find.textContaining('observation'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('library-signal-accurate')));
    await tester.pumpAndSettle();
    final input = find.byKey(const ValueKey('library-signal-timeline-input'));
    expect(input, findsOneWidget);
    await tester.enterText(input, 'I need more room between fixed plans.');
    await tester.tap(
      find.byKey(const ValueKey('library-signal-add-timeline')),
    );
    await tester.pumpAndSettle();

    expect(repository.responses, hasLength(1));
    expect(repository.responses.single['status'], 'accurate');
    expect(repository.responses.single['userText'],
        'I need more room between fixed plans.');
    expect(repository.responses.single['addToTimeline'], isTrue);
    expect(find.text('Added to your timeline.'), findsOneWidget);
  });

  testWidgets('somewhat can edit then decline timeline with zero response',
      (tester) async {
    final repository = _FakeSignalLibraryRepository();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_buildWidget(repository: repository));
    await tester.pump();

    final review = find.byKey(
      const ValueKey('library-review-over_scheduled_weeks'),
    );
    await tester.ensureVisible(review);
    await tester.tap(review);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('library-signal-partial')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('library-signal-timeline-input')),
      'Only the lack of buffer feels familiar.',
    );
    await tester.tap(
      find.byKey(const ValueKey('library-signal-do-not-add')),
    );
    await tester.pumpAndSettle();

    expect(repository.responses, isEmpty);
    expect(
      find.text('Nothing was added to your timeline.'),
      findsOneWidget,
    );
  });

  testWidgets('Chinese copy uses three real judgements without old actions',
      (tester) async {
    final repository = _FakeSignalLibraryRepository();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_buildWidget(
      repository: repository,
      locale: const Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hans',
      ),
    ));
    await tester.pump();

    expect(repository.lastLanguage, 'zh-Hans');
    expect(find.text('看看像不像我'), findsOneWidget);
    await tester.tap(find.text('看看像不像我'));
    await tester.pumpAndSettle();
    expect(find.text('准'), findsOneWidget);
    expect(find.text('有一点像'), findsOneWidget);
    expect(find.text('不准'), findsOneWidget);
    expect(find.text('加入今日小行动'), findsNothing);
    expect(find.text('保存观察'), findsNothing);
    expect(find.text('暂时不做'), findsNothing);
    expect(find.textContaining('你就是这种人'), findsNothing);
    expect(find.textContaining('你有这个问题'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('library-signal-inaccurate')));
    await tester.pumpAndSettle();
    expect(repository.responses, isEmpty);
    expect(
      find.byKey(const ValueKey('library-signal-timeline-input')),
      findsNothing,
    );
  });

  testWidgets('passes Traditional Chinese and Japanese locale codes',
      (tester) async {
    final traditionalRepository = _FakeSignalLibraryRepository();
    await tester.pumpWidget(
      _buildWidget(
        repository: traditionalRepository,
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hant',
        ),
      ),
    );
    await tester.pump();
    expect(traditionalRepository.lastLanguage, 'zh-Hant');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    final japaneseRepository = _FakeSignalLibraryRepository();
    await tester.pumpWidget(
      _buildWidget(
        repository: japaneseRepository,
        locale: const Locale('ja'),
      ),
    );
    await tester.pump();
    expect(japaneseRepository.lastLanguage, 'ja');
  });

  testWidgets('reloads curated patterns when the app language changes',
      (tester) async {
    final repository = _FakeSignalLibraryRepository();
    final locale = ValueNotifier<Locale>(const Locale('en'));

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => SignalLibraryViewModel(repository),
        child: ValueListenableBuilder<Locale>(
          valueListenable: locale,
          builder: (context, value, _) => MaterialApp(
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            locale: value,
            supportedLocales: const [
              Locale('en'),
              Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
              Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
              Locale('ja'),
            ],
            home: const SignalLibraryPage(),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('fixed commitments'), findsOneWidget);

    locale.value = const Locale.fromSubtags(
      languageCode: 'zh',
      scriptCode: 'Hans',
    );
    await tester.pump();
    await tester.pump();

    expect(repository.requestedLanguages, ['en', 'zh-Hans']);
    expect(find.text('有些时候，一周里固定安排很多，中间却几乎没有可以缓一缓的空隙。'), findsOneWidget);
    expect(find.textContaining('fixed commitments'), findsNothing);
  });

  testWidgets(
      'category chips filter visible library cards instead of acting as static labels',
      (tester) async {
    final repository = _FakeSignalLibraryRepository(includeCategorySet: true);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_buildWidget(repository: repository));
    await tester.pump();

    expect(find.textContaining('fixed commitments'), findsOneWidget);
    expect(find.textContaining('rest starts feeling'), findsOneWidget);

    await tester.ensureVisible(
        find.byKey(const ValueKey('library-category-food_sleep')));
    await tester.tap(find.byKey(const ValueKey('library-category-food_sleep')));
    await tester.pump();

    expect(find.textContaining('rest starts feeling'), findsOneWidget);
    expect(find.textContaining('fixed commitments'), findsNothing);

    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(-520, 0),
    );
    await tester.pump();
    await tester.ensureVisible(
        find.byKey(const ValueKey('library-category-growth_plan')));
    await tester
        .tap(find.byKey(const ValueKey('library-category-growth_plan')));
    await tester.pump();

    expect(find.textContaining('fixed commitments'), findsOneWidget);
    expect(find.textContaining('rest starts feeling'), findsNothing);

    await tester.ensureVisible(
        find.byKey(const ValueKey('library-category-self_boundary')));
    await tester
        .tap(find.byKey(const ValueKey('library-category-self_boundary')));
    await tester.pump();

    expect(find.textContaining('relationship itself'), findsOneWidget);
    expect(find.textContaining('fixed commitments'), findsNothing);
  });
}

Widget _buildWidget(
    {Locale? locale, _FakeSignalLibraryRepository? repository}) {
  final fakeRepository = repository ?? _FakeSignalLibraryRepository();
  return ChangeNotifierProvider(
    create: (_) => SignalLibraryViewModel(fakeRepository),
    child: MaterialApp(
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      locale: locale,
      supportedLocales: const [
        Locale('en'),
        Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
        Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        Locale('ja'),
      ],
      home: const SignalLibraryPage(),
    ),
  );
}

class _FakeSignalLibraryRepository extends SignalLibraryRepository {
  _FakeSignalLibraryRepository({this.includeCategorySet = false})
      : super(LocalDatabase());

  final bool includeCategorySet;

  String? lastLanguage;
  final List<String> requestedLanguages = [];
  final List<Map<String, Object?>> responses = [];

  @override
  Future<List<LibraryPatternModel>> listCuratedPatterns({
    String language = 'en',
  }) async {
    lastLanguage = language;
    requestedLanguages.add(language);
    if (includeCategorySet && language == 'en') {
      return [_pattern, _recoveryPattern, _relationshipPattern];
    }
    return [language == 'zh-Hans' ? _simplifiedChinesePattern : _pattern];
  }

  @override
  Future<RecentSignalModel?> respondToPattern({
    required LibraryPatternModel pattern,
    required String status,
    String? userText,
    bool addToTimeline = false,
  }) async {
    responses.add({
      'patternId': pattern.id,
      'status': status,
      'userText': userText,
      'addToTimeline': addToTimeline,
    });
    if (!addToTimeline || status == 'inaccurate') return null;
    return RecentSignalModel(
      id: 'library_test',
      signalCardId: 'library_test',
      sourceType: 'library_saved',
      content: userText ?? pattern.abstractPattern,
      privacyLevel: 'private',
      userConfirmation: status,
      rawPayloadJson: pattern.toPayloadJson(),
    );
  }
}

final _pattern = LibraryPatternModel(
  id: 'over_scheduled_weeks',
  title: 'Over-scheduled weeks',
  abstractPattern:
      'Some people encounter a similar structure when the week has many fixed commitments and very little space between them.',
  commonScenes: const ['work', 'planning'],
  commonFrictions: const ['schedule density'],
  energyLoadHint: 'high-drain',
  possiblePositiveSignal: 'a small pocket of open time',
  language: 'en',
  createdAt: DateTime.utc(2026, 5, 29),
  updatedAt: DateTime.utc(2026, 5, 29),
);

final _simplifiedChinesePattern = LibraryPatternModel(
  id: 'over_scheduled_weeks_zh_hans',
  title: '安排过密的一周',
  abstractPattern: '有些时候，一周里固定安排很多，中间却几乎没有可以缓一缓的空隙。',
  commonScenes: const ['工作', '安排'],
  commonFrictions: const ['日程密度'],
  energyLoadHint: 'high-drain',
  possiblePositiveSignal: '一小段可自由安排的时间',
  language: 'zh-Hans',
  createdAt: DateTime.utc(2026, 5, 29),
  updatedAt: DateTime.utc(2026, 5, 29),
);

final _recoveryPattern = LibraryPatternModel(
  id: 'recovery_debt',
  title: 'Recovery debt',
  abstractPattern:
      'Some people notice rest starts feeling like something to catch up on after several demanding days.',
  commonScenes: const ['body', 'rest'],
  commonFrictions: const ['recovery debt'],
  energyLoadHint: 'recovery',
  possiblePositiveSignal: 'sleep recovery',
  language: 'en',
  createdAt: DateTime.utc(2026, 5, 29),
  updatedAt: DateTime.utc(2026, 5, 29),
);

final _relationshipPattern = LibraryPatternModel(
  id: 'unclear_expectation_relationship_friction',
  title: 'Unclear expectations',
  abstractPattern:
      'Sometimes the tiring part is not the relationship itself, but the unclear expectation around it.',
  commonScenes: const ['relationships', 'communication'],
  commonFrictions: const ['boundary', 'expectations'],
  energyLoadHint: 'mixed',
  possiblePositiveSignal: 'clear connection',
  language: 'en',
  createdAt: DateTime.utc(2026, 5, 29),
  updatedAt: DateTime.utc(2026, 5, 29),
);
