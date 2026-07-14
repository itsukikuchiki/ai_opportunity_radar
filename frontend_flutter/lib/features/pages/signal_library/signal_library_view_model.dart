import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/api/repositories/analytics_repository.dart';
import '../../../core/api/repositories/signal_library_repository.dart';
import '../../../core/models/signal_library_models.dart';
import '../../../core/models/today_models.dart';

class SignalLibraryViewModel extends ChangeNotifier {
  final SignalLibraryRepository _repository;
  final AnalyticsRepository? _analyticsRepository;

  List<LibraryPatternModel> patterns = const [];
  bool loading = false;
  String selectedCategory = 'all';

  SignalLibraryViewModel(
    this._repository, {
    AnalyticsRepository? analyticsRepository,
  }) : _analyticsRepository = analyticsRepository;

  Future<void> load({String language = 'en'}) async {
    loading = true;
    notifyListeners();
    patterns = await _repository.listCuratedPatterns(language: language);
    unawaited(_analyticsRepository?.track(
      'signal_library_opened',
      properties: {
        'language': language,
        'pattern_count': patterns.length,
      },
    ));
    loading = false;
    notifyListeners();
  }

  List<LibraryPatternModel> get visiblePatterns {
    if (selectedCategory == 'all') return patterns;
    return patterns.where(_matchesSelectedCategory).toList(growable: false);
  }

  void selectCategory(String category) {
    if (selectedCategory == category) return;
    selectedCategory = category;
    unawaited(_analyticsRepository?.track(
      'signal_library_category_selected',
      properties: {'category': category},
    ));
    notifyListeners();
  }

  bool _matchesSelectedCategory(LibraryPatternModel pattern) {
    final haystack = [
      pattern.id,
      pattern.title,
      pattern.abstractPattern,
      pattern.energyLoadHint,
      pattern.possiblePositiveSignal,
      ...pattern.commonScenes,
      ...pattern.commonFrictions,
    ].join(' ').toLowerCase();

    bool containsAny(List<String> values) =>
        values.any((value) => haystack.contains(value.toLowerCase()));

    switch (selectedCategory) {
      case 'emotional_stability':
        return containsAny([
          'recovery',
          'recover',
          'rest',
          'emotion',
          'calm',
          'fatigue',
          'body',
          'sleep',
          '恢复',
          '恢復',
          '休息',
          '情绪',
          '情緒',
          '安定',
          '疲惫',
          '疲憊',
          '身体',
          '身體',
          '睡眠',
          '回復',
          '休息',
        ]);
      case 'relationship_connection':
        return containsAny([
          'relationship',
          'relationships',
          'communication',
          'connection',
          'boundary',
          '关系',
          '關係',
          '沟通',
          '溝通',
          '连接',
          '連結',
          '边界',
          '邊界',
          '関係',
          'コミュニケーション',
          'つながり',
          '境界',
        ]);
      case 'meaning_value':
        return containsAny([
          'meaning',
          'value',
          'purpose',
          'worth',
          'seen',
          '意义',
          '意義',
          '价值',
          '價值',
          '被看见',
          '被看見',
          '存在感',
          '意味',
          '価値',
        ]);
      case 'growth_plan':
        return containsAny([
          'work',
          'planning',
          'messages',
          'attention',
          'schedule',
          '工作',
          '安排',
          '消息',
          '注意力',
          '日程',
          'growth',
          'plan',
          '成长',
          '成長',
          '计划',
          '計劃',
          '予定',
          '仕事',
          'メッセージ',
          '注意',
        ]);
      case 'self_boundary':
        return containsAny([
          'boundary',
          'personal time',
          'freedom',
          'agency',
          '边界',
          '邊界',
          '自由',
          '个人时间',
          '個人時間',
          '境界',
          '自由感',
          '自分の時間',
        ]);
      case 'creative_expression':
        return containsAny([
          'creative',
          'creation',
          'expression',
          'writing',
          'idea',
          'output',
          '创造',
          '創造',
          '表达',
          '表達',
          '灵感',
          '靈感',
          '写作',
          '創作',
          '表現',
          'アイデア',
        ]);
      case 'food_sleep':
        return containsAny([
          'food',
          'sleep',
          'rest',
          'late-night',
          'night',
          'body',
          '饮食',
          '飲食',
          '睡眠',
          '休息',
          '深夜',
          '晚上',
          '身体',
          '身體',
          '食事',
        ]);
      case 'living_environment':
        return containsAny([
          'environment',
          'home',
          'money',
          'health',
          'order',
          '生活',
          '环境',
          '環境',
          '居住',
          '金钱',
          '金錢',
          '健康',
          '秩序',
          '生活環境',
          '住まい',
        ]);
      case 'interests_hobbies':
        return containsAny([
          'interest',
          'hobby',
          'travel',
          'nature',
          'sport',
          'ride',
          'horse',
          '兴趣',
          '興趣',
          '爱好',
          '愛好',
          '旅行',
          '自然',
          '运动',
          '運動',
          '骑马',
          '乗馬',
          '趣味',
        ]);
      default:
        return true;
    }
  }

  Future<RecentSignalModel?> respondToPattern({
    required LibraryPatternModel pattern,
    required String status,
    String? userText,
    bool addToTimeline = false,
  }) async {
    final signal = await _repository.respondToPattern(
      pattern: pattern,
      status: status,
      userText: userText,
      addToTimeline: addToTimeline,
    );
    if (signal != null) {
      unawaited(_analyticsRepository?.track(
        'signal_library_pattern_added',
        properties: {
          'pattern_id': pattern.id,
          'has_adjustment': userText?.trim().isNotEmpty == true &&
              userText!.trim() != pattern.abstractPattern.trim(),
          'generation_rule_version': 'signal_library_reference_v1',
        },
      ));
    }
    return signal;
  }
}
