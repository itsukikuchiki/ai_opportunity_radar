// ignore_for_file: unused_element

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/i18n/app_locale_text.dart';
import '../../../core/i18n/energy_budget_text.dart';
import '../../../core/models/candidate_models.dart';
import '../../../core/models/energy_budget_models.dart';
import '../../../core/models/experiment_evaluation_models.dart';
import '../../../core/models/phase3_plus_models.dart';
import '../../../core/models/weekly_illustration_catalog.dart';
import '../../../core/models/weekly_models.dart';
import '../../../core/preferences/focus_domains.dart';
import '../../../core/readiness/report_readiness.dart';
import '../../../shared/states/load_state.dart';
import '../../../shared/widgets/aurora_ui.dart';
import '../../../shared/widgets/empty_state_block.dart';
import '../../../shared/widgets/experiment_feedback_sheets.dart';
import '../../../shared/widgets/signal_illustration_kit.dart';
import '../../paywall/paywall_sheet.dart';
import 'weekly_view_model.dart';

class WeeklyPage extends StatelessWidget {
  const WeeklyPage({super.key});

  void _openMePage(BuildContext context) {
    context.go(AppRoutes.me);
  }

  Future<String?> _chooseTodayCompletion(
    BuildContext context, {
    required String title,
    required bool isGoal,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(
          color: Color(0xFFFFFCFA),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AuroraColors.line,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              AppLocaleText.tr(
                sheetContext,
                en: isGoal
                    ? 'Record today’s goal'
                    : 'Record today’s small experiment',
                zhHans: isGoal ? '登记今天的目标' : '登记今天的小实验',
                zhHant: isGoal ? '登記今天的目標' : '登記今天的小實驗',
                ja: isGoal ? '今日の目標を記録' : '今日の小実験を記録',
              ),
              style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                    color: AuroraColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: Theme.of(sheetContext).textTheme.bodyLarge?.copyWith(
                    color: AuroraColors.ink,
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              AppLocaleText.tr(
                sheetContext,
                en: 'Only today can be recorded here. Past and future days stay read-only.',
                zhHans: '这里只登记今天。过去和未来的格子保持只读。',
                zhHant: '這裡只登記今天。過去和未來的格子保持唯讀。',
                ja: 'ここでは今日だけ記録できます。過去と未来のマスは読み取り専用です。',
              ),
              style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                    color: AuroraColors.muted,
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey('weekly-completed-choice'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: AuroraColors.mint,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () =>
                        Navigator.of(sheetContext).pop('completed'),
                    icon: const Icon(Icons.check_rounded),
                    label: Text(
                      AppLocaleText.tr(
                        sheetContext,
                        en: 'Completed',
                        zhHans: '已完成',
                        zhHant: '已完成',
                        ja: '完了',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('weekly-not-completed-choice'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      foregroundColor: AuroraColors.orange,
                      side: BorderSide(
                        color: AuroraColors.orange.withValues(alpha: 0.45),
                      ),
                    ),
                    onPressed: () =>
                        Navigator.of(sheetContext).pop('not_completed'),
                    icon: const Icon(Icons.close_rounded),
                    label: Text(
                      AppLocaleText.tr(
                        sheetContext,
                        en: 'Not completed',
                        zhHans: '未完成',
                        zhHant: '未完成',
                        ja: '未完了',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<_WeeklyGoalSummaryInput?> _openGoalWeeklySummary(
    BuildContext context, {
    required LifeExperimentModel experiment,
    required int completedObservationDays,
  }) async {
    final belowMinimum =
        completedObservationDays < experiment.minimumObservationDays;
    final noteController = TextEditingController();
    final result = await showModalBottomSheet<_WeeklyGoalSummaryInput>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        String? outcome = belowMinimum ? GoalOutcomeResult.unclear : null;
        String? burden;
        return StatefulBuilder(
          builder: (context, setSheetState) => Container(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFFFFFCFA),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AuroraColors.line,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    AppLocaleText.tr(
                      context,
                      en: 'Weekly goal summary',
                      zhHans: '目标周次总结',
                      zhHant: '目標週次總結',
                      ja: '目標の週間まとめ',
                    ),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AuroraColors.ink,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    experiment.title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AuroraColors.ink,
                          height: 1.4,
                        ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    AppLocaleText.tr(
                      context,
                      en: 'Summarize only this week here. The overall summary stays in Life Experiment.',
                      zhHans: '这里只总结本周；目标的整体总结留在生活小实验。',
                      zhHant: '這裡只總結本週；目標的整體總結留在生活小實驗。',
                      ja: 'ここでは今週だけをまとめます。目標全体のまとめは生活実験に残します。',
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AuroraColors.muted,
                          height: 1.4,
                        ),
                  ),
                  if (belowMinimum) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AuroraColors.gold.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AuroraColors.gold.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Text(
                        AppLocaleText.tr(
                          context,
                          en: 'Only “Too early to tell” is available until the minimum observation period is reached.',
                          zhHans: '达到最低观察天数前，本周只能记录为“还看不出”。',
                          zhHant: '達到最低觀察天數前，本週只能記錄為「還看不出」。',
                          ja: '最低観察日数に達するまでは、今週の結果は「まだ不明」のみ記録できます。',
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AuroraColors.ink,
                              height: 1.4,
                            ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    AppLocaleText.tr(
                      context,
                      en: 'What changed this week?',
                      zhHans: '这周想观察的变化出现了吗？',
                      zhHant: '這週想觀察的變化出現了嗎？',
                      ja: '今週、観察した変化はありましたか？',
                    ),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AuroraColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (!belowMinimum) ...[
                        _WeeklySummaryChoice(
                          label: AppLocaleText.tr(context,
                              en: 'Improved',
                              zhHans: '有改善',
                              zhHant: '有改善',
                              ja: '改善'),
                          selected: outcome == GoalOutcomeResult.improved,
                          onTap: () => setSheetState(
                            () => outcome = GoalOutcomeResult.improved,
                          ),
                        ),
                        _WeeklySummaryChoice(
                          label: AppLocaleText.tr(context,
                              en: 'A little',
                              zhHans: '有一点',
                              zhHant: '有一點',
                              ja: '少し'),
                          selected:
                              outcome == GoalOutcomeResult.somewhatImproved,
                          onTap: () => setSheetState(
                            () => outcome = GoalOutcomeResult.somewhatImproved,
                          ),
                        ),
                        _WeeklySummaryChoice(
                          label: AppLocaleText.tr(context,
                              en: 'No change',
                              zhHans: '没变化',
                              zhHant: '沒變化',
                              ja: '変化なし'),
                          selected: outcome == GoalOutcomeResult.noChange,
                          onTap: () => setSheetState(
                            () => outcome = GoalOutcomeResult.noChange,
                          ),
                        ),
                        _WeeklySummaryChoice(
                          label: AppLocaleText.tr(context,
                              en: 'Worse',
                              zhHans: '变差',
                              zhHant: '變差',
                              ja: '悪化'),
                          selected: outcome == GoalOutcomeResult.worse,
                          onTap: () => setSheetState(
                            () => outcome = GoalOutcomeResult.worse,
                          ),
                        ),
                      ],
                      _WeeklySummaryChoice(
                        label: AppLocaleText.tr(context,
                            en: 'Too early to tell',
                            zhHans: '还看不出',
                            zhHant: '還看不出',
                            ja: 'まだ不明'),
                        selected: outcome == GoalOutcomeResult.unclear,
                        onTap: () => setSheetState(
                          () => outcome = GoalOutcomeResult.unclear,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppLocaleText.tr(
                      context,
                      en: 'How demanding was it this week?',
                      zhHans: '这周做起来费力吗？',
                      zhHant: '這週做起來費力嗎？',
                      ja: '今週の負担は？',
                    ),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AuroraColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _WeeklySummaryChoice(
                        label: AppLocaleText.tr(context,
                            en: 'Easy', zhHans: '轻松', zhHant: '輕鬆', ja: '楽'),
                        selected: burden == EvaluationEffort.easy,
                        onTap: () => setSheetState(
                          () => burden = EvaluationEffort.easy,
                        ),
                      ),
                      _WeeklySummaryChoice(
                        label: AppLocaleText.tr(context,
                            en: 'Acceptable',
                            zhHans: '可接受',
                            zhHant: '可接受',
                            ja: '許容範囲'),
                        selected: burden == EvaluationEffort.acceptable,
                        onTap: () => setSheetState(
                          () => burden = EvaluationEffort.acceptable,
                        ),
                      ),
                      _WeeklySummaryChoice(
                        label: AppLocaleText.tr(context,
                            en: 'Too demanding',
                            zhHans: '太费力',
                            zhHant: '太費力',
                            ja: '負担が大きい'),
                        selected: burden == EvaluationEffort.tooDifficult,
                        onTap: () => setSheetState(
                          () => burden = EvaluationEffort.tooDifficult,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: noteController,
                    maxLength: 240,
                    decoration: InputDecoration(
                      labelText: AppLocaleText.tr(
                        context,
                        en: 'Add one factual note (optional)',
                        zhHans: '补一句事实（可选）',
                        zhHant: '補一句事實（可選）',
                        ja: '事実をひと言追加（任意）',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      key: const ValueKey('save-weekly-goal-summary'),
                      onPressed: outcome == null || burden == null
                          ? null
                          : () => Navigator.of(sheetContext).pop(
                                _WeeklyGoalSummaryInput(
                                  outcome: outcome!,
                                  burden: burden!,
                                  note: noteController.text.trim().isEmpty
                                      ? null
                                      : noteController.text.trim(),
                                ),
                              ),
                      child: Text(
                        AppLocaleText.tr(
                          context,
                          en: 'Save weekly summary',
                          zhHans: '保存周次总结',
                          zhHant: '儲存週次總結',
                          ja: '週間まとめを保存',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    noteController.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WeeklyViewModel>();

    return Scaffold(
      body: Stack(
        children: [
          AuroraPage(
            child: SafeArea(
              bottom: false,
              child: vm.loadState == LoadState.ready && vm.weeklyInsight != null
                  ? _WeeklyReadyBody(
                      weekly: vm.weeklyInsight!,
                      currentDay: vm.currentLocalDay,
                      currentWeekExperiment: vm.currentWeekExperiment,
                      nextWeekExperiment: vm.nextWeekExperiment,
                      activeMicroActions: vm.activeMicroActions,
                      activeExperiments: vm.activeExperiments,
                      energyBudget: vm.energyBudget,
                      progressLoadFailed: vm.progressLoadFailed,
                      candidateStatus: vm.experimentCandidateStatus,
                      candidateCount: vm.experimentCandidateCount,
                      candidatePreviewTitle: vm.experimentCandidatePreviewTitle,
                      candidateStaleReason: vm.experimentCandidateStaleReason,
                      candidateEligibleSignalCount:
                          vm.experimentCandidateEligibleSignalCount,
                      candidateRefreshFailed: vm.candidateErrorMessage != null,
                      feedbackSubmitState: vm.feedbackSubmitState,
                      experimentSubmitState: vm.experimentSubmitState,
                      attemptFeedbackSubmitState: vm.attemptFeedbackSubmitState,
                      onMicroActionTodayTap: (action) async {
                        final feedback = await showSmallTryAttemptFeedbackSheet(
                          context,
                          title: action.title,
                        );
                        if (feedback == null || !context.mounted) return;
                        await vm.submitMicroActionFeedback(
                          action: action,
                          status: feedback.completionStatus,
                          effect: feedback.effect,
                          difficulty: feedback.difficulty,
                          userNote: feedback.note,
                        );
                        if (!context.mounted) return;
                        final didSave = vm.attemptFeedbackSubmitState ==
                            SubmitState.success;
                        _showWeeklyHint(
                          context,
                          didSave
                              ? AppLocaleText.tr(
                                  context,
                                  en: 'Today’s small experiment was recorded.',
                                  zhHans: '今天的小实验完成情况已记录。',
                                  zhHant: '今天的小實驗完成情況已記錄。',
                                  ja: '今日の小実験を記録しました。',
                                )
                              : AppLocaleText.tr(
                                  context,
                                  en: 'This update could not be recorded. Please try again.',
                                  zhHans: '这次完成情况暂未记录，请重试。',
                                  zhHant: '這次完成情況暫未記錄，請重試。',
                                  ja: '今回は記録できませんでした。もう一度お試しください。',
                                ),
                        );
                      },
                      onExperimentTodayTap: (experiment) async {
                        final status = await _chooseTodayCompletion(
                          context,
                          title: experiment.title,
                          isGoal: true,
                        );
                        if (status == null || !context.mounted) return;
                        await vm.submitLifeExperimentFeedback(
                          experiment: experiment,
                          status: status,
                        );
                        if (!context.mounted) return;
                        final didSave = vm.attemptFeedbackSubmitState ==
                            SubmitState.success;
                        _showWeeklyHint(
                          context,
                          didSave
                              ? AppLocaleText.tr(
                                  context,
                                  en: 'Today’s goal was recorded.',
                                  zhHans: '今天的目标完成情况已记录。',
                                  zhHant: '今天的目標完成情況已記錄。',
                                  ja: '今日の目標を記録しました。',
                                )
                              : AppLocaleText.tr(
                                  context,
                                  en: 'This update could not be recorded. Please try again.',
                                  zhHans: '这次完成情况暂未记录，请重试。',
                                  zhHant: '這次完成情況暫未記錄，請重試。',
                                  ja: '今回は記録できませんでした。もう一度お試しください。',
                                ),
                        );
                      },
                      onGoalWeeklySummaryTap: (experiment) async {
                        final completedObservationDays =
                            await vm.completedGoalObservationDays(experiment);
                        if (!context.mounted) return;
                        final summary = await _openGoalWeeklySummary(
                          context,
                          experiment: experiment,
                          completedObservationDays: completedObservationDays,
                        );
                        if (summary == null || !context.mounted) return;
                        final didSave = await vm.submitGoalWeeklySummary(
                          experiment: experiment,
                          outcomeResult: summary.outcome,
                          burden: summary.burden,
                          note: summary.note,
                        );
                        if (!context.mounted) return;
                        _showWeeklyHint(
                          context,
                          didSave
                              ? AppLocaleText.tr(
                                  context,
                                  en: 'This week’s goal summary was saved.',
                                  zhHans: '这周的目标总结已保存。',
                                  zhHant: '這週的目標總結已儲存。',
                                  ja: '今週の目標まとめを保存しました。',
                                )
                              : AppLocaleText.tr(
                                  context,
                                  en: 'The weekly summary could not be saved. Make sure this goal has at least one record this week.',
                                  zhHans: '周次总结暂未保存，请确认这个目标本周至少有一条记录。',
                                  zhHant: '週次總結暫未儲存，請確認這個目標本週至少有一條記錄。',
                                  ja: '週間まとめを保存できませんでした。今週、この目標に少なくとも1件の記録があるか確認してください。',
                                ),
                        );
                      },
                      onSubmitFeedback: (value) async {
                        await vm.submitFeedback(value);
                        if (!context.mounted) return;
                        _showWeeklyHint(
                          context,
                          AppLocaleText.tr(
                            context,
                            en: 'This weekly feedback is saved.',
                            zhHans: '这周的反馈已保存。',
                            zhHant: '這週的回饋已保存。',
                            ja: '今週のフィードバックを保存しました。',
                          ),
                        );
                      },
                      onSaveExperiment: () async {
                        await context
                            .push(AppRoutes.weeklyExperimentCandidates);
                        if (context.mounted) await vm.load();
                      },
                      onRefresh: vm.load,
                    )
                  : ListView(
                      key: const ValueKey('weekly-scroll-view'),
                      padding: AuroraMainPageSpec.scrollPadding(context),
                      children: [
                        _WeeklyHeroHeader(weekly: vm.weeklyInsight),
                        const SizedBox(height: AuroraMainPageSpec.heroGap),
                        switch (vm.loadState) {
                          LoadState.loading => const Padding(
                              padding: EdgeInsets.symmetric(vertical: 56),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                          LoadState.error => EmptyStateBlock(
                              icon: Icons.error_outline,
                              title: AppLocaleText.tr(
                                context,
                                en: 'Failed to load this week',
                                zhHans: '这周的内容加载失败了',
                                zhHant: '這週的內容載入失敗了',
                                ja: '今週の内容を読み込めませんでした',
                              ),
                              subtitle: vm.errorMessage ??
                                  AppLocaleText.tr(
                                    context,
                                    en: 'Please try again later.',
                                    zhHans: '请稍后重试。',
                                    zhHant: '請稍後重試。',
                                    ja: 'しばらくしてから、もう一度試してください。',
                                  ),
                            ),
                          LoadState.empty => _WeeklyEmptyReviewState(
                              readiness: vm.reportReadiness,
                              onToday: () => context.go(AppRoutes.today),
                            ),
                          _ => const SizedBox.shrink(),
                        },
                      ],
                    ),
            ),
          ),
          const AuroraSafeTopMask(extraHeight: 4),
        ],
      ),
    );
  }

  String _weeklyHeroText(BuildContext context, WeeklyInsightModel? weekly) {
    final insight = weekly?.keyInsight;
    if (insight != null && insight.trim().isNotEmpty) return insight;
    return AppLocaleText.tr(
      context,
      en: 'This week may be less about doing more, and more about switching less and recovering a little earlier.',
      zhHans: '这周最耗你的，不是任务量，而是切换太多、恢复太少。',
      zhHant: '這週最耗你的，不是任務量，而是切換太多、恢復太少。',
      ja: '今週いちばん消耗したのは、量そのものより、切り替えの多さと回復の少なさかもしれません。',
    );
  }

  String _buildWeekRange(BuildContext context, WeeklyInsightModel? weekly) {
    if (weekly == null) {
      return AppLocaleText.tr(
        context,
        en: 'This week',
        zhHans: '这一周',
        zhHant: '這一週',
        ja: '今週',
      );
    }
    return '${weekly.weekStart} - ${weekly.weekEnd}';
  }

  String _buildHeaderSummary(BuildContext context, WeeklyViewModel vm) {
    if (vm.loadState == LoadState.loading) {
      return AppLocaleText.tr(
        context,
        en: 'Gathering this week’s signals...',
        zhHans: '正在整理这一周的线索',
        zhHant: '正在整理這一週的線索',
        ja: '今週の手がかりを整理しています',
      );
    }

    if (vm.showFirstDayGate) {
      return AppLocaleText.tr(
        context,
        en: 'Weekly starts after 3 eligible signals in the current local Monday-Sunday week.',
        zhHans: '当前本地周一至周日记录满 3 条有效信号后，每周复盘开始显示报告。',
        zhHant: '當前本地週一至週日記錄滿 3 條有效信號後，Weekly 開始顯示報告。',
        ja: '現在のローカル月曜〜日曜で有効なシグナルが 3 件になると Weekly レポートを表示します。',
      );
    }

    if (vm.loadState == LoadState.empty) {
      return AppLocaleText.tr(
        context,
        en: 'Weekly is forming. The page shows exact X/3 progress before publishing a report.',
        zhHans: '每周复盘正在形成。达到门槛前只显示明确的 X/3 进度，不发布推断报告。',
        zhHant: 'Weekly 正在形成。達到門檻前只顯示明確的 X/3 進度，不發布推斷報告。',
        ja: 'Weekly は形成中です。条件を満たすまでは X/3 の進捗だけを表示します。',
      );
    }

    if (vm.isLightReady) {
      return AppLocaleText.tr(
        context,
        en: 'A light weekly read is available now. It is early, so this page stays gentle and provisional.',
        zhHans: '这周已经有足够线索开始形成观察了，但还比较早，所以这里只先给温和的阶段观察。',
        zhHant: '這週已經有足夠線索開始形成觀察了，但還比較早，所以這裡先給溫和的階段觀察。',
        ja: '今週は軽い見立てが見られる段階です。まだ早いので、ここではやわらかい途中観察として表示します。',
      );
    }

    return AppLocaleText.tr(
      context,
      en: 'A fuller weekly read is starting to take shape.',
      zhHans: '这周已经开始形成更完整的阶段判断。',
      zhHant: '這週已經開始形成更完整的階段判斷。',
      ja: '今週の見立てが、よりまとまった形になり始めています。',
    );
  }

  String _preferenceText(BuildContext context, String? value) {
    final focusLabel = _focusAreaLabel(context, value);
    return AppLocaleText.tr(
      context,
      en: 'Focus this week: $focusLabel',
      zhHans: '本周关注：$focusLabel',
      zhHant: '本週關注：$focusLabel',
      ja: '今週の注目：$focusLabel',
    );
  }

  String _focusAreaLabel(BuildContext context, String? value) {
    return FocusDomains.labelFor(context, value);
  }
}

void _showWeeklyHint(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
      ),
    );
}

class _WeeklyGoalSummaryInput {
  final String outcome;
  final String burden;
  final String? note;

  const _WeeklyGoalSummaryInput({
    required this.outcome,
    required this.burden,
    this.note,
  });
}

class _WeeklySummaryChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _WeeklySummaryChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: const VisualDensity(vertical: 1),
    );
  }
}

class _WeeklyEmptyReviewState extends StatelessWidget {
  final ReportReadiness readiness;
  final VoidCallback onToday;

  const _WeeklyEmptyReviewState({
    required this.readiness,
    required this.onToday,
  });

  @override
  Widget build(BuildContext context) {
    return _WeeklyGlassCard(
      containerKey: const ValueKey('weekly-empty-card'),
      icon: Icons.auto_awesome_rounded,
      title: AppLocaleText.tr(
        context,
        en: 'Not enough signals yet',
        zhHans: '本周还没有足够信号',
        zhHant: '本週還沒有足夠信號',
        ja: '今週はまだシグナルが足りません',
      ),
      child: Column(
        children: [
          const AuroraSoftIconCircle(
            icon: Icons.auto_awesome_rounded,
            color: AuroraColors.purple,
            size: 64,
            iconSize: 32,
          ),
          const SizedBox(height: AuroraMainPageSpec.sectionGap),
          Text(
            AppLocaleText.tr(
              context,
              en: 'After three or more life signals, Weekly will organize this week’s patterns and next-week suggestions.',
              zhHans: '记录 3 条以上生活信号后，这里会帮你整理本周模式和下周建议。',
              zhHant: '記錄 3 條以上生活信號後，這裡會幫你整理本週模式和下週建議。',
              ja: '生活シグナルが 3 件以上になると、今週のパターンと来週の提案を整理します。',
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF5F687C),
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 14),
          _ReportReadinessProgress(
            readiness: readiness,
            label: AppLocaleText.tr(
              context,
              en: '${readiness.signalCount} / 3 eligible signals this week',
              zhHans: '本周已记录 ${readiness.signalCount} / 3 条有效信号',
              zhHant: '本週已記錄 ${readiness.signalCount} / 3 條有效信號',
              ja: '今週の有効なシグナル ${readiness.signalCount} / 3 件',
            ),
          ),
          const SizedBox(height: AuroraMainPageSpec.sectionGap),
          const _NextWeekExperimentFormingState(),
          const SizedBox(height: AuroraMainPageSpec.sectionGap),
          AuroraPillButton(
            filled: true,
            label: AppLocaleText.tr(
              context,
              en: 'Record today',
              zhHans: '去记录今天',
              zhHant: '去記錄今天',
              ja: '今日を記録する',
            ),
            onPressed: onToday,
          ),
        ],
      ),
    );
  }
}

class _ReportReadinessProgress extends StatelessWidget {
  final ReportReadiness readiness;
  final String label;

  const _ReportReadinessProgress({
    required this.readiness,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      value: '${(readiness.progress * 100).round()}%',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AuroraColors.purple,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              key: const ValueKey('weekly-report-readiness-progress'),
              value: readiness.progress,
              minHeight: 8,
              color: AuroraColors.purple,
              backgroundColor: AuroraColors.purple.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyReadyBody extends StatelessWidget {
  final WeeklyInsightModel weekly;
  final DateTime currentDay;
  final LifeExperimentModel? currentWeekExperiment;
  final LifeExperimentModel? nextWeekExperiment;
  final List<AdoptedMicroActionProgress> activeMicroActions;
  final List<AdoptedLifeExperimentProgress> activeExperiments;
  final EnergyBudgetModel? energyBudget;
  final bool progressLoadFailed;
  final CandidateGenerationStatus candidateStatus;
  final int candidateCount;
  final String? candidatePreviewTitle;
  final String? candidateStaleReason;
  final int candidateEligibleSignalCount;
  final bool candidateRefreshFailed;
  final SubmitState feedbackSubmitState;
  final SubmitState experimentSubmitState;
  final SubmitState attemptFeedbackSubmitState;
  final Future<void> Function(MicroActionModel) onMicroActionTodayTap;
  final Future<void> Function(LifeExperimentModel) onExperimentTodayTap;
  final Future<void> Function(LifeExperimentModel) onGoalWeeklySummaryTap;
  final Future<void> Function(String) onSubmitFeedback;
  final Future<void> Function() onSaveExperiment;
  final Future<void> Function() onRefresh;

  const _WeeklyReadyBody({
    required this.weekly,
    required this.currentDay,
    required this.currentWeekExperiment,
    required this.nextWeekExperiment,
    required this.activeMicroActions,
    required this.activeExperiments,
    required this.energyBudget,
    required this.progressLoadFailed,
    required this.candidateStatus,
    required this.candidateCount,
    required this.candidatePreviewTitle,
    required this.candidateStaleReason,
    required this.candidateEligibleSignalCount,
    required this.candidateRefreshFailed,
    required this.feedbackSubmitState,
    required this.experimentSubmitState,
    required this.attemptFeedbackSubmitState,
    required this.onMicroActionTodayTap,
    required this.onExperimentTodayTap,
    required this.onGoalWeeklySummaryTap,
    required this.onSubmitFeedback,
    required this.onSaveExperiment,
    required this.onRefresh,
  });

  bool get isLightReady => weekly.status == 'light_ready';

  @override
  Widget build(BuildContext context) {
    final topic = weekly.deriveTopicFocus();
    final structure = weekly.deriveV3CStructure();
    final actionPlan = weekly.deriveActionPlan();

    return RefreshIndicator(
      key: const ValueKey('weekly-pull-to-refresh'),
      onRefresh: onRefresh,
      child: ListView(
        key: const ValueKey('weekly-scroll-view'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AuroraMainPageSpec.scrollPadding(context),
        children: [
          _WeeklyHeroHeader(weekly: weekly),
          const SizedBox(height: AuroraMainPageSpec.heroGap),
          _WeeklyAiQuoteCard(
            weekly: weekly,
          ),
          const SizedBox(height: AuroraMainPageSpec.sectionGap),
          _WeeklyReviewReportCard(
            weekly: weekly,
            structure: structure,
            topic: topic,
            currentDay: currentDay,
            activeMicroActions: activeMicroActions,
            activeExperiments: activeExperiments,
            fallbackExperiment: currentWeekExperiment,
            progressLoadFailed: progressLoadFailed,
            isBusy: attemptFeedbackSubmitState == SubmitState.submitting,
            onMicroActionTodayTap: onMicroActionTodayTap,
            onExperimentTodayTap: onExperimentTodayTap,
            onGoalWeeklySummaryTap: onGoalWeeklySummaryTap,
          ),
          const SizedBox(height: AuroraMainPageSpec.sectionGap),
          const _WeeklyProEntryCard(),
          const SizedBox(height: AuroraMainPageSpec.sectionGap),
          _NextWeekExperimentCard(
            actionPlan: actionPlan,
            experiment: nextWeekExperiment,
            candidateStatus: candidateStatus,
            candidateCount: candidateCount,
            candidatePreviewTitle: candidatePreviewTitle,
            candidateStaleReason: candidateStaleReason,
            candidateRefreshFailed: candidateRefreshFailed,
            eligibleSignalCount: candidateEligibleSignalCount,
            weekEnd: weekly.weekEnd,
            energyBudget: energyBudget,
            experimentSubmitState: experimentSubmitState,
            onSaveExperiment: onSaveExperiment,
            onRefresh: onRefresh,
          ),
        ],
      ),
    );
  }
}

class _WeeklyHeroHeader extends StatelessWidget {
  final WeeklyInsightModel? weekly;

  const _WeeklyHeroHeader({this.weekly});

  @override
  Widget build(BuildContext context) {
    final titleSize = AuroraMainPageSpec.responsiveHeroTitleSize(context);
    final compact = MediaQuery.sizeOf(context).width < 360;
    return AuroraCard(
      key: const ValueKey('weekly-hero-header'),
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(24),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFFFFFBF6).withValues(alpha: 0.92),
          const Color(0xFFF5F0FF).withValues(alpha: 0.84),
          const Color(0xFFEEF5FF).withValues(alpha: 0.78),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 160),
          child: Stack(
            children: [
              Positioned(
                key: const ValueKey('weekly-hero-review-pattern'),
                right: compact ? -30 : -22,
                top: compact ? -26 : -32,
                width: compact ? 158 : 184,
                height: compact ? 158 : 184,
                child: const IgnorePointer(
                  child: AuroraReviewHeroPattern(),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 14 : 16,
                  compact ? 13 : 15,
                  compact ? 14 : 16,
                  compact ? 12 : 14,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(right: compact ? 72 : 96),
                      child: AuroraHeroTitle(
                        key: const ValueKey('weekly-hero-title'),
                        text: AppLocaleText.tr(
                          context,
                          en: 'Weekly Review',
                          zhHans: '每周复盘',
                          zhHant: '每週復盤',
                          ja: '今週の振り返り',
                        ),
                        fontSize: titleSize,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    _WeekRangePill(weekly: weekly),
                    const SizedBox(height: 8),
                    Padding(
                      padding: EdgeInsets.only(right: compact ? 46 : 70),
                      child: Text(
                        AppLocaleText.tr(
                          context,
                          en: 'Review this week from Signals, behavior patterns, and real attempts.',
                          zhHans: '从 Signal、行为模式到真实尝试，完整回看这一周。',
                          zhHant: '從 Signal、行為模式到真實嘗試，完整回看這一週。',
                          ja: 'Signal、行動パターン、実際の試みから一週間を振り返ります。',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AuroraColors.ink.withValues(alpha: 0.79),
                              fontSize: compact ? 12.5 : 13.5,
                              height: 1.34,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekRangePill extends StatelessWidget {
  final WeeklyInsightModel? weekly;

  const _WeekRangePill({required this.weekly});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('weekly-range-pill'),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.92)),
        boxShadow: [
          BoxShadow(
            color: AuroraColors.purple.withValues(alpha: 0.11),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_month_rounded,
              size: 14, color: AuroraColors.purple),
          const SizedBox(width: 5),
          Text(
            weekly == null
                ? AppLocaleText.tr(
                    context,
                    en: 'This week',
                    zhHans: '这一周',
                    zhHant: '這一週',
                    ja: '今週',
                  )
                : _formatWeekRange(weekly!.weekStart, weekly!.weekEnd),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AuroraColors.purple,
                  fontSize: AuroraMainPageSpec.supportingSize,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyAiQuoteCard extends StatelessWidget {
  final WeeklyInsightModel weekly;

  const _WeeklyAiQuoteCard({
    required this.weekly,
  });

  @override
  Widget build(BuildContext context) {
    final previous = weekly.previousWeekSummary;
    final summary = previous?.factualSummary.trim();
    final watchpoint = previous?.thisWeekWatchpoint.trim();
    final hasPreviousSignals = previous?.hasSignals ?? false;
    return Container(
      key: const ValueKey('weekly-ai-quote-card'),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFFFCFB).withValues(alpha: 0.86),
            const Color(0xFFF2F0FF).withValues(alpha: 0.78),
            const Color(0xFFFFF6EE).withValues(alpha: 0.78),
          ],
        ),
        borderRadius: BorderRadius.circular(AuroraMainPageSpec.cardRadiusLarge),
        border: Border.all(color: Colors.white.withValues(alpha: 0.90)),
        boxShadow: [
          BoxShadow(
            color: AuroraColors.purple.withValues(alpha: 0.09),
            blurRadius: 26,
            offset: const Offset(0, 13),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Last week, looking back',
                    zhHans: '上周回看',
                    zhHant: '上週回看',
                    ja: '先週を振り返る',
                  ),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AuroraColors.purple,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  summary?.isNotEmpty == true
                      ? summary!
                      : AppLocaleText.tr(
                          context,
                          en: 'There are not enough last-week Signals to look back on yet.',
                          zhHans: '上周还没有足够的 Signal 可以回看。',
                          zhHant: '上週還沒有足夠的 Signal 可以回看。',
                          ja: '先週を振り返るための Signal がまだ十分ではありません。',
                        ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF172440),
                        fontSize: 17,
                        height: 1.38,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  watchpoint?.isNotEmpty == true
                      ? watchpoint!
                      : hasPreviousSignals
                          ? AppLocaleText.tr(
                              context,
                              en: 'This week, notice what repeats before drawing a conclusion.',
                              zhHans: '本周可留意：先观察哪些情况再次出现。',
                              zhHant: '本週可留意：先觀察哪些情況再次出現。',
                              ja: '今週は、結論を急がず何が繰り返すかに目を向けます。',
                            )
                          : AppLocaleText.tr(
                              context,
                              en: 'This week, start with one real Signal whenever it feels useful.',
                              zhHans: '本周可留意：从一条真实的 Signal 开始即可。',
                              zhHant: '本週可留意：從一條真實的 Signal 開始即可。',
                              ja: '今週は、必要なときに一つの実際の Signal から始めます。',
                            ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF647086),
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
          const Positioned(
            right: 0,
            top: 0,
            child: SizedBox(
              key: ValueKey('weekly-ai-quote-badge'),
              width: 40,
              height: 40,
              child: AuroraSectionIcon(
                icon: Icons.auto_awesome_rounded,
                size: 40,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyReviewReportCard extends StatelessWidget {
  final WeeklyInsightModel weekly;
  final WeeklyV3CStructureModel structure;
  final WeeklyTopicFocusModel topic;
  final DateTime currentDay;
  final List<AdoptedMicroActionProgress> activeMicroActions;
  final List<AdoptedLifeExperimentProgress> activeExperiments;
  final LifeExperimentModel? fallbackExperiment;
  final bool progressLoadFailed;
  final bool isBusy;
  final Future<void> Function(MicroActionModel) onMicroActionTodayTap;
  final Future<void> Function(LifeExperimentModel) onExperimentTodayTap;
  final Future<void> Function(LifeExperimentModel) onGoalWeeklySummaryTap;

  const _WeeklyReviewReportCard({
    required this.weekly,
    required this.structure,
    required this.topic,
    required this.currentDay,
    required this.activeMicroActions,
    required this.activeExperiments,
    required this.fallbackExperiment,
    required this.progressLoadFailed,
    required this.isBusy,
    required this.onMicroActionTodayTap,
    required this.onExperimentTodayTap,
    required this.onGoalWeeklySummaryTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('weekly-review-report-card'),
      padding: AuroraMainPageSpec.comfortableCardPadding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.88),
            const Color(0xFFF4F1FF).withValues(alpha: 0.76),
            const Color(0xFFFFF8F1).withValues(alpha: 0.72),
          ],
        ),
        borderRadius: BorderRadius.circular(
          AuroraMainPageSpec.cardRadiusLarge,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.92)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7568A6).withValues(alpha: 0.09),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                key: ValueKey('weekly-report-review-mark'),
                width: 42,
                height: 42,
                child: AuroraReviewHeroPattern(opacity: 0.88),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocaleText.tr(
                        context,
                        en: 'This week’s review report',
                        zhHans: '本周复盘报告',
                        zhHant: '本週復盤報告',
                        ja: '今週の振り返りレポート',
                      ),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: const Color(0xFF213052),
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      AppLocaleText.tr(
                        context,
                        en: 'Signal facts → behavior patterns → results of real attempts',
                        zhHans: 'Signal 事实 → 行为模式 → 真实尝试结果',
                        zhHant: 'Signal 事實 → 行為模式 → 真實嘗試結果',
                        ja: 'Signal の事実 → 行動パターン → 実際の試みの結果',
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AuroraColors.muted,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _WeeklySignalDistributionCard(
            weekly: weekly,
            embedded: true,
          ),
          const _WeeklyReportConnector(),
          _WeeklyBehaviorPatternCard(
            weekly: weekly,
            structure: structure,
            topic: topic,
            embedded: true,
          ),
          const _WeeklyReportConnector(),
          _WeeklyAttemptsCard(
            weekly: weekly,
            currentDay: currentDay,
            activeMicroActions: activeMicroActions,
            activeExperiments: activeExperiments,
            fallbackExperiment: fallbackExperiment,
            progressLoadFailed: progressLoadFailed,
            isBusy: isBusy,
            onMicroActionTodayTap: onMicroActionTodayTap,
            onExperimentTodayTap: onExperimentTodayTap,
            onGoalWeeklySummaryTap: onGoalWeeklySummaryTap,
            embedded: true,
          ),
        ],
      ),
    );
  }
}

class _WeeklyReportConnector extends StatelessWidget {
  const _WeeklyReportConnector();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: SizedBox(
        height: 18,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 1.5,
            height: 18,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AuroraColors.purple.withValues(alpha: 0.48),
                  AuroraColors.blue.withValues(alpha: 0.18),
                ],
              ),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }
}

class _WeeklyReportSection extends StatelessWidget {
  final Key sectionKey;
  final String step;
  final String title;
  final String description;
  final Color color;
  final Widget child;

  const _WeeklyReportSection({
    required this.sectionKey,
    required this.step,
    required this.title,
    required this.description,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: sectionKey,
      padding: const EdgeInsets.fromLTRB(0, 2, 0, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.22)),
                ),
                child: Text(
                  step,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: const Color(0xFF213052),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AuroraColors.muted,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _WeeklySignalDistributionCard extends StatelessWidget {
  final WeeklyInsightModel weekly;
  final bool embedded;

  const _WeeklySignalDistributionCard({
    required this.weekly,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    final rows = _rows(context);
    final readiness = weekly.reportReadiness;
    final recordDays = readiness.distinctDayCount > 0
        ? readiness.distinctDayCount
        : (readiness.signalCount > 0 ? 1 : 0);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: InkWell(
            key: const ValueKey('weekly-open-signal-timeline'),
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.push(_weeklySignalTimelineLocation(weekly)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      AppLocaleText.tr(
                        context,
                        en: 'View weekly Signals',
                        zhHans: '查看本周 Signal',
                        zhHant: '查看本週 Signal',
                        ja: '今週の Signal を見る',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AuroraColors.purple,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 19,
                    color: AuroraColors.purple,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, constraints) {
            final signalMetric = _WeeklyMetricBox(
              icon: Icons.show_chart_rounded,
              color: AuroraColors.purple,
              value: '${readiness.signalCount}',
              label: AppLocaleText.tr(
                context,
                en: 'signals',
                zhHans: '条信号',
                zhHant: '條信號',
                ja: '件のシグナル',
              ),
            );
            final dayMetric = _WeeklyMetricBox(
              icon: Icons.calendar_today_rounded,
              color: AuroraColors.blue,
              value: '$recordDays',
              label: AppLocaleText.tr(
                context,
                en: 'record days',
                zhHans: '个记录日',
                zhHant: '個記錄日',
                ja: '記録日',
              ),
            );
            final stackMetrics = constraints.maxWidth < 290 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.15;
            if (stackMetrics) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  signalMetric,
                  const SizedBox(height: 7),
                  dayMetric,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: signalMetric),
                const SizedBox(width: 8),
                Expanded(child: dayMetric),
              ],
            );
          },
        ),
        if (rows.isNotEmpty) ...[
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final row in rows.take(3))
                  _WeeklyDomainChip(
                    data: row,
                    maxWidth: constraints.maxWidth,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
    if (embedded) {
      return _WeeklyReportSection(
        sectionKey: const ValueKey('weekly-signal-distribution-card'),
        step: '01',
        title: AppLocaleText.tr(
          context,
          en: 'Signal facts',
          zhHans: 'Signal 事实',
          zhHant: 'Signal 事實',
          ja: 'Signal の事実',
        ),
        description: AppLocaleText.tr(
          context,
          en: 'What was recorded this week, without adding interpretation.',
          zhHans: '先看这周记录了什么，不在这里追加解释。',
          zhHant: '先看這週記錄了什麼，不在這裡追加解釋。',
          ja: '今週記録された事実を、解釈を加えずに確認します。',
        ),
        color: AuroraColors.purple,
        child: content,
      );
    }
    return _WeeklyGlassCard(
      containerKey: const ValueKey('weekly-signal-distribution-card'),
      icon: Icons.bubble_chart_rounded,
      title: AppLocaleText.tr(
        context,
        en: 'Signal facts',
        zhHans: 'Signal 事实',
        zhHant: 'Signal 事實',
        ja: 'Signal の事実',
      ),
      child: content,
    );
  }

  List<_DistributionData> _rows(BuildContext context) {
    // Signal facts must be projected only from the underlying Signal rows.
    // Weekly patterns/frictions belong to the next report layer and must not
    // be reused as a made-up distribution when entry detail is unavailable.
    return _rowsFromSignalEntries(context);
  }

  List<_DistributionData> _rowsFromSignalEntries(BuildContext context) {
    final raw = weekly.opportunitySnapshot?['_weekly_signal_entries'];
    if (raw is! List) return const [];
    final counts = <String, int>{};
    for (final item in raw.whereType<Map>()) {
      final map = item.map((key, value) => MapEntry('$key', value));
      final label = _domainFromSignalEntry(context, map);
      counts[label] = (counts[label] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) {
        final countCompare = b.value.compareTo(a.value);
        if (countCompare != 0) return countCompare;
        return a.key.compareTo(b.key);
      });
    return sorted.take(5).map((entry) {
      final index = sorted.indexOf(entry);
      return _DistributionData(
        icon: _domainIcon(entry.key),
        illustrationAsset: _WeeklyIllustrationAsset.forText(entry.key),
        label: entry.key,
        count: entry.value,
        color: _domainColor(entry.key, index),
      );
    }).toList();
  }

  String _domainFromSignalEntry(
    BuildContext context,
    Map<String, dynamic> entry,
  ) {
    final explicitDomains = <String>[
      ..._stringList(entry['focus_domain_id']),
      ..._stringList(entry['focus_domains']),
      ..._stringList(entry['domain_tags']),
      ..._stringList(entry['scene_tags']),
      ..._stringList(entry['category']),
    ];
    for (final value in explicitDomains) {
      final option = FocusDomains.optionFor(value);
      if (option != null) return option.label(context);
    }
    final candidates = <String>[
      ..._stringList(entry['domain_tags']),
      ..._stringList(entry['focus_domains']),
      ..._stringList(entry['scene_tags']),
      ..._stringList(entry['intent_tags']),
      _textFromMap(entry, const ['scene', 'emotion', 'source_type']),
      _textFromMap(entry, const [
        'content',
        'observation',
        'try_next',
        'friction',
        'positive_signal',
        'energy_load',
      ]),
    ].where((value) => value.trim().isNotEmpty).toList();

    final joined = candidates.join(' ');
    if (_containsAny(joined, const [
      '情绪',
      '心情',
      '平静',
      '开心',
      '焦虑',
      '混乱',
      '累',
      '疲惫',
      'emotion',
      'mood',
      'status'
    ])) {
      return '情绪安定';
    }
    if (_containsAny(joined,
        const ['关系', '家人', '朋友', '同事', '伴侣', 'connection', 'relationship'])) {
      return '关系连接';
    }
    if (_containsAny(
        joined, const ['意义', '价值', '方向', 'why', 'meaning', 'value'])) {
      return '价值意义';
    }
    if (_containsAny(joined, const ['边界', '拒绝', '自己的时间', '推着', 'boundary'])) {
      return '自我边界';
    }
    if (_containsAny(
        joined, const ['成长', '计划', '学习', '推进', '目标', 'growth', 'plan'])) {
      return '成长计划';
    }
    if (_containsAny(
        joined, const ['创造', '表达', '写', '画', '作品', 'create', 'creative'])) {
      return '创造表达';
    }
    if (_containsAny(joined, const [
      '饮食',
      '睡眠',
      '睡',
      '晚',
      '午餐',
      '吃',
      '休息',
      '恢复',
      'sleep',
      'food',
      'recovery'
    ])) {
      return '饮食睡眠';
    }
    if (_containsAny(joined,
        const ['环境', '房间', '家里', '整理', '出门', '通勤', 'environment', 'home'])) {
      return '生活环境';
    }
    if (_containsAny(
        joined, const ['兴趣', '爱好', '骑马', '音乐', '游戏', 'hobby', 'interest'])) {
      return '兴趣爱好';
    }
    return '情绪安定';
  }

  List<String> _stringList(Object? raw) {
    if (raw is List) {
      return raw
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    final text = raw?.toString().trim();
    if (text == null || text.isEmpty) return const [];
    return [text];
  }

  bool _containsAny(String text, List<String> needles) {
    final lower = text.toLowerCase();
    return needles.any((needle) => lower.contains(needle.toLowerCase()));
  }

  int _maxCount(List<_DistributionData> rows) {
    if (rows.isEmpty) return 1;
    return rows.map((row) => row.count).reduce(math.max);
  }

  String _textFromMap(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return '';
  }

  IconData _domainIcon(String label) {
    if (label.contains('情绪')) return Icons.mood_rounded;
    if (label.contains('关系')) return Icons.groups_rounded;
    if (label.contains('价值')) return Icons.stars_rounded;
    if (label.contains('边界')) return Icons.shield_rounded;
    if (label.contains('成长')) return Icons.spa_rounded;
    if (label.contains('创造')) return Icons.brush_rounded;
    if (label.contains('饮食') || label.contains('睡眠')) {
      return Icons.nightlight_round;
    }
    if (label.contains('环境')) return Icons.home_rounded;
    if (label.contains('兴趣')) return Icons.favorite_rounded;
    return Icons.auto_awesome_rounded;
  }

  Color _domainColor(String label, int index) {
    if (label.contains('情绪')) return AuroraColors.orange;
    if (label.contains('边界')) return AuroraColors.purple;
    if (label.contains('饮食') || label.contains('睡眠')) {
      return const Color(0xFF48C9CE);
    }
    if (label.contains('成长')) return AuroraColors.blue;
    if (label.contains('兴趣')) return const Color(0xFFF07CB9);
    if (label.contains('关系')) return const Color(0xFF8D7AF6);
    if (label.contains('价值')) return const Color(0xFFFFC45B);
    if (label.contains('创造')) return const Color(0xFFFF8BC6);
    if (label.contains('环境')) return const Color(0xFF74D9A4);
    const palette = [
      AuroraColors.purple,
      AuroraColors.orange,
      Color(0xFF48C9CE),
      AuroraColors.blue,
    ];
    return palette[index % palette.length];
  }

  String _weeklySignalTimelineLocation(WeeklyInsightModel weekly) {
    final datedSignals = weekly.chartData
        .where((point) => point.signalCount > 0)
        .map((point) => DateTime.tryParse(point.date))
        .whereType<DateTime>()
        .toList(growable: false)
      ..sort();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekEnd = DateTime.tryParse(weekly.weekEnd);
    final anchor = datedSignals.isNotEmpty
        ? datedSignals.last
        : (weekEnd != null && weekEnd.isBefore(today) ? weekEnd : today);
    final date = '${anchor.year.toString().padLeft(4, '0')}-'
        '${anchor.month.toString().padLeft(2, '0')}-'
        '${anchor.day.toString().padLeft(2, '0')}';
    return Uri(
      path: AppRoutes.todayDiary,
      queryParameters: {'date': date},
    ).toString();
  }
}

class _WeeklyMetricBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _WeeklyMetricBox({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AuroraColors.line.withValues(alpha: 0.72)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 19, color: color),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF172440),
                      height: 1.05,
                      fontWeight: FontWeight.w700,
                    ),
                children: [
                  TextSpan(
                    text: '$value\n',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(text: label),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyDomainChip extends StatelessWidget {
  final _DistributionData data;
  final double maxWidth;

  const _WeeklyDomainChip({
    required this.data,
    required this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.50),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AuroraColors.line.withValues(alpha: 0.70)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(data.icon, size: 17, color: data.color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                data.label,
                maxLines: 2,
                softWrap: true,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: const Color(0xFF25324D),
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            const SizedBox(width: 7),
            Text(
              '${data.count}',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: const Color(0xFF172440),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyBehaviorPatternCard extends StatelessWidget {
  final WeeklyInsightModel weekly;
  final WeeklyV3CStructureModel structure;
  final WeeklyTopicFocusModel topic;
  final bool embedded;

  const _WeeklyBehaviorPatternCard({
    required this.weekly,
    required this.structure,
    required this.topic,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    final blocks = _patternBlocks(context);
    final content = LayoutBuilder(
      builder: (context, constraints) {
        final stack = constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.15;
        final tileWidth =
            stack ? constraints.maxWidth : (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var index = 0; index < blocks.length; index++)
              SizedBox(
                key: ValueKey('weekly-pattern-block-$index'),
                width: tileWidth,
                child: _WeeklyPatternBlockTile(data: blocks[index]),
              ),
          ],
        );
      },
    );
    if (embedded) {
      return _WeeklyReportSection(
        sectionKey: const ValueKey('weekly-behavior-pattern-card'),
        step: '02',
        title: AppLocaleText.tr(
          context,
          en: 'Behavior patterns',
          zhHans: '行为模式',
          zhHant: '行為模式',
          ja: '行動パターン',
        ),
        description: AppLocaleText.tr(
          context,
          en: 'One to three grounded patterns distilled from multiple eligible Signals.',
          zhHans: '从多条有效 Signal 中提炼 1–3 条有来源可追溯的行为模式。',
          zhHant: '從多條有效 Signal 中提煉 1–3 條可追溯來源的行為模式。',
          ja: '複数の有効な Signal から、根拠をたどれる行動パターンを 1〜3 件整理します。',
        ),
        color: AuroraColors.orange,
        child: content,
      );
    }
    return _WeeklyGlassCard(
      containerKey: const ValueKey('weekly-behavior-pattern-card'),
      icon: Icons.account_tree_rounded,
      title: AppLocaleText.tr(
        context,
        en: 'Behavior patterns',
        zhHans: '行为模式',
        zhHant: '行為模式',
        ja: '行動パターン',
      ),
      child: content,
    );
  }

  List<_WeeklyPatternBlockData> _patternBlocks(BuildContext context) {
    final groundedPatterns = weekly.behaviorPatterns;
    if (groundedPatterns.isNotEmpty) {
      final palette = [
        AuroraColors.purple,
        AuroraColors.orange,
        AuroraColors.blue,
      ];
      return groundedPatterns.indexed.map((entry) {
        final pattern = entry.$2;
        final dates = pattern.supportDates;
        final trace = dates.isEmpty
            ? AppLocaleText.tr(
                context,
                en: 'Supported by ${pattern.sourceSignalCardIds.length} Signals.',
                zhHans: '由 ${pattern.sourceSignalCardIds.length} 条 Signal 支持。',
                zhHant: '由 ${pattern.sourceSignalCardIds.length} 條 Signal 支持。',
                ja: 'Signal ${pattern.sourceSignalCardIds.length} 件が根拠です。',
              )
            : AppLocaleText.tr(
                context,
                en: 'Seen on ${dates.join(', ')}.',
                zhHans: '支持日期：${dates.join('、')}。',
                zhHant: '支持日期：${dates.join('、')}。',
                ja: '確認日：${dates.join('・')}。',
              );
        return _WeeklyPatternBlockData(
          label: pattern.label,
          body: '${pattern.summary}\n$trace',
          icon: _iconForText('${pattern.kind} ${pattern.label}'),
          color: palette[entry.$1 % palette.length],
        );
      }).toList(growable: false);
    }
    final rawPatterns = weekly.patterns
        .whereType<Map>()
        .map((map) => map.map((key, value) => MapEntry('$key', value)))
        .where((map) => !_isSignalSourceItem(map))
        .toList(growable: false);
    final explicit = rawPatterns.isEmpty ? null : rawPatterns.first;
    final structured = explicit == null
        ? const <String, String>{}
        : <String, String>{
            'trigger': _textFromMap(
              explicit,
              const ['trigger', 'trigger_point'],
            ),
            'reaction': _textFromMap(
              explicit,
              const ['reaction', 'typical_reaction'],
            ),
            'short_result': _textFromMap(
              explicit,
              const ['short_result', 'short_term_result'],
            ),
            'long_impact': _textFromMap(
              explicit,
              const ['long_impact', 'long_term_impact'],
            ),
          };
    if (structured.values.any((value) => value.trim().isNotEmpty)) {
      final forming = AppLocaleText.tr(
        context,
        en: 'This layer is still forming from this week’s Signals.',
        zhHans: '本周 Signal 还不足以形成这一层。',
        zhHant: '本週 Signal 還不足以形成這一層。',
        ja: 'この層は今週の Signal からまだ形成中です。',
      );
      final longForming = AppLocaleText.tr(
        context,
        en: 'Long-term impact needs more weeks of Signals.',
        zhHans: '长期影响需要更多周的 Signal 才能判断。',
        zhHant: '長期影響需要更多週的 Signal 才能判斷。',
        ja: '長期的な影響には、さらに数週間の Signal が必要です。',
      );
      return [
        _WeeklyPatternBlockData(
          label: AppLocaleText.tr(
            context,
            en: 'Trigger',
            zhHans: '触发点',
            zhHant: '觸發點',
            ja: 'きっかけ',
          ),
          body: _valueOr(structured['trigger']!, forming),
          icon: Icons.chat_bubble_outline_rounded,
          color: AuroraColors.purple,
        ),
        _WeeklyPatternBlockData(
          label: AppLocaleText.tr(
            context,
            en: 'Typical response',
            zhHans: '典型反应',
            zhHant: '典型反應',
            ja: '典型的な反応',
          ),
          body: _valueOr(structured['reaction']!, forming),
          icon: Icons.flash_on_rounded,
          color: AuroraColors.orange,
        ),
        _WeeklyPatternBlockData(
          label: AppLocaleText.tr(
            context,
            en: 'Short-term result',
            zhHans: '短期结果',
            zhHant: '短期結果',
            ja: '短期的な結果',
          ),
          body: _valueOr(structured['short_result']!, forming),
          icon: Icons.track_changes_rounded,
          color: AuroraColors.blue,
        ),
        _WeeklyPatternBlockData(
          label: AppLocaleText.tr(
            context,
            en: 'Long-term impact',
            zhHans: '长期影响',
            zhHant: '長期影響',
            ja: '長期的な影響',
          ),
          body: _valueOr(structured['long_impact']!, longForming),
          icon: Icons.spa_rounded,
          color: AuroraColors.mint,
        ),
      ];
    }

    final steps = _stepsFromWeekly(context);
    return steps
        .take(4)
        .map(
          (step) => _WeeklyPatternBlockData(
            label: step.title,
            body: step.body,
            icon: step.icon,
            color: step.color,
          ),
        )
        .toList(growable: false);
  }

  bool _isSignalSourceItem(Map<String, dynamic> map) {
    final title = _textFromMap(map, const ['name', 'title', 'pattern'])
        .trim()
        .toLowerCase();
    return title == '证据来源' ||
        title == '證據來源' ||
        title == 'signal source' ||
        title == 'evidence source';
  }

  String _valueOr(String value, String fallback) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  List<_BehaviorStep> _stepsFromWeekly(BuildContext context) {
    final rawSteps = <Map<String, dynamic>>[];
    rawSteps.addAll(
      weekly.patterns
          .whereType<Map>()
          .map(
            (map) => map.map((key, value) => MapEntry('$key', value)),
          )
          .where((map) => !_isSignalSourceItem(map))
          .take(3),
    );
    if (rawSteps.length < 3) {
      rawSteps.addAll(
        weekly.frictions.whereType<Map>().take(3 - rawSteps.length).map(
              (map) => map.map((key, value) => MapEntry('$key', value)),
            ),
      );
    }
    final steps = <_BehaviorStep>[];
    for (final map in rawSteps) {
      final title = _textFromMap(map, const ['name', 'title', 'pattern']);
      final body =
          _textFromMap(map, const ['summary', 'description', 'reason']);
      final hint = _illustrationHintFromMap(map);
      if (title.isEmpty && body.isEmpty) continue;
      steps.add(
        _BehaviorStep(
          icon: _iconForText('$hint $title $body'),
          illustrationAsset:
              _WeeklyIllustrationAsset.forText('$hint $title $body'),
          title: title.isNotEmpty ? title : topic.headline,
          body: _compact(body, topic.reason),
          color: steps.length == 2 ? AuroraColors.blue : AuroraColors.purple,
        ),
      );
    }
    if (steps.isNotEmpty) return steps;
    return [
      _BehaviorStep(
        icon: Icons.hourglass_top_rounded,
        illustrationAsset: _WeeklyIllustrationAsset.forText(
          '只是观察也有帮助',
        ),
        title: AppLocaleText.tr(
          context,
          en: 'Pattern still forming',
          zhHans: '模式仍在形成',
          zhHant: '模式仍在形成',
          ja: 'パターンは形成中',
        ),
        body: AppLocaleText.tr(
          context,
          en: 'This week’s Signals are shown in the facts layer. More repeated relationships are needed before a pattern is stated.',
          zhHans: '本周 Signal 已在事实层展示；还需要更多重复关系，才能形成模式判断。',
          zhHant: '本週 Signal 已在事實層展示；還需要更多重複關係，才能形成模式判斷。',
          ja: '今週の Signal は事実の層に表示されています。パターンを述べるには、さらに繰り返す関係が必要です。',
        ),
        color: AuroraColors.purple,
      ),
    ];
  }

  List<_BehaviorStep> _stepsFromSignalEntries(BuildContext context) {
    final entries = _weeklySignalEntries();
    if (entries.isEmpty) return const [];

    final buckets = <String, List<Map<String, dynamic>>>{};
    for (final entry in entries) {
      final key = _signalBucketKey(entry);
      buckets.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(entry);
    }

    final sorted = buckets.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    final palette = [
      AuroraColors.orange,
      AuroraColors.purple,
      AuroraColors.blue,
      const Color(0xFF48C9CE),
    ];

    return sorted.take(3).map((bucket) {
      final sample = bucket.value.first;
      final displayTitle = _localizedSignalTag(context, bucket.key);
      final body = _compact(
        _signalBody(sample),
        '${bucket.value.length} 条信号里出现过这个线索。',
      );
      final hint = _signalIllustrationHint(sample, bucket.key, body);
      return _BehaviorStep(
        icon: _iconForText('$hint ${bucket.key} $body'),
        illustrationAsset: _WeeklyIllustrationAsset.forText(
          '$hint ${bucket.key} $body',
        ),
        title: displayTitle,
        body: bucket.value.length > 1
            ? '$body · ${bucket.value.length} 条信号'
            : body,
        color: palette[sorted.indexOf(bucket) % palette.length],
      );
    }).toList();
  }

  String _localizedSignalTag(BuildContext context, String raw) {
    final normalized = raw.trim().toLowerCase().replaceAll('-', '_');
    return switch (normalized) {
      'work' || 'work_tasks' => AppLocaleText.tr(
          context,
          en: 'Work',
          zhHans: '工作',
          zhHant: '工作',
          ja: '仕事',
        ),
      'commute' => AppLocaleText.tr(
          context,
          en: 'Commute',
          zhHans: '通勤',
          zhHant: '通勤',
          ja: '移動',
        ),
      'household' || 'home' => AppLocaleText.tr(
          context,
          en: 'Home',
          zhHans: '家务',
          zhHant: '家務',
          ja: '家事',
        ),
      'relationship' || 'relationships' => AppLocaleText.tr(
          context,
          en: 'Relationships',
          zhHans: '关系',
          zhHant: '關係',
          ja: '人間関係',
        ),
      'growth_plan' || 'growth' => AppLocaleText.tr(
          context,
          en: 'Growth plan',
          zhHans: '成长计划',
          zhHant: '成長計劃',
          ja: '成長計画',
        ),
      'recovery' || 'restoring' => AppLocaleText.tr(
          context,
          en: 'Recovery',
          zhHans: '恢复',
          zhHant: '恢復',
          ja: '回復',
        ),
      'interest' || 'interests' || 'hobby' || 'hobbies' => AppLocaleText.tr(
          context,
          en: 'Interests',
          zhHans: '兴趣',
          zhHant: '興趣',
          ja: '趣味',
        ),
      'schedule' || 'arrangement' => AppLocaleText.tr(
          context,
          en: 'Schedule',
          zhHans: '安排',
          zhHant: '安排',
          ja: '予定',
        ),
      'emotion' || 'emotional' || 'mood' => AppLocaleText.tr(
          context,
          en: 'Emotions',
          zhHans: '情绪',
          zhHant: '情緒',
          ja: '感情',
        ),
      'voice' || 'voice_signal' => AppLocaleText.tr(
          context,
          en: 'Voice signal',
          zhHans: '语音信号',
          zhHant: '語音信號',
          ja: '音声シグナル',
        ),
      'status' || 'quick_status' || 'status_signal' => AppLocaleText.tr(
          context,
          en: 'Status signal',
          zhHans: '状态信号',
          zhHant: '狀態信號',
          ja: '状態シグナル',
        ),
      'ai_predicted' || 'ai_prediction' => AppLocaleText.tr(
          context,
          en: 'AI prediction signal',
          zhHans: 'AI 预判信号',
          zhHant: 'AI 預判信號',
          ja: 'AI 予測シグナル',
        ),
      _ => raw.trim(),
    };
  }

  String _illustrationHintFromMap(Map<String, dynamic> map) {
    final explicit = _textFromMap(map, const [
      'illustration_hint',
      'illustrationHint',
      'visual_hint',
      'visualHint',
      'illustration_keyword',
      'illustrationKeyword',
      'asset_hint',
      'assetHint',
    ]);
    if (explicit.isNotEmpty) return explicit;
    final title = _textFromMap(map, const ['name', 'title', 'pattern']);
    final body = _textFromMap(map, const ['summary', 'description', 'reason']);
    return _deriveIllustrationHint('$title $body');
  }

  List<Map<String, dynamic>> _weeklySignalEntries() {
    final raw = weekly.opportunitySnapshot?['_weekly_signal_entries'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((map) => map.map((key, value) => MapEntry('$key', value)))
        .where(
          (map) =>
              map.isNotEmpty &&
              !_textFromMap(map, const ['source_type', 'sourceType'])
                  .toLowerCase()
                  .contains('schedule'),
        )
        .toList();
  }

  String _signalBucketKey(Map<String, dynamic> entry) {
    for (final key in const ['scene_tags', 'intent_tags', 'domain_tags']) {
      final tags = _stringList(entry[key]);
      if (tags.isNotEmpty) return tags.first;
    }
    final sourceType = _textFromMap(entry, const ['source_type', 'sourceType']);
    if (sourceType.isNotEmpty && sourceType != 'text') {
      return sourceType;
    }
    final emotion = _textFromMap(entry, const ['emotion', 'mood']);
    if (emotion.isNotEmpty) return emotion;
    return '本周信号';
  }

  String _signalBody(Map<String, dynamic> entry) {
    final body = _textFromMap(entry, const [
      'content',
      'observation',
      'try_next',
      'tryNext',
      'positive_signal',
      'friction',
      'energy_load',
      'acknowledgement',
    ]);
    return _compact(body, topic.reason);
  }

  String _signalIllustrationHint(
    Map<String, dynamic> entry,
    String bucket,
    String body,
  ) {
    final explicit = _textFromMap(entry, const [
      'illustration_hint',
      'illustrationHint',
      'visual_hint',
      'visualHint',
    ]);
    if (explicit.isNotEmpty) return explicit;
    return _deriveIllustrationHint('$bucket $body ${entry.values.join(' ')}');
  }

  String _deriveIllustrationHint(String text) {
    if (_hasAny(text, const ['任务', '堆', '太多', 'todo'])) {
      return '任务堆积，开始变困难';
    }
    if (_hasAny(text, const ['会议', '开会'])) return '会议密集，注意力被切碎';
    if (_hasAny(text, const ['临时', '变化', '打断'])) {
      return '临时变化打断原本节奏';
    }
    if (_hasAny(text, const ['休息', '恢复', '挤'])) return '休息时间被任务挤掉';
    if (_hasAny(text, const ['空转', '停不下来'])) {
      return '想休息，但停下来后反而空转';
    }
    if (_hasAny(text, const ['手机', '短视频', '刷'])) return '晚上刷手机变多';
    if (_hasAny(text, const ['早上', '启动'])) return '早上启动困难';
    if (_hasAny(text, const ['中午', '午后', '下午', '精力'])) {
      return '中午以后精力明显下降';
    }
    if (_hasAny(text, const ['日程', '安排', '密度'])) {
      return '情绪被日程密度带着走';
    }
    if (_hasAny(text, const ['焦虑', '紧张', '还没开始'])) {
      return '焦虑提前出现，还没开始就紧张';
    }
    if (_hasAny(text, const ['完成', '做完', '更累'])) {
      return '做完事后更累，不是更轻松';
    }
    if (_hasAny(text, const ['计划', '目标', '太大'])) {
      return '计划越大，越容易不开始';
    }
    if (_hasAny(text, const ['分散', '目标太多'])) return '目标太多，注意力分散';
    if (_hasAny(text, const ['创作', '创造', '工作'])) return '创作被工作挤掉';
    if (_hasAny(text, const ['拒绝', '边界', '自己的时间'])) {
      return '不敢拒绝，自己的时间被挤占';
    }
    if (_hasAny(text, const ['迎合', '疲惫'])) return '过度迎合后感到疲惫';
    if (_hasAny(text, const ['表达', '说不清'])) return '想表达，但说不清';
    if (_hasAny(text, const ['独处'])) return '独处不足，恢复变慢';
    if (_hasAny(text, const ['环境', '房间', '混乱'])) return '生活环境混乱，心情也乱';
    if (_hasAny(text, const ['关系', '对话', '内耗'])) return '关系对话后反复内耗';
    if (_hasAny(text, const ['金钱', '钱', '现实压力'])) {
      return '金钱或现实压力牵动安全感';
    }
    if (_hasAny(text, const ['身体', '累'])) return '身体信号先出现，才意识到累';
    if (_hasAny(text, const ['有效', '稳定'])) return '小实验有效，节奏开始稳定';
    if (_hasAny(text, const ['兴趣', '爱好'])) return '兴趣活动带来恢复感';
    return '只是观察也有帮助';
  }

  bool _hasAny(String text, List<String> tokens) {
    final lower = text.toLowerCase();
    return tokens.any((token) => lower.contains(token.toLowerCase()));
  }

  List<String> _stringList(Object? raw) {
    if (raw is List) {
      return raw
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    final text = raw?.toString().trim();
    if (text == null || text.isEmpty) return const [];
    return [text];
  }

  String _textFromMap(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return '';
  }

  IconData _iconForText(String text) {
    if (text.contains('安排') || text.contains('会议')) {
      return Icons.calendar_month_rounded;
    }
    if (text.contains('休息') || text.contains('恢复')) {
      return Icons.schedule_rounded;
    }
    if (text.contains('睡') || text.contains('晚')) {
      return Icons.nights_stay_rounded;
    }
    if (text.contains('关系')) return Icons.groups_rounded;
    if (text.contains('边界')) return Icons.shield_rounded;
    if (text.contains('创造')) return Icons.brush_rounded;
    return Icons.auto_awesome_rounded;
  }
}

class _WeeklyPatternBlockData {
  final String label;
  final String body;
  final IconData icon;
  final Color color;

  const _WeeklyPatternBlockData({
    required this.label,
    required this.body,
    required this.icon,
    required this.color,
  });
}

class _WeeklyPatternBlockTile extends StatelessWidget {
  final _WeeklyPatternBlockData data;

  const _WeeklyPatternBlockTile({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 116),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.78),
            data.color.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: data.color.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AuroraSoftIconCircle(
                icon: data.icon,
                color: data.color,
                size: 30,
                iconSize: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  data.label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: const Color(0xFF25324D),
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            data.body,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF536077),
                  height: 1.42,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyAttemptsCard extends StatelessWidget {
  final WeeklyInsightModel weekly;
  final DateTime currentDay;
  final List<AdoptedMicroActionProgress> activeMicroActions;
  final List<AdoptedLifeExperimentProgress> activeExperiments;
  final LifeExperimentModel? fallbackExperiment;
  final bool progressLoadFailed;
  final bool isBusy;
  final bool embedded;
  final Future<void> Function(MicroActionModel) onMicroActionTodayTap;
  final Future<void> Function(LifeExperimentModel) onExperimentTodayTap;
  final Future<void> Function(LifeExperimentModel) onGoalWeeklySummaryTap;

  const _WeeklyAttemptsCard({
    required this.weekly,
    required this.currentDay,
    required this.activeMicroActions,
    required this.activeExperiments,
    required this.fallbackExperiment,
    required this.progressLoadFailed,
    required this.isBusy,
    this.embedded = false,
    required this.onMicroActionTodayTap,
    required this.onExperimentTodayTap,
    required this.onGoalWeeklySummaryTap,
  });

  @override
  Widget build(BuildContext context) {
    final feedbackIllustration = WeeklyReviewIllustrationSelector.select(
      opportunitySnapshot: weekly.opportunitySnapshot,
      actionReview: weekly.actionReview.toMap(),
    );
    final items = <_WeeklyAttemptDisplayItem>[
      for (final item in activeMicroActions)
        _WeeklyAttemptDisplayItem(
          title: item.action.title,
          kind: AppLocaleText.tr(
            context,
            en: 'Small experiment',
            zhHans: '小实验',
            zhHant: '小實驗',
            ja: '小実験',
          ),
          icon: Icons.spa_rounded,
          color: AuroraColors.mint,
          progress: item.progress,
          sourceChanged: item.action.sourceChanged,
          action: item.action,
        ),
      for (final item in activeExperiments)
        _WeeklyAttemptDisplayItem(
          title: item.experiment.title,
          kind: AppLocaleText.tr(
            context,
            en: 'Goal',
            zhHans: '目标',
            zhHant: '目標',
            ja: '目標',
          ),
          icon: Icons.science_rounded,
          color: AuroraColors.blue,
          progress: item.progress,
          sourceChanged: item.experiment.sourceChanged,
          experiment: item.experiment,
        ),
      if (activeExperiments.isEmpty && fallbackExperiment != null)
        _WeeklyAttemptDisplayItem(
          title: fallbackExperiment!.title,
          kind: AppLocaleText.tr(
            context,
            en: 'Goal',
            zhHans: '目标',
            zhHant: '目標',
            ja: '目標',
          ),
          icon: Icons.science_rounded,
          color: AuroraColors.blue,
          progress: SevenDayProgressModel(
            subjectId: fallbackExperiment!.id,
            startDate: weekly.weekStart,
            endDate: weekly.weekEnd,
            cells: [
              for (final day in _weekDays())
                SevenDayProgressCell(
                  localDate: _dateKey(day),
                  state: ProgressCellState.empty,
                ),
            ],
          ),
          sourceChanged: fallbackExperiment!.sourceChanged,
          experiment: fallbackExperiment,
        ),
    ];
    final days = _weekDays();
    final recordedDates = <String>{};
    var recordedItemDays = 0;
    var completedItemDays = 0;
    for (final item in items) {
      for (final cell in item.progress.cells) {
        if (cell.state != ProgressCellState.empty) {
          recordedItemDays += 1;
          recordedDates.add(cell.localDate);
        }
        if (cell.state == ProgressCellState.completed) {
          completedItemDays += 1;
        }
      }
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (progressLoadFailed) const _WeeklyProgressLoadWarning(),
        if (feedbackIllustration != null) ...[
          _WeeklyAttemptFeedbackArtwork(selection: feedbackIllustration),
          const SizedBox(height: 12),
        ],
        if (items.isEmpty)
          _WeeklyAttemptEmptyRow(
            icon: Icons.spa_rounded,
            color: AuroraColors.mint,
            kind: AppLocaleText.tr(
              context,
              en: 'No attempts yet',
              zhHans: '本周还没有尝试记录',
              zhHant: '本週還沒有嘗試記錄',
              ja: '今週の試みはまだありません',
            ),
            message: AppLocaleText.tr(
              context,
              en: 'Adopted small experiments and goals will appear here by day.',
              zhHans: '采纳的小实验和目标会按周一至周日显示在这里。',
              zhHant: '採納的小實驗和目標會按週一至週日顯示在這裡。',
              ja: '採用した小実験と目標が曜日ごとに表示されます。',
            ),
          )
        else ...[
          _WeeklyAttemptTotals(
            itemCount: items.length,
            recordedDayCount: recordedDates.length,
            completedItemDays: completedItemDays,
          ),
          const SizedBox(height: 12),
          _WeeklyDayHeader(days: days),
          const SizedBox(height: 7),
          for (var index = 0; index < items.length; index++) ...[
            _WeeklyAttemptMatrixRow(
              item: items[index],
              days: days,
              today: currentDay,
              isBusy: isBusy,
              onTodayTap: () async {
                final action = items[index].action;
                if (action != null) {
                  await onMicroActionTodayTap(action);
                  return;
                }
                final experiment = items[index].experiment;
                if (experiment != null) {
                  await onExperimentTodayTap(experiment);
                }
              },
              onWeeklySummaryTap: items[index].experiment == null
                  ? null
                  : () => onGoalWeeklySummaryTap(items[index].experiment!),
            ),
            if (index != items.length - 1) const SizedBox(height: 12),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.touch_app_rounded,
                size: 17,
                color: AuroraColors.purple,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Tap today’s cell to record it. Other days are read-only.',
                    zhHans: '点击今天的格子可登记；其他日期保持只读。',
                    zhHant: '點擊今天的格子可登記；其他日期保持唯讀。',
                    ja: '今日のマスをタップして記録できます。ほかの日は読み取り専用です。',
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AuroraColors.muted,
                        height: 1.35,
                      ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        _WeeklyAttemptFacts(
          itemCount: items.length,
          recordedItemDays: recordedItemDays,
          completedItemDays: completedItemDays,
          recordedDates: recordedDates,
          signalDates: weekly.chartData
              .where((point) => point.signalCount > 0)
              .map((point) => point.date)
              .toSet(),
        ),
      ],
    );
    if (embedded) {
      return _WeeklyReportSection(
        sectionKey: const ValueKey('weekly-action-review-card'),
        step: '03',
        title: AppLocaleText.tr(
          context,
          en: 'Attempt results',
          zhHans: '尝试结果',
          zhHant: '嘗試結果',
          ja: '試みの結果',
        ),
        description: AppLocaleText.tr(
          context,
          en: 'What you joined, which days were recorded, and what was completed.',
          zhHans: '回看参与了什么、哪些天登记过，以及实际完成情况。',
          zhHant: '回看參與了什麼、哪些天登記過，以及實際完成情況。',
          ja: '参加した内容、記録した日、実際の完了状況を振り返ります。',
        ),
        color: AuroraColors.mint,
        child: content,
      );
    }
    return _WeeklyGlassCard(
      containerKey: const ValueKey('weekly-action-review-card'),
      icon: Icons.view_week_rounded,
      title: AppLocaleText.tr(
        context,
        en: 'Attempt results',
        zhHans: '尝试结果',
        zhHant: '嘗試結果',
        ja: '試みの結果',
      ),
      child: content,
    );
  }

  List<DateTime> _weekDays() {
    final parsed = DateTime.tryParse(weekly.weekStart);
    final anchor = parsed ??
        DateTime(currentDay.year, currentDay.month, currentDay.day).subtract(
          Duration(days: currentDay.weekday - DateTime.monday),
        );
    return List.generate(7, (index) => anchor.add(Duration(days: index)));
  }

  String _dateKey(DateTime value) => '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

class _WeeklyAttemptFeedbackArtwork extends StatelessWidget {
  final WeeklyReviewIllustrationSelection selection;

  const _WeeklyAttemptFeedbackArtwork({required this.selection});

  @override
  Widget build(BuildContext context) {
    final description = AppLocaleText.tr(
      context,
      en: 'Selected from ${selection.count} real attempt feedback record(s)',
      zhHans: '根据 ${selection.count} 条真实尝试反馈选择',
      zhHant: '根據 ${selection.count} 條真實嘗試回饋選擇',
      ja: '実際の試行フィードバック ${selection.count} 件から選択',
    );
    return Semantics(
      key: ValueKey(
        'weekly-attempt-feedback-illustration-${selection.definition.id}',
      ),
      image: true,
      label: description,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.64),
              AuroraColors.mint.withValues(alpha: 0.07),
              AuroraColors.purple.withValues(alpha: 0.06),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AuroraColors.line.withValues(alpha: 0.62),
          ),
        ),
        child: Row(
          children: [
            ExcludeSemantics(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  selection.definition.asset,
                  key: ValueKey(
                    'weekly-attempt-feedback-asset-${selection.definition.id}',
                  ),
                  width: 68,
                  height: 68,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocaleText.tr(
                      context,
                      en: 'This week’s attempt feedback',
                      zhHans: '本周尝试反馈',
                      zhHant: '本週嘗試回饋',
                      ja: '今週の試行フィードバック',
                    ),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AuroraColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AuroraColors.muted,
                          height: 1.35,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyAttemptDisplayItem {
  final String title;
  final String kind;
  final IconData icon;
  final Color color;
  final SevenDayProgressModel progress;
  final bool sourceChanged;
  final MicroActionModel? action;
  final LifeExperimentModel? experiment;

  const _WeeklyAttemptDisplayItem({
    required this.title,
    required this.kind,
    required this.icon,
    required this.color,
    required this.progress,
    required this.sourceChanged,
    this.action,
    this.experiment,
  });
}

class _WeeklyAttemptTotals extends StatelessWidget {
  final int itemCount;
  final int recordedDayCount;
  final int completedItemDays;

  const _WeeklyAttemptTotals({
    required this.itemCount,
    required this.recordedDayCount,
    required this.completedItemDays,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        _WeeklyAttemptMetricChip(
          key: const ValueKey('weekly-attempt-item-count'),
          label: AppLocaleText.tr(
            context,
            en: '$itemCount attempts',
            zhHans: '参与 $itemCount 项',
            zhHant: '參與 $itemCount 項',
            ja: '$itemCount 件に参加',
          ),
        ),
        _WeeklyAttemptMetricChip(
          key: const ValueKey('weekly-attempt-recorded-days'),
          label: AppLocaleText.tr(
            context,
            en: '$recordedDayCount recorded days',
            zhHans: '登记 $recordedDayCount 天',
            zhHant: '登記 $recordedDayCount 天',
            ja: '$recordedDayCount 日記録',
          ),
        ),
        _WeeklyAttemptMetricChip(
          key: const ValueKey('weekly-attempt-completed-count'),
          label: AppLocaleText.tr(
            context,
            en: '$completedItemDays completions',
            zhHans: '完成 $completedItemDays 次',
            zhHant: '完成 $completedItemDays 次',
            ja: '$completedItemDays 回完了',
          ),
        ),
      ],
    );
  }
}

class _WeeklyAttemptMetricChip extends StatelessWidget {
  final String label;

  const _WeeklyAttemptMetricChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AuroraColors.purple.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AuroraColors.purple.withValues(alpha: 0.12),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: const Color(0xFF59627A),
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _WeeklyDayHeader extends StatelessWidget {
  final List<DateTime> days;

  const _WeeklyDayHeader({required this.days});

  @override
  Widget build(BuildContext context) {
    final labels = <String>[
      AppLocaleText.tr(context, en: 'M', zhHans: '一', zhHant: '一', ja: '月'),
      AppLocaleText.tr(context, en: 'T', zhHans: '二', zhHant: '二', ja: '火'),
      AppLocaleText.tr(context, en: 'W', zhHans: '三', zhHant: '三', ja: '水'),
      AppLocaleText.tr(context, en: 'T', zhHans: '四', zhHant: '四', ja: '木'),
      AppLocaleText.tr(context, en: 'F', zhHans: '五', zhHant: '五', ja: '金'),
      AppLocaleText.tr(context, en: 'S', zhHans: '六', zhHant: '六', ja: '土'),
      AppLocaleText.tr(context, en: 'S', zhHans: '日', zhHant: '日', ja: '日'),
    ];
    return Row(
      children: [
        for (var index = 0; index < days.length; index++)
          Expanded(
            child: Column(
              children: [
                Text(
                  labels[index],
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AuroraColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 1),
                Text(
                  '${days[index].day}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF7B8497),
                      ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _WeeklyAttemptMatrixRow extends StatelessWidget {
  final _WeeklyAttemptDisplayItem item;
  final List<DateTime> days;
  final DateTime today;
  final bool isBusy;
  final Future<void> Function() onTodayTap;
  final Future<void> Function()? onWeeklySummaryTap;

  const _WeeklyAttemptMatrixRow({
    required this.item,
    required this.days,
    required this.today,
    required this.isBusy,
    required this.onTodayTap,
    this.onWeeklySummaryTap,
  });

  @override
  Widget build(BuildContext context) {
    final cells = {
      for (final cell in item.progress.cells) cell.localDate: cell,
    };
    final hasAnyRecord = item.progress.cells.any(
      (cell) => cell.state != ProgressCellState.empty,
    );
    return Container(
      key: ValueKey('weekly-attempt-row-${item.progress.subjectId}'),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AuroraColors.line.withValues(alpha: 0.65)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(item.icon, size: 17, color: item.color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.kind,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: item.color,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AuroraColors.ink,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (item.sourceChanged) ...[
            const SizedBox(height: 6),
            const _WeeklySourceChangedLabel(),
          ],
          const SizedBox(height: 9),
          Row(
            children: [
              for (final day in days)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: _WeeklyAttemptDayCell(
                      subjectId: item.progress.subjectId,
                      cell: cells[_dateKey(day)] ??
                          SevenDayProgressCell(
                            localDate: _dateKey(day),
                            state: ProgressCellState.empty,
                          ),
                      isToday: _sameDate(day, today),
                      canRecord: _sameDate(day, today) &&
                          _canRecordToday(item, today) &&
                          !isBusy,
                      onTap: onTodayTap,
                    ),
                  ),
                ),
            ],
          ),
          if (onWeeklySummaryTap != null && hasAnyRecord) ...[
            const SizedBox(height: 9),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                key: ValueKey(
                  'weekly-goal-summary-${item.progress.subjectId}',
                ),
                onPressed: isBusy
                    ? null
                    : () {
                        onWeeklySummaryTap?.call();
                      },
                icon: const Icon(Icons.insights_rounded, size: 17),
                label: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Summarize this week',
                    zhHans: '总结本周',
                    zhHant: '總結本週',
                    ja: '今週をまとめる',
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AuroraColors.blue,
                  minimumSize: const Size(0, 44),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _canRecordToday(_WeeklyAttemptDisplayItem item, DateTime date) {
    final action = item.action;
    if (action != null) {
      if (_isClosedStatus(action.status)) return false;
      final start = DateTime.tryParse(
            action.progressStartDate ?? action.plannedDate ?? '',
          ) ??
          action.adoptedAt ??
          action.createdAt;
      if (start == null) return false;
      final end = DateTime.tryParse(action.progressEndDate ?? '') ??
          start.add(const Duration(days: 6));
      return !_dateOnly(date).isBefore(_dateOnly(start)) &&
          !_dateOnly(date).isAfter(_dateOnly(end));
    }
    final experiment = item.experiment;
    if (experiment == null || _isClosedStatus(experiment.status)) return false;
    final start = DateTime.tryParse(
          experiment.progressStartDate ?? experiment.sourceWeekStart,
        ) ??
        experiment.adoptedAt ??
        experiment.createdAt;
    if (start == null) return false;
    final end = DateTime.tryParse(
          experiment.progressEndDate ?? experiment.sourceWeekEnd,
        ) ??
        start.add(const Duration(days: 6));
    return !_dateOnly(date).isBefore(_dateOnly(start)) &&
        !_dateOnly(date).isAfter(_dateOnly(end));
  }

  bool _isClosedStatus(String raw) {
    final value = raw.trim().toLowerCase();
    return value.contains('pause') ||
        value.contains('stop') ||
        value.contains('archive') ||
        value.contains('complete') ||
        value.contains('done') ||
        value.contains('finish') ||
        value.contains('dismiss');
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  bool _sameDate(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  String _dateKey(DateTime value) => '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

class _WeeklySourceChangedLabel extends StatelessWidget {
  const _WeeklySourceChangedLabel();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.sync_problem_rounded,
          size: 15,
          color: AuroraColors.orange,
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            AppLocaleText.tr(
              context,
              en: 'The source Signal changed. This adopted attempt is kept.',
              zhHans: '来源 Signal 已变化，已采纳的尝试继续保留。',
              zhHant: '來源 Signal 已變化，已採納的嘗試繼續保留。',
              ja: '参照元の Signal が変わりました。採用済みの試みは保持されます。',
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF8A5D2C),
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }
}

class _WeeklyAttemptDayCell extends StatelessWidget {
  final String subjectId;
  final SevenDayProgressCell cell;
  final bool isToday;
  final bool canRecord;
  final Future<void> Function() onTap;

  const _WeeklyAttemptDayCell({
    required this.subjectId,
    required this.cell,
    required this.isToday,
    required this.canRecord,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, foreground, background, stateLabel) = switch (cell.state) {
      ProgressCellState.completed => (
          Icons.check_rounded,
          AuroraColors.mint,
          AuroraColors.mint.withValues(alpha: 0.13),
          AppLocaleText.tr(
            context,
            en: 'completed',
            zhHans: '已完成',
            zhHant: '已完成',
            ja: '完了',
          ),
        ),
      ProgressCellState.notCompleted => (
          Icons.close_rounded,
          AuroraColors.orange,
          AuroraColors.orange.withValues(alpha: 0.11),
          AppLocaleText.tr(
            context,
            en: 'not completed',
            zhHans: '未完成',
            zhHant: '未完成',
            ja: '未完了',
          ),
        ),
      ProgressCellState.empty => (
          Icons.circle_outlined,
          const Color(0xFF9AA2B2),
          const Color(0xFFF5F5FA),
          AppLocaleText.tr(
            context,
            en: 'not recorded',
            zhHans: '未登记',
            zhHant: '未登記',
            ja: '未記録',
          ),
        ),
    };
    final label = '$cell.localDate, $stateLabel${isToday ? ', today' : ''}';
    return Semantics(
      button: canRecord,
      enabled: canRecord,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('weekly-attempt-cell-$subjectId-${cell.localDate}'),
          onTap: canRecord ? onTap : null,
          borderRadius: BorderRadius.circular(11),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 44,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: isToday
                    ? AuroraColors.purple
                    : foreground.withValues(alpha: 0.2),
                width: isToday ? 1.6 : 1,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: foreground),
          ),
        ),
      ),
    );
  }
}

class _WeeklyAttemptFacts extends StatelessWidget {
  final int itemCount;
  final int recordedItemDays;
  final int completedItemDays;
  final Set<String> recordedDates;
  final Set<String> signalDates;

  const _WeeklyAttemptFacts({
    required this.itemCount,
    required this.recordedItemDays,
    required this.completedItemDays,
    required this.recordedDates,
    required this.signalDates,
  });

  @override
  Widget build(BuildContext context) {
    final overlap = recordedDates.intersection(signalDates).length;
    final first = itemCount == 0
        ? AppLocaleText.tr(
            context,
            en: 'There are no adopted attempts to summarize this week yet.',
            zhHans: '本周还没有可汇总的已采纳尝试。',
            zhHant: '本週還沒有可彙總的已採納嘗試。',
            ja: '今週は、まとめられる採用済みの試みがまだありません。',
          )
        : AppLocaleText.tr(
            context,
            en: '$recordedItemDays item-days were recorded across $itemCount attempts; $completedItemDays were completed.',
            zhHans:
                '$itemCount 项尝试共登记了 $recordedItemDays 个项目日，其中 $completedItemDays 个已完成。',
            zhHant:
                '$itemCount 項嘗試共登記了 $recordedItemDays 個項目日，其中 $completedItemDays 個已完成。',
            ja: '$itemCount 件の試みで $recordedItemDays 件の日次記録があり、そのうち $completedItemDays 件が完了でした。',
          );
    final second = _signalSummary(context, overlap);
    return Container(
      key: const ValueKey('weekly-attempt-fact-summary'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AuroraColors.purple.withValues(alpha: 0.075),
            AuroraColors.mint.withValues(alpha: 0.055),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_graph_rounded,
                size: 18,
                color: AuroraColors.purple,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'This week in facts',
                    zhHans: '本周事实',
                    zhHant: '本週事實',
                    ja: '今週の事実',
                  ),
                  maxLines: 2,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AuroraColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            first,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF4C566D),
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 5),
          Text(
            second,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF4C566D),
                  height: 1.45,
                ),
          ),
        ],
      ),
    );
  }

  String _signalSummary(BuildContext context, int overlap) {
    if (signalDates.isEmpty) {
      return AppLocaleText.tr(
        context,
        en: 'There are no Signals to place beside these attempts yet.',
        zhHans: '本周还没有可与尝试并排查看的 Signal。',
        zhHant: '本週還沒有可與嘗試並排查看的 Signal。',
        ja: '今週は、試みと並べて見られる Signal がまだありません。',
      );
    }
    if (recordedDates.isEmpty) {
      return AppLocaleText.tr(
        context,
        en: 'Signals appeared on ${signalDates.length} days; attempt completion has not been recorded yet.',
        zhHans: '本周有 ${signalDates.length} 天留下 Signal，尝试完成情况还没有开始登记。',
        zhHant: '本週有 ${signalDates.length} 天留下 Signal，嘗試完成情況還沒有開始登記。',
        ja: '今週は ${signalDates.length} 日に Signal があり、試みの完了記録はまだありません。',
      );
    }
    if (overlap == 0) {
      return AppLocaleText.tr(
        context,
        en: 'Signals and attempt records did not fall on the same day this week; keep observing without forcing a link.',
        zhHans: '本周的 Signal 与尝试记录还没有落在同一天，先不急着解释它们的关系。',
        zhHant: '本週的 Signal 與嘗試記錄還沒有落在同一天，先不急著解釋它們的關係。',
        ja: '今週は Signal と試みの記録が同じ日に重なっていないため、関係を急いで決めません。',
      );
    }
    return AppLocaleText.tr(
      context,
      en: 'On $overlap of ${signalDates.length} Signal days, an attempt was also recorded. This shows co-occurrence, not cause.',
      zhHans:
          '本周 ${signalDates.length} 个 Signal 日中，有 $overlap 天也登记了尝试；这里只表示同时出现，不判断因果。',
      zhHant:
          '本週 ${signalDates.length} 個 Signal 日中，有 $overlap 天也登記了嘗試；這裡只表示同時出現，不判斷因果。',
      ja: '今週の ${signalDates.length} 日の Signal のうち、$overlap 日は試みの記録もありました。これは同時に現れた事実だけを示します。',
    );
  }
}

class _LegacyWeeklyAttemptsCard extends StatelessWidget {
  final List<AdoptedMicroActionProgress> activeMicroActions;
  final List<AdoptedLifeExperimentProgress> activeExperiments;
  final LifeExperimentModel? fallbackExperiment;
  final bool progressLoadFailed;

  const _LegacyWeeklyAttemptsCard({
    required this.activeMicroActions,
    required this.activeExperiments,
    required this.fallbackExperiment,
    required this.progressLoadFailed,
  });

  @override
  Widget build(BuildContext context) {
    final hasCanonicalExperiments = activeExperiments.isNotEmpty;

    return _WeeklyGlassCard(
      containerKey: const ValueKey('weekly-action-review-card'),
      icon: Icons.checklist_rounded,
      title: AppLocaleText.tr(
        context,
        en: 'Life Experiment progress',
        zhHans: '本周尝试',
        zhHant: '本週嘗試',
        ja: '今週の試み',
      ),
      child: Column(
        children: [
          if (progressLoadFailed) const _WeeklyProgressLoadWarning(),
          if (activeMicroActions.isEmpty)
            _WeeklyAttemptEmptyRow(
              icon: Icons.eco_rounded,
              color: AuroraColors.mint,
              kind: AppLocaleText.tr(
                context,
                en: 'Small experiment',
                zhHans: '小实验',
                zhHant: '小實驗',
                ja: '小実験',
              ),
              message: AppLocaleText.tr(
                context,
                en: 'No adopted small experiments in the current 7-day window.',
                zhHans: '当前 7 天周期内还没有采纳的小实验。',
                zhHant: '目前 7 天週期內還沒有採納的小實驗。',
                ja: '現在の 7 日間には、採用した小実験がまだありません。',
              ),
            )
          else
            for (final item in activeMicroActions)
              Padding(
                padding: EdgeInsets.only(
                  bottom: identical(item, activeMicroActions.last) ? 0 : 12,
                ),
                child: _WeeklyAttemptRow(
                  icon: Icons.eco_rounded,
                  color: AuroraColors.mint,
                  kind: AppLocaleText.tr(
                    context,
                    en: 'Small experiment',
                    zhHans: '小实验',
                    zhHant: '小實驗',
                    ja: '小実験',
                  ),
                  title: item.action.title,
                  progress: item.progress.completedDays,
                  total: SevenDayProgressModel.totalDays,
                  sourceChanged: item.action.sourceChanged,
                ),
              ),
          Divider(
            height: 20,
            color: AuroraColors.line.withValues(alpha: 0.65),
          ),
          Container(
            key: const ValueKey('weekly-experiment-result-card'),
            child: Column(
              children: [
                if (!hasCanonicalExperiments && fallbackExperiment == null)
                  _WeeklyAttemptEmptyRow(
                    icon: Icons.science_outlined,
                    color: AuroraColors.blue,
                    kind: AppLocaleText.tr(
                      context,
                      en: 'Goal',
                      zhHans: '目标',
                      zhHant: '目標',
                      ja: '目標',
                    ),
                    message: AppLocaleText.tr(
                      context,
                      en: 'No adopted goals in the current 7-day window.',
                      zhHans: '当前 7 天周期内还没有采纳的目标。',
                      zhHant: '目前 7 天週期內還沒有採納的目標。',
                      ja: '現在の 7 日間には、採用した目標がまだありません。',
                    ),
                  )
                else if (hasCanonicalExperiments)
                  for (final item in activeExperiments)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom:
                            identical(item, activeExperiments.last) ? 0 : 12,
                      ),
                      child: _WeeklyAttemptRow(
                        icon: Icons.science_outlined,
                        color: AuroraColors.blue,
                        kind: AppLocaleText.tr(
                          context,
                          en: 'Goal',
                          zhHans: '目标',
                          zhHant: '目標',
                          ja: '目標',
                        ),
                        title: item.experiment.title,
                        progress: item.progress.completedDays,
                        total: SevenDayProgressModel.totalDays,
                        sourceChanged: item.experiment.sourceChanged,
                        onTap: () => context.push(AppRoutes.experiment),
                      ),
                    )
                else
                  _WeeklyAttemptRow(
                    icon: Icons.science_outlined,
                    color: AuroraColors.blue,
                    kind: AppLocaleText.tr(
                      context,
                      en: 'Goal',
                      zhHans: '目标',
                      zhHant: '目標',
                      ja: '目標',
                    ),
                    title: fallbackExperiment!.title,
                    progress: 0,
                    total: SevenDayProgressModel.totalDays,
                    sourceChanged: fallbackExperiment!.sourceChanged,
                    onTap: () => context.push(AppRoutes.experiment),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyAttemptEmptyRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String kind;
  final String message;

  const _WeeklyAttemptEmptyRow({
    required this.icon,
    required this.color,
    required this.kind,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                kind,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: const Color(0xFF24314C),
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF6B7487),
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeeklyProgressLoadWarning extends StatelessWidget {
  const _WeeklyProgressLoadWarning();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('weekly-progress-load-warning'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AuroraColors.orange.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        AppLocaleText.tr(
          context,
          en: 'Progress could not be refreshed. Pull down to try again.',
          zhHans: '进度暂时无法刷新，下拉页面可重试。',
          zhHant: '進度暫時無法重新整理，下拉頁面可重試。',
          ja: '進捗を更新できませんでした。下に引いて再試行できます。',
        ),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF7A5630),
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _WeeklyAttemptRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String kind;
  final String title;
  final int progress;
  final int total;
  final bool sourceChanged;
  final VoidCallback? onTap;

  const _WeeklyAttemptRow({
    required this.icon,
    required this.color,
    required this.kind,
    required this.title,
    required this.progress,
    required this.total,
    this.sourceChanged = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: '$kind, $title, $progress / $total',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, size: 22, color: color),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 82,
                    child: Text(
                      kind,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: const Color(0xFF24314C),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF354158),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$progress/$total',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AuroraColors.purple,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 21,
                    color: onTap == null
                        ? const Color(0xFF9AA2B2).withValues(alpha: 0.48)
                        : const Color(0xFF7D879A),
                  ),
                ],
              ),
              if (sourceChanged) ...[
                const SizedBox(height: 7),
                Padding(
                  padding: const EdgeInsets.only(left: 32),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.sync_problem_rounded,
                        size: 15,
                        color: AuroraColors.orange,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          _sourceChangedText(context),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF8A5D2C),
                                    height: 1.3,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _sourceChangedText(BuildContext context) {
    return AppLocaleText.tr(
      context,
      en: 'Source changed. This adopted item is kept.',
      zhHans: '来源已变化，已采纳内容继续保留。',
      zhHant: '來源已變化，已採納內容繼續保留。',
      ja: '参照元が変わりました。採用済みの内容は保持されます。',
    );
  }
}

class _WeeklyActionReviewSummaryCard extends StatelessWidget {
  final WeeklyActionReviewModel review;
  final LifeExperimentModel? experiment;
  final WeeklyV3CStructureModel structure;

  const _WeeklyActionReviewSummaryCard({
    required this.review,
    required this.experiment,
    required this.structure,
  });

  @override
  Widget build(BuildContext context) {
    final rows = _rows(context);
    return _WeeklyGlassCard(
      containerKey: const ValueKey('weekly-action-review-card'),
      title: AppLocaleText.tr(
        context,
        en: 'Small experiments and review',
        zhHans: '本周小实验和复盘',
        zhHant: '本週小實驗和回顧',
        ja: '今週の小実験と振り返り',
      ),
      child: rows.isEmpty
          ? Text(
              AppLocaleText.tr(
                context,
                en: 'No small experiment feedback has been recorded this week yet.',
                zhHans: '这周还没有保存小实验反馈。',
                zhHant: '這週還沒有保存小實驗回饋。',
                ja: '今週はまだ小実験のフィードバックが保存されていません。',
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF4B5468),
                    height: 1.45,
                  ),
            )
          : Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  _ActionReviewRow(data: rows[i]),
                  if (i != rows.length - 1)
                    Divider(
                      height: 1,
                      color: AuroraColors.line.withValues(alpha: 0.55),
                    ),
                ],
              ],
            ),
    );
  }

  List<_ActionReviewRowData> _rows(BuildContext context) {
    final rows = <_ActionReviewRowData>[];
    if (review.mostHelpfulAction.trim().isNotEmpty) {
      final hint = _helpfulActionIllustrationHint(review.mostHelpfulAction);
      rows.add(
        _ActionReviewRowData(
          icon: Icons.task_alt_rounded,
          illustrationAsset: _WeeklyIllustrationAsset.forText(
            '$hint ${review.mostHelpfulAction} 做到了 有帮助',
          ),
          title: review.mostHelpfulAction.trim(),
          count: math.max(1, review.helpfulActionCount),
          status: AppLocaleText.tr(
            context,
            en: 'Helpful',
            zhHans: '有帮助',
            zhHant: '有幫助',
            ja: '役立つ',
          ),
          color: AuroraColors.mint,
        ),
      );
    }
    if (review.hardestAction.trim().isNotEmpty) {
      final hint = _hardActionIllustrationHint(review.hardestAction);
      rows.add(
        _ActionReviewRowData(
          icon: Icons.remove_circle_outline_rounded,
          illustrationAsset: _WeeklyIllustrationAsset.forText(
            '$hint ${review.hardestAction} 偏难 更累',
          ),
          title: review.hardestAction.trim(),
          count:
              math.max(1, review.triedActionCount - review.helpfulActionCount),
          status: AppLocaleText.tr(
            context,
            en: 'Hard',
            zhHans: '偏难',
            zhHant: '偏難',
            ja: '難しめ',
          ),
          color: const Color(0xFFFF6F8D),
        ),
      );
    }
    if (review.nextAdjustment.trim().isNotEmpty) {
      final hint = _nextAdjustmentIllustrationHint(review.nextAdjustment);
      rows.add(
        _ActionReviewRowData(
          icon: Icons.tune_rounded,
          illustrationAsset: _WeeklyIllustrationAsset.forText(
            '$hint ${review.nextAdjustment} 调整',
          ),
          title: review.nextAdjustment.trim(),
          count: math.max(1, review.generatedActionCount),
          status: AppLocaleText.tr(
            context,
            en: 'Adjust',
            zhHans: '调整',
            zhHant: '調整',
            ja: '調整',
          ),
          color: AuroraColors.orange,
        ),
      );
    }
    if (rows.isEmpty && experiment?.suggestedAction.trim().isNotEmpty == true) {
      final hint = _helpfulActionIllustrationHint(experiment!.suggestedAction);
      rows.add(
        _ActionReviewRowData(
          icon: Icons.science_rounded,
          illustrationAsset: _WeeklyIllustrationAsset.forText(
            '$hint ${experiment!.suggestedAction}',
          ),
          title: experiment!.suggestedAction.trim(),
          count: math.max(1, review.triedActionCount),
          status: AppLocaleText.tr(
            context,
            en: 'Daily practice',
            zhHans: '每日做法',
            zhHant: '每日做法',
            ja: '毎日の取り組み',
          ),
          color: AuroraColors.purple,
        ),
      );
    }
    return rows;
  }

  String _helpfulActionIllustrationHint(String text) {
    if (_hasAny(text, const ['10', '十分钟', '分钟', '短'])) {
      return '10 分钟以内更容易发生';
    }
    if (_hasAny(text, const ['身体', '拉伸', '呼吸', '放松'])) {
      return '身体类小实验更有效';
    }
    if (_hasAny(text, const ['写', '观察', '一句', '记录'])) {
      return '写一句观察更有效';
    }
    if (_hasAny(text, const ['散步', '走路', '走'])) {
      return '散步类行动更有效';
    }
    if (_hasAny(text, const ['手机', '屏幕', '刷'])) {
      return '放下手机类行动有效';
    }
    if (_hasAny(text, const ['整理', '房间', '环境', '收纳'])) {
      return '整理环境类行动有效';
    }
    if (_hasAny(text, const ['关系', '表达', '对话', '沟通'])) {
      return '关系表达类行动有效';
    }
    if (_hasAny(text, const ['拆', '目标', '小步', '小一点'])) {
      return '目标拆小类行动有效';
    }
    return '有帮助';
  }

  String _hardActionIllustrationHint(String text) {
    if (_hasAny(text, const ['打卡', '任务', '清单', '必须'])) {
      return '太像任务打卡';
    }
    if (_hasAny(text, const ['太长', '很久', '半小时', '30', '一小时'])) {
      return '时间太长';
    }
    if (_hasAny(text, const ['复杂', '步骤', '太多', '流程'])) {
      return '太复杂了';
    }
    return '太难了';
  }

  String _nextAdjustmentIllustrationHint(String text) {
    if (_hasAny(text, const ['早上', '晨间', '上午'])) return '早上更容易做到';
    if (_hasAny(text, const ['晚上', '睡前', '夜里'])) return '晚上更容易做到';
    if (_hasAny(text, const ['周末'])) return '周末更容易做到';
    if (_hasAny(text, const ['连续', '几天', '保持'])) return '连续发生几天';
    if (_hasAny(text, const ['重新', '中断', '再开始'])) return '中断后重新开始';
    if (_hasAny(text, const ['部分', '一半'])) return '部分发生';
    if (_hasAny(text, const ['观察', '看见', '记录'])) return '只是观察也有帮助';
    if (_hasAny(text, const ['安排', '日程', '会议'])) return '被安排打断';
    if (_hasAny(text, const ['情绪', '焦虑', '烦'])) return '被情绪打断';
    if (_hasAny(text, const ['继续', '停止', '改小', '调轻', '归档', '换'])) {
      return '下周继续 / 停止 / 改小';
    }
    return '想调整';
  }

  bool _hasAny(String text, List<String> tokens) {
    final source = text.toLowerCase();
    return tokens.any((token) => source.contains(token.toLowerCase()));
  }
}

class _WeeklyExperimentResultCard extends StatelessWidget {
  final WeeklyV3CStructureModel structure;
  final LifeExperimentModel? experiment;
  final WeeklyActionReviewModel review;

  const _WeeklyExperimentResultCard({
    required this.structure,
    required this.experiment,
    required this.review,
  });

  @override
  Widget build(BuildContext context) {
    final totalDays = math.max(1, experiment?.plannedTotalDays ?? 7);
    final progress = math.max(0, math.min(totalDays, review.triedActionCount));
    final title = experiment?.title.trim().isNotEmpty == true
        ? experiment!.title.trim()
        : structure.onePattern;
    return _WeeklyGlassCard(
      containerKey: const ValueKey('weekly-experiment-result-card'),
      title: AppLocaleText.tr(
        context,
        en: 'Goal result and review',
        zhHans: '本周目标结果和复盘',
        zhHant: '本週目標結果和回顧',
        ja: '今週の目標結果と振り返り',
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (experiment == null) {
            return _EmptyWeeklyExperimentResult();
          }
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AuroraColors.purple,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                structure.oneExperiment,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF49536A),
                      height: 1.45,
                    ),
              ),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AuroraColors.purple.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'More suitable for a low-pressure, body-clear daily practice.',
                    zhHans: '你更适合低压力、身体感明确、可以马上开始的小动作。',
                    zhHant: '你更適合低壓力、身體感明確、可以馬上開始的小動作。',
                    ja: '低負荷で、身体感覚が明確な毎日の取り組みが合いそうです。',
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AuroraColors.purple,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          );
          if (constraints.maxWidth < 330) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProgressRing(progress: progress, total: totalDays),
                const SizedBox(height: 16),
                copy,
              ],
            );
          }
          return Row(
            children: [
              _ProgressRing(progress: progress, total: totalDays),
              const SizedBox(width: 20),
              Expanded(child: copy),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyWeeklyExperimentResult extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AuroraSoftIconCircle(
          icon: Icons.science_outlined,
          color: AuroraColors.purple,
          size: 56,
          iconSize: 28,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocaleText.tr(
                  context,
                  en: 'No goal this week',
                  zhHans: '本周还没有目标',
                  zhHant: '本週還沒有目標',
                  ja: '今週の目標はまだありません',
                ),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF29334D),
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocaleText.tr(
                  context,
                  en: 'When a Life Experiment goal has attempts or feedback, its progress and review will appear here.',
                  zhHans: '生活小实验中的目标出现尝试或反馈后，这里会显示真实进度和复盘。',
                  zhHant: '生活小實驗中的目標出現嘗試或回饋後，這裡會顯示真實進度和回顧。',
                  ja: '生活実験の目標に試行や反応が出ると、進捗と振り返りがここに表示されます。',
                ),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF5C6578),
                      height: 1.42,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NextWeekExperimentCard extends StatelessWidget {
  final WeeklyActionPlanModel actionPlan;
  final LifeExperimentModel? experiment;
  final CandidateGenerationStatus candidateStatus;
  final int candidateCount;
  final String? candidatePreviewTitle;
  final String? candidateStaleReason;
  final bool candidateRefreshFailed;
  final int eligibleSignalCount;
  final String weekEnd;
  final EnergyBudgetModel? energyBudget;
  final SubmitState experimentSubmitState;
  final Future<void> Function() onSaveExperiment;
  final Future<void> Function() onRefresh;

  const _NextWeekExperimentCard({
    required this.actionPlan,
    required this.experiment,
    required this.candidateStatus,
    required this.candidateCount,
    required this.candidatePreviewTitle,
    required this.candidateStaleReason,
    required this.candidateRefreshFailed,
    required this.eligibleSignalCount,
    required this.weekEnd,
    required this.energyBudget,
    required this.experimentSubmitState,
    required this.onSaveExperiment,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final busy = experimentSubmitState == SubmitState.submitting;
    final hasExperiment = experiment != null;
    final isAdopted = hasExperiment && !experiment!.id.startsWith('cand_');
    return _WeeklyGlassCard(
      containerKey: const ValueKey('weekly-next-experiment-card'),
      icon: Icons.science_rounded,
      title: AppLocaleText.tr(
        context,
        en: 'Next week’s tries',
        zhHans: '下周尝试',
        zhHant: '下週嘗試',
        ja: '来週の試み',
      ),
      child: switch (candidateStatus) {
        CandidateGenerationStatus.gated => _NextWeekExperimentFormingState(
            eligibleSignalCount: eligibleSignalCount,
          ),
        CandidateGenerationStatus.stale => _WeeklyCandidateStatusState(
            key: const ValueKey('weekly-candidate-status-stale'),
            icon: Icons.sync_problem_rounded,
            title: AppLocaleText.tr(
              context,
              en: 'Signals changed',
              zhHans: '信号来源已变化',
              zhHant: '信號來源已變化',
              ja: 'シグナルの参照元が変わりました',
            ),
            message: AppLocaleText.tr(
              context,
              en: 'Old candidates are no longer shown. Refresh to rebuild them from the latest signals.',
              zhHans: '旧候选已失效并停止展示。请根据最新信号重新生成。',
              zhHant: '舊候選已失效並停止顯示。請根據最新信號重新生成。',
              ja: '古い候補は無効になりました。最新のシグナルから作り直してください。',
            ),
            detail: candidateStaleReason == null
                ? null
                : AppLocaleText.tr(
                    context,
                    en: 'The Signal set changed after these candidates were generated.',
                    zhHans: '这些候选生成后，关联的 Signal 集合发生了变化。',
                    zhHant: '這些候選生成後，關聯的 Signal 集合發生了變化。',
                    ja: '候補の作成後に、関連する Signal の組み合わせが変わりました。',
                  ),
            buttonLabel: AppLocaleText.tr(
              context,
              en: 'Refresh candidates',
              zhHans: '刷新候选',
              zhHant: '重新整理候選',
              ja: '候補を更新',
            ),
            onPressed: onRefresh,
          ),
        CandidateGenerationStatus.regenerating => _WeeklyCandidateStatusState(
            key: const ValueKey('weekly-candidate-status-regenerating'),
            loading: true,
            icon: Icons.auto_awesome_rounded,
            title: AppLocaleText.tr(
              context,
              en: 'Updating candidates',
              zhHans: '正在更新候选',
              zhHant: '正在更新候選',
              ja: '候補を更新しています',
            ),
            message: AppLocaleText.tr(
              context,
              en: 'The latest signals are being reorganized. Existing adopted goals stay unchanged.',
              zhHans: '正在根据最新信号重新整理。已采纳的目标不会被覆盖。',
              zhHant: '正在根據最新信號重新整理。已採納的目標不會被覆蓋。',
              ja: '最新のシグナルから整理し直しています。採用済みの目標は変わりません。',
            ),
          ),
        CandidateGenerationStatus.failed => _WeeklyCandidateStatusState(
            key: const ValueKey('weekly-candidate-status-failed'),
            icon: Icons.error_outline_rounded,
            title: AppLocaleText.tr(
              context,
              en: 'Candidates could not be generated',
              zhHans: '候选暂时生成失败',
              zhHant: '候選暫時生成失敗',
              ja: '候補を作成できませんでした',
            ),
            message: AppLocaleText.tr(
              context,
              en: candidateRefreshFailed
                  ? 'Your Weekly report is still available. Try candidate generation again.'
                  : 'Try candidate generation again when you are ready.',
              zhHans: candidateRefreshFailed
                  ? '每周复盘报告仍可正常查看，可以单独重试候选生成。'
                  : '准备好后可以再次生成候选。',
              zhHant: candidateRefreshFailed
                  ? 'Weekly 報告仍可正常查看，可以單獨重試候選生成。'
                  : '準備好後可以再次生成候選。',
              ja: candidateRefreshFailed
                  ? 'Weekly レポートは引き続き見られます。候補作成だけ再試行できます。'
                  : '準備ができたら、候補作成をもう一度試せます。',
            ),
            buttonLabel: AppLocaleText.tr(
              context,
              en: 'Try again',
              zhHans: '重试',
              zhHant: '重試',
              ja: '再試行',
            ),
            onPressed: onRefresh,
          ),
        CandidateGenerationStatus.ready => candidateCount <= 0
            ? _WeeklyCandidateStatusState(
                key: const ValueKey('weekly-candidate-status-ready-empty'),
                icon: Icons.inbox_outlined,
                title: AppLocaleText.tr(
                  context,
                  en: 'No candidates available yet',
                  zhHans: '暂时没有可用候选',
                  zhHant: '暫時沒有可用候選',
                  ja: '利用できる候補がまだありません',
                ),
                message: AppLocaleText.tr(
                  context,
                  en: 'Refresh once more to use the latest eligible signals.',
                  zhHans: '可再次刷新，使用最新符合条件的信号生成。',
                  zhHant: '可再次重新整理，使用最新符合條件的信號生成。',
                  ja: '最新の有効なシグナルでもう一度更新できます。',
                ),
                buttonLabel: AppLocaleText.tr(
                  context,
                  en: 'Refresh candidates',
                  zhHans: '刷新候选',
                  zhHant: '重新整理候選',
                  ja: '候補を更新',
                ),
                onPressed: onRefresh,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _nextWeekRange(context),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF526077),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppLocaleText.tr(
                      context,
                      en: '$candidateCount candidate${candidateCount == 1 ? '' : 's'} ready',
                      zhHans: '$candidateCount 个候选已准备好',
                      zhHant: '$candidateCount 個候選已準備好',
                      ja: '候補が $candidateCount 件そろいました',
                    ),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: const Color(0xFF213052),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if (candidatePreviewTitle?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 5),
                    Text(
                      candidatePreviewTitle!.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF536077),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _WeeklyCandidateTrait(
                        label: _energyStrengthText(context, energyBudget),
                        color: AuroraColors.purple,
                      ),
                      _WeeklyCandidateTrait(
                        label: AppLocaleText.tr(
                          context,
                          en: 'Low switching',
                          zhHans: '低切换',
                          zhHant: '低切換',
                          ja: '切替少なめ',
                        ),
                        color: AuroraColors.blue,
                      ),
                      _WeeklyCandidateTrait(
                        label: AppLocaleText.tr(
                          context,
                          en: 'Pausable',
                          zhHans: '可暂停',
                          zhHant: '可暫停',
                          ja: '中断できる',
                        ),
                        color: AuroraColors.mint,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AuroraPillButton(
                    filled: true,
                    label: busy
                        ? AppLocaleText.tr(
                            context,
                            en: 'Saving',
                            zhHans: '保存中',
                            zhHant: '保存中',
                            ja: '保存中',
                          )
                        : AppLocaleText.tr(
                            context,
                            en: isAdopted
                                ? 'View selected tries'
                                : 'Choose next week’s tries',
                            zhHans: isAdopted ? '查看已选尝试' : '选择下周尝试',
                            zhHant: isAdopted ? '查看已選嘗試' : '選擇下週嘗試',
                            ja: isAdopted ? '選んだ試みを見る' : '来週の試みを選ぶ',
                          ),
                    onPressed: busy ? null : onSaveExperiment,
                  ),
                ],
              ),
      },
    );
  }

  String _nextWeekRange(BuildContext context) {
    final end = DateTime.tryParse(weekEnd);
    if (end == null) {
      return AppLocaleText.tr(
        context,
        en: 'Next week',
        zhHans: '下周',
        zhHant: '下週',
        ja: '来週',
      );
    }
    final start = end.add(const Duration(days: 1));
    final nextEnd = end.add(const Duration(days: 7));
    String format(DateTime value) => '${value.month}月${value.day}日';
    return '${format(start)}–${format(nextEnd)}';
  }

  String _energyAdjustedExperimentText(BuildContext context) {
    final candidateAction = experiment?.suggestedAction.trim();
    final base = candidateAction != null && candidateAction.isNotEmpty
        ? candidateAction
        : actionPlan.smallExperiment.trim();
    final budget = energyBudget;
    if (budget == null || budget.status == 'insufficient_data') {
      return AppLocaleText.tr(
        context,
        en: '${base.isEmpty ? 'Start with one very light daily practice for next week’s goal.' : base} Keep it light until energy signals become clearer.',
        zhHans:
            '${base.isEmpty ? '下周目标先从一个很轻的每日做法开始。' : base} 在能量线索更清楚前，先保持轻量。',
        zhHant:
            '${base.isEmpty ? '下週目標先從一個很輕的每日做法開始。' : base} 在能量線索更清楚前，先保持輕量。',
        ja: '${base.isEmpty ? '来週の目標は、とても軽い毎日の取り組みから始めます。' : base} エネルギーの手がかりが見えるまでは軽めにします。',
      );
    }

    final rawAdjustment = budget.switchingAdjustment.trim().isNotEmpty
        ? budget.switchingAdjustment.trim()
        : budget.bufferLocation.trim();
    final adjustment = EnergyBudgetText.localizeCopy(context, rawAdjustment);
    if (adjustment.isEmpty) {
      return base.isEmpty
          ? AppLocaleText.tr(
              context,
              en: 'Start the goal with one daily practice and enough buffer around it.',
              zhHans: '下周目标先安排一个每日做法，并给它前后留一点余地。',
              zhHant: '下週目標先安排一個每日做法，並給它前後留一點餘地。',
              ja: '来週の目標は、前後に余白を残した毎日の取り組みから始めます。',
            )
          : base;
    }
    return AppLocaleText.tr(
      context,
      en: '${base.isEmpty ? 'Start with one daily practice.' : base} Energy adjustment: $adjustment',
      zhHans: '${base.isEmpty ? '先从一个每日做法开始。' : base} 能量调节：$adjustment',
      zhHant: '${base.isEmpty ? '先從一個每日做法開始。' : base} 能量調節：$adjustment',
      ja: '${base.isEmpty ? '毎日の取り組みを一つ始めます。' : base} エネルギー調整：$adjustment',
    );
  }
}

class _WeeklyCandidateStatusState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? detail;
  final String? buttonLabel;
  final Future<void> Function()? onPressed;
  final bool loading;

  const _WeeklyCandidateStatusState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.detail,
    this.buttonLabel,
    this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final detailText = detail?.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F0FF).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AuroraColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              else
                Icon(icon, size: 21, color: AuroraColors.purple),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: const Color(0xFF29334D),
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF5C6578),
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (detailText != null && detailText.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              detailText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF7A8292),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
          if (buttonLabel != null && onPressed != null) ...[
            const SizedBox(height: 12),
            AuroraPillButton(
              filled: false,
              label: buttonLabel!,
              onPressed: () async => onPressed!.call(),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeeklyCandidateTrait extends StatelessWidget {
  final String label;
  final Color color;

  const _WeeklyCandidateTrait({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 190),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _WeeklyProEntryCard extends StatelessWidget {
  const _WeeklyProEntryCard();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppLocaleText.tr(
        context,
        en: 'Pro weekly deep read. Data is ready.',
        zhHans: 'Pro 本周深读，数据已准备好',
        zhHant: 'Pro 本週深讀，資料已準備好',
        ja: 'Pro 今週の深掘り。データの準備ができました。',
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push(AppRoutes.weeklyReflect),
        child: Container(
          key: const ValueKey('weekly-pro-entry-card'),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFFFF0D1).withValues(alpha: 0.92),
                const Color(0xFFFFFBF7).withValues(alpha: 0.82),
                const Color(0xFFF2EEFF).withValues(alpha: 0.72),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFE8C27A).withValues(alpha: 0.60),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD6AA58).withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3CA68),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  'Pro',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: const Color(0xFF5B4215),
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'This week deep read · Data is ready',
                    zhHans: '本周深读 · 数据已准备好',
                    zhHant: '本週深讀 · 資料已準備好',
                    ja: '今週の深掘り・データ準備済み',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF4A3B2A),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF776C61),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextWeekExperimentFormingState extends StatelessWidget {
  final int eligibleSignalCount;

  const _NextWeekExperimentFormingState({this.eligibleSignalCount = 0});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('weekly-next-experiment-forming'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F0FF).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AuroraColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocaleText.tr(
              context,
              en: 'Next week goals are taking shape',
              zhHans: '下周目标正在形成',
              zhHant: '下週目標正在形成',
              ja: '来週の目標を整理しています',
            ),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: const Color(0xFF29334D),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 5),
          Text(
            AppLocaleText.tr(
              context,
              en: 'After 3 eligible life signals, up to 3 optional goals appear (${eligibleSignalCount.clamp(0, 3)}/3). Waiting helps avoid over-reading one moment.',
              zhHans:
                  '记录 3 条符合条件的生活信号后，最多显示 3 个可选目标（${eligibleSignalCount.clamp(0, 3)}/3）。先等待几条信号，是为了避免过度解读一个瞬间。',
              zhHant:
                  '記錄 3 條符合條件的生活信號後，最多顯示 3 個可選目標（${eligibleSignalCount.clamp(0, 3)}/3）。先等待幾條信號，是為了避免過度解讀一個瞬間。',
              ja: '条件を満たすシグナルが 3 件になると、最大 3 件の実験候補を表示します（${eligibleSignalCount.clamp(0, 3)}/3）。一つの瞬間を読み込みすぎないためです。',
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF5C6578),
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyGlassCard extends StatelessWidget {
  final Key? containerKey;
  final String title;
  final IconData icon;
  final Widget child;

  const _WeeklyGlassCard({
    this.containerKey,
    required this.title,
    this.icon = Icons.auto_awesome_rounded,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: containerKey,
      padding: AuroraMainPageSpec.comfortableCardPadding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.84),
            const Color(0xFFF6F3FF).withValues(alpha: 0.68),
            const Color(0xFFFFFAF5).withValues(alpha: 0.70),
          ],
        ),
        borderRadius: BorderRadius.circular(AuroraMainPageSpec.cardRadiusLarge),
        border: Border.all(color: Colors.white.withValues(alpha: 0.90)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7568A6).withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AuroraSectionIcon(icon: icon, size: 30),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF213052),
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AuroraMainPageSpec.sectionGap),
          child,
        ],
      ),
    );
  }
}

class _WeeklyIllustrationAsset {
  static const emotionStable =
      'assets/weekly/weekly-illustration-emotion-stable.png';
  static const growthPlan = 'assets/weekly/weekly-illustration-growth-plan.png';
  static const eveningLoop =
      'assets/weekly/weekly-illustration-evening-loop.png';
  static const scheduleHeavy =
      'assets/weekly/weekly-illustration-schedule-heavy.png';
  static const interestHobby =
      'assets/weekly/weekly-illustration-interest-hobby.png';
  static const secondDayTired =
      'assets/weekly/weekly-illustration-second-day-tired.png';
  static const selfBoundary =
      'assets/weekly/weekly-illustration-self-boundary.png';
  static const foodSleep = 'assets/weekly/weekly-illustration-food-sleep.png';
  static const taskPileStartBlocked =
      'assets/weekly/weekly-pattern-task-pile-start-blocked.png';
  static const meetingFragmented =
      'assets/weekly/weekly-pattern-meeting-fragmented.png';
  static const routeInterrupted =
      'assets/weekly/weekly-pattern-route-interrupted.png';
  static const restSqueezed = 'assets/weekly/weekly-pattern-rest-squeezed.png';
  static const stopLoop = 'assets/weekly/weekly-pattern-stop-loop.png';
  static const nightPhone = 'assets/weekly/weekly-pattern-night-phone.png';
  static const morningStartSlow =
      'assets/weekly/weekly-pattern-morning-start-slow.png';
  static const afternoonEnergyDrop =
      'assets/weekly/weekly-pattern-afternoon-energy-drop.png';
  static const scheduleDrivenMood =
      'assets/weekly/weekly-pattern-schedule-driven-mood.png';
  static const anticipatoryAnxiety =
      'assets/weekly/weekly-pattern-anticipatory-anxiety.png';
  static const doneMoreTired =
      'assets/weekly/weekly-pattern-done-more-tired.png';
  static const largePlanHardStart =
      'assets/weekly/weekly-pattern-large-plan-hard-start.png';
  static const tooManyGoalsScattered =
      'assets/weekly/weekly-pattern-too-many-goals-scattered.png';
  static const creationSqueezedByWork =
      'assets/weekly/weekly-pattern-creation-squeezed-by-work.png';
  static const boundaryPushedTimeSqueezed =
      'assets/weekly/weekly-pattern-boundary-pushed-time-squeezed.png';
  static const peoplePleasingTired =
      'assets/weekly/weekly-pattern-people-pleasing-tired.png';
  static const unclearExpression =
      'assets/weekly/weekly-pattern-unclear-expression.png';
  static const solitudeInsufficient =
      'assets/weekly/weekly-pattern-solitude-insufficient.png';
  static const messyEnvironmentMood =
      'assets/weekly/weekly-pattern-messy-environment-mood.png';
  static const relationshipDialogueRumination =
      'assets/weekly/weekly-pattern-relationship-dialogue-rumination.png';
  static const moneySafetyPressure =
      'assets/weekly/weekly-pattern-money-safety-pressure.png';
  static const bodySignalBeforeTired =
      'assets/weekly/weekly-pattern-body-signal-before-tired.png';
  static const smallActionStabilizes =
      'assets/weekly/weekly-pattern-small-action-stabilizes.png';
  static const interestRecovery =
      'assets/weekly/weekly-pattern-interest-recovery.png';

  static String? forText(String text) {
    final catalogAsset = WeeklyIllustrationCatalog.assetForText(text);
    if (catalogAsset != null) return catalogAsset;
    final lower = text.toLowerCase();
    if (_contains(lower, const [
      '关系对话后反复内耗',
      '对话后反复内耗',
      '关系内耗',
      '对话气泡循环',
      '回声线',
      'dialogue rumination',
    ])) {
      return relationshipDialogueRumination;
    }
    if (_contains(lower, const [
      '金钱或现实压力',
      '现实压力',
      '牵动安全感',
      '钱币',
      '保护盾',
      'money pressure',
      'safety pressure',
    ])) {
      return moneySafetyPressure;
    }
    if (_contains(lower, const [
      '身体信号先出现',
      '才意识到累',
      '身体信号',
      '身体轮廓',
      '提醒灯',
      'body signal',
    ])) {
      return bodySignalBeforeTired;
    }
    if (_contains(lower, const [
      '小实验有效',
      '小行动有效',
      '节奏开始稳定',
      '开始稳定',
      '稳定光环',
      'small action effective',
      'stabilize',
    ])) {
      return smallActionStabilizes;
    }
    if (_contains(lower, const [
      '兴趣活动带来恢复感',
      '兴趣带来恢复',
      '带来恢复感',
      '小星光',
      'interest recovery',
    ])) {
      return interestRecovery;
    }
    if (_contains(lower, const [
      '做完事后更累',
      '做完更累',
      '完成后更累',
      '不是更轻松',
      '低电量',
      'done tired',
    ])) {
      return doneMoreTired;
    }
    if (_contains(lower, const [
      '计划越大',
      '越容易不开始',
      '巨大清单',
      '不开始',
      'large plan',
      'hard start',
    ])) {
      return largePlanHardStart;
    }
    if (_contains(lower, const [
      '目标太多',
      '注意力分散',
      '多条分叉路',
      '散开的星点',
      'too many goals',
      'scattered',
    ])) {
      return tooManyGoalsScattered;
    }
    if (_contains(lower, const [
      '创作被工作挤掉',
      '创造被工作挤掉',
      '画笔被文件压住',
      '创作被挤掉',
      'creation squeezed',
    ])) {
      return creationSqueezedByWork;
    }
    if (_contains(lower, const [
      '不敢拒绝',
      '自己的时间被挤占',
      '边界线被推开',
      '时间被挤占',
      'boundary pushed',
    ])) {
      return boundaryPushedTimeSqueezed;
    }
    if (_contains(lower, const [
      '过度迎合',
      '迎合后感到疲惫',
      '微笑面具',
      'people pleasing',
    ])) {
      return peoplePleasingTired;
    }
    if (_contains(lower, const [
      '想表达但说不清',
      '想表达',
      '说不清',
      '断开的对话',
      'unclear expression',
    ])) {
      return unclearExpression;
    }
    if (_contains(lower, const [
      '独处不足',
      '恢复变慢',
      '安静空间缺失',
      '小房间',
      'solitude',
    ])) {
      return solitudeInsufficient;
    }
    if (_contains(lower, const [
      '生活环境混乱',
      '环境混乱',
      '房间杂物',
      '心情也乱',
      'messy environment',
    ])) {
      return messyEnvironmentMood;
    }
    if (_contains(lower, const [
      '任务堆积',
      '任务太多',
      '堆积',
      '开始变困难',
      '起点被挡',
      'task pile',
      'backlog',
    ])) {
      return taskPileStartBlocked;
    }
    if (_contains(lower, const [
      '会议密集',
      '会议太多',
      '注意力被切碎',
      '碎片化',
      'meeting-heavy',
      'fragment',
    ])) {
      return meetingFragmented;
    }
    if (_contains(lower, const [
      '临时变化',
      '打断原本节奏',
      '被打断',
      '插入',
      'route interrupted',
      'interruption',
    ])) {
      return routeInterrupted;
    }
    if (_contains(lower, const [
      '休息时间被任务挤掉',
      '休息被挤掉',
      '休息被任务',
      '休息被压缩',
      '休息被压',
      '休息压缩',
      '被压缩',
    ])) {
      return restSqueezed;
    }
    if (_contains(lower, const [
      '想休息但停下来',
      '停下来后空转',
      '停下来反而空转',
      '停止键',
      '旋转圆圈',
      'stop loop',
    ])) {
      return stopLoop;
    }
    if (_contains(lower, const [
      '晚上刷手机',
      '刷手机变多',
      '手机发光',
      '通知点',
      'night phone',
    ])) {
      return nightPhone;
    }
    if (_contains(lower, const [
      '早上启动困难',
      '早上启动',
      '晨间启动',
      '慢启动',
      'morning start',
    ])) {
      return morningStartSlow;
    }
    if (_contains(lower, const [
      '中午以后精力下降',
      '午后精力',
      '下午精力',
      '电量下降',
      'energy drop',
      'afternoon',
    ])) {
      return afternoonEnergyDrop;
    }
    if (_contains(lower, const [
      '情绪被日程',
      '日程密度',
      '日历连接情绪',
      'schedule mood',
    ])) {
      return scheduleDrivenMood;
    }
    if (_contains(lower, const [
      '焦虑提前',
      '还没开始就紧张',
      '提前紧张',
      '未来时间点',
      'anticipatory',
    ])) {
      return anticipatoryAnxiety;
    }
    if (_contains(lower, const ['第二天', '更累', '偏难', '太难', 'hard'])) {
      return secondDayTired;
    }
    if (_contains(lower, const ['自我边界', '边界', 'boundary'])) {
      return selfBoundary;
    }
    if (_contains(lower, const ['饮食睡眠', '饮食', '吃', '午餐', 'food'])) {
      return foodSleep;
    }
    if (_contains(lower, const ['安排', '会议', '日程', 'schedule', 'calendar'])) {
      return scheduleHeavy;
    }
    if (_contains(lower, const ['晚上空转', '空转', '刷手机', '睡', '晚', 'sleep'])) {
      return eveningLoop;
    }
    if (_contains(lower, const ['成长', '计划', '目标', '推进', 'growth', 'plan'])) {
      return growthPlan;
    }
    if (_contains(lower, const ['兴趣', '爱好', '创造', '表达', 'hobby', 'interest'])) {
      return interestHobby;
    }
    if (_contains(lower, const ['情绪', '状态', '平静', '稳定', '焦虑', '累', 'mood'])) {
      return emotionStable;
    }
    return null;
  }

  static bool _contains(String text, List<String> needles) {
    return needles.any((needle) => text.contains(needle.toLowerCase()));
  }
}

class _WeeklyIllustrationThumb extends StatelessWidget {
  final String? asset;
  final IconData fallbackIcon;
  final Color color;
  final double size;
  final double iconSize;

  const _WeeklyIllustrationThumb({
    required this.asset,
    required this.fallbackIcon,
    required this.color,
    required this.size,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final path = asset;
    if (path == null) {
      return AuroraSoftIconCircle(
        icon: fallbackIcon,
        color: color,
        size: size,
        iconSize: iconSize,
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.26),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        path,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}

class _DistributionRow extends StatelessWidget {
  final _DistributionData data;
  final int maxCount;

  const _DistributionRow({
    required this.data,
    required this.maxCount,
  });

  @override
  Widget build(BuildContext context) {
    final widthFactor = (data.count / math.max(1, maxCount)).clamp(0.18, 1.0);
    return Row(
      children: [
        _WeeklyIllustrationThumb(
          asset: data.illustrationAsset,
          fallbackIcon: data.icon,
          color: data.color,
          size: 44,
          iconSize: 22,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      data.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: const Color(0xFF313A56),
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  Text(
                    '${data.count}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: const Color(0xFF34405D),
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: Stack(
                  children: [
                    Container(
                      height: 7,
                      color: AuroraColors.purple.withValues(alpha: 0.10),
                    ),
                    FractionallySizedBox(
                      widthFactor: widthFactor,
                      child: Container(
                        height: 7,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          color: data.color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BehaviorStepTile extends StatelessWidget {
  final int index;
  final _BehaviorStep step;

  const _BehaviorStepTile({
    required this.index,
    required this.step,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                step.color.withValues(alpha: 0.85),
                AuroraColors.purple.withValues(alpha: 0.70),
              ],
            ),
          ),
          child: Text(
            '$index',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
          ),
          child: Column(
            children: [
              _WeeklyIllustrationThumb(
                asset: step.illustrationAsset,
                fallbackIcon: step.icon,
                color: step.color,
                size: 46,
                iconSize: 23,
              ),
              const SizedBox(height: 10),
              Text(
                step.title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: const Color(0xFF26314F),
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 5),
              Text(
                step.body,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF687389),
                      height: 1.25,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionReviewRow extends StatelessWidget {
  final _ActionReviewRowData data;

  const _ActionReviewRow({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _WeeklyIllustrationThumb(
            asset: data.illustrationAsset,
            fallbackIcon: data.icon,
            color: data.color,
            size: 36,
            iconSize: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              data.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF26304A),
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              AppLocaleText.tr(
                context,
                en: 'Happened ${data.count} times',
                zhHans: '发生了 ${data.count} 次',
                zhHant: '發生了 ${data.count} 次',
                ja: '${data.count}回発生',
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: const Color(0xFF4E5870),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          _StatusPill(label: data.status, color: data.color),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final failed = label.contains('没') ||
        label.toLowerCase().contains('miss') ||
        label.contains('でき');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            failed ? Icons.close_rounded : Icons.check_rounded,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  final int progress;
  final int total;

  const _ProgressRing({
    required this.progress,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      height: 112,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size.square(112),
            painter: _ProgressRingPainter(progress / total),
          ),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$progress',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AuroraColors.purple,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                TextSpan(
                  text: '/$total',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AuroraColors.purple.withValues(alpha: 0.68),
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DistributionData {
  final IconData icon;
  final String? illustrationAsset;
  final String label;
  final int count;
  final Color color;

  const _DistributionData({
    required this.icon,
    this.illustrationAsset,
    required this.label,
    required this.count,
    required this.color,
  });
}

class _SignalDistributionDonut extends StatelessWidget {
  final List<_DistributionData> rows;
  final int total;

  const _SignalDistributionDonut({
    required this.rows,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AuroraColors.purple.withValues(alpha: 0.10),
                    blurRadius: 34,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),
          ),
          CustomPaint(
            painter: _SignalDistributionDonutPainter(
              rows: rows,
              total: total,
            ),
            child: const SizedBox.expand(),
          ),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.42),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.72),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.55),
                  blurRadius: 24,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white.withValues(alpha: 0.92),
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

class _DistributionFocusNote extends StatelessWidget {
  final List<_DistributionData> rows;

  const _DistributionFocusNote({required this.rows});

  @override
  Widget build(BuildContext context) {
    final first = rows.first;
    final second = rows.length > 1 ? rows[1] : null;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.68)),
      ),
      child: Row(
        children: [
          _WeeklyIllustrationThumb(
            asset: first.illustrationAsset,
            fallbackIcon: Icons.star_rounded,
            color: first.color,
            size: 52,
            iconSize: 24,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: AppLocaleText.tr(
                  context,
                  en: 'This week is more concentrated in ',
                  zhHans: '本周重点更集中在',
                  zhHant: '本週重點更集中在',
                  ja: '今週は特に',
                ),
                children: [
                  TextSpan(
                    text: first.label,
                    style: TextStyle(color: first.color),
                  ),
                  if (second != null)
                    TextSpan(
                      text: AppLocaleText.tr(
                        context,
                        en: ' and ',
                        zhHans: '和',
                        zhHant: '和',
                        ja: 'と',
                      ),
                    ),
                  if (second != null)
                    TextSpan(
                      text: second.label,
                      style: TextStyle(color: second.color),
                    ),
                  TextSpan(
                    text: AppLocaleText.tr(
                      context,
                      en: '.',
                      zhHans: '。',
                      zhHant: '。',
                      ja: 'に集中しています。',
                    ),
                  ),
                ],
              ),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF4D566D),
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalDistributionDonutPainter extends CustomPainter {
  final List<_DistributionData> rows;
  final int total;

  _SignalDistributionDonutPainter({
    required this.rows,
    required this.total,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = size.shortestSide * 0.35;
    final stroke = size.shortestSide * 0.16;
    final ringRect = Rect.fromCircle(center: center, radius: radius);
    final background = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt
      ..color = Colors.white.withValues(alpha: 0.42);
    canvas.drawCircle(center, radius, background);

    if (rows.isEmpty || total <= 0) return;

    var start = -math.pi / 2.25;
    const gap = math.pi * 0.018;
    for (final row in rows) {
      final sweep = math.max(0.08, (row.count / total) * math.pi * 2 - gap);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt
        ..shader = SweepGradient(
          startAngle: start,
          endAngle: start + sweep,
          colors: [
            row.color.withValues(alpha: 0.58),
            row.color,
            Colors.white.withValues(alpha: 0.76),
          ],
        ).createShader(ringRect);
      canvas.drawArc(ringRect, start, sweep, false, paint);

      final dotAngle = start + sweep * 0.12;
      final dot = Offset(
        center.dx + math.cos(dotAngle) * radius,
        center.dy + math.sin(dotAngle) * radius,
      );
      canvas.drawCircle(
        dot,
        stroke * 0.20,
        Paint()..color = Colors.white.withValues(alpha: 0.95),
      );
      canvas.drawCircle(
        dot,
        stroke * 0.12,
        Paint()..color = row.color.withValues(alpha: 0.85),
      );
      start += sweep + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _SignalDistributionDonutPainter oldDelegate) {
    return oldDelegate.rows != rows || oldDelegate.total != total;
  }
}

class _BehaviorStep {
  final IconData icon;
  final String? illustrationAsset;
  final String title;
  final String body;
  final Color color;

  const _BehaviorStep({
    required this.icon,
    this.illustrationAsset,
    required this.title,
    required this.body,
    required this.color,
  });
}

class _ActionReviewRowData {
  final IconData icon;
  final String? illustrationAsset;
  final String title;
  final int count;
  final String status;
  final Color color;

  const _ActionReviewRowData({
    required this.icon,
    this.illustrationAsset,
    required this.title,
    required this.count,
    required this.status,
    required this.color,
  });
}

String _formatWeekRange(String start, String end) {
  String format(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return '${parsed.month}月${parsed.day}日';
  }

  return '${format(start)} - ${format(end)}';
}

String _compact(String raw, String fallback) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return fallback;
  final first = trimmed.split(RegExp(r'[。；;\n]')).first.trim();
  final source = first.isEmpty ? trimmed : first;
  if (source.runes.length <= 22) return source;
  return '${String.fromCharCodes(source.runes.take(22))}...';
}

class _SoftPlant extends StatelessWidget {
  final Color color;

  const _SoftPlant({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      height: 92,
      child: CustomPaint(painter: _SoftPlantPainter(color)),
    );
  }
}

class _SoftPlantPainter extends CustomPainter {
  final Color color;

  _SoftPlantPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final stem = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    final start = Offset(size.width * 0.5, size.height);
    final end = Offset(size.width * 0.48, size.height * 0.05);
    canvas.drawLine(start, end, stem);

    final leaf = Paint()..color = color.withValues(alpha: 0.78);
    for (var i = 0; i < 5; i++) {
      final y = size.height * (0.22 + i * 0.13);
      final left = i.isEven;
      final path = Path()
        ..moveTo(size.width * 0.50, y)
        ..cubicTo(
          left ? size.width * 0.16 : size.width * 0.84,
          y - 16,
          left ? size.width * 0.16 : size.width * 0.84,
          y + 4,
          size.width * 0.50,
          y + 14,
        )
        ..close();
      canvas.drawPath(path, leaf);
    }
  }

  @override
  bool shouldRepaint(covariant _SoftPlantPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;

  _ProgressRingPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = size.width * 0.12;
    final ringRect = rect.deflate(stroke / 2);
    canvas.drawArc(
      ringRect,
      -math.pi / 2,
      math.pi * 2,
      false,
      Paint()
        ..color = AuroraColors.purple.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke,
    );
    canvas.drawArc(
      ringRect,
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0, 1),
      false,
      Paint()
        ..shader = const SweepGradient(
          colors: [
            Color(0xFF7B6FF2),
            Color(0xFF69A7FF),
            Color(0xFFB982FF),
            Color(0xFF7B6FF2),
          ],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _WeeklySignalOrbPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) * 0.36;
    canvas.drawCircle(
      center,
      radius * 1.36,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.90),
            AuroraColors.purple.withValues(alpha: 0.18),
            Colors.transparent,
          ],
        ).createShader(rect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const SweepGradient(
          colors: [
            Color(0xFFFFB45B),
            Color(0xFF65D7D4),
            Color(0xFF6D92F8),
            Color(0xFF9665F4),
            Color(0xFFFFB45B),
          ],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round,
    );

    final soft = Paint()
      ..color = Colors.white.withValues(alpha: 0.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius + 9, soft);
    canvas.drawCircle(center, radius - 24, soft..strokeWidth = 1.4);

    final path = Path()
      ..moveTo(center.dx - 4, center.dy - 18)
      ..cubicTo(center.dx + 48, center.dy - 6, center.dx + 34, center.dy + 18,
          center.dx - 2, center.dy + 30)
      ..cubicTo(center.dx - 58, center.dy + 49, center.dx - 26, center.dy + 72,
          center.dx + 48, center.dy + 92);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.68)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );

    for (final dot in [
      Offset(center.dx - radius, center.dy - 6),
      Offset(center.dx + radius * 0.74, center.dy - radius * 0.70),
      Offset(center.dx + radius * 0.72, center.dy + radius * 0.64),
      Offset(center.dx - radius * 0.72, center.dy + radius * 0.72),
    ]) {
      canvas.drawCircle(dot, 6, Paint()..color = Colors.white);
      canvas.drawCircle(
        dot,
        3.3,
        Paint()..color = AuroraColors.purple.withValues(alpha: 0.70),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WeeklyPagerPage {
  final String title;
  final List<Widget> children;

  const _WeeklyPagerPage({
    required this.title,
    required this.children,
  });
}

class _WeeklyPager extends StatefulWidget {
  final List<_WeeklyPagerPage> pages;

  const _WeeklyPager({required this.pages});

  @override
  State<_WeeklyPager> createState() => _WeeklyPagerState();
}

class _WeeklyPagerState extends State<_WeeklyPager> {
  static const _qaInitialPage =
      int.fromEnvironment('SIGNALPATH_WEEKLY_PAGE', defaultValue: 0);
  late final PageController _pageController;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = _qaInitialPage.clamp(0, widget.pages.length - 1);
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _setPage(int index) {
    if (index == _currentPage) return;
    setState(() => _currentPage = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Row(
            children: [
              for (var index = 0; index < widget.pages.length; index++) ...[
                Expanded(
                  child: _WeeklyPageTab(
                    label: widget.pages[index].title,
                    selected: index == _currentPage,
                    onTap: () => _setPage(index),
                  ),
                ),
                if (index < widget.pages.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        Expanded(
          child: PageView.builder(
            key: const ValueKey('weekly-page-view'),
            controller: _pageController,
            itemCount: widget.pages.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              return ListView(
                key: PageStorageKey<String>('weekly-page-$index'),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 132),
                children: widget.pages[index].children,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _WeeklyPageTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _WeeklyPageTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? AuroraColors.purple.withValues(alpha: 0.13)
                  : Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? AuroraColors.purple.withValues(alpha: 0.36)
                    : AuroraColors.line,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AuroraColors.purple.withValues(alpha: 0.10),
                        blurRadius: 14,
                        offset: const Offset(0, 7),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: theme.textTheme.labelMedium?.copyWith(
                color: selected ? AuroraColors.purple : AuroraColors.muted,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WeeklyDrainChainCard extends StatelessWidget {
  final WeeklyV3CStructureModel structure;

  const _WeeklyDrainChainCard({required this.structure});

  @override
  Widget build(BuildContext context) {
    final nodes = _weeklyDrainNodes(context, structure);
    return AuroraCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocaleText.tr(
              context,
              en: 'Main drain chain',
              zhHans: '主要消耗链',
              zhHant: '主要消耗鏈',
              ja: '主な消耗の流れ',
            ),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < nodes.length; i++) ...[
                Expanded(
                  child: Column(
                    children: [
                      AuroraSoftIconCircle(
                        icon: nodes[i].icon,
                        color: nodes[i].color,
                        size: 48,
                        iconSize: 23,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        nodes[i].label,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: AuroraColors.ink,
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                ),
                      ),
                    ],
                  ),
                ),
                if (i != nodes.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 22,
                      color: AuroraColors.muted.withValues(alpha: 0.66),
                    ),
                  ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Text(
            structure.onePattern,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AuroraColors.muted,
                  height: 1.35,
                ),
          ),
        ],
      ),
    );
  }

  List<_WeeklyDrainNode> _weeklyDrainNodes(
    BuildContext context,
    WeeklyV3CStructureModel structure,
  ) {
    final pattern = _compactNodeLabel(structure.onePattern);
    final experiment = _compactNodeLabel(structure.oneExperiment);
    final positive = _compactNodeLabel(structure.positiveSignal);
    return [
      _WeeklyDrainNode(
        label: pattern.isNotEmpty
            ? pattern
            : AppLocaleText.tr(
                context,
                en: 'Main pattern',
                zhHans: '主要模式',
                zhHant: '主要模式',
                ja: '主なパターン',
              ),
        icon: Icons.center_focus_strong_rounded,
        color: AuroraColors.purple,
      ),
      _WeeklyDrainNode(
        label: AppLocaleText.tr(
          context,
          en: 'Drain point',
          zhHans: '消耗点',
          zhHant: '消耗點',
          ja: '消耗点',
        ),
        icon: Icons.bolt_rounded,
        color: AuroraColors.orange,
      ),
      _WeeklyDrainNode(
        label: AppLocaleText.tr(
          context,
          en: 'Energy load',
          zhHans: '能量负荷',
          zhHant: '能量負荷',
          ja: '負荷',
        ),
        icon: Icons.battery_saver_rounded,
        color: AuroraColors.blue,
      ),
      _WeeklyDrainNode(
        label: experiment.isNotEmpty
            ? experiment
            : AppLocaleText.tr(
                context,
                en: 'Goal',
                zhHans: '目标',
                zhHant: '目標',
                ja: '目標',
              ),
        icon: Icons.science_outlined,
        color: AuroraColors.mint,
      ),
      _WeeklyDrainNode(
        label: positive.isNotEmpty
            ? positive
            : AppLocaleText.tr(
                context,
                en: 'Recovery clue',
                zhHans: '恢复线索',
                zhHant: '恢復線索',
                ja: '回復の手がかり',
              ),
        icon: Icons.wb_twilight_rounded,
        color: AuroraColors.gold,
      ),
    ];
  }

  String _compactNodeLabel(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    final separators = RegExp(r'[：:，,。.\n]');
    final first = trimmed.split(separators).first.trim();
    final source = first.isEmpty ? trimmed : first;
    if (source.runes.length <= 9) return source;
    return String.fromCharCodes(source.runes.take(9));
  }
}

class _WeeklyDrainNode {
  final String label;
  final IconData icon;
  final Color color;

  const _WeeklyDrainNode({
    required this.label,
    required this.icon,
    required this.color,
  });
}

class _DrainSourcesCard extends StatelessWidget {
  final WeeklyInsightModel weekly;
  final EnergyBudgetModel? budget;

  const _DrainSourcesCard({
    required this.weekly,
    required this.budget,
  });

  @override
  Widget build(BuildContext context) {
    final sources = _buildSources(context);
    return AuroraCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                AppLocaleText.tr(
                  context,
                  en: 'Drain sources',
                  zhHans: '消耗来源',
                  zhHant: '消耗來源',
                  ja: '消耗の来源',
                ),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
              ),
              const Spacer(),
              Text(
                AppLocaleText.tr(
                  context,
                  en: 'This week',
                  zhHans: '本周',
                  zhHant: '本週',
                  ja: '今週',
                ),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AuroraColors.muted,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (sources.isEmpty)
            Text(
              AppLocaleText.tr(
                context,
                en: 'A clearer ranking will appear after a few more signals.',
                zhHans: '再多几条信号后，这里会出现更可靠的来源排序。',
                zhHant: '再多幾條信號後，這裡會出現更可靠的來源排序。',
                ja: 'もう少しシグナルが集まると、ここに来源の並びが表示されます。',
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AuroraColors.muted,
                  ),
            )
          else
            for (final source in sources) ...[
              _DrainSourceRow(
                icon: source.icon,
                label: source.label,
                value: source.value,
              ),
              if (source != sources.last) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  List<_DrainSourceData> _buildSources(BuildContext context) {
    final blocks = [...?budget?.blocks]
      ..sort((a, b) => b.count.compareTo(a.count));
    if (blocks.isNotEmpty) {
      final total = blocks.fold<int>(0, (sum, block) => sum + block.count);
      final denominator = total == 0 ? 1 : total;
      return blocks.take(4).map((block) {
        return _DrainSourceData(
          icon: _blockIcon(block.type),
          label: _blockLabel(context, block),
          value: block.count / denominator,
        );
      }).toList();
    }

    final items = [
      ...weekly.frictions.whereType<Map>(),
      ...weekly.patterns.whereType<Map>(),
    ];
    if (items.isEmpty) return const [];
    final take = items.take(4).toList();
    final denominator = take.length;
    return [
      for (var i = 0; i < take.length; i++)
        _DrainSourceData(
          icon: _rankIcon(i),
          label: _itemName(take[i]),
          value: (denominator - i) / denominator,
        ),
    ];
  }

  String _itemName(Map item) {
    final raw = item['name'] ?? item['title'] ?? item['label'];
    final text = raw?.toString().trim() ?? '';
    return text.isEmpty ? 'Signal' : text;
  }

  IconData _rankIcon(int index) {
    const icons = [
      Icons.notifications_none_rounded,
      Icons.calendar_month_rounded,
      Icons.help_outline_rounded,
      Icons.groups_rounded,
    ];
    return icons[index.clamp(0, icons.length - 1)];
  }

  IconData _blockIcon(String type) {
    switch (type) {
      case 'high_switching':
        return Icons.swap_horiz_rounded;
      case 'deep':
        return Icons.center_focus_strong_rounded;
      case 'recovery':
        return Icons.nights_stay_outlined;
      case 'boundary':
        return Icons.health_and_safety_outlined;
      case 'buffer':
        return Icons.hourglass_empty_rounded;
      default:
        return Icons.bolt_rounded;
    }
  }

  String _blockLabel(BuildContext context, EnergyBlockModel block) {
    switch (block.type) {
      case 'high_switching':
        return AppLocaleText.tr(context,
            en: 'Switching load', zhHans: '切换消耗', zhHant: '切換消耗', ja: '切替負荷');
      case 'deep':
        return AppLocaleText.tr(context,
            en: 'Deep work', zhHans: '深度投入', zhHant: '深度投入', ja: '深い作業');
      case 'recovery':
        return AppLocaleText.tr(context,
            en: 'Recovery clue', zhHans: '恢复线索', zhHant: '恢復線索', ja: '回復の手がかり');
      case 'boundary':
        return AppLocaleText.tr(context,
            en: 'Boundary load', zhHans: '边界负荷', zhHant: '邊界負荷', ja: '境界の負荷');
      case 'buffer':
        return AppLocaleText.tr(context,
            en: 'Buffer need', zhHans: '缓冲需求', zhHant: '緩衝需求', ja: '余白の必要');
      default:
        return AppLocaleText.tr(context,
            en: 'High drain', zhHans: '高消耗', zhHant: '高消耗', ja: '高い消耗');
    }
  }
}

class _DrainSourceData {
  final IconData icon;
  final String label;
  final double value;

  const _DrainSourceData({
    required this.icon,
    required this.label,
    required this.value,
  });
}

class _DrainSourceRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;

  const _DrainSourceRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AuroraColors.purple, size: 22),
        const SizedBox(width: 10),
        SizedBox(
          width: 92,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AuroraColors.ink,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(
              children: [
                Container(
                  height: 8,
                  color: AuroraColors.line.withValues(alpha: 0.42),
                ),
                FractionallySizedBox(
                  widthFactor: value.clamp(0.0, 1.0),
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AuroraColors.purple.withValues(alpha: 0.78),
                          AuroraColors.blue.withValues(alpha: 0.58),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 38,
          child: Text(
            '${(value * 100).round()}%',
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AuroraColors.ink,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }
}

class _OneWeeklyFocusCard extends StatelessWidget {
  final WeeklyTopicFocusModel topic;

  const _OneWeeklyFocusCard({required this.topic});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: () => _showWeeklyHint(
        context,
        AppLocaleText.tr(
          context,
          en: 'This is the one direction to keep visible this week.',
          zhHans: '这是这周先放在眼前的一个观察方向。',
          zhHant: '這是這週先放在眼前的一個觀察方向。',
          ja: 'これは今週、まず見える場所に置いておく一つの方向です。',
        ),
      ),
      child: AuroraCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            const AuroraSoftIconCircle(
              icon: Icons.center_focus_strong_rounded,
              color: AuroraColors.purple,
              size: 54,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'One Weekly Focus',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AuroraColors.purple,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    topic.nextWatch,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AuroraColors.ink,
                          height: 1.35,
                        ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AuroraColors.muted),
          ],
        ),
      ),
    );
  }
}

class _TopicFocusCard extends StatelessWidget {
  final WeeklyTopicFocusModel topic;
  final bool isLightReady;

  const _TopicFocusCard({
    required this.topic,
    required this.isLightReady,
  });

  @override
  Widget build(BuildContext context) {
    return _UnifiedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocaleText.tr(
              context,
              en: 'This week’s key topic',
              zhHans: '本周重点议题',
              zhHant: '本週重點議題',
              ja: '今週の重点トピック',
            ),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          const SwitchingGapVisual(),
          const SizedBox(height: 12),
          _TopicRow(
            label: AppLocaleText.tr(
              context,
              en: 'Topic',
              zhHans: '议题',
              zhHant: '議題',
              ja: 'トピック',
            ),
            value: topic.headline,
          ),
          const SizedBox(height: 10),
          _TopicRow(
            label: AppLocaleText.tr(
              context,
              en: 'Why it matters now',
              zhHans: '为什么这周先看这个',
              zhHant: '為什麼這週先看這個',
              ja: 'なぜ今週はこれを見るのか',
            ),
            value: topic.reason,
          ),
          const SizedBox(height: 10),
          _TopicRow(
            label: isLightReady
                ? AppLocaleText.tr(
                    context,
                    en: 'Keep watching',
                    zhHans: '接下来继续看',
                    zhHant: '接下來繼續看',
                    ja: 'このあと見続けること',
                  )
                : AppLocaleText.tr(
                    context,
                    en: 'Watch next week',
                    zhHans: '下周先观察',
                    zhHant: '下週先觀察',
                    ja: '来週はまず何を見るか',
                  ),
            value: topic.nextWatch,
          ),
        ],
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  final String label;
  final String value;

  const _TopicRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 4),
        Text(value),
      ],
    );
  }
}

class _WeeklyV3CStructureCard extends StatelessWidget {
  final WeeklyV3CStructureModel structure;
  final bool isLightReady;

  const _WeeklyV3CStructureCard({
    required this.structure,
    required this.isLightReady,
  });

  @override
  Widget build(BuildContext context) {
    return _UnifiedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocaleText.tr(
              context,
              en: 'This week, you can look at it this way',
              zhHans: '这周可以先这样看',
              zhHant: '這週可以先這樣看',
              ja: '今週はまずこう見てみる',
            ),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          const ExperimentPathVisual(),
          const SizedBox(height: 8),
          _WeeklyStructureRow(
            icon: Icons.notes_outlined,
            label: AppLocaleText.tr(
              context,
              en: 'Small observation',
              zhHans: '本周小观察',
              zhHant: '本週小觀察',
              ja: '今週の小さな観察',
            ),
            value: structure.lightObservation,
          ),
          const SizedBox(height: 12),
          _WeeklyStructureRow(
            icon: Icons.blur_linear_outlined,
            label: AppLocaleText.tr(
              context,
              en: 'One pattern',
              zhHans: '一个最消耗的模式',
              zhHant: '一個最消耗的模式',
              ja: '一つの消耗 pattern',
            ),
            value: structure.onePattern,
          ),
          const SizedBox(height: 12),
          _WeeklyStructureRow(
            icon: Icons.science_outlined,
            label: AppLocaleText.tr(
              context,
              en: 'One goal',
              zhHans: '一个低成本目标',
              zhHant: '一個低成本目標',
              ja: '負担の少ない目標を一つ',
            ),
            value: structure.oneExperiment,
          ),
          const SizedBox(height: 12),
          _WeeklyStructureRow(
            icon: Icons.spa_outlined,
            label: AppLocaleText.tr(
              context,
              en: 'Recovery signal',
              zhHans: '一个恢复线索',
              zhHant: '一個恢復線索',
              ja: '回復の手がかり',
            ),
            value: structure.positiveSignal,
          ),
        ],
      ),
    );
  }
}

class _WeeklyStructureRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _WeeklyStructureRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              Text(value),
            ],
          ),
        ),
      ],
    );
  }
}

class _EnergyBudgetLiteCard extends StatelessWidget {
  final EnergyBudgetModel? budget;

  const _EnergyBudgetLiteCard({
    required this.budget,
  });

  @override
  Widget build(BuildContext context) {
    final value = budget;
    final isFallback = value == null || value.status == 'insufficient_data';
    final energyStates = _WeeklyEnergyStateData.fromBudget(value);

    return _UnifiedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AuroraSectionIcon(
                icon: Icons.battery_charging_full_rounded,
                color: AuroraColors.mint,
                size: 30,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'This week’s energy state',
                    zhHans: '本周能量状态',
                    zhHant: '本週能量狀態',
                    ja: '今週のエネルギー状態',
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF213052),
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: AuroraColors.purple.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: AuroraColors.purple.withValues(alpha: 0.16),
                  ),
                ),
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: isFallback ? 'Forming' : 'Initial read',
                    zhHans: isFallback ? '形成中' : '初步形成',
                    zhHant: isFallback ? '形成中' : '初步形成',
                    ja: isFallback ? '形成中' : '初期の見立て',
                  ),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AuroraColors.purple,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _WeeklyEnergyStateOverview(states: energyStates),
          if (!isFallback) ...[
            const SizedBox(height: 12),
            _WeeklyEnergyCallout(
              icon: Icons.bolt_rounded,
              color: AuroraColors.orange,
              label: AppLocaleText.tr(
                context,
                en: 'Draining clue',
                zhHans: '偏耗力线索',
                zhHant: '偏耗力線索',
                ja: 'やや消耗する手がかり',
              ),
              value: EnergyBudgetText.localizeCopy(
                context,
                value.mostDrainingSource,
              ),
            ),
            const SizedBox(height: 8),
            _WeeklyEnergyCallout(
              icon: Icons.eco_rounded,
              color: AuroraColors.mint,
              label: AppLocaleText.tr(
                context,
                en: 'Recovery clue',
                zhHans: '恢复线索',
                zhHant: '恢復線索',
                ja: '回復の手がかり',
              ),
              value: EnergyBudgetText.localizeCopy(
                context,
                value.recoveryClue,
              ),
            ),
            const SizedBox(height: 8),
            _WeeklyEnergyCallout(
              icon: Icons.shield_outlined,
              color: AuroraColors.purple,
              label: AppLocaleText.tr(
                context,
                en: 'Boundary and room',
                zhHans: '边界与余地',
                zhHant: '邊界與餘地',
                ja: '境界と余白',
              ),
              value: [
                EnergyBudgetText.localizeCopy(
                  context,
                  value.bufferLocation,
                ),
                EnergyBudgetText.localizeCopy(
                  context,
                  value.switchingAdjustment,
                ),
              ].where((text) => text.trim().isNotEmpty).join(' · '),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            isFallback
                ? _energyStrengthText(context, value)
                : AppLocaleText.tr(
                    context,
                    en: 'Next-week goals will prioritize a light, low-switching, pausable daily practice.',
                    zhHans: '下周候选将优先采用 3–5 分钟、低切换、可暂停的轻量尝试。',
                    zhHant: '下週候選將優先採用 3–5 分鐘、低切換、可暫停的輕量嘗試。',
                    ja: '来週は短時間・切替少なめ・中断できる軽い候補を優先します。',
                  ),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF536077),
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}

enum _WeeklyEnergyStateKind {
  draining,
  steady,
  ease,
  recovery,
  boundaryBuffer,
}

extension on _WeeklyEnergyStateKind {
  String get key => switch (this) {
        _WeeklyEnergyStateKind.draining => 'draining',
        _WeeklyEnergyStateKind.steady => 'steady',
        _WeeklyEnergyStateKind.ease => 'ease',
        _WeeklyEnergyStateKind.recovery => 'recovery',
        _WeeklyEnergyStateKind.boundaryBuffer => 'boundary_buffer',
      };

  Color get color => switch (this) {
        _WeeklyEnergyStateKind.draining => AuroraColors.orange,
        _WeeklyEnergyStateKind.steady => AuroraColors.blue,
        _WeeklyEnergyStateKind.ease => AuroraColors.gold,
        _WeeklyEnergyStateKind.recovery => AuroraColors.mint,
        _WeeklyEnergyStateKind.boundaryBuffer => AuroraColors.purple,
      };

  IconData get icon => switch (this) {
        _WeeklyEnergyStateKind.draining => Icons.bolt_rounded,
        _WeeklyEnergyStateKind.steady => Icons.horizontal_rule_rounded,
        _WeeklyEnergyStateKind.ease => Icons.wb_sunny_outlined,
        _WeeklyEnergyStateKind.recovery => Icons.eco_rounded,
        _WeeklyEnergyStateKind.boundaryBuffer => Icons.shield_outlined,
      };

  String label(BuildContext context) => switch (this) {
        _WeeklyEnergyStateKind.draining => AppLocaleText.tr(
            context,
            en: 'Draining',
            zhHans: '偏耗力',
            zhHant: '偏耗力',
            ja: 'やや消耗',
          ),
        _WeeklyEnergyStateKind.steady => AppLocaleText.tr(
            context,
            en: 'Steady',
            zhHans: '平稳',
            zhHant: '平穩',
            ja: '安定',
          ),
        _WeeklyEnergyStateKind.ease => AppLocaleText.tr(
            context,
            en: 'At ease',
            zhHans: '有余力',
            zhHant: '有餘力',
            ja: '余力あり',
          ),
        _WeeklyEnergyStateKind.recovery => AppLocaleText.tr(
            context,
            en: 'Recovering',
            zhHans: '恢复',
            zhHant: '恢復',
            ja: '回復',
          ),
        _WeeklyEnergyStateKind.boundaryBuffer => AppLocaleText.tr(
            context,
            en: 'Boundary & room',
            zhHans: '边界与余地',
            zhHant: '邊界與餘地',
            ja: '境界と余白',
          ),
      };

  String description(BuildContext context) => switch (this) {
        _WeeklyEnergyStateKind.draining => AppLocaleText.tr(
            context,
            en: 'Uses noticeably more energy',
            zhHans: '明显更费力',
            zhHant: '明顯更費力',
            ja: '明らかに力を使う',
          ),
        _WeeklyEnergyStateKind.steady => AppLocaleText.tr(
            context,
            en: 'Neither draining nor clearly restorative',
            zhHans: '不太耗力，也非明显恢复',
            zhHant: '不太耗力，也非明顯恢復',
            ja: '消耗も回復も目立たない',
          ),
        _WeeklyEnergyStateKind.ease => AppLocaleText.tr(
            context,
            en: 'Feels light with capacity left',
            zhHans: '轻松，还有余力',
            zhHant: '輕鬆，還有餘力',
            ja: '軽く、余力が残る',
          ),
        _WeeklyEnergyStateKind.recovery => AppLocaleText.tr(
            context,
            en: 'Helps energy return',
            zhHans: '状态正在往回收',
            zhHant: '狀態正在往回收',
            ja: '状態が戻ってくる',
          ),
        _WeeklyEnergyStateKind.boundaryBuffer => AppLocaleText.tr(
            context,
            en: 'Protects limits or leaves room',
            zhHans: '守住边界，留出空间',
            zhHant: '守住邊界，留出空間',
            ja: '境界を守り、余白を残す',
          ),
      };
}

class _WeeklyEnergyStateData {
  final Map<_WeeklyEnergyStateKind, int> counts;

  const _WeeklyEnergyStateData(this.counts);

  factory _WeeklyEnergyStateData.fromBudget(EnergyBudgetModel? budget) {
    final counts = {
      for (final state in _WeeklyEnergyStateKind.values) state: 0,
    };
    final source = budget?.energyStateCounts ?? const <String, int>{};
    for (final entry in source.entries) {
      final state = _stateForRawEnergyKey(entry.key);
      counts[state] = (counts[state] ?? 0) + math.max(0, entry.value);
    }

    // Old cached snapshots may only have energy blocks. Keep their projection
    // readable, while new snapshots always provide the five canonical keys.
    if (counts.values.every((count) => count == 0)) {
      for (final block in budget?.blocks ?? const <EnergyBlockModel>[]) {
        final state = _stateForRawEnergyKey(block.type);
        counts[state] = (counts[state] ?? 0) + math.max(0, block.count);
      }
    }
    return _WeeklyEnergyStateData(counts);
  }

  int countFor(_WeeklyEnergyStateKind state) => counts[state] ?? 0;

  int get total => counts.values.fold(0, (sum, count) => sum + count);

  static _WeeklyEnergyStateKind _stateForRawEnergyKey(String raw) {
    final key = raw.trim().toLowerCase().replaceAll('-', '_');
    return switch (key) {
      'draining' ||
      'high_drain' ||
      'high_switching' ||
      'drain' =>
        _WeeklyEnergyStateKind.draining,
      'ease' ||
      'at_ease' ||
      'light' ||
      'low_load' ||
      'resourced' =>
        _WeeklyEnergyStateKind.ease,
      'recovery' || 'restoring' => _WeeklyEnergyStateKind.recovery,
      'boundary_buffer' ||
      'boundary' ||
      'buffer' =>
        _WeeklyEnergyStateKind.boundaryBuffer,
      // Legacy neutral/deep values and any stale unknown value are projected
      // into the defined steady state. No sixth/gray category is created.
      _ => _WeeklyEnergyStateKind.steady,
    };
  }
}

class _WeeklyEnergyStateOverview extends StatelessWidget {
  final _WeeklyEnergyStateData states;

  const _WeeklyEnergyStateOverview({required this.states});

  @override
  Widget build(BuildContext context) {
    final semantics = _WeeklyEnergyStateKind.values
        .map((state) => '${state.label(context)} ${states.countFor(state)}')
        .join('，');
    final ring = Semantics(
      key: const ValueKey('weekly-energy-state-ring'),
      label: AppLocaleText.tr(
        context,
        en: 'Weekly energy states. $semantics',
        zhHans: '本周能量状态。$semantics',
        zhHant: '本週能量狀態。$semantics',
        ja: '今週のエネルギー状態。$semantics',
      ),
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: 132,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _WeeklyEnergyStateRingPainter(states),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      states.total == 0 ? '—' : '${states.total}',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: AuroraColors.ink,
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    Text(
                      states.total == 0
                          ? AppLocaleText.tr(
                              context,
                              en: 'Forming',
                              zhHans: '形成中',
                              zhHant: '形成中',
                              ja: '形成中',
                            )
                          : 'Signal',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AuroraColors.muted,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final legend = Column(
      children: [
        for (final state in _WeeklyEnergyStateKind.values)
          _WeeklyEnergyStateLegendItem(
            state: state,
            count: states.countFor(state),
          ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = constraints.maxWidth < 310 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.15;
        if (stack) {
          return Column(
            children: [
              ring,
              const SizedBox(height: 12),
              legend,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ring,
            const SizedBox(width: 14),
            Expanded(child: legend),
          ],
        );
      },
    );
  }
}

class _WeeklyEnergyStateLegendItem extends StatelessWidget {
  final _WeeklyEnergyStateKind state;
  final int count;

  const _WeeklyEnergyStateLegendItem({
    required this.state,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: ValueKey('weekly-energy-state-${state.key}'),
      label:
          '${state.label(context)}，${state.description(context)}，$count Signal',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: state.color.withValues(alpha: 0.13),
                  shape: BoxShape.circle,
                ),
                child: Icon(state.icon, size: 15, color: state.color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.label(context),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: const Color(0xFF22304A),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      state.description(context),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AuroraColors.muted,
                            height: 1.25,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$count',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: state.color,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeeklyEnergyStateRingPainter extends CustomPainter {
  final _WeeklyEnergyStateData states;

  const _WeeklyEnergyStateRingPainter(this.states);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(14);
    const gap = 0.055;
    var start = -math.pi / 2;
    final total = states.total;

    for (final state in _WeeklyEnergyStateKind.values) {
      final count = states.countFor(state);
      final fraction = total == 0 ? 0.2 : count / total;
      final sweep = math.max(0.0, math.pi * 2 * fraction - gap);
      if (sweep > 0) {
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 16
          ..strokeCap = StrokeCap.round
          ..color = state.color.withValues(alpha: total == 0 ? 0.22 : 0.88);
        canvas.drawArc(arcRect, start + gap / 2, sweep, false, paint);
      }
      start += math.pi * 2 * fraction;
    }
  }

  @override
  bool shouldRepaint(covariant _WeeklyEnergyStateRingPainter oldDelegate) {
    return oldDelegate.states.counts.toString() != states.counts.toString();
  }
}

class _WeeklyEnergyCallout extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _WeeklyEnergyCallout({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF536077),
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                children: [
                  TextSpan(
                    text: '$label  ',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(text: value.trim()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnergyBudgetRows extends StatelessWidget {
  final EnergyBudgetModel? budget;

  const _EnergyBudgetRows({required this.budget});

  @override
  Widget build(BuildContext context) {
    final value = budget;
    if (value == null || value.status == 'insufficient_data') {
      return _EnergyBudgetRow(
        label: AppLocaleText.tr(
          context,
          en: 'Energy change',
          zhHans: '能量变化',
          zhHant: '能量變化',
          ja: 'エネルギー変化',
        ),
        value: value?.mostDrainingSource.trim().isNotEmpty == true
            ? EnergyBudgetText.localizeCopy(
                context,
                value!.mostDrainingSource,
              )
            : AppLocaleText.tr(
                context,
                en: 'Energy signals are still forming. Keep the next goal and its daily practice very light.',
                zhHans: '能量线索还在形成中，下周目标和每日做法先保持很轻。',
                zhHant: '能量線索還在形成中，下週目標和每日做法先保持很輕。',
                ja: 'エネルギーの手がかりは形成中です。次の目標と毎日の取り組みは軽くします。',
              ),
      );
    }

    final rows = [
      (
        AppLocaleText.tr(
          context,
          en: 'Costly point',
          zhHans: '耗力点',
          zhHant: '耗力點',
          ja: '消耗点',
        ),
        EnergyBudgetText.localizeCopy(context, value.mostDrainingSource)
      ),
      (
        AppLocaleText.tr(
          context,
          en: 'Recovery clue',
          zhHans: '恢复线索',
          zhHant: '恢復線索',
          ja: '回復の手がかり',
        ),
        EnergyBudgetText.localizeCopy(context, value.recoveryClue)
      ),
      (
        AppLocaleText.tr(
          context,
          en: 'Daily-practice intensity',
          zhHans: '每日做法强度',
          zhHant: '每日做法強度',
          ja: '毎日の取り組みの強さ',
        ),
        _energyStrengthText(context, value)
      ),
    ].where((row) => row.$2.trim().isNotEmpty).toList();

    return Column(
      children: [
        for (final row in rows.take(3))
          _EnergyBudgetRow(label: row.$1, value: row.$2),
      ],
    );
  }
}

class _EnergyIntensityPill extends StatelessWidget {
  final EnergyBudgetModel? budget;

  const _EnergyIntensityPill({required this.budget});

  @override
  Widget build(BuildContext context) {
    final label = _energyStrengthText(context, budget);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AuroraColors.blue.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: AuroraColors.blue.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.battery_saver_rounded,
              size: 16,
              color: AuroraColors.blue,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AuroraColors.blue,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _energyStrengthText(BuildContext context, EnergyBudgetModel? budget) {
  final value = budget;
  if (value == null || value.status == 'insufficient_data') {
    return AppLocaleText.tr(
      context,
      en: 'Very light daily practice',
      zhHans: '先用很轻的每日做法',
      zhHant: '先用很輕的每日做法',
      ja: 'とても軽い毎日の取り組み',
    );
  }

  final hasHighLoad = value.blocks.any(
      (block) => block.type == 'high_drain' || block.type == 'high_switching');
  final hasRecovery = value.blocks.any((block) => block.type == 'recovery');

  if (hasHighLoad) {
    return AppLocaleText.tr(
      context,
      en: 'Lower the daily-practice intensity',
      zhHans: '根据能量变化调轻每日做法',
      zhHant: '根據能量變化調輕每日做法',
      ja: 'エネルギーに合わせて毎日の取り組みを軽くする',
    );
  }
  if (hasRecovery) {
    return AppLocaleText.tr(
      context,
      en: 'Keep the recovery-friendly version',
      zhHans: '保留更容易恢复的版本',
      zhHant: '保留更容易恢復的版本',
      ja: '回復しやすい形で続ける',
    );
  }
  return AppLocaleText.tr(
    context,
    en: 'Keep it small and buffered',
    zhHans: '保持小一点，并留出余地',
    zhHant: '保持小一點，並留出餘地',
    ja: '小さく、余白を残す',
  );
}

class _EnergyDistributionBar extends StatelessWidget {
  final List<EnergyBlockModel> blocks;

  const _EnergyDistributionBar({required this.blocks});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (blocks.isEmpty) {
      return Text(
        AppLocaleText.tr(
          context,
          en: 'Energy blocks will appear here once a few signals have enough shape.',
          zhHans: '等几条信号更成形后，这里会出现轻量能量块。',
          zhHant: '等幾條信號更成形後，這裡會出現輕量能量塊。',
          ja: 'いくつかのシグナルが見えてくると、ここに小さな energy block が表示されます。',
        ),
        style: theme.textTheme.bodySmall,
      );
    }

    final total = blocks.fold<int>(0, (sum, block) => sum + block.count);
    final safeTotal = total == 0 ? 1 : total;
    final colors = <Color>[
      const Color(0xFF8B7CF6),
      const Color(0xFFFF9B58),
      const Color(0xFFFFCD62),
      const Color(0xFF74D58C),
      const Color(0xFF64A8F7),
    ];
    final visibleBlocks = blocks.take(5).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final block in visibleBlocks)
              Text(
                '${(block.count * 100 / safeTotal).round()}%',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 16,
            child: Row(
              children: [
                for (var i = 0; i < visibleBlocks.length; i++)
                  Expanded(
                    flex: (visibleBlocks[i].count * 100 / safeTotal)
                        .round()
                        .clamp(1, 100),
                    child: Container(
                      height: 16,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colors[i % colors.length].withValues(alpha: 0.92),
                            colors[i % colors.length].withValues(alpha: 0.62),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            for (var i = 0; i < visibleBlocks.length; i++)
              _EnergyLegendItem(
                color: colors[i % colors.length],
                label: _energyBlockLabel(context, visibleBlocks[i]),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          AppLocaleText.tr(
            context,
            en: 'Display only: this helps read distribution, not performance.',
            zhHans: '仅用于展示分布，不是表现评分。',
            zhHant: '僅用於展示分布，不是表現評分。',
            ja: '表示のみです。分布を見るためのもので、評価ではありません。',
          ),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  String _energyBlockLabel(BuildContext context, EnergyBlockModel block) {
    switch (block.type) {
      case 'high_drain':
      case 'high-drain':
      case 'high-drain block':
        return AppLocaleText.tr(
          context,
          en: 'drain',
          zhHans: '耗力',
          zhHant: '耗力',
          ja: '消耗',
        );
      case 'high_switching':
      case 'high-switching':
      case 'high-switching block':
        return AppLocaleText.tr(
          context,
          en: 'switching',
          zhHans: '切换',
          zhHant: '切換',
          ja: '切替',
        );
      case 'recovery':
      case 'recovery block':
        return AppLocaleText.tr(
          context,
          en: 'recovery',
          zhHans: '恢复',
          zhHant: '恢復',
          ja: '回復',
        );
      case 'boundary':
      case 'boundary block':
        return AppLocaleText.tr(
          context,
          en: 'boundary',
          zhHans: '边界',
          zhHant: '邊界',
          ja: '境界',
        );
      case 'buffer':
      case 'buffer block':
        return AppLocaleText.tr(
          context,
          en: 'buffer',
          zhHans: '余地',
          zhHant: '餘地',
          ja: '余白',
        );
      default:
        return block.label;
    }
  }
}

class _EnergyLegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _EnergyLegendItem({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.28),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _EnergyBudgetRow extends StatelessWidget {
  final String label;
  final String value;

  const _EnergyBudgetRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 3),
          Text(value),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final String text;

  const _MetaPill(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(text, style: theme.textTheme.labelSmall),
      ),
    );
  }
}

class _WeeklyActionReviewCard extends StatelessWidget {
  final WeeklyActionReviewModel review;

  const _WeeklyActionReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _UnifiedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.route_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Small experiment review',
                    zhHans: '本周小实验复盘',
                    zhHant: '本週小實驗回顧',
                    ja: '今週の小実験の振り返り',
                  ),
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionReviewChip(
                label: AppLocaleText.tr(
                  context,
                  en: 'AI predictions',
                  zhHans: 'AI 预判',
                  zhHant: 'AI 預判',
                  ja: 'AI 予測',
                ),
                value: review.aiJudgementCount,
                color: AuroraColors.purple,
              ),
              _ActionReviewChip(
                label: AppLocaleText.tr(
                  context,
                  en: 'Confirmed',
                  zhHans: '用户确认',
                  zhHant: '使用者確認',
                  ja: '確認済み',
                ),
                value: review.confirmedJudgementCount,
                color: AuroraColors.mint,
              ),
              _ActionReviewChip(
                label: AppLocaleText.tr(
                  context,
                  en: 'Small experiments',
                  zhHans: '生成小实验',
                  zhHant: '生成小實驗',
                  ja: '小実験',
                ),
                value: review.generatedActionCount,
                color: AuroraColors.blue,
              ),
              _ActionReviewChip(
                label: AppLocaleText.tr(
                  context,
                  en: 'Tried',
                  zhHans: '实际尝试',
                  zhHant: '實際嘗試',
                  ja: '試した',
                ),
                value: review.triedActionCount,
                color: AuroraColors.gold,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _reviewSentence(context),
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
          if (review.mostHelpfulAction.trim().isNotEmpty ||
              review.hardestAction.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _ActionReviewLine(
              icon: Icons.favorite_outline_rounded,
              label: AppLocaleText.tr(
                context,
                en: 'Most helpful',
                zhHans: '最有帮助',
                zhHant: '最有幫助',
                ja: '助けになったこと',
              ),
              value: review.mostHelpfulAction.trim().isNotEmpty
                  ? review.mostHelpfulAction
                  : AppLocaleText.tr(
                      context,
                      en: 'Still forming',
                      zhHans: '还在形成',
                      zhHant: '還在形成',
                      ja: 'まだ形成中',
                    ),
              color: AuroraColors.mint,
            ),
            const SizedBox(height: 8),
            _ActionReviewLine(
              icon: Icons.tune_rounded,
              label: AppLocaleText.tr(
                context,
                en: 'Needs adjustment',
                zhHans: '需要调整',
                zhHant: '需要調整',
                ja: '調整したいこと',
              ),
              value: review.hardestAction.trim().isNotEmpty
                  ? review.hardestAction
                  : review.nextAdjustment,
              color: AuroraColors.orange,
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionDecisionButton(
                label: AppLocaleText.tr(
                  context,
                  en: 'Continue',
                  zhHans: '继续这个方向',
                  zhHant: '繼續這個方向',
                  ja: 'この方向を続ける',
                ),
              ),
              _ActionDecisionButton(
                label: AppLocaleText.tr(
                  context,
                  en: 'Make it lighter',
                  zhHans: '调轻一点',
                  zhHant: '調輕一點',
                  ja: '軽くする',
                ),
              ),
              _ActionDecisionButton(
                label: AppLocaleText.tr(
                  context,
                  en: 'Try another',
                  zhHans: '换一个策略',
                  zhHant: '換一個策略',
                  ja: '別の方法へ',
                ),
              ),
              _ActionDecisionButton(
                label: AppLocaleText.tr(
                  context,
                  en: 'Pause',
                  zhHans: '暂时不做',
                  zhHant: '暫時不做',
                  ja: 'いったん休む',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _reviewSentence(BuildContext context) {
    if (!review.hasData) {
      return AppLocaleText.tr(
        context,
        en: 'No small experiment loop has settled yet. This week can still be read as a small observation.',
        zhHans: '这一周还没有形成明确的小实验闭环，先把它当作一个小观察。',
        zhHant: '這一週還沒有形成明確的小實驗閉環，先把它當作一個小觀察。',
        ja: '今週はまだ小実験の循環がはっきりしていません。小さな観察として扱います。',
      );
    }
    return AppLocaleText.tr(
      context,
      en: '${review.aiJudgementCount} AI prediction(s), ${review.confirmedJudgementCount} confirmed, ${review.generatedActionCount} small experiment/tries, ${review.triedActionCount} tried. Next: ${review.nextAdjustment}',
      zhHans:
          '这周有 ${review.aiJudgementCount} 条 AI 预判，${review.confirmedJudgementCount} 条被确认，生成 ${review.generatedActionCount} 个小实验，实际尝试 ${review.triedActionCount} 个。下周可以先看：${review.nextAdjustment}',
      zhHant:
          '這週有 ${review.aiJudgementCount} 條 AI 預判，${review.confirmedJudgementCount} 條被確認，生成 ${review.generatedActionCount} 個小實驗，實際嘗試 ${review.triedActionCount} 個。下週可以先看：${review.nextAdjustment}',
      ja: '今週は AI 予測が ${review.aiJudgementCount} 件、確認済みが ${review.confirmedJudgementCount} 件、小実験が ${review.generatedActionCount} 件、試したものが ${review.triedActionCount} 件。次は「${review.nextAdjustment}」を見ます。',
    );
  }
}

class _ActionReviewChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _ActionReviewChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Text(
        '$label $value',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _ActionReviewLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ActionReviewLine({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$label：$value',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AuroraColors.muted,
                  height: 1.35,
                ),
          ),
        ),
      ],
    );
  }
}

class _ActionDecisionButton extends StatelessWidget {
  final String label;

  const _ActionDecisionButton({required this.label});

  @override
  Widget build(BuildContext context) {
    return AuroraPillButton(
      icon: Icons.check_circle_outline_rounded,
      label: label,
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocaleText.tr(
                context,
                en: 'Saved for the next review.',
                zhHans: '已保存到下一次回看。',
                zhHant: '已保存到下一次回看。',
                ja: '次の振り返りに保存しました。',
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WeeklyInclusionCard extends StatelessWidget {
  final WeeklyInclusionSummaryModel inclusion;

  const _WeeklyInclusionCard({required this.inclusion});

  @override
  Widget build(BuildContext context) {
    return _UnifiedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocaleText.tr(
              context,
              en: 'How your notes were used',
              zhHans: '这些记录是怎么被使用的',
              zhHant: '這些記錄是怎麼被使用的',
              ja: '記録の使われ方',
            ),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Text(
            _summaryText(context),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            AppLocaleText.tr(
              context,
              en: 'Notes marked not quite right or kept out of analysis stay in your Timeline, but are not used for this Weekly.',
              zhHans: '被标记为不太准、或不参与分析的记录，会保留在时间线里，但不会被当成这周判断材料。',
              zhHant: '被標記為不太準、或不參與分析的記錄，會保留在時間線裡，但不會被當成這週判斷材料。',
              ja: 'しっくりこない記録や分析から外した記録はタイムラインに残りますが、今週の見立てには使いません。',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  String _summaryText(BuildContext context) {
    final used = inclusion.usedCount;
    final timelineOnly = inclusion.timelineOnlyCount;
    final legacy = inclusion.legacyReferenceCount;

    return AppLocaleText.tr(
      context,
      en: '$used notes were used for this Weekly. $timelineOnly stayed only in Timeline. $legacy older notes were treated as gentle context.',
      zhHans:
          '$used 条记录进入了这份每周复盘，$timelineOnly 条只保留在时间线。$legacy 条旧记录只作为轻量背景参考。',
      zhHant:
          '$used 條記錄進入了這份 Weekly，$timelineOnly 條只保留在 Timeline。$legacy 條舊記錄只作為輕量背景參考。',
      ja: '$used 件の記録をこの Weekly に使いました。$timelineOnly 件は Timeline にだけ残しています。$legacy 件の古い記録は軽い背景として扱いました。',
    );
  }
}

class _LifeExperimentCard extends StatelessWidget {
  final WeeklyActionPlanModel actionPlan;
  final LifeExperimentModel experiment;
  final SubmitState submitState;
  final Future<void> Function() onSave;
  final Future<void> Function() onSkip;
  final Future<void> Function({
    required String status,
    required String feedbackText,
  }) onFeedback;

  const _LifeExperimentCard({
    required this.actionPlan,
    required this.experiment,
    required this.submitState,
    required this.onSave,
    required this.onSkip,
    required this.onFeedback,
  });

  bool get _isSubmitting => submitState == SubmitState.submitting;

  @override
  Widget build(BuildContext context) {
    final isSaved = experiment.status == 'saved';
    final hasFeedback = const {
      'tried',
      'not_helpful',
      'adjusted',
    }.contains(experiment.status);

    return _UnifiedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.science_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Next week goal',
                    zhHans: '下周目标',
                    zhHant: '下週目標',
                    ja: '来週の目標',
                  ),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            AppLocaleText.tr(
              context,
              en: 'One medium-range goal from this week. Save it with a daily practice to continue in Life Experiment next week.',
              zhHans: '这是从本周信号里提炼出的中期目标。保存每日做法后，下周会在生活小实验中继续。',
              zhHant: '這是從本週信號裡提煉出的中期目標。保存每日做法後，下週會在生活小實驗中繼續。',
              ja: '今週のシグナルからまとめた中期目標です。毎日の取り組みと一緒に保存すると、来週の生活実験で続けられます。',
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AuroraColors.muted,
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 12),
          Text(actionPlan.title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(
            AppLocaleText.tr(
              context,
              en: 'Medium-range goal: ${actionPlan.mediumRangeGoal}',
              zhHans: '中期改善目标：${actionPlan.mediumRangeGoal}',
              zhHant: '中期改善目標：${actionPlan.mediumRangeGoal}',
              ja: '中期の調整目標：${actionPlan.mediumRangeGoal}',
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AuroraColors.muted,
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 6),
          Text(actionPlan.smallExperiment),
          const SizedBox(height: 10),
          Text(
            AppLocaleText.tr(
              context,
              en: 'Life Experiment keeps the goal, daily practice, and feedback; Weekly proposes what to continue next week.',
              zhHans: '生活小实验负责保存目标、每日做法和反馈；每周复盘提出下周继续的方向。',
              zhHant: '生活小實驗負責保存目標、每日做法和回饋；每週回顧提出下週繼續的方向。',
              ja: '生活実験が目標、毎日の取り組み、反応を保存し、週間レビューが来週続ける方向を提案します。',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (experiment.status == 'skipped')
            Text(
              AppLocaleText.tr(
                context,
                en: 'Skipped for now. It stays as context, not a miss.',
                zhHans: '这次先不看。它会作为背景留下，不算错过。',
                zhHant: '這次先不看。它會作為背景留下，不算錯過。',
                ja: '今回は見送っています。失敗ではなく、背景として残ります。',
              ),
            )
          else if (hasFeedback)
            Text(
              AppLocaleText.tr(
                context,
                en: 'Your feedback is saved for the next review.',
                zhHans: '你的反馈已经保存，会进入下一次回看。',
                zhHant: '你的回饋已經保存，會進入下一次回看。',
                ja: 'フィードバックは次の振り返り用に保存されています。',
              ),
            )
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _isSubmitting || isSaved ? null : onSave,
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: Text(
                    AppLocaleText.tr(
                      context,
                      en: isSaved ? 'Saved' : 'Save',
                      zhHans: isSaved ? '已保存' : '保存',
                      zhHant: isSaved ? '已保存' : '保存',
                      ja: isSaved ? '保存済み' : '保存',
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _isSubmitting ? null : onSkip,
                  child: Text(
                    AppLocaleText.tr(
                      context,
                      en: 'Not now',
                      zhHans: '稍后再看',
                      zhHant: '稍後再看',
                      ja: '今は見送る',
                    ),
                  ),
                ),
              ],
            ),
            if (isSaved) ...[
              const SizedBox(height: 12),
              Text(
                AppLocaleText.tr(
                  context,
                  en: 'Did this design save you a little energy?',
                  zhHans: '这个尝试有没有帮你省一点力？',
                  zhHant: '這個嘗試有沒有幫你省一點力？',
                  ja: 'この設計は少し楽にしてくれましたか？',
                ),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: _isSubmitting
                        ? null
                        : () => onFeedback(
                              status: 'tried',
                              feedbackText: 'Helped a little',
                            ),
                    child: Text(
                      AppLocaleText.tr(
                        context,
                        en: 'Helped a little',
                        zhHans: '有一点帮助',
                        zhHant: '有一點幫助',
                        ja: '少し助かった',
                      ),
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: _isSubmitting
                        ? null
                        : () => onFeedback(
                              status: 'adjusted',
                              feedbackText: 'Needs adjustment',
                            ),
                    child: Text(
                      AppLocaleText.tr(
                        context,
                        en: 'Needs adjustment',
                        zhHans: '需要调整',
                        zhHant: '需要調整',
                        ja: '調整したい',
                      ),
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: _isSubmitting
                        ? null
                        : () => onFeedback(
                              status: 'not_helpful',
                              feedbackText: 'Not helpful this time',
                            ),
                    child: Text(
                      AppLocaleText.tr(
                        context,
                        en: 'Not helpful this time',
                        zhHans: '这次帮助不明显',
                        zhHant: '這次幫助不明顯',
                        ja: '今回はあまり合わない',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _CompositeChartCard extends StatelessWidget {
  final List<WeeklyChartPointModel> points;
  final bool isLightReady;

  const _CompositeChartCard({
    required this.points,
    required this.isLightReady,
  });

  @override
  Widget build(BuildContext context) {
    final safePoints = points.isEmpty ? _emptyWeekPoints() : points;
    final humanSummary = _buildHumanSummary(context, safePoints, isLightReady);

    return _UnifiedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocaleText.tr(
              context,
              en: 'Signal density and weekly trend',
              zhHans: '线索密度与本周走势',
              zhHant: '線索密度與本週走勢',
              ja: '手がかりの密度と今週の流れ',
            ),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            humanSummary,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 220,
            width: double.infinity,
            child: _CompositeWeeklyChart(points: safePoints),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              _LegendItem(
                label: AppLocaleText.tr(
                  context,
                  en: 'Bars = signal count',
                  zhHans: '柱状 = 线索数量',
                  zhHant: '柱狀 = 線索數量',
                  ja: '棒 = 手がかりの数',
                ),
                kind: _LegendKind.bar,
              ),
              _LegendItem(
                label: AppLocaleText.tr(
                  context,
                  en: 'Line = weekly trend',
                  zhHans: '折线 = 本周走势',
                  zhHant: '折線 = 本週走勢',
                  ja: '折れ線 = 今週の流れ',
                ),
                kind: _LegendKind.line,
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<WeeklyChartPointModel> _emptyWeekPoints() {
    return List.generate(
      7,
      (index) => WeeklyChartPointModel(
        date: 'day$index',
        signalCount: 0,
        moodScore: 0,
        frictionScore: 0,
        hasPositiveSignal: false,
      ),
    );
  }

  String _buildHumanSummary(
    BuildContext context,
    List<WeeklyChartPointModel> points,
    bool isLightReady,
  ) {
    final peak = points.reduce(
      (a, b) => a.signalCount >= b.signalCount ? a : b,
    );
    final avgMood = points.isEmpty
        ? 0.0
        : points.map((e) => e.moodScore).reduce((a, b) => a + b) /
            points.length;

    final peakDay = _dayLabel(context, peak.date);

    if (isLightReady) {
      if (peak.signalCount <= 0) {
        return AppLocaleText.tr(
          context,
          en: 'Signals are starting to gather, but it is still too early to say much more.',
          zhHans: '线索已经开始聚起来了，但现在还比较早，先不下太重判断。',
          zhHant: '線索已經開始聚起來了，但現在還比較早，先不下太重判斷。',
          ja: '手がかりは集まり始めていますが、まだ早いので、ここでは重い判断はしません。',
        );
      }
      return AppLocaleText.tr(
        context,
        en: 'For now, the densest day is $peakDay, and the weekly trend is ${avgMood >= 0 ? 'not clearly falling' : 'a little pulled downward'}.',
        zhHans:
            '目前线索最集中的一天是$peakDay，这一周的走势${avgMood >= 0 ? '没有明显往下掉' : '有一点被往下拉'}。',
        zhHant:
            '目前線索最集中的一天是$peakDay，這一週的走勢${avgMood >= 0 ? '沒有明顯往下掉' : '有一點被往下拉'}。',
        ja: '今のところ、手がかりがいちばん集まっているのは$peakDayで、今週の流れは${avgMood >= 0 ? '大きく下がってはいません' : '少し下に引かれています'}。',
      );
    }

    return AppLocaleText.tr(
      context,
      en: 'The bars show where this week’s signals gathered most, and the line shows whether the weekly trend was lifting or dropping.',
      zhHans: '柱状能看到这周线索最集中的是哪几天，折线则能看到这一周的走势是在往上走还是往下掉。',
      zhHant: '柱狀能看到這週線索最集中的是哪幾天，折線則能看到這一週的走勢是在往上走還是往下掉。',
      ja: '棒を見ると今週の手がかりがどの日に集まったかがわかり、折れ線を見ると今週の流れが上向きだったか下向きだったかが見えてきます。',
    );
  }

  String _dayLabel(BuildContext context, String date) {
    if (date.length >= 10 && date.contains('-')) {
      return date.substring(5);
    }
    return AppLocaleText.tr(
      context,
      en: 'this week',
      zhHans: '这周',
      zhHant: '這週',
      ja: '今週',
    );
  }
}

class _CompositeWeeklyChart extends StatelessWidget {
  final List<WeeklyChartPointModel> points;

  const _CompositeWeeklyChart({
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CompositeWeeklyChartPainter(
        points: points,
        textDirection: Directionality.of(context),
      ),
      child: Container(),
    );
  }
}

class _CompositeWeeklyChartPainter extends CustomPainter {
  final List<WeeklyChartPointModel> points;
  final TextDirection textDirection;

  _CompositeWeeklyChartPainter({
    required this.points,
    required this.textDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const topPad = 14.0;
    const rightPad = 10.0;
    const bottomPad = 34.0;
    const leftPad = 10.0;

    final chartRect = Rect.fromLTWH(
      leftPad,
      topPad,
      size.width - leftPad - rightPad,
      size.height - topPad - bottomPad,
    );

    final baseLineY = chartRect.bottom;
    final midLineY = chartRect.top + chartRect.height / 2;

    final gridPaint = Paint()
      ..color = Colors.grey.withAlpha(70)
      ..strokeWidth = 1;

    final axisPaint = Paint()
      ..color = Colors.grey.withAlpha(120)
      ..strokeWidth = 1.2;

    canvas.drawLine(
      Offset(chartRect.left, baseLineY),
      Offset(chartRect.right, baseLineY),
      axisPaint,
    );
    canvas.drawLine(
      Offset(chartRect.left, midLineY),
      Offset(chartRect.right, midLineY),
      gridPaint,
    );
    canvas.drawLine(
      Offset(chartRect.left, chartRect.top),
      Offset(chartRect.right, chartRect.top),
      gridPaint,
    );

    final maxSignal = math.max(
      1,
      points.map((e) => e.signalCount).fold<int>(0, math.max),
    );

    final segmentWidth = chartRect.width / points.length;
    final barWidth = segmentWidth * 0.42;

    final barPaint = Paint()
      ..color = Colors.blueGrey.withAlpha(125)
      ..style = PaintingStyle.fill;

    final positiveDotPaint = Paint()
      ..color = Colors.green.withAlpha(160)
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = Colors.black.withAlpha(180)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final linePath = Path();

    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final centerX = chartRect.left + (segmentWidth * i) + (segmentWidth / 2);

      final barHeight = (point.signalCount / maxSignal) * chartRect.height;
      final barRect = Rect.fromLTWH(
        centerX - barWidth / 2,
        baseLineY - barHeight,
        barWidth,
        barHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(barRect, const Radius.circular(4)),
        barPaint,
      );

      final clampedMood = point.moodScore.clamp(-1.0, 1.0);
      final y = midLineY - (clampedMood * (chartRect.height * 0.42));
      final p = Offset(centerX, y);

      if (i == 0) {
        linePath.moveTo(p.dx, p.dy);
      } else {
        linePath.lineTo(p.dx, p.dy);
      }

      if (point.hasPositiveSignal) {
        canvas.drawCircle(
          Offset(centerX, baseLineY - barHeight - 6),
          3,
          positiveDotPaint,
        );
      }

      _drawBottomLabel(
        canvas,
        text: _shortDate(point.date),
        center: Offset(centerX, size.height - 14),
      );
    }

    canvas.drawPath(linePath, linePaint);
  }

  String _shortDate(String date) {
    if (date.length >= 10 && date.contains('-')) {
      return date.substring(5);
    }
    return date;
  }

  void _drawBottomLabel(Canvas canvas,
      {required String text, required Offset center}) {
    final span = TextSpan(
      text: text,
      style: TextStyle(
        color: Colors.grey.withAlpha(180),
        fontSize: 10,
      ),
    );
    final painter = TextPainter(
      text: span,
      textDirection: textDirection,
      maxLines: 1,
    )..layout(minWidth: 0, maxWidth: 40);

    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _CompositeWeeklyChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.textDirection != textDirection;
  }
}

enum _LegendKind { bar, line }

class _LegendItem extends StatelessWidget {
  final String label;
  final _LegendKind kind;

  const _LegendItem({
    required this.label,
    required this.kind,
  });

  @override
  Widget build(BuildContext context) {
    Widget marker;
    switch (kind) {
      case _LegendKind.bar:
        marker = Container(
          width: 16,
          height: 10,
          decoration: BoxDecoration(
            color: Colors.blueGrey.withAlpha(125),
            borderRadius: BorderRadius.circular(3),
          ),
        );
        break;
      case _LegendKind.line:
        marker = SizedBox(
          width: 18,
          height: 10,
          child: CustomPaint(
            painter: _LineLegendPainter(),
          ),
        );
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        marker,
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

class _LineLegendPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withAlpha(180)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _LineLegendPainter oldDelegate) => false;
}

class _StatusChipBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _StatusChipBanner({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return _UnifiedCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(subtitle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroInsightCard extends StatelessWidget {
  final String title;
  final String body;

  const _HeroInsightCard({
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return _UnifiedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _OpportunityCard extends StatelessWidget {
  final String title;
  final Map<String, dynamic> snapshot;

  const _OpportunityCard({
    required this.title,
    required this.snapshot,
  });

  @override
  Widget build(BuildContext context) {
    final name = (snapshot['name'] as String?) ?? '';
    final summary = (snapshot['summary'] as String?) ?? '';

    return _UnifiedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          if (name.trim().isNotEmpty) ...[
            Text(name, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
          ],
          Text(summary),
        ],
      ),
    );
  }
}

class _PremiumChartInsightCard extends StatelessWidget {
  const _PremiumChartInsightCard();

  @override
  Widget build(BuildContext context) {
    return _UnifiedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lock_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Pro chart reading',
                    zhHans: 'Pro 图表解读',
                    zhHant: 'Pro 圖表解讀',
                    ja: 'Pro の図表読み',
                  ),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            AppLocaleText.tr(
              context,
              en: 'Unlock the key density day, low point, rebound signal, and what this week’s curve is asking you to watch next.',
              zhHans: '解锁线索最密的一天、走势低点、回升信号，以及这条曲线提示你下周该看什么。',
              zhHant: '解鎖線索最密的一天、走勢低點、回升訊號，以及這條曲線提示你下週該看什麼。',
              ja: '手がかりが最も濃い日、低い点、戻りの兆し、来週見るべきポイントを開きます。',
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: () => showPremiumPaywall(
                context,
                source: 'Weekly chart reading',
              ),
              icon: const Icon(Icons.workspace_premium_outlined),
              label: Text(
                AppLocaleText.tr(
                  context,
                  en: 'Unlock reading',
                  zhHans: '解锁解读',
                  zhHant: '解鎖解讀',
                  ja: '読みを開く',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartInsightCard extends StatelessWidget {
  final List<WeeklyChartPointModel> points;

  const _ChartInsightCard({required this.points});

  @override
  Widget build(BuildContext context) {
    final safePoints =
        points.isEmpty ? const <WeeklyChartPointModel>[] : [...points]
          ..sort((a, b) => a.date.compareTo(b.date));

    String densityText;
    String trendText;
    String reboundText;

    if (safePoints.isEmpty) {
      densityText = '这一周还没有足够图表线索。';
      trendText = '等记录再多一点，这里会开始指出哪一天最集中、走势什么时候往下或往上。';
      reboundText = '目前先继续记下重复出现的场景就好。';
    } else {
      final peak =
          safePoints.reduce((a, b) => a.signalCount >= b.signalCount ? a : b);
      final low =
          safePoints.reduce((a, b) => a.moodScore <= b.moodScore ? a : b);
      final rebound = safePoints.last;
      densityText =
          '线索最密的一天是 ${peak.date.length >= 10 ? peak.date.substring(5) : peak.date}，更像是同类事情在那一天集中冒头。';
      trendText =
          '走势最低点更接近 ${low.date.length >= 10 ? low.date.substring(5) : low.date}，说明那附近的状态更容易被往下拉。';
      reboundText = rebound.moodScore > low.moodScore
          ? '从后半段看，状态有一点往回收，说明并不是整周都在持续往下掉。'
          : '从后半段看，状态还没有明显回弹，下周更适合继续缩小观察范围。';
    }

    return _UnifiedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocaleText.tr(
              context,
              en: 'What this chart is pointing at',
              zhHans: '这张图在提示什么',
              zhHant: '這張圖在提示什麼',
              ja: 'この図が示していること',
            ),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Text('• $densityText'),
          const SizedBox(height: 8),
          Text('• $trendText'),
          const SizedBox(height: 8),
          Text('• $reboundText'),
        ],
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final bool isSubmitted;
  final SubmitState submitState;
  final Future<void> Function(String) onSubmit;

  const _FeedbackCard({
    required this.isSubmitted,
    required this.submitState,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    if (isSubmitted) {
      return _UnifiedCard(
        child: Text(
          AppLocaleText.tr(
            context,
            en: 'Thanks — your feedback for this week has been saved.',
            zhHans: '谢谢，这周的反馈已经保存。',
            zhHant: '謝謝，這週的回饋已經保存。',
            ja: 'ありがとうございます。今週のフィードバックは保存されました。',
          ),
        ),
      );
    }

    final isSubmitting = submitState == SubmitState.submitting;

    return _UnifiedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocaleText.tr(
              context,
              en: 'Did this weekly read feel right?',
              zhHans: '这份每周复盘看起来对吗？',
              zhHant: '這份 Weekly 看起來對嗎？',
              ja: 'この Weekly の見立てはしっくりきましたか？',
            ),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: isSubmitting ? null : () => onSubmit('helpful'),
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Mostly yes',
                    zhHans: '大体是',
                    zhHant: '大體是',
                    ja: 'だいたい合っている',
                  ),
                ),
              ),
              FilledButton.tonal(
                onPressed: isSubmitting ? null : () => onSubmit('partial'),
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Partly',
                    zhHans: '一部分对',
                    zhHant: '一部分對',
                    ja: '一部は合っている',
                  ),
                ),
              ),
              FilledButton.tonal(
                onPressed: isSubmitting ? null : () => onSubmit('off'),
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Not really',
                    zhHans: '不太对',
                    zhHant: '不太對',
                    ja: 'あまり合っていない',
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

class _UnifiedCard extends StatelessWidget {
  final Widget child;

  const _UnifiedCard({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AuroraMainPageSpec.comfortableCardPadding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.84),
            const Color(0xFFF6F3FF).withValues(alpha: 0.68),
            const Color(0xFFFFFAF5).withValues(alpha: 0.70),
          ],
        ),
        borderRadius: BorderRadius.circular(AuroraMainPageSpec.cardRadiusLarge),
        border: Border.all(color: Colors.white.withValues(alpha: 0.90)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7568A6).withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }
}
