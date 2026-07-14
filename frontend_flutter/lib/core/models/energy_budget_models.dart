enum EnergyBudgetPeriodKind {
  daily,
  weekly;

  String get storageValue => name;
}

enum EnergyCapacityBand {
  unknown,
  veryLow,
  low,
  medium,
  high;

  String get storageValue => switch (this) {
        EnergyCapacityBand.veryLow => 'very_low',
        _ => name,
      };

  static EnergyCapacityBand fromStorage(Object? raw) {
    return switch (raw?.toString().trim().toLowerCase()) {
      'very_low' => EnergyCapacityBand.veryLow,
      'low' => EnergyCapacityBand.low,
      'medium' => EnergyCapacityBand.medium,
      'high' => EnergyCapacityBand.high,
      _ => EnergyCapacityBand.unknown,
    };
  }
}

enum EnergyRecommendedIntensity {
  veryLight,
  light,
  moderate;

  String get storageValue => switch (this) {
        EnergyRecommendedIntensity.veryLight => 'very_light',
        EnergyRecommendedIntensity.light => 'light',
        EnergyRecommendedIntensity.moderate => 'moderate',
      };

  static EnergyRecommendedIntensity fromCapacity(EnergyCapacityBand band) {
    return switch (band) {
      EnergyCapacityBand.high => EnergyRecommendedIntensity.moderate,
      EnergyCapacityBand.medium => EnergyRecommendedIntensity.light,
      _ => EnergyRecommendedIntensity.veryLight,
    };
  }
}

class EnergyBlockModel {
  final String type;
  final String label;
  final String summary;
  final int count;
  final String evidenceLevel;

  const EnergyBlockModel({
    required this.type,
    required this.label,
    required this.summary,
    required this.count,
    required this.evidenceLevel,
  });
}

/// One bounded, reproducible planning snapshot.
///
/// This remains a derived read model: it never becomes a SignalCard and never
/// contributes to the three-signal eligibility gate.
class EnergyBudgetSnapshot {
  static const policyVersion = 'energy_budget_v2';

  final String id;
  final EnergyBudgetPeriodKind periodKind;
  final String periodStart;
  final String periodEnd;
  final String timezone;
  final EnergyCapacityBand capacityBand;
  final EnergyRecommendedIntensity recommendedIntensity;
  final List<String> evidenceSignalIds;
  final List<String> feedbackEventIds;
  final String sourceHash;
  final String readiness;
  final String confidence;
  final DateTime updatedAt;
  final EnergyBudgetModel budget;

  const EnergyBudgetSnapshot({
    required this.id,
    required this.periodKind,
    required this.periodStart,
    required this.periodEnd,
    required this.timezone,
    required this.capacityBand,
    required this.recommendedIntensity,
    required this.evidenceSignalIds,
    required this.feedbackEventIds,
    required this.sourceHash,
    required this.readiness,
    required this.confidence,
    required this.updatedAt,
    required this.budget,
  });

  bool get isUnknown => capacityBand == EnergyCapacityBand.unknown;
}

class EnergyBudgetModel {
  final String status;
  final String mostDrainingSource;
  final String recoveryClue;
  final String bufferLocation;
  final String switchingAdjustment;
  final String experimentConnection;
  final String scheduleDensityHint;
  final String recoverySignalHint;
  final String externalConflictNote;
  final Map<String, String> abstractExternalHints;
  final List<EnergyBlockModel> blocks;

  const EnergyBudgetModel({
    required this.status,
    required this.mostDrainingSource,
    required this.recoveryClue,
    required this.bufferLocation,
    required this.switchingAdjustment,
    required this.experimentConnection,
    this.scheduleDensityHint = '',
    this.recoverySignalHint = '',
    this.externalConflictNote = '',
    this.abstractExternalHints = const {},
    required this.blocks,
  });

  bool get hasAnyBlocks => blocks.isNotEmpty;

  EnergyBlockModel? blockByType(String type) {
    for (final block in blocks) {
      if (block.type == type) return block;
    }
    return null;
  }
}
