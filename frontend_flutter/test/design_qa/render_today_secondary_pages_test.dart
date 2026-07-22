import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ai_opportunity_radar/core/api/repositories/signal_library_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/models/signal_library_models.dart';
import 'package:ai_opportunity_radar/core/models/today_models.dart';
import 'package:ai_opportunity_radar/features/pages/signal_library/signal_library_page.dart';
import 'package:ai_opportunity_radar/features/pages/signal_library/signal_library_view_model.dart';
import 'package:ai_opportunity_radar/features/pages/today/today_diary_page.dart';
import 'package:ai_opportunity_radar/features/pages/today/today_view_model.dart';

import '../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final fontBytes =
        await File('/System/Library/Fonts/Hiragino Sans GB.ttc').readAsBytes();
    await (FontLoader(_designReviewFontFamily)
          ..addFont(Future.value(ByteData.sublistView(fontBytes))))
        .load();
    final iconBytes = await File(
      '/Users/yangyang/development/flutter/bin/cache/artifacts/material_fonts/'
      'MaterialIcons-Regular.otf',
    ).readAsBytes();
    await (FontLoader('MaterialIcons')
          ..addFont(Future.value(ByteData.sublistView(iconBytes))))
        .load();
  });

  testWidgets('renders the current Today diary timeline for design review',
      (tester) async {
    _configureViewport(tester);
    final now = DateTime.now();
    final localDate = _dateKey(now);
    final repository = StubTodayRepository(
      fetchTodayResult: {
        'insight': TodayInsightModel(text: '今天的 Signal 正在慢慢连成一页。'),
        'pendingQuestion': null,
        'bestAction': DailyBestActionModel(text: '先给切换留一点缓冲。'),
        'recentSignals': [
          RecentSignalModel(
            id: 'diary-status',
            signalCardId: 'diary-status',
            sourceType: 'one_tap',
            content: '现在状态比较平稳，精力还好。',
            createdAt: now.subtract(const Duration(minutes: 12)),
            localDate: localDate,
            acknowledgement: '我接住了，先把此刻的状态留在这里。',
            energyLoad: 'neutral',
            userConfirmation: 'confirmed',
          ),
          RecentSignalModel(
            id: 'diary-switching',
            signalCardId: 'diary-switching',
            sourceType: 'text',
            content: '上午连续切了三个任务，真正累的是不停重新进入状态。',
            createdAt: now.subtract(const Duration(minutes: 46)),
            localDate: localDate,
            acknowledgement: '这种来回切换确实很磨人，先把它留在这里。',
            sceneTags: const ['growth_plan'],
            energyLoad: 'draining',
            userConfirmation: 'confirmed',
          ),
          RecentSignalModel(
            id: 'diary-recovery',
            signalCardId: 'diary-recovery',
            sourceType: 'voice',
            content: '午后离开屏幕走了十分钟，回来时轻松了一点。',
            createdAt: now.subtract(const Duration(hours: 2)),
            localDate: localDate,
            acknowledgement: '这个轻松一点的瞬间，也值得被记住。',
            sceneTags: const ['food_sleep'],
            energyLoad: 'restoring',
            userConfirmation: 'confirmed',
          ),
          RecentSignalModel(
            id: 'diary-time-use',
            signalCardId: 'diary-time-use',
            sourceType: 'time_use',
            content: '09:30–10:30 · 成长计划 · 集中整理方案',
            createdAt: DateTime(now.year, now.month, now.day, 9, 30),
            localDate: localDate,
            sceneTags: const ['growth_plan'],
            rawPayloadJson: {
              'timeline_type': 'time_use',
              'focus_domain_id': 'growth_plan',
              'category': 'growth_plan',
              'start_at': DateTime(now.year, now.month, now.day, 9, 30)
                  .toIso8601String(),
              'end_at': DateTime(now.year, now.month, now.day, 10, 30)
                  .toIso8601String(),
              'duration_minutes': 60,
            },
          ),
        ],
      },
    );
    final captureKey = GlobalKey();

    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: _DesignReviewApp(
          child: ChangeNotifierProvider<TodayViewModel>(
            create: (_) => TodayViewModel(repository),
            child: const TodayDiaryPage(),
          ),
        ),
      ),
    );
    await _precacheTodayHero(tester, captureKey);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('today-diary-hero')), findsOneWidget);
    expect(find.text('上午连续切了三个任务，真正累的是不停重新进入状态。'), findsOneWidget);
    await _capture(
      tester,
      captureKey,
      'design_qa/today-diary-current-2026-07-17.png',
    );
  });

  testWidgets('renders the current Signal Library for design review',
      (tester) async {
    _configureViewport(tester);
    final repository = _DesignSignalLibraryRepository();
    final captureKey = GlobalKey();

    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: _DesignReviewApp(
          child: ChangeNotifierProvider<SignalLibraryViewModel>(
            create: (_) => SignalLibraryViewModel(repository),
            child: const SignalLibraryPage(),
          ),
        ),
      ),
    );
    await _precacheTodayHero(tester, captureKey);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('signal-library-signal-pattern')),
        findsOneWidget);
    expect(
      find.text('有些时候，一周里固定安排很多，中间却几乎没有可以缓一缓的空隙。'),
      findsOneWidget,
    );
    await _capture(
      tester,
      captureKey,
      'design_qa/signal-library-current-2026-07-17.png',
    );
  });
}

void _configureViewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _precacheTodayHero(
  WidgetTester tester,
  GlobalKey captureKey,
) async {
  await tester.pump();
  await tester.runAsync(
    () => precacheImage(
      const AssetImage('assets/hero_art/today-signal-points-v1.png'),
      captureKey.currentContext!,
    ),
  );
  await tester.pump();
}

Future<void> _capture(
  WidgetTester tester,
  GlobalKey captureKey,
  String path,
) async {
  await tester.runAsync(() async {
    final boundary =
        captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(path).writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
    image.dispose();
  });
}

String _dateKey(DateTime value) => '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

class _DesignReviewApp extends StatelessWidget {
  final Widget child;

  const _DesignReviewApp({required this.child});

  @override
  Widget build(BuildContext context) {
    const scheme = ColorScheme.light(
      primary: Color(0xFF7767F4),
      onPrimary: Colors.white,
      secondary: Color(0xFF5F95E8),
      tertiary: Color(0xFF62C594),
      surface: Color(0xFFFFFCFA),
      onSurface: Color(0xFF252B4A),
      outline: Color(0xFFCFCBD8),
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hans',
      ),
      supportedLocales: const [
        Locale('en'),
        Locale('ja'),
        Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
        Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      ],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        fontFamily: _designReviewFontFamily,
        scaffoldBackgroundColor: scheme.surface,
      ),
      home: child,
    );
  }
}

class _DesignSignalLibraryRepository extends SignalLibraryRepository {
  _DesignSignalLibraryRepository() : super(LocalDatabase());

  @override
  Future<List<LibraryPatternModel>> listCuratedPatterns({
    String language = 'en',
  }) async {
    return _patterns;
  }

  @override
  Future<RecentSignalModel?> respondToPattern({
    required LibraryPatternModel pattern,
    required String status,
    String? userText,
    bool addToTimeline = false,
  }) async {
    return null;
  }
}

final _patterns = [
  _pattern(
    id: 'over_scheduled_weeks_zh_hans',
    domain: 'growth_plan',
    title: '安排过密的一周',
    text: '有些时候，一周里固定安排很多，中间却几乎没有可以缓一缓的空隙。',
    scenes: const ['工作', '安排'],
    frictions: const ['日程密度'],
    energy: 'high-drain',
    positive: '一小段可自由安排的时间',
  ),
  _pattern(
    id: 'recovery_debt_zh_hans',
    domain: 'food_sleep',
    title: '恢复总被放到最后',
    text: '连续几天都在撑着的时候，休息很容易变成一件需要以后再补的事。',
    scenes: const ['身体', '休息'],
    frictions: const ['恢复不足'],
    energy: 'recovery',
    positive: '开始感到轻松的时刻',
  ),
  _pattern(
    id: 'personal_time_boundary_zh_hans',
    domain: 'self_boundary',
    title: '自己的时间不断消失',
    text: '每一段空白都被新的请求填满时，留给自己的时间会一点点消失。',
    scenes: const ['个人时间'],
    frictions: const ['边界'],
    energy: 'mixed',
    positive: '一段被保护的时间',
  ),
  _pattern(
    id: 'creative_input_zh_hans',
    domain: 'creative_expression',
    title: '输入很多却没有表达',
    text: '持续接收很多信息、却没有表达出口时，有时会离自己的声音越来越远。',
    scenes: const ['创造', '表达'],
    frictions: const ['输入过多'],
    energy: 'high-input',
    positive: '一次很小的表达',
  ),
];

LibraryPatternModel _pattern({
  required String id,
  required String domain,
  required String title,
  required String text,
  required List<String> scenes,
  required List<String> frictions,
  required String energy,
  required String positive,
}) {
  return LibraryPatternModel(
    id: id,
    focusDomainId: domain,
    title: title,
    abstractPattern: text,
    commonScenes: scenes,
    commonFrictions: frictions,
    energyLoadHint: energy,
    possiblePositiveSignal: positive,
    language: 'zh-Hans',
    createdAt: DateTime.utc(2026, 5, 29),
    updatedAt: DateTime.utc(2026, 5, 29),
  );
}

const _designReviewFontFamily = 'DesignReviewCJK';
