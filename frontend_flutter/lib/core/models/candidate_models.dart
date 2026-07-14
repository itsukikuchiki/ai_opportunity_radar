import 'energy_budget_models.dart';
import 'phase3_plus_models.dart';
import 'weekly_models.dart';

enum CandidateKind {
  microAction('micro_action'),
  lifeExperiment('life_experiment');

  final String storageValue;
  const CandidateKind(this.storageValue);
}

enum CandidateGenerationStatus {
  gated,
  stale,
  regenerating,
  ready,
  failed;

  static CandidateGenerationStatus fromStorage(Object? value) {
    return CandidateGenerationStatus.values.firstWhere(
      (item) => item.name == value?.toString(),
      orElse: () => CandidateGenerationStatus.stale,
    );
  }
}

class CandidateGateState {
  static const defaultRequiredSignalCount = 3;

  final CandidateKind kind;
  final String periodStart;
  final String periodEnd;
  final int eligibleSignalCount;
  final int requiredSignalCount;
  final List<String> eligibleSignalCardIds;

  const CandidateGateState({
    required this.kind,
    required this.periodStart,
    required this.periodEnd,
    required this.eligibleSignalCount,
    this.requiredSignalCount = defaultRequiredSignalCount,
    this.eligibleSignalCardIds = const [],
  });

  bool get isOpen => eligibleSignalCount >= requiredSignalCount;
  int get remaining =>
      (requiredSignalCount - eligibleSignalCount).clamp(0, requiredSignalCount);
}

class CandidateGenerationState {
  final CandidateKind kind;
  final String periodStart;
  final String periodEnd;
  final CandidateGenerationStatus status;
  final String? sourceHash;
  final String? staleReason;
  final int eligibleSignalCount;
  final DateTime? generationStartedAt;
  final DateTime? generationFinishedAt;
  final DateTime? updatedAt;

  const CandidateGenerationState({
    required this.kind,
    required this.periodStart,
    required this.periodEnd,
    required this.status,
    this.sourceHash,
    this.staleReason,
    this.eligibleSignalCount = 0,
    this.generationStartedAt,
    this.generationFinishedAt,
    this.updatedAt,
  });

  bool get isBusy => status == CandidateGenerationStatus.regenerating;
  bool get canDisplayCandidates => status == CandidateGenerationStatus.ready;
}

class CandidateSnapshot<T> {
  final CandidateGateState gate;
  final CandidateGenerationState generation;
  final List<T> candidates;

  const CandidateSnapshot({
    required this.gate,
    required this.generation,
    required this.candidates,
  });
}

/// Compact planning fingerprint stored in the existing `source_hash` column.
///
/// Keeping the component hashes in one backward-compatible value avoids a DB
/// migration while still making energy, focus and feedback independently
/// auditable and invalidating candidates when any one of them changes.
class CandidatePlanningFingerprint {
  static const version = 'pc2';

  final String combinedHash;
  final String signalHash;
  final String energySnapshotHash;
  final EnergyCapacityBand capacityBand;
  final String focusHash;
  final String feedbackHash;

  const CandidatePlanningFingerprint({
    required this.combinedHash,
    required this.signalHash,
    required this.energySnapshotHash,
    required this.capacityBand,
    required this.focusHash,
    required this.feedbackHash,
  });

  String encode() => [
        version,
        combinedHash,
        signalHash,
        energySnapshotHash,
        capacityBand.storageValue,
        focusHash,
        feedbackHash,
      ].join('.');

  static CandidatePlanningFingerprint? tryParse(String raw) {
    final parts = raw.split('.');
    if (parts.length != 7 || parts.first != version) return null;
    return CandidatePlanningFingerprint(
      combinedHash: parts[1],
      signalHash: parts[2],
      energySnapshotHash: parts[3],
      capacityBand: EnergyCapacityBand.fromStorage(parts[4]),
      focusHash: parts[5],
      feedbackHash: parts[6],
    );
  }
}

class CandidateFeedbackSummary {
  final List<String> effectiveEventIds;
  final int helpfulCount;
  final int difficultCount;
  final int skippedCount;
  final String sourceHash;

  const CandidateFeedbackSummary({
    this.effectiveEventIds = const [],
    this.helpfulCount = 0,
    this.difficultCount = 0,
    this.skippedCount = 0,
    this.sourceHash = '00000000',
  });

  bool get hasEvidence => effectiveEventIds.isNotEmpty;
}

class CandidatePlanningContext {
  final CandidateGateState gate;
  final EnergyBudgetSnapshot energySnapshot;
  final EnergyBudgetSnapshot? weeklyEnergySnapshot;
  final List<String> focusDomainIds;
  final CandidateFeedbackSummary feedback;
  final String sourceHash;

  const CandidatePlanningContext({
    required this.gate,
    required this.energySnapshot,
    this.weeklyEnergySnapshot,
    required this.focusDomainIds,
    required this.feedback,
    required this.sourceHash,
  });

  CandidateKind get kind => gate.kind;
  String get periodStart => gate.periodStart;
  String get periodEnd => gate.periodEnd;
  int get eligibleSignalCount => gate.eligibleSignalCount;
  int get requiredSignalCount => gate.requiredSignalCount;
  List<String> get eligibleSignalCardIds => gate.eligibleSignalCardIds;
  bool get isOpen => gate.isOpen;

  /// Daily planning uses the explicit local-day state and applies the local
  /// week as a conservative constraint. A positive weekly budget cannot turn
  /// an unknown current state into a positive capacity conclusion.
  EnergyCapacityBand get planningCapacityBand => resolveCapacity(
        energySnapshot.capacityBand,
        weeklyEnergySnapshot?.capacityBand,
      );

  EnergyRecommendedIntensity get planningRecommendedIntensity =>
      EnergyRecommendedIntensity.fromCapacity(planningCapacityBand);

  static EnergyCapacityBand resolveCapacity(
    EnergyCapacityBand primary,
    EnergyCapacityBand? weekly,
  ) {
    if (weekly == null || weekly == EnergyCapacityBand.unknown) return primary;
    if (primary == EnergyCapacityBand.unknown) {
      return weekly == EnergyCapacityBand.veryLow ||
              weekly == EnergyCapacityBand.low
          ? weekly
          : EnergyCapacityBand.unknown;
    }
    const order = <EnergyCapacityBand, int>{
      EnergyCapacityBand.veryLow: 0,
      EnergyCapacityBand.low: 1,
      EnergyCapacityBand.medium: 2,
      EnergyCapacityBand.high: 3,
      EnergyCapacityBand.unknown: 4,
    };
    return order[primary]! <= order[weekly]! ? primary : weekly;
  }
}

class MicroActionCandidateDraft {
  final String title;
  final String reason;
  final String difficulty;
  final List<String> linkedSignalCardIds;
  final List<String> focusDomainIds;
  final String energyAdaptationExplanation;
  final String recommendedIntensity;

  const MicroActionCandidateDraft({
    required this.title,
    required this.reason,
    this.difficulty = 'very_light',
    this.linkedSignalCardIds = const [],
    this.focusDomainIds = const [],
    this.energyAdaptationExplanation = '',
    this.recommendedIntensity = '',
  });
}

class ExperimentCandidateDraft {
  final String title;
  final String hypothesis;
  final String suggestedAction;
  final String confidenceLevel;
  final List<String> linkedSignalCardIds;
  final List<String> linkedObservationIds;
  final Map<String, dynamic> metadata;
  final String energyAdaptationExplanation;
  final String recommendedIntensity;

  const ExperimentCandidateDraft({
    required this.title,
    required this.hypothesis,
    required this.suggestedAction,
    this.confidenceLevel = 'medium',
    this.linkedSignalCardIds = const [],
    this.linkedObservationIds = const [],
    this.metadata = const {},
    this.energyAdaptationExplanation = '',
    this.recommendedIntensity = '',
  });
}

class MicroActionCandidateModel {
  final String id;
  final String candidateGroupId;
  final String localUserId;
  final String localDate;
  final int rank;
  final String title;
  final String reason;
  final String difficulty;
  final List<String> linkedSignalCardIds;
  final List<String> focusDomainIds;
  final String status;
  final String? adoptedMicroActionId;
  final String sourceHash;
  final String energySnapshotHash;
  final EnergyCapacityBand energyCapacityBand;
  final String energyAdaptationExplanation;
  final String recommendedIntensity;
  final bool isStale;
  final String? staleReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const MicroActionCandidateModel({
    required this.id,
    required this.candidateGroupId,
    required this.localUserId,
    required this.localDate,
    required this.rank,
    required this.title,
    required this.reason,
    required this.difficulty,
    required this.linkedSignalCardIds,
    required this.focusDomainIds,
    required this.status,
    required this.sourceHash,
    this.energySnapshotHash = '',
    this.energyCapacityBand = EnergyCapacityBand.unknown,
    this.energyAdaptationExplanation = '',
    this.recommendedIntensity = 'very_light',
    this.adoptedMicroActionId,
    this.isStale = false,
    this.staleReason,
    this.createdAt,
    this.updatedAt,
  });

  bool get isAdopted => status == 'adopted' && adoptedMicroActionId != null;
}

class ExperimentCandidateRecord {
  final String id;
  final String candidateGroupId;
  final String localUserId;
  final String weekStart;
  final String weekEnd;
  final int rank;
  final String title;
  final String hypothesis;
  final String suggestedAction;
  final List<String> linkedSignalCardIds;
  final List<String> linkedObservationIds;
  final String confidenceLevel;
  final Map<String, dynamic> metadata;
  final String status;
  final String? adoptedExperimentId;
  final String sourceHash;
  final String energySnapshotHash;
  final EnergyCapacityBand energyCapacityBand;
  final String energyAdaptationExplanation;
  final String recommendedIntensity;
  final bool isStale;
  final String? staleReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ExperimentCandidateRecord({
    required this.id,
    required this.candidateGroupId,
    required this.localUserId,
    required this.weekStart,
    required this.weekEnd,
    required this.rank,
    required this.title,
    required this.hypothesis,
    required this.suggestedAction,
    required this.linkedSignalCardIds,
    required this.linkedObservationIds,
    required this.confidenceLevel,
    required this.metadata,
    required this.status,
    required this.sourceHash,
    this.energySnapshotHash = '',
    this.energyCapacityBand = EnergyCapacityBand.unknown,
    this.energyAdaptationExplanation = '',
    this.recommendedIntensity = 'very_light',
    this.adoptedExperimentId,
    this.isStale = false,
    this.staleReason,
    this.createdAt,
    this.updatedAt,
  });

  bool get isAdopted => status == 'adopted' && adoptedExperimentId != null;
}

enum ProgressCellState { empty, completed, notCompleted }

class SevenDayProgressCell {
  final String localDate;
  final ProgressCellState state;
  final String? latestEventId;
  final DateTime? latestEventAt;

  const SevenDayProgressCell({
    required this.localDate,
    required this.state,
    this.latestEventId,
    this.latestEventAt,
  });
}

class SevenDayProgressModel {
  static const totalDays = 7;

  final String subjectId;
  final String startDate;
  final String endDate;
  final List<SevenDayProgressCell> cells;

  const SevenDayProgressModel({
    required this.subjectId,
    required this.startDate,
    required this.endDate,
    required this.cells,
  });

  int get completedDays => cells
      .where((cell) => cell.state == ProgressCellState.completed)
      .length
      .clamp(0, totalDays);
}

class AdoptedMicroActionProgress {
  final MicroActionModel action;
  final SevenDayProgressModel progress;

  const AdoptedMicroActionProgress({
    required this.action,
    required this.progress,
  });
}

class AdoptedLifeExperimentProgress {
  final LifeExperimentModel experiment;
  final SevenDayProgressModel progress;

  const AdoptedLifeExperimentProgress({
    required this.experiment,
    required this.progress,
  });
}
