import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../api/repositories/cloud_backup_repository.dart';
import 'backup_bundle_repository.dart';

class CloudBackupSyncService {
  static const String accountSessionTokenKey = 'cloud_account_session_token';
  static const String latestBackupVersionKey = 'cloud_latest_backup_version';
  static const String lastAutoBackupAtKey = 'cloud_last_auto_backup_at';

  final BackupBundleRepository backupBundleRepository;
  final CloudBackupRepository cloudBackupRepository;
  final SharedPreferences preferences;
  final String localUserId;
  final String deviceId;
  final Duration minInterval;

  const CloudBackupSyncService({
    required this.backupBundleRepository,
    required this.cloudBackupRepository,
    required this.preferences,
    required this.localUserId,
    required this.deviceId,
    this.minInterval = const Duration(minutes: 10),
  });

  void markDataChanged({bool force = false}) {
    unawaited(uploadIfSignedIn(force: force));
  }

  Future<bool> uploadIfSignedIn({bool force = false}) async {
    final session = preferences.getString(accountSessionTokenKey);
    if (session == null || session.trim().isEmpty) return false;
    if (!force && !_canUploadNow()) return false;

    final bundle = await backupBundleRepository.exportBundle(
      localUserId: localUserId,
      deviceId: deviceId,
    );
    final uploaded = await cloudBackupRepository.uploadBackup(
      sessionToken: session,
      bundle: bundle,
    );
    await preferences.setString(
      latestBackupVersionKey,
      uploaded.backupVersion,
    );
    await preferences.setString(
      lastAutoBackupAtKey,
      DateTime.now().toUtc().toIso8601String(),
    );
    return true;
  }

  bool _canUploadNow() {
    final raw = preferences.getString(lastAutoBackupAtKey);
    final last = raw == null ? null : DateTime.tryParse(raw);
    if (last == null) return true;
    return DateTime.now().toUtc().difference(last.toUtc()) >= minInterval;
  }
}
