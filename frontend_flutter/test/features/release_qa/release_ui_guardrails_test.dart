import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:ai_opportunity_radar/app/app_router.dart';
import 'package:ai_opportunity_radar/core/api/repositories/memory_repository.dart';
import 'package:ai_opportunity_radar/core/api/repositories/signal_library_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/models/energy_budget_models.dart';
import 'package:ai_opportunity_radar/core/models/memory_models.dart';
import 'package:ai_opportunity_radar/core/models/signal_library_models.dart';
import 'package:ai_opportunity_radar/core/models/today_models.dart';
import 'package:ai_opportunity_radar/core/models/weekly_models.dart';
import 'package:ai_opportunity_radar/features/pages/me/advanced_signal_settings_page.dart';
import 'package:ai_opportunity_radar/features/pages/me/me_page.dart';
import 'package:ai_opportunity_radar/features/pages/me/me_view_model.dart';
import 'package:ai_opportunity_radar/features/pages/experiment/experiment_page.dart';
import 'package:ai_opportunity_radar/features/pages/memory/memory_page.dart';
import 'package:ai_opportunity_radar/features/pages/memory/memory_view_model.dart';
import 'package:ai_opportunity_radar/features/pages/signal_library/signal_library_page.dart';
import 'package:ai_opportunity_radar/features/pages/signal_library/signal_library_view_model.dart';
import 'package:ai_opportunity_radar/features/pages/today/today_page.dart';
import 'package:ai_opportunity_radar/features/pages/today/today_view_model.dart';
import 'package:ai_opportunity_radar/features/pages/weekly/weekly_page.dart';
import 'package:ai_opportunity_radar/features/pages/weekly/weekly_view_model.dart';
import 'package:ai_opportunity_radar/features/shell/home_shell_page.dart';

import '../../helpers/widget_test_helpers.dart';

final List<FlutterErrorDetails> _flutterErrors = [];
FlutterExceptionHandler? _previousFlutterErrorHandler;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const compactPhone = Size(320, 640);
  const regularPhone = Size(390, 844);
  const largePhone = Size(430, 932);
  const tablet = Size(768, 1024);

  setUp(() {
    _flutterErrors.clear();
    _previousFlutterErrorHandler ??= FlutterError.onError;
    FlutterError.onError = (details) {
      _flutterErrors.add(details);
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('signalpath/external_energy'),
      (call) async {
        if (call.method == 'calendarPermissionStatus' ||
            call.method == 'healthPermissionStatus') {
          return 'not_requested';
        }
        return null;
      },
    );
  });

  tearDown(() {
    FlutterError.onError = _previousFlutterErrorHandler;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('signalpath/external_energy'),
      null,
    );
  });

  for (final viewport in [compactPhone, regularPhone, largePhone, tablet]) {
    testWidgets('release UI smoke matrix renders primary pages at $viewport',
        (tester) async {
      await _setViewport(tester, viewport);
      await _pumpToday(tester);
      _expectNoRenderFailure(tester);
      _expectInViewport(tester, find.text('How is today going?').first);
      _expectFullyInViewport(
        tester,
        find.byKey(const ValueKey('today-status-action')),
      );
      _expectFullyInViewport(
        tester,
        find.byKey(const ValueKey('today-schedule-action')),
      );
      expect(
        find.byKey(const ValueKey('today-ai-judgement-action')),
        findsNothing,
      );
      _expectFullyInViewport(tester, find.text('Voice').first);
      _expectFullyInViewport(tester, find.text('Library').first);
      expect(find.byKey(const ValueKey('today-sync-action')), findsNothing);
      expect(find.text('View trend'), findsNothing);
      // Today groups adopted actions and experiments into one compact
      // "Today's attempts" surface with a shared entry point.
      await tester.scrollUntilVisible(
        find.text('View all'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(find.text('View all'), findsOneWidget);

      await _pumpWeekly(tester);
      _expectNoRenderFailure(tester);
      _expectInViewport(tester, find.text('Weekly Review').first);
      await tester.scrollUntilVisible(
        find.text('Behavior pattern'),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      _expectInViewport(tester, find.text('Behavior pattern').first);

      await _pumpExperiment(tester);
      _expectNoRenderFailure(tester);
      _expectInViewport(tester, find.text('Life Experiment').first);

      await _pumpJourney(tester);
      _expectNoRenderFailure(tester);
      _expectInViewport(tester, find.text('Journey').first);

      await _pumpLibrary(tester);
      _expectNoRenderFailure(tester);
      _expectInViewport(tester, find.text('Signal Library').first);
      await tester.ensureVisible(
          find.byKey(const ValueKey('library-category-food_sleep')));
      await tester
          .tap(find.byKey(const ValueKey('library-category-food_sleep')));
      await tester.pump();
      expect(find.textContaining('Rest may start'), findsOneWidget);
      expect(find.textContaining('fixed commitments'), findsNothing);
    });
  }

  for (final localeCase in _localeCases) {
    testWidgets('critical pages support ${localeCase.name} at 1.3 text scale',
        (tester) async {
      await _setViewport(tester, regularPhone);

      await _pumpToday(
        tester,
        locale: localeCase.locale,
        textScale: 1.3,
      );
      _expectNoRenderFailure(tester);
      _expectInViewport(tester, find.text(localeCase.todayTitle).first);

      await _pumpWeekly(
        tester,
        locale: localeCase.locale,
        textScale: 1.3,
      );
      _expectNoRenderFailure(tester);
      _expectInViewport(tester, find.text(localeCase.weeklyTitle).first);

      await _pumpExperiment(
        tester,
        locale: localeCase.locale,
        textScale: 1.3,
      );
      _expectNoRenderFailure(tester);
      _expectInViewport(tester, find.text(localeCase.experimentTitle).first);

      await _pumpJourney(
        tester,
        locale: localeCase.locale,
        textScale: 1.3,
      );
      _expectNoRenderFailure(tester);
      _expectInViewport(tester, find.text(localeCase.journeyTitle).first);

      await _pumpMe(
        tester,
        locale: localeCase.locale,
        textScale: 1.3,
      );
      _expectNoRenderFailure(tester);
      _expectInViewport(tester, find.text(localeCase.meTitle).first);

      await _pumpLibrary(
        tester,
        locale: localeCase.locale,
        textScale: 1.3,
      );
      _expectNoRenderFailure(tester);
      _expectInViewport(tester, find.text(localeCase.libraryTitle).first);
    });
  }

  testWidgets('bottom navigation keeps all labels tappable on compact phones',
      (tester) async {
    await _setViewport(tester, compactPhone);
    final semantics = tester.ensureSemantics();

    final router = GoRouter(
      initialLocation: AppRoutes.today,
      routes: [
        ShellRoute(
          builder: (_, __, child) => HomeShellPage(child: child),
          routes: [
            _route(AppRoutes.today, 'today route'),
            _route(AppRoutes.weekly, 'weekly route'),
            _route(AppRoutes.experiment, 'experiment route'),
            _route(AppRoutes.memory, 'journey route'),
            _route(AppRoutes.signalLibrary, 'library route'),
            _route(AppRoutes.me, 'me route'),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    for (final label in ['Today', 'Weekly', 'Experiment', 'Journey', 'Me']) {
      final finder = find.text(label);
      expect(finder, findsOneWidget);
      _expectInViewport(tester, finder);
      _expectMinimumTapTarget(
        tester,
        find.ancestor(of: finder, matching: find.byType(InkWell)).first,
      );
      await tester.tap(finder);
      await tester.pumpAndSettle();
      _expectNoRenderFailure(tester);
      expect(find.text(label), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel(label)),
        matchesSemantics(
          label: label,
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
    }
    semantics.dispose();
  });

  testWidgets('quick record controls meet touch and VoiceOver contracts',
      (tester) async {
    await _setViewport(tester, compactPhone);
    final semantics = tester.ensureSemantics();

    await _pumpToday(tester);
    _expectNoRenderFailure(tester);

    const controls = <(String, ValueKey<String>)>[
      ('Text', ValueKey('today-text-action')),
      ('Voice', ValueKey('today-voice-action')),
      ('State', ValueKey('today-status-action')),
      ('Plan', ValueKey('today-schedule-action')),
      ('Library', ValueKey('today-signal-library-action')),
      ('Save signal', ValueKey('today-submit-text-action')),
    ];
    for (final control in controls) {
      _expectMinimumTapTarget(tester, find.byKey(control.$2));
      expect(
        tester.getSemantics(find.bySemanticsLabel(control.$1)),
        matchesSemantics(
          label: control.$1,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
    }
    semantics.dispose();
  });

  testWidgets('secondary pages keep back controls inside the safe area',
      (tester) async {
    await _setViewport(tester, regularPhone);

    await tester.pumpWidget(
      const MaterialApp(home: AdvancedSignalSettingsPage()),
    );
    await tester.pumpAndSettle();

    final backButton = find.byIcon(Icons.arrow_back_rounded);
    expect(backButton, findsOneWidget);
    _expectInViewport(tester, backButton);
    expect(tester.getRect(backButton).top, greaterThanOrEqualTo(0));
    _expectNoRenderFailure(tester);
  });
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _expectNoRenderFailure(WidgetTester tester) {
  if (_flutterErrors.isNotEmpty) {
    final details = _flutterErrors.removeAt(0);
    fail(details.toString());
  }
  final exception = tester.takeException();
  if (exception is FlutterError) {
    fail(exception.toStringDeep());
  }
  expect(exception, isNull);
}

void _expectInViewport(WidgetTester tester, Finder finder) {
  expect(finder, findsWidgets);
  final rect = tester.getRect(finder.first);
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  expect(rect.bottom, greaterThan(0));
  expect(rect.top, lessThan(size.height));
  expect(rect.right, greaterThan(0));
  expect(rect.left, lessThan(size.width));
}

void _expectFullyInViewport(WidgetTester tester, Finder finder) {
  expect(finder, findsWidgets);
  final rect = tester.getRect(finder.first);
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  expect(rect.left, greaterThanOrEqualTo(0));
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(rect.right, lessThanOrEqualTo(size.width));
  expect(rect.bottom, lessThanOrEqualTo(size.height));
}

void _expectMinimumTapTarget(
  WidgetTester tester,
  Finder finder, {
  double minimum = 44,
}) {
  expect(finder, findsOneWidget);
  final size = tester.getSize(finder);
  expect(size.width, greaterThanOrEqualTo(minimum));
  expect(size.height, greaterThanOrEqualTo(minimum));
}

Widget _withTextScale(Widget child, double textScale) {
  return Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: child,
    ),
  );
}

Future<void> _pumpToday(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  double textScale = 1,
}) async {
  final repo = StubTodayRepository(
    fetchTodayResult: {
      'insight': TodayInsightModel(
        text: 'Today is easier to read when one small signal is saved first.',
      ),
      'pendingQuestion': null,
      'bestAction': DailyBestActionModel(
        text: 'Try leaving one small note before changing anything.',
      ),
      'recentSignals': [
        RecentSignalModel(
          id: 'guardrail-signal',
          signalCardId: 'guardrail-signal',
          content: 'I kept switching tasks and felt tired.',
          createdAt: DateTime(2026, 6, 18, 9, 10),
          acknowledgement:
              'The switching itself may be taking more space than it seems.',
          sceneTags: const ['work', 'switching'],
          energyLoad: 'draining',
          userConfirmation: 'unconfirmed',
          isLocalDraft: true,
          syncFailed: true,
        ),
      ],
    },
  );
  final meVm = await buildMeViewModel();

  await tester.pumpWidget(
    buildTestApp(
      locale: locale,
      child: _withTextScale(const TodayPage(), textScale),
      providers: [
        ChangeNotifierProvider<TodayViewModel>(
          create: (_) => TodayViewModel(repo),
        ),
        ChangeNotifierProvider<MeViewModel>.value(value: meVm),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpWeekly(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  double textScale = 1,
}) async {
  final repo = StubWeeklyRepository(weekly: _weeklyModel);
  final energyRepo = StubEnergyBudgetRepository(budget: _energyBudget);
  final meVm = await buildMeViewModel(repeatArea: 'work_tasks');

  await tester.pumpWidget(
    buildTestApp(
      locale: locale,
      child: _withTextScale(const WeeklyPage(), textScale),
      providers: [
        ChangeNotifierProvider<WeeklyViewModel>(
          create: (_) => WeeklyViewModel(
            repo,
            energyBudgetRepository: energyRepo,
          ),
        ),
        ChangeNotifierProvider<MeViewModel>.value(value: meVm),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpExperiment(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  double textScale = 1,
}) async {
  final repo = StubWeeklyRepository(weekly: _weeklyModel);

  await tester.pumpWidget(
    buildTestApp(
      locale: locale,
      child: _withTextScale(const ExperimentPage(), textScale),
      providers: [
        ChangeNotifierProvider<WeeklyViewModel>(
          create: (_) => WeeklyViewModel(repo),
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpJourney(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  double textScale = 1,
}) async {
  final repo = StubMemoryRepository(
    result: MemoryFetchResult(
      isFirstDayGate: false,
      summary: MemorySummaryModel(
        patterns: const [
          JourneySignalItemModel(
            name: 'Switching fatigue',
            summary: 'This pattern has appeared more than once.',
            signalLevel: 'repeated_pattern',
          ),
        ],
        frictions: const [
          JourneySignalItemModel(
            name: 'Too little recovery buffer',
            summary: 'Recovery feels easier when there is a small buffer.',
            signalLevel: 'stable_mode',
          ),
        ],
        desires: const [],
        experiments: const [
          JourneySignalItemModel(
            name: 'Twelve-minute no-input recovery',
            summary: 'The experiment is starting to show a useful shape.',
            signalLevel: 'weak_signal',
          ),
        ],
      ),
    ),
  );
  final meVm = await buildMeViewModel(repeatArea: 'time_rhythm');

  await tester.pumpWidget(
    buildTestApp(
      locale: locale,
      child: _withTextScale(const MemoryPage(), textScale),
      providers: [
        ChangeNotifierProvider<MemoryViewModel>(
          create: (_) => MemoryViewModel(repo),
        ),
        ChangeNotifierProvider<MeViewModel>.value(value: meVm),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpMe(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  double textScale = 1,
}) async {
  final meVm = await buildMeViewModel(repeatArea: 'time_rhythm');

  await tester.pumpWidget(
    buildTestApp(
      locale: locale,
      child: _withTextScale(const MePage(), textScale),
      providers: [
        ChangeNotifierProvider<MeViewModel>.value(value: meVm),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpLibrary(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    buildTestApp(
      locale: locale,
      child: _withTextScale(const SignalLibraryPage(), textScale),
      providers: [
        ChangeNotifierProvider<SignalLibraryViewModel>(
          create: (_) => SignalLibraryViewModel(_GuardrailLibraryRepository()),
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

GoRoute _route(String path, String label) {
  return GoRoute(
    path: path,
    builder: (_, __) => Scaffold(body: Center(child: Text(label))),
  );
}

final _weeklyModel = WeeklyInsightModel(
  weekStart: '2026-06-15',
  weekEnd: '2026-06-21',
  status: 'ready',
  keyInsight: 'This week, switching load is easier to see than task volume.',
  patterns: const [
    {'name': 'High switching', 'summary': 'Many notes point to switching.'},
  ],
  frictions: const [
    {'name': 'Interruptions', 'summary': 'Interruptions show up repeatedly.'},
  ],
  bestAction: 'Leave a twelve-minute no-input buffer after dense switching.',
  opportunitySnapshot: const {
    '_weekly_inclusion': {
      'used_count': 3,
      'timeline_only_count': 1,
      'excluded_count': 0,
      'legacy_reference_count': 0,
    },
    '_life_experiment': {
      'id': 'guardrail-experiment',
      'local_user_id': 'test-user',
      'source_week_start': '2026-06-15',
      'source_week_end': '2026-06-21',
      'title': 'Twelve-minute buffer',
      'hypothesis': 'A short no-input buffer may reduce switching load.',
      'suggested_action':
          'Leave a twelve-minute no-input buffer after dense switching.',
      'linked_signal_card_ids': ['guardrail-signal'],
      'status': 'suggested',
    },
  },
  feedbackSubmitted: false,
);

const _energyBudget = EnergyBudgetModel(
  status: 'ready',
  mostDrainingSource: 'The strongest source is high switching load.',
  recoveryClue: 'A small recovery buffer appears helpful.',
  bufferLocation: 'The place that needs buffer is after dense switching.',
  switchingAdjustment: 'Leave a little room before the next context switch.',
  experimentConnection: 'This can connect to the current Life Experiment.',
  blocks: [
    EnergyBlockModel(
      type: 'high_switching',
      label: 'high-switching block',
      summary: 'Switching is the main load.',
      count: 3,
      evidenceLevel: 'confirmed',
    ),
  ],
);

class _GuardrailLibraryRepository extends SignalLibraryRepository {
  _GuardrailLibraryRepository() : super(LocalDatabase());

  @override
  Future<List<LibraryPatternModel>> listCuratedPatterns({
    String language = 'en',
  }) async {
    return [_workPattern, _recoveryPattern];
  }
}

final _workPattern = LibraryPatternModel(
  id: 'over_scheduled_weeks',
  title: 'Over-scheduled weeks',
  abstractPattern: 'A week with fixed commitments and little buffer.',
  commonScenes: const ['work', 'planning'],
  commonFrictions: const ['schedule density'],
  energyLoadHint: 'high-drain',
  possiblePositiveSignal: 'open time',
  language: 'en',
  createdAt: DateTime.utc(2026, 6, 18),
  updatedAt: DateTime.utc(2026, 6, 18),
);

final _recoveryPattern = LibraryPatternModel(
  id: 'recovery_debt',
  title: 'Recovery debt',
  abstractPattern: 'Rest may start to feel like something to catch up on.',
  commonScenes: const ['body', 'rest'],
  commonFrictions: const ['recovery debt'],
  energyLoadHint: 'recovery',
  possiblePositiveSignal: 'sleep recovery',
  language: 'en',
  createdAt: DateTime.utc(2026, 6, 18),
  updatedAt: DateTime.utc(2026, 6, 18),
);

class _LocaleCase {
  final String name;
  final Locale locale;
  final String todayTitle;
  final String weeklyTitle;
  final String experimentTitle;
  final String journeyTitle;
  final String meTitle;
  final String libraryTitle;

  const _LocaleCase({
    required this.name,
    required this.locale,
    required this.todayTitle,
    required this.weeklyTitle,
    required this.experimentTitle,
    required this.journeyTitle,
    required this.meTitle,
    required this.libraryTitle,
  });
}

const _localeCases = <_LocaleCase>[
  _LocaleCase(
    name: 'English',
    locale: Locale('en'),
    todayTitle: 'How is today going?',
    weeklyTitle: 'Weekly Review',
    experimentTitle: 'Life Experiment',
    journeyTitle: 'Journey',
    meTitle: 'Me',
    libraryTitle: 'Signal Library',
  ),
  _LocaleCase(
    name: 'Simplified Chinese',
    locale: Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    todayTitle: '今天过得怎么样？',
    weeklyTitle: '每周复盘',
    experimentTitle: '生活小实验',
    journeyTitle: '旅程',
    meTitle: '我的',
    libraryTitle: '信号库',
  ),
  _LocaleCase(
    name: 'Traditional Chinese',
    locale: Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    todayTitle: '今天過得怎麼樣？',
    weeklyTitle: '每週復盤',
    experimentTitle: '小實驗',
    journeyTitle: '旅程',
    meTitle: '我的',
    libraryTitle: '信號庫',
  ),
  _LocaleCase(
    name: 'Japanese',
    locale: Locale('ja'),
    todayTitle: '今日はどんな一日ですか？',
    weeklyTitle: '今週の振り返り',
    experimentTitle: '小さな実験',
    journeyTitle: '旅程',
    meTitle: '私',
    libraryTitle: 'シグナルライブラリ',
  ),
];
