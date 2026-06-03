class JourneySignalItemModel {
  final String name;
  final String summary;
  final String signalLevel;

  const JourneySignalItemModel({
    required this.name,
    required this.summary,
    required this.signalLevel,
  });

  factory JourneySignalItemModel.fromJson(Map<String, dynamic> json) {
    return JourneySignalItemModel(
      name: (json['name'] as String?) ?? '',
      summary: (json['summary'] as String?) ?? '',
      signalLevel: (json['signal_level'] as String?) ?? 'weak_signal',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'summary': summary,
      'signal_level': signalLevel,
    };
  }

  bool get isWeakSignal => signalLevel == 'weak_signal';
  bool get isRepeatedPattern => signalLevel == 'repeated_pattern';
  bool get isStableMode => signalLevel == 'stable_mode';
}

class MemorySummaryModel {
  final List<JourneySignalItemModel> patterns;
  final List<JourneySignalItemModel> frictions;
  final List<JourneySignalItemModel> desires;
  final List<JourneySignalItemModel> experiments;

  MemorySummaryModel({
    required this.patterns,
    required this.frictions,
    required this.desires,
    required this.experiments,
  });

  factory MemorySummaryModel.fromJson(Map<String, dynamic> json) {
    return MemorySummaryModel(
      patterns: ((json['patterns'] as List?) ?? const [])
          .whereType<Map>()
          .map(
              (e) => JourneySignalItemModel.fromJson(e.cast<String, dynamic>()))
          .toList(),
      frictions: ((json['frictions'] as List?) ?? const [])
          .whereType<Map>()
          .map(
              (e) => JourneySignalItemModel.fromJson(e.cast<String, dynamic>()))
          .toList(),
      desires: ((json['desires'] as List?) ?? const [])
          .whereType<Map>()
          .map(
              (e) => JourneySignalItemModel.fromJson(e.cast<String, dynamic>()))
          .toList(),
      experiments: ((json['experiments'] as List?) ?? const [])
          .whereType<Map>()
          .map(
              (e) => JourneySignalItemModel.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }

  bool get hasAnySignals =>
      patterns.isNotEmpty ||
      frictions.isNotEmpty ||
      desires.isNotEmpty ||
      experiments.isNotEmpty;

  JourneySignalItemModel? get longTermPattern => _firstOrNull(patterns);
  JourneySignalItemModel? get mainFriction => _firstOrNull(frictions);
  JourneySignalItemModel? get recoverySignal => _firstOrNull(desires);
  JourneySignalItemModel? get experimentFeedback => _firstOrNull(experiments);

  JourneySignalItemModel get nextAdjustmentDirection {
    final experiment = experimentFeedback;
    if (experiment == null) {
      return const JourneySignalItemModel(
        name: '下次可以轻一点调整',
        summary: '现在还不用急着改变什么。继续记录几天后，再选一个最省力的小方向就好。',
        signalLevel: 'weak_signal',
      );
    }
    return JourneySignalItemModel(
      name: '下次可以轻一点调整',
      summary:
          '可以把“${experiment.name}”先当作一个生活设计来看：它有没有帮你省一点力，如果没有，也只是说明这个设计需要再调小一点。',
      signalLevel: experiment.signalLevel,
    );
  }

  List<JourneySignalItemModel> get weakSignals => [
        ...patterns.where((e) => e.isWeakSignal),
        ...frictions.where((e) => e.isWeakSignal),
        ...desires.where((e) => e.isWeakSignal),
        ...experiments.where((e) => e.isWeakSignal),
      ];

  List<JourneySignalItemModel> get repeatedPatterns => [
        ...patterns.where((e) => e.isRepeatedPattern),
        ...frictions.where((e) => e.isRepeatedPattern),
        ...desires.where((e) => e.isRepeatedPattern),
        ...experiments.where((e) => e.isRepeatedPattern),
      ];

  List<JourneySignalItemModel> get stableModes => [
        ...patterns.where((e) => e.isStableMode),
        ...frictions.where((e) => e.isStableMode),
        ...desires.where((e) => e.isStableMode),
        ...experiments.where((e) => e.isStableMode),
      ];

  static JourneySignalItemModel? _firstOrNull(
    List<JourneySignalItemModel> items,
  ) {
    return items.isEmpty ? null : items.first;
  }
}
