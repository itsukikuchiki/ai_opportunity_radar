import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'app_router.dart';
import '../core/di/app_dependencies.dart';
import '../core/purchases/purchase_controller.dart';
import '../core/state/app_bootstrap_state.dart';
import '../core/state/app_data_refresh_coordinator.dart';
import '../features/onboarding/onboarding_page.dart';
import '../features/onboarding/onboarding_view_model.dart';
import '../features/pages/me/me_view_model.dart';
import '../features/pages/memory/memory_view_model.dart';
import '../features/pages/memory/journey_pro_view_model.dart';
import '../features/pages/self_review/self_review_view_model.dart';
import '../features/pages/signal_library/signal_library_view_model.dart';
import '../features/pages/today/today_view_model.dart';
import '../features/pages/weekly/weekly_view_model.dart';
import '../features/system/initialization_failure_page.dart';
import '../shared/widgets/aurora_ui.dart';

class RadarApp extends StatefulWidget {
  final AppBootstrapState bootstrapState;

  const RadarApp({
    super.key,
    required this.bootstrapState,
  });

  @override
  State<RadarApp> createState() => _RadarAppState();
}

class _RadarAppState extends State<RadarApp> with WidgetsBindingObserver {
  late final GoRouter _router;

  AppDependencies? _dependencies;
  OnboardingViewModel? _onboardingViewModel;
  TodayViewModel? _todayViewModel;
  WeeklyViewModel? _weeklyViewModel;
  MemoryViewModel? _memoryViewModel;
  JourneyProViewModel? _journeyProViewModel;
  SelfReviewViewModel? _selfReviewViewModel;
  SignalLibraryViewModel? _signalLibraryViewModel;
  MeViewModel? _meViewModel;
  PurchaseController? _purchaseController;
  AppDataRefreshCoordinator? _dataRefreshCoordinator;
  String? _purchaseEntitlementSignature;
  bool _trackedAppOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _router = createAppRouter(widget.bootstrapState);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final purchase = _purchaseController;
    if (purchase != null) {
      unawaited(purchase.refreshCurrentEntitlements());
    }
  }

  void _ensureAppObjectsInitialized() {
    if (_dependencies != null) return;

    final dependencies = widget.bootstrapState.dependencies;
    _dependencies = dependencies;
    _meViewModel = MeViewModel(
      dependencies.apiClient,
      dependencies.localDatabase,
    );
    _onboardingViewModel = OnboardingViewModel(
      dependencies.apiClient,
      analyticsRepository: dependencies.analyticsRepository,
      onFocusDomainsPersisted: _meViewModel!.applyPersistedFocusDomains,
    );
    _todayViewModel = TodayViewModel(dependencies.todayRepository);
    _weeklyViewModel = WeeklyViewModel(
      dependencies.weeklyRepository,
      energyBudgetRepository: dependencies.energyBudgetRepository,
      analyticsRepository: dependencies.analyticsRepository,
      candidatePlanningRepository:
          dependencies.localCandidatePlanningRepository,
    );
    _memoryViewModel = MemoryViewModel(
      dependencies.memoryRepository,
      analyticsRepository: dependencies.analyticsRepository,
    );
    _journeyProViewModel = JourneyProViewModel(
      dependencies.journeyProRepository,
    );
    _selfReviewViewModel =
        SelfReviewViewModel(dependencies.selfReviewRepository);
    _signalLibraryViewModel = SignalLibraryViewModel(
      dependencies.signalLibraryRepository,
      analyticsRepository: dependencies.analyticsRepository,
    );
    _purchaseController = PurchaseController(apiClient: dependencies.apiClient);
    _purchaseEntitlementSignature = _entitlementSignature(_purchaseController!);
    _purchaseController!.addListener(_handlePurchaseStateChanged);
    _dataRefreshCoordinator = AppDataRefreshCoordinator(
      routeLoaders: {
        AppRoutes.today: _todayViewModel!.load,
        AppRoutes.weekly: _weeklyViewModel!.load,
        AppRoutes.experiment: _weeklyViewModel!.load,
        AppRoutes.memory: _memoryViewModel!.load,
        AppRoutes.me: _meViewModel!.reload,
      },
    );
    if (!_trackedAppOpen) {
      _trackedAppOpen = true;
      unawaited(dependencies.analyticsRepository.track('app_open'));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeAppObjects();
    _router.dispose();
    super.dispose();
  }

  void _disposeAppObjects() {
    final dependencies = _dependencies;
    _purchaseController?.removeListener(_handlePurchaseStateChanged);
    _dataRefreshCoordinator?.dispose();
    _onboardingViewModel?.dispose();
    _todayViewModel?.dispose();
    _weeklyViewModel?.dispose();
    _memoryViewModel?.dispose();
    _journeyProViewModel?.dispose();
    _selfReviewViewModel?.dispose();
    _signalLibraryViewModel?.dispose();
    _meViewModel?.dispose();
    _purchaseController?.dispose();
    if (dependencies != null) {
      unawaited(dependencies.localCandidatePlanningRepository.dispose());
      dependencies.apiClient.close();
    }
    _dependencies = null;
    _onboardingViewModel = null;
    _todayViewModel = null;
    _weeklyViewModel = null;
    _memoryViewModel = null;
    _journeyProViewModel = null;
    _selfReviewViewModel = null;
    _signalLibraryViewModel = null;
    _meViewModel = null;
    _purchaseController = null;
    _dataRefreshCoordinator = null;
    _purchaseEntitlementSignature = null;
  }

  void _handlePurchaseStateChanged() {
    final controller = _purchaseController;
    if (controller == null) return;
    final next = _entitlementSignature(controller);
    final previous = _purchaseEntitlementSignature;
    _purchaseEntitlementSignature = next;
    if (previous == null || previous == next) return;
    AppDataMutationBus.publish(
      kind: AppDataMutationKind.entitlement,
      reason: 'pro_entitlement_changed',
    );
  }

  String _entitlementSignature(PurchaseController controller) => [
        controller.isPremium,
        controller.entitlementProductId ?? '',
        controller.entitlementVerificationSource ?? '',
        controller.serverVerified,
      ].join('|');

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.bootstrapState,
      builder: (context, _) {
        final bootstrap = widget.bootstrapState;

        if (!bootstrap.initialized) {
          return _buildLoadingApp(
            showOnboarding: !bootstrap.onboardingCompleted,
          );
        }
        if (bootstrap.hasError) return _buildErrorApp(bootstrap);

        if (_dependencies != null &&
            !identical(_dependencies, bootstrap.dependencies)) {
          _disposeAppObjects();
        }

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
            ChangeNotifierProvider<JourneyProViewModel>.value(
                value: _journeyProViewModel!),
            ChangeNotifierProvider<SelfReviewViewModel>.value(
                value: _selfReviewViewModel!),
            ChangeNotifierProvider<SignalLibraryViewModel>.value(
                value: _signalLibraryViewModel!),
            ChangeNotifierProvider<MeViewModel>.value(value: _meViewModel!),
            ChangeNotifierProvider<PurchaseController?>.value(
                value: _purchaseController!),
            Provider<AppDataRefreshCoordinator>.value(
              value: _dataRefreshCoordinator!,
            ),
          ],
          child: _buildRouterApp(_router),
        );
      },
    );
  }

  Widget _buildLoadingApp({required bool showOnboarding}) {
    return MaterialApp(
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
      localeResolutionCallback: _resolveLocale,
      theme: _buildTheme(),
      home: showOnboarding
          ? const OnboardingLaunchPage()
          : const _BrandLaunchScreen(),
    );
  }

  Widget _buildErrorApp(AppBootstrapState bootstrap) {
    return MaterialApp(
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
      localeResolutionCallback: _resolveLocale,
      theme: _buildTheme(),
      home: InitializationFailurePage(
        referenceId: bootstrap.initErrorEventId,
        onRetry: bootstrap.retryInitialization,
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
      localeResolutionCallback: _resolveLocale,
      theme: _buildTheme(),
      routerConfig: router,
    );
  }

  Locale _resolveLocale(
    Locale? locale,
    Iterable<Locale> supportedLocales,
  ) {
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
              languageCode: 'zh',
              scriptCode: 'Hans',
            );
    }
    return const Locale('en');
  }

  ThemeData _buildTheme() {
    const colorScheme = ColorScheme.light(
      primary: Color(0xFF7767F4),
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
      onSurface: Color(0xFF252B4A),
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
      textTheme: const TextTheme(
        headlineMedium:
            TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.2),
        headlineSmall: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0),
        titleLarge: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0),
        titleMedium: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0),
        bodyLarge: TextStyle(height: 1.48, letterSpacing: 0),
        bodyMedium: TextStyle(height: 1.48, letterSpacing: 0),
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
      body: Stack(
        children: [
          AuroraPage(
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxHeight < 700;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 52,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 344),
                          child: AuroraCard(
                            key: const ValueKey('brand-launch-surface'),
                            padding: EdgeInsets.fromLTRB(
                              24,
                              compact ? 24 : 30,
                              24,
                              compact ? 26 : 32,
                            ),
                            borderRadius: BorderRadius.circular(30),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ExcludeSemantics(
                                  child: AuroraHeroEmblem(
                                    size: compact ? 132 : 164,
                                    opacity: 0.94,
                                  ),
                                ),
                                SizedBox(height: compact ? 14 : 20),
                                Semantics(
                                  key: const ValueKey('brand-launch-title'),
                                  header: true,
                                  label: 'Signal Path',
                                  child: const ExcludeSemantics(
                                    child: AuroraHeroTitle(
                                      text: 'Signal Path',
                                      fontSize: 38,
                                      maxLines: 1,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '看见信号，轻轻调整',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        color: AuroraColors.ink
                                            .withValues(alpha: 0.76),
                                        height: 1.4,
                                        fontWeight: FontWeight.w400,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const AuroraSafeTopMask(extraHeight: 0),
        ],
      ),
    );
  }
}
