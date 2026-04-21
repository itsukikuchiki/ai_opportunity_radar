import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/i18n/app_locale_text.dart';
import '../../../core/models/memory_models.dart';
import '../../../shared/states/load_state.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/empty_state_block.dart';
import '../../../shared/widgets/section_header.dart';
import '../me/me_view_model.dart';
import 'memory_view_model.dart';

class MemoryPage extends StatelessWidget {
  const MemoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MemoryViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocaleText.tr(
            context,
            en: 'Journey',
            zhHans: 'Journey',
            zhHant: 'Journey',
            ja: 'Journey',
          ),
        ),
      ),
      body: switch (vm.loadState) {
        LoadState.loading => const Center(child: CircularProgressIndicator()),
        LoadState.error => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              EmptyStateBlock(
                icon: Icons.error_outline,
                title: AppLocaleText.tr(
                  context,
                  en: 'Journey failed to load',
                  zhHans: 'Journey 加载失败了',
                  zhHant: 'Journey 載入失敗了',
                  ja: 'Journey の読み込みに失敗しました',
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
            ],
          ),
        LoadState.empty => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              EmptyStateBlock(
                icon: vm.showFirstDayGate
                    ? Icons.route_outlined
                    : Icons.timeline_outlined,
                title: vm.showFirstDayGate
                    ? AppLocaleText.tr(
                        context,
                        en: 'Journey starts on day 2',
                        zhHans: 'Journey 第 2 天开始展示',
                        zhHant: 'Journey 第 2 天開始展示',
                        ja: 'Journey は 2 日目から表示されます',
                      )
                    : AppLocaleText.tr(
                        context,
                        en: 'No long-term signals yet',
                        zhHans: '还没有形成长期线索',
                        zhHant: '還沒有形成長期線索',
                        ja: 'まだ長期的な手がかりはありません',
                      ),
                subtitle: vm.showFirstDayGate
                    ? AppLocaleText.tr(
                        context,
                        en: 'If you already have local entries today, Journey can still start showing right away. Otherwise, it will begin from day 2.',
                        zhHans: '如果你今天已经留下本地记录，Journey 也可以立即开始展示；如果今天还没有记录，就会从第 2 天开始出现。',
                        zhHant: '如果你今天已經留下本地記錄，Journey 也可以立即開始展示；如果今天還沒有記錄，就會從第 2 天開始出現。',
                        ja: '今日すでにローカル記録があれば Journey はすぐ表示できます。まだ記録がなければ、2 日目から始まります。',
                      )
                    : AppLocaleText.tr(
                        context,
                        en: 'As more records accumulate, this page will begin sorting your long-term signals into weak signals, repeated patterns, and stable modes.',
                        zhHans: '随着记录慢慢积累，这里会开始把长期线索分成：刚冒头的线索、已经重复的模式、以及开始稳定成形的倾向。',
                        zhHant: '隨著記錄慢慢累積，這裡會開始把長期線索分成：剛冒頭的線索、已經重複的模式、以及開始穩定成形的傾向。',
                        ja: '記録が少しずつたまると、ここでは長期的な手がかりを「弱い signal」「繰り返している pattern」「安定し始めた mode」に分けて見られるようになります。',
                      ),
              ),
            ],
          ),
        _ => _JourneyReadyBody(vm: vm),
      },
    );
  }
}

class _JourneyReadyBody extends StatelessWidget {
  final MemoryViewModel vm;

  const _JourneyReadyBody({required this.vm});

  @override
  Widget build(BuildContext context) {
    final meVm = context.watch<MeViewModel>();
    final summary = vm.summary;
    final focusArea = meVm.selectedRepeatArea;

    if (summary == null || !summary.hasAnySignals) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          EmptyStateBlock(
            icon: Icons.timeline_outlined,
            title: AppLocaleText.tr(
              context,
              en: 'No long-term signals yet',
              zhHans: '还没有形成长期线索',
              zhHant: '還沒有形成長期線索',
              ja: 'まだ長期的な手がかりはありません',
            ),
            subtitle: AppLocaleText.tr(
              context,
              en: 'As more records accumulate, this page will begin sorting your long-term signals into weak signals, repeated patterns, and stable modes.',
              zhHans: '随着记录慢慢积累，这里会开始把长期线索分成：刚冒头的线索、已经重复的模式、以及开始稳定成形的倾向。',
              zhHant: '隨著記錄慢慢累積，這裡會開始把長期線索分成：剛冒頭的線索、已經重複的模式、以及開始穩定成形的傾向。',
              ja: '記録が少しずつたまると、ここでは長期的な手がかりを「弱い signal」「繰り返している pattern」「安定し始めた mode」に分けて見られるようになります。',
            ),
          ),
        ],
      );
    }

    final weakSignals = summary.weakSignals;
    final repeatedPatterns = summary.repeatedPatterns;
    final stableModes = summary.stableModes;
    final totalCount =
        weakSignals.length + repeatedPatterns.length + stableModes.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        AppHeader(
          title: AppLocaleText.tr(
            context,
            en: 'Journey',
            zhHans: 'Journey',
            zhHant: 'Journey',
            ja: 'Journey',
          ),
          subtitle: _headerSubtitle(context, focusArea),
          summary: AppLocaleText.tr(
            context,
            en: '$totalCount long-term signals are beginning to settle into layers',
            zhHans: '目前已经沉淀了 $totalCount 条长期线索，并开始分层成形',
            zhHant: '目前已經沉澱了 $totalCount 條長期線索，並開始分層成形',
            ja: 'ここまでに $totalCount 件の長期的な手がかりが積み上がり、層として見え始めています',
          ),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => context.go(AppRoutes.journal),
            icon: const Icon(Icons.menu_book_outlined),
            label: Text(
              AppLocaleText.tr(
                context,
                en: 'Open journal view',
                zhHans: '打开手帐视图',
                zhHant: '打開手帳視圖',
                ja: '手帳ビューを開く',
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _JourneyOverviewCard(
          weakCount: weakSignals.length,
          repeatedCount: repeatedPatterns.length,
          stableCount: stableModes.length,
        ),
        const SizedBox(height: 22),
        SectionHeader(
          title: AppLocaleText.tr(
            context,
            en: 'Three layers of your long-term signals',
            zhHans: '你的长期线索，开始分成 3 层',
            zhHant: '你的長期線索，開始分成 3 層',
            ja: '長期的な手がかりは 3 層に分かれ始めています',
          ),
          subtitle: AppLocaleText.tr(
            context,
            en: 'Start with what is only just appearing, then move to what keeps repeating, and finally to what is beginning to feel stable.',
            zhHans: '先看刚刚冒头的，再看已经反复出现的，最后看那些开始稳定下来的。',
            zhHant: '先看剛剛冒頭的，再看已經反覆出現的，最後看那些開始穩定下來的。',
            ja: 'まずは出始めたものを見て、次に繰り返しているもの、最後に安定し始めたものを見る流れです。',
          ),
        ),
        const SizedBox(height: 12),
        _SignalLayerSection(
          icon: Icons.radar_outlined,
          title: AppLocaleText.tr(
            context,
            en: 'Weak signals',
            zhHans: '刚冒头的线索',
            zhHant: '剛冒頭的線索',
            ja: '弱い signal',
          ),
          subtitle: AppLocaleText.tr(
            context,
            en: 'These are not strong enough yet to call a pattern, but they are worth keeping an eye on.',
            zhHans: '这些还不够强，暂时不能叫模式，但已经值得继续盯着看。',
            zhHant: '這些還不夠強，暫時不能叫模式，但已經值得繼續盯著看。',
            ja: 'まだ pattern と呼ぶほどではありませんが、見続ける価値が出始めています。',
          ),
          items: weakSignals,
          emptyText: AppLocaleText.tr(
            context,
            en: 'Right now there are no fresh weak signals standing out on their own.',
            zhHans: '目前还没有特别单独冒头的新线索。',
            zhHant: '目前還沒有特別單獨冒頭的新線索。',
            ja: '今のところ、単独で浮かび上がっている新しい signal はまだありません。',
          ),
        ),
        const SizedBox(height: 16),
        _SignalLayerSection(
          icon: Icons.repeat_rounded,
          title: AppLocaleText.tr(
            context,
            en: 'Repeated patterns',
            zhHans: '已经重复的模式',
            zhHant: '已經重複的模式',
            ja: '繰り返している pattern',
          ),
          subtitle: AppLocaleText.tr(
            context,
            en: 'These have shown up enough times that they are starting to look like something real.',
            zhHans: '这些已经出现过不止一次，开始像“真的有这么回事”。',
            zhHant: '這些已經出現過不止一次，開始像「真的有這麼回事」。',
            ja: 'これらは何度か現れていて、「たまたま」ではなくなり始めています。',
          ),
          items: repeatedPatterns,
          emptyText: AppLocaleText.tr(
            context,
            en: 'Nothing is clearly repeating yet.',
            zhHans: '目前还没有很清楚地重复起来的东西。',
            zhHant: '目前還沒有很清楚地重複起來的東西。',
            ja: 'まだはっきり繰り返しているものはありません。',
          ),
        ),
        const SizedBox(height: 16),
        _SignalLayerSection(
          icon: Icons.layers_outlined,
          title: AppLocaleText.tr(
            context,
            en: 'Stable modes',
            zhHans: '开始稳定成形的倾向',
            zhHant: '開始穩定成形的傾向',
            ja: '安定し始めた mode',
          ),
          subtitle: AppLocaleText.tr(
            context,
            en: 'These are no longer just returning. They are beginning to settle into a rhythm or tendency.',
            zhHans: '这些已经不只是反复回来，而开始沉淀成某种节奏或倾向。',
            zhHant: '這些已經不只是反覆回來，而開始沉澱成某種節奏或傾向。',
            ja: 'これらはただ戻ってくるだけではなく、リズムや傾向として定着し始めています。',
          ),
          items: stableModes,
          emptyText: AppLocaleText.tr(
            context,
            en: 'Nothing feels fully settled yet.',
            zhHans: '目前还没有完全稳定下来的东西。',
            zhHant: '目前還沒有完全穩定下來的東西。',
            ja: 'まだ十分に定着したと感じられるものはありません。',
          ),
        ),
        const SizedBox(height: 22),
        SectionHeader(
          title: AppLocaleText.tr(
            context,
            en: 'See the same signals by source',
            zhHans: '把同样的线索，换个来源角度再看一次',
            zhHant: '把同樣的線索，換個來源角度再看一次',
            ja: '同じ手がかりを、今度は出所ごとに見る',
          ),
          subtitle: AppLocaleText.tr(
            context,
            en: 'The three layers tell you how far a signal has developed. The sections below tell you what kind of signal it is.',
            zhHans: '上面的三层告诉你它发展到哪一步了；下面这一层告诉你，它本质上属于哪一种线索。',
            zhHant: '上面的三層告訴你它發展到哪一步了；下面這一層告訴你，它本質上屬於哪一種線索。',
            ja: '上の 3 層は手がかりがどこまで育っているかを示し、下のセクションはその手がかりが何の種類なのかを示します。',
          ),
        ),
        const SizedBox(height: 12),
        _SourceGroupsSection(summary: summary),
      ],
    );
  }

  String _headerSubtitle(BuildContext context, String? focusArea) {
    final focusLabel = _focusAreaLabel(context, focusArea);
    return AppLocaleText.tr(
      context,
      en: 'Long-term signals around $focusLabel',
      zhHans: '围绕「$focusLabel」的长期线索',
      zhHant: '圍繞「$focusLabel」的長期線索',
      ja: '「$focusLabel」をめぐる長期的な手がかり',
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
        return AppLocaleText.tr(context, en: 'your recent records', zhHans: '最近的记录', zhHant: '最近的記錄', ja: '最近の記録');
    }
  }
}

class _JourneyOverviewCard extends StatelessWidget {
  final int weakCount;
  final int repeatedCount;
  final int stableCount;

  const _JourneyOverviewCard({
    required this.weakCount,
    required this.repeatedCount,
    required this.stableCount,
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
              en: 'Where your journey stands now',
              zhHans: '你现在的 Journey，停在这里',
              zhHant: '你現在的 Journey，停在這裡',
              ja: '今の Journey はこのあたりです',
            ),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Text(
            AppLocaleText.tr(
              context,
              en: 'This page no longer shows only categories. It now shows how far each signal has actually developed.',
              zhHans: '这里不再只显示类别，而开始显示每条线索究竟发展到了哪一步。',
              zhHant: '這裡不再只顯示類別，而開始顯示每條線索究竟發展到了哪一步。',
              ja: 'ここではカテゴリだけでなく、それぞれの手がかりがどこまで育っているかも見えるようになっています。',
            ),
          ),
          const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => context.go(AppRoutes.journal),
            icon: const Icon(Icons.menu_book_outlined),
            label: Text(
              AppLocaleText.tr(
                context,
                en: 'Open journal view',
                zhHans: '打开手帐视图',
                zhHant: '打開手帳視圖',
                ja: '手帳ビューを開く',
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _CountChip(
                label: AppLocaleText.tr(
                  context,
                  en: 'Weak',
                  zhHans: '冒头',
                  zhHant: '冒頭',
                  ja: '出始め',
                ),
                count: weakCount,
              ),
              _CountChip(
                label: AppLocaleText.tr(
                  context,
                  en: 'Repeated',
                  zhHans: '重复',
                  zhHant: '重複',
                  ja: '反復',
                ),
                count: repeatedCount,
              ),
              _CountChip(
                label: AppLocaleText.tr(
                  context,
                  en: 'Stable',
                  zhHans: '稳定',
                  zhHant: '穩定',
                  ja: '安定',
                ),
                count: stableCount,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  final int count;

  const _CountChip({
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalLayerSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<JourneySignalItemModel> items;
  final String emptyText;

  const _SignalLayerSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.items,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    return _UnifiedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(subtitle),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text(emptyText)
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _JourneySignalCard(item: item),
              ),
            ),
        ],
      ),
    );
  }
}

class _JourneySignalCard extends StatelessWidget {
  final JourneySignalItemModel item;

  const _JourneySignalCard({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final tagLabel = _signalLevelLabel(context, item.signalLevel);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                item.name,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              _LevelChip(label: tagLabel),
            ],
          ),
          const SizedBox(height: 8),
          Text(item.summary),
        ],
      ),
    );
  }

  String _signalLevelLabel(BuildContext context, String level) {
    switch (level) {
      case 'stable_mode':
        return AppLocaleText.tr(
          context,
          en: 'stable mode',
          zhHans: '稳定倾向',
          zhHant: '穩定傾向',
          ja: '安定し始めた mode',
        );
      case 'repeated_pattern':
        return AppLocaleText.tr(
          context,
          en: 'repeated pattern',
          zhHans: '重复模式',
          zhHant: '重複模式',
          ja: '繰り返している pattern',
        );
      default:
        return AppLocaleText.tr(
          context,
          en: 'weak signal',
          zhHans: '弱线索',
          zhHant: '弱線索',
          ja: '弱い signal',
        );
    }
  }
}

class _SourceGroupsSection extends StatelessWidget {
  final MemorySummaryModel summary;

  const _SourceGroupsSection({
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SourceGroupTile(
          icon: Icons.sync_alt_rounded,
          title: AppLocaleText.tr(
            context,
            en: 'Patterns',
            zhHans: 'Patterns / 模式',
            zhHant: 'Patterns / 模式',
            ja: 'Patterns / パターン',
          ),
          subtitle: AppLocaleText.tr(
            context,
            en: 'Things that keep coming back in a similar way.',
            zhHans: '那些会以相似方式一再回来的东西。',
            zhHant: '那些會以相似方式一再回來的東西。',
            ja: '似た形で繰り返し戻ってくるもの。',
          ),
          items: summary.patterns,
        ),
        const SizedBox(height: 12),
        _SourceGroupTile(
          icon: Icons.warning_amber_rounded,
          title: AppLocaleText.tr(
            context,
            en: 'Frictions',
            zhHans: 'Frictions / 摩擦',
            zhHant: 'Frictions / 摩擦',
            ja: 'Frictions / 摩擦',
          ),
          subtitle: AppLocaleText.tr(
            context,
            en: 'Things that keep draining your time, focus, or energy.',
            zhHans: '那些持续消耗你时间、注意力或精力的东西。',
            zhHant: '那些持續消耗你時間、注意力或精力的東西。',
            ja: '時間や集中力、エネルギーを削り続けるもの。',
          ),
          items: summary.frictions,
        ),
        const SizedBox(height: 12),
        _SourceGroupTile(
          icon: Icons.explore_outlined,
          title: AppLocaleText.tr(
            context,
            en: 'Desires',
            zhHans: 'Desires / 方向',
            zhHant: 'Desires / 方向',
            ja: 'Desires / 方向',
          ),
          subtitle: AppLocaleText.tr(
            context,
            en: 'Things you may be moving toward, even if they are still vague.',
            zhHans: '那些你可能正在靠近、但还没完全说清的方向。',
            zhHant: '那些你可能正在靠近、但還沒完全說清的方向。',
            ja: 'まだ曖昧でも、少しずつ向かい始めている方向。',
          ),
          items: summary.desires,
        ),
        const SizedBox(height: 12),
        _SourceGroupTile(
          icon: Icons.auto_awesome_outlined,
          title: AppLocaleText.tr(
            context,
            en: 'Experiments',
            zhHans: 'Experiments / 有效尝试',
            zhHant: 'Experiments / 有效嘗試',
            ja: 'Experiments / 効いている試み',
          ),
          subtitle: AppLocaleText.tr(
            context,
            en: 'Things that may already be helping a little.',
            zhHans: '那些可能已经开始起一点作用的东西。',
            zhHant: '那些可能已經開始起一點作用的東西。',
            ja: '少しずつ助けになり始めているかもしれないもの。',
          ),
          items: summary.experiments,
        ),
      ],
    );
  }
}

class _SourceGroupTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<JourneySignalItemModel> items;

  const _SourceGroupTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        backgroundColor: Theme.of(context).cardColor,
        collapsedBackgroundColor: Theme.of(context).cardColor,
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        children: [
          if (items.isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                AppLocaleText.tr(
                  context,
                  en: 'There are no clear signals in this source yet.',
                  zhHans: '这个来源下暂时还没有很明确的线索。',
                  zhHant: '這個來源下暫時還沒有很明確的線索。',
                  ja: 'この出所では、まだはっきりした手がかりは見えていません。',
                ),
              ),
            )
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _JourneySignalCard(item: item),
              ),
            ),
        ],
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  final String label;

  const _LevelChip({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall,
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
