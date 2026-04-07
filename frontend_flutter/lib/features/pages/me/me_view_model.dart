import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../onboarding/onboarding_view_model.dart';

class MeViewModel extends ChangeNotifier {
  String? selectedRepeatArea;
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
          prefs.getString(OnboardingViewModel.repeatAreaPreferenceKey);
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> reload() => load();

  Future<bool> updateRepeatArea(String value) async {
    saving = true;
    errorMessage = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
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
