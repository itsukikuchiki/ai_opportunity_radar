import '../../../shared/states/load_state.dart';
import '../../../core/models/phase3_plus_models.dart';
import '../../../core/models/today_models.dart';

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
  final List<ScheduleSignalModel> scheduleSignals;
  final List<GoalModel> activeGoals;
  final List<GoalTaskInstanceModel> goalTasks;
  final AiJudgementModel? aiJudgement;
  final List<MicroActionModel> microActions;
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
    required this.scheduleSignals,
    required this.activeGoals,
    required this.goalTasks,
    required this.aiJudgement,
    required this.microActions,
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
        scheduleSignals: [],
        activeGoals: [],
        goalTasks: [],
        aiJudgement: null,
        microActions: [],
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

  MicroActionModel? get activeMicroAction =>
      microActions.isEmpty ? null : microActions.first;

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
    List<ScheduleSignalModel>? scheduleSignals,
    List<GoalModel>? activeGoals,
    List<GoalTaskInstanceModel>? goalTasks,
    Object? aiJudgement = _unset,
    List<MicroActionModel>? microActions,
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
      scheduleSignals: scheduleSignals ?? this.scheduleSignals,
      activeGoals: activeGoals ?? this.activeGoals,
      goalTasks: goalTasks ?? this.goalTasks,
      aiJudgement: identical(aiJudgement, _unset)
          ? this.aiJudgement
          : aiJudgement as AiJudgementModel?,
      microActions: microActions ?? this.microActions,
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
