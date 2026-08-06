/// Stable storage values describing how a user-visible experiment entered the
/// plan. This is deliberately independent from linked Signal provenance:
/// Signal links remain an internal reasoning/audit chain, while this field
/// records the user-facing creation path.
enum ExperimentCreationSource {
  userCreated('user_created'),
  candidateAdoption('candidate_adoption'),
  continuation('continuation'),
  legacyAiJudgement('legacy_ai_judgement'),
  legacyUnknown('legacy_unknown');

  const ExperimentCreationSource(this.storageValue);

  final String storageValue;

  static ExperimentCreationSource fromStorage(Object? raw) {
    final value = raw?.toString().trim().toLowerCase() ?? '';
    return values.firstWhere(
      (item) => item.storageValue == value,
      orElse: () => legacyUnknown,
    );
  }
}
