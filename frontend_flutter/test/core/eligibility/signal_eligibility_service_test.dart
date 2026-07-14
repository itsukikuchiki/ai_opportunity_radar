import 'package:flutter_test/flutter_test.dart';

import 'package:ai_opportunity_radar/core/eligibility/signal_eligibility_service.dart';
import 'package:ai_opportunity_radar/core/models/today_models.dart';

void main() {
  const service = SignalEligibilityService();
  const coreAnalysisStages = [
    SignalEligibilityStage.daily,
    SignalEligibilityStage.weekly,
    SignalEligibilityStage.journey,
    SignalEligibilityStage.aiReason,
  ];

  group('P2.1-03 full rule matrix', () {
    test('draft 不进入 Daily / Weekly / Journey / AI', () {
      final signal = _signal(isLocalDraft: true);

      _expectExcludedFromAll(
        service: service,
        signal: signal,
        stages: coreAnalysisStages,
        reason: 'draft',
      );
    });

    test('sync_failed 按策略排除，不进入高层分析', () {
      final signal = _signal(syncFailed: true);

      _expectExcludedFromAll(
        service: service,
        signal: signal,
        stages: coreAnalysisStages,
        reason: 'sync_failed',
      );
    });

    test('inaccurate 全部排除', () {
      final signal = _signal(userConfirmation: 'inaccurate');

      _expectExcludedFromAll(
        service: service,
        signal: signal,
        stages: SignalEligibilityStage.values,
        reason: 'inaccurate',
      );
    });

    test('privacy excluded 全部排除', () {
      final signal = _signal(privacyLevel: 'excluded');

      _expectExcludedFromAll(
        service: service,
        signal: signal,
        stages: SignalEligibilityStage.values,
        reason: 'excluded',
      );
    });

    test('do_not_analyze 全部排除', () {
      final signal = _signal(privacyLevel: 'do_not_analyze');

      _expectExcludedFromAll(
        service: service,
        signal: signal,
        stages: SignalEligibilityStage.values,
        reason: 'do_not_analyze',
      );
    });

    test('AI predicted 未确认不进入，confirmed 后进入', () {
      final unconfirmed = _signal(
        sourceType: 'ai_predicted',
        userConfirmation: 'unconfirmed',
      );
      final confirmed = _signal(
        sourceType: 'ai_predicted',
        userConfirmation: 'confirmed',
      );

      _expectExcludedFromAll(
        service: service,
        signal: unconfirmed,
        stages: coreAnalysisStages,
        reason: 'ai_prediction_unconfirmed',
      );
      _expectEligibleForAll(
        service: service,
        signal: confirmed,
        stages: coreAnalysisStages,
      );
    });

    test('AI predicted 补充个人语境后也进入', () {
      final supplemented = _signal(
        sourceType: 'ai_predicted',
        userConfirmation: 'supplemented',
        userCorrectionJson: const {
          'supplement_text': '这确实发生在连续会议之后。',
        },
      );

      _expectEligibleForAll(
        service: service,
        signal: supplemented,
        stages: coreAnalysisStages,
      );
    });

    test('Library saved 未确认不进入，confirmed / partial 后进入', () {
      final unconfirmed = _signal(
        sourceType: 'library_saved',
        userConfirmation: 'unconfirmed',
      );
      final confirmed = _signal(
        sourceType: 'library_saved',
        userConfirmation: 'confirmed',
      );
      final partial = _signal(
        sourceType: 'library_saved',
        userConfirmation: 'partial',
      );

      _expectExcludedFromAll(
        service: service,
        signal: unconfirmed,
        stages: coreAnalysisStages,
        reason: 'library_unconfirmed',
      );
      _expectEligibleForAll(
        service: service,
        signal: confirmed,
        stages: coreAnalysisStages,
      );
      _expectEligibleForAll(
        service: service,
        signal: partial,
        stages: coreAnalysisStages,
      );
    });

    test('Library saved 补充个人语境后也进入', () {
      final supplemented = _signal(
        sourceType: 'library_saved',
        userConfirmation: 'supplemented',
        userCorrectionJson: const {
          'supplement_text': '这是我本周真实遇到的模式。',
        },
      );

      _expectEligibleForAll(
        service: service,
        signal: supplemented,
        stages: coreAnalysisStages,
      );
    });
  });

  test('excludes processing failures and analysis policy blocks', () {
    final signal = RecentSignalModel(
      content: 'private signal',
      syncFailed: true,
      privacyLevel: 'do_not_analyze',
      userConfirmation: 'inaccurate',
    );

    final result = service.evaluate(signal, SignalEligibilityStage.weekly);

    expect(result.eligible, false);
    expect(
        result.reasons,
        containsAll([
          'sync_failed',
          'do_not_analyze',
          'inaccurate',
        ]));
    expect(result.policyVersion, SignalEligibilityService.policyVersion);
  });

  test('edited AI prediction is eligible after the explicit decision', () {
    final adjusted = RecentSignalModel(
      content: 'AI guessed signal',
      sourceType: 'ai_predicted',
      userConfirmation: 'edited',
      userCorrectionJson: const {'edited_text': 'Corrected signal'},
    );

    expect(service.isEligible(adjusted, SignalEligibilityStage.journey), true);
  });

  test('all current analysis stages exclude legacy references', () {
    final legacy = RecentSignalModel(
      content: 'old capture',
      isLegacy: true,
      userConfirmation: 'accurate',
    );

    _expectExcludedFromAll(
      service: service,
      signal: legacy,
      stages: SignalEligibilityStage.values,
      reason: 'legacy_reference',
    );
  });

  test('schedule and goal source types remain compatibility-only', () {
    for (final sourceType in const [
      'calendar',
      'manual_schedule',
      'schedule_feedback',
      'goal',
      'goal_feedback',
    ]) {
      _expectExcludedFromAll(
        service: service,
        signal: _signal(sourceType: sourceType),
        stages: SignalEligibilityStage.values,
        reason: 'legacy_reference',
      );
    }
  });

  test('reason labels are user-facing for exclusion display', () {
    expect(
      SignalEligibilityService.reasonLabelZhHans('sync_failed'),
      '同步待重试',
    );
    expect(
      SignalEligibilityService.reasonLabelEn('ai_prediction_unconfirmed'),
      'AI prediction needs confirmation',
    );
  });
}

RecentSignalModel _signal({
  String sourceType = 'text',
  String userConfirmation = 'confirmed',
  String privacyLevel = 'private',
  bool isLocalDraft = false,
  bool syncFailed = false,
  Map<String, dynamic> userCorrectionJson = const {},
}) {
  return RecentSignalModel(
    content: 'test signal',
    sourceType: sourceType,
    userConfirmation: userConfirmation,
    privacyLevel: privacyLevel,
    isLocalDraft: isLocalDraft,
    syncFailed: syncFailed,
    userCorrectionJson: userCorrectionJson,
  );
}

void _expectExcludedFromAll({
  required SignalEligibilityService service,
  required RecentSignalModel signal,
  required Iterable<SignalEligibilityStage> stages,
  required String reason,
}) {
  for (final stage in stages) {
    final result = service.evaluate(signal, stage);
    expect(
      result.eligible,
      false,
      reason: '$stage should exclude $reason',
    );
    expect(result.reasons, contains(reason));
  }
}

void _expectEligibleForAll({
  required SignalEligibilityService service,
  required RecentSignalModel signal,
  required Iterable<SignalEligibilityStage> stages,
}) {
  for (final stage in stages) {
    final result = service.evaluate(signal, stage);
    expect(
      result.eligible,
      true,
      reason: '$stage should accept the confirmed signal',
    );
    expect(result.reasons, isEmpty);
  }
}
