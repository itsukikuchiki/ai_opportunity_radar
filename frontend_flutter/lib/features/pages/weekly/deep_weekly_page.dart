import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/app_router.dart';
import '../../../core/di/app_dependencies.dart';
import '../../../core/i18n/app_locale_text.dart';
import '../../../core/i18n/energy_budget_text.dart';
import '../../../core/models/energy_budget_models.dart';
import '../../../core/models/deepening_observation_models.dart';
import '../../../core/models/weekly_illustration_catalog.dart';
import '../../../core/models/weekly_models.dart';
import '../../../core/local/local_deepening_observation_repository.dart';
import '../../../core/navigation/app_back_navigation.dart';
import '../../../core/notifications/signal_reminder_repository.dart';
import '../../../core/notifications/signal_reminder_rule.dart';
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
                  final deep = _localizedWeeklyReflectCopy(
                    context,
                    result.reflect!,
                  );
                  final weekly = result.weekly!;
                  final patternIllustration =
                      _patternIllustrationForWeekly(deep, weekly);
                  final reviewIllustration =
                      WeeklyReviewIllustrationSelector.select(
                    opportunitySnapshot: weekly.opportunitySnapshot,
                    actionReview: weekly.actionReview.toMap(),
                  );
                  return ListView(
                    key: const ValueKey('weekly-reflect-scroll-view'),
                    padding: AuroraMainPageSpec.scrollPadding(context),
                    children: [
                      _WeeklyReflectHero(
                        showStatus: true,
                        weekly: weekly,
                      ),
                      const SizedBox(height: AuroraMainPageSpec.heroGap),
                      _HeroInsightCard(
                        deep: deep,
                        illustrationAsset: patternIllustration?.asset,
                        illustrationLabel: patternIllustration?.hint,
                      ),
                      const SizedBox(height: AuroraMainPageSpec.sectionGap),
                      _DeepPatternRelationshipCard(
                        deep: deep,
                        weekly: weekly,
                      ),
                      const SizedBox(height: AuroraMainPageSpec.sectionGap),
                      _WeeklyTimingChart(
                        weekly: weekly,
                        timingSummary: _nonEmpty(
                          deep.timingSummary,
                          deep.hiddenPattern,
                        ),
                      ),
                      const SizedBox(height: AuroraMainPageSpec.sectionGap),
                      _DeepWeeklyEnergyCard(
                        weekly: weekly,
                        snapshot: result.energySnapshot,
                      ),
                      const SizedBox(height: AuroraMainPageSpec.sectionGap),
                      _NextValidationCard(
                        deep: deep,
                        weekly: weekly,
                        illustrationAsset: reviewIllustration?.definition.asset,
                        illustrationLabel: reviewIllustration?.definition.hint,
                      ),
                      const SizedBox(height: AuroraMainPageSpec.sectionGap),
                      _AnalysisScopeCard(
                        weekly: weekly,
                        scopeNote: _nonEmpty(
                          deep.scopeNote,
                          deep.riskNote,
                        ),
                      ),
                      const SizedBox(height: AuroraMainPageSpec.sectionGap),
                      if (_hasExplainableReminderWindow(deep.timingSummary))
                        _SignalReminderSuggestionCard(
                          suggestion: deep.timingSummary,
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
    final dependencies = context.read<AppDependencies>();
    final repository = dependencies.weeklyRepository;
    final weekly = await repository.fetchCurrentWeekly();
    final readiness = weekly.reportReadiness;
    if (!readiness.isReady) {
      return _WeeklyReflectLoad(readiness: readiness);
    }
    final reflect = await repository.fetchWeeklyReflect();
    EnergyBudgetSnapshot? energySnapshot;
    try {
      energySnapshot =
          await dependencies.energyBudgetRepository.fetchWeeklySnapshot(
        day: repository.nowLoader(),
        weekly: weekly,
      );
    } catch (_) {
      // Energy is an additive Pro projection. A transient or legacy
      // dependency failure must not hide an otherwise available deep review.
      energySnapshot = null;
    }
    return _WeeklyReflectLoad(
      readiness: readiness,
      reflect: reflect,
      weekly: weekly,
      energySnapshot: energySnapshot,
    );
  }
}

class _WeeklyReflectHero extends StatelessWidget {
  final bool showStatus;
  final WeeklyInsightModel? weekly;

  const _WeeklyReflectHero({required this.showStatus, this.weekly});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 360;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.15;
    return AuroraCard(
      key: const ValueKey('weekly-reflect-hero'),
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
          constraints: BoxConstraints(
            minHeight: largeText ? (showStatus ? 216 : 198) : 188,
          ),
          child: Stack(
            children: [
              Positioned(
                key: const ValueKey('weekly-reflect-review-pattern'),
                right: compact ? -12 : -6,
                top: compact ? -8 : -6,
                width: compact ? 166 : 184,
                height: compact ? 150 : 164,
                child: const IgnorePointer(
                  child: AuroraReviewHeroPattern(),
                ),
              ),
              Positioned(
                left: 4,
                top: 4,
                child: IconButton(
                  key: const ValueKey('weekly-reflect-back'),
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: () => context.popOrGo(AppRoutes.weekly),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  color: AuroraColors.ink,
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 14 : 16,
                  54,
                  compact ? 14 : 16,
                  14,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(right: compact ? 72 : 94),
                      child: AuroraHeroTitle(
                        text: AppLocaleText.tr(
                          context,
                          en: 'This Week’s Deep Analysis',
                          zhHans: '本周深度分析',
                          zhHant: '本週深度分析',
                          ja: '今週の深掘りレビュー',
                        ),
                        fontSize: compact ? 28 : 30,
                        maxLines: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: EdgeInsets.only(right: compact ? 58 : 82),
                      child: Text(
                        AppLocaleText.tr(
                          context,
                          en: 'A structural reading based on this week’s Signals.',
                          zhHans: '基于你本周的 Signal，做一次更有结构的深读。',
                          zhHant: '基於你本週的 Signal，做一次更有結構的深讀。',
                          ja: '今週の Signal から、構造を少し深く読み解きます。',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AuroraColors.ink.withValues(alpha: 0.70),
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),
                    if (showStatus) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          AuroraChip(
                            label: AppLocaleText.tr(
                              context,
                              en: _weekRangeLabel(weekly),
                              zhHans: _weekRangeLabel(weekly),
                              zhHant: _weekRangeLabel(weekly),
                              ja: _weekRangeLabel(weekly),
                            ),
                          ),
                          AuroraChip(
                            label: _weeklyCountLabel(context, weekly),
                            color: AuroraColors.blue,
                          ),
                        ],
                      ),
                    ],
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

class _WeeklyReflectLoad {
  final ReportReadiness readiness;
  final WeeklyReflectModel? reflect;
  final WeeklyInsightModel? weekly;
  final EnergyBudgetSnapshot? energySnapshot;

  const _WeeklyReflectLoad({
    required this.readiness,
    this.reflect,
    this.weekly,
    this.energySnapshot,
  });
}

WeeklyReflectModel _localizedWeeklyReflectCopy(
  BuildContext context,
  WeeklyReflectModel source,
) {
  final replacement = switch (AppLocaleText.resolve(context)) {
    AppLanguage.english => 'Deep Analysis',
    AppLanguage.simplifiedChinese => '深度分析',
    AppLanguage.traditionalChinese => '深度分析',
    AppLanguage.japanese => '詳細分析',
  };
  final tensionLabel = AppLocaleText.tr(
    context,
    en: 'tension',
    zhHans: '内在拉扯',
    zhHant: '內在拉扯',
    ja: '内的な葛藤',
  );
  final internalFieldLabels = <String, String>{
    'root_tension': AppLocaleText.tr(
      context,
      en: 'core tension',
      zhHans: '核心拉扯',
      zhHant: '核心拉扯',
      ja: '核心の葛藤',
    ),
    'hidden_pattern': AppLocaleText.tr(
      context,
      en: 'hidden pattern',
      zhHans: '隐藏模式',
      zhHant: '隱藏模式',
      ja: '隠れたパターン',
    ),
    'next_focus': AppLocaleText.tr(
      context,
      en: 'next focus',
      zhHans: '下一步关注',
      zhHant: '下一步關注',
      ja: '次の注目点',
    ),
  };

  String localize(String value) {
    var result = value
        .replaceAll(
          RegExp(r'\bPro\s*L3(?:\s*Reflect)?\b', caseSensitive: false),
          replacement,
        )
        .replaceAll(
          RegExp(r'\bL3\s*Reflect\b', caseSensitive: false),
          replacement,
        )
        .replaceAll(
          RegExp(r'\bL3\b', caseSensitive: false),
          replacement,
        );
    result = EnergyBudgetText.localizeCopy(context, result);
    for (final entry in internalFieldLabels.entries) {
      result = result.replaceAll(
        RegExp('\\b${entry.key}\\b', caseSensitive: false),
        entry.value,
      );
    }
    return result.replaceAll(
      RegExp(r'\btension\b', caseSensitive: false),
      tensionLabel,
    );
  }

  return WeeklyReflectModel(
    summary: localize(source.summary),
    rootTension: localize(source.rootTension),
    hiddenPattern: localize(source.hiddenPattern),
    nextFocus: localize(source.nextFocus),
    riskNote: localize(source.riskNote),
    keyNodes: source.keyNodes.map(localize).toList(growable: false),
    patternLabel: localize(source.patternLabel),
    frictionLabel: localize(source.frictionLabel),
    impactLabel: localize(source.impactLabel),
    relationshipSummary: localize(source.relationshipSummary),
    timingSummary: localize(source.timingSummary),
    nextQuestion: localize(source.nextQuestion),
    illustrationHint: source.illustrationHint,
    sourceSignalCardIds: source.sourceSignalCardIds,
    scopeNote: localize(source.scopeNote),
  );
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
      key: const ValueKey('weekly-reflect-unavailable-scroll-view'),
      padding: AuroraMainPageSpec.scrollPadding(context),
      children: [
        const _WeeklyReflectHero(showStatus: false),
        const SizedBox(height: AuroraMainPageSpec.heroGap),
        AuroraCard(
          key: const ValueKey('weekly-reflect-readiness-card'),
          padding: AuroraMainPageSpec.comfortableCardPadding,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.86),
              const Color(0xFFF3F0FF).withValues(alpha: 0.76),
              const Color(0xFFFFFAF5).withValues(alpha: 0.76),
            ],
          ),
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
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocaleText.tr(
                  context,
                  en: 'Weekly review and its same-week Deep Analysis start after 3 eligible Signal Cards in the current local Monday-Sunday week. Journey Pro compares natural calendar months; change synthesis appears after at least two months each reach 7 eligible Signals across 3 recording days.',
                  zhHans:
                      '当前本地周一至周日达到 3 条有效 Signal Card 后，每周复盘和本周深度分析才开始显示。旅程 Pro 按自然月比较；至少两个月各达到 7 条有效 Signal、覆盖 3 个记录日后，才显示变化综合。',
                  zhHant:
                      '當前本地週一至週日達到 3 條有效 Signal Card 後，每週復盤和本週深度分析才開始顯示。旅程 Pro 按自然月比較；至少兩個月各達到 7 條有效 Signal、覆蓋 3 個記錄日後，才顯示變化綜合。',
                  ja: '現在のローカル月曜〜日曜で有効な Signal Card が3件になると、週間レビューと今週の詳細分析を表示します。旅程 Pro は暦月単位で比較し、2か月以上で各月Signal 7件・記録日3日を満たすと変化のまとめを表示します。',
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
                      fontWeight: FontWeight.w700,
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
    return ListView(
      padding: AuroraMainPageSpec.scrollPadding(context),
      children: [
        const _WeeklyReflectHero(showStatus: false),
        const SizedBox(height: AuroraMainPageSpec.heroGap),
        AuroraCard(
          padding: AuroraMainPageSpec.comfortableCardPadding,
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
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroInsightCard extends StatelessWidget {
  final WeeklyReflectModel deep;
  final String? illustrationAsset;
  final String? illustrationLabel;

  const _HeroInsightCard({
    required this.deep,
    this.illustrationAsset,
    this.illustrationLabel,
  });

  @override
  Widget build(BuildContext context) {
    return AuroraCard(
      key: const ValueKey('weekly-reflect-insight-card'),
      padding: const EdgeInsets.all(18),
      gradient: const LinearGradient(
        colors: [Color(0xFFFFFFFF), Color(0xFFF2F0FF), Color(0xFFFFFBF4)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (illustrationAsset != null)
                Semantics(
                  key: const ValueKey('weekly-reflect-pattern-illustration'),
                  image: true,
                  label: illustrationLabel,
                  child: ExcludeSemantics(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        illustrationAsset!,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                )
              else
                const AuroraLandscapeMedallion(size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AuroraChip(
                    label: AppLocaleText.tr(
                      context,
                      en: 'This week’s core insight',
                      zhHans: '本周核心洞察',
                      zhHant: '本週核心洞察',
                      ja: '今週の中心',
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _compactAnalysisText(deep.relationshipSummary.isNotEmpty
                ? deep.relationshipSummary
                : deep.summary),
            key: const ValueKey('weekly-reflect-summary'),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AuroraColors.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }
}

class _DeepPatternRelationshipCard extends StatelessWidget {
  final WeeklyReflectModel deep;
  final WeeklyInsightModel weekly;

  const _DeepPatternRelationshipCard({
    required this.deep,
    required this.weekly,
  });

  @override
  Widget build(BuildContext context) {
    final corePattern = weekly.behaviorPatterns.isNotEmpty
        ? weekly.behaviorPatterns.first
        : null;
    final corePatternSourceDate =
        corePattern == null || corePattern.supportDates.isEmpty
            ? null
            : _validDateOrNull(corePattern.supportDates.first);
    final energy = weekly.energyProjection;
    final primaryEnergy = _primaryEnergyState(energy?.totals ?? const {});
    final relationships = [
      (
        AppLocaleText.tr(
          context,
          en: 'Scene & behavior',
          zhHans: '场景与行为',
          zhHant: '場景與行為',
          ja: '場面と行動',
        ),
        corePattern == null
            ? _nonEmpty(deep.patternLabel, _legacyNodeValue(deep, 0))
            : '${corePattern.label}\n${corePattern.summary}',
        Icons.account_tree_rounded,
        AuroraColors.purple,
        corePatternSourceDate,
      ),
      (
        AppLocaleText.tr(
          context,
          en: 'Energy state',
          zhHans: '能量状态',
          zhHant: '能量狀態',
          ja: 'エネルギー状態',
        ),
        primaryEnergy == null
            ? _nonEmpty(deep.frictionLabel, _legacyNodeValue(deep, 1))
            : _deepEnergyStateSummary(context, primaryEnergy, energy),
        Icons.bolt_rounded,
        AuroraColors.blue,
        null,
      ),
      (
        AppLocaleText.tr(
          context,
          en: 'Attempt feedback',
          zhHans: '尝试反馈',
          zhHant: '嘗試回饋',
          ja: '試した結果',
        ),
        _nonEmpty(
          deep.impactLabel,
          AppLocaleText.tr(
            context,
            en: 'Feedback is still forming',
            zhHans: '尝试反馈仍在形成',
            zhHant: '嘗試回饋仍在形成',
            ja: 'フィードバックは形成中',
          ),
        ),
        Icons.fact_check_outlined,
        AuroraColors.mint,
        null,
      ),
    ];
    return AuroraCard(
      key: const ValueKey('weekly-deep-pattern-relationship-card'),
      padding: AuroraMainPageSpec.comfortableCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AuroraSectionIcon(
                icon: Icons.hub_rounded,
                size: 30,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  AppLocaleText.tr(context,
                      en: 'This week’s relationship map',
                      zhHans: '本周关系图',
                      zhHant: '本週關係圖',
                      ja: '今週の関係図'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AuroraColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            AppLocaleText.tr(
              context,
              en: 'Connections mean these items appeared in the same weekly range, not that one caused another.',
              zhHans: '连接表示它们在本周同一范围内共同出现，不代表因果。',
              zhHant: '連接表示它們在本週同一範圍內共同出現，不代表因果。',
              ja: 'つながりは同じ週の範囲で一緒に現れたことを示し、因果関係ではありません。',
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AuroraColors.muted,
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final tiles = relationships.indexed
                  .map(
                    (entry) => _DeepRelationshipTile(
                      key: ValueKey(
                        'weekly-reflect-relationship-${entry.$1}',
                      ),
                      label: entry.$2.$1,
                      body: entry.$2.$2,
                      icon: entry.$2.$3,
                      color: entry.$2.$4,
                      sourceDate: entry.$2.$5,
                      onOpenSource: entry.$2.$5 == null
                          ? null
                          : () => context.push(
                                _todayDiaryLocation(entry.$2.$5!),
                              ),
                    ),
                  )
                  .toList(growable: false);
              if (constraints.maxWidth < 520 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.15) {
                return Column(
                  children: [
                    for (var index = 0; index < tiles.length; index++) ...[
                      tiles[index],
                      if (index < tiles.length - 1)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 2),
                          child: Icon(
                            Icons.more_vert_rounded,
                            color: AuroraColors.muted,
                          ),
                        ),
                    ],
                  ],
                );
              }
              return Row(
                children: tiles.indexed
                    .expand(
                      (entry) => [
                        Expanded(child: entry.$2),
                        if (entry.$1 < tiles.length - 1)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              Icons.more_horiz_rounded,
                              color: AuroraColors.muted,
                            ),
                          ),
                      ],
                    )
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }

  String? _primaryEnergyState(Map<String, int> totals) {
    if (totals.isEmpty) return null;
    final entries = totals.entries.where((entry) => entry.value > 0).toList();
    if (entries.isEmpty) return null;
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries.first.key;
  }

  String _deepEnergyStateSummary(
    BuildContext context,
    String state,
    WeeklyEnergyProjectionModel? projection,
  ) {
    final label = switch (state) {
      'draining' => AppLocaleText.tr(context,
          en: 'Draining', zhHans: '偏耗力', zhHant: '偏耗力', ja: 'やや消耗'),
      'ease' => AppLocaleText.tr(context,
          en: 'At ease', zhHans: '有余力', zhHant: '有餘力', ja: '余力あり'),
      'recovery' => AppLocaleText.tr(context,
          en: 'Recovery', zhHans: '恢复', zhHant: '恢復', ja: '回復'),
      'boundary_buffer' => AppLocaleText.tr(context,
          en: 'Boundary & room', zhHans: '边界与余地', zhHant: '邊界與餘地', ja: '境界と余白'),
      _ => AppLocaleText.tr(context,
          en: 'Steady', zhHans: '平稳', zhHant: '平穩', ja: '安定'),
    };
    final count = projection?.totals[state] ?? 0;
    return AppLocaleText.tr(
      context,
      en: '$label appeared in $count Signals this week.',
      zhHans: '本周有 $count 条 Signal 属于“$label”。',
      zhHant: '本週有 $count 條 Signal 屬於「$label」。',
      ja: '今週は $count 件の Signal が「$label」でした。',
    );
  }
}

class _DeepRelationshipTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final String body;
  final Color color;
  final DateTime? sourceDate;
  final VoidCallback? onOpenSource;

  const _DeepRelationshipTile({
    super.key,
    required this.label,
    required this.icon,
    required this.body,
    required this.color,
    this.sourceDate,
    this.onOpenSource,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuroraSoftIconCircle(
            icon: icon,
            color: color,
            size: 34,
            iconSize: 17,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AuroraColors.ink,
                        fontWeight: FontWeight.w500,
                        height: 1.42,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    final source = sourceDate;
    final openSource = onOpenSource;
    if (source == null || openSource == null) return content;
    final sourceLabel = AppLocaleText.tr(
      context,
      en: 'Open supporting Signals from ${_monthDay(source)}',
      zhHans: '查看 ${_monthDay(source)} 的支持 Signal',
      zhHant: '查看 ${_monthDay(source)} 的支持 Signal',
      ja: '${_monthDay(source)} の裏付け Signal を見る',
    );
    return Semantics(
      button: true,
      label: '$label，$sourceLabel',
      onTapHint: sourceLabel,
      child: Tooltip(
        message: sourceLabel,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: openSource,
            child: ExcludeSemantics(child: content),
          ),
        ),
      ),
    );
  }
}

class _WeeklyTimingChart extends StatelessWidget {
  final WeeklyInsightModel weekly;
  final String timingSummary;

  const _WeeklyTimingChart({
    required this.weekly,
    required this.timingSummary,
  });

  @override
  Widget build(BuildContext context) {
    final points = _sevenDayPoints(weekly);
    final maxCount = points.fold<int>(
      1,
      (current, point) => math.max(current, point.$2),
    );
    final total = points.fold<int>(0, (sum, point) => sum + point.$2);
    final activeDays = points.where((point) => point.$2 > 0).length;
    return AuroraCard(
      key: const ValueKey('weekly-deep-timing-chart'),
      padding: AuroraMainPageSpec.comfortableCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AuroraSectionIcon(
                icon: Icons.bar_chart_rounded,
                color: AuroraColors.blue,
                size: 30,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Where it appeared this week',
                    zhHans: '本周出现位置',
                    zhHant: '本週出現位置',
                    ja: '今週どこで現れたか',
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AuroraColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              AuroraChip(
                label: AppLocaleText.tr(
                  context,
                  en: '$total Signals · $activeDays days',
                  zhHans: '$total 条 Signal · $activeDays 天',
                  zhHant: '$total 條 Signal · $activeDays 天',
                  ja: 'Signal $total 件・$activeDays 日',
                ),
                color: AuroraColors.blue,
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 128,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final point in points)
                  Expanded(
                    child: Semantics(
                      button: point.$2 > 0,
                      onTapHint: point.$2 > 0
                          ? AppLocaleText.tr(
                              context,
                              en: 'Open this day in the diary',
                              zhHans: '在手帐时间线打开这一天',
                              zhHant: '在手帳時間線開啟這一天',
                              ja: '手帳タイムラインでこの日を開く',
                            )
                          : null,
                      onTap: point.$2 > 0
                          ? () => context.push(_todayDiaryLocation(point.$1))
                          : null,
                      label: AppLocaleText.tr(
                        context,
                        en: '${_monthDay(point.$1)}: ${point.$2} Signals',
                        zhHans: '${_monthDay(point.$1)}：${point.$2} 条 Signal',
                        zhHant: '${_monthDay(point.$1)}：${point.$2} 條 Signal',
                        ja: '${_monthDay(point.$1)}：Signal ${point.$2} 件',
                      ),
                      child: Tooltip(
                        message: point.$2 > 0
                            ? AppLocaleText.tr(
                                context,
                                en: 'Open Signals from ${_monthDay(point.$1)}',
                                zhHans: '查看 ${_monthDay(point.$1)} 的 Signal',
                                zhHant: '查看 ${_monthDay(point.$1)} 的 Signal',
                                ja: '${_monthDay(point.$1)} の Signal を見る',
                              )
                            : '',
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: point.$2 > 0
                                ? () => context.push(
                                      _todayDiaryLocation(point.$1),
                                    )
                                : null,
                            child: ExcludeSemantics(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${point.$2}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: AuroraColors.muted,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      key: ValueKey(
                                        'weekly-deep-signal-bar-${_dateKey(point.$1)}',
                                      ),
                                      width: 18,
                                      height: point.$2 == 0
                                          ? 6
                                          : 16 + 58 * point.$2 / maxCount,
                                      decoration: BoxDecoration(
                                        color: point.$2 == 0
                                            ? AuroraColors.blue
                                                .withValues(alpha: 0.10)
                                            : AuroraColors.blue.withValues(
                                                alpha: 0.40 +
                                                    0.40 * point.$2 / maxCount,
                                              ),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                    ),
                                    const SizedBox(height: 7),
                                    Text(
                                      _monthDay(point.$1),
                                      maxLines: 1,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: AuroraColors.muted,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (timingSummary.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              _compactAnalysisText(timingSummary),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AuroraColors.ink.withValues(alpha: 0.78),
                    height: 1.4,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The standard Weekly page deliberately stays on facts, behavior patterns and
/// feedback. Energy is a Pro-only derived view, so the five-state legend and
/// its load recommendation live here rather than duplicating that read on the
/// Weekly home page.
class _DeepWeeklyEnergyCard extends StatelessWidget {
  final WeeklyInsightModel weekly;
  final EnergyBudgetSnapshot? snapshot;

  const _DeepWeeklyEnergyCard({
    required this.weekly,
    required this.snapshot,
  });

  @override
  Widget build(BuildContext context) {
    final projection = weekly.energyProjection;
    final states = projection?.totals ??
        snapshot?.budget.energyStateCounts ??
        const <String, int>{};
    final total = states.values.fold<int>(0, (sum, value) => sum + value);
    final points = projection == null
        ? _sevenDayPoints(weekly)
            .map<(DateTime, int, WeeklyEnergyDayModel?)>(
              (point) => (point.$1, point.$2, null),
            )
            .toList(growable: false)
        : projection.days
            .map<(DateTime, int, WeeklyEnergyDayModel?)>(
              (day) => (_parseDate(day.date), day.signalCount, day),
            )
            .toList(growable: false);
    final maxSignals =
        points.fold<int>(1, (maxValue, point) => math.max(maxValue, point.$2));
    return AuroraCard(
      key: const ValueKey('weekly-deep-energy-card'),
      padding: AuroraMainPageSpec.comfortableCardPadding,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFFF5FFFC).withValues(alpha: 0.92),
          const Color(0xFFF4F6FF).withValues(alpha: 0.84),
        ],
      ),
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
                        color: AuroraColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              AuroraChip(
                label: total == 0
                    ? AppLocaleText.tr(
                        context,
                        en: 'Forming',
                        zhHans: '形成中',
                        zhHant: '形成中',
                        ja: '形成中',
                      )
                    : AppLocaleText.tr(
                        context,
                        en: '$total Signals',
                        zhHans: '$total 条 Signal',
                        zhHant: '$total 條 Signal',
                        ja: 'Signal $total 件',
                      ),
                color: AuroraColors.mint,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            AppLocaleText.tr(
              context,
              en: 'The seven-day Signal distribution is read together with five energy states. This is a weekly observation, not a diagnosis.',
              zhHans: '七日 Signal 分布与五类能量状态一起阅读；它是本周观察，不是诊断。',
              zhHant: '七日 Signal 分布與五類能量狀態一起閱讀；它是本週觀察，不是診斷。',
              ja: '7 日間の Signal 分布を 5 つのエネルギー状態と合わせて見ます。これは週ごとの観察であり、診断ではありません。',
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AuroraColors.muted,
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 132,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final point in points)
                  Expanded(
                    child: Semantics(
                      button: point.$2 > 0,
                      onTapHint: point.$2 > 0
                          ? AppLocaleText.tr(
                              context,
                              en: 'Open this day in the diary',
                              zhHans: '在手帐时间线打开这一天',
                              zhHant: '在手帳時間線開啟這一天',
                              ja: '手帳タイムラインでこの日を開く',
                            )
                          : null,
                      onTap: point.$2 > 0
                          ? () => context.push(_todayDiaryLocation(point.$1))
                          : null,
                      label: AppLocaleText.tr(
                        context,
                        en: '${_monthDay(point.$1)}: ${point.$2} Signals, ${_energyStateLabel(context, point.$3?.dominantState ?? 'steady')}, ${(point.$3?.feedbackCount ?? 0) > 0 ? 'try feedback recorded' : 'no try feedback'}',
                        zhHans:
                            '${_monthDay(point.$1)}：${point.$2} 条 Signal，${_energyStateLabel(context, point.$3?.dominantState ?? 'steady')}，${(point.$3?.feedbackCount ?? 0) > 0 ? '已登记尝试反馈' : '暂无尝试反馈'}',
                        zhHant:
                            '${_monthDay(point.$1)}：${point.$2} 條 Signal，${_energyStateLabel(context, point.$3?.dominantState ?? 'steady')}，${(point.$3?.feedbackCount ?? 0) > 0 ? '已登記嘗試回饋' : '尚無嘗試回饋'}',
                        ja: '${_monthDay(point.$1)}：Signal ${point.$2} 件、${_energyStateLabel(context, point.$3?.dominantState ?? 'steady')}、${(point.$3?.feedbackCount ?? 0) > 0 ? '試みの記録あり' : '試みの記録なし'}',
                      ),
                      child: Tooltip(
                        message: point.$2 > 0
                            ? AppLocaleText.tr(
                                context,
                                en: 'Open Signals from ${_monthDay(point.$1)}',
                                zhHans: '查看 ${_monthDay(point.$1)} 的 Signal',
                                zhHant: '查看 ${_monthDay(point.$1)} 的 Signal',
                                ja: '${_monthDay(point.$1)} の Signal を見る',
                              )
                            : '',
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: point.$2 > 0
                                ? () => context.push(
                                      _todayDiaryLocation(point.$1),
                                    )
                                : null,
                            child: ExcludeSemantics(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${point.$2}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: AuroraColors.muted,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Stack(
                                      clipBehavior: Clip.none,
                                      alignment: Alignment.topCenter,
                                      children: [
                                        Container(
                                          key: ValueKey(
                                            'weekly-deep-energy-signal-${_dateKey(point.$1)}',
                                          ),
                                          width: 18,
                                          height: point.$2 == 0
                                              ? 6
                                              : 14 + 48 * point.$2 / maxSignals,
                                          decoration: BoxDecoration(
                                            color: _energyColorForPoint(
                                              count: point.$2,
                                              state: point.$3?.dominantState,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                        ),
                                        if ((point.$3?.feedbackCount ?? 0) > 0)
                                          const Positioned(
                                            top: -8,
                                            child: Icon(
                                              Icons.check_circle_rounded,
                                              color: AuroraColors.mint,
                                              size: 14,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _monthDay(point.$1),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: AuroraColors.muted,
                                            fontSize: 10,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _deepEnergyLegend(context, states),
          ),
          const SizedBox(height: 14),
          _DeepLoadRecommendation(
            snapshot: snapshot,
            projection: projection,
          ),
        ],
      ),
    );
  }

  Color _energyColorForPoint({required int count, required String? state}) {
    if (count == 0) return AuroraColors.line.withValues(alpha: 0.7);
    return switch (state) {
      'draining' => AuroraColors.orange,
      'ease' => AuroraColors.gold,
      'recovery' => AuroraColors.mint,
      'boundary_buffer' => AuroraColors.purple,
      _ => AuroraColors.blue,
    };
  }

  List<Widget> _deepEnergyLegend(
    BuildContext context,
    Map<String, int> states,
  ) {
    const definitions = [
      ('draining', AuroraColors.orange),
      ('steady', AuroraColors.blue),
      ('ease', AuroraColors.gold),
      ('recovery', AuroraColors.mint),
      ('boundary_buffer', AuroraColors.purple),
    ];
    return definitions
        .map(
      (definition) => AuroraChip(
        label:
            '${_energyStateLabel(context, definition.$1)} ${states[definition.$1] ?? 0}',
        color: definition.$2,
      ),
    )
        .followedBy([
      AuroraChip(
        label: AppLocaleText.tr(
          context,
          en: '✓ Try feedback recorded',
          zhHans: '✓ 有尝试反馈',
          zhHant: '✓ 有嘗試回饋',
          ja: '✓ 試みの回饋あり',
        ),
        color: AuroraColors.mint,
      ),
    ]).toList(growable: false);
  }

  String _energyStateLabel(BuildContext context, String state) =>
      switch (state) {
        'draining' => AppLocaleText.tr(
            context,
            en: 'Draining',
            zhHans: '偏耗力',
            zhHant: '偏耗力',
            ja: 'やや消耗',
          ),
        'ease' => AppLocaleText.tr(
            context,
            en: 'At ease',
            zhHans: '有余力',
            zhHant: '有餘力',
            ja: '余力あり',
          ),
        'recovery' => AppLocaleText.tr(
            context,
            en: 'Recovery',
            zhHans: '恢复',
            zhHant: '恢復',
            ja: '回復',
          ),
        'boundary_buffer' => AppLocaleText.tr(
            context,
            en: 'Boundary & room',
            zhHans: '边界与余地',
            zhHant: '邊界與餘地',
            ja: '境界と余白',
          ),
        _ => AppLocaleText.tr(
            context,
            en: 'Steady',
            zhHans: '平稳',
            zhHant: '平穩',
            ja: '安定',
          ),
      };
}

class _DeepLoadRecommendation extends StatelessWidget {
  final EnergyBudgetSnapshot? snapshot;
  final WeeklyEnergyProjectionModel? projection;

  const _DeepLoadRecommendation({
    required this.snapshot,
    required this.projection,
  });

  @override
  Widget build(BuildContext context) {
    final currentProjection = projection;
    final (label, body, color, icon) = currentProjection != null
        ? switch (currentProjection.recommendation) {
            'cautiously_increase' => (
                AppLocaleText.tr(context,
                    en: 'Next-week load: cautiously increase',
                    zhHans: '下周负荷建议：小幅加量',
                    zhHant: '下週負荷建議：小幅加量',
                    ja: '来週の負荷提案：少しだけ増やす'),
                currentProjection.rationale,
                AuroraColors.mint,
                Icons.trending_up_rounded,
              ),
            'maintain_load' => (
                AppLocaleText.tr(context,
                    en: 'Next-week load: maintain',
                    zhHans: '下周负荷建议：维持',
                    zhHant: '下週負荷建議：維持',
                    ja: '来週の負荷提案：維持'),
                currentProjection.rationale,
                AuroraColors.blue,
                Icons.horizontal_rule_rounded,
              ),
            _ => (
                AppLocaleText.tr(context,
                    en: 'Next-week load: reduce',
                    zhHans: '下周负荷建议：减量',
                    zhHant: '下週負荷建議：減量',
                    ja: '来週の負荷提案：減らす'),
                currentProjection.rationale,
                AuroraColors.orange,
                Icons.south_rounded,
              ),
          }
        : switch (snapshot?.recommendedIntensity) {
            EnergyRecommendedIntensity.moderate => (
                AppLocaleText.tr(context,
                    en: 'Next-week load: cautiously increase',
                    zhHans: '下周负荷建议：小幅加量',
                    zhHant: '下週負荷建議：小幅加量',
                    ja: '来週の負荷提案：少しだけ増やす'),
                AppLocaleText.tr(context,
                    en: 'Keep choices pausable, then add only one small layer.',
                    zhHans: '保持可暂停，只多加一层很小的尝试。',
                    zhHant: '保持可暫停，只多加一層很小的嘗試。',
                    ja: '中断できる形を保ち、小さな一段だけ追加します。'),
                AuroraColors.mint,
                Icons.trending_up_rounded,
              ),
            EnergyRecommendedIntensity.light => (
                AppLocaleText.tr(context,
                    en: 'Next-week load: maintain',
                    zhHans: '下周负荷建议：维持',
                    zhHant: '下週負荷建議：維持',
                    ja: '来週の負荷提案：維持'),
                AppLocaleText.tr(context,
                    en: 'Keep the current size and leave enough room between tasks.',
                    zhHans: '保持当前规模，并在任务之间留出余地。',
                    zhHant: '保持目前規模，並在任務之間留出餘地。',
                    ja: '今の大きさを保ち、タスクの間に余白を残します。'),
                AuroraColors.blue,
                Icons.horizontal_rule_rounded,
              ),
            _ => (
                AppLocaleText.tr(context,
                    en: 'Next-week load: reduce',
                    zhHans: '下周负荷建议：减量',
                    zhHant: '下週負荷建議：減量',
                    ja: '来週の負荷提案：減らす'),
                AppLocaleText.tr(context,
                    en: 'Prioritize a short, low-switching option that can be paused.',
                    zhHans: '优先选择短、低切换、可以暂停的尝试。',
                    zhHant: '優先選擇短、低切換、可以暫停的嘗試。',
                    ja: '短く、切り替えが少なく、中断できる試みを優先します。'),
                AuroraColors.orange,
                Icons.south_rounded,
              ),
          };
    return Container(
      key: const ValueKey('weekly-deep-load-recommendation'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AuroraColors.ink,
                        height: 1.35,
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

class _NextValidationCard extends StatefulWidget {
  final WeeklyReflectModel deep;
  final WeeklyInsightModel weekly;
  final String? illustrationAsset;
  final String? illustrationLabel;

  const _NextValidationCard({
    required this.deep,
    required this.weekly,
    this.illustrationAsset,
    this.illustrationLabel,
  });

  @override
  State<_NextValidationCard> createState() => _NextValidationCardState();
}

class _NextValidationCardState extends State<_NextValidationCard> {
  LocalDeepeningObservationRepository? _repository;
  DeepeningObservationPlan? _latestResolvedPlan;
  DeepeningObservationPlan? _nextWeekPlan;
  bool _loading = true;
  bool _adopting = false;

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  Future<void> _loadPlan() async {
    final dependencies = context.read<AppDependencies>();
    final repository = LocalDeepeningObservationRepository(
      localDatabase: dependencies.localDatabase,
      localCaptureRepository: dependencies.localCaptureRepository,
      localUserId: dependencies.localUserId,
      nowLoader: dependencies.weeklyRepository.nowLoader,
    );
    final today = dependencies.weeklyRepository.nowLoader();
    DeepeningObservationPlan? latestResolvedPlan;
    DeepeningObservationPlan? plannedForNextWeek;
    try {
      latestResolvedPlan =
          await repository.resolveLatestCompletedTargetWeek(today);
      plannedForNextWeek =
          await repository.forTargetWeek(today.add(const Duration(days: 7)));
    } catch (_) {
      // Deep observation is optional. A legacy/test database that has not
      // been initialised must not block the entire deep report.
      plannedForNextWeek = null;
    }
    if (!mounted) return;
    setState(() {
      _repository = repository;
      _latestResolvedPlan =
          latestResolvedPlan?.status == DeepeningObservationPlanStatus.resolved
              ? latestResolvedPlan
              : null;
      _nextWeekPlan = plannedForNextWeek;
      _loading = false;
    });
  }

  DeepeningObservationProposal _proposal() {
    final ids = widget.weekly.behaviorPatterns
        .expand((pattern) => pattern.sourceSignalCardIds)
        .toSet()
        .toList(growable: false);
    final watch = <String>[
      _nonEmpty(widget.deep.nextQuestion, widget.deep.nextFocus),
      _nonEmpty(widget.deep.relationshipSummary, widget.deep.hiddenPattern),
    ].where((value) => value.trim().isNotEmpty).toList(growable: false);
    return DeepeningObservationProposal(
      sourceWeekStart: widget.weekly.weekStart,
      sourceWeekEnd: widget.weekly.weekEnd,
      question: _nonEmpty(widget.deep.nextQuestion, widget.deep.nextFocus),
      whatToWatch: watch,
      sourceSignalCardIds: ids,
      sourceHash:
          '${widget.weekly.weekStart}:${widget.weekly.reportReadiness.signalCount}:${ids.join(',')}',
    );
  }

  Future<void> _adopt() async {
    final repository = _repository;
    if (repository == null || _adopting) return;
    setState(() => _adopting = true);
    final plan = await repository.adopt(_proposal());
    if (!mounted) return;
    setState(() {
      _adopting = false;
      _nextWeekPlan = plan;
    });
  }

  @override
  Widget build(BuildContext context) {
    final deep = widget.deep;
    final latestResolvedPlan = _latestResolvedPlan;
    final nextWeekPlan = _nextWeekPlan;
    return AuroraCard(
      padding: AuroraMainPageSpec.comfortableCardPadding,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.88),
          const Color(0xFFF8F3FF).withValues(alpha: 0.82),
          const Color(0xFFFFF8F0).withValues(alpha: 0.78),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (widget.illustrationAsset != null)
                Semantics(
                  key: const ValueKey('weekly-deep-review-illustration'),
                  image: true,
                  label: widget.illustrationLabel,
                  child: ExcludeSemantics(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(
                        widget.illustrationAsset!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                )
              else
                const AuroraSectionIcon(
                  icon: Icons.science_rounded,
                  size: 42,
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Proposed deeper observation next week',
                    zhHans: '提案下周深化观察的问题',
                    zhHant: '提案下週深化觀察的問題',
                    ja: '来週に深めて観察する問い',
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AuroraColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (latestResolvedPlan != null) ...[
            _PreviousObservationResult(plan: latestResolvedPlan),
            const SizedBox(height: 14),
          ],
          _ValidationRow(
            icon: Icons.link_rounded,
            color: AuroraColors.mint,
            label: AppLocaleText.tr(
              context,
              en: 'What it helps distinguish',
              zhHans: '想区分什么可能性',
              zhHant: '想區分什麼可能性',
              ja: '何を見分けたいか',
            ),
            body: _nonEmpty(deep.relationshipSummary, deep.rootTension),
          ),
          const SizedBox(height: 9),
          _ValidationRow(
            icon: Icons.edit_calendar_rounded,
            color: AuroraColors.orange,
            label: AppLocaleText.tr(
              context,
              en: 'Signals to observe',
              zhHans: '下周应该观察哪些 Signal',
              zhHant: '下週應該觀察哪些 Signal',
              ja: '来週に観察する Signal',
            ),
            body: _nonEmpty(deep.nextQuestion, deep.nextFocus),
          ),
          const SizedBox(height: 9),
          _ValidationRow(
            icon: Icons.visibility_outlined,
            color: AuroraColors.blue,
            label: AppLocaleText.tr(
              context,
              en: 'What would support each reading',
              zhHans: '什么现象支持不同解释',
              zhHant: '什麼現象支持不同解釋',
              ja: 'どの現象がそれぞれの見立てを支えるか',
            ),
            body: AppLocaleText.tr(
              context,
              en: 'Notice which Signals recur, what changes after a small experiment, and which observations point to a different explanation.',
              zhHans: '留意哪些 Signal 再次出现、小实验后有什么变化，以及哪些观察指向另一种解释。',
              zhHant: '留意哪些 Signal 再次出現、小實驗後有什麼變化，以及哪些觀察指向另一種解釋。',
              ja: 'どの Signal が繰り返され、小実験の後に何が変わり、別の見立てを支える観察が何かを見ます。',
            ),
          ),
          const SizedBox(height: 10),
          Text(
            AppLocaleText.tr(
              context,
              en: 'This is an observation direction, not a task. Related small experiments and goals are selected separately on the next-week page.',
              zhHans: '这是一个观察方向，不是任务；相关的小实验和目标会在下周尝试页另行选择。',
              zhHant: '這是一個觀察方向，不是任務；相關的小實驗和目標會在下週嘗試頁另行選擇。',
              ja: 'これは観察の方向であり、タスクではありません。関連する小実験と目標は、来週の試みページで別に選びます。',
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AuroraColors.muted,
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const LinearProgressIndicator(minHeight: 2)
          else if (nextWeekPlan != null)
            _ObservationPlanScheduled(plan: nextWeekPlan)
          else
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                key: const ValueKey('weekly-deep-observation-adopt'),
                onPressed: _adopting ? null : _adopt,
                icon: _adopting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_task_rounded),
                label: Text(AppLocaleText.tr(
                  context,
                  en: 'Adopt this observation direction',
                  zhHans: '采纳这个观察方向',
                  zhHant: '採納這個觀察方向',
                  ja: 'この観察の方向を採用',
                )),
              ),
            ),
        ],
      ),
    );
  }
}

class _ValidationRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String body;

  const _ValidationRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  _compactAnalysisText(body),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AuroraColors.ink,
                        height: 1.38,
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

class _ObservationPlanScheduled extends StatelessWidget {
  final DeepeningObservationPlan plan;

  const _ObservationPlanScheduled({required this.plan});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('weekly-deep-observation-planned'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AuroraColors.mint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AuroraColors.mint.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, color: AuroraColors.mint),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              AppLocaleText.tr(
                context,
                en: 'Added for the week of ${plan.targetWeekStart}. A result will appear in deep analysis after that week is complete.',
                zhHans: '已加入 ${plan.targetWeekStart} 当周的深化观察；该周结束后会在深度分析中显示结果。',
                zhHant: '已加入 ${plan.targetWeekStart} 當週的深化觀察；該週結束後會在深度分析中顯示結果。',
                ja: '${plan.targetWeekStart} の週の深化観察に追加しました。その週が終わると深度分析に結果が表示されます。',
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AuroraColors.ink,
                    height: 1.38,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ObservationPlanResult extends StatelessWidget {
  final DeepeningObservationPlan plan;

  const _ObservationPlanResult({required this.plan});

  @override
  Widget build(BuildContext context) {
    final (title, color) = switch (plan.resultStatus) {
      DeepeningObservationResultStatus.supported => (
          AppLocaleText.tr(context,
              en: 'Deeper observation result',
              zhHans: '深化观察结果',
              zhHant: '深化觀察結果',
              ja: '深化観察の結果'),
          AuroraColors.mint,
        ),
      DeepeningObservationResultStatus.mixed => (
          AppLocaleText.tr(context,
              en: 'Deeper observation: still mixed',
              zhHans: '深化观察：结果仍不明确',
              zhHant: '深化觀察：結果仍不明確',
              ja: '深化観察：まだ混在しています'),
          AuroraColors.blue,
        ),
      _ => (
          AppLocaleText.tr(context,
              en: 'Deeper observation: more Signals needed',
              zhHans: '深化观察：还需要更多 Signal',
              zhHant: '深化觀察：還需要更多 Signal',
              ja: '深化観察：さらに Signal が必要です'),
          AuroraColors.orange,
        ),
    };
    return Container(
      key: const ValueKey('weekly-deep-observation-result'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  )),
          const SizedBox(height: 4),
          Text(
            plan.resultSummary ??
                AppLocaleText.tr(context,
                    en: 'No conclusion is shown until enough Signals are available.',
                    zhHans: '在有足够 Signal 前，不会给出结论。',
                    zhHant: '在有足夠 Signal 前，不會給出結論。',
                    ja: '十分な Signal が集まるまでは結論を表示しません。'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AuroraColors.ink,
                  height: 1.38,
                ),
          ),
        ],
      ),
    );
  }
}

class _PreviousObservationResult extends StatelessWidget {
  final DeepeningObservationPlan plan;

  const _PreviousObservationResult({required this.plan});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocaleText.tr(
            context,
            en: 'Previous deeper observation result',
            zhHans: '上一轮深化观察结果',
            zhHant: '上一輪深化觀察結果',
            ja: '前回の深化観察の結果',
          ),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AuroraColors.ink,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        _ObservationPlanResult(plan: plan),
      ],
    );
  }
}

class _AnalysisScopeCard extends StatelessWidget {
  final WeeklyInsightModel weekly;
  final String scopeNote;

  const _AnalysisScopeCard({
    required this.weekly,
    required this.scopeNote,
  });

  @override
  Widget build(BuildContext context) {
    final readiness = weekly.reportReadiness;
    final recordDays = weekly.chartData
        .where((point) => point.signalCount > 0)
        .map((point) => point.date)
        .toSet()
        .length;
    return AuroraCard(
      key: const ValueKey('weekly-analysis-scope-card'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AuroraSectionIcon(
                icon: Icons.info_outline_rounded,
                color: AuroraColors.gold,
                size: 32,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Analysis scope',
                    zhHans: '分析范围',
                    zhHant: '分析範圍',
                    ja: '分析の範囲',
                  ),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AuroraColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              AuroraChip(
                label: AppLocaleText.tr(
                  context,
                  en: '${readiness.signalCount} Signals · $recordDays days',
                  zhHans: '${readiness.signalCount} 条 Signal · $recordDays 天',
                  zhHant: '${readiness.signalCount} 條 Signal · $recordDays 天',
                  ja: 'Signal ${readiness.signalCount} 件・$recordDays 日',
                ),
                color: AuroraColors.gold,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ScopeRow(
            icon: Icons.check_circle_outline_rounded,
            color: AuroraColors.mint,
            label: AppLocaleText.tr(
              context,
              en: 'Can show',
              zhHans: '能说明',
              zhHant: '能說明',
              ja: '分かること',
            ),
            value: AppLocaleText.tr(
              context,
              en: 'Relationships that repeatedly appeared together this week.',
              zhHans: '本周反复同时出现的关系。',
              zhHant: '本週反覆同時出現的關係。',
              ja: '今週、繰り返し一緒に現れた関係。',
            ),
          ),
          const SizedBox(height: 8),
          _ScopeRow(
            icon: Icons.remove_circle_outline_rounded,
            color: AuroraColors.orange,
            label: AppLocaleText.tr(
              context,
              en: 'Cannot show',
              zhHans: '不能说明',
              zhHant: '不能說明',
              ja: '分からないこと',
            ),
            value: AppLocaleText.tr(
              context,
              en: 'Cause, personality, or a long-term conclusion.',
              zhHans: '因果、人格或长期结论。',
              zhHant: '因果、人格或長期結論。',
              ja: '原因、性格、長期的な結論。',
            ),
          ),
          if (scopeNote.trim().isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(
              _compactAnalysisText(scopeNote),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AuroraColors.muted,
                    height: 1.35,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Kept separate from analysis scope: scope explains the limits of a read,
/// while a reminder is an optional user-controlled follow-up. Scheduling and
/// persistence are wired by the reminder data flow; this card intentionally
/// makes no claim that a notification itself writes a Signal.
class _SignalReminderSuggestionCard extends StatefulWidget {
  final String suggestion;

  const _SignalReminderSuggestionCard({required this.suggestion});

  @override
  State<_SignalReminderSuggestionCard> createState() =>
      _SignalReminderSuggestionCardState();
}

class _SignalReminderSuggestionCardState
    extends State<_SignalReminderSuggestionCard> {
  SignalReminderRepository? _repository;
  SignalReminderRule? _rule;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadRule();
  }

  Future<void> _loadRule() async {
    final preferences = await SharedPreferences.getInstance();
    final repository = SignalReminderRepository(preferences: preferences);
    final rules = await repository.loadRules();
    SignalReminderRule? activeRule;
    for (final rule in rules) {
      if (rule.enabled) {
        activeRule = rule;
        break;
      }
    }
    if (!mounted) return;
    setState(() {
      _repository = repository;
      _rule = activeRule;
      _loading = false;
    });
  }

  Future<void> _configure() async {
    final initial = _rule == null
        ? _timeFromSuggestion(widget.suggestion) ??
            const TimeOfDay(hour: 20, minute: 30)
        : TimeOfDay(hour: _rule!.hour, minute: _rule!.minute);
    final selected = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: AppLocaleText.tr(
        context,
        en: 'Choose a Signal reminder time',
        zhHans: '选择 Signal 记录提醒时间',
        zhHant: '選擇 Signal 記錄提醒時間',
        ja: 'Signal 記録リマインダーの時間を選ぶ',
      ),
    );
    if (!mounted || selected == null) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocaleText.tr(
          dialogContext,
          en: 'Enable a local Signal reminder?',
          zhHans: '开启本机 Signal 提醒？',
          zhHant: '開啟本機 Signal 提醒？',
          ja: '端末内の Signal リマインダーを有効にしますか？',
        )),
        content: Text(AppLocaleText.tr(
          dialogContext,
          en: 'It will remind you at ${selected.format(dialogContext)}. It only opens input and never creates a Signal for you.',
          zhHans:
              '每天 ${selected.format(dialogContext)} 提醒你记录；它只打开输入入口，不会自动创建 Signal。',
          zhHant:
              '每天 ${selected.format(dialogContext)} 提醒你記錄；它只打開輸入入口，不會自動建立 Signal。',
          ja: '毎日 ${selected.format(dialogContext)} に記録を促します。入力を開くだけで、Signal を自動作成することはありません。',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppLocaleText.tr(dialogContext,
                en: 'Not now', zhHans: '暂不设置', zhHant: '暫不設定', ja: '今はしない')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(AppLocaleText.tr(dialogContext,
                en: 'Enable', zhHans: '确认开启', zhHant: '確認開啟', ja: '有効にする')),
          ),
        ],
      ),
    );
    if (!mounted || accepted != true || _repository == null) return;
    setState(() => _saving = true);
    final result = await _repository!.saveConfirmed(
      SignalReminderRule.weekly(
        id: _rule?.id,
        weekdays: const {
          DateTime.monday,
          DateTime.tuesday,
          DateTime.wednesday,
          DateTime.thursday,
          DateTime.friday,
          DateTime.saturday,
          DateTime.sunday,
        },
        hour: selected.hour,
        minute: selected.minute,
        localeTag: Localizations.localeOf(context).toLanguageTag(),
      ),
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _rule = result.scheduled ? result.rule : null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.scheduled
              ? AppLocaleText.tr(context,
                  en: 'Signal reminder is on.',
                  zhHans: 'Signal 记录提醒已开启。',
                  zhHant: 'Signal 記錄提醒已開啟。',
                  ja: 'Signal 記録リマインダーを有効にしました。')
              : AppLocaleText.tr(context,
                  en: 'The reminder was not enabled.',
                  zhHans: '提醒未开启。',
                  zhHant: '提醒未開啟。',
                  ja: 'リマインダーは有効になりませんでした。'),
        ),
      ),
    );
  }

  Future<void> _disable() async {
    final rule = _rule;
    final repository = _repository;
    if (rule == null || repository == null) return;
    setState(() => _saving = true);
    await repository.disable(rule.id);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _rule = null;
    });
  }

  Future<void> _delete() async {
    final rule = _rule;
    final repository = _repository;
    if (rule == null || repository == null) return;
    setState(() => _saving = true);
    await repository.delete(rule.id);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _rule = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuroraCard(
      key: const ValueKey('weekly-deep-signal-reminder-card'),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AuroraSectionIcon(
            icon: Icons.notifications_none_rounded,
            color: AuroraColors.purple,
            size: 32,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Signal reminder suggestion',
                    zhHans: 'Signal 记录提醒建议',
                    zhHant: 'Signal 記錄提醒建議',
                    ja: 'Signal 記録リマインダーの提案',
                  ),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AuroraColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppLocaleText.tr(
                    context,
                    en: 'When a repeatable time window becomes clear, you can choose whether to receive a local reminder. A reminder only opens input; it never creates a Signal by itself.',
                    zhHans:
                        '建议时段：${widget.suggestion}\n你可以选择是否接收本机提醒；时间可编辑。提醒只打开输入入口，不会自行创建 Signal。',
                    zhHant:
                        '建議時段：${widget.suggestion}\n你可以選擇是否接收本機提醒；時間可編輯。提醒只打開輸入入口，不會自行建立 Signal。',
                    ja: '記録しやすい時間帯が見えてきたら、端末内のリマインダーを受け取るか選べます。リマインダーは入力を開くだけで、Signal を自動作成しません。',
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AuroraColors.muted,
                        height: 1.38,
                      ),
                ),
                const SizedBox(height: 10),
                if (_loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (_rule == null)
                  OutlinedButton.icon(
                    key: const ValueKey('weekly-signal-reminder-configure'),
                    onPressed: _saving ? null : _configure,
                    icon: const Icon(Icons.schedule_rounded),
                    label: Text(AppLocaleText.tr(
                      context,
                      en: 'Set a reminder',
                      zhHans: '设置提醒',
                      zhHant: '設定提醒',
                      ja: 'リマインダーを設定',
                    )),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      AuroraChip(
                        label: AppLocaleText.tr(
                          context,
                          en: 'Daily ${_rule!.hour.toString().padLeft(2, '0')}:${_rule!.minute.toString().padLeft(2, '0')}',
                          zhHans:
                              '每天 ${_rule!.hour.toString().padLeft(2, '0')}:${_rule!.minute.toString().padLeft(2, '0')}',
                          zhHant:
                              '每天 ${_rule!.hour.toString().padLeft(2, '0')}:${_rule!.minute.toString().padLeft(2, '0')}',
                          ja: '毎日 ${_rule!.hour.toString().padLeft(2, '0')}:${_rule!.minute.toString().padLeft(2, '0')}',
                        ),
                        color: AuroraColors.mint,
                      ),
                      TextButton(
                        key: const ValueKey('weekly-signal-reminder-edit'),
                        onPressed: _saving ? null : _configure,
                        child: Text(AppLocaleText.tr(context,
                            en: 'Edit', zhHans: '编辑', zhHant: '編輯', ja: '編集')),
                      ),
                      TextButton(
                        key: const ValueKey('weekly-signal-reminder-disable'),
                        onPressed: _saving ? null : _disable,
                        child: Text(AppLocaleText.tr(context,
                            en: 'Turn off',
                            zhHans: '关闭',
                            zhHant: '關閉',
                            ja: 'オフにする')),
                      ),
                      TextButton(
                        key: const ValueKey('weekly-signal-reminder-delete'),
                        onPressed: _saving ? null : _delete,
                        child: Text(AppLocaleText.tr(context,
                            en: 'Delete',
                            zhHans: '删除',
                            zhHant: '刪除',
                            ja: '削除')),
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

bool _hasExplainableReminderWindow(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) return false;
  return RegExp(r'\b\d{1,2}[:：]\d{2}\b').hasMatch(normalized) ||
      RegExp(r'(早上|上午|中午|午后|下午|晚上|睡前|morning|afternoon|evening|night)',
              caseSensitive: false)
          .hasMatch(normalized);
}

TimeOfDay? _timeFromSuggestion(String value) {
  final match = RegExp(r'\b(\d{1,2})[:：](\d{2})\b').firstMatch(value);
  if (match == null) return null;
  final hour = int.tryParse(match.group(1) ?? '');
  final minute = int.tryParse(match.group(2) ?? '');
  if (hour == null || minute == null || hour > 23 || minute > 59) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

class _ScopeRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _ScopeRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          '$label：',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AuroraColors.ink,
                  height: 1.35,
                ),
          ),
        ),
      ],
    );
  }
}

WeeklyIllustrationDefinition? _patternIllustrationForWeekly(
  WeeklyReflectModel deep,
  WeeklyInsightModel weekly,
) {
  final hints = <String>[
    deep.illustrationHint ?? '',
    for (final item in [...weekly.patterns, ...weekly.frictions])
      if (item is Map) item['illustration_hint']?.toString() ?? '',
  ];
  for (final hint in hints) {
    if (hint.trim().isEmpty) continue;
    final exact = WeeklyIllustrationCatalog.patternForHint(hint);
    if (exact != null) return exact;
  }
  final fallback = WeeklyIllustrationCatalog.forText(
    '${deep.patternLabel} ${deep.frictionLabel}',
  );
  return fallback?.id.startsWith('pattern.') == true ? fallback : null;
}

List<(DateTime, int)> _sevenDayPoints(WeeklyInsightModel weekly) {
  final firstChartDate = weekly.chartData.isEmpty
      ? null
      : DateTime.tryParse(weekly.chartData.first.date);
  final start = DateTime.tryParse(weekly.weekStart) ??
      firstChartDate ??
      DateTime(1970, 1, 5);
  final counts = <String, int>{
    for (final point in weekly.chartData)
      point.date.length >= 10 ? point.date.substring(0, 10) : point.date:
          point.signalCount,
  };
  return List.generate(7, (index) {
    final date =
        DateTime(start.year, start.month, start.day).add(Duration(days: index));
    return (date, counts[_dateKey(date)] ?? 0);
  }, growable: false);
}

String _weekRangeLabel(WeeklyInsightModel? weekly) {
  if (weekly == null) return '';
  final start = DateTime.tryParse(weekly.weekStart);
  final end = DateTime.tryParse(weekly.weekEnd);
  if (start == null || end == null) {
    return '${weekly.weekStart}–${weekly.weekEnd}';
  }
  return '${_monthDay(start)}–${_monthDay(end)}';
}

String _weeklyCountLabel(
  BuildContext context,
  WeeklyInsightModel? weekly,
) {
  if (weekly == null) return '';
  final count = weekly.reportReadiness.signalCount;
  final days = weekly.chartData
      .where((point) => point.signalCount > 0)
      .map((point) => point.date)
      .toSet()
      .length;
  return AppLocaleText.tr(
    context,
    en: '$count Signals · $days days',
    zhHans: '$count 条 Signal · $days 天',
    zhHant: '$count 條 Signal · $days 天',
    ja: 'Signal $count 件・$days 日',
  );
}

String _legacyNodeValue(WeeklyReflectModel deep, int index) {
  if (index < deep.keyNodes.length) {
    final value = deep.keyNodes[index].trim();
    final separator = value.indexOf(RegExp(r'[:：]'));
    if (separator >= 0 && separator + 1 < value.length) {
      return value.substring(separator + 1).trim();
    }
    if (value.isNotEmpty) return value;
  }
  return index == 0 ? deep.rootTension : deep.hiddenPattern;
}

String _compactAnalysisText(String value) {
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _nonEmpty(String value, String fallback) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? fallback.trim() : trimmed;
}

String _monthDay(DateTime date) => '${date.month}/${date.day}';

DateTime _parseDate(String raw) =>
    DateTime.tryParse(raw) ?? DateTime(1970, 1, 1);

String _dateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

DateTime? _validDateOrNull(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;
  return DateTime.tryParse(value);
}

String _todayDiaryLocation(DateTime date) => Uri(
      path: AppRoutes.todayDiary,
      queryParameters: {'date': _dateKey(date)},
    ).toString();
