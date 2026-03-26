class MemorySummaryModel {
  final List<dynamic> patterns;
  final List<dynamic> frictions;
  final List<dynamic> desires;
  final List<dynamic> experiments;

  MemorySummaryModel({required this.patterns, required this.frictions, required this.desires, required this.experiments});

  factory MemorySummaryModel.fromJson(Map<String, dynamic> json) {
    return MemorySummaryModel(
      patterns: (json['patterns'] as List?) ?? [],
      frictions: (json['frictions'] as List?) ?? [],
      desires: (json['desires'] as List?) ?? [],
      experiments: (json['experiments'] as List?) ?? [],
    );
  }
}
