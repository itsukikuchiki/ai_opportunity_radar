import 'dart:ui' as ui;

import 'package:shared_preferences/shared_preferences.dart';

import '../../eligibility/signal_eligibility_service.dart';
import '../../i18n/app_locale_text.dart';
import '../../local/local_capture_repository.dart';
import '../../local/local_monthly_snapshot_repository.dart';
import '../../models/monthly_models.dart';
import '../../models/today_models.dart';
import '../../preferences/focus_domains.dart';
import 'ai_repository.dart';

typedef MonthlyFocusAreaLoader = Future<String?> Function();
typedef MonthlyInstallationDateLoader = Future<DateTime> Function();
typedef MonthlyLanguageLoader = AppLanguage Function();

class MonthlyRepository {
  final LocalCaptureRepository localCaptureRepository;
  final LocalMonthlySnapshotRepository localMonthlySnapshotRepository;
  final AiRepository aiRepository;
  final MonthlyFocusAreaLoader? focusAreaLoader;
  final MonthlyInstallationDateLoader? installationDateLoader;
  final MonthlyLanguageLoader? languageLoader;
  final SignalEligibilityService eligibilityService;

  MonthlyRepository({
    required this.localCaptureRepository,
    required this.localMonthlySnapshotRepository,
    required this.aiRepository,
    this.focusAreaLoader,
    this.installationDateLoader,
    this.languageLoader,
    SignalEligibilityService? eligibilityService,
  }) : eligibilityService =
            eligibilityService ?? const SignalEligibilityService();

  Future<MonthlyReviewModel> fetchCurrentMonthly() async {
    final language = _readLanguage();
    final installationDate = await _readOrCreateInstallationDate();
    final today = _dateOnly(DateTime.now());

    final isFirstMonth = installationDate.year == today.year &&
        installationDate.month == today.month;

    final range = _currentMonthRange();
    final rangeSignals = await localCaptureRepository.listSignalCardsBetween(
      startDate: _dateKey(range.start),
      endDate: _dateKey(range.end),
      limit: 4000,
    );

    if (isFirstMonth && rangeSignals.isEmpty) {
      return MonthlyReviewModel(
        monthStart: _dateKey(DateTime(today.year, today.month, 1)),
        monthEnd: _dateKey(_monthEnd(today)),
        status: 'first_month_gate',
      );
    }

    final monthSignals = eligibilityService.filter(
      rangeSignals,
      SignalEligibilityStage.aiReflect,
    );

    if (monthSignals.isEmpty) {
      return MonthlyReviewModel(
        monthStart: _dateKey(range.start),
        monthEnd: _dateKey(range.end),
        status: isFirstMonth ? 'first_month_gate' : 'insufficient_data',
      );
    }

    final stats = _buildMonthlyStats(monthSignals, language: language);
    final sourceHash = localMonthlySnapshotRepository.buildSourceHash(
      entries: [
        ...stats.entries,
        {'_display_language': _languageCode(language)},
      ],
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
      if (!_monthlyMatchesLanguage(
        generated,
        language: language,
        sourceEntries: stats.entries,
        sourceTokens: stats.topTokens,
      )) {
        generated = _buildFallbackMonthlyReview(
          range: range,
          stats: stats,
          language: language,
        );
      }
    } catch (_) {
      generated = _buildFallbackMonthlyReview(
        range: range,
        stats: stats,
        language: language,
      );
    }

    await localMonthlySnapshotRepository.upsert(
      monthly: generated,
      sourceHash: sourceHash,
    );

    return generated;
  }

  _MonthlyStats _buildMonthlyStats(
    List<RecentSignalModel> signals, {
    required AppLanguage language,
  }) {
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

      final weekLabel = _weekLabelInMonth(createdAt, language);
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
      monthStart: generated.monthStart.isEmpty
          ? _dateKey(range.start)
          : generated.monthStart,
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
    required AppLanguage language,
  }) {
    final topToken = stats.topTokens.isEmpty
        ? _copy(
            language,
            en: 'this month’s entries',
            zhHans: '这个月的记录',
            zhHant: '這個月的記錄',
            ja: '今月の記録',
          )
        : stats.topTokens.first;

    final bridgeItems = stats.weekCounts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return MonthlyReviewModel(
      monthStart: _dateKey(range.start),
      monthEnd: _dateKey(range.end),
      status: 'ready',
      monthlySummary: _copy(
        language,
        en: '“$topToken” kept returning this month, so it is becoming more than an isolated moment.',
        zhHans: '这个月反复回来的主题更接近“$topToken”，说明它已经不是零散的小片段了。',
        zhHant: '這個月反覆出現的主題更接近「$topToken」，表示它已不只是零散片段。',
        ja: '今月は「$topToken」が繰り返し現れ、単発の出来事ではなくなりつつあります。',
      ),
      repeatedThemes: stats.topTokens
          .take(3)
          .map(
            (e) => _copy(
              language,
              en: '“$e” appeared repeatedly.',
              zhHans: '“$e” 重复出现。',
              zhHant: '「$e」反覆出現。',
              ja: '「$e」が繰り返し現れました。',
            ),
          )
          .toList(),
      improvingSignals: [
        _copy(
          language,
          en: 'Some ways of recovering are gradually becoming more stable.',
          zhHans: '有些恢复方式正在慢慢变得更稳定。',
          zhHant: '有些恢復方式正逐漸變得更穩定。',
          ja: 'いくつかの回復方法が少しずつ安定してきています。',
        ),
      ],
      unresolvedPoints: [
        _copy(
          language,
          en: 'High-load situations have not been fully separated yet.',
          zhHans: '高消耗场景还没有被完全拆开。',
          zhHant: '高消耗情境還沒有被完全拆開。',
          ja: '負担の大きい場面は、まだ十分に切り分けられていません。',
        ),
      ],
      nextMonthWatch: _copy(
        language,
        en: 'Next month, keep watching which situations tend to trigger the first rise in load.',
        zhHans: '下个月先继续看，哪类场景最容易触发第一下消耗。',
        zhHant: '下個月先繼續觀察，哪類情境最容易引發最初的消耗。',
        ja: '来月は、どの場面で最初の負担が生まれやすいかを見ていきましょう。',
      ),
      weeklyBridges: bridgeItems.isEmpty
          ? [
              MonthlyBridgeWeekModel(
                label: _weekLabel(1, language),
                summary: _copy(
                  language,
                  en: 'A theme worth continuing to follow has begun to form.',
                  zhHans: '这个月已经开始形成可继续追踪的主题。',
                  zhHant: '這個月已開始形成值得持續追蹤的主題。',
                  ja: '今月は、引き続き見ていけるテーマが形になり始めています。',
                ),
              ),
            ]
          : bridgeItems
              .map(
                (e) => MonthlyBridgeWeekModel(
                  label: e.key,
                  summary: _copy(
                    language,
                    en: '${e.value} Signal entries were recorded.',
                    zhHans: '记录了 ${e.value} 条 Signal。',
                    zhHant: '記錄了 ${e.value} 條 Signal。',
                    ja: '${e.value}件のSignalを記録しました。',
                  ),
                ),
              )
              .toList(),
    );
  }

  bool _monthlyMatchesLanguage(
    MonthlyReviewModel monthly, {
    required AppLanguage language,
    required List<Map<String, dynamic>> sourceEntries,
    required List<String> sourceTokens,
  }) {
    final generated = <String>[
      monthly.monthlySummary ?? '',
      ...monthly.repeatedThemes,
      ...monthly.improvingSignals,
      ...monthly.unresolvedPoints,
      monthly.nextMonthWatch ?? '',
      ...monthly.weeklyBridges.expand((e) => [e.label, e.summary]),
    ].join(' ');
    final generatedProse = <String>[
      monthly.monthlySummary ?? '',
      monthly.nextMonthWatch ?? '',
      ...monthly.weeklyBridges.map((e) => e.summary),
    ].where((value) => value.trim().isNotEmpty).toList(growable: false);
    final sourceText = <String>[
      ...sourceTokens,
      ...sourceEntries.map((e) => (e['content'] as String?) ?? ''),
    ];
    final generatedOnly = _withoutSourceText(generated, sourceText);
    if (!_matchesDisplayLanguage(generatedOnly, language)) return false;
    if (language != AppLanguage.japanese) return true;
    if (RegExp(r'[这们么还没为个录复续觉验這們麼還沒]').hasMatch(generatedOnly)) {
      return false;
    }
    return generatedProse.isNotEmpty &&
        generatedProse.every(
          (value) => RegExp(r'[\u3040-\u30ff]').hasMatch(value),
        );
  }

  String _withoutSourceText(String generated, List<String> sourceText) {
    var value = generated;
    final sorted = sourceText
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final source in sorted) {
      value = value.replaceAll(source, '');
    }
    return value;
  }

  bool _matchesDisplayLanguage(String value, AppLanguage language) {
    final hasHan = RegExp(r'[\u3400-\u9fff]').hasMatch(value);
    final hasKana = RegExp(r'[\u3040-\u30ff]').hasMatch(value);
    final hasSimplifiedOnly = RegExp(
      r'[这复个让还会条录续变为进关现发后开门问时与类场稳观]',
    ).hasMatch(value);
    final hasTraditionalOnly = RegExp(
      r'[這復個裡讓還會條錄續變為進關現發後開門問時與類場穩觀]',
    ).hasMatch(value);
    final withoutAllowedEnglish =
        value.replaceAll('Signal Path', '').replaceAll('Signal', '');
    final hasOtherEnglish = RegExp(r'[A-Za-z]').hasMatch(withoutAllowedEnglish);

    return switch (language) {
      AppLanguage.english =>
        !hasHan && !hasKana && RegExp(r'[A-Za-z]').hasMatch(value),
      AppLanguage.japanese => hasKana && !hasOtherEnglish,
      AppLanguage.simplifiedChinese =>
        hasHan && !hasKana && !hasTraditionalOnly && !hasOtherEnglish,
      AppLanguage.traditionalChinese =>
        hasHan && !hasKana && !hasSimplifiedOnly && !hasOtherEnglish,
    };
  }

  Future<String?> _readFocusArea() async {
    if (focusAreaLoader != null) {
      return focusAreaLoader!();
    }

    final prefs = await SharedPreferences.getInstance();
    final focusDomainIds = FocusDomains.normalizeIds(
      prefs.getStringList(FocusDomains.productPreferenceKey) ??
          prefs.getStringList(FocusDomains.preferenceKey) ??
          const [],
    );
    if (focusDomainIds.isNotEmpty) {
      return focusDomainIds.join(',');
    }
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

  String _weekLabelInMonth(DateTime date, AppLanguage language) {
    final weekIndex = ((date.day - 1) ~/ 7) + 1;
    return _weekLabel(weekIndex, language);
  }

  String _weekLabel(int weekIndex, AppLanguage language) => _copy(
        language,
        en: 'Week $weekIndex',
        zhHans: '第$weekIndex周',
        zhHant: '第$weekIndex週',
        ja: '第$weekIndex週',
      );

  AppLanguage _readLanguage() {
    if (languageLoader != null) return languageLoader!();
    return AppLocaleText.resolveFromLocale(
      ui.PlatformDispatcher.instance.locale,
    );
  }

  String _languageCode(AppLanguage language) => switch (language) {
        AppLanguage.simplifiedChinese => 'zh-Hans',
        AppLanguage.traditionalChinese => 'zh-Hant',
        AppLanguage.japanese => 'ja',
        AppLanguage.english => 'en',
      };

  String _copy(
    AppLanguage language, {
    required String en,
    required String zhHans,
    required String zhHant,
    required String ja,
  }) =>
      switch (language) {
        AppLanguage.english => en,
        AppLanguage.simplifiedChinese => zhHans,
        AppLanguage.traditionalChinese => zhHant,
        AppLanguage.japanese => ja,
      };

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
