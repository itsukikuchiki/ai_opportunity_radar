import 'monthly_models.dart';

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

class LifeDirectionModel {
  final String title;
  final String summary;

  const LifeDirectionModel({
    required this.title,
    required this.summary,
  });

  factory LifeDirectionModel.fromJson(Map<String, dynamic> json) {
    return LifeDirectionModel(
      title: (json['title'] as String?) ?? '',
      summary: (json['summary'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'summary': summary,
    };
  }
}

class JourneyThemeModel {
  final String id;
  final String title;
  final int count;

  const JourneyThemeModel({
    required this.id,
    required this.title,
    required this.count,
  });

  factory JourneyThemeModel.fromJson(Map<String, dynamic> json) {
    return JourneyThemeModel(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'count': count,
    };
  }
}

class JourneyTraceModel {
  final String id;
  final String sourceType;
  final String title;
  final String summary;
  final String localDate;
  final String cluster;
  final double intensity;
  final String signalLevel;

  /// Typed source metadata used by read projections without changing the
  /// append-only event identity. Examples include `review_type`,
  /// `subject_id`, `is_effective`, and the canonical five-state energy key.
  final Map<String, dynamic> metadata;

  const JourneyTraceModel({
    required this.id,
    required this.sourceType,
    required this.title,
    required this.summary,
    required this.localDate,
    required this.cluster,
    required this.intensity,
    required this.signalLevel,
    this.metadata = const {},
  });

  factory JourneyTraceModel.fromJson(Map<String, dynamic> json) {
    return JourneyTraceModel(
      id: (json['id'] as String?) ?? '',
      sourceType: (json['source_type'] as String?) ?? 'signal_card',
      title: (json['title'] as String?) ?? '',
      summary: (json['summary'] as String?) ?? '',
      localDate: (json['local_date'] as String?) ?? '',
      cluster: (json['cluster'] as String?) ?? 'life',
      intensity: ((json['intensity'] as num?) ?? 0.45).toDouble(),
      signalLevel: (json['signal_level'] as String?) ?? 'weak_signal',
      metadata: json['metadata'] is Map
          ? (json['metadata'] as Map).cast<String, dynamic>()
          : const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'source_type': sourceType,
      'title': title,
      'summary': summary,
      'local_date': localDate,
      'cluster': cluster,
      'intensity': intensity,
      'signal_level': signalLevel,
      'metadata': metadata,
    };
  }
}

/// Factual daily projection for one selected local calendar month.
///
/// This is not an inferred score. Signal count comes only from eligible
/// Signal Cards, energy counts are the exhaustive five-state classification
/// of those same Signals, and feedback counts come from append-only facts.
class JourneyDayFactModel {
  final String localDate;
  final int signalCount;
  final Map<String, int> energyStateCounts;
  final int smallExperimentAttemptCount;
  final int goalFeedbackCount;

  const JourneyDayFactModel({
    required this.localDate,
    this.signalCount = 0,
    this.energyStateCounts = const {},
    this.smallExperimentAttemptCount = 0,
    this.goalFeedbackCount = 0,
  });

  factory JourneyDayFactModel.fromJson(Map<String, dynamic> json) {
    final rawEnergy = json['energy_state_counts'];
    return JourneyDayFactModel(
      localDate: (json['local_date'] as String?) ?? '',
      signalCount: (json['signal_count'] as num?)?.toInt() ?? 0,
      energyStateCounts: rawEnergy is Map
          ? rawEnergy.map(
              (key, value) => MapEntry(
                key.toString(),
                (value as num?)?.toInt() ?? 0,
              ),
            )
          : const {},
      smallExperimentAttemptCount:
          (json['small_experiment_attempt_count'] as num?)?.toInt() ?? 0,
      goalFeedbackCount: (json['goal_feedback_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'local_date': localDate,
        'signal_count': signalCount,
        'energy_state_counts': energyStateCounts,
        'small_experiment_attempt_count': smallExperimentAttemptCount,
        'goal_feedback_count': goalFeedbackCount,
      };
}

/// One read-only small-experiment or goal trajectory in Journey.
class JourneyExperimentTrackModel {
  final String subjectId;
  final String kind;
  final String title;
  final int attemptCount;
  final int feedbackCount;
  final int roundReviewCount;
  final int weeklyReviewCount;
  final int wholeRoundReviewCount;
  final String latestResult;
  final String latestLocalDate;

  const JourneyExperimentTrackModel({
    required this.subjectId,
    required this.kind,
    required this.title,
    this.attemptCount = 0,
    this.feedbackCount = 0,
    this.roundReviewCount = 0,
    this.weeklyReviewCount = 0,
    this.wholeRoundReviewCount = 0,
    this.latestResult = '',
    this.latestLocalDate = '',
  });

  factory JourneyExperimentTrackModel.fromJson(Map<String, dynamic> json) {
    return JourneyExperimentTrackModel(
      subjectId: (json['subject_id'] as String?) ?? '',
      kind: (json['kind'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      attemptCount: (json['attempt_count'] as num?)?.toInt() ?? 0,
      feedbackCount: (json['feedback_count'] as num?)?.toInt() ?? 0,
      roundReviewCount: (json['round_review_count'] as num?)?.toInt() ?? 0,
      weeklyReviewCount: (json['weekly_review_count'] as num?)?.toInt() ?? 0,
      wholeRoundReviewCount:
          (json['whole_round_review_count'] as num?)?.toInt() ?? 0,
      latestResult: (json['latest_result'] as String?) ?? '',
      latestLocalDate: (json['latest_local_date'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'subject_id': subjectId,
        'kind': kind,
        'title': title,
        'attempt_count': attemptCount,
        'feedback_count': feedbackCount,
        'round_review_count': roundReviewCount,
        'weekly_review_count': weeklyReviewCount,
        'whole_round_review_count': wholeRoundReviewCount,
        'latest_result': latestResult,
        'latest_local_date': latestLocalDate,
      };
}

/// Complete factual layer for the selected month. Synthesis readiness is
/// evaluated separately and only eligible Signal Cards contribute to it.
class JourneyPeriodFactsModel {
  final String periodStart;
  final String periodEnd;
  final int signalCount;
  final int activeDayCount;
  final int smallExperimentAttemptCount;
  final int smallExperimentRoundReviewCount;
  final int goalFeedbackCount;
  final int goalWeeklyReviewCount;
  final int goalWholeRoundReviewCount;
  final Map<String, int> energyStateCounts;
  final List<JourneyDayFactModel> days;
  final List<JourneyExperimentTrackModel> experimentTracks;

  const JourneyPeriodFactsModel({
    required this.periodStart,
    required this.periodEnd,
    this.signalCount = 0,
    this.activeDayCount = 0,
    this.smallExperimentAttemptCount = 0,
    this.smallExperimentRoundReviewCount = 0,
    this.goalFeedbackCount = 0,
    this.goalWeeklyReviewCount = 0,
    this.goalWholeRoundReviewCount = 0,
    this.energyStateCounts = const {},
    this.days = const [],
    this.experimentTracks = const [],
  });

  factory JourneyPeriodFactsModel.fromJson(Map<String, dynamic> json) {
    final rawEnergy = json['energy_state_counts'];
    return JourneyPeriodFactsModel(
      periodStart: (json['period_start'] as String?) ?? '',
      periodEnd: (json['period_end'] as String?) ?? '',
      signalCount: (json['signal_count'] as num?)?.toInt() ?? 0,
      activeDayCount: (json['active_day_count'] as num?)?.toInt() ?? 0,
      smallExperimentAttemptCount:
          (json['small_experiment_attempt_count'] as num?)?.toInt() ?? 0,
      smallExperimentRoundReviewCount:
          (json['small_experiment_round_review_count'] as num?)?.toInt() ?? 0,
      goalFeedbackCount: (json['goal_feedback_count'] as num?)?.toInt() ?? 0,
      goalWeeklyReviewCount:
          (json['goal_weekly_review_count'] as num?)?.toInt() ?? 0,
      goalWholeRoundReviewCount:
          (json['goal_whole_round_review_count'] as num?)?.toInt() ?? 0,
      energyStateCounts: rawEnergy is Map
          ? rawEnergy.map(
              (key, value) => MapEntry(
                key.toString(),
                (value as num?)?.toInt() ?? 0,
              ),
            )
          : const {},
      days: ((json['days'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => JourneyDayFactModel.fromJson(
                item.cast<String, dynamic>(),
              ))
          .toList(growable: false),
      experimentTracks: ((json['experiment_tracks'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => JourneyExperimentTrackModel.fromJson(
                item.cast<String, dynamic>(),
              ))
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => {
        'period_start': periodStart,
        'period_end': periodEnd,
        'signal_count': signalCount,
        'active_day_count': activeDayCount,
        'small_experiment_attempt_count': smallExperimentAttemptCount,
        'small_experiment_round_review_count': smallExperimentRoundReviewCount,
        'goal_feedback_count': goalFeedbackCount,
        'goal_weekly_review_count': goalWeeklyReviewCount,
        'goal_whole_round_review_count': goalWholeRoundReviewCount,
        'energy_state_counts': energyStateCounts,
        'days': days.map((item) => item.toJson()).toList(growable: false),
        'experiment_tracks': experimentTracks
            .map((item) => item.toJson())
            .toList(growable: false),
      };
}

class JourneyEvidenceItemModel {
  final String sourceType;
  final String sourceId;
  final String title;
  final String summary;
  final String localDate;
  final String relationType;
  final Map<String, dynamic> metadata;

  const JourneyEvidenceItemModel({
    required this.sourceType,
    required this.sourceId,
    required this.title,
    required this.summary,
    required this.localDate,
    required this.relationType,
    this.metadata = const {},
  });
}

class JourneyObservationModel {
  final String id;
  final String text;
  final String status;
  final String confidence;
  final String observationType;
  final String evidenceText;
  final String suggestedPattern;
  final String localDate;

  const JourneyObservationModel({
    required this.id,
    required this.text,
    required this.status,
    required this.confidence,
    required this.observationType,
    required this.evidenceText,
    required this.suggestedPattern,
    required this.localDate,
  });

  factory JourneyObservationModel.fromJson(Map<String, dynamic> json) {
    return JourneyObservationModel(
      id: (json['id'] as String?) ?? '',
      text: (json['text'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'generated',
      confidence: (json['confidence'] as String?) ?? 'medium',
      observationType: (json['observation_type'] as String?) ?? 'hypothesis',
      evidenceText: (json['evidence_text'] as String?) ?? '',
      suggestedPattern: (json['suggested_pattern'] as String?) ?? '',
      localDate: (json['local_date'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'status': status,
      'confidence': confidence,
      'observation_type': observationType,
      'evidence_text': evidenceText,
      'suggested_pattern': suggestedPattern,
      'local_date': localDate,
    };
  }

  bool get isConfirmed => status == 'confirmed';
  bool get isDismissed => status == 'dismissed';
}

class PhaseMemoryModel {
  final String monthKey;
  final List<JourneyTraceModel> traces;
  final List<JourneyThemeModel> themes;

  const PhaseMemoryModel({
    required this.monthKey,
    required this.traces,
    required this.themes,
  });

  factory PhaseMemoryModel.fromJson(Map<String, dynamic> json) {
    return PhaseMemoryModel(
      monthKey: (json['month_key'] as String?) ?? '',
      traces: ((json['traces'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => JourneyTraceModel.fromJson(e.cast<String, dynamic>()))
          .toList(),
      themes: ((json['themes'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => JourneyThemeModel.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'month_key': monthKey,
      'traces': traces.map((e) => e.toJson()).toList(),
      'themes': themes.map((e) => e.toJson()).toList(),
    };
  }
}

class MemorySummaryModel {
  final List<JourneySignalItemModel> patterns;
  final List<JourneySignalItemModel> frictions;
  final List<JourneySignalItemModel> desires;
  final List<JourneySignalItemModel> experiments;
  final MonthlyReviewModel? monthlyReview;
  final LifeDirectionModel? lifeDirection;
  final List<JourneyThemeModel> journeyThemes;
  final List<JourneyTraceModel> journeyTraces;
  final List<JourneyObservationModel> observations;
  final PhaseMemoryModel? phaseMemory;
  final JourneyPeriodFactsModel? periodFacts;

  MemorySummaryModel({
    required this.patterns,
    required this.frictions,
    required this.desires,
    required this.experiments,
    this.monthlyReview,
    this.lifeDirection,
    this.journeyThemes = const [],
    this.journeyTraces = const [],
    this.observations = const [],
    this.phaseMemory,
    this.periodFacts,
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
      monthlyReview: json['monthly_review'] is Map
          ? MonthlyReviewModel.fromJson(
              (json['monthly_review'] as Map).cast<String, dynamic>(),
            )
          : null,
      lifeDirection: json['life_direction'] is Map
          ? LifeDirectionModel.fromJson(
              (json['life_direction'] as Map).cast<String, dynamic>(),
            )
          : null,
      journeyThemes: ((json['journey_themes'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => JourneyThemeModel.fromJson(e.cast<String, dynamic>()))
          .toList(),
      journeyTraces: ((json['journey_traces'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => JourneyTraceModel.fromJson(e.cast<String, dynamic>()))
          .toList(),
      observations: ((json['observations'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) =>
              JourneyObservationModel.fromJson(e.cast<String, dynamic>()))
          .toList(),
      phaseMemory: json['phase_memory'] is Map
          ? PhaseMemoryModel.fromJson(
              (json['phase_memory'] as Map).cast<String, dynamic>(),
            )
          : null,
      periodFacts: json['period_facts'] is Map
          ? JourneyPeriodFactsModel.fromJson(
              (json['period_facts'] as Map).cast<String, dynamic>(),
            )
          : null,
    );
  }

  bool get hasAnySignals =>
      patterns.isNotEmpty ||
      frictions.isNotEmpty ||
      desires.isNotEmpty ||
      experiments.isNotEmpty ||
      observations.isNotEmpty ||
      journeyTraces.isNotEmpty;

  MemorySummaryModel copyWith({
    List<JourneySignalItemModel>? patterns,
    List<JourneySignalItemModel>? frictions,
    List<JourneySignalItemModel>? desires,
    List<JourneySignalItemModel>? experiments,
    MonthlyReviewModel? monthlyReview,
    LifeDirectionModel? lifeDirection,
    List<JourneyThemeModel>? journeyThemes,
    List<JourneyTraceModel>? journeyTraces,
    List<JourneyObservationModel>? observations,
    PhaseMemoryModel? phaseMemory,
    JourneyPeriodFactsModel? periodFacts,
  }) {
    return MemorySummaryModel(
      patterns: patterns ?? this.patterns,
      frictions: frictions ?? this.frictions,
      desires: desires ?? this.desires,
      experiments: experiments ?? this.experiments,
      monthlyReview: monthlyReview ?? this.monthlyReview,
      lifeDirection: lifeDirection ?? this.lifeDirection,
      journeyThemes: journeyThemes ?? this.journeyThemes,
      journeyTraces: journeyTraces ?? this.journeyTraces,
      observations: observations ?? this.observations,
      phaseMemory: phaseMemory ?? this.phaseMemory,
      periodFacts: periodFacts ?? this.periodFacts,
    );
  }

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
