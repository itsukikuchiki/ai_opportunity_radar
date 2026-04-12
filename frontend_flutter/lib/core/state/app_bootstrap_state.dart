import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../di/app_dependencies.dart';

class AppBootstrapState extends ChangeNotifier {
  AppDependencies? _dependencies;
  bool _initialized = false;
  bool _onboardingCompleted = false;
  Object? _initError;

  AppDependencies get dependencies {
    final deps = _dependencies;
    if (deps == null) {
      throw StateError('AppDependencies not initialized yet.');
    }
    return deps;
  }

  bool get initialized => _initialized;
  bool get onboardingCompleted => _onboardingCompleted;
  bool get hasError => _initError != null;
  Object? get initError => _initError;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _onboardingCompleted =
          prefs.getBool('onboarding_completed') ??
          prefs.getBool('onboardingCompleted') ??
          false;

      _dependencies = await AppDependencies.create();
      _initialized = true;
      _initError = null;
    } catch (e) {
      _initError = e;
      _initialized = true;
    }

    notifyListeners();
  }

  Future<void> markOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    await prefs.setBool('onboardingCompleted', true);
    _onboardingCompleted = true;
    notifyListeners();
  }
}
