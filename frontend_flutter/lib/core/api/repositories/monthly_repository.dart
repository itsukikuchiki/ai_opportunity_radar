import 'package:shared_preferences/shared_preferences.dart';

import '../../local/local_capture_repository.dart';
import '../../local/local_monthly_snapshot_repository.dart';
import '../../models/monthly_models.dart';
import '../../models/today_models.dart';
import 'ai_repository.dart';

typedef MonthlyFocusAreaLoader = Future<String?> Function();
typedef MonthlyInstallationDateLoader = Future<DateTime> Function();

class MonthlyRepository {
  final LocalCaptureRepository localCaptureRepository;
  final LocalMonthlySnapshotRepository localMonthlySnapshotRepository;
  final AiRepository aiRepository;
  final MonthlyFocusAreaLoader? focusAreaLoader;
  final MonthlyInstallationDateLoader? installationDateLoader;

  MonthlyRepository({
    required this.localCaptureRepository,
    required this.localMonthlySnapshotRepository,
    required this.aiRepository,
    this.focusAreaLoader,
    this.installationDateLoader,
  });

  Future<MonthlyReviewModel> fetchCurrentMonthly() async {
    final installationDate = await _readOrCreateInstallationDate();
    final today = _dateOnly(DateTime.now());

    final isFirstMonth =
        installationDate.year == today.year &&
        installationDate.month == today.month;

    final recentSignals =
        await localCaptureRepository.listRecentSignals(limit: 4000);

    if (isFirstMonth && recentSignals.isEmpty) {
      return MonthlyReviewModel(
        monthStart: _dateKey(DateTime(today.year, today.month, 1)),
        monthEnd: _dateKey(_monthEnd(today)),
        status: 'first_month_gate',
      );
    }

    final range = _currentMonthRange();
    final monthSignals = _filterSignalsForRange(
      recentSignals,
      range.start,
      range.end,
    );

    if (monthSignals.isEmpty) {
      return MonthlyReviewModel(
        monthStart: _dateKey(range.start),
        monthEnd: _dateKey(range.end),
        status: isFirstMonth ? 'first_month_gate' : 'insufficient_data',
      );
    }

    final stats = _buildMonthlyStats(monthSignals);
    final sourceHash = localMonthlySnapshotRepository.buildSourceHash(
      entries: stats.entries,
      weekCounts: stats.weekCounts,
      topTokens: stats.topTokens,
    );

    final monthStartKey = _dateKey(range.start);
    final cached =
        await localMonthlySnapshotRepository.getByMonthStart(monthStartKey);
    final cachedHash =
        await localMonthlySnapshotRepository.getSourceHash(monthStartKey);

    if (cached != null && cachedHash == sourceHash) {
      return cached;
    }

    final focusArea = await _readFocusArea();

    MonthlyReviewModel generated;
    try {
     generated = await aiRepository.generateMonthlyReview(
        monthStart: monthStartKey,
        monthEnd: _dateKey(range.end),
        entries: stats.entries,
        topTokens: stats.topTokens,
        focusArea: focusArea,
        totalDays: stats.totalDays,
      );
      generated = _normalizeGeneratedMonthly(
        generated: generated,
        range: range,
      );
    } catch (_) {
      generated = _buildFallbackMonthlyReview(
        range: range,
        stats: stats,
      );
    }

    await localMonthlySnapshotRepository.upsert(
      monthly: generated,
      sourceHash: sourceHash,
    );

    return generated;
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

  _MonthlyStats _buildMonthlyStats(List<RecentSignalModel> signals) {
    final entries = <Map<String, dynamic>>[];
    final tokenCounts = <String, int>{};
    final weekCounts = <String, int>{};

    for (final signal in signals) {
      final createdAt = signal.createdAt?.toLocal();
      if (createdAt == null) continue;

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

      for (final tag in signal.sceneTags) {
        final normalized = tag.trim();
        if (normalized.isNotEmpty) {
          tokenCounts[normalized] = (tokenCounts[normalized] ?? 0) + 1;
        }
      }

      final weekLabel = _weekLabelInMonth(createdAt);
      weekCounts[weekLabel] = (weekCounts[weekLabel] ?? 0) + 1;
    }

    final sortedTokens = tokenCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final dayKeys = signals
        .map((e) => e.createdAt?.toLocal())
        .whereType<DateTime>()
        .map((e) => _dateKey(e))
        .toSet();

    return _MonthlyStats(
      entries: entries,
      topTokens: sortedTokens.take(10).map((e) => e.key).toList(),
      totalDays: dayKeys.length,
      weekCounts: weekCounts,
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
      '今天',
      '就是',
      '一个',
      '有点',
      '然后',
      '最近',
      '一直',
      'また',
      'もう',
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

  MonthlyReviewModel _normalizeGeneratedMonthly({
    required MonthlyReviewModel generated,
    required _MonthRange range,
  }) {
    return MonthlyReviewModel(
      monthStart:
          generated.monthStart.isEmpty ? _dateKey(range.start) : generated.monthStart,
      monthEnd:
          generated.monthEnd.isEmpty ? _dateKey(range.end) : generated.monthEnd,
      status: generated.status.isEmpty ? 'ready' : generated.status,
      monthlySummary: generated.monthlySummary,
      repeatedThemes: generated.repeatedThemes,
      improvingSignals: generated.improvingSignals,
      unresolvedPoints: generated.unresolvedPoints,
      nextMonthWatch: generated.nextMonthWatch,
      weeklyBridges: generated.weeklyBridges,
    );
  }

  MonthlyReviewModel _buildFallbackMonthlyReview({
    required _MonthRange range,
    required _MonthlyStats stats,
  }) {
    final topToken =
        stats.topTokens.isEmpty ? '这个月的记录' : stats.topTokens.first;

    final bridgeItems = stats.weekCounts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return MonthlyReviewModel(
      monthStart: _dateKey(range.start),
      monthEnd: _dateKey(range.end),
      status: 'ready',
      monthlySummary: '这个月反复回来的主题更接近“$topToken”，说明它已经不是零散的小片段了。',
      repeatedThemes: stats.topTokens.take(3).map((e) => '“$e” 重复出现。').toList(),
      improvingSignals: const [
        '有些恢复方式正在慢慢变得更稳定。',
      ],
      unresolvedPoints: const [
        '高消耗场景还没有被完全拆开。',
      ],
      nextMonthWatch: '下个月先继续看，哪类场景最容易触发第一下消耗。',
      weeklyBridges: bridgeItems.isEmpty
          ? const [
              MonthlyBridgeWeekModel(
                label: 'Week 1',
                summary: '这个月已经开始形成可继续追踪的主题。',
              ),
            ]
          : bridgeItems
              .map(
                (e) => MonthlyBridgeWeekModel(
                  label: e.key,
                  summary: '${e.value} entries landed here.',
                ),
              )
              .toList(),
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
    const key = 'installation_date';
    final raw = prefs.getString(key);
    if (raw != null && raw.isNotEmpty) {
      return _dateOnly(DateTime.tryParse(raw) ?? DateTime.now());
    }

    final today = _dateOnly(DateTime.now());
    await prefs.setString(key, today.toIso8601String());
    return today;
  }

  _MonthRange _currentMonthRange() {
    final now = _dateOnly(DateTime.now());
    final start = DateTime(now.year, now.month, 1);
    final end = _monthEnd(now);
    return _MonthRange(start: start, end: end);
  }

  DateTime _monthEnd(DateTime date) {
    return DateTime(date.year, date.month + 1, 0);
  }

  String _weekLabelInMonth(DateTime date) {
    final weekIndex = ((date.day - 1) ~/ 7) + 1;
    return 'Week $weekIndex';
  }

  DateTime _dateOnly(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  String _dateKey(DateTime date) {
    final local = date.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd';
  }
}

class _MonthRange {
  final DateTime start;
  final DateTime end;

  const _MonthRange({
    required this.start,
    required this.end,
  });
}

class _MonthlyStats {
  final List<Map<String, dynamic>> entries;
  final List<String> topTokens;
  final int totalDays;
  final Map<String, int> weekCounts;

  const _MonthlyStats({
    required this.entries,
    required this.topTokens,
    required this.totalDays,
    required this.weekCounts,
  });
}
