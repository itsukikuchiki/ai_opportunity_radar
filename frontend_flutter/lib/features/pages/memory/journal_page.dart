import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/di/app_dependencies.dart';
import '../../../core/i18n/app_locale_text.dart';
import '../../../core/models/today_models.dart';
import '../../../shared/widgets/aurora_ui.dart';

class JournalPage extends StatefulWidget {
  const JournalPage({super.key});

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  Future<List<RecentSignalModel>>? _signalsFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _signalsFuture ??= context
        .read<AppDependencies>()
        .localCaptureRepository
        .listSignalCards(limit: 2000);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: AuroraPage(
        child: SafeArea(
          bottom: false,
          child: FutureBuilder<List<RecentSignalModel>>(
            future: _signalsFuture,
            builder: (context, snapshot) {
              final signals = snapshot.data ?? const <RecentSignalModel>[];
              final entries = _journalEntries(context, signals);
              return ListView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 118),
                children: [
                  const _JournalTopBar(),
                  const SizedBox(height: 14),
                  const _JournalHeroHeader(),
                  const SizedBox(height: 14),
                  _JournalSummaryCard(total: entries.length),
                  const SizedBox(height: 18),
                  const _JournalFilterChips(),
                  const SizedBox(height: 10),
                  if (!snapshot.hasData)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (entries.isEmpty)
                    const _JournalEmptyCard()
                  else
                    for (final entry in entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _JournalEntryCard(entry: entry),
                      ),
                  const _JournalClosingCard(),
                ],
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: const _JournalBottomNav(),
    );
  }
}

class _JournalTopBar extends StatelessWidget {
  const _JournalTopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _JournalCircleButton(
          icon: Icons.chevron_left_rounded,
          onTap: () => context.go(AppRoutes.memory),
        ),
        const Spacer(),
        const _JournalCircleButton(icon: Icons.format_list_bulleted_rounded),
      ],
    );
  }
}

class _JournalHeroHeader extends StatelessWidget {
  const _JournalHeroHeader();

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < AuroraMainPageSpec.compactBreakpoint;
    return ConstrainedBox(
      key: const ValueKey('journey-journal-hero'),
      constraints: const BoxConstraints(minHeight: 168),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: compact ? -18 : -12,
            top: compact ? -24 : -30,
            child: IgnorePointer(
              child: AuroraHeroEmblem(
                size: compact ? 118 : 142,
                opacity: 0.80,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 2, 2, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(right: compact ? 80 : 104),
                  child: AuroraHeroTitle(
                    text: AppLocaleText.tr(
                      context,
                      en: 'Fragments Kept This Month',
                      zhHans: '本月留下的片段',
                      zhHant: '本月留下的片段',
                      ja: '今月残した断片',
                    ),
                    fontSize: compact ? 30 : 34,
                    maxLines: 2,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.78),
                        const Color(0xFFF2EDFF).withValues(alpha: 0.66),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.86),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.chevron_left_rounded,
                        color: AuroraColors.muted,
                        size: 19,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        AppLocaleText.tr(
                          context,
                          en: 'July 2025',
                          zhHans: '2025年7月',
                          zhHant: '2025年7月',
                          ja: '2025年7月',
                        ),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AuroraColors.purple,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AuroraColors.muted,
                        size: 19,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: EdgeInsets.only(right: compact ? 58 : 82),
                  child: Text(
                    AppLocaleText.tr(
                      context,
                      en: 'Gently collect the moments you truly kept this month.',
                      zhHans: '把这个月真正留下来的时刻，轻轻收在一起。',
                      zhHant: '把這個月真正留下來的時刻，輕輕收在一起。',
                      ja: '今月ほんとうに残った瞬間を、そっと集めます。',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AuroraColors.ink.withValues(alpha: 0.76),
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

class _JournalSummaryCard extends StatelessWidget {
  final int total;

  const _JournalSummaryCard({required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 145),
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 22),
      decoration: _journalGlassDecoration(),
      child: Row(
        children: [
          const _JournalSquareImageIcon(
              icon: Icons.menu_book_rounded,
              color: Color(0xFF8B62E8),
              size: 76),
          const SizedBox(width: 24),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: AppLocaleText.tr(context,
                    en: 'This month kept ',
                    zhHans: '本月共留下 ',
                    zhHant: '本月共留下 ',
                    ja: '今月は '),
                children: [
                  TextSpan(
                    text: '$total',
                    style:
                        const TextStyle(color: Color(0xFF7154E8), fontSize: 38),
                  ),
                  TextSpan(
                    text: AppLocaleText.tr(context,
                        en: ' fragments\nincluding ',
                        zhHans: ' 条片段\n其中 ',
                        zhHant: ' 條片段\n其中 ',
                        ja: ' 個の断片\nそのうち '),
                  ),
                  const TextSpan(
                      text: '3',
                      style: TextStyle(color: Color(0xFF7154E8), fontSize: 30)),
                  TextSpan(
                    text: AppLocaleText.tr(context,
                        en: ' important moments.',
                        zhHans: ' 个被标记为重要时刻。',
                        zhHant: ' 個被標記為重要時刻。',
                        ja: ' 個は大切な瞬間です。'),
                  ),
                ],
              ),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF09286A),
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const _JournalSquareImageIcon(
              icon: Icons.star_rounded, color: Color(0xFFB184FF), size: 72),
        ],
      ),
    );
  }
}

class _JournalFilterChips extends StatelessWidget {
  const _JournalFilterChips();

  @override
  Widget build(BuildContext context) {
    final labels = [
      AppLocaleText.tr(context,
          en: 'All', zhHans: '全部', zhHant: '全部', ja: '全部'),
      AppLocaleText.tr(context,
          en: 'Record', zhHans: '记录', zhHant: '記錄', ja: '記録'),
      AppLocaleText.tr(context,
          en: 'Reflection', zhHans: '反思记录', zhHant: '反思記錄', ja: '振り返り'),
      AppLocaleText.tr(context,
          en: 'Small action', zhHans: '小行动反馈', zhHant: '小行動回饋', ja: '小さな行動'),
      AppLocaleText.tr(context,
          en: 'Growth', zhHans: '习惯成长', zhHant: '習慣成長', ja: '習慣成長'),
      AppLocaleText.tr(context,
          en: 'Important', zhHans: '重要时刻', zhHant: '重要時刻', ja: '大切'),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _journalGlassDecoration(),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
                decoration: BoxDecoration(
                  gradient: i == 0
                      ? const LinearGradient(
                          colors: [Color(0xFFBE8BFF), Color(0xFF7B57E8)])
                      : null,
                  color: i == 0 ? null : Colors.white.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(999),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.76)),
                ),
                child: Text(
                  labels[i],
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: i == 0 ? Colors.white : const Color(0xFF49659A),
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              if (i < labels.length - 1) const SizedBox(width: 14),
            ],
          ],
        ),
      ),
    );
  }
}

class _JournalEntryCard extends StatelessWidget {
  final _JournalEntryData entry;

  const _JournalEntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 132,
      clipBehavior: Clip.antiAlias,
      decoration: _journalGlassDecoration(),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 285,
            child: Opacity(
              opacity: 0.58,
              child: Image.asset(
                'assets/journey/journal-card-note.png',
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.78),
                    Colors.white.withValues(alpha: 0.44),
                    Colors.white.withValues(alpha: 0.10),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Row(
              children: [
                _JournalSquareImageIcon(
                    icon: entry.icon, color: entry.color, size: 66),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: const Color(0xFF09286A),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              entry.time,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    color: const Color(0xFF5B72A7),
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _JournalTag(label: entry.tag, color: entry.color),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        entry.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: const Color(0xFF173773),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const _JournalCircleButton(
                    icon: Icons.chevron_right_rounded, compact: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _JournalClosingCard extends StatelessWidget {
  const _JournalClosingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 128,
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
      decoration: _journalGlassDecoration(),
      child: Row(
        children: [
          const _JournalSquareImageIcon(
              icon: Icons.draw_rounded, color: Color(0xFFB184FF), size: 70),
          const SizedBox(width: 28),
          Expanded(
            child: Text(
              AppLocaleText.tr(
                context,
                en: 'Every fragment is a gentle footprint on your growth path. Keep recording and you will see a clearer, steadier self.',
                zhHans: '每一个片段，都是你成长路上的温柔脚印。\n坚持记录，你会遇见更清晰、更坚定的自己。',
                zhHant: '每一個片段，都是你成長路上的溫柔腳印。\n堅持記錄，你會遇見更清晰、更堅定的自己。',
                ja: '一つひとつの断片は、成長の道に残るやさしい足跡です。記録を続けるほど、より澄んだ自分に出会えます。',
              ),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF173773),
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JournalEmptyCard extends StatelessWidget {
  const _JournalEmptyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      decoration: _journalGlassDecoration(),
      child: Text(
        AppLocaleText.tr(
          context,
          en: 'No fragments yet. Records from your Today timeline will gather here.',
          zhHans: '本月还没有片段，今天时间线里的真实记录会汇集到这里。',
          zhHant: '本月還沒有片段，Today 時間線裡的真實記錄會匯集到這裡。',
          ja: '今月の断片はまだありません。Today のタイムラインに残した記録がここに集まります。',
        ),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: const Color(0xFF5B6F9D),
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _JournalBottomNav extends StatelessWidget {
  const _JournalBottomNav();

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        Icons.wb_sunny_outlined,
        AppLocaleText.tr(context,
            en: 'Today', zhHans: '今天', zhHant: '今天', ja: '今日'),
        false,
        AppRoutes.today
      ),
      (
        Icons.calendar_month_rounded,
        AppLocaleText.tr(context,
            en: 'Weekly', zhHans: '每周复盘', zhHant: '每週', ja: 'Weekly'),
        false,
        AppRoutes.weekly
      ),
      (
        Icons.science_rounded,
        AppLocaleText.tr(context,
            en: 'Experiment', zhHans: '生活小实验', zhHant: '小實驗', ja: '実験'),
        false,
        AppRoutes.experiment
      ),
      (
        Icons.route_rounded,
        AppLocaleText.tr(context,
            en: 'Journey', zhHans: '旅程', zhHant: '旅程', ja: 'Journey'),
        true,
        AppRoutes.memory
      ),
      (
        Icons.person_rounded,
        AppLocaleText.tr(context,
            en: 'Me', zhHans: '我的', zhHant: '我的', ja: 'マイ'),
        false,
        AppRoutes.me
      ),
    ];
    return SafeArea(
      top: false,
      child: Container(
        height: 82,
        margin: const EdgeInsets.fromLTRB(18, 0, 18, 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.88),
              const Color(0xFFF7F3FF).withValues(alpha: 0.78),
              const Color(0xFFF3F8FF).withValues(alpha: 0.72),
            ],
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white.withValues(alpha: 0.92)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7164A8).withValues(alpha: 0.14),
              blurRadius: 28,
              spreadRadius: -10,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            for (final item in items)
              Expanded(
                child: InkWell(
                  onTap: () => context.go(item.$4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _JournalSquareImageIcon(
                        icon: item.$1,
                        color: item.$3
                            ? const Color(0xFF8B62E8)
                            : const Color(0xFF9BA4C2),
                        size: item.$3 ? 40 : 34,
                        active: item.$3,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.$2,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: item.$3
                                  ? const Color(0xFF7B57E8)
                                  : const Color(0xFF7E89AF),
                              fontWeight:
                                  item.$3 ? FontWeight.w700 : FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _JournalCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool compact;

  const _JournalCircleButton({
    required this.icon,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    const size = 44.0;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.72),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.88)),
        ),
        child: Icon(icon, color: AuroraColors.ink, size: compact ? 23 : 24),
      ),
    );
  }
}

class _JournalSquareImageIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final bool active;

  const _JournalSquareImageIcon({
    required this.icon,
    required this.color,
    required this.size,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(active ? size / 2 : 22),
        gradient: RadialGradient(
          center: const Alignment(-0.42, -0.42),
          colors: [
            Colors.white.withValues(alpha: 0.95),
            color.withValues(alpha: active ? 0.42 : 0.32),
            color.withValues(alpha: active ? 0.90 : 0.72),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.86)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.48),
    );
  }
}

class _JournalTag extends StatelessWidget {
  final String label;
  final Color color;

  const _JournalTag({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _JournalEntryData {
  final IconData icon;
  final Color color;
  final String title;
  final String time;
  final String tag;
  final String subtitle;

  const _JournalEntryData({
    required this.icon,
    required this.color,
    required this.title,
    required this.time,
    required this.tag,
    required this.subtitle,
  });
}

List<_JournalEntryData> _journalEntries(
    BuildContext context, List<RecentSignalModel> signals) {
  if (signals.isEmpty) return const [];

  final colors = [
    const Color(0xFF7B7AF6),
    const Color(0xFF63D48D),
    const Color(0xFF8B78F6),
    const Color(0xFFFF9A55),
    const Color(0xFF6EA4F7),
  ];
  final icons = [
    Icons.edit_note_rounded,
    Icons.spa_rounded,
    Icons.groups_rounded,
    Icons.star_rounded,
    Icons.check_circle_rounded,
  ];
  return [
    for (var i = 0; i < signals.take(12).length; i++)
      _JournalEntryData(
        icon: icons[i % icons.length],
        color: colors[i % colors.length],
        title: signals[i].content,
        time: _formatJournalDate(signals[i].createdAt),
        tag: i % 4 == 0
            ? AppLocaleText.tr(context,
                en: 'Important', zhHans: '重要时刻', zhHant: '重要時刻', ja: '大切')
            : AppLocaleText.tr(context,
                en: 'Record', zhHans: '记录', zhHant: '記錄', ja: '記録'),
        subtitle: (signals[i].acknowledgement ?? '').trim().isEmpty
            ? AppLocaleText.tr(context,
                en: 'A small trace worth keeping.',
                zhHans: '一个值得留下来的生活片段。',
                zhHant: '一個值得留下來的生活片段。',
                ja: '残しておきたい小さな軌跡。')
            : signals[i].acknowledgement!.trim(),
      ),
  ];
}

String _formatJournalDate(DateTime? time) {
  final dt = time?.toLocal() ?? DateTime(2025, 7, 7, 20, 14);
  return '${dt.month}月${dt.day}日 ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

BoxDecoration _journalGlassDecoration() {
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withValues(alpha: 0.86),
        const Color(0xFFFFF8F4).withValues(alpha: 0.70),
        const Color(0xFFF3F1FF).withValues(alpha: 0.66),
        const Color(0xFFF1F8FF).withValues(alpha: 0.62),
      ],
      stops: const [0, 0.36, 0.72, 1],
    ),
    borderRadius: BorderRadius.circular(22),
    border: Border.all(color: Colors.white.withValues(alpha: 0.86), width: 1),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF7164A8).withValues(alpha: 0.10),
        blurRadius: 30,
        spreadRadius: -14,
        offset: const Offset(0, 15),
      ),
      BoxShadow(
        color: const Color(0xFFFFB17C).withValues(alpha: 0.07),
        blurRadius: 26,
        spreadRadius: -14,
        offset: const Offset(-6, 10),
      ),
    ],
  );
}
