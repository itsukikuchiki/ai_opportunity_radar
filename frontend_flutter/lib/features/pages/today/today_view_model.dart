import 'package:flutter/foundation.dart';

import '../../../core/api/repositories/today_repository.dart';
import '../../../core/i18n/app_locale_text.dart';
import '../../../core/models/phase3_plus_models.dart';
import '../../../core/models/today_models.dart';
import '../../../shared/states/load_state.dart';
import 'today_state.dart';

enum DraftSyncResult { completed, stillPending, noPending }

class TodayViewModel extends ChangeNotifier {
  final TodayRepository repository;

  TodayState _state = TodayState.initial();
  TodayState get state => _state;

  TodayViewModel(this.repository) {
    load();
  }

  Future<void> load() async {
    _state = _state.copyWith(
      loadState: LoadState.loading,
      clearErrorMessage: true,
    );
    notifyListeners();

    try {
      final data = await repository.fetchToday();

      final fetchedSignals =
          (data['recentSignals'] as List<RecentSignalModel>? ?? const []);

      _state = _state.copyWith(
        loadState: LoadState.ready,
        insight: data['insight'] as TodayInsightModel?,
        pendingQuestion: data['pendingQuestion'] as FollowupQuestionModel?,
        bestAction: data['bestAction'] as DailyBestActionModel?,
        recentSignals: fetchedSignals,
        scheduleSignals:
            data['scheduleSignals'] as List<ScheduleSignalModel>? ?? const [],
        activeGoals: data['activeGoals'] as List<GoalModel>? ?? const [],
        goalTasks:
            data['goalTasks'] as List<GoalTaskInstanceModel>? ?? const [],
        aiJudgement: data['aiJudgement'] as AiJudgementModel?,
        microActions:
            data['microActions'] as List<MicroActionModel>? ?? const [],
        clearErrorMessage: true,
      );
    } catch (e) {
      _state = _state.copyWith(
        loadState: LoadState.error,
        errorMessage: e.toString(),
      );
    }

    notifyListeners();
  }

  Future<void> retry() => load();

  Future<DraftSyncResult> retryDraftSync() async {
    if (_state.isDraftSyncing) return DraftSyncResult.stillPending;
    final hasPending = _state.recentSignals.any(
      (signal) => signal.isLocalDraft || signal.syncFailed,
    );
    if (!hasPending) return DraftSyncResult.noPending;

    _state = _state.copyWith(
      draftSyncSubmitState: SubmitState.submitting,
      clearErrorMessage: true,
      clearDraftSyncMessage: true,
    );
    notifyListeners();
    try {
      await repository.retryPendingDrafts();
      final data = await repository.fetchToday();
      final fetchedSignals =
          (data['recentSignals'] as List<RecentSignalModel>? ?? const []);
      final stillPending = fetchedSignals.any(
        (signal) => signal.isLocalDraft || signal.syncFailed,
      );
      _state = _state.copyWith(
        loadState: LoadState.ready,
        insight: data['insight'] as TodayInsightModel?,
        pendingQuestion: data['pendingQuestion'] as FollowupQuestionModel?,
        bestAction: data['bestAction'] as DailyBestActionModel?,
        recentSignals: fetchedSignals,
        scheduleSignals:
            data['scheduleSignals'] as List<ScheduleSignalModel>? ?? const [],
        activeGoals: data['activeGoals'] as List<GoalModel>? ?? const [],
        goalTasks:
            data['goalTasks'] as List<GoalTaskInstanceModel>? ?? const [],
        aiJudgement: data['aiJudgement'] as AiJudgementModel?,
        microActions:
            data['microActions'] as List<MicroActionModel>? ?? const [],
        draftSyncSubmitState:
            stillPending ? SubmitState.failure : SubmitState.success,
        draftSyncMessage: stillPending ? 'sync_still_pending' : 'sync_complete',
        clearErrorMessage: true,
      );
      return stillPending
          ? DraftSyncResult.stillPending
          : DraftSyncResult.completed;
    } catch (e) {
      _state = _state.copyWith(
        draftSyncSubmitState: SubmitState.failure,
        draftSyncMessage: 'sync_still_pending',
        errorMessage: e.toString(),
      );
      return DraftSyncResult.stillPending;
    } finally {
      notifyListeners();
    }
  }

  void updateInput(String value) {
    _state = _state.copyWith(
      inputText: value,
      captureSubmitState: SubmitState.idle,
      clearErrorMessage: true,
    );
    notifyListeners();
  }

  void applyQuickExample(String value) {
    _state = _state.copyWith(
      inputText: value,
      captureSubmitState: SubmitState.idle,
      clearErrorMessage: true,
    );
    notifyListeners();
  }

  Future<void> submitCapture({String? tagHint}) async {
    final content = _state.inputText.trim();
    if (content.isEmpty) {
      _state = _state.copyWith(
        errorMessage: 'empty_input',
      );
      notifyListeners();
      return;
    }

    _state = _state.copyWith(
      captureSubmitState: SubmitState.submitting,
      clearErrorMessage: true,
    );
    notifyListeners();

    try {
      final result = await repository.submitCapture(
        content: content,
        tagHint: tagHint,
      );

      final updatedSignals =
          (result['updatedRecentSignals'] as List<RecentSignalModel>? ??
              const []);

      final refreshed = await repository.fetchToday();

      _state = _state.copyWith(
        captureSubmitState: SubmitState.success,
        inputText: '',
        acknowledgement: result['acknowledgement'] as String?,
        pendingQuestion: result['followup'] as FollowupQuestionModel?,
        insight: refreshed['insight'] as TodayInsightModel?,
        bestAction: refreshed['bestAction'] as DailyBestActionModel?,
        recentSignals: updatedSignals,
        scheduleSignals:
            refreshed['scheduleSignals'] as List<ScheduleSignalModel>? ??
                const [],
        activeGoals: refreshed['activeGoals'] as List<GoalModel>? ?? const [],
        goalTasks:
            refreshed['goalTasks'] as List<GoalTaskInstanceModel>? ?? const [],
        aiJudgement: refreshed['aiJudgement'] as AiJudgementModel?,
        microActions:
            refreshed['microActions'] as List<MicroActionModel>? ?? const [],
        captureSuccessTick: _state.captureSuccessTick + 1,
        clearErrorMessage: true,
      );
    } catch (e) {
      _state = _state.copyWith(
        captureSubmitState: SubmitState.failure,
        errorMessage: e.toString(),
      );
    }

    notifyListeners();
  }

  Future<void> submitVoiceTranscript(String transcript) async {
    final content = transcript.trim();
    if (content.isEmpty) {
      _state = _state.copyWith(errorMessage: 'empty_input');
      notifyListeners();
      return;
    }

    _state = _state.copyWith(
      captureSubmitState: SubmitState.submitting,
      clearErrorMessage: true,
    );
    notifyListeners();

    try {
      final result = await repository.submitCapture(
        content: content,
        sourceType: 'voice',
        rawPayloadJson: const {
          'transcript_only': true,
          'audio_saved': false,
          'audio_uploaded': false,
        },
      );
      final refreshed = await repository.fetchToday();
      _state = _state.copyWith(
        captureSubmitState: SubmitState.success,
        inputText: '',
        acknowledgement: result['acknowledgement'] as String?,
        insight: refreshed['insight'] as TodayInsightModel?,
        bestAction: refreshed['bestAction'] as DailyBestActionModel?,
        recentSignals:
            refreshed['recentSignals'] as List<RecentSignalModel>? ?? const [],
        scheduleSignals:
            refreshed['scheduleSignals'] as List<ScheduleSignalModel>? ??
                const [],
        activeGoals: refreshed['activeGoals'] as List<GoalModel>? ?? const [],
        goalTasks:
            refreshed['goalTasks'] as List<GoalTaskInstanceModel>? ?? const [],
        aiJudgement: refreshed['aiJudgement'] as AiJudgementModel?,
        microActions:
            refreshed['microActions'] as List<MicroActionModel>? ?? const [],
        captureSuccessTick: _state.captureSuccessTick + 1,
        clearErrorMessage: true,
      );
    } catch (e) {
      _state = _state.copyWith(
        captureSubmitState: SubmitState.failure,
        errorMessage: e.toString(),
      );
    }

    notifyListeners();
  }

  Future<void> submitQuickStatus({
    required String choice,
    AppLanguage language = AppLanguage.english,
  }) async {
    final content = _quickStatusText(choice, language);
    if (content.trim().isEmpty) return;
    final rawPayloadJson = {
      'quick_status': choice,
      'user_triggered': true,
    };

    _state = _state.copyWith(
      captureSubmitState: SubmitState.submitting,
      clearErrorMessage: true,
    );
    notifyListeners();

    try {
      await repository.submitCapture(
        content: content,
        sourceType: 'one_tap',
        rawPayloadJson: rawPayloadJson,
      );
      final localFallbackSignals = _signalsWithSubmittedLocal(
        content: content,
        sourceType: 'one_tap',
        rawPayloadJson: rawPayloadJson,
        language: language,
      );
      final refreshed = await repository.fetchToday();
      final refreshedSignals =
          refreshed['recentSignals'] as List<RecentSignalModel>?;
      final refreshedIncludesSubmitted = refreshedSignals?.any(
            (signal) =>
                signal.sourceType == 'one_tap' && signal.content == content,
          ) ??
          false;
      _state = _state.copyWith(
        captureSubmitState: SubmitState.success,
        insight: refreshed['insight'] as TodayInsightModel?,
        bestAction: refreshed['bestAction'] as DailyBestActionModel?,
        recentSignals: !refreshedIncludesSubmitted
            ? localFallbackSignals
            : refreshedSignals,
        scheduleSignals:
            refreshed['scheduleSignals'] as List<ScheduleSignalModel>? ??
                const [],
        activeGoals: refreshed['activeGoals'] as List<GoalModel>? ?? const [],
        goalTasks:
            refreshed['goalTasks'] as List<GoalTaskInstanceModel>? ?? const [],
        aiJudgement: refreshed['aiJudgement'] as AiJudgementModel?,
        microActions:
            refreshed['microActions'] as List<MicroActionModel>? ?? const [],
        captureSuccessTick: _state.captureSuccessTick + 1,
        clearErrorMessage: true,
      );
    } catch (e) {
      _state = _state.copyWith(
        captureSubmitState: SubmitState.failure,
        errorMessage: e.toString(),
      );
    }

    notifyListeners();
  }

  List<RecentSignalModel> _signalsWithSubmittedLocal({
    required String content,
    required String sourceType,
    required Map<String, dynamic> rawPayloadJson,
    required AppLanguage language,
  }) {
    final now = DateTime.now();
    final localSignal = RecentSignalModel(
      id: 'local-$sourceType-${now.microsecondsSinceEpoch}',
      signalCardId: 'local-$sourceType-${now.microsecondsSinceEpoch}',
      sourceType: sourceType,
      content: content,
      createdAt: now,
      localDate: _dateKey(now),
      acknowledgement: _quickSavedAcknowledgement(sourceType, language),
      rawPayloadJson: rawPayloadJson,
      sceneTags: sourceType == 'one_tap' ? const ['state'] : const [],
      userConfirmation: 'unconfirmed',
      privacyLevel: 'private',
    );
    return [localSignal, ..._state.recentSignals];
  }

  String _quickSavedAcknowledgement(String sourceType, AppLanguage language) {
    if (sourceType == 'one_tap') {
      return switch (language) {
        AppLanguage.simplifiedChinese => '这个状态已经放进你的手帐时间线。',
        AppLanguage.traditionalChinese => '這個狀態已經放進你的手帳時間線。',
        AppLanguage.japanese => 'この状態を手帳タイムラインに残しました。',
        AppLanguage.english =>
          'This state has been added to your diary timeline.',
      };
    }
    return switch (language) {
      AppLanguage.simplifiedChinese => '这条信号已经保存。',
      AppLanguage.traditionalChinese => '這條信號已經保存。',
      AppLanguage.japanese => 'このシグナルを保存しました。',
      AppLanguage.english => 'This signal has been saved.',
    };
  }

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<void> createPredictedSignal({
    AppLanguage language = AppLanguage.english,
  }) async {
    _state = _state.copyWith(
      captureSubmitState: SubmitState.submitting,
      clearErrorMessage: true,
    );
    notifyListeners();

    try {
      await repository.createAiJudgementForToday(language: language);
      await _refreshAfterJudgementMutation(
        submitState: SubmitState.success,
        incrementSuccessTick: true,
      );
    } catch (e) {
      _state = _state.copyWith(
        captureSubmitState: SubmitState.failure,
        errorMessage: e.toString(),
      );
      notifyListeners();
    }
  }

  Future<void> respondToAiJudgement({
    required AiJudgementModel judgement,
    required String status,
    String? userAdjustmentText,
    AppLanguage language = AppLanguage.english,
  }) async {
    _state = _state.copyWith(
      captureSubmitState: SubmitState.submitting,
      clearErrorMessage: true,
    );
    notifyListeners();

    try {
      final refreshed = await repository.respondToAiJudgement(
        judgementId: judgement.id,
        status: status,
        userAdjustmentText: userAdjustmentText,
        language: language,
      );
      _applyTodayRefresh(
        refreshed,
        submitState: SubmitState.success,
        incrementSuccessTick: false,
      );
    } catch (e) {
      _state = _state.copyWith(
        captureSubmitState: SubmitState.failure,
        errorMessage: e.toString(),
      );
    }
    notifyListeners();
  }

  Future<void> chooseMicroAction({
    required MicroActionModel action,
    required String choice,
    AppLanguage language = AppLanguage.english,
  }) async {
    _state = _state.copyWith(
      captureSubmitState: SubmitState.submitting,
      clearErrorMessage: true,
    );
    notifyListeners();

    try {
      final refreshed = await repository.chooseMicroAction(
        microActionId: action.id,
        choice: choice,
        language: language,
      );
      _applyTodayRefresh(
        refreshed,
        submitState: SubmitState.success,
        incrementSuccessTick: false,
      );
    } catch (e) {
      _state = _state.copyWith(
        captureSubmitState: SubmitState.failure,
        errorMessage: e.toString(),
      );
    }
    notifyListeners();
  }

  Future<void> submitMicroActionFeedback({
    required MicroActionModel action,
    required String feedback,
    String? userNote,
  }) async {
    _state = _state.copyWith(
      captureSubmitState: SubmitState.submitting,
      clearErrorMessage: true,
    );
    notifyListeners();

    try {
      final refreshed = await repository.submitMicroActionFeedback(
        microActionId: action.id,
        feedback: feedback,
        userNote: userNote,
      );
      _applyTodayRefresh(
        refreshed,
        submitState: SubmitState.success,
        incrementSuccessTick: false,
      );
    } catch (e) {
      _state = _state.copyWith(
        captureSubmitState: SubmitState.failure,
        errorMessage: e.toString(),
      );
    }
    notifyListeners();
  }

  Future<void> _refreshAfterJudgementMutation({
    required SubmitState submitState,
    required bool incrementSuccessTick,
  }) async {
    final refreshed = await repository.fetchToday();
    _applyTodayRefresh(
      refreshed,
      submitState: submitState,
      incrementSuccessTick: incrementSuccessTick,
    );
    notifyListeners();
  }

  void _applyTodayRefresh(
    Map<String, dynamic> refreshed, {
    required SubmitState submitState,
    required bool incrementSuccessTick,
  }) {
    _state = _state.copyWith(
      captureSubmitState: submitState,
      insight: refreshed['insight'] as TodayInsightModel?,
      pendingQuestion: refreshed['pendingQuestion'] as FollowupQuestionModel?,
      bestAction: refreshed['bestAction'] as DailyBestActionModel?,
      recentSignals:
          refreshed['recentSignals'] as List<RecentSignalModel>? ?? const [],
      scheduleSignals:
          refreshed['scheduleSignals'] as List<ScheduleSignalModel>? ??
              const [],
      activeGoals: refreshed['activeGoals'] as List<GoalModel>? ?? const [],
      goalTasks:
          refreshed['goalTasks'] as List<GoalTaskInstanceModel>? ?? const [],
      aiJudgement: refreshed['aiJudgement'] as AiJudgementModel?,
      microActions:
          refreshed['microActions'] as List<MicroActionModel>? ?? const [],
      captureSuccessTick: incrementSuccessTick
          ? _state.captureSuccessTick + 1
          : _state.captureSuccessTick,
      clearErrorMessage: true,
    );
  }

  String _quickStatusText(String choice, AppLanguage language) {
    switch (language) {
      case AppLanguage.simplifiedChinese:
        return switch (choice) {
          'good' => '现在感觉还不错。',
          'steady' => '现在状态比较平稳。',
          'tired' => '现在有点累。',
          'scattered' => '现在有点乱。',
          'irritated' => '现在有点烦。',
          'recovery' => '现在想留一点恢复空间。',
          'connection' => '现在有点想和人连接。',
          'quiet' => '现在想一个人安静一下。',
          'energy_low' => '现在能量有点低。',
          'friction_high' => '现在摩擦感有点高。',
          'recovery_low' => '现在恢复感有点不够。',
          _ => '现在有一个状态信号。',
        };
      case AppLanguage.traditionalChinese:
        return switch (choice) {
          'good' => '現在感覺還不錯。',
          'steady' => '現在狀態比較平穩。',
          'tired' => '現在有點累。',
          'scattered' => '現在有點亂。',
          'irritated' => '現在有點煩。',
          'recovery' => '現在想留一點恢復空間。',
          'connection' => '現在有點想和人連結。',
          'quiet' => '現在想一個人安靜一下。',
          'energy_low' => '現在能量有點低。',
          'friction_high' => '現在摩擦感有點高。',
          'recovery_low' => '現在恢復感有點不夠。',
          _ => '現在有一個狀態信號。',
        };
      case AppLanguage.japanese:
        return switch (choice) {
          'good' => '今、少しいい感じです。',
          'steady' => '今、状態はわりと落ち着いています。',
          'tired' => '今、少し疲れています。',
          'scattered' => '今、少し散らかっている感じがします。',
          'irritated' => '今、少しイライラしています。',
          'recovery' => '今、少し回復する余白がほしいです。',
          'connection' => '今、少し人とのつながりがほしいです。',
          'quiet' => '今、一人で静かにしたいです。',
          'energy_low' => '今、エネルギーが少し低い。',
          'friction_high' => '今、摩擦感が少し高い。',
          'recovery_low' => '今、回復感が少し足りない。',
          _ => '今、状態のシグナルが一つあります。',
        };
      case AppLanguage.english:
        return switch (choice) {
          'good' => 'I feel pretty good right now.',
          'steady' => 'I feel fairly steady right now.',
          'tired' => 'I feel a little tired right now.',
          'scattered' => 'I feel a little scattered right now.',
          'irritated' => 'I feel a little irritated right now.',
          'recovery' => 'I want a little recovery space right now.',
          'connection' => 'I want a little connection right now.',
          'quiet' => 'I want some quiet alone time right now.',
          'energy_low' => 'Energy feels a little low right now.',
          'friction_high' => 'Friction feels a little high right now.',
          'recovery_low' => 'Recovery feels a little short right now.',
          _ => 'There is a small state signal right now.',
        };
    }
  }

  Future<void> submitFollowup(String value) async {
    final followup = _state.pendingQuestion;
    if (followup == null) return;

    _state = _state.copyWith(
      followupSubmitState: SubmitState.submitting,
      clearErrorMessage: true,
    );
    notifyListeners();

    try {
      await repository.submitFollowup(
        followupId: followup.id,
        answerValue: value,
      );

      _state = _state.copyWith(
        followupSubmitState: SubmitState.success,
        clearPendingQuestion: true,
        acknowledgement: null,
        followupSuccessTick: _state.followupSuccessTick + 1,
        clearErrorMessage: true,
      );
    } catch (e) {
      _state = _state.copyWith(
        followupSubmitState: SubmitState.failure,
        errorMessage: e.toString(),
      );
    }

    notifyListeners();
  }

  Future<void> confirmSignal({
    required RecentSignalModel signal,
    required String confirmation,
    Map<String, dynamic>? correction,
  }) async {
    final signalCardId = signal.signalCardId ?? signal.id;
    if (signalCardId == null || signalCardId.trim().isEmpty) return;

    await repository.confirmSignalCard(
      signalCardId: signalCardId,
      userConfirmation: confirmation,
      userCorrectionJson: correction ?? const {},
    );

    final refreshed = await repository.fetchToday();
    _state = _state.copyWith(
      insight: refreshed['insight'] as TodayInsightModel?,
      bestAction: refreshed['bestAction'] as DailyBestActionModel?,
      recentSignals:
          refreshed['recentSignals'] as List<RecentSignalModel>? ?? const [],
      scheduleSignals:
          refreshed['scheduleSignals'] as List<ScheduleSignalModel>? ??
              const [],
      activeGoals: refreshed['activeGoals'] as List<GoalModel>? ?? const [],
      goalTasks:
          refreshed['goalTasks'] as List<GoalTaskInstanceModel>? ?? const [],
      aiJudgement: refreshed['aiJudgement'] as AiJudgementModel?,
      microActions:
          refreshed['microActions'] as List<MicroActionModel>? ?? const [],
      clearErrorMessage: true,
    );
    notifyListeners();
  }

  Future<void> createSchedule({
    required String title,
    DateTime? date,
    DateTime? time,
    DateTime? endTime,
    String? scene,
    String? note,
    String? expectedEnergyLoad,
    bool reminderEnabled = false,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      _state = _state.copyWith(errorMessage: 'schedule_title_required');
      notifyListeners();
      return;
    }
    await repository.createScheduleSignal(
      title: trimmed,
      date: date,
      time: time,
      endTime: endTime,
      scene: scene,
      note: note,
      expectedEnergyLoad: expectedEnergyLoad,
      reminderEnabled: reminderEnabled,
    );
    await load();
  }

  Future<void> updateSchedule({
    required ScheduleSignalModel schedule,
    required String title,
    DateTime? date,
    DateTime? time,
    DateTime? endTime,
    String? scene,
    String? note,
    String? expectedEnergyLoad,
    bool reminderEnabled = false,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      _state = _state.copyWith(errorMessage: 'schedule_title_required');
      notifyListeners();
      return;
    }
    await repository.updateScheduleSignal(
      id: schedule.id,
      title: trimmed,
      date: date,
      time: time,
      endTime: endTime,
      scene: scene,
      note: note,
      expectedEnergyLoad: expectedEnergyLoad,
      reminderEnabled: reminderEnabled,
    );
    await load();
  }

  Future<void> deleteSchedule(ScheduleSignalModel schedule) async {
    await repository.deleteScheduleSignal(schedule.id);
    await load();
  }

  Future<void> recordScheduleFeeling({
    required ScheduleSignalModel schedule,
    required String feelingText,
  }) async {
    final text = feelingText.trim();
    if (text.isEmpty) return;
    await repository.recordScheduleFeeling(
      schedule: schedule,
      feelingText: text,
    );
    await load();
  }

  Future<void> createGoal({
    required String title,
    String? desiredFrequency,
    int? desiredDurationMinutes,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      _state = _state.copyWith(errorMessage: 'goal_title_required');
      notifyListeners();
      return;
    }
    await repository.createGoalWithPlan(
      title: trimmed,
      desiredFrequency: desiredFrequency,
      desiredDurationMinutes: desiredDurationMinutes,
    );
    await load();
  }

  Future<void> submitGoalFeedback({
    required GoalTaskInstanceModel task,
    required String happened,
    String? effect,
  }) async {
    await repository.submitGoalFeedback(
      goalId: task.goalId,
      goalTaskInstanceId: task.id,
      happened: happened,
      effect: effect,
      taskTitle: task.title,
    );
    await load();
  }
}
