import 'package:flutter/material.dart';

import '../i18n/app_locale_text.dart';

class FocusDomainOption {
  final String id;
  final String en;
  final String zhHans;
  final String zhHant;
  final String ja;
  final String zhHansDescription;
  final IconData icon;
  final Color color;

  const FocusDomainOption({
    required this.id,
    required this.en,
    required this.zhHans,
    required this.zhHant,
    required this.ja,
    required this.zhHansDescription,
    required this.icon,
    required this.color,
  });

  String label(BuildContext context) {
    return AppLocaleText.tr(
      context,
      en: en,
      zhHans: zhHans,
      zhHant: zhHant,
      ja: ja,
    );
  }

  String description(BuildContext context) {
    return AppLocaleText.tr(
      context,
      en: zhHansDescription,
      zhHans: zhHansDescription,
      zhHant: zhHansDescription,
      ja: zhHansDescription,
    );
  }
}

class FocusDomains {
  static const String productPreferenceKey = 'selected_focus_domains';
  static const String preferenceKey = 'focus_domain_ids';
  static const String legacyRepeatAreaKey = 'repeat_area_preference';
  static const String legacySelectedRepeatAreaKey = 'selected_repeat_area';

  static const defaultIds = [
    'emotional_stability',
    'growth_plan',
    'food_sleep',
  ];

  static const options = [
    FocusDomainOption(
      id: 'emotional_stability',
      en: 'emotional stability',
      zhHans: '情绪安定',
      zhHant: '情緒安定',
      ja: '感情の安定',
      zhHansDescription: '焦虑、紧绷、失控感与低刺激恢复',
      icon: Icons.sentiment_satisfied_alt_rounded,
      color: Color(0xFFF3C85F),
    ),
    FocusDomainOption(
      id: 'relationship_connection',
      en: 'relationship connection',
      zhHans: '关系连接',
      zhHant: '關係連結',
      ja: '関係のつながり',
      zhHansDescription: '被理解、被接纳、靠近与疏离',
      icon: Icons.groups_rounded,
      color: Color(0xFF8A7AF5),
    ),
    FocusDomainOption(
      id: 'meaning_value',
      en: 'meaning and value',
      zhHans: '价值意义',
      zhHant: '價值意義',
      ja: '価値と意味',
      zhHansDescription: '价值感、存在感、被看见与意义感',
      icon: Icons.auto_awesome_rounded,
      color: Color(0xFF7F84FF),
    ),
    FocusDomainOption(
      id: 'self_boundary',
      en: 'self boundary',
      zhHans: '自我边界',
      zhHant: '自我邊界',
      ja: '自分の境界',
      zhHansDescription: '拒绝、保护节奏、表达真实需要',
      icon: Icons.shield_rounded,
      color: Color(0xFF6D8CFF),
    ),
    FocusDomainOption(
      id: 'growth_plan',
      en: 'growth plan',
      zhHans: '成长计划',
      zhHant: '成長計劃',
      ja: '成長計画',
      zhHansDescription: '目标、卡点、练习与下一步',
      icon: Icons.spa_rounded,
      color: Color(0xFF4FC7D6),
    ),
    FocusDomainOption(
      id: 'creative_expression',
      en: 'creative expression',
      zhHans: '创造表达',
      zhHant: '創造表達',
      ja: '創造と表現',
      zhHansDescription: '灵感、写作、输出、作品与观点',
      icon: Icons.brush_rounded,
      color: Color(0xFFE76AC1),
    ),
    FocusDomainOption(
      id: 'food_sleep',
      en: 'food and sleep',
      zhHans: '饮食睡眠',
      zhHant: '飲食睡眠',
      ja: '食事と睡眠',
      zhHansDescription: '睡眠、饮食、疲劳与身体基础照护',
      icon: Icons.dark_mode_rounded,
      color: Color(0xFF6EA6FF),
    ),
    FocusDomainOption(
      id: 'living_environment',
      en: 'living environment',
      zhHans: '生活环境',
      zhHant: '生活環境',
      ja: '生活環境',
      zhHansDescription: '居住、金钱、健康、秩序与现实支撑',
      icon: Icons.home_rounded,
      color: Color(0xFF62D48F),
    ),
    FocusDomainOption(
      id: 'interests_hobbies',
      en: 'interests and hobbies',
      zhHans: '兴趣爱好',
      zhHant: '興趣愛好',
      ja: '興味と趣味',
      zhHansDescription: '兴趣、旅行、自然、运动与生命感',
      icon: Icons.favorite_rounded,
      color: Color(0xFFFF77A8),
    ),
  ];

  static const legacyMap = {
    'work_tasks': 'growth_plan',
    'emotion_stress': 'emotional_stability',
    'relationships': 'relationship_connection',
    'time_rhythm': 'food_sleep',
    'health_body': 'food_sleep',
    'money_spending': 'living_environment',
    'learning_growth_expression': 'creative_expression',
    'open': 'emotional_stability',
  };

  static List<String> normalizeIds(Iterable<String?> rawIds) {
    final result = <String>[];
    final known = options.map((item) => item.id).toSet();
    for (final raw in rawIds) {
      final value = raw?.trim();
      if (value == null || value.isEmpty) continue;
      final mapped = legacyMap[value] ?? value;
      if (!known.contains(mapped) || result.contains(mapped)) continue;
      result.add(mapped);
    }
    return result;
  }

  static FocusDomainOption? optionFor(String? id) {
    final normalized = normalizeIds([id]);
    if (normalized.isEmpty) return null;
    for (final option in options) {
      if (option.id == normalized.first) return option;
    }
    return null;
  }

  static String labelFor(BuildContext context, String? id) {
    final option = optionFor(id);
    if (option == null) {
      return AppLocaleText.tr(
        context,
        en: 'not set yet',
        zhHans: '暂未设置',
        zhHant: '暫未設定',
        ja: '未設定',
      );
    }
    return option.label(context);
  }

  static String summaryLabel(BuildContext context, List<String> ids) {
    final normalized = normalizeIds(ids);
    if (normalized.isEmpty) return labelFor(context, null);
    final labels = normalized
        .take(3)
        .map((id) => labelFor(context, id))
        .where((label) => label.trim().isNotEmpty)
        .join(' / ');
    if (normalized.length <= 3) return labels;
    return AppLocaleText.tr(
      context,
      en: '$labels +${normalized.length - 3}',
      zhHans: '$labels 等 ${normalized.length} 项',
      zhHant: '$labels 等 ${normalized.length} 項',
      ja: '$labels ほか ${normalized.length - 3}件',
    );
  }
}
