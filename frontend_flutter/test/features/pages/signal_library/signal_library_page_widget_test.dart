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
import 'package:ai_opportunity_radar/shared/widgets/aurora_ui.dart';

void main() {
  testWidgets('shows privacy-safe official abstract patterns', (tester) async {
    await tester.pumpWidget(_buildWidget());
    await tester.pump();

    expect(find.text('Signal Library'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('signal-library-signal-pattern')),
      findsOneWidget,
    );
    expect(find.byType(AuroraHeroEmblem), findsNothing);
    expect(find.text('Search a signal...'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('emotional stability'), findsOneWidget);
    expect(find.text('self boundary'), findsOneWidget);
    expect(find.textContaining('fixed commitments'), findsOneWidget);
    expect(find.text('Accurate'), findsOneWidget);
    expect(find.text('Somewhat'), findsOneWidget);
    expect(find.text('Not accurate'), findsOneWidget);
    final illustration = find.byKey(
      const ValueKey('library-pattern-asset-over_scheduled_weeks'),
    );
    expect(illustration, findsOneWidget);
    final image = tester.widget<Image>(illustration);
    final resized = image.image as ResizeImage;
    expect(
      (resized.imageProvider as AssetImage).assetName,
      'assets/weekly/weekly-pattern-schedule-driven-mood.png',
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Over-scheduled weeks',
      ),
      findsOneWidget,
    );
    expect(find.text('Does this match me?'), findsNothing);
    expect(find.text('Save'), findsNothing);
    expect(find.text('Make it mine'), findsNothing);
    expect(find.textContaining('observation'), findsNothing);
    expect(find.textContaining('you are this kind of person'), findsNothing);
  });

  testWidgets(
      'accurate opens editable confirmation and only save creates SignalCard',
      (tester) async {
    final repository = _FakeSignalLibraryRepository();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_buildWidget(repository: repository));
    await tester.pump();

    final accurate = find.byKey(
      const ValueKey('library-signal-accurate-over_scheduled_weeks'),
    );
    await tester.ensureVisible(accurate);
    expect(find.text('Try today'), findsNothing);
    expect(find.text('Save'), findsNothing);
    expect(find.textContaining('observation'), findsNothing);

    await tester.tap(accurate);
    await tester.pumpAndSettle();

    expect(repository.responses, isEmpty);
    expect(
      find.byKey(
        const ValueKey(
          'library-pattern-over_scheduled_weeks-timeline-input',
        ),
      ),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(
        const ValueKey(
          'library-pattern-over_scheduled_weeks-timeline-input',
        ),
      ),
      'My week has too many fixed commitments and no buffer.',
    );
    await tester.tap(
      find.byKey(
        const ValueKey(
          'library-pattern-over_scheduled_weeks-add-timeline',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.responses, hasLength(1));
    expect(repository.responses.single['status'], 'accurate');
    expect(
      repository.responses.single['userText'],
      'My week has too many fixed commitments and no buffer.',
    );
    expect(repository.responses.single['addToTimeline'], isTrue);
    expect(find.text('Added to your timeline.'), findsOneWidget);
  });

  testWidgets('somewhat cancel and inaccurate are zero-write actions',
      (tester) async {
    final repository = _FakeSignalLibraryRepository();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_buildWidget(repository: repository));
    await tester.pump();

    final partial = find.byKey(
      const ValueKey('library-signal-partial-over_scheduled_weeks'),
    );
    await tester.ensureVisible(partial);
    await tester.tap(partial);
    await tester.pumpAndSettle();

    expect(repository.responses, isEmpty);
    await tester.tap(
      find.byKey(
        const ValueKey(
          'library-pattern-over_scheduled_weeks-dialog-cancel',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.responses, isEmpty);

    await tester.tap(partial);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey(
          'library-pattern-over_scheduled_weeks-add-timeline',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.responses, hasLength(1));
    expect(repository.responses.single['status'], 'partial');

    final inaccurate = find.byKey(
      const ValueKey('library-signal-inaccurate-over_scheduled_weeks'),
    );
    await tester.tap(inaccurate);
    await tester.pumpAndSettle();

    expect(repository.responses, hasLength(1));
    expect(
      find.byKey(const ValueKey('library-pattern-over_scheduled_weeks')),
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
    expect(find.text('看看像不像我'), findsNothing);
    expect(find.text('准'), findsOneWidget);
    expect(find.text('有一点像'), findsOneWidget);
    expect(find.text('不准'), findsOneWidget);
    expect(find.text('加入今日小行动'), findsNothing);
    expect(find.text('保存观察'), findsNothing);
    expect(find.text('暂时不做'), findsNothing);
    expect(find.textContaining('你就是这种人'), findsNothing);
    expect(find.textContaining('你有这个问题'), findsNothing);

    await tester.tap(find.byKey(
      const ValueKey(
        'library-signal-inaccurate-over_scheduled_weeks_zh_hans',
      ),
    ));
    await tester.pumpAndSettle();
    expect(repository.responses, isEmpty);
    expect(
      find.byKey(const ValueKey('library-signal-timeline-input')),
      findsNothing,
    );
    expect(
      find.byKey(
        const ValueKey('library-pattern-over_scheduled_weeks_zh_hans'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
      'not accurate replaces within the current result at most three times '
      'and never writes to the repository', (tester) async {
    final patterns = List<LibraryPatternModel>.generate(
      5,
      (index) => _replacementPattern(index + 1),
    );
    final repository = _FakeSignalLibraryRepository(patterns: patterns);
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_buildWidget(repository: repository));
    await tester.pump();

    final firstCard = find.byKey(
      const ValueKey('library-pattern-replacement-pattern-1'),
    );
    final firstSlotTop = tester.getTopLeft(firstCard).dy;

    for (var index = 1; index <= 3; index += 1) {
      final currentId = 'replacement-pattern-$index';
      final nextId = 'replacement-pattern-${index + 1}';

      await tester.tap(
        find.byKey(ValueKey('library-signal-inaccurate-$currentId')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(ValueKey('library-pattern-$currentId')),
        findsNothing,
        reason: 'successful replacement $index must remove the current card',
      );
      expect(
        find.byKey(ValueKey('library-pattern-$nextId')),
        findsOneWidget,
        reason: 'the next result must fill the vacated slot',
      );
      expect(
        tester
            .getTopLeft(
              find.byKey(ValueKey('library-pattern-$nextId')),
            )
            .dy,
        closeTo(firstSlotTop, 1),
      );
      expect(repository.responses, isEmpty);
    }

    final fourthCard = find.byKey(
      const ValueKey('library-pattern-replacement-pattern-4'),
    );
    final fourthTopBefore = tester.getTopLeft(fourthCard).dy;
    await tester.tap(
      find.byKey(
        const ValueKey('library-signal-inaccurate-replacement-pattern-4'),
      ),
    );
    await tester.pumpAndSettle();

    expect(fourthCard, findsOneWidget);
    expect(tester.getTopLeft(fourthCard).dy, closeTo(fourthTopBefore, 1));
    expect(
      find.byKey(const ValueKey('library-pattern-replacement-pattern-5')),
      findsOneWidget,
    );
    expect(repository.responses, isEmpty);
  });

  testWidgets(
      'a single matching result stays visible and does not consume replacement '
      'quota', (tester) async {
    final patterns = List<LibraryPatternModel>.generate(
      4,
      (index) => _replacementPattern(
        index + 1,
        abstractPattern: index == 0
            ? 'Only isolated-match appears in this search.'
            : 'Shared replacement result ${index + 1}.',
      ),
    );
    final repository = _FakeSignalLibraryRepository(patterns: patterns);
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_buildWidget(repository: repository));
    await tester.pump();

    final searchField = find.byType(TextField);
    await tester.enterText(searchField, 'isolated-match');
    await tester.pump();
    expect(
      find.byKey(const ValueKey('library-pattern-replacement-pattern-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('library-pattern-replacement-pattern-2')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(
        const ValueKey('library-signal-inaccurate-replacement-pattern-1'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('library-pattern-replacement-pattern-1')),
      findsOneWidget,
      reason: 'no replacement means the current result must remain',
    );
    expect(repository.responses, isEmpty);

    await tester.enterText(searchField, '');
    await tester.pump();

    for (var index = 1; index <= 3; index += 1) {
      final id = 'replacement-pattern-$index';
      await tester.tap(
        find.byKey(ValueKey('library-signal-inaccurate-$id')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('library-pattern-$id')),
        findsNothing,
        reason:
            'the failed isolated attempt must not consume success $index of 3',
      );
    }

    expect(
      find.byKey(const ValueKey('library-pattern-replacement-pattern-4')),
      findsOneWidget,
    );
    expect(repository.responses, isEmpty);
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

    await tester.ensureVisible(
        find.byKey(const ValueKey('library-category-food_sleep')));
    await tester.tap(find.byKey(const ValueKey('library-category-food_sleep')));
    await tester.pump();

    expect(find.textContaining('rest starts feeling'), findsOneWidget);
    expect(find.textContaining('fixed commitments'), findsNothing);
    expect(find.textContaining('relationship itself'), findsNothing);
    expect(
        find.textContaining('personal time keeps disappearing'), findsNothing);

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
    expect(find.textContaining('relationship itself'), findsNothing);
    expect(
        find.textContaining('personal time keeps disappearing'), findsNothing);

    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(-520, 0),
    );
    await tester.pump();
    await tester.ensureVisible(
        find.byKey(const ValueKey('library-category-relationship_connection')));
    await tester.tap(
        find.byKey(const ValueKey('library-category-relationship_connection')));
    await tester.pump();

    expect(find.textContaining('relationship itself'), findsOneWidget);
    expect(find.textContaining('fixed commitments'), findsNothing);
    expect(find.textContaining('rest starts feeling'), findsNothing);
    expect(
        find.textContaining('personal time keeps disappearing'), findsNothing);

    await tester.ensureVisible(
        find.byKey(const ValueKey('library-category-self_boundary')));
    await tester
        .tap(find.byKey(const ValueKey('library-category-self_boundary')));
    await tester.pump();

    expect(find.textContaining('personal time keeps disappearing'),
        findsOneWidget);
    expect(find.textContaining('relationship itself'), findsNothing);
    expect(find.textContaining('fixed commitments'), findsNothing);
  });

  testWidgets('all nine category chips use the explicit card tag',
      (tester) async {
    final repository = _FakeSignalLibraryRepository(includeCategorySet: true);
    await tester.binding.setSurfaceSize(const Size(2400, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_buildWidget(repository: repository));
    await tester.pump();

    const expectedPatternByCategory = {
      'emotional_stability': 'emotional-capacity',
      'relationship_connection': 'unclear_expectation_relationship_friction',
      'meaning_value': 'meaning-at-work',
      'self_boundary': 'personal_time_boundary',
      'growth_plan': 'over_scheduled_weeks',
      'creative_expression': 'creative-input',
      'food_sleep': 'recovery_debt',
      'living_environment': 'living-clutter',
      'interests_hobbies': 'hobby-vitality',
    };

    for (final entry in expectedPatternByCategory.entries) {
      await tester.ensureVisible(
        find.byKey(ValueKey('library-category-${entry.key}')),
      );
      await tester.tap(
        find.byKey(ValueKey('library-category-${entry.key}')),
      );
      await tester.pump();

      for (final candidate in expectedPatternByCategory.entries) {
        expect(
          find.byKey(ValueKey('library-pattern-${candidate.value}')),
          candidate.key == entry.key ? findsOneWidget : findsNothing,
          reason: '${entry.key} should only show ${entry.value}',
        );
      }
    }
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
  _FakeSignalLibraryRepository({
    this.includeCategorySet = false,
    this.patterns,
  }) : super(LocalDatabase());

  final bool includeCategorySet;
  final List<LibraryPatternModel>? patterns;

  String? lastLanguage;
  final List<String> requestedLanguages = [];
  final List<Map<String, Object?>> responses = [];

  @override
  Future<List<LibraryPatternModel>> listCuratedPatterns({
    String language = 'en',
  }) async {
    lastLanguage = language;
    requestedLanguages.add(language);
    if (patterns != null && language == 'en') {
      return patterns!;
    }
    if (includeCategorySet && language == 'en') {
      return [
        _emotionalPattern,
        _pattern,
        _recoveryPattern,
        _relationshipPattern,
        _meaningPattern,
        _boundaryPattern,
        _creativePattern,
        _livingPattern,
        _interestPattern,
      ];
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
  focusDomainId: 'growth_plan',
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

LibraryPatternModel _replacementPattern(
  int number, {
  String? abstractPattern,
}) {
  return LibraryPatternModel(
    id: 'replacement-pattern-$number',
    focusDomainId: 'growth_plan',
    title: 'Replacement pattern $number',
    abstractPattern: abstractPattern ?? 'Shared replacement result $number.',
    commonScenes: const ['planning'],
    commonFrictions: const ['schedule density'],
    energyLoadHint: 'steady',
    possiblePositiveSignal: 'a little more room',
    language: 'en',
    createdAt: DateTime.utc(2026, 7, 27),
    updatedAt: DateTime.utc(2026, 7, 27),
  );
}

final _simplifiedChinesePattern = LibraryPatternModel(
  id: 'over_scheduled_weeks_zh_hans',
  focusDomainId: 'growth_plan',
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
  focusDomainId: 'food_sleep',
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
  focusDomainId: 'relationship_connection',
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

final _boundaryPattern = LibraryPatternModel(
  id: 'personal_time_boundary',
  focusDomainId: 'self_boundary',
  title: 'Personal time boundary',
  abstractPattern:
      'Some people notice personal time keeps disappearing when every open space gets filled by requests.',
  commonScenes: const ['personal time'],
  commonFrictions: const ['boundary'],
  energyLoadHint: 'mixed',
  possiblePositiveSignal: 'one protected hour',
  language: 'en',
  createdAt: DateTime.utc(2026, 5, 29),
  updatedAt: DateTime.utc(2026, 5, 29),
);

final _emotionalPattern = LibraryPatternModel(
  id: 'emotional-capacity',
  focusDomainId: 'emotional_stability',
  title: 'Emotional capacity',
  abstractPattern:
      'Some people notice small changes feel harder when emotional capacity is low.',
  commonScenes: const ['emotion'],
  commonFrictions: const ['low capacity'],
  energyLoadHint: 'high-drain',
  possiblePositiveSignal: 'a steadier moment',
  language: 'en',
  createdAt: DateTime.utc(2026, 5, 29),
  updatedAt: DateTime.utc(2026, 5, 29),
);

final _meaningPattern = LibraryPatternModel(
  id: 'meaning-at-work',
  focusDomainId: 'meaning_value',
  title: 'Meaning in effort',
  abstractPattern:
      'Some people feel more motivated when their effort connects to something important.',
  commonScenes: const ['meaning'],
  commonFrictions: const ['unclear value'],
  energyLoadHint: 'mixed',
  possiblePositiveSignal: 'clear meaning',
  language: 'en',
  createdAt: DateTime.utc(2026, 5, 29),
  updatedAt: DateTime.utc(2026, 5, 29),
);

final _creativePattern = LibraryPatternModel(
  id: 'creative-input',
  focusDomainId: 'creative_expression',
  title: 'Input without expression',
  abstractPattern:
      'Some people lose touch with their own voice after taking in a lot without expressing anything.',
  commonScenes: const ['creative expression'],
  commonFrictions: const ['too much input'],
  energyLoadHint: 'high-input',
  possiblePositiveSignal: 'a small expression',
  language: 'en',
  createdAt: DateTime.utc(2026, 5, 29),
  updatedAt: DateTime.utc(2026, 5, 29),
);

final _livingPattern = LibraryPatternModel(
  id: 'living-clutter',
  focusDomainId: 'living_environment',
  title: 'Clutter and attention',
  abstractPattern:
      'Some people feel unfinished tasks remain open when their room is cluttered.',
  commonScenes: const ['living environment'],
  commonFrictions: const ['clutter'],
  energyLoadHint: 'high-friction',
  possiblePositiveSignal: 'a clear surface',
  language: 'en',
  createdAt: DateTime.utc(2026, 5, 29),
  updatedAt: DateTime.utc(2026, 5, 29),
);

final _interestPattern = LibraryPatternModel(
  id: 'hobby-vitality',
  focusDomainId: 'interests_hobbies',
  title: 'Vitality from interests',
  abstractPattern:
      'Some people feel more alive after making room for an interest or hobby.',
  commonScenes: const ['interests'],
  commonFrictions: const ['joy comes last'],
  energyLoadHint: 'recovery',
  possiblePositiveSignal: 'more vitality',
  language: 'en',
  createdAt: DateTime.utc(2026, 5, 29),
  updatedAt: DateTime.utc(2026, 5, 29),
);
