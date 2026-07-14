class LegacyFallbackMonitor {
  static const opportunitySnapshotLifeExperiment =
      'legacy_opportunity_snapshot_read_count';
  static const snapshotAiField = 'legacy_snapshot_ai_field_read_count';
  static const signalInclusionField =
      'legacy_signal_inclusion_field_read_count';
  static const signalPrivacyField = 'legacy_signal_privacy_field_read_count';
  static const capturesRawRead = 'legacy_captures_raw_read_count';
  static const capturesMirror = 'legacy_captures_mirror_count';
  static const backupServiceConstruct = 'legacy_backup_service_construct_count';
  static const backupExport = 'legacy_backup_export_count';
  static const backupImport = 'legacy_backup_import_count';

  static final Map<String, int> _counts = {
    opportunitySnapshotLifeExperiment: 0,
    snapshotAiField: 0,
    signalInclusionField: 0,
    signalPrivacyField: 0,
    capturesRawRead: 0,
    capturesMirror: 0,
    backupServiceConstruct: 0,
    backupExport: 0,
    backupImport: 0,
  };

  static void record(String counter) {
    _counts[counter] = (_counts[counter] ?? 0) + 1;
  }

  static Map<String, int> snapshot() {
    return Map<String, int>.unmodifiable(_counts);
  }

  static void reset() {
    for (final key in _counts.keys.toList()) {
      _counts[key] = 0;
    }
  }
}
