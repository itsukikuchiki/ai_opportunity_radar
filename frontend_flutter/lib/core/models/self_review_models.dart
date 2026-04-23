class SelfReviewModel {
  final String status;
  final int reviewedDays;
  final List<String> repeatedBlockers;
  final List<String> mainDrains;
  final List<String> helpingPatterns;
  final String closingNote;

  const SelfReviewModel({
    required this.status,
    required this.reviewedDays,
    required this.repeatedBlockers,
    required this.mainDrains,
    required this.helpingPatterns,
    required this.closingNote,
  });

  factory SelfReviewModel.fromJson(Map<String, dynamic> json) {
    return SelfReviewModel(
      status: (json['status'] as String?) ?? 'insufficient_data',
      reviewedDays: (json['reviewed_days'] as num?)?.toInt() ?? 0,
      repeatedBlockers: ((json['repeated_blockers'] as List?) ?? const [])
          .map((e) => e?.toString() ?? '')
          .where((e) => e.trim().isNotEmpty)
          .toList(),
      mainDrains: ((json['main_drains'] as List?) ?? const [])
          .map((e) => e?.toString() ?? '')
          .where((e) => e.trim().isNotEmpty)
          .toList(),
      helpingPatterns: ((json['helping_patterns'] as List?) ?? const [])
          .map((e) => e?.toString() ?? '')
          .where((e) => e.trim().isNotEmpty)
          .toList(),
      closingNote: (json['closing_note'] as String?) ?? '',
    );
  }

  bool get isReady => status == 'ready';
  bool get isInsufficient => status == 'insufficient_data';
}
