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
    return pattern.focusDomainId == selectedCategory;
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
