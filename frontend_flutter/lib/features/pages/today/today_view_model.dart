import 'package:flutter/foundation.dart';

import '../../../core/api/repositories/today_repository.dart';
import '../../../core/i18n/app_locale_text.dart';
import '../../../core/models/today_models.dart';
import '../../../shared/states/load_state.dart';
import 'today_state.dart';

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

  Future<void> retryDraftSync() async {
    if (_state.isDraftSyncing) return;
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
        draftSyncSubmitState:
            stillPending ? SubmitState.failure : SubmitState.success,
        draftSyncMessage: stillPending ? 'sync_still_pending' : 'sync_complete',
        clearErrorMessage: true,
      );
    } catch (e) {
      _state = _state.copyWith(
        draftSyncSubmitState: SubmitState.failure,
        draftSyncMessage: 'sync_still_pending',
        errorMessage: e.toString(),
      );
    }
    notifyListeners();
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

  Future<void> createPredictedSignal({
    AppLanguage language = AppLanguage.english,
  }) async {
    final originalSignals = _state.recentSignals.where(
      (signal) => signal.sourceType == 'text' || signal.sourceType == 'voice',
    );
    final firstSignal =
        originalSignals.isEmpty ? null : originalSignals.first.content.trim();
    final seed = _predictedSignalSeed(language, firstSignal);

    _state = _state.copyWith(
      captureSubmitState: SubmitState.submitting,
      clearErrorMessage: true,
    );
    notifyListeners();

    try {
      await repository.submitCapture(
        content: seed,
        sourceType: 'ai_predicted',
        rawPayloadJson: const {
          'user_triggered': true,
          'proactive_push': false,
          'included_by_default': false,
        },
      );
      final refreshed = await repository.fetchToday();
      _state = _state.copyWith(
        captureSubmitState: SubmitState.success,
        recentSignals:
            refreshed['recentSignals'] as List<RecentSignalModel>? ?? const [],
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

  String _predictedSignalSeed(AppLanguage language, String? firstSignal) {
    final hasFirstSignal = firstSignal != null && firstSignal.isNotEmpty;
    switch (language) {
      case AppLanguage.simplifiedChinese:
        return hasFirstSignal
            ? '也许今天有一个信号，和「$firstSignal」有关。'
            : '也许今天有一个信号，和哪里更耗力或更轻一点有关。';
      case AppLanguage.traditionalChinese:
        return hasFirstSignal
            ? '也許今天有一個信號，和「$firstSignal」有關。'
            : '也許今天有一個信號，和哪裡更耗力或更輕一點有關。';
      case AppLanguage.japanese:
        return hasFirstSignal
            ? '今日は「$firstSignal」の周りにシグナルがあるかもしれません。'
            : '今日は、少し重かったことや少し軽くなったことの周りにシグナルがあるかもしれません。';
      case AppLanguage.english:
        return hasFirstSignal
            ? 'Maybe today has a signal around $firstSignal.'
            : 'Maybe there is a small signal around what felt a little heavier or lighter today.';
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
      clearErrorMessage: true,
    );
    notifyListeners();
  }
}
