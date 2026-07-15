import 'package:flutter/foundation.dart';

import '../../../core/api/repositories/today_repository.dart';
import '../../../core/i18n/app_locale_text.dart';
import '../../../core/models/phase3_plus_models.dart';
import '../../../core/models/today_models.dart';
import '../../../core/models/weekly_models.dart';
import '../../../shared/states/load_state.dart';
import 'today_state.dart';

enum DraftSyncResult { completed, stillPending, noPending }

class TodayViewModel extends ChangeNotifier {
  final TodayRepository repository;
  final Set<String> _sessionHiddenJudgementIds = <String>{};

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
        aiJudgement: _visibleJudgement(data['aiJudgement']),
        microActions:
            data['microActions'] as List<MicroActionModel>? ?? const [],
        todayLifeExperiment:
            data['todayLifeExperiment'] as LifeExperimentModel?,
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
        aiJudgement: _visibleJudgement(data['aiJudgement']),
        microActions:
            data['microActions'] as List<MicroActionModel>? ?? const [],
        todayLifeExperiment:
            data['todayLifeExperiment'] as LifeExperimentModel?,
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
        aiJudgement: refreshed['aiJudgement'] as AiJudgementModel?,
        microActions:
            refreshed['microActions'] as List<MicroActionModel>? ?? const [],
        todayLifeExperiment:
            refreshed['todayLifeExperiment'] as LifeExperimentModel?,
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
        aiJudgement: refreshed['aiJudgement'] as AiJudgementModel?,
        microActions:
            refreshed['microActions'] as List<MicroActionModel>? ?? const [],
        todayLifeExperiment:
            refreshed['todayLifeExperiment'] as LifeExperimentModel?,
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
    String? detail,
    int? energyLevel,
    String? note,
  }) async {
    final content = _quickStatusText(
      choice,
      language,
      detail: detail,
      energyLevel: energyLevel,
      note: note,
    );
    if (content.trim().isEmpty) return;
    final rawPayloadJson = {
      'quick_status': choice,
      'user_triggered': true,
      if (detail != null && detail.trim().isNotEmpty) 'detail': detail,
      if (energyLevel != null) 'energy_level': energyLevel,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
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
        aiJudgement: refreshed['aiJudgement'] as AiJudgementModel?,
        microActions:
            refreshed['microActions'] as List<MicroActionModel>? ?? const [],
        todayLifeExperiment:
            refreshed['todayLifeExperiment'] as LifeExperimentModel?,
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

  Future<void> submitTimeUseSignal({
    required String title,
    required DateTime startAt,
    required DateTime endAt,
    required String category,
    required String categoryLabel,
    required String recordStatus,
    String? energyEffect,
    String? note,
    AppLanguage language = AppLanguage.english,
  }) async {
    final normalizedTitle = title.trim();
    final normalizedNote = note?.trim() ?? '';
    if (normalizedTitle.isEmpty) {
      _state = _state.copyWith(errorMessage: 'empty_input');
      notifyListeners();
      return;
    }
    if (!endAt.isAfter(startAt)) {
      _state = _state.copyWith(errorMessage: 'invalid_time_range');
      notifyListeners();
      return;
    }

    final durationMinutes = endAt.difference(startAt).inMinutes;
    final rawPayloadJson = <String, dynamic>{
      'timeline_type': 'time_use',
      'schema_version': 1,
      'title': normalizedTitle,
      'record_status': recordStatus,
      'category': category,
      'start_at': startAt.toIso8601String(),
      'end_at': endAt.toIso8601String(),
      'duration_minutes': durationMinutes,
      if (energyEffect != null && energyEffect.trim().isNotEmpty)
        'energy_effect': energyEffect.trim(),
      if (normalizedNote.isNotEmpty) 'note': normalizedNote,
      'user_triggered': true,
    };
    final content = _timeUseContent(
      title: normalizedTitle,
      startAt: startAt,
      endAt: endAt,
      categoryLabel: categoryLabel,
      recordStatus: recordStatus,
      energyEffect: energyEffect,
      note: normalizedNote,
      language: language,
    );

    _state = _state.copyWith(
      captureSubmitState: SubmitState.submitting,
      clearErrorMessage: true,
    );
    notifyListeners();

    try {
      await repository.submitCapture(
        content: content,
        sourceType: 'time_use',
        rawPayloadJson: rawPayloadJson,
      );
      final localFallbackSignals = _signalsWithSubmittedLocal(
        content: content,
        sourceType: 'time_use',
        rawPayloadJson: rawPayloadJson,
        language: language,
      );
      final refreshed = await repository.fetchToday();
      final refreshedSignals =
          refreshed['recentSignals'] as List<RecentSignalModel>?;
      final refreshedIncludesSubmitted = refreshedSignals?.any(
            (signal) =>
                signal.sourceType == 'time_use' &&
                signal.rawPayloadJson['start_at'] ==
                    rawPayloadJson['start_at'] &&
                signal.content == content,
          ) ??
          false;
      _state = _state.copyWith(
        captureSubmitState: SubmitState.success,
        insight: refreshed['insight'] as TodayInsightModel?,
        bestAction: refreshed['bestAction'] as DailyBestActionModel?,
        recentSignals: refreshedIncludesSubmitted
            ? refreshedSignals
            : localFallbackSignals,
        aiJudgement: refreshed['aiJudgement'] as AiJudgementModel?,
        microActions:
            refreshed['microActions'] as List<MicroActionModel>? ?? const [],
        todayLifeExperiment:
            refreshed['todayLifeExperiment'] as LifeExperimentModel?,
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
      sceneTags: switch (sourceType) {
        'one_tap' => const ['state'],
        'time_use' => [
            rawPayloadJson['category']?.toString() ?? 'time_use',
          ],
        _ => const <String>[],
      },
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
    if (sourceType == 'time_use') {
      return switch (language) {
        AppLanguage.simplifiedChinese => '这段时间安排已经放进你的手帐时间线。',
        AppLanguage.traditionalChinese => '這段時間安排已經放進你的手帳時間線。',
        AppLanguage.japanese => 'この時間の予定を手帳タイムラインに残しました。',
        AppLanguage.english =>
          'This time entry has been added to your diary timeline.',
      };
    }
    return switch (language) {
      AppLanguage.simplifiedChinese => '这条信号已经保存。',
      AppLanguage.traditionalChinese => '這條信號已經保存。',
      AppLanguage.japanese => 'このシグナルを保存しました。',
      AppLanguage.english => 'This signal has been saved.',
    };
  }

  String _timeUseContent({
    required String title,
    required DateTime startAt,
    required DateTime endAt,
    required String categoryLabel,
    required String recordStatus,
    required String? energyEffect,
    required String note,
    required AppLanguage language,
  }) {
    final range = '${_clock(startAt)}–${_clock(endAt)}';
    final statusLabel = switch ((language, recordStatus)) {
      (AppLanguage.simplifiedChinese, 'planned') => '接下来安排',
      (AppLanguage.traditionalChinese, 'planned') => '接下來安排',
      (AppLanguage.japanese, 'planned') => 'これからの予定',
      (AppLanguage.english, 'planned') => 'Planned',
      (AppLanguage.simplifiedChinese, _) => '已经发生',
      (AppLanguage.traditionalChinese, _) => '已經發生',
      (AppLanguage.japanese, _) => '完了',
      (AppLanguage.english, _) => 'Completed',
    };
    final energyLabel = _timeUseEnergyLabel(energyEffect, language);
    return switch (language) {
      AppLanguage.simplifiedChinese =>
        '$range · $categoryLabel · $title（$statusLabel${energyLabel.isEmpty ? '' : '，$energyLabel'}）${note.isEmpty ? '' : '。补充：$note'}',
      AppLanguage.traditionalChinese =>
        '$range · $categoryLabel · $title（$statusLabel${energyLabel.isEmpty ? '' : '，$energyLabel'}）${note.isEmpty ? '' : '。補充：$note'}',
      AppLanguage.japanese =>
        '$range・$categoryLabel・$title（$statusLabel${energyLabel.isEmpty ? '' : '、$energyLabel'}）${note.isEmpty ? '' : '。メモ：$note'}',
      AppLanguage.english =>
        '$range · $categoryLabel · $title ($statusLabel${energyLabel.isEmpty ? '' : ', $energyLabel'})${note.isEmpty ? '' : '. Note: $note'}',
    };
  }

  String _timeUseEnergyLabel(String? value, AppLanguage language) {
    if (value == null || value.trim().isEmpty || value == 'unknown') return '';
    return switch ((language, value)) {
      (AppLanguage.simplifiedChinese, 'draining') => '偏耗力',
      (AppLanguage.simplifiedChinese, 'restoring') => '偏恢复',
      (AppLanguage.simplifiedChinese, _) => '体感一般',
      (AppLanguage.traditionalChinese, 'draining') => '偏耗力',
      (AppLanguage.traditionalChinese, 'restoring') => '偏恢復',
      (AppLanguage.traditionalChinese, _) => '體感一般',
      (AppLanguage.japanese, 'draining') => '消耗気味',
      (AppLanguage.japanese, 'restoring') => '回復寄り',
      (AppLanguage.japanese, _) => '負荷は普通',
      (AppLanguage.english, 'draining') => 'draining',
      (AppLanguage.english, 'restoring') => 'restoring',
      (AppLanguage.english, _) => 'neutral',
    };
  }

  String _clock(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

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
    bool addToTimeline = true,
    AppLanguage language = AppLanguage.english,
  }) async {
    final createsSignalCard = addToTimeline &&
        const {'confirmed', 'adjusted', 'accurate', 'partial'}
            .contains(status == 'supplemented' ? 'adjusted' : status);
    if (!createsSignalCard) {
      _sessionHiddenJudgementIds.add(judgement.id);
      _state = _state.copyWith(
        captureSubmitState: SubmitState.success,
        aiJudgement: null,
        clearErrorMessage: true,
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
      final refreshed = await repository.respondToAiJudgement(
        judgementId: judgement.id,
        status: status,
        userAdjustmentText: userAdjustmentText,
        addToTimeline: addToTimeline,
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

  Future<void> archiveAndSubmitMicroActionFeedback({
    required MicroActionModel action,
    required String feedback,
  }) async {
    _state = _state.copyWith(
      captureSubmitState: SubmitState.submitting,
      clearErrorMessage: true,
    );
    notifyListeners();

    try {
      await repository.chooseMicroAction(
        microActionId: action.id,
        choice: 'weekly_experiment',
      );
      final refreshed = await repository.submitMicroActionFeedback(
        microActionId: action.id,
        feedback: feedback,
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
      aiJudgement: _visibleJudgement(refreshed['aiJudgement']),
      microActions:
          refreshed['microActions'] as List<MicroActionModel>? ?? const [],
      todayLifeExperiment:
          refreshed['todayLifeExperiment'] as LifeExperimentModel?,
      captureSuccessTick: incrementSuccessTick
          ? _state.captureSuccessTick + 1
          : _state.captureSuccessTick,
      clearErrorMessage: true,
    );
  }

  AiJudgementModel? _visibleJudgement(Object? value) {
    final judgement = value as AiJudgementModel?;
    if (judgement == null ||
        _sessionHiddenJudgementIds.contains(judgement.id)) {
      return null;
    }
    return judgement;
  }

  String _quickStatusText(
    String choice,
    AppLanguage language, {
    String? detail,
    int? energyLevel,
    String? note,
  }) {
    final noteText = note?.trim();
    final base = _quickStatusBaseText(choice, language);
    final detailText = _quickStatusDetailText(detail, language);
    final energyText = _quickStatusEnergyText(energyLevel, language);
    if (noteText != null && noteText.isNotEmpty) {
      return switch (language) {
        AppLanguage.simplifiedChinese =>
          '$base$detailText$energyText 补充：$noteText',
        AppLanguage.traditionalChinese =>
          '$base$detailText$energyText 補充：$noteText',
        AppLanguage.japanese => '$base$detailText$energyText 補足：$noteText',
        AppLanguage.english => '$base$detailText$energyText Note: $noteText',
      };
    }
    return '$base$detailText$energyText';
  }

  String _quickStatusBaseText(String choice, AppLanguage language) {
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

  String _quickStatusDetailText(String? detail, AppLanguage language) {
    if (detail == null || detail.trim().isEmpty) return '';
    return switch (language) {
      AppLanguage.simplifiedChinese => switch (detail) {
          'a_bit_tired' => ' 更像是有点累。',
          'mind_messy' => ' 更像是心里乱。',
          'want_rest' => ' 更像是想休息。',
          'still_want_do' => ' 但还想做点事。',
          _ => '',
        },
      AppLanguage.traditionalChinese => switch (detail) {
          'a_bit_tired' => ' 更像是有點累。',
          'mind_messy' => ' 更像是心裡亂。',
          'want_rest' => ' 更像是想休息。',
          'still_want_do' => ' 但還想做點事。',
          _ => '',
        },
      AppLanguage.japanese => switch (detail) {
          'a_bit_tired' => ' 少し疲れている感じです。',
          'mind_messy' => ' 心が散らかっている感じです。',
          'want_rest' => ' 休みたい感じです。',
          'still_want_do' => ' でも少し動きたい感じです。',
          _ => '',
        },
      AppLanguage.english => switch (detail) {
          'a_bit_tired' => ' It feels a bit tired.',
          'mind_messy' => ' It feels mentally messy.',
          'want_rest' => ' It feels like I want rest.',
          'still_want_do' => ' I still want to do a little.',
          _ => '',
        },
    };
  }

  String _quickStatusEnergyText(int? energyLevel, AppLanguage language) {
    if (energyLevel == null) return '';
    return switch (language) {
      AppLanguage.simplifiedChinese => switch (energyLevel) {
          0 => ' 精力偏低。',
          1 => ' 精力还好。',
          _ => ' 精力很足。',
        },
      AppLanguage.traditionalChinese => switch (energyLevel) {
          0 => ' 精力偏低。',
          1 => ' 精力還好。',
          _ => ' 精力很足。',
        },
      AppLanguage.japanese => switch (energyLevel) {
          0 => ' エネルギーは低めです。',
          1 => ' エネルギーはまあまあです。',
          _ => ' エネルギーは十分です。',
        },
      AppLanguage.english => switch (energyLevel) {
          0 => ' Energy feels low.',
          1 => ' Energy feels okay.',
          _ => ' Energy feels enough.',
        },
    };
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
      aiJudgement: refreshed['aiJudgement'] as AiJudgementModel?,
      microActions:
          refreshed['microActions'] as List<MicroActionModel>? ?? const [],
      todayLifeExperiment:
          refreshed['todayLifeExperiment'] as LifeExperimentModel?,
      clearErrorMessage: true,
    );
    notifyListeners();
  }

  Future<void> submitTodayLifeExperimentFeedback({
    required LifeExperimentModel experiment,
    required String status,
    required String feedbackText,
  }) async {
    _state = _state.copyWith(
      captureSubmitState: SubmitState.submitting,
      clearErrorMessage: true,
    );
    notifyListeners();

    try {
      final refreshed = await repository.submitTodayLifeExperimentFeedback(
        experimentId: experiment.id,
        status: status,
        feedbackText: feedbackText,
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
}
