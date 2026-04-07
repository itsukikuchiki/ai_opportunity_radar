import 'package:go_router/go_router.dart';

import '../core/state/app_bootstrap_state.dart';
import '../features/onboarding/onboarding_page.dart';
import '../features/pages/me/me_page.dart';
import '../features/pages/memory/memory_page.dart';
import '../features/pages/opportunities/opportunity_detail_page.dart';
import '../features/pages/today/today_page.dart';
import '../features/pages/weekly/weekly_page.dart';
import '../features/shell/home_shell_page.dart';

class AppRoutes {
  static const onboarding = '/onboarding';
  static const today = '/today';
  static const weekly = '/weekly';
  static const opportunity = '/opportunity';
  static const memory = '/memory';
  static const me = '/me';
}

GoRouter createAppRouter(AppBootstrapState bootstrap) {
  return GoRouter(
    initialLocation:
        bootstrap.onboardingCompleted ? AppRoutes.today : AppRoutes.onboarding,
    refreshListenable: bootstrap,
    routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, __) => const OnboardingPage(),
      ),
      ShellRoute(
        builder: (_, __, child) => HomeShellPage(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.today,
            builder: (_, __) => const TodayPage(),
          ),
          GoRoute(
            path: AppRoutes.weekly,
            builder: (_, __) => const WeeklyPage(),
          ),
          GoRoute(
            path: AppRoutes.memory,
            builder: (_, __) => const MemoryPage(),
          ),
          GoRoute(
            path: AppRoutes.me,
            builder: (_, __) => const MePage(),
          ),
        ],
      ),
      GoRoute(
        path: '${AppRoutes.opportunity}/:id',
        builder: (_, state) =>
            OpportunityDetailPage(opportunityId: state.pathParameters['id']!),
      ),
    ],
    redirect: (_, state) {
      final completed = bootstrap.onboardingCompleted;
      final goingToOnboarding = state.matchedLocation == AppRoutes.onboarding;

      if (!completed && !goingToOnboarding) {
        return AppRoutes.onboarding;
      }

      if (completed && goingToOnboarding) {
        return AppRoutes.today;
      }

      return null;
    },
  );
}
