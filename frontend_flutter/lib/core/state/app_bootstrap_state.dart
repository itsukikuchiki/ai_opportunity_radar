import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/build_environment.dart';
import '../diagnostics/privacy_safe_logger.dart';
import '../di/app_dependencies.dart';
import '../notifications/schedule_notification_service.dart';
import '../notifications/signal_reminder_repository.dart';
import '../qa/qa_showcase_seeder.dart';

typedef AppDependenciesFactory = Future<AppDependencies> Function();
typedef SignalReminderTodayDestinationReader = Future<bool> Function();

class AppBootstrapState extends ChangeNotifier {
  final AppDependenciesFactory _dependenciesFactory;
  final PrivacySafeLogger _logger;
  final SignalReminderTodayDestinationReader
      _signalReminderTodayDestinationReader;
  SharedPreferences? _preferences;
  AppDependencies? _dependencies;
  bool _initialized = false;
  bool _initializing = false;
  bool _onboardingCompleted = false;
  bool _signalReminderTodayPending = false;
  Object? _initError;
  String? _initErrorEventId;

  AppBootstrapState({
    AppDependenciesFactory? dependenciesFactory,
    PrivacySafeLogger? logger,
    SignalReminderTodayDestinationReader? signalReminderTodayDestinationReader,
  })  : _dependenciesFactory = dependenciesFactory ?? AppDependencies.create,
        _logger = logger ?? PrivacySafeLogger.instance,
        _signalReminderTodayDestinationReader =
            signalReminderTodayDestinationReader ??
                ScheduleNotificationService().consumeTodayDestination;

  AppDependencies get dependencies {
    final deps = _dependencies;
    if (deps == null) {
      throw StateError('AppDependencies not initialized yet.');
    }
    return deps;
  }

  bool get initialized => _initialized;
  bool get initializing => _initializing;
  bool get onboardingCompleted => _onboardingCompleted;
  bool get hasError => _initError != null;
  Object? get initError => _initError;
  String? get initErrorEventId => _initErrorEventId;
  bool get signalReminderTodayPending => _signalReminderTodayPending;

  /// Reads and consumes the platform's one-time notification destination.
  ///
  /// The platform returns only a boolean route marker; no Signal is created or
  /// mutated by this handoff.
  Future<bool> refreshSignalReminderTodayDestination() async {
    if (_signalReminderTodayPending) return true;
    final pending = await _signalReminderTodayDestinationReader();
    if (!pending) return false;
    _signalReminderTodayPending = true;
    notifyListeners();
    return true;
  }

  Future<void> prepareLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    _preferences = prefs;
    _readOnboardingCompletion(prefs);
    if (BuildEnvironment.qaShowcaseData) {
      await prefs.setBool('onboarding_completed', true);
      await prefs.setBool('onboardingCompleted', true);
      _onboardingCompleted = true;
    }
  }

  Future<void> init() async {
    if (_initializing) return;
    _initializing = true;
    try {
      final prefs = _preferences ?? await SharedPreferences.getInstance();
      _preferences = prefs;
      _readOnboardingCompletion(prefs);

      final dependencies = await _dependenciesFactory();
      if (BuildEnvironment.qaShowcaseData) {
        await QaShowcaseSeeder.seed(
          dependencies: dependencies,
          preferences: prefs,
        );
        _onboardingCompleted = true;
      }
      _dependencies = dependencies;
      await _clearLegacyScheduleNotificationsOnce(prefs);
      await refreshSignalReminderTodayDestination();
      // Local weekly rules are expanded into one-time notifications. Refreshing
      // on launch keeps their local clock time correct after timezone/DST
      // changes and never asks for notification permission.
      await SignalReminderRepository(preferences: prefs)
          .rescheduleEnabledRules();
      _initialized = true;
      _initError = null;
      _initErrorEventId = null;
    } catch (error, stackTrace) {
      _initError = error;
      _initErrorEventId = _logger
          .capture(
            error,
            stackTrace,
            operation: 'app_initialization',
            fatal: true,
          )
          .eventId;
      _initialized = true;
    } finally {
      _initializing = false;
    }

    notifyListeners();
  }

  Future<void> retryInitialization() async {
    if (_initializing) return;
    _initialized = false;
    _initError = null;
    _initErrorEventId = null;
    notifyListeners();
    await init();
  }

  Future<void> markOnboardingCompleted() async {
    final prefs = _preferences ?? await SharedPreferences.getInstance();
    _preferences = prefs;
    await prefs.setBool('onboarding_completed', true);
    await prefs.setBool('onboardingCompleted', true);
    _onboardingCompleted = true;
    notifyListeners();
  }

  /// Recreates the anonymous local identity after a complete data deletion.
  /// This prevents writes made later in the same process from resurrecting the
  /// just-deleted server/local identity.
  Future<void> resetAfterDataDeletion() async {
    _initialized = false;
    _onboardingCompleted = false;
    _signalReminderTodayPending = false;
    _initError = null;
    _initErrorEventId = null;
    _dependencies = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      _preferences = prefs;
      await prefs.setBool('onboarding_completed', false);
      await prefs.setBool('onboardingCompleted', false);
      _dependencies = await _dependenciesFactory();
    } catch (error, stackTrace) {
      _initError = error;
      _initErrorEventId = _logger
          .capture(
            error,
            stackTrace,
            operation: 'reset_after_data_deletion',
            fatal: true,
          )
          .eventId;
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  void _readOnboardingCompletion(SharedPreferences prefs) {
    _onboardingCompleted = prefs.getBool('onboarding_completed') ??
        prefs.getBool('onboardingCompleted') ??
        false;
  }

  Future<void> _clearLegacyScheduleNotificationsOnce(
    SharedPreferences prefs,
  ) async {
    const key = 'legacy_schedule_notifications_cleared_v1';
    if (prefs.getBool(key) == true) return;
    final cleared =
        await ScheduleNotificationService().cancelAllLegacyScheduleReminders();
    if (cleared) await prefs.setBool(key, true);
  }
}
