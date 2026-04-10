import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../di/app_dependencies.dart';

class AppBootstrapState extends ChangeNotifier {
  static const String _onboardingCompletedKey = 'onboarding_completed';

  bool _initialized = false;
  bool _onboardingCompleted = false;
  AppDependencies? _dependencies;
  Object? _initError;

  bool get initialized => _initialized;
  bool get onboardingCompleted => _onboardingCompleted;
  bool get hasError => _initError != null;
  Object? get initError => _initError;

  AppDependencies get dependencies {
    final value = _dependencies;
    if (value == null) {
      throw StateError(
        'AppDependencies has not been initialized yet. '
        'Call AppBootstrapState.init() before accessing dependencies.',
      );
    }
    return value;
  }

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _dependencies = await AppDependencies.create();
      _onboardingCompleted =
          prefs.getBool(_onboardingCompletedKey) ?? false;
      _initError = null;
    } catch (e) {
      _initError = e;
      rethrow;
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> markOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompletedKey, true);
    _onboardingCompleted = true;
    notifyListeners();
  }

  Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_onboardingCompletedKey);
    _onboardingCompleted = false;
    notifyListeners();
  }
}
