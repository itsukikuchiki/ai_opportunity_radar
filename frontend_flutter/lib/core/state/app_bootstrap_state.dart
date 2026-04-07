import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppBootstrapState extends ChangeNotifier {
  static const _onboardingCompletedKey = 'onboarding_completed';

  bool _initialized = false;
  bool _onboardingCompleted = false;

  bool get initialized => _initialized;
  bool get onboardingCompleted => _onboardingCompleted;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _onboardingCompleted = prefs.getBool(_onboardingCompletedKey) ?? false;
    _initialized = true;
    notifyListeners();
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
