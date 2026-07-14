import 'package:shared_preferences/shared_preferences.dart';

import '../../eligibility/signal_eligibility_service.dart';
import '../../local/local_capture_repository.dart';
import '../../models/self_review_models.dart';
import '../../models/today_models.dart';
import '../../preferences/focus_domains.dart';
import '../api_client.dart';

typedef SelfReviewFocusAreaLoader = Future<String?> Function();

class SelfReviewRepository {
  final LocalCaptureRepository localCaptureRepository;
  final ApiClient apiClient;
  final SelfReviewFocusAreaLoader? focusAreaLoader;
  final SignalEligibilityService eligibilityService;

  SelfReviewRepository({
    required this.localCaptureRepository,
    required this.apiClient,
    this.focusAreaLoader,
    SignalEligibilityService? eligibilityService,
  }) : eligibilityService =
            eligibilityService ?? const SignalEligibilityService();

  Future<SelfReviewModel> fetchSelfReview() async {
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
      return const SelfReviewModel(
        status: 'insufficient_data',
        reviewedDays: 0,
        repeatedBlockers: [],
        mainDrains: [],
        helpingPatterns: [],
        closingNote:
            'Leave a few more entries first, then the structured review will have something real to work with.',
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
        },
      );
      final data = (res['data'] as Map<String, dynamic>?) ?? res;
      return SelfReviewModel.fromJson(data);
    } catch (_) {
      return _buildFallback(stats);
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

  SelfReviewModel _buildFallback(_SelfReviewStats stats) {
    final token = stats.topTokens.isEmpty ? '最近反复出现的主题' : stats.topTokens.first;
    final sample = _sampleFragment(stats.entries);
    return SelfReviewModel(
      status: 'ready',
      reviewedDays: stats.totalDays,
      repeatedBlockers: [
        '“$token” 已经不是一次性的瞬间，而是在最近这段时间里反复回来；像“$sample”这样的记录，适合被放进同一个专题里看。',
        '这说明你已经有了值得单独抽出来看的固定主题，而不是只能得到一段普通总结。',
      ],
      mainDrains: [
        '最近最稳定的消耗，不只是事情多，而是同类问题总在相似场景里出现，让你重复进入判断成本。',
        '比起单个事件本身，更值得看的，是那种“又来了”的熟悉消耗感：它通常说明问题发生在同一个入口。',
      ],
      helpingPatterns: [
        '你已经不是完全没有恢复力了；能把片段写下来，本身就是在把模糊压力变成可观察对象。',
        '继续把最卡的瞬间写具体，并补一句它发生在开始、推进还是收尾，会更容易看见真正有用的方法。',
      ],
      closingNote:
          '先别急着一次性解决全部问题。这份 self-review 更适合帮你收窄注意力：接下来先继续盯住“$token”，每次它出现时只多补一句触发条件。',
    );
  }

  String _sampleFragment(List<Map<String, dynamic>> entries) {
    if (entries.isEmpty) return '最近的一条记录';
    final sorted = [...entries]..sort((a, b) {
        final aText = (a['content'] as String?) ?? '';
        final bText = (b['content'] as String?) ?? '';
        return bText.length.compareTo(aText.length);
      });
    final content = ((sorted.first['content'] as String?) ?? '').trim();
    if (content.isEmpty) return '最近的一条记录';
    return content.length > 24 ? '${content.substring(0, 24)}...' : content;
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
