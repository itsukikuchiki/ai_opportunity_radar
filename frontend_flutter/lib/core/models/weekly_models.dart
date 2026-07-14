import 'dart:convert';

import '../debug/legacy_fallback_monitor.dart';
import '../readiness/report_readiness.dart';

class WeeklyChartPointModel {
  final String date;
  final int signalCount;
  final double moodScore;
  final double frictionScore;
  final bool hasPositiveSignal;

  const WeeklyChartPointModel({
    required this.date,
    required this.signalCount,
    required this.moodScore,
    required this.frictionScore,
    required this.hasPositiveSignal,
  });

  factory WeeklyChartPointModel.fromJson(Map<String, dynamic> json) {
    return WeeklyChartPointModel(
      date: (json['date'] as String?) ?? '',
      signalCount: (json['signal_count'] as num?)?.toInt() ?? 0,
      moodScore: (json['mood_score'] as num?)?.toDouble() ?? 0,
      frictionScore: (json['friction_score'] as num?)?.toDouble() ?? 0,
      hasPositiveSignal: (json['has_positive_signal'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'signal_count': signalCount,
      'mood_score': moodScore,
      'friction_score': frictionScore,
      'has_positive_signal': hasPositiveSignal,
    };
  }
}

class WeeklyTopicFocusModel {
  final String headline;
  final String reason;
  final String nextWatch;

  const WeeklyTopicFocusModel({
    required this.headline,
    required this.reason,
    required this.nextWatch,
  });
}

class WeeklyV3CStructureModel {
  final String lightObservation;
  final String onePattern;
  final String oneExperiment;
  final String positiveSignal;

  const WeeklyV3CStructureModel({
    required this.lightObservation,
    required this.onePattern,
    required this.oneExperiment,
    required this.positiveSignal,
  });
}

class WeeklyActionPlanModel {
  final String title;
  final String mediumRangeGoal;
  final String smallExperiment;
  final String? sourceExperimentId;

  const WeeklyActionPlanModel({
    required this.title,
    required this.mediumRangeGoal,
    required this.smallExperiment,
    this.sourceExperimentId,
  });
}

class WeeklyInclusionSummaryModel {
  final int usedCount;
  final int timelineOnlyCount;
  final int excludedCount;
  final int legacyReferenceCount;

  const WeeklyInclusionSummaryModel({
    required this.usedCount,
    required this.timelineOnlyCount,
    required this.excludedCount,
    required this.legacyReferenceCount,
  });

  factory WeeklyInclusionSummaryModel.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const WeeklyInclusionSummaryModel(
        usedCount: 0,
        timelineOnlyCount: 0,
        excludedCount: 0,
        legacyReferenceCount: 0,
      );
    }
    return WeeklyInclusionSummaryModel(
      usedCount: (map['used_count'] as num?)?.toInt() ?? 0,
      timelineOnlyCount: (map['timeline_only_count'] as num?)?.toInt() ?? 0,
      excludedCount: (map['excluded_count'] as num?)?.toInt() ?? 0,
      legacyReferenceCount:
          (map['legacy_reference_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class LifeExperimentModel {
  final String id;
  final String localUserId;
  final String sourceWeekStart;
  final String sourceWeekEnd;
  final String? parentExperimentId;
  final String title;
  final String hypothesis;
  final String suggestedAction;
  final List<String> linkedSignalCardIds;
  final String status;
  final String? feedbackText;
  final String? focusAreaId;
  final String? patternId;
  final String? feedbackPatternId;
  final String? iconAssetId;
  final String? plannedFrequency;
  final int? plannedDurationMinutes;
  final int? plannedTotalDays;
  final String? originCandidateId;
  final DateTime? adoptedAt;
  final String? progressStartDate;
  final String? progressEndDate;
  final bool sourceChanged;
  final String? sourceChangeReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const LifeExperimentModel({
    required this.id,
    required this.localUserId,
    required this.sourceWeekStart,
    required this.sourceWeekEnd,
    this.parentExperimentId,
    required this.title,
    required this.hypothesis,
    required this.suggestedAction,
    required this.linkedSignalCardIds,
    required this.status,
    this.feedbackText,
    this.focusAreaId,
    this.patternId,
    this.feedbackPatternId,
    this.iconAssetId,
    this.plannedFrequency,
    this.plannedDurationMinutes,
    this.plannedTotalDays,
    this.originCandidateId,
    this.adoptedAt,
    this.progressStartDate,
    this.progressEndDate,
    this.sourceChanged = false,
    this.sourceChangeReason,
    this.createdAt,
    this.updatedAt,
  });

  factory LifeExperimentModel.fromJson(Map<String, dynamic> json) {
    return LifeExperimentModel(
      id: _readString(json, const ['id']),
      localUserId: _readString(json, const ['local_user_id', 'localUserId']),
      sourceWeekStart:
          _readString(json, const ['source_week_start', 'sourceWeekStart']),
      sourceWeekEnd:
          _readString(json, const ['source_week_end', 'sourceWeekEnd']),
      parentExperimentId: _nullableString(
        json,
        const ['parent_experiment_id', 'parentExperimentId'],
      ),
      title: _readString(json, const ['title']),
      hypothesis: _readString(json, const ['hypothesis']),
      suggestedAction:
          _readString(json, const ['suggested_action', 'suggestedAction']),
      linkedSignalCardIds: _parseStringList(
        json['linked_signal_card_ids'] ??
            json['linkedSignalCardIds'] ??
            json['linked_signal_card_ids_json'],
      ),
      status: _readString(json, const ['status'], fallback: 'suggested'),
      feedbackText:
          _nullableString(json, const ['feedback_text', 'feedbackText']),
      focusAreaId: _nullableString(
        json,
        const ['focus_area_id', 'focusAreaId'],
      ),
      patternId: _nullableString(json, const ['pattern_id', 'patternId']),
      feedbackPatternId: _nullableString(
        json,
        const ['feedback_pattern_id', 'feedbackPatternId'],
      ),
      iconAssetId:
          _nullableString(json, const ['icon_asset_id', 'iconAssetId']),
      plannedFrequency: _nullableString(
        json,
        const ['planned_frequency', 'plannedFrequency'],
      ),
      plannedDurationMinutes: _parseInt(
        json['planned_duration_minutes'] ?? json['plannedDurationMinutes'],
      ),
      plannedTotalDays: _parseInt(
        json['planned_total_days'] ?? json['plannedTotalDays'],
      ),
      originCandidateId: _nullableString(
        json,
        const ['origin_candidate_id', 'originCandidateId'],
      ),
      adoptedAt: _parseDateTime(json['adopted_at'] ?? json['adoptedAt']),
      progressStartDate: _nullableString(
        json,
        const ['progress_start_date', 'progressStartDate'],
      ),
      progressEndDate: _nullableString(
        json,
        const ['progress_end_date', 'progressEndDate'],
      ),
      sourceChanged:
          _parseBool(json['source_changed'] ?? json['sourceChanged']),
      sourceChangeReason: _nullableString(
        json,
        const ['source_change_reason', 'sourceChangeReason'],
      ),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'local_user_id': localUserId,
      'source_week_start': sourceWeekStart,
      'source_week_end': sourceWeekEnd,
      'parent_experiment_id': parentExperimentId,
      'title': title,
      'hypothesis': hypothesis,
      'suggested_action': suggestedAction,
      'linked_signal_card_ids': linkedSignalCardIds,
      'status': status,
      'feedback_text': feedbackText,
      'focus_area_id': focusAreaId,
      'pattern_id': patternId,
      'feedback_pattern_id': feedbackPatternId,
      'icon_asset_id': iconAssetId,
      'planned_frequency': plannedFrequency,
      'planned_duration_minutes': plannedDurationMinutes,
      'planned_total_days': plannedTotalDays,
      'origin_candidate_id': originCandidateId,
      'adopted_at': adoptedAt?.toUtc().toIso8601String(),
      'progress_start_date': progressStartDate,
      'progress_end_date': progressEndDate,
      'source_changed': sourceChanged,
      'source_change_reason': sourceChangeReason,
      'created_at': createdAt?.toUtc().toIso8601String(),
      'updated_at': updatedAt?.toUtc().toIso8601String(),
    };
  }

  LifeExperimentModel copyWith({
    String? parentExperimentId,
    String? title,
    String? hypothesis,
    String? suggestedAction,
    String? status,
    String? feedbackText,
    String? focusAreaId,
    String? patternId,
    String? feedbackPatternId,
    String? iconAssetId,
    String? plannedFrequency,
    int? plannedDurationMinutes,
    int? plannedTotalDays,
    String? originCandidateId,
    DateTime? adoptedAt,
    String? progressStartDate,
    String? progressEndDate,
    bool? sourceChanged,
    String? sourceChangeReason,
    DateTime? updatedAt,
  }) {
    return LifeExperimentModel(
      id: id,
      localUserId: localUserId,
      sourceWeekStart: sourceWeekStart,
      sourceWeekEnd: sourceWeekEnd,
      parentExperimentId: parentExperimentId ?? this.parentExperimentId,
      title: title ?? this.title,
      hypothesis: hypothesis ?? this.hypothesis,
      suggestedAction: suggestedAction ?? this.suggestedAction,
      linkedSignalCardIds: linkedSignalCardIds,
      status: status ?? this.status,
      feedbackText: feedbackText ?? this.feedbackText,
      focusAreaId: focusAreaId ?? this.focusAreaId,
      patternId: patternId ?? this.patternId,
      feedbackPatternId: feedbackPatternId ?? this.feedbackPatternId,
      iconAssetId: iconAssetId ?? this.iconAssetId,
      plannedFrequency: plannedFrequency ?? this.plannedFrequency,
      plannedDurationMinutes:
          plannedDurationMinutes ?? this.plannedDurationMinutes,
      plannedTotalDays: plannedTotalDays ?? this.plannedTotalDays,
      originCandidateId: originCandidateId ?? this.originCandidateId,
      adoptedAt: adoptedAt ?? this.adoptedAt,
      progressStartDate: progressStartDate ?? this.progressStartDate,
      progressEndDate: progressEndDate ?? this.progressEndDate,
      sourceChanged: sourceChanged ?? this.sourceChanged,
      sourceChangeReason: sourceChangeReason ?? this.sourceChangeReason,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class LifeExperimentFeedbackModel {
  final String id;
  final String experimentId;
  final String localUserId;
  final DateTime feedbackDate;
  final String localDate;
  final String completionStatus;
  final int? helpfulnessScore;
  final String? feedbackText;
  final List<String> conditionTags;
  final int? durationMinutes;
  final String? timeSlot;
  final String? patternId;
  final String? feedbackPatternId;
  final String? focusAreaId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const LifeExperimentFeedbackModel({
    required this.id,
    required this.experimentId,
    required this.localUserId,
    required this.feedbackDate,
    required this.localDate,
    required this.completionStatus,
    this.helpfulnessScore,
    this.feedbackText,
    this.conditionTags = const [],
    this.durationMinutes,
    this.timeSlot,
    this.patternId,
    this.feedbackPatternId,
    this.focusAreaId,
    this.createdAt,
    this.updatedAt,
  });

  factory LifeExperimentFeedbackModel.fromJson(Map<String, dynamic> json) {
    final feedbackDate = _parseDateTime(json['feedback_date']) ??
        _parseDateTime(json['created_at']) ??
        DateTime.now();
    final legacyContext = _nullableString(json, const ['trigger_context']);
    final tags = _parseStringList(
      json['condition_tags'] ?? json['condition_tags_json'],
    );
    final mergedTags = <String>{...tags};
    if (legacyContext != null && legacyContext.trim().isNotEmpty) {
      mergedTags.add(legacyContext.trim());
    }

    return LifeExperimentFeedbackModel(
      id: _readString(json, const ['id']),
      experimentId: _readString(json, const ['experiment_id', 'experimentId']),
      localUserId: _readString(json, const ['local_user_id', 'localUserId']),
      feedbackDate: feedbackDate,
      localDate: _readString(
        json,
        const ['local_date', 'localDate'],
        fallback: _dateKey(feedbackDate),
      ),
      completionStatus: _readString(
        json,
        const ['completion_status', 'completionStatus'],
        fallback: _completionStatusFromLegacy(json['happened']),
      ),
      helpfulnessScore: _parseInt(json['helpfulness_score']) ??
          _helpfulnessFromLegacy(json['effect']),
      feedbackText:
          _nullableString(json, const ['feedback_text', 'feedbackText']) ??
              _nullableString(json, const ['comment']),
      conditionTags: mergedTags.toList(),
      durationMinutes: _parseInt(
        json['duration_minutes'] ?? json['actual_duration_minutes'],
      ),
      timeSlot: _nullableString(json, const ['time_slot', 'timeSlot']) ??
          legacyContext,
      patternId: _nullableString(json, const ['pattern_id', 'patternId']),
      feedbackPatternId: _nullableString(
        json,
        const ['feedback_pattern_id', 'feedbackPatternId'],
      ),
      focusAreaId:
          _nullableString(json, const ['focus_area_id', 'focusAreaId']),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'experiment_id': experimentId,
      'local_user_id': localUserId,
      'feedback_date': feedbackDate.toUtc().toIso8601String(),
      'local_date': localDate,
      'completion_status': completionStatus,
      'helpfulness_score': helpfulnessScore,
      'feedback_text': feedbackText,
      'condition_tags': conditionTags,
      'condition_tags_json': jsonEncode(conditionTags),
      'duration_minutes': durationMinutes,
      'time_slot': timeSlot,
      'pattern_id': patternId,
      'feedback_pattern_id': feedbackPatternId,
      'focus_area_id': focusAreaId,
      'created_at': createdAt?.toUtc().toIso8601String(),
      'updated_at': updatedAt?.toUtc().toIso8601String(),
    };
  }
}

DateTime? _parseDateTime(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  if (raw is String && raw.trim().isNotEmpty) {
    return DateTime.tryParse(raw);
  }
  return null;
}

String _readString(
  Map<String, dynamic> json,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final raw = json[key];
    if (raw == null) continue;
    final value = raw.toString().trim();
    if (value.isNotEmpty) return value;
  }
  return fallback;
}

String? _nullableString(Map<String, dynamic> json, List<String> keys) {
  final value = _readString(json, keys);
  return value.isEmpty ? null : value;
}

List<String> _parseStringList(dynamic raw) {
  if (raw == null) return const [];
  if (raw is List) {
    return raw
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
  }
  if (raw is String && raw.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      return _parseStringList(decoded);
    } catch (_) {
      return raw
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
  }
  return const [];
}

int? _parseInt(dynamic raw) {
  if (raw == null) return null;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw.trim());
  return null;
}

bool _parseBool(dynamic raw) {
  if (raw is bool) return raw;
  if (raw is num) return raw != 0;
  final value = raw?.toString().trim().toLowerCase();
  return value == 'true' || value == '1' || value == 'yes';
}

String _completionStatusFromLegacy(dynamic raw) {
  if (raw == null) return 'unknown';
  if (raw is bool) return raw ? 'done' : 'not_done';
  if (raw is num) return raw == 0 ? 'not_done' : 'done';
  final value = raw.toString().trim().toLowerCase();
  if (value.isEmpty) return 'unknown';
  if (value == 'true' || value == 'yes' || value == 'done' || value == '1') {
    return 'done';
  }
  if (value == 'false' ||
      value == 'no' ||
      value == 'not_done' ||
      value == '0') {
    return 'not_done';
  }
  return value;
}

int? _helpfulnessFromLegacy(dynamic raw) {
  if (raw == null) return null;
  if (raw is num) return raw.toInt();
  final value = raw.toString().trim().toLowerCase();
  if (value.isEmpty) return null;
  if (value.contains('help') ||
      value.contains('effective') ||
      value.contains('有帮助') ||
      value.contains('有效')) {
    return 5;
  }
  if (value.contains('general') || value.contains('一般')) return 3;
  if (value.contains('no') || value.contains('没帮助') || value.contains('无效')) {
    return 1;
  }
  return null;
}

String _dateKey(DateTime date) {
  final local = date.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

class WeeklyActionReviewModel {
  final int aiJudgementCount;
  final int confirmedJudgementCount;
  final int generatedActionCount;
  final int triedActionCount;
  final int helpfulActionCount;
  final String mostHelpfulAction;
  final String hardestAction;
  final String nextAdjustment;
  final List<String> linkedMicroActionIds;

  const WeeklyActionReviewModel({
    this.aiJudgementCount = 0,
    this.confirmedJudgementCount = 0,
    this.generatedActionCount = 0,
    this.triedActionCount = 0,
    this.helpfulActionCount = 0,
    this.mostHelpfulAction = '',
    this.hardestAction = '',
    this.nextAdjustment = '',
    this.linkedMicroActionIds = const [],
  });

  bool get hasData =>
      aiJudgementCount > 0 ||
      generatedActionCount > 0 ||
      triedActionCount > 0 ||
      helpfulActionCount > 0;

  factory WeeklyActionReviewModel.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const WeeklyActionReviewModel();
    return WeeklyActionReviewModel(
      aiJudgementCount: (map['ai_judgement_count'] as num?)?.toInt() ?? 0,
      confirmedJudgementCount:
          (map['confirmed_judgement_count'] as num?)?.toInt() ?? 0,
      generatedActionCount:
          (map['generated_action_count'] as num?)?.toInt() ?? 0,
      triedActionCount: (map['tried_action_count'] as num?)?.toInt() ?? 0,
      helpfulActionCount: (map['helpful_action_count'] as num?)?.toInt() ?? 0,
      mostHelpfulAction: (map['most_helpful_action'] as String?) ?? '',
      hardestAction: (map['hardest_action'] as String?) ?? '',
      nextAdjustment: (map['next_adjustment'] as String?) ?? '',
      linkedMicroActionIds:
          ((map['linked_micro_action_ids'] as List?) ?? const [])
              .map((e) => e?.toString() ?? '')
              .where((e) => e.trim().isNotEmpty)
              .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ai_judgement_count': aiJudgementCount,
      'confirmed_judgement_count': confirmedJudgementCount,
      'generated_action_count': generatedActionCount,
      'tried_action_count': triedActionCount,
      'helpful_action_count': helpfulActionCount,
      'most_helpful_action': mostHelpfulAction,
      'hardest_action': hardestAction,
      'next_adjustment': nextAdjustment,
      'linked_micro_action_ids': linkedMicroActionIds,
    };
  }
}

class WeeklyInsightModel {
  final String weekStart;
  final String weekEnd;
  final String status;
  final String? keyInsight;
  final List<dynamic> patterns;
  final List<dynamic> frictions;
  final String? bestAction;
  final Map<String, dynamic>? opportunitySnapshot;
  final bool feedbackSubmitted;
  final List<WeeklyChartPointModel> chartData;

  WeeklyInsightModel({
    required this.weekStart,
    required this.weekEnd,
    required this.status,
    required this.keyInsight,
    required this.patterns,
    required this.frictions,
    required this.bestAction,
    required this.opportunitySnapshot,
    required this.feedbackSubmitted,
    this.chartData = const [],
  });

  factory WeeklyInsightModel.fromJson(Map<String, dynamic> json) {
    return WeeklyInsightModel(
      weekStart: json['week_start'] as String,
      weekEnd: json['week_end'] as String,
      status: json['status'] as String,
      keyInsight: json['key_insight'] as String?,
      patterns: (json['patterns'] as List?) ?? [],
      frictions: (json['frictions'] as List?) ?? [],
      bestAction: json['best_action'] as String?,
      opportunitySnapshot:
          json['opportunity_snapshot'] as Map<String, dynamic>?,
      feedbackSubmitted: (json['feedback_submitted'] as bool?) ?? false,
      chartData: ((json['chart_data'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => WeeklyChartPointModel.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }

  bool get isLightReady => status == 'light_ready';
  bool get isReady => status == 'ready';

  WeeklyInclusionSummaryModel get inclusionSummary {
    final raw = opportunitySnapshot?['_weekly_inclusion'];
    if (raw is Map<String, dynamic>) {
      return WeeklyInclusionSummaryModel.fromMap(raw);
    }
    if (raw is Map) {
      return WeeklyInclusionSummaryModel.fromMap(
        raw.map((key, value) => MapEntry('$key', value)),
      );
    }
    return WeeklyInclusionSummaryModel.fromMap(null);
  }

  ReportReadiness get reportReadiness {
    final raw = opportunitySnapshot?['_report_readiness'];
    if (raw is Map<String, dynamic>) {
      return ReportReadiness.fromMap(
        raw,
        fallbackRule: ReportReadinessEvaluator.weeklyRule,
      );
    }
    if (raw is Map) {
      return ReportReadiness.fromMap(
        raw.map((key, value) => MapEntry('$key', value)),
        fallbackRule: ReportReadinessEvaluator.weeklyRule,
      );
    }
    return ReportReadiness(
      rule: ReportReadinessEvaluator.weeklyRule,
      signalCount: inclusionSummary.usedCount,
      distinctDayCount:
          chartData.where((point) => point.signalCount > 0).length,
      distinctWeekCount: inclusionSummary.usedCount > 0 ? 1 : 0,
    );
  }

  LifeExperimentModel? get lifeExperiment {
    final raw = opportunitySnapshot?['_life_experiment'];
    if (raw is Map<String, dynamic>) {
      LegacyFallbackMonitor.record(
        LegacyFallbackMonitor.opportunitySnapshotLifeExperiment,
      );
      return LifeExperimentModel.fromJson(raw);
    }
    if (raw is Map) {
      LegacyFallbackMonitor.record(
        LegacyFallbackMonitor.opportunitySnapshotLifeExperiment,
      );
      return LifeExperimentModel.fromJson(
        raw.map((key, value) => MapEntry('$key', value)),
      );
    }
    return null;
  }

  WeeklyActionPlanModel deriveActionPlan() {
    final structure = deriveV3CStructure();
    final experiment = lifeExperiment;
    return WeeklyActionPlanModel(
      title: experiment?.title.trim().isNotEmpty == true
          ? experiment!.title.trim()
          : structure.onePattern,
      mediumRangeGoal: structure.onePattern,
      smallExperiment: experiment?.suggestedAction.trim().isNotEmpty == true
          ? experiment!.suggestedAction.trim()
          : structure.oneExperiment,
      sourceExperimentId: experiment?.id,
    );
  }

  WeeklyActionReviewModel get actionReview {
    final raw = opportunitySnapshot?['_weekly_action_review'];
    if (raw is Map<String, dynamic>) {
      return WeeklyActionReviewModel.fromMap(raw);
    }
    if (raw is Map) {
      return WeeklyActionReviewModel.fromMap(
        raw.map((key, value) => MapEntry('$key', value)),
      );
    }
    return const WeeklyActionReviewModel();
  }

  WeeklyV3CStructureModel deriveV3CStructure() {
    final topic = deriveTopicFocus();
    final opportunityName = _stringOrNull(opportunitySnapshot?['name']);
    final opportunitySummary = _stringOrNull(opportunitySnapshot?['summary']);
    final keyInsightText = (keyInsight ?? '').trim();
    final actionText = (bestAction ?? '').trim();

    return WeeklyV3CStructureModel(
      lightObservation: keyInsightText.ifEmpty(
        isLightReady
            ? '这周可以先这样看：线索已经开始出现，但还适合保持轻一点。'
            : '这周可以先这样看：有一个方向开始比其他内容更明显。',
      ),
      onePattern: topic.headline.ifEmpty(
        isLightReady ? '这周先冒头的一个线索' : '这周最明显的一个模式',
      ),
      oneExperiment: actionText.ifEmpty(
        '下周可以试试一个很小的实验：同类场景出现时，只补一句它发生在哪里。',
      ),
      positiveSignal: (opportunitySummary ?? opportunityName ?? '').ifEmpty(
        '也留意一下哪些时刻让状态稍微往回收一点，它们可能是恢复线索。',
      ),
    );
  }

  WeeklyTopicFocusModel deriveTopicFocus() {
    final friction = _firstMap(frictions);
    final pattern = _firstMap(patterns);

    final frictionName = _stringOrNull(friction?['name']);
    final frictionSummary = _stringOrNull(friction?['summary']);

    final patternName = _stringOrNull(pattern?['name']);
    final patternSummary = _stringOrNull(pattern?['summary']);

    final bestActionText = (bestAction ?? '').trim();
    final keyInsightText = (keyInsight ?? '').trim();

    if (frictionName != null && frictionName.isNotEmpty) {
      return WeeklyTopicFocusModel(
        headline: frictionName,
        reason: frictionSummary ??
            keyInsightText.ifEmpty(
              '这周更值得先看的，不是所有内容，而是这个反复出现的消耗点。',
            ),
        nextWatch: bestActionText.ifEmpty(
          '下周先继续看这个卡点会不会在同类场景里重复出现。',
        ),
      );
    }

    if (patternName != null && patternName.isNotEmpty) {
      return WeeklyTopicFocusModel(
        headline: patternName,
        reason: patternSummary ??
            keyInsightText.ifEmpty(
              '这周已经开始出现一个值得继续追踪的重复主题。',
            ),
        nextWatch: bestActionText.ifEmpty(
          '下周先继续看这个主题会不会在更多场景里出现。',
        ),
      );
    }

    if (keyInsightText.isNotEmpty) {
      return WeeklyTopicFocusModel(
        headline: isLightReady ? '这周先冒头的方向' : '这周最明显的方向',
        reason: keyInsightText,
        nextWatch: bestActionText.ifEmpty(
          '下周先继续留意这一类情况会不会重复出现。',
        ),
      );
    }

    return WeeklyTopicFocusModel(
      headline: isLightReady ? '这周先冒头的方向' : '这周最明显的方向',
      reason: isLightReady
          ? '现在已经开始有一些线索聚起来了，不过还比较早，先轻轻看着就好。'
          : '这周已经出现了值得继续整理的方向。',
      nextWatch: bestActionText.ifEmpty(
        '下周先继续看哪类事情最容易重复回来。',
      ),
    );
  }

  static Map<String, dynamic>? _firstMap(List<dynamic> source) {
    if (source.isEmpty) return null;
    final first = source.first;
    if (first is Map<String, dynamic>) return first;
    if (first is Map) {
      return first.map((key, value) => MapEntry('$key', value));
    }
    return null;
  }

  static String? _stringOrNull(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

extension _NullableStringFallback on String {
  String ifEmpty(String fallback) {
    return trim().isEmpty ? fallback : this;
  }
}

class WeeklyReflectModel {
  final String summary;
  final String rootTension;
  final String hiddenPattern;
  final String nextFocus;
  final String riskNote;
  final List<String> keyNodes;

  const WeeklyReflectModel({
    required this.summary,
    required this.rootTension,
    required this.hiddenPattern,
    required this.nextFocus,
    required this.riskNote,
    this.keyNodes = const [],
  });

  factory WeeklyReflectModel.fromJson(Map<String, dynamic> json) {
    return WeeklyReflectModel(
      summary: (json['summary'] as String?) ?? '',
      rootTension: (json['root_tension'] as String?) ?? '',
      hiddenPattern: (json['hidden_pattern'] as String?) ?? '',
      nextFocus: (json['next_focus'] as String?) ?? '',
      riskNote: (json['risk_note'] as String?) ?? '',
      keyNodes: ((json['key_nodes'] as List?) ?? const [])
          .map((e) => e?.toString() ?? '')
          .where((e) => e.trim().isNotEmpty)
          .toList(),
    );
  }
}
