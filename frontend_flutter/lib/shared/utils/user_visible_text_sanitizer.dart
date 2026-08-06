import 'package:flutter/widgets.dart';

import '../../core/i18n/app_locale_text.dart';
import '../../core/i18n/energy_budget_text.dart';

/// Converts stable machine labels embedded in generated copy into the current
/// display language.
///
/// This is presentation-only: raw Signal data, source hashes and stored enum
/// values remain language-independent. Natural user-authored English is not
/// translated; only exact or quoted taxonomy values and unmistakable
/// snake_case identifiers are rewritten.
String localizeUserVisibleDynamicText(
  BuildContext context,
  String value,
) {
  if (value.trim().isEmpty) return value;
  return EnergyBudgetText.localizeCopy(context, value);
}

/// Keeps raw exception and transport messages out of localized product UI.
///
/// Those messages are still available to diagnostics and request logs. The
/// presentation layer only shows stable, reader-facing copy so a backend or
/// platform error cannot introduce an English fragment into another locale.
String localizeUserVisibleErrorText(
  BuildContext context,
  String? value,
) {
  final text = value?.trim() ?? '';
  final language = AppLocaleText.resolve(context);
  if (text.isNotEmpty &&
      !_looksTechnicalOrEnglish(text) &&
      _matchesDisplayLanguage(text, language)) {
    return text;
  }
  return switch (language) {
    AppLanguage.simplifiedChinese => '暂时无法完成，请稍后重试。',
    AppLanguage.traditionalChinese => '暫時無法完成，請稍後重試。',
    AppLanguage.japanese => '一時的に完了できませんでした。しばらくしてから再試行してください。',
    AppLanguage.english => 'Something went wrong. Please try again.',
  };
}

bool _matchesDisplayLanguage(String value, AppLanguage language) {
  final hasCjk = RegExp(r'[\u3400-\u9FFF]').hasMatch(value);
  final hasKana = RegExp(r'[\u3040-\u30FF]').hasMatch(value);
  return switch (language) {
    AppLanguage.english => !hasCjk && !hasKana,
    AppLanguage.japanese => hasKana,
    AppLanguage.simplifiedChinese || AppLanguage.traditionalChinese => !hasKana,
  };
}

bool _looksTechnicalOrEnglish(String value) {
  if (RegExp(r'\b(?:Exception|Error|failed|timeout|HTTP|SQL|Socket)\b',
          caseSensitive: false)
      .hasMatch(value)) {
    return true;
  }
  final withoutAllowedNames = value
      .replaceAll(RegExp(r'Signal Path', caseSensitive: false), '')
      .replaceAll(RegExp(r'\bSignal\b', caseSensitive: false), '');
  return RegExp(r'[A-Za-z]').hasMatch(withoutAllowedNames) ||
      RegExp(r'\b[a-z_]+(?:_[a-z_]+)+\b').hasMatch(value);
}

String? sanitizeUserVisibleAiText(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return null;
  final lower = text.toLowerCase();
  if (_blockedUserVisibleAiPhrases.any(lower.contains)) return null;
  return text;
}

/// Timeline acknowledgements are L1 Attune snapshots. Older app versions
/// could persist advice or a follow-up question in this field; keep that raw
/// value for audit/backup, but never surface it as today's one-line reply.
String? sanitizeTimelineAcknowledgement(String? value) {
  final text = sanitizeUserVisibleAiText(value);
  if (text == null) return null;
  final lower = text.toLowerCase();
  if (text.contains('?') || text.contains('？')) return null;
  if (_blockedTimelineAdvicePhrases.any(lower.contains)) return null;
  return text;
}

const _blockedUserVisibleAiPhrases = [
  '保存在本机',
  '保存在这台',
  '保存在這台',
  '保存在这台设备',
  '保存在這台設備',
  '本机保存',
  '本機保存',
  '网络恢复',
  '網路恢復',
  '同步完成',
  '等同步',
  '同步',
  '不会丢',
  '不會丟',
  '已私密',
  '观察里',
  '觀察裡',
  '重复输入',
  'saved on this device',
  'saved locally',
  'saved privately',
  'network recovers',
  'sync complete',
  'sync',
  'retry',
  '端末に保存',
  '同期',
  '从 ai 预判确认并加入时间线',
  '從 ai 預判確認並加入時間線',
  'ai 预判确认并加入时间线',
  'ai 預判確認並加入時間線',
  'confirmed from an ai prediction and added to your timeline',
  'ai予測から確認し、タイムラインに追加しました',
];

const _blockedTimelineAdvicePhrases = [
  '建议',
  '建議',
  '你可以',
  '可以先',
  '可以试',
  '可以試',
  '试试看',
  '試試看',
  '试试',
  '試試',
  '不妨',
  '下一步',
  '应该做',
  '應該做',
  '如果愿意',
  '如果願意',
  '继续说',
  '繼續說',
  '告诉我',
  '告訴我',
  '先把动作',
  '先把動作',
  '先做一个',
  '先做一個',
  '先选一个',
  '先選一個',
  'you should',
  'you can ',
  'try to ',
  'try this',
  'consider ',
  'if you want',
  'next step',
  'tell me',
  'say more',
  'why don\'t',
  'よければ',
  'してみ',
  'しましょう',
  'してください',
  'どうですか',
  '話して',
  '教えて',
  '次に',
];
