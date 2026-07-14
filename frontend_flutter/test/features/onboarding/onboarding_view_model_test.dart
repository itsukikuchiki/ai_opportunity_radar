import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_opportunity_radar/core/api/api_client.dart';
import 'package:ai_opportunity_radar/core/preferences/focus_domains.dart';
import 'package:ai_opportunity_radar/features/onboarding/onboarding_view_model.dart';

void main() {
  test('complete persists local onboarding preferences when remote sync fails',
      () async {
    SharedPreferences.setMockInitialValues({});
    List<String>? persistedFocusIds;
    final viewModel = OnboardingViewModel(
      _FailingApiClient(),
      onFocusDomainsPersisted: (values) => persistedFocusIds = values,
    );

    viewModel.updateFocusDomains(const [
      'relationship_connection',
      'growth_plan',
    ]);

    await viewModel.complete();
    await Future<void>.delayed(Duration.zero);

    final prefs = await SharedPreferences.getInstance();
    expect(viewModel.submitting, isFalse);
    expect(viewModel.errorCode, isNull);
    expect(
      prefs.getStringList(FocusDomains.productPreferenceKey),
      ['relationship_connection', 'growth_plan'],
    );
    expect(
      prefs.getStringList(FocusDomains.preferenceKey),
      ['relationship_connection', 'growth_plan'],
    );
    expect(
      prefs.getString(OnboardingViewModel.repeatAreaPreferenceKey),
      'relationship_connection',
    );
    expect(
      prefs.getString(FocusDomains.legacyRepeatAreaKey),
      'relationship_connection',
    );
    expect(
      persistedFocusIds,
      ['relationship_connection', 'growth_plan'],
    );
  });
}

class _FailingApiClient extends ApiClient {
  _FailingApiClient() : super(baseUrl: 'http://127.0.0.1:1', userId: 'test');

  @override
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    throw Exception('offline');
  }
}
