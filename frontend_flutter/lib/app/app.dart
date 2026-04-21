import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'app_router.dart';
import '../core/di/app_dependencies.dart';
import '../core/state/app_bootstrap_state.dart';
import '../features/onboarding/onboarding_view_model.dart';
import '../features/pages/me/me_view_model.dart';
import '../features/pages/monthly/monthly_view_model.dart';
import '../features/pages/memory/memory_view_model.dart';
import '../features/pages/opportunities/opportunity_detail_view_model.dart';
import '../features/pages/today/today_view_model.dart';
import '../features/pages/weekly/weekly_view_model.dart';

class RadarApp extends StatefulWidget {
  final AppBootstrapState bootstrapState;

  const RadarApp({
    super.key,
    required this.bootstrapState,
  });

  @override
  State<RadarApp> createState() => _RadarAppState();
}

class _RadarAppState extends State<RadarApp> {
  late final GoRouter _router;

  AppDependencies? _dependencies;
  OnboardingViewModel? _onboardingViewModel;
  TodayViewModel? _todayViewModel;
  WeeklyViewModel? _weeklyViewModel;
  OpportunityDetailViewModel? _opportunityDetailViewModel;
  MemoryViewModel? _memoryViewModel;
  MonthlyViewModel? _monthlyViewModel;
  MeViewModel? _meViewModel;

  @override
  void initState() {
    super.initState();
    _router = createAppRouter(widget.bootstrapState);
  }

  void _ensureAppObjectsInitialized() {
    if (_dependencies != null) {
      return;
    }

    final dependencies = widget.bootstrapState.dependencies;

    _dependencies = dependencies;
    _onboardingViewModel = OnboardingViewModel(dependencies.apiClient);
    _todayViewModel = TodayViewModel(dependencies.todayRepository);
    _weeklyViewModel = WeeklyViewModel(dependencies.weeklyRepository);
    _opportunityDetailViewModel =
        OpportunityDetailViewModel(dependencies.opportunityRepository);
    _memoryViewModel = MemoryViewModel(dependencies.memoryRepository);
    _monthlyViewModel = MonthlyViewModel(dependencies.monthlyRepository);
    _meViewModel = MeViewModel();
  }

  @override
  void dispose() {
    _onboardingViewModel?.dispose();
    _todayViewModel?.dispose();
    _weeklyViewModel?.dispose();
    _opportunityDetailViewModel?.dispose();
    _memoryViewModel?.dispose();
    _monthlyViewModel?.dispose();
    _meViewModel?.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.bootstrapState,
      builder: (context, _) {
        final bootstrap = widget.bootstrapState;

        if (!bootstrap.initialized) {
          return _buildLoadingApp();
        }

        if (bootstrap.hasError) {
          return _buildErrorApp(bootstrap.initError);
        }

        _ensureAppObjectsInitialized();

        final dependencies = _dependencies!;
        final onboardingViewModel = _onboardingViewModel!;
        final todayViewModel = _todayViewModel!;
        final weeklyViewModel = _weeklyViewModel!;
        final opportunityDetailViewModel = _opportunityDetailViewModel!;
        final memoryViewModel = _memoryViewModel!;
        final monthlyViewModel = _monthlyViewModel!;
        final meViewModel = _meViewModel!;

        return MultiProvider(
          providers: [
            Provider<AppDependencies>.value(value: dependencies),
            ChangeNotifierProvider<AppBootstrapState>.value(value: bootstrap),
            ChangeNotifierProvider<OnboardingViewModel>.value(
              value: onboardingViewModel,
            ),
            ChangeNotifierProvider<TodayViewModel>.value(
              value: todayViewModel,
            ),
            ChangeNotifierProvider<WeeklyViewModel>.value(
              value: weeklyViewModel,
            ),
            ChangeNotifierProvider<OpportunityDetailViewModel>.value(
              value: opportunityDetailViewModel,
            ),
            ChangeNotifierProvider<MemoryViewModel>.value(
              value: memoryViewModel,
            ),
            ChangeNotifierProvider<MonthlyViewModel>.value(
              value: monthlyViewModel,
            ),
            ChangeNotifierProvider<MeViewModel>.value(
              value: meViewModel,
            ),
          ],
          child: _buildRouterApp(_router),
        );
      },
    );
  }

  Widget _buildLoadingApp() {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Signal Path：AI手帳',
      theme: _buildTheme(),
      home: const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }

  Widget _buildErrorApp(Object? error) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Signal Path：AI手帳',
      theme: _buildTheme(),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'App failed to initialize.\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRouterApp(GoRouter router) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Signal Path：AI手帳',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
        Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        Locale('ja'),
      ],
      localeResolutionCallback: (locale, supportedLocales) {
        if (locale == null) {
          return const Locale('en');
        }

        final languageCode = locale.languageCode.toLowerCase();
        final scriptCode = locale.scriptCode?.toLowerCase();
        final countryCode = locale.countryCode?.toUpperCase();

        if (languageCode == 'ja') {
          return const Locale('ja');
        }

        if (languageCode == 'zh') {
          final isTraditional = scriptCode == 'hant' ||
              countryCode == 'TW' ||
              countryCode == 'HK' ||
              countryCode == 'MO';

          return isTraditional
              ? const Locale.fromSubtags(
                  languageCode: 'zh',
                  scriptCode: 'Hant',
                )
              : const Locale.fromSubtags(
                  languageCode: 'zh',
                  scriptCode: 'Hans',
                );
        }

        return const Locale('en');
      },
      theme: _buildTheme(),
      routerConfig: router,
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      colorSchemeSeed: const Color(0xFF6B7A90),
      scaffoldBackgroundColor: const Color(0xFFF7F8FB),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF7F8FB),
        foregroundColor: Color(0xFF1F2430),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD9DEE7)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD9DEE7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFF6B7A90),
            width: 1.4,
          ),
        ),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: Color(0xFF1F2430),
        ),
        titleMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1F2430),
        ),
        titleSmall: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1F2430),
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          height: 1.6,
          color: Color(0xFF2F3441),
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.55,
          color: Color(0xFF4A5260),
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          height: 1.45,
          color: Color(0xFF6F7784),
        ),
      ),
    );
  }
}
