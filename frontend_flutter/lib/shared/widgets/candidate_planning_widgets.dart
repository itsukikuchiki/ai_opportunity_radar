import 'package:flutter/material.dart';

import '../../core/i18n/app_locale_text.dart';
import '../../core/models/candidate_models.dart';
import '../../core/models/energy_budget_models.dart';
import 'aurora_ui.dart';

/// Shared, accessible presentation for the reusable
/// candidate -> adoption -> progress flow.
///
/// The widgets in this file intentionally contain no repository logic. Both
/// the daily MicroAction hub and the weekly LifeExperiment hub use the same
/// visual/state language, while their pages remain responsible for loading and
/// writing the corresponding objects.
class CandidateGateCard extends StatelessWidget {
  final CandidateGateState gate;
  final IconData icon;
  final Color accent;

  const CandidateGateCard({
    super.key,
    required this.gate,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final count =
        gate.eligibleSignalCount.clamp(0, gate.requiredSignalCount).toInt();
    final title = gate.isOpen
        ? AppLocaleText.tr(
            context,
            en: 'Suggestions are ready',
            zhHans: '建议已经准备好',
            zhHant: '建議已經準備好',
            ja: '提案の準備ができました',
          )
        : AppLocaleText.tr(
            context,
            en: 'Suggestions start after 3 signals',
            zhHans: '记录 3 条信号后开始显示',
            zhHant: '記錄 3 條信號後開始顯示',
            ja: '3 件のシグナルから提案を表示します',
          );
    final explanation = gate.isOpen
        ? AppLocaleText.tr(
            context,
            en: 'Only eligible, user-owned signals are used. You can adopt none, one, or several.',
            zhHans: '这里只使用符合条件、属于你的真实信号。你可以不采纳，也可以采纳一个或多个。',
            zhHant: '這裡只使用符合條件、屬於你的真實信號。你可以不採納，也可以採納一個或多個。',
            ja: '条件を満たす本人のシグナルだけを使います。採用しない、1 件、複数件を選べます。',
          )
        : AppLocaleText.tr(
            context,
            en: 'A few real signals help the app avoid over-interpreting one moment. Drafts and unconfirmed AI content do not count.',
            zhHans: '先积累几条真实信号，是为了避免把某一个瞬间过度解读。草稿和未确认的 AI 内容不会计入。',
            zhHant: '先累積幾條真實信號，是為了避免把某一個瞬間過度解讀。草稿和未確認的 AI 內容不會計入。',
            ja: '一つの瞬間を読み込みすぎないよう、複数の実際のシグナルを待ちます。下書きと未確認の AI 内容は数えません。',
          );

    return Semantics(
      container: true,
      label: '$title, $count of ${gate.requiredSignalCount}',
      child: AuroraCard(
        key: const ValueKey('candidate-gate-card'),
        padding: AuroraMainPageSpec.comfortableCardPadding,
        borderRadius: BorderRadius.circular(AuroraMainPageSpec.cardRadiusLarge),
        color: Colors.white.withValues(alpha: 0.72),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, color: accent, size: 23),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AuroraColors.ink,
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$count/${gate.requiredSignalCount}',
                        key: const ValueKey('candidate-gate-count'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: gate.requiredSignalCount == 0
                    ? 1
                    : count / gate.requiredSignalCount,
                backgroundColor: AuroraColors.line.withValues(alpha: 0.58),
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              explanation,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AuroraColors.muted,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class CandidateRefreshBanner extends StatelessWidget {
  final CandidateGenerationState generation;

  const CandidateRefreshBanner({
    super.key,
    required this.generation,
  });

  @override
  Widget build(BuildContext context) {
    final isBusy = generation.status == CandidateGenerationStatus.regenerating;
    final isStale = generation.status == CandidateGenerationStatus.stale;
    final isFailed = generation.status == CandidateGenerationStatus.failed;
    if (!isBusy && !isStale && !isFailed) return const SizedBox.shrink();

    final title = isFailed
        ? AppLocaleText.tr(
            context,
            en: 'Could not update suggestions',
            zhHans: '建议暂时没有更新成功',
            zhHant: '建議暫時沒有更新成功',
            ja: '提案を更新できませんでした',
          )
        : AppLocaleText.tr(
            context,
            en: 'Updating from your latest signals',
            zhHans: '正在根据最新信号更新',
            zhHant: '正在根據最新信號更新',
            ja: '最新のシグナルから更新しています',
          );
    final subtitle = isFailed
        ? AppLocaleText.tr(
            context,
            en: 'Your adopted items are unchanged. Try again when you return.',
            zhHans: '已经采纳的内容不会改变。稍后重新进入时会再次尝试。',
            zhHant: '已經採納的內容不會改變。稍後重新進入時會再次嘗試。',
            ja: '採用済みの内容は変わりません。あとでもう一度試します。',
          )
        : AppLocaleText.tr(
            context,
            en: 'Old choices are temporarily disabled so you do not adopt an outdated suggestion.',
            zhHans: '旧候选会暂时停用，避免误采纳已经过期的建议。新候选会在原位置替换。',
            zhHant: '舊候選會暫時停用，避免誤採納已經過期的建議。新候選會在原位置替換。',
            ja: '古い提案は一時的に選べません。更新後、同じ位置で新しい提案に置き換わります。',
          );

    return Semantics(
      liveRegion: true,
      container: true,
      label: '$title. $subtitle',
      child: Container(
        key: const ValueKey('candidate-refresh-banner'),
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: (isFailed ? AuroraColors.orange : AuroraColors.blue)
              .withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: (isFailed ? AuroraColors.orange : AuroraColors.blue)
                .withValues(alpha: 0.38),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: isBusy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : Icon(
                        isFailed
                            ? Icons.error_outline_rounded
                            : Icons.sync_rounded,
                        color:
                            isFailed ? AuroraColors.orange : AuroraColors.blue,
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
                          color: AuroraColors.ink,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AuroraColors.muted,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
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

class CandidateOptionCard extends StatefulWidget {
  final String id;
  final int rank;
  final String title;
  final String reason;
  final String? secondaryText;
  final String difficultyLabel;
  final int evidenceCount;
  final bool selected;
  final bool adopted;
  final bool disabled;
  final bool sourceChanged;
  final EnergyCapacityBand energyCapacityBand;
  final String energyAdaptationExplanation;
  final ValueChanged<bool>? onSelected;
  final VoidCallback? onEdit;

  const CandidateOptionCard({
    super.key,
    required this.id,
    required this.rank,
    required this.title,
    required this.reason,
    required this.difficultyLabel,
    required this.evidenceCount,
    required this.selected,
    required this.adopted,
    required this.disabled,
    required this.sourceChanged,
    this.energyCapacityBand = EnergyCapacityBand.unknown,
    this.energyAdaptationExplanation = '',
    this.secondaryText,
    this.onSelected,
    this.onEdit,
  });

  @override
  State<CandidateOptionCard> createState() => _CandidateOptionCardState();
}

class _CandidateOptionCardState extends State<CandidateOptionCard> {
  bool _showWhy = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.adopted
        ? AuroraColors.mint
        : widget.selected
            ? AuroraColors.purple
            : AuroraColors.blue;
    final stateLabel = widget.adopted
        ? AppLocaleText.tr(
            context,
            en: 'Adopted',
            zhHans: '已采纳',
            zhHant: '已採納',
            ja: '採用済み',
          )
        : widget.selected
            ? AppLocaleText.tr(
                context,
                en: 'Selected',
                zhHans: '已选择',
                zhHant: '已選擇',
                ja: '選択済み',
              )
            : AppLocaleText.tr(
                context,
                en: 'Not selected',
                zhHans: '未选择',
                zhHant: '未選擇',
                ja: '未選択',
              );
    final energyAdaptation = widget.energyAdaptationExplanation.trim().isEmpty
        ? _defaultEnergyAdaptationText(context, widget.energyCapacityBand)
        : widget.energyAdaptationExplanation.trim();

    return Semantics(
      key: ValueKey('candidate-option-${widget.id}'),
      container: true,
      selected: widget.selected,
      enabled: !widget.disabled,
      label:
          '${widget.rank}. ${widget.title}. $stateLabel. ${widget.difficultyLabel}',
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: widget.disabled ? 0.62 : 1,
        child: AuroraCard(
          padding: AuroraMainPageSpec.comfortableCardPadding,
          borderRadius:
              BorderRadius.circular(AuroraMainPageSpec.cardRadiusLarge),
          color: Colors.white.withValues(alpha: 0.74),
          border: Border.all(
            color: widget.selected || widget.adopted
                ? accent.withValues(alpha: 0.74)
                : AuroraColors.line,
            width: widget.selected || widget.adopted ? 1.8 : 1,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${widget.rank}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: AuroraColors.ink,
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                        if (widget.secondaryText?.trim().isNotEmpty ==
                            true) ...[
                          const SizedBox(height: 5),
                          Text(
                            widget.secondaryText!.trim(),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color:
                                      AuroraColors.ink.withValues(alpha: 0.76),
                                  height: 1.4,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (widget.adopted)
                    _StateBadge(
                      icon: Icons.check_circle_rounded,
                      label: stateLabel,
                      color: AuroraColors.mint,
                    )
                  else
                    Semantics(
                      button: true,
                      label: stateLabel,
                      child: Checkbox(
                        value: widget.selected,
                        onChanged: widget.disabled || widget.onSelected == null
                            ? null
                            : (value) {
                                if (value != null) widget.onSelected!(value);
                              },
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (!widget.adopted)
                    _StateBadge(
                      icon: widget.selected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      label: stateLabel,
                      color: widget.selected
                          ? AuroraColors.purple
                          : AuroraColors.muted,
                    ),
                  _StateBadge(
                    icon: Icons.bolt_rounded,
                    label: widget.difficultyLabel,
                    color: AuroraColors.gold,
                  ),
                  _StateBadge(
                    icon: Icons.link_rounded,
                    label: AppLocaleText.tr(
                      context,
                      en: '${widget.evidenceCount} signal sources',
                      zhHans: '${widget.evidenceCount} 条信号依据',
                      zhHant: '${widget.evidenceCount} 條信號依據',
                      ja: '${widget.evidenceCount} 件の根拠',
                    ),
                    color: AuroraColors.blue,
                  ),
                  if (widget.sourceChanged)
                    _StateBadge(
                      icon: Icons.sync_problem_rounded,
                      label: AppLocaleText.tr(
                        context,
                        en: 'Source changed',
                        zhHans: '来源已变化',
                        zhHant: '來源已變化',
                        ja: '根拠が変更',
                      ),
                      color: AuroraColors.orange,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                key: ValueKey('candidate-energy-adaptation-${widget.id}'),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AuroraColors.gold.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AuroraColors.gold.withValues(alpha: 0.24),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.bolt_rounded,
                      size: 18,
                      color: AuroraColors.gold,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        energyAdaptation,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AuroraColors.ink.withValues(alpha: 0.78),
                              height: 1.42,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 44),
                        alignment: Alignment.centerLeft,
                      ),
                      onPressed: () => setState(() => _showWhy = !_showWhy),
                      icon: Icon(
                        _showWhy
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                      ),
                      label: Text(
                        AppLocaleText.tr(
                          context,
                          en: 'Why this suggestion',
                          zhHans: '为什么看到这个',
                          zhHant: '為什麼看到這個',
                          ja: 'この提案の理由',
                        ),
                      ),
                    ),
                  ),
                  if (!widget.adopted && widget.onEdit != null)
                    IconButton(
                      tooltip: AppLocaleText.tr(
                        context,
                        en: 'Edit wording',
                        zhHans: '修改内容',
                        zhHant: '修改內容',
                        ja: '内容を編集',
                      ),
                      constraints: const BoxConstraints.tightFor(
                        width: 44,
                        height: 44,
                      ),
                      onPressed: widget.disabled ? null : widget.onEdit,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                ],
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F2FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    widget.reason.trim().isEmpty
                        ? AppLocaleText.tr(
                            context,
                            en: 'This suggestion uses the eligible signals shown above. It is not a diagnosis.',
                            zhHans: '这条建议只参考上方符合条件的真实信号，不代表诊断或事实判断。',
                            zhHant: '這條建議只參考上方符合條件的真實信號，不代表診斷或事實判斷。',
                            ja: 'この提案は条件を満たすシグナルだけを参照し、診断や事実認定ではありません。',
                          )
                        : widget.reason,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AuroraColors.ink.withValues(alpha: 0.74),
                          height: 1.45,
                        ),
                  ),
                ),
                crossFadeState: _showWhy
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 180),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _defaultEnergyAdaptationText(
    BuildContext context,
    EnergyCapacityBand band,
  ) {
    return switch (band) {
      EnergyCapacityBand.veryLow => AppLocaleText.tr(
          context,
          en: 'Energy fit: kept within 1–3 minutes and easy to pause.',
          zhHans: '能量适配：控制在 1–3 分钟，并且可以随时暂停。',
          zhHant: '能量適配：控制在 1–3 分鐘，並且可以隨時暫停。',
          ja: 'エネルギー調整：1〜3分で、いつでも中断できる案です。',
        ),
      EnergyCapacityBand.low => AppLocaleText.tr(
          context,
          en: 'Energy fit: kept short with fewer switches and more buffer.',
          zhHans: '能量适配：保持短时、少切换，并多留一点缓冲。',
          zhHant: '能量適配：保持短時、少切換，並多留一點緩衝。',
          ja: 'エネルギー調整：短く、切り替えを減らし、余白を残す案です。',
        ),
      EnergyCapacityBand.medium => AppLocaleText.tr(
          context,
          en: 'Energy fit: a normal light option with one clear step.',
          zhHans: '能量适配：采用普通轻量强度，并保持一个清楚步骤。',
          zhHant: '能量適配：採用一般輕量強度，並保持一個清楚步驟。',
          ja: 'エネルギー調整：通常の軽い強度で、一つの手順に絞っています。',
        ),
      EnergyCapacityBand.high => AppLocaleText.tr(
          context,
          en: 'Energy fit: a slightly deeper option, with a light fallback.',
          zhHans: '能量适配：可以稍微深入，同时保留轻量退路。',
          zhHant: '能量適配：可以稍微深入，同時保留輕量退路。',
          ja: 'エネルギー調整：少し深めに試せますが、軽い案も残しています。',
        ),
      EnergyCapacityBand.unknown => AppLocaleText.tr(
          context,
          en: 'Energy fit: evidence is limited, so this stays very light and reversible.',
          zhHans: '能量适配：当前证据有限，因此保持很轻、可逆、没有完成压力。',
          zhHant: '能量適配：目前證據有限，因此保持很輕、可逆、沒有完成壓力。',
          ja: 'エネルギー調整：手がかりが少ないため、軽く戻せる案にしています。',
        ),
    };
  }
}

class SevenDayProgressGrid extends StatelessWidget {
  final SevenDayProgressModel progress;
  final ValueChanged<SevenDayProgressCell>? onCellTap;
  final bool Function(SevenDayProgressCell cell)? isCellEnabled;

  const SevenDayProgressGrid({
    super.key,
    required this.progress,
    this.onCellTap,
    this.isCellEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final cells = progress.cells.take(SevenDayProgressModel.totalDays).toList();
    return Semantics(
      key: ValueKey('seven-day-progress-${progress.subjectId}'),
      container: true,
      label: AppLocaleText.tr(
        context,
        en: '${progress.completedDays} of 7 days completed',
        zhHans: '七天中已完成 ${progress.completedDays} 天',
        zhHant: '七天中已完成 ${progress.completedDays} 天',
        ja: '7 日中 ${progress.completedDays} 日完了',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${progress.completedDays}/7',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AuroraColors.purple,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Tap a day to record progress',
                    zhHans: '点击日期登记实际进度',
                    zhHant: '點擊日期登記實際進度',
                    ja: '日付をタップして進捗を記録',
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AuroraColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var index = 0; index < cells.length; index++) ...[
                  _ProgressCellButton(
                    cell: cells[index],
                    onTap: onCellTap == null ||
                            !(isCellEnabled?.call(cells[index]) ?? true)
                        ? null
                        : () => onCellTap!(cells[index]),
                  ),
                  if (index != cells.length - 1) const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressCellButton extends StatelessWidget {
  final SevenDayProgressCell cell;
  final VoidCallback? onTap;

  const _ProgressCellButton({required this.cell, this.onTap});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(cell.localDate);
    final dayLabel =
        date == null ? cell.localDate : '${date.month}/${date.day}';
    final (icon, color, stateLabel) = switch (cell.state) {
      ProgressCellState.completed => (
          Icons.check_rounded,
          AuroraColors.mint,
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
          AppLocaleText.tr(
            context,
            en: 'recorded, not completed',
            zhHans: '已登记，未完成',
            zhHant: '已登記，未完成',
            ja: '記録済み、未完了',
          ),
        ),
      ProgressCellState.empty => (
          Icons.circle_outlined,
          AuroraColors.muted,
          AppLocaleText.tr(
            context,
            en: 'not recorded',
            zhHans: '未登记',
            zhHant: '未登記',
            ja: '未記録',
          ),
        ),
    };

    return Semantics(
      button: onTap != null,
      label: '$dayLabel, $stateLabel',
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          key: ValueKey('progress-cell-${cell.localDate}'),
          width: 44,
          height: 58,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.48)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 3),
              Text(
                dayLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AuroraColors.ink.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w800,
                      fontSize: 9.5,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StateBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StateBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AuroraColors.ink.withValues(alpha: 0.76),
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}
