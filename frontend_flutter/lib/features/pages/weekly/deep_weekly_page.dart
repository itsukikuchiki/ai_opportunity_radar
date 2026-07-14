import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/di/app_dependencies.dart';
import '../../../core/i18n/app_locale_text.dart';
import '../../../core/models/weekly_models.dart';
import '../../../core/readiness/report_readiness.dart';
import '../../../shared/widgets/aurora_ui.dart';

class WeeklyReflectPage extends StatelessWidget {
  const WeeklyReflectPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          AuroraPage(
            child: SafeArea(
              bottom: false,
              child: FutureBuilder<_WeeklyReflectLoad>(
                future: _load(context),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const _WeeklyReflectLoading();
                  }
                  final result = snapshot.data!;
                  if (!result.readiness.isReady || result.reflect == null) {
                    return _WeeklyReflectUnavailable(
                      readiness: result.readiness,
                    );
                  }
                  final deep = result.reflect!;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                    children: [
                      Row(
                        children: [
                          Text(
                            AppLocaleText.tr(
                              context,
                              en: 'Weekly Deep Review',
                              zhHans: 'Weekly 本周深读',
                              zhHant: 'Weekly 本週深讀',
                              ja: 'Weekly 深掘りレビュー',
                            ),
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  color: AuroraColors.ink,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(width: 10),
                          AuroraChip(
                            label: AppLocaleText.tr(
                              context,
                              en: 'Reflect',
                              zhHans: '深度反思',
                              zhHant: '深度反思',
                              ja: 'Reflect',
                            ),
                          ),
                          const Spacer(),
                          const AuroraChip(
                              label: '3/4', color: AuroraColors.blue),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppLocaleText.tr(
                          context,
                          en: 'A structural reading based on this week’s signals.',
                          zhHans: '基于你本周的信号，做一次更有结构的深读。',
                          zhHant: '基於你本週的信號，做一次更有結構的深讀。',
                          ja: '今週のシグナルから、構造を少し深く読み解きます。',
                        ),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AuroraColors.muted,
                            ),
                      ),
                      const SizedBox(height: 18),
                      _HeroInsightCard(deep: deep),
                      const SizedBox(height: 18),
                      _CoreTopicsCard(deep: deep),
                      const SizedBox(height: 18),
                      _EvidenceAndEnergyGrid(deep: deep),
                      const SizedBox(height: 18),
                      _PatternFlowCard(deep: deep),
                      const SizedBox(height: 18),
                      _ExperimentSuggestionCard(deep: deep),
                      const SizedBox(height: 18),
                      _DeepActionDesignCard(deep: deep),
                      const SizedBox(height: 18),
                      _SectionCard(
                        title: AppLocaleText.tr(
                          context,
                          en: 'Use gently',
                          zhHans: '温和使用',
                          zhHant: '溫和使用',
                          ja: 'やさしく使う',
                        ),
                        body: deep.riskNote,
                        color: AuroraColors.gold,
                        icon: Icons.light_mode_rounded,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const AuroraSafeTopMask(),
        ],
      ),
    );
  }

  Future<_WeeklyReflectLoad> _load(BuildContext context) async {
    final repository = context.read<AppDependencies>().weeklyRepository;
    final weekly = await repository.fetchCurrentWeekly();
    final readiness = weekly.reportReadiness;
    if (!readiness.isReady) {
      return _WeeklyReflectLoad(readiness: readiness);
    }
    return _WeeklyReflectLoad(
      readiness: readiness,
      reflect: await repository.fetchWeeklyReflect(),
    );
  }
}

class _WeeklyReflectLoad {
  final ReportReadiness readiness;
  final WeeklyReflectModel? reflect;

  const _WeeklyReflectLoad({
    required this.readiness,
    this.reflect,
  });
}

class _WeeklyReflectUnavailable extends StatelessWidget {
  final ReportReadiness readiness;

  const _WeeklyReflectUnavailable({required this.readiness});

  @override
  Widget build(BuildContext context) {
    final progressText = AppLocaleText.tr(
      context,
      en: '${readiness.signalCount} / 3 eligible signals this week',
      zhHans: '本周已记录 ${readiness.signalCount} / 3 条有效信号',
      zhHant: '本週已記錄 ${readiness.signalCount} / 3 條有效信號',
      ja: '今週の有効なシグナル ${readiness.signalCount} / 3 件',
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        Text(
          AppLocaleText.tr(
            context,
            en: 'Weekly Deep Review',
            zhHans: 'Weekly 本周深读',
            zhHant: 'Weekly 本週深讀',
            ja: 'Weekly 深掘りレビュー',
          ),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AuroraColors.ink,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 18),
        AuroraCard(
          key: const ValueKey('weekly-reflect-readiness-card'),
          child: Column(
            children: [
              const AuroraSoftIconCircle(
                icon: Icons.auto_graph_rounded,
                color: AuroraColors.purple,
                size: 72,
              ),
              const SizedBox(height: 16),
              Text(
                AppLocaleText.tr(
                  context,
                  en: 'The weekly report is still forming',
                  zhHans: '本周报告还在形成',
                  zhHant: '本週報告還在形成',
                  ja: '今週のレポートはまだ形成中です',
                ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AuroraColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocaleText.tr(
                  context,
                  en: 'Weekly and its same-week deep review start after 3 eligible SignalCards in the current local Monday-Sunday week. Cross-period L3 uses the separate 28-day Pro threshold.',
                  zhHans:
                      '当前本地周一至周日达到 3 条有效 SignalCard 后，Weekly 和本周深读才开始显示。跨周期 L3 使用独立的 28 天 Pro 门槛。',
                  zhHant:
                      '當前本地週一至週日達到 3 條有效 SignalCard 後，Weekly 和本週深讀才開始顯示。跨週期 L3 使用獨立的 28 天 Pro 門檻。',
                  ja: '現在のローカル月曜〜日曜で 3 件になると Weekly 深掘りを表示します。期間比較 L3 には別の 28 日 Pro 条件を使います。',
                ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AuroraColors.muted,
                      height: 1.45,
                    ),
              ),
              const SizedBox(height: 14),
              Text(
                progressText,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AuroraColors.purple,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Semantics(
                label: progressText,
                value: '${(readiness.progress * 100).round()}%',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: readiness.progress,
                    minHeight: 8,
                    color: AuroraColors.purple,
                    backgroundColor:
                        AuroraColors.purple.withValues(alpha: 0.12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeeklyReflectLoading extends StatelessWidget {
  const _WeeklyReflectLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: AuroraCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AuroraSoftIconCircle(
                icon: Icons.auto_graph_rounded,
                color: AuroraColors.purple,
                size: 76,
              ),
              const SizedBox(height: 18),
              Text(
                AppLocaleText.tr(
                  context,
                  en: 'Reading this week one layer deeper...',
                  zhHans: '正在把这一周再往深一层看...',
                  zhHant: '正在把這一週再往深一層看...',
                  ja: '今週をもう一段深く見ています...',
                ),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AuroraColors.ink,
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

class _HeroInsightCard extends StatelessWidget {
  final WeeklyReflectModel deep;

  const _HeroInsightCard({required this.deep});

  @override
  Widget build(BuildContext context) {
    return AuroraCard(
      padding: const EdgeInsets.all(22),
      gradient: const LinearGradient(
        colors: [Color(0xFFFFFFFF), Color(0xFFF2F0FF), Color(0xFFFFFBF4)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Row(
        children: [
          const AuroraLandscapeMedallion(size: 70),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AuroraChip(
                  label: AppLocaleText.tr(
                    context,
                    en: 'This week’s core insight',
                    zhHans: '本周核心洞察',
                    zhHant: '本週核心洞察',
                    ja: '今週の中心',
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  deep.summary,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AuroraColors.ink,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _MiniInsight(
                      icon: Icons.bolt_rounded,
                      label: AppLocaleText.tr(context,
                          en: 'Friction',
                          zhHans: '摩擦源',
                          zhHant: '摩擦源',
                          ja: '摩擦'),
                      value: deep.rootTension,
                      color: AuroraColors.orange,
                    ),
                    const SizedBox(width: 8),
                    _MiniInsight(
                      icon: Icons.trending_up_rounded,
                      label: AppLocaleText.tr(context,
                          en: 'Direction',
                          zhHans: '能量方向',
                          zhHant: '能量方向',
                          ja: '方向'),
                      value: deep.nextFocus,
                      color: AuroraColors.mint,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniInsight extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MiniInsight({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.68),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            AuroraSoftIconCircle(
                icon: icon, color: color, size: 32, iconSize: 17),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.labelSmall),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AuroraColors.ink,
                          fontWeight: FontWeight.w800,
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

class _CoreTopicsCard extends StatelessWidget {
  final WeeklyReflectModel deep;

  const _CoreTopicsCard({required this.deep});

  @override
  Widget build(BuildContext context) {
    final topics = [
      (
        Icons.favorite_border_rounded,
        deep.rootTension,
        '32%',
        AuroraColors.purple
      ),
      (
        Icons.battery_charging_full_rounded,
        deep.hiddenPattern,
        '26%',
        AuroraColors.orange
      ),
      (Icons.science_rounded, deep.nextFocus, '19%', AuroraColors.blue),
      (
        Icons.spa_rounded,
        AppLocaleText.tr(context,
            en: 'Growth and trying',
            zhHans: '成长与尝试',
            zhHant: '成長與嘗試',
            ja: '成長と試み'),
        '8%',
        AuroraColors.gold
      ),
    ];
    return AuroraCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocaleText.tr(context,
                en: 'Core topics', zhHans: '核心主题', zhHant: '核心主題', ja: '中心テーマ'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AuroraColors.ink,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: topics
                  .map(
                    (topic) => Container(
                      width: 130,
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: topic.$4.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(18),
                        border:
                            Border.all(color: topic.$4.withValues(alpha: 0.14)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AuroraSoftIconCircle(
                            icon: topic.$1,
                            color: topic.$4,
                            size: 34,
                            iconSize: 17,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            topic.$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          const SizedBox(height: 6),
                          AuroraChip(label: topic.$3, color: topic.$4),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _EvidenceAndEnergyGrid extends StatelessWidget {
  final WeeklyReflectModel deep;

  const _EvidenceAndEnergyGrid({required this.deep});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _SectionCard(
            title: AppLocaleText.tr(context,
                en: 'Evidence gathered',
                zhHans: '证据聚集',
                zhHant: '證據聚集',
                ja: '集まった証拠'),
            body: deep.keyNodes.isEmpty
                ? AppLocaleText.tr(context,
                    en: 'Signals are still forming.',
                    zhHans: '信号还在形成中。',
                    zhHant: '信號還在形成中。',
                    ja: 'シグナルはまだ形成中です。')
                : deep.keyNodes.take(4).join('\n'),
            color: AuroraColors.mint,
            icon: Icons.fact_check_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AuroraCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  AppLocaleText.tr(context,
                      en: 'Energy structure',
                      zhHans: '能量与摩擦结构',
                      zhHant: '能量與摩擦結構',
                      ja: 'エネルギー構造'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AuroraColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 108,
                  height: 108,
                  child: CustomPaint(painter: _DonutPainter()),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PatternFlowCard extends StatelessWidget {
  final WeeklyReflectModel deep;

  const _PatternFlowCard({required this.deep});

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        Icons.chat_bubble_outline_rounded,
        AppLocaleText.tr(context,
            en: 'Trigger', zhHans: '触发点', zhHant: '觸發點', ja: 'きっかけ')
      ),
      (
        Icons.flash_on_rounded,
        AppLocaleText.tr(context,
            en: 'Reaction', zhHans: '典型反应', zhHant: '典型反應', ja: '反応')
      ),
      (
        Icons.track_changes_rounded,
        AppLocaleText.tr(context,
            en: 'Short result', zhHans: '短期结果', zhHant: '短期結果', ja: '短期結果')
      ),
      (
        Icons.spa_rounded,
        AppLocaleText.tr(context,
            en: 'Long impact', zhHans: '长期影响', zhHant: '長期影響', ja: '長期影響')
      ),
    ];
    return AuroraCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocaleText.tr(context,
                en: 'This week’s pattern breakdown',
                zhHans: '本周模式拆解',
                zhHant: '本週模式拆解',
                ja: '今週のパターン分解'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AuroraColors.ink,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AuroraColors.purple.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        AuroraSoftIconCircle(
                          icon: items[i].$1,
                          color: i.isEven
                              ? AuroraColors.purple
                              : AuroraColors.orange,
                          size: 34,
                          iconSize: 17,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          items[i].$2,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ),
                if (i < items.length - 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.arrow_forward_rounded,
                        color: AuroraColors.muted, size: 18),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ExperimentSuggestionCard extends StatelessWidget {
  final WeeklyReflectModel deep;

  const _ExperimentSuggestionCard({required this.deep});

  @override
  Widget build(BuildContext context) {
    return AuroraCard(
      padding: const EdgeInsets.all(18),
      gradient: const LinearGradient(
        colors: [Color(0xFFFFFFFF), Color(0xFFF8F3FF)],
      ),
      child: Row(
        children: [
          const AuroraSoftIconCircle(
            icon: Icons.science_rounded,
            color: AuroraColors.purple,
            size: 58,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocaleText.tr(context,
                      en: 'Suggested small experiment',
                      zhHans: '建议的小实验',
                      zhHant: '建議的小實驗',
                      ja: 'おすすめの小さな実験'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AuroraColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  deep.nextFocus,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AuroraColors.ink,
                        height: 1.4,
                      ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AuroraColors.muted),
        ],
      ),
    );
  }
}

class _DeepActionDesignCard extends StatelessWidget {
  final WeeklyReflectModel deep;

  const _DeepActionDesignCard({required this.deep});

  @override
  Widget build(BuildContext context) {
    final strategy = deep.rootTension.trim().isEmpty
        ? AppLocaleText.tr(
            context,
            en: 'Look at the repeated loop before changing too much at once.',
            zhHans: '先看反复出现的循环，不急着一次改太多。',
            zhHant: '先看反覆出現的循環，不急著一次改太多。',
            ja: '一度に変えすぎる前に、繰り返している循環を見ます。',
          )
        : deep.rootTension.trim();
    final design = deep.nextFocus.trim().isEmpty
        ? AppLocaleText.tr(
            context,
            en: 'Try one small adjustment next week and keep feedback light.',
            zhHans: '下周只试一个小调整，反馈保持轻一点。',
            zhHant: '下週只試一個小調整，回饋保持輕一點。',
            ja: '来週は小さな調整を一つだけ試し、反応は軽く残します。',
          )
        : deep.nextFocus.trim();

    return AuroraCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      gradient: LinearGradient(
        colors: [
          AuroraColors.purple.withValues(alpha: 0.10),
          Colors.white.withValues(alpha: 0.94),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AuroraSoftIconCircle(
                icon: Icons.architecture_rounded,
                color: AuroraColors.purple,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Deep action design',
                    zhHans: '深度行动设计',
                    zhHant: '深度行動設計',
                    ja: '深い行動デザイン',
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AuroraColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _DeepDesignRow(
            label: 'Strategy',
            title: AppLocaleText.tr(
              context,
              en: 'Why this first',
              zhHans: '为什么先做',
              zhHant: '為什麼先做',
              ja: 'なぜ先に見るか',
            ),
            body: strategy,
            icon: Icons.track_changes_rounded,
            color: AuroraColors.mint,
          ),
          const SizedBox(height: 10),
          _DeepDesignRow(
            label: 'Design',
            title: AppLocaleText.tr(
              context,
              en: 'Next small try',
              zhHans: '下周试试',
              zhHant: '下週試試',
              ja: '次の小さな試み',
            ),
            body: design,
            icon: Icons.edit_rounded,
            color: AuroraColors.orange,
          ),
          const SizedBox(height: 10),
          _DeepDesignRow(
            label: 'Development',
            title: AppLocaleText.tr(
              context,
              en: 'Review signal',
              zhHans: '复盘指标',
              zhHant: '復盤指標',
              ja: 'ふり返りの目印',
            ),
            body: AppLocaleText.tr(
              context,
              en: 'Notice whether evening fatigue softens, recovery starts sooner, or the design needs to be lighter.',
              zhHans: '观察晚间疲惫是否下降、恢复是否更容易开始，或这个设计是否需要调轻。',
              zhHant: '觀察晚間疲憊是否下降、恢復是否更容易開始，或這個設計是否需要調輕。',
              ja: '夜の疲れがやわらぐか、回復が始まりやすくなるか、設計を軽くする必要があるかを見ます。',
            ),
            icon: Icons.insights_rounded,
            color: AuroraColors.blue,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DeepConfirmChip(
                label: AppLocaleText.tr(
                  context,
                  en: 'Looks right',
                  zhHans: '准',
                  zhHant: '準',
                  ja: '合っている',
                ),
              ),
              _DeepConfirmChip(
                label: AppLocaleText.tr(
                  context,
                  en: 'Partly',
                  zhHans: '有一部分准',
                  zhHant: '有一部分準',
                  ja: '一部合っている',
                ),
              ),
              _DeepConfirmChip(
                label: AppLocaleText.tr(
                  context,
                  en: 'Another angle',
                  zhHans: '换个角度',
                  zhHant: '換個角度',
                  ja: '別の角度',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeepDesignRow extends StatelessWidget {
  final String label;
  final String title;
  final String body;
  final IconData icon;
  final Color color;

  const _DeepDesignRow({
    required this.label,
    required this.title,
    required this.body,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.13)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuroraSoftIconCircle(
              icon: icon, color: color, size: 34, iconSize: 18),
          const SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AuroraColors.ink,
                      height: 1.42,
                    ),
                children: [
                  TextSpan(
                    text: '$title：',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(text: body),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeepConfirmChip extends StatelessWidget {
  final String label;

  const _DeepConfirmChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      avatar: const Icon(Icons.check_circle_outline_rounded, size: 18),
      backgroundColor: Colors.white.withValues(alpha: 0.80),
      side: BorderSide(color: AuroraColors.purple.withValues(alpha: 0.18)),
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocaleText.tr(
                context,
                en: 'Saved as a review signal.',
                zhHans: '已记录为下次复盘的参考。',
                zhHant: '已記錄為下次復盤的參考。',
                ja: '次のふり返りの参考として残しました。',
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DonutPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = size.width * 0.16;
    final colors = [
      AuroraColors.purple,
      AuroraColors.mint,
      AuroraColors.gold,
      AuroraColors.orange,
    ];
    var start = -1.57;
    for (final color in colors) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.70);
      canvas.drawArc(rect.deflate(stroke), start, 1.15, false, paint);
      start += 1.35;
    }
    final textPainter = TextPainter(
      text: const TextSpan(
        text: '+18%',
        style: TextStyle(
          color: AuroraColors.mint,
          fontWeight: FontWeight.w800,
          fontSize: 20,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String body;
  final Color color;
  final IconData icon;

  const _SectionCard({
    required this.title,
    required this.body,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return AuroraCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuroraSoftIconCircle(
              icon: icon, color: color, size: 42, iconSize: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AuroraColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  body,
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
