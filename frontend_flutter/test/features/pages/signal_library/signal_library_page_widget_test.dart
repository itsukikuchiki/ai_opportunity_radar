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

    expect(find.text('Shared life signals'), findsOneWidget);
    expect(
      find.text('Possible structure'),
      findsOneWidget,
    );
    expect(find.text('Observe'), findsOneWidget);
    expect(find.text('Small experiment'), findsOneWidget);
    expect(find.text('Me too'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.textContaining('you are this kind of person'), findsNothing);
  });

  testWidgets('saving a pattern uses private low-pressure confirmation',
      (tester) async {
    await tester.pumpWidget(_buildWidget());
    await tester.pump();

    final saveButton = find.text('Save');
    await tester.ensureVisible(saveButton);
    await tester.pump();
    await tester.tap(saveButton);
    await tester.pump();

    expect(
      find.text('Saved privately into your observations.'),
      findsOneWidget,
    );
    expect(find.text('Saved'), findsOneWidget);
    expect(find.textContaining('confirm you have this problem'), findsNothing);
  });

  testWidgets('Chinese copy saves into observation without labeling the user',
      (tester) async {
    final repository = _FakeSignalLibraryRepository();
    await tester.pumpWidget(
      _buildWidget(
        repository: repository,
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
      ),
    );
    await tester.pump();

    expect(repository.lastLanguage, 'zh-Hans');
    expect(find.text('保存'), findsOneWidget);
    expect(find.textContaining('你就是这种人'), findsNothing);
    expect(find.textContaining('你有这个问题'), findsNothing);
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
    expect(find.text('Over-scheduled weeks'), findsOneWidget);

    locale.value = const Locale.fromSubtags(
      languageCode: 'zh',
      scriptCode: 'Hans',
    );
    await tester.pump();
    await tester.pump();

    expect(repository.requestedLanguages, ['en', 'zh-Hans']);
    expect(find.text('安排过密的一周'), findsOneWidget);
    expect(find.text('Over-scheduled weeks'), findsNothing);
  });

  testWidgets(
      'category chips filter visible library cards instead of acting as static labels',
      (tester) async {
    final repository = _FakeSignalLibraryRepository(includeCategorySet: true);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_buildWidget(repository: repository));
    await tester.pump();

    expect(find.text('Over-scheduled weeks'), findsOneWidget);
    expect(find.text('Recovery debt'), findsOneWidget);
    expect(find.text('Unclear expectations'), findsOneWidget);

    await tester
        .ensureVisible(find.byKey(const ValueKey('library-category-recovery')));
    await tester.tap(find.byKey(const ValueKey('library-category-recovery')));
    await tester.pump();

    expect(find.text('Recovery debt'), findsOneWidget);
    expect(find.text('Over-scheduled weeks'), findsNothing);
    expect(find.text('Unclear expectations'), findsNothing);

    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(-520, 0),
    );
    await tester.pump();
    await tester
        .ensureVisible(find.byKey(const ValueKey('library-category-work')));
    await tester.tap(find.byKey(const ValueKey('library-category-work')));
    await tester.pump();

    expect(find.text('Over-scheduled weeks'), findsOneWidget);
    expect(find.text('Recovery debt'), findsNothing);
    expect(find.text('Unclear expectations'), findsNothing);

    await tester.ensureVisible(
        find.byKey(const ValueKey('library-category-relationships')));
    await tester
        .tap(find.byKey(const ValueKey('library-category-relationships')));
    await tester.pump();

    expect(find.text('Unclear expectations'), findsOneWidget);
    expect(find.text('Over-scheduled weeks'), findsNothing);
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
  Future<void> recordPrivateAction({
    required String patternId,
    required String action,
  }) async {}

  @override
  Future<RecentSignalModel> saveToMyObservation({
    required LibraryPatternModel pattern,
    String timezone = 'local',
  }) async {
    return RecentSignalModel(
      id: 'library_test',
      signalCardId: 'library_test',
      sourceType: 'library_saved',
      content: '',
      privacyLevel: 'private',
      userConfirmation: 'unconfirmed',
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
  gentleReflection:
      'This may be less about doing more and more about where the week has no soft edges.',
  suggestedSmallExperiment:
      'Try leaving one small buffer before or after the densest part of the week.',
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
  gentleReflection: '这也许不是需要做得更多，而是这一周哪里少了一点柔软的边界。',
  suggestedSmallExperiment: '可以试着在最密的一段前后，留一个很小的缓冲。',
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
  gentleReflection: 'Recovery may need a little more room this week.',
  suggestedSmallExperiment: 'Try setting one small stop time before bed.',
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
  gentleReflection: 'This can be observed without deciding anything yet.',
  suggestedSmallExperiment:
      'Try naming one small expectation before responding.',
  language: 'en',
  createdAt: DateTime.utc(2026, 5, 29),
  updatedAt: DateTime.utc(2026, 5, 29),
);
