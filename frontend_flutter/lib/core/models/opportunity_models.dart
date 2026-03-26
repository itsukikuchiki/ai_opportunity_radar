class OpportunityListItemModel {
  final String id;
  final String name;
  final String? maturity;
  final String? opportunityType;
  final double? scoreTotal;
  final String? summary;

  OpportunityListItemModel({
    required this.id,
    required this.name,
    required this.maturity,
    required this.opportunityType,
    required this.scoreTotal,
    required this.summary,
  });

  factory OpportunityListItemModel.fromJson(Map<String, dynamic> json) {
    return OpportunityListItemModel(
      id: json['id'] as String,
      name: json['name'] as String,
      maturity: json['maturity'] as String?,
      opportunityType: json['opportunity_type'] as String?,
      scoreTotal: (json['score_total'] as num?)?.toDouble(),
      summary: json['summary'] as String?,
    );
  }
}

class OpportunityDetailModel {
  final String id;
  final String name;
  final String? description;
  final String? maturity;
  final String? opportunityType;
  final double? totalScore;
  final String? whyThisOpportunity;
  final List<dynamic> evidenceSummary;
  final String? solutionFitExplanation;
  final String? nextStep;
  final String? userFacingSummary;

  OpportunityDetailModel({
    required this.id,
    required this.name,
    required this.description,
    required this.maturity,
    required this.opportunityType,
    required this.totalScore,
    required this.whyThisOpportunity,
    required this.evidenceSummary,
    required this.solutionFitExplanation,
    required this.nextStep,
    required this.userFacingSummary,
  });

  factory OpportunityDetailModel.fromJson(Map<String, dynamic> json) {
    final score = json['score'] as Map<String, dynamic>?;
    return OpportunityDetailModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      maturity: json['maturity'] as String?,
      opportunityType: json['opportunity_type'] as String?,
      totalScore: (score?['total'] as num?)?.toDouble() ?? (json['score_total'] as num?)?.toDouble(),
      whyThisOpportunity: json['why_this_opportunity'] as String?,
      evidenceSummary: (json['evidence_summary'] as List?) ?? [],
      solutionFitExplanation: json['solution_fit_explanation'] as String?,
      nextStep: json['next_step'] as String?,
      userFacingSummary: json['user_facing_summary'] as String?,
    );
  }
}
