import 'package:flutter/material.dart';

import '../i18n/app_locale_text.dart';

class FocusDomainOption {
  final String id;
  final String en;
  final String zhHans;
  final String zhHant;
  final String ja;
  final String enDescription;
  final String zhHansDescription;
  final String zhHantDescription;
  final String jaDescription;
  final IconData icon;
  final Color color;

  const FocusDomainOption({
    required this.id,
    required this.en,
    required this.zhHans,
    required this.zhHant,
    required this.ja,
    required this.enDescription,
    required this.zhHansDescription,
    required this.zhHantDescription,
    required this.jaDescription,
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
      en: enDescription,
      zhHans: zhHansDescription,
      zhHant: zhHantDescription,
      ja: jaDescription,
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
      enDescription:
          'Anxiety, tension, loss of control, and low-stimulation recovery',
      zhHansDescription: '焦虑、紧绷、失控感与低刺激恢复',
      zhHantDescription: '焦慮、緊繃、失控感與低刺激恢復',
      jaDescription: '不安、緊張、制御できない感覚と低刺激での回復',
      icon: Icons.sentiment_satisfied_alt_rounded,
      color: Color(0xFFF3C85F),
    ),
    FocusDomainOption(
      id: 'relationship_connection',
      en: 'relationship connection',
      zhHans: '关系连接',
      zhHant: '關係連結',
      ja: '関係のつながり',
      enDescription: 'Feeling understood and accepted, closeness, and distance',
      zhHansDescription: '被理解、被接纳、靠近与疏离',
      zhHantDescription: '被理解、被接納、靠近與疏離',
      jaDescription: '理解や受容、近づくことと距離を置くこと',
      icon: Icons.groups_rounded,
      color: Color(0xFF8A7AF5),
    ),
    FocusDomainOption(
      id: 'meaning_value',
      en: 'meaning and value',
      zhHans: '价值意义',
      zhHant: '價值意義',
      ja: '価値と意味',
      enDescription: 'A sense of worth, presence, being seen, and meaning',
      zhHansDescription: '价值感、存在感、被看见与意义感',
      zhHantDescription: '價值感、存在感、被看見與意義感',
      jaDescription: '自分の価値、存在感、見てもらえる感覚と意味',
      icon: Icons.auto_awesome_rounded,
      color: Color(0xFF7F84FF),
    ),
    FocusDomainOption(
      id: 'self_boundary',
      en: 'self boundary',
      zhHans: '自我边界',
      zhHant: '自我邊界',
      ja: '自分の境界',
      enDescription:
          'Saying no, protecting your pace, and expressing real needs',
      zhHansDescription: '拒绝、保护节奏、表达真实需要',
      zhHantDescription: '拒絕、保護節奏、表達真實需要',
      jaDescription: '断ること、自分のペースを守ること、本当の必要を伝えること',
      icon: Icons.shield_rounded,
      color: Color(0xFF6D8CFF),
    ),
    FocusDomainOption(
      id: 'growth_plan',
      en: 'growth plan',
      zhHans: '成长计划',
      zhHant: '成長計劃',
      ja: '成長計画',
      enDescription: 'Goals, sticking points, practice, and next steps',
      zhHansDescription: '目标、卡点、练习与下一步',
      zhHantDescription: '目標、卡點、練習與下一步',
      jaDescription: '目標、つまずき、練習と次の一歩',
      icon: Icons.spa_rounded,
      color: Color(0xFF4FC7D6),
    ),
    FocusDomainOption(
      id: 'creative_expression',
      en: 'creative expression',
      zhHans: '创造表达',
      zhHant: '創造表達',
      ja: '創造と表現',
      enDescription: 'Ideas, writing, sharing, creative work, and viewpoints',
      zhHansDescription: '灵感、写作、输出、作品与观点',
      zhHantDescription: '靈感、寫作、輸出、作品與觀點',
      jaDescription: 'ひらめき、文章、発信、作品と考え',
      icon: Icons.brush_rounded,
      color: Color(0xFFE76AC1),
    ),
    FocusDomainOption(
      id: 'food_sleep',
      en: 'food and sleep',
      zhHans: '饮食睡眠',
      zhHant: '飲食睡眠',
      ja: '食事と睡眠',
      enDescription: 'Sleep, food, fatigue, and basic physical care',
      zhHansDescription: '睡眠、饮食、疲劳与身体基础照护',
      zhHantDescription: '睡眠、飲食、疲勞與身體基礎照護',
      jaDescription: '睡眠、食事、疲れと身体の基礎的なケア',
      icon: Icons.dark_mode_rounded,
      color: Color(0xFF6EA6FF),
    ),
    FocusDomainOption(
      id: 'living_environment',
      en: 'living environment',
      zhHans: '生活环境',
      zhHant: '生活環境',
      ja: '生活環境',
      enDescription: 'Home, money, health, order, and practical foundations',
      zhHansDescription: '居住、金钱、健康、秩序与现实支撑',
      zhHantDescription: '居住、金錢、健康、秩序與現實支撐',
      jaDescription: '住まい、お金、健康、秩序と現実的な支え',
      icon: Icons.home_rounded,
      color: Color(0xFF62D48F),
    ),
    FocusDomainOption(
      id: 'interests_hobbies',
      en: 'interests and hobbies',
      zhHans: '兴趣爱好',
      zhHant: '興趣愛好',
      ja: '興味と趣味',
      enDescription: 'Interests, travel, nature, movement, and vitality',
      zhHansDescription: '兴趣、旅行、自然、运动与生命感',
      zhHantDescription: '興趣、旅行、自然、運動與生命感',
      jaDescription: '興味、旅行、自然、運動と生きている感覚',
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

  /// Taxonomy tokens emitted by historical and current Signal classifiers.
  ///
  /// These are intentionally separate from [legacyMap]: legacy preferences
  /// are migrated by exact ID, while Signal evidence may contain scene or
  /// intent tokens that still need to project into the nine Focus Domains.
  static const _classificationAliases = <String, String>{
    'emotional': 'emotional_stability',
    'emotion': 'emotional_stability',
    'daily_friction': 'emotional_stability',
    'relationship': 'relationship_connection',
    'communication': 'relationship_connection',
    'meaning': 'meaning_value',
    'value': 'meaning_value',
    'self_doubt': 'meaning_value',
    'future': 'meaning_value',
    'boundary': 'self_boundary',
    'work': 'growth_plan',
    'planning': 'growth_plan',
    'scheduling': 'growth_plan',
    'information_gathering': 'growth_plan',
    'decision_making': 'growth_plan',
    'achievement': 'growth_plan',
    'execution': 'growth_plan',
    'study': 'growth_plan',
    'writing': 'creative_expression',
    'creative': 'creative_expression',
    'expression': 'creative_expression',
    'recovery': 'food_sleep',
    'sleep': 'food_sleep',
    'body': 'food_sleep',
    'rest': 'food_sleep',
    'fatigue': 'food_sleep',
    'home': 'living_environment',
    'commute': 'living_environment',
    'household': 'living_environment',
    'money': 'living_environment',
    'cost': 'living_environment',
    'daily_life': 'living_environment',
    'hobby': 'interests_hobbies',
    'interest': 'interests_hobbies',
    'travel': 'interests_hobbies',
    'nature': 'interests_hobbies',
    'movement': 'interests_hobbies',
  };

  static const _classificationKeywords = <String, List<String>>{
    'emotional_stability': [
      '情绪',
      '心情',
      '平静',
      '开心',
      '焦虑',
      '紧绷',
      '混乱',
      '不安',
      '感情',
      'emotion',
      'mood',
      'anxious',
      'stress',
    ],
    'relationship_connection': [
      '关系',
      '家人',
      '朋友',
      '同事',
      '伴侣',
      '沟通',
      '関係',
      '家族',
      '友達',
      'connection',
      'relationship',
      'communication',
    ],
    'meaning_value': [
      '意义',
      '价值',
      '方向',
      '被看见',
      '意味',
      '価値',
      'meaning',
      'value',
      'purpose',
    ],
    'self_boundary': [
      '边界',
      '拒绝',
      '自己的时间',
      '真实需要',
      '境界',
      '断る',
      'boundary',
      'say no',
    ],
    'growth_plan': [
      '成长',
      '计划',
      '学习',
      '推进',
      '目标',
      '下一步',
      '練習',
      '目標',
      '学習',
      'growth',
      'plan',
      'goal',
      'learn',
    ],
    'creative_expression': [
      '创造',
      '表达',
      '写作',
      '灵感',
      '作品',
      '創作',
      '表現',
      'creative',
      'writing',
      'expression',
    ],
    'food_sleep': [
      '饮食',
      '睡眠',
      '睡觉',
      '午餐',
      '吃饭',
      '休息',
      '恢复',
      '疲惫',
      '食事',
      '疲れ',
      'sleep',
      'food',
      'recovery',
      'tired',
    ],
    'living_environment': [
      '环境',
      '房间',
      '家里',
      '整理',
      '出门',
      '通勤',
      '金钱',
      '居住',
      '環境',
      '部屋',
      'お金',
      'environment',
      'home',
      'commute',
      'money',
    ],
    'interests_hobbies': [
      '兴趣',
      '爱好',
      '旅行',
      '自然',
      '运动',
      '音乐',
      '游戏',
      '趣味',
      'hobby',
      'interest',
      'travel',
      'nature',
    ],
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

  /// Classifies Signal evidence into exactly one of the nine canonical Focus
  /// Domains. Explicit stored IDs win over inferred scene/text evidence.
  static String classifyId({
    Iterable<String?> explicitIds = const [],
    Iterable<String?> taxonomyTokens = const [],
    Iterable<String?> textEvidence = const [],
    String fallbackId = 'emotional_stability',
  }) {
    final explicit = normalizeIds(explicitIds.map(_classificationToken));
    if (explicit.isNotEmpty) return explicit.first;

    for (final raw in taxonomyTokens) {
      final token = _classificationToken(raw);
      if (token.isEmpty || token == 'other' || token == 'unknown') continue;
      final canonical = normalizeIds([token]);
      if (canonical.isNotEmpty) return canonical.first;
      final alias = _classificationAliases[token];
      if (alias != null) return alias;
    }

    final text = [...taxonomyTokens, ...textEvidence]
        .whereType<String>()
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .join(' ');
    if (text.isNotEmpty) {
      for (final entry in _classificationKeywords.entries) {
        if (entry.value.any((keyword) => text.contains(keyword))) {
          return entry.key;
        }
      }
    }

    final fallback = normalizeIds([fallbackId]);
    return fallback.isEmpty ? 'emotional_stability' : fallback.first;
  }

  static String _classificationToken(String? raw) {
    return (raw ?? '').trim().toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');
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
