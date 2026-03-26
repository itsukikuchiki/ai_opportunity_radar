import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_router.dart';
import '../core/di/app_dependencies.dart';
import '../features/onboarding/onboarding_view_model.dart';
import '../features/pages/today/today_view_model.dart';
import '../features/pages/weekly/weekly_view_model.dart';
import '../features/pages/opportunities/opportunity_detail_view_model.dart';
import '../features/pages/memory/memory_view_model.dart';

class RadarApp extends StatelessWidget {
  const RadarApp({super.key});

  @override
  Widget build(BuildContext context) {
    final dependencies = AppDependencies.create();
    return MultiProvider(
      providers: [
        Provider.value(value: dependencies),
        ChangeNotifierProvider(create: (_) => OnboardingViewModel(dependencies.apiClient)),
        ChangeNotifierProvider(create: (_) => TodayViewModel(dependencies.todayRepository)),
        ChangeNotifierProvider(create: (_) => WeeklyViewModel(dependencies.weeklyRepository)),
        ChangeNotifierProvider(create: (_) => OpportunityDetailViewModel(dependencies.opportunityRepository)),
        ChangeNotifierProvider(create: (_) => MemoryViewModel(dependencies.memoryRepository)),
      ],
      child: MaterialApp.router(
        title: 'AI Opportunity Radar',
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        routerConfig: appRouter,
      ),
    );
  }
}
