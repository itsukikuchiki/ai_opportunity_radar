import 'signal_library_illustration_catalog.dart';

class LibraryPatternModel {
  final String id;
  final String focusDomainId;
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
    required this.focusDomainId,
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

  String get canonicalId =>
      SignalLibraryIllustrationCatalog.canonicalPatternId(id);

  String? get illustrationKey =>
      SignalLibraryIllustrationCatalog.keyForPatternId(id);

  Map<String, dynamic> toPayloadJson() {
    return {
      'library_pattern_id': id,
      'canonical_pattern_id': canonicalId,
      'focus_domain_id': focusDomainId,
      if (illustrationKey != null) 'illustration_key': illustrationKey,
      if (illustrationKey != null)
        'illustration_catalog_version':
            SignalLibraryIllustrationCatalog.version,
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
