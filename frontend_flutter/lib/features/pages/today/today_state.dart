import '../../../shared/states/load_state.dart';
import '../../../core/models/today_models.dart';

class TodayState {
  final LoadState loadState;
  final SubmitState captureSubmitState;
  final SubmitState followupSubmitState;
  final String inputText;
  final String? acknowledgement;
  final TodayInsightModel? insight;
  final FollowupQuestionModel? pendingQuestion;
  final DailyBestActionModel? bestAction;
  final List<RecentSignalModel> recentSignals;
  final String? errorMessage;

  const TodayState({
    required this.loadState,
    required this.captureSubmitState,
    required this.followupSubmitState,
    required this.inputText,
    required this.acknowledgement,
    required this.insight,
    required this.pendingQuestion,
    required this.bestAction,
    required this.recentSignals,
    required this.errorMessage,
  });

  factory TodayState.initial() => const TodayState(
        loadState: LoadState.initial,
        captureSubmitState: SubmitState.idle,
        followupSubmitState: SubmitState.idle,
        inputText: '',
        acknowledgement: null,
        insight: null,
        pendingQuestion: null,
        bestAction: null,
        recentSignals: [],
        errorMessage: null,
      );

  TodayState copyWith({
    LoadState? loadState,
    SubmitState? captureSubmitState,
    SubmitState? followupSubmitState,
    String? inputText,
    String? acknowledgement,
    TodayInsightModel? insight,
    FollowupQuestionModel? pendingQuestion,
    DailyBestActionModel? bestAction,
    List<RecentSignalModel>? recentSignals,
    String? errorMessage,
  }) {
    return TodayState(
      loadState: loadState ?? this.loadState,
      captureSubmitState: captureSubmitState ?? this.captureSubmitState,
      followupSubmitState: followupSubmitState ?? this.followupSubmitState,
      inputText: inputText ?? this.inputText,
      acknowledgement: acknowledgement ?? this.acknowledgement,
      insight: insight ?? this.insight,
      pendingQuestion: pendingQuestion ?? this.pendingQuestion,
      bestAction: bestAction ?? this.bestAction,
      recentSignals: recentSignals ?? this.recentSignals,
      errorMessage: errorMessage,
    );
  }
}
