import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/di/app_dependencies.dart';
import '../../../core/i18n/app_locale_text.dart';
import '../../../core/models/weekly_models.dart';
import '../../../core/navigation/app_back_navigation.dart';
import '../../../shared/widgets/aurora_ui.dart';

enum _GoalRecordAvailability { active, notStarted, ended }

class TodayExperimentFeedbackPage extends StatefulWidget {
  final String experimentId;

  const TodayExperimentFeedbackPage({
    super.key,
    required this.experimentId,
  });

  @visibleForTesting
  static String normalizedFeedbackText(String rawText) => rawText.trim();

  @override
  State<TodayExperimentFeedbackPage> createState() =>
      _TodayExperimentFeedbackPageState();
}

class _TodayExperimentFeedbackPageState
    extends State<TodayExperimentFeedbackPage> {
  final _noteController = TextEditingController();
  String? _status;
  bool _loading = true;
  bool _saving = false;
  LifeExperimentModel? _experiment;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final deps = context.read<AppDependencies>();
    final experiment = await deps.localLifeExperimentRepository.getById(
      widget.experimentId,
    );
    if (!mounted) return;
    setState(() {
      _experiment = experiment;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final experiment = _experiment;
    final status = _status;
    if (experiment == null ||
        status == null ||
        _saving ||
        _goalRecordAvailability(experiment) != _GoalRecordAvailability.active) {
      return;
    }
    setState(() => _saving = true);
    final deps = context.read<AppDependencies>();
    final saved = await deps.localLifeExperimentRepository.recordFeedback(
      experimentId: experiment.id,
      localUserId: deps.localUserId,
      completionStatus: status,
      feedbackText: TodayExperimentFeedbackPage.normalizedFeedbackText(
        _noteController.text,
      ),
      feedbackDate: DateTime.now(),
      conditionTags: [status],
      enforceProgressWindow: true,
    );
    if (!mounted) return;
    if (saved == null) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocaleText.tr(
              context,
              en: 'This goal is not currently within its planned record period.',
              zhHans: '当前不在这条目标的计划记录期内。',
              zhHant: '目前不在這個目標的計畫記錄期內。',
              ja: '現在はこの目標の予定記録期間外です。',
            ),
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocaleText.tr(
            context,
            en: 'Goal feedback saved.',
            zhHans: '目标反馈已保存。',
            zhHant: '目標回饋已保存。',
            ja: '目標のフィードバックを保存しました。',
          ),
        ),
      ),
    );
    context.go(AppRoutes.today);
  }

  @override
  Widget build(BuildContext context) {
    final experiment = _experiment;
    final recordAvailability = experiment == null
        ? _GoalRecordAvailability.ended
        : _goalRecordAvailability(experiment);
    return Scaffold(
      body: Stack(
        children: [
          AuroraPage(
            child: Stack(
              children: [
                const Positioned(
                  key: ValueKey('experiment-feedback-experiment-pattern'),
                  right: -22,
                  top: 10,
                  width: 182,
                  height: 124,
                  child: IgnorePointer(
                    child: AuroraExperimentHeroPattern(
                      opacity: 0.68,
                      alignment: Alignment.centerRight,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: ListView(
                    key: const ValueKey('experiment-feedback-scroll-view'),
                    padding: EdgeInsets.fromLTRB(
                      AuroraMainPageSpec.horizontalPadding,
                      AuroraMainPageSpec.topPadding,
                      AuroraMainPageSpec.horizontalPadding,
                      MediaQuery.paddingOf(context).bottom + 32,
                    ),
                    children: [
                      Row(
                        children: [
                          AuroraIconButton(
                            onPressed: () => context.popOrGo(AppRoutes.today),
                            icon: Icons.chevron_left_rounded,
                            tooltip: AppLocaleText.tr(
                              context,
                              en: 'Back',
                              zhHans: '返回',
                              zhHant: '返回',
                              ja: '戻る',
                            ),
                          ),
                          Expanded(
                            child: Text(
                              AppLocaleText.tr(
                                context,
                                en: 'Goal feedback',
                                zhHans: '目标反馈',
                                zhHant: '目標回饋',
                                ja: '目標フィードバック',
                              ),
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    color: AuroraColors.ink,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 44),
                        ],
                      ),
                      const SizedBox(height: 22),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (experiment == null)
                        AuroraCard(
                          padding: AuroraMainPageSpec.comfortableCardPadding,
                          child: Text(
                            AppLocaleText.tr(
                              context,
                              en: 'This goal could not be found.',
                              zhHans: '没有找到这个目标。',
                              zhHant: '沒有找到這個目標。',
                              ja: 'この目標が見つかりません。',
                            ),
                          ),
                        )
                      else ...[
                        AuroraCard(
                          padding: AuroraMainPageSpec.comfortableCardPadding,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFFFFFBF7).withValues(alpha: 0.90),
                              const Color(0xFFF2EEFF).withValues(alpha: 0.82),
                              const Color(0xFFEDF7FF).withValues(alpha: 0.72),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const AuroraSectionIcon(
                                icon: Icons.science_rounded,
                                color: AuroraColors.purple,
                                size: 38,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      experiment.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            color: AuroraColors.ink,
                                            fontWeight: FontWeight.w700,
                                            height: 1.25,
                                          ),
                                    ),
                                    const SizedBox(height: 7),
                                    Text(
                                      experiment.suggestedAction,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: AuroraColors.ink
                                                .withValues(alpha: 0.70),
                                            height: 1.42,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (recordAvailability !=
                            _GoalRecordAvailability.active)
                          AuroraCard(
                            key: const ValueKey(
                              'goal-feedback-record-window-read-only',
                            ),
                            padding: AuroraMainPageSpec.comfortableCardPadding,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.history_rounded,
                                  color: AuroraColors.muted,
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    _recordAvailabilityLabel(
                                      context,
                                      recordAvailability,
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: AuroraColors.muted,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else ...[
                          AuroraCard(
                            padding: AuroraMainPageSpec.comfortableCardPadding,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const AuroraSectionIcon(
                                      icon: Icons.rate_review_rounded,
                                      color: AuroraColors.mint,
                                      size: 32,
                                    ),
                                    const SizedBox(width: 9),
                                    Expanded(
                                      child: Text(
                                        AppLocaleText.tr(
                                          context,
                                          en: 'Did you complete it today?',
                                          zhHans: '今天完成了吗？',
                                          zhHant: '今天完成了嗎？',
                                          ja: '今日は完了しましたか？',
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              color: AuroraColors.ink,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _FeedbackChoice(
                                      selected: _status == 'completed',
                                      label: AppLocaleText.tr(context,
                                          en: 'Completed',
                                          zhHans: '已完成',
                                          zhHant: '已完成',
                                          ja: '完了'),
                                      onTap: () =>
                                          setState(() => _status = 'completed'),
                                    ),
                                    _FeedbackChoice(
                                      selected: _status == 'not_completed',
                                      label: AppLocaleText.tr(context,
                                          en: 'Not completed',
                                          zhHans: '未完成',
                                          zhHant: '未完成',
                                          ja: '未完了'),
                                      onTap: () => setState(
                                          () => _status = 'not_completed'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                TextField(
                                  controller: _noteController,
                                  maxLines: 4,
                                  decoration: InputDecoration(
                                    hintText: AppLocaleText.tr(
                                      context,
                                      en: 'Add one sentence if you want.',
                                      zhHans: '如果愿意，可以补一句。',
                                      zhHant: '如果願意，可以補一句。',
                                      ja: '必要なら一言足せます。',
                                    ),
                                    filled: true,
                                    fillColor:
                                        Colors.white.withValues(alpha: 0.58),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide: BorderSide(
                                        color: AuroraColors.line
                                            .withValues(alpha: 0.74),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide: const BorderSide(
                                        color: AuroraColors.purple,
                                        width: 1.2,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 52,
                            child: AuroraPillButton(
                              filled: true,
                              icon: Icons.check_rounded,
                              label: _saving
                                  ? AppLocaleText.tr(
                                      context,
                                      en: 'Saving',
                                      zhHans: '保存中',
                                      zhHant: '保存中',
                                      ja: '保存中',
                                    )
                                  : AppLocaleText.tr(
                                      context,
                                      en: 'Save feedback',
                                      zhHans: '保存反馈',
                                      zhHant: '保存回饋',
                                      ja: '保存する',
                                    ),
                              onPressed:
                                  _saving || _status == null ? null : _save,
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const AuroraSafeTopMask(extraHeight: 4),
        ],
      ),
    );
  }
}

_GoalRecordAvailability _goalRecordAvailability(
  LifeExperimentModel experiment, {
  DateTime? now,
}) {
  final status = experiment.status.trim().toLowerCase();
  if (!const {'accepted', 'saved', 'active', 'in_progress'}.contains(status)) {
    return _GoalRecordAvailability.ended;
  }
  final start = _parseLocalDate(experiment.progressStartDate) ??
      _parseLocalDate(experiment.sourceWeekStart) ??
      experiment.adoptedAt?.toLocal() ??
      experiment.createdAt?.toLocal();
  if (start == null) return _GoalRecordAvailability.ended;
  final end = _parseLocalDate(experiment.progressEndDate);
  final today = _dateOnly((now ?? DateTime.now()).toLocal());
  final localStart = _dateOnly(start.toLocal());
  if (today.isBefore(localStart)) return _GoalRecordAvailability.notStarted;
  if (end != null && today.isAfter(_dateOnly(end.toLocal()))) {
    return _GoalRecordAvailability.ended;
  }
  return _GoalRecordAvailability.active;
}

DateTime? _parseLocalDate(String? value) {
  final raw = value?.trim() ?? '';
  return raw.isEmpty ? null : DateTime.tryParse(raw);
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _recordAvailabilityLabel(
  BuildContext context,
  _GoalRecordAvailability availability,
) {
  return availability == _GoalRecordAvailability.notStarted
      ? AppLocaleText.tr(
          context,
          en: 'The planned record period has not started yet.',
          zhHans: '计划记录期尚未开始',
          zhHant: '計畫記錄期尚未開始',
          ja: '予定された記録期間はまだ始まっていません',
        )
      : AppLocaleText.tr(
          context,
          en: 'The planned record period has ended.',
          zhHans: '计划记录期已结束',
          zhHant: '計畫記錄期已結束',
          ja: '予定された記録期間は終了しました',
        );
}

class _FeedbackChoice extends StatelessWidget {
  final bool selected;
  final String label;
  final VoidCallback onTap;

  const _FeedbackChoice({
    required this.selected,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) => onTap(),
      showCheckmark: false,
      selectedColor: AuroraColors.purple.withValues(alpha: 0.14),
      backgroundColor: Colors.white.withValues(alpha: 0.58),
      side: BorderSide(
        color: selected
            ? AuroraColors.purple.withValues(alpha: 0.48)
            : Colors.white.withValues(alpha: 0.82),
      ),
      labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: selected ? AuroraColors.purple : AuroraColors.ink,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}
