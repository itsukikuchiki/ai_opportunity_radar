import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_client.dart';

class OnboardingViewModel extends ChangeNotifier {
  static const String repeatAreaPreferenceKey = 'selected_repeat_area';

  final ApiClient apiClient;

  OnboardingViewModel(this.apiClient);

  String? selectedRepeatArea;
  bool submitting = false;
  String? errorCode;

  bool get canSubmit => !submitting && selectedRepeatArea != null;

  void updateRepeatArea(String value) {
    selectedRepeatArea = value;
    errorCode = null;
    notifyListeners();
  }

  Future<void> complete() async {
    if (selectedRepeatArea == null) {
      errorCode = 'repeat_area_required';
      notifyListeners();
      throw Exception(errorCode);
    }

    submitting = true;
    errorCode = null;
    notifyListeners();

    try {
      await apiClient.postJson('/api/v1/onboarding/complete', {
        'selected_repeat_area': selectedRepeatArea,
        'selected_ai_help_type': null,
        'selected_output_preference': null,
      });

      await _persistPreference();
    } catch (e) {
      errorCode = 'submit_failed';
      rethrow;
    } finally {
      submitting = false;
      notifyListeners();
    }
  }

  Future<void> _persistPreference() async {
    final value = selectedRepeatArea;
    if (value == null || value.trim().isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(repeatAreaPreferenceKey, value);
  }
}
