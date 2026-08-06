import 'weekly_illustration_catalog.dart';

class SignalLibraryIllustrationDefinition {
  final String id;
  final String asset;

  const SignalLibraryIllustrationDefinition({
    required this.id,
    required this.asset,
  });
}

/// Stable illustration mapping for the curated Signal Library.
///
/// Library copy is localized, but the canonical pattern id and illustration
/// stay the same in every language. The catalog deliberately reuses only the
/// behavior-pattern artwork; review/feedback artwork has different semantics.
class SignalLibraryIllustrationCatalog {
  const SignalLibraryIllustrationCatalog._();

  static const version = 'signal_library_illustration_v1';

  static const Map<String, SignalLibraryIllustrationDefinition>
      _libraryOnlyDefinitions = {
    'tension_without_a_big_event': SignalLibraryIllustrationDefinition(
      id: 'pattern.tension_without_big_event',
      asset: 'assets/weekly/weekly-pattern-tension-without-big-event.png',
    ),
    'being_heard_before_advice': SignalLibraryIllustrationDefinition(
      id: 'pattern.being_heard_before_advice',
      asset: 'assets/weekly/weekly-pattern-being-heard-before-advice.png',
    ),
    'contribution_seen_restores_motivation':
        SignalLibraryIllustrationDefinition(
      id: 'pattern.contribution_seen_restores_motivation',
      asset:
          'assets/weekly/weekly-pattern-contribution-seen-restores-motivation.png',
    ),
  };

  static const Map<String, String> _illustrationKeyByPatternId = {
    'over_scheduled_weeks': 'pattern.schedule_driven_mood',
    'recovery_debt': 'pattern.rest_squeezed',
    'attention_switching_fatigue': 'pattern.meeting_fragmented',
    'unclear_expectation_relationship_friction': 'pattern.unclear_expression',
    'late_night_compensation_behavior': 'pattern.night_phone',
    'weak_positive_signals': 'pattern.small_action_stabilizes',
    'boundary_fatigue': 'pattern.boundary_pushed_time_squeezed',
    'small_freedom_connection_creative_energy': 'pattern.interest_recovery',
    'busy_without_a_clear_why': 'pattern.too_many_goals_scattered',
    'agreeing_before_checking_capacity': 'pattern.people_pleasing_tired',
    'input_without_expression': 'pattern.creation_squeezed_by_work',
    'clutter_keeps_attention_open': 'pattern.messy_environment_mood',
    'unclear_spending_background_stress': 'pattern.money_safety_pressure',
    'enjoyment_always_comes_last': 'pattern.interest_recovery',
    'vitality_after_movement_or_nature': 'pattern.interest_recovery',
  };

  static String canonicalPatternId(String rawPatternId) {
    return rawPatternId
        .trim()
        .replaceFirst(RegExp(r'_(zh_hans|zh_hant|ja)$'), '');
  }

  static String? keyForPatternId(String rawPatternId) {
    final canonicalId = canonicalPatternId(rawPatternId);
    return _libraryOnlyDefinitions[canonicalId]?.id ??
        _illustrationKeyByPatternId[canonicalId];
  }

  static SignalLibraryIllustrationDefinition? forPatternId(
    String rawPatternId,
  ) {
    final canonicalId = canonicalPatternId(rawPatternId);
    final libraryOnly = _libraryOnlyDefinitions[canonicalId];
    if (libraryOnly != null) return libraryOnly;

    final key = _illustrationKeyByPatternId[canonicalId];
    if (key == null) return null;
    final weekly = WeeklyIllustrationCatalog.patternForId(key);
    if (weekly == null) return null;
    return SignalLibraryIllustrationDefinition(
      id: weekly.id,
      asset: weekly.asset,
    );
  }
}
