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
      opportunitySnapshot: json['opportunity_snapshot'] as Map<String, dynamic>?,
      feedbackSubmitted: (json['feedback_submitted'] as bool?) ?? false,
      chartData: ((json['chart_data'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => WeeklyChartPointModel.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }

  bool get isLightReady => status == 'light_ready';
  bool get isReady => status == 'ready';

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


class DeepWeeklyModel {
  final String summary;
  final String rootTension;
  final String hiddenPattern;
  final String nextFocus;
  final String riskNote;
  final List<String> keyNodes;

  const DeepWeeklyModel({
    required this.summary,
    required this.rootTension,
    required this.hiddenPattern,
    required this.nextFocus,
    required this.riskNote,
    this.keyNodes = const [],
  });

  factory DeepWeeklyModel.fromJson(Map<String, dynamic> json) {
    return DeepWeeklyModel(
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
