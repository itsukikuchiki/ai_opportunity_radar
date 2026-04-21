class MonthlyBridgeWeekModel {
  final String label;
  final String summary;

  const MonthlyBridgeWeekModel({
    required this.label,
    required this.summary,
  });

  factory MonthlyBridgeWeekModel.fromJson(Map<String, dynamic> json) {
    return MonthlyBridgeWeekModel(
      label: (json['label'] as String?) ?? '',
      summary: (json['summary'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'summary': summary,
      };
}

class MonthlyReviewModel {
  final String monthStart;
  final String monthEnd;
  final String status;
  final String? monthlySummary;
  final List<String> repeatedThemes;
  final List<String> improvingSignals;
  final List<String> unresolvedPoints;
  final String? nextMonthWatch;
  final List<MonthlyBridgeWeekModel> weeklyBridges;

  const MonthlyReviewModel({
    required this.monthStart,
    required this.monthEnd,
    required this.status,
    this.monthlySummary,
    this.repeatedThemes = const [],
    this.improvingSignals = const [],
    this.unresolvedPoints = const [],
    this.nextMonthWatch,
    this.weeklyBridges = const [],
  });

  factory MonthlyReviewModel.fromJson(Map<String, dynamic> json) {
    return MonthlyReviewModel(
      monthStart: (json['month_start'] as String?) ?? '',
      monthEnd: (json['month_end'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'ready',
      monthlySummary: json['monthly_summary'] as String?,
      repeatedThemes: ((json['repeated_themes'] as List?) ?? const [])
          .map((e) => e?.toString() ?? '')
          .where((e) => e.trim().isNotEmpty)
          .toList(),
      improvingSignals: ((json['improving_signals'] as List?) ?? const [])
          .map((e) => e?.toString() ?? '')
          .where((e) => e.trim().isNotEmpty)
          .toList(),
      unresolvedPoints: ((json['unresolved_points'] as List?) ?? const [])
          .map((e) => e?.toString() ?? '')
          .where((e) => e.trim().isNotEmpty)
          .toList(),
      nextMonthWatch: json['next_month_watch'] as String?,
      weeklyBridges: ((json['weekly_bridges'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => MonthlyBridgeWeekModel.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }

  bool get isReady => status == 'ready';
  bool get isLightReady => status == 'light_ready';
}
