import 'dart:ui' as ui;

import 'package:shared_preferences/shared_preferences.dart';

import '../../eligibility/signal_eligibility_service.dart';
import '../../i18n/app_locale_text.dart';
import '../../local/local_capture_repository.dart';
import '../../models/self_review_models.dart';
import '../../models/today_models.dart';
import '../../preferences/focus_domains.dart';
import '../api_client.dart';

typedef SelfReviewFocusAreaLoader = Future<String?> Function();
typedef SelfReviewLanguageLoader = AppLanguage Function();

class SelfReviewRepository {
  final LocalCaptureRepository localCaptureRepository;
  final ApiClient apiClient;
  final SelfReviewFocusAreaLoader? focusAreaLoader;
  final SelfReviewLanguageLoader? languageLoader;
  final SignalEligibilityService eligibilityService;

  SelfReviewRepository({
    required this.localCaptureRepository,
    required this.apiClient,
    this.focusAreaLoader,
    this.languageLoader,
    SignalEligibilityService? eligibilityService,
  }) : eligibilityService =
            eligibilityService ?? const SignalEligibilityService();

  Future<SelfReviewModel> fetchSelfReview() async {
    final language = _readLanguage();
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final rangeSignals = await localCaptureRepository.listSignalCardsBetween(
      startDate: _dateKey(cutoff),
      endDate: _dateKey(DateTime.now()),
      limit: 2000,
    );
    final eligibleSignals = eligibilityService.filter(
      rangeSignals,
      SignalEligibilityStage.aiReflect,
    );
    final signals = eligibleSignals.where((signal) {
      final time = signal.createdAt?.toLocal();
      return time != null && !time.isBefore(cutoff);
    }).toList()
      ..sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aTime.compareTo(bTime);
      });

    if (signals.isEmpty) {
      return SelfReviewModel(
        status: 'insufficient_data',
        reviewedDays: 0,
        repeatedBlockers: const [],
        mainDrains: const [],
        helpingPatterns: const [],
        closingNote: _copy(
          language,
          en: 'Leave a few more entries first, then the structured review will have something real to work with.',
          zhHans: '再留下一些记录后，自我回顾才会有足够的真实内容可以整理。',
          zhHant: '再留下一些記錄後，自我回顧才會有足夠的真實內容可以整理。',
          ja: 'もう少し記録を残すと、実際の内容をもとに振り返れるようになります。',
        ),
      );
    }

    final stats = _buildStats(signals);
    final focusArea = await _readFocusArea();

    try {
      final res = await apiClient.postJson(
        '/api/v1/ai/self-review',
        {
          'entry_count': stats.entries.length,
          'entries': stats.entries,
          'top_tokens': stats.topTokens,
          'total_days': stats.totalDays,
          'focus_area': focusArea,
          'language': _languageCode(language),
        },
      );
      final data = (res['data'] as Map<String, dynamic>?) ?? res;
      final generated = SelfReviewModel.fromJson(data);
      if (_selfReviewMatchesLanguage(
        generated,
        language: language,
        sourceEntries: stats.entries,
        sourceTokens: stats.topTokens,
      )) {
        return generated;
      }
      return _buildFallback(stats, language: language);
    } catch (_) {
      return _buildFallback(stats, language: language);
    }
  }

  _SelfReviewStats _buildStats(List<RecentSignalModel> signals) {
    final entries = <Map<String, dynamic>>[];
    final tokenCounts = <String, int>{};
    final dayKeys = <String>{};

    for (final signal in signals) {
      final createdAt = signal.createdAt?.toLocal();
      if (createdAt == null) continue;

      dayKeys.add(_dateKey(createdAt));
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

    return _SelfReviewStats(
      entries: entries,
      topTokens: sortedTokens.take(8).map((e) => e.key).toList(),
      totalDays: dayKeys.length,
    );
  }

  SelfReviewModel _buildFallback(
    _SelfReviewStats stats, {
    required AppLanguage language,
  }) {
    final token = stats.topTokens.isEmpty
        ? _copy(
            language,
            en: 'a theme that has been returning lately',
            zhHans: '最近反复出现的主题',
            zhHant: '最近反覆出現的主題',
            ja: '最近繰り返し現れているテーマ',
          )
        : stats.topTokens.first;
    final sample = _sampleFragment(stats.entries, language);
    return SelfReviewModel(
      status: 'ready',
      reviewedDays: stats.totalDays,
      repeatedBlockers: [
        _copy(
          language,
          en: '“$token” is no longer an isolated moment. It has kept returning lately, and entries such as “$sample” are worth viewing together.',
          zhHans: '“$token” 已经不是一次性的瞬间，而是在最近这段时间里反复回来；像“$sample”这样的记录，适合放在一起看。',
          zhHant: '「$token」已經不是一次性的片刻，而是在最近這段時間裡反覆出現；像「$sample」這樣的記錄，適合放在一起看。',
          ja: '「$token」は一度きりの出来事ではなく、最近何度も現れています。「$sample」のような記録は、まとめて見ていく価値があります。',
        ),
        _copy(
          language,
          en: 'You now have a stable theme worth separating out, rather than only a general summary.',
          zhHans: '这说明你已经有了值得单独整理的固定主题，而不只是一段普通总结。',
          zhHant: '這表示你已經有了值得單獨整理的固定主題，而不只是一段普通總結。',
          ja: '一般的な要約だけでなく、ひとつのテーマとして整理できる材料が集まっています。',
        ),
      ],
      mainDrains: [
        _copy(
          language,
          en: 'The most consistent load lately is not only having too much to do. Similar issues keep appearing in similar situations, making you pay the same decision cost again.',
          zhHans: '最近最稳定的消耗，不只是事情多，而是同类问题总在相似场景里出现，让你重复承担判断成本。',
          zhHant: '最近最穩定的消耗，不只是事情多，而是同類問題總在相似情境裡出現，讓你反覆承擔判斷成本。',
          ja: '最近続いている負担は、単にやることが多いだけではありません。似た場面で同じ種類の問題が起こり、判断の負担を繰り返し背負っています。',
        ),
        _copy(
          language,
          en: 'More than any single event, the familiar feeling of “here it is again” is worth watching. It often points to the same entry point.',
          zhHans: '比起单个事件本身，更值得看的是那种“又来了”的熟悉消耗感：它通常说明问题发生在同一个入口。',
          zhHant: '比起單一事件本身，更值得看的是那種「又來了」的熟悉消耗感：它通常表示問題發生在同一個入口。',
          ja: '個々の出来事よりも、「また来た」と感じる見慣れた負担に注目してみてください。同じ入口で起きている可能性があります。',
        ),
      ],
      helpingPatterns: [
        _copy(
          language,
          en: 'You are not without ways to recover. Writing these moments down is already turning vague pressure into something you can observe.',
          zhHans: '你并不是完全没有恢复方式；能把片段写下来，本身就是在把模糊压力变成可观察的内容。',
          zhHant: '你並不是完全沒有恢復方式；能把片段寫下來，本身就是在把模糊壓力變成可觀察的內容。',
          ja: '回復する方法がまったくないわけではありません。断片を書き残すこと自体が、曖昧な負担を観察できる形に変えています。',
        ),
        _copy(
          language,
          en: 'Keep describing the hardest moment precisely, including whether it happened at the beginning, in the middle, or near the end. That will make useful approaches easier to see.',
          zhHans: '继续把最卡的瞬间写具体，并补一句它发生在开始、推进还是收尾，会更容易看见真正有用的方法。',
          zhHant: '繼續把最卡住的片刻寫具體，並補充它發生在開始、推進還是收尾，會更容易看見真正有用的方法。',
          ja: 'いちばん詰まった瞬間を具体的に書き、それが始め・途中・終わりのどこで起きたかも添えると、役立つ方法が見えやすくなります。',
        ),
      ],
      closingNote: _copy(
        language,
        en: 'There is no need to solve everything at once. Use this review to narrow your attention: keep watching “$token”, and add just one line about what triggered it each time it appears.',
        zhHans:
            '先别急着一次性解决全部问题。这次自我回顾更适合帮你收窄注意力：接下来继续留意“$token”，每次它出现时只多补一句触发条件。',
        zhHant:
            '先別急著一次解決所有問題。這次自我回顧更適合幫你收窄注意力：接下來繼續留意「$token」，每次它出現時只多補一句觸發條件。',
        ja: 'すべてを一度に解決しなくて大丈夫です。この振り返りでは注目する範囲を絞り、次は「$token」が現れるたびに、きっかけを一言だけ添えてみてください。',
      ),
    );
  }

  String _sampleFragment(
    List<Map<String, dynamic>> entries,
    AppLanguage language,
  ) {
    if (entries.isEmpty) {
      return _copy(
        language,
        en: 'a recent entry',
        zhHans: '最近的一条记录',
        zhHant: '最近的一條記錄',
        ja: '最近の記録',
      );
    }
    final sorted = [...entries]..sort((a, b) {
        final aText = (a['content'] as String?) ?? '';
        final bText = (b['content'] as String?) ?? '';
        return bText.length.compareTo(aText.length);
      });
    final content = ((sorted.first['content'] as String?) ?? '').trim();
    if (content.isEmpty) {
      return _copy(
        language,
        en: 'a recent entry',
        zhHans: '最近的一条记录',
        zhHant: '最近的一條記錄',
        ja: '最近の記録',
      );
    }
    return content.length > 24 ? '${content.substring(0, 24)}...' : content;
  }

  bool _selfReviewMatchesLanguage(
    SelfReviewModel review, {
    required AppLanguage language,
    required List<Map<String, dynamic>> sourceEntries,
    required List<String> sourceTokens,
  }) {
    final generated = <String>[
      ...review.repeatedBlockers,
      ...review.mainDrains,
      ...review.helpingPatterns,
      review.closingNote,
    ].join(' ');
    final sourceText = <String>[
      ...sourceTokens,
      ...sourceEntries.map((e) => (e['content'] as String?) ?? ''),
    ];
    return _matchesDisplayLanguage(
      _withoutSourceText(generated, sourceText),
      language,
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
      'ただ'
    };
    return rawParts
        .where((e) => e.trim().isNotEmpty)
        .where((e) => e.runes.length >= 2)
        .where((e) => !stopWords.contains(e))
        .toList();
  }

  String _dateKey(DateTime date) {
    final local = date.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd';
  }
}

class _SelfReviewStats {
  final List<Map<String, dynamic>> entries;
  final List<String> topTokens;
  final int totalDays;

  const _SelfReviewStats({
    required this.entries,
    required this.topTokens,
    required this.totalDays,
  });
}
