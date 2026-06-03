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
