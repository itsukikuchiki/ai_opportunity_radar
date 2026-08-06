import 'dart:io';

import 'package:ai_opportunity_radar/core/models/weekly_illustration_catalog.dart';
import 'package:ai_opportunity_radar/core/models/weekly_illustration_taxonomy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WeeklyIllustrationCatalog', () {
    test('30 review taxonomy values map to 30 unique packaged assets', () {
      const definitions = WeeklyIllustrationCatalog.reviewDefinitions;

      expect(definitions, hasLength(30));
      expect(
        definitions.map((item) => item.hint).toSet(),
        WeeklyIllustrationTaxonomy.reviewPatterns.toSet(),
      );
      expect(definitions.map((item) => item.id).toSet(), hasLength(30));
      expect(definitions.map((item) => item.asset).toSet(), hasLength(30));

      for (final definition in definitions) {
        expect(
          WeeklyIllustrationCatalog.reviewForHint(definition.hint),
          same(definition),
        );
        expect(
          WeeklyIllustrationCatalog.reviewForId(definition.id),
          same(definition),
        );
        expect(
          File(definition.asset).existsSync(),
          isTrue,
          reason: 'Missing packaged artwork: ${definition.asset}',
        );
      }
    });

    test('24 behavior taxonomy values map to unique packaged pattern assets',
        () {
      const definitions = WeeklyIllustrationCatalog.patternDefinitions;

      expect(definitions, hasLength(24));
      expect(
        definitions.map((item) => item.hint).toSet(),
        WeeklyIllustrationTaxonomy.behaviorPatterns.toSet(),
      );
      expect(definitions.map((item) => item.id).toSet(), hasLength(24));
      expect(definitions.map((item) => item.asset).toSet(), hasLength(24));
      for (final definition in definitions) {
        expect(File(definition.asset).existsSync(), isTrue);
      }
    });

    test('legacy review copy resolves through the shared catalog', () {
      expect(
        WeeklyIllustrationCatalog.assetForText('这次被安排打断了'),
        'assets/weekly/weekly-review-interrupted-by-schedule.png',
      );
      expect(
        WeeklyIllustrationCatalog.assetForText('任务堆积，开始变困难'),
        'assets/weekly/weekly-pattern-task-pile-start-blocked.png',
      );
    });
  });

  group('WeeklyReviewIllustrationSelector', () {
    test('returns null without real attempt feedback', () {
      expect(
        WeeklyReviewIllustrationSelector.select(
          opportunitySnapshot: {
            '_feedback_event_summary': {
              'events': [
                {
                  'source_type': 'schedule_feedback',
                  'subject_type': 'schedule_signal',
                  'status': 'completed',
                },
              ],
            },
          },
          actionReview: {
            'generated_action_count': 3,
            'tried_action_count': 0,
          },
        ),
        isNull,
      );
    });

    test('selects by frequency before recency', () {
      final selection = WeeklyReviewIllustrationSelector.select(
        opportunitySnapshot: {
          '_feedback_event_summary': {
            'events': [
              _event(
                status: 'completed',
                effect: 'helpful',
                at: '2026-07-14T09:00:00Z',
              ),
              _event(
                status: 'completed',
                effect: 'helpful',
                at: '2026-07-15T09:00:00Z',
              ),
              _event(
                status: 'not_completed',
                at: '2026-07-16T09:00:00Z',
              ),
            ],
          },
        },
      );

      expect(selection?.definition.id, 'review.helpful');
      expect(selection?.count, 2);
      expect(selection?.latestAt, DateTime.parse('2026-07-15T09:00:00Z'));
    });

    test('uses latest occurrence when counts tie', () {
      final selection = WeeklyReviewIllustrationSelector.select(
        opportunitySnapshot: {
          '_feedback_event_summary': {
            'events': [
              _event(
                status: 'completed',
                at: '2026-07-14T09:00:00Z',
              ),
              _event(
                status: 'not_completed',
                at: '2026-07-16T09:00:00Z',
              ),
            ],
          },
        },
      );

      expect(selection?.definition.id, 'review.not_done');
    });

    test('uses canonical id as the final deterministic tie-break', () {
      final snapshot = {
        '_feedback_event_summary': {
          'events': [
            _event(
              status: 'not_completed',
              at: '2026-07-16T09:00:00Z',
            ),
            _event(
              status: 'completed',
              at: '2026-07-16T09:00:00Z',
            ),
          ],
        },
      };

      final first = WeeklyReviewIllustrationSelector.select(
        opportunitySnapshot: snapshot,
      );
      final second = WeeklyReviewIllustrationSelector.select(
        opportunitySnapshot: snapshot,
      );

      expect(first?.definition.id, 'review.done');
      expect(second?.definition.id, first?.definition.id);
    });

    test('respects an explicit canonical feedback pattern id', () {
      final selection = WeeklyReviewIllustrationSelector.select(
        opportunitySnapshot: {
          '_feedback_event_summary': {
            'events': [
              _event(
                status: 'completed',
                at: '2026-07-16T09:00:00Z',
                subjectId: 'action-16',
                metadata: {
                  'feedback_pattern_id': 'review.interrupted_by_emotion',
                },
              ),
            ],
          },
        },
      );

      expect(selection?.definition.id, 'review.interrupted_by_emotion');
      expect(selection?.subjectId, 'action-16');
    });

    test('legacy action review is used only after a real attempt occurred', () {
      final selection = WeeklyReviewIllustrationSelector.select(
        actionReview: {
          'tried_action_count': 3,
          'helpful_action_count': 2,
          'most_helpful_action': '睡前散步十分钟',
          'hardest_action': '需要半小时的流程',
        },
      );

      expect(selection?.definition.id, 'review.under_ten_minutes');
      expect(selection?.count, 2);
    });
  });
}

Map<String, dynamic> _event({
  required String status,
  required String at,
  String? effect,
  String? subjectId,
  Map<String, dynamic> metadata = const {},
}) {
  return {
    'source_type': 'micro_action_feedback',
    'subject_type': 'micro_action',
    if (subjectId != null) 'subject_id': subjectId,
    'status': status,
    if (effect != null) 'effect': effect,
    'created_at': at,
    'metadata': metadata,
  };
}
