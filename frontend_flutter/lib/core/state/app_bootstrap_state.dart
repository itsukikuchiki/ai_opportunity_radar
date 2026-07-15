import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/build_environment.dart';
import '../diagnostics/privacy_safe_logger.dart';
import '../di/app_dependencies.dart';
import '../notifications/schedule_notification_service.dart';
import '../qa/qa_showcase_seeder.dart';

typedef AppDependenciesFactory = Future<AppDependencies> Function();

class AppBootstrapState extends ChangeNotifier {
  final AppDependenciesFactory _dependenciesFactory;
  final PrivacySafeLogger _logger;
  SharedPreferences? _preferences;
  AppDependencies? _dependencies;
  bool _initialized = false;
  bool _initializing = false;
  bool _onboardingCompleted = false;
  Object? _initError;
  String? _initErrorEventId;

  AppBootstrapState({
    AppDependenciesFactory? dependenciesFactory,
    PrivacySafeLogger? logger,
  })  : _dependenciesFactory = dependenciesFactory ?? AppDependencies.create,
        _logger = logger ?? PrivacySafeLogger.instance;

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
