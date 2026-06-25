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
import '../features/pages/memory/memory_view_model.dart';
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
  MemoryViewModel? _memoryViewModel;
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
    _memoryViewModel = MemoryViewModel(
      dependencies.memoryRepository,
      analyticsRepository: dependencies.analyticsRepository,
    );
    _selfReviewViewModel =
        SelfReviewViewModel(dependencies.selfReviewRepository);
    _signalLibraryViewModel =
        SignalLibraryViewModel(dependencies.signalLibraryRepository);
    _meViewModel = MeViewModel(
      dependencies.apiClient,
      dependencies.backupBundleRepository,
      dependencies.cloudBackupRepository,
      dependencies.localUserId,
      dependencies.deviceId,
    );
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
    _memoryViewModel?.dispose();
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
            ChangeNotifierProvider<MemoryViewModel>.value(
                value: _memoryViewModel!),
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
      primary: Color(0xFF7267F0),
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFEDEBFF),
      onPrimaryContainer: Color(0xFF151A33),
      secondary: Color(0xFF5F95E8),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFEAF3FF),
      onSecondaryContainer: Color(0xFF151A33),
      tertiary: Color(0xFF62C594),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFEAF8F0),
      onTertiaryContainer: Color(0xFF151A33),
      surface: Color(0xFFFFFCFA),
      onSurface: Color(0xFF151A33),
      surfaceContainerHighest: Color(0xFFF5F4F8),
      onSurfaceVariant: Color(0xFF7F8797),
      outline: Color(0xFFCFCBD8),
      outlineVariant: Color(0xFFE7E4EC),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      cardTheme: const CardThemeData(elevation: 0, margin: EdgeInsets.zero),
      fontFamily: 'SF Pro Text',
      textTheme: const TextTheme(
        headlineMedium:
            TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0),
        headlineSmall: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0),
        titleLarge: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0),
        titleMedium: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0),
        bodyLarge: TextStyle(height: 1.45, letterSpacing: 0),
        bodyMedium: TextStyle(height: 1.45, letterSpacing: 0),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0x00FFFCFA),
        foregroundColor: Color(0xFF151A33),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF7267F0),
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF151A33),
          side: const BorderSide(color: Color(0xFFE7E4EC)),
          minimumSize: const Size(64, 46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.94),
        indicatorColor: const Color(0xFFEDEBFF),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(
            color: Color(0xFF7267F0),
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
                'assets/brand-icon-transparent.png',
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
