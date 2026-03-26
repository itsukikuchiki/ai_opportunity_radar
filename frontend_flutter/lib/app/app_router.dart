import 'package:go_router/go_router.dart';
import '../features/onboarding/onboarding_page.dart';
import '../features/pages/today/today_page.dart';
import '../features/pages/weekly/weekly_page.dart';
import '../features/pages/opportunities/opportunity_detail_page.dart';
import '../features/pages/memory/memory_page.dart';

class AppRoutes {
  static const onboarding = '/onboarding';
  static const today = '/today';
  static const weekly = '/weekly';
  static const opportunity = '/opportunity';
  static const memory = '/memory';
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.onboarding,
  routes: [
    GoRoute(path: AppRoutes.onboarding, builder: (_, __) => const OnboardingPage()),
    GoRoute(path: AppRoutes.today, builder: (_, __) => const TodayPage()),
    GoRoute(path: AppRoutes.weekly, builder: (_, __) => const WeeklyPage()),
    GoRoute(
      path: '${AppRoutes.opportunity}/:id',
      builder: (_, state) => OpportunityDetailPage(opportunityId: state.pathParameters['id']!),
    ),
    GoRoute(path: AppRoutes.memory, builder: (_, __) => const MemoryPage()),
  ],
);
