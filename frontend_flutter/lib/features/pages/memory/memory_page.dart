import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/i18n/app_locale_text.dart';
import '../../../shared/states/load_state.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/empty_state_block.dart';
import '../me/me_view_model.dart';
import 'memory_view_model.dart';

class MemoryPage extends StatelessWidget {
  const MemoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MemoryViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocaleText.tr(
            context,
            en: 'Journey',
            zhHans: 'Journey',
            zhHant: 'Journey',
            ja: 'Journey',
          ),
        ),
      ),
      body: switch (vm.loadState) {
        LoadState.loading => const Center(child: CircularProgressIndicator()),
        LoadState.error => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              EmptyStateBlock(
                icon: Icons.error_outline,
                title: AppLocaleText.tr(
                  context,
                  en: 'Journey failed to load',
                  zhHans: 'Journey 加载失败了',
                  zhHant: 'Journey 載入失敗了',
                  ja: 'Journey の読み込みに失敗しました',
                ),
                subtitle: vm.errorMessage ??
                    AppLocaleText.tr(
                      context,
                      en: 'Please try again later.',
                      zhHans: '请稍后重试。',
                      zhHant: '請稍後重試。',
                      ja: 'しばらくしてから、もう一度試してください。',
                    ),
              ),
            ],
          ),
        LoadState.empty => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              EmptyStateBlock(
                icon: vm.showFirstDayGate
                    ? Icons.route_outlined
                    : Icons.timeline_outlined,
                title: vm.showFirstDayGate
                    ? AppLocaleText.tr(
                        context,
                        en: 'Journey starts on day 2',
                        zhHans: 'Journey 第 2 天开始展示',
                        zhHant: 'Journey 第 2 天開始展示',
                        ja: 'Journey は 2 日目から表示されます',
                      )
                    : AppLocaleText.tr(
                        context,
                        en: 'No long-term clues yet',
                        zhHans: '还没有形成长期线索',
                        zhHant: '還沒有形成長期線索',
                        ja: 'まだ長期的な手がかりはありません',
                      ),
                subtitle: vm.showFirstDayGate
                    ? AppLocaleText.tr(
                        context,
                        en: 'If you already have local entries today, Journey can still start showing right away. Otherwise, it will begin from day 2.',
                        zhHans: '如果你今天已经留下本地记录，Journey 也可以立即开始展示；如果今天还没有记录，就会从第 2 天开始出现。',
                        zhHant: '如果你今天已經留下本地記錄，Journey 也可以立即開始展示；如果今天還沒有記錄，就會從第 2 天開始出現。',
                        ja: '今日すでにローカル記録があれば Journey はすぐ表示できます。まだ記録がなければ、2 日目から始まります。',
                      )
                    : AppLocaleText.tr(
                        context,
                        en: 'As more records accumulate, this page will start showing recurring patterns, stable frictions, what is helping, and what is still emerging.',
                        zhHans: '等记录慢慢积累后，这里会出现那些反复出现的模式、持续摩擦、开始有效的方法，以及还在浮现中的变化。',
                        zhHant: '等記錄慢慢累積後，這裡會出現那些反覆出現的模式、持續摩擦、開始有效的方法，以及還在浮現中的變化。',
                        ja: '記録が少しずつたまってくると、ここに繰り返し現れるパターンや摩擦、助けになり始めていること、まだ浮かびつつある変化が見えてきます。',
                      ),
              ),
            ],
          ),
        _ => _JourneyReadyBody(vm: vm),
      },
    );
  }
}

class _JourneyReadyBody extends StatelessWidget {
  final MemoryViewModel vm;

  const _JourneyReadyBody({required this.vm});

  @override
  Widget build(BuildContext context) {
    final meVm = context.watch<MeViewModel>();
    final summary = vm.summary;
    final focusArea = meVm.selectedRepeatArea;

    if (summary == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          EmptyStateBlock(
            icon: Icons.timeline_outlined,
            title: AppLocaleText.tr(
              context,
              en: 'No long-term clues yet',
              zhHans: '还没有形成长期线索',
              zhHant: '還沒有形成長期線索',
              ja: 'まだ長期的な手がかりはありません',
            ),
            subtitle: AppLocaleText.tr(
              context,
              en: 'As more records accumulate, this page will start showing recurring patterns, stable frictions, what is helping, and what is still emerging.',
              zhHans: '等记录慢慢积累后，这里会出现那些反复出现的模式、持续摩擦、开始有效的方法，以及还在浮现中的变化。',
              zhHant: '等記錄慢慢累積後，這裡會出現那些反覆出現的模式、持續摩擦、開始有效的方法，以及還在浮現中的變化。',
              ja: '記録が少しずつたまってくると、ここに繰り返し現れるパターンや摩擦、助けになり始めていること、まだ浮かびつつある変化が見えてきます。',
            ),
          ),
        ],
      );
    }

    final stations = _realStationsFromSummary(context, summary, focusArea);
    final totalCount = stations.fold<int>(0, (sum, station) => sum + station.items.length);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        AppHeader(
          title: AppLocaleText.tr(
            context,
            en: 'Journey',
            zhHans: 'Journey',
            zhHant: 'Journey',
            ja: 'Journey',
          ),
          subtitle: _headerSubtitle(context, focusArea),
          summary: AppLocaleText.tr(
            context,
            en: '$totalCount long-term clues are starting to settle',
            zhHans: '目前已经沉淀了 $totalCount 条长期线索',
            zhHant: '目前已經沉澱了 $totalCount 條長期線索',
            ja: 'ここまでに $totalCount 件の長期的な手がかりが少しずつ積み上がっています',
          ),
        ),
        const SizedBox(height: 14),
        Text(
          AppLocaleText.tr(
            context,
            en: 'Four stations on the way',
            zhHans: '一路上的 4 个车站',
            zhHant: '一路上的 4 個車站',
            ja: 'この道の 4 つの駅',
          ),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          AppLocaleText.tr(
            context,
            en: 'Each station shows only the summary first. Open it when you want the full details.',
            zhHans: '每个车站先只看摘要，想看完整内容时再点开。',
            zhHant: '每個車站先只看摘要，想看完整內容時再點開。',
            ja: '各駅ではまず要約だけを見て、詳しく見たいときに開けます。',
          ),
        ),
        const SizedBox(height: 18),
        _JourneyRail(stations: stations),
      ],
    );
  }

  List<_JourneyStationData> _realStationsFromSummary(
    BuildContext context,
    dynamic summary,
    String? focusArea,
  ) {
    final patterns = _listField(summary, 'patterns');
    final frictions = _listField(summary, 'frictions');
    final desires = _listField(summary, 'desires');
    final experiments = _listField(summary, 'experiments');

    return [
      _JourneyStationData(
        kind: _JourneyStationKind.recurring,
        title: _stationTitleRecurring(context, focusArea),
        summary: AppLocaleText.tr(
          context,
          en: '${patterns.length} clue(s) are repeating over time.',
          zhHans: '目前有 ${patterns.length} 条线索正在长期重复出现。',
          zhHant: '目前有 ${patterns.length} 條線索正在長期重複出現。',
          ja: '現在、${patterns.length} 件の手がかりが長い目で見て繰り返し現れています。',
        ),
        items: _mapEntries(
          context,
          patterns,
          AppLocaleText.tr(
            context,
            en: 'Recurring pattern',
            zhHans: '长期模式',
            zhHant: '長期模式',
            ja: '長期パターン',
          ),
        ),
      ),
      _JourneyStationData(
        kind: _JourneyStationKind.friction,
        title: _stationTitleFriction(context, focusArea),
        summary: AppLocaleText.tr(
          context,
          en: '${frictions.length} clue(s) are behaving like stable friction.',
          zhHans: '目前有 ${frictions.length} 条线索更像持续摩擦。',
          zhHant: '目前有 ${frictions.length} 條線索更像持續摩擦。',
          ja: '現在、${frictions.length} 件の手がかりが継続する摩擦のように見えています。',
        ),
        items: _mapEntries(
          context,
          frictions,
          AppLocaleText.tr(
            context,
            en: 'Stable friction',
            zhHans: '持续摩擦',
            zhHant: '持續摩擦',
            ja: '継続する摩擦',
          ),
        ),
      ),
      _JourneyStationData(
        kind: _JourneyStationKind.helping,
        title: _stationTitleHelping(context, focusArea),
        summary: AppLocaleText.tr(
          context,
          en: '${experiments.length} clue(s) may already be helping.',
          zhHans: '目前有 ${experiments.length} 条线索开始显得有效。',
          zhHant: '目前有 ${experiments.length} 條線索開始顯得有效。',
          ja: '現在、${experiments.length} 件の手がかりが少しずつ助けになり始めています。',
        ),
        items: _mapEntries(
          context,
          experiments,
          AppLocaleText.tr(
            context,
            en: 'Starting to help',
            zhHans: '开始有效',
            zhHant: '開始有效',
            ja: '効き始め',
          ),
        ),
      ),
      _JourneyStationData(
        kind: _JourneyStationKind.observing,
        title: _stationTitleObserving(context, focusArea),
        summary: AppLocaleText.tr(
          context,
          en: '${desires.length} clue(s) are still taking shape.',
          zhHans: '目前有 ${desires.length} 条线索还在浮现中。',
          zhHant: '目前有 ${desires.length} 條線索還在浮現中。',
          ja: '現在、${desires.length} 件の手がかりがまだ形になりつつあります。',
        ),
        items: _mapEntries(
          context,
          desires,
          AppLocaleText.tr(
            context,
            en: 'Still observing',
            zhHans: '继续观察',
            zhHant: '繼續觀察',
            ja: '観察中',
          ),
        ),
      ),
    ];
  }

  List<_JourneyEntry> _mapEntries(
    BuildContext context,
    List<dynamic> source,
    String tag,
  ) {
    return source.map((item) {
      final title = _itemTitle(item);
      final detail = _itemSubtitle(item) ??
          AppLocaleText.tr(
            context,
            en: 'This clue is still taking shape.',
            zhHans: '这条线索还在慢慢成形。',
            zhHant: '這條線索還在慢慢成形。',
            ja: 'この手がかりはまだ少しずつ形になっているところです。',
          );

      return _JourneyEntry(
        title: title,
        summary: _compactSummary(context, title, detail),
        detail: detail,
        tag: tag,
      );
    }).toList();
  }

  static List<dynamic> _listField(dynamic obj, String key) {
    if (obj is Map) {
      final value = obj[key];
      if (value is List) return value;
    }
    try {
      final json = (obj as dynamic).toJson();
      final value = json[key];
      if (value is List) return value;
    } catch (_) {}
    return const [];
  }

  String _compactSummary(BuildContext context, String title, String body) {
    final lowered = title.toLowerCase();

    if (lowered.contains('整理') || lowered.contains('organize')) {
      return AppLocaleText.tr(
        context,
        en: 'Information still tends to reopen instead of closing cleanly.',
        zhHans: '信息还会反复重开，没有一次收住。',
        zhHant: '資訊還會反覆重開，沒有一次收住。',
        ja: '情報が一度で収まりきらず、何度も開き直されています。',
      );
    }
    if (lowered.contains('确认') || lowered.contains('確認') || lowered.contains('confirm')) {
      return AppLocaleText.tr(
        context,
        en: 'The same kind of thing keeps needing re-confirmation.',
        zhHans: '同一类事情会一直重新确认。',
        zhHant: '同一類事情會一直重新確認。',
        ja: '同じ種類のことを何度も確認し直しています。',
      );
    }
    if (lowered.contains('打断') || lowered.contains('打斷') || lowered.contains('interrupt') || lowered.contains('context')) {
      return AppLocaleText.tr(
        context,
        en: 'This is where your rhythm gets cut most easily.',
        zhHans: '这里很容易把节奏切断。',
        zhHant: '這裡很容易把節奏切斷。',
        ja: 'ここでリズムが切れやすくなっています。',
      );
    }
    if (lowered.contains('收尾') || lowered.contains('cleanup')) {
      return AppLocaleText.tr(
        context,
        en: 'Things that should not land on you still do.',
        zhHans: '原本不该落到你这里的事，还是会落过来。',
        zhHant: '原本不該落到你這裡的事，還是會落過來。',
        ja: '本来自分に来るべきではないことが来ています。',
      );
    }

    return body;
  }

  String _headerSubtitle(BuildContext context, String? focusArea) {
    switch (focusArea) {
      case 'emotion_stress':
        return AppLocaleText.tr(
          context,
          en: 'Over time, you are starting to see which feelings return, what drains you, and what makes things lighter.',
          zhHans: '一路以来，你正在慢慢看见哪些情绪会反复出现，哪些地方最耗你，哪些时刻会让你轻一点。',
          zhHant: '一路以來，你正在慢慢看見哪些情緒會反覆出現，哪些地方最耗你，哪些時刻會讓你輕一點。',
          ja: '少しずつ、どんな感情が繰り返し現れ、何が消耗を生み、どんな瞬間が少し楽にしてくれるのかが見えてきています。',
        );
      case 'time_rhythm':
        return AppLocaleText.tr(
          context,
          en: 'Over time, you are starting to see where your rhythm gets cut, where it stalls, and where it gets smoother.',
          zhHans: '一路以来，你正在慢慢看见节奏最容易在哪里被打断，哪里最容易卡住，哪里开始变顺。',
          zhHant: '一路以來，你正在慢慢看見節奏最容易在哪裡被打斷，哪裡最容易卡住，哪裡開始變順。',
          ja: '少しずつ、どこでリズムが切られやすく、どこで詰まりやすく、どこが少しずつ整ってきているのかが見えてきています。',
        );
      default:
        return AppLocaleText.tr(
          context,
          en: 'Over time, your signals begin to gather into a clearer trail.',
          zhHans: '一路以来，你正在慢慢看见自己的模式。',
          zhHant: '一路以來，你正在慢慢看見自己的模式。',
          ja: '少しずつ、自分のパターンが見えてきています。',
        );
    }
  }

  String _stationTitleRecurring(BuildContext context, String? focusArea) {
    switch (focusArea) {
      case 'emotion_stress':
        return AppLocaleText.tr(context, en: 'Repeated feelings', zhHans: '反复出现的情绪', zhHant: '反覆出現的情緒', ja: '繰り返し現れる感情');
      case 'time_rhythm':
        return AppLocaleText.tr(context, en: 'Repeated rhythm patterns', zhHans: '反复出现的节奏模式', zhHant: '反覆出現的節奏模式', ja: '繰り返し現れるリズム');
      default:
        return AppLocaleText.tr(context, en: 'Repeated patterns', zhHans: '反复出现的模式', zhHant: '反覆出現的模式', ja: '繰り返し現れるパターン');
    }
  }

  String _stationTitleFriction(BuildContext context, String? focusArea) {
    switch (focusArea) {
      case 'emotion_stress':
        return AppLocaleText.tr(context, en: 'What keeps draining you', zhHans: '最耗你的地方', zhHant: '最耗你的地方', ja: 'いちばん消耗する場所');
      case 'time_rhythm':
        return AppLocaleText.tr(context, en: 'Where rhythm gets cut', zhHans: '最容易打断节奏的地方', zhHant: '最容易打斷節奏的地方', ja: 'リズムが切れやすい場所');
      default:
        return AppLocaleText.tr(context, en: 'Stable friction', zhHans: '持续摩擦', zhHant: '持續摩擦', ja: '継続する摩擦');
    }
  }

  String _stationTitleHelping(BuildContext context, String? focusArea) {
    switch (focusArea) {
      case 'emotion_stress':
        return AppLocaleText.tr(context, en: 'What is making things lighter', zhHans: '开始让你轻一点的东西', zhHant: '開始讓你輕一點的東西', ja: '少し楽にしてくれるもの');
      case 'time_rhythm':
        return AppLocaleText.tr(context, en: 'What is making things flow better', zhHans: '开始让节奏变顺的东西', zhHant: '開始讓節奏變順的東西', ja: '流れを少し整えているもの');
      default:
        return AppLocaleText.tr(context, en: 'Starting to help', zhHans: '开始有效', zhHant: '開始有效', ja: '効き始め');
    }
  }

  String _stationTitleObserving(BuildContext context, String? focusArea) {
    switch (focusArea) {
      case 'emotion_stress':
        return AppLocaleText.tr(context, en: 'Still watching emotional changes', zhHans: '还在观察的情绪变化', zhHant: '還在觀察的情緒變化', ja: 'まだ観察中の感情の変化');
      case 'time_rhythm':
        return AppLocaleText.tr(context, en: 'Still watching flow changes', zhHans: '还在观察的节奏变化', zhHant: '還在觀察的節奏變化', ja: 'まだ観察中の流れの変化');
      default:
        return AppLocaleText.tr(context, en: 'Still observing', zhHans: '继续观察', zhHant: '繼續觀察', ja: 'まだ観察中');
    }
  }

  String _itemTitle(dynamic item) {
    if (item is Map) {
      final name = item['name'];
      if (name != null && name.toString().trim().isNotEmpty) {
        return name.toString();
      }
    }
    try {
      return (item as dynamic).name?.toString() ?? item.toString();
    } catch (_) {
      return item.toString();
    }
  }

  String? _itemSubtitle(dynamic item) {
    if (item is Map) {
      final summary = item['summary'];
      if (summary != null && summary.toString().trim().isNotEmpty) {
        return summary.toString();
      }
    }
    try {
      final value = (item as dynamic).summary;
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    } catch (_) {}
    return null;
  }
}

enum _JourneyStationKind {
  recurring,
  friction,
  helping,
  observing,
}

class _JourneyStationData {
  final _JourneyStationKind kind;
  final String title;
  final String summary;
  final List<_JourneyEntry> items;

  const _JourneyStationData({
    required this.kind,
    required this.title,
    required this.summary,
    required this.items,
  });
}

class _JourneyEntry {
  final String title;
  final String summary;
  final String detail;
  final String tag;

  const _JourneyEntry({
    required this.title,
    required this.summary,
    required this.detail,
    required this.tag,
  });
}

class _JourneyRail extends StatelessWidget {
  final List<_JourneyStationData> stations;

  const _JourneyRail({required this.stations});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(stations.length, (index) {
        final station = stations[index];
        return _JourneyStationCard(
          station: station,
          index: index + 1,
          isLast: index == stations.length - 1,
        );
      }),
    );
  }
}

class _JourneyStationCard extends StatelessWidget {
  final _JourneyStationData station;
  final int index;
  final bool isLast;

  const _JourneyStationCard({
    required this.station,
    required this.index,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = switch (station.kind) {
      _JourneyStationKind.recurring => const Color(0xFF5F84C9),
      _JourneyStationKind.friction => const Color(0xFFCC8555),
      _JourneyStationKind.helping => const Color(0xFF63A36C),
      _JourneyStationKind.observing => const Color(0xFF7A6FB4),
    };

    final preview = station.items.take(2).toList();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 3,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            accent.withValues(alpha: 0.38),
                            accent.withValues(alpha: 0.10),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$index. ${station.title}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    station.summary,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (preview.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.34),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        AppLocaleText.tr(
                          context,
                          en: 'No summary at this station yet.',
                          zhHans: '这个车站暂时还没有摘要。',
                          zhHant: '這個車站暫時還沒有摘要。',
                          ja: 'この駅にはまだ要約がありません。',
                        ),
                      ),
                    )
                  else
                    ...preview.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _JourneyPreviewTile(
                          entry: entry,
                          accent: accent,
                          onTap: () => _openEntryDetail(context, station.title, entry, accent),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEntryDetail(
    BuildContext context,
    String stationTitle,
    _JourneyEntry entry,
    Color accent,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stationTitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        entry.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    entry.tag,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  entry.detail,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.65),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _JourneyPreviewTile extends StatelessWidget {
  final _JourneyEntry entry;
  final Color accent;
  final VoidCallback onTap;

  const _JourneyPreviewTile({
    required this.entry,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    entry.summary,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
