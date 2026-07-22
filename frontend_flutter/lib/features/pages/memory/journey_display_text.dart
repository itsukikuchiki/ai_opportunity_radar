import 'package:flutter/widgets.dart';

import '../../../core/i18n/app_locale_text.dart';
import '../../../core/preferences/focus_domains.dart';

/// Localizes analysis tokens only at presentation time.
///
/// Journey data deliberately keeps stable, language-independent enum values in
/// storage. This helper prevents those implementation values from leaking into
/// the localized report UI without changing the underlying records.
String localizeJourneyDisplayText(BuildContext context, String text) {
  var output = text.replaceAll(
    RegExp(r'\[planning\]', caseSensitive: false),
    _categoryLabel(context, 'planning'),
  );

  for (final token in _journeyCategoryTokens) {
    output = output.replaceAll(
      RegExp(
        '\\b${RegExp.escape(token)}\\b',
        caseSensitive: false,
      ),
      _categoryLabel(context, token),
    );
  }
  return output;
}

/// Keeps stored MicroAction completion tokens stable while presenting the
/// completion result in the current app language.
String localizeJourneyEvidenceText(
  BuildContext context, {
  required String sourceType,
  required String text,
}) {
  var output = localizeJourneyDisplayText(context, text);
  if (sourceType.trim().toLowerCase() != 'micro_action_feedback') {
    return output;
  }

  final notCompleted = AppLocaleText.tr(
    context,
    en: 'Not completed',
    zhHans: '未完成',
    zhHant: '未完成',
    ja: '未完了',
  );
  final completed = AppLocaleText.tr(
    context,
    en: 'Completed',
    zhHans: '已完成',
    zhHant: '已完成',
    ja: '完了',
  );
  for (final token in const [
    'not_suitable_today',
    'not_completed',
    'not_occurred',
    'not_happened',
    'not_done',
    'skipped',
    'no',
  ]) {
    output = output.replaceAll(
      RegExp('\\b${RegExp.escape(token)}\\b', caseSensitive: false),
      notCompleted,
    );
  }
  for (final token in const [
    'completed',
    'occurred',
    'happened',
    'done',
    'yes',
  ]) {
    output = output.replaceAll(
      RegExp('\\b${RegExp.escape(token)}\\b', caseSensitive: false),
      completed,
    );
  }
  return output;
}

String localizeJourneyCategoryLabel(BuildContext context, String value) {
  final normalized = value.trim().toLowerCase();
  if (const {
    'micro action feedback',
    'micro-action feedback',
    'microaction feedback',
    'small action feedback',
  }.contains(normalized)) {
    return _smallTryFeedbackLabel(context);
  }
  if (const {
    'experiment feedback',
    'life experiment feedback',
  }.contains(normalized)) {
    return _goalFeedbackLabel(context);
  }
  if (normalized == 'life experiment') {
    return _goalLabel(context);
  }
  final focusDomain = FocusDomains.optionFor(normalized);
  if (focusDomain != null) return focusDomain.label(context);
  if (_journeyCategoryTokens.contains(normalized)) {
    return _categoryLabel(context, normalized);
  }
  if (normalized == 'signalcard' || normalized == 'signal_card') {
    return 'Signal Card';
  }
  return localizeJourneyDisplayText(context, value);
}

String journeySourceTypeLabel(BuildContext context, String sourceType) {
  switch (sourceType.trim().toLowerCase()) {
    case 'text':
      return AppLocaleText.tr(
        context,
        en: 'Text',
        zhHans: '文字',
        zhHant: '文字',
        ja: 'テキスト',
      );
    case 'voice':
      return AppLocaleText.tr(
        context,
        en: 'Voice',
        zhHans: '语音',
        zhHant: '語音',
        ja: '音声',
      );
    case 'status':
      return AppLocaleText.tr(
        context,
        en: 'Status',
        zhHans: '状态',
        zhHant: '狀態',
        ja: '状態',
      );
    case 'time_use':
      return AppLocaleText.tr(
        context,
        en: 'Time use',
        zhHans: '时间使用',
        zhHant: '時間使用',
        ja: '時間の使い方',
      );
    case 'library_saved':
    case 'signal_library':
      return AppLocaleText.tr(
        context,
        en: 'Signal Library',
        zhHans: '信号库',
        zhHant: '信號庫',
        ja: 'シグナルライブラリ',
      );
    case 'manual_reflection':
      return AppLocaleText.tr(
        context,
        en: 'Manual reflection',
        zhHans: '手动反思',
        zhHant: '手動反思',
        ja: '手動の振り返り',
      );
    case 'micro_action_feedback':
      return _smallTryFeedbackLabel(context);
    case 'life_experiment':
      return _goalLabel(context);
    case 'life_experiment_feedback':
      return _goalFeedbackLabel(context);
    case 'weekly_review':
      return AppLocaleText.tr(
        context,
        en: 'Weekly Review',
        zhHans: '每周复盘',
        zhHant: '每週複盤',
        ja: '毎週の振り返り',
      );
    case 'signal_card':
    case 'signalcard':
      return 'Signal Card';
    default:
      return localizeJourneyCategoryLabel(context, sourceType);
  }
}

String _smallTryFeedbackLabel(BuildContext context) => AppLocaleText.tr(
      context,
      en: 'Life Experiment · Small experiment feedback',
      zhHans: '生活小实验 · 小实验反馈',
      zhHant: '生活小實驗 · 小實驗回饋',
      ja: '生活実験 · 小実験の反応',
    );

String _goalLabel(BuildContext context) => AppLocaleText.tr(
      context,
      en: 'Life Experiment · Goal',
      zhHans: '生活小实验 · 目标',
      zhHant: '生活小實驗 · 目標',
      ja: '生活実験 · 目標',
    );

String _goalFeedbackLabel(BuildContext context) => AppLocaleText.tr(
      context,
      en: 'Life Experiment · Goal feedback',
      zhHans: '生活小实验 · 目标反馈',
      zhHant: '生活小實驗 · 目標回饋',
      ja: '生活実験 · 目標の反応',
    );

const _journeyCategoryTokens = <String>{
  'planning',
  'work',
  'recovery',
  'relationship',
  'boundary',
  'emotional',
  'emotional_stability',
  'relationship_connection',
  'meaning_value',
  'self_boundary',
  'growth_plan',
  'creative_expression',
  'food_sleep',
  'living_environment',
  'interests_hobbies',
  'home',
  'sleep',
  'commute',
  'body',
  'money',
  'future',
  'hobby',
  'rest',
  'achievement',
  'self_doubt',
  'daily_friction',
  'study',
  'daily_life',
  'friction',
  'helpful',
  'weekly',
  'life',
  'unknown',
  'other',
};

String _categoryLabel(BuildContext context, String value) {
  final focusDomain = FocusDomains.optionFor(value);
  if (focusDomain != null) return focusDomain.label(context);
  switch (value) {
    case 'planning':
      return AppLocaleText.tr(
        context,
        en: 'rhythm',
        zhHans: '节奏',
        zhHant: '節奏',
        ja: 'リズム',
      );
    case 'work':
      return AppLocaleText.tr(
        context,
        en: 'work',
        zhHans: '工作',
        zhHant: '工作',
        ja: '仕事',
      );
    case 'recovery':
      return AppLocaleText.tr(
        context,
        en: 'recovery',
        zhHans: '恢复',
        zhHant: '恢復',
        ja: '回復',
      );
    case 'relationship':
      return AppLocaleText.tr(
        context,
        en: 'relationship',
        zhHans: '关系',
        zhHant: '關係',
        ja: '関係',
      );
    case 'boundary':
      return AppLocaleText.tr(
        context,
        en: 'boundary',
        zhHans: '边界',
        zhHant: '邊界',
        ja: '境界線',
      );
    case 'emotional':
      return AppLocaleText.tr(
        context,
        en: 'emotional',
        zhHans: '情绪',
        zhHant: '情緒',
        ja: '感情',
      );
    case 'emotional_stability':
      return AppLocaleText.tr(
        context,
        en: 'emotional stability',
        zhHans: '情绪安定',
        zhHant: '情緒安定',
        ja: '感情の安定',
      );
    case 'home':
      return AppLocaleText.tr(
        context,
        en: 'home',
        zhHans: '居家',
        zhHant: '居家',
        ja: '家',
      );
    case 'sleep':
      return AppLocaleText.tr(
        context,
        en: 'sleep',
        zhHans: '睡眠',
        zhHant: '睡眠',
        ja: '睡眠',
      );
    case 'commute':
      return AppLocaleText.tr(
        context,
        en: 'commute',
        zhHans: '通勤',
        zhHant: '通勤',
        ja: '通勤',
      );
    case 'body':
      return AppLocaleText.tr(
        context,
        en: 'body',
        zhHans: '身体',
        zhHant: '身體',
        ja: '身体',
      );
    case 'money':
      return AppLocaleText.tr(
        context,
        en: 'money',
        zhHans: '金钱',
        zhHant: '金錢',
        ja: 'お金',
      );
    case 'future':
      return AppLocaleText.tr(
        context,
        en: 'future',
        zhHans: '未来',
        zhHant: '未來',
        ja: '未来',
      );
    case 'hobby':
      return AppLocaleText.tr(
        context,
        en: 'hobby',
        zhHans: '兴趣',
        zhHant: '興趣',
        ja: '趣味',
      );
    case 'rest':
      return AppLocaleText.tr(
        context,
        en: 'rest',
        zhHans: '休息',
        zhHant: '休息',
        ja: '休息',
      );
    case 'achievement':
      return AppLocaleText.tr(
        context,
        en: 'achievement',
        zhHans: '成就',
        zhHant: '成就',
        ja: '達成',
      );
    case 'self_doubt':
      return AppLocaleText.tr(
        context,
        en: 'self-doubt',
        zhHans: '自我怀疑',
        zhHant: '自我懷疑',
        ja: '自信の揺らぎ',
      );
    case 'daily_friction':
      return AppLocaleText.tr(
        context,
        en: 'daily friction',
        zhHans: '日常摩擦',
        zhHant: '日常摩擦',
        ja: '日常の摩擦',
      );
    case 'study':
      return AppLocaleText.tr(
        context,
        en: 'study',
        zhHans: '学习',
        zhHant: '學習',
        ja: '学習',
      );
    case 'daily_life':
      return AppLocaleText.tr(
        context,
        en: 'daily life',
        zhHans: '日常生活',
        zhHant: '日常生活',
        ja: '日常生活',
      );
    case 'friction':
      return AppLocaleText.tr(
        context,
        en: 'friction',
        zhHans: '摩擦',
        zhHant: '摩擦',
        ja: '摩擦',
      );
    case 'helpful':
      return AppLocaleText.tr(
        context,
        en: 'helpful',
        zhHans: '有帮助',
        zhHant: '有幫助',
        ja: '役に立った',
      );
    case 'weekly':
      return AppLocaleText.tr(
        context,
        en: 'weekly',
        zhHans: '每周复盘',
        zhHant: '每週複盤',
        ja: '毎週の振り返り',
      );
    case 'life':
      return AppLocaleText.tr(
        context,
        en: 'life',
        zhHans: '生活',
        zhHant: '生活',
        ja: '生活',
      );
    case 'unknown':
      return AppLocaleText.tr(
        context,
        en: 'Uncategorized',
        zhHans: '未分类',
        zhHant: '未分類',
        ja: '未分類',
      );
    default:
      return AppLocaleText.tr(
        context,
        en: 'Other',
        zhHans: '其他',
        zhHant: '其他',
        ja: 'その他',
      );
  }
}
