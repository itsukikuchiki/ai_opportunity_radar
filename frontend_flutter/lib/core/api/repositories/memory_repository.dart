import 'package:shared_preferences/shared_preferences.dart';

import '../../local/local_capture_repository.dart';
import '../../local/local_journey_snapshot_repository.dart';
import '../../local/local_life_experiment_repository.dart';
import '../../models/memory_models.dart';
import '../../models/today_models.dart';
import '../../models/weekly_models.dart';
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
  final LocalLifeExperimentRepository? localLifeExperimentRepository;
  final AiRepository aiRepository;
  final MemoryFocusAreaLoader? focusAreaLoader;
  final JourneyInstallationDateLoader? installationDateLoader;
  final String localUserId;

  MemoryRepository({
    required this.localCaptureRepository,
    required this.localJourneySnapshotRepository,
    required this.aiRepository,
    this.localLifeExperimentRepository,
    this.focusAreaLoader,
    this.installationDateLoader,
    this.localUserId = 'local',
  });

  Future<MemoryFetchResult> fetchMemorySummaryResult() async {
    final installationDate = await _readOrCreateInstallationDate();
    final today = _dateOnly(DateTime.now());
    final isFirstDay = _sameDay(installationDate, today);

    final signals = await localCaptureRepository.listSignalCards(limit: 2000);
    final journeySignals = _journeyEligibleSignals(signals);
    final experimentHistory = await localLifeExperimentRepository?.listRecent(
          localUserId: localUserId,
        ) ??
        const <LifeExperimentModel>[];

    if (journeySignals.isEmpty && experimentHistory.isEmpty) {
      return MemoryFetchResult(
        summary: null,
        isFirstDayGate: isFirstDay,
      );
    }

    final sortedSignals = [...journeySignals]..sort((a, b) {
        final dateCompare = a.localDateKey().compareTo(b.localDateKey());
        if (dateCompare != 0) return dateCompare;
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aTime.compareTo(bTime);
      });

    final stats = _buildJourneyStats(
      sortedSignals,
      experimentHistory: experimentHistory,
    );
    final snapshotDate = _dateKey(today);
    final sourceHash = localJourneySnapshotRepository.buildSourceHash(
      entries: stats.entries,
      topTokens: stats.topTokens,
      totalDays: stats.totalDays,
      experimentHistory: stats.experimentEntries,
    );
    await _markJourneyInclusion(stats);

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

  List<RecentSignalModel> _journeyEligibleSignals(
    List<RecentSignalModel> signals,
  ) {
    return signals.where(_isJourneyEligible).toList();
  }

  bool _isJourneyEligible(RecentSignalModel signal) {
    if (signal.isLocalDraft || signal.syncFailed) return false;
    if (signal.userConfirmation == 'inaccurate') return false;
    if (signal.isLibrarySaved && !signal.hasUserConfirmedLibrarySaved) {
      return false;
    }
    if (signal.isAiPredicted && !signal.hasUserConfirmedAiPrediction) {
      return false;
    }
    final privacy = signal.privacyLevel.trim().toLowerCase();
    if (privacy == 'do_not_analyze' ||
        privacy == 'excluded' ||
        privacy == 'sensitive') {
      return false;
    }
    return true;
  }

  _JourneyStats _buildJourneyStats(
    List<RecentSignalModel> signals, {
    required List<LifeExperimentModel> experimentHistory,
  }) {
    final entries = <Map<String, dynamic>>[];
    final tokenCounts = <String, int>{};
    final dayKeys = <String>{};
    final sceneCounts = <String, int>{};
    final frictionCounts = <String, int>{};
    final energyLoadCounts = <String, int>{};
    final positiveSignalCounts = <String, int>{};

    for (final signal in signals) {
      final dayKey = signal.localDateKey();
      if (dayKey.isEmpty) continue;
      final createdAt = signal.createdAt?.toLocal();
      dayKeys.add(dayKey);

      entries.add({
        'id': signal.id,
        'signal_card_id': signal.signalCardId,
        'source_type': signal.sourceType,
        'content': _analysisContent(signal),
        'created_at': createdAt?.toUtc().toIso8601String(),
        'local_date': dayKey,
        'timezone': signal.timezone,
        'acknowledgement': signal.acknowledgement,
        'observation': signal.observation,
        'try_next': signal.tryNext,
        'emotion': signal.emotion,
        'intensity': signal.intensity,
        'scene': signal.scene,
        'friction': signal.friction,
        'energy_load': signal.energyLoad,
        'positive_signal': signal.positiveSignal,
        'scene_tags': signal.sceneTags,
        'intent_tags': signal.intentTags,
        'user_confirmation': signal.userConfirmation,
        'is_legacy': signal.isLegacy,
        'journey_confidence': _journeyEvidenceLevel(signal),
      });

      for (final token in _tokenize(_analysisContent(signal))) {
        tokenCounts[token] = (tokenCounts[token] ?? 0) + 1;
      }
      for (final tag in signal.sceneTags) {
        final normalized = tag.trim();
        if (normalized.isNotEmpty) {
          tokenCounts[normalized] = (tokenCounts[normalized] ?? 0) + 1;
        }
      }
      _countIfPresent(sceneCounts, signal.scene);
      _countIfPresent(frictionCounts, signal.friction);
      _countIfPresent(energyLoadCounts, signal.energyLoad);
      _countIfPresent(positiveSignalCounts, signal.positiveSignal);
    }

    final sortedTokens = tokenCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final sortedDayKeys = dayKeys.toList()..sort();
    final first =
        sortedDayKeys.isEmpty ? null : DateTime.tryParse(sortedDayKeys.first);
    final last =
        sortedDayKeys.isEmpty ? null : DateTime.tryParse(sortedDayKeys.last);
    final totalDays =
        (first == null || last == null) ? 1 : last.difference(first).inDays + 1;

    return _JourneyStats(
      entries: entries,
      topTokens: sortedTokens.take(10).map((e) => e.key).toList(),
      topScenes: _topKeys(sceneCounts),
      topFrictions: _topKeys(frictionCounts),
      topEnergyLoads: _topKeys(energyLoadCounts),
      topPositiveSignals: _topKeys(positiveSignalCounts),
      totalDays: totalDays,
      activeDays: dayKeys.length,
      entryCount: entries.length,
      experimentHistory: experimentHistory,
      experimentEntries: experimentHistory.map(_experimentHashEntry).toList(),
    );
  }

  String _analysisContent(RecentSignalModel signal) {
    if (!signal.isLibrarySaved) return signal.content;
    return [
      signal.libraryPatternTitle,
      signal.libraryAbstractPattern,
      signal.userCorrectionJson['edited_text']?.toString(),
      signal.userCorrectionJson['supplement_text']?.toString(),
    ]
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .join(' ');
  }

  String _journeyEvidenceLevel(RecentSignalModel signal) {
    if (signal.isLegacy) return 'legacy_context';
    if (signal.isLibrarySaved) return 'library_saved_confirmed';
    if (signal.userConfirmation == 'unconfirmed') return 'light_observation';
    return 'standard';
  }

  Map<String, dynamic> _experimentHashEntry(LifeExperimentModel experiment) {
    return {
      'id': experiment.id,
      'status': experiment.status,
      'feedback_text': experiment.feedbackText ?? '',
      'updated_at': experiment.updatedAt?.toUtc().toIso8601String() ?? '',
    };
  }

  Future<void> _markJourneyInclusion(_JourneyStats stats) async {
    final ids = stats.entries
        .map((entry) =>
            (entry['signal_card_id'] as String?) ?? (entry['id'] as String?))
        .whereType<String>();
    await localCaptureRepository.updateSignalCardInclusion(
      signalCardIds: ids,
      includedInJourney: true,
    );
  }

  void _countIfPresent(Map<String, int> counts, String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return;
    counts[normalized] = (counts[normalized] ?? 0) + 1;
  }

  List<String> _topKeys(Map<String, int> counts) {
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(5).map((e) => e.key).toList();
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
        fallbackLabel: '一个恢复线索',
        stats: stats,
        preferStable: false,
      ),
      experiments: _normalizeSignalItems(
        items: _experimentItems(
          generated.experiments,
          stats,
        ),
        fallbackLabel: '一个实验调整记录',
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

    return items.take(1).map((item) {
      final signalLevel = item.signalLevel.trim().isEmpty
          ? _resolveSignalLevel(
              entryCount: stats.entryCount,
              activeDays: stats.activeDays,
              preferStable: preferStable,
            )
          : item.signalLevel;

      return JourneySignalItemModel(
        name: item.name.trim().isEmpty ? fallbackLabel : item.name,
        summary: _softJourneyText(
          item.summary.trim().isEmpty
              ? _defaultSignalSummary(
                  fallbackLabel: fallbackLabel,
                  stats: stats,
                )
              : item.summary,
        ),
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
          name: '一个恢复线索',
          summary: _recoverySummary(stats),
          signalLevel: weakOrRepeated,
        ),
      ],
      experiments: [
        _fallbackExperimentItem(stats, weakOrRepeated),
      ],
    );
  }

  List<JourneySignalItemModel> _experimentItems(
    List<JourneySignalItemModel> generated,
    _JourneyStats stats,
  ) {
    if (stats.experimentHistory.isEmpty) return generated;
    final latest = stats.experimentHistory.first;
    return [
      JourneySignalItemModel(
        name: '最近一次实验调整',
        summary:
            '“${latest.title}”现在是 ${_experimentStatusText(latest.status)}。${_feedbackText(latest.feedbackText)}可以把它当作一个生活设计来回看：这个设计有没有帮你省一点力。',
        signalLevel: 'weak_signal',
      ),
    ];
  }

  JourneySignalItemModel _fallbackExperimentItem(
    _JourneyStats stats,
    String signalLevel,
  ) {
    if (stats.experimentHistory.isNotEmpty) {
      final latest = stats.experimentHistory.first;
      return JourneySignalItemModel(
        name: '最近一次实验调整',
        summary:
            '“${latest.title}”现在是 ${_experimentStatusText(latest.status)}。${_feedbackText(latest.feedbackText)}可以把它当作一个生活设计来回看：这个设计有没有帮你省一点力。',
        signalLevel: signalLevel,
      );
    }
    return JourneySignalItemModel(
      name: '一个实验调整记录',
      summary: stats.entryCount <= 1
          ? '现在还太早，不过之后会更容易看见什么正在慢慢对你起作用。'
          : '继续记录下去，会更容易看见什么做法不是偶然有效，而是在慢慢变得有帮助。',
      signalLevel: signalLevel,
    );
  }

  String _recoverySummary(_JourneyStats stats) {
    if (stats.topPositiveSignals.isNotEmpty) {
      return '最近反复出现的恢复线索是“${stats.topPositiveSignals.first}”，可以先把它当作轻一点的观察方向。';
    }
    if (stats.topEnergyLoads.contains('restoring') ||
        stats.topEnergyLoads.contains('recovery')) {
      return '记录里已经出现一些恢复感，先看看它通常和什么场景一起出现。';
    }
    if (stats.totalDays <= 1) {
      return '现在还只是一个很轻的方向感，继续记录会更清楚。';
    }
    return '记录已经跨越 ${stats.totalDays} 天，一些让你稍微省力的线索会逐渐更清楚。';
  }

  String _experimentStatusText(String status) {
    switch (status) {
      case 'saved':
        return '已保存，之后可以再试';
      case 'skipped':
        return '这次先不看，也会作为回看背景保留';
      case 'tried':
        return '已经试过，可以继续看它是否省力';
      case 'not_helpful':
        return '这次帮助不明显';
      case 'adjusted':
        return '已经提供了可学习的调整线索';
      default:
        return '一个可以试试的方向';
    }
  }

  String _softJourneyText(String input) {
    return input
        .replaceAll('长期问题', '长期线索')
        .replaceAll('严重', '值得留意')
        .replaceAll('失败', '帮助不明显')
        .replaceAll('你应该', '可以先')
        .replaceAll('必须', '可以试试')
        .replaceAll('完成', '试一小步');
  }

  String _feedbackText(String? feedbackText) {
    final text = feedbackText?.trim();
    if (text == null || text.isEmpty) {
      return '没有反馈也没关系，不会影响长期回看。';
    }
    return '反馈是：$text。';
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
  final List<String> topScenes;
  final List<String> topFrictions;
  final List<String> topEnergyLoads;
  final List<String> topPositiveSignals;
  final int totalDays;
  final int activeDays;
  final int entryCount;
  final List<LifeExperimentModel> experimentHistory;
  final List<Map<String, dynamic>> experimentEntries;

  _JourneyStats({
    required this.entries,
    required this.topTokens,
    required this.topScenes,
    required this.topFrictions,
    required this.topEnergyLoads,
    required this.topPositiveSignals,
    required this.totalDays,
    required this.activeDays,
    required this.entryCount,
    required this.experimentHistory,
    required this.experimentEntries,
  });
}
