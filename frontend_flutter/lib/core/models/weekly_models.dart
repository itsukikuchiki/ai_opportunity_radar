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
    );
  }
}
