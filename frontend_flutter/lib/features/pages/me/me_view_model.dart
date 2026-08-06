import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/repositories/cloud_backup_repository.dart';
import '../../../core/backup/backup_bundle_repository.dart';
import '../../../core/backup/cloud_backup_sync_service.dart';
import '../../../core/local/local_database.dart';
import '../../../core/notifications/signal_reminder_repository.dart';
import '../../../core/preferences/focus_domains.dart';
import '../../../core/state/app_data_refresh_coordinator.dart';
import '../../onboarding/onboarding_view_model.dart';

class UsageQuotaViewData {
  final String featureKey;
  final String periodType;
  final int used;
  final int? limit;

  const UsageQuotaViewData({
    required this.featureKey,
    required this.periodType,
    required this.used,
    required this.limit,
  });

  String get displayValue => limit == null ? '$used' : '$used/$limit';
}

class MeViewModel extends ChangeNotifier {
  static const String repeatAreaPreferenceKey = 'repeat_area_preference';
  static const String fallbackRepeatAreaPreferenceKey = 'selected_repeat_area';
  static const String responseStylePreferenceKey = 'response_style_preference';
  static const String profilePhotoPathPreferenceKey = 'me_profile_photo_path';
  static const String profileDisplayNamePreferenceKey =
      'me_profile_display_name';
  static const String lifeDirectionPreferenceKey = 'me_life_direction';
  static const String lifeDirectionCreatedAtPreferenceKey =
      'me_life_direction_created_at';
  static const int maxProfilePhotoBytes = 2 * 1024 * 1024;

  final ApiClient? apiClient;
  final LocalDatabase? localDatabase;

  String? selectedRepeatArea;
  List<String> selectedFocusDomainIds = const [];
  String selectedResponseStyle = 'gentle';
  Map<String, UsageQuotaViewData> usageQuotas = const {};
  String? profilePhotoPath;
  String? profileDisplayName;
  String? lifeDirection;
  DateTime? lifeDirectionCreatedAt;
  String? usageEntitlement;
  DateTime? usageLastUpdatedAt;
  bool hasCloudAccount = false;
  bool loading = true;
  bool saving = false;
  bool usageLoading = false;
  bool deletingData = false;
  bool usageLoadFailed = false;
  String? errorMessage;
  Future<void>? _loadInFlight;

  MeViewModel([this.apiClient, this.localDatabase]) {
    load();
  }

  Future<void> load() {
    final activeLoad = _loadInFlight;
    if (activeLoad != null) return activeLoad;

    final future = _performLoad();
    _loadInFlight = future;
    future.whenComplete(() {
      if (identical(_loadInFlight, future)) {
        _loadInFlight = null;
      }
    });
    return future;
  }

  Future<void> _performLoad() async {
    loading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final rawFocusIds =
          prefs.getStringList(FocusDomains.productPreferenceKey) ??
              prefs.getStringList(FocusDomains.preferenceKey);
      final rawRepeatArea = prefs.getString(repeatAreaPreferenceKey) ??
          prefs.getString(OnboardingViewModel.repeatAreaPreferenceKey) ??
          prefs.getString(fallbackRepeatAreaPreferenceKey);
      _setFocusDomains([
        ...?rawFocusIds,
        rawRepeatArea,
      ]);
      selectedResponseStyle =
          prefs.getString(responseStylePreferenceKey) ?? 'gentle';
      profilePhotoPath = prefs.getString(profilePhotoPathPreferenceKey);
      profileDisplayName = _nonEmpty(
        prefs.getString(profileDisplayNamePreferenceKey),
      );
      lifeDirection = _nonEmpty(prefs.getString(lifeDirectionPreferenceKey));
      lifeDirectionCreatedAt = DateTime.tryParse(
        prefs.getString(lifeDirectionCreatedAtPreferenceKey) ?? '',
      );
      hasCloudAccount = _nonEmpty(
            prefs.getString(CloudBackupSyncService.accountSessionTokenKey),
          ) !=
          null;
      await _loadUsageSummary();
    } catch (_) {
      errorMessage = 'profile_load_failed';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> reload() => load();

  /// Keeps the long-lived Me page state aligned after onboarding persists a
  /// new selection, without reloading usage data or writing preferences twice.
  void applyPersistedFocusDomains(List<String> values) {
    _setFocusDomains(values);
    notifyListeners();
  }

  void _setFocusDomains(Iterable<String?> values) {
    selectedFocusDomainIds = FocusDomains.normalizeIds(values);
    selectedRepeatArea =
        selectedFocusDomainIds.isEmpty ? null : selectedFocusDomainIds.first;
  }

  Future<void> _loadUsageSummary() async {
    final client = apiClient;
    if (client == null) return;
    usageLoading = true;
    usageLoadFailed = false;
    notifyListeners();
    try {
      final response = await client.getJson('/api/v1/usage/summary');
      final data = (response['data'] as Map<String, dynamic>?) ?? response;
      usageEntitlement = data['entitlement']?.toString();
      final rawQuotas = (data['quotas'] as List?) ?? const [];
      final parsed = <String, UsageQuotaViewData>{};
      for (final item in rawQuotas.whereType<Map>()) {
        final featureKey = item['feature_key']?.toString() ?? '';
        if (featureKey.isEmpty) continue;
        parsed[featureKey] = UsageQuotaViewData(
          featureKey: featureKey,
          periodType: item['period_type']?.toString() ?? 'monthly',
          used: (item['used'] as num?)?.toInt() ?? 0,
          limit: (item['limit'] as num?)?.toInt(),
        );
      }
      usageQuotas = parsed;
      usageLastUpdatedAt = DateTime.now();
    } catch (_) {
      // Keep the last known values visible; a network error must not turn
      // real usage into a misleading zero/empty state.
      usageLoadFailed = true;
    } finally {
      usageLoading = false;
      notifyListeners();
    }
  }

  Future<void> reloadUsage() => _loadUsageSummary();

  bool usageMatchesLocalEntitlement(bool localPremium) {
    final remote = usageEntitlement;
    if (remote == null || remote.isEmpty) return true;
    return (remote == 'pro') == localPremium;
  }

  Future<bool> updateResponseStyle(String value) async {
    saving = true;
    errorMessage = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(responseStylePreferenceKey, value);
      selectedResponseStyle = value;
      return true;
    } catch (_) {
      errorMessage = 'response_style_save_failed';
      return false;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<bool> updateRepeatArea(String value) async {
    return updateFocusDomains([value]);
  }

  Future<bool> updateFocusDomains(List<String> values) async {
    saving = true;
    errorMessage = null;
    notifyListeners();

    try {
      final normalized = FocusDomains.normalizeIds(values);
      final nextValues = normalized;
      final primary = nextValues.isEmpty ? null : nextValues.first;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(FocusDomains.productPreferenceKey, nextValues);
      await prefs.setStringList(FocusDomains.preferenceKey, nextValues);
      if (primary == null) {
        await prefs.remove(repeatAreaPreferenceKey);
        await prefs.remove(OnboardingViewModel.repeatAreaPreferenceKey);
      } else {
        await prefs.setString(repeatAreaPreferenceKey, primary);
        await prefs.setString(
          OnboardingViewModel.repeatAreaPreferenceKey,
          primary,
        );
      }
      _setFocusDomains(nextValues);
      AppDataMutationBus.publish(
        kind: AppDataMutationKind.focusDomains,
        reason: 'me_focus_domains_changed',
      );
      return true;
    } catch (_) {
      errorMessage = 'focus_domains_save_failed';
      return false;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<bool> updateProfilePhotoPath({
    required String path,
    required int sizeBytes,
  }) async {
    saving = true;
    errorMessage = null;
    notifyListeners();

    try {
      if (sizeBytes > maxProfilePhotoBytes) {
        errorMessage = 'profile_photo_too_large';
        return false;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(profilePhotoPathPreferenceKey, path);
      profilePhotoPath = path;
      return true;
    } catch (_) {
      errorMessage = 'profile_photo_save_failed';
      return false;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<bool> updateProfile({
    required String displayName,
    required String direction,
  }) async {
    saving = true;
    errorMessage = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final normalizedName = displayName.trim();
      final normalizedDirection = direction.trim();
      if (normalizedName.isEmpty) {
        await prefs.remove(profileDisplayNamePreferenceKey);
      } else {
        await prefs.setString(profileDisplayNamePreferenceKey, normalizedName);
      }
      if (normalizedDirection.isEmpty) {
        await prefs.remove(lifeDirectionPreferenceKey);
        await prefs.remove(lifeDirectionCreatedAtPreferenceKey);
        lifeDirectionCreatedAt = null;
      } else {
        final createdAt = lifeDirectionCreatedAt ?? DateTime.now();
        await prefs.setString(lifeDirectionPreferenceKey, normalizedDirection);
        await prefs.setString(
          lifeDirectionCreatedAtPreferenceKey,
          createdAt.toUtc().toIso8601String(),
        );
        lifeDirectionCreatedAt = createdAt;
      }
      profileDisplayName = normalizedName.isEmpty ? null : normalizedName;
      lifeDirection = normalizedDirection.isEmpty ? null : normalizedDirection;
      return true;
    } catch (_) {
      errorMessage = 'profile_save_failed';
      return false;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<bool> deleteMyData() async {
    if (deletingData) return false;
    final database = localDatabase;
    if (database == null) {
      errorMessage = 'local_delete_unavailable';
      notifyListeners();
      return false;
    }

    deletingData = true;
    errorMessage = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final session = _nonEmpty(
        prefs.getString(CloudBackupSyncService.accountSessionTokenKey),
      );
      if (session != null) {
        final client = apiClient;
        if (client == null) {
          errorMessage = 'account_delete_unavailable';
          return false;
        }
        await CloudBackupRepository(client).deleteAccount(
          sessionToken: session,
        );
      }

      final oldPhotoPath = profilePhotoPath;
      final signalReminderRepository = SignalReminderRepository(
        preferences: prefs,
      );
      await BackupBundleRepository(
        localDatabase: database,
        preferences: prefs,
        signalReminderRepository: signalReminderRepository,
      ).deleteAllLocalData();
      if (oldPhotoPath != null && oldPhotoPath.trim().isNotEmpty) {
        final file = File(oldPhotoPath);
        if (await file.exists()) await file.delete();
      }

      selectedRepeatArea = null;
      selectedFocusDomainIds = const [];
      selectedResponseStyle = 'gentle';
      usageQuotas = const {};
      usageEntitlement = null;
      profilePhotoPath = null;
      profileDisplayName = null;
      lifeDirection = null;
      lifeDirectionCreatedAt = null;
      hasCloudAccount = false;
      AppDataMutationBus.publish(
        kind: AppDataMutationKind.signalCard,
        reason: 'all_user_data_deleted',
      );
      return true;
    } catch (_) {
      errorMessage =
          hasCloudAccount ? 'account_delete_failed' : 'local_delete_failed';
      return false;
    } finally {
      deletingData = false;
      notifyListeners();
    }
  }

  String? _nonEmpty(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
