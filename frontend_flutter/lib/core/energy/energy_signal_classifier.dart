import '../models/energy_budget_models.dart';
import '../models/today_models.dart';

/// Canonical, write-free projection from one Signal Card to one energy state.
///
/// Every eligible Signal resolves to exactly one of the five states. The
/// classifier is intentionally shared by Today, Weekly, Journey and Pro so a
/// Signal cannot change meaning between pages.
class EnergySignalClassifier {
  const EnergySignalClassifier();

  EnergySignalState classify(
    RecentSignalModel signal, {
    DateTime? now,
  }) {
    if (signal.sourceType == 'time_use' &&
        !isCompletedTimeUse(signal, now: now)) {
      return EnergySignalState.steady;
    }

    final explicitLevel = explicitEnergyLevel(signal);
    if (explicitLevel != null) {
      if (explicitLevel <= 0) return EnergySignalState.draining;
      if (explicitLevel >= 2) return EnergySignalState.ease;
      return EnergySignalState.steady;
    }

    final legacyEffect = signal.rawPayloadJson['energy_effect']
            ?.toString()
            .trim()
            .toLowerCase() ??
        '';
    switch (legacyEffect) {
      case 'draining':
        return EnergySignalState.draining;
      case 'restoring':
      case 'recovery':
        return EnergySignalState.recovery;
      case 'ease':
      case 'resourced':
        return EnergySignalState.ease;
      case 'neutral':
      case 'steady':
        return EnergySignalState.steady;
    }

    final serverState = signal.energyState?.trim().toLowerCase();
    if (serverState != null &&
        EnergySignalState.values
            .any((state) => state.storageValue == serverState)) {
      return EnergySignalState.fromStorage(serverState);
    }

    final energyLoad = (signal.energyLoad ?? '').trim().toLowerCase();
    final friction = (signal.friction ?? '').trim().toLowerCase();
    final positive = (signal.positiveSignal ?? '').trim().toLowerCase();
    final content = signal.content.trim().toLowerCase();
    final stages = signal.linkedLifeChainStages
        .map((stage) => stage.trim().toLowerCase())
        .toSet();

    final hasBoundaryBufferMarker =
        _containsAny(energyLoad, const ['boundary_buffer', 'buffer']) ||
            _containsAny(
              friction,
              const [
                'boundary',
                'self_boundary',
                'boundary_load',
                'overcommit',
                'capacity_limit',
              ],
            ) ||
            stages.any(
              const {
                'boundary',
                'boundary_load',
                'buffer',
                'boundary_buffer',
              }.contains,
            ) ||
            _containsAny(
              content,
              const [
                '留出余地',
                '留一点余地',
                '留了余地',
                '留出空间',
                '留了空间',
                '留出缓冲',
                '留了缓冲',
                '设了边界',
                '守住边界',
                '拒绝了',
                '说了不',
                'made room',
                'left room',
                'left a buffer',
                'set a boundary',
                'said no',
                '余白を残',
                '境界を守',
                '断った',
              ],
            );
    if (hasBoundaryBufferMarker) return EnergySignalState.boundaryBuffer;

    final hasRecoveryMarker = _containsAny(
          energyLoad,
          const ['restore', 'restoring', 'restorative', 'recovery'],
        ) ||
        stages.contains('recovery') ||
        _containsAny(
          content,
          const [
            '恢复了一点',
            '恢复过来',
            '缓过来',
            '补回精力',
            '休息后',
            '散步后',
            '睡了一觉',
            '充上电',
            'recovered',
            'felt restored',
            'after resting',
            'after a walk',
            '回復した',
            '休んだ後',
            '散歩の後',
          ],
        );
    if (hasRecoveryMarker) return EnergySignalState.recovery;

    final hasDrainingMarker = _containsAny(
          energyLoad,
          const ['drain', 'draining', 'high_drain', 'exhaust'],
        ) ||
        stages.contains('energy_drain') ||
        _containsAny(
          content,
          const [
            '很耗力',
            '有点耗力',
            '特别消耗',
            '精疲力尽',
            '很累',
            '疲惫',
            'exhausted',
            'draining',
            'worn out',
            '疲れた',
            '消耗した',
          ],
        );
    if (hasDrainingMarker) return EnergySignalState.draining;

    final hasEaseMarker = _containsAny(
          energyLoad,
          const ['ease', 'easy', 'light', 'resourced'],
        ) ||
        positive.isNotEmpty ||
        _containsAny(
          content,
          const [
            '有余力',
            '很轻松',
            '比较轻松',
            '很顺畅',
            '精力很足',
            '状态很好',
            'felt easy',
            'felt light',
            'had energy left',
            'went smoothly',
            '余力がある',
            '楽だった',
            '順調だった',
          ],
        );
    if (hasEaseMarker) return EnergySignalState.ease;

    return EnergySignalState.steady;
  }

  int? explicitEnergyLevel(RecentSignalModel signal) {
    final raw = signal.rawPayloadJson['energy_level'];
    final level = switch (raw) {
      final int value => value,
      final num value when value == value.roundToDouble() => value.toInt(),
      _ => int.tryParse(raw?.toString() ?? ''),
    };
    if (level == null || level < 0 || level > 2) return null;
    return level;
  }

  bool isCompletedTimeUse(
    RecentSignalModel signal, {
    DateTime? now,
  }) {
    if (signal.sourceType != 'time_use') return false;
    final status = signal.rawPayloadJson['record_status']
            ?.toString()
            .trim()
            .toLowerCase() ??
        '';
    final schemaVersionRaw = signal.rawPayloadJson['schema_version'];
    final schemaVersion = schemaVersionRaw is num
        ? schemaVersionRaw.toInt()
        : int.tryParse(schemaVersionRaw?.toString() ?? '');
    final legacyEffect = signal.rawPayloadJson['energy_effect']
            ?.toString()
            .trim()
            .toLowerCase() ??
        '';
    final explicitlyCompleted =
        const {'completed', 'occurred', 'actual'}.contains(status);
    final legacyCompletedWithoutStatus = status.isEmpty &&
        (schemaVersion ?? 1) < 2 &&
        const {'draining', 'neutral', 'restoring'}.contains(legacyEffect);
    if (!explicitlyCompleted && !legacyCompletedWithoutStatus) return false;

    final rawEndAt = signal.rawPayloadJson['end_at']?.toString().trim() ?? '';
    final endAt = DateTime.tryParse(rawEndAt);
    if (endAt != null &&
        endAt.toUtc().isAfter((now ?? DateTime.now()).toUtc())) {
      return false;
    }
    return true;
  }

  bool _containsAny(String value, List<String> needles) {
    return needles.any(value.contains);
  }
}
