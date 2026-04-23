import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../onboarding/onboarding_view_model.dart';

class MeViewModel extends ChangeNotifier {
  static const String repeatAreaPreferenceKey = 'repeat_area_preference';
  static const String fallbackRepeatAreaPreferenceKey = 'selected_repeat_area';
  static const String responseStylePreferenceKey = 'response_style_preference';

  String? selectedRepeatArea;
  String selectedResponseStyle = 'gentle';
  bool loading = true;
  bool saving = false;
  String? errorMessage;

  MeViewModel() {
    load();
  }

  Future<void> load() async {
    loading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      selectedRepeatArea =
          prefs.getString(repeatAreaPreferenceKey) ??
          prefs.getString(OnboardingViewModel.repeatAreaPreferenceKey) ??
          prefs.getString(fallbackRepeatAreaPreferenceKey);
      selectedResponseStyle =
          prefs.getString(responseStylePreferenceKey) ?? 'gentle';
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> reload() => load();


  Future<bool> updateResponseStyle(String value) async {
    saving = true;
    errorMessage = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(responseStylePreferenceKey, value);
      selectedResponseStyle = value;
      return true;
    } catch (e) {
      errorMessage = e.toString();
      return false;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<bool> updateRepeatArea(String value) async {
    saving = true;
    errorMessage = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(repeatAreaPreferenceKey, value);
      await prefs.setString(OnboardingViewModel.repeatAreaPreferenceKey, value);
      selectedRepeatArea = value;
      return true;
    } catch (e) {
      errorMessage = e.toString();
      return false;
    } finally {
      saving = false;
      notifyListeners();
    }
  }
}
