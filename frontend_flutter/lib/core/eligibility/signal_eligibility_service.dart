import '../models/today_models.dart';

enum SignalEligibilityStage {
  daily,
  weekly,
  journey,
  experiment,
  aiReason,
  aiReflect,
  energyBudget,
}

class SignalEligibilityResult {
  final bool eligible;
  final SignalEligibilityStage stage;
  final List<String> reasons;
  final DateTime evaluatedAt;
  final String policyVersion;

  const SignalEligibilityResult({
    required this.eligible,
    required this.stage,
    required this.reasons,
    required this.evaluatedAt,
    required this.policyVersion,
  });
}

class SignalEligibilityService {
  static const policyVersion = 'v5_current_objects_only_1';

  const SignalEligibilityService();

  SignalEligibilityResult evaluate(
    RecentSignalModel signal,
    SignalEligibilityStage stage,
  ) {
    final reasons = <String>[];

    if (signal.isLocalDraft) reasons.add('draft');
    if (signal.syncFailed) reasons.add('sync_failed');
    if (signal.userConfirmation == 'inaccurate') reasons.add('inaccurate');

    final privacy = signal.privacyLevel.trim().toLowerCase();
    if (privacy == 'sensitive') reasons.add('sensitive');
    if (privacy == 'excluded') reasons.add('excluded');
    if (privacy == 'do_not_analyze') reasons.add('do_not_analyze');

    if (signal.isLibrarySaved && !signal.hasUserConfirmedLibrarySaved) {
      reasons.add('library_unconfirmed');
    }
    if (signal.isAiPredicted && !signal.hasUserConfirmedAiPrediction) {
      reasons.add('ai_prediction_unconfirmed');
    }

    if (_requiresNonLegacy(stage) &&
        (signal.isLegacy || _isLegacyCompatibilitySource(signal.sourceType))) {
      reasons.add('legacy_reference');
    }

    return SignalEligibilityResult(
      eligible: reasons.isEmpty,
      stage: stage,
      reasons: reasons,
      evaluatedAt: DateTime.now(),
      policyVersion: policyVersion,
    );
  }

  bool isEligible(RecentSignalModel signal, SignalEligibilityStage stage) {
    return evaluate(signal, stage).eligible;
  }

  List<RecentSignalModel> filter(
    Iterable<RecentSignalModel> signals,
    SignalEligibilityStage stage,
  ) {
    return signals.where((signal) => isEligible(signal, stage)).toList();
  }

  static String reasonLabelZhHans(String reason) {
    switch (reason) {
      case 'draft':
        return '本机草稿，等待同步';
      case 'sync_failed':
        return '同步待重试';
      case 'inaccurate':
        return '已标记为不准确';
      case 'sensitive':
        return '敏感记录';
      case 'excluded':
        return '已被排除';
      case 'do_not_analyze':
        return '隐私设置为不分析';
      case 'library_unconfirmed':
        return '信号库内容需要补充个人语境';
      case 'ai_prediction_unconfirmed':
        return 'AI 预判需要确认';
      case 'legacy_reference':
        return '旧记录仅作参考';
      default:
        return reason;
    }
  }

  static String reasonLabelEn(String reason) {
    switch (reason) {
      case 'draft':
        return 'local draft awaiting sync';
      case 'sync_failed':
        return 'sync needs retry';
      case 'inaccurate':
        return 'marked inaccurate';
      case 'sensitive':
        return 'sensitive record';
      case 'excluded':
        return 'excluded';
      case 'do_not_analyze':
        return 'privacy set to do not analyze';
      case 'library_unconfirmed':
        return 'library item needs your context';
      case 'ai_prediction_unconfirmed':
        return 'AI prediction needs confirmation';
      case 'legacy_reference':
        return 'legacy import is reference only';
      default:
        return reason;
    }
  }

  static bool _requiresNonLegacy(SignalEligibilityStage stage) {
    return SignalEligibilityStage.values.contains(stage);
  }

  static bool _isLegacyCompatibilitySource(String sourceType) {
    final normalized = sourceType.trim().toLowerCase();
    return normalized == 'calendar' ||
        normalized.contains('schedule') ||
        normalized == 'goal' ||
        normalized.startsWith('goal_');
  }
}
