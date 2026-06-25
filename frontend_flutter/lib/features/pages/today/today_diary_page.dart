import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/i18n/app_locale_text.dart';
import '../../../core/models/today_models.dart';
import '../../../shared/widgets/aurora_ui.dart';
import 'today_view_model.dart';

enum _DiaryRangeFilter { today, week, all }

class TodayDiaryPage extends StatefulWidget {
  const TodayDiaryPage({super.key});

  @override
  State<TodayDiaryPage> createState() => _TodayDiaryPageState();
}

class _TodayDiaryPageState extends State<TodayDiaryPage> {
  final TextEditingController _searchController = TextEditingController();
  final PageController _pageController = PageController();
  final Set<String> _selectedSourceTypes = <String>{};
  int _pageIndex = 0;
  _DiaryRangeFilter _rangeFilter = _DiaryRangeFilter.today;

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _resetVisiblePage() {
    _pageIndex = 0;
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signals = context.watch<TodayViewModel>().state.recentSignals;
    final filteredSignals = _filterSignals(signals);
    final grouped = _groupSignals(filteredSignals);
    final dayKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    final displayPageIndex =
        dayKeys.isEmpty ? 0 : _pageIndex.clamp(0, dayKeys.length - 1).toInt();

    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          AuroraPage(
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 8),
                    child: Row(
                      children: [
                        AuroraIconButton(
                          icon: Icons.arrow_back_rounded,
                          tooltip: MaterialLocalizations.of(context)
                              .backButtonTooltip,
                          onPressed: () => _goBack(context),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocaleText.tr(
                                  context,
                                  en: 'Diary timeline',
                                  zhHans: '手帐时间线',
                                  zhHant: '手帳時間線',
                                  ja: '手帳タイムライン',
                                ),
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: AuroraColors.ink,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                AppLocaleText.tr(
                                  context,
                                  en: 'Track each signal and the small changes around it.',
                                  zhHans: '记录每一个信号，追踪生活的微小变化。',
                                  zhHant: '記錄每一個信號，追蹤生活的微小變化。',
                                  ja: '一つひとつのシグナルと、小さな変化を残します。',
                                ),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AuroraColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (dayKeys.isNotEmpty)
                          Text(
                            '${displayPageIndex + 1} / ${dayKeys.length}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: AuroraColors.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: _SegmentBar(
                            labels: [
                              AppLocaleText.tr(context,
                                  en: 'Today',
                                  zhHans: '今天',
                                  zhHant: '今天',
                                  ja: '今日'),
                              AppLocaleText.tr(context,
                                  en: 'This week',
                                  zhHans: '本周',
                                  zhHant: '本週',
                                  ja: '今週'),
                              AppLocaleText.tr(context,
                                  en: 'All',
                                  zhHans: '全部',
                                  zhHant: '全部',
                                  ja: 'すべて'),
                            ],
                            selectedIndex: _rangeFilter.index,
                            onSelected: (index) {
                              setState(() {
                                _rangeFilter = _DiaryRangeFilter.values[index];
                                _resetVisiblePage();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SearchPill(
                            controller: _searchController,
                            hint: AppLocaleText.tr(
                              context,
                              en: 'Search diary...',
                              zhHans: '搜索手帐内容...',
                              zhHant: '搜尋手帳內容...',
                              ja: '手帳を検索...',
                            ),
                            hasActiveFilters: _selectedSourceTypes.isNotEmpty,
                            onChanged: (_) => setState(_resetVisiblePage),
                            onFilterPressed: () =>
                                _showSourceFilterSheet(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: dayKeys.isEmpty
                        ? _EmptyDiaryState()
                        : PageView.builder(
                            key: const ValueKey('today-diary-page-view'),
                            controller: _pageController,
                            itemCount: dayKeys.length,
                            onPageChanged: (index) =>
                                setState(() => _pageIndex = index),
                            itemBuilder: (context, index) {
                              final dayKey = dayKeys[index];
                              return _DiaryDayPage(
                                dayKey: dayKey,
                                signals: grouped[dayKey]!,
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          const AuroraSafeTopMask(),
        ],
      ),
    );
  }

  List<RecentSignalModel> _filterSignals(List<RecentSignalModel> signals) {
    final query = _searchController.text.trim().toLowerCase();
    return signals.where((signal) {
      if (!_matchesRange(signal)) return false;
      if (_selectedSourceTypes.isNotEmpty &&
          !_selectedSourceTypes.contains(signal.sourceType)) {
        return false;
      }
      if (query.isNotEmpty && !_matchesQuery(signal, query)) return false;
      return true;
    }).toList();
  }

  bool _matchesRange(RecentSignalModel signal) {
    if (_rangeFilter == _DiaryRangeFilter.all) return true;
    final signalDate = _signalLocalDate(signal);
    if (signalDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_rangeFilter == _DiaryRangeFilter.today) {
      return signalDate == today;
    }
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    return !signalDate.isBefore(weekStart) && !signalDate.isAfter(today);
  }

  DateTime? _signalLocalDate(RecentSignalModel signal) {
    final rawLocalDate = signal.localDate?.trim();
    if (rawLocalDate != null && rawLocalDate.isNotEmpty) {
      final parsed = DateTime.tryParse(rawLocalDate);
      if (parsed != null) {
        return DateTime(parsed.year, parsed.month, parsed.day);
      }
    }
    final createdAt = signal.createdAt?.toLocal();
    if (createdAt == null) return null;
    return DateTime(createdAt.year, createdAt.month, createdAt.day);
  }

  bool _matchesQuery(RecentSignalModel signal, String query) {
    final values = <String?>[
      signal.content,
      signal.acknowledgement,
      signal.observation,
      signal.tryNext,
      signal.emotion,
      signal.intensity,
      signal.scene,
      signal.friction,
      signal.positiveSignal,
      signal.energyLoad,
      signal.userConfirmation,
      signal.sourceType,
      ...signal.sceneTags,
      ...signal.intentTags,
      ...signal.linkedLifeChainStages,
      ...signal.rawPayloadJson.values.map((value) => value?.toString()),
      ...signal.userCorrectionJson.values.map((value) => value?.toString()),
    ];
    return values.any((value) => value?.toLowerCase().contains(query) ?? false);
  }

  Future<void> _showSourceFilterSheet(BuildContext context) async {
    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final draftSelection = Set<String>.from(_selectedSourceTypes);
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 26,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AuroraColors.line,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    AppLocaleText.tr(
                      context,
                      en: 'Filter diary records',
                      zhHans: '筛选手帐记录',
                      zhHant: '篩選手帳記錄',
                      ja: '手帳記録を絞り込む',
                    ),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AuroraColors.ink,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final option in _sourceOptions(context))
                        FilterChip(
                          selected: draftSelection.contains(option.type),
                          label: Text(option.label),
                          avatar: Icon(option.icon, size: 18),
                          selectedColor:
                              AuroraColors.purple.withValues(alpha: 0.14),
                          checkmarkColor: AuroraColors.purple,
                          onSelected: (value) {
                            setModalState(() {
                              if (value) {
                                draftSelection.add(option.type);
                              } else {
                                draftSelection.remove(option.type);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () =>
                            setModalState(() => draftSelection.clear()),
                        child: Text(
                          AppLocaleText.tr(
                            context,
                            en: 'All types',
                            zhHans: '全部类型',
                            zhHant: '全部類型',
                            ja: 'すべて',
                          ),
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 124,
                        child: AuroraPillButton(
                          filled: true,
                          label: AppLocaleText.tr(
                            context,
                            en: 'Apply',
                            zhHans: '应用',
                            zhHant: '套用',
                            ja: '適用',
                          ),
                          onPressed: () =>
                              Navigator.of(context).pop(draftSelection),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selectedSourceTypes
        ..clear()
        ..addAll(selected);
      _resetVisiblePage();
    });
  }

  List<_DiarySourceOption> _sourceOptions(BuildContext context) {
    return [
      _DiarySourceOption(
        type: 'text',
        label: AppLocaleText.tr(context,
            en: 'Text', zhHans: '文字', zhHant: '文字', ja: 'テキスト'),
        icon: Icons.text_fields_rounded,
      ),
      _DiarySourceOption(
        type: 'voice',
        label: AppLocaleText.tr(context,
            en: 'Voice', zhHans: '语音', zhHant: '語音', ja: '音声'),
        icon: Icons.mic_rounded,
      ),
      _DiarySourceOption(
        type: 'one_tap',
        label: AppLocaleText.tr(context,
            en: 'Status', zhHans: '状态', zhHant: '狀態', ja: '状態'),
        icon: Icons.mood_rounded,
      ),
      _DiarySourceOption(
        type: 'calendar',
        label: AppLocaleText.tr(context,
            en: 'Schedule', zhHans: '安排', zhHant: '安排', ja: '予定'),
        icon: Icons.calendar_month_rounded,
      ),
      _DiarySourceOption(
        type: 'ai_predicted',
        label: AppLocaleText.tr(context,
            en: 'AI predicted', zhHans: 'AI 预判', zhHant: 'AI 預判', ja: 'AI 予測'),
        icon: Icons.auto_awesome_rounded,
      ),
      _DiarySourceOption(
        type: 'library_saved',
        label: AppLocaleText.tr(context,
            en: 'Library', zhHans: '信号库', zhHant: '信號庫', ja: 'ライブラリ'),
        icon: Icons.bookmark_rounded,
      ),
    ];
  }

  Map<String, List<RecentSignalModel>> _groupSignals(
    List<RecentSignalModel> signals,
  ) {
    final grouped = <String, List<RecentSignalModel>>{};
    for (final signal in signals) {
      final key = signal.localDateKey();
      if (key.isEmpty) continue;
      grouped.putIfAbsent(key, () => []).add(signal);
    }
    for (final items in grouped.values) {
      items.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aTime.compareTo(bTime);
      });
    }
    return grouped;
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.today);
    }
  }
}

class _DiarySourceOption {
  final String type;
  final String label;
  final IconData icon;

  const _DiarySourceOption({
    required this.type,
    required this.label,
    required this.icon,
  });
}

class _DiaryDayPage extends StatelessWidget {
  final String dayKey;
  final List<RecentSignalModel> signals;

  const _DiaryDayPage({
    required this.dayKey,
    required this.signals,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 120),
      children: [
        Text(
          dayKey,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: AuroraColors.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          AppLocaleText.tr(
            context,
            en: '${signals.length} saved signals',
            zhHans: '保存了 ${signals.length} 条信号',
            zhHant: '保存了 ${signals.length} 條信號',
            ja: '${signals.length} 件のシグナル',
          ),
          style: theme.textTheme.bodySmall?.copyWith(color: AuroraColors.muted),
        ),
        const SizedBox(height: 18),
        for (var index = 0; index < signals.length; index++)
          _TimelineRow(
            signal: signals[index],
            isLast: index == signals.length - 1,
          ),
      ],
    );
  }
}

class _SegmentBar extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _SegmentBar({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selectedIndex,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelected(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == selectedIndex
                          ? AuroraColors.purple.withValues(alpha: 0.13)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: i == selectedIndex
                                ? AuroraColors.purple
                                : AuroraColors.ink,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchPill extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool hasActiveFilters;
  final ValueChanged<String> onChanged;
  final VoidCallback onFilterPressed;

  const _SearchPill({
    required this.controller,
    required this.hint,
    required this.hasActiveFilters,
    required this.onChanged,
    required this.onFilterPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 19, color: AuroraColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              key: const ValueKey('today-diary-search-field'),
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: hint,
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintStyle: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AuroraColors.muted),
              ),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AuroraColors.ink),
            ),
          ),
          Container(width: 1, height: 18, color: AuroraColors.line),
          const SizedBox(width: 4),
          IconButton(
            key: const ValueKey('today-diary-filter-button'),
            tooltip: AppLocaleText.tr(
              context,
              en: 'Filter',
              zhHans: '筛选',
              zhHant: '篩選',
              ja: '絞り込み',
            ),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
            onPressed: onFilterPressed,
            icon: Icon(
              Icons.tune_rounded,
              size: 18,
              color:
                  hasActiveFilters ? AuroraColors.purple : AuroraColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDiaryState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: AuroraCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AuroraLandscapeMedallion(size: 84),
              const SizedBox(height: 18),
              Text(
                AppLocaleText.tr(
                  context,
                  en: 'No diary records yet',
                  zhHans: '手帐里还没有记录',
                  zhHant: '手帳裡還沒有記錄',
                  ja: '手帳にはまだ記録がありません',
                ),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AuroraColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocaleText.tr(
                  context,
                  en: 'Things you save in Today will appear here by date.',
                  zhHans: '你在今天保存的内容，会按日期放在这里。',
                  zhHant: '你在今天保存的內容，會按日期放在這裡。',
                  ja: '今日に保存した内容が、日付ごとにここへ並びます。',
                ),
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AuroraColors.muted, height: 1.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final RecentSignalModel signal;
  final bool isLast;

  const _TimelineRow({
    required this.signal,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final color = _signalColor(signal);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatTime(signal.createdAt),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AuroraColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  _kindLabel(context, signal),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 15,
                  height: 15,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.22),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AuroraColors.purple.withValues(alpha: 0.16),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: _DiarySignalCard(signal: signal)),
        ],
      ),
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '--:--';
    final local = time.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _kindLabel(BuildContext context, RecentSignalModel signal) {
    if (signal.sourceType == 'calendar') {
      return AppLocaleText.tr(context,
          en: 'Schedule', zhHans: '日程相关', zhHant: '日程相關', ja: '予定');
    }
    if (signal.sourceType == 'voice') {
      return AppLocaleText.tr(context,
          en: 'Voice', zhHans: '语音记录', zhHant: '語音記錄', ja: '音声');
    }
    if (signal.sourceType == 'ai_predicted') {
      return AppLocaleText.tr(context,
          en: 'AI reflection', zhHans: 'AI 回顾', zhHant: 'AI 回顧', ja: 'AI 回顧');
    }
    if (signal.sourceType == 'library_saved') {
      return AppLocaleText.tr(context,
          en: 'Library', zhHans: '信号库', zhHant: '信號庫', ja: 'ライブラリ');
    }
    return AppLocaleText.tr(context,
        en: 'Signal', zhHans: '信号记录', zhHant: '信號記錄', ja: 'シグナル');
  }

  Color _signalColor(RecentSignalModel signal) {
    if (signal.sourceType == 'calendar') return AuroraColors.orange;
    if (signal.sourceType == 'voice') return AuroraColors.blue;
    if (signal.sourceType == 'library_saved') return AuroraColors.mint;
    if (signal.sourceType == 'ai_predicted') return AuroraColors.purple;
    if (signal.energyLoad == 'restoring') return AuroraColors.mint;
    if (signal.energyLoad == 'draining') return AuroraColors.orange;
    return AuroraColors.purple;
  }
}

class _DiarySignalCard extends StatelessWidget {
  final RecentSignalModel signal;

  const _DiarySignalCard({required this.signal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reply = signal.acknowledgement?.trim();

    final color = _signalColor(signal);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: AuroraCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AuroraSoftIconCircle(
                  icon: _signalIcon(signal),
                  color: color,
                  size: 42,
                  iconSize: 21,
                ),
                const Spacer(),
                Icon(Icons.more_horiz_rounded,
                    color: AuroraColors.muted.withValues(alpha: 0.76)),
              ],
            ),
            const SizedBox(height: 10),
            if (signal.isLibrarySaved)
              Text(
                AppLocaleText.tr(
                  context,
                  en: 'Saved from Signal Library',
                  zhHans: '来自信号库的观察',
                  zhHant: '來自信號庫的觀察',
                  ja: 'シグナルライブラリから保存',
                ),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            if (signal.isLibrarySaved) const SizedBox(height: 6),
            Text(
              signal.content.trim().isEmpty
                  ? _libraryTitle(signal)
                  : signal.content,
              style: theme.textTheme.titleSmall?.copyWith(
                color: AuroraColors.ink,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
            if (reply != null && reply.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F2FF).withValues(alpha: 0.70),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.7)),
                ),
                child: Text(
                  reply,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AuroraColors.ink,
                    height: 1.45,
                  ),
                ),
              ),
            ],
            if (_statusLabels(context).isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _statusLabels(context)
                    .map(
                      (label) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _chipColor(label).withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: _chipColor(label),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 12),
            _DiaryReactivateCard(signal: signal),
          ],
        ),
      ),
    );
  }

  IconData _signalIcon(RecentSignalModel signal) {
    if (signal.sourceType == 'calendar') return Icons.calendar_month_rounded;
    if (signal.sourceType == 'voice') return Icons.mic_rounded;
    if (signal.sourceType == 'library_saved') return Icons.bookmark_rounded;
    if (signal.sourceType == 'ai_predicted') return Icons.auto_awesome_rounded;
    return Icons.auto_awesome_rounded;
  }

  Color _signalColor(RecentSignalModel signal) {
    if (signal.sourceType == 'calendar') return AuroraColors.orange;
    if (signal.sourceType == 'voice') return AuroraColors.blue;
    if (signal.sourceType == 'library_saved') return AuroraColors.mint;
    if (signal.sourceType == 'ai_predicted') return AuroraColors.purple;
    if (signal.energyLoad == 'restoring') return AuroraColors.mint;
    if (signal.energyLoad == 'draining') return AuroraColors.orange;
    return AuroraColors.purple;
  }

  Color _chipColor(String label) {
    if (label.contains('库') ||
        label.contains('Library') ||
        label.contains('ライブラリ')) {
      return AuroraColors.mint;
    }
    if (label.contains('同步') ||
        label.contains('sync') ||
        label.contains('同期')) {
      return AuroraColors.orange;
    }
    return AuroraColors.purple;
  }

  String _libraryTitle(RecentSignalModel signal) {
    return signal.rawPayloadJson['title']?.toString().trim() ??
        signal.rawPayloadJson['abstract_pattern']?.toString().trim() ??
        '';
  }

  List<String> _statusLabels(BuildContext context) {
    return [
      if (signal.isLegacy)
        AppLocaleText.tr(
          context,
          en: 'Imported',
          zhHans: '旧记录已导入',
          zhHant: '舊記錄已導入',
          ja: '移行済み',
        ),
      if (signal.isLocalDraft)
        AppLocaleText.tr(
          context,
          en: 'Saved on device',
          zhHans: '已保存在本机',
          zhHant: '已保存在本機',
          ja: '端末に保存済み',
        ),
      if (signal.syncFailed)
        AppLocaleText.tr(
          context,
          en: 'Waiting to sync',
          zhHans: '等待同步',
          zhHant: '等待同步',
          ja: '同期待ち',
        ),
      if (signal.isLibrarySaved)
        AppLocaleText.tr(
          context,
          en: 'Private observation',
          zhHans: '私密观察',
          zhHant: '私密觀察',
          ja: 'プライベート観察',
        ),
    ];
  }
}

class _DiaryReactivateCard extends StatelessWidget {
  final RecentSignalModel signal;

  const _DiaryReactivateCard({required this.signal});

  @override
  Widget build(BuildContext context) {
    final raw = signal.content.trim().isEmpty
        ? signal.rawPayloadJson['title']?.toString().trim()
        : signal.content.trim();
    final shortSignal = (raw ?? '').length > 20
        ? '${(raw ?? '').substring(0, 20).trim()}...'
        : (raw ?? '');

    void showSaved(String message) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AuroraColors.purple.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.72),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AuroraSoftIconCircle(
                icon: Icons.replay_rounded,
                color: AuroraColors.purple,
                size: 34,
                iconSize: 17,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Does this still come back?',
                    zhHans: '这条记录还在反复出现吗？',
                    zhHant: '這條記錄還在反覆出現嗎？',
                    ja: 'この記録はまだ繰り返していますか？',
                  ),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AuroraColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          if (shortSignal.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              AppLocaleText.tr(
                    context,
                    en: 'Signal: ',
                    zhHans: '围绕：',
                    zhHant: '圍繞：',
                    ja: 'シグナル：',
                  ) +
                  shortSignal,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AuroraColors.muted,
                    height: 1.35,
                  ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DiaryReactivateButton(
                label: AppLocaleText.tr(
                  context,
                  en: 'Still here',
                  zhHans: '还在',
                  zhHant: '還在',
                  ja: 'まだある',
                ),
                onPressed: () => showSaved(AppLocaleText.tr(
                  context,
                  en: 'Saved as a clue for later judgement.',
                  zhHans: '已作为后续判断线索保存。',
                  zhHant: '已作為後續判斷線索保存。',
                  ja: '後で見る手がかりとして保存しました。',
                )),
              ),
              _DiaryReactivateButton(
                label: AppLocaleText.tr(
                  context,
                  en: 'Better now',
                  zhHans: '已经好了',
                  zhHant: '已經好了',
                  ja: 'もう大丈夫',
                ),
                onPressed: () => showSaved(AppLocaleText.tr(
                  context,
                  en: 'Noted.',
                  zhHans: '已记录。',
                  zhHant: '已記錄。',
                  ja: '記録しました。',
                )),
              ),
              _DiaryReactivateButton(
                label: AppLocaleText.tr(
                  context,
                  en: 'Not sure',
                  zhHans: '不确定',
                  zhHant: '不確定',
                  ja: 'まだ不明',
                ),
                onPressed: () => showSaved(AppLocaleText.tr(
                  context,
                  en: 'Kept as an observation.',
                  zhHans: '先保留为观察。',
                  zhHant: '先保留為觀察。',
                  ja: '観察として残しました。',
                )),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DiaryReactivateButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _DiaryReactivateButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AuroraColors.purple,
        backgroundColor: Colors.white.withValues(alpha: 0.76),
        side: BorderSide(color: AuroraColors.purple.withValues(alpha: 0.16)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(label),
    );
  }
}
