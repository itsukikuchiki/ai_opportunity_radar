class LibraryPatternModel {
  final String id;
  final String title;
  final String abstractPattern;
  final List<String> commonScenes;
  final List<String> commonFrictions;
  final String energyLoadHint;
  final String possiblePositiveSignal;
  final String language;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LibraryPatternModel({
    required this.id,
    required this.title,
    required this.abstractPattern,
    required this.commonScenes,
    required this.commonFrictions,
    required this.energyLoadHint,
    required this.possiblePositiveSignal,
    required this.language,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toPayloadJson() {
    return {
      'library_pattern_id': id,
      'title': title,
      'abstract_pattern': abstractPattern,
      'common_scenes': commonScenes,
      'common_frictions': commonFrictions,
      'energy_load_hint': energyLoadHint,
      'possible_positive_signal': possiblePositiveSignal,
      'language': language,
    };
  }
}
