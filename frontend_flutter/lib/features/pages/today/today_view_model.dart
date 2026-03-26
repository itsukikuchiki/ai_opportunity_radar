import 'package:flutter/foundation.dart';
import '../../../core/api/repositories/today_repository.dart';
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
    _state = _state.copyWith(loadState: LoadState.loading);
    notifyListeners();
    try {
      final data = await repository.fetchToday();
      _state = _state.copyWith(
        loadState: LoadState.ready,
        insight: data['insight'],
        pendingQuestion: data['pendingQuestion'],
        bestAction: data['bestAction'],
        recentSignals: data['recentSignals'],
        errorMessage: null,
      );
    } catch (e) {
      _state = _state.copyWith(loadState: LoadState.error, errorMessage: e.toString());
    }
    notifyListeners();
  }

  void updateInput(String value) {
    _state = _state.copyWith(inputText: value);
    notifyListeners();
  }

  Future<void> submitCapture({String? tagHint}) async {
    if (_state.inputText.trim().isEmpty) return;
    _state = _state.copyWith(captureSubmitState: SubmitState.submitting);
    notifyListeners();
    try {
      final result = await repository.submitCapture(content: _state.inputText, tagHint: tagHint);
      _state = _state.copyWith(
        captureSubmitState: SubmitState.success,
        inputText: '',
        acknowledgement: result['acknowledgement'] as String,
        pendingQuestion: result['followup'],
        recentSignals: result['updatedRecentSignals'],
      );
    } catch (e) {
      _state = _state.copyWith(captureSubmitState: SubmitState.failure, errorMessage: e.toString());
    }
    notifyListeners();
  }

  Future<void> submitFollowup(String value) async {
    final followup = _state.pendingQuestion;
    if (followup == null) return;
    _state = _state.copyWith(followupSubmitState: SubmitState.submitting);
    notifyListeners();
    try {
      await repository.submitFollowup(followupId: followup.id, answerValue: value);
      _state = _state.copyWith(followupSubmitState: SubmitState.success, pendingQuestion: null);
    } catch (e) {
      _state = _state.copyWith(followupSubmitState: SubmitState.failure, errorMessage: e.toString());
    }
    notifyListeners();
  }
}
