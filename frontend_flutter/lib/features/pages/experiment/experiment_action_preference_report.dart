import 'package:flutter/material.dart';

import '../../../core/i18n/app_locale_text.dart';
import '../../../core/models/candidate_models.dart';
import '../../../core/models/experiment_creation_source.dart';
import '../../../core/models/experiment_evaluation_models.dart';
import '../../../core/models/phase3_plus_models.dart';
import '../../../core/models/weekly_models.dart';
import '../../../shared/widgets/aurora_ui.dart';

enum ExperimentActionTheme {
  recoveryAndBuffer,
  startingAndSwitching,
  boundariesAndConnection,
  reflectionAndOrganization,
  other,
}

class ExperimentActionThemeSummary {
  final ExperimentActionTheme theme;
  final int evaluatedFeedbackCount;
  final int positiveFeedbackCount;
  final int manageableFeedbackCount;
  final int distinctItemCount;

  const ExperimentActionThemeSummary({
    required this.theme,
    required this.evaluatedFeedbackCount,
    required this.positiveFeedbackCount,
    required this.manageableFeedbackCount,
    required this.distinctItemCount,
  });

  double get positiveRatio => evaluatedFeedbackCount == 0
      ? 0
      : positiveFeedbackCount / evaluatedFeedbackCount;

  double get manageableRatio => evaluatedFeedbackCount == 0
      ? 0
      : manageableFeedbackCount / evaluatedFeedbackCount;
}

class ExperimentActionPreferenceReport {
  static const int synthesisFeedbackThreshold = 5;
  static const int synthesisItemThreshold = 2;
  static const int synthesisDayThreshold = 3;
  static const int comparisonFeedbackThreshold = 10;
  static const int comparisonItemThreshold = 3;

  final int totalEvaluatedFeedbackCount;
  final int distinctItemCount;
  final int distinctDayCount;
  final int smallExperimentFeedbackCount;
  final int goalReviewCount;
  final int positiveCount;
  final int partialPositiveCount;
  final int neutralOrNegativeCount;
  final int easyCount;
  final int acceptableCount;
  final int difficultCount;
  final int userCreatedFeedbackCount;
  final int suggestedFeedbackCount;
  final List<ExperimentActionThemeSummary> themes;

  const ExperimentActionPreferenceReport({
    required this.totalEvaluatedFeedbackCount,
    required this.distinctItemCount,
    required this.distinctDayCount,
    required this.smallExperimentFeedbackCount,
    required this.goalReviewCount,
    required this.positiveCount,
    required this.partialPositiveCount,
    required this.neutralOrNegativeCount,
    required this.easyCount,
    required this.acceptableCount,
    required this.difficultCount,
    required this.userCreatedFeedbackCount,
    required this.suggestedFeedbackCount,
    required this.themes,
  });

  int get ratedBurdenCount => easyCount + acceptableCount + difficultCount;

  bool get hasPreferenceSynthesis =>
      totalEvaluatedFeedbackCount >= synthesisFeedbackThreshold &&
      distinctItemCount >= synthesisItemThreshold &&
      distinctDayCount >= synthesisDayThreshold;

  bool get canCompareConditions =>
      totalEvaluatedFeedbackCount >= comparisonFeedbackThreshold &&
      distinctItemCount >= comparisonItemThreshold &&
      themes.where((theme) => theme.evaluatedFeedbackCount >= 2).length >= 2;

  ExperimentActionThemeSummary? get leadingTheme {
    final eligible = themes
        .where((theme) => theme.evaluatedFeedbackCount >= 2)
        .toList(growable: false);
    if (eligible.isEmpty) return null;
    return eligible.first;
  }

  int get remainingFeedbackCount =>
      (synthesisFeedbackThreshold - totalEvaluatedFeedbackCount)
          .clamp(0, synthesisFeedbackThreshold)
          .toInt();

  int get remainingItemCount => (synthesisItemThreshold - distinctItemCount)
      .clamp(0, synthesisItemThreshold)
      .toInt();

  int get remainingDayCount => (synthesisDayThreshold - distinctDayCount)
      .clamp(0, synthesisDayThreshold)
      .toInt();
}

ExperimentActionPreferenceReport buildExperimentActionPreferenceReport({
  required Iterable<AdoptedMicroActionProgress> smallExperiments,
  required Map<String, List<MicroActionFeedbackModel>> smallExperimentFeedbacks,
  required Iterable<LifeExperimentModel> goals,
  required Map<String, List<LifeExperimentOutcomeReviewModel>> goalReviews,
}) {
  final accumulators =
      <ExperimentActionTheme, _ExperimentActionThemeAccumulator>{};
  final itemIds = <String>{};
  final localDates = <String>{};
  var smallExperimentFeedbackCount = 0;
  var goalReviewCount = 0;
  var positiveCount = 0;
  var partialPositiveCount = 0;
  var neutralOrNegativeCount = 0;
  var easyCount = 0;
  var acceptableCount = 0;
  var difficultCount = 0;
  var userCreatedFeedbackCount = 0;
  var suggestedFeedbackCount = 0;

  void addSource(ExperimentCreationSource source) {
    if (source == ExperimentCreationSource.userCreated) {
      userCreatedFeedbackCount += 1;
    } else if (source == ExperimentCreationSource.candidateAdoption ||
        source == ExperimentCreationSource.legacyAiJudgement) {
      suggestedFeedbackCount += 1;
    }
  }

  for (final item in smallExperiments) {
    final theme = _classifyActionTheme(
      '${item.action.title} ${item.action.reason}',
    );
    for (final feedback
        in smallExperimentFeedbacks[item.action.id] ?? const []) {
      if (!feedback.isValid || !_smallExperimentWasTried(feedback.happened)) {
        continue;
      }
      final effect = normalizeSmallTryEffect(feedback.effect);
      if (!SmallTryEffect.values.contains(effect)) continue;
      smallExperimentFeedbackCount += 1;
      itemIds.add(item.action.id);
      if (feedback.localDate.trim().isNotEmpty) {
        localDates.add(feedback.localDate.trim());
      }
      addSource(item.action.creationSource);
      final positive = effect == SmallTryEffect.helpful ||
          effect == SmallTryEffect.somewhatHelpful;
      if (effect == SmallTryEffect.helpful) {
        positiveCount += 1;
      } else if (effect == SmallTryEffect.somewhatHelpful) {
        partialPositiveCount += 1;
      } else {
        neutralOrNegativeCount += 1;
      }
      final difficulty = normalizeSmallTryDifficulty(feedback.difficulty);
      final manageable = difficulty == SmallTryDifficulty.easy ||
          difficulty == SmallTryDifficulty.okay;
      if (difficulty == SmallTryDifficulty.easy) {
        easyCount += 1;
      } else if (difficulty == SmallTryDifficulty.okay) {
        acceptableCount += 1;
      } else if (difficulty == SmallTryDifficulty.difficult) {
        difficultCount += 1;
      }
      accumulators
          .putIfAbsent(
            theme,
            () => _ExperimentActionThemeAccumulator(theme),
          )
          .add(
            itemId: item.action.id,
            positive: positive,
            manageable: manageable,
          );
    }
  }

  for (final goal in goals) {
    final theme = _classifyActionTheme(
      '${goal.title} ${goal.hypothesis} ${goal.suggestedAction}',
    );
    for (final review in goalReviews[goal.id] ?? const []) {
      final result = review.outcomeResult.trim().toLowerCase();
      if (!GoalOutcomeResult.values.contains(result) ||
          result == GoalOutcomeResult.unclear) {
        continue;
      }
      goalReviewCount += 1;
      itemIds.add(goal.id);
      if (review.localDate.trim().isNotEmpty) {
        localDates.add(review.localDate.trim());
      }
      addSource(goal.creationSource);
      final positive = result == GoalOutcomeResult.improved ||
          result == GoalOutcomeResult.somewhatImproved;
      if (result == GoalOutcomeResult.improved) {
        positiveCount += 1;
      } else if (result == GoalOutcomeResult.somewhatImproved) {
        partialPositiveCount += 1;
      } else {
        neutralOrNegativeCount += 1;
      }
      final burden = review.burden.trim().toLowerCase();
      final manageable = burden == EvaluationEffort.easy ||
          burden == EvaluationEffort.acceptable;
      if (burden == EvaluationEffort.easy) {
        easyCount += 1;
      } else if (burden == EvaluationEffort.acceptable) {
        acceptableCount += 1;
      } else if (burden == EvaluationEffort.tooDifficult) {
        difficultCount += 1;
      }
      accumulators
          .putIfAbsent(
            theme,
            () => _ExperimentActionThemeAccumulator(theme),
          )
          .add(
            itemId: goal.id,
            positive: positive,
            manageable: manageable,
          );
    }
  }

  final themes = accumulators.values
      .map((item) => item.toSummary())
      .toList(growable: false)
    ..sort((a, b) {
      final ratio = b.positiveRatio.compareTo(a.positiveRatio);
      if (ratio != 0) return ratio;
      return b.evaluatedFeedbackCount.compareTo(a.evaluatedFeedbackCount);
    });
  return ExperimentActionPreferenceReport(
    totalEvaluatedFeedbackCount: smallExperimentFeedbackCount + goalReviewCount,
    distinctItemCount: itemIds.length,
    distinctDayCount: localDates.length,
    smallExperimentFeedbackCount: smallExperimentFeedbackCount,
    goalReviewCount: goalReviewCount,
    positiveCount: positiveCount,
    partialPositiveCount: partialPositiveCount,
    neutralOrNegativeCount: neutralOrNegativeCount,
    easyCount: easyCount,
    acceptableCount: acceptableCount,
    difficultCount: difficultCount,
    userCreatedFeedbackCount: userCreatedFeedbackCount,
    suggestedFeedbackCount: suggestedFeedbackCount,
    themes: themes,
  );
}

class ExperimentActionPreferenceReportPage extends StatelessWidget {
  final ExperimentActionPreferenceReport report;

  const ExperimentActionPreferenceReportPage({
    super.key,
    required this.report,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('experiment-pro-action-preference-page'),
      body: Stack(
        children: [
          AuroraPage(
            child: SafeArea(
              bottom: false,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  22,
                  12,
                  22,
                  MediaQuery.paddingOf(context).bottom + 42,
                ),
                children: [
                  _ActionPreferenceHero(
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(height: 16),
                  _PreferenceReadinessCard(report: report),
                  const SizedBox(height: 14),
                  if (report.hasPreferenceSynthesis) ...[
                    _PreferenceSummaryCard(report: report),
                    const SizedBox(height: 14),
                  ],
                  _PreferenceEffectCard(report: report),
                  const SizedBox(height: 14),
                  _PreferenceEffortCard(report: report),
                  const SizedBox(height: 14),
                  _PreferenceTrackCard(report: report),
                  const SizedBox(height: 14),
                  _PreferenceBoundaryCard(report: report),
                ],
              ),
            ),
          ),
          const AuroraSafeTopMask(extraHeight: 4),
        ],
      ),
    );
  }
}

class ExperimentActionPreferenceEntryCard extends StatelessWidget {
  final bool isPremium;
  final bool isLoading;
  final VoidCallback onTap;

  const ExperimentActionPreferenceEntryCard({
    super.key,
    required this.isPremium,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppLocaleText.tr(
        context,
        en: 'Pro action preference report',
        zhHans: '专业版行动偏好深度报告',
        zhHant: '專業版行動偏好深度報告',
        ja: 'プロ版の行動傾向レポート',
      ),
      child: InkWell(
        key: const ValueKey('experiment-pro-action-preference-entry'),
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(24),
        child: AuroraCard(
          padding: const EdgeInsets.all(16),
          borderRadius: BorderRadius.circular(24),
          color: Colors.white.withValues(alpha: 0.72),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF735EFF), Color(0xFF59B6F2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(19),
                  boxShadow: [
                    BoxShadow(
                      color: AuroraColors.purple.withValues(alpha: 0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(17),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.insights_rounded,
                        color: Colors.white,
                        size: 29,
                      ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AuroraColors.gold.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            AppLocaleText.tr(
                              context,
                              en: 'Pro',
                              zhHans: '专业版',
                              zhHant: '專業版',
                              ja: 'プロ版',
                            ),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: const Color(0xFF9A6B08),
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            AppLocaleText.tr(
                              context,
                              en: 'Action preferences',
                              zhHans: '行动偏好',
                              zhHant: '行動偏好',
                              ja: '行動の傾向',
                            ),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: AuroraColors.ink,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppLocaleText.tr(
                        context,
                        en: 'See which experiments feel more helpful, manageable and easier to begin.',
                        zhHans: '整理什么样的实验更有帮助、负担更合适，也更容易开始。',
                        zhHant: '整理什麼樣的實驗更有幫助、負擔更合適，也更容易開始。',
                        ja: '役立ちやすく、負担が合い、始めやすい実験の傾向を整理します。',
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AuroraColors.muted,
                            height: 1.45,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isPremium ? Icons.chevron_right_rounded : Icons.lock_outline,
                color: AuroraColors.purple,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionPreferenceHero extends StatelessWidget {
  final VoidCallback onBack;

  const _ActionPreferenceHero({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('experiment-action-preference-hero'),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
        boxShadow: [
          BoxShadow(
            color: AuroraColors.purple.withValues(alpha: 0.11),
            blurRadius: 25,
            offset: const Offset(0, 11),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned(
            right: -34,
            top: 0,
            width: 188,
            height: 150,
            child: IgnorePointer(
              child: AuroraExperimentHeroPattern(opacity: 0.7),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton.filledTonal(
                    key: const ValueKey('experiment-action-preference-back'),
                    onPressed: onBack,
                    icon:
                        const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
                    tooltip:
                        MaterialLocalizations.of(context).backButtonTooltip,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFF438CF0), Color(0xFF8155EF)],
                        ).createShader(bounds),
                        child: Text(
                          AppLocaleText.tr(
                            context,
                            en: 'Action preference report',
                            zhHans: '行动偏好深度报告',
                            zhHant: '行動偏好深度報告',
                            ja: '行動傾向の深いレポート',
                          ),
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                              ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 265),
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'A cross-experiment view of what helps, what feels manageable and what conditions fit you.',
                    zhHans: '跨多个小实验与目标，整理什么更有帮助、负担更合适，以及哪些条件更适合你。',
                    zhHant: '跨多個小實驗與目標，整理什麼更有幫助、負擔更合適，以及哪些條件更適合你。',
                    ja: '複数の小実験と目標を横断し、役立ちやすさ・負担・合う条件を整理します。',
                  ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AuroraColors.muted,
                        height: 1.5,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreferenceReadinessCard extends StatelessWidget {
  final ExperimentActionPreferenceReport report;

  const _PreferenceReadinessCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final ready = report.hasPreferenceSynthesis;
    final color = ready ? AuroraColors.mint : AuroraColors.gold;
    return _PreferenceCard(
      key: const ValueKey('experiment-preference-readiness'),
      title: ready
          ? AppLocaleText.tr(
              context,
              en: 'Preference summary is ready',
              zhHans: '行动偏好已经开始形成',
              zhHant: '行動偏好已經開始形成',
              ja: '行動傾向が見え始めました',
            )
          : AppLocaleText.tr(
              context,
              en: 'Preference summary is still forming',
              zhHans: '行动偏好仍在形成',
              zhHant: '行動偏好仍在形成',
              ja: '行動傾向はまだ形成中です',
            ),
      icon: ready ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
      color: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricChip(
                label: AppLocaleText.tr(
                  context,
                  en: '${report.totalEvaluatedFeedbackCount} ratings',
                  zhHans: '${report.totalEvaluatedFeedbackCount} 条明确反馈',
                  zhHant: '${report.totalEvaluatedFeedbackCount} 條明確回饋',
                  ja: '${report.totalEvaluatedFeedbackCount} 件の明確な評価',
                ),
                color: AuroraColors.purple,
              ),
              _MetricChip(
                label: AppLocaleText.tr(
                  context,
                  en: '${report.distinctItemCount} experiments',
                  zhHans: '覆盖 ${report.distinctItemCount} 项',
                  zhHant: '涵蓋 ${report.distinctItemCount} 項',
                  ja: '${report.distinctItemCount} 件を対象',
                ),
                color: AuroraColors.blue,
              ),
              _MetricChip(
                label: AppLocaleText.tr(
                  context,
                  en: '${report.distinctDayCount} days',
                  zhHans: '${report.distinctDayCount} 个登记日',
                  zhHant: '${report.distinctDayCount} 個登記日',
                  ja: '${report.distinctDayCount} 日分',
                ),
                color: AuroraColors.mint,
              ),
            ],
          ),
          if (!ready) ...[
            const SizedBox(height: 12),
            Text(
              _remainingReadinessText(context, report),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AuroraColors.muted,
                    height: 1.45,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PreferenceSummaryCard extends StatelessWidget {
  final ExperimentActionPreferenceReport report;

  const _PreferenceSummaryCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final leading = report.leadingTheme;
    final positive = report.positiveCount + report.partialPositiveCount;
    final manageable = report.easyCount + report.acceptableCount;
    return _PreferenceCard(
      title: AppLocaleText.tr(
        context,
        en: 'Current action preference',
        zhHans: '目前的行动偏好',
        zhHant: '目前的行動偏好',
        ja: '現在の行動傾向',
      ),
      icon: Icons.auto_awesome_rounded,
      color: AuroraColors.purple,
      child: Text(
        leading == null
            ? AppLocaleText.tr(
                context,
                en: '$positive of ${report.totalEvaluatedFeedbackCount} explicit ratings were positive; $manageable of ${report.ratedBurdenCount} burden ratings felt manageable.',
                zhHans:
                    '${report.totalEvaluatedFeedbackCount} 条明确反馈中有 $positive 条偏正向；${report.ratedBurdenCount} 条负担反馈中有 $manageable 条属于轻松或还好。',
                zhHant:
                    '${report.totalEvaluatedFeedbackCount} 條明確回饋中有 $positive 條偏正向；${report.ratedBurdenCount} 條負擔回饋中有 $manageable 條屬於輕鬆或還好。',
                ja: '${report.totalEvaluatedFeedbackCount} 件の明確な評価のうち $positive 件が前向きで、負担評価 ${report.ratedBurdenCount} 件のうち $manageable 件が無理のない範囲でした。',
              )
            : AppLocaleText.tr(
                context,
                en: '${_themeLabel(context, leading.theme)} currently has positive feedback in ${leading.positiveFeedbackCount} of ${leading.evaluatedFeedbackCount} ratings. This is a current pattern, not a causal conclusion.',
                zhHans:
                    '目前「${_themeLabel(context, leading.theme)}」类做法在 ${leading.evaluatedFeedbackCount} 条反馈中有 ${leading.positiveFeedbackCount} 条偏正向。这是当前反馈呈现的倾向，不代表因果结论。',
                zhHant:
                    '目前「${_themeLabel(context, leading.theme)}」類做法在 ${leading.evaluatedFeedbackCount} 條回饋中有 ${leading.positiveFeedbackCount} 條偏正向。這是目前回饋呈現的傾向，不代表因果結論。',
                ja: '現在は「${_themeLabel(context, leading.theme)}」の評価 ${leading.evaluatedFeedbackCount} 件中 ${leading.positiveFeedbackCount} 件が前向きです。因果ではなく、現時点の傾向です。',
              ),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AuroraColors.ink,
              height: 1.55,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _PreferenceEffectCard extends StatelessWidget {
  final ExperimentActionPreferenceReport report;

  const _PreferenceEffectCard({required this.report});

  @override
  Widget build(BuildContext context) {
    return _PreferenceCard(
      key: const ValueKey('experiment-preference-effect-chart'),
      title: AppLocaleText.tr(
        context,
        en: 'What seems more helpful',
        zhHans: '什么样的实验更有帮助',
        zhHant: '什麼樣的實驗更有幫助',
        ja: '役立ちやすい実験の傾向',
      ),
      icon: Icons.insights_rounded,
      color: AuroraColors.blue,
      child: report.themes.isEmpty
          ? _NoConclusionText(
              text: AppLocaleText.tr(
                context,
                en: 'No explicit effect ratings yet.',
                zhHans: '还没有明确的效果反馈。',
                zhHant: '還沒有明確的效果回饋。',
                ja: '明確な効果評価はまだありません。',
              ),
            )
          : Column(
              children: [
                for (final theme in report.themes.take(4))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 11),
                    child: _PreferenceRatioRow(
                      label: _themeLabel(context, theme.theme),
                      numerator: theme.positiveFeedbackCount,
                      denominator: theme.evaluatedFeedbackCount,
                      color: _themeColor(theme.theme),
                    ),
                  ),
                if (!report.canCompareConditions)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: _NoConclusionText(
                      key: const ValueKey(
                        'experiment-preference-no-conclusion',
                      ),
                      text: AppLocaleText.tr(
                        context,
                        en: 'More comparable feedback is needed before ranking conditions.',
                        zhHans: '还需要更多可比较的反馈，暂不排列“最有效”的顺序。',
                        zhHant: '還需要更多可比較的回饋，暫不排列「最有效」的順序。',
                        ja: '条件を順位づけするには、比較できる評価がもう少し必要です。',
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _PreferenceEffortCard extends StatelessWidget {
  final ExperimentActionPreferenceReport report;

  const _PreferenceEffortCard({required this.report});

  @override
  Widget build(BuildContext context) {
    return _PreferenceCard(
      key: const ValueKey('experiment-preference-effort-chart'),
      title: AppLocaleText.tr(
        context,
        en: 'Effort preference',
        zhHans: '负担偏好',
        zhHant: '負擔偏好',
        ja: '負担の傾向',
      ),
      icon: Icons.speed_rounded,
      color: AuroraColors.orange,
      child: report.ratedBurdenCount == 0
          ? _NoConclusionText(
              text: AppLocaleText.tr(
                context,
                en: 'No explicit effort ratings yet.',
                zhHans: '还没有明确的负担反馈。',
                zhHant: '還沒有明確的負擔回饋。',
                ja: '明確な負担評価はまだありません。',
              ),
            )
          : Column(
              children: [
                _PreferenceRatioRow(
                  label: AppLocaleText.tr(
                    context,
                    en: 'Easy',
                    zhHans: '轻松',
                    zhHant: '輕鬆',
                    ja: '楽',
                  ),
                  numerator: report.easyCount,
                  denominator: report.ratedBurdenCount,
                  color: AuroraColors.mint,
                ),
                const SizedBox(height: 11),
                _PreferenceRatioRow(
                  label: AppLocaleText.tr(
                    context,
                    en: 'Manageable',
                    zhHans: '还好',
                    zhHant: '還好',
                    ja: '無理のない範囲',
                  ),
                  numerator: report.acceptableCount,
                  denominator: report.ratedBurdenCount,
                  color: AuroraColors.blue,
                ),
                const SizedBox(height: 11),
                _PreferenceRatioRow(
                  label: AppLocaleText.tr(
                    context,
                    en: 'Demanding',
                    zhHans: '偏费力',
                    zhHant: '偏費力',
                    ja: '負担が大きい',
                  ),
                  numerator: report.difficultCount,
                  denominator: report.ratedBurdenCount,
                  color: AuroraColors.orange,
                ),
              ],
            ),
    );
  }
}

class _PreferenceTrackCard extends StatelessWidget {
  final ExperimentActionPreferenceReport report;

  const _PreferenceTrackCard({required this.report});

  @override
  Widget build(BuildContext context) {
    return _PreferenceCard(
      key: const ValueKey('experiment-preference-track-summary'),
      title: AppLocaleText.tr(
        context,
        en: 'Spot Tries and goals',
        zhHans: '小实验与目标',
        zhHant: '小實驗與目標',
        ja: '小実験と目標',
      ),
      icon: Icons.view_week_outlined,
      color: AuroraColors.mint,
      child: Row(
        children: [
          Expanded(
            child: _TrackMetric(
              icon: Icons.spa_rounded,
              color: AuroraColors.mint,
              value: report.smallExperimentFeedbackCount,
              label: AppLocaleText.tr(
                context,
                en: 'Immediate ratings',
                zhHans: '小实验即时反馈',
                zhHant: '小實驗即時回饋',
                ja: '小実験の即時評価',
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _TrackMetric(
              icon: Icons.flag_rounded,
              color: AuroraColors.blue,
              value: report.goalReviewCount,
              label: AppLocaleText.tr(
                context,
                en: 'Goal reviews',
                zhHans: '目标总结',
                zhHant: '目標總結',
                ja: '目標のまとめ',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreferenceBoundaryCard extends StatelessWidget {
  final ExperimentActionPreferenceReport report;

  const _PreferenceBoundaryCard({required this.report});

  @override
  Widget build(BuildContext context) {
    return _PreferenceCard(
      title: AppLocaleText.tr(
        context,
        en: 'How to read this report',
        zhHans: '如何使用这份报告',
        zhHant: '如何使用這份報告',
        ja: 'このレポートの見方',
      ),
      icon: Icons.info_outline_rounded,
      color: AuroraColors.gold,
      child: Text(
        AppLocaleText.tr(
          context,
          en: 'It summarizes explicit feedback across experiments. Completion alone never counts as effectiveness, and the report does not claim causation.',
          zhHans: '这里只整理你明确登记的效果、负担和目标总结。完成次数不会自动算作有效，当前倾向也不代表因果。',
          zhHant: '這裡只整理你明確登記的效果、負擔和目標總結。完成次數不會自動算作有效，目前傾向也不代表因果。',
          ja: '明確に記録した効果・負担・目標のまとめだけを集計します。完了回数だけで有効とは判断せず、因果も断定しません。',
        ),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AuroraColors.muted,
              height: 1.55,
            ),
      ),
    );
  }
}

class _PreferenceCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;

  const _PreferenceCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AuroraCard(
      padding: const EdgeInsets.all(17),
      borderRadius: BorderRadius.circular(24),
      color: Colors.white.withValues(alpha: 0.74),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AuroraSoftIconCircle(icon: icon, color: color, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AuroraColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _PreferenceRatioRow extends StatelessWidget {
  final String label;
  final int numerator;
  final int denominator;
  final Color color;

  const _PreferenceRatioRow({
    required this.label,
    required this.numerator,
    required this.denominator,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = denominator == 0 ? 0.0 : numerator / denominator;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AuroraColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            Text(
              '$numerator/$denominator',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: ratio,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _TrackMetric extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int value;
  final String label;

  const _TrackMetric({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 23),
          const SizedBox(height: 9),
          Text(
            '$value',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AuroraColors.muted,
                  height: 1.35,
                ),
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final Color color;

  const _MetricChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _NoConclusionText extends StatelessWidget {
  final String text;

  const _NoConclusionText({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AuroraColors.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AuroraColors.muted,
              height: 1.45,
            ),
      ),
    );
  }
}

class _ExperimentActionThemeAccumulator {
  final ExperimentActionTheme theme;
  final Set<String> itemIds = {};
  int evaluatedFeedbackCount = 0;
  int positiveFeedbackCount = 0;
  int manageableFeedbackCount = 0;

  _ExperimentActionThemeAccumulator(this.theme);

  void add({
    required String itemId,
    required bool positive,
    required bool manageable,
  }) {
    itemIds.add(itemId);
    evaluatedFeedbackCount += 1;
    if (positive) positiveFeedbackCount += 1;
    if (manageable) manageableFeedbackCount += 1;
  }

  ExperimentActionThemeSummary toSummary() => ExperimentActionThemeSummary(
        theme: theme,
        evaluatedFeedbackCount: evaluatedFeedbackCount,
        positiveFeedbackCount: positiveFeedbackCount,
        manageableFeedbackCount: manageableFeedbackCount,
        distinctItemCount: itemIds.length,
      );
}

bool _smallExperimentWasTried(String raw) {
  const aliases = {
    'yes',
    'happened',
    'occurred',
    'done',
    'completed',
    'true',
    'tried',
  };
  return aliases.contains(raw.trim().toLowerCase());
}

ExperimentActionTheme _classifyActionTheme(String raw) {
  final text = raw.toLowerCase();
  bool hasAny(Iterable<String> keywords) =>
      keywords.any((keyword) => text.contains(keyword));
  if (hasAny(const [
    '恢复',
    '恢復',
    '休息',
    '缓冲',
    '緩衝',
    '散步',
    '呼吸',
    '离屏',
    '離屏',
    '睡眠',
    '放松',
    '放鬆',
    '螢幕',
    'recovery',
    'rest',
    'walk',
    'sleep',
    'break',
    '回復',
    '休む',
    '散歩',
  ])) {
    return ExperimentActionTheme.recoveryAndBuffer;
  }
  if (hasAny(const [
    '边界',
    '邊界',
    '拒绝',
    '拒絕',
    '关系',
    '關係',
    '沟通',
    '溝通',
    '消息',
    '訊息',
    'boundary',
    'relationship',
    'communicat',
    'message',
    '境界',
    '関係',
    '連絡',
  ])) {
    return ExperimentActionTheme.boundariesAndConnection;
  }
  if (hasAny(const [
    '切换',
    '切換',
    '开始',
    '開始',
    '启动',
    '啟動',
    '任务',
    '任務',
    '会议',
    '會議',
    '专注',
    '專注',
    '间隔',
    '間隔',
    'switch',
    'start',
    'task',
    'meeting',
    'focus',
    '切り替え',
    '始め',
    '会議',
    '集中',
  ])) {
    return ExperimentActionTheme.startingAndSwitching;
  }
  if (hasAny(const [
    '写',
    '寫',
    '记录',
    '記錄',
    '整理',
    '表达',
    '表達',
    '复盘',
    '復盤',
    'write',
    'journal',
    'record',
    'organize',
    'reflect',
    '書く',
    '記録',
    '整理',
    '振り返',
  ])) {
    return ExperimentActionTheme.reflectionAndOrganization;
  }
  return ExperimentActionTheme.other;
}

String _remainingReadinessText(
  BuildContext context,
  ExperimentActionPreferenceReport report,
) {
  final missing = <String>[];
  if (report.remainingFeedbackCount > 0) {
    missing.add(
      AppLocaleText.tr(
        context,
        en: '${report.remainingFeedbackCount} more explicit ratings',
        zhHans: '再登记 ${report.remainingFeedbackCount} 条明确反馈',
        zhHant: '再登記 ${report.remainingFeedbackCount} 條明確回饋',
        ja: '明確な評価をあと ${report.remainingFeedbackCount} 件',
      ),
    );
  }
  if (report.remainingItemCount > 0) {
    missing.add(
      AppLocaleText.tr(
        context,
        en: '${report.remainingItemCount} more experiments or goals',
        zhHans: '再覆盖 ${report.remainingItemCount} 个小实验或目标',
        zhHant: '再涵蓋 ${report.remainingItemCount} 個小實驗或目標',
        ja: '小実験または目標をあと ${report.remainingItemCount} 件',
      ),
    );
  }
  if (report.remainingDayCount > 0) {
    missing.add(
      AppLocaleText.tr(
        context,
        en: '${report.remainingDayCount} more recording days',
        zhHans: '再增加 ${report.remainingDayCount} 个登记日',
        zhHant: '再增加 ${report.remainingDayCount} 個登記日',
        ja: '記録日をあと ${report.remainingDayCount} 日',
      ),
    );
  }
  return AppLocaleText.tr(
    context,
    en: 'To avoid over-reading a single case, add ${missing.join(', ')}.',
    zhHans: '为了避免把单次体验读得过重，需要${missing.join('、')}。',
    zhHant: '為了避免把單次體驗讀得過重，需要${missing.join('、')}。',
    ja: '一度の体験を読み込みすぎないため、${missing.join('、')}が必要です。',
  );
}

String _themeLabel(BuildContext context, ExperimentActionTheme theme) {
  return switch (theme) {
    ExperimentActionTheme.recoveryAndBuffer => AppLocaleText.tr(
        context,
        en: 'Recovery and buffers',
        zhHans: '恢复与缓冲',
        zhHant: '恢復與緩衝',
        ja: '回復と余白',
      ),
    ExperimentActionTheme.startingAndSwitching => AppLocaleText.tr(
        context,
        en: 'Starting and switching',
        zhHans: '启动与切换',
        zhHant: '啟動與切換',
        ja: '開始と切り替え',
      ),
    ExperimentActionTheme.boundariesAndConnection => AppLocaleText.tr(
        context,
        en: 'Boundaries and connection',
        zhHans: '边界与连接',
        zhHant: '邊界與連結',
        ja: '境界とつながり',
      ),
    ExperimentActionTheme.reflectionAndOrganization => AppLocaleText.tr(
        context,
        en: 'Reflection and organization',
        zhHans: '记录与整理',
        zhHant: '記錄與整理',
        ja: '記録と整理',
      ),
    ExperimentActionTheme.other => AppLocaleText.tr(
        context,
        en: 'Other approaches',
        zhHans: '其他做法',
        zhHant: '其他做法',
        ja: 'その他の方法',
      ),
  };
}

Color _themeColor(ExperimentActionTheme theme) => switch (theme) {
      ExperimentActionTheme.recoveryAndBuffer => AuroraColors.mint,
      ExperimentActionTheme.startingAndSwitching => AuroraColors.blue,
      ExperimentActionTheme.boundariesAndConnection => AuroraColors.purple,
      ExperimentActionTheme.reflectionAndOrganization => AuroraColors.gold,
      ExperimentActionTheme.other => AuroraColors.orange,
    };
