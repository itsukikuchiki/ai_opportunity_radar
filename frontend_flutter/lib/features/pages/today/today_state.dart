import '../../../shared/states/load_state.dart';
import '../../../core/models/phase3_plus_models.dart';
import '../../../core/models/today_models.dart';
import '../../../core/models/weekly_models.dart';

class TodayState {
  final LoadState loadState;
  final SubmitState captureSubmitState;
  final SubmitState followupSubmitState;
  final SubmitState draftSyncSubmitState;
  final String inputText;
  final String? acknowledgement;
  final TodayInsightModel? insight;
  final FollowupQuestionModel? pendingQuestion;
  final DailyBestActionModel? bestAction;
  final List<RecentSignalModel> recentSignals;
  final AiJudgementModel? aiJudgement;
  final bool aiJudgementExhausted;
  final List<MicroActionModel> microActions;
  final LifeExperimentModel? todayLifeExperiment;
  final String? errorMessage;
  final int captureSuccessTick;
  final int followupSuccessTick;
  final String? draftSyncMessage;

  const TodayState({
    required this.loadState,
    required this.captureSubmitState,
    required this.followupSubmitState,
    required this.draftSyncSubmitState,
    required this.inputText,
    required this.acknowledgement,
    required this.insight,
    required this.pendingQuestion,
    required this.bestAction,
    required this.recentSignals,
    required this.aiJudgement,
    required this.aiJudgementExhausted,
    required this.microActions,
    required this.todayLifeExperiment,
    required this.errorMessage,
    required this.captureSuccessTick,
    required this.followupSuccessTick,
    required this.draftSyncMessage,
  });

  factory TodayState.initial() => const TodayState(
        loadState: LoadState.initial,
        captureSubmitState: SubmitState.idle,
        followupSubmitState: SubmitState.idle,
        draftSyncSubmitState: SubmitState.idle,
        inputText: '',
        acknowledgement: null,
        insight: null,
        pendingQuestion: null,
        bestAction: null,
        recentSignals: [],
        aiJudgement: null,
        aiJudgementExhausted: false,
        microActions: [],
        todayLifeExperiment: null,
        errorMessage: null,
        captureSuccessTick: 0,
        followupSuccessTick: 0,
        draftSyncMessage: null,
      );

  bool get isInitialLoading =>
      loadState == LoadState.initial || loadState == LoadState.loading;

  bool get isCaptureSubmitting => captureSubmitState == SubmitState.submitting;

  bool get isFollowupSubmitting =>
      followupSubmitState == SubmitState.submitting;

  bool get isDraftSyncing => draftSyncSubmitState == SubmitState.submitting;

  bool get hasError => errorMessage != null && errorMessage!.trim().isNotEmpty;

  bool get hasRecentSignals => recentSignals.isNotEmpty;

  MicroActionModel? get activeMicroAction {
    final linkedId = aiJudgement?.linkedMicroActionId;
    if (linkedId == null || linkedId.trim().isEmpty) return null;
    for (final action in microActions) {
      if (action.id == linkedId) return action;
    }
    return null;
  }

  static const Object _unset = Object();

  TodayState copyWith({
    LoadState? loadState,
    SubmitState? captureSubmitState,
    SubmitState? followupSubmitState,
    SubmitState? draftSyncSubmitState,
    String? inputText,
    String? acknowledgement,
    TodayInsightModel? insight,
    FollowupQuestionModel? pendingQuestion,
    DailyBestActionModel? bestAction,
    List<RecentSignalModel>? recentSignals,
    Object? aiJudgement = _unset,
    bool? aiJudgementExhausted,
    List<MicroActionModel>? microActions,
    Object? todayLifeExperiment = _unset,
    String? errorMessage,
    int? captureSuccessTick,
    int? followupSuccessTick,
    String? draftSyncMessage,
    bool clearAcknowledgement = false,
    bool clearPendingQuestion = false,
    bool clearErrorMessage = false,
    bool clearDraftSyncMessage = false,
  }) {
    return TodayState(
      loadState: loadState ?? this.loadState,
      captureSubmitState: captureSubmitState ?? this.captureSubmitState,
      followupSubmitState: followupSubmitState ?? this.followupSubmitState,
      draftSyncSubmitState: draftSyncSubmitState ?? this.draftSyncSubmitState,
      inputText: inputText ?? this.inputText,
      acknowledgement: clearAcknowledgement
          ? null
          : (acknowledgement ?? this.acknowledgement),
      insight: insight ?? this.insight,
      pendingQuestion: clearPendingQuestion
          ? null
          : (pendingQuestion ?? this.pendingQuestion),
      bestAction: bestAction ?? this.bestAction,
      recentSignals: recentSignals ?? this.recentSignals,
      aiJudgement: identical(aiJudgement, _unset)
          ? this.aiJudgement
          : aiJudgement as AiJudgementModel?,
      aiJudgementExhausted: aiJudgementExhausted ?? this.aiJudgementExhausted,
      microActions: microActions ?? this.microActions,
      todayLifeExperiment: identical(todayLifeExperiment, _unset)
          ? this.todayLifeExperiment
          : todayLifeExperiment as LifeExperimentModel?,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      captureSuccessTick: captureSuccessTick ?? this.captureSuccessTick,
      followupSuccessTick: followupSuccessTick ?? this.followupSuccessTick,
      draftSyncMessage: clearDraftSyncMessage
          ? null
          : (draftSyncMessage ?? this.draftSyncMessage),
    );
  }
}
