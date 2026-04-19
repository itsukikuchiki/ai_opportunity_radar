import 'package:shared_preferences/shared_preferences.dart';

import '../../local/local_capture_repository.dart';
import '../../local/local_journey_snapshot_repository.dart';
import '../../models/memory_models.dart';
import '../../models/today_models.dart';
import 'ai_repository.dart';

typedef MemoryFocusAreaLoader = Future<String?> Function();
typedef JourneyInstallationDateLoader = Future<DateTime> Function();

class MemoryFetchResult {
  final MemorySummaryModel? summary;
  final bool isFirstDayGate;

  const MemoryFetchResult({
    required this.summary,
    required this.isFirstDayGate,
  });
}

class MemoryRepository {
  final LocalCaptureRepository localCaptureRepository;
  final LocalJourneySnapshotRepository localJourneySnapshotRepository;
  final AiRepository aiRepository;
  final MemoryFocusAreaLoader? focusAreaLoader;
  final JourneyInstallationDateLoader? installationDateLoader;

  MemoryRepository({
    required this.localCaptureRepository,
    required this.localJourneySnapshotRepository,
    required this.aiRepository,
    this.focusAreaLoader,
    this.installationDateLoader,
  });

  Future<MemoryFetchResult> fetchMemorySummaryResult() async {
    final installationDate = await _readOrCreateInstallationDate();
    final today = _dateOnly(DateTime.now());
    final isFirstDay = _sameDay(installationDate, today);

    final signals = await localCaptureRepository.listRecentSignals(limit: 2000);
    if (signals.isEmpty) {
      return MemoryFetchResult(
        summary: null,
        isFirstDayGate: isFirstDay,
      );
    }

    final sortedSignals = [...signals]
      ..sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aTime.compareTo(bTime);
      });

    final stats = _buildJourneyStats(sortedSignals);
    final snapshotDate = _dateKey(today);
    final sourceHash = localJourneySnapshotRepository.buildSourceHash(
      entries: stats.entries,
      topTokens: stats.topTokens,
      totalDays: stats.totalDays,
    );

    final cached = await localJourneySnapshotRepository.getByDate(snapshotDate);
    final cachedHash =
        await localJourneySnapshotRepository.getSourceHash(snapshotDate);

    if (cached != null && cachedHash == sourceHash) {
      return MemoryFetchResult(
        summary: cached,
        isFirstDayGate: false,
      );
    }

    final focusArea = await _readFocusArea();

    MemorySummaryModel generated;
    try {
      generated = await aiRepository.generateJourneySummary(
        snapshotDate: snapshotDate,
        entries: stats.entries,
        topTokens: stats.topTokens,
        totalDays: stats.totalDays,
        focusArea: focusArea,
      );
      generated = _normalizeJourneySummary(
        generated: generated,
        stats: stats,
      );
    } catch (_) {
      generated = _buildFallbackJourneySummary(stats);
    }

    await localJourneySnapshotRepository.upsert(
      snapshotDate: snapshotDate,
      summary: generated,
      sourceHash: sourceHash,
    );

    return MemoryFetchResult(
      summary: generated,
      isFirstDayGate: false,
    );
  }

  Future<MemorySummaryModel?> fetchMemorySummary() async {
    final result = await fetchMemorySummaryResult();
    return result.summary;
  }

  _JourneyStats _buildJourneyStats(List<RecentSignalModel> signals) {
    final entries = <Map<String, dynamic>>[];
    final tokenCounts = <String, int>{};
    final dayKeys = <String>{};

    for (final signal in signals) {
      final createdAt = signal.createdAt?.toLocal();
      if (createdAt == null) continue;

      final dayKey = _dateKey(createdAt);
      dayKeys.add(dayKey);

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
    }

    final sortedTokens = tokenCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final first = signals.first.createdAt?.toLocal();
    final last = signals.last.createdAt?.toLocal();
    final totalDays = (first == null || last == null)
        ? 1
        : DateTime(last.year, last.month, last.day)
                .difference(DateTime(first.year, first.month, first.day))
                .inDays +
            1;

    return _JourneyStats(
      entries: entries,
      topTokens: sortedTokens.take(10).map((e) => e.key).toList(),
      totalDays: totalDays,
      activeDays: dayKeys.length,
      entryCount: entries.length,
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

  MemorySummaryModel _normalizeJourneySummary({
    required MemorySummaryModel generated,
    required _JourneyStats stats,
  }) {
    return MemorySummaryModel(
      patterns: _normalizeSignalItems(
        items: generated.patterns,
        fallbackLabel: '反复出现的主题',
        stats: stats,
        preferStable: true,
      ),
      frictions: _normalizeSignalItems(
        items: generated.frictions,
        fallbackLabel: '持续性的摩擦',
        stats: stats,
        preferStable: false,
      ),
      desires: _normalizeSignalItems(
        items: generated.desires,
        fallbackLabel: '还在浮现的方向',
        stats: stats,
        preferStable: false,
      ),
      experiments: _normalizeSignalItems(
        items: generated.experiments,
        fallbackLabel: '开始有帮助的东西',
        stats: stats,
        preferStable: false,
      ),
    );
  }

  List<JourneySignalItemModel> _normalizeSignalItems({
    required List<JourneySignalItemModel> items,
    required String fallbackLabel,
    required _JourneyStats stats,
    required bool preferStable,
  }) {
    if (items.isEmpty) {
      return [
        JourneySignalItemModel(
          name: fallbackLabel,
          summary: _defaultSignalSummary(
            fallbackLabel: fallbackLabel,
            stats: stats,
          ),
          signalLevel: _resolveSignalLevel(
            entryCount: stats.entryCount,
            activeDays: stats.activeDays,
            preferStable: preferStable,
          ),
        ),
      ];
    }

    return items.map((item) {
      final signalLevel = item.signalLevel.trim().isEmpty
          ? _resolveSignalLevel(
              entryCount: stats.entryCount,
              activeDays: stats.activeDays,
              preferStable: preferStable,
            )
          : item.signalLevel;

      return JourneySignalItemModel(
        name: item.name.trim().isEmpty ? fallbackLabel : item.name,
        summary: item.summary.trim().isEmpty
            ? _defaultSignalSummary(
                fallbackLabel: fallbackLabel,
                stats: stats,
              )
            : item.summary,
        signalLevel: signalLevel,
      );
    }).toList();
  }

  String _resolveSignalLevel({
    required int entryCount,
    required int activeDays,
    required bool preferStable,
  }) {
    if (entryCount >= 4 && activeDays >= 3 && preferStable) {
      return 'stable_mode';
    }
    if (entryCount >= 3 || activeDays >= 2) {
      return 'repeated_pattern';
    }
    return 'weak_signal';
  }

  String _defaultSignalSummary({
    required String fallbackLabel,
    required _JourneyStats stats,
  }) {
    final topToken = stats.topTokens.isEmpty ? '最近的记录' : stats.topTokens.first;

    if (stats.entryCount <= 1) {
      return '现在还只是一个刚刚冒头的线索，先继续看看它会不会再出现。';
    }
    if (stats.entryCount < 4 || stats.activeDays < 2) {
      return '这个方向已经不止一次出现了，开始值得继续留意。';
    }
    return '一路看下来，“$topToken”已经不只是偶然，而开始形成更稳定的节奏。';
  }

  MemorySummaryModel _buildFallbackJourneySummary(_JourneyStats stats) {
    final topToken = stats.topTokens.isEmpty ? '最近的记录' : stats.topTokens.first;
    final weakOrRepeated = _resolveSignalLevel(
      entryCount: stats.entryCount,
      activeDays: stats.activeDays,
      preferStable: false,
    );
    final stableOrRepeated = _resolveSignalLevel(
      entryCount: stats.entryCount,
      activeDays: stats.activeDays,
      preferStable: true,
    );

    return MemorySummaryModel(
      patterns: [
        JourneySignalItemModel(
          name: '反复出现的主题',
          summary: stats.entryCount <= 1
              ? '“$topToken”刚刚出现一次，先把它作为一个值得继续留意的线索放着。'
              : stats.entryCount < 4 || stats.activeDays < 2
                  ? '一路看下来，“$topToken”已经不止一次出现，开始像一个重复主题了。'
                  : '一路看下来，“$topToken”已经不止一次地出现，正在慢慢形成稳定模式。',
          signalLevel: stableOrRepeated,
        ),
      ],
      frictions: [
        JourneySignalItemModel(
          name: '持续性的摩擦',
          summary: stats.entryCount <= 1
              ? '现在还只是一个初步摩擦点，先继续看它会不会在别的场景里再出现。'
              : stats.entryCount < 4 || stats.activeDays < 2
                  ? '这段时间里，有些消耗已经不是一次性的，而是在开始重复回来。'
                  : '这段时间里，某些同类问题已经不是一次性，而是在慢慢累积成稳定摩擦。',
          signalLevel: weakOrRepeated,
        ),
      ],
      desires: [
        JourneySignalItemModel(
          name: '还在浮现的方向',
          summary: stats.totalDays <= 1
              ? '现在还只是一个很轻的方向感，继续记录会更清楚。'
              : '记录已经跨越 ${stats.totalDays} 天，一些真正长期在意的方向正在慢慢浮现。',
          signalLevel: weakOrRepeated,
        ),
      ],
      experiments: [
        JourneySignalItemModel(
          name: '开始有帮助的东西',
          summary: stats.entryCount <= 1
              ? '现在还太早，不过之后会更容易看见什么正在慢慢对你起作用。'
              : '继续记录下去，会更容易看见什么做法不是偶然有效，而是在慢慢变得有帮助。',
          signalLevel: weakOrRepeated,
        ),
      ],
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
}

class _JourneyStats {
  final List<Map<String, dynamic>> entries;
  final List<String> topTokens;
  final int totalDays;
  final int activeDays;
  final int entryCount;

  _JourneyStats({
    required this.entries,
    required this.topTokens,
    required this.totalDays,
    required this.activeDays,
    required this.entryCount,
  });
}
