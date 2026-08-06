import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:shared_preferences/shared_preferences.dart';

import '../../backup/cloud_backup_sync_service.dart';
import '../../eligibility/signal_eligibility_service.dart';
import '../../eligibility/today_signal_scope.dart';
import '../../local/local_capture_repository.dart';
import '../../local/local_daily_snapshot_repository.dart';
import '../../local/local_life_experiment_repository.dart';
import '../../local/local_pipeline_run_repository.dart';
import '../../local/local_phase3_plus_repository.dart';
import '../../models/experiment_evaluation_models.dart';
import '../../models/phase3_plus_models.dart';
import '../../models/today_models.dart';
import '../../i18n/app_locale_text.dart';
import '../../i18n/runtime_locale_text.dart';
import '../../preferences/focus_domains.dart';
import '../../../shared/utils/l1_attunement_fallback.dart';
import '../api_client.dart';
import 'analytics_repository.dart';
import 'ai_repository.dart';

typedef FocusAreaLoader = Future<String?> Function();
typedef ResponseStyleLoader = Future<String?> Function();
typedef TodayNowLoader = DateTime Function();

enum _AiJudgementCue {
  interest,
  switching,
  boundary,
  load,
  recovery,
  energy,
  positive,
}

class TodayRepository {
  final LocalCaptureRepository localCaptureRepository;
  final LocalDailySnapshotRepository localDailySnapshotRepository;
  final LocalLifeExperimentRepository? localLifeExperimentRepository;
  final LocalPhase3PlusRepository? localPhase3PlusRepository;
  final AiRepository aiRepository;
  final ApiClient? apiClient;
  final AnalyticsRepository? analyticsRepository;
  final FocusAreaLoader? focusAreaLoader;
  final ResponseStyleLoader? responseStyleLoader;
  final CloudBackupSyncService? cloudBackupSyncService;
  final SignalEligibilityService eligibilityService;
  final String localUserId;
  final TodayNowLoader? nowLoader;

  TodayRepository({
    required this.localCaptureRepository,
    required this.localDailySnapshotRepository,
    this.localLifeExperimentRepository,
    this.localPhase3PlusRepository,
    required this.aiRepository,
    this.apiClient,
    this.analyticsRepository,
    this.focusAreaLoader,
    this.responseStyleLoader,
    this.cloudBackupSyncService,
    this.localUserId = 'local',
    this.nowLoader,
    SignalEligibilityService? eligibilityService,
  }) : eligibilityService =
            eligibilityService ?? const SignalEligibilityService();

  Future<Map<String, dynamic>> fetchToday() async {
    final now = nowLoader?.call() ?? DateTime.now();
    await retryPendingDrafts();
    if (apiClient != null) {
      try {
        final remoteSignals = await _fetchRemoteSignalCards();
        await localCaptureRepository.upsertRemoteSignalCards(remoteSignals);
      } catch (_) {
        // 远端不可用时继续使用本地 SignalCard 缓存和 draft queue。
      }
    }

    final allSignals = apiClient == null
        ? await localCaptureRepository.listRecentSignals(limit: 200)
        : await localCaptureRepository.listSignalCards(limit: 200);
    final liveAllSignals =
        TodaySignalScope.liveOnly(allSignals).toList(growable: false);
    final todayKey = _dateKey(now);
    final todaySignals = liveAllSignals
        .where((signal) => signal.localDateKey() == todayKey)
        .toList();
    final snapshot = await localDailySnapshotRepository.getByDate(now);

    final sourceHash = localDailySnapshotRepository.buildSourceHash(
      todaySignals,
      language: aiRepository.languageLoader(),
    );

    if ((todaySignals.isNotEmpty || snapshot != null) &&
        (snapshot == null || snapshot.sourceHash != sourceHash)) {
      await _regenerateTodaySummary(todaySignals);
    }

    final latestSnapshot = await localDailySnapshotRepository.getByDate(now);
    final latestSignalsUnfiltered = apiClient == null
        ? allSignals
        : await localCaptureRepository.listSignalCards(limit: 200);
    final latestSignals = TodaySignalScope.liveOnly(latestSignalsUnfiltered)
        .toList(growable: false);
    var aiJudgement =
        await localPhase3PlusRepository?.getAiJudgementForDate(todayKey);
    final shouldRefreshAiJudgement = aiJudgement == null ||
        _aiJudgementSourcesChanged(
          aiJudgement,
          allSignals: liveAllSignals,
          todayKey: todayKey,
        );
    if (shouldRefreshAiJudgement) {
      try {
        aiJudgement = await createAiJudgementForToday(
          language: _deviceAppLanguage(),
        );
      } catch (_) {
        // 预判属于增强信息，生成失败不阻塞 Today 的记录与时间线。
      }
    }
    final microActions =
        await localPhase3PlusRepository?.listMicroActionsForDate(todayKey) ??
            const <MicroActionModel>[];
    final todayLifeExperiment =
        await localLifeExperimentRepository?.getSavedForToday(
      localUserId: localUserId,
      today: now,
    );

    return {
      'insight': TodayInsightModel(
        text: latestSnapshot?.observationText ??
            _defaultObservation(todaySignals),
      ),
      'pendingQuestion': null,
      'bestAction': DailyBestActionModel(
        text:
            latestSnapshot?.suggestionText ?? _defaultSuggestion(todaySignals),
      ),
      'recentSignals': latestSignals,
      'aiJudgement': aiJudgement,
      'microActions': microActions,
      'todayLifeExperiment': todayLifeExperiment,
    };
  }

  Future<Map<String, dynamic>> submitTodayLifeExperimentFeedback({
    required String experimentId,
    required String status,
    required String feedbackText,
  }) async {
    final feedback = await localLifeExperimentRepository?.recordFeedback(
      experimentId: experimentId,
      completionStatus: status,
      feedbackText: feedbackText,
      enforceProgressWindow: true,
    );
    if (feedback != null) {
      cloudBackupSyncService?.markDataChanged();
      unawaited(analyticsRepository?.track(
        'life_experiment_feedback_submitted',
        properties: {
          'status': status,
          'has_note': feedbackText.trim().isNotEmpty,
        },
      ));
    }
    return fetchToday();
  }

  Future<AiJudgementModel?> createAiJudgementForToday({
    AppLanguage language = AppLanguage.english,
    int variationIndex = 0,
  }) async {
    final repo = localPhase3PlusRepository;
    if (repo == null) return null;

    final todayKey = _dateKey(nowLoader?.call() ?? DateTime.now());
    final allSignals = await localCaptureRepository.listSignalCards(limit: 200);
    final eligibleSignals = TodaySignalScope.liveOnly(allSignals)
        .where((signal) => _isEligibleForAiJudgement(signal, todayKey))
        .toList();
    if (eligibleSignals.isEmpty) {
      return null;
    }

    final anchorSignal = _latestAiJudgementAnchor(eligibleSignals);
    final anchorSignalId =
        (anchorSignal.signalCardId ?? anchorSignal.id ?? '').trim();
    if (anchorSignalId.isEmpty) {
      return null;
    }

    final latestForDate = await repo.getAiJudgementForDate(todayKey);
    final sourceSignalCardIds = <String>[anchorSignalId];
    final sourceVersionId = _stableAiJudgementId(
      repo.localUserId,
      todayKey,
      sourceSignalCardIds,
      sourceVersionFingerprint: _aiJudgementAnchorFingerprint(anchorSignal),
    );
    AiJudgementModel? matchingExisting;
    if (latestForDate?.id == sourceVersionId &&
        _sameIds(
          sourceSignalCardIds.toSet(),
          latestForDate!.sourceSignalCardIds,
        ) &&
        latestForDate.sourceScheduleSignalIds.isEmpty &&
        latestForDate.sourceGoalTaskInstanceIds.isEmpty) {
      matchingExisting = latestForDate;
    } else {
      final versioned = await repo.getAiJudgementById(sourceVersionId);
      if (versioned != null &&
          _sameIds(
            sourceSignalCardIds.toSet(),
            versioned.sourceSignalCardIds,
          )) {
        matchingExisting = versioned;
      }
    }
    final generated = _buildAiJudgementCopy(
      anchorSignal,
      language,
      variationIndex: variationIndex,
    );
    if (generated == null) {
      return null;
    }
    final now = nowLoader?.call() ?? DateTime.now();
    final judgement = AiJudgementModel(
      id: matchingExisting?.id ?? sourceVersionId,
      sourceSignalCardIds: sourceSignalCardIds,
      sourceScheduleSignalIds: const [],
      sourceGoalTaskInstanceIds: const [],
      localDate: todayKey,
      judgementText: generated[0],
      evidenceText: generated[1],
      predictionKind: 'inferred_signal',
      predictedSignalText: generated[0],
      suggestedPattern: generated[2],
      suggestedLifeChainStage: generated[3],
      confidenceLevel: 'low',
      status: matchingExisting?.status ?? 'pending',
      userAdjustmentText: matchingExisting?.userAdjustmentText,
      confirmationNote: matchingExisting?.confirmationNote,
      linkedMicroActionId: matchingExisting?.linkedMicroActionId,
      includedInWeekly: matchingExisting?.includedInWeekly ?? false,
      includedInJourney: matchingExisting?.includedInJourney ?? false,
      createdAt: matchingExisting?.createdAt ?? now,
      updatedAt: now,
    );
    if (variationIndex == 0) {
      await repo.upsertAiJudgement(judgement);
      cloudBackupSyncService?.markDataChanged();
      unawaited(analyticsRepository?.track(
        'ai_judgement_generated',
        properties: {
          'daily_signal_count': eligibleSignals.length,
          'supporting_signal_count': 1,
          'confidence_level': judgement.confidenceLevel,
          'variation_index': variationIndex,
        },
      ));
    }
    return judgement;
  }

  Future<Map<String, dynamic>> respondToAiJudgement({
    required String judgementId,
    required String status,
    String? userAdjustmentText,
    AiJudgementModel? displayedJudgement,
    bool addToTimeline = true,
    AppLanguage language = AppLanguage.english,
  }) async {
    final normalizedStatus = status == 'supplemented' ? 'adjusted' : status;
    final confirmedSignal = const {
      'confirmed',
      'adjusted',
      'accurate',
      'partial',
    }.contains(normalizedStatus);

    // Choosing not to add the proposal is a zero-write dismissal. It creates
    // neither a SignalCard nor a persisted match-feedback event.
    if (!confirmedSignal || !addToTimeline) {
      return _readTodayWithoutDerivedWrites();
    }

    final repo = localPhase3PlusRepository;
    if (repo == null) return fetchToday();

    final persistedJudgement = await repo.getAiJudgementById(judgementId);
    if (persistedJudgement == null) return fetchToday();
    // Session-only replacement predictions intentionally are not persisted.
    // Save the exact candidate the user saw, while keeping the persisted
    // judgement as the authoritative source link and status record.
    final judgement = displayedJudgement?.id == judgementId &&
            _sameIds(
              displayedJudgement!.sourceSignalCardIds.toSet(),
              persistedJudgement.sourceSignalCardIds,
            )
        ? displayedJudgement
        : persistedJudgement;
    final acceptedSessionReplacement = judgement.predictedSignalText !=
            persistedJudgement.predictedSignalText ||
        judgement.suggestedPattern != persistedJudgement.suggestedPattern ||
        judgement.suggestedLifeChainStage !=
            persistedJudgement.suggestedLifeChainStage;
    if (acceptedSessionReplacement) {
      await repo.upsertAiJudgement(judgement);
    }

    final confirmationNote = _confirmationNote(
      language,
      addedToTimeline: true,
    );
    final confirmedContent = (userAdjustmentText?.trim().isNotEmpty ?? false)
        ? userAdjustmentText!.trim()
        : judgement.predictedSignalText.trim();
    var acknowledgement = _defaultAcknowledgement(
      confirmedContent,
      language: language,
    );
    try {
      final aiReply = await aiRepository.generateCaptureReply(
        content: confirmedContent,
        recentAssistantTexts:
            await localCaptureRepository.listRecentAcknowledgements(limit: 10),
        language: _languageCode(language),
        focusArea: await _readFocusArea(),
        responseStyle: await _readResponseStyle(),
      );
      if (aiReply.acknowledgement.trim().isNotEmpty) {
        acknowledgement = aiReply.acknowledgement.trim();
      }
    } catch (_) {
      // Saving the confirmed SignalCard must never depend on AI availability.
    }
    unawaited(analyticsRepository?.track(
      'ai_judgement_responded',
      properties: {
        'status': normalizedStatus,
        'confirmed_signal': confirmedSignal,
        'added_to_timeline': true,
        'has_adjustment': userAdjustmentText?.trim().isNotEmpty ?? false,
      },
    ));
    await localCaptureRepository.insertConfirmedSignalCard(
      signalCardId: 'ai_prediction_${judgement.id}',
      content: confirmedContent,
      sourceType: 'ai_predicted',
      language: _languageCode(language),
      acknowledgement: acknowledgement,
      observation: judgement.evidenceText.trim().isEmpty
          ? null
          : judgement.evidenceText.trim(),
      sceneTags: [
        if (judgement.suggestedPattern.trim().isNotEmpty)
          judgement.suggestedPattern.trim(),
        if (judgement.suggestedLifeChainStage.trim().isNotEmpty)
          judgement.suggestedLifeChainStage.trim(),
      ],
      rawPayloadJson: {
        'ai_judgement_id': judgement.id,
        'confirmation_status': normalizedStatus,
        'added_to_timeline': true,
        'confirmation_note': confirmationNote,
        if (userAdjustmentText?.trim().isNotEmpty ?? false)
          'user_adjustment_text': userAdjustmentText!.trim(),
      },
      includedInSummary: false,
      includedInWeekly: false,
      includedInJourney: false,
    );
    await repo.updateAiJudgementStatus(
      id: judgementId,
      status: normalizedStatus,
      userAdjustmentText: userAdjustmentText,
      confirmationNote: confirmationNote,
      includedInWeekly: false,
      includedInJourney: false,
    );
    cloudBackupSyncService?.markDataChanged();
    return fetchToday();
  }

  /// Returns the current local Today projection without synchronizing,
  /// regenerating summaries or refreshing AI judgements.
  ///
  /// The dismissal path uses this deliberately: "do not add to timeline" is
  /// a strict no-op for persisted product data, including derived caches.
  Future<Map<String, dynamic>> _readTodayWithoutDerivedWrites() async {
    final now = nowLoader?.call() ?? DateTime.now();
    final todayKey = _dateKey(now);
    final signals = await localCaptureRepository.listRecentSignals(limit: 200);
    final todaySignals = signals
        .where((signal) => signal.localDateKey() == todayKey)
        .toList(growable: false);
    final snapshot = await localDailySnapshotRepository.getByDate(now);
    final aiJudgement =
        await localPhase3PlusRepository?.getAiJudgementForDate(todayKey);
    final microActions =
        await localPhase3PlusRepository?.listMicroActionsForDate(todayKey) ??
            const <MicroActionModel>[];
    final todayLifeExperiment =
        await localLifeExperimentRepository?.getSavedForToday(
      localUserId: localUserId,
      today: now,
    );

    return {
      'insight': TodayInsightModel(
        text: snapshot?.observationText ?? _defaultObservation(todaySignals),
      ),
      'pendingQuestion': null,
      'bestAction': DailyBestActionModel(
        text: snapshot?.suggestionText ?? _defaultSuggestion(todaySignals),
      ),
      'recentSignals': signals,
      'aiJudgement': aiJudgement,
      'microActions': microActions,
      'todayLifeExperiment': todayLifeExperiment,
    };
  }

  Future<Map<String, dynamic>> chooseMicroAction({
    required String microActionId,
    required String choice,
    AppLanguage language = AppLanguage.english,
  }) async {
    final repo = localPhase3PlusRepository;
    if (repo == null) return fetchToday();

    final action = await repo.getMicroActionById(microActionId);
    if (action == null) return fetchToday();

    final updated = switch (choice) {
      'today_try' => _copyMicroAction(
          action,
          status: 'accepted',
          actionType: 'today_try',
        ),
      'add_to_weekly' => _copyMicroAction(
          action,
          status: 'active',
          actionType: 'weekly_experiment',
        ),
      'weekly_experiment' => _copyMicroAction(
          action,
          status: 'active',
          actionType: 'weekly_experiment',
        ),
      'lighter' => _copyMicroAction(
          action,
          title: _lighterMicroActionTitle(language),
          difficulty: 'very_light',
          status: 'adjusted',
        ),
      'skip' => _copyMicroAction(action, status: 'skipped'),
      _ => action,
    };

    await repo.upsertMicroAction(updated);
    cloudBackupSyncService?.markDataChanged();
    unawaited(analyticsRepository?.track(
      'micro_action_chosen',
      properties: {
        'choice': choice,
        'result_status': updated.status,
        'action_type': updated.actionType,
        'difficulty': updated.difficulty,
      },
    ));
    return fetchToday();
  }

  Future<Map<String, dynamic>> submitMicroActionFeedback({
    required String microActionId,
    required String feedback,
    String? effect,
    String? difficulty,
    String? userNote,
  }) async {
    final repo = localPhase3PlusRepository;
    if (repo == null) return fetchToday();

    final action = await repo.getMicroActionById(microActionId);
    if (action == null) return fetchToday();

    final now = nowLoader?.call() ?? DateTime.now();
    if (!_canRecordMicroActionFeedbackOn(action: action, date: now)) {
      return fetchToday();
    }
    final canonicalFeedback = switch (feedback) {
      'completed' || 'done' || 'occurred' || 'happened' => 'completed',
      'not_completed' ||
      'not_done' ||
      'not_occurred' ||
      'not_happened' ||
      'not_suitable_today' =>
        'not_completed',
      _ => feedback,
    };
    final isCompleted = canonicalFeedback == 'completed';
    final normalizedEffect = isCompleted ? effect : null;
    final normalizedDifficulty = isCompleted ? difficulty : null;
    final nextAdjustment = normalizedDifficulty == SmallTryDifficulty.difficult
        ? SmallTryNextAdjustment.makeLighter
        : SmallTryNextAdjustment.keep;

    await repo.recordStructuredMicroActionFeedback(
      microActionId: microActionId,
      localDate: _dateKey(now),
      completionStatus: canonicalFeedback,
      effect: normalizedEffect,
      difficulty: normalizedDifficulty,
      note: userNote,
      nextAdjustment: nextAdjustment,
      createdAt: now,
    );
    await repo.updateMicroActionStatus(
      id: microActionId,
      // An attempt result is not the lifecycle of the small try. Only an
      // explicit round review may retain, lighten, or end the adopted object.
      status: action.status,
      feedbackStatus: canonicalFeedback,
    );
    cloudBackupSyncService?.markDataChanged();
    unawaited(analyticsRepository?.track(
      'micro_action_feedback_submitted',
      properties: {
        'feedback': canonicalFeedback,
        'happened': canonicalFeedback,
        'effect': normalizedEffect,
        'difficulty': normalizedDifficulty,
        'next_adjustment': nextAdjustment,
        'has_note': userNote?.trim().isNotEmpty ?? false,
      },
    ));
    return fetchToday();
  }

  bool _canRecordMicroActionFeedbackOn({
    required MicroActionModel action,
    required DateTime date,
  }) {
    final lifecycle = action.status.trim().toLowerCase();
    if (lifecycle.contains('pause') ||
        lifecycle.contains('stop') ||
        lifecycle.contains('skip') ||
        lifecycle.contains('archive') ||
        lifecycle.contains('complete') ||
        lifecycle.contains('done') ||
        lifecycle.contains('finish') ||
        lifecycle.contains('dismiss')) {
      return false;
    }

    final start = DateTime.tryParse(
          action.progressStartDate ?? action.plannedDate ?? '',
        ) ??
        action.adoptedAt ??
        action.createdAt;
    if (start == null) return false;
    final configuredEnd = DateTime.tryParse(action.progressEndDate ?? '');
    final localDate = DateTime(date.year, date.month, date.day);
    final localStart = DateTime(start.year, start.month, start.day);
    if (localDate.isBefore(localStart)) return false;
    // A source/adoption week is not a lifecycle deadline. Small tries remain
    // writable until their lifecycle is explicitly closed, unless an actual
    // progress_end_date was persisted for this object.
    if (configuredEnd == null) return true;
    final localEnd = DateTime(
      configuredEnd.year,
      configuredEnd.month,
      configuredEnd.day,
    );
    return !localDate.isAfter(localEnd);
  }

  bool _isEligibleForAiJudgement(RecentSignalModel signal, String todayKey) {
    if (signal.localDateKey() != todayKey) return false;
    if (signal.sourceType == 'ai_predicted') return false;
    if (signal.content.trim().isEmpty) return false;
    return eligibilityService.isEligible(
      signal,
      SignalEligibilityStage.aiReason,
    );
  }

  RecentSignalModel _latestAiJudgementAnchor(
    List<RecentSignalModel> signals,
  ) {
    var latest = signals.first;
    for (final signal in signals.skip(1)) {
      final candidateTime = signal.createdAt;
      final latestTime = latest.createdAt;
      if (candidateTime != null &&
          (latestTime == null || candidateTime.isAfter(latestTime))) {
        latest = signal;
      }
    }
    return latest;
  }

  String _aiJudgementAnchorFingerprint(RecentSignalModel signal) {
    String rawPayload;
    try {
      rawPayload = jsonEncode(_canonicalJsonValue(signal.rawPayloadJson));
    } catch (_) {
      rawPayload = signal.rawPayloadJson.toString();
    }
    final sceneTags = signal.sceneTags.toList()..sort();
    final intentTags = signal.intentTags.toList()..sort();
    return [
      signal.sourceType,
      signal.content.trim(),
      signal.scene?.trim() ?? '',
      signal.friction?.trim() ?? '',
      signal.positiveSignal?.trim() ?? '',
      signal.energyLoad?.trim() ?? '',
      signal.energyState?.trim() ?? '',
      sceneTags.join('\u241f'),
      intentTags.join('\u241f'),
      rawPayload,
    ].join('\u241e');
  }

  dynamic _canonicalJsonValue(dynamic value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return <String, dynamic>{
        for (final key in keys) key: _canonicalJsonValue(value[key]),
      };
    }
    if (value is Iterable) {
      return value.map(_canonicalJsonValue).toList(growable: false);
    }
    return value;
  }

  List<String>? _buildAiJudgementCopy(
    RecentSignalModel anchorSignal,
    AppLanguage language, {
    int variationIndex = 0,
  }) {
    if (variationIndex < 0 || variationIndex > 3) return null;
    final cue = _detectAiJudgementCue(anchorSignal);
    if (cue == null) return null;

    final sample = _compactAiJudgementSample(anchorSignal.content);
    if (sample.isEmpty) return null;
    final cueLabel = _aiJudgementCueLabel(cue, language);
    final pattern = _aiJudgementPatternLabel(
      cueLabel,
      language,
      variationIndex,
    );
    final evidence = switch (language) {
      AppLanguage.simplifiedChinese => '这条预判只依据「$sample」。',
      AppLanguage.traditionalChinese => '這條預判只依據「$sample」。',
      AppLanguage.japanese => 'この予測は「$sample」だけを根拠にしています。',
      AppLanguage.english => 'This prediction is based only on “$sample”.',
    };
    final prediction = switch ((language, variationIndex)) {
      (AppLanguage.simplifiedChinese, 0) =>
        '从「$sample」看，今天值得确认的是：$cueLabel是否正在变得更明显。',
      (AppLanguage.simplifiedChinese, 1) =>
        '换个角度看「$sample」：这条 Signal 也许记录的是$cueLabel，可以继续留意。',
      (AppLanguage.simplifiedChinese, 2) =>
        '还可以确认：在「$sample」发生前后，$cueLabel有没有变化。',
      (AppLanguage.simplifiedChinese, _) =>
        '最后一个角度：如果「$sample」再次出现，可以看看$cueLabel是否也一起出现。',
      (AppLanguage.traditionalChinese, 0) =>
        '從「$sample」看，今天值得確認的是：$cueLabel是否正在變得更明顯。',
      (AppLanguage.traditionalChinese, 1) =>
        '換個角度看「$sample」：這條 Signal 也許記錄的是$cueLabel，可以繼續留意。',
      (AppLanguage.traditionalChinese, 2) =>
        '還可以確認：在「$sample」發生前後，$cueLabel有沒有變化。',
      (AppLanguage.traditionalChinese, _) =>
        '最後一個角度：如果「$sample」再次出現，可以看看$cueLabel是否也一起出現。',
      (AppLanguage.japanese, 0) =>
        '「$sample」から、今日は$cueLabelがはっきりしてきているかを確かめられそうです。',
      (AppLanguage.japanese, 1) =>
        '別の角度では、「$sample」は$cueLabelを記録したシグナルかもしれません。',
      (AppLanguage.japanese, 2) => '「$sample」の前後で、$cueLabelがどう変わったかも確かめられます。',
      (AppLanguage.japanese, _) =>
        '最後の角度として、「$sample」がまた起きたときに$cueLabelも一緒に現れるかを見られます。',
      (AppLanguage.english, 0) =>
        'From “$sample”, it may be worth checking whether $cueLabel is becoming more noticeable.',
      (AppLanguage.english, 1) =>
        'Another angle on “$sample” is that it may be a signal of $cueLabel.',
      (AppLanguage.english, 2) =>
        'You could also check how $cueLabel changed before and after “$sample”.',
      (AppLanguage.english, _) =>
        'One last angle: if “$sample” happens again, notice whether $cueLabel appears with it.',
    };

    return [
      prediction,
      evidence,
      pattern,
      'today_anchor_${cue.name}',
    ];
  }

  _AiJudgementCue? _detectAiJudgementCue(RecentSignalModel signal) {
    final focusDomain = (signal.rawPayloadJson['focus_domain_id'] ??
            signal.rawPayloadJson['category'])
        ?.toString()
        .trim()
        .toLowerCase();
    final text = [
      signal.content,
      signal.scene,
      signal.friction,
      signal.positiveSignal,
      signal.energyLoad,
      signal.energyState,
      ...signal.sceneTags,
      ...signal.intentTags,
    ].whereType<String>().join(' ').toLowerCase();

    final negatedInterest = _containsAny(text, const [
      '不喜欢',
      '不喜歡',
      '討厭',
      '讨厌',
      '嫌い',
      'dislike',
      "don't like",
      'do not like',
    ]);
    if (!negatedInterest &&
        (focusDomain == 'interests_hobbies' ||
            _containsAny(text, const [
              '喜欢',
              '喜歡',
              '兴趣',
              '興趣',
              '爱好',
              '愛好',
              '好奇',
              '音乐',
              '音樂',
              'rap',
              'hip hop',
              'hip-hop',
              '好き',
              '興味',
              '趣味',
              '音楽',
              'like ',
              'likes ',
              'enjoy',
              'interest',
              'curious',
              'hobby',
              'music',
            ]))) {
      return _AiJudgementCue.interest;
    }
    if (_containsAny(text, const [
      '切换',
      '切換',
      '中断',
      '中斷',
      '打断',
      '打斷',
      '来回换',
      '來回換',
      'switch',
      'interrupt',
      'context switching',
      '切り替',
      '中断',
      '割り込',
    ])) {
      return _AiJudgementCue.switching;
    }
    if (_containsAny(text, const [
      '边界',
      '邊界',
      '拒绝',
      '拒絕',
      '不敢说不',
      '不敢說不',
      '勉强答应',
      '勉強答應',
      'boundary',
      'say no',
      'people pleasing',
      '境界',
      '断れ',
      '無理に引き受け',
    ])) {
      return _AiJudgementCue.boundary;
    }
    if (_containsAny(text, const [
      '累',
      '疲惫',
      '疲憊',
      '疲劳',
      '疲勞',
      '忙不过来',
      '忙不過來',
      '压力',
      '壓力',
      '焦虑',
      '焦慮',
      '紧张',
      '緊張',
      '耗力',
      '耗能',
      '事情太多',
      '负担',
      '負擔',
      'tired',
      'exhausted',
      'fatigue',
      'busy',
      'stress',
      'overwhelm',
      'burden',
      'しんど',
      '疲れ',
      '忙し',
      'ストレス',
      'つら',
      '負担',
    ])) {
      return _AiJudgementCue.load;
    }
    if (_containsAny(text, const [
      '恢复',
      '恢復',
      '休息',
      '放松',
      '放鬆',
      '散步',
      '晒太阳',
      '曬太陽',
      '睡得好',
      '睡了一觉',
      '睡了一覺',
      'recovery',
      'recover',
      'rest',
      'relax',
      'walk',
      'nature',
      '回復',
      '休め',
      '休ん',
      '散歩',
      'リラックス',
    ])) {
      return _AiJudgementCue.recovery;
    }
    final hasStructuredEnergy = signal.sourceType == 'one_tap' ||
        signal.rawPayloadJson['energy_level'] != null ||
        (signal.energyState?.trim().isNotEmpty ?? false) ||
        (signal.energyLoad?.trim().isNotEmpty ?? false);
    if (hasStructuredEnergy ||
        _containsAny(text, const [
          '精力',
          '能量',
          '活力',
          '体力',
          '體力',
          'energy',
          'vitality',
          '元気',
          '活力',
          '体力',
        ])) {
      return _AiJudgementCue.energy;
    }
    if ((signal.positiveSignal?.trim().isNotEmpty ?? false) ||
        _containsAny(text, const [
          '开心',
          '開心',
          '高兴',
          '高興',
          '不错',
          '不錯',
          '顺利',
          '順利',
          '舒服',
          '平静',
          '平靜',
          '满足',
          '滿足',
          '快乐',
          '快樂',
          '轻松',
          '輕鬆',
          'happy',
          'good',
          'comfortable',
          'calm',
          'relieved',
          '嬉しい',
          '楽しい',
          '落ち着',
          '心地よ',
        ])) {
      return _AiJudgementCue.positive;
    }
    return null;
  }

  bool _containsAny(String text, List<String> needles) {
    return needles.any(text.contains);
  }

  String _aiJudgementCueLabel(
    _AiJudgementCue cue,
    AppLanguage language,
  ) {
    return switch ((language, cue)) {
      (AppLanguage.simplifiedChinese, _AiJudgementCue.interest) => '新出现的兴趣',
      (AppLanguage.simplifiedChinese, _AiJudgementCue.switching) =>
        '切换带来的注意力变化',
      (AppLanguage.simplifiedChinese, _AiJudgementCue.boundary) => '边界被触碰时的感受',
      (AppLanguage.simplifiedChinese, _AiJudgementCue.load) => '负担感',
      (AppLanguage.simplifiedChinese, _AiJudgementCue.recovery) => '恢复线索',
      (AppLanguage.simplifiedChinese, _AiJudgementCue.energy) => '精力变化',
      (AppLanguage.simplifiedChinese, _AiJudgementCue.positive) => '让状态变好的因素',
      (AppLanguage.traditionalChinese, _AiJudgementCue.interest) => '新出現的興趣',
      (AppLanguage.traditionalChinese, _AiJudgementCue.switching) =>
        '切換帶來的注意力變化',
      (AppLanguage.traditionalChinese, _AiJudgementCue.boundary) => '邊界被觸碰時的感受',
      (AppLanguage.traditionalChinese, _AiJudgementCue.load) => '負擔感',
      (AppLanguage.traditionalChinese, _AiJudgementCue.recovery) => '恢復線索',
      (AppLanguage.traditionalChinese, _AiJudgementCue.energy) => '精力變化',
      (AppLanguage.traditionalChinese, _AiJudgementCue.positive) => '讓狀態變好的因素',
      (AppLanguage.japanese, _AiJudgementCue.interest) => '芽生えた興味',
      (AppLanguage.japanese, _AiJudgementCue.switching) => '切り替えによる注意の変化',
      (AppLanguage.japanese, _AiJudgementCue.boundary) => '境界に触れられたときの感覚',
      (AppLanguage.japanese, _AiJudgementCue.load) => '負担感',
      (AppLanguage.japanese, _AiJudgementCue.recovery) => '回復の手がかり',
      (AppLanguage.japanese, _AiJudgementCue.energy) => 'エネルギーの変化',
      (AppLanguage.japanese, _AiJudgementCue.positive) => '状態をよくした要因',
      (AppLanguage.english, _AiJudgementCue.interest) => 'an emerging interest',
      (AppLanguage.english, _AiJudgementCue.switching) =>
        'the attention shift caused by switching',
      (AppLanguage.english, _AiJudgementCue.boundary) =>
        'how it felt when a boundary was touched',
      (AppLanguage.english, _AiJudgementCue.load) => 'the sense of load',
      (AppLanguage.english, _AiJudgementCue.recovery) => 'a recovery cue',
      (AppLanguage.english, _AiJudgementCue.energy) => 'the change in energy',
      (AppLanguage.english, _AiJudgementCue.positive) =>
        'what helped the moment feel better',
    };
  }

  String _aiJudgementPatternLabel(
    String cueLabel,
    AppLanguage language,
    int variationIndex,
  ) {
    if (variationIndex == 0) return cueLabel;
    return switch ((language, variationIndex)) {
      (AppLanguage.simplifiedChinese, 1) => '$cueLabel · 换个角度',
      (AppLanguage.simplifiedChinese, 2) => '$cueLabel · 前后变化',
      (AppLanguage.simplifiedChinese, _) => '$cueLabel · 再次出现',
      (AppLanguage.traditionalChinese, 1) => '$cueLabel · 換個角度',
      (AppLanguage.traditionalChinese, 2) => '$cueLabel · 前後變化',
      (AppLanguage.traditionalChinese, _) => '$cueLabel · 再次出現',
      (AppLanguage.japanese, 1) => '$cueLabel・別の角度',
      (AppLanguage.japanese, 2) => '$cueLabel・前後の変化',
      (AppLanguage.japanese, _) => '$cueLabel・再び現れるとき',
      (AppLanguage.english, 1) => '$cueLabel · another angle',
      (AppLanguage.english, 2) => '$cueLabel · before and after',
      (AppLanguage.english, _) => '$cueLabel · when it appears again',
    };
  }

  String _compactAiJudgementSample(String content) {
    final normalized = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.runes.length <= 72) return normalized;
    return '${String.fromCharCodes(normalized.runes.take(71))}…';
  }

  MicroActionModel _copyMicroAction(
    MicroActionModel action, {
    String? title,
    String? reason,
    String? actionType,
    String? difficulty,
    String? status,
    String? feedbackStatus,
  }) {
    return MicroActionModel(
      id: action.id,
      judgementId: action.judgementId,
      title: title ?? action.title,
      reason: reason ?? action.reason,
      actionType: actionType ?? action.actionType,
      difficulty: difficulty ?? action.difficulty,
      plannedDate: action.plannedDate,
      plannedTime: action.plannedTime,
      linkedScheduleSignalId: action.linkedScheduleSignalId,
      linkedGoalId: action.linkedGoalId,
      linkedLifeExperimentId: action.linkedLifeExperimentId,
      status: status ?? action.status,
      feedbackStatus: feedbackStatus ?? action.feedbackStatus,
      creationSource: action.creationSource,
      createdAt: action.createdAt,
      updatedAt: DateTime.now(),
    );
  }

  String _lighterMicroActionTitle(AppLanguage language) {
    return switch (language) {
      AppLanguage.simplifiedChinese => '先用 2 分钟补一句场景',
      AppLanguage.traditionalChinese => '先用 2 分鐘補一句情境',
      AppLanguage.japanese => 'まず2分だけ状況を一言足す',
      AppLanguage.english => 'Add one line of context for 2 minutes',
    };
  }

  String _confirmationNote(
    AppLanguage language, {
    required bool addedToTimeline,
  }) {
    if (addedToTimeline) {
      return switch (language) {
        AppLanguage.simplifiedChinese => '这条内容已从智能预判确认并加入时间线。',
        AppLanguage.traditionalChinese => '這條內容已從智能預判確認並加入時間線。',
        AppLanguage.japanese => '人工知能による予測から確認し、タイムラインに追加しました。',
        AppLanguage.english =>
          'Confirmed from an AI prediction and added to your timeline.',
      };
    }
    return switch (language) {
      AppLanguage.simplifiedChinese => '已确认这条智能预判，未加入时间线。',
      AppLanguage.traditionalChinese => '已確認這條智能預判，未加入時間線。',
      AppLanguage.japanese => '人工知能による予測を確認しました。タイムラインには追加していません。',
      AppLanguage.english =>
        'Confirmed this AI prediction without adding it to the timeline.',
    };
  }

  bool _aiJudgementSourcesChanged(
    AiJudgementModel judgement, {
    required List<RecentSignalModel> allSignals,
    required String todayKey,
  }) {
    final eligibleSignals = allSignals
        .where((signal) => _isEligibleForAiJudgement(signal, todayKey))
        .toList(growable: false);
    if (eligibleSignals.isEmpty) {
      return judgement.sourceSignalCardIds.isNotEmpty ||
          judgement.sourceScheduleSignalIds.isNotEmpty ||
          judgement.sourceGoalTaskInstanceIds.isNotEmpty;
    }
    final anchor = _latestAiJudgementAnchor(eligibleSignals);
    final anchorId = (anchor.signalCardId ?? anchor.id ?? '').trim();
    final signalIds = anchorId.isEmpty ? <String>{} : <String>{anchorId};
    final expectedId = _stableAiJudgementId(
      localPhase3PlusRepository?.localUserId ?? localUserId,
      todayKey,
      signalIds,
      sourceVersionFingerprint: _aiJudgementAnchorFingerprint(anchor),
    );
    return judgement.id != expectedId ||
        !judgement.suggestedLifeChainStage.startsWith('today_anchor_') ||
        !_sameIds(signalIds, judgement.sourceSignalCardIds) ||
        judgement.sourceScheduleSignalIds.isNotEmpty ||
        judgement.sourceGoalTaskInstanceIds.isNotEmpty;
  }

  bool _sameIds(Set<String> current, List<String> stored) {
    final storedSet = stored.where((id) => id.isNotEmpty).toSet();
    return current.length == storedSet.length && current.containsAll(storedSet);
  }

  String _stableAiJudgementId(
    String localUserId,
    String localDate,
    Iterable<String> sourceSignalCardIds, {
    required String sourceVersionFingerprint,
  }) {
    final user = localUserId.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
    final date = localDate.replaceAll('-', '');
    final sources = sourceSignalCardIds
        .where((id) => id.trim().isNotEmpty)
        .map((id) => id.trim())
        .toList(growable: false)
      ..sort();
    final fingerprint = _stableFnv64(
      '${sources.join('\u241f')}\u241e$sourceVersionFingerprint',
    );
    return 'aj_${user}_${date}_$fingerprint';
  }

  String _stableFnv64(String value) {
    var hash = BigInt.parse('cbf29ce484222325', radix: 16);
    final prime = BigInt.parse('100000001b3', radix: 16);
    final mask = (BigInt.one << 64) - BigInt.one;
    for (final byte in utf8.encode(value)) {
      hash = ((hash ^ BigInt.from(byte)) * prime) & mask;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  Future<RecentSignalModel?> getCaptureById(String captureId) {
    return localCaptureRepository.getCaptureById(captureId);
  }

  Future<LightDialogResponseModel> continueLightDialog({
    required RecentSignalModel signal,
    required List<LightDialogTurnModel> history,
    required String userMessage,
  }) async {
    final focusArea = await _readFocusArea();
    final responseStyle = await _readResponseStyle();
    return aiRepository.generateLightDialog(
      signal: signal,
      history: history,
      userMessage: userMessage,
      language: _languageCode(),
      focusArea: focusArea,
      responseStyle: responseStyle,
    );
  }

  Future<Map<String, dynamic>> submitCapture({
    required String content,
    String? tagHint,
    String sourceType = 'text',
    Map<String, dynamic> rawPayloadJson = const {},
  }) async {
    final normalizedRawPayloadJson = sourceType == 'time_use'
        ? _normalizeTimeUsePayload(rawPayloadJson)
        : rawPayloadJson;
    if (apiClient != null) {
      return _submitCaptureViaSignalCard(
        content: content,
        tagHint: tagHint,
        sourceType: sourceType,
        rawPayloadJson: normalizedRawPayloadJson,
      );
    }
    if (sourceType == 'time_use') {
      return _submitLocalTimeUseCapture(
        content: content,
        rawPayloadJson: normalizedRawPayloadJson,
      );
    }

    final inserted = await localCaptureRepository.insertCapture(
      content: content,
      inputMode: sourceType,
      tagHint: tagHint,
    );
    await analyticsRepository?.track(
      'entry_created',
      properties: {
        'content_length': content.trim().length,
        'has_tag_hint': tagHint != null && tagHint.trim().isNotEmpty,
      },
    );

    final focusArea = await _readFocusArea();
    final responseStyle = await _readResponseStyle();
    final recentAssistantTexts =
        await localCaptureRepository.listRecentAcknowledgements(limit: 10);

    late AiCaptureReplyResult aiReply;

    try {
      aiReply = await aiRepository.generateCaptureReply(
        content: content,
        recentAssistantTexts: recentAssistantTexts,
        language: _languageCode(),
        focusArea: focusArea,
        responseStyle: responseStyle,
      );
    } catch (_) {
      aiReply = AiCaptureReplyResult(
        acknowledgement: _defaultAcknowledgement(content),
        observation: _defaultSingleObservation(content),
        tryNext: _defaultSingleTryNext(content),
        emotion: _defaultEmotion(content),
        intensity: _defaultIntensity(content),
        sceneTags: _defaultSceneTags(content),
        intentTags: _defaultIntentTags(content),
        followup: null,
      );
    }

    if (inserted.id != null) {
      await localCaptureRepository.updateAiReply(
        captureId: inserted.id!,
        acknowledgement: aiReply.acknowledgement,
        observation: aiReply.observation,
        tryNext: aiReply.tryNext,
        emotion: aiReply.emotion,
        intensity: aiReply.intensity,
        sceneTags: aiReply.sceneTags,
        intentTags: aiReply.intentTags,
      );
    }

    final refreshedTodaySignals =
        await localCaptureRepository.listTodaySignals();

    await _regenerateTodaySummary(refreshedTodaySignals);
    cloudBackupSyncService?.markDataChanged();

    return {
      'acknowledgement': aiReply.acknowledgement,
      'followup': aiReply.followup,
      'updatedRecentSignals': refreshedTodaySignals,
      'localSignal': RecentSignalModel(
        id: inserted.id,
        content: inserted.content,
        createdAt: inserted.createdAt,
        acknowledgement: aiReply.acknowledgement,
        observation: aiReply.observation,
        tryNext: aiReply.tryNext,
        emotion: aiReply.emotion,
        intensity: aiReply.intensity,
        sceneTags: aiReply.sceneTags,
        intentTags: aiReply.intentTags,
      ),
    };
  }

  Future<Map<String, dynamic>> _submitLocalTimeUseCapture({
    required String content,
    required Map<String, dynamic> rawPayloadJson,
  }) async {
    await analyticsRepository?.track(
      'entry_created',
      properties: {
        'content_length': content.trim().length,
        'source_type': 'time_use',
        'has_structured_time': rawPayloadJson['start_at'] != null &&
            rawPayloadJson['end_at'] != null,
      },
    );
    final focusArea = await _readFocusArea();
    final responseStyle = await _readResponseStyle();
    final recentAssistantTexts =
        await localCaptureRepository.listRecentAcknowledgements(limit: 10);
    late AiCaptureReplyResult aiReply;
    try {
      aiReply = await aiRepository.generateCaptureReply(
        content: content,
        recentAssistantTexts: recentAssistantTexts,
        language: _languageCode(),
        focusArea: focusArea,
        responseStyle: responseStyle,
      );
    } catch (_) {
      aiReply = AiCaptureReplyResult(
        acknowledgement: _defaultAcknowledgement(content),
        observation: _defaultSingleObservation(content),
        tryNext: _defaultSingleTryNext(content),
        emotion: _defaultEmotion(content),
        intensity: _defaultIntensity(content),
        sceneTags: _defaultSceneTags(content),
        intentTags: _defaultIntentTags(content),
        followup: null,
      );
    }
    final category =
        (rawPayloadJson['focus_domain_id'] ?? rawPayloadJson['category'])
                ?.toString()
                .trim() ??
            '';
    final energyEffect =
        rawPayloadJson['energy_effect']?.toString().trim() ?? '';
    final inserted = await localCaptureRepository.insertConfirmedSignalCard(
      content: content,
      sourceType: 'time_use',
      language: _languageCode(),
      acknowledgement: aiReply.acknowledgement,
      observation: aiReply.observation,
      tryNext: aiReply.tryNext,
      scene: category.isEmpty ? null : category,
      energyLoad: energyEffect.isEmpty || energyEffect == 'unknown'
          ? null
          : energyEffect,
      sceneTags: {
        ...aiReply.sceneTags,
        if (category.isNotEmpty) category,
      }.toList(growable: false),
      intentTags: aiReply.intentTags,
      rawPayloadJson: rawPayloadJson,
      userConfirmation: 'unconfirmed',
      includedInSummary: true,
      includedInWeekly: true,
      includedInJourney: true,
    );
    final refreshedTodaySignals =
        await localCaptureRepository.listTodaySignals();
    await _regenerateTodaySummary(refreshedTodaySignals);
    cloudBackupSyncService?.markDataChanged();
    return {
      'acknowledgement': aiReply.acknowledgement,
      'followup': aiReply.followup,
      'updatedRecentSignals': refreshedTodaySignals,
      'localSignal': inserted,
    };
  }

  Map<String, dynamic> _normalizeTimeUsePayload(
    Map<String, dynamic> rawPayloadJson,
  ) {
    final normalized = <String, dynamic>{...rawPayloadJson};
    final rawFocusDomain = normalized['focus_domain_id']?.toString().trim();
    final rawCategory = normalized['category']?.toString().trim();
    final canonicalFocusDomain = FocusDomains.optionFor(rawFocusDomain)?.id ??
        FocusDomains.optionFor(rawCategory)?.id;
    if (canonicalFocusDomain != null) {
      normalized['focus_domain_id'] = canonicalFocusDomain;
      // Keep category during the schema transition so older timeline readers
      // render the same canonical value instead of maintaining a second
      // taxonomy.
      normalized['category'] = canonicalFocusDomain;
    } else {
      // focus_domain_id is a canonical field; keep unknown historical values
      // only under category instead of writing an invalid canonical id.
      normalized.remove('focus_domain_id');
      if ((normalized['category']?.toString().trim() ?? '').isEmpty) {
        normalized.remove('category');
      }
    }

    final recordStatus =
        normalized['record_status']?.toString().trim().toLowerCase() ?? '';
    final rawEnergyLevel = normalized['energy_level'];
    final energyLevel = switch (rawEnergyLevel) {
      final int value => value,
      final num value when value == value.roundToDouble() => value.toInt(),
      _ => int.tryParse(rawEnergyLevel?.toString() ?? ''),
    };
    if (recordStatus == 'planned' ||
        energyLevel == null ||
        energyLevel < 0 ||
        energyLevel > 2) {
      normalized.remove('energy_level');
    } else {
      normalized['energy_level'] = energyLevel;
    }

    final legacyEnergyEffect =
        normalized['energy_effect']?.toString().trim().toLowerCase() ?? '';
    if (legacyEnergyEffect.isEmpty ||
        legacyEnergyEffect == 'unknown' ||
        normalized.containsKey('energy_level')) {
      normalized.remove('energy_effect');
    } else {
      // Non-empty historical values remain readable while new callers use
      // energy_level exclusively.
      normalized['energy_effect'] = legacyEnergyEffect;
    }
    return normalized;
  }

  Future<void> retryPendingDrafts() async {
    final client = apiClient;
    if (client == null) return;

    final drafts = await localCaptureRepository.listPendingDraftRows();
    for (final draft in drafts) {
      final draftId = draft['draft_id'] as String?;
      final clientId = (draft['client_id'] as String?) ?? draftId;
      final rawText = draft['raw_text'] as String?;
      final rawPayloadJson = switch (draft['raw_payload_json']) {
        final Map raw => raw.map(
            (key, value) => MapEntry(key.toString(), value),
          ),
        _ => const <String, dynamic>{},
      };
      if (draftId == null || rawText == null || rawText.trim().isEmpty) {
        continue;
      }
      try {
        final response = await client.postJson(
          '/api/v1/captures',
          {
            'content': rawText,
            'input_mode': draft['source_type'] as String? ?? 'text',
            'tag_hint': draft['tag_hint'] as String?,
            'language': draft['language'] as String? ?? _languageCode(),
            'timezone': draft['timezone'] as String? ?? _timezoneName(),
            'client_id': clientId,
            if (rawPayloadJson.isNotEmpty) 'raw_payload_json': rawPayloadJson,
          },
        );
        final signals = _parseRecentSignals(response);
        final remoteSignalId =
            signals.isEmpty ? null : signals.first.signalCardId;
        await localCaptureRepository.upsertRemoteSignalCards(signals);
        await localCaptureRepository.markDraftSynced(
          draftId: draftId,
          remoteSignalCardId: remoteSignalId,
        );
        cloudBackupSyncService?.markDataChanged();
      } catch (e) {
        await localCaptureRepository.markDraftFailed(
          draftId: draftId,
          error: e.toString(),
        );
      }
    }
  }

  Future<void> confirmSignalCard({
    required String signalCardId,
    required String userConfirmation,
    Map<String, dynamic> userCorrectionJson = const {},
  }) async {
    await localCaptureRepository.updateSignalCardConfirmation(
      signalCardId: signalCardId,
      userConfirmation: userConfirmation,
      userCorrectionJson: userCorrectionJson,
    );
    cloudBackupSyncService?.markDataChanged();

    final client = apiClient;
    if (client == null || signalCardId.startsWith('draft_')) return;

    try {
      await client.patchJson(
        '/api/v1/captures/signal-cards/$signalCardId/confirmation',
        {
          'user_confirmation': userConfirmation,
          'user_correction_json': userCorrectionJson,
        },
      );
    } catch (_) {
      // 确认动作先落本地；下一轮同步基础版不阻塞用户操作。
    }
  }

  Future<void> deleteSignalCard({
    required String signalCardId,
    String reason = 'user_deleted',
  }) async {
    final client = apiClient;
    if (client != null && !signalCardId.startsWith('draft_')) {
      try {
        await client.deleteJson(
          '/api/v1/captures/signal-cards/$signalCardId',
          body: {'reason': reason},
        );
      } catch (_) {
        // 删除先落本地；远端失败不会阻塞用户移除这条 SignalCard。
      }
    }
    await localCaptureRepository.deleteSignalCard(signalCardId, reason: reason);
    cloudBackupSyncService?.markDataChanged();
  }

  Future<void> restoreSignalCard({
    required String signalCardId,
  }) async {
    final client = apiClient;
    if (client == null || signalCardId.startsWith('draft_')) return;
    await client.postJson(
      '/api/v1/captures/signal-cards/$signalCardId/restore',
      const <String, dynamic>{},
    );
    final remoteSignals = await _fetchRemoteSignalCards();
    await localCaptureRepository.upsertRemoteSignalCards(
      remoteSignals,
      restoreTombstoned: true,
    );
    cloudBackupSyncService?.markDataChanged();
  }

  Future<Map<String, dynamic>> _submitCaptureViaSignalCard({
    required String content,
    String? tagHint,
    String sourceType = 'text',
    Map<String, dynamic> rawPayloadJson = const {},
  }) async {
    final localDraft = await localCaptureRepository.insertLocalDraftSignal(
      content: content,
      sourceType: sourceType,
      tagHint: tagHint,
      language: _languageCode(),
      timezone: _timezoneName(),
      rawPayloadJson: rawPayloadJson,
    );
    await analyticsRepository?.track(
      'entry_created',
      properties: {
        'content_length': content.trim().length,
        'has_tag_hint': tagHint != null && tagHint.trim().isNotEmpty,
        'signal_card_source': 'v3b',
      },
    );

    try {
      final response = await apiClient!.postJson(
        '/api/v1/captures',
        {
          'content': content,
          'input_mode': sourceType,
          'tag_hint': tagHint,
          'language': _languageCode(),
          'timezone': _timezoneName(),
          'client_id': localDraft.clientId ?? localDraft.id,
          if (rawPayloadJson.isNotEmpty) 'raw_payload_json': rawPayloadJson,
        },
      );
      final signals = _parseRecentSignals(response);
      await localCaptureRepository.upsertRemoteSignalCards(signals);
      await localCaptureRepository.markDraftSynced(
        draftId: localDraft.signalCardId ?? localDraft.id ?? '',
        remoteSignalCardId: signals.isEmpty ? null : signals.first.signalCardId,
      );
    } catch (e) {
      await localCaptureRepository.markDraftFailed(
        draftId: localDraft.signalCardId ?? localDraft.id ?? '',
        error: e.toString(),
      );
    }

    final allSignals = await localCaptureRepository.listSignalCards(limit: 200);
    final todayKey = _dateKey(DateTime.now());
    final todaySignals = allSignals
        .where((signal) => signal.localDateKey() == todayKey)
        .toList();
    await _regenerateTodaySummary(todaySignals);
    final latestSignals =
        await localCaptureRepository.listSignalCards(limit: 200);
    cloudBackupSyncService?.markDataChanged();

    return {
      'acknowledgement': latestSignals
          .firstWhere(
            (signal) => signal.content == content,
            orElse: () => localDraft,
          )
          .acknowledgement,
      'followup': null,
      'updatedRecentSignals': latestSignals,
      'localSignal': localDraft,
    };
  }

  Future<RecentSignalModel> saveLocalDraftCapture({
    required String content,
    String sourceType = 'text',
    String? tagHint,
    Map<String, dynamic> rawPayloadJson = const {},
  }) async {
    final normalizedRawPayloadJson = sourceType == 'time_use'
        ? _normalizeTimeUsePayload(rawPayloadJson)
        : rawPayloadJson;
    final draft = await localCaptureRepository.insertLocalDraftSignal(
      content: content,
      sourceType: sourceType,
      tagHint: tagHint,
      language: _languageCode(),
      timezone: _timezoneName(),
      rawPayloadJson: normalizedRawPayloadJson,
    );
    cloudBackupSyncService?.markDataChanged();
    await analyticsRepository?.track(
      'entry_draft_saved',
      properties: {
        'content_length': content.trim().length,
        'source_type': sourceType,
      },
    );
    return draft;
  }

  Future<List<RecentSignalModel>> _fetchRemoteSignalCards() async {
    final response = await apiClient!.getJson('/api/v1/captures/recent');
    return _parseRecentSignals(response);
  }

  List<RecentSignalModel> _parseRecentSignals(Map<String, dynamic> response) {
    final data = (response['data'] as Map<String, dynamic>?) ?? response;
    final raw = (data['recent_signals'] as List?) ??
        ((data['recentSignals'] as List?) ?? const []);
    return raw
        .whereType<Map>()
        .map((e) => RecentSignalModel.fromJson(
              e.map((key, value) => MapEntry(key.toString(), value)),
            ))
        .toList();
  }

  Future<void> submitFollowup({
    required String followupId,
    required String answerValue,
  }) async {
    // Phase 1 先不做后续问题回写；保留接口，避免页面层大改。
  }

  Future<void> _regenerateTodaySummary(
      List<RecentSignalModel> todaySignals) async {
    final focusArea = await _readFocusArea();
    final responseStyle = await _readResponseStyle();
    final liveTodaySignals =
        TodaySignalScope.liveOnly(todaySignals).toList(growable: false);
    final summarySignals = _summaryEligibleSignals(liveTodaySignals);

    String observationText;
    String suggestionText;

    if (liveTodaySignals.isEmpty) {
      observationText = _defaultObservation(const []);
      suggestionText = _defaultSuggestion(const []);
    } else if (summarySignals.isEmpty) {
      observationText = _deferredSummaryObservation(liveTodaySignals);
      suggestionText = _deferredSummarySuggestion(liveTodaySignals);
    } else {
      try {
        final result = await aiRepository.generateTodaySummary(
          date: DateTime.now(),
          entries: summarySignals,
          focusArea: focusArea,
          responseStyle: responseStyle,
        );
        observationText = result.observation;
        suggestionText = result.suggestion;
      } catch (error) {
        await _recordPipelineFailure(
          pipelineType: 'assist_generation',
          sourceType: 'daily_snapshot',
          sourceId: _dateKey(DateTime.now()),
          inputHash: localDailySnapshotRepository.buildSourceHash(
            liveTodaySignals,
            language: aiRepository.languageLoader(),
          ),
          error: error,
        );
        observationText = _defaultObservation(summarySignals);
        suggestionText = _defaultSuggestion(summarySignals);
      }
    }

    final sourceHash = localDailySnapshotRepository.buildSourceHash(
      liveTodaySignals,
      language: aiRepository.languageLoader(),
    );

    await localDailySnapshotRepository.upsert(
      date: DateTime.now(),
      entryCount: liveTodaySignals.length,
      observationText: observationText,
      suggestionText: suggestionText,
      sourceHash: sourceHash,
    );

    await localCaptureRepository.updateSignalCardInclusion(
      signalCardIds: summarySignals
          .map((signal) => signal.signalCardId ?? signal.id ?? '')
          .where((id) => id.trim().isNotEmpty),
      includedInSummary: true,
    );
  }

  Future<void> _recordPipelineFailure({
    required String pipelineType,
    required String sourceType,
    required String sourceId,
    required String inputHash,
    required Object error,
  }) async {
    final repository = LocalPipelineRunRepository(
      localDailySnapshotRepository.localDatabase,
    );
    final runId = await repository.start(
      pipelineType: pipelineType,
      sourceType: sourceType,
      sourceId: sourceId,
      inputHash: inputHash,
    );
    await repository.fail(
      runId: runId,
      errorCode: error.runtimeType.toString(),
      errorMessage: error.toString(),
    );
  }

  List<RecentSignalModel> _summaryEligibleSignals(
      List<RecentSignalModel> signals) {
    return eligibilityService.filter(
      signals,
      SignalEligibilityStage.daily,
    );
  }

  Future<String?> _readResponseStyle() async {
    if (responseStyleLoader != null) {
      return responseStyleLoader!();
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('response_style_preference') ?? 'gentle';
    } catch (_) {
      return 'gentle';
    }
  }

  Future<String?> _readFocusArea() async {
    if (focusAreaLoader != null) {
      return focusAreaLoader!();
    }

    final prefs = await SharedPreferences.getInstance();
    final focusDomainIds = FocusDomains.normalizeIds(
      prefs.getStringList(FocusDomains.productPreferenceKey) ??
          prefs.getStringList(FocusDomains.preferenceKey) ??
          const [],
    );
    if (focusDomainIds.isNotEmpty) {
      return focusDomainIds.join(',');
    }
    return prefs.getString('repeat_area_preference') ??
        prefs.getString('selected_repeat_area');
  }

  String _languageCode([AppLanguage? language]) {
    if (language != null) {
      return switch (language) {
        AppLanguage.simplifiedChinese => 'zh-Hans',
        AppLanguage.traditionalChinese => 'zh-Hant',
        AppLanguage.japanese => 'ja',
        AppLanguage.english => 'en',
      };
    }
    final locale = ui.PlatformDispatcher.instance.locale;
    final languageCode = locale.languageCode.toLowerCase();
    final scriptCode = locale.scriptCode?.toLowerCase();
    final countryCode = locale.countryCode?.toUpperCase();

    if (languageCode == 'ja') return 'ja';
    if (languageCode == 'zh') {
      final isTraditional = scriptCode == 'hant' ||
          countryCode == 'TW' ||
          countryCode == 'HK' ||
          countryCode == 'MO';
      return isTraditional ? 'zh-Hant' : 'zh-Hans';
    }
    return 'en';
  }

  AppLanguage _deviceAppLanguage() {
    return switch (_languageCode()) {
      'zh-Hans' => AppLanguage.simplifiedChinese,
      'zh-Hant' => AppLanguage.traditionalChinese,
      'ja' => AppLanguage.japanese,
      _ => AppLanguage.english,
    };
  }

  String _timezoneName() {
    return DateTime.now().timeZoneName;
  }

  String _dateKey(DateTime date) {
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  String _defaultAcknowledgement(
    String content, {
    AppLanguage? language,
  }) {
    final trimmed = content.trim();
    final languageCode =
        language == null ? _languageCode() : _languageCode(language);
    if (_isImmediateSafetyRisk(content)) {
      return switch (languageCode) {
        'ja' =>
          '今の言葉をとても心配しています。今すぐ自分や誰かを傷つける可能性があるなら、危険な物から離れ、地域の緊急窓口か、すぐそばに来られる信頼できる人へ連絡してください。',
        'en' =>
          'I am very concerned about what you just said. If you might hurt yourself or someone else right now, move away from anything dangerous and contact local emergency services or a trusted person who can be with you now.',
        'zh-Hant' =>
          '我很在意你剛才這句話。若你現在可能馬上傷害自己或他人，請先離開危險物品，並聯絡當地緊急服務或一位能立刻到你身邊的可信任的人。',
        _ => '我很在意你刚才这句话。若你现在可能马上伤害自己或他人，请先离开危险物品，并联系当地紧急服务或一位能立刻到你身边的可信任的人。',
      };
    }
    if (trimmed.isEmpty) {
      return switch (languageCode) {
        'ja' => '書いてくれたことを、そのままここに残します。',
        'en' => 'I am keeping what you wrote here as it is.',
        'zh-Hant' => '你寫下的這件事已經留在這裡了。',
        _ => '你写下的这件事已经留在这里了。',
      };
    }

    return l1AttunedAcknowledgement(
      content: content,
      language: languageCode,
    );
  }

  bool _isImmediateSafetyRisk(String content) {
    final normalized = content.trim().toLowerCase();
    return const [
      '想自杀',
      '要自杀',
      '不想活了',
      '结束生命',
      '傷害自己',
      '自殺したい',
      '今すぐ死にたい',
      'kill myself',
      'suicide now',
      'end my life',
      'hurt myself',
      'hurt someone',
    ].any(normalized.contains);
  }

  String _defaultSingleObservation(String content) {
    final emotion = _defaultEmotion(content);
    final sceneTags = _defaultSceneTags(content);

    if (emotion == 'positive') {
      if (sceneTags.contains('achievement')) {
        return _copy(
          en: 'What stands out today is how a real sense of progress lifted you.',
          zhHans: '今天比较值得记住的，是你会被“确实有推进”的感觉明显提起来。',
          zhHant: '今天比較值得記住的，是「確實有推進」的感覺明顯讓你振作起來。',
          ja: '今日印象に残るのは、「確かに進んだ」という感覚が気持ちを持ち上げたことです。',
        );
      }
      return _copy(
        en: 'A clearer Signal today is that small, concrete good moments can restore you.',
        zhHans: '今天更清楚的 Signal 是：一些具体的小好事，确实能给你补回状态。',
        zhHant: '今天更清楚的 Signal 是：一些具體的小好事，確實能讓你恢復一些狀態。',
        ja: '今日よりはっきりした Signal は、具体的な小さな良い出来事が回復につながることです。',
      );
    }
    if (emotion == 'mixed') {
      return _copy(
        en: 'The tension matters here: something drained you, while something concrete also held you.',
        zhHans: '这条里最值得记的是那种拉扯感：你会被消耗，也会被一些具体的东西重新接住。',
        zhHant: '這裡最值得記下的是那種拉扯感：你會被消耗，也會被一些具體的事物重新接住。',
        ja: 'ここで残しておきたいのは揺れです。消耗する一方で、具体的な何かにも支えられています。',
      );
    }
    if (emotion == 'negative') {
      if (sceneTags.contains('work')) {
        return _copy(
          en: 'What stands out is not the emotion alone, but repeated interruptions, changes, or loss of control at work.',
          zhHans: '今天更明显的不是情绪本身，而是工作里的打断、改动或失控感在反复磨你。',
          zhHant: '今天更明顯的不是情緒本身，而是工作中的打斷、變動或失控感反覆消耗著你。',
          ja: '目立つのは感情そのものより、仕事での中断や変更、思いどおりにならない感覚の積み重なりです。',
        );
      }
      return _copy(
        en: 'What stands out is not just feeling upset, but a specific situation repeatedly draining you.',
        zhHans: '今天更明显的不是一句“烦”，而是某个具体场景正在稳定地消耗你。',
        zhHant: '今天更明顯的不只是一句「煩」，而是某個具體情境正持續消耗著你。',
        ja: '目立つのは単なる「つらさ」ではなく、特定の場面が継続して消耗につながっていることです。',
      );
    }
    return _copy(
      en: 'This reads more like a Signal about your current state than a strong emotion.',
      zhHans: '这更像是你留下的一条状态 Signal，而不是一股很强的情绪。',
      zhHant: '這更像是你留下的一條狀態 Signal，而不是一股很強烈的情緒。',
      ja: 'これは強い感情というより、今の状態を示す Signal に見えます。',
    );
  }

  String _defaultSingleTryNext(String content) {
    final emotion = _defaultEmotion(content);
    final sceneTags = _defaultSceneTags(content);

    if (emotion == 'positive') {
      if (sceneTags.contains('achievement')) {
        return _copy(
            en: 'Note what created that sense of progress; it may be reusable.',
            zhHans: '先记住这一下具体是因为什么推进感出现的，之后很容易复用。',
            zhHant: '先記下是什麼帶來了這份推進感，之後會比較容易再次運用。',
            ja: '何が前進感につながったのかだけ残しておくと、また活かしやすくなります。');
      }
      return _copy(
          en: 'Just note the specific thing that felt good; it can be brief.',
          zhHans: '先把让你感觉不错的那个具体点记下来，不用写多。',
          zhHant: '先把讓你感覺不錯的具體一點記下來，不用寫很多。',
          ja: '良い感じにつながった具体的な一点だけ、短く残しておきましょう。');
    }
    if (emotion == 'mixed') {
      return _copy(
          en: 'No need to sum up the whole day; just note what helped you recover a little.',
          zhHans: '今天先别急着总结整天，只记住是什么让你后面稍微缓回来一点。',
          zhHant: '今天先不用急著總結整天，只要記下後來是什麼讓你稍微緩回來一點。',
          ja: '一日全体をまとめなくて大丈夫です。少し戻れたきっかけだけ残しておきましょう。');
    }
    if (emotion == 'negative') {
      if (sceneTags.contains('work')) {
        return _copy(
            en: 'If it happens again, one line about the work setting will already be useful.',
            zhHans: '下次再出现时，只补一句它发生在什么工作场景里，就已经很有用了。',
            zhHant: '下次再出現時，只要補一句它發生在哪個工作情境，就已經很有幫助。',
            ja: '次に起きたら、どんな仕事の場面だったかを一言足すだけでも十分役立ちます。');
      }
      return _copy(
          en: 'For now, note the moment that felt most stuck; the rest can wait.',
          zhHans: '先把最卡你的那个瞬间记下来，其他先不用整理。',
          zhHant: '先把最卡住你的那個瞬間記下來，其他暫時不用整理。',
          ja: 'まず一番引っかかった瞬間だけ残し、ほかはまだ整理しなくて大丈夫です。');
    }
    return _copy(
        en: 'Leave this Signal here for now and see whether it returns.',
        zhHans: '先把这条 Signal 放着，看看之后它会不会再回来。',
        zhHant: '先把這條 Signal 留在這裡，看看之後是否會再次出現。',
        ja: 'この Signal はいったんここに置いて、また現れるか見てみましょう。');
  }

  String _defaultObservation(List<RecentSignalModel> entries) {
    if (entries.isEmpty) {
      return _copy(
          en: 'Nothing recorded yet today. Start with one small thing that really happened.',
          zhHans: '今天还没有记录，先留下一件真实发生的小事就好。',
          zhHant: '今天還沒有記錄，先留下一件真實發生的小事就好。',
          ja: '今日はまだ記録がありません。実際にあった小さなことを一つ残すだけで十分です。');
    }
    if (entries.length == 1) {
      return _copy(
          en: 'You recorded 1 Signal today and began keeping what actually happened.',
          zhHans: '今天记录了 1 条 Signal。你已经开始把真实发生的事留了下来。',
          zhHant: '今天記錄了 1 條 Signal。你已經開始把真實發生的事留下來。',
          ja: '今日は Signal を1件記録し、実際に起きたことを残し始めました。');
    }

    final mixedCount = entries.where((e) => e.emotion == 'mixed').length;
    final negativeCount = entries.where((e) => e.emotion == 'negative').length;
    final positiveCount = entries.where((e) => e.emotion == 'positive').length;

    if (mixedCount > 0) {
      return _copy(
          en: 'You recorded ${entries.length} Signals today; they show movement in more than one direction.',
          zhHans: '今天记录了 ${entries.length} 条 Signal，几条线索不是单向变化，而是在来回拉扯。',
          zhHant: '今天記錄了 ${entries.length} 條 Signal，幾條線索不是單向變化，而是在來回拉扯。',
          ja: '今日は Signal を${entries.length}件記録しました。変化は一方向ではなく、揺れが見えています。');
    }
    if (negativeCount >= positiveCount && negativeCount > 0) {
      return _copy(
          en: 'You recorded ${entries.length} Signals today; some situations repeatedly drained you.',
          zhHans: '今天记录了 ${entries.length} 条 Signal，更明显的是某些场景在反复消耗你。',
          zhHant: '今天記錄了 ${entries.length} 條 Signal，更明顯的是某些情境反覆消耗著你。',
          ja: '今日は Signal を${entries.length}件記録しました。いくつかの場面で消耗が繰り返されています。');
    }
    if (positiveCount > 0) {
      return _copy(
          en: 'You recorded ${entries.length} Signals today; some concrete restorative moments are emerging.',
          zhHans: '今天记录了 ${entries.length} 条 Signal，里面已经开始出现一些能把你拉回来的具体片段。',
          zhHant: '今天記錄了 ${entries.length} 條 Signal，其中已開始出現一些能讓你恢復的具體片段。',
          ja: '今日は Signal を${entries.length}件記録しました。回復につながる具体的な場面も見え始めています。');
    }
    return _copy(
        en: 'You recorded ${entries.length} Signals today. The day is starting to take shape.',
        zhHans: '今天记录了 ${entries.length} 条 Signal。今天的线索已经开始慢慢聚起来了。',
        zhHant: '今天記錄了 ${entries.length} 條 Signal。今天的線索已經開始慢慢聚集。',
        ja: '今日は Signal を${entries.length}件記録しました。今日の輪郭が少しずつ見え始めています。');
  }

  String _defaultSuggestion(List<RecentSignalModel> entries) {
    if (entries.isEmpty) {
      return _copy(
          en: 'Start by recording one small thing that made you pause today.',
          zhHans: '今天先记下一件让你停顿了一下的小事就好。',
          zhHant: '今天先記下一件讓你停頓了一下的小事就好。',
          ja: '今日は、少し立ち止まった出来事を一つ記録するだけで十分です。');
    }
    if (entries.length == 1) {
      return _copy(
          en: 'If something similar happens again today, add one more Signal.',
          zhHans: '如果同类事情今天再出现一次，再补记一条 Signal 就可以。',
          zhHant: '如果同類事情今天再次出現，再補記一條 Signal 就可以。',
          ja: '今日また似たことが起きたら、Signal をもう1件追加するだけで十分です。');
    }

    final workHeavy = entries.where((e) => e.sceneTags.contains('work')).length;
    final mixedCount = entries.where((e) => e.emotion == 'mixed').length;

    if (mixedCount > 0) {
      return _copy(
          en: 'Notice which situations lower your energy and which small things bring you back.',
          zhHans: '今天先留意：哪些场景会把你拉低，哪些小事又会把你拉回来。',
          zhHant: '今天先留意：哪些情境會讓你往下掉，哪些小事又會讓你恢復。',
          ja: '今日は、どんな場面で消耗し、どんな小さなことで戻れるかを見てみましょう。');
    }
    if (workHeavy > 0) {
      return _copy(
          en: 'When a similar work situation returns, add one line about where it happened.',
          zhHans: '下次再出现同类工作场景时，用一句话补记它发生在什么地方。',
          zhHant: '下次再出現同類工作情境時，用一句話補記它發生在哪裡。',
          ja: '同じような仕事の場面がまた起きたら、どこで起きたかを一言残してみましょう。');
    }
    return _copy(
        en: 'Notice whether anything today has happened in this way before.',
        zhHans: '接下来先留意：今天有没有哪类事情已经不是第一次这样发生。',
        zhHant: '接下來先留意：今天是否有哪類事情已經不是第一次這樣發生。',
        ja: '今日の出来事の中に、同じ形で以前にも起きたものがないか見てみましょう。');
  }

  String _deferredSummaryObservation(List<RecentSignalModel> entries) {
    if (entries.any((signal) => signal.isLocalDraft || signal.syncFailed)) {
      return _copy(
          en: 'Your original entry is saved. It can be organized after syncing finishes.',
          zhHans: '原文已经保存，等同步完成后再整理也来得及。',
          zhHant: '原文已經儲存，等同步完成後再整理也來得及。',
          ja: '元の記録は保存されています。同期が完了してから整理しても間に合います。');
    }
    if (entries.any((signal) => signal.isLegacy)) {
      return _copy(
          en: 'The earlier entry is back on the timeline; there is no need to reassess it now.',
          zhHans: '旧记录已经放回时间线，这里先不急着重新判断它。',
          zhHant: '舊記錄已經放回時間線，現在不用急著重新判斷。',
          ja: '以前の記録はタイムラインに戻りました。今すぐ判断し直す必要はありません。');
    }
    return _copy(
        en: 'The entry is saved. Organize it when the Signals become clearer.',
        zhHans: '记录已经留下，等 Signal 更清楚一点再整理。',
        zhHant: '記錄已經留下，等 Signal 更清楚一點再整理。',
        ja: '記録は残っています。Signal がもう少し明確になってから整理しましょう。');
  }

  String _deferredSummarySuggestion(List<RecentSignalModel> entries) {
    if (entries.any((signal) => signal.isLocalDraft || signal.syncFailed)) {
      return _copy(
          en: 'No need to enter it again; this record can stay with today.',
          zhHans: '先不用重复输入，这条记录可以先放在今天。',
          zhHant: '不用重複輸入，這條記錄可以先留在今天。',
          ja: '入力し直す必要はありません。この記録は今日のままで大丈夫です。');
    }
    return _copy(
        en: 'Let this record stay here; it does not need an immediate conclusion.',
        zhHans: '先让这条记录待在这里，不需要马上给它下结论。',
        zhHant: '先讓這條記錄留在這裡，不需要立刻下結論。',
        ja: 'この記録はいったんここに置き、すぐに結論を出さなくて大丈夫です。');
  }

  String _copy({
    required String en,
    required String zhHans,
    required String zhHant,
    required String ja,
  }) =>
      RuntimeLocaleText.tr(
        language: aiRepository.languageLoader(),
        en: en,
        zhHans: zhHans,
        zhHant: zhHant,
        ja: ja,
      );

  String _defaultEmotion(String content) {
    final text = content.toLowerCase();

    final positiveKeywords = [
      '开心',
      '高兴',
      '喜欢',
      '顺利',
      '放松',
      '舒服',
      '满足',
      '期待',
      '有成就感',
      '轻松',
      '好吃',
      '快乐',
      '愉快',
      '安心',
      '踏实',
      '嬉しい',
      '楽しい',
      'よかった',
      '満足',
      '安心',
      'happy',
      'glad',
      'good',
      'great',
      'relieved',
      'nice',
    ];
    final negativeKeywords = [
      '烦',
      '累',
      '崩',
      '难受',
      '焦虑',
      '生气',
      '压力',
      '不想',
      '麻烦',
      '受不了',
      '被打断',
      '烦躁',
      '委屈',
      '失控',
      '糟糕',
      '痛苦',
      '压抑',
      'しんどい',
      'つらい',
      '疲れた',
      'イライラ',
      '不安',
      '最悪',
      'annoyed',
      'tired',
      'upset',
      'angry',
      'anxious',
      'stressed',
      'frustrated',
    ];
    final mixedMarkers = [
      '但是',
      '但',
      '不过',
      '后来',
      '虽然',
      '又',
      '缓回来',
      '好了一点',
      'けど',
      'でも',
      'そのあと',
      'but',
      'however',
      'though',
      'later',
    ];

    final hasPositive = positiveKeywords.any(text.contains);
    final hasNegative = negativeKeywords.any(text.contains);
    final hasMixedMarker = mixedMarkers.any(text.contains);

    if ((hasPositive && hasNegative) ||
        (hasMixedMarker && (hasPositive || hasNegative))) {
      return 'mixed';
    }
    if (hasNegative) return 'negative';
    if (hasPositive) return 'positive';
    return 'neutral';
  }

  String _defaultIntensity(String content) {
    final text = content.toLowerCase();

    final strongMarkers = [
      '一直',
      '总是',
      '反复',
      '受不了',
      '崩了',
      '特别',
      '非常',
      '真的',
      '很烦',
      '很累',
      'ずっと',
      'かなり',
      '本当に',
      'めちゃくちゃ',
      'very',
      'really',
      'extremely',
    ];
    final mediumMarkers = [
      '有点',
      '有一些',
      '有一点',
      '有些',
      '稍微',
      'ちょっと',
      '少し',
      'a bit',
      'kind of',
      'somewhat',
    ];

    if (strongMarkers.any(text.contains) ||
        content.contains('!') ||
        content.contains('！')) {
      return 'high';
    }
    if (mediumMarkers.any(text.contains) ||
        _defaultEmotion(content) != 'neutral') {
      return 'medium';
    }
    return 'low';
  }

  List<String> _defaultSceneTags(String content) {
    final text = content.toLowerCase();
    final scenes = <String>[];

    bool hit(List<String> keywords) => keywords.any(text.contains);

    if (hit([
      '上班',
      '开会',
      '同事',
      '老板',
      '需求',
      '任务',
      '公司',
      '工作',
      '邮件',
      '会议',
      '職場',
      '仕事',
      '会議',
      'task',
      'work',
      'meeting',
      'manager'
    ])) {
      scenes.add('work');
    }
    if (hit(
        ['通勤', '地铁', '电车', '路上', '回家路上', '出门', '満員電車', 'commute', 'train'])) {
      scenes.add('commute');
    }
    if (hit([
      '朋友',
      '家人',
      '恋人',
      '关系',
      '聊天',
      '人間関係',
      'family',
      'friend',
      'partner'
    ])) {
      scenes.add('relationship');
    }
    if (hit([
      '头疼',
      '困',
      '睡',
      '累',
      '身体',
      '胃',
      '不舒服',
      '健康',
      '体調',
      '眠い',
      'body',
      'health'
    ])) {
      scenes.add('body');
    }
    if (hit([
      '花钱',
      '工资',
      '金钱',
      '消费',
      '买',
      '预算',
      'お金',
      '支出',
      'money',
      'budget',
      'spent'
    ])) {
      scenes.add('money');
    }
    if (hit(
        ['休息', '放松', '睡觉', '午休', '恢复', '发呆', '散步', '休憩', 'rest', 'relax'])) {
      scenes.add('rest');
    }
    if (hit([
      '完成',
      '做完',
      '推进',
      '成果',
      '达成',
      '有进展',
      '進んだ',
      '達成',
      'finished',
      'done'
    ])) {
      scenes.add('achievement');
    }
    if (hit(['怀疑自己', '自我否定', '不够好', '没做好', '担心自己', '自信がない', 'self doubt'])) {
      scenes.add('self_doubt');
    }
    if (hit([
      '被打断',
      '重复',
      '麻烦',
      '卡住',
      '拖延',
      '琐事',
      '不顺',
      'interrupted',
      'blocked',
      'friction'
    ])) {
      scenes.add('daily_friction');
    }
    if (hit(['在家', '回家', '房间', '家里', '家务', '家', '家で', 'home'])) {
      scenes.add('home');
    }
    if (hit([
      '学习',
      '看书',
      '复习',
      '考试',
      '输出',
      '写作',
      '勉強',
      'study',
      'reading',
      'writing'
    ])) {
      scenes.add('study');
    }
    if (hit(
        ['吃饭', '好吃', '逛', '买东西', '天气', '散步', '咖啡', '食べた', 'lunch', 'coffee'])) {
      scenes.add('daily_life');
    }

    if (scenes.isEmpty) {
      return _defaultEmotion(content) == 'negative'
          ? const ['daily_friction']
          : const ['daily_life'];
    }
    return scenes.take(3).toList();
  }

  List<String> _defaultIntentTags(String content) {
    final emotion = _defaultEmotion(content);
    final text = content.toLowerCase();
    final intents = <String>[];

    if (emotion == 'negative') intents.add('vent');
    if (emotion == 'positive') intents.add('celebrate');
    if (emotion == 'mixed') {
      intents.add('vent');
      intents.add('reflection');
    }
    if (intents.isEmpty) intents.add('record');

    if (['为什么', '是不是', '感觉', '好像', '也许', 'maybe', 'wonder', '気がする']
            .any(text.contains) &&
        !intents.contains('reflection')) {
      intents.add('reflection');
    }

    if (['要不要', '决定', '算了', 'whether', 'decide', '決める'].any(text.contains) &&
        !intents.contains('decision')) {
      intents.add('decision');
    }

    return intents.take(3).toList();
  }
}
