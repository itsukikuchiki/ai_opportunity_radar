import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/repositories/cloud_backup_repository.dart';
import '../../../core/backup/backup_bundle_repository.dart';
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
  static const String accountSessionTokenKey = 'cloud_account_session_token';
  static const String accountIdKey = 'cloud_account_id';
  static const String latestBackupVersionKey = 'cloud_latest_backup_version';

  final ApiClient? apiClient;
  final BackupBundleRepository? backupBundleRepository;
  final CloudBackupRepository? cloudBackupRepository;
  final String? localUserId;
  final String? deviceId;

  String? selectedRepeatArea;
  String selectedResponseStyle = 'gentle';
  Map<String, UsageQuotaViewData> usageQuotas = const {};
  String? cloudAccountId;
  String? cloudSessionToken;
  String? latestBackupVersion;
  bool loading = true;
  bool saving = false;
  bool usageLoading = false;
  bool cloudLoading = false;
  String? errorMessage;
  String? cloudMessage;

  MeViewModel([
    this.apiClient,
    this.backupBundleRepository,
    this.cloudBackupRepository,
    this.localUserId,
    this.deviceId,
  ]) {
    load();
  }

  bool get cloudBackupAvailable =>
      backupBundleRepository != null &&
      cloudBackupRepository != null &&
      (localUserId ?? '').trim().isNotEmpty &&
      (deviceId ?? '').trim().isNotEmpty;

  bool get cloudSignedIn => (cloudSessionToken ?? '').trim().isNotEmpty;

  Future<void> load() async {
    loading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      selectedRepeatArea = prefs.getString(repeatAreaPreferenceKey) ??
          prefs.getString(OnboardingViewModel.repeatAreaPreferenceKey) ??
          prefs.getString(fallbackRepeatAreaPreferenceKey);
      selectedResponseStyle =
          prefs.getString(responseStylePreferenceKey) ?? 'gentle';
      cloudAccountId = prefs.getString(accountIdKey);
      cloudSessionToken = prefs.getString(accountSessionTokenKey);
      latestBackupVersion = prefs.getString(latestBackupVersionKey);
      await _loadUsageSummary();
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> reload() => load();

  Future<void> _loadUsageSummary() async {
    final client = apiClient;
    if (client == null) return;
    usageLoading = true;
    notifyListeners();
    try {
      final response = await client.getJson('/api/v1/usage/summary');
      final data = (response['data'] as Map<String, dynamic>?) ?? response;
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
    } catch (_) {
      usageQuotas = const {};
    } finally {
      usageLoading = false;
      notifyListeners();
    }
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

  Future<bool> signInWithAppleAndBackupNow() async {
    if (!cloudBackupAvailable) {
      cloudMessage = 'cloud_backup_unavailable';
      notifyListeners();
      return false;
    }

    cloudLoading = true;
    cloudMessage = null;
    notifyListeners();

    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
        ],
      );
      final appleSubject =
          credential.userIdentifier ?? credential.identityToken ?? '';
      if (appleSubject.trim().isEmpty) {
        throw StateError('Missing Apple account identifier');
      }

      final session = await cloudBackupRepository!.signInWithApple(
        appleUserId: appleSubject,
        identityToken: credential.identityToken,
        localUserId: localUserId!,
        deviceId: deviceId!,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(accountIdKey, session.accountId);
      await prefs.setString(accountSessionTokenKey, session.sessionToken);
      cloudAccountId = session.accountId;
      cloudSessionToken = session.sessionToken;

      final uploaded = await _uploadBackupWithSession(session.sessionToken);
      cloudMessage = uploaded ? 'cloud_backup_uploaded' : 'cloud_backup_failed';
      return uploaded;
    } catch (e) {
      cloudMessage = e.toString();
      return false;
    } finally {
      cloudLoading = false;
      notifyListeners();
    }
  }

  Future<bool> uploadCloudBackupNow() async {
    final session = cloudSessionToken;
    if (!cloudBackupAvailable || session == null || session.trim().isEmpty) {
      cloudMessage = 'cloud_backup_sign_in_required';
      notifyListeners();
      return false;
    }

    cloudLoading = true;
    cloudMessage = null;
    notifyListeners();

    try {
      final uploaded = await _uploadBackupWithSession(session);
      cloudMessage = uploaded ? 'cloud_backup_uploaded' : 'cloud_backup_failed';
      return uploaded;
    } catch (e) {
      cloudMessage = e.toString();
      return false;
    } finally {
      cloudLoading = false;
      notifyListeners();
    }
  }

  Future<bool> restoreLatestCloudBackup() async {
    final session = cloudSessionToken;
    if (!cloudBackupAvailable || session == null || session.trim().isEmpty) {
      cloudMessage = 'cloud_backup_sign_in_required';
      notifyListeners();
      return false;
    }

    cloudLoading = true;
    cloudMessage = null;
    notifyListeners();

    try {
      final latest = await cloudBackupRepository!.fetchLatestBackup(
        sessionToken: session,
      );
      if (latest == null || latest.payload.isEmpty) {
        cloudMessage = 'cloud_backup_empty';
        return false;
      }
      final result = await backupBundleRepository!.importBundle(latest.payload);
      await cloudBackupRepository!.confirmRestore(
        sessionToken: session,
        backupId: latest.id,
        deviceId: deviceId!,
      );
      cloudMessage = result.importedRows > 0
          ? 'cloud_backup_restored'
          : 'cloud_backup_empty';
      return result.importedRows > 0;
    } catch (e) {
      cloudMessage = e.toString();
      return false;
    } finally {
      cloudLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteAccountAndAllData() async {
    if (backupBundleRepository == null) {
      cloudMessage = 'account_delete_unavailable';
      notifyListeners();
      return false;
    }

    cloudLoading = true;
    cloudMessage = null;
    notifyListeners();

    try {
      final session = cloudSessionToken;
      if (cloudBackupRepository != null &&
          session != null &&
          session.trim().isNotEmpty) {
        await cloudBackupRepository!.deleteAccount(sessionToken: session);
      }

      await backupBundleRepository!.deleteAllLocalData();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(accountIdKey);
      await prefs.remove(accountSessionTokenKey);
      await prefs.remove(latestBackupVersionKey);
      cloudAccountId = null;
      cloudSessionToken = null;
      latestBackupVersion = null;
      usageQuotas = const {};
      selectedRepeatArea = null;
      selectedResponseStyle = 'gentle';
      cloudMessage = 'account_deleted';
      return true;
    } catch (e) {
      cloudMessage = e.toString();
      return false;
    } finally {
      cloudLoading = false;
      notifyListeners();
    }
  }

  Future<bool> _uploadBackupWithSession(String sessionToken) async {
    final bundle = await backupBundleRepository!.exportBundle(
      localUserId: localUserId!,
      deviceId: deviceId!,
    );
    final uploaded = await cloudBackupRepository!.uploadBackup(
      sessionToken: sessionToken,
      bundle: bundle,
    );
    latestBackupVersion = uploaded.backupVersion;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(latestBackupVersionKey, uploaded.backupVersion);
    return true;
  }
}
