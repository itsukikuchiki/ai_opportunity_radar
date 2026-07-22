class WeeklyIllustrationDefinition {
  final String id;
  final String hint;
  final String asset;

  const WeeklyIllustrationDefinition({
    required this.id,
    required this.hint,
    required this.asset,
  });
}

/// Canonical catalog for the packaged Weekly review and pattern artwork.
///
/// IDs, rather than localized display copy, are the stable selection keys.
/// Legacy `illustration_hint` text is still accepted at the boundary so old
/// snapshots continue to resolve to the same bundled artwork.
class WeeklyIllustrationCatalog {
  const WeeklyIllustrationCatalog._();

  static const reviewDefinitions = <WeeklyIllustrationDefinition>[
    WeeklyIllustrationDefinition(
      id: 'review.done',
      hint: '做到了',
      asset: 'assets/weekly/weekly-review-done.png',
    ),
    WeeklyIllustrationDefinition(
      id: 'review.not_done',
      hint: '没做到',
      asset: 'assets/weekly/weekly-review-not-done.png',
    ),
    WeeklyIllustrationDefinition(
      id: 'review.skip',
      hint: '不想做',
      asset: 'assets/weekly/weekly-review-skip.png',
    ),
    WeeklyIllustrationDefinition(
      id: 'review.not_suitable_today',
      hint: '今天不适合',
      asset: 'assets/weekly/weekly-review-not-suitable-today.png',
    ),
    WeeklyIllustrationDefinition(
      id: 'review.helpful',
      hint: '有帮助',
      asset: 'assets/weekly/weekly-review-helpful.png',
    ),
    WeeklyIllustrationDefinition(
      id: 'review.neutral',
      hint: '一般',
      asset: 'assets/weekly/weekly-review-neutral.png',
    ),
    WeeklyIllustrationDefinition(
      id: 'review.not_helpful',
      hint: '没帮助',
      asset: 'assets/weekly/weekly-review-not-helpful.png',
    ),
    WeeklyIllustrationDefinition(
      id: 'review.adjust',
      hint: '想调整',
      asset: 'assets/weekly/weekly-review-adjust.png',
    ),
    WeeklyIllustrationDefinition(
      id: 'review.too_hard',
      hint: '太难了',
      asset: 'assets/weekly/weekly-review-too-hard.png',
    ),
    WeeklyIllustrationDefinition(
      id: 'review.too_complex',
      hint: '太复杂了',
      asset: 'assets/weekly/weekly-review-too-complex.png',
    ),
    WeeklyIllustrationDefinition(
      id: 'review.task_checkin_pressure',
      hint: '太像任务打卡',
      asset: 'assets/weekly/weekly-review-task-checkin-pressure.png',
    ),
    WeeklyIllustrationDefinition(
      id: 'review.too_long',
      hint: '时间太长',
      asset: 'assets/weekly/weekly-review-too-long.png',
    ),
    WeeklyIllustrationDefinition(
      id: 'review.under_ten_minutes',
      hint: '10 分钟以内更容易发生',
      asset: 'assets/weekly/weekly-review-under-ten-minutes.png',
    ),
    WeeklyIllustrationDefinition(
      id: 'review.body_action_effective',
      hint: '身体类小实验更有效',
      asset: 'assets/weekly/weekly-review-body-action-effective.png',
    ),
    WeeklyIllustrationDefinition(
      id: 'review.one_line_observation_effective',
      hint: '写一句观察更有效',
      asset: 'assets/weekly/weekly-review-one-line-observation-effective.png',
    ),
    WeeklyIllustrationDefinition(
      id: 'review.walk_effective',
      hint: '散步类行动更有效',
      asset: 'assets/weekly/weekly-review-walk-effective.png',
    ),
    WeeklyIllustrationDefinition(
      id: 'review.put_phone_down_effective',
      hint: '放下手机类行动有效',
      asset: 'assets/weekly/weekly-review-put-phone-down-effective.png',
    ),
    WeeklyIllustrationDefinition(
      id: 'review.organize_space_effective',
      hint: '整理环境类行动有效',
      asset: 'assets/weekly/weekly-review-organize-space-effective.png',
    ),
    WeeklyIllustrationDefinition(
      id: 'review.relationship_expression_effective',
      hint: '关系表达类行动有效',
      asset:
          'assets/weekly/weekly-review-relationship-expression-effective.png',
    ),
    WeeklyIllustrationDefinition(
      id: 'review.break_goal_smaller_effective',
      hint: '目标拆小类行动有效',
      asset: 'assets/weekly/weekly-review-break-goal-smaller-effective.png',
    ),
    WeeklyIllustrationDefinition(
      id: 'review.morning_easier',
      hint: '早上更容易做到',
      asset: 'assets/weekly/weekly-review-morning-easier.png',
    ),
    WeeklyIllustrationDefinition(
      id: 'review.evening_easier',
      hint: '晚上更容易做到',
      asset: 'assets/weekly/weekly-review-evening-easier.png',
    ),
    WeeklyIllustrationDefinition(
      id: 'review.weekend_easier',
      hint: '周末更容易做到',
      asset: 'assets/weekly/weekly-review-weekend-easier.png',
    ),
    WeeklyIllustrationDefinition(
      id: 'review.continuous_days',
      hint: '连续发生几天',
      asset: 'assets/weekly/weekly-review-continuous-days.png',
    ),
    WeeklyIllustrationDefinition(
      id: 'review.restart_after_interruption',
      hint: '中断后重新开始',
      asset: 'assets/weekly/weekly-review-restart-after-interruption.png',
    ),
    WeeklyIllustrationDefinition(
      id: 'review.partial_happened',
      hint: '部分发生',
      asset: 'assets/weekly/weekly-review-partial-happened.png',
    ),
    WeeklyIllustrationDefinition(
      id: 'review.observation_helpful',
      hint: '只是观察也有帮助',
      asset: 'assets/weekly/weekly-review-observation-helpful.png',
    ),
    WeeklyIllustrationDefinition(
      id: 'review.interrupted_by_schedule',
      hint: '被安排打断',
      asset: 'assets/weekly/weekly-review-interrupted-by-schedule.png',
    ),
    WeeklyIllustrationDefinition(
      id: 'review.interrupted_by_emotion',
      hint: '被情绪打断',
      asset: 'assets/weekly/weekly-review-interrupted-by-emotion.png',
    ),
    WeeklyIllustrationDefinition(
      id: 'review.next_week_branch',
      hint: '下周继续 / 停止 / 改小',
      asset: 'assets/weekly/weekly-review-next-week-branch.png',
    ),
  ];

  static const patternDefinitions = <WeeklyIllustrationDefinition>[
    WeeklyIllustrationDefinition(
        id: 'pattern.task_pile_start_blocked',
        hint: '任务堆积，开始变困难',
        asset: 'assets/weekly/weekly-pattern-task-pile-start-blocked.png'),
    WeeklyIllustrationDefinition(
        id: 'pattern.meeting_fragmented',
        hint: '会议密集，注意力被切碎',
        asset: 'assets/weekly/weekly-pattern-meeting-fragmented.png'),
    WeeklyIllustrationDefinition(
        id: 'pattern.route_interrupted',
        hint: '临时变化打断原本节奏',
        asset: 'assets/weekly/weekly-pattern-route-interrupted.png'),
    WeeklyIllustrationDefinition(
        id: 'pattern.rest_squeezed',
        hint: '休息时间被任务挤掉',
        asset: 'assets/weekly/weekly-pattern-rest-squeezed.png'),
    WeeklyIllustrationDefinition(
        id: 'pattern.stop_loop',
        hint: '想休息，但停下来后反而空转',
        asset: 'assets/weekly/weekly-pattern-stop-loop.png'),
    WeeklyIllustrationDefinition(
        id: 'pattern.night_phone',
        hint: '晚上刷手机变多',
        asset: 'assets/weekly/weekly-pattern-night-phone.png'),
    WeeklyIllustrationDefinition(
        id: 'pattern.morning_start_slow',
        hint: '早上启动困难',
        asset: 'assets/weekly/weekly-pattern-morning-start-slow.png'),
    WeeklyIllustrationDefinition(
        id: 'pattern.afternoon_energy_drop',
        hint: '中午以后精力明显下降',
        asset: 'assets/weekly/weekly-pattern-afternoon-energy-drop.png'),
    WeeklyIllustrationDefinition(
        id: 'pattern.schedule_driven_mood',
        hint: '情绪被日程密度带着走',
        asset: 'assets/weekly/weekly-pattern-schedule-driven-mood.png'),
    WeeklyIllustrationDefinition(
        id: 'pattern.anticipatory_anxiety',
        hint: '焦虑提前出现，还没开始就紧张',
        asset: 'assets/weekly/weekly-pattern-anticipatory-anxiety.png'),
    WeeklyIllustrationDefinition(
        id: 'pattern.done_more_tired',
        hint: '做完事后更累，不是更轻松',
        asset: 'assets/weekly/weekly-pattern-done-more-tired.png'),
    WeeklyIllustrationDefinition(
        id: 'pattern.large_plan_hard_start',
        hint: '计划越大，越容易不开始',
        asset: 'assets/weekly/weekly-pattern-large-plan-hard-start.png'),
    WeeklyIllustrationDefinition(
        id: 'pattern.too_many_goals_scattered',
        hint: '目标太多，注意力分散',
        asset: 'assets/weekly/weekly-pattern-too-many-goals-scattered.png'),
    WeeklyIllustrationDefinition(
        id: 'pattern.creation_squeezed_by_work',
        hint: '创作被工作挤掉',
        asset: 'assets/weekly/weekly-pattern-creation-squeezed-by-work.png'),
    WeeklyIllustrationDefinition(
        id: 'pattern.boundary_pushed_time_squeezed',
        hint: '不敢拒绝，自己的时间被挤占',
        asset:
            'assets/weekly/weekly-pattern-boundary-pushed-time-squeezed.png'),
    WeeklyIllustrationDefinition(
        id: 'pattern.people_pleasing_tired',
        hint: '过度迎合后感到疲惫',
        asset: 'assets/weekly/weekly-pattern-people-pleasing-tired.png'),
    WeeklyIllustrationDefinition(
        id: 'pattern.unclear_expression',
        hint: '想表达，但说不清',
        asset: 'assets/weekly/weekly-pattern-unclear-expression.png'),
    WeeklyIllustrationDefinition(
        id: 'pattern.solitude_insufficient',
        hint: '独处不足，恢复变慢',
        asset: 'assets/weekly/weekly-pattern-solitude-insufficient.png'),
    WeeklyIllustrationDefinition(
        id: 'pattern.messy_environment_mood',
        hint: '生活环境混乱，心情也乱',
        asset: 'assets/weekly/weekly-pattern-messy-environment-mood.png'),
    WeeklyIllustrationDefinition(
        id: 'pattern.relationship_dialogue_rumination',
        hint: '关系对话后反复内耗',
        asset:
            'assets/weekly/weekly-pattern-relationship-dialogue-rumination.png'),
    WeeklyIllustrationDefinition(
        id: 'pattern.money_safety_pressure',
        hint: '金钱或现实压力牵动安全感',
        asset: 'assets/weekly/weekly-pattern-money-safety-pressure.png'),
    WeeklyIllustrationDefinition(
        id: 'pattern.body_signal_before_tired',
        hint: '身体信号先出现，才意识到累',
        asset: 'assets/weekly/weekly-pattern-body-signal-before-tired.png'),
    WeeklyIllustrationDefinition(
        id: 'pattern.small_action_stabilizes',
        hint: '小实验有效，节奏开始稳定',
        asset: 'assets/weekly/weekly-pattern-small-action-stabilizes.png'),
    WeeklyIllustrationDefinition(
        id: 'pattern.interest_recovery',
        hint: '兴趣活动带来恢复感',
        asset: 'assets/weekly/weekly-pattern-interest-recovery.png'),
  ];

  static WeeklyIllustrationDefinition? reviewForId(String raw) =>
      _byId(reviewDefinitions, raw);

  static WeeklyIllustrationDefinition? patternForId(String raw) =>
      _byId(patternDefinitions, raw);

  static WeeklyIllustrationDefinition? reviewForHint(String raw) =>
      _byHint(reviewDefinitions, raw);

  static WeeklyIllustrationDefinition? patternForHint(String raw) =>
      _byHint(patternDefinitions, raw);

  static WeeklyIllustrationDefinition? reviewForText(String raw) {
    final text = _normalize(raw);
    if (text.isEmpty) return null;
    final exact = reviewForHint(raw) ?? reviewForId(raw);
    if (exact != null) return exact;
    for (final rule in _reviewTextRules) {
      if (rule.$2.any(text.contains)) return reviewForId(rule.$1);
    }
    return null;
  }

  static WeeklyIllustrationDefinition? patternForText(String raw) {
    final text = _normalize(raw);
    if (text.isEmpty) return null;
    final exact = patternForHint(raw) ?? patternForId(raw);
    if (exact != null) return exact;
    for (final definition in patternDefinitions) {
      if (text.contains(_normalize(definition.hint))) return definition;
    }
    return null;
  }

  static WeeklyIllustrationDefinition? forText(String raw) =>
      reviewForText(raw) ?? patternForText(raw);

  static String? assetForText(String raw) => forText(raw)?.asset;

  static WeeklyIllustrationDefinition? _byId(
    List<WeeklyIllustrationDefinition> definitions,
    String raw,
  ) {
    final value = _normalize(raw).replaceAll(' ', '_');
    for (final definition in definitions) {
      if (_normalize(definition.id).replaceAll(' ', '_') == value) {
        return definition;
      }
    }
    return null;
  }

  static WeeklyIllustrationDefinition? _byHint(
    List<WeeklyIllustrationDefinition> definitions,
    String raw,
  ) {
    final value = _normalize(raw);
    for (final definition in definitions) {
      if (_normalize(definition.hint) == value) return definition;
    }
    return null;
  }

  static String _normalize(String raw) => raw
      .trim()
      .toLowerCase()
      .replaceAll('　', ' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  static const _reviewTextRules = <(String, List<String>)>[
    (
      'review.task_checkin_pressure',
      ['太像任务打卡', '像任务打卡', '清单压力', 'checkin pressure']
    ),
    ('review.too_long', ['时间太长', '太长', 'too long']),
    ('review.under_ten_minutes', ['10 分钟以内', '10分钟以内', '十分钟以内', 'under ten']),
    (
      'review.body_action_effective',
      [
        '身体类小实验更有效',
        // Legacy aliases remain matchable, but are never selected as the
        // user-visible label.
        '身体类小尝试更有效',
        '身体类小行动更有效',
        'body action effective'
      ]
    ),
    (
      'review.one_line_observation_effective',
      ['写一句观察更有效', '一句观察', 'one line observation']
    ),
    ('review.walk_effective', ['散步类行动更有效', '散步类', 'walk effective']),
    (
      'review.put_phone_down_effective',
      ['放下手机类行动有效', '放下手机', 'put phone down']
    ),
    (
      'review.organize_space_effective',
      ['整理环境类行动有效', '整理环境', 'organize space']
    ),
    (
      'review.relationship_expression_effective',
      ['关系表达类行动有效', '关系表达', 'relationship expression']
    ),
    (
      'review.break_goal_smaller_effective',
      ['目标拆小类行动有效', '目标拆小', 'break goal smaller']
    ),
    ('review.morning_easier', ['早上更容易做到', '早上更容易', 'morning easier']),
    ('review.evening_easier', ['晚上更容易做到', '晚上更容易', 'evening easier']),
    ('review.weekend_easier', ['周末更容易做到', '周末更容易', 'weekend easier']),
    ('review.continuous_days', ['连续发生几天', '连续几天', 'continuous days']),
    (
      'review.restart_after_interruption',
      ['中断后重新开始', '重新开始', 'restart after interruption']
    ),
    ('review.partial_happened', ['部分发生', 'partial happened']),
    (
      'review.observation_helpful',
      ['只是观察也有帮助', '观察也有帮助', 'observation helpful']
    ),
    ('review.interrupted_by_schedule', ['被安排打断', 'interrupted by schedule']),
    ('review.interrupted_by_emotion', ['被情绪打断', 'interrupted by emotion']),
    ('review.next_week_branch', ['下周继续', '继续 / 停止 / 改小', 'next week branch']),
    ('review.not_suitable_today', ['今天不适合', '不适合']),
    ('review.not_helpful', ['没帮助', '没有帮助', 'not helpful']),
    ('review.too_complex', ['太复杂', '复杂了', 'too complex']),
    ('review.too_hard', ['太难了', '太难', 'too hard']),
    ('review.helpful', ['有帮助', 'helpful', 'helped']),
    ('review.not_done', ['没做到', '沒有做到', 'not_done', 'not completed', 'missed']),
    ('review.skip', ['不想做', '暂时不做', 'skip', 'not want']),
    ('review.neutral', ['一般', 'neutral', 'ordinary']),
    ('review.adjust', ['想调整', '调整后再试', '调轻一点', 'adjust']),
    ('review.done', ['做到了', '已完成', 'completed', 'done']),
  ];
}

class WeeklyReviewIllustrationSelection {
  final WeeklyIllustrationDefinition definition;
  final int count;
  final DateTime? latestAt;

  const WeeklyReviewIllustrationSelection({
    required this.definition,
    required this.count,
    this.latestAt,
  });
}

/// Chooses one representative *real feedback* illustration for a week.
///
/// Ordering is deterministic: frequency, latest occurrence, then canonical ID.
/// Non-attempt feedback is ignored, and no-data returns null rather than
/// fabricating a behavior.
class WeeklyReviewIllustrationSelector {
  const WeeklyReviewIllustrationSelector._();

  static WeeklyReviewIllustrationSelection? select({
    Map<String, dynamic>? opportunitySnapshot,
    Map<String, dynamic>? actionReview,
  }) {
    final summary = _map(opportunitySnapshot?['_feedback_event_summary']);
    final events = (summary?['events'] as List?)
            ?.whereType<Map>()
            .map(_map)
            .whereType<Map<String, dynamic>>()
            .where(_isAttemptFeedback)
            .toList(growable: false) ??
        const <Map<String, dynamic>>[];

    final buckets = <String, _SelectionBucket>{};
    for (final event in events) {
      final definition = _definitionForEvent(event);
      if (definition == null) continue;
      final latest = _eventDate(event);
      final bucket = buckets.putIfAbsent(
        definition.id,
        () => _SelectionBucket(definition),
      );
      bucket.count += 1;
      if (latest != null &&
          (bucket.latestAt == null || latest.isAfter(bucket.latestAt!))) {
        bucket.latestAt = latest;
      }
    }

    if (buckets.isNotEmpty) {
      final sorted = buckets.values.toList()
        ..sort((first, second) {
          final count = second.count.compareTo(first.count);
          if (count != 0) return count;
          final recent = (second.latestAt?.millisecondsSinceEpoch ?? 0)
              .compareTo(first.latestAt?.millisecondsSinceEpoch ?? 0);
          if (recent != 0) return recent;
          return first.definition.id.compareTo(second.definition.id);
        });
      final winner = sorted.first;
      final refined = _refineFromActionReview(
        winner.definition,
        _map(actionReview),
      );
      return WeeklyReviewIllustrationSelection(
        definition: refined,
        count: winner.count,
        latestAt: winner.latestAt,
      );
    }

    return _fallbackFromActionReview(_map(actionReview));
  }

  static bool _isAttemptFeedback(Map<String, dynamic> event) {
    final subject = _text(event['subject_type']).toLowerCase();
    final source = _text(event['source_type']).toLowerCase();
    return subject == 'micro_action' ||
        subject == 'life_experiment' ||
        source == 'micro_action_feedback' ||
        source == 'life_experiment_feedback';
  }

  static WeeklyIllustrationDefinition? _definitionForEvent(
    Map<String, dynamic> event,
  ) {
    final metadata = _map(event['metadata']) ?? const <String, dynamic>{};
    final direct = WeeklyIllustrationCatalog.reviewForId(
          _text(metadata['feedback_pattern_id']),
        ) ??
        WeeklyIllustrationCatalog.reviewForHint(
          _text(metadata['feedback_pattern_id']),
        );
    if (direct != null) return direct;

    final noteText = [
      event['note'],
      metadata['feedback_text'],
      metadata['user_note'],
      metadata['condition_tags'],
    ].map(_text).where((value) => value.isNotEmpty).join(' ');
    final fromNote = WeeklyIllustrationCatalog.reviewForText(noteText);
    if (fromNote != null) return fromNote;

    final difficulty = _text(metadata['difficulty']);
    final nextAdjustment = _text(metadata['next_adjustment']);
    final fromDetail = WeeklyIllustrationCatalog.reviewForText(
      '$difficulty $nextAdjustment',
    );
    if (fromDetail != null) return fromDetail;

    final effect = _text(event['effect']).isNotEmpty
        ? _text(event['effect'])
        : _text(metadata['effect']);
    final score = int.tryParse(effect) ?? _int(metadata['helpfulness_score']);
    if (score != null) {
      if (score >= 4) {
        return WeeklyIllustrationCatalog.reviewForId('review.helpful');
      }
      if (score <= 2) {
        return WeeklyIllustrationCatalog.reviewForId('review.not_helpful');
      }
      return WeeklyIllustrationCatalog.reviewForId('review.neutral');
    }
    final normalizedEffect = effect.toLowerCase();
    if (const {
      'helpful',
      'very_helpful',
      'helped',
      'lighter',
      'better',
      'positive',
      'recovery',
      'energizing',
      'yes',
      'somewhat',
    }.contains(normalizedEffect)) {
      return WeeklyIllustrationCatalog.reviewForId('review.helpful');
    }
    if (const {'neutral', 'general', 'okay'}.contains(normalizedEffect)) {
      return WeeklyIllustrationCatalog.reviewForId('review.neutral');
    }
    if (const {'not_helpful', 'worse', 'negative', 'no'}
        .contains(normalizedEffect)) {
      return WeeklyIllustrationCatalog.reviewForId('review.not_helpful');
    }

    final status = _text(event['status']).isNotEmpty
        ? _text(event['status'])
        : _text(metadata['completion_status']);
    return switch (status.toLowerCase()) {
      'completed' ||
      'done' ||
      'happened' ||
      'yes' ||
      'tried' =>
        WeeklyIllustrationCatalog.reviewForId('review.done'),
      'partial' ||
      'partially_completed' =>
        WeeklyIllustrationCatalog.reviewForId('review.partial_happened'),
      'not_completed' ||
      'not_done' ||
      'not_happened' ||
      'no' ||
      'missed' =>
        WeeklyIllustrationCatalog.reviewForId('review.not_done'),
      'not_suitable_today' ||
      'not_suitable' =>
        WeeklyIllustrationCatalog.reviewForId('review.not_suitable_today'),
      'skipped' ||
      'skip' ||
      'paused' ||
      'pause' =>
        WeeklyIllustrationCatalog.reviewForId('review.skip'),
      _ => null,
    };
  }

  static WeeklyIllustrationDefinition _refineFromActionReview(
    WeeklyIllustrationDefinition definition,
    Map<String, dynamic>? review,
  ) {
    if (review == null) return definition;
    String detail = '';
    if (definition.id == 'review.helpful') {
      detail = _text(review['most_helpful_action']);
      final hint = _helpfulHint(detail);
      return WeeklyIllustrationCatalog.reviewForHint(hint) ?? definition;
    }
    if (definition.id == 'review.too_hard' ||
        definition.id == 'review.not_helpful') {
      detail = _text(review['hardest_action']);
      final hint = _hardHint(detail);
      return WeeklyIllustrationCatalog.reviewForHint(hint) ?? definition;
    }
    if (definition.id == 'review.adjust') {
      detail = _text(review['next_adjustment']);
      return WeeklyIllustrationCatalog.reviewForText(detail) ?? definition;
    }
    return definition;
  }

  static WeeklyReviewIllustrationSelection? _fallbackFromActionReview(
    Map<String, dynamic>? review,
  ) {
    if (review == null) return null;
    final tried = _int(review['tried_action_count']) ?? 0;
    if (tried <= 0) return null;
    final helpful = _int(review['helpful_action_count']) ?? 0;
    final helpfulTitle = _text(review['most_helpful_action']);
    final hardTitle = _text(review['hardest_action']);
    final hard = (tried - helpful).clamp(0, tried);
    final candidates = <_SelectionBucket>[];
    if (helpful > 0) {
      final definition = WeeklyIllustrationCatalog.reviewForHint(
            _helpfulHint(helpfulTitle),
          ) ??
          WeeklyIllustrationCatalog.reviewForId('review.helpful')!;
      candidates.add(_SelectionBucket(definition)..count = helpful);
    }
    if (hard > 0 && hardTitle.isNotEmpty) {
      final definition = WeeklyIllustrationCatalog.reviewForHint(
            _hardHint(hardTitle),
          ) ??
          WeeklyIllustrationCatalog.reviewForId('review.too_hard')!;
      candidates.add(_SelectionBucket(definition)..count = hard);
    }
    if (candidates.isEmpty) {
      final definition = WeeklyIllustrationCatalog.reviewForId('review.done')!;
      return WeeklyReviewIllustrationSelection(
        definition: definition,
        count: tried,
      );
    }
    candidates.sort((first, second) {
      final count = second.count.compareTo(first.count);
      if (count != 0) return count;
      return first.definition.id.compareTo(second.definition.id);
    });
    final winner = candidates.first;
    return WeeklyReviewIllustrationSelection(
      definition: winner.definition,
      count: winner.count,
    );
  }

  static String _helpfulHint(String text) {
    final source = text.toLowerCase();
    if (_containsAny(source, const ['10', '十分钟', '分钟', '短'])) {
      return '10 分钟以内更容易发生';
    }
    if (_containsAny(source, const ['身体', '拉伸', '呼吸', '放松'])) {
      return '身体类小实验更有效';
    }
    if (_containsAny(source, const ['写', '观察', '一句', '记录'])) {
      return '写一句观察更有效';
    }
    if (_containsAny(source, const ['散步', '走路'])) return '散步类行动更有效';
    if (_containsAny(source, const ['手机', '屏幕', '刷'])) return '放下手机类行动有效';
    if (_containsAny(source, const ['整理', '房间', '环境', '收纳'])) {
      return '整理环境类行动有效';
    }
    if (_containsAny(source, const ['关系', '表达', '对话', '沟通'])) {
      return '关系表达类行动有效';
    }
    if (_containsAny(source, const ['拆', '目标', '小步', '小一点'])) {
      return '目标拆小类行动有效';
    }
    return '有帮助';
  }

  static String _hardHint(String text) {
    final source = text.toLowerCase();
    if (_containsAny(source, const ['打卡', '任务', '清单', '必须'])) return '太像任务打卡';
    if (_containsAny(source, const ['太长', '很久', '半小时', '30', '一小时'])) {
      return '时间太长';
    }
    if (_containsAny(source, const ['复杂', '步骤', '太多', '流程'])) return '太复杂了';
    return '太难了';
  }

  static bool _containsAny(String text, List<String> tokens) =>
      tokens.any(text.contains);

  static Map<String, dynamic>? _map(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry('$key', value));
    }
    return null;
  }

  static String _text(Object? raw) {
    if (raw is Iterable) {
      return raw.map(_text).where((value) => value.isNotEmpty).join(' ');
    }
    return raw?.toString().trim() ?? '';
  }

  static int? _int(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(_text(raw));
  }

  static DateTime? _eventDate(Map<String, dynamic> event) {
    for (final key in const [
      'created_at',
      'occurred_at',
      'updated_at',
      'local_date',
    ]) {
      final value = DateTime.tryParse(_text(event[key]));
      if (value != null) return value;
    }
    return null;
  }
}

class _SelectionBucket {
  final WeeklyIllustrationDefinition definition;
  int count = 0;
  DateTime? latestAt;

  _SelectionBucket(this.definition);
}
