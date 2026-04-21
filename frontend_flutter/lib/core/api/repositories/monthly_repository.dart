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
    final signals = await localCaptureRepository.listRecentSignals(limit: 4000);

    final range = _currentMonthRange();
    final monthSignals = _filterSignalsForRange(signals, range.start, range.end);
    final isFirstMonth = installationDate.year == today.year && installationDate.month == today.month;

    if (isFirstMonth && monthSignals.isEmpty) {
      return MonthlyReviewModel(
        monthStart: _dateKey(range.start),
        monthEnd: _dateKey(range.end),
        status: 'first_month_gate',
      );
    }

    if (monthSignals.isEmpty) {
      return MonthlyReviewModel(
        monthStart: _dateKey(range.start),
        monthEnd: _dateKey(range.end),
        status: 'insufficient_data',
      );
    }

    final stats = _buildMonthlyStats(monthSignals);
    final monthStartKey = _dateKey(range.start);
    final sourceHash = localMonthlySnapshotRepository.buildSourceHash(
      entries: stats.entries,
      weekCounts: stats.weekCounts,
      topTokens: stats.topTokens,
    );

    final cached = await localMonthlySnapshotRepository.getByMonthStart(monthStartKey);
    final cachedHash = await localMonthlySnapshotRepository.getSourceHash(monthStartKey);
    if (cached != null && cachedHash == sourceHash) {
      return cached;
    }

    final focusArea = await _readFocusArea();
    final isLight = stats.entries.length < 4 || stats.weekCounts.length < 2;

    MonthlyReviewModel generated;
    try {
      generated = await aiRepository.generateMonthlyReview(
        monthStart: monthStartKey,
        monthEnd: _dateKey(range.end),
        entries: stats.entries,
        weekCounts: stats.weekCounts,
        topTokens: stats.topTokens,
        focusArea: focusArea,
      );
      generated = _normalizeGeneratedMonthly(generated: generated, stats: stats, isLight: isLight);
    } catch (_) {
      generated = _buildFallbackMonthly(monthStartKey, _dateKey(range.end), stats, isLight);
    }

    await localMonthlySnapshotRepository.upsert(monthly: generated, sourceHash: sourceHash);
    return generated;
  }

  MonthlyReviewModel _normalizeGeneratedMonthly({
    required MonthlyReviewModel generated,
    required _MonthlyStats stats,
    required bool isLight,
  }) {
    return MonthlyReviewModel(
      monthStart: generated.monthStart,
      monthEnd: generated.monthEnd,
      status: isLight ? 'light_ready' : 'ready',
      monthlySummary: (generated.monthlySummary ?? '').trim().isEmpty
          ? _defaultSummary(stats, isLight)
          : generated.monthlySummary,
      repeatedThemes: generated.repeatedThemes.isEmpty
          ? [_fallbackTheme(stats)]
          : generated.repeatedThemes,
      improvingSignals: generated.improvingSignals.isEmpty
          ? ['Small recovery moments are starting to become easier to notice.']
          : generated.improvingSignals,
      unresolvedPoints: generated.unresolvedPoints.isEmpty
          ? ['The same draining scene is still coming back often enough to keep watching.']
          : generated.unresolvedPoints,
      nextMonthWatch: (generated.nextMonthWatch ?? '').trim().isEmpty
          ? 'Next month, keep watching what scene most often triggers ${_fallbackTheme(stats).toLowerCase()}.'
          : generated.nextMonthWatch,
      weeklyBridges: generated.weeklyBridges.isEmpty
          ? stats.weekCounts.entries.map((e) => MonthlyBridgeWeekModel(label: e.key, summary: '${e.value} entries were recorded in this week band.')).toList()
          : generated.weeklyBridges,
    );
  }

  MonthlyReviewModel _buildFallbackMonthly(String monthStart, String monthEnd, _MonthlyStats stats, bool isLight) {
    return MonthlyReviewModel(
      monthStart: monthStart,
      monthEnd: monthEnd,
      status: isLight ? 'light_ready' : 'ready',
      monthlySummary: _defaultSummary(stats, isLight),
      repeatedThemes: [_fallbackTheme(stats)],
      improvingSignals: const ['Some smaller recovery points are beginning to stand out.'],
      unresolvedPoints: const ['One repeated friction still seems to return across the month.'],
      nextMonthWatch: 'Next month, watch which repeated scene keeps consuming energy first.',
      weeklyBridges: stats.weekCounts.entries
          .map((e) => MonthlyBridgeWeekModel(label: e.key, summary: '${e.value} entries gathered in this week.'))
          .toList(),
    );
  }

  String _defaultSummary(_MonthlyStats stats, bool isLight) {
    final token = _fallbackTheme(stats);
    if (isLight) {
      return 'This month is still early, but several entries are already clustering around $token.';
    }
    return 'Across this month, the repeated pull is not random. Entries keep circling back to $token, while some small recovery moments also begin to appear.';
  }

  String _fallbackTheme(_MonthlyStats stats) {
    return stats.topTokens.isEmpty ? 'a repeated theme' : stats.topTokens.first;
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
      final weekLabel = _weekBucket(createdAt);
      weekCounts[weekLabel] = (weekCounts[weekLabel] ?? 0) + 1;
    }
    final sortedTokens = tokenCounts.entries.toList()..sort((a,b)=>b.value.compareTo(a.value));
    return _MonthlyStats(entries: entries, weekCounts: weekCounts, topTokens: sortedTokens.take(8).map((e)=>e.key).toList());
  }

  List<String> _tokenize(String content) {
    final normalized = content.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ').trim();
    if (normalized.isEmpty) return const [];
    final rawParts = normalized.split(RegExp(r'\s+'));
    const stopWords = {'the','and','for','this','that','today','又','今天','还是','そして','して','いる'};
    final tokens = <String>[];
    for (final part in rawParts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty || stopWords.contains(trimmed)) continue;
      if (trimmed.runes.length >= 2) tokens.add(trimmed);
    }
    return tokens;
  }

  List<RecentSignalModel> _filterSignalsForRange(List<RecentSignalModel> signals, DateTime start, DateTime end) {
    final endExclusive = end.add(const Duration(days: 1));
    return signals.where((signal) {
      final time = signal.createdAt?.toLocal();
      if (time == null) return false;
      return !time.isBefore(start) && time.isBefore(endExclusive);
    }).toList()..sort((a,b){
      final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aTime.compareTo(bTime);
    });
  }

  ({DateTime start, DateTime end}) _currentMonthRange() {
    final today = _dateOnly(DateTime.now());
    final start = DateTime(today.year, today.month, 1);
    final end = DateTime(today.year, today.month + 1, 0);
    return (start: start, end: end);
  }

  String _weekBucket(DateTime date) {
    final day = date.day;
    if (day <= 7) return 'Week 1';
    if (day <= 14) return 'Week 2';
    if (day <= 21) return 'Week 3';
    if (day <= 28) return 'Week 4';
    return 'Week 5';
  }

  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  String _dateKey(DateTime date) {
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '${date.year}-$mm-$dd';
  }

  Future<String?> _readFocusArea() async {
    if (focusAreaLoader != null) return focusAreaLoader!.call();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('repeat_area_preference');
  }

  Future<DateTime> _readOrCreateInstallationDate() async {
    if (installationDateLoader != null) return installationDateLoader!.call();
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString('app_installation_date');
    if (existing != null) {
      final parsed = DateTime.tryParse(existing);
      if (parsed != null) return _dateOnly(parsed.toLocal());
    }
    final now = _dateOnly(DateTime.now());
    await prefs.setString('app_installation_date', now.toIso8601String());
    return now;
  }
}

class _MonthlyStats {
  final List<Map<String, dynamic>> entries;
  final Map<String, int> weekCounts;
  final List<String> topTokens;

  _MonthlyStats({
    required this.entries,
    required this.weekCounts,
    required this.topTokens,
  });
}
