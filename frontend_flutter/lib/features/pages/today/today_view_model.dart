import 'package:flutter/foundation.dart';

import '../../../core/api/repositories/today_repository.dart';
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
        insight: data['insight'],
        pendingQuestion: data['pendingQuestion'],
        bestAction: data['bestAction'],
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

      final backendSignals =
          (result['updatedRecentSignals'] as List<RecentSignalModel>? ?? const []);

      _state = _state.copyWith(
        captureSubmitState: SubmitState.success,
        inputText: '',
        acknowledgement: result['acknowledgement'] as String?,
        pendingQuestion: result['followup'],
        recentSignals: backendSignals,
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
      notifyListeners();

      await load();
    } catch (e) {
      _state = _state.copyWith(
        followupSubmitState: SubmitState.failure,
        errorMessage: e.toString(),
      );
      notifyListeners();
    }
  }
}
