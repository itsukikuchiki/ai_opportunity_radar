import '../models/today_models.dart';

/// Today uses the person's live records, never release-QA showcase fixtures.
///
/// Showcase rows remain available to Weekly, Journey and Pro so an internal
/// testing build can still demonstrate those reports.
class TodaySignalScope {
  const TodaySignalScope._();

  static bool isQaShowcase(RecentSignalModel signal) {
    if (signal.rawPayloadJson['qa_showcase'] == true ||
        signal.migrationStatus.trim().toLowerCase() == 'qa_showcase' ||
        signal.intentTags
            .map((tag) => tag.trim().toLowerCase())
            .contains('qa_showcase')) {
      return true;
    }

    return [
      signal.id,
      signal.signalCardId,
      signal.clientId,
      signal.serverId,
    ].whereType<String>().any(
          (id) => id.trim().toLowerCase().startsWith('qa_demo_'),
        );
  }

  static Iterable<RecentSignalModel> liveOnly(
    Iterable<RecentSignalModel> signals,
  ) {
    return signals.where((signal) => !isQaShowcase(signal));
  }
}
