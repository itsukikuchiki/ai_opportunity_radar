class FollowupQuestionModel {
  final String id;
  final String question;
  final List<FollowupOptionModel> options;

  FollowupQuestionModel({required this.id, required this.question, required this.options});

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

  FollowupOptionModel({required this.label, required this.value});

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
  final String content;
  RecentSignalModel({required this.content});
}
