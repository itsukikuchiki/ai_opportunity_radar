import 'package:ai_opportunity_radar/core/local/local_daily_snapshot_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/local/local_journey_snapshot_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_weekly_snapshot_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('snapshot source hashes include display language', () {
    final database = LocalDatabase();
    final daily = LocalDailySnapshotRepository(database);
    final weekly = LocalWeeklySnapshotRepository(database);
    final journey = LocalJourneySnapshotRepository(database);

    expect(
      daily.buildSourceHash(const [], language: 'en'),
      isNot(daily.buildSourceHash(const [], language: 'ja')),
    );
    expect(
      weekly.buildSourceHash(
        entries: const [],
        dayCounts: const {},
        topTokens: const [],
        language: 'zh-Hans',
      ),
      isNot(
        weekly.buildSourceHash(
          entries: const [],
          dayCounts: const {},
          topTokens: const [],
          language: 'zh-Hant',
        ),
      ),
    );
    expect(
      journey.buildSourceHash(
        entries: const [],
        topTokens: const [],
        totalDays: 0,
        language: 'en',
      ),
      isNot(
        journey.buildSourceHash(
          entries: const [],
          topTokens: const [],
          totalDays: 0,
          language: 'ja',
        ),
      ),
    );
  });

  test('Journey source hash changes with chart-driving trace facts', () {
    final journey = LocalJourneySnapshotRepository(LocalDatabase());
    String hashFor({
      required String cluster,
      required String energyState,
    }) {
      return journey.buildSourceHash(
        entries: const [
          {
            'id': 'signal-1',
            'content': 'Same visible Signal text',
            'created_at': '2026-08-02T09:00:00Z',
          },
        ],
        topTokens: const ['Signal'],
        totalDays: 1,
        traceEntries: [
          {
            'id': 'signal-1',
            'source_type': 'signal_card',
            'local_date': '2026-08-02',
            'summary': 'Same visible Signal text',
            'cluster': cluster,
            'intensity': 0.72,
            'signal_level': 'repeated_pattern',
            'metadata': {'energy_state': energyState},
          },
        ],
        language: 'en',
      );
    }

    final original = hashFor(
      cluster: 'emotional_stability',
      energyState: 'draining',
    );
    expect(
      hashFor(
        cluster: 'relationship_connection',
        energyState: 'draining',
      ),
      isNot(original),
    );
    expect(
      hashFor(
        cluster: 'emotional_stability',
        energyState: 'recovery',
      ),
      isNot(original),
    );
  });
}
