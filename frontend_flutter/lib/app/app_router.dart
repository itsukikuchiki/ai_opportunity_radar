import 'package:go_router/go_router.dart';

import '../core/state/app_bootstrap_state.dart';
import '../features/onboarding/onboarding_page.dart';
import '../features/paywall/premium_gate_page.dart';
import '../features/debug/debug_trace_page.dart';
import '../core/models/candidate_models.dart';
import '../features/pages/candidates/candidate_hub_page.dart';
import '../features/pages/me/me_page.dart';
import '../features/pages/me/advanced_signal_settings_page.dart';
import '../features/pages/me/data_privacy_page.dart';
import '../features/pages/me/signal_reminder_settings_page.dart';
import '../features/pages/experiment/experiment_page.dart';
import '../features/pages/memory/journey_pro_page.dart';
import '../features/pages/memory/memory_page.dart';
import '../features/pages/self_review/self_review_page.dart';
import '../features/pages/signal_library/signal_library_page.dart';
import '../features/pages/today/today_diary_page.dart';
import '../features/pages/today/today_dialog_page.dart';
import '../features/pages/today/today_experiment_feedback_page.dart';
import '../features/pages/today/today_page.dart';
import '../features/pages/weekly/deep_weekly_page.dart';
import '../features/pages/weekly/weekly_page.dart';
import '../features/shell/home_shell_page.dart';

class AppRoutes {
  static const onboarding = '/onboarding';
  static const today = '/today';
  static const weekly = '/weekly';
  static const experiment = '/experiment';
  static const todayActionCandidates = '/today/action-candidates';
  static const weeklyExperimentCandidates = '/weekly/experiment-candidates';
  static const todayExperimentFeedback = '/today/experiment-feedback';
  static const memory = '/memory';
  static const me = '/me';
  static const selfReview = '/self-review';
  static const advancedSignals = '/me/advanced-signals';
  static const dataPrivacy = '/me/data-privacy';
  static const signalReminders = '/me/signal-reminders';
  static const signalLibrary = '/signal-library';
  static const todayDiary = '/today/diary';
  static const todayDialog = '/today/dialog';
  static const weeklyReflect = '/weekly/reflect';
  static const deepWeekly = '/weekly/deep';
  static const journal = '/memory/journal';
  static const journeyFragments = '/memory/fragments';
  static const journeyPro = '/memory/pro-l3';
  static const debugTrace = '/debug/trace';
}

GoRouter createAppRouter(AppBootstrapState bootstrap) {
  const qaInitialRoute = String.fromEnvironment('SIGNALPATH_INITIAL_ROUTE');
  final qaResolvedInitialRoute = resolvedInitialRoute(qaInitialRoute);
  var consumedSignalReminderTodayRedirect = false;
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
            path: AppRoutes.experiment,
            builder: (_, __) => const ExperimentPage(),
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
        builder: (_, state) => TodayDiaryPage(
          initialDateKey: state.uri.queryParameters['date'],
        ),
      ),
      GoRoute(
        path: AppRoutes.todayActionCandidates,
        builder: (_, __) => const CandidateHubPage(
          kind: CandidateKind.microAction,
        ),
      ),
      GoRoute(
        path: AppRoutes.weeklyExperimentCandidates,
        builder: (_, __) => const CandidateHubPage(
          kind: CandidateKind.lifeExperiment,
        ),
      ),
      GoRoute(
        path: '${AppRoutes.todayExperimentFeedback}/:experimentId',
        builder: (_, state) => TodayExperimentFeedbackPage(
          experimentId: state.pathParameters['experimentId']!,
        ),
      ),
      GoRoute(
        path: '${AppRoutes.todayDialog}/:captureId',
        builder: (_, state) => PremiumGatePage(
          source: '今天记录',
          fallbackRoute: AppRoutes.today,
          child: TodayDialogPage(
            captureId: state.pathParameters['captureId']!,
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.weeklyReflect,
        builder: (_, __) => const PremiumGatePage(
          source: '每周复盘深度分析',
          fallbackRoute: AppRoutes.weekly,
          child: WeeklyReflectPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.deepWeekly,
        redirect: (_, __) => AppRoutes.weeklyReflect,
      ),
      GoRoute(
        path: AppRoutes.journal,
        redirect: (_, state) {
          final date = state.uri.queryParameters['date'];
          return canonicalDiaryLocation(date: date);
        },
      ),
      GoRoute(
        path: AppRoutes.journeyFragments,
        redirect: (_, state) => canonicalDiaryLocationForMonth(
          month: state.uri.queryParameters['month'],
        ),
      ),
      GoRoute(
        path: AppRoutes.journeyPro,
        builder: (_, state) => PremiumGatePage(
          source: '旅程 Pro 三个月变化',
          fallbackRoute: AppRoutes.memory,
          child: JourneyProPage(
            initialMonthKey: state.uri.queryParameters['month'],
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.selfReview,
        builder: (_, __) => const PremiumGatePage(
          source: 'Structured self-review',
          fallbackRoute: AppRoutes.me,
          child: SelfReviewPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.advancedSignals,
        builder: (_, __) => const AdvancedSignalSettingsPage(),
      ),
      GoRoute(
        path: AppRoutes.dataPrivacy,
        builder: (_, __) => const DataPrivacyPage(),
      ),
      GoRoute(
        path: AppRoutes.signalReminders,
        builder: (_, __) => const SignalReminderSettingsPage(),
      ),
      GoRoute(
        path: AppRoutes.debugTrace,
        builder: (_, state) => DebugTracePage(
          initialSignalId: state.uri.queryParameters['signalId'],
        ),
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

      // A notification tap is a one-shot routing instruction only. It opens
      // Today, never writes a Signal, and must win over a remembered tab.
      if (completed &&
          bootstrap.signalReminderTodayPending &&
          !consumedSignalReminderTodayRedirect) {
        consumedSignalReminderTodayRedirect = true;
        if (state.matchedLocation != AppRoutes.today) {
          return AppRoutes.today;
        }
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
    case AppRoutes.experiment:
    case AppRoutes.memory:
    case AppRoutes.signalLibrary:
    case AppRoutes.me:
      return true;
    default:
      return false;
  }
}

String resolvedInitialRoute(String route) {
  switch (route) {
    case AppRoutes.today:
    case AppRoutes.weekly:
    case AppRoutes.experiment:
    case AppRoutes.memory:
    case AppRoutes.signalLibrary:
    case AppRoutes.me:
    case AppRoutes.debugTrace:
    case AppRoutes.weeklyReflect:
    case AppRoutes.todayActionCandidates:
    case AppRoutes.weeklyExperimentCandidates:
    case AppRoutes.journeyPro:
    case AppRoutes.dataPrivacy:
    case AppRoutes.signalReminders:
      return route;
    case AppRoutes.deepWeekly:
      return AppRoutes.weeklyReflect;
    default:
      return AppRoutes.today;
  }
}

String canonicalDiaryLocation({String? date}) {
  final normalized = date?.trim();
  if (normalized == null || normalized.isEmpty) return AppRoutes.todayDiary;
  return Uri(
    path: AppRoutes.todayDiary,
    queryParameters: {'date': normalized},
  ).toString();
}

String canonicalDiaryLocationForMonth({String? month}) {
  final normalized = month?.trim();
  if (normalized == null ||
      !RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(normalized)) {
    return canonicalDiaryLocation();
  }
  return canonicalDiaryLocation(date: '$normalized-01');
}
