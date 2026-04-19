import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/i18n/app_locale_text.dart';
import '../../../core/models/weekly_models.dart';
import '../../../shared/states/load_state.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/empty_state_block.dart';
import '../../../shared/widgets/section_header.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocaleText.tr(
            context,
            en: 'Weekly',
            zhHans: 'Weekly',
            zhHant: 'Weekly',
            ja: 'Weekly',
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          AppHeader(
            title: AppLocaleText.tr(
              context,
              en: 'Weekly',
              zhHans: 'Weekly',
              zhHant: 'Weekly',
              ja: 'Weekly',
            ),
            subtitle: _buildWeekRange(context, vm.weeklyInsight),
            summary: _buildHeaderSummary(context, vm),
            preferenceText: _preferenceText(context, meVm.selectedRepeatArea),
            onTapPreference: () => _openMePage(context),
          ),
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
                      en: 'Weekly starts on day 2',
                      zhHans: 'Weekly 第 2 天开始展示',
                      zhHant: 'Weekly 第 2 天開始展示',
                      ja: 'Weekly は 2 日目から表示されます',
                    ),
                    subtitle: AppLocaleText.tr(
                      context,
                      en: 'If you add local entries today, Weekly can still start showing right away. Otherwise, it will begin from day 2.',
                      zhHans: '如果你今天已经留下本地记录，Weekly 也可以立即开始展示；如果今天还没有记录，就会从第 2 天开始出现。',
                      zhHant: '如果你今天已經留下本地記錄，Weekly 也可以立即開始展示；如果今天還沒有記錄，就會從第 2 天開始出現。',
                      ja: '今日すでにローカル記録があれば Weekly はすぐ表示できます。まだ記録がなければ、2 日目から始まります。',
                    ),
                  )
                : EmptyStateBlock(
                    icon: Icons.stacked_line_chart_outlined,
                    title: AppLocaleText.tr(
                      context,
                      en: 'Not enough signals yet this week',
                      zhHans: '这周的记录还不够多',
                      zhHant: '這週的記錄還不夠多',
                      ja: '今週はまだ記録が足りません',
                    ),
                    subtitle: AppLocaleText.tr(
                      context,
                      en: 'After a few more entries, this page will start showing repeated patterns, ongoing frictions, and what may be worth trying next.',
                      zhHans: '等你再记几条之后，这里会慢慢开始看见重复模式、持续摩擦，以及接下来最值得试的一步。',
                      zhHant: '等你再記幾條之後，這裡會慢慢開始看見重複模式、持續摩擦，以及接下來最值得試的一步。',
                      ja: 'もう少し記録がたまると、繰り返している pattern や継続する摩擦、次に試すとよさそうな一歩が少しずつ見えてきます。',
                    ),
                  ),
            _ => _WeeklyReadyBody(
                weekly: vm.weeklyInsight!,
                feedbackSubmitState: vm.feedbackSubmitState,
                onSubmitFeedback: vm.submitFeedback,
              ),
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
        en: 'On day 1, Weekly appears once local records start to exist. Otherwise it begins from day 2.',
        zhHans: '第 1 天如果已经有本地记录，Weekly 可以直接展示；如果还没有记录，就会从第 2 天开始出现。',
        zhHant: '第 1 天如果已經有本地記錄，Weekly 可以直接展示；如果還沒有記錄，就會從第 2 天開始出現。',
        ja: '1 日目でもローカル記録があれば Weekly は表示されます。まだ記録がなければ 2 日目から始まります。',
      );
    }

    if (vm.loadState == LoadState.empty) {
      return AppLocaleText.tr(
        context,
        en: 'There is not enough yet to form a weekly read.',
        zhHans: '这周还没有形成足够的判断。',
        zhHant: '這週還沒有形成足夠的判斷。',
        ja: '今週はまだ十分な見立てができるほどではありません。',
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
        return AppLocaleText.tr(context, en: 'work and tasks', zhHans: '工作与任务', zhHant: '工作與任務', ja: '仕事とタスク');
      case 'emotion_stress':
        return AppLocaleText.tr(context, en: 'emotions and stress', zhHans: '情绪与压力', zhHant: '情緒與壓力', ja: '感情とストレス');
      case 'relationships':
        return AppLocaleText.tr(context, en: 'relationships and interaction', zhHans: '关系与相处', zhHant: '關係與相處', ja: '人間関係と付き合い方');
      case 'time_rhythm':
        return AppLocaleText.tr(context, en: 'time and daily rhythm', zhHans: '时间与生活节奏', zhHant: '時間與生活節奏', ja: '時間と生活リズム');
      case 'health_body':
        return AppLocaleText.tr(context, en: 'health and physical state', zhHans: '健康与身体状态', zhHant: '健康與身體狀態', ja: '健康と身体の状態');
      case 'money_spending':
        return AppLocaleText.tr(context, en: 'money and spending', zhHans: '金钱与消费', zhHant: '金錢與消費', ja: 'お金と消費');
      case 'learning_growth_expression':
        return AppLocaleText.tr(context, en: 'learning, growth, and expression', zhHans: '学习、成长与表达', zhHant: '學習、成長與表達', ja: '学び・成長・表現');
      case 'open':
        return AppLocaleText.tr(context, en: 'whatever comes up', zhHans: '想到什么记什么', zhHant: '想到什麼記什麼', ja: '思いついたことから記録する');
      default:
        return AppLocaleText.tr(context, en: 'not set yet', zhHans: '暂未设置', zhHant: '暫未設定', ja: '未設定');
    }
  }
}

class _WeeklyReadyBody extends StatelessWidget {
  final WeeklyInsightModel weekly;
  final SubmitState feedbackSubmitState;
  final Future<void> Function(String) onSubmitFeedback;

  const _WeeklyReadyBody({
    required this.weekly,
    required this.feedbackSubmitState,
    required this.onSubmitFeedback,
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

    final bestAction = weekly.bestAction ??
        AppLocaleText.tr(
          context,
          en: 'Start with one small step this week.',
          zhHans: '这周先从一小步开始。',
          zhHant: '這週先從一小步開始。',
          ja: '今週はまず小さな一歩から始めてみてください。',
        );

    final patterns = weekly.patterns;
    final frictions = weekly.frictions;
    final chartData = weekly.chartData;
    final topic = weekly.deriveTopicFocus();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isLightReady) ...[
          _StatusChipBanner(
            icon: Icons.wb_twilight_outlined,
            title: AppLocaleText.tr(
              context,
              en: 'Light weekly read',
              zhHans: '轻量 Weekly',
              zhHant: '輕量 Weekly',
              ja: '軽い Weekly',
            ),
            subtitle: AppLocaleText.tr(
              context,
              en: 'There are enough signals to begin reading, but it is still early. So this page stays lighter and more tentative.',
              zhHans: '现在已经有足够的线索开始形成观察了，但还比较早，所以这里会保持更轻、更保留的表达。',
              zhHant: '現在已經有足夠的線索開始形成觀察了，但還比較早，所以這裡會保持更輕、更保留的表達。',
              ja: '見立てを始めるだけの手がかりはありますが、まだ早い段階なので、ここでは軽めで保留のある表現にしています。',
            ),
          ),
        ] else ...[
          _StatusChipBanner(
            icon: Icons.insights_outlined,
            title: AppLocaleText.tr(
              context,
              en: 'Full weekly read',
              zhHans: '完整 Weekly',
              zhHant: '完整 Weekly',
              ja: 'まとまった Weekly',
            ),
            subtitle: AppLocaleText.tr(
              context,
              en: 'This week has enough material to support a more complete read.',
              zhHans: '这周已经有足够的材料，能支持更完整的阶段判断。',
              zhHant: '這週已經有足夠的材料，能支持更完整的階段判斷。',
              ja: '今週は、よりまとまった見立てを支えるだけの材料がそろっています。',
            ),
          ),
        ],
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
        const SizedBox(height: 22),
        SectionHeader(
          title: AppLocaleText.tr(
            context,
            en: 'This week at a glance',
            zhHans: '这周一眼看过去',
            zhHant: '這週一眼看過去',
            ja: '今週をひと目で見る',
          ),
          subtitle: isLightReady
              ? AppLocaleText.tr(
                  context,
                  en: 'Even a light weekly read can already show where signals are gathering and where the weekly trend is moving.',
                  zhHans: '即使是轻量 Weekly，也已经能先看到线索在往哪几天聚，以及这一周的走势大致往哪里走。',
                  zhHant: '即使是輕量 Weekly，也已經能先看到線索在往哪幾天聚，以及這一週的走勢大致往哪裡走。',
                  ja: '軽い Weekly でも、手がかりがどの日に集まりやすいか、今週の流れがどちらへ動いているかは見えてきます。',
                )
              : AppLocaleText.tr(
                  context,
                  en: 'Bars show signal density, and the line shows the weekly trend.',
                  zhHans: '柱状表示线索密度，折线表示这一周的走势。',
                  zhHant: '柱狀表示線索密度，折線表示這一週的走勢。',
                  ja: '棒は手がかりの密度、折れ線は今週の流れを表します。',
                ),
        ),
        const SizedBox(height: 10),
        _CompositeChartCard(
          points: chartData,
          isLightReady: isLightReady,
        ),
        const SizedBox(height: 22),
        if (isLightReady) ...[
          SectionHeader(
            title: AppLocaleText.tr(
              context,
              en: 'First signals',
              zhHans: '先看到的线索',
              zhHant: '先看到的線索',
              ja: '最初に見えてきた手がかり',
            ),
            subtitle: AppLocaleText.tr(
              context,
              en: 'A light weekly read focuses on one early pattern and one early friction.',
              zhHans: '轻量 Weekly 会先抓一个初步模式和一个初步摩擦点。',
              zhHant: '輕量 Weekly 會先抓一個初步模式和一個初步摩擦點。',
              ja: '軽い Weekly では、最初の pattern と最初の摩擦点を一つずつ拾います。',
            ),
          ),
          const SizedBox(height: 10),
          _InsightBlockList(
            title: AppLocaleText.tr(
              context,
              en: 'Repeated patterns',
              zhHans: '重复模式',
              zhHant: '重複模式',
              ja: '繰り返している pattern',
            ),
            items: patterns,
          ),
          const SizedBox(height: 14),
          _InsightBlockList(
            title: AppLocaleText.tr(
              context,
              en: 'Ongoing frictions',
              zhHans: '持续摩擦',
              zhHant: '持續摩擦',
              ja: '継続する摩擦',
            ),
            items: frictions,
          ),
          const SizedBox(height: 18),
          _ActionCard(
            title: AppLocaleText.tr(
              context,
              en: 'One small step for now',
              zhHans: '现在先做的一小步',
              zhHant: '現在先做的一小步',
              ja: '今はこれだけ試す',
            ),
            body: bestAction,
          ),
        ] else ...[
          SectionHeader(
            title: AppLocaleText.tr(
              context,
              en: 'Repeated patterns and ongoing frictions',
              zhHans: '这周的重复模式与持续摩擦',
              zhHant: '這週的重複模式與持續摩擦',
              ja: '今週の繰り返している pattern と継続する摩擦',
            ),
            subtitle: AppLocaleText.tr(
              context,
              en: 'This is where the week begins to feel less like scattered events and more like a shape.',
              zhHans: '这时这一周已经不太像散点事件，而开始有轮廓了。',
              zhHant: '這時這一週已經不太像散點事件，而開始有輪廓了。',
              ja: 'この段階になると、今週は散らばった出来事というより、少し形を持ち始めます。',
            ),
          ),
          const SizedBox(height: 10),
          _InsightBlockList(
            title: AppLocaleText.tr(
              context,
              en: 'Repeated patterns',
              zhHans: '重复模式',
              zhHant: '重複模式',
              ja: '繰り返している pattern',
            ),
            items: patterns,
          ),
          const SizedBox(height: 14),
          _InsightBlockList(
            title: AppLocaleText.tr(
              context,
              en: 'Ongoing frictions',
              zhHans: '持续摩擦',
              zhHant: '持續摩擦',
              ja: '継続する摩擦',
            ),
            items: frictions,
          ),
          const SizedBox(height: 18),
          _ActionCard(
            title: AppLocaleText.tr(
              context,
              en: 'What to try next',
              zhHans: '接下来先试什么',
              zhHant: '接下來先試什麼',
              ja: '次に試すなら',
            ),
            body: bestAction,
          ),
        ],
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
        : points.map((e) => e.moodScore).reduce((a, b) => a + b) / points.length;

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
        zhHans: '目前线索最集中的一天是$peakDay，这一周的走势${avgMood >= 0 ? '没有明显往下掉' : '有一点被往下拉'}。',
        zhHant: '目前線索最集中的一天是$peakDay，這一週的走勢${avgMood >= 0 ? '沒有明顯往下掉' : '有一點被往下拉'}。',
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

  void _drawBottomLabel(Canvas canvas, {required String text, required Offset center}) {
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

class _InsightBlockList extends StatelessWidget {
  final String title;
  final List<dynamic> items;

  const _InsightBlockList({
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final displayItems = items.isEmpty
        ? [
            {
              'name': AppLocaleText.tr(
                context,
                en: 'Not enough yet',
                zhHans: '暂时还不够',
                zhHant: '暫時還不夠',
                ja: 'まだ十分ではありません',
              ),
              'summary': AppLocaleText.tr(
                context,
                en: 'A clearer weekly shape will appear after a few more entries.',
                zhHans: '再多几条记录之后，这里的轮廓会更清楚。',
                zhHant: '再多幾條記錄之後，這裡的輪廓會更清楚。',
                ja: 'もう少し記録が増えると、ここはもっとはっきりしてきます。',
              ),
            }
          ]
        : items;

    return _UnifiedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          ...displayItems.map((item) {
            final map = item is Map<String, dynamic>
                ? item
                : (item is Map ? item.cast<String, dynamic>() : <String, dynamic>{});
            final name = (map['name'] as String?) ?? '';
            final summary = (map['summary'] as String?) ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(summary),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String body;

  const _ActionCard({
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
          Text(body),
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
