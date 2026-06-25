import 'package:go_router/go_router.dart';

import '../core/state/app_bootstrap_state.dart';
import '../features/onboarding/onboarding_page.dart';
import '../features/paywall/premium_gate_page.dart';
import '../features/pages/me/me_page.dart';
import '../features/pages/me/advanced_signal_settings_page.dart';
import '../features/pages/memory/memory_page.dart';
import '../features/pages/self_review/self_review_page.dart';
import '../features/pages/signal_library/signal_library_page.dart';
import '../features/pages/today/today_diary_page.dart';
import '../features/pages/today/today_dialog_page.dart';
import '../features/pages/today/today_page.dart';
import '../features/pages/weekly/deep_weekly_page.dart';
import '../features/pages/weekly/weekly_page.dart';
import '../features/shell/home_shell_page.dart';

class AppRoutes {
  static const onboarding = '/onboarding';
  static const today = '/today';
  static const weekly = '/weekly';
  static const memory = '/memory';
  static const me = '/me';
  static const selfReview = '/self-review';
  static const advancedSignals = '/me/advanced-signals';
  static const signalLibrary = '/signal-library';
  static const todayDiary = '/today/diary';
  static const todayDialog = '/today/dialog';
  static const deepWeekly = '/weekly/deep';
  static const journal = '/memory/journal';
}

GoRouter createAppRouter(AppBootstrapState bootstrap) {
  const qaInitialRoute = String.fromEnvironment('SIGNALPATH_INITIAL_ROUTE');
  final qaResolvedInitialRoute = _resolvedInitialRoute(qaInitialRoute);
  final initialLocation = bootstrap.onboardingCompleted
      ? qaResolvedInitialRoute
      : AppRoutes.onboarding;

  return GoRouter(
    initialLocation: initialLocation,
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
            path: AppRoutes.signalLibrary,
            builder: (_, __) => const SignalLibraryPage(),
          ),
          GoRoute(
            path: AppRoutes.me,
            builder: (_, __) => const MePage(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.todayDiary,
        builder: (_, __) => const TodayDiaryPage(),
      ),
      GoRoute(
        path: '${AppRoutes.todayDialog}/:captureId',
        builder: (_, state) => PremiumGatePage(
          source: 'Today dialogue',
          child: TodayDialogPage(
            captureId: state.pathParameters['captureId']!,
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.deepWeekly,
        builder: (_, __) => const PremiumGatePage(
          source: 'Deep Weekly',
          child: DeepWeeklyPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.journal,
        builder: (_, __) => const TodayDiaryPage(),
      ),
      GoRoute(
        path: AppRoutes.selfReview,
        builder: (_, __) => const PremiumGatePage(
          source: 'Structured self-review',
          child: SelfReviewPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.advancedSignals,
        builder: (_, __) => const AdvancedSignalSettingsPage(),
      ),
    ],
    redirect: (_, state) {
      final completed = bootstrap.onboardingCompleted;
      final goingToOnboarding = state.matchedLocation == AppRoutes.onboarding;
      final hasQaInitialRoute = qaInitialRoute.isNotEmpty;

      if (!completed && !goingToOnboarding) {
        return AppRoutes.onboarding;
      }

      if (completed && goingToOnboarding) {
        return hasQaInitialRoute ? qaResolvedInitialRoute : AppRoutes.today;
      }

      if (completed &&
          hasQaInitialRoute &&
          _isShellRoute(state.matchedLocation) &&
          state.matchedLocation != qaResolvedInitialRoute) {
        return qaResolvedInitialRoute;
      }

      return null;
    },
  );
}

bool _isShellRoute(String route) {
  switch (route) {
    case AppRoutes.today:
    case AppRoutes.weekly:
    case AppRoutes.memory:
    case AppRoutes.signalLibrary:
    case AppRoutes.me:
      return true;
    default:
      return false;
  }
}

String _resolvedInitialRoute(String route) {
  switch (route) {
    case AppRoutes.today:
    case AppRoutes.weekly:
    case AppRoutes.memory:
    case AppRoutes.signalLibrary:
    case AppRoutes.me:
      return route;
    default:
      return AppRoutes.today;
  }
}
