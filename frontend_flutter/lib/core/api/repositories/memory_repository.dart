import 'package:shared_preferences/shared_preferences.dart';

import '../../local/local_capture_repository.dart';
import '../../local/local_journey_snapshot_repository.dart';
import '../../models/memory_models.dart';
import '../../models/today_models.dart';
import 'ai_repository.dart';

typedef MemoryFocusAreaLoader = Future<String?> Function();

class MemoryRepository {
  final LocalCaptureRepository localCaptureRepository;
  final LocalJourneySnapshotRepository localJourneySnapshotRepository;
  final AiRepository aiRepository;
  final MemoryFocusAreaLoader? focusAreaLoader;

  MemoryRepository({
    required this.localCaptureRepository,
    required this.localJourneySnapshotRepository,
    required this.aiRepository,
    this.focusAreaLoader,
  });

  Future<MemorySummaryModel?> fetchMemorySummary() async {
    final signals = await localCaptureRepository.listRecentSignals(limit: 2000);
    if (signals.isEmpty) return null;

    final sortedSignals = [...signals]
      ..sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aTime.compareTo(bTime);
      });

    final firstSignal = sortedSignals.first.createdAt?.toLocal();
    if (firstSignal == null) return null;

    final today = DateTime.now();
    final firstDay = DateTime(firstSignal.year, firstSignal.month, firstSignal.day);
    final todayDay = DateTime(today.year, today.month, today.day);

    if (!firstDay.isBefore(todayDay)) {
      return null;
    }

    final stats = _buildJourneyStats(sortedSignals);
    final snapshotDate = _dateKey(todayDay);
    final sourceHash = localJourneySnapshotRepository.buildSourceHash(
      entries: stats.entries,
      topTokens: stats.topTokens,
      totalDays: stats.totalDays,
    );

    final cached = await localJourneySnapshotRepository.getByDate(snapshotDate);
    final cachedHash =
        await localJourneySnapshotRepository.getSourceHash(snapshotDate);

    if (cached != null && cachedHash == sourceHash) {
      return cached;
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
    } catch (_) {
      generated = _buildFallbackJourneySummary(stats);
    }

    await localJourneySnapshotRepository.upsert(
      snapshotDate: snapshotDate,
      summary: generated,
      sourceHash: sourceHash,
    );

    return generated;
  }

  _JourneyStats _buildJourneyStats(List<RecentSignalModel> signals) {
    final entries = <Map<String, dynamic>>[];
    final tokenCounts = <String, int>{};

    for (final signal in signals) {
      final createdAt = signal.createdAt?.toLocal();
      if (createdAt == null) continue;

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
      '最近',
      '一直',
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

  MemorySummaryModel _buildFallbackJourneySummary(_JourneyStats stats) {
    final topToken = stats.topTokens.isEmpty ? '最近的记录' : stats.topTokens.first;

    return MemorySummaryModel(
      patterns: [
        {
          'name': '反复出现的主题',
          'summary': '一路看下来，“$topToken”开始不止一次地出现。',
        },
      ],
      frictions: [
        {
          'name': '持续性的摩擦',
          'summary': '这段时间里，某些同类问题不是一次性，而是在慢慢累积。',
        },
      ],
      desires: [
        {
          'name': '还在浮现的方向',
          'summary': '记录已经跨越 ${stats.totalDays} 天，一些真正长期在意的方向正在慢慢浮现。',
        },
      ],
      experiments: [
        {
          'name': '开始有帮助的东西',
          'summary': '继续记录下去，会更容易看见什么正在慢慢对你起作用。',
        },
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

  _JourneyStats({
    required this.entries,
    required this.topTokens,
    required this.totalDays,
  });
}
