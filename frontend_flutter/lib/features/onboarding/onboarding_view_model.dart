import 'package:flutter/foundation.dart';
import '../../core/api/api_client.dart';

class OnboardingViewModel extends ChangeNotifier {
  final ApiClient apiClient;
  OnboardingViewModel(this.apiClient);

  String? selectedRepeatArea;
  String? selectedAiHelpType;
  String? selectedOutputPreference;
  bool submitting = false;

  void updateRepeatArea(String value) {
    selectedRepeatArea = value;
    notifyListeners();
  }

  Future<void> complete() async {
    submitting = true;
    notifyListeners();
    try {
      await apiClient.postJson('/api/v1/onboarding/complete', {
        'selected_repeat_area': selectedRepeatArea,
        'selected_ai_help_type': selectedAiHelpType,
        'selected_output_preference': selectedOutputPreference,
      });
    } finally {
      submitting = false;
      notifyListeners();
    }
  }
}
