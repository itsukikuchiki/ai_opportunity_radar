import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_client.dart';
import '../../core/api/repositories/analytics_repository.dart';
import '../../core/diagnostics/privacy_safe_logger.dart';
import '../../core/preferences/focus_domains.dart';
import '../../core/state/app_data_refresh_coordinator.dart';

class OnboardingViewModel extends ChangeNotifier {
  static const String repeatAreaPreferenceKey = 'selected_repeat_area';

  final ApiClient apiClient;
  final AnalyticsRepository? analyticsRepository;
  final ValueChanged<List<String>>? onFocusDomainsPersisted;

  OnboardingViewModel(
    this.apiClient, {
    this.analyticsRepository,
    this.onFocusDomainsPersisted,
  });

  String? selectedRepeatArea;
  List<String> selectedFocusDomainIds = FocusDomains.defaultIds;
  bool submitting = false;
  String? errorCode;

  bool get canSubmit => !submitting && selectedFocusDomainIds.isNotEmpty;

  void updateRepeatArea(String value) {
    selectedRepeatArea = value;
    selectedFocusDomainIds = FocusDomains.normalizeIds([value]);
    if (selectedFocusDomainIds.isEmpty) {
      selectedFocusDomainIds = FocusDomains.defaultIds;
    }
    errorCode = null;
    notifyListeners();
  }

  void updateFocusDomains(List<String> values) {
    final normalized = FocusDomains.normalizeIds(values);
    selectedFocusDomainIds =
        normalized.isEmpty ? FocusDomains.defaultIds : normalized;
    selectedRepeatArea = selectedFocusDomainIds.first;
    errorCode = null;
    notifyListeners();
  }

  Future<void> complete() async {
    _ensureFocusSelection();

    submitting = true;
    errorCode = null;
    notifyListeners();

    try {
      await _persistPreference();
      unawaited(analyticsRepository?.track(
        'onboarding_completed',
        properties: {
          'focus_domain_count': selectedFocusDomainIds.length,
          'primary_focus_domain': selectedRepeatArea,
        },
      ));
      unawaited(_submitRemoteCompletion());
    } catch (e) {
      errorCode = 'submit_failed';
      rethrow;
    } finally {
      submitting = false;
      notifyListeners();
    }
  }

  Future<void> _submitRemoteCompletion() async {
    try {
      await apiClient.postJson('/api/v1/onboarding/complete', {
        'selected_repeat_area': selectedRepeatArea,
        'selected_focus_domain_ids': selectedFocusDomainIds,
        'selected_ai_help_type': null,
        'selected_output_preference': null,
      });
    } catch (error, stackTrace) {
      PrivacySafeLogger.instance.capture(
        error,
        stackTrace,
        operation: 'onboarding_remote_completion',
      );
    }
  }

  Future<void> persistLocalPreference() async {
    _ensureFocusSelection();
    await _persistPreference();
  }

  Future<void> trackSkipped() async {
    _ensureFocusSelection();
    unawaited(analyticsRepository?.track(
      'onboarding_skipped',
      properties: {
        'focus_domain_count': selectedFocusDomainIds.length,
        'primary_focus_domain': selectedRepeatArea,
      },
    ));
  }

  void _ensureFocusSelection() {
    selectedFocusDomainIds = FocusDomains.normalizeIds(selectedFocusDomainIds);
    if (selectedFocusDomainIds.isEmpty) {
      selectedFocusDomainIds = FocusDomains.defaultIds;
    }
    selectedRepeatArea = selectedFocusDomainIds.first;
  }

  Future<void> _persistPreference() async {
    final value = selectedRepeatArea;
    if (value == null || value.trim().isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      FocusDomains.productPreferenceKey,
      selectedFocusDomainIds,
    );
    await prefs.setStringList(
      FocusDomains.preferenceKey,
      selectedFocusDomainIds,
    );
    await prefs.setString(FocusDomains.legacyRepeatAreaKey, value);
    await prefs.setString(repeatAreaPreferenceKey, value);
    onFocusDomainsPersisted?.call(
      List<String>.unmodifiable(selectedFocusDomainIds),
    );
    AppDataMutationBus.publish(
      kind: AppDataMutationKind.focusDomains,
      reason: 'onboarding_focus_domains_changed',
    );
  }
}
