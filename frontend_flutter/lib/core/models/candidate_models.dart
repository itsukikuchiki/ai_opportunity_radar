import 'energy_budget_models.dart';
import 'phase3_plus_models.dart';
import 'weekly_models.dart';

enum CandidateKind {
  // Storage values stay unchanged for migration and backup compatibility.
  // In the product language both kinds belong to the Life Experiment domain:
  // microAction is the short "small experiment" track, while lifeExperiment
  // is the medium/long-term "goal" track.
  microAction('micro_action'),
  lifeExperiment('life_experiment');

  final String storageValue;
  const CandidateKind(this.storageValue);
}

enum LifeExperimentTrack { smallTry, goal }

extension CandidateKindLifeExperimentTrack on CandidateKind {
  LifeExperimentTrack get lifeExperimentTrack => switch (this) {
        CandidateKind.microAction => LifeExperimentTrack.smallTry,
        CandidateKind.lifeExperiment => LifeExperimentTrack.goal,
      };
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

/// A user's explicit decision about a generated candidate.
///
/// `undecided` is an internal initial state rather than a third visible
/// choice. `considering` keeps the candidate as a read-only observation
/// without creating a progress-bearing plan; `adopted` means a canonical
/// micro action or life experiment has been created.
enum CandidateDecisionStatus {
  undecided,
  considering,
  adopted;

  static CandidateDecisionStatus fromStorage(Object? value) {
    return CandidateDecisionStatus.values.firstWhere(
      (item) => item.name == value?.toString().trim().toLowerCase(),
      orElse: () => CandidateDecisionStatus.undecided,
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

/// The explicit selection surface for the following Monday. Both tracks live
/// under Life Experiment: small tries can be attempted immediately once the
/// target week begins, while goals need repeated practice across that week.
/// Nothing in this read model is active in Today before `targetWeekStart`.
class NextWeekPlanCandidateSnapshot {
  final CandidateGateState gate;
  final String targetWeekStart;
  final String targetWeekEnd;
  final List<MicroActionCandidateModel> smallTryCandidates;
  final List<ExperimentCandidateRecord> goalCandidates;

  const NextWeekPlanCandidateSnapshot({
    required this.gate,
    required this.targetWeekStart,
    required this.targetWeekEnd,
    this.smallTryCandidates = const [],
    this.goalCandidates = const [],
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
  final int completedCount;
  final int notCompletedCount;
  final int helpfulCount;
  final int difficultCount;
  final int skippedCount;
  final String sourceHash;

  const CandidateFeedbackSummary({
    this.effectiveEventIds = const [],
    this.completedCount = 0,
    this.notCompletedCount = 0,
    this.helpfulCount = 0,
    this.difficultCount = 0,
    this.skippedCount = 0,
    this.sourceHash = '00000000',
  });

  bool get hasEvidence => effectiveEventIds.isNotEmpty;
}

/// Optional Pro/deep-analysis context used only to improve the ordering and
/// wording of next-week candidates. It never opens the candidate gate and is
/// not required for a free user to receive grounded suggestions.
class DeepPlanningReference {
  final String id;
  final String sourceHash;
  final String summary;
  final String? observationPlanId;

  const DeepPlanningReference({
    required this.id,
    required this.sourceHash,
    required this.summary,
    this.observationPlanId,
  });
}

class CandidatePlanningContext {
  final CandidateGateState gate;
  final EnergyBudgetSnapshot energySnapshot;
  final EnergyBudgetSnapshot? weeklyEnergySnapshot;
  final List<String> focusDomainIds;
  final CandidateFeedbackSummary feedback;
  final String sourceHash;
  final DeepPlanningReference? deepReference;

  const CandidatePlanningContext({
    required this.gate,
    required this.energySnapshot,
    this.weeklyEnergySnapshot,
    required this.focusDomainIds,
    required this.feedback,
    required this.sourceHash,
    this.deepReference,
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
  final CandidateDecisionStatus decisionStatus;
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
    this.decisionStatus = CandidateDecisionStatus.undecided,
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

  bool get isAdopted =>
      (decisionStatus == CandidateDecisionStatus.adopted ||
          const {'adopted', 'planned', 'active'}.contains(status)) &&
      adoptedMicroActionId != null;

  bool get isConsidering =>
      decisionStatus == CandidateDecisionStatus.considering && !isAdopted;
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
  final CandidateDecisionStatus decisionStatus;
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
    this.decisionStatus = CandidateDecisionStatus.undecided,
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

  bool get isAdopted =>
      (decisionStatus == CandidateDecisionStatus.adopted ||
          const {'adopted', 'planned', 'active'}.contains(status)) &&
      adoptedExperimentId != null;

  bool get isConsidering =>
      decisionStatus == CandidateDecisionStatus.considering && !isAdopted;
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
  /// Kept for the goal/week compatibility projection. Quick experiments may
  /// now carry any number of real attempt cells and do not use this ceiling.
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

  /// Every valid feedback entry preserved by the projection.
  ///
  /// Quick experiments are append-only: several entries may belong to the
  /// same local day. This is deliberately not an "attempt" count because a
  /// user may also record that they did not try the experiment.
  int get recordedEntries => cells.length;

  /// Entries that confirm a real attempt happened.
  ///
  /// Legacy completion aliases are normalized by the repository before the
  /// cells reach this model, so an old record can count even when it does not
  /// contain the newer effect or difficulty evaluation.
  int get completedEntries =>
      cells.where((cell) => cell.state == ProgressCellState.completed).length;

  int get completedAttempts => completedEntries;

  /// Valid feedback entries explicitly saying the experiment was not tried.
  int get notAttemptedEntries => cells
      .where((cell) => cell.state == ProgressCellState.notCompleted)
      .length;

  /// Compatibility name used by goal/day-grid consumers.
  int get completedDays => completedEntries;
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
