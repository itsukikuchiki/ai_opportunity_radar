import 'package:shared_preferences/shared_preferences.dart';

import '../../local/local_capture_repository.dart';
import '../../local/local_weekly_snapshot_repository.dart';
import '../../models/today_models.dart';
import '../../models/weekly_models.dart';
import 'ai_repository.dart';

typedef WeeklyFocusAreaLoader = Future<String?> Function();
typedef InstallationDateLoader = Future<DateTime> Function();

class WeeklyRepository {
  final LocalCaptureRepository localCaptureRepository;
  final LocalWeeklySnapshotRepository localWeeklySnapshotRepository;
  final AiRepository aiRepository;
  final WeeklyFocusAreaLoader? focusAreaLoader;
  final InstallationDateLoader? installationDateLoader;

  WeeklyRepository({
    required this.localCaptureRepository,
    required this.localWeeklySnapshotRepository,
    required this.aiRepository,
    this.focusAreaLoader,
    this.installationDateLoader,
  });

  Future<WeeklyInsightModel> fetchCurrentWeekly() async {
    final installationDate = await _readOrCreateInstallationDate();
    final today = _dateOnly(DateTime.now());
    final isFirstDay = _sameDay(installationDate, today);

    final recentSignals = await localCaptureRepository.listRecentSignals(
      limit: 500,
    );

    if (isFirstDay && recentSignals.isEmpty) {
      return WeeklyInsightModel(
        weekStart: _dateKey(today.subtract(const Duration(days: 6))),
        weekEnd: _dateKey(today),
        status: 'first_day_gate',
        keyInsight: null,
        patterns: const [],
        frictions: const [],
        bestAction: null,
        opportunitySnapshot: null,
        feedbackSubmitted: false,
        chartData: _buildChartDataForEmptyRange(
          start: today.subtract(const Duration(days: 6)),
          end: today,
        ),
      );
    }

    final range = _currentWeekRange();
    final weekSignals = _filterSignalsForRange(
      recentSignals,
      range.start,
      range.end,
    );

    if (weekSignals.isEmpty) {
      return WeeklyInsightModel(
        weekStart: _dateKey(range.start),
        weekEnd: _dateKey(range.end),
        status: 'insufficient_data',
        keyInsight: null,
        patterns: const [],
        frictions: const [],
        bestAction: null,
        opportunitySnapshot: null,
        feedbackSubmitted: false,
        chartData: _buildChartDataForEmptyRange(
          start: range.start,
          end: range.end,
        ),
      );
    }

    final stats = _buildWeeklyStats(weekSignals);
    final sourceHash = localWeeklySnapshotRepository.buildSourceHash(
      entries: stats.entries,
      dayCounts: stats.dayCounts,
      topTokens: stats.topTokens,
    );

    final weekStartKey = _dateKey(range.start);
    final cached = await localWeeklySnapshotRepository.getByWeekStart(
      weekStartKey,
    );
    final cachedHash = await localWeeklySnapshotRepository.getSourceHash(
      weekStartKey,
    );

    if (cached != null && cachedHash == sourceHash) {
      return cached;
    }

    final focusArea = await _readFocusArea();
    final isLightWeekly = _isLightWeekly(stats);

    WeeklyInsightModel generated;
    try {
      generated = await aiRepository.generateWeeklySummary(
        weekStart: weekStartKey,
        weekEnd: _dateKey(range.end),
        entries: stats.entries,
        dayCounts: stats.dayCounts,
        topTokens: stats.topTokens,
        focusArea: focusArea,
      );
      generated = _normalizeGeneratedWeekly(
        generated: generated,
        stats: stats,
        isLightWeekly: isLightWeekly,
      );
    } catch (_) {
      generated = _buildFallbackWeeklyInsight(
        weekStart: weekStartKey,
        weekEnd: _dateKey(range.end),
        stats: stats,
        isLightWeekly: isLightWeekly,
      );
    }

    await localWeeklySnapshotRepository.upsert(
      weekly: generated,
      sourceHash: sourceHash,
    );

    return generated;
  }


  Future<DeepWeeklyModel> fetchDeepWeekly() async {
    final weekly = await fetchCurrentWeekly();
    final focusArea = await _readFocusArea();
    return aiRepository.generateDeepWeekly(
      weekly: weekly,
      focusArea: focusArea,
    );
  }

  Future<void> submitWeeklyFeedback({
    required String weekStart,
    required String feedbackValue,
  }) async {
    await localWeeklySnapshotRepository.markFeedbackSubmitted(weekStart);
  }

  List<RecentSignalModel> _filterSignalsForRange(
    List<RecentSignalModel> signals,
    DateTime start,
    DateTime end,
  ) {
    final endExclusive = end.add(const Duration(days: 1));

    return signals.where((signal) {
      final time = signal.createdAt?.toLocal();
      if (time == null) return false;
      return !time.isBefore(start) && time.isBefore(endExclusive);
    }).toList()
      ..sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aTime.compareTo(bTime);
      });
  }

  _WeeklyStats _buildWeeklyStats(List<RecentSignalModel> signals) {
    final entries = <Map<String, dynamic>>[];
    final dayCounts = <String, int>{};
    final tokenCounts = <String, int>{};
    final chartDataMap = <String, _ChartAccumulator>{};

    for (final signal in signals) {
      final createdAt = signal.createdAt?.toLocal();
      if (createdAt == null) continue;

      final dayKey = _dateKey(createdAt);
      dayCounts[dayKey] = (dayCounts[dayKey] ?? 0) + 1;

      entries.add({
        'id': signal.id,
        'content': signal.content,
        'created_at': createdAt.toUtc().toIso8601String(),
        'acknowledgement': signal.acknowledgement,
        'observation': signal.observation,
        'try_next': signal.tryNext,
        'emotion': signal.emotion,
        'intensity': signal.intensity,
        'scene_tags': signal.sceneTags,
        'intent_tags': signal.intentTags,
      });

      for (final token in _tokenize(signal.content)) {
        tokenCounts[token] = (tokenCounts[token] ?? 0) + 1;
      }

      final bucket = chartDataMap.putIfAbsent(dayKey, () => _ChartAccumulator());
      bucket.signalCount += 1;
      bucket.moodScore += _emotionToMoodScore(signal.emotion);
      bucket.frictionScore += _emotionToFrictionScore(signal.emotion);
      if ((signal.emotion ?? '') == 'positive' || (signal.emotion ?? '') == 'mixed') {
        bucket.hasPositiveSignal = true;
      }
    }

    final sortedTokens = tokenCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final chartData = chartDataMap.entries.map((entry) {
      final bucket = entry.value;
      final count = bucket.signalCount == 0 ? 1 : bucket.signalCount;
      return WeeklyChartPointModel(
        date: entry.key,
        signalCount: bucket.signalCount,
        moodScore: double.parse((bucket.moodScore / count).toStringAsFixed(3)),
        frictionScore: double.parse((bucket.frictionScore / count).toStringAsFixed(3)),
        hasPositiveSignal: bucket.hasPositiveSignal,
      );
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return _WeeklyStats(
      entries: entries,
      dayCounts: dayCounts,
      topTokens: sortedTokens.take(8).map((e) => e.key).toList(),
      chartData: chartData,
    );
  }

  List<String> _tokenize(String content) {
    final normalized = content
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
        .trim();

    if (normalized.isEmpty) return const [];

    final rawParts = normalized.split(RegExp(r'\s+'));
    const stopWords = {
      'the',
      'and',
      'for',
      'that',
      'this',
      'with',
      'have',
      'just',
      'today',
      'then',
      '又',
      '还是',
      '今天',
      '就是',
      '一个',
      '有点',
      '然后',
      'して',
      'いる',
      'こと',
      'もの',
      'これ',
      'それ',
      'ただ',
    };

    return rawParts
        .where((e) => e.trim().isNotEmpty)
        .where((e) => e.runes.length >= 2)
        .where((e) => !stopWords.contains(e))
        .toList();
  }

  bool _isLightWeekly(_WeeklyStats stats) {
    final signalCount = stats.entries.length;
    final activeDays = stats.dayCounts.keys.length;
    return signalCount > 0 && (signalCount < 4 || activeDays < 2);
  }

  WeeklyInsightModel _normalizeGeneratedWeekly({
    required WeeklyInsightModel generated,
    required _WeeklyStats stats,
    required bool isLightWeekly,
  }) {
    if (!isLightWeekly) {
      return WeeklyInsightModel(
        weekStart: generated.weekStart,
        weekEnd: generated.weekEnd,
        status: 'ready',
        keyInsight: generated.keyInsight,
        patterns: generated.patterns,
        frictions: generated.frictions,
        bestAction: generated.bestAction,
        opportunitySnapshot: generated.opportunitySnapshot,
        feedbackSubmitted: generated.feedbackSubmitted,
        chartData: generated.chartData.isNotEmpty ? generated.chartData : stats.chartData,
      );
    }

    return WeeklyInsightModel(
      weekStart: generated.weekStart,
      weekEnd: generated.weekEnd,
      status: 'light_ready',
      keyInsight: _lightenKeyInsight(
        generated.keyInsight,
        topToken: stats.topTokens.isEmpty ? null : stats.topTokens.first,
      ),
      patterns: _lightenItems(
        generated.patterns,
        fallbackName: '这周先冒头的线索',
      ),
      frictions: _lightenItems(
        generated.frictions,
        fallbackName: '这周先看到的消耗点',
      ),
      bestAction: generated.bestAction?.trim().isNotEmpty == true
          ? generated.bestAction
          : '这周先别急着总结完整，只要继续记下重复出现的场景就可以。',
      opportunitySnapshot: generated.opportunitySnapshot ??
          const {
            'name': '先把线索留住',
            'summary': '现在更适合先继续收集线索，等轮廓再清楚一点，再判断值不值得进一步整理。',
          },
      feedbackSubmitted: generated.feedbackSubmitted,
      chartData: generated.chartData.isNotEmpty ? generated.chartData : stats.chartData,
    );
  }

  Future<String?> _readFocusArea() async {
    if (focusAreaLoader != null) {
      return focusAreaLoader!();
    }

    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('repeat_area_preference') ??
        prefs.getString('selected_repeat_area');
  }

  Future<DateTime> _readOrCreateInstallationDate() async {
    if (installationDateLoader != null) {
      return _dateOnly(await installationDateLoader!());
    }

    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString('local_app_started_date');
    if (existing != null && existing.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(existing);
      if (parsed != null) {
        return _dateOnly(parsed);
      }
    }

    final today = _dateOnly(DateTime.now());
    await prefs.setString('local_app_started_date', today.toIso8601String());
    return today;
  }

  _WeekRange _currentWeekRange() {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day);
    final start = end.subtract(const Duration(days: 6));
    return _WeekRange(start: start, end: end);
  }

  DateTime _dateOnly(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  bool _sameDay(DateTime a, DateTime b) {
    final aa = _dateOnly(a);
    final bb = _dateOnly(b);
    return aa.year == bb.year && aa.month == bb.month && aa.day == bb.day;
  }

  String _dateKey(DateTime date) {
    final local = date.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd';
  }

  WeeklyInsightModel _buildFallbackWeeklyInsight({
    required String weekStart,
    required String weekEnd,
    required _WeeklyStats stats,
    required bool isLightWeekly,
  }) {
    final topToken = stats.topTokens.isEmpty ? '本周记录' : stats.topTokens.first;
    final peakDay = _resolvePeakDay(stats.dayCounts);

    if (isLightWeekly) {
      return WeeklyInsightModel(
        weekStart: weekStart,
        weekEnd: weekEnd,
        status: 'light_ready',
        keyInsight: '这周已经开始有线索冒出来了，目前最明显的是“$topToken”。',
        patterns: [
          {
            'name': '这周先冒头的线索',
            'summary': '记录还不多，但已经能看见一个开始重复的方向。',
          },
        ],
        frictions: [
          {
            'name': '这周先看到的消耗点',
            'summary': '现在更适合先轻轻看着，还不急着下太重的判断。',
          },
        ],
        bestAction: '这周先别急着总结完整，只要继续记下重复出现的场景就可以。',
        opportunitySnapshot: const {
          'name': '先把线索留住',
          'summary': '现在更适合先继续收集线索，等轮廓再清楚一点，再判断值不值得进一步整理。',
        },
        feedbackSubmitted: false,
        chartData: stats.chartData,
      );
    }

    return WeeklyInsightModel(
      weekStart: weekStart,
      weekEnd: weekEnd,
      status: 'ready',
      keyInsight: '这周的记录开始围绕“$topToken”聚集，$peakDay 的信号更密集。',
      patterns: [
        {
          'name': '重复出现的主题',
          'summary': '这周有一些内容在反复出现，说明它已经不只是一次性的瞬间。',
        },
        {
          'name': '高频关键词：$topToken',
          'summary': '从本地统计看，这个主题在这周尤其明显。',
        },
      ],
      frictions: [
        {
          'name': '本周的主要消耗',
          'summary': '当前最大的摩擦，更像是同类事情反复回来，而不是单次事件。',
        },
      ],
      bestAction: '这周先试一步：下次再出现同类情况时，用一句话补记它发生在什么场景。',
      opportunitySnapshot: const {
        'name': '把重复信号固定下来',
        'summary': '如果某类事情总是回来，它可能值得先被结构化记录。',
      },
      feedbackSubmitted: false,
      chartData: stats.chartData,
    );
  }

  String _lightenKeyInsight(String? input, {String? topToken}) {
    if (input != null && input.trim().isNotEmpty) {
      return input;
    }
    if (topToken != null && topToken.trim().isNotEmpty) {
      return '这周已经开始有线索冒出来了，目前最明显的是“$topToken”。';
    }
    return '这周已经开始有线索冒出来了，不过现在更适合先轻轻看着。';
  }

  List<dynamic> _lightenItems(List<dynamic> items, {required String fallbackName}) {
    if (items.isEmpty) {
      return [
        {
          'name': fallbackName,
          'summary': '记录还不多，但已经能看见一个开始重复的方向。',
        },
      ];
    }

    return items.take(2).map((item) {
      if (item is Map<String, dynamic>) {
        return {
          'name': (item['name'] as String?) ?? fallbackName,
          'summary': (item['summary'] as String?) ??
              '线索已经出现了，但还不适合下太重的判断。',
        };
      }
      if (item is Map) {
        return {
          'name': (item['name']?.toString()) ?? fallbackName,
          'summary': (item['summary']?.toString()) ??
              '线索已经出现了，但还不适合下太重的判断。',
        };
      }
      return {
        'name': fallbackName,
        'summary': '线索已经出现了，但还不适合下太重的判断。',
      };
    }).toList();
  }

  String _resolvePeakDay(Map<String, int> dayCounts) {
    if (dayCounts.isEmpty) return '这周';
    final entries = dayCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.first.key;
  }

  double _emotionToMoodScore(String? emotion) {
    switch (emotion) {
      case 'positive':
        return 1.0;
      case 'mixed':
        return 0.2;
      case 'negative':
        return -1.0;
      default:
        return 0.0;
    }
  }

  double _emotionToFrictionScore(String? emotion) {
    switch (emotion) {
      case 'negative':
        return 1.0;
      case 'mixed':
        return 0.6;
      case 'positive':
        return 0.0;
      default:
        return 0.2;
    }
  }

  List<WeeklyChartPointModel> _buildChartDataForEmptyRange({
    required DateTime start,
    required DateTime end,
  }) {
    final result = <WeeklyChartPointModel>[];
    var cursor = start;
    while (!cursor.isAfter(end)) {
      result.add(
        WeeklyChartPointModel(
          date: _dateKey(cursor),
          signalCount: 0,
          moodScore: 0,
          frictionScore: 0,
          hasPositiveSignal: false,
        ),
      );
      cursor = cursor.add(const Duration(days: 1));
    }
    return result;
  }
}

class _WeeklyStats {
  final List<Map<String, dynamic>> entries;
  final Map<String, int> dayCounts;
  final List<String> topTokens;
  final List<WeeklyChartPointModel> chartData;

  _WeeklyStats({
    required this.entries,
    required this.dayCounts,
    required this.topTokens,
    required this.chartData,
  });
}

class _WeekRange {
  final DateTime start;
  final DateTime end;

  _WeekRange({
    required this.start,
    required this.end,
  });
}

class _ChartAccumulator {
  int signalCount = 0;
  double moodScore = 0;
  double frictionScore = 0;
  bool hasPositiveSignal = false;
}
