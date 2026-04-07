import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'app_router.dart';
import '../core/di/app_dependencies.dart';
import '../core/state/app_bootstrap_state.dart';
import '../features/onboarding/onboarding_view_model.dart';
import '../features/pages/me/me_view_model.dart';
import '../features/pages/today/today_view_model.dart';
import '../features/pages/weekly/weekly_view_model.dart';
import '../features/pages/opportunities/opportunity_detail_view_model.dart';
import '../features/pages/memory/memory_view_model.dart';

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
  late final AppDependencies dependencies;
  late final GoRouter router;

  @override
  void initState() {
    super.initState();
    dependencies = AppDependencies.create();
    router = createAppRouter(widget.bootstrapState);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: dependencies),
        ChangeNotifierProvider.value(value: widget.bootstrapState),
        ChangeNotifierProvider(
          create: (_) => OnboardingViewModel(dependencies.apiClient),
        ),
        ChangeNotifierProvider(
          create: (_) => TodayViewModel(dependencies.todayRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => WeeklyViewModel(dependencies.weeklyRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => OpportunityDetailViewModel(
            dependencies.opportunityRepository,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => MemoryViewModel(dependencies.memoryRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => MeViewModel(),
        ),
      ],
      child: MaterialApp.router(
        title: 'AI Opportunity Radar',
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
            final isTraditional =
                scriptCode == 'hant' ||
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
        theme: ThemeData(
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
              borderSide:
                  const BorderSide(color: Color(0xFF6B7A90), width: 1.4),
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
        ),
        routerConfig: router,
      ),
    );
  }
}
