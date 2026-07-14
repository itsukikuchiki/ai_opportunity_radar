import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_opportunity_radar/core/api/api_client.dart';
import 'package:ai_opportunity_radar/core/preferences/focus_domains.dart';
import 'package:ai_opportunity_radar/features/pages/me/me_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('MeViewModel can load and update response style preference', () async {
    SharedPreferences.setMockInitialValues({
      'repeat_area_preference': 'emotion_stress',
      'response_style_preference': 'gentle',
    });

    final vm = MeViewModel();
    await vm.load();

    expect(vm.selectedResponseStyle, 'gentle');

    final ok = await vm.updateResponseStyle('direct');
    expect(ok, true);
    expect(vm.selectedResponseStyle, 'direct');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('response_style_preference'), 'direct');
  });

  test('MeViewModel migrates legacy focus area and saves new focus domains',
      () async {
    SharedPreferences.setMockInitialValues({
      'repeat_area_preference': 'emotion_stress',
    });

    final vm = MeViewModel();
    await vm.load();

    expect(vm.selectedRepeatArea, 'emotional_stability');
    expect(vm.selectedFocusDomainIds, contains('emotional_stability'));

    final ok = await vm.updateFocusDomains([
      'relationship_connection',
      'creative_expression',
    ]);

    expect(ok, true);
    expect(vm.selectedRepeatArea, 'relationship_connection');
    expect(vm.selectedFocusDomainIds, [
      'relationship_connection',
      'creative_expression',
    ]);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(FocusDomains.productPreferenceKey), [
      'relationship_connection',
      'creative_expression',
    ]);
    expect(prefs.getStringList(FocusDomains.preferenceKey), [
      'relationship_connection',
      'creative_expression',
    ]);
    expect(
        prefs.getString('repeat_area_preference'), 'relationship_connection');
  });

  test('MeViewModel saves profile photo path within size limit', () async {
    SharedPreferences.setMockInitialValues({});

    final vm = MeViewModel();
    await vm.load();

    final ok = await vm.updateProfilePhotoPath(
      path: '/tmp/avatar.jpg',
      sizeBytes: MeViewModel.maxProfilePhotoBytes,
    );

    expect(ok, true);
    expect(vm.profilePhotoPath, '/tmp/avatar.jpg');

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(MeViewModel.profilePhotoPathPreferenceKey),
      '/tmp/avatar.jpg',
    );
  });

  test('MeViewModel applies persisted onboarding focus domains in memory',
      () async {
    SharedPreferences.setMockInitialValues({
      FocusDomains.productPreferenceKey: FocusDomains.defaultIds,
    });

    final vm = MeViewModel();
    await vm.load();
    var notifications = 0;
    vm.addListener(() => notifications += 1);

    vm.applyPersistedFocusDomains(const [
      'relationship_connection',
      'creative_expression',
      'relationship_connection',
      'unknown',
    ]);

    expect(vm.selectedFocusDomainIds, [
      'relationship_connection',
      'creative_expression',
    ]);
    expect(vm.selectedRepeatArea, 'relationship_connection');
    expect(notifications, 1);
  });

  test('MeViewModel rejects oversized profile photo', () async {
    SharedPreferences.setMockInitialValues({});

    final vm = MeViewModel();
    await vm.load();

    final ok = await vm.updateProfilePhotoPath(
      path: '/tmp/huge-avatar.jpg',
      sizeBytes: MeViewModel.maxProfilePhotoBytes + 1,
    );

    expect(ok, false);
    expect(vm.profilePhotoPath, isNull);
    expect(vm.errorMessage, 'profile_photo_too_large');
  });

  test('MeViewModel keeps profile empty until the user saves real values',
      () async {
    SharedPreferences.setMockInitialValues({});

    final vm = MeViewModel();
    await vm.load();

    expect(vm.profileDisplayName, isNull);
    expect(vm.lifeDirection, isNull);
    expect(vm.lifeDirectionCreatedAt, isNull);

    final saved = await vm.updateProfile(
      displayName: 'Mina',
      direction: '给恢复和创造都留出空间。',
    );

    expect(saved, true);
    expect(vm.profileDisplayName, 'Mina');
    expect(vm.lifeDirection, '给恢复和创造都留出空间。');
    expect(vm.lifeDirectionCreatedAt, isNotNull);

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(MeViewModel.profileDisplayNamePreferenceKey),
      'Mina',
    );
    expect(
      prefs.getString(MeViewModel.lifeDirectionPreferenceKey),
      '给恢复和创造都留出空间。',
    );
  });

  test('MeViewModel keeps real quota values when a later usage refresh fails',
      () async {
    SharedPreferences.setMockInitialValues({});
    final api = _UsageApiClient();
    final vm = MeViewModel(api);
    await vm.load();

    expect(vm.usageEntitlement, 'pro');
    expect(vm.usageLoadFailed, isFalse);
    expect(vm.usageQuotas['l3_reflect']?.used, 4);
    expect(vm.usageQuotas['l3_reflect']?.limit, 12);
    expect(vm.usageQuotas['l3_reflect']?.displayValue, '4/12');

    api.fail = true;
    await vm.reloadUsage();

    expect(vm.usageLoadFailed, isTrue);
    expect(vm.usageEntitlement, 'pro');
    expect(vm.usageQuotas['l3_reflect']?.displayValue, '4/12');
    expect(vm.usageMatchesLocalEntitlement(true), isTrue);
    expect(vm.usageMatchesLocalEntitlement(false), isFalse);
  });
}

class _UsageApiClient extends ApiClient {
  bool fail = false;

  _UsageApiClient()
      : super(
          baseUrl: 'https://example.invalid',
          userId: 'me-usage-test',
        );

  @override
  Future<Map<String, dynamic>> getJson(String path) async {
    expect(path, '/api/v1/usage/summary');
    if (fail) throw StateError('offline');
    return const {
      'data': {
        'entitlement': 'pro',
        'quotas': [
          {
            'feature_key': 'l3_reflect',
            'period_type': 'monthly',
            'used': 4,
            'limit': 12,
          },
        ],
      },
    };
  }
}
