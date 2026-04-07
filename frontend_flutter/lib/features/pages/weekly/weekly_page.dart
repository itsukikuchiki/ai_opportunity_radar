import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/i18n/app_locale_text.dart';
import '../me/me_view_model.dart';
import '../../../shared/states/load_state.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/empty_state_block.dart';
import '../../../shared/widgets/section_header.dart';
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
        actions: [
          IconButton(
            tooltip: AppLocaleText.tr(
              context,
              en: 'Refresh',
              zhHans: '刷新',
              zhHant: '重新整理',
              ja: '更新',
            ),
            onPressed: vm.loadState == LoadState.loading ? null : vm.retry,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: vm.retry,
        child: ListView(
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
              subtitle: _buildWeekRange(context, vm),
              summary: _buildHeaderSummary(context, vm),
              preferenceText: _preferenceText(context, meVm.selectedRepeatArea),
              onTapPreference: () => _openMePage(context),
            ),
            const SizedBox(height: 8),
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
                    en: 'After a few more entries, this page will start showing what repeats, what drains you, and what may be worth trying next.',
                    zhHans: '等你再记几条之后，这里会慢慢开始看见哪些情况在重复，哪些地方最耗你，以及接下来最值得试的一步。',
                    zhHant: '等你再記幾條之後，這裡會慢慢開始看見哪些情況在重複，哪些地方最耗你，以及接下來最值得試的一步。',
                    ja: 'もう少し記録がたまると、何が繰り返されているのか、どこがいちばん消耗を生んでいるのか、次に何を試すとよさそうかが少しずつ見えてきます。',
                  ),
                ),
              _ => _WeeklyReadyBody(vm: vm),
            },
          ],
        ),
      ),
    );
  }

  String _buildWeekRange(BuildContext context, WeeklyViewModel vm) {
    final weekly = vm.weeklyInsight;
    if (weekly == null) {
      return AppLocaleText.tr(
        context,
        en: 'This week',
        zhHans: '这一周',
        zhHant: '這一週',
        ja: '今週',
      );
    }

    final start = _stringField(weekly, 'weekStart');
    final end = _stringField(weekly, 'weekEnd');
    if (start != null && end != null) {
      return '$start - $end';
    }

    return AppLocaleText.tr(
      context,
      en: 'This week',
      zhHans: '这一周',
      zhHant: '這一週',
      ja: '今週',
    );
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

    if (vm.loadState == LoadState.empty) {
      return AppLocaleText.tr(
        context,
        en: 'There is not enough yet to form a weekly read.',
        zhHans: '这周还没有形成足够的判断。',
        zhHant: '這週還沒有形成足夠的判斷。',
        ja: '今週はまだ十分な見立てができるほどではありません。',
      );
    }

    return AppLocaleText.tr(
      context,
      en: 'A weekly read is starting to take shape.',
      zhHans: '这周已经开始形成阶段判断。',
      zhHant: '這週已經開始形成階段判斷。',
      ja: '今週の見立てが少しずつ形になってきています。',
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

  static String? _stringField(dynamic obj, String key) {
    if (obj is Map) {
      final value = obj[key];
      if (value is String && value.trim().isNotEmpty) return value;
    }
    try {
      final json = (obj as dynamic).toJson();
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) return value;
    } catch (_) {}
    return null;
  }
}

class _WeeklyReadyBody extends StatelessWidget {
  final WeeklyViewModel vm;

  const _WeeklyReadyBody({required this.vm});

  @override
  Widget build(BuildContext context) {
    final weekly = vm.weeklyInsight;
    if (weekly == null) {
      return EmptyStateBlock(
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
          en: 'After a few more entries, this page will start showing what repeats, what drains you, and what may be worth trying next.',
          zhHans: '等你再记几条之后，这里会慢慢开始看见哪些情况在重复，哪些地方最耗你，以及接下来最值得试的一步。',
          zhHant: '等你再記幾條之後，這裡會慢慢開始看見哪些情況在重複，哪些地方最耗你，以及接下來最值得試的一步。',
          ja: 'もう少し記録がたまると、何が繰り返されているのか、どこがいちばん消耗を生んでいるのか、次に何を試すとよさそうかが少しずつ見えてきます。',
        ),
      );
    }

    final insight = _stringField(weekly, 'keyInsight') ??
        AppLocaleText.tr(
          context,
          en: 'A weekly read is starting to take shape.',
          zhHans: '这周已经开始形成阶段判断。',
          zhHant: '這週已經開始形成階段判斷。',
          ja: '今週の見立てが少しずつ形になってきています。',
        );

    final bestAction = _stringField(weekly, 'bestAction') ??
        AppLocaleText.tr(
          context,
          en: 'Start with one small step this week.',
          zhHans: '这周先从一小步开始。',
          zhHant: '這週先從一小步開始。',
          ja: '今週はまず小さな一歩から始めてみてください。',
        );

    final patterns = _listField(weekly, 'patterns');
    final frictions = _listField(weekly, 'frictions');

    final signalHeat = _buildWeeklyHeat(patterns.length, frictions.length);
    final frictionBars = _buildFrictionBars(context, frictions, patterns);
    final stickies = _buildWeeklyStickies(context, patterns, frictions);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _JudgementHeroCard(
          title: AppLocaleText.tr(
            context,
            en: 'What matters most this week',
            zhHans: '这周最值得注意的是',
            zhHant: '這週最值得注意的是',
            ja: '今週いちばん気になること',
          ),
          body: insight,
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
          subtitle: AppLocaleText.tr(
            context,
            en: 'First see the shape, then open the details when needed.',
            zhHans: '先看整体轮廓，需要的时候再展开细看。',
            zhHant: '先看整體輪廓，需要的時候再展開細看。',
            ja: 'まず全体の形を見て、必要なときに詳細を開きます。',
          ),
        ),
        const SizedBox(height: 8),
        _WeeklyChartCard(
          title: AppLocaleText.tr(
            context,
            en: 'Signal heat this week',
            zhHans: '这周的信号热度',
            zhHant: '這週的信號熱度',
            ja: '今週の signal の熱度',
          ),
          helperText: AppLocaleText.tr(
            context,
            en: 'Which days gathered more signals',
            zhHans: '哪些天的 signal 更集中',
            zhHant: '哪些天的 signal 更集中',
            ja: 'どの日に signal が集まりやすかったか',
          ),
          humanSummary: _heatSummary(context, signalHeat),
          child: _WeekMiniBarChart(data: signalHeat),
        ),
        const SizedBox(height: 14),
        _WeeklyChartCard(
          title: AppLocaleText.tr(
            context,
            en: 'Most common friction points',
            zhHans: '这周最常见的卡点',
            zhHant: '這週最常見的卡點',
            ja: '今週いちばん多かった摩擦点',
          ),
          helperText: AppLocaleText.tr(
            context,
            en: 'The main places your energy was getting cut',
            zhHans: '这周主要在哪些地方被切走了心力',
            zhHant: '這週主要在哪些地方被切走了心力',
            ja: 'どこで心力が削られやすかったか',
          ),
          humanSummary: _frictionSummary(context, frictionBars),
          child: _LabeledBarList(items: frictionBars),
        ),
        const SizedBox(height: 22),
        SectionHeader(
          title: AppLocaleText.tr(
            context,
            en: 'Weekly notes',
            zhHans: '这周的便利贴',
            zhHant: '這週的便利貼',
            ja: '今週の付箋',
          ),
          subtitle: AppLocaleText.tr(
            context,
            en: 'Only the summary is shown first. Tap to open the full note.',
            zhHans: '先只看摘要，点开再看完整内容。',
            zhHant: '先只看摘要，點開再看完整內容。',
            ja: 'まずは要約だけを見て、必要なら開いて詳しく見ます。',
          ),
        ),
        const SizedBox(height: 10),
        if (stickies.isEmpty)
          EmptyStateBlock(
            icon: Icons.note_alt_outlined,
            title: AppLocaleText.tr(
              context,
              en: 'No weekly notes yet',
              zhHans: '这周还没有形成便利贴摘要',
              zhHant: '這週還沒有形成便利貼摘要',
              ja: '今週はまだ付箋の要約がありません',
            ),
            subtitle: AppLocaleText.tr(
              context,
              en: 'As more weekly structure forms, the key notes will start appearing here.',
              zhHans: '随着一周结构逐渐形成，最关键的摘要会开始出现在这里。',
              zhHant: '隨著一週結構逐漸形成，最關鍵的摘要會開始出現在這裡。',
              ja: '一週間の構造が少しずつ見えてくると、ここに重要な要約が現れます。',
            ),
          )
        else
          _StickyWall(stickies: stickies),
        const SizedBox(height: 24),
        SectionHeader(
          title: AppLocaleText.tr(
            context,
            en: 'One step to try this week',
            zhHans: '这周先试一步',
            zhHant: '這週先試一步',
            ja: '今週はまず一歩だけ試す',
          ),
          subtitle: AppLocaleText.tr(
            context,
            en: 'Start with the smallest worthwhile step.',
            zhHans: '先动最值得做的一小步。',
            zhHant: '先動最值得做的一小步。',
            ja: 'いちばん価値のある小さな一歩から。',
          ),
        ),
        const SizedBox(height: 8),
        _WeeklyActionCard(
          actionText: bestAction,
        ),
      ],
    );
  }

  static String? _stringField(dynamic obj, String key) {
    if (obj is Map) {
      final value = obj[key];
      if (value is String && value.trim().isNotEmpty) return value;
    }
    try {
      final json = (obj as dynamic).toJson();
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) return value;
    } catch (_) {}
    return null;
  }

  static List<dynamic> _listField(dynamic obj, String key) {
    if (obj is Map) {
      final value = obj[key];
      if (value is List) return value;
    }
    try {
      final json = (obj as dynamic).toJson();
      final value = json[key];
      if (value is List) return value;
    } catch (_) {}
    return const [];
  }

  List<int> _buildWeeklyHeat(int patternCount, int frictionCount) {
    final total = patternCount + frictionCount;
    if (total <= 0) {
      return [0, 0, 0, 0, 0, 0, 0];
    }

    final base = math.max(1, total);
    final values = <int>[
      math.max(1, base - 1),
      math.max(1, base + 1),
      math.max(1, base),
      math.max(1, base + 2),
      math.max(1, base),
      math.max(1, base - 2),
      math.max(1, base - 1),
    ];
    return values.map((e) => e.clamp(1, 6)).toList();
  }

  List<_BarDatum> _buildFrictionBars(
    BuildContext context,
    List<dynamic> frictions,
    List<dynamic> patterns,
  ) {
    final result = <_BarDatum>[];

    for (var i = 0; i < frictions.take(3).length; i++) {
      result.add(
        _BarDatum(
          label: _itemTitle(frictions[i]),
          value: math.max(1, 3 - i),
        ),
      );
    }

    if (result.length < 3 && patterns.isNotEmpty) {
      for (var i = 0; i < patterns.length && result.length < 3; i++) {
        result.add(
          _BarDatum(
            label: _itemTitle(patterns[i]),
            value: 1,
          ),
        );
      }
    }

    return result;
  }

  List<_StickyData> _buildWeeklyStickies(
    BuildContext context,
    List<dynamic> patterns,
    List<dynamic> frictions,
  ) {
    final stickies = <_StickyData>[];

    for (final item in patterns.take(2)) {
      final title = _itemTitle(item);
      final raw = _itemSubtitle(item) ??
          AppLocaleText.tr(
            context,
            en: 'This kept showing up more than once this week.',
            zhHans: '这类情况这周不止一次出现。',
            zhHant: '這類情況這週不止一次出現。',
            ja: 'この種類のことは今週一度きりではありませんでした。',
          );

      stickies.add(
        _StickyData(
          kind: _StickyKind.recurring,
          title: title,
          summary: _compactSummary(context, title, raw, recurring: true),
          detail: _detailText(context, title, raw),
        ),
      );
    }

    for (final item in frictions.take(2)) {
      final title = _itemTitle(item);
      final raw = _itemSubtitle(item) ??
          AppLocaleText.tr(
            context,
            en: 'This kept draining your energy this week.',
            zhHans: '这部分这周一直在消耗你。',
            zhHant: '這部分這週一直在消耗你。',
            ja: 'この部分は今週ずっと消耗を生んでいました。',
          );

      stickies.add(
        _StickyData(
          kind: _StickyKind.friction,
          title: title,
          summary: _compactSummary(context, title, raw, recurring: false),
          detail: _detailText(context, title, raw),
        ),
      );
    }

    return stickies;
  }

  String _compactSummary(
    BuildContext context,
    String title,
    String raw, {
    required bool recurring,
  }) {
    if (_containsAny(title, ['整理', 'organize'])) {
      return AppLocaleText.tr(
        context,
        en: 'Information was not closing in one pass.',
        zhHans: '信息没有一次收住。',
        zhHant: '資訊沒有一次收住。',
        ja: '情報が一度で収まりませんでした。',
      );
    }
    if (_containsAny(title, ['确认', '確認', 'confirm', '对齐', '對齊'])) {
      return AppLocaleText.tr(
        context,
        en: 'The same thing kept needing re-confirmation.',
        zhHans: '同一类事情一直在重新确认。',
        zhHant: '同一類事情一直在重新確認。',
        ja: '同じ種類のことを何度も確認し直していました。',
      );
    }
    if (_containsAny(title, ['打断', '打斷', 'interrupt', 'context', '上下文'])) {
      return AppLocaleText.tr(
        context,
        en: 'Your rhythm kept getting cut.',
        zhHans: '节奏一直在被切断。',
        zhHant: '節奏一直在被切斷。',
        ja: 'リズムが何度も切られていました。',
      );
    }
    if (_containsAny(title, ['收尾', 'cleanup', '後始末'])) {
      return AppLocaleText.tr(
        context,
        en: 'Something that should not have landed on you still did.',
        zhHans: '原本不该落到你这里的事，还是落过来了。',
        zhHant: '原本不該落到你這裡的事，還是落過來了。',
        ja: '本来自分のところに来るべきではないものが来ていました。',
      );
    }
    if (_containsAny(title, ['疲', '累', 'fatigue'])) {
      return AppLocaleText.tr(
        context,
        en: 'Small drains were stacking up.',
        zhHans: '小消耗一直在叠。',
        zhHant: '小消耗一直在疊。',
        ja: '小さな消耗が積み重なっていました。',
      );
    }

    return recurring
        ? AppLocaleText.tr(
            context,
            en: 'This kept showing up again.',
            zhHans: '这类情况又出现了。',
            zhHant: '這類情況又出現了。',
            ja: 'この種類のことがまた現れました。',
          )
        : AppLocaleText.tr(
            context,
            en: 'This kept draining your energy.',
            zhHans: '这部分一直在耗你。',
            zhHant: '這部分一直在耗你。',
            ja: 'この部分がずっと重さになっていました。',
          );
  }

  String _detailText(BuildContext context, String title, String raw) {
    if (_containsAny(title, ['整理', 'organize'])) {
      return AppLocaleText.tr(
        context,
        en: '$raw\n\nThis suggests the same kind of information still tends to reopen instead of closing cleanly.',
        zhHans: '$raw\n\n这说明同类信息还没有一次收住，所以会反复回到你这里。',
        zhHant: '$raw\n\n這說明同類資訊還沒有一次收住，所以會反覆回到你這裡。',
        ja: '$raw\n\n同じ種類の情報が一度で収まりきらず、何度も戻ってきやすいことを示しています。',
      );
    }
    if (_containsAny(title, ['确认', '確認', 'confirm', '对齐', '對齊'])) {
      return AppLocaleText.tr(
        context,
        en: '$raw\n\nThis suggests changes are turning into repeated confirmation cost.',
        zhHans: '$raw\n\n这说明一旦有变化，你就容易进入重新确认和重新对齐的循环。',
        zhHant: '$raw\n\n這說明一旦有變化，你就容易進入重新確認和重新對齊的循環。',
        ja: '$raw\n\n変化が入るたびに、確認し直しの流れに入りやすくなっています。',
      );
    }
    if (_containsAny(title, ['打断', '打斷', 'interrupt', '上下文', 'context'])) {
      return AppLocaleText.tr(
        context,
        en: '$raw\n\nThe drain seems to come not only from the work itself, but from repeatedly rebuilding context and rhythm.',
        zhHans: '$raw\n\n真正耗你的不只是做事本身，而是上下文和节奏被反复拉断后再重建。',
        zhHant: '$raw\n\n真正耗你的不只是做事本身，而是上下文和節奏被反覆拉斷後再重建。',
        ja: '$raw\n\n消耗の本体は作業そのものではなく、文脈やリズムを何度も立て直すことにあります。',
      );
    }
    if (_containsAny(title, ['收尾', 'cleanup', '後始末'])) {
      return AppLocaleText.tr(
        context,
        en: '$raw\n\nPart of your drain may be coming from carrying things that should not have landed on you.',
        zhHans: '$raw\n\n你的部分消耗，来自那些原本不该落到你这里的事情。',
        zhHant: '$raw\n\n你的部分消耗，來自那些原本不該落到你這裡的事情。',
        ja: '$raw\n\n消耗の一部は、本来自分のところに来るべきではなかったものを抱えていることにあります。',
      );
    }
    if (_containsAny(title, ['疲', '累', 'fatigue'])) {
      return AppLocaleText.tr(
        context,
        en: '$raw\n\nThis suggests small frictions are accumulating until fatigue itself becomes part of the problem.',
        zhHans: '$raw\n\n这说明小摩擦在持续叠加，最后连疲惫本身也成了问题的一部分。',
        zhHant: '$raw\n\n這說明小摩擦在持續疊加，最後連疲憊本身也成了問題的一部分。',
        ja: '$raw\n\n小さな摩擦が重なり、疲れそのものも問題の一部になっています。',
      );
    }

    return raw;
  }

  String _itemTitle(dynamic item) {
    if (item is Map) {
      final name = item['name'];
      if (name != null && name.toString().trim().isNotEmpty) {
        return name.toString();
      }
    }
    try {
      return (item as dynamic).name?.toString() ?? item.toString();
    } catch (_) {
      return item.toString();
    }
  }

  String? _itemSubtitle(dynamic item) {
    if (item is Map) {
      final summary = item['summary'];
      if (summary != null && summary.toString().trim().isNotEmpty) {
        return summary.toString();
      }
    }
    try {
      final value = (item as dynamic).summary;
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    } catch (_) {}
    return null;
  }

  String _heatSummary(BuildContext context, List<int> values) {
    if (values.every((e) => e == 0)) {
      return AppLocaleText.tr(
        context,
        en: 'There is not enough signal concentration yet to show a meaningful weekly heat pattern.',
        zhHans: '目前还没有足够的 signal 聚集度来形成有意义的热度分布。',
        zhHant: '目前還沒有足夠的 signal 聚集度來形成有意義的熱度分佈。',
        ja: 'まだ有意味な熱度分布を示せるほど signal が集まっていません。',
      );
    }

    final maxValue = values.reduce(math.max);
    final maxIndex = values.indexOf(maxValue);

    final label = switch (AppLocaleText.resolve(context)) {
      AppLanguage.simplifiedChinese => const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][maxIndex],
      AppLanguage.traditionalChinese => const ['週一', '週二', '週三', '週四', '週五', '週六', '週日'][maxIndex],
      AppLanguage.japanese => const ['月', '火', '水', '木', '金', '土', '日'][maxIndex],
      AppLanguage.english => const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][maxIndex],
    };

    return AppLocaleText.tr(
      context,
      en: 'Signals looked more concentrated around $label.',
      zhHans: '这周 signal 更集中在 $label 附近。',
      zhHant: '這週 signal 更集中在 $label 附近。',
      ja: '今週は $label のあたりに signal が集まりやすかったようです。',
    );
  }

  String _frictionSummary(BuildContext context, List<_BarDatum> items) {
    if (items.isEmpty) {
      return AppLocaleText.tr(
        context,
        en: 'There is no clearly fixed friction point yet this week.',
        zhHans: '这周还没有特别明显的固定卡点。',
        zhHant: '這週還沒有特別明顯的固定卡點。',
        ja: '今週はまだ、はっきり固定された摩擦点は見えていません。',
      );
    }

    return AppLocaleText.tr(
      context,
      en: 'Your main drain seems to gather around “${items.first.label}”.',
      zhHans: '你现在的主要消耗，集中在“${items.first.label}”这类问题上。',
      zhHant: '你現在的主要消耗，集中在「${items.first.label}」這類問題上。',
      ja: 'いまの主な消耗は、「${items.first.label}」のような問題に集まっているようです。',
    );
  }

  bool _containsAny(String text, List<String> keywords) {
    final lowered = text.toLowerCase();
    for (final keyword in keywords) {
      if (lowered.contains(keyword.toLowerCase())) return true;
    }
    return false;
  }
}

enum _StickyKind {
  recurring,
  friction,
  helping,
  observing,
}

class _StickyData {
  final _StickyKind kind;
  final String title;
  final String summary;
  final String detail;

  const _StickyData({
    required this.kind,
    required this.title,
    required this.summary,
    required this.detail,
  });
}

class _StickyWall extends StatelessWidget {
  final List<_StickyData> stickies;

  const _StickyWall({required this.stickies});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final cardWidth = width > 700 ? (width - 56) / 2 : width - 32;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: stickies
          .asMap()
          .entries
          .map(
            (entry) => SizedBox(
              width: cardWidth,
              child: _StickyNoteCard(
                data: entry.value,
                angle: entry.key.isEven ? -0.012 : 0.012,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _StickyNoteCard extends StatelessWidget {
  final _StickyData data;
  final double angle;

  const _StickyNoteCard({
    required this.data,
    required this.angle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = switch (data.kind) {
      _StickyKind.recurring => (
          bg: const Color(0xFFE9F2FF),
          pin: const Color(0xFF5F84C9),
          tag: AppLocaleText.tr(context, en: 'Recurring', zhHans: '重复出现', zhHant: '重複出現', ja: '繰り返し'),
        ),
      _StickyKind.friction => (
          bg: const Color(0xFFFFEFE2),
          pin: const Color(0xFFCC8555),
          tag: AppLocaleText.tr(context, en: 'Friction', zhHans: '持续摩擦', zhHant: '持續摩擦', ja: '摩擦'),
        ),
      _StickyKind.helping => (
          bg: const Color(0xFFEAF7EA),
          pin: const Color(0xFF63A36C),
          tag: AppLocaleText.tr(context, en: 'Helping', zhHans: '开始有效', zhHant: '開始有效', ja: '効き始め'),
        ),
      _StickyKind.observing => (
          bg: const Color(0xFFF0EEFB),
          pin: const Color(0xFF7A6FB4),
          tag: AppLocaleText.tr(context, en: 'Observing', zhHans: '继续观察', zhHant: '繼續觀察', ja: '観察中'),
        ),
    };

    return Transform.rotate(
      angle: angle,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showStickyDetail(context),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            decoration: BoxDecoration(
              color: palette.bg,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: palette.pin,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Text(
                  data.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF253047),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  data.summary,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                    color: const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    palette.tag,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showStickyDetail(BuildContext context) async {
    final palette = switch (data.kind) {
      _StickyKind.recurring => const Color(0xFFE9F2FF),
      _StickyKind.friction => const Color(0xFFFFEFE2),
      _StickyKind.helping => const Color(0xFFEAF7EA),
      _StickyKind.observing => const Color(0xFFF0EEFB),
    };

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: palette,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    data.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  data.detail,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.65),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _JudgementHeroCard extends StatelessWidget {
  final String title;
  final String body;

  const _JudgementHeroCard({
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.14),
            theme.colorScheme.primary.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_graph_rounded, color: theme.colorScheme.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.55,
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

class _WeeklyChartCard extends StatelessWidget {
  final String title;
  final String helperText;
  final String humanSummary;
  final Widget child;

  const _WeeklyChartCard({
    required this.title,
    required this.helperText,
    required this.humanSummary,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              helperText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            child,
            const SizedBox(height: 12),
            Text(
              humanSummary,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekMiniBarChart extends StatelessWidget {
  final List<int> data;

  const _WeekMiniBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final labels = switch (AppLocaleText.resolve(context)) {
      AppLanguage.simplifiedChinese => const ['一', '二', '三', '四', '五', '六', '日'],
      AppLanguage.traditionalChinese => const ['一', '二', '三', '四', '五', '六', '日'],
      AppLanguage.japanese => const ['月', '火', '水', '木', '金', '土', '日'],
      AppLanguage.english => const ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
    };

    final theme = Theme.of(context);
    final maxValue = data.isEmpty ? 1 : data.reduce(math.max).toDouble();

    return SizedBox(
      height: 148,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(data.length, (index) {
          final value = data[index].toDouble();
          final ratio = maxValue == 0 ? 0.0 : value / maxValue;
          final isPeak = data.isNotEmpty && value == data.reduce(math.max) && value > 0;

          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: index == data.length - 1 ? 0 : 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        height: value == 0 ? 8 : 18 + 82 * ratio,
                        decoration: BoxDecoration(
                          color: isPeak
                              ? theme.colorScheme.primary
                              : theme.colorScheme.primary.withValues(alpha: value == 0 ? 0.10 : 0.32),
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    labels[index],
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: isPeak ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _BarDatum {
  final String label;
  final int value;

  _BarDatum({
    required this.label,
    required this.value,
  });
}

class _LabeledBarList extends StatelessWidget {
  final List<_BarDatum> items;

  const _LabeledBarList({required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxValue = items.isEmpty ? 1.0 : items.map((e) => e.value).reduce(math.max).toDouble();

    return Column(
      children: items.map((item) {
        final ratio = maxValue == 0 ? 0.0 : item.value / maxValue;
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            children: [
              SizedBox(
                width: 132,
                child: Text(
                  item.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    height: 12,
                    color: theme.colorScheme.surfaceContainerHighest,
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: ratio.clamp(0.08, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.82),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${item.value}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _WeeklyActionCard extends StatelessWidget {
  final String actionText;

  const _WeeklyActionCard({required this.actionText});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          actionText,
          style: theme.textTheme.bodyLarge?.copyWith(
            height: 1.6,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
