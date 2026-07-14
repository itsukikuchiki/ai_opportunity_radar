import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/i18n/app_locale_text.dart';
import '../../../core/models/today_models.dart';
import '../../../shared/utils/user_visible_text_sanitizer.dart';
import '../../../shared/widgets/aurora_ui.dart';
import 'today_view_model.dart';

enum _TimelineFilter { all, record, action, experiment }

class TodayDiaryPage extends StatefulWidget {
  final String? initialDateKey;

  const TodayDiaryPage({
    super.key,
    this.initialDateKey,
  });

  @override
  State<TodayDiaryPage> createState() => _TodayDiaryPageState();
}

class _TodayDiaryPageState extends State<TodayDiaryPage> {
  _TimelineFilter _filter = _TimelineFilter.all;

  @override
  Widget build(BuildContext context) {
    final signals = context.watch<TodayViewModel>().state.recentSignals;
    final entries = _buildEntries(signals)
        .where((entry) =>
            _filter == _TimelineFilter.all || entry.filter == _filter)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final displayDate = _displayDate(entries);

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          AuroraPage(
            child: SafeArea(
              bottom: false,
              child: CustomScrollView(
                key: const ValueKey('today-diary-scroll-view'),
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (Navigator.of(context).canPop()) ...[
                            _BackButtonPill(
                              onTap: () => Navigator.of(context).maybePop(),
                            ),
                            const SizedBox(height: 4),
                          ],
                          _TimelineHero(
                            title: AppLocaleText.tr(
                              context,
                              en: 'Diary Timeline',
                              zhHans: '手帐时间线',
                              zhHant: '手帳時間線',
                              ja: '手帳タイムライン',
                            ),
                            subtitle: AppLocaleText.tr(
                              context,
                              en: 'Connect today’s signals, small actions, and small experiments.',
                              zhHans: '把今天的信号、小行动和小实验串起来。',
                              zhHant: '把今天的信號、小行動和小實驗串起來。',
                              ja: '今日のシグナル、小さな行動、小さな実験をつなぎます。',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: _TimelineFilterBar(
                        selected: _filter,
                        onSelected: (filter) => setState(() {
                          _filter = filter;
                        }),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: _DateHeader(date: displayDate),
                    ),
                  ),
                  if (entries.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyDiaryState(filter: _filter),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
                        MediaQuery.paddingOf(context).bottom + 150,
                      ),
                      sliver: SliverList.builder(
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          return _TimelineEntryRow(
                            entry: entry,
                            isFirst: index == 0,
                            isLast: index == entries.length - 1,
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          const AuroraSafeTopMask(extraHeight: 6),
        ],
      ),
      bottomNavigationBar: const _DiaryBottomNavigation(),
    );
  }

  List<_TimelineEntry> _buildEntries(List<RecentSignalModel> signals) {
    final now = DateTime.now();
    final selected = _TimelineEntry._parseLocalDate(widget.initialDateKey);
    final today = selected ?? DateTime(now.year, now.month, now.day);
    return [
      for (final signal in signals.where((signal) {
        if (_isLegacyScheduleSource(signal.sourceType)) return false;
        final date = _TimelineEntry._parseLocalDate(signal.localDate) ??
            signal.createdAt?.toLocal();
        if (date == null) return false;
        return date.year == today.year &&
            date.month == today.month &&
            date.day == today.day;
      }))
        _TimelineEntry.fromSignal(signal),
    ];
  }

  bool _isLegacyScheduleSource(String sourceType) {
    final normalized = sourceType.toLowerCase();
    return normalized.contains('schedule') ||
        normalized == 'calendar' ||
        normalized == 'goal' ||
        normalized.startsWith('goal_');
  }

  DateTime _displayDate(List<_TimelineEntry> entries) {
    if (entries.isNotEmpty) {
      final date = entries.first.localDate ?? entries.first.createdAt;
      return DateTime(date.year, date.month, date.day);
    }
    final selected = _TimelineEntry._parseLocalDate(widget.initialDateKey);
    if (selected != null) return selected;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}

class _BackButtonPill extends StatelessWidget {
  final VoidCallback onTap;

  const _BackButtonPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.78),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.92)),
            boxShadow: [
              BoxShadow(
                color: AuroraColors.purple.withValues(alpha: 0.12),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AuroraColors.ink, size: 18),
        ),
      ),
    );
  }
}

class _TimelineHero extends StatelessWidget {
  final String title;
  final String subtitle;

  const _TimelineHero({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('today-diary-hero'),
      height: 116,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -2,
            top: -8,
            width: 96,
            height: 96,
            child: IgnorePointer(
              child: CustomPaint(painter: _DiarySignalOrbPainter()),
            ),
          ),
          const Positioned(
            right: 56,
            top: 6,
            child: _Sparkle(size: 13, opacity: 0.72),
          ),
          const Positioned(
            right: 8,
            top: 86,
            child: _Sparkle(size: 7, opacity: 0.64),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontSize: 34,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                        foreground: Paint()
                          ..shader = const LinearGradient(
                            colors: [
                              Color(0xFF5A86F5),
                              Color(0xFF8D65F4),
                            ],
                          ).createShader(const Rect.fromLTWH(0, 0, 240, 48)),
                      ),
                ),
                const SizedBox(height: 7),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 270),
                  child: Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF6E7488),
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineFilterBar extends StatelessWidget {
  final _TimelineFilter selected;
  final ValueChanged<_TimelineFilter> onSelected;

  const _TimelineFilterBar({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _TimelineFilterItem(
        filter: _TimelineFilter.all,
        icon: Icons.grid_view_rounded,
        label: AppLocaleText.tr(
          context,
          en: 'All',
          zhHans: '全部',
          zhHant: '全部',
          ja: 'すべて',
        ),
      ),
      _TimelineFilterItem(
        filter: _TimelineFilter.record,
        icon: Icons.chat_bubble_rounded,
        label: AppLocaleText.tr(
          context,
          en: 'Records',
          zhHans: '记录',
          zhHant: '記錄',
          ja: '記録',
        ),
      ),
      _TimelineFilterItem(
        filter: _TimelineFilter.action,
        icon: Icons.spa_rounded,
        label: AppLocaleText.tr(
          context,
          en: 'Actions',
          zhHans: '小行动',
          zhHant: '小行動',
          ja: '行動',
        ),
      ),
      _TimelineFilterItem(
        filter: _TimelineFilter.experiment,
        icon: Icons.science_rounded,
        label: AppLocaleText.tr(
          context,
          en: 'Experiment',
          zhHans: '小实验',
          zhHant: '小實驗',
          ja: '実験',
        ),
      ),
    ];

    return SizedBox(
      key: const ValueKey('today-diary-filter-bar'),
      height: 40,
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            Expanded(
              child: _FilterPill(
                item: items[i],
                selected: selected == items[i].filter,
                onTap: () => onSelected(items[i].filter),
              ),
            ),
            if (i != items.length - 1) const SizedBox(width: 5),
          ],
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final _TimelineFilterItem item;
  final bool selected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xFF8D5DF6), Color(0xFFBD8CFF)],
                  )
                : null,
            color: selected ? null : Colors.white.withValues(alpha: 0.66),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? Colors.white.withValues(alpha: 0.72)
                  : Colors.white.withValues(alpha: 0.88),
            ),
            boxShadow: [
              BoxShadow(
                color: (selected ? AuroraColors.purple : Colors.white)
                    .withValues(alpha: selected ? 0.28 : 0.20),
                blurRadius: selected ? 16 : 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  item.icon,
                  size: 16,
                  color: selected ? Colors.white : const Color(0xFF878EA2),
                ),
                const SizedBox(width: 4),
                Text(
                  item.label,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color:
                            selected ? Colors.white : const Color(0xFF697083),
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  final DateTime date;

  const _DateHeader({required this.date});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final isToday = today.year == date.year &&
        today.month == date.month &&
        today.day == date.day;
    final weekday = _weekdayLabel(context, date.weekday);
    final dateText = '${date.month}月${date.day}日';

    return Row(
      key: const ValueKey('today-diary-date-header'),
      children: [
        const Icon(
          Icons.calendar_month_rounded,
          color: AuroraColors.purple,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          isToday
              ? AppLocaleText.tr(
                  context,
                  en: 'Today',
                  zhHans: '今天',
                  zhHant: '今天',
                  ja: '今日',
                )
              : '${date.month}/${date.day}',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AuroraColors.purple,
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(width: 6),
        Text(
          '| $dateText  $weekday',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: const Color(0xFF4A5165),
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }

  String _weekdayLabel(BuildContext context, int weekday) {
    const zh = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    const en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const ja = ['月', '火', '水', '木', '金', '土', '日'];
    final language = Localizations.localeOf(context).languageCode;
    if (language == 'ja') return ja[weekday - 1];
    if (language == 'zh') return zh[weekday - 1];
    return en[weekday - 1];
  }
}

class _TimelineEntryRow extends StatelessWidget {
  final _TimelineEntry entry;
  final bool isFirst;
  final bool isLast;

  const _TimelineEntryRow({
    required this.entry,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 22,
            child: Column(
              children: [
                if (!isFirst)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Colors.white.withValues(alpha: 0.96),
                    ),
                  )
                else
                  const SizedBox(height: 4),
                _TimelineNode(color: entry.color),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Colors.white.withValues(alpha: 0.96),
                    ),
                  )
                else
                  const SizedBox(height: 14),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _TimelineEntryCard(entry: entry),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineNode extends StatelessWidget {
  final Color color;

  const _TimelineNode({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.82),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.28),
            blurRadius: 10,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.white,
                color.withValues(alpha: 0.92),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimelineEntryCard extends StatelessWidget {
  final _TimelineEntry entry;

  const _TimelineEntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const ValueKey('today-diary-entry-card'),
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.64),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.90)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7568A6).withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Text(
              entry.timeLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF687084),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _TimelineEntryIcon(entry: entry),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: entry.color,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF454C62),
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
                if (entry.tagLabel != null) ...[
                  const SizedBox(height: 6),
                  AuroraChip(label: entry.tagLabel!, color: entry.color),
                ],
                if (entry.feedbackLabel != null) ...[
                  const SizedBox(height: 6),
                  _FeedbackMiniPill(
                    label: entry.feedbackLabel!,
                    color: entry.color,
                  ),
                ],
                if (entry.progressText != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: entry.progressValue,
                            minHeight: 5,
                            backgroundColor:
                                AuroraColors.purple.withValues(alpha: 0.12),
                            color: AuroraColors.purple,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        entry.progressText!,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: const Color(0xFF6B7184),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            children: [
              _MiniActionButton(
                label: 'AI',
                onTap: () => _openAiDialog(context, entry),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openAiDialog(BuildContext context, _TimelineEntry entry) {
    final captureId = entry.captureId;
    if (captureId == null || captureId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocaleText.tr(
              context,
              en: 'This record cannot open AI chat yet.',
              zhHans: '这条记录暂时还不能打开 AI 聊聊。',
              zhHant: '這條記錄暫時還不能打開 AI 聊聊。',
              ja: 'この記録はまだ AI チャットを開けません。',
            ),
          ),
        ),
      );
      return;
    }
    context.push('${AppRoutes.todayDialog}/$captureId');
  }
}

class _TimelineEntryIcon extends StatelessWidget {
  final _TimelineEntry entry;

  const _TimelineEntryIcon({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.45),
          colors: [
            Colors.white.withValues(alpha: 0.95),
            entry.color.withValues(alpha: 0.48),
            entry.color.withValues(alpha: 0.76),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
        boxShadow: [
          BoxShadow(
            color: entry.color.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(entry.icon, color: Colors.white, size: 21),
    );
  }
}

class _FeedbackMiniPill extends StatelessWidget {
  final String label;
  final Color color;

  const _FeedbackMiniPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.95),
            AuroraColors.purple.withValues(alpha: 0.76),
          ],
        ),
        borderRadius: BorderRadius.circular(99),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _MiniActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _MiniActionButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: onTap,
      child: Container(
        width: 36,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.66),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: Colors.white.withValues(alpha: 0.90)),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AuroraColors.purple,
                fontWeight: FontWeight.w900,
              ),
        ),
      ),
    );
  }
}

class _EmptyDiaryState extends StatelessWidget {
  final _TimelineFilter filter;

  const _EmptyDiaryState({required this.filter});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 120),
      child: AuroraCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AuroraCrystalIllustration(width: 112, height: 88),
            const SizedBox(height: 16),
            Text(
              _title(context),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AuroraColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocaleText.tr(
                context,
                en: 'Records saved from Today will appear here in order.',
                zhHans: '从 Today 保存的内容，会按时间放在这里。',
                zhHant: '從 Today 保存的內容，會按時間放在這裡。',
                ja: 'Today で保存した内容が時間順にここへ並びます。',
              ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AuroraColors.muted,
                    height: 1.45,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  String _title(BuildContext context) {
    switch (filter) {
      case _TimelineFilter.record:
        return AppLocaleText.tr(
          context,
          en: 'No records yet',
          zhHans: '还没有记录',
          zhHant: '還沒有記錄',
          ja: '記録はまだありません',
        );
      case _TimelineFilter.action:
        return AppLocaleText.tr(
          context,
          en: 'No small actions yet',
          zhHans: '还没有小行动',
          zhHant: '還沒有小行動',
          ja: '小さな行動はまだありません',
        );
      case _TimelineFilter.experiment:
        return AppLocaleText.tr(
          context,
          en: 'No small experiments yet',
          zhHans: '还没有小实验',
          zhHant: '還沒有小實驗',
          ja: '実験はまだありません',
        );
      case _TimelineFilter.all:
        return AppLocaleText.tr(
          context,
          en: 'No timeline records yet',
          zhHans: '手帐里还没有记录',
          zhHant: '手帳裡還沒有記錄',
          ja: '手帳にはまだ記録がありません',
        );
    }
  }
}

class _DiaryBottomNavigation extends StatelessWidget {
  const _DiaryBottomNavigation();

  @override
  Widget build(BuildContext context) {
    final items = [
      const _DiaryNavItem(
        label: 'Today',
        icon: Icons.wb_sunny_outlined,
        selectedIcon: Icons.wb_sunny_rounded,
        route: AppRoutes.today,
        selected: true,
      ),
      const _DiaryNavItem(
        label: 'Weekly',
        icon: Icons.bar_chart_rounded,
        selectedIcon: Icons.bar_chart_rounded,
        route: AppRoutes.weekly,
      ),
      const _DiaryNavItem(
        label: 'Experiment',
        icon: Icons.science_outlined,
        selectedIcon: Icons.science_rounded,
        route: AppRoutes.experiment,
      ),
      const _DiaryNavItem(
        label: 'Journey',
        icon: Icons.explore_outlined,
        selectedIcon: Icons.explore_rounded,
        route: AppRoutes.memory,
      ),
      const _DiaryNavItem(
        label: 'Me',
        icon: Icons.person_outline_rounded,
        selectedIcon: Icons.person_rounded,
        route: AppRoutes.me,
      ),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
        child: Container(
          height: 74,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.84),
            borderRadius: BorderRadius.circular(31),
            border: Border.all(color: Colors.white.withValues(alpha: 0.95)),
            boxShadow: [
              BoxShadow(
                color: AuroraColors.purple.withValues(alpha: 0.14),
                blurRadius: 32,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Row(
            children: [
              for (final item in items)
                Expanded(child: _DiaryNavPill(item: item)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiaryNavPill extends StatelessWidget {
  final _DiaryNavItem item;

  const _DiaryNavPill({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => item.selected ? null : context.go(item.route),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 38,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: item.selected
                  ? const RadialGradient(
                      colors: [Color(0xFFB59AFF), Color(0xFF8063F4)],
                    )
                  : null,
              boxShadow: item.selected
                  ? [
                      BoxShadow(
                        color: AuroraColors.purple.withValues(alpha: 0.34),
                        blurRadius: 18,
                        offset: const Offset(0, 7),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              item.selected ? item.selectedIcon : item.icon,
              color: item.selected ? Colors.white : const Color(0xFF9498AE),
              size: 23,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: item.selected
                      ? AuroraColors.purple
                      : const Color(0xFF747989),
                  fontWeight: item.selected ? FontWeight.w900 : FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _TimelineEntry {
  final String? captureId;
  final DateTime createdAt;
  final DateTime? localDate;
  final String timeLabel;
  final String title;
  final String body;
  final String? tagLabel;
  final String? feedbackLabel;
  final String? progressText;
  final double? progressValue;
  final IconData icon;
  final Color color;
  final _TimelineFilter filter;

  const _TimelineEntry({
    required this.captureId,
    required this.createdAt,
    required this.localDate,
    required this.timeLabel,
    required this.title,
    required this.body,
    required this.tagLabel,
    required this.feedbackLabel,
    required this.progressText,
    required this.progressValue,
    required this.icon,
    required this.color,
    required this.filter,
  });

  factory _TimelineEntry.fromSignal(RecentSignalModel signal) {
    final createdAt = signal.createdAt?.toLocal() ?? DateTime.now();
    final localDate = _parseLocalDate(signal.localDate) ??
        DateTime(createdAt.year, createdAt.month, createdAt.day);
    final kind = _kindForSignal(signal);
    final feedback = _feedbackLabel(signal);
    final progress = _progress(signal);
    return _TimelineEntry(
      captureId: signal.signalCardId ?? signal.id,
      createdAt: createdAt,
      localDate: localDate,
      timeLabel:
          '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}',
      title: kind.title,
      body: _body(signal),
      tagLabel: kind.tagLabel(signal),
      feedbackLabel: feedback,
      progressText: progress?.$1,
      progressValue: progress?.$2,
      icon: kind.icon,
      color: kind.color,
      filter: kind.filter,
    );
  }

  static DateTime? _parseLocalDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(raw.trim());
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static _TimelineEntryKind _kindForSignal(RecentSignalModel signal) {
    final source = signal.sourceType;
    final payloadKind = signal.rawPayloadJson['timeline_type']?.toString() ??
        signal.rawPayloadJson['kind']?.toString() ??
        '';
    if (source == 'micro_action' ||
        source == 'daily_action' ||
        payloadKind == 'micro_action') {
      return const _TimelineEntryKind(
        title: '今日小行动',
        icon: Icons.spa_rounded,
        color: Color(0xFF45C9C3),
        filter: _TimelineFilter.action,
      );
    }
    if (source == 'feedback' || payloadKind == 'feedback') {
      return const _TimelineEntryKind(
        title: '小行动记录',
        icon: Icons.favorite_rounded,
        color: Color(0xFFFF70B1),
        filter: _TimelineFilter.action,
      );
    }
    if (source == 'weekly_experiment' ||
        source == 'experiment' ||
        payloadKind == 'experiment') {
      return const _TimelineEntryKind(
        title: '本周小实验',
        icon: Icons.science_rounded,
        color: AuroraColors.purple,
        filter: _TimelineFilter.experiment,
      );
    }
    if (source == 'one_tap' || source == 'status') {
      return const _TimelineEntryKind(
        title: '状态',
        icon: Icons.mood_rounded,
        color: AuroraColors.orange,
        filter: _TimelineFilter.record,
      );
    }
    if (source == 'ai_predicted') {
      return const _TimelineEntryKind(
        title: 'AI',
        icon: Icons.text_fields_rounded,
        color: AuroraColors.blue,
        filter: _TimelineFilter.record,
      );
    }
    if (source == 'voice') {
      return const _TimelineEntryKind(
        title: '语音记录',
        icon: Icons.mic_rounded,
        color: AuroraColors.purple,
        filter: _TimelineFilter.record,
      );
    }
    return const _TimelineEntryKind(
      title: '文字记录',
      icon: Icons.notes_rounded,
      color: AuroraColors.purple,
      filter: _TimelineFilter.record,
    );
  }

  static String _body(RecentSignalModel signal) {
    final candidates = [
      signal.content,
      signal.observation,
      _usableAiText(signal.acknowledgement),
      signal.tryNext,
      signal.libraryPatternTitle,
      signal.libraryAbstractPattern,
    ];
    for (final value in candidates) {
      final text = value?.trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return _fallbackReplyFromContent(signal.content);
  }

  static String? _usableAiText(String? value) {
    return sanitizeUserVisibleAiText(value);
  }

  static String _fallbackReplyFromContent(String content) {
    final text = content.trim();
    if (text.contains('累') || text.contains('疲') || text.contains('耗')) {
      return '这条记录更像是在提醒你：今天的能量需要被看见。';
    }
    if (text.contains('睡') || text.contains('休息')) {
      return '这条记录和恢复有关，之后可以看看它是否反复出现。';
    }
    if (text.contains('上班') || text.contains('工作') || text.contains('会议')) {
      return '这条记录可能和工作节奏有关，可以先轻轻放进今天的线索里。';
    }
    return text.isEmpty ? '这是一条今天的生活信号。' : '这条记录已经成为今天的一条生活信号。';
  }

  static String? _feedbackLabel(RecentSignalModel signal) {
    final feedback = signal.rawPayloadJson['feedback']?.toString() ??
        signal.rawPayloadJson['micro_action_feedback']?.toString() ??
        signal.userCorrectionJson['feedback']?.toString();
    switch (feedback) {
      case 'occurred':
      case 'done':
      case 'happened':
        return '发生了';
      case 'not_occurred':
      case 'not_done':
      case 'not_happened':
        return '没发生';
      case 'not_suitable_today':
      case 'skip':
        return '今天不适合';
      case 'helpful':
        return '有帮助';
      default:
        return feedback?.trim().isEmpty ?? true ? null : feedback;
    }
  }

  static (String, double)? _progress(RecentSignalModel signal) {
    final done = _asInt(signal.rawPayloadJson['completed_days'] ??
        signal.rawPayloadJson['done_days']);
    final total = _asInt(signal.rawPayloadJson['total_days']) ?? 7;
    if (done == null) return null;
    final safeTotal = total <= 0 ? 7 : total;
    return ('进度 $done/$safeTotal', (done / safeTotal).clamp(0, 1));
  }

  static int? _asInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }
}

class _TimelineEntryKind {
  final String title;
  final IconData icon;
  final Color color;
  final _TimelineFilter filter;

  const _TimelineEntryKind({
    required this.title,
    required this.icon,
    required this.color,
    required this.filter,
  });

  String? tagLabel(RecentSignalModel signal) {
    final firstScene =
        signal.sceneTags.isNotEmpty ? signal.sceneTags.first.trim() : '';
    if (firstScene.isNotEmpty) return firstScene;
    if (signal.energyLoad?.trim().isNotEmpty ?? false) return signal.energyLoad;
    if (signal.emotion?.trim().isNotEmpty ?? false) return signal.emotion;
    if (signal.isLibrarySaved) return '信号库';
    return null;
  }
}

class _TimelineFilterItem {
  final _TimelineFilter filter;
  final IconData icon;
  final String label;

  const _TimelineFilterItem({
    required this.filter,
    required this.icon,
    required this.label,
  });
}

class _DiaryNavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;
  final bool selected;

  const _DiaryNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.route,
    this.selected = false,
  });
}

class _Sparkle extends StatelessWidget {
  final double size;
  final double opacity;

  const _Sparkle({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Icon(Icons.auto_awesome_rounded, color: Colors.white, size: size),
    );
  }
}

class _DiarySignalOrbPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) * 0.36;
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.95),
          AuroraColors.purple.withValues(alpha: 0.18),
          Colors.transparent,
        ],
      ).createShader(rect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(center, radius * 1.18, glow);

    final ring = Paint()
      ..shader = const SweepGradient(
        colors: [
          Color(0xFFFFB45B),
          Color(0xFF65D7D4),
          Color(0xFF5E89F4),
          Color(0xFF9665F4),
          Color(0xFFFFB45B),
        ],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, ring);

    final shine = Paint()
      ..color = Colors.white.withValues(alpha: 0.80)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius + 9, shine);
    canvas.drawCircle(center, radius - 23, shine..strokeWidth = 1.4);

    final road = Path()
      ..moveTo(center.dx - 12, center.dy - 20)
      ..cubicTo(center.dx + 42, center.dy - 6, center.dx + 30, center.dy + 16,
          center.dx - 2, center.dy + 28)
      ..cubicTo(center.dx - 56, center.dy + 48, center.dx - 28, center.dy + 70,
          center.dx + 44, center.dy + 88);
    canvas.drawPath(
      road,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );

    final dots = [
      Offset(center.dx - radius, center.dy - 8),
      Offset(center.dx + radius * 0.74, center.dy - radius * 0.68),
      Offset(center.dx + radius * 0.72, center.dy + radius * 0.62),
      Offset(center.dx - radius * 0.72, center.dy + radius * 0.72),
    ];
    for (final dot in dots) {
      canvas.drawCircle(
        dot,
        6,
        Paint()..color = Colors.white.withValues(alpha: 0.92),
      );
      canvas.drawCircle(
        dot,
        3.4,
        Paint()..color = AuroraColors.purple.withValues(alpha: 0.74),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
