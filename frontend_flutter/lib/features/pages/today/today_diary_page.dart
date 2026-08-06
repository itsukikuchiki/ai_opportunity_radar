import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/di/app_dependencies.dart';
import '../../../core/diagnostics/privacy_safe_logger.dart';
import '../../../core/i18n/app_locale_text.dart';
import '../../../core/i18n/energy_budget_text.dart';
import '../../../core/local/local_candidate_planning_repository.dart';
import '../../../core/local/local_capture_repository.dart';
import '../../../core/models/candidate_models.dart';
import '../../../core/models/today_models.dart';
import '../../../core/navigation/app_back_navigation.dart';
import '../../../core/preferences/focus_domains.dart';
import '../../../core/state/app_data_refresh_coordinator.dart';
import '../../../shared/utils/user_visible_text_sanitizer.dart';
import '../../../shared/widgets/aurora_ui.dart';
import '../../shell/main_tab_bottom_navigation.dart';
import 'today_view_model.dart';

enum _TimelineFilter { all, record, action, experiment }

class TodayDiaryPage extends StatefulWidget {
  final String? initialDateKey;
  final LocalCandidatePlanningRepository? repositoryOverride;
  final LocalCaptureRepository? captureRepositoryOverride;

  const TodayDiaryPage({
    super.key,
    this.initialDateKey,
    this.repositoryOverride,
    this.captureRepositoryOverride,
  });

  @override
  State<TodayDiaryPage> createState() => _TodayDiaryPageState();
}

class _TodayDiaryPageState extends State<TodayDiaryPage> {
  _TimelineFilter _filter = _TimelineFilter.all;
  List<AdoptedMicroActionProgress> _actions = const [];
  List<AdoptedLifeExperimentProgress> _experiments = const [];
  List<RecentSignalModel> _selectedSignals = const [];
  Set<String> _contentDateKeys = const <String>{};
  bool _loadingPlans = true;
  bool _startedLoadingPlans = false;
  int _loadRevision = 0;
  StreamSubscription<AppDataMutation>? _invalidationSubscription;

  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = _initialSelectedDate(widget.initialDateKey);
  }

  DateTime _initialSelectedDate(String? raw) {
    final selected = _TimelineEntry._parseLocalDate(raw);
    if (selected != null) return _dateOnly(selected);
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _watchInvalidations();
    if (_startedLoadingPlans) return;
    _startedLoadingPlans = true;
    unawaited(_loadPlans());
  }

  @override
  void didUpdateWidget(covariant TodayDiaryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialDateKey == widget.initialDateKey &&
        identical(oldWidget.repositoryOverride, widget.repositoryOverride) &&
        identical(
          oldWidget.captureRepositoryOverride,
          widget.captureRepositoryOverride,
        )) {
      return;
    }
    if (oldWidget.initialDateKey != widget.initialDateKey) {
      _selectedDate = _initialSelectedDate(widget.initialDateKey);
    }
    unawaited(_invalidationSubscription?.cancel());
    _invalidationSubscription = null;
    _watchInvalidations();
    unawaited(_loadPlans());
  }

  @override
  void dispose() {
    unawaited(_invalidationSubscription?.cancel());
    super.dispose();
  }

  LocalCandidatePlanningRepository? _repository() {
    return widget.repositoryOverride ??
        context.read<AppDependencies?>()?.localCandidatePlanningRepository;
  }

  LocalCaptureRepository? _captureRepository() {
    return widget.captureRepositoryOverride ??
        context.read<AppDependencies?>()?.localCaptureRepository;
  }

  Future<void> _loadPlans() async {
    final repository = _repository();
    final captureRepository = _captureRepository();
    final revision = ++_loadRevision;
    if (mounted) setState(() => _loadingPlans = true);
    try {
      final actions = repository == null
          ? const <AdoptedMicroActionProgress>[]
          : await repository.listAdoptedSmallTriesForDate(_selectedDate);
      final experiments = repository == null
          ? const <AdoptedLifeExperimentProgress>[]
          : await repository.listAdoptedGoalsForDate(_selectedDate);
      final selectedSignals = captureRepository == null
          ? const <RecentSignalModel>[]
          : await captureRepository.listSignalCardsForDate(
              _dateKey(_selectedDate),
            );
      final signalDateKeys = captureRepository == null
          ? const <String>{}
          : await captureRepository.listSignalCardDateKeys();
      final planDateKeys = repository == null
          ? const <String>{}
          : await repository.listAdoptedPlanContentDateKeys();
      if (!mounted || revision != _loadRevision) return;
      setState(() {
        _actions = actions;
        _experiments = experiments;
        _selectedSignals = selectedSignals;
        _contentDateKeys = {...signalDateKeys, ...planDateKeys};
        _loadingPlans = false;
      });
    } catch (error, stackTrace) {
      PrivacySafeLogger.instance.capture(
        error,
        stackTrace,
        operation: 'today_diary_plans_load',
      );
      if (!mounted || revision != _loadRevision) return;
      setState(() {
        _actions = const [];
        _experiments = const [];
        _selectedSignals = const [];
        _loadingPlans = false;
      });
    }
  }

  void _watchInvalidations() {
    if (_invalidationSubscription != null) return;
    final repository = _repository();
    if (repository == null) return;
    _invalidationSubscription = AppDataMutationBus.stream
        .where((mutation) =>
            mutation.kind == AppDataMutationKind.candidatePlanning ||
            mutation.kind == AppDataMutationKind.signalCard)
        .listen((_) {
      if (mounted) unawaited(_loadPlans());
    });
  }

  void _selectDate(DateTime value) {
    final selected = _dateOnly(value);
    if (_isSameDay(selected, _selectedDate)) return;
    final today = _dateOnly(DateTime.now());
    if (selected.isAfter(today)) return;
    setState(() => _selectedDate = selected);
    unawaited(_loadPlans());
  }

  Future<void> _openDatePicker() async {
    final today = _dateOnly(DateTime.now());
    final contentDates = _contentDateKeys
        .map(DateTime.tryParse)
        .whereType<DateTime>()
        .map(_dateOnly)
        .toList(growable: false);
    var firstDate = contentDates.isEmpty
        ? DateTime(today.year - 5, today.month, today.day)
        : contentDates
            .reduce((left, right) => left.isBefore(right) ? left : right);
    if (firstDate.isAfter(_selectedDate)) firstDate = _selectedDate;
    if (!mounted) return;
    final selected = await showModalBottomSheet<DateTime>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DiaryMonthPicker(
        initialDate: _selectedDate.isAfter(today) ? today : _selectedDate,
        firstDate: firstDate,
        lastDate: today,
      ),
    );
    if (selected != null && mounted) _selectDate(selected);
  }

  List<RecentSignalModel> _mergedSignals(
    List<RecentSignalModel> viewModelSignals,
  ) {
    final merged = <String, RecentSignalModel>{};
    for (final signal in [..._selectedSignals, ...viewModelSignals]) {
      final key = signal.signalCardId ??
          signal.id ??
          '${signal.localDate}|${signal.createdAt?.toIso8601String()}|${signal.content}';
      merged[key] = signal;
    }
    return merged.values.toList(growable: false);
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static bool _isSameDay(DateTime left, DateTime right) =>
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;

  @override
  Widget build(BuildContext context) {
    final viewModelSignals =
        context.watch<TodayViewModel>().state.recentSignals;
    final signals = _mergedSignals(viewModelSignals);
    final entries = _buildEntries(
      context,
      signals,
      actions: _actions,
      experiments: _experiments,
    )
        .where((entry) =>
            _filter == _TimelineFilter.all || entry.filter == _filter)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
                          _TimelineHero(
                            onBack: () => context.popOrGo(AppRoutes.today),
                            title: AppLocaleText.tr(
                              context,
                              en: 'Diary Timeline',
                              zhHans: '手帐时间线',
                              zhHant: '手帳時間線',
                              ja: '手帳タイムライン',
                            ),
                            subtitle: AppLocaleText.tr(
                              context,
                              en: 'Turn the pages by date to revisit signals, Spot Tries, and goals.',
                              zhHans: '按日期翻阅信号、简单尝试和目标。',
                              zhHant: '按日期翻閱信號、簡單嘗試和目標。',
                              ja: '日付ごとにシグナル、スポットトライ、目標を振り返ります。',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: _DiaryDateNavigator(
                        selectedDate: _selectedDate,
                        onSelected: _selectDate,
                        onOpenCalendar: _openDatePicker,
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
                  if (entries.isEmpty && _loadingPlans)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (entries.isEmpty)
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
      bottomNavigationBar: const MainTabBottomNavigation(selectedIndex: 0),
    );
  }

  List<_TimelineEntry> _buildEntries(
    BuildContext context,
    List<RecentSignalModel> signals, {
    required List<AdoptedMicroActionProgress> actions,
    required List<AdoptedLifeExperimentProgress> experiments,
  }) {
    final today = _selectedDate;
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
        _TimelineEntry.fromSignal(context, signal),
      for (final action in actions)
        _TimelineEntry.fromMicroActionProgress(context, action, today),
      for (final experiment in experiments)
        _TimelineEntry.fromLifeExperimentProgress(
          context,
          experiment,
          today,
        ),
    ];
  }

  bool _isLegacyScheduleSource(String sourceType) {
    final normalized = sourceType.toLowerCase();
    return normalized.contains('schedule') ||
        normalized == 'calendar' ||
        normalized == 'goal' ||
        normalized.startsWith('goal_');
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
  final VoidCallback onBack;
  final String title;
  final String subtitle;

  const _TimelineHero({
    required this.onBack,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('today-diary-hero'),
      height: 92,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: _BackButtonPill(onTap: onBack),
          ),
          const Positioned(
            key: ValueKey('today-diary-signal-pattern'),
            right: -4,
            top: -10,
            width: 164,
            height: 112,
            child: IgnorePointer(
              child: AuroraSignalHeroPattern(
                opacity: 0.82,
                alignment: Alignment.centerRight,
              ),
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
            child: Padding(
              padding: const EdgeInsets.only(left: 52),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AuroraHeroTitle(
                    text: title,
                    fontSize: 34,
                    maxLines: 1,
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
          ),
        ],
      ),
    );
  }
}

class _DiaryDateNavigator extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelected;
  final VoidCallback onOpenCalendar;

  const _DiaryDateNavigator({
    required this.selectedDate,
    required this.onSelected,
    required this.onOpenCalendar,
  });

  @override
  Widget build(BuildContext context) {
    final selected = _dateOnly(selectedDate);
    final today = _dateOnly(DateTime.now());
    final weekStart =
        selected.subtract(Duration(days: selected.weekday - DateTime.monday));
    final days = List<DateTime>.generate(
      DateTime.daysPerWeek,
      (index) => weekStart.add(Duration(days: index)),
    );

    return Container(
      key: const ValueKey('today-diary-date-navigator'),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFEFC).withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.94)),
        boxShadow: [
          BoxShadow(
            color: AuroraColors.purple.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _DiaryDateArrow(
                key: const ValueKey('today-diary-previous-day'),
                icon: Icons.chevron_left_rounded,
                tooltip: AppLocaleText.tr(
                  context,
                  en: 'Previous day',
                  zhHans: '前一天',
                  zhHant: '前一天',
                  ja: '前の日',
                ),
                onTap: () =>
                    onSelected(selected.subtract(const Duration(days: 1))),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Semantics(
                  button: true,
                  label: AppLocaleText.tr(
                    context,
                    en: 'Choose a diary date',
                    zhHans: '选择手帐日期',
                    zhHant: '選擇手帳日期',
                    ja: '手帳の日付を選ぶ',
                  ),
                  child: InkWell(
                    key: const ValueKey('today-diary-open-calendar'),
                    borderRadius: BorderRadius.circular(16),
                    onTap: onOpenCalendar,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.menu_book_rounded,
                            color: AuroraColors.purple,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _monthTitle(context, selected),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: AuroraColors.ink,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.expand_more_rounded,
                            color: AuroraColors.muted,
                            size: 19,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _DiaryDateArrow(
                key: const ValueKey('today-diary-next-day'),
                icon: Icons.chevron_right_rounded,
                tooltip: AppLocaleText.tr(
                  context,
                  en: 'Next day',
                  zhHans: '后一天',
                  zhHant: '後一天',
                  ja: '次の日',
                ),
                onTap: selected.isBefore(today)
                    ? () => onSelected(selected.add(const Duration(days: 1)))
                    : null,
              ),
            ],
          ),
          Container(
            height: 1,
            margin: const EdgeInsets.fromLTRB(8, 1, 8, 5),
            color: AuroraColors.line.withValues(alpha: 0.58),
          ),
          Row(
            children: [
              for (final day in days)
                Expanded(
                  child: _DiaryDayTab(
                    date: day,
                    selected: _sameDay(day, selected),
                    enabled: !day.isAfter(today),
                    onTap: () => onSelected(day),
                  ),
                ),
            ],
          ),
          if (!_sameDay(selected, today)) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const ValueKey('today-diary-back-to-today'),
                onPressed: () => onSelected(today),
                icon: const Icon(Icons.today_rounded, size: 17),
                label: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Back to today',
                    zhHans: '回到今天',
                    zhHant: '回到今天',
                    ja: '今日に戻る',
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static bool _sameDay(DateTime left, DateTime right) =>
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;

  static String _monthTitle(BuildContext context, DateTime value) {
    final weekday = _longWeekday(context, value.weekday);
    return AppLocaleText.tr(
      context,
      en: '${_englishMonth(value.month)} ${value.day}, ${value.year}',
      zhHans: '${value.year}年${value.month}月${value.day}日 $weekday',
      zhHant: '${value.year}年${value.month}月${value.day}日 $weekday',
      ja: '${value.year}年${value.month}月${value.day}日（$weekday）',
    );
  }

  static String _longWeekday(BuildContext context, int weekday) {
    const zh = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    const ja = ['月', '火', '水', '木', '金', '土', '日'];
    final language = Localizations.localeOf(context).languageCode;
    if (language == 'zh') return zh[weekday - 1];
    if (language == 'ja') return ja[weekday - 1];
    return '';
  }

  static String _englishMonth(int month) => const [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ][month - 1];
}

class _DiaryDateArrow extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _DiaryDateArrow({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon),
      color: AuroraColors.purple,
      disabledColor: AuroraColors.muted.withValues(alpha: 0.34),
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
    );
  }
}

class _DiaryDayTab extends StatelessWidget {
  final DateTime date;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _DiaryDayTab({
    required this.date,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? Colors.white
        : enabled
            ? AuroraColors.ink
            : AuroraColors.muted.withValues(alpha: 0.42);
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: '${date.month}/${date.day}',
      child: InkWell(
        key: ValueKey(
          'today-diary-day-${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}',
        ),
        borderRadius: BorderRadius.circular(16),
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 50),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF8165F5), Color(0xFFB987FF)],
                  )
                : null,
            color: selected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _weekday(context, date.weekday),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: foreground.withValues(alpha: 0.76),
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                '${date.day}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _weekday(BuildContext context, int weekday) {
    const en = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    const zh = ['一', '二', '三', '四', '五', '六', '日'];
    const ja = ['月', '火', '水', '木', '金', '土', '日'];
    final language = Localizations.localeOf(context).languageCode;
    if (language == 'zh') return zh[weekday - 1];
    if (language == 'ja') return ja[weekday - 1];
    return en[weekday - 1];
  }
}

class _DiaryMonthPicker extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  const _DiaryMonthPicker({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<_DiaryMonthPicker> createState() => _DiaryMonthPickerState();
}

class _DiaryMonthPickerState extends State<_DiaryMonthPicker> {
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    _visibleMonth = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
    );
  }

  DateTime get _firstMonth =>
      DateTime(widget.firstDate.year, widget.firstDate.month);

  DateTime get _lastMonth =>
      DateTime(widget.lastDate.year, widget.lastDate.month);

  bool get _canGoPrevious => _visibleMonth.isAfter(_firstMonth);

  bool get _canGoNext => _visibleMonth.isBefore(_lastMonth);

  void _moveMonth(int delta) {
    final next = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    if (next.isBefore(_firstMonth) || next.isAfter(_lastMonth)) return;
    setState(() => _visibleMonth = next);
  }

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = _visibleMonth;
    final daysInMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final leading = (firstOfMonth.weekday - DateTime.monday) % 7;
    final rowCount = ((leading + daysInMonth) / 7).ceil();
    final theme = Theme.of(context);

    return Container(
      key: const ValueKey('today-diary-month-picker'),
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFBF7), Color(0xFFF5F2FF)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.92)),
        boxShadow: [
          BoxShadow(
            color: AuroraColors.purple.withValues(alpha: 0.18),
            blurRadius: 32,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AuroraColors.muted.withValues(alpha: 0.48),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    AppLocaleText.tr(
                      context,
                      en: 'Open a diary day',
                      zhHans: '翻到某一天',
                      zhHant: '翻到某一天',
                      ja: '手帳の日付を選ぶ',
                    ),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AuroraColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  key: const ValueKey('today-diary-calendar-previous-month'),
                  tooltip: AppLocaleText.tr(
                    context,
                    en: 'Previous month',
                    zhHans: '上个月',
                    zhHant: '上個月',
                    ja: '前の月',
                  ),
                  onPressed: _canGoPrevious ? () => _moveMonth(-1) : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    MaterialLocalizations.of(context)
                        .formatMonthYear(_visibleMonth),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AuroraColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('today-diary-calendar-next-month'),
                  tooltip: AppLocaleText.tr(
                    context,
                    en: 'Next month',
                    zhHans: '下个月',
                    zhHant: '下個月',
                    ja: '次の月',
                  ),
                  onPressed: _canGoNext ? () => _moveMonth(1) : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                for (final label in _weekdayLabels(context))
                  Expanded(
                    child: SizedBox(
                      height: 28,
                      child: Center(
                        child: Text(
                          label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AuroraColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rowCount * 7,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) {
                final dayNumber = index - leading + 1;
                if (dayNumber < 1 || dayNumber > daysInMonth) {
                  return const SizedBox.shrink();
                }
                final date = DateTime(
                  _visibleMonth.year,
                  _visibleMonth.month,
                  dayNumber,
                );
                return _DiaryMonthDay(
                  date: date,
                  selected: _sameDay(date, widget.initialDate),
                  enabled: !date.isBefore(widget.firstDate) &&
                      !date.isAfter(widget.lastDate),
                  onTap: () => Navigator.of(context).pop(date),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static bool _sameDay(DateTime left, DateTime right) =>
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;

  static List<String> _weekdayLabels(BuildContext context) {
    return switch (Localizations.localeOf(context).languageCode) {
      'zh' => const ['一', '二', '三', '四', '五', '六', '日'],
      'ja' => const ['月', '火', '水', '木', '金', '土', '日'],
      _ => const ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
    };
  }
}

class _DiaryMonthDay extends StatelessWidget {
  final DateTime date;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _DiaryMonthDay({
    required this.date,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final key = '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: MaterialLocalizations.of(context).formatFullDate(date),
      child: InkWell(
        key: ValueKey('today-diary-calendar-day-$key'),
        borderRadius: BorderRadius.circular(15),
        onTap: enabled ? onTap : null,
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xFF8464F6), Color(0xFFB887FF)],
                  )
                : null,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${date.day}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: !enabled
                          ? AuroraColors.muted.withValues(alpha: 0.38)
                          : selected
                              ? Colors.white
                              : AuroraColors.ink,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
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
          en: 'Signals',
          zhHans: '信号',
          zhHant: '信號',
          ja: 'シグナル',
        ),
      ),
      _TimelineFilterItem(
        filter: _TimelineFilter.action,
        icon: Icons.spa_rounded,
        label: AppLocaleText.tr(
          context,
          en: 'Spot Tries',
          zhHans: '简单尝试',
          zhHant: '簡單嘗試',
          ja: 'スポットトライ',
        ),
      ),
      _TimelineFilterItem(
        filter: _TimelineFilter.experiment,
        icon: Icons.science_rounded,
        label: AppLocaleText.tr(
          context,
          en: 'Goals',
          zhHans: '目标',
          zhHant: '目標',
          ja: '目標',
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
        key: ValueKey('today-diary-filter-${item.filter.name}'),
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
                        fontWeight: FontWeight.w700,
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
                  key: const ValueKey('today-diary-entry-title'),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: entry.color,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                if (entry.timeUse != null)
                  _DiaryTimeUsePeriodBlock(data: entry.timeUse!)
                else
                  Text(
                    entry.body,
                    key: const ValueKey('today-diary-entry-body'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF454C62),
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                if (entry.timeUse == null && entry.tagLabel != null) ...[
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
          if (entry.captureId?.isNotEmpty ?? false) ...[
            const SizedBox(width: 6),
            Column(
              children: [
                _MiniActionButton(
                  label: AppLocaleText.tr(
                    context,
                    en: 'Chat',
                    zhHans: '聊聊',
                    zhHant: '聊聊',
                    ja: '話す',
                  ),
                  onTap: () => _openAiDialog(context, entry),
                ),
              ],
            ),
          ],
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
              zhHans: '这条记录暂时还不能打开智能助手聊天。',
              zhHant: '這條記錄暫時還不能開啟智慧助手對話。',
              ja: 'この記録では、まだ人工知能との対話を開けません。',
            ),
          ),
        ),
      );
      return;
    }
    context.push('${AppRoutes.todayDialog}/$captureId');
  }
}

class _DiaryTimeUsePeriodBlock extends StatelessWidget {
  final _DiaryTimeUseData data;

  const _DiaryTimeUsePeriodBlock({required this.data});

  @override
  Widget build(BuildContext context) {
    final accent = data.isPlanned ? AuroraColors.blue : const Color(0xFF45C9C3);
    return Container(
      key: const ValueKey('today-diary-time-use-period-block'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.14),
            Colors.white.withValues(alpha: 0.52),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Column(
              children: [
                Text(
                  data.startTime,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AuroraColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Container(
                  width: 1,
                  height: 7,
                  margin: const EdgeInsets.symmetric(vertical: 1),
                  color: accent.withValues(alpha: 0.52),
                ),
                Text(
                  data.endTime,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AuroraColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF454C62),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        height: 1.25,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${data.categoryLabel} · ${data.statusLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
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
              fontWeight: FontWeight.w700,
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
                fontWeight: FontWeight.w700,
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
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocaleText.tr(
                context,
                en: 'This diary day will collect its signals, Spot Tries, and goals in time order.',
                zhHans: '这一天的信号、简单尝试和目标，会按时间留在手帐里。',
                zhHant: '這一天的信號、簡單嘗試和目標，會按時間留在手帳裡。',
                ja: 'この日のシグナル、スポットトライ、目標が時間順に並びます。',
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
          en: 'No signals on this day',
          zhHans: '这一天还没有信号',
          zhHant: '這一天還沒有信號',
          ja: 'この日のシグナルはまだありません',
        );
      case _TimelineFilter.action:
        return AppLocaleText.tr(
          context,
          en: 'No Spot Tries on this day',
          zhHans: '这一天还没有简单尝试',
          zhHant: '這一天還沒有簡單嘗試',
          ja: 'この日のスポットトライはまだありません',
        );
      case _TimelineFilter.experiment:
        return AppLocaleText.tr(
          context,
          en: 'No goals on this day',
          zhHans: '这一天还没有目标',
          zhHant: '這一天還沒有目標',
          ja: 'この日の目標はまだありません',
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
  final _DiaryTimeUseData? timeUse;

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
    this.timeUse,
  });

  factory _TimelineEntry.fromSignal(
    BuildContext context,
    RecentSignalModel signal,
  ) {
    final createdAt = signal.createdAt?.toLocal() ?? DateTime.now();
    final timeUseStart = signal.sourceType == 'time_use'
        ? DateTime.tryParse(
            signal.rawPayloadJson['start_at']?.toString() ?? '',
          )?.toLocal()
        : null;
    final displayTime = timeUseStart ?? createdAt;
    final localDate = _parseLocalDate(signal.localDate) ??
        DateTime(displayTime.year, displayTime.month, displayTime.day);
    final kind = _kindForSignal(context, signal);
    final feedback = _feedbackLabel(context, signal);
    final progress = _progress(context, signal);
    final timeUse = signal.sourceType == 'time_use' ||
            signal.rawPayloadJson['timeline_type'] == 'time_use'
        ? _DiaryTimeUseData.tryFromSignal(context, signal)
        : null;
    return _TimelineEntry(
      captureId: signal.signalCardId ?? signal.id,
      createdAt: displayTime,
      localDate: localDate,
      timeLabel:
          '${displayTime.hour.toString().padLeft(2, '0')}:${displayTime.minute.toString().padLeft(2, '0')}',
      title: kind.title,
      body: _body(context, signal),
      tagLabel: kind.tagLabel(context, signal),
      feedbackLabel: feedback,
      progressText: progress?.$1,
      progressValue: progress?.$2,
      icon: kind.icon,
      color: kind.color,
      filter: kind.filter,
      timeUse: timeUse,
    );
  }

  factory _TimelineEntry.fromMicroActionProgress(
    BuildContext context,
    AdoptedMicroActionProgress item,
    DateTime selectedDate,
  ) {
    final cell = _cellForDate(item.progress, selectedDate);
    final eventAt = cell?.latestEventAt?.toLocal();
    final adoptedAt = item.action.adoptedAt?.toLocal();
    final adoptionAt = _isSameDay(adoptedAt, selectedDate) ? adoptedAt : null;
    final displayTime = eventAt ?? adoptionAt;
    final completedDays = _completedDaysThrough(
      item.progress,
      selectedDate,
    );
    return _TimelineEntry(
      captureId: null,
      createdAt: displayTime ?? _dateOnly(selectedDate),
      localDate: _dateOnly(selectedDate),
      timeLabel: _timeLabel(displayTime),
      title: AppLocaleText.tr(
        context,
        en: 'Spot Try',
        zhHans: '简单尝试',
        zhHant: '簡單嘗試',
        ja: 'スポットトライ',
      ),
      body: item.action.title.trim().isEmpty
          ? item.action.reason.trim()
          : item.action.title.trim(),
      tagLabel: item.action.sourceChanged
          ? AppLocaleText.tr(
              context,
              en: 'Source changed',
              zhHans: '来源已变化',
              zhHant: '來源已變化',
              ja: '参照元が変わりました',
            )
          : null,
      feedbackLabel: _progressCellLabel(
        context,
        cell?.state,
      ),
      progressText: AppLocaleText.tr(
        context,
        en: 'Progress $completedDays/7',
        zhHans: '进度 $completedDays/7',
        zhHant: '進度 $completedDays/7',
        ja: '進捗 $completedDays/7',
      ),
      progressValue: completedDays / SevenDayProgressModel.totalDays,
      icon: Icons.spa_rounded,
      color: const Color(0xFF45C9C3),
      filter: _TimelineFilter.action,
    );
  }

  factory _TimelineEntry.fromLifeExperimentProgress(
    BuildContext context,
    AdoptedLifeExperimentProgress item,
    DateTime selectedDate,
  ) {
    final cell = _cellForDate(item.progress, selectedDate);
    final eventAt = cell?.latestEventAt?.toLocal();
    final adoptedAt = item.experiment.adoptedAt?.toLocal();
    final adoptionAt = _isSameDay(adoptedAt, selectedDate) ? adoptedAt : null;
    final displayTime = eventAt ?? adoptionAt;
    final completedDays = _completedDaysThrough(
      item.progress,
      selectedDate,
    );
    final title = item.experiment.title.trim();
    return _TimelineEntry(
      captureId: null,
      createdAt: displayTime ?? _dateOnly(selectedDate),
      localDate: _dateOnly(selectedDate),
      timeLabel: _timeLabel(displayTime),
      title: AppLocaleText.tr(
        context,
        en: 'Goal',
        zhHans: '目标',
        zhHant: '目標',
        ja: '目標',
      ),
      body: title.isEmpty ? item.experiment.suggestedAction.trim() : title,
      tagLabel: item.experiment.sourceChanged
          ? AppLocaleText.tr(
              context,
              en: 'Source changed',
              zhHans: '来源已变化',
              zhHant: '來源已變化',
              ja: '参照元が変わりました',
            )
          : null,
      feedbackLabel: _progressCellLabel(
        context,
        cell?.state,
      ),
      progressText: AppLocaleText.tr(
        context,
        en: 'Progress $completedDays/7',
        zhHans: '进度 $completedDays/7',
        zhHant: '進度 $completedDays/7',
        ja: '進捗 $completedDays/7',
      ),
      progressValue: completedDays / SevenDayProgressModel.totalDays,
      icon: Icons.science_rounded,
      color: AuroraColors.purple,
      filter: _TimelineFilter.experiment,
    );
  }

  static SevenDayProgressCell? _cellForDate(
    SevenDayProgressModel progress,
    DateTime selectedDate,
  ) {
    final key = _dateKey(selectedDate);
    for (final cell in progress.cells) {
      if (cell.localDate == key) return cell;
    }
    return null;
  }

  static int _completedDaysThrough(
    SevenDayProgressModel progress,
    DateTime selectedDate,
  ) {
    final selectedKey = _dateKey(selectedDate);
    return progress.cells
        .where((cell) =>
            cell.localDate.compareTo(selectedKey) <= 0 &&
            cell.state == ProgressCellState.completed)
        .length
        .clamp(0, SevenDayProgressModel.totalDays);
  }

  static String? _progressCellLabel(
    BuildContext context,
    ProgressCellState? state,
  ) {
    return switch (state) {
      ProgressCellState.completed => AppLocaleText.tr(
          context,
          en: 'Completed today',
          zhHans: '今天已完成',
          zhHant: '今天已完成',
          ja: '今日は完了',
        ),
      ProgressCellState.notCompleted => AppLocaleText.tr(
          context,
          en: 'Not completed today',
          zhHans: '今天未完成',
          zhHant: '今天未完成',
          ja: '今日は未完了',
        ),
      ProgressCellState.empty || null => null,
    };
  }

  static String _timeLabel(DateTime? date) {
    if (date == null) return '—';
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  static bool _isSameDay(DateTime? left, DateTime right) {
    return left != null &&
        left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  static DateTime? _parseLocalDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(raw.trim());
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static _TimelineEntryKind _kindForSignal(
    BuildContext context,
    RecentSignalModel signal,
  ) {
    final source = signal.sourceType;
    final payloadKind = signal.rawPayloadJson['timeline_type']?.toString() ??
        signal.rawPayloadJson['kind']?.toString() ??
        '';
    if (source == 'time_use' || payloadKind == 'time_use') {
      return _TimelineEntryKind(
        title: AppLocaleText.tr(
          context,
          en: 'Schedule',
          zhHans: '安排',
          zhHant: '安排',
          ja: '予定',
        ),
        icon: Icons.event_note_rounded,
        color: AuroraColors.blue,
        filter: _TimelineFilter.record,
      );
    }
    if (source == 'micro_action' ||
        source == 'daily_action' ||
        payloadKind == 'micro_action') {
      return _TimelineEntryKind(
        title: AppLocaleText.tr(
          context,
          en: 'Spot Try',
          zhHans: '小实验',
          zhHant: '小實驗',
          ja: '小実験',
        ),
        icon: Icons.spa_rounded,
        color: const Color(0xFF45C9C3),
        filter: _TimelineFilter.action,
      );
    }
    if (source == 'feedback' || payloadKind == 'feedback') {
      return _TimelineEntryKind(
        title: AppLocaleText.tr(
          context,
          en: 'Spot Try record',
          zhHans: '小实验记录',
          zhHant: '小實驗記錄',
          ja: '小実験の記録',
        ),
        icon: Icons.favorite_rounded,
        color: const Color(0xFFFF70B1),
        filter: _TimelineFilter.action,
      );
    }
    if (source == 'weekly_experiment' ||
        source == 'experiment' ||
        payloadKind == 'experiment') {
      return _TimelineEntryKind(
        title: AppLocaleText.tr(
          context,
          en: 'Goal',
          zhHans: '目标',
          zhHant: '目標',
          ja: '目標',
        ),
        icon: Icons.science_rounded,
        color: AuroraColors.purple,
        filter: _TimelineFilter.experiment,
      );
    }
    if (source == 'one_tap' || source == 'status') {
      return _TimelineEntryKind(
        title: AppLocaleText.tr(
          context,
          en: 'State',
          zhHans: '状态',
          zhHant: '狀態',
          ja: '状態',
        ),
        icon: Icons.mood_rounded,
        color: AuroraColors.orange,
        filter: _TimelineFilter.record,
      );
    }
    if (source == 'ai_predicted') {
      return _TimelineEntryKind(
        title: AppLocaleText.tr(
          context,
          en: 'Prediction',
          zhHans: '智能预判',
          zhHant: '智慧預判',
          ja: '人工知能による予測',
        ),
        icon: Icons.text_fields_rounded,
        color: AuroraColors.blue,
        filter: _TimelineFilter.record,
      );
    }
    if (source == 'voice') {
      return _TimelineEntryKind(
        title: AppLocaleText.tr(
          context,
          en: 'Voice record',
          zhHans: '语音记录',
          zhHant: '語音記錄',
          ja: '音声記録',
        ),
        icon: Icons.mic_rounded,
        color: AuroraColors.purple,
        filter: _TimelineFilter.record,
      );
    }
    return _TimelineEntryKind(
      title: AppLocaleText.tr(
        context,
        en: 'Text record',
        zhHans: '文字记录',
        zhHant: '文字記錄',
        ja: '文字記録',
      ),
      icon: Icons.notes_rounded,
      color: AuroraColors.purple,
      filter: _TimelineFilter.record,
    );
  }

  static String _body(BuildContext context, RecentSignalModel signal) {
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
    return _fallbackReplyFromContent(context, signal.content);
  }

  static String? _usableAiText(String? value) {
    return sanitizeTimelineAcknowledgement(value);
  }

  static String _fallbackReplyFromContent(
    BuildContext context,
    String content,
  ) {
    final text = content.trim();
    if (text.contains('累') || text.contains('疲') || text.contains('耗')) {
      return AppLocaleText.tr(
        context,
        en: 'This record may be a reminder to notice your energy today.',
        zhHans: '这条记录更像是在提醒你：今天的能量需要被看见。',
        zhHant: '這條記錄更像是在提醒你：今天的能量需要被看見。',
        ja: 'この記録は、今日のエネルギーに目を向ける合図かもしれません。',
      );
    }
    if (text.contains('睡') || text.contains('休息')) {
      return AppLocaleText.tr(
        context,
        en: 'This record relates to recovery. You can notice whether it recurs.',
        zhHans: '这条记录和恢复有关，之后可以看看它是否反复出现。',
        zhHant: '這條記錄和恢復有關，之後可以看看它是否反覆出現。',
        ja: 'この記録は回復に関係しています。繰り返すかを後で見てみましょう。',
      );
    }
    if (text.contains('上班') || text.contains('工作') || text.contains('会议')) {
      return AppLocaleText.tr(
        context,
        en: 'This record may relate to your work rhythm. Keep it as one of today’s clues.',
        zhHans: '这条记录可能和工作节奏有关，可以先轻轻放进今天的线索里。',
        zhHant: '這條記錄可能和工作節奏有關，可以先輕輕放進今天的線索裡。',
        ja: 'この記録は仕事のリズムに関係しているかもしれません。今日の手がかりとして残しておきましょう。',
      );
    }
    return text.isEmpty
        ? AppLocaleText.tr(
            context,
            en: 'This is one of today’s life signals.',
            zhHans: '这是一条今天的生活信号。',
            zhHant: '這是一條今天的生活信號。',
            ja: 'これは今日の暮らしのシグナルです。',
          )
        : AppLocaleText.tr(
            context,
            en: 'This record is now one of today’s life signals.',
            zhHans: '这条记录已经成为今天的一条生活信号。',
            zhHant: '這條記錄已經成為今天的一條生活信號。',
            ja: 'この記録は今日の暮らしのシグナルになりました。',
          );
  }

  static String? _feedbackLabel(
    BuildContext context,
    RecentSignalModel signal,
  ) {
    final feedback = signal.rawPayloadJson['feedback']?.toString() ??
        signal.rawPayloadJson['micro_action_feedback']?.toString() ??
        signal.userCorrectionJson['feedback']?.toString();
    switch (feedback) {
      case 'completed':
      case 'occurred':
      case 'done':
      case 'happened':
        return AppLocaleText.tr(
          context,
          en: 'Completed',
          zhHans: '已完成',
          zhHant: '已完成',
          ja: '完了',
        );
      case 'not_completed':
      case 'not_occurred':
      case 'not_done':
      case 'not_happened':
        return AppLocaleText.tr(
          context,
          en: 'Not completed',
          zhHans: '未完成',
          zhHant: '未完成',
          ja: '未完了',
        );
      case 'not_suitable_today':
      case 'skip':
        return AppLocaleText.tr(
          context,
          en: 'Not completed',
          zhHans: '未完成',
          zhHant: '未完成',
          ja: '未完了',
        );
      case 'helpful':
        return AppLocaleText.tr(
          context,
          en: 'Helpful',
          zhHans: '有帮助',
          zhHant: '有幫助',
          ja: '役に立った',
        );
      default:
        if (feedback?.trim().isEmpty ?? true) return null;
        return EnergyBudgetText.localizeCopy(context, feedback!.trim());
    }
  }

  static (String, double)? _progress(
    BuildContext context,
    RecentSignalModel signal,
  ) {
    final done = _asInt(signal.rawPayloadJson['completed_days'] ??
        signal.rawPayloadJson['done_days']);
    final total = _asInt(signal.rawPayloadJson['total_days']) ?? 7;
    if (done == null) return null;
    final safeTotal = total <= 0 ? 7 : total;
    return (
      AppLocaleText.tr(
        context,
        en: 'Progress $done/$safeTotal',
        zhHans: '进度 $done/$safeTotal',
        zhHant: '進度 $done/$safeTotal',
        ja: '進捗 $done/$safeTotal',
      ),
      (done / safeTotal).clamp(0, 1),
    );
  }

  static int? _asInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }
}

class _DiaryTimeUseData {
  final String startTime;
  final String endTime;
  final String title;
  final String categoryLabel;
  final String statusLabel;
  final bool isPlanned;

  const _DiaryTimeUseData({
    required this.startTime,
    required this.endTime,
    required this.title,
    required this.categoryLabel,
    required this.statusLabel,
    required this.isPlanned,
  });

  static _DiaryTimeUseData? tryFromSignal(
    BuildContext context,
    RecentSignalModel signal,
  ) {
    final payload = signal.rawPayloadJson;
    final startAt =
        DateTime.tryParse(payload['start_at']?.toString() ?? '')?.toLocal();
    final endAt =
        DateTime.tryParse(payload['end_at']?.toString() ?? '')?.toLocal();
    if (startAt == null || endAt == null || !endAt.isAfter(startAt)) {
      return null;
    }
    final rawCategory = payload['focus_domain_id']?.toString() ??
        payload['category']?.toString() ??
        '';
    final planned = payload['record_status']?.toString() == 'planned';
    final structuredTitle = payload['title']?.toString().trim() ?? '';
    return _DiaryTimeUseData(
      startTime: _clock(startAt),
      endTime: _clock(endAt),
      title: structuredTitle.isEmpty ? signal.content.trim() : structuredTitle,
      categoryLabel:
          _TimelineEntryKind._timeUseDomainLabel(context, rawCategory) ??
              AppLocaleText.tr(
                context,
                en: 'Other',
                zhHans: '其他',
                zhHant: '其他',
                ja: 'その他',
              ),
      statusLabel: planned
          ? AppLocaleText.tr(
              context,
              en: 'Coming up',
              zhHans: '接下来安排',
              zhHant: '接下來安排',
              ja: 'これからの予定',
            )
          : AppLocaleText.tr(
              context,
              en: 'Completed',
              zhHans: '已经发生',
              zhHant: '已經發生',
              ja: '完了',
            ),
      isPlanned: planned,
    );
  }

  static String _clock(DateTime value) {
    return '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
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

  String? tagLabel(BuildContext context, RecentSignalModel signal) {
    final firstScene =
        signal.sceneTags.isNotEmpty ? signal.sceneTags.first.trim() : '';
    final rawFocusDomain =
        signal.rawPayloadJson['focus_domain_id']?.toString() ??
            signal.rawPayloadJson['category']?.toString();
    final focusDomain = FocusDomains.optionFor(rawFocusDomain) ??
        FocusDomains.optionFor(firstScene);
    if (focusDomain != null) return focusDomain.label(context);
    if (signal.sourceType == 'time_use' ||
        signal.rawPayloadJson['timeline_type'] == 'time_use') {
      final rawDomain = rawFocusDomain ?? firstScene;
      final label = _timeUseDomainLabel(context, rawDomain);
      if (label != null) return label;
    }
    if (firstScene.isNotEmpty) {
      return _timelineTaxonomyLabel(context, firstScene);
    }
    final energyLabel = _signalStateLabel(context, signal.energyLoad);
    if (energyLabel != null) return energyLabel;
    final emotionLabel = _signalStateLabel(context, signal.emotion);
    if (emotionLabel != null) return emotionLabel;
    if (signal.isLibrarySaved) {
      return AppLocaleText.tr(
        context,
        en: 'Signal Library',
        zhHans: '信号库',
        zhHant: '信號庫',
        ja: 'Signal ライブラリ',
      );
    }
    return null;
  }

  static String? _timeUseDomainLabel(BuildContext context, String? raw) {
    final normalized = raw?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty) return null;
    final focusDomain = FocusDomains.optionFor(normalized);
    if (focusDomain != null) return focusDomain.label(context);
    return switch (normalized) {
      'work' => AppLocaleText.tr(
          context,
          en: 'Work',
          zhHans: '工作',
          zhHant: '工作',
          ja: '仕事',
        ),
      'commute' => AppLocaleText.tr(
          context,
          en: 'Commute',
          zhHans: '通勤',
          zhHant: '通勤',
          ja: '通勤',
        ),
      'household' => AppLocaleText.tr(
          context,
          en: 'Household',
          zhHans: '家务',
          zhHant: '家務',
          ja: '家事',
        ),
      'relationship' => AppLocaleText.tr(
          context,
          en: 'Relationships',
          zhHans: '关系',
          zhHant: '關係',
          ja: '関係',
        ),
      'recovery' => AppLocaleText.tr(
          context,
          en: 'Recovery',
          zhHans: '恢复',
          zhHant: '恢復',
          ja: '回復',
        ),
      'interest' => AppLocaleText.tr(
          context,
          en: 'Interests',
          zhHans: '兴趣',
          zhHant: '興趣',
          ja: '趣味',
        ),
      'other' => AppLocaleText.tr(
          context,
          en: 'Other',
          zhHans: '其他',
          zhHant: '其他',
          ja: 'その他',
        ),
      _ => null,
    };
  }

  static String? _signalStateLabel(BuildContext context, String? raw) {
    final normalized = raw?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty) return null;
    return switch (normalized) {
      'draining' || 'high_draining' => AppLocaleText.tr(
          context,
          en: 'Draining',
          zhHans: '消耗',
          zhHant: '消耗',
          ja: '消耗',
        ),
      'restoring' || 'restorative' || 'recovering' => AppLocaleText.tr(
          context,
          en: 'Restoring',
          zhHans: '恢复',
          zhHant: '恢復',
          ja: '回復',
        ),
      'mixed' => AppLocaleText.tr(
          context,
          en: 'Mixed',
          zhHans: '混合',
          zhHant: '混合',
          ja: '混在',
        ),
      'neutral' => AppLocaleText.tr(
          context,
          en: 'Neutral',
          zhHans: '中性',
          zhHant: '中性',
          ja: '中立',
        ),
      'calm' => AppLocaleText.tr(
          context,
          en: 'Calm',
          zhHans: '平静',
          zhHant: '平靜',
          ja: '穏やか',
        ),
      'happy' => AppLocaleText.tr(
          context,
          en: 'Happy',
          zhHans: '开心',
          zhHant: '開心',
          ja: 'うれしい',
        ),
      'tired' => AppLocaleText.tr(
          context,
          en: 'Tired',
          zhHans: '疲惫',
          zhHant: '疲憊',
          ja: '疲れ',
        ),
      'anxious' => AppLocaleText.tr(
          context,
          en: 'Anxious',
          zhHans: '焦虑',
          zhHant: '焦慮',
          ja: '不安',
        ),
      'confused' => AppLocaleText.tr(
          context,
          en: 'Confused',
          zhHans: '混乱',
          zhHant: '混亂',
          ja: '混乱',
        ),
      _ => _timelineTaxonomyLabel(context, normalized),
    };
  }

  static String _timelineTaxonomyLabel(
    BuildContext context,
    String raw,
  ) {
    final normalized = raw.trim().toLowerCase().replaceAll(' ', '_');
    if (normalized.isEmpty) return '';
    final focusDomain = FocusDomains.optionFor(normalized);
    if (focusDomain != null) return focusDomain.label(context);
    final localized = EnergyBudgetText.localizeCopy(context, normalized);
    if (localized != normalized) return localized;
    if (normalized == 'unknown') {
      return AppLocaleText.tr(
        context,
        en: 'To observe',
        zhHans: '待观察',
        zhHant: '待觀察',
        ja: '観察中',
      );
    }
    if (normalized == 'other') {
      return AppLocaleText.tr(
        context,
        en: 'Other',
        zhHans: '其他',
        zhHant: '其他',
        ja: 'その他',
      );
    }
    final languageCode = Localizations.localeOf(context).languageCode;
    if (languageCode != 'en' && RegExp(r'^[a-z0-9_-]+$').hasMatch(normalized)) {
      return AppLocaleText.tr(
        context,
        en: normalized.replaceAll('_', ' '),
        zhHans: '其他',
        zhHant: '其他',
        ja: 'その他',
      );
    }
    return normalized.replaceAll('_', ' ');
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

// Retained for compatibility with older visual snapshots.
// ignore: unused_element
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
