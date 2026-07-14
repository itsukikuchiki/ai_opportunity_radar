import '../api_client.dart';

class CloudBackupRepository {
  final ApiClient apiClient;

  const CloudBackupRepository(this.apiClient);

  Future<CloudAccountSession> signInWithApple({
    required String appleUserId,
    String? identityToken,
    required String localUserId,
    required String deviceId,
  }) async {
    final response = await apiClient.postJson(
      '/api/v1/auth/apple',
      {
        'apple_user_id': appleUserId,
        'identity_token': identityToken,
        'local_user_id': localUserId,
        'device_id': deviceId,
      },
    );
    final data = (response['data'] as Map<String, dynamic>?) ?? response;
    return CloudAccountSession(
      accountId: data['account_id']?.toString() ?? '',
      sessionToken: data['session_token']?.toString() ?? '',
    );
  }

  Future<void> bindLocalUser({
    required String sessionToken,
    required String localUserId,
  }) async {
    await _postWithSession(
      '/api/v1/account/bind-local-user',
      sessionToken,
      {'local_user_id': localUserId},
    );
  }

  Future<CloudBackupMetadata> uploadBackup({
    required String sessionToken,
    required Map<String, dynamic> bundle,
  }) async {
    final response = await _postWithSession(
      '/api/v1/backup/upload',
      sessionToken,
      {
        'schema_version': bundle['schema_version'] ?? 1,
        'backup_version': bundle['backup_version']?.toString() ?? '',
        'device_id': bundle['device_id']?.toString(),
        'payload': bundle,
        'counts': bundle['counts'] ?? const {},
      },
    );
    final data = (response['data'] as Map<String, dynamic>?) ?? response;
    return CloudBackupMetadata.fromJson(data);
  }

  Future<CloudBackupMetadata?> fetchLatestBackup({
    required String sessionToken,
  }) async {
    final response =
        await _getWithSession('/api/v1/backup/latest', sessionToken);
    final data = response['data'];
    if (data is! Map<String, dynamic>) return null;
    return CloudBackupMetadata.fromJson(data);
  }

  Future<void> confirmRestore({
    required String sessionToken,
    required String backupId,
    required String deviceId,
  }) async {
    await _postWithSession(
      '/api/v1/backup/restore-confirmed',
      sessionToken,
      {
        'backup_id': backupId,
        'device_id': deviceId,
      },
    );
  }

  Future<int> deleteCloudBackup({
    required String sessionToken,
  }) async {
    final decoded = await apiClient.deleteJsonWithHeaders(
      '/api/v1/backup',
      additionalHeaders: _sessionHeaders(sessionToken),
    );
    final data = (decoded['data'] as Map<String, dynamic>?) ?? decoded;
    return (data['deleted'] as num?)?.toInt() ?? 0;
  }

  Future<Map<String, int>> deleteAccount({
    required String sessionToken,
  }) async {
    final decoded = await apiClient.deleteJsonWithHeaders(
      '/api/v1/account',
      additionalHeaders: _sessionHeaders(sessionToken),
    );
    final data = (decoded['data'] as Map<String, dynamic>?) ?? decoded;
    final deleted = (data['deleted'] as Map?) ?? const {};
    return {
      for (final entry in deleted.entries)
        entry.key.toString(): (entry.value as num?)?.toInt() ?? 0,
    };
  }

  Future<Map<String, dynamic>> _getWithSession(
    String path,
    String sessionToken,
  ) {
    return apiClient.getJsonWithHeaders(
      path,
      additionalHeaders: _sessionHeaders(sessionToken),
    );
  }

  Future<Map<String, dynamic>> _postWithSession(
    String path,
    String sessionToken,
    Map<String, dynamic> body,
  ) {
    return apiClient.postJsonWithHeaders(
      path,
      body,
      additionalHeaders: _sessionHeaders(sessionToken),
    );
  }

  Map<String, String> _sessionHeaders(String sessionToken) {
    return {
      'X-Account-Session': sessionToken,
    };
  }
}

class CloudAccountSession {
  final String accountId;
  final String sessionToken;

  const CloudAccountSession({
    required this.accountId,
    required this.sessionToken,
  });
}

class CloudBackupMetadata {
  final String id;
  final String backupVersion;
  final String? deviceId;
  final Map<String, dynamic> payload;
  final Map<String, dynamic> counts;
  final DateTime? createdAt;

  const CloudBackupMetadata({
    required this.id,
    required this.backupVersion,
    required this.deviceId,
    required this.payload,
    required this.counts,
    required this.createdAt,
  });

  factory CloudBackupMetadata.fromJson(Map<String, dynamic> json) {
    return CloudBackupMetadata(
      id: json['id']?.toString() ?? '',
      backupVersion: json['backup_version']?.toString() ?? '',
      deviceId: json['device_id']?.toString(),
      payload: (json['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
      counts: (json['counts'] as Map?)?.cast<String, dynamic>() ?? const {},
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}
