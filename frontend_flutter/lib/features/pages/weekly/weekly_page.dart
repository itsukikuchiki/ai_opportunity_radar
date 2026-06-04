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
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/empty_state_block.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/signal_illustration_kit.dart';
import '../../paywall/paywall_sheet.dart';
import '../me/me_view_model.dart';
import 'weekly_view_model.dart';

class WeeklyPage extends StatelessWidget {
  const WeeklyPage({super.key});

  void _openMePage(BuildContext context) {
    context.go(AppRoutes.me);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WeeklyViewModel>();
    final meVm = context.watch<MeViewModel>();
    final header = AppHeader(
      title: AppLocaleText.tr(
        context,
        en: 'Weekly',
        zhHans: '本周',
        zhHant: '本週',
        ja: '今週',
      ),
      subtitle: _buildWeekRange(context, vm.weeklyInsight),
      summary: _buildHeaderSummary(context, vm),
      preferenceText: _preferenceText(context, meVm.selectedRepeatArea),
      onTapPreference: () => _openMePage(context),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocaleText.tr(
            context,
            en: 'Weekly',
            zhHans: '本周',
            zhHant: '本週',
            ja: '今週',
          ),
        ),
      ),
      body: vm.loadState == LoadState.ready && vm.weeklyInsight != null
          ? Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: header,
                ),
                Expanded(
                  child: _WeeklyReadyBody(
                    weekly: vm.weeklyInsight!,
                    energyBudget: vm.energyBudget,
                    feedbackSubmitState: vm.feedbackSubmitState,
                    experimentSubmitState: vm.experimentSubmitState,
                    onSubmitFeedback: vm.submitFeedback,
                    onSaveExperiment: vm.saveExperiment,
                    onSkipExperiment: vm.skipExperiment,
                    onExperimentFeedback: vm.submitExperimentFeedback,
                  ),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                header,
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
                  LoadState.empty => vm.showFirstDayGate
                      ? EmptyStateBlock(
                          icon: Icons.stacked_line_chart_outlined,
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
                        )
                      : EmptyStateBlock(
                          icon: Icons.stacked_line_chart_outlined,
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

    return _WeeklyPager(
      pages: [
        _WeeklyPagerPage(
          title: AppLocaleText.tr(
            context,
            en: 'Observation',
            zhHans: '本周观察',
            zhHant: '本週觀察',
            ja: '今週の観察',
          ),
          children: [
            if (isLightReady)
              _StatusChipBanner(
                icon: Icons.wb_twilight_outlined,
                title: AppLocaleText.tr(
                  context,
                  en: 'Weekly small observation',
                  zhHans: '本周小观察',
                  zhHant: '本週小觀察',
                  ja: '今週の小さな観察',
                ),
                subtitle: AppLocaleText.tr(
                  context,
                  en: 'A small observation is beginning to appear from the signals you have saved so far.',
                  zhHans: '目前先看到一个轻线索，它来自你已经留下的信号。',
                  zhHant: '目前先看到一個輕線索，它來自你已經留下的信號。',
                  ja: 'これまで残したシグナルから、小さな観察が少し見え始めています。',
                ),
              )
            else
              _StatusChipBanner(
                icon: Icons.insights_outlined,
                title: AppLocaleText.tr(
                  context,
                  en: 'Weekly small observation is formed',
                  zhHans: '本周小观察已形成',
                  zhHant: '本週小觀察已形成',
                  ja: '今週の小さな観察が形になっています',
                ),
                subtitle: AppLocaleText.tr(
                  context,
                  en: 'This week’s signals are enough to see one main pattern.',
                  zhHans: '这一周的信号已经足够看见一个主要模式。',
                  zhHant: '這一週的信號已經足夠看見一個主要模式。',
                  ja: '今週のシグナルから、一つの主なパターンが見え始めています。',
                ),
              ),
            const SizedBox(height: 16),
            _HeroInsightCard(
              title: isLightReady
                  ? AppLocaleText.tr(
                      context,
                      en: 'What is starting to show this week',
                      zhHans: '这周开始冒头的是',
                      zhHant: '這週開始冒頭的是',
                      ja: '今週、少し見え始めているのは',
                    )
                  : AppLocaleText.tr(
                      context,
                      en: 'What matters most this week',
                      zhHans: '这周最值得注意的是',
                      zhHant: '這週最值得注意的是',
                      ja: '今週いちばん気になること',
                    ),
              body: insight,
            ),
            const SizedBox(height: 18),
            _TopicFocusCard(
              topic: topic,
              isLightReady: isLightReady,
            ),
            const SizedBox(height: 18),
            _WeeklyInclusionCard(inclusion: inclusion),
          ],
        ),
        _WeeklyPagerPage(
          title: AppLocaleText.tr(
            context,
            en: 'Energy',
            zhHans: '能量分布',
            zhHant: '能量分布',
            ja: 'エネルギー分布',
          ),
          children: [
            SectionHeader(
              title: AppLocaleText.tr(
                context,
                en: 'Energy budget',
                zhHans: '能量分布',
                zhHant: '能量分布',
                ja: 'エネルギー分布',
              ),
              subtitle: isLightReady
                  ? AppLocaleText.tr(
                      context,
                      en: 'A light view of where energy may be draining or returning. It is a distribution, not a score.',
                      zhHans: '轻轻看一下哪里可能有些耗力，哪里可能有恢复线索。这是分布，不是评分。',
                      zhHant: '輕輕看一下哪裡可能有些耗力，哪裡可能有恢復線索。這是分布，不是評分。',
                      ja: 'どこで少し消耗し、どこに回復の手がかりがあるかを軽く見ます。これは分布であり、点数ではありません。',
                    )
                  : AppLocaleText.tr(
                      context,
                      en: 'Look at the distribution first, without turning the week into a score.',
                      zhHans: '先看分布，不把这一周变成评分。',
                      zhHant: '先看分布，不把這一週變成評分。',
                      ja: 'まず分布として見ます。今週を点数にはしません。',
                    ),
            ),
            const SizedBox(height: 10),
            _EnergyBudgetLiteCard(
              budget: energyBudget,
              fallbackExperiment: structure.oneExperiment,
            ),
            const SizedBox(height: 18),
            SectionHeader(
              title: AppLocaleText.tr(
                context,
                en: 'Signal trend',
                zhHans: '信号走势',
                zhHant: '信號走勢',
                ja: 'シグナルの流れ',
              ),
              subtitle: AppLocaleText.tr(
                context,
                en: 'Bars show signal density, and the line shows the weekly trend.',
                zhHans: '柱状表示信号密度，折线表示这一周的走势。',
                zhHant: '柱狀表示信號密度，折線表示這一週的走勢。',
                ja: '棒はシグナルの密度、線は今週の流れを表します。',
              ),
            ),
            const SizedBox(height: 10),
            _CompositeChartCard(
              points: chartData,
              isLightReady: isLightReady,
            ),
            const SizedBox(height: 12),
            if (purchase?.isPremium ?? false)
              _ChartInsightCard(points: chartData)
            else
              const _PremiumChartInsightCard(),
          ],
        ),
        _WeeklyPagerPage(
          title: AppLocaleText.tr(
            context,
            en: 'Experiment',
            zhHans: '小实验',
            zhHant: '小實驗',
            ja: '小さな試み',
          ),
          children: [
            SectionHeader(
              title: isLightReady
                  ? AppLocaleText.tr(
                      context,
                      en: 'This week, keep it light',
                      zhHans: '这周先看一个小观察',
                      zhHant: '這週先看一個小觀察',
                      ja: '今週は小さな観察を一つだけ見る',
                    )
                  : AppLocaleText.tr(
                      context,
                      en: 'This week, look at one thing',
                      zhHans: '这周先看一件事',
                      zhHant: '這週先看一件事',
                      ja: '今週は一つだけ見る',
                    ),
              subtitle: isLightReady
                  ? AppLocaleText.tr(
                      context,
                      en: 'One small pattern is enough for now. The rest can stay in the timeline.',
                      zhHans: '现在先看一个小模式就够了，其他内容继续留在时间线里。',
                      zhHant: '現在先看一個小模式就夠了，其他內容繼續留在時間線裡。',
                      ja: '今は小さなパターンを一つ見るだけで十分です。ほかはタイムラインに残しておけます。',
                    )
                  : AppLocaleText.tr(
                      context,
                      en: 'This page narrows the week into one pattern and one small experiment.',
                      zhHans: '这里会把这一周收束成一个模式和一个可以试试的小实验。',
                      zhHant: '這裡會把這一週收束成一個模式和一個可以試試的小實驗。',
                      ja: 'ここでは今週を一つのパターンと一つの小さな試みに絞ります。',
                    ),
            ),
            const SizedBox(height: 10),
            _WeeklyV3CStructureCard(
              structure: structure,
              isLightReady: isLightReady,
            ),
            if (experiment != null) ...[
              const SizedBox(height: 12),
              _LifeExperimentCard(
                experiment: experiment,
                submitState: experimentSubmitState,
                onSave: onSaveExperiment,
                onSkip: onSkipExperiment,
                onFeedback: onExperimentFeedback,
              ),
            ],
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: () {
                  if (purchase?.isPremium ?? false) {
                    context.push(AppRoutes.deepWeekly);
                  } else {
                    showPremiumPaywall(context, source: 'Deep Weekly');
                  }
                },
                icon: Icon(
                  purchase?.isPremium ?? false
                      ? Icons.auto_graph_outlined
                      : Icons.lock_outline,
                ),
                label: Text(
                  AppLocaleText.tr(
                    context,
                    en: (purchase?.isPremium ?? false)
                        ? 'Open Deep Weekly'
                        : 'Unlock Deep Weekly',
                    zhHans: (purchase?.isPremium ?? false)
                        ? '打开 Deep Weekly'
                        : '解锁 Deep Weekly',
                    zhHant: (purchase?.isPremium ?? false)
                        ? '打開 Deep Weekly'
                        : '解鎖 Deep Weekly',
                    ja: 'Deep Weekly を開く',
                  ),
                ),
              ),
            ),
            if (weekly.opportunitySnapshot != null) ...[
              const SizedBox(height: 18),
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
            const SizedBox(height: 22),
            _FeedbackCard(
              isSubmitted: weekly.feedbackSubmitted,
              submitState: feedbackSubmitState,
              onSubmit: onSubmitFeedback,
            ),
          ],
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

class _WeeklyPager extends StatefulWidget {
  final List<_WeeklyPagerPage> pages;

  const _WeeklyPager({required this.pages});

  @override
  State<_WeeklyPager> createState() => _WeeklyPagerState();
}

class _WeeklyPagerState extends State<_WeeklyPager> {
  int _currentPage = 0;

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
            itemCount: widget.pages.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              return ListView(
                key: PageStorageKey<String>('weekly-page-$index'),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
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

  const _WeeklyPageTab({
    required this.label,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: selected
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: theme.textTheme.labelMedium?.copyWith(
          color: selected
              ? theme.colorScheme.onPrimaryContainer
              : theme.colorScheme.onSurfaceVariant,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
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
  final String fallbackExperiment;

  const _EnergyBudgetLiteCard({
    required this.budget,
    required this.fallbackExperiment,
  });

  @override
  Widget build(BuildContext context) {
    final value = budget;
    final isFallback = value == null || value.status == 'insufficient_data';
    final mostDrainingSource = value?.mostDrainingSource ??
        AppLocaleText.tr(
          context,
          en: 'There is not enough internal signal yet to read energy flow.',
          zhHans: '现在还没有足够的内部信号来判断能量流向。',
          zhHant: '現在還沒有足夠的內部信號來判斷能量流向。',
          ja: 'エネルギーの流れを見るには、まだ内部シグナルが少ない状態です。',
        );
    final recoveryClue = value?.recoveryClue ??
        AppLocaleText.tr(
          context,
          en: 'For now, keep one note about what felt a little lighter.',
          zhHans: '现在可以先留下一条“哪里稍微省力”的记录。',
          zhHant: '現在可以先留下一條「哪裡稍微省力」的記錄。',
          ja: '今は「少し楽だったこと」を一つ残しておくだけで十分です。',
        );
    final bufferLocation = value?.bufferLocation ??
        AppLocaleText.tr(
          context,
          en: 'No clear buffer point yet.',
          zhHans: '暂时还没有明确需要 buffer 的位置。',
          zhHant: '暫時還沒有明確需要 buffer 的位置。',
          ja: 'まだ buffer が必要な場所ははっきりしていません。',
        );
    final switchingAdjustment = value?.switchingAdjustment ??
        AppLocaleText.tr(
          context,
          en: 'This adjustment can simply be something to try: $fallbackExperiment',
          zhHans: '这个调整也可以只是试试看：$fallbackExperiment',
          zhHant: '這個調整也可以只是試試看：$fallbackExperiment',
          ja: 'この調整は、試してみる程度で大丈夫です：$fallbackExperiment',
        );
    final experimentConnection = value?.experimentConnection ??
        AppLocaleText.tr(
          context,
          en: 'If one block feels costly, keep the next experiment optional and small.',
          zhHans: '如果某个位置明显耗力，下一个实验也保持可选、很小就好。',
          zhHant: '如果某個位置明顯耗力，下一個實驗也保持可選、很小就好。',
          ja: 'どこかが明らかに消耗するなら、次の実験も任意で小さくしておきます。',
        );

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
          const SizedBox(height: 8),
          Text(
            isFallback
                ? AppLocaleText.tr(
                    context,
                    en: 'This is still a light read. It is not a score or diagnosis.',
                    zhHans: '这里先保持轻量观察。它不是评分，也不是诊断。',
                    zhHant: '這裡先保持輕量觀察。它不是評分，也不是診斷。',
                    ja: 'ここでは軽く見るだけです。スコアでも診断でもありません。',
                  )
                : AppLocaleText.tr(
                    context,
                    en: 'A small read of where things may feel costly, and where you might leave a little room.',
                    zhHans: '轻轻看一下哪里可能有点耗力，以及哪里可以先留一点余地。',
                    zhHant: '輕輕看一下哪裡可能有點耗力，以及哪裡可以先留一點餘地。',
                    ja: 'どこが少し消耗しやすいか、どこに少し余白を置けそうかを軽く見ます。',
                  ),
          ),
          const SizedBox(height: 12),
          EnergyRingVisual(
            label: AppLocaleText.tr(
              context,
              en: 'Distribution\nnot a score',
              zhHans: '分布感\n不是评分',
              zhHant: '分布感\n不是評分',
              ja: '分布を見る\n評価ではありません',
            ),
          ),
          const SizedBox(height: 12),
          _EnergyDistributionBar(blocks: value?.blocks ?? const []),
          const SizedBox(height: 12),
          _EnergyBudgetRow(
            label: AppLocaleText.tr(
              context,
              en: 'Most costly source',
              zhHans: '最耗力的一个来源',
              zhHant: '最耗力的一個來源',
              ja: 'いちばん消耗しやすいところ',
            ),
            value: mostDrainingSource,
          ),
          _EnergyBudgetRow(
            label: AppLocaleText.tr(
              context,
              en: 'Recovery clue',
              zhHans: '一个恢复线索',
              zhHant: '一個恢復線索',
              ja: '回復の手がかり',
            ),
            value: recoveryClue,
          ),
          _EnergyBudgetRow(
            label: AppLocaleText.tr(
              context,
              en: 'Buffer point',
              zhHans: '需要 buffer 的位置',
              zhHant: '需要 buffer 的位置',
              ja: 'buffer を置けそうな場所',
            ),
            value: bufferLocation,
          ),
          _EnergyBudgetRow(
            label: AppLocaleText.tr(
              context,
              en: 'Small adjustment',
              zhHans: '减少切换负担的小调整',
              zhHant: '減少切換負擔的小調整',
              ja: '切り替え負担を減らす小さな調整',
            ),
            value: switchingAdjustment,
          ),
          _EnergyBudgetRow(
            label: AppLocaleText.tr(
              context,
              en: 'Experiment link',
              zhHans: '和 Life Experiment 的连接',
              zhHant: '和 Life Experiment 的連接',
              ja: 'Life Experiment とのつながり',
            ),
            value: experimentConnection,
          ),
          const SizedBox(height: 8),
          Text(
            AppLocaleText.tr(
              context,
              en: 'This is not a score or diagnosis. Older or unconfirmed notes may be used only as light context. Inaccurate, excluded, sensitive, or unsynced notes are not used here.',
              zhHans: '这不是评分，也不是诊断。旧记录和未确认记录只会作为轻背景；不准、已排除、敏感或未同步的记录不会进入这里。',
              zhHant: '這不是評分，也不是診斷。舊記錄和未確認記錄只會作為輕背景；不準、已排除、敏感或未同步的記錄不會進入這裡。',
              ja: 'これはスコアでも診断でもありません。古い記録や未確認の記録は軽い文脈としてだけ使われます。不正確・除外・センシティブ・未同期の記録はここでは使いません。',
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
      theme.colorScheme.errorContainer,
      theme.colorScheme.tertiaryContainer,
      theme.colorScheme.primaryContainer,
      theme.colorScheme.secondaryContainer,
      theme.colorScheme.surfaceContainerHighest,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 12,
            child: Row(
              children: [
                for (var i = 0; i < blocks.length; i++)
                  Expanded(
                    flex: (blocks[i].count * 100 / safeTotal)
                        .round()
                        .clamp(1, 100),
                    child: ColoredBox(color: colors[i % colors.length]),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: blocks
              .take(4)
              .map((block) => _MetaPill('${block.label} · ${block.count}'))
              .toList(),
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
