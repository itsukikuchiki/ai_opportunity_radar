// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/i18n/app_locale_text.dart';
import '../../../core/models/memory_models.dart';
import '../../../shared/states/load_state.dart';
import '../../../shared/widgets/aurora_ui.dart';
import '../../../shared/widgets/empty_state_block.dart';
import 'memory_view_model.dart';

class MemoryPage extends StatelessWidget {
  const MemoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MemoryViewModel>();

    return Scaffold(
      body: Stack(
        children: [
          AuroraPage(
            child: SafeArea(
              bottom: false,
              child: switch (vm.loadState) {
                LoadState.loading =>
                  const Center(child: CircularProgressIndicator()),
                LoadState.error => ListView(
                    padding: const EdgeInsets.fromLTRB(20, 2, 20, 116),
                    children: [
                      _JourneyTop(summary: vm.summary),
                      const SizedBox(height: 16),
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
                    padding: const EdgeInsets.fromLTRB(20, 2, 20, 116),
                    children: [
                      _JourneyTop(summary: vm.summary),
                      const SizedBox(height: 16),
                      EmptyStateBlock(
                        icon: vm.showFirstDayGate
                            ? Icons.route_outlined
                            : Icons.timeline_outlined,
                        title: AppLocaleText.tr(
                          context,
                          en: 'Your Life Journey is forming',
                          zhHans: '生活地图正在形成',
                          zhHant: '生活地圖正在形成',
                          ja: '生活の旅路が形になり始めています',
                        ),
                        subtitle: vm.showFirstDayGate
                            ? AppLocaleText.tr(
                                context,
                                en: 'It starts with a first light path and gradually becomes your Life Journey.',
                                zhHans: '先显示第一段轻量路径，之后会慢慢变成你的生活地图。',
                                zhHant: '先顯示第一段輕量路徑，之後會慢慢變成你的生活地圖。',
                                ja: 'まず最初の軽い道すじから始まり、少しずつあなたの生活の旅路になっていきます。',
                              )
                            : AppLocaleText.tr(
                                context,
                                en: 'Leave a few signals first. The first life path will gradually appear here.',
                                zhHans: '先留下几条信号，第一段生活路径会慢慢出现在这里。',
                                zhHant: '先留下幾條信號，第一段生活路徑會慢慢出現在這裡。',
                                ja: 'まずいくつかのシグナルを残すと、最初の生活の道すじが少しずつここに現れます。',
                              ),
                      ),
                    ],
                  ),
                _ => _JourneyReadyBody(vm: vm),
              },
            ),
          ),
          const AuroraSafeTopMask(),
        ],
      ),
    );
  }
}

void _showJourneyHint(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
      ),
    );
}

class _JourneyTop extends StatelessWidget {
  final MemorySummaryModel? summary;

  const _JourneyTop({required this.summary});

  @override
  Widget build(BuildContext context) {
    final text = summary?.longTermPattern?.summary.trim();
    final displayText = text == null || text.isEmpty
        ? null
        : _localizedGeneratedText(context, text);
    return AuroraQuoteCard(
      minHeight: 132,
      landscape: true,
      text: displayText == null || displayText.isEmpty
          ? AppLocaleText.tr(
              context,
              en: 'Your Life Journey is still forming from the signals you keep.',
              zhHans: '你的生活地图正在从留下的信号里慢慢形成。',
              zhHant: '你的生活地圖正在從留下的信號裡慢慢形成。',
              ja: 'あなたの生活の旅路は、残したシグナルから少しずつ形になっています。',
            )
          : displayText,
    );
  }
}

String _localizedGeneratedText(BuildContext context, String text) {
  final planning = AppLocaleText.tr(
    context,
    en: 'planning',
    zhHans: '安排',
    zhHant: '安排',
    ja: '予定',
  );
  final labels = {
    '[planning]': planning,
    'planning': planning,
    'work': AppLocaleText.tr(
      context,
      en: 'work',
      zhHans: '工作',
      zhHant: '工作',
      ja: '仕事',
    ),
    'recovery': AppLocaleText.tr(
      context,
      en: 'recovery',
      zhHans: '恢复',
      zhHant: '恢復',
      ja: '回復',
    ),
    'relationship': AppLocaleText.tr(
      context,
      en: 'relationship',
      zhHans: '关系',
      zhHant: '關係',
      ja: '関係',
    ),
    'boundary': AppLocaleText.tr(
      context,
      en: 'boundary',
      zhHans: '边界',
      zhHant: '邊界',
      ja: '境界線',
    ),
  };

  var output = text;
  for (final entry in labels.entries) {
    output = output
        .replaceAll('"${entry.key}"', '"${entry.value}"')
        .replaceAll('“${entry.key}”', '“${entry.value}”')
        .replaceAll('「${entry.key}」', '「${entry.value}」')
        .replaceAll(entry.key, entry.value);
  }
  return output;
}

class _LongTermPatternStrip extends StatelessWidget {
  final int totalCount;
  final MemorySummaryModel summary;

  const _LongTermPatternStrip({
    required this.totalCount,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    return AuroraCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Long-term patterns',
                    zhHans: '长期模式',
                    zhHant: '長期模式',
                    ja: '長期パターン',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 0,
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => _showJourneyHint(
                    context,
                    AppLocaleText.tr(
                      context,
                      en: 'The available long-term patterns are shown in this card for now.',
                      zhHans: '目前可用的长期模式已显示在这张卡里。',
                      zhHant: '目前可用的長期模式已顯示在這張卡裡。',
                      ja: '現在利用できる長期パターンは、このカードに表示しています。',
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
                              en: 'View all',
                              zhHans: '查看全部',
                              zhHant: '查看全部',
                              ja: 'すべて見る',
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
                child: _PatternMini(
                  color: AuroraColors.purple,
                  icon: Icons.repeat_rounded,
                  title: AppLocaleText.tr(
                    context,
                    en: 'Repeated',
                    zhHans: '重复模式',
                    zhHant: '重複模式',
                    ja: '反復',
                  ),
                  body: _patternText(
                    context,
                    summary.repeatedPatterns,
                    fallback: AppLocaleText.tr(
                      context,
                      en: 'Repeated signals',
                      zhHans: '重复线索',
                      zhHant: '重複線索',
                      ja: '反復シグナル',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PatternMini(
                  color: AuroraColors.orange,
                  icon: Icons.timeline_rounded,
                  title: AppLocaleText.tr(
                    context,
                    en: 'Stable',
                    zhHans: '稳定模式',
                    zhHant: '穩定模式',
                    ja: '安定',
                  ),
                  body: _patternText(
                    context,
                    summary.stableModes,
                    fallback: AppLocaleText.tr(
                      context,
                      en: 'Stable mode forming',
                      zhHans: '稳定模式形成中',
                      zhHant: '穩定模式形成中',
                      ja: '安定モード形成中',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PatternMini(
                  color: AuroraColors.blue,
                  icon: Icons.trending_up_rounded,
                  title: AppLocaleText.tr(
                    context,
                    en: 'Shifting',
                    zhHans: '变化模式',
                    zhHant: '變化模式',
                    ja: '変化',
                  ),
                  body: AppLocaleText.tr(
                    context,
                    en: '$totalCount signals settling',
                    zhHans: '$totalCount 条长期线索',
                    zhHant: '$totalCount 條長期線索',
                    ja: '$totalCount 件のシグナル',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _patternText(
    BuildContext context,
    List<JourneySignalItemModel> items, {
    required String fallback,
  }) {
    if (items.isEmpty) return fallback;
    final name = items.first.name.trim();
    if (name.isNotEmpty) return name;
    final summary = items.first.summary.trim();
    if (summary.isEmpty) return fallback;
    final first = summary.split(RegExp(r'[。.!！\n]')).first.trim();
    return first.isEmpty ? fallback : first;
  }
}

class _PatternMini extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String body;

  const _PatternMini({
    required this.color,
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuroraSoftIconCircle(
            icon: icon,
            color: color,
            size: 44,
            iconSize: 22,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: color,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _JourneyReadyBody extends StatelessWidget {
  final MemoryViewModel vm;

  const _JourneyReadyBody({required this.vm});

  @override
  Widget build(BuildContext context) {
    final summary = vm.summary;

    if (summary == null || !summary.hasAnySignals) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 116),
        children: [
          EmptyStateBlock(
            icon: Icons.timeline_outlined,
            title: AppLocaleText.tr(
              context,
              en: 'No long-term signals yet',
              zhHans: '生活地图正在形成',
              zhHant: '生活地圖正在形成',
              ja: '生活の旅路が形になり始めています',
            ),
            subtitle: AppLocaleText.tr(
              context,
              en: 'Leave one sentence in Today first. Tomorrow, this page can begin showing the first light path.',
              zhHans: '先留下几条信号，第一段生活路径会慢慢出现在这里。',
              zhHant: '先留下幾條信號，第一段生活路徑會慢慢出現在這裡。',
              ja: 'まずいくつかのシグナルを残すと、最初の生活の道すじが少しずつここに現れます。',
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
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 116),
      children: [
        _JourneyTop(summary: summary),
        const SizedBox(height: 14),
        _LongTermPatternStrip(totalCount: totalCount, summary: summary),
        const SizedBox(height: 14),
        _JourneyStructurePathCard(summary: summary),
        const SizedBox(height: 14),
        _JourneyHeatmapLite(
          summary: summary,
          weakCount: weakSignals.length,
          repeatedCount: repeatedPatterns.length,
          stableCount: stableModes.length,
        ),
        const SizedBox(height: 14),
        _ExperimentTracksCard(summary: summary),
        const SizedBox(height: 14),
        _JourneyActionLoopCard(summary: summary),
        const SizedBox(height: 14),
        _JourneyBottomInsightCard(summary: summary),
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
            en: 'your recent records',
            zhHans: '最近的记录',
            zhHant: '最近的記錄',
            ja: '最近の記録');
    }
  }
}

class _JourneyStructurePathCard extends StatelessWidget {
  final MemorySummaryModel summary;

  const _JourneyStructurePathCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final nodes = _structureNodes(context, summary);
    return AuroraCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Life structure path',
                    zhHans: '生活结构路径',
                    zhHant: '生活結構路徑',
                    ja: '生活構造の道すじ',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 0,
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => _showJourneyHint(
                    context,
                    AppLocaleText.tr(
                      context,
                      en: 'The current life structure path is shown here.',
                      zhHans: '当前的生活结构路径已显示在这里。',
                      zhHant: '目前的生活結構路徑已顯示在這裡。',
                      ja: '現在の生活構造の道すじはここに表示しています。',
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
                              en: 'View all',
                              zhHans: '查看全部',
                              zhHant: '查看全部',
                              ja: 'すべて見る',
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
          const SizedBox(height: 18),
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
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
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
                      color: AuroraColors.muted.withValues(alpha: 0.58),
                    ),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  List<_JourneyPathNode> _structureNodes(
    BuildContext context,
    MemorySummaryModel summary,
  ) {
    final items = [
      summary.mainFriction,
      summary.longTermPattern,
      summary.recoverySignal,
      summary.experimentFeedback,
      summary.nextAdjustmentDirection,
    ];
    final fallbackLabels = [
      AppLocaleText.tr(context,
          en: 'Main friction', zhHans: '主要摩擦', zhHant: '主要摩擦', ja: '主な摩擦'),
      AppLocaleText.tr(context,
          en: 'Repeated pattern', zhHans: '重复模式', zhHant: '重複模式', ja: '反復パターン'),
      AppLocaleText.tr(context,
          en: 'Recovery clue', zhHans: '恢复线索', zhHant: '恢復線索', ja: '回復の手がかり'),
      AppLocaleText.tr(context,
          en: 'Experiment feedback',
          zhHans: '实验反馈',
          zhHant: '實驗回饋',
          ja: '試みの反応'),
      AppLocaleText.tr(context,
          en: 'Next adjustment', zhHans: '下次调整', zhHant: '下次調整', ja: '次の調整'),
    ];
    const icons = [
      Icons.battery_alert_outlined,
      Icons.repeat_rounded,
      Icons.nights_stay_rounded,
      Icons.science_outlined,
      Icons.wb_twilight_rounded,
    ];
    const colors = [
      AuroraColors.orange,
      AuroraColors.purple,
      AuroraColors.blue,
      AuroraColors.mint,
      AuroraColors.gold,
    ];
    return [
      for (var i = 0; i < fallbackLabels.length; i++)
        _JourneyPathNode(
          label: _fallbackIfEmpty(
            _compactLabel(items[i]?.name ?? items[i]?.summary ?? ''),
            fallbackLabels[i],
          ),
          icon: icons[i],
          color: colors[i],
        ),
    ];
  }

  String _compactLabel(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    final first = trimmed.split(RegExp(r'[：:，,。.!！\n]')).first.trim();
    final source = first.isEmpty ? trimmed : first;
    if (source.runes.length <= 8) return source;
    return String.fromCharCodes(source.runes.take(8));
  }

  String _fallbackIfEmpty(String value, String fallback) {
    return value.trim().isEmpty ? fallback : value;
  }
}

class _JourneyPathNode {
  final String label;
  final IconData icon;
  final Color color;

  const _JourneyPathNode({
    required this.label,
    required this.icon,
    required this.color,
  });
}

class _ExperimentTracksCard extends StatelessWidget {
  final MemorySummaryModel summary;

  const _ExperimentTracksCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final items = _trackItems(context);
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
                  en: 'Experiment tracks',
                  zhHans: '实验轨迹',
                  zhHant: '實驗軌跡',
                  ja: '試みの軌跡',
                ),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
              ),
              const Spacer(),
              Text(
                summary.experiments.isNotEmpty
                    ? AppLocaleText.tr(
                        context,
                        en: '${summary.experiments.length} item(s)',
                        zhHans: '共 ${summary.experiments.length} 个',
                        zhHant: '共 ${summary.experiments.length} 個',
                        ja: '${summary.experiments.length}件',
                      )
                    : AppLocaleText.tr(
                        context,
                        en: 'Forming',
                        zhHans: '形成中',
                        zhHant: '形成中',
                        ja: '形成中',
                      ),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AuroraColors.muted,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            Text(
              AppLocaleText.tr(
                context,
                en: 'Experiment feedback will appear here after you save or try one small experiment.',
                zhHans: '保存或尝试一个小实验后，反馈会出现在这里。',
                zhHant: '保存或嘗試一個小實驗後，回饋會出現在這裡。',
                ja: '小さな試みを保存したり試したりすると、ここに反応が表示されます。',
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AuroraColors.muted,
                  ),
            )
          else if (items.length == 1)
            _ExperimentTrackTile(
              icon: items.first.icon,
              title: items.first.title,
              status: items.first.status,
              color: items.first.color,
              isCompact: true,
            )
          else
            GridView.count(
              crossAxisCount: items.length < 3 ? items.length : 4,
              crossAxisSpacing: 9,
              mainAxisSpacing: 9,
              childAspectRatio: 0.98,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final item in items)
                  _ExperimentTrackTile(
                    icon: item.icon,
                    title: item.title,
                    status: item.status,
                    color: item.color,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  List<_ExperimentTrackData> _trackItems(BuildContext context) {
    return summary.experiments.take(4).map((item) {
      final color = switch (item.signalLevel) {
        'stable_mode' => AuroraColors.mint,
        'repeated_pattern' => AuroraColors.orange,
        _ => AuroraColors.purple,
      };
      return _ExperimentTrackData(
        icon: Icons.science_outlined,
        title: _compactTrackTitle(item.name),
        status: _trackStatus(context, item.signalLevel),
        color: color,
      );
    }).toList();
  }

  String _compactTrackTitle(String value) {
    final text = value.trim();
    if (text.isEmpty) return 'Experiment';
    if (text.runes.length <= 8) return text;
    return String.fromCharCodes(text.runes.take(8));
  }

  String _trackStatus(BuildContext context, String level) {
    switch (level) {
      case 'stable_mode':
        return AppLocaleText.tr(
          context,
          en: 'Helpful',
          zhHans: '有效',
          zhHant: '有效',
          ja: '有効',
        );
      case 'repeated_pattern':
        return AppLocaleText.tr(
          context,
          en: 'Learning',
          zhHans: '学习中',
          zhHant: '學習中',
          ja: '学び中',
        );
      default:
        return AppLocaleText.tr(
          context,
          en: 'Unsteady',
          zhHans: '未稳定',
          zhHant: '未穩定',
          ja: 'まだ不安定',
        );
    }
  }
}

class _ExperimentTrackData {
  final IconData icon;
  final String title;
  final String status;
  final Color color;

  const _ExperimentTrackData({
    required this.icon,
    required this.title,
    required this.status,
    required this.color,
  });
}

class _ExperimentTrackTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String status;
  final Color color;
  final bool isCompact;

  const _ExperimentTrackTile({
    required this.icon,
    required this.title,
    required this.status,
    required this.color,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.055),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.16)),
        ),
        child: Row(
          children: [
            AuroraSoftIconCircle(
              icon: icon,
              color: color,
              size: 40,
              iconSize: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AuroraColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 5),
                  SizedBox(
                    height: 18,
                    child: AuroraSparkline(color: color),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            AuroraChip(label: status, color: color),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(9, 10, 9, 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuroraSoftIconCircle(
            icon: icon,
            color: color,
            size: 34,
            iconSize: 18,
          ),
          const Spacer(),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AuroraColors.ink,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 18,
            width: double.infinity,
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: AuroraSparkline(color: color),
            ),
          ),
          AuroraChip(label: status, color: color),
        ],
      ),
    );
  }
}

class _JourneyActionLoopCard extends StatelessWidget {
  final MemorySummaryModel summary;

  const _JourneyActionLoopCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final confirmedCount =
        summary.repeatedPatterns.length + summary.stableModes.length;
    final triedCount = summary.experiments.length;
    final helpfulCount = summary.experiments
        .where((item) => item.signalLevel == 'stable_mode')
        .length;
    final feedback = summary.experimentFeedback?.summary.trim() ?? '';
    final next = summary.nextAdjustmentDirection.summary.trim();
    final loopText = feedback.isNotEmpty
        ? feedback
        : next.isNotEmpty
            ? next
            : AppLocaleText.tr(
                context,
                en: 'Saved actions and feedback will slowly show which small designs fit your life.',
                zhHans: '保存的小行动和反馈会慢慢看出，哪些生活设计更适合你。',
                zhHant: '保存的小行動和回饋會慢慢看出，哪些生活設計更適合你。',
                ja: '保存した小さな行動と反応から、どんな生活設計が合うかが少しずつ見えてきます。',
              );

    return AuroraCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AuroraSoftIconCircle(
                icon: Icons.loop_rounded,
                color: AuroraColors.purple,
                size: 34,
                iconSize: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Action fit pattern',
                    zhHans: '行动适配模式',
                    zhHant: '行動適配模式',
                    ja: '行動の合いやすさ',
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _JourneyLoopMetric(
                  label: AppLocaleText.tr(
                    context,
                    en: 'Confirmed',
                    zhHans: '已确认',
                    zhHant: '已確認',
                    ja: '確認済み',
                  ),
                  value: confirmedCount,
                  color: AuroraColors.purple,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _JourneyLoopMetric(
                  label: AppLocaleText.tr(
                    context,
                    en: 'Tried',
                    zhHans: '尝试过',
                    zhHant: '嘗試過',
                    ja: '試した',
                  ),
                  value: triedCount,
                  color: AuroraColors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _JourneyLoopMetric(
                  label: AppLocaleText.tr(
                    context,
                    en: 'Helpful',
                    zhHans: '有帮助',
                    zhHant: '有幫助',
                    ja: '助けになる',
                  ),
                  value: helpfulCount,
                  color: AuroraColors.mint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AuroraColors.purple.withValues(alpha: 0.055),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AuroraColors.purple.withValues(alpha: 0.12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Long-term loop trace',
                    zhHans: '长期闭环轨迹',
                    zhHant: '長期閉環軌跡',
                    ja: '長期の循環メモ',
                  ),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AuroraColors.purple,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  loopText,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AuroraColors.ink,
                        height: 1.45,
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

class _JourneyLoopMetric extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _JourneyLoopMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.065),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Column(
        children: [
          Text(
            value.toString(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AuroraColors.muted,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _JourneyBottomInsightCard extends StatelessWidget {
  final MemorySummaryModel summary;

  const _JourneyBottomInsightCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final text = summary.nextAdjustmentDirection.summary.trim();
    return AuroraQuoteCard(
      minHeight: 76,
      landscape: true,
      text: text.isEmpty
          ? AppLocaleText.tr(
              context,
              en: 'For now, keep one small adjustment visible rather than forcing a big change.',
              zhHans: '现在先保留一个小调整方向，不需要强行大改。',
              zhHant: '現在先保留一個小調整方向，不需要強行大改。',
              ja: '今は大きく変えるより、小さな調整を一つ見える場所に置いておきます。',
            )
          : text,
    );
  }
}

class _JourneyHeatmapLite extends StatelessWidget {
  final MemorySummaryModel summary;
  final int weakCount;
  final int repeatedCount;
  final int stableCount;

  const _JourneyHeatmapLite({
    required this.summary,
    required this.weakCount,
    required this.repeatedCount,
    required this.stableCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final frictionStatus = _statusFromItem(
      summary.mainFriction,
      fallback: repeatedCount > 0
          ? AppLocaleText.tr(context,
              en: 'Pressured', zhHans: '有压力', zhHant: '有壓力', ja: '圧あり')
          : AppLocaleText.tr(context,
              en: 'Forming', zhHans: '形成中', zhHant: '形成中', ja: '形成中'),
    );
    final recoveryStatus = _statusFromItem(
      summary.recoverySignal,
      fallback: stableCount > 0
          ? AppLocaleText.tr(context,
              en: 'Visible', zhHans: '可见', zhHant: '可見', ja: '見える')
          : AppLocaleText.tr(context,
              en: 'Low', zhHans: '不足', zhHant: '不足', ja: '少なめ'),
    );
    final patternStatus = _statusFromItem(
      summary.longTermPattern,
      fallback: stableCount > 0
          ? AppLocaleText.tr(context,
              en: 'Stable', zhHans: '稳定', zhHant: '穩定', ja: '安定')
          : AppLocaleText.tr(context,
              en: 'Early', zhHans: '早期', zhHant: '早期', ja: '初期'),
    );
    final experimentStatus = _statusFromItem(
      summary.experimentFeedback,
      fallback: summary.experiments.isEmpty
          ? AppLocaleText.tr(context,
              en: 'Not yet', zhHans: '暂未出现', zhHant: '暫未出現', ja: 'まだ')
          : AppLocaleText.tr(context,
              en: 'Learning', zhHans: '学习中', zhHant: '學習中', ja: '学び中'),
    );
    final monthly = summary.monthlyReview;
    final monthlyRepeated = _firstMonthlyText(
      monthly?.repeatedThemes,
      fallback: frictionStatus,
    );
    final monthlyImproving = _firstMonthlyText(
      monthly?.improvingSignals,
      fallback: recoveryStatus,
    );
    final monthlyUnresolved = _firstMonthlyText(
      monthly?.unresolvedPoints,
      fallback: patternStatus,
    );
    final monthlyWatch = _shortStatus(
      monthly?.nextMonthWatch,
      fallback: experimentStatus,
    );
    final areas = [
      (
        Icons.work_outline_rounded,
        AppLocaleText.tr(context,
            en: 'Work / responsibility',
            zhHans: '工作 / 责任',
            zhHant: '工作 / 責任',
            ja: '仕事 / 責任'),
        monthlyRepeated,
        AuroraColors.orange,
      ),
      (
        Icons.track_changes_rounded,
        AppLocaleText.tr(context,
            en: 'Attention', zhHans: '注意力', zhHant: '注意力', ja: '注意'),
        monthlyUnresolved,
        AuroraColors.gold,
      ),
      (
        Icons.nights_stay_rounded,
        AppLocaleText.tr(context,
            en: 'Recovery', zhHans: '恢复', zhHant: '恢復', ja: '回復'),
        monthlyImproving,
        AuroraColors.blue,
      ),
      (
        Icons.groups_rounded,
        AppLocaleText.tr(context,
            en: 'Relationships',
            zhHans: '关系 / 边界',
            zhHant: '關係 / 邊界',
            ja: '関係 / 境界'),
        monthlyRepeated,
        AuroraColors.purple,
      ),
      (
        Icons.favorite_rounded,
        AppLocaleText.tr(context,
            en: 'Body', zhHans: '身体', zhHant: '身體', ja: '身体'),
        monthlyImproving,
        AuroraColors.mint,
      ),
      (
        Icons.near_me_rounded,
        AppLocaleText.tr(context,
            en: 'Freedom', zhHans: '自由感', zhHant: '自由感', ja: '自由感'),
        monthlyWatch,
        AuroraColors.blue,
      ),
    ];

    return _UnifiedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocaleText.tr(
              context,
              en: 'Monthly life map',
              zhHans: '轻量生活地图',
              zhHant: '輕量生活地圖',
              ja: '月の生活の旅路',
            ),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocaleText.tr(
              context,
              en: 'A map of where signals are gathering. It is not a score.',
              zhHans: monthly == null
                  ? '简单看一下信号正在聚到哪里。它是地图，不是评分。'
                  : '来自同一份月度快照：看信号聚到哪里，不是评分。',
              zhHant: '簡單看一下信號正在聚到哪裡。它是地圖，不是評分。',
              ja: 'シグナルがどこに集まっているかを軽く見る地図です。点数ではありません。',
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AuroraColors.muted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.65,
            children: [
              for (final area in areas)
                _LifeMapAreaCard(
                  icon: area.$1,
                  title: area.$2,
                  status: area.$3,
                  color: area.$4,
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _firstMonthlyText(
    List<String>? items, {
    required String fallback,
  }) {
    if (items == null || items.isEmpty) return fallback;
    return _shortStatus(items.first, fallback: fallback);
  }

  String _shortStatus(String? value, {required String fallback}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return fallback;
    final first = trimmed.split(RegExp(r'[，。,.、：:]')).first.trim();
    if (first.isEmpty) return fallback;
    final runes = first.runes.toList();
    if (runes.length <= 8) return first;
    return String.fromCharCodes(runes.take(8));
  }

  String _statusFromItem(
    JourneySignalItemModel? item, {
    required String fallback,
  }) {
    final name = item?.name.trim();
    if (name != null && name.isNotEmpty) {
      if (name.runes.length <= 5) return name;
      return String.fromCharCodes(name.runes.take(5));
    }
    return fallback;
  }
}

class _LifeMapAreaCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String status;
  final Color color;

  const _LifeMapAreaCard({
    required this.icon,
    required this.title,
    required this.status,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 0.68),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          AuroraSoftIconCircle(
              icon: icon, color: color, size: 36, iconSize: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AuroraColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                AuroraChip(label: status, color: color),
              ],
            ),
          ),
        ],
      ),
    );
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

class _ReviewAdjustSection extends StatelessWidget {
  final MemorySummaryModel summary;

  const _ReviewAdjustSection({required this.summary});

  @override
  Widget build(BuildContext context) {
    return _UnifiedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocaleText.tr(
              context,
              en: 'This period, start here',
              zhHans: '这段时间，可以先这样看',
              zhHant: '這段時間，可以先這樣看',
              ja: 'この期間は、まずこう見てみる',
            ),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            AppLocaleText.tr(
              context,
              en: 'A light review of one pattern, one source of friction, one recovery clue, and what the latest experiment taught you.',
              zhHans: '先轻轻回看一个模式、一个消耗来源、一个恢复线索，以及最近一次实验留下的反馈。',
              zhHant: '先輕輕回看一個模式、一個消耗來源、一個恢復線索，以及最近一次實驗留下的回饋。',
              ja: 'ひとつの pattern、ひとつの friction、ひとつの回復の手がかり、そして直近の実験から見えたことを軽く振り返ります。',
            ),
          ),
          const SizedBox(height: 14),
          _ReviewAdjustTile(
            icon: Icons.repeat_rounded,
            title: AppLocaleText.tr(
              context,
              en: 'One pattern',
              zhHans: '一个反复出现的生活模式',
              zhHant: '一個反覆出現的生活模式',
              ja: 'ひとつの pattern',
            ),
            item: summary.longTermPattern,
            fallback: AppLocaleText.tr(
              context,
              en: 'There is no clear repeated pattern yet. Keeping the notes is enough for now.',
              zhHans: '暂时还没有清楚重复起来的模式。现在先把记录留下来就够了。',
              zhHant: '暫時還沒有清楚重複起來的模式。現在先把記錄留下來就夠了。',
              ja: 'まだはっきり繰り返す pattern はありません。今は記録が残っていれば十分です。',
            ),
          ),
          _ReviewAdjustTile(
            icon: Icons.bolt_outlined,
            title: AppLocaleText.tr(
              context,
              en: 'One friction source',
              zhHans: '一个主要消耗来源',
              zhHant: '一個主要消耗來源',
              ja: 'ひとつの friction',
            ),
            item: summary.mainFriction,
            fallback: AppLocaleText.tr(
              context,
              en: 'No single friction source is standing out yet.',
              zhHans: '暂时还没有特别突出的单一消耗来源。',
              zhHant: '暫時還沒有特別突出的單一消耗來源。',
              ja: '今はまだ、ひとつだけ目立つ friction はありません。',
            ),
          ),
          _ReviewAdjustTile(
            icon: Icons.spa_outlined,
            title: AppLocaleText.tr(
              context,
              en: 'One recovery clue',
              zhHans: '一个恢复线索',
              zhHant: '一個恢復線索',
              ja: 'ひとつの回復の手がかり',
            ),
            item: summary.recoverySignal,
            fallback: AppLocaleText.tr(
              context,
              en: 'A recovery clue has not surfaced clearly yet.',
              zhHans: '恢复线索还没有很清楚地浮出来。',
              zhHant: '恢復線索還沒有很清楚地浮出來。',
              ja: '回復の手がかりは、まだはっきり見えていません。',
            ),
          ),
          _ReviewAdjustTile(
            icon: Icons.tune_rounded,
            title: AppLocaleText.tr(
              context,
              en: 'Experiment feedback',
              zhHans: '一次实验反馈',
              zhHant: '一次實驗回饋',
              ja: '実験からのフィードバック',
            ),
            item: summary.experimentFeedback,
            fallback: AppLocaleText.tr(
              context,
              en: 'No experiment feedback yet. That does not block Journey.',
              zhHans: '暂时还没有实验反馈，这不会影响 Journey 继续回看。',
              zhHant: '暫時還沒有實驗回饋，這不會影響 Journey 繼續回看。',
              ja: 'まだ実験のフィードバックはありません。Journey の振り返りには影響しません。',
            ),
          ),
          _ReviewAdjustTile(
            icon: Icons.arrow_forward_rounded,
            title: AppLocaleText.tr(
              context,
              en: 'Next gentle adjustment',
              zhHans: '下次温和调整方向',
              zhHant: '下次溫和調整方向',
              ja: '次の小さな調整',
            ),
            item: summary.nextAdjustmentDirection,
            fallback: '',
          ),
        ],
      ),
    );
  }
}

class _ReviewAdjustTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final JourneySignalItemModel? item;
  final String fallback;

  const _ReviewAdjustTile({
    required this.icon,
    required this.title,
    required this.item,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final text =
        item?.summary.trim().isNotEmpty == true ? item!.summary : fallback;
    final name = item?.name.trim();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (name != null && name.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(text),
              ],
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
          ja: '弱いシグナル',
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
