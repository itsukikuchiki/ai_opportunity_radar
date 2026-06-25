// ignore_for_file: unused_element

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/app_router.dart';
import '../../../core/i18n/app_locale_text.dart';
import '../../../core/models/energy_budget_models.dart';
import '../../../core/models/weekly_models.dart';
import '../../../core/purchases/purchase_controller.dart';
import '../../../shared/states/load_state.dart';
import '../../../shared/widgets/aurora_ui.dart';
import '../../../shared/widgets/empty_state_block.dart';
import '../../../shared/widgets/signal_illustration_kit.dart';
import '../../paywall/paywall_sheet.dart';
import 'weekly_view_model.dart';

class WeeklyPage extends StatelessWidget {
  const WeeklyPage({super.key});

  void _openMePage(BuildContext context) {
    context.go(AppRoutes.me);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WeeklyViewModel>();
    final top = Column(
      children: [
        AuroraQuoteCard(
          minHeight: 136,
          landscape: true,
          text: _weeklyHeroText(context, vm.weeklyInsight),
        ),
        const SizedBox(height: 14),
        _WeeklyWeatherCard(weekly: vm.weeklyInsight),
      ],
    );

    return Scaffold(
      body: Stack(
        children: [
          AuroraPage(
            child: SafeArea(
              bottom: false,
              child: vm.loadState == LoadState.ready && vm.weeklyInsight != null
                  ? _WeeklyReadyBody(
                      weekly: vm.weeklyInsight!,
                      energyBudget: vm.energyBudget,
                      feedbackSubmitState: vm.feedbackSubmitState,
                      experimentSubmitState: vm.experimentSubmitState,
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
                        await vm.saveExperiment();
                        if (!context.mounted) return;
                        _showWeeklyHint(
                          context,
                          AppLocaleText.tr(
                            context,
                            en: 'This experiment is saved for the week.',
                            zhHans: '这个小实验已放进本周。',
                            zhHant: '這個小實驗已放進本週。',
                            ja: 'この小さな試みを今週に保存しました。',
                          ),
                        );
                      },
                      onSkipExperiment: () async {
                        await vm.skipExperiment();
                        if (!context.mounted) return;
                        _showWeeklyHint(
                          context,
                          AppLocaleText.tr(
                            context,
                            en: 'No problem. This experiment is skipped for now.',
                            zhHans: '没关系，这个小实验先暂时跳过。',
                            zhHant: '沒關係，這個小實驗先暫時跳過。',
                            ja: '大丈夫です。この試みは今は見送ります。',
                          ),
                        );
                      },
                      onExperimentFeedback: ({
                        required status,
                        required feedbackText,
                      }) async {
                        await vm.submitExperimentFeedback(
                          status: status,
                          feedbackText: feedbackText,
                        );
                        if (!context.mounted) return;
                        _showWeeklyHint(
                          context,
                          AppLocaleText.tr(
                            context,
                            en: 'This experiment note is saved.',
                            zhHans: '这次实验反馈已保存。',
                            zhHant: '這次實驗回饋已保存。',
                            ja: '試みの反応を保存しました。',
                          ),
                        );
                      },
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 2, 20, 116),
                      children: [
                        top,
                        const SizedBox(height: 10),
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
                          LoadState.empty => EmptyStateBlock(
                              icon: vm.showFirstDayGate
                                  ? Icons.stacked_line_chart_outlined
                                  : Icons.stacked_line_chart_outlined,
                              title: AppLocaleText.tr(
                                context,
                                en: 'Weekly is forming',
                                zhHans: '本周正在形成',
                                zhHant: '本週正在形成',
                                ja: '今週は形成中です',
                              ),
                              subtitle: AppLocaleText.tr(
                                context,
                                en: 'Leave a few signals first. This week’s small observation will gradually appear. Not a report, not a score.',
                                zhHans: '先留下几条信号，本周的小观察会慢慢出现。不是报告，也不是评分。',
                                zhHant: '先留下幾條信號，本週的小觀察會慢慢出現。不是報告，也不是評分。',
                                ja: 'まずいくつかのシグナルを残しておくと、今週の小さな観察が少しずつ現れます。レポートでも評価でもありません。',
                              ),
                            ),
                          _ => const SizedBox.shrink(),
                        },
                      ],
                    ),
            ),
          ),
          const AuroraSafeTopMask(),
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
        en: 'On day 1, Weekly appears once local records start to exist. Otherwise tomorrow it begins with a light read.',
        zhHans: '第 1 天如果已经有本地记录，Weekly 可以直接展示；如果还没有记录，明天会先出现轻量整理。',
        zhHant: '第 1 天如果已經有本地記錄，Weekly 可以直接展示；如果還沒有記錄，明天會先出現輕量整理。',
        ja: '1 日目でもローカル記録があれば Weekly は表示されます。まだ記録がなければ、明日まず軽い整理から始まります。',
      );
    }

    if (vm.loadState == LoadState.empty) {
      return AppLocaleText.tr(
        context,
        en: 'Weekly is forming. It will begin with a light read, not a full report.',
        zhHans: 'Weekly 正在形成。这里会先从轻量整理开始，不会假装成完整报告。',
        zhHant: 'Weekly 正在形成。這裡會先從輕量整理開始，不會假裝成完整報告。',
        ja: 'Weekly は形になり始めています。完全なレポートではなく、軽い整理から始まります。',
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
    switch (value) {
      case 'work_tasks':
        return AppLocaleText.tr(context,
            en: 'work and tasks',
            zhHans: '工作与任务',
            zhHant: '工作與任務',
            ja: '仕事とタスク');
      case 'emotion_stress':
        return AppLocaleText.tr(context,
            en: 'emotions and stress',
            zhHans: '情绪与压力',
            zhHant: '情緒與壓力',
            ja: '感情とストレス');
      case 'relationships':
        return AppLocaleText.tr(context,
            en: 'relationships and interaction',
            zhHans: '关系与相处',
            zhHant: '關係與相處',
            ja: '人間関係と付き合い方');
      case 'time_rhythm':
        return AppLocaleText.tr(context,
            en: 'time and daily rhythm',
            zhHans: '时间与生活节奏',
            zhHant: '時間與生活節奏',
            ja: '時間と生活リズム');
      case 'health_body':
        return AppLocaleText.tr(context,
            en: 'health and physical state',
            zhHans: '健康与身体状态',
            zhHant: '健康與身體狀態',
            ja: '健康と身体の状態');
      case 'money_spending':
        return AppLocaleText.tr(context,
            en: 'money and spending',
            zhHans: '金钱与消费',
            zhHant: '金錢與消費',
            ja: 'お金と消費');
      case 'learning_growth_expression':
        return AppLocaleText.tr(context,
            en: 'learning, growth, and expression',
            zhHans: '学习、成长与表达',
            zhHant: '學習、成長與表達',
            ja: '学び・成長・表現');
      case 'open':
        return AppLocaleText.tr(context,
            en: 'whatever comes up',
            zhHans: '想到什么记什么',
            zhHant: '想到什麼記什麼',
            ja: '思いついたことから記録する');
      default:
        return AppLocaleText.tr(context,
            en: 'not set yet', zhHans: '暂未设置', zhHant: '暫未設定', ja: '未設定');
    }
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

class _WeeklyWeatherCard extends StatelessWidget {
  final WeeklyInsightModel? weekly;

  const _WeeklyWeatherCard({required this.weekly});

  @override
  Widget build(BuildContext context) {
    final points = weekly?.chartData ?? const <WeeklyChartPointModel>[];
    final totalSignals = points.fold<int>(0, (sum, p) => sum + p.signalCount);
    final avgFriction = points.isEmpty
        ? 0.0
        : points.fold<double>(0, (sum, p) => sum + p.frictionScore) /
            points.length;
    final positiveDays = points.where((p) => p.hasPositiveSignal).length;
    final frictionItems = weekly?.frictions.length ?? 0;

    final energyValue = totalSignals == 0
        ? AppLocaleText.tr(
            context,
            en: 'Forming',
            zhHans: '形成中',
            zhHant: '形成中',
            ja: '形成中',
          )
        : avgFriction >= 0.62 || frictionItems >= 2
            ? AppLocaleText.tr(
                context,
                en: 'Low',
                zhHans: '偏低',
                zhHant: '偏低',
                ja: '低め',
              )
            : AppLocaleText.tr(
                context,
                en: 'Stable',
                zhHans: '平稳',
                zhHant: '平穩',
                ja: '安定',
              );
    final frictionValue = totalSignals == 0
        ? AppLocaleText.tr(
            context,
            en: 'Forming',
            zhHans: '形成中',
            zhHant: '形成中',
            ja: '形成中',
          )
        : avgFriction >= 0.55 || frictionItems >= 2
            ? AppLocaleText.tr(
                context,
                en: 'High',
                zhHans: '偏高',
                zhHant: '偏高',
                ja: '高め',
              )
            : AppLocaleText.tr(
                context,
                en: 'Light',
                zhHans: '较轻',
                zhHant: '較輕',
                ja: '軽め',
              );
    final recoveryValue = totalSignals == 0
        ? AppLocaleText.tr(
            context,
            en: 'Forming',
            zhHans: '形成中',
            zhHant: '形成中',
            ja: '形成中',
          )
        : positiveDays > 0
            ? AppLocaleText.tr(
                context,
                en: 'Seen',
                zhHans: '有线索',
                zhHant: '有線索',
                ja: 'あり',
              )
            : AppLocaleText.tr(
                context,
                en: 'Low',
                zhHans: '不足',
                zhHant: '不足',
                ja: '少なめ',
              );

    return AuroraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'This week’s life weather',
                    zhHans: '本周生活天气',
                    zhHant: '本週生活天氣',
                    ja: '今週の生活天気',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 0,
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => _showWeeklyHint(
                    context,
                    AppLocaleText.tr(
                      context,
                      en: 'The weekly trend is reflected in the weather, chain, and energy cards below.',
                      zhHans: '本周趋势已在生活天气、消耗链和能量分布里展示。',
                      zhHant: '本週趨勢已在生活天氣、消耗鏈和能量分佈裡展示。',
                      ja: '今週の流れは、生活天気・消耗の連鎖・エネルギー分布に表示しています。',
                    ),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            AppLocaleText.tr(
                              context,
                              en: 'View trend',
                              zhHans: '查看趋势',
                              zhHant: '查看趨勢',
                              ja: '流れを見る',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: AuroraColors.muted,
                                ),
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            color: AuroraColors.muted),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AuroraMetricCard(
                  icon: Icons.battery_saver_rounded,
                  label: AppLocaleText.tr(
                    context,
                    en: 'Energy',
                    zhHans: '能量',
                    zhHant: '能量',
                    ja: 'エネルギー',
                  ),
                  value: energyValue,
                  color: AuroraColors.mint,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AuroraMetricCard(
                  icon: Icons.monitor_heart_outlined,
                  label: AppLocaleText.tr(
                    context,
                    en: 'Friction',
                    zhHans: '摩擦',
                    zhHant: '摩擦',
                    ja: '摩擦',
                  ),
                  value: frictionValue,
                  color: AuroraColors.orange,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AuroraMetricCard(
                  icon: Icons.nights_stay_outlined,
                  label: AppLocaleText.tr(
                    context,
                    en: 'Recovery',
                    zhHans: '恢复',
                    zhHant: '恢復',
                    ja: '回復',
                  ),
                  value: recoveryValue,
                  color: AuroraColors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeeklyReadyBody extends StatelessWidget {
  final WeeklyInsightModel weekly;
  final EnergyBudgetModel? energyBudget;
  final SubmitState feedbackSubmitState;
  final SubmitState experimentSubmitState;
  final Future<void> Function(String) onSubmitFeedback;
  final Future<void> Function() onSaveExperiment;
  final Future<void> Function() onSkipExperiment;
  final Future<void> Function({
    required String status,
    required String feedbackText,
  }) onExperimentFeedback;

  const _WeeklyReadyBody({
    required this.weekly,
    required this.energyBudget,
    required this.feedbackSubmitState,
    required this.experimentSubmitState,
    required this.onSubmitFeedback,
    required this.onSaveExperiment,
    required this.onSkipExperiment,
    required this.onExperimentFeedback,
  });

  bool get isLightReady => weekly.status == 'light_ready';

  @override
  Widget build(BuildContext context) {
    final insight = weekly.keyInsight ??
        AppLocaleText.tr(
          context,
          en: 'A weekly read is starting to take shape.',
          zhHans: '这周已经开始形成阶段判断。',
          zhHant: '這週已經開始形成階段判斷。',
          ja: '今週の見立てが少しずつ形になってきています。',
        );

    final chartData = weekly.chartData;
    final purchase = context.watch<PurchaseController?>();
    final topic = weekly.deriveTopicFocus();
    final structure = weekly.deriveV3CStructure();
    final inclusion = weekly.inclusionSummary;
    final experiment = weekly.lifeExperiment;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 116),
      children: [
        AuroraQuoteCard(
          landscape: true,
          minHeight: 136,
          text: insight,
        ),
        const SizedBox(height: 14),
        _WeeklyWeatherCard(weekly: weekly),
        const SizedBox(height: 14),
        _WeeklyDrainChainCard(structure: structure),
        const SizedBox(height: 14),
        _EnergyBudgetLiteCard(
          budget: energyBudget,
        ),
        const SizedBox(height: 14),
        _DrainSourcesCard(weekly: weekly, budget: energyBudget),
        const SizedBox(height: 14),
        _ScheduleGoalWeeklyCard(
          summary: weekly.opportunitySnapshot?['_schedule_goal_summary'],
        ),
        const SizedBox(height: 14),
        _OneWeeklyFocusCard(topic: topic),
        const SizedBox(height: 14),
        if (experiment != null)
          _LifeExperimentCard(
            experiment: experiment,
            submitState: experimentSubmitState,
            onSave: onSaveExperiment,
            onSkip: onSkipExperiment,
            onFeedback: onExperimentFeedback,
          )
        else
          _WeeklyV3CStructureCard(
            structure: structure,
            isLightReady: isLightReady,
          ),
        const SizedBox(height: 14),
        _WeeklyActionReviewCard(review: weekly.actionReview),
        const SizedBox(height: 14),
        _WeeklyInclusionCard(inclusion: inclusion),
        if (weekly.opportunitySnapshot != null) ...[
          const SizedBox(height: 14),
          _OpportunityCard(
            title: AppLocaleText.tr(
              context,
              en: 'Worth keeping an eye on',
              zhHans: '值得继续留意的是',
              zhHant: '值得繼續留意的是',
              ja: '引き続き見ておきたいこと',
            ),
            snapshot: weekly.opportunitySnapshot!,
          ),
        ],
        const SizedBox(height: 14),
        if (!(purchase?.isPremium ?? false))
          const _PremiumChartInsightCard()
        else
          _ChartInsightCard(points: chartData),
        const SizedBox(height: 14),
        _FeedbackCard(
          isSubmitted: weekly.feedbackSubmitted,
          submitState: feedbackSubmitState,
          onSubmit: onSubmitFeedback,
        ),
      ],
    );
  }
}

class _WeeklyPagerPage {
  final String title;
  final List<Widget> children;

  const _WeeklyPagerPage({
    required this.title,
    required this.children,
  });
}

class _ScheduleGoalWeeklyCard extends StatelessWidget {
  final Object? summary;

  const _ScheduleGoalWeeklyCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final map = summary is Map
        ? (summary as Map).map((key, value) => MapEntry('$key', value))
        : const <String, dynamic>{};
    final known = (map['schedule_known_count'] as num?)?.toInt() ?? 0;
    final pending = (map['pending_schedule_count'] as num?)?.toInt() ?? 0;
    final feedback = (map['feedback_count'] as num?)?.toInt() ?? 0;
    final goals = (map['active_goal_count'] as num?)?.toInt() ?? 0;
    final goalFeedback = (map['goal_feedback_count'] as num?)?.toInt() ?? 0;

    return AuroraCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AuroraSoftIconCircle(
                icon: Icons.route_outlined,
                color: AuroraColors.blue,
                size: 40,
                iconSize: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Schedule and goal signals',
                    zhHans: '安排与目标线索',
                    zhHant: '安排與目標線索',
                    ja: '予定と目標のシグナル',
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniCountTile(
                  label: AppLocaleText.tr(
                    context,
                    en: 'Known',
                    zhHans: '已定',
                    zhHant: '已定',
                    ja: '確定',
                  ),
                  value: '$known',
                  color: AuroraColors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniCountTile(
                  label: AppLocaleText.tr(
                    context,
                    en: 'Pending',
                    zhHans: '待定',
                    zhHant: '待定',
                    ja: '未定',
                  ),
                  value: '$pending',
                  color: AuroraColors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniCountTile(
                  label: AppLocaleText.tr(
                    context,
                    en: 'Feedback',
                    zhHans: '反馈',
                    zhHant: '回饋',
                    ja: '反応',
                  ),
                  value: '${feedback + goalFeedback}',
                  color: AuroraColors.mint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            goals > 0
                ? AppLocaleText.tr(
                    context,
                    en: 'Your goal practice is included as optional Review & Adjust evidence.',
                    zhHans: '目标练习会作为可选的 Review & Adjust 线索进入本周。',
                    zhHant: '目標練習會作為可選的 Review & Adjust 線索進入本週。',
                    ja: '目標練習は、任意の Review & Adjust の手がかりとして今週に入ります。',
                  )
                : AppLocaleText.tr(
                    context,
                    en: 'A schedule title is enough; unfinished timing will stay as a pending signal.',
                    zhHans: '只写安排标题也可以，未定时间会先作为待定线索保留。',
                    zhHant: '只寫安排標題也可以，未定時間會先作為待定線索保留。',
                    ja: '予定はタイトルだけでも大丈夫。時間未定のものは未定シグナルとして残ります。',
                  ),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AuroraColors.muted,
                  height: 1.35,
                ),
          ),
        ],
      ),
    );
  }
}

class _MiniCountTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniCountTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AuroraColors.ink,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
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
                en: 'Small experiment',
                zhHans: '小实验',
                zhHant: '小實驗',
                ja: '小さな試み',
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
              en: 'One small experiment',
              zhHans: '一个低成本小实验',
              zhHant: '一個低成本小實驗',
              ja: '一つの小さな実験',
            ),
            value: structure.oneExperiment,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString(
                  'local_plan_block_current',
                  structure.oneExperiment,
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      AppLocaleText.tr(
                        context,
                        en: 'Plan block kept locally. No calendar or notification was created.',
                        zhHans: '这段小安排已本地保存，不会写入日历，也不会创建提醒。',
                        zhHant: '這段小安排已本地保存，不會寫入日曆，也不會建立提醒。',
                        ja: 'この小さな予定は端末内に保存しました。カレンダーや通知は作成しません。',
                      ),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.event_note_outlined),
              label: Text(
                AppLocaleText.tr(
                  context,
                  en: 'Keep as Plan Block',
                  zhHans: '保存为小安排',
                  zhHant: '保存為小安排',
                  ja: '小さな予定として保存',
                ),
              ),
            ),
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

    return _UnifiedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.battery_charging_full_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Energy Budget',
                    zhHans: '能量分布',
                    zhHant: '能量分布',
                    ja: 'エネルギーの分布',
                  ),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _EnergyDistributionBar(blocks: value?.blocks ?? const []),
          const SizedBox(height: 8),
          Text(
            AppLocaleText.tr(
              context,
              en: isFallback
                  ? 'A light read for now. Not a score.'
                  : 'Look at distribution, not performance.',
              zhHans: isFallback ? '先轻轻看，不是评分。' : '看分布，不是评分。',
              zhHant: isFallback ? '先輕輕看，不是評分。' : '看分布，不是評分。',
              ja: isFallback ? '軽く見るだけです。評価ではありません。' : '分布を見るためのもので、評価ではありません。',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
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
                    en: 'Small action review',
                    zhHans: '本周小行动复盘',
                    zhHant: '本週小行動回顧',
                    ja: '今週の小さな行動の振り返り',
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
                  en: 'AI reads',
                  zhHans: 'AI 判断',
                  zhHant: 'AI 判斷',
                  ja: 'AI の見立て',
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
                  en: 'Actions',
                  zhHans: '生成小行动',
                  zhHant: '生成小行動',
                  ja: '小さな行動',
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
        en: 'No action loop has settled yet. This week can still be read as a small observation.',
        zhHans: '这一周还没有形成明确的小行动闭环，先把它当作一个小观察。',
        zhHant: '這一週還沒有形成明確的小行動閉環，先把它當作一個小觀察。',
        ja: '今週はまだ小さな行動の循環がはっきりしていません。小さな観察として扱います。',
      );
    }
    return AppLocaleText.tr(
      context,
      en: '${review.aiJudgementCount} AI read(s), ${review.confirmedJudgementCount} confirmed, ${review.generatedActionCount} small action(s), ${review.triedActionCount} tried. Next: ${review.nextAdjustment}',
      zhHans:
          '这周有 ${review.aiJudgementCount} 条 AI 判断，${review.confirmedJudgementCount} 条被确认，生成 ${review.generatedActionCount} 个小行动，实际尝试 ${review.triedActionCount} 个。下周可以先看：${review.nextAdjustment}',
      zhHant:
          '這週有 ${review.aiJudgementCount} 條 AI 判斷，${review.confirmedJudgementCount} 條被確認，生成 ${review.generatedActionCount} 個小行動，實際嘗試 ${review.triedActionCount} 個。下週可以先看：${review.nextAdjustment}',
      ja: '今週は AI の見立てが ${review.aiJudgementCount} 件、確認済みが ${review.confirmedJudgementCount} 件、小さな行動が ${review.generatedActionCount} 件、試したものが ${review.triedActionCount} 件。次は「${review.nextAdjustment}」を見ます。',
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
              en: 'Notes that are still syncing, marked not quite right, or kept out of analysis stay saved in your Timeline.',
              zhHans: '还在同步、被标记为不太准、或不参与分析的记录，会继续保存在 Timeline，不会被当成这周判断材料。',
              zhHant: '還在同步、被標記為不太準、或不參與分析的記錄，會繼續保存在 Timeline，不會被當成這週判斷材料。',
              ja: '同期中の記録、しっくりこないとされた記録、分析から外した記録は Timeline に保存されたままで、今週の見立てには使いません。',
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
          '$used 条记录进入了这份 Weekly，$timelineOnly 条只保留在 Timeline。$legacy 条旧记录只作为轻量背景参考。',
      zhHant:
          '$used 條記錄進入了這份 Weekly，$timelineOnly 條只保留在 Timeline。$legacy 條舊記錄只作為輕量背景參考。',
      ja: '$used 件の記録をこの Weekly に使いました。$timelineOnly 件は Timeline にだけ残しています。$legacy 件の古い記録は軽い背景として扱いました。',
    );
  }
}

class _LifeExperimentCard extends StatelessWidget {
  final LifeExperimentModel experiment;
  final SubmitState submitState;
  final Future<void> Function() onSave;
  final Future<void> Function() onSkip;
  final Future<void> Function({
    required String status,
    required String feedbackText,
  }) onFeedback;

  const _LifeExperimentCard({
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
                    en: 'A small experiment you can keep',
                    zhHans: '可以留下来的一个小实验',
                    zhHant: '可以留下來的一個小實驗',
                    ja: '残しておける小さな実験',
                  ),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(experiment.title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(experiment.suggestedAction),
          const SizedBox(height: 10),
          Text(
            AppLocaleText.tr(
              context,
              en: 'This is only a design to try, not a task to complete.',
              zhHans: '这只是一个可以试试的生活设计，不是必须完成的任务。',
              zhHant: '這只是一個可以試試的生活設計，不是必須完成的任務。',
              ja: 'これは試してみるための設計で、完了すべきタスクではありません。',
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
              zhHans: '这份 Weekly 看起来对吗？',
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
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: child,
      ),
    );
  }
}
