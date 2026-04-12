class FollowupQuestionModel {
  final String id;
  final String question;
  final List<FollowupOptionModel> options;

  FollowupQuestionModel({
    required this.id,
    required this.question,
    required this.options,
  });

  factory FollowupQuestionModel.fromJson(Map<String, dynamic> json) {
    return FollowupQuestionModel(
      id: json['id'] as String,
      question: json['question'] as String,
      options: ((json['options'] as List?) ?? [])
          .map((e) => FollowupOptionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class FollowupOptionModel {
  final String label;
  final String value;

  FollowupOptionModel({
    required this.label,
    required this.value,
  });

  factory FollowupOptionModel.fromJson(Map<String, dynamic> json) {
    return FollowupOptionModel(
      label: json['label'] as String,
      value: json['value'] as String,
    );
  }
}

class TodayInsightModel {
  final String text;

  TodayInsightModel({required this.text});
}

class DailyBestActionModel {
  final String text;

  DailyBestActionModel({required this.text});
}

class RecentSignalModel {
  final String? id;
  final String content;
  final DateTime? createdAt;
  final String? acknowledgement;

  RecentSignalModel({
    this.id,
    required this.content,
    this.createdAt,
    this.acknowledgement,
  });

  factory RecentSignalModel.fromJson(Map<String, dynamic> json) {
    return RecentSignalModel(
      id: json['id'] as String?,
      content: (json['content'] as String?) ??
          (json['summary'] as String?) ??
          '',
      createdAt: _parseDateTime(
        json['created_at'] ??
            json['createdAt'] ??
            json['timestamp'] ??
            json['captured_at'],
      ),
      acknowledgement: (json['acknowledgement'] as String?) ??
          (json['ai_acknowledgement'] as String?) ??
          (json['response'] as String?),
    );
  }

  static DateTime? _parseDateTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String && raw.trim().isNotEmpty) {
      return DateTime.tryParse(raw);
    }
    return null;
  }

  String dedupeKey() {
    return '${id ?? ''}|${content.trim().toLowerCase()}';
  }
}

class DailySnapshotModel {
  final String date;
  final int entryCount;
  final String? observationText;
  final String? suggestionText;
  final String? sourceHash;
  final DateTime? generatedAt;

  DailySnapshotModel({
    required this.date,
    required this.entryCount,
    required this.observationText,
    required this.suggestionText,
    required this.sourceHash,
    required this.generatedAt,
  });

  factory DailySnapshotModel.fromDb(Map<String, Object?> row) {
    return DailySnapshotModel(
      date: (row['date'] as String?) ?? '',
      entryCount: (row['entry_count'] as int?) ?? 0,
      observationText: row['observation_text'] as String?,
      suggestionText: row['suggestion_text'] as String?,
      sourceHash: row['source_hash'] as String?,
      generatedAt: DateTime.tryParse((row['generated_at'] as String?) ?? ''),
    );
  }
}

class AiCaptureReplyResult {
  final String acknowledgement;
  final FollowupQuestionModel? followup;

  AiCaptureReplyResult({
    required this.acknowledgement,
    required this.followup,
  });
}

class AiTodaySummaryResult {
  final String observation;
  final String suggestion;

  AiTodaySummaryResult({
    required this.observation,
    required this.suggestion,
  });
}
