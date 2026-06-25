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
import 'package:ai_opportunity_radar/features/pages/me/me_view_model.dart';
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
      _expectInViewport(tester, find.text('Signal input').first);
      expect(find.byKey(const ValueKey('today-sync-action')), findsNothing);
      expect(find.text('View trend'), findsNothing);
      expect(find.text('View all'), findsNothing);

      await _pumpWeekly(tester);
      _expectNoRenderFailure(tester);
      _expectInViewport(tester, find.text('Main drain chain').first);

      await _pumpJourney(tester);
      _expectNoRenderFailure(tester);
      _expectInViewport(tester, find.text('Long-term patterns').first);

      await _pumpLibrary(tester);
      _expectNoRenderFailure(tester);
      _expectInViewport(tester, find.text('Shared life signals').first);
      await tester.ensureVisible(
          find.byKey(const ValueKey('library-category-recovery')));
      await tester.tap(find.byKey(const ValueKey('library-category-recovery')));
      await tester.pump();
      expect(find.text('Recovery debt'), findsOneWidget);
      expect(find.text('Over-scheduled weeks'), findsNothing);
    });
  }

  testWidgets('bottom navigation keeps all labels tappable on compact phones',
      (tester) async {
    await _setViewport(tester, compactPhone);

    final router = GoRouter(
      initialLocation: AppRoutes.today,
      routes: [
        ShellRoute(
          builder: (_, __, child) => HomeShellPage(child: child),
          routes: [
            _route(AppRoutes.today, 'today route'),
            _route(AppRoutes.weekly, 'weekly route'),
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

    for (final label in ['Today', 'Weekly', 'Journey', 'Library', 'Me']) {
      final finder = find.text(label);
      expect(finder, findsOneWidget);
      _expectInViewport(tester, finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
      _expectNoRenderFailure(tester);
      expect(find.text(label), findsOneWidget);
    }
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

Future<void> _pumpToday(WidgetTester tester) async {
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
}

Future<void> _pumpWeekly(WidgetTester tester) async {
  final repo = StubWeeklyRepository(weekly: _weeklyModel);
  final energyRepo = StubEnergyBudgetRepository(budget: _energyBudget);
  final meVm = await buildMeViewModel(repeatArea: 'work_tasks');

  await tester.pumpWidget(
    buildTestApp(
      child: const WeeklyPage(),
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

Future<void> _pumpJourney(WidgetTester tester) async {
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
}

Future<void> _pumpLibrary(WidgetTester tester) async {
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => SignalLibraryViewModel(_GuardrailLibraryRepository()),
      child: const MaterialApp(home: SignalLibraryPage()),
    ),
  );
  await tester.pump();
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
  gentleReflection: 'This may be about missing soft edges.',
  suggestedSmallExperiment: 'Leave one small buffer this week.',
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
  gentleReflection: 'Recovery may need a little more room.',
  suggestedSmallExperiment: 'Set one small stop time before bed.',
  language: 'en',
  createdAt: DateTime.utc(2026, 6, 18),
  updatedAt: DateTime.utc(2026, 6, 18),
);
