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
    } catch (_) {
      generated = _buildFallbackWeeklyInsight(
        weekStart: weekStartKey,
        weekEnd: _dateKey(range.end),
        stats: stats,
      );
    }

    await localWeeklySnapshotRepository.upsert(
      weekly: generated,
      sourceHash: sourceHash,
    );

    return generated;
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
      });

      for (final token in _tokenize(signal.content)) {
        tokenCounts[token] = (tokenCounts[token] ?? 0) + 1;
      }
    }

    final sortedTokens = tokenCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _WeeklyStats(
      entries: entries,
      dayCounts: dayCounts,
      topTokens: sortedTokens.take(8).map((e) => e.key).toList(),
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
  }) {
    final topToken =
        stats.topTokens.isEmpty ? '本周记录' : stats.topTokens.first;
    final peakDay = _resolvePeakDay(stats.dayCounts);

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
    );
  }

  String _resolvePeakDay(Map<String, int> dayCounts) {
    if (dayCounts.isEmpty) return '这周';
    final entries = dayCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.first.key;
  }
}

class _WeekRange {
  final DateTime start;
  final DateTime end;

  _WeekRange({
    required this.start,
    required this.end,
  });
}

class _WeeklyStats {
  final List<Map<String, dynamic>> entries;
  final Map<String, int> dayCounts;
  final List<String> topTokens;

  _WeeklyStats({
    required this.entries,
    required this.dayCounts,
    required this.topTokens,
  });
}
