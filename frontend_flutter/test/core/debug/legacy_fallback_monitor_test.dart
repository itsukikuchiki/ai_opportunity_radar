import 'package:flutter_test/flutter_test.dart';

import 'package:ai_opportunity_radar/core/debug/legacy_fallback_monitor.dart';
import 'package:ai_opportunity_radar/core/models/weekly_models.dart';

void main() {
  tearDown(LegacyFallbackMonitor.reset);

  test('records opportunitySnapshot life experiment fallback reads', () {
    LegacyFallbackMonitor.reset();

    final weekly = WeeklyInsightModel(
      weekStart: '2026-07-01',
      weekEnd: '2026-07-07',
      status: 'ready',
      keyInsight: 'test',
      patterns: const [],
      frictions: const [],
      bestAction: 'test',
      opportunitySnapshot: const {
        '_life_experiment': {
          'id': 'legacy_exp',
          'title': 'Legacy experiment',
          'hypothesis': 'legacy',
          'suggested_action': 'legacy action',
          'status': 'suggested',
          'source_week_start': '2026-07-01',
          'source_week_end': '2026-07-07',
          'linked_signal_card_ids': [],
        },
      },
      feedbackSubmitted: false,
    );

    expect(weekly.lifeExperiment?.id, 'legacy_exp');
    expect(
      LegacyFallbackMonitor.snapshot()[
          LegacyFallbackMonitor.opportunitySnapshotLifeExperiment],
      1,
    );

    LegacyFallbackMonitor.reset();
    expect(
      LegacyFallbackMonitor.snapshot()[
          LegacyFallbackMonitor.opportunitySnapshotLifeExperiment],
      0,
    );
  });
}
