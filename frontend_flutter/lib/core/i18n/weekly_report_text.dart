import 'package:flutter/material.dart';

import '../models/weekly_models.dart';
import 'app_locale_text.dart';
import 'energy_budget_text.dart';

/// Presentation-only cleanup for generated Weekly report copy.
///
/// Weekly data keeps stable English taxonomy keys for persistence and
/// analysis. Those keys must not leak into a Chinese or Japanese report.
/// User-authored Signal content is deliberately not passed through this
/// helper.
class WeeklyReportText {
  const WeeklyReportText._();

  static String localizeCopy(BuildContext context, String copy) {
    if (copy.trim().isEmpty) return copy;

    var result = EnergyBudgetText.localizeCopy(context, copy);
    final language = AppLocaleText.resolve(context);
    result = _localizeGeneratedActionPhrases(result, language);
    if (language == AppLanguage.english) return result;

    final replacements = switch (language) {
      AppLanguage.simplifiedChinese => _simplifiedChineseTerms,
      AppLanguage.traditionalChinese => _traditionalChineseTerms,
      AppLanguage.japanese => _japaneseTerms,
      AppLanguage.english => const <String, String>{},
    };

    final orderedTerms = replacements.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final term in orderedTerms) {
      result = result.replaceAll(
        RegExp(
          '(?<![A-Za-z0-9_])${RegExp.escape(term)}(?![A-Za-z0-9_])',
          caseSensitive: false,
        ),
        replacements[term]!,
      );
    }

    // EnergyBudgetText knows the complete current taxonomy. Applying it to
    // each machine token also covers newly added exact taxonomy values
    // without translating ordinary user-authored prose.
    result = result.replaceAllMapped(
      RegExp(r'(?<![A-Za-z0-9_])[A-Za-z][A-Za-z0-9_]*(?![A-Za-z0-9_])'),
      (match) {
        final token = match.group(0)!;
        final localized = EnergyBudgetText.localizeCopy(context, token);
        return localized == token ? token : localized;
      },
    );
    // English source copy often leaves spaces around replaced Chinese terms
    // (for example "AI in ProL3" becoming "智能助手 在 深度分析 中").
    // Generated report copy should follow natural CJK spacing.
    result = result.replaceAll(
      RegExp(r'(?<=[\u3400-\u9FFF])\s+(?=[\u3400-\u9FFF])'),
      '',
    );
    return result;
  }

  /// Keeps generated Weekly/Deep Analysis prose in the active UI language.
  ///
  /// Older persisted reports can outlive a locale change. Taxonomy replacement
  /// alone cannot translate those free-form paragraphs, so generated surfaces
  /// must fail closed to a deterministic, fact-backed localized fallback.
  /// User-authored Signal text must not be passed through this helper.
  static String generatedCopyOrFallback(
    BuildContext context,
    String copy, {
    required String fallback,
  }) {
    final localized = localizeCopy(context, copy);
    if (localized.trim().isEmpty) return localized;
    return _generatedCopyMatchesLanguage(context, localized)
        ? localized
        : fallback;
  }

  static bool _generatedCopyMatchesLanguage(
    BuildContext context,
    String copy,
  ) {
    final language = AppLocaleText.resolve(context);
    if (language == AppLanguage.simplifiedChinese ||
        language == AppLanguage.traditionalChinese) {
      return true;
    }
    final hasHan = RegExp(r'[\u3400-\u9fff]').hasMatch(copy);
    final hasKana = RegExp(r'[\u3040-\u30ff]').hasMatch(copy);
    if (language == AppLanguage.english) {
      return !hasHan && !hasKana && RegExp(r'[A-Za-z]').hasMatch(copy);
    }
    final hasChineseOnlyForms = RegExp(
      r'[这们么还没为个录复续觉验几条让层里边'
      r'這們麼還沒錄續覺驗條讓裡邊]',
    ).hasMatch(copy);
    return hasKana && !hasChineseOnlyForms;
  }

  static String _localizeGeneratedActionPhrases(
    String copy,
    AppLanguage language,
  ) {
    final replacements = switch (language) {
      AppLanguage.english => _englishGeneratedActionPhrases,
      AppLanguage.simplifiedChinese => _simplifiedGeneratedActionPhrases,
      AppLanguage.traditionalChinese => _traditionalGeneratedActionPhrases,
      AppLanguage.japanese => _japaneseGeneratedActionPhrases,
    };
    var result = copy;
    final orderedPhrases = replacements.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final phrase in orderedPhrases) {
      result = result.replaceAll(phrase, replacements[phrase]!);
    }
    return result;
  }

  static WeeklyInsightModel localizeInsight(
    BuildContext context,
    WeeklyInsightModel source,
  ) {
    final previous = source.previousWeekSummary;
    final energy = source.energyProjection;
    return WeeklyInsightModel(
      weekStart: source.weekStart,
      weekEnd: source.weekEnd,
      status: source.status,
      keyInsight: _nullableCopy(context, source.keyInsight),
      patterns: _localizeReportRows(context, source.patterns),
      frictions: _localizeReportRows(context, source.frictions),
      bestAction: _nullableCopy(context, source.bestAction),
      opportunitySnapshot:
          _localizeOpportunitySummary(context, source.opportunitySnapshot),
      feedbackSubmitted: source.feedbackSubmitted,
      chartData: source.chartData,
      previousWeekSummary: previous == null
          ? null
          : PreviousWeekSummaryModel(
              weekStart: previous.weekStart,
              weekEnd: previous.weekEnd,
              readiness: previous.readiness,
              signalCount: previous.signalCount,
              recordedDayCount: previous.recordedDayCount,
              factualSummary: localizeCopy(context, previous.factualSummary),
              thisWeekWatchpoint:
                  localizeCopy(context, previous.thisWeekWatchpoint),
              sourceSignalCardIds: previous.sourceSignalCardIds,
              sourceHash: previous.sourceHash,
            ),
      behaviorPatterns: source.behaviorPatterns
          .map(
            (pattern) => WeeklyBehaviorPatternModel(
              id: pattern.id,
              label: localizeCopy(context, pattern.label),
              summary: localizeCopy(context, pattern.summary),
              kind: pattern.kind,
              sourceSignalCardIds: pattern.sourceSignalCardIds,
              supportDates: pattern.supportDates,
              illustrationHint: pattern.illustrationHint,
            ),
          )
          .toList(growable: false),
      energyProjection: energy == null
          ? null
          : WeeklyEnergyProjectionModel(
              days: energy.days,
              totals: energy.totals,
              recommendation: energy.recommendation,
              rationale: localizeCopy(context, energy.rationale),
            ),
    );
  }

  static String? _nullableCopy(BuildContext context, String? value) {
    if (value == null) return null;
    return localizeCopy(context, value);
  }

  static List<dynamic> _localizeReportRows(
    BuildContext context,
    List<dynamic> rows,
  ) {
    return rows.map((row) {
      if (row is! Map) return row;
      return row.map((rawKey, value) {
        final key = '$rawKey';
        if (value is String && _generatedCopyKeys.contains(key)) {
          return MapEntry(rawKey, localizeCopy(context, value));
        }
        return MapEntry(rawKey, value);
      });
    }).toList(growable: false);
  }

  static Map<String, dynamic>? _localizeOpportunitySummary(
    BuildContext context,
    Map<String, dynamic>? snapshot,
  ) {
    if (snapshot == null) return null;
    final localized = Map<String, dynamic>.from(snapshot);
    for (final key in const ['name', 'summary']) {
      final value = localized[key];
      if (value is String) localized[key] = localizeCopy(context, value);
    }
    final actionReview = localized['_weekly_action_review'];
    if (actionReview is Map) {
      localized['_weekly_action_review'] = actionReview.map((rawKey, value) {
        final key = '$rawKey';
        if (value is String && _actionReviewCopyKeys.contains(key)) {
          return MapEntry(rawKey, localizeCopy(context, value));
        }
        return MapEntry(rawKey, value);
      });
    }
    return localized;
  }

  static const _generatedCopyKeys = {
    'name',
    'title',
    'pattern',
    'summary',
    'description',
    'reason',
    'trigger',
    'trigger_point',
    'reaction',
    'typical_reaction',
    'short_result',
    'short_term_result',
    'long_impact',
    'long_term_impact',
  };

  static const _actionReviewCopyKeys = {
    'most_helpful_action',
    'hardest_action',
    'next_adjustment',
  };

  // These phrases are persisted by the local weekly action-review pipeline.
  // Keep compatibility with both Simplified and Traditional Chinese caches,
  // but translate them only on generated Weekly report surfaces.
  static const _englishGeneratedActionPhrases = <String, String>{
    '先选一个很小的尝试': 'Choose one very small Spot Try first',
    '先選一個很小的嘗試': 'Choose one very small Spot Try first',
    '继续这个方向': 'Continue in this direction',
    '繼續這個方向': 'Continue in this direction',
    '调整后再试': 'Adjust it and try again',
    '調整後再試': 'Adjust it and try again',
    '换一个策略': 'Try another approach',
    '換一個策略': 'Try another approach',
    '调轻一点': 'Make it a little lighter',
    '調輕一點': 'Make it a little lighter',
    '暂时不做': 'Pause for now',
    '暫時不做': 'Pause for now',
  };

  static const _simplifiedGeneratedActionPhrases = <String, String>{
    '先選一個很小的嘗試': '先选一个很小的尝试',
    '繼續這個方向': '继续这个方向',
    '調整後再試': '调整后再试',
    '換一個策略': '换一个策略',
    '調輕一點': '调轻一点',
    '暫時不做': '暂时不做',
  };

  static const _traditionalGeneratedActionPhrases = <String, String>{
    '先选一个很小的尝试': '先選一個很小的嘗試',
    '继续这个方向': '繼續這個方向',
    '调整后再试': '調整後再試',
    '换一个策略': '換一個策略',
    '调轻一点': '調輕一點',
    '暂时不做': '暫時不做',
  };

  static const _japaneseGeneratedActionPhrases = <String, String>{
    '先选一个很小的尝试': 'まず、とても小さなスポットトライを一つ選ぶ',
    '先選一個很小的嘗試': 'まず、とても小さなスポットトライを一つ選ぶ',
    '继续这个方向': 'この方向を続ける',
    '繼續這個方向': 'この方向を続ける',
    '调整后再试': '調整してもう一度試す',
    '調整後再試': '調整してもう一度試す',
    '换一个策略': '別の方法を試す',
    '換一個策略': '別の方法を試す',
    '调轻一点': '少し軽くする',
    '調輕一點': '少し軽くする',
    '暂时不做': 'いったん休む',
    '暫時不做': 'いったん休む',
  };

  static const _simplifiedChineseTerms = <String, String>{
    'Signal Cards': '信号卡',
    'Signal Card': '信号卡',
    'SignalCard': '信号卡',
    'Deep Analysis': '深度分析',
    'Pro L3 Reflect': '深度分析',
    'ProL3': '深度分析',
    'L3 Reflect': '深度分析',
    'Life Experiment': '生活小实验',
    'LifeExperiment': '生活小实验',
    'Energy Budget': '能量预算',
    'EnergyBudget': '能量预算',
    'body tension': '身体紧绷',
    'Strategy': '策略',
    'Design': '设计',
    'Development': '检验指标',
    'Weekly': '每周复盘',
    'Journey': '旅程',
    'Today': '今天',
    '未分类': '其他',
    'unknown': '其他',
    'AI': '智能助手',
    'Pro': '专业版',
    'L3': '深度分析',
  };

  static const _traditionalChineseTerms = <String, String>{
    'Signal Cards': '信號卡',
    'Signal Card': '信號卡',
    'SignalCard': '信號卡',
    'Deep Analysis': '深度分析',
    'Pro L3 Reflect': '深度分析',
    'ProL3': '深度分析',
    'L3 Reflect': '深度分析',
    'Life Experiment': '生活小實驗',
    'LifeExperiment': '生活小實驗',
    'Energy Budget': '能量預算',
    'EnergyBudget': '能量預算',
    'body tension': '身體緊繃',
    'Strategy': '策略',
    'Design': '設計',
    'Development': '檢驗指標',
    'Weekly': '每週復盤',
    'Journey': '旅程',
    'Today': '今天',
    '未分類': '其他',
    'unknown': '其他',
    'AI': '人工智慧',
    'Pro': '專業版',
    'L3': '深度分析',
  };

  static const _japaneseTerms = <String, String>{
    'Signal Cards': 'シグナルカード',
    'Signal Card': 'シグナルカード',
    'SignalCard': 'シグナルカード',
    'Deep Analysis': '詳細分析',
    'Pro L3 Reflect': '詳細分析',
    'ProL3': '詳細分析',
    'L3 Reflect': '詳細分析',
    'Life Experiment': '生活の小実験',
    'LifeExperiment': '生活の小実験',
    'Energy Budget': 'エネルギー配分',
    'EnergyBudget': 'エネルギー配分',
    'body tension': '身体のこわばり',
    'Strategy': '方針',
    'Design': '設計',
    'Development': '確認指標',
    'Weekly': '週間レビュー',
    'Journey': '旅程',
    'Today': '今日',
    'unknown': 'その他',
    'AI': '人工知能',
    'Pro': 'プロ版',
    'L3': '詳細分析',
  };
}
