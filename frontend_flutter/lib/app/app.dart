import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'app_router.dart';
import '../core/di/app_dependencies.dart';
import '../core/purchases/purchase_controller.dart';
import '../core/state/app_bootstrap_state.dart';
import '../features/onboarding/onboarding_view_model.dart';
import '../features/pages/me/me_view_model.dart';
import '../features/pages/monthly/monthly_view_model.dart';
import '../features/pages/memory/memory_view_model.dart';
import '../features/pages/opportunities/opportunity_detail_view_model.dart';
import '../features/pages/self_review/self_review_view_model.dart';
import '../features/pages/signal_library/signal_library_view_model.dart';
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
  SelfReviewViewModel? _selfReviewViewModel;
  SignalLibraryViewModel? _signalLibraryViewModel;
  MeViewModel? _meViewModel;
  PurchaseController? _purchaseController;
  bool _trackedAppOpen = false;

  @override
  void initState() {
    super.initState();
    _router = createAppRouter(widget.bootstrapState);
  }

  void _ensureAppObjectsInitialized() {
    if (_dependencies != null) return;

    final dependencies = widget.bootstrapState.dependencies;
    _dependencies = dependencies;
    _onboardingViewModel = OnboardingViewModel(dependencies.apiClient);
    _todayViewModel = TodayViewModel(dependencies.todayRepository);
    _weeklyViewModel = WeeklyViewModel(
      dependencies.weeklyRepository,
      energyBudgetRepository: dependencies.energyBudgetRepository,
      analyticsRepository: dependencies.analyticsRepository,
    );
    _opportunityDetailViewModel =
        OpportunityDetailViewModel(dependencies.opportunityRepository);
    _memoryViewModel = MemoryViewModel(
      dependencies.memoryRepository,
      analyticsRepository: dependencies.analyticsRepository,
    );
    _monthlyViewModel = MonthlyViewModel(dependencies.monthlyRepository);
    _selfReviewViewModel =
        SelfReviewViewModel(dependencies.selfReviewRepository);
    _signalLibraryViewModel =
        SignalLibraryViewModel(dependencies.signalLibraryRepository);
    _meViewModel = MeViewModel();
    _purchaseController = PurchaseController(apiClient: dependencies.apiClient);
    if (!_trackedAppOpen) {
      _trackedAppOpen = true;
      unawaited(dependencies.analyticsRepository.track('app_open'));
    }
  }

  @override
  void dispose() {
    _onboardingViewModel?.dispose();
    _todayViewModel?.dispose();
    _weeklyViewModel?.dispose();
    _opportunityDetailViewModel?.dispose();
    _memoryViewModel?.dispose();
    _monthlyViewModel?.dispose();
    _selfReviewViewModel?.dispose();
    _signalLibraryViewModel?.dispose();
    _meViewModel?.dispose();
    _purchaseController?.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.bootstrapState,
      builder: (context, _) {
        final bootstrap = widget.bootstrapState;

        if (!bootstrap.initialized) return _buildLoadingApp();
        if (bootstrap.hasError) return _buildErrorApp(bootstrap.initError);

        _ensureAppObjectsInitialized();

        final dependencies = _dependencies!;
        return MultiProvider(
          providers: [
            Provider<AppDependencies>.value(value: dependencies),
            ChangeNotifierProvider<AppBootstrapState>.value(value: bootstrap),
            ChangeNotifierProvider<OnboardingViewModel>.value(
                value: _onboardingViewModel!),
            ChangeNotifierProvider<TodayViewModel>.value(
                value: _todayViewModel!),
            ChangeNotifierProvider<WeeklyViewModel>.value(
                value: _weeklyViewModel!),
            ChangeNotifierProvider<OpportunityDetailViewModel>.value(
                value: _opportunityDetailViewModel!),
            ChangeNotifierProvider<MemoryViewModel>.value(
                value: _memoryViewModel!),
            ChangeNotifierProvider<MonthlyViewModel>.value(
                value: _monthlyViewModel!),
            ChangeNotifierProvider<SelfReviewViewModel>.value(
                value: _selfReviewViewModel!),
            ChangeNotifierProvider<SignalLibraryViewModel>.value(
                value: _signalLibraryViewModel!),
            ChangeNotifierProvider<MeViewModel>.value(value: _meViewModel!),
            ChangeNotifierProvider<PurchaseController?>.value(
                value: _purchaseController!),
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
      home: const _BrandLaunchScreen(),
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
            child: Text('App failed to initialize.\n$error',
                textAlign: TextAlign.center),
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
        if (locale == null) return const Locale('en');
        final languageCode = locale.languageCode.toLowerCase();
        final scriptCode = locale.scriptCode?.toLowerCase();
        final countryCode = locale.countryCode?.toUpperCase();
        if (languageCode == 'ja') return const Locale('ja');
        if (languageCode == 'zh') {
          final isTraditional = scriptCode == 'hant' ||
              countryCode == 'TW' ||
              countryCode == 'HK' ||
              countryCode == 'MO';
          return isTraditional
              ? const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')
              : const Locale.fromSubtags(
                  languageCode: 'zh', scriptCode: 'Hans');
        }
        return const Locale('en');
      },
      theme: _buildTheme(),
      routerConfig: router,
    );
  }

  ThemeData _buildTheme() {
    const colorScheme = ColorScheme.light(
      primary: Color(0xFF2F5F85),
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFEAF2F8),
      onPrimaryContainer: Color(0xFF223044),
      secondary: Color(0xFF526DA8),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFEEF5FA),
      onSecondaryContainer: Color(0xFF223044),
      tertiary: Color(0xFF7EA48B),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFEEF7F0),
      onTertiaryContainer: Color(0xFF223044),
      surface: Color(0xFFF8FBFD),
      onSurface: Color(0xFF223044),
      surfaceContainerHighest: Color(0xFFF1F5F8),
      onSurfaceVariant: Color(0xFF728292),
      outline: Color(0xFFB8C8D5),
      outlineVariant: Color(0xFFD9E3EA),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      cardTheme: const CardThemeData(elevation: 0, margin: EdgeInsets.zero),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF8FBFD),
        foregroundColor: Color(0xFF1F2430),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFDCECF8),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(
            color: Color(0xFF2F5F85),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _BrandLaunchScreen extends StatelessWidget {
  const _BrandLaunchScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBFD),
      body: Center(
        child: Transform.translate(
          offset: const Offset(0, -32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/icon-1024-noalpha.png',
                width: 148,
                height: 148,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 26),
              Text(
                'Signal Path',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: const Color(0xFF213040),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                '看见信号，轻轻调整',
                style: TextStyle(
                  color: Color(0xFF394B5C),
                  fontSize: 17,
                  height: 1.35,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
