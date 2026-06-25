// ignore_for_file: unused_element

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/i18n/app_locale_text.dart';
import '../../../core/models/phase3_plus_models.dart';
import '../../../core/models/today_models.dart';
import '../../../core/purchases/purchase_controller.dart';
import '../../../shared/states/load_state.dart';
import '../../../shared/widgets/aurora_ui.dart';
import '../../../shared/widgets/signal_illustration_kit.dart';
import '../../paywall/paywall_sheet.dart';
import '../weekly/weekly_view_model.dart';
import 'today_state.dart';
import 'today_view_model.dart';

class TodayPage extends StatefulWidget {
  const TodayPage({super.key});

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  late final TextEditingController _controller;
  late final FocusNode _captureFocusNode;
  int _lastCaptureSuccessTick = 0;
  int _lastFollowupSuccessTick = 0;

  @override
  void initState() {
    super.initState();
    final vm = context.read<TodayViewModel>();
    _controller = TextEditingController(text: vm.state.inputText);
    _captureFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _captureFocusNode.dispose();
    super.dispose();
  }

  void _openMePage() {
    context.go(AppRoutes.me);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TodayViewModel>();
    final weeklyVm = context.watch<WeeklyViewModel?>();
    final purchase = context.watch<PurchaseController?>();
    final state = vm.state;
    final todaySignals = _todayOnlySignals(state.recentSignals);
    final pendingDraftCount = state.recentSignals
        .where((signal) => signal.isLocalDraft || signal.syncFailed)
        .length;

    if (_controller.text != state.inputText) {
      _controller.value = TextEditingValue(
        text: state.inputText,
        selection: TextSelection.collapsed(offset: state.inputText.length),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (state.captureSuccessTick > _lastCaptureSuccessTick) {
        _lastCaptureSuccessTick = state.captureSuccessTick;
        FocusScope.of(context).unfocus();
      }

      if (state.followupSuccessTick > _lastFollowupSuccessTick) {
        _lastFollowupSuccessTick = state.followupSuccessTick;
        FocusScope.of(context).unfocus();
      }
    });

    final insightText = _resolveObservationText(context, state, todaySignals);

    return Scaffold(
      body: Stack(
        children: [
          AuroraPage(
            child: SafeArea(
              bottom: false,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  18,
                  2,
                  18,
                  MediaQuery.paddingOf(context).bottom + 88,
                ),
                children: [
                  _CaptureInputCard(
                    controller: _controller,
                    focusNode: _captureFocusNode,
                    isSubmitting: state.isCaptureSubmitting,
                    onChanged: vm.updateInput,
                    onTextMode: () {
                      if (_controller.text.trim().isEmpty) {
                        _captureFocusNode.requestFocus();
                      } else {
                        vm.submitCapture();
                      }
                    },
                    onVoiceDraft: () => _openVoiceTranscriptDraft(context, vm),
                    onQuickStatus: () => _openQuickStatusSheet(context, vm),
                    onSchedule: () => _openScheduleSignalForm(context, vm),
                    onPredict: () => vm.createPredictedSignal(
                      language: AppLocaleText.resolve(context),
                    ),
                  ),
                  if (state.hasError &&
                      state.errorMessage != 'empty_input') ...[
                    const SizedBox(height: 10),
                    _InlineStatusCard(
                      icon: Icons.error_outline,
                      text: _displayErrorText(context, state.errorMessage),
                      isError: true,
                    ),
                  ],
                  const SizedBox(height: 10),
                  _TodayOverviewCard(signals: todaySignals),
                  const SizedBox(height: 10),
                  _TodayInsightCard(text: insightText),
                  const SizedBox(height: 10),
                  _AiJudgementPanel(
                    judgement: state.aiJudgement,
                    microAction: state.activeMicroAction,
                    isBusy: state.isCaptureSubmitting,
                    onConfirm: (judgement) => vm.respondToAiJudgement(
                      judgement: judgement,
                      status: 'confirmed',
                      language: AppLocaleText.resolve(context),
                    ),
                    onInaccurate: (judgement) => vm.respondToAiJudgement(
                      judgement: judgement,
                      status: 'inaccurate',
                      language: AppLocaleText.resolve(context),
                    ),
                    onAdjust: (judgement) async {
                      final text = await _askForShortText(
                        context,
                        title: AppLocaleText.tr(
                          context,
                          en: 'Adjust this judgement',
                          zhHans: '调整这个判断',
                          zhHant: '調整這個判斷',
                          ja: 'この判断を調整',
                        ),
                        hint: AppLocaleText.tr(
                          context,
                          en: 'What feels closer?',
                          zhHans: '怎样说更接近？',
                          zhHant: '怎樣說更接近？',
                          ja: 'どう言うと近いですか？',
                        ),
                      );
                      if (text == null ||
                          text.trim().isEmpty ||
                          !context.mounted) {
                        return;
                      }
                      final language = AppLocaleText.resolve(context);
                      await vm.respondToAiJudgement(
                        judgement: judgement,
                        status: 'adjusted',
                        userAdjustmentText: text.trim(),
                        language: language,
                      );
                    },
                    onSupplement: (judgement) async {
                      final text = await _askForShortText(
                        context,
                        title: AppLocaleText.tr(
                          context,
                          en: 'Add one sentence',
                          zhHans: '补一句',
                          zhHant: '補一句',
                          ja: '一言補足',
                        ),
                        hint: AppLocaleText.tr(
                          context,
                          en: 'Add a little context',
                          zhHans: '补充一点自己的情况',
                          zhHant: '補充一點自己的情況',
                          ja: '少し状況を足す',
                        ),
                      );
                      if (text == null ||
                          text.trim().isEmpty ||
                          !context.mounted) {
                        return;
                      }
                      final language = AppLocaleText.resolve(context);
                      await vm.respondToAiJudgement(
                        judgement: judgement,
                        status: 'supplemented',
                        userAdjustmentText: text.trim(),
                        language: language,
                      );
                    },
                    onMicroActionChoice: (action, choice) =>
                        vm.chooseMicroAction(
                      action: action,
                      choice: choice,
                      language: AppLocaleText.resolve(context),
                    ),
                    onFeedback: (action, feedback) async {
                      if (feedback == 'note') {
                        final text = await _askForShortText(
                          context,
                          title: AppLocaleText.tr(
                            context,
                            en: 'Add one note',
                            zhHans: '补一句反馈',
                            zhHant: '補一句回饋',
                            ja: '一言フィードバック',
                          ),
                          hint: AppLocaleText.tr(
                            context,
                            en: 'What happened after trying it?',
                            zhHans: '试过之后发生了什么？',
                            zhHant: '試過之後發生了什麼？',
                            ja: '試した後、何が起きましたか？',
                          ),
                        );
                        if (text == null ||
                            text.trim().isEmpty ||
                            !context.mounted) {
                          return;
                        }
                        await vm.submitMicroActionFeedback(
                          action: action,
                          feedback: feedback,
                          userNote: text.trim(),
                        );
                        return;
                      }
                      await vm.submitMicroActionFeedback(
                        action: action,
                        feedback: feedback,
                      );
                    },
                  ),
                  if (state.pendingQuestion != null) ...[
                    const SizedBox(height: 10),
                    _FollowupQuestionCard(
                      question: state.pendingQuestion!,
                      isSubmitting: state.isFollowupSubmitting,
                      onSubmit: vm.submitFollowup,
                    ),
                  ],
                  const SizedBox(height: 12),
                  _ScheduleSignalsSection(
                    schedules: state.scheduleSignals,
                    onCreate: () => _openScheduleSignalForm(context, vm),
                    onEdit: (schedule) => _openScheduleSignalForm(context, vm,
                        schedule: schedule),
                    onRecordFeeling: (schedule) =>
                        _openScheduleFeelingForm(context, vm, schedule),
                  ),
                  const SizedBox(height: 12),
                  _GoalExerciseSection(
                    goals: state.activeGoals,
                    tasks: state.goalTasks,
                    onCreate: () => _openGoalForm(context, vm),
                    onFeedback: (task, feedback) async {
                      final happened = feedback == 'not_today' ? 'no' : 'yes';
                      final effect = switch (feedback) {
                        'helpful' => 'helpful',
                        'adjust' => 'adjust',
                        'not_today' => 'not_today',
                        _ => 'tried',
                      };
                      await vm.submitGoalFeedback(
                        task: task,
                        happened: happened,
                        effect: effect,
                      );
                      if (!context.mounted) return;
                      _showSoftMessage(
                        context,
                        AppLocaleText.tr(
                          context,
                          en: 'Your feedback is saved.',
                          zhHans: '反馈已保存。',
                          zhHant: '回饋已保存。',
                          ja: 'フィードバックを保存しました。',
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _DiaryTimelineSection(
                    signals: todaySignals,
                    pendingDraftCount: pendingDraftCount,
                    isSyncing: state.isDraftSyncing,
                    syncMessage: state.draftSyncMessage,
                    onOpenAllRecords: () => context.push(AppRoutes.todayDiary),
                    onOpenDialog: (signal) {
                      final captureId = signal.signalCardId ?? signal.id;
                      if (captureId == null || captureId.trim().isEmpty) {
                        return;
                      }
                      _openTodayDialog(context, purchase, captureId);
                    },
                  ),
                  if (state.isInitialLoading) ...[
                    const SizedBox(height: 18),
                    const Center(child: CircularProgressIndicator()),
                  ],
                  if (!state.isInitialLoading) ...[
                    const SizedBox(height: 12),
                    _WeeklyExperimentTodayCard(
                      experiment: weeklyVm?.weeklyInsight?.lifeExperiment,
                      isSubmitting: weeklyVm?.experimentSubmitState ==
                          SubmitState.submitting,
                      onFeedback: (status, text) async {
                        await weeklyVm?.submitExperimentFeedback(
                          status: status,
                          feedbackText: text,
                        );
                        if (!context.mounted) return;
                        _showSoftMessage(
                          context,
                          AppLocaleText.tr(
                            context,
                            en: 'This experiment note is saved.',
                            zhHans: '这次实验反馈已保存。',
                            zhHant: '這次實驗回饋已保存。',
                            ja: '試みの反応を保存しました。',
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          const AuroraSafeTopMask(extraHeight: 4),
        ],
      ),
    );
  }

  void _showSoftMessage(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _openTodayDialog(
    BuildContext context,
    PurchaseController? purchase,
    String captureId,
  ) {
    if (purchase?.isPremium ?? false) {
      context.push('${AppRoutes.todayDialog}/$captureId');
      return;
    }

    showPremiumPaywall(context, source: 'Today dialogue');
  }

  Future<void> _retryDraftSync(
    BuildContext context,
    TodayViewModel vm,
  ) async {
    final result = await vm.retryDraftSync();
    if (!context.mounted) return;

    final text = switch (result) {
      DraftSyncResult.completed => AppLocaleText.tr(
          context,
          en: 'Sync completed.',
          zhHans: '同步完成。',
          zhHant: '同步完成。',
          ja: '同期が完了しました。',
        ),
      DraftSyncResult.noPending => AppLocaleText.tr(
          context,
          en: 'Nothing is waiting to sync.',
          zhHans: '没有需要同步的内容。',
          zhHant: '沒有需要同步的內容。',
          ja: '同期待ちの内容はありません。',
        ),
      DraftSyncResult.stillPending => AppLocaleText.tr(
          context,
          en: 'Still saved on this device. Try again when the connection is stable.',
          zhHans: '内容仍已保存在本机。网络稳定后可以再试一次。',
          zhHant: '內容仍已保存在本機。網路穩定後可以再試一次。',
          ja: '内容は端末に保存されています。接続が安定したら、もう一度試せます。',
        ),
    };

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _openVoiceTranscriptDraft(
    BuildContext context,
    TodayViewModel vm,
  ) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => const _VoiceTranscriptSheet(),
    );
    if (result == null || result.trim().isEmpty) return;
    await vm.submitVoiceTranscript(result);
  }

  Future<void> _openQuickStatusSheet(
    BuildContext context,
    TodayViewModel vm,
  ) async {
    final language = AppLocaleText.resolve(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: AuroraColors.purple.withValues(alpha: 0.14),
              blurRadius: 34,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
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
                    en: 'Leave one quick state',
                    zhHans: '留一个当前状态',
                    zhHant: '留一個目前狀態',
                    ja: '今の状態を一つ残す',
                  ),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AuroraColors.ink,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Tap the closest feeling. It is only saved as a private signal.',
                    zhHans: '点一个最接近的感觉，只会作为你的私人信号保存。',
                    zhHant: '點一個最接近的感覺，只會作為你的私人信號保存。',
                    ja: '近い感覚を一つ選びます。個人のシグナルとしてだけ保存されます。',
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AuroraColors.muted,
                        height: 1.35,
                      ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _QuickMoodOption(
                      emoji: '🙂',
                      color: AuroraColors.mint,
                      title: AppLocaleText.tr(
                        context,
                        en: 'Feeling good',
                        zhHans: '感觉不错',
                        zhHant: '感覺不錯',
                        ja: 'いい感じ',
                      ),
                      onTap: () => Navigator.of(dialogContext).pop('good'),
                    ),
                    _QuickMoodOption(
                      emoji: '😌',
                      color: AuroraColors.blue,
                      title: AppLocaleText.tr(
                        context,
                        en: 'Steady',
                        zhHans: '比较平稳',
                        zhHant: '比較平穩',
                        ja: '落ち着いている',
                      ),
                      onTap: () => Navigator.of(dialogContext).pop('steady'),
                    ),
                    _QuickMoodOption(
                      emoji: '😮‍💨',
                      color: AuroraColors.gold,
                      title: AppLocaleText.tr(
                        context,
                        en: 'A bit tired',
                        zhHans: '有点累',
                        zhHant: '有點累',
                        ja: '少し疲れた',
                      ),
                      onTap: () => Navigator.of(dialogContext).pop('tired'),
                    ),
                    _QuickMoodOption(
                      emoji: '😵‍💫',
                      color: AuroraColors.purple,
                      title: AppLocaleText.tr(
                        context,
                        en: 'A bit scattered',
                        zhHans: '有点乱',
                        zhHant: '有點亂',
                        ja: '少し散らかっている',
                      ),
                      onTap: () => Navigator.of(dialogContext).pop('scattered'),
                    ),
                    _QuickMoodOption(
                      emoji: '😤',
                      color: AuroraColors.orange,
                      title: AppLocaleText.tr(
                        context,
                        en: 'A little irritated',
                        zhHans: '有点烦',
                        zhHant: '有點煩',
                        ja: '少しイライラ',
                      ),
                      onTap: () => Navigator.of(dialogContext).pop('irritated'),
                    ),
                    _QuickMoodOption(
                      emoji: '🌿',
                      color: AuroraColors.mint,
                      title: AppLocaleText.tr(
                        context,
                        en: 'Need recovery',
                        zhHans: '想恢复',
                        zhHant: '想恢復',
                        ja: '回復したい',
                      ),
                      onTap: () => Navigator.of(dialogContext).pop('recovery'),
                    ),
                    _QuickMoodOption(
                      emoji: '🤝',
                      color: AuroraColors.blue,
                      title: AppLocaleText.tr(
                        context,
                        en: 'Want connection',
                        zhHans: '想连接',
                        zhHant: '想連結',
                        ja: 'つながりたい',
                      ),
                      onTap: () =>
                          Navigator.of(dialogContext).pop('connection'),
                    ),
                    _QuickMoodOption(
                      emoji: '🌙',
                      color: AuroraColors.purple,
                      title: AppLocaleText.tr(
                        context,
                        en: 'Need quiet',
                        zhHans: '想独处',
                        zhHant: '想獨處',
                        ja: '静かにしたい',
                      ),
                      onTap: () => Navigator.of(dialogContext).pop('quiet'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (choice == null) return;
    await vm.submitQuickStatus(choice: choice, language: language);
  }

  Future<void> _openScheduleSignalForm(
    BuildContext context,
    TodayViewModel vm, {
    ScheduleSignalModel? schedule,
  }) async {
    final result = await showModalBottomSheet<_ScheduleFormResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ScheduleFormSheet(schedule: schedule),
    );
    if (result == null) return;
    if (result.delete && schedule != null) {
      await vm.deleteSchedule(schedule);
      return;
    }
    if (schedule == null) {
      await vm.createSchedule(
        title: result.title,
        date: result.date,
        time: result.startTime,
        endTime: result.endTime,
        scene: result.scene,
        note: result.note,
        expectedEnergyLoad: result.expectedEnergyLoad,
        reminderEnabled: result.reminderEnabled,
      );
    } else {
      await vm.updateSchedule(
        schedule: schedule,
        title: result.title,
        date: result.date,
        time: result.startTime,
        endTime: result.endTime,
        scene: result.scene,
        note: result.note,
        expectedEnergyLoad: result.expectedEnergyLoad,
        reminderEnabled: result.reminderEnabled,
      );
    }
  }

  Future<void> _openScheduleFeelingForm(
    BuildContext context,
    TodayViewModel vm,
    ScheduleSignalModel schedule,
  ) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          AppLocaleText.tr(
            context,
            en: 'How did this schedule feel?',
            zhHans: '这个安排之后感觉如何？',
            zhHant: '這個安排之後感覺如何？',
            ja: 'この予定のあと、どう感じましたか？',
          ),
        ),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 5,
          autofocus: true,
          decoration: InputDecoration(
            hintText: AppLocaleText.tr(
              context,
              en: 'One sentence is enough...',
              zhHans: '一句话就够……',
              zhHant: '一句話就夠……',
              ja: '一文だけで大丈夫…',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(AppLocaleText.tr(
              context,
              en: 'Later',
              zhHans: '稍后',
              zhHant: '稍後',
              ja: 'あとで',
            )),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(AppLocaleText.tr(
              context,
              en: 'Save feeling',
              zhHans: '保存感受',
              zhHant: '保存感受',
              ja: '感覚を保存',
            )),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.trim().isEmpty) return;
    await vm.recordScheduleFeeling(schedule: schedule, feelingText: result);
  }

  Future<void> _openGoalForm(BuildContext context, TodayViewModel vm) async {
    final titleController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocaleText.tr(
          context,
          en: 'Goal experiment',
          zhHans: '目标实验',
          zhHant: '目標實驗',
          ja: '目標の小さな試み',
        )),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: AppLocaleText.tr(
              context,
              en: 'Example: restore after work, write, exercise...',
              zhHans: '例如：下班后恢复、写作、运动……',
              zhHant: '例如：下班後恢復、寫作、運動……',
              ja: '例：仕事後の回復、書く、運動する…',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(AppLocaleText.tr(
              context,
              en: 'Cancel',
              zhHans: '取消',
              zhHant: '取消',
              ja: 'キャンセル',
            )),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(titleController.text.trim()),
            child: Text(AppLocaleText.tr(
              context,
              en: 'Create',
              zhHans: '创建',
              zhHant: '建立',
              ja: '作成',
            )),
          ),
        ],
      ),
    );
    titleController.dispose();
    if (result == null || result.trim().isEmpty) return;
    await vm.createGoal(title: result);
  }

  List<RecentSignalModel> _todayOnlySignals(List<RecentSignalModel> all) {
    final now = DateTime.now();
    final todayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return all.where((signal) => signal.localDateKey() == todayKey).toList()
      ..sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
  }

  String _resolveObservationText(
    BuildContext context,
    TodayState state,
    List<RecentSignalModel> todaySignals,
  ) {
    if (todaySignals.length == 1) {
      final single = todaySignals.first;
      if (_hasText(single.observation)) return single.observation!;
      if (_hasText(state.insight?.text)) return state.insight!.text;
      return _fallbackObservation(context, todaySignals);
    }

    if (_hasText(state.insight?.text)) return state.insight!.text;

    for (final signal in todaySignals) {
      if (_hasText(signal.observation)) return signal.observation!;
    }

    return _fallbackObservation(context, todaySignals);
  }

  String _resolveTryNextText(
    BuildContext context,
    TodayState state,
    List<RecentSignalModel> todaySignals,
  ) {
    if (todaySignals.length == 1) {
      final single = todaySignals.first;
      if (_hasText(single.tryNext)) return single.tryNext!;
      if (_hasText(state.bestAction?.text)) return state.bestAction!.text;
      return _fallbackSuggestion(context, todaySignals);
    }

    if (_hasText(state.bestAction?.text)) return state.bestAction!.text;

    for (final signal in todaySignals) {
      if (_hasText(signal.tryNext)) return signal.tryNext!;
    }

    return _fallbackSuggestion(context, todaySignals);
  }

  bool _hasText(String? value) {
    return value != null && value.trim().isNotEmpty;
  }

  String _todayTitle(BuildContext context) {
    return AppLocaleText.tr(
      context,
      en: 'Today',
      zhHans: '今天',
      zhHant: '今天',
      ja: '今日',
    );
  }

  String _todayHeaderTitle(BuildContext context) {
    return AppLocaleText.tr(
      context,
      en: 'Signal Feed',
      zhHans: 'Signal Feed',
      zhHant: 'Signal Feed',
      ja: 'Signal Feed',
    );
  }

  String _preferenceText(BuildContext context, String? value) {
    final focusLabel = _focusAreaLabel(context, value);
    return AppLocaleText.tr(
      context,
      en: 'Focus this week: $focusLabel',
      zhHans: '本周关注：$focusLabel',
      zhHant: '本週關注：$focusLabel',
      ja: '今週の注目：$focusLabel',
    );
  }

  String _focusAreaLabel(BuildContext context, String? value) {
    switch (value) {
      case 'work_tasks':
        return AppLocaleText.tr(context,
            en: 'work and tasks',
            zhHans: '工作与任务',
            zhHant: '工作與任務',
            ja: '仕事とタスク');
      case 'emotion_stress':
        return AppLocaleText.tr(context,
            en: 'emotions and stress',
            zhHans: '情绪与压力',
            zhHant: '情緒與壓力',
            ja: '感情とストレス');
      case 'relationships':
        return AppLocaleText.tr(context,
            en: 'relationships and interaction',
            zhHans: '关系与相处',
            zhHant: '關係與相處',
            ja: '人間関係と付き合い方');
      case 'time_rhythm':
        return AppLocaleText.tr(context,
            en: 'time and daily rhythm',
            zhHans: '时间与生活节奏',
            zhHant: '時間與生活節奏',
            ja: '時間と生活リズム');
      case 'health_body':
        return AppLocaleText.tr(context,
            en: 'health and physical state',
            zhHans: '健康与身体状态',
            zhHant: '健康與身體狀態',
            ja: '健康と身体の状態');
      case 'money_spending':
        return AppLocaleText.tr(context,
            en: 'money and spending',
            zhHans: '金钱与消费',
            zhHant: '金錢與消費',
            ja: 'お金と消費');
      case 'learning_growth_expression':
        return AppLocaleText.tr(context,
            en: 'learning, growth, and expression',
            zhHans: '学习、成长与表达',
            zhHant: '學習、成長與表達',
            ja: '学び・成長・表現');
      case 'open':
        return AppLocaleText.tr(context,
            en: 'whatever comes up',
            zhHans: '想到什么记什么',
            zhHant: '想到什麼記什麼',
            ja: '思いついたことから記録する');
      default:
        return AppLocaleText.tr(context,
            en: 'not set yet', zhHans: '暂未设置', zhHant: '暫未設定', ja: '未設定');
    }
  }

  String _emptyTitleText(BuildContext context) {
    return AppLocaleText.tr(
      context,
      en: 'No entries yet today',
      zhHans: '今天还没有记录',
      zhHant: '今天還沒有記錄',
      ja: '今日はまだ記録がありません',
    );
  }

  String _emptySubtitleText(BuildContext context) {
    return AppLocaleText.tr(
      context,
      en: 'No need to organize or classify. Just note one small thing first, and I’ll look at it with you.',
      zhHans: '不用整理，也不用分类。先记下一件小事，我会陪你一起看。',
      zhHant: '不用整理，也不用分類。先記下一件小事，我會陪你一起看。',
      ja: '整理しなくても、分類しなくても大丈夫。まずは小さなことを一つ記してみて。一緒に見ていこう。',
    );
  }

  String _todayRecordsTitle(BuildContext context) {
    return AppLocaleText.tr(
      context,
      en: 'Signal inbox',
      zhHans: '今日信号箱',
      zhHant: '今日信號箱',
      ja: '今日のシグナル',
    );
  }

  String _todayRecordsSubtitle(BuildContext context) {
    return AppLocaleText.tr(
      context,
      en: 'Things saved today, using your local date',
      zhHans: '按你的本地日期，先放下今天发生的事',
      zhHant: '按你的本地日期，先放下今天發生的事',
      ja: 'あなたのローカル日付で、今日のことを置いておく場所です',
    );
  }

  String _todayDateText(BuildContext context) {
    final now = DateTime.now();
    final languageCode =
        Localizations.localeOf(context).languageCode.toLowerCase();

    switch (languageCode) {
      case 'ja':
      case 'zh':
        return '${now.year}年${now.month}月${now.day}日';
      default:
        return '${_monthShort(now.month)} ${now.day}, ${now.year}';
    }
  }

  String _monthShort(int month) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month.clamp(1, 12)];
  }

  String _buildTodaySummary(
    BuildContext context,
    List<RecentSignalModel> signals,
    bool isInitialLoading,
  ) {
    if (isInitialLoading) {
      return AppLocaleText.tr(
        context,
        en: 'Looking through today’s entries...',
        zhHans: '正在整理今天的记录……',
        zhHant: '正在整理今天的記錄……',
        ja: '今日の記録を整理しています……',
      );
    }

    if (signals.isEmpty) {
      return AppLocaleText.tr(
        context,
        en: 'Leave one real thing from today first.',
        zhHans: '先留下一件今天真实发生的小事。',
        zhHant: '先留下一件今天真實發生的小事。',
        ja: 'まずは今日、本当にあった小さなことを一つ残してみて。',
      );
    }

    if (signals.length == 1) {
      return AppLocaleText.tr(
        context,
        en: '1 entry today. The first signal from today is starting to show.',
        zhHans: '今天记录了 1 条，今天的第一条线索已经开始出现。',
        zhHant: '今天記錄了 1 條，今天的第一條線索已經開始出現。',
        ja: '今日は 1 件記録しました。今日の最初の手がかりが少し見え始めています。',
      );
    }

    return AppLocaleText.tr(
      context,
      en: '${signals.length} entries today. Today’s signals are starting to gather into a small shape.',
      zhHans: '今天记录了 ${signals.length} 条，今天的几条线索已经开始慢慢聚成一点轮廓。',
      zhHant: '今天記錄了 ${signals.length} 條，今天的幾條線索已經開始慢慢聚成一點輪廓。',
      ja: '今日は ${signals.length} 件記録しました。今日の手がかりが少しずつ小さな輪郭を持ち始めています。',
    );
  }

  String _fallbackObservation(
      BuildContext context, List<RecentSignalModel> signals) {
    if (signals.isEmpty) {
      return AppLocaleText.tr(
        context,
        en: 'No entries yet today. Start with one small real thing.',
        zhHans: '今天还没有记录，先留下一件真实发生的小事就好。',
        zhHant: '今天還沒有記錄，先留下一件真實發生的小事就好。',
        ja: '今日はまだ記録がありません。まずは本当にあった小さなことを一つ残してみて。',
      );
    }
    if (signals.length == 1) {
      return AppLocaleText.tr(
        context,
        en: 'You’ve started to leave a real trace from today.',
        zhHans: '你已经开始把今天里真实发生的事留了下来。',
        zhHant: '你已經開始把今天裡真實發生的事留了下來。',
        ja: '今日の中で実際に起きたことを、ちゃんと残し始めています。',
      );
    }
    return AppLocaleText.tr(
      context,
      en: 'Today’s signals are starting to gather into a small shape.',
      zhHans: '今天的线索已经开始慢慢聚成一点轮廓。',
      zhHant: '今天的線索已經開始慢慢聚成一點輪廓。',
      ja: '今日の手がかりが少しずつ小さな輪郭を持ち始めています。',
    );
  }

  String _fallbackSuggestion(
      BuildContext context, List<RecentSignalModel> signals) {
    if (signals.isEmpty) {
      return AppLocaleText.tr(
        context,
        en: 'Just note one moment that made you pause today.',
        zhHans: '今天先记下一件让你停顿了一下的小事就好。',
        zhHant: '今天先記下一件讓你停頓了一下的小事就好。',
        ja: '今日は、少し立ち止まった瞬間を一つだけ残してみて。',
      );
    }
    if (signals.length == 1) {
      return AppLocaleText.tr(
        context,
        en: 'If something similar happens again today, add one more line.',
        zhHans: '如果同类事情今天再出现一次，再补记一条就可以。',
        zhHant: '如果同類事情今天再出現一次，再補記一條就可以。',
        ja: '同じようなことが今日もう一度起きたら、一行だけ追記してみて。',
      );
    }
    return AppLocaleText.tr(
      context,
      en: 'Notice whether any kind of moment has already repeated today.',
      zhHans: '接下来先留意：今天有没有哪类事情已经不是第一次这样发生。',
      zhHant: '接下來先留意：今天有沒有哪類事情已經不是第一次這樣發生。',
      ja: 'これからは、今日の中でもう繰り返していることがないかだけ見てみて。',
    );
  }

  String _displayErrorText(BuildContext context, String? errorMessage) {
    if (errorMessage == null || errorMessage.trim().isEmpty) {
      return AppLocaleText.tr(
        context,
        en: 'Something went wrong.',
        zhHans: '发生了一点问题。',
        zhHant: '發生了一點問題。',
        ja: '少し問題が発生しました。',
      );
    }

    if (errorMessage == 'empty_input') {
      return AppLocaleText.tr(
        context,
        en: 'Write one small thing first.',
        zhHans: '先写下一件小事。',
        zhHant: '先寫下一件小事。',
        ja: 'まずは小さなことを一つ書いてみて。',
      );
    }

    return errorMessage;
  }
}

Future<String?> _askForShortText(
  BuildContext context, {
  required String title,
  required String hint,
}) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          minLines: 1,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (_) {
            Navigator.of(dialogContext).pop(controller.text.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              AppLocaleText.tr(
                context,
                en: 'Cancel',
                zhHans: '取消',
                zhHant: '取消',
                ja: 'キャンセル',
              ),
            ),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(
              AppLocaleText.tr(
                context,
                en: 'Save',
                zhHans: '保存',
                zhHant: '儲存',
                ja: '保存',
              ),
            ),
          ),
        ],
      );
    },
  );
  controller.dispose();
  return result;
}

class _TodayOverviewCard extends StatelessWidget {
  final List<RecentSignalModel> signals;

  const _TodayOverviewCard({required this.signals});

  @override
  Widget build(BuildContext context) {
    final draining = signals.where((s) => s.energyLoad == 'draining').length;
    final restoring = signals.where((s) => s.energyLoad == 'restoring').length;
    final friction = signals.where((s) {
      return (s.friction ?? '').trim().isNotEmpty ||
          s.energyLoad == 'draining' ||
          s.energyLoad == 'mixed';
    }).length;
    return AuroraCard(
      padding: const EdgeInsets.fromLTRB(15, 12, 15, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Today overview',
                    zhHans: '今日概览',
                    zhHant: '今日概覽',
                    ja: '今日の概要',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _StatusMetricTile(
                  icon: Icons.battery_saver_rounded,
                  label: AppLocaleText.tr(
                    context,
                    en: 'Energy',
                    zhHans: '能量',
                    zhHant: '能量',
                    ja: 'エネルギー',
                  ),
                  value: draining > restoring || signals.isEmpty
                      ? AppLocaleText.tr(
                          context,
                          en: 'Low',
                          zhHans: '偏低',
                          zhHant: '偏低',
                          ja: '低め',
                        )
                      : AppLocaleText.tr(
                          context,
                          en: 'Stable',
                          zhHans: '平稳',
                          zhHant: '平穩',
                          ja: '安定',
                        ),
                  color: AuroraColors.mint,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _StatusMetricTile(
                  icon: Icons.monitor_heart_outlined,
                  label: AppLocaleText.tr(
                    context,
                    en: 'Friction',
                    zhHans: '摩擦',
                    zhHant: '摩擦',
                    ja: '摩擦',
                  ),
                  value: friction > 1 || signals.isEmpty
                      ? AppLocaleText.tr(
                          context,
                          en: 'High',
                          zhHans: '偏高',
                          zhHant: '偏高',
                          ja: '高め',
                        )
                      : AppLocaleText.tr(
                          context,
                          en: 'Light',
                          zhHans: '较轻',
                          zhHant: '較輕',
                          ja: '軽め',
                        ),
                  color: AuroraColors.orange,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _StatusMetricTile(
                  icon: Icons.nights_stay_outlined,
                  label: AppLocaleText.tr(
                    context,
                    en: 'Recovery',
                    zhHans: '恢复',
                    zhHant: '恢復',
                    ja: '回復',
                  ),
                  value: restoring > 0
                      ? AppLocaleText.tr(
                          context,
                          en: 'Seen',
                          zhHans: '有线索',
                          zhHant: '有線索',
                          ja: 'あり',
                        )
                      : AppLocaleText.tr(
                          context,
                          en: 'Low',
                          zhHans: '不足',
                          zhHant: '不足',
                          ja: '少なめ',
                        ),
                  color: AuroraColors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusMetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatusMetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AuroraSoftIconCircle(
                icon: icon,
                color: color,
                size: 36,
                iconSize: 19,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AuroraColors.ink,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _TinySparkline extends StatelessWidget {
  final Color color;
  final List<double> values;

  const _TinySparkline({
    required this.color,
    required this.values,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 15,
      child: CustomPaint(painter: _TinySparklinePainter(color, values)),
    );
  }
}

class _TinySparklinePainter extends CustomPainter {
  final Color color;
  final List<double> values;

  _TinySparklinePainter(this.color, this.values);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final point = Offset(
        i / (values.length - 1) * size.width,
        values[i].clamp(0.0, 1.0) * size.height,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.82)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 1.7,
    );
  }

  @override
  bool shouldRepaint(covariant _TinySparklinePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.values != values;
  }
}

class _TodayInsightCard extends StatelessWidget {
  final String text;

  const _TodayInsightCard({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AuroraCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFFF2F0FF).withValues(alpha: 0.92),
          const Color(0xFFFFFBF5).withValues(alpha: 0.90),
          const Color(0xFFF7FBFF).withValues(alpha: 0.92),
        ],
      ),
      child: Row(
        children: [
          const AuroraLandscapeMedallion(size: 50),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '“',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: AuroraColors.purple.withValues(alpha: 0.26),
                    fontWeight: FontWeight.w800,
                    height: 0.9,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    text,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AuroraColors.ink,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                      fontSize: 15.5,
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

class _AiJudgementPanel extends StatelessWidget {
  final AiJudgementModel? judgement;
  final MicroActionModel? microAction;
  final bool isBusy;
  final ValueChanged<AiJudgementModel> onConfirm;
  final ValueChanged<AiJudgementModel> onInaccurate;
  final ValueChanged<AiJudgementModel> onAdjust;
  final ValueChanged<AiJudgementModel> onSupplement;
  final void Function(MicroActionModel action, String choice)
      onMicroActionChoice;
  final void Function(MicroActionModel action, String feedback) onFeedback;

  const _AiJudgementPanel({
    required this.judgement,
    required this.microAction,
    required this.isBusy,
    required this.onConfirm,
    required this.onInaccurate,
    required this.onAdjust,
    required this.onSupplement,
    required this.onMicroActionChoice,
    required this.onFeedback,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AuroraCard(
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AuroraColors.purple),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'AI judgement',
                    zhHans: 'AI 判断',
                    zhHant: 'AI 判斷',
                    ja: 'AI 判断',
                  ),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AuroraColors.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            AppLocaleText.tr(
              context,
              en: 'Confirm whether it fits, then decide whether to try one small action.',
              zhHans: '先确认准不准，再决定要不要试一个小行动。',
              zhHant: '先確認準不準，再決定要不要試一個小行動。',
              ja: '合っているか確認してから、小さな行動を試すか決めます。',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: AuroraColors.muted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          if (judgement == null)
            _AiJudgementEmptyState()
          else
            _AiJudgementContent(
              judgement: judgement!,
              microAction: microAction,
              isBusy: isBusy,
              onConfirm: onConfirm,
              onInaccurate: onInaccurate,
              onAdjust: onAdjust,
              onSupplement: onSupplement,
              onMicroActionChoice: onMicroActionChoice,
              onFeedback: onFeedback,
            ),
        ],
      ),
    );
  }
}

class _AiJudgementEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.86)),
      ),
      child: Row(
        children: [
          const AuroraSoftIconCircle(
            icon: Icons.auto_awesome,
            color: AuroraColors.purple,
            size: 42,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AppLocaleText.tr(
                context,
                en: 'After you leave a few signals, I will help find one confirmable clue.',
                zhHans: '留下几条信号后，我会帮你找一个可确认的线索。',
                zhHant: '留下幾條信號後，我會幫你找一個可確認的線索。',
                ja: 'いくつかシグナルを残すと、確認できる手がかりを一つ探します。',
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AuroraColors.muted,
                    height: 1.35,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiJudgementContent extends StatelessWidget {
  final AiJudgementModel judgement;
  final MicroActionModel? microAction;
  final bool isBusy;
  final ValueChanged<AiJudgementModel> onConfirm;
  final ValueChanged<AiJudgementModel> onInaccurate;
  final ValueChanged<AiJudgementModel> onAdjust;
  final ValueChanged<AiJudgementModel> onSupplement;
  final void Function(MicroActionModel action, String choice)
      onMicroActionChoice;
  final void Function(MicroActionModel action, String feedback) onFeedback;

  const _AiJudgementContent({
    required this.judgement,
    required this.microAction,
    required this.isBusy,
    required this.onConfirm,
    required this.onInaccurate,
    required this.onAdjust,
    required this.onSupplement,
    required this.onMicroActionChoice,
    required this.onFeedback,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AuroraColors.purple.withValues(alpha: 0.10),
                Colors.white.withValues(alpha: 0.72),
                AuroraColors.blue.withValues(alpha: 0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: AuroraColors.purple.withValues(alpha: 0.10)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AuroraSoftIconCircle(
                    icon: Icons.psychology_alt_outlined,
                    color: AuroraColors.purple,
                    size: 38,
                    iconSize: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          judgement.judgementText,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: AuroraColors.ink,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                        if (judgement.evidenceText.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            judgement.evidenceText,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AuroraColors.muted,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (judgement.suggestedPattern.trim().isNotEmpty ||
                  judgement.suggestedLifeChainStage.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (judgement.suggestedPattern.trim().isNotEmpty)
                      _AiJudgementTag(
                        label: judgement.suggestedPattern.trim(),
                        color: AuroraColors.purple,
                      ),
                    if (judgement.suggestedLifeChainStage.trim().isNotEmpty)
                      _AiJudgementTag(
                        label: judgement.suggestedLifeChainStage.trim(),
                        color: AuroraColors.blue,
                      ),
                    _AiJudgementTag(
                      label:
                          _confidenceLabel(context, judgement.confidenceLevel),
                      color: AuroraColors.mint,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (judgement.isPending)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _AiJudgementActionButton(
                label: AppLocaleText.tr(
                  context,
                  en: 'Fits',
                  zhHans: '准',
                  zhHant: '準',
                  ja: '合ってる',
                ),
                icon: Icons.check_circle_outline,
                isPrimary: true,
                onPressed: isBusy ? null : () => onConfirm(judgement),
              ),
              _AiJudgementActionButton(
                label: AppLocaleText.tr(
                  context,
                  en: 'Not quite',
                  zhHans: '不准',
                  zhHant: '不準',
                  ja: '少し違う',
                ),
                icon: Icons.remove_circle_outline,
                onPressed: isBusy ? null : () => onInaccurate(judgement),
              ),
              _AiJudgementActionButton(
                label: AppLocaleText.tr(
                  context,
                  en: 'Adjust',
                  zhHans: '调整一下',
                  zhHant: '調整一下',
                  ja: '調整する',
                ),
                icon: Icons.tune,
                onPressed: isBusy ? null : () => onAdjust(judgement),
              ),
              _AiJudgementActionButton(
                label: AppLocaleText.tr(
                  context,
                  en: 'Add a line',
                  zhHans: '补一句',
                  zhHant: '補一句',
                  ja: '一言足す',
                ),
                icon: Icons.add_comment_outlined,
                onPressed: isBusy ? null : () => onSupplement(judgement),
              ),
            ],
          )
        else if (judgement.isInaccurate)
          _AiJudgementNotice(
            text: AppLocaleText.tr(
              context,
              en: 'This judgement will not be used in Weekly or Journey.',
              zhHans: '这条判断不会进入本周或旅程分析。',
              zhHant: '這條判斷不會進入本週或旅程分析。',
              ja: 'この判断はWeeklyやJourneyの分析には使いません。',
            ),
          )
        else
          _AiJudgementNotice(
            text: AppLocaleText.tr(
              context,
              en: 'Confirmed. It can now lead to one small action.',
              zhHans: '已确认，可以接成一个小行动。',
              zhHant: '已確認，可以接成一個小行動。',
              ja: '確認しました。一つの小さな行動につなげられます。',
            ),
          ),
        if (microAction != null) ...[
          const SizedBox(height: 12),
          _MicroActionCard(
            action: microAction!,
            isBusy: isBusy,
            onChoice: (choice) => onMicroActionChoice(microAction!, choice),
            onFeedback: (feedback) => onFeedback(microAction!, feedback),
          ),
        ],
      ],
    );
  }

  String _confidenceLabel(BuildContext context, String confidence) {
    switch (confidence) {
      case 'high':
        return AppLocaleText.tr(
          context,
          en: 'high confidence',
          zhHans: '较可信',
          zhHant: '較可信',
          ja: '信頼度高め',
        );
      case 'low':
        return AppLocaleText.tr(
          context,
          en: 'light clue',
          zhHans: '轻线索',
          zhHant: '輕線索',
          ja: '小さな手がかり',
        );
      default:
        return AppLocaleText.tr(
          context,
          en: 'medium confidence',
          zhHans: '中等可信',
          zhHant: '中等可信',
          ja: '中くらい',
        );
    }
  }
}

class _AiJudgementNotice extends StatelessWidget {
  final String text;

  const _AiJudgementNotice({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AuroraColors.purple.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AuroraColors.muted,
              height: 1.35,
            ),
      ),
    );
  }
}

class _MicroActionCard extends StatelessWidget {
  final MicroActionModel action;
  final bool isBusy;
  final ValueChanged<String> onChoice;
  final ValueChanged<String> onFeedback;

  const _MicroActionCard({
    required this.action,
    required this.isBusy,
    required this.onChoice,
    required this.onFeedback,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AuroraColors.purple.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AuroraSoftIconCircle(
                icon: Icons.science_outlined,
                color: AuroraColors.purple,
                size: 38,
                iconSize: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AuroraColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (action.reason.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        action.reason,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AuroraColors.muted,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _AiJudgementTag(
                label: _statusLabel(context, action.status),
                color: AuroraColors.purple,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MicroActionChoiceButton(
                label: AppLocaleText.tr(
                  context,
                  en: 'Try today',
                  zhHans: '今天试试',
                  zhHant: '今天試試',
                  ja: '今日試す',
                ),
                onPressed: isBusy ? null : () => onChoice('today_try'),
                isPrimary:
                    action.status == 'accepted' || action.status == 'suggested',
              ),
              _MicroActionChoiceButton(
                label: AppLocaleText.tr(
                  context,
                  en: 'Add to weekly',
                  zhHans: '加到本周实验',
                  zhHant: '加到本週實驗',
                  ja: '今週の実験へ',
                ),
                onPressed: isBusy ? null : () => onChoice('add_to_weekly'),
              ),
              _MicroActionChoiceButton(
                label: AppLocaleText.tr(
                  context,
                  en: 'Make lighter',
                  zhHans: '换轻一点',
                  zhHant: '換輕一點',
                  ja: '軽くする',
                ),
                onPressed: isBusy ? null : () => onChoice('lighter'),
              ),
              _MicroActionChoiceButton(
                label: AppLocaleText.tr(
                  context,
                  en: 'Not now',
                  zhHans: '暂时不做',
                  zhHant: '暫時不做',
                  ja: '今はしない',
                ),
                onPressed: isBusy ? null : () => onChoice('skip'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _FeedbackChip(
                label: AppLocaleText.tr(
                  context,
                  en: 'Happened',
                  zhHans: '发生了',
                  zhHant: '發生了',
                  ja: '起きた',
                ),
                selected: action.feedbackStatus == 'happened',
                onPressed: isBusy ? null : () => onFeedback('happened'),
              ),
              _FeedbackChip(
                label: AppLocaleText.tr(
                  context,
                  en: 'Did not happen',
                  zhHans: '没发生',
                  zhHant: '沒發生',
                  ja: '起きなかった',
                ),
                selected: action.feedbackStatus == 'not_happened',
                onPressed: isBusy ? null : () => onFeedback('not_happened'),
              ),
              _FeedbackChip(
                label: AppLocaleText.tr(
                  context,
                  en: 'Helpful',
                  zhHans: '有帮助',
                  zhHant: '有幫助',
                  ja: '助かった',
                ),
                selected: action.feedbackStatus == 'helpful',
                onPressed: isBusy ? null : () => onFeedback('helpful'),
              ),
              _FeedbackChip(
                label: AppLocaleText.tr(
                  context,
                  en: 'Too hard',
                  zhHans: '太难了',
                  zhHant: '太難了',
                  ja: '難しかった',
                ),
                selected: action.feedbackStatus == 'too_hard',
                onPressed: isBusy ? null : () => onFeedback('too_hard'),
              ),
              _FeedbackChip(
                label: AppLocaleText.tr(
                  context,
                  en: 'Add a line',
                  zhHans: '补一句',
                  zhHant: '補一句',
                  ja: '一言足す',
                ),
                selected: false,
                onPressed: isBusy ? null : () => onFeedback('note'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _statusLabel(BuildContext context, String status) {
    switch (status) {
      case 'accepted':
        return AppLocaleText.tr(
          context,
          en: 'trying today',
          zhHans: '今天试试',
          zhHant: '今天試試',
          ja: '今日試す',
        );
      case 'active':
        return AppLocaleText.tr(
          context,
          en: 'weekly experiment',
          zhHans: '本周实验',
          zhHant: '本週實驗',
          ja: '今週の実験',
        );
      case 'skipped':
        return AppLocaleText.tr(
          context,
          en: 'not now',
          zhHans: '暂不做',
          zhHant: '暫不做',
          ja: '今はしない',
        );
      case 'done':
        return AppLocaleText.tr(
          context,
          en: 'reviewed',
          zhHans: '已反馈',
          zhHant: '已回饋',
          ja: '振り返り済み',
        );
      case 'adjusted':
        return AppLocaleText.tr(
          context,
          en: 'lighter',
          zhHans: '已调轻',
          zhHant: '已調輕',
          ja: '軽く調整',
        );
      default:
        return AppLocaleText.tr(
          context,
          en: 'suggested',
          zhHans: '可尝试',
          zhHant: '可嘗試',
          ja: '試せる',
        );
    }
  }
}

class _AiJudgementTag extends StatelessWidget {
  final String label;
  final Color color;

  const _AiJudgementTag({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
      ),
    );
  }
}

class _AiJudgementActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback? onPressed;

  const _AiJudgementActionButton({
    required this.label,
    required this.icon,
    this.isPrimary = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = isPrimary ? Colors.white : AuroraColors.ink;
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 17, color: foreground),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: foreground,
        backgroundColor: isPrimary
            ? AuroraColors.purple
            : Colors.white.withValues(alpha: 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(
            color: isPrimary
                ? AuroraColors.purple
                : AuroraColors.line.withValues(alpha: 0.75),
          ),
        ),
        textStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _MicroActionChoiceButton extends StatelessWidget {
  final String label;
  final bool isPrimary;
  final VoidCallback? onPressed;

  const _MicroActionChoiceButton({
    required this.label,
    this.isPrimary = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: isPrimary ? Colors.white : AuroraColors.ink,
        backgroundColor: isPrimary
            ? AuroraColors.purple
            : Colors.white.withValues(alpha: 0.80),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(color: AuroraColors.line.withValues(alpha: 0.70)),
        ),
        textStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
      child: Text(label),
    );
  }
}

class _FeedbackChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  const _FeedbackChip({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onPressed,
      side: BorderSide(
        color: selected
            ? AuroraColors.purple.withValues(alpha: 0.42)
            : AuroraColors.line.withValues(alpha: 0.56),
      ),
      backgroundColor: selected
          ? AuroraColors.purple.withValues(alpha: 0.12)
          : Colors.white.withValues(alpha: 0.72),
      labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: selected ? AuroraColors.purple : AuroraColors.ink,
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _PredictedSignalStrip extends StatelessWidget {
  final List<RecentSignalModel> signals;
  final bool isGenerating;
  final Future<void> Function() onGenerate;
  final Future<void> Function(RecentSignalModel, String) onConfirm;

  const _PredictedSignalStrip({
    required this.signals,
    required this.isGenerating,
    required this.onGenerate,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final items = signals.take(3).toList();
    return AuroraCard(
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AuroraColors.purple),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'AI predicted signals',
                    zhHans: 'AI 预判信号',
                    zhHant: 'AI 預判信號',
                    ja: 'AI 予測シグナル',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            _PredictionEmptyState(
              isGenerating: isGenerating,
              onGenerate: onGenerate,
            )
          else
            Row(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  Expanded(
                    child: _PredictionMiniCard(
                      signal: items[i],
                      index: i,
                      onConfirm: onConfirm,
                    ),
                  ),
                  if (i != items.length - 1) const SizedBox(width: 10),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _PredictionEmptyState extends StatelessWidget {
  final bool isGenerating;
  final Future<void> Function() onGenerate;

  const _PredictionEmptyState({
    required this.isGenerating,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.86)),
      ),
      child: Row(
        children: [
          const AuroraSoftIconCircle(
            icon: Icons.auto_awesome_rounded,
            color: AuroraColors.purple,
            size: 42,
            iconSize: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AppLocaleText.tr(
                context,
                en: 'Generate one small predicted signal from today’s notes.',
                zhHans: '根据今天的记录，生成一个可确认的预判信号。',
                zhHant: '根據今天的記錄，生成一個可確認的預判信號。',
                ja: '今日の記録から、確認できる予測シグナルを一つ作ります。',
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AuroraColors.muted,
                    height: 1.35,
                  ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            key: const ValueKey('today-predict-action'),
            onPressed: isGenerating ? null : onGenerate,
            style: FilledButton.styleFrom(
              backgroundColor: AuroraColors.purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Text(
              isGenerating
                  ? AppLocaleText.tr(
                      context,
                      en: 'Predicting',
                      zhHans: '预判中',
                      zhHant: '預判中',
                      ja: '予測中',
                    )
                  : AppLocaleText.tr(
                      context,
                      en: 'Predict',
                      zhHans: '预判',
                      zhHant: '預判',
                      ja: '予測',
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PredictionMiniCard extends StatelessWidget {
  final RecentSignalModel signal;
  final int index;
  final Future<void> Function(RecentSignalModel, String) onConfirm;

  const _PredictionMiniCard({
    required this.signal,
    required this.index,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final id = signal.signalCardId ?? signal.id ?? '';
    final palette = [
      (AuroraColors.purple, Icons.shuffle_rounded),
      (AuroraColors.blue, Icons.battery_charging_full_rounded),
      (AuroraColors.orange, Icons.groups_rounded),
    ];
    final color = palette[index % palette.length].$1;
    final icon = palette[index % palette.length].$2;
    return Container(
      constraints: const BoxConstraints(minHeight: 108),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.76),
            color.withValues(alpha: 0.035),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.86)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuroraSoftIconCircle(
            icon: icon,
            color: color,
            size: 38,
            iconSize: 19,
          ),
          const SizedBox(height: 8),
          Text(
            signal.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _TinyConfirmButton(
                  label: AppLocaleText.tr(
                    context,
                    en: 'Yes',
                    zhHans: '准',
                    zhHant: '準',
                    ja: '近い',
                  ),
                  onTap:
                      id.isEmpty ? null : () => onConfirm(signal, 'accurate'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _TinyConfirmButton(
                  label: AppLocaleText.tr(
                    context,
                    en: 'No',
                    zhHans: '不准',
                    zhHant: '不準',
                    ja: '違う',
                  ),
                  onTap:
                      id.isEmpty ? null : () => onConfirm(signal, 'inaccurate'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _TinyConfirmButton(
                  label: AppLocaleText.tr(
                    context,
                    en: '+',
                    zhHans: '补一句',
                    zhHant: '補一句',
                    ja: '補足',
                  ),
                  onTap: id.isEmpty
                      ? null
                      : () => onConfirm(signal, 'supplemented'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TinyConfirmButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _TinyConfirmButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 5),
        decoration: BoxDecoration(
          color: AuroraColors.mint.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF39785E),
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
          ),
        ),
      ),
    );
  }
}

class _CaptureInputCard extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSubmitting;
  final ValueChanged<String> onChanged;
  final VoidCallback onTextMode;
  final VoidCallback onVoiceDraft;
  final VoidCallback onQuickStatus;
  final VoidCallback onSchedule;
  final VoidCallback onPredict;

  const _CaptureInputCard({
    required this.controller,
    required this.focusNode,
    required this.isSubmitting,
    required this.onChanged,
    required this.onTextMode,
    required this.onVoiceDraft,
    required this.onQuickStatus,
    required this.onSchedule,
    required this.onPredict,
  });

  @override
  Widget build(BuildContext context) {
    return AuroraCard(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFFF4F0FF).withValues(alpha: 0.86),
          Colors.white.withValues(alpha: 0.94),
          const Color(0xFFFFFBF6).withValues(alpha: 0.90),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome,
                  color: AuroraColors.purple, size: 21),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Signal input',
                    zhHans: '信号输入',
                    zhHant: '信號輸入',
                    ja: 'シグナル入力',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AuroraColors.purple,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          TextField(
            controller: controller,
            focusNode: focusNode,
            minLines: 1,
            maxLines: 3,
            onChanged: onChanged,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.72),
              suffixIcon: Padding(
                padding: const EdgeInsetsDirectional.only(end: 6),
                child: _ComposerSaveIconButton(
                  isSubmitting: isSubmitting,
                  onPressed: onTextMode,
                ),
              ),
              suffixIconConstraints:
                  const BoxConstraints(minWidth: 48, minHeight: 48),
              hintText: AppLocaleText.tr(
                context,
                en: 'Leave one signal from today...',
                zhHans: '留下一点今天的信号…',
                zhHant: '留下一點今天的信號…',
                ja: '今日のシグナルを少し残す…',
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: AuroraColors.line),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: AuroraColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: AuroraColors.purple),
              ),
            ),
          ),
          const SizedBox(height: 9),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            clipBehavior: Clip.none,
            child: Row(
              children: [
                _ComposerModeButton(
                  onPressed: isSubmitting ? null : onTextMode,
                  icon: Icons.text_fields_rounded,
                  label: AppLocaleText.tr(
                    context,
                    en: 'Text',
                    zhHans: '文字',
                    zhHant: '文字',
                    ja: '文字',
                  ),
                ),
                const SizedBox(width: 8),
                _ComposerModeButton(
                  onPressed: isSubmitting ? null : onVoiceDraft,
                  icon: Icons.mic_none_rounded,
                  label: AppLocaleText.tr(
                    context,
                    en: 'Voice',
                    zhHans: '语音',
                    zhHant: '語音',
                    ja: '音声',
                  ),
                ),
                const SizedBox(width: 8),
                _ComposerModeButton(
                  key: const ValueKey('today-status-action'),
                  onPressed: isSubmitting ? null : onQuickStatus,
                  icon: Icons.mood_outlined,
                  label: AppLocaleText.tr(
                    context,
                    en: 'State',
                    zhHans: '状态',
                    zhHant: '狀態',
                    ja: '状態',
                  ),
                ),
                const SizedBox(width: 8),
                _ComposerModeButton(
                  key: const ValueKey('today-schedule-action'),
                  onPressed: isSubmitting ? null : onSchedule,
                  icon: Icons.event_note_outlined,
                  label: AppLocaleText.tr(
                    context,
                    en: 'Schedule',
                    zhHans: '安排',
                    zhHant: '安排',
                    ja: '予定',
                  ),
                ),
                const SizedBox(width: 8),
                _ComposerModeButton(
                  key: const ValueKey('today-ai-judgement-action'),
                  onPressed: isSubmitting ? null : onPredict,
                  icon: Icons.psychology_alt_outlined,
                  label: AppLocaleText.tr(
                    context,
                    en: 'Predict',
                    zhHans: '预判',
                    zhHant: '預判',
                    ja: '予測',
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

class _ComposerSaveIconButton extends StatelessWidget {
  final bool isSubmitting;
  final VoidCallback onPressed;

  const _ComposerSaveIconButton({
    required this.isSubmitting,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final label = isSubmitting
        ? AppLocaleText.tr(
            context,
            en: 'Saving',
            zhHans: '保存中',
            zhHant: '保存中',
            ja: '保存中',
          )
        : AppLocaleText.tr(
            context,
            en: 'Save signal',
            zhHans: '保存信号',
            zhHant: '保存信號',
            ja: 'シグナルを保存',
          );

    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isSubmitting ? null : onPressed,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isSubmitting
                      ? [
                          AuroraColors.purple.withValues(alpha: 0.30),
                          AuroraColors.purple.withValues(alpha: 0.18),
                        ]
                      : const [
                          Color(0xFF7D6BFF),
                          Color(0xFF6756E8),
                        ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AuroraColors.purple.withValues(alpha: 0.20),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ComposerModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _ComposerModeButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      child: AuroraPillButton(
        onPressed: onPressed,
        icon: icon,
        label: label,
      ),
    );
  }
}

class _QuickStatusOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final VoidCallback onTap;

  const _QuickStatusOption({
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.20)),
        ),
        child: Row(
          children: [
            AuroraSoftIconCircle(
              icon: icon,
              color: color,
              size: 38,
              iconSize: 19,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AuroraColors.ink,
                    ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AuroraColors.muted),
          ],
        ),
      ),
    );
  }
}

class _QuickMoodOption extends StatelessWidget {
  final String emoji;
  final Color color;
  final String title;
  final VoidCallback onTap;

  const _QuickMoodOption({
    required this.emoji,
    required this.color,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: (MediaQuery.sizeOf(context).width - 50) / 2,
      child: Material(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: color.withValues(alpha: 0.18)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.80),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.14),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 21),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AuroraColors.ink,
                          height: 1.15,
                        ),
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

class _DiaryTimelineSection extends StatelessWidget {
  final List<RecentSignalModel> signals;
  final int pendingDraftCount;
  final bool isSyncing;
  final String? syncMessage;
  final VoidCallback onOpenAllRecords;
  final void Function(RecentSignalModel signal) onOpenDialog;

  const _DiaryTimelineSection({
    required this.signals,
    required this.pendingDraftCount,
    required this.isSyncing,
    required this.syncMessage,
    required this.onOpenAllRecords,
    required this.onOpenDialog,
  });

  @override
  Widget build(BuildContext context) {
    final items = (signals.isEmpty
            ? _demoItems(context)
            : signals.take(4).map((signal) => _DiaryTimelineItem.fromSignal(
                  context,
                  signal,
                  onOpenDialog: () => onOpenDialog(signal),
                )))
        .toList();
    return AuroraCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Diary Timeline',
                    zhHans: '手帐时间线',
                    zhHant: '手帳時間線',
                    ja: '手帳タイムライン',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onOpenAllRecords,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppLocaleText.tr(
                          context,
                          en: 'All records',
                          zhHans: '全部记录',
                          zhHant: '全部記錄',
                          ja: 'すべて',
                        ),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AuroraColors.muted,
                            ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: AuroraColors.muted, size: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (pendingDraftCount > 0 || syncMessage != null) ...[
            const SizedBox(height: 14),
            _CompactSyncNotice(
              count: pendingDraftCount,
              isSyncing: isSyncing,
              message: syncMessage,
            ),
          ],
          const SizedBox(height: 14),
          Stack(
            children: [
              Positioned(
                left: 9,
                top: 10,
                bottom: 10,
                child: Container(
                  width: 1.4,
                  decoration: BoxDecoration(
                    color: AuroraColors.purple.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Column(
                children: [
                  for (final item in items) ...[
                    _TimelineRow(item: item),
                    if (item != items.last) const SizedBox(height: 12),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<_DiaryTimelineItem> _demoItems(BuildContext context) {
    return [
      _DiaryTimelineItem(
        time: '21:43',
        userText: AppLocaleText.tr(
          context,
          en: 'I did not want to reply to messages today.',
          zhHans: '今天不想回消息。',
          zhHant: '今天不想回訊息。',
          ja: '今日はメッセージを返したくなかった。',
        ),
        aiText: AppLocaleText.tr(
          context,
          en: 'This may be your boundary sense saying today has already taken enough.',
          zhHans: '这更像是你的边界感在提醒你今天已经耗得差不多了。',
          zhHant: '這更像是你的邊界感在提醒你今天已經耗得差不多了。',
          ja: 'これは、今日はもう十分消耗したと境界線が知らせているのかもしれません。',
        ),
        tags: [
          _DiaryTag(
              AppLocaleText.tr(context,
                  en: 'relationship', zhHans: '关系', zhHant: '關係', ja: '関係'),
              AuroraColors.purple),
          _DiaryTag(
              AppLocaleText.tr(context,
                  en: 'boundary', zhHans: '边界', zhHant: '邊界', ja: '境界'),
              AuroraColors.blue),
          _DiaryTag(
              AppLocaleText.tr(context,
                  en: 'low energy', zhHans: '低能量', zhHant: '低能量', ja: '低エネルギー'),
              AuroraColors.mint),
        ],
      ),
      _DiaryTimelineItem(
        time: '15:20',
        userText: AppLocaleText.tr(
          context,
          en: 'Meetings were dense and my mind never caught up.',
          zhHans: '会议太碎，脑子一直切不过来。',
          zhHant: '會議太碎，腦子一直切不過來。',
          ja: '会議が細かく続いて、頭が切り替わらなかった。',
        ),
        aiText: AppLocaleText.tr(
          context,
          en: 'You look more worn down by switching than by simple workload.',
          zhHans: '你现在更像是被高切换拖累，而不是单纯效率低。',
          zhHant: '你現在更像是被高切換拖累，而不是單純效率低。',
          ja: '単に効率が低いのではなく、切り替えの多さに削られているようです。',
        ),
        tags: [
          _DiaryTag(
              AppLocaleText.tr(context,
                  en: 'work', zhHans: '工作', zhHant: '工作', ja: '仕事'),
              AuroraColors.blue),
          _DiaryTag(
              AppLocaleText.tr(context,
                  en: 'switching', zhHans: '切换', zhHant: '切換', ja: '切替'),
              AuroraColors.purple),
          _DiaryTag(
              AppLocaleText.tr(context,
                  en: 'drain', zhHans: '消耗', zhHant: '消耗', ja: '消耗'),
              AuroraColors.orange),
        ],
      ),
      _DiaryTimelineItem(
        time: '09:07',
        userText: AppLocaleText.tr(
          context,
          en: 'I woke up tired and did not want to move.',
          zhHans: '早上起来就很累，不想动。',
          zhHant: '早上起來就很累，不想動。',
          ja: '朝起きた時点で疲れていて、動きたくなかった。',
        ),
        aiText: AppLocaleText.tr(
          context,
          en: 'Recovery may not be enough; the energy account is still catching up.',
          zhHans: '你的恢复可能不足，能量账户还没补上。',
          zhHant: '你的恢復可能不足，能量帳戶還沒補上。',
          ja: '回復がまだ足りず、エネルギーの残高が追いついていないのかもしれません。',
        ),
        tags: [
          _DiaryTag(
              AppLocaleText.tr(context,
                  en: 'energy', zhHans: '能量', zhHant: '能量', ja: 'エネルギー'),
              AuroraColors.mint),
          _DiaryTag(
              AppLocaleText.tr(context,
                  en: 'recovery', zhHans: '恢复', zhHant: '恢復', ja: '回復'),
              AuroraColors.blue),
          _DiaryTag(
              AppLocaleText.tr(context,
                  en: 'sleep', zhHans: '睡眠', zhHant: '睡眠', ja: '睡眠'),
              AuroraColors.purple),
        ],
      ),
    ];
  }
}

class _ScheduleFormResult {
  final String title;
  final DateTime? date;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? scene;
  final String? expectedEnergyLoad;
  final bool reminderEnabled;
  final String? note;
  final bool delete;

  const _ScheduleFormResult({
    required this.title,
    this.date,
    this.startTime,
    this.endTime,
    this.scene,
    this.expectedEnergyLoad,
    this.reminderEnabled = false,
    this.note,
  }) : delete = false;

  const _ScheduleFormResult.delete()
      : title = '',
        date = null,
        startTime = null,
        endTime = null,
        scene = null,
        expectedEnergyLoad = null,
        reminderEnabled = false,
        note = null,
        delete = true;
}

class _ScheduleFormSheet extends StatefulWidget {
  final ScheduleSignalModel? schedule;

  const _ScheduleFormSheet({this.schedule});

  @override
  State<_ScheduleFormSheet> createState() => _ScheduleFormSheetState();
}

class _ScheduleFormSheetState extends State<_ScheduleFormSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  DateTime? _date;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String? _scene;
  String? _load;
  bool _allDay = false;
  bool _reminderEnabled = false;
  String? _errorText;

  bool get _isEditing => widget.schedule != null;

  @override
  void initState() {
    super.initState();
    final schedule = widget.schedule;
    _titleController = TextEditingController(text: schedule?.title ?? '');
    _noteController = TextEditingController(text: schedule?.note ?? '');
    _scene = schedule?.scene;
    _load = schedule?.expectedEnergyLoad;
    _reminderEnabled = schedule?.reminderEnabled ?? false;
    final start = schedule?.startTime?.toLocal();
    final end = schedule?.endTime?.toLocal();
    if (schedule != null && schedule.datePrecision != 'none') {
      _date = start == null
          ? DateTime.tryParse(schedule.localDate ?? '')
          : DateTime(start.year, start.month, start.day);
    }
    if (start != null && schedule?.timePrecision == 'time') {
      _startTime = TimeOfDay.fromDateTime(start);
      _endTime = TimeOfDay.fromDateTime(
        end ?? start.add(const Duration(hours: 1)),
      );
    }
    _allDay = schedule != null &&
        schedule.datePrecision == 'date' &&
        schedule.timePrecision == 'none';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: bottom),
      child: FractionallySizedBox(
        heightFactor: bottom > 0 ? 0.98 : 0.94,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFDFDFF),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDADAE6),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 64,
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(AppLocaleText.tr(
                            context,
                            en: 'Cancel',
                            zhHans: '取消',
                            zhHant: '取消',
                            ja: 'キャンセル',
                          )),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          AppLocaleText.tr(
                            context,
                            en: _isEditing ? 'Edit schedule' : 'Add schedule',
                            zhHans: _isEditing ? '编辑安排' : '添加安排',
                            zhHant: _isEditing ? '編輯安排' : '新增安排',
                            ja: _isEditing ? '予定を編集' : '予定を追加',
                          ),
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AuroraColors.ink,
                                  ),
                        ),
                      ),
                      SizedBox(
                        width: 64,
                        child: TextButton(
                          onPressed: _save,
                          child: Text(AppLocaleText.tr(
                            context,
                            en: 'Save',
                            zhHans: '保存',
                            zhHant: '保存',
                            ja: '保存',
                          )),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    children: [
                      if (_isEditing)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => Navigator.of(context).pop(
                              const _ScheduleFormResult.delete(),
                            ),
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: Text(AppLocaleText.tr(
                              context,
                              en: 'Delete',
                              zhHans: '删除',
                              zhHant: '刪除',
                              ja: '削除',
                            )),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFE65353),
                            ),
                          ),
                        ),
                      _titleField(context),
                      const SizedBox(height: 10),
                      if (_errorText != null)
                        _SoftMessage(
                          icon: Icons.info_outline_rounded,
                          text: _errorText!,
                          color: AuroraColors.orange,
                        )
                      else
                        _SoftMessage(
                          icon: Icons.auto_awesome_rounded,
                          text: AppLocaleText.tr(
                            context,
                            en: _titleController.text.trim().isEmpty
                                ? 'A title is enough. You can add time and details later.'
                                : 'Saved as a gentle schedule signal. Details can be added later.',
                            zhHans: _titleController.text.trim().isEmpty
                                ? '只填标题也可以，其他信息可稍后补充。'
                                : '已准备保存为安排线索，时间与细节可以稍后补充。',
                            zhHant: _titleController.text.trim().isEmpty
                                ? '只填標題也可以，其他資訊可稍後補充。'
                                : '已準備保存為安排線索，時間與細節可以稍後補充。',
                            ja: _titleController.text.trim().isEmpty
                                ? 'タイトルだけでも保存できます。時間や詳細はあとで足せます。'
                                : '予定シグナルとして保存できます。詳細はあとで足せます。',
                          ),
                          color: AuroraColors.purple,
                        ),
                      const SizedBox(height: 20),
                      _SectionLabel(
                        icon: Icons.calendar_today_outlined,
                        title: AppLocaleText.tr(
                          context,
                          en: 'Time',
                          zhHans: '时间',
                          zhHant: '時間',
                          ja: '時間',
                        ),
                      ),
                      const SizedBox(height: 8),
                      _timeCard(context),
                      const SizedBox(height: 20),
                      _SectionLabel(
                        icon: Icons.category_outlined,
                        title: AppLocaleText.tr(
                          context,
                          en: 'Type',
                          zhHans: '类型',
                          zhHant: '類型',
                          ja: '種類',
                        ),
                        optional: true,
                      ),
                      const SizedBox(height: 8),
                      _horizontalChoices(_sceneChoices(context), _scene,
                          (value) {
                        FocusScope.of(context).unfocus();
                        setState(() => _scene = value);
                      }),
                      const SizedBox(height: 20),
                      _SectionLabel(
                        icon: Icons.monitor_heart_outlined,
                        title: AppLocaleText.tr(
                          context,
                          en: 'Expected load',
                          zhHans: '预期负荷',
                          zhHant: '預期負荷',
                          ja: '予想される負荷',
                        ),
                        optional: true,
                      ),
                      const SizedBox(height: 8),
                      _horizontalChoices(_loadChoices(context), _load, (value) {
                        FocusScope.of(context).unfocus();
                        setState(() => _load = value);
                      }),
                      const SizedBox(height: 20),
                      _SectionLabel(
                        icon: Icons.notifications_none_rounded,
                        title: AppLocaleText.tr(
                          context,
                          en: 'Reminder',
                          zhHans: '是否提醒',
                          zhHant: '是否提醒',
                          ja: 'リマインダー',
                        ),
                        optional: true,
                      ),
                      const SizedBox(height: 8),
                      _reminderCard(context),
                      const SizedBox(height: 20),
                      _SectionLabel(
                        icon: Icons.note_alt_outlined,
                        title: AppLocaleText.tr(
                          context,
                          en: 'Note',
                          zhHans: '备注',
                          zhHant: '備註',
                          ja: 'メモ',
                        ),
                        optional: true,
                      ),
                      const SizedBox(height: 8),
                      _noteField(context),
                      const SizedBox(height: 14),
                      _SoftMessage(
                        icon: Icons.lightbulb_outline_rounded,
                        text: AppLocaleText.tr(
                          context,
                          en: 'Schedules help you notice energy rhythm. They are not a task list and can be changed or deleted anytime.',
                          zhHans: '安排是为了帮助你更好地安排精力，不是任务清单，可以随时修改或删除。',
                          zhHant: '安排是為了幫助你更好地安排精力，不是任務清單，可以隨時修改或刪除。',
                          ja: '予定はエネルギーの流れを見るためのものです。タスクリストではなく、いつでも変更できます。',
                        ),
                        color: AuroraColors.purple,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _titleField(BuildContext context) {
    return TextField(
      key: const Key('schedule-title-field'),
      controller: _titleController,
      autofocus: !_isEditing,
      maxLines: 1,
      onChanged: (_) => setState(() => _errorText = null),
      decoration: InputDecoration(
        labelText: AppLocaleText.tr(
          context,
          en: 'Schedule title',
          zhHans: '安排标题',
          zhHant: '安排標題',
          ja: '予定タイトル',
        ),
        hintText: AppLocaleText.tr(
          context,
          en: 'Project meeting',
          zhHans: '项目会议',
          zhHant: '專案會議',
          ja: 'プロジェクト会議',
        ),
        suffixIcon: _titleController.text.isEmpty
            ? null
            : IconButton(
                onPressed: () => setState(() => _titleController.clear()),
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.74),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AuroraColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AuroraColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AuroraColors.purple, width: 1.4),
        ),
      ),
    );
  }

  Widget _timeCard(BuildContext context) {
    return _GroupedCard(
      children: [
        _ScheduleRow(
          title: AppLocaleText.tr(
            context,
            en: 'All day',
            zhHans: '全天',
            zhHant: '全天',
            ja: '終日',
          ),
          trailing: Switch.adaptive(
            value: _allDay,
            activeThumbColor: AuroraColors.purple,
            onChanged: (value) {
              setState(() {
                _allDay = value;
                if (value) {
                  _startTime = null;
                  _endTime = null;
                  _reminderEnabled = false;
                  _date ??= DateTime.now();
                }
              });
            },
          ),
        ),
        _ScheduleRow(
          title: AppLocaleText.tr(
            context,
            en: 'Date',
            zhHans: '日期',
            zhHant: '日期',
            ja: '日付',
          ),
          value: _date == null
              ? AppLocaleText.tr(
                  context,
                  en: 'Not set',
                  zhHans: '暂未设置',
                  zhHant: '暫未設定',
                  ja: '未設定',
                )
              : _dateLabel(context, _date!),
          onTap: _pickDate,
        ),
        if (!_allDay) ...[
          _ScheduleRow(
            title: AppLocaleText.tr(
              context,
              en: 'Start time',
              zhHans: '开始时间',
              zhHant: '開始時間',
              ja: '開始時間',
            ),
            value: _startTime == null
                ? AppLocaleText.tr(
                    context,
                    en: 'Not set',
                    zhHans: '暂未设置',
                    zhHant: '暫未設定',
                    ja: '未設定',
                  )
                : _startTime!.format(context),
            onTap: () => _pickTime(isStart: true),
          ),
          _ScheduleRow(
            title: AppLocaleText.tr(
              context,
              en: 'End time',
              zhHans: '结束时间',
              zhHant: '結束時間',
              ja: '終了時間',
            ),
            value: _endTime == null
                ? AppLocaleText.tr(
                    context,
                    en: 'Not set',
                    zhHans: '暂未设置',
                    zhHant: '暫未設定',
                    ja: '未設定',
                  )
                : _endTime!.format(context),
            onTap: () => _pickTime(isStart: false),
          ),
        ],
      ],
    );
  }

  Widget _horizontalChoices(
    List<_ScheduleChoice> choices,
    String? selected,
    ValueChanged<String> onSelect,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (final choice in choices) ...[
            _ScheduleChoiceTile(
              choice: choice,
              selected: choice.value == selected,
              onTap: () => onSelect(choice.value),
            ),
            const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }

  Widget _reminderCard(BuildContext context) {
    return _GroupedCard(
      children: [
        _ScheduleRow(
          title: AppLocaleText.tr(
            context,
            en: 'Enable reminder',
            zhHans: '是否提醒',
            zhHant: '是否提醒',
            ja: 'リマインドする',
          ),
          trailing: Switch.adaptive(
            value: _reminderEnabled,
            activeThumbColor: AuroraColors.purple,
            onChanged: _startTime == null
                ? null
                : (value) => setState(() => _reminderEnabled = value),
          ),
        ),
        _ScheduleRow(
          title: AppLocaleText.tr(
            context,
            en: 'Reminder time',
            zhHans: '提前时间',
            zhHant: '提前時間',
            ja: '通知時間',
          ),
          value: AppLocaleText.tr(
            context,
            en: '15 minutes before start',
            zhHans: '开始前15分钟',
            zhHant: '開始前15分鐘',
            ja: '開始15分前',
          ),
        ),
      ],
    );
  }

  Widget _noteField(BuildContext context) {
    return TextField(
      controller: _noteController,
      minLines: 3,
      maxLines: 5,
      maxLength: 200,
      decoration: InputDecoration(
        hintText: AppLocaleText.tr(
          context,
          en: 'Add anything you want to remember...',
          zhHans: '补充一些你想记住的事...',
          zhHant: '補充一些你想記住的事...',
          ja: '覚えておきたいことを少し...',
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.74),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AuroraColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AuroraColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AuroraColors.purple, width: 1.4),
        ),
      ),
    );
  }

  List<_ScheduleChoice> _sceneChoices(BuildContext context) => [
        _ScheduleChoice(
          value: 'work',
          label: AppLocaleText.tr(context,
              en: 'Work', zhHans: '工作', zhHant: '工作', ja: '仕事'),
          icon: Icons.calendar_month_outlined,
          color: AuroraColors.purple,
        ),
        _ScheduleChoice(
          value: 'study',
          label: AppLocaleText.tr(context,
              en: 'Study', zhHans: '学习', zhHant: '學習', ja: '学び'),
          icon: Icons.menu_book_outlined,
          color: AuroraColors.blue,
        ),
        _ScheduleChoice(
          value: 'life',
          label: AppLocaleText.tr(context,
              en: 'Life', zhHans: '生活', zhHant: '生活', ja: '生活'),
          icon: Icons.local_florist_outlined,
          color: AuroraColors.orange,
        ),
        _ScheduleChoice(
          value: 'health',
          label: AppLocaleText.tr(context,
              en: 'Health', zhHans: '健康', zhHant: '健康', ja: '健康'),
          icon: Icons.favorite_border_rounded,
          color: AuroraColors.mint,
        ),
        _ScheduleChoice(
          value: 'other',
          label: AppLocaleText.tr(context,
              en: 'Other', zhHans: '其他', zhHant: '其他', ja: 'その他'),
          icon: Icons.more_horiz_rounded,
          color: AuroraColors.muted,
        ),
      ];

  List<_ScheduleChoice> _loadChoices(BuildContext context) => [
        _ScheduleChoice(
          value: 'very_light',
          label: AppLocaleText.tr(context,
              en: 'Very light', zhHans: '很轻松', zhHant: '很輕鬆', ja: 'とても軽い'),
          icon: Icons.favorite_border_rounded,
          color: AuroraColors.mint,
        ),
        _ScheduleChoice(
          value: 'light',
          label: AppLocaleText.tr(context,
              en: 'Light', zhHans: '轻松', zhHant: '輕鬆', ja: '軽い'),
          icon: Icons.favorite_border_rounded,
          color: AuroraColors.blue,
        ),
        _ScheduleChoice(
          value: 'medium',
          label: AppLocaleText.tr(context,
              en: 'Medium', zhHans: '中等', zhHant: '中等', ja: '中くらい'),
          icon: Icons.favorite_rounded,
          color: AuroraColors.purple,
        ),
        _ScheduleChoice(
          value: 'heavy',
          label: AppLocaleText.tr(context,
              en: 'A bit heavy', zhHans: '有点重', zhHant: '有點重', ja: '少し重い'),
          icon: Icons.favorite_border_rounded,
          color: AuroraColors.orange,
        ),
        _ScheduleChoice(
          value: 'very_heavy',
          label: AppLocaleText.tr(context,
              en: 'Heavy', zhHans: '很重', zhHant: '很重', ja: '重い'),
          icon: Icons.favorite_border_rounded,
          color: const Color(0xFFE87979),
        ),
      ];

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365)),
      initialDate: _date ?? now,
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    FocusScope.of(context).unfocus();
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart
          ? (_startTime ?? TimeOfDay.now())
          : (_endTime ?? _startTime ?? TimeOfDay.now()),
    );
    if (picked == null) return;
    setState(() {
      _date ??= DateTime.now();
      if (isStart) {
        _startTime = picked;
        _endTime ??= TimeOfDay(
          hour: (picked.hour + 1) % 24,
          minute: picked.minute,
        );
      } else {
        _endTime = picked;
      }
      _allDay = false;
    });
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() {
        _errorText = AppLocaleText.tr(
          context,
          en: 'A title is enough, but the title cannot be empty.',
          zhHans: '只填标题就能保存，但标题需要有一点内容。',
          zhHant: '只填標題就能保存，但標題需要有一點內容。',
          ja: 'タイトルだけで保存できますが、空にはできません。',
        );
      });
      return;
    }
    Navigator.of(context).pop(
      _ScheduleFormResult(
        title: title,
        date: _date,
        startTime: _startTime == null
            ? null
            : DateTime(0, 1, 1, _startTime!.hour, _startTime!.minute),
        endTime: _endTime == null
            ? null
            : DateTime(0, 1, 1, _endTime!.hour, _endTime!.minute),
        scene: _scene,
        note: _noteController.text.trim(),
        expectedEnergyLoad: _load,
        reminderEnabled: _reminderEnabled && _startTime != null,
      ),
    );
  }

  String _dateLabel(BuildContext context, DateTime date) {
    final today = DateTime.now();
    final prefix = '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    if (date.year == today.year &&
        date.month == today.month &&
        date.day == today.day) {
      return AppLocaleText.tr(
        context,
        en: '$prefix Today',
        zhHans: '$prefix 今天',
        zhHant: '$prefix 今天',
        ja: '$prefix 今日',
      );
    }
    return prefix;
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool optional;

  const _SectionLabel({
    required this.icon,
    required this.title,
    this.optional = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AuroraColors.ink),
        const SizedBox(width: 8),
        Text(
          optional
              ? '$title ${AppLocaleText.tr(context, en: '(optional)', zhHans: '（可选）', zhHant: '（可選）', ja: '（任意）')}'
              : title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AuroraColors.ink,
              ),
        ),
      ],
    );
  }
}

class _GroupedCard extends StatelessWidget {
  final List<Widget> children;

  const _GroupedCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AuroraColors.line),
      ),
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1)
              const Divider(height: 1, color: AuroraColors.line),
          ],
        ],
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  final String title;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _ScheduleRow({
    required this.title,
    this.value,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AuroraColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          if (value != null)
            Flexible(
              child: Text(
                value!,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AuroraColors.purple,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          if (trailing != null) trailing!,
          if (onTap != null) ...[
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded,
                color: AuroraColors.muted, size: 20),
          ],
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: () {
        FocusScope.of(context).unfocus();
        onTap?.call();
      },
      borderRadius: BorderRadius.circular(18),
      child: content,
    );
  }
}

class _ScheduleChoice {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _ScheduleChoice({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });
}

class _ScheduleChoiceTile extends StatelessWidget {
  final _ScheduleChoice choice;
  final bool selected;
  final VoidCallback onTap;

  const _ScheduleChoiceTile({
    required this.choice,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selectedColor =
        choice.color == AuroraColors.muted ? AuroraColors.purple : choice.color;
    final foregroundColor = selected ? selectedColor : choice.color;
    return SizedBox(
      width: 72,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? selectedColor.withValues(alpha: 0.13)
                : Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? selectedColor : AuroraColors.line,
              width: selected ? 1.6 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: selectedColor.withValues(alpha: 0.12),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(choice.icon, color: foregroundColor, size: 20),
                  const SizedBox(height: 6),
                  Text(
                    choice.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: selected ? selectedColor : AuroraColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
              if (selected)
                Positioned(
                  top: -7,
                  right: -5,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: selectedColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: selectedColor.withValues(alpha: 0.2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SoftMessage extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _SoftMessage({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AuroraColors.muted,
                    height: 1.35,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleSignalsSection extends StatelessWidget {
  final List<ScheduleSignalModel> schedules;
  final VoidCallback onCreate;
  final void Function(ScheduleSignalModel schedule) onEdit;
  final void Function(ScheduleSignalModel schedule) onRecordFeeling;

  const _ScheduleSignalsSection({
    required this.schedules,
    required this.onCreate,
    required this.onEdit,
    required this.onRecordFeeling,
  });

  @override
  Widget build(BuildContext context) {
    final items = schedules.take(3).toList();
    return AuroraCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AuroraSoftIconCircle(
                icon: Icons.event_note_outlined,
                color: AuroraColors.blue,
                size: 38,
                iconSize: 19,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Today’s schedule signals',
                    zhHans: '今日安排信号',
                    zhHant: '今日安排信號',
                    ja: '今日の予定シグナル',
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 16.5,
                      ),
                ),
              ),
              TextButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(AppLocaleText.tr(
                  context,
                  en: 'Add',
                  zhHans: '添加',
                  zhHant: '新增',
                  ja: '追加',
                )),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Text(
              AppLocaleText.tr(
                context,
                en: 'If an arrangement may affect your energy, leave it here first. A title is enough.',
                zhHans: '如果有一个安排可能影响今天的能量，先把标题放在这里就够。',
                zhHant: '如果有一個安排可能影響今天的能量，先把標題放在這裡就夠。',
                ja: '今日のエネルギーに影響しそうな予定があれば、まずタイトルだけ置いておけます。',
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AuroraColors.muted,
                    height: 1.35,
                  ),
            )
          else
            Column(
              children: [
                for (final schedule in items) ...[
                  _ScheduleSignalTile(
                    schedule: schedule,
                    onEdit: () => onEdit(schedule),
                    onRecordFeeling: () => onRecordFeeling(schedule),
                  ),
                  if (schedule != items.last) const SizedBox(height: 8),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _ScheduleSignalTile extends StatelessWidget {
  final ScheduleSignalModel schedule;
  final VoidCallback onEdit;
  final VoidCallback onRecordFeeling;

  const _ScheduleSignalTile({
    required this.schedule,
    required this.onEdit,
    required this.onRecordFeeling,
  });

  @override
  Widget build(BuildContext context) {
    final status = _statusLabel(context);
    final meta = _metaLabel(context);
    final accent = _accentColor;
    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AuroraColors.line),
        ),
        child: Row(
          children: [
            AuroraSoftIconCircle(
              icon: _icon,
              color: accent,
              size: 40,
              iconSize: 19,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AuroraChip(label: status, color: accent),
                      if (schedule.feedbackStatus != 'not_started') ...[
                        const SizedBox(width: 6),
                        AuroraChip(
                          label: AppLocaleText.tr(
                            context,
                            en: 'Feeling saved',
                            zhHans: '感受已保存',
                            zhHant: '感受已保存',
                            ja: '感覚を保存済み',
                          ),
                          color: AuroraColors.mint,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    schedule.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AuroraColors.ink,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        schedule.timePrecision == 'time'
                            ? Icons.calendar_today_outlined
                            : Icons.access_time_rounded,
                        size: 14,
                        color: AuroraColors.muted,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AuroraColors.muted,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onRecordFeeling,
              child: Text(AppLocaleText.tr(
                context,
                en: 'Feeling',
                zhHans: '感受',
                zhHant: '感受',
                ja: '感覚',
              )),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AuroraColors.muted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(BuildContext context) {
    if (schedule.isUnscheduled) {
      return AppLocaleText.tr(
        context,
        en: 'Pending schedule',
        zhHans: '待定安排',
        zhHant: '待定安排',
        ja: '未定の予定',
      );
    }
    if (schedule.timePrecision == 'none') {
      return AppLocaleText.tr(
        context,
        en: 'Date only',
        zhHans: '只有日期',
        zhHant: '只有日期',
        ja: '日付のみ',
      );
    }
    return AppLocaleText.tr(
      context,
      en: 'Scheduled',
      zhHans: '已定安排',
      zhHant: '已定安排',
      ja: '予定済み',
    );
  }

  String _metaLabel(BuildContext context) {
    final start = schedule.startTime?.toLocal();
    final end = schedule.endTime?.toLocal();
    final scene =
        schedule.scene == null ? null : _sceneLabel(context, schedule.scene!);
    if (schedule.isUnscheduled || start == null) {
      return AppLocaleText.tr(
        context,
        en: 'Time can be added later',
        zhHans: '时间待定',
        zhHant: '時間待定',
        ja: '時間はあとで追加',
      );
    }
    if (schedule.timePrecision == 'time') {
      final time = end == null
          ? _timeLabel(start)
          : '${_timeLabel(start)} - ${_timeLabel(end)}';
      return scene == null ? time : '$time · $scene';
    }
    final date =
        '${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
    return scene == null ? date : '$date · $scene';
  }

  String _timeLabel(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _sceneLabel(BuildContext context, String value) {
    switch (value) {
      case 'work':
        return AppLocaleText.tr(context,
            en: 'Work', zhHans: '工作', zhHant: '工作', ja: '仕事');
      case 'study':
        return AppLocaleText.tr(context,
            en: 'Study', zhHans: '学习', zhHant: '學習', ja: '学び');
      case 'life':
        return AppLocaleText.tr(context,
            en: 'Life', zhHans: '生活', zhHant: '生活', ja: '生活');
      case 'health':
        return AppLocaleText.tr(context,
            en: 'Health', zhHans: '健康', zhHant: '健康', ja: '健康');
      case 'relationship':
        return AppLocaleText.tr(context,
            en: 'Relationship', zhHans: '关系', zhHant: '關係', ja: '関係');
      case 'recovery':
        return AppLocaleText.tr(context,
            en: 'Recovery', zhHans: '恢复', zhHant: '恢復', ja: '回復');
      default:
        return AppLocaleText.tr(context,
            en: 'Other', zhHans: '其他', zhHant: '其他', ja: 'その他');
    }
  }

  Color get _accentColor {
    switch (schedule.expectedEnergyLoad) {
      case 'very_light':
      case 'light':
      case 'restoring':
        return AuroraColors.mint;
      case 'medium':
        return AuroraColors.purple;
      case 'heavy':
      case 'very_heavy':
      case 'high_draining':
      case 'switching':
        return AuroraColors.orange;
      default:
        return AuroraColors.blue;
    }
  }

  IconData get _icon {
    switch (schedule.scene) {
      case 'study':
        return Icons.menu_book_outlined;
      case 'life':
        return Icons.local_florist_outlined;
      case 'health':
        return Icons.favorite_border_rounded;
      case 'relationship':
        return Icons.groups_2_outlined;
      case 'recovery':
        return Icons.nights_stay_outlined;
      default:
        return Icons.event_available_outlined;
    }
  }
}

class _GoalExerciseSection extends StatelessWidget {
  final List<GoalModel> goals;
  final List<GoalTaskInstanceModel> tasks;
  final VoidCallback onCreate;
  final void Function(GoalTaskInstanceModel task, String feedback) onFeedback;

  const _GoalExerciseSection({
    required this.goals,
    required this.tasks,
    required this.onCreate,
    required this.onFeedback,
  });

  @override
  Widget build(BuildContext context) {
    final goal = goals.isNotEmpty ? goals.first : null;
    final practiceTasks = tasks.take(3).toList();
    final completedCount = tasks
        .where((task) => task.status == 'tried')
        .length
        .clamp(0, 7)
        .toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AuroraCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.90),
              const Color(0xFFF7F4FF).withValues(alpha: 0.80),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.science_outlined,
                      color: AuroraColors.purple, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocaleText.tr(
                        context,
                        en: 'Today’s goal experiment',
                        zhHans: '今日目标实验',
                        zhHant: '今日目標實驗',
                        ja: '今日の目標実験',
                      ),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: AuroraColors.ink,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: onCreate,
                    icon: const Icon(Icons.add_rounded),
                    tooltip: AppLocaleText.tr(
                      context,
                      en: 'Add goal',
                      zhHans: '添加目标',
                      zhHant: '新增目標',
                      ja: '目標を追加',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _GoalProgressPanel(
                goalTitle: _goalTitle(context, goal, practiceTasks),
                completedDays: completedCount == 0 && practiceTasks.isNotEmpty
                    ? 1
                    : completedCount,
                totalDays: 7,
              ),
              const SizedBox(height: 12),
              _GoalInsightQuote(
                text: AppLocaleText.tr(
                  context,
                  en: 'Not doing more, but leaving a steadier space for recovery first.',
                  zhHans: '不是做更多，而是先为恢复留出一点稳定空间。',
                  zhHant: '不是做更多，而是先為恢復留出一點穩定空間。',
                  ja: 'もっと増やすのではなく、回復のための安定した余白を先に残します。',
                ),
              ),
              const SizedBox(height: 10),
              _GoalStructureRow(
                icon: Icons.track_changes_rounded,
                accent: AuroraColors.mint,
                label: 'Strategy',
                body: AppLocaleText.tr(
                  context,
                  en: 'Why: after frequent switching, recovery is easy to get squeezed out.',
                  zhHans: '为什么做：高切换后，恢复总被挤掉。',
                  zhHant: '為什麼做：高切換後，恢復總被擠掉。',
                  ja: '理由：切り替えが多い後は、回復の余白が押し出されやすい。',
                ),
              ),
              const SizedBox(height: 8),
              _GoalStructureRow(
                icon: Icons.edit_rounded,
                accent: AuroraColors.orange,
                label: 'Design',
                body: _designText(context, practiceTasks, goal),
              ),
              const SizedBox(height: 8),
              _GoalStructureRow(
                icon: Icons.bar_chart_rounded,
                accent: AuroraColors.blue,
                label: 'Development',
                body: AppLocaleText.tr(
                  context,
                  en: 'After trying: happened / not today / helpful / adjust.',
                  zhHans: '执行后记录：发生了 / 没发生 / 有帮助 / 想调整',
                  zhHant: '執行後記錄：發生了 / 沒發生 / 有幫助 / 想調整',
                  ja: '試した後の記録：できた / 今日はまだ / 役立った / 調整したい',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AuroraCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.assignment_turned_in_outlined,
                      color: AuroraColors.purple, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocaleText.tr(
                        context,
                        en: 'Today’s practice tasks',
                        zhHans: '今日练习任务',
                        zhHant: '今日練習任務',
                        ja: '今日の練習タスク',
                      ),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 16.5,
                            color: AuroraColors.ink,
                          ),
                    ),
                  ),
                  TextButton(
                    onPressed: onCreate,
                    child: Text(AppLocaleText.tr(
                      context,
                      en: 'See all',
                      zhHans: '查看全部',
                      zhHant: '查看全部',
                      ja: 'すべて見る',
                    )),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (practiceTasks.isEmpty)
                Text(
                  goals.isEmpty
                      ? AppLocaleText.tr(
                          context,
                          en: 'Add a goal first. Signal Path will keep the practice small and optional.',
                          zhHans: '先添加一个目标。Signal Path 会把练习保持得很小、可选择。',
                          zhHant: '先新增一個目標。Signal Path 會把練習保持得很小、可選擇。',
                          ja: 'まず目標を追加してください。Signal Path は練習を小さく任意に保ちます。',
                        )
                      : AppLocaleText.tr(
                          context,
                          en: 'No practice task for today. You can still keep the goal as context.',
                          zhHans: '今天还没有练习任务，目标会先作为背景保留。',
                          zhHant: '今天還沒有練習任務，目標會先作為背景保留。',
                          ja: '今日は練習タスクがありません。目標は背景として残ります。',
                        ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AuroraColors.muted,
                        height: 1.35,
                      ),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final task in practiceTasks) ...[
                        _PracticeTaskPill(
                          task: task,
                          onTap: () => onFeedback(task, 'tried'),
                        ),
                        if (task != practiceTasks.last)
                          const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              if (practiceTasks.isNotEmpty) ...[
                const SizedBox(height: 12),
                _GoalFeedbackStrip(
                  onFeedback: (value) => onFeedback(practiceTasks.first, value),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static String _goalTitle(BuildContext context, GoalModel? goal,
      List<GoalTaskInstanceModel> tasks) {
    if (goal != null && goal.title.trim().isNotEmpty) {
      return goal.title.trim();
    }
    if (tasks.isNotEmpty) {
      return AppLocaleText.tr(
        context,
        en: 'Keep ${tasks.first.title}',
        zhHans: '持续保留 ${tasks.first.title}',
        zhHant: '持續保留 ${tasks.first.title}',
        ja: '${tasks.first.title}を続ける',
      );
    }
    return AppLocaleText.tr(
      context,
      en: 'Keep one small recovery space',
      zhHans: '保留一个小恢复空间',
      zhHant: '保留一個小恢復空間',
      ja: '小さな回復の余白を残す',
    );
  }

  static String _designText(BuildContext context,
      List<GoalTaskInstanceModel> tasks, GoalModel? goal) {
    if (tasks.isNotEmpty) {
      final taskText = tasks.take(2).map((task) => task.title).join('；');
      return AppLocaleText.tr(
        context,
        en: 'Today’s plan: $taskText.',
        zhHans: '今天计划：$taskText。',
        zhHant: '今天計畫：$taskText。',
        ja: '今日の計画：$taskText。',
      );
    }
    final desiredMinutes = goal?.desiredDurationMinutes;
    if (desiredMinutes != null) {
      return AppLocaleText.tr(
        context,
        en: 'Today’s plan: leave $desiredMinutes minutes for this.',
        zhHans: '今天计划：先为它留 $desiredMinutes 分钟。',
        zhHant: '今天計畫：先為它留 $desiredMinutes 分鐘。',
        ja: '今日の計画：まず $desiredMinutes 分を残す。',
      );
    }
    return AppLocaleText.tr(
      context,
      en: 'Today’s plan: keep the smallest version that still counts.',
      zhHans: '今天计划：先做一个仍然算数的最小版本。',
      zhHant: '今天計畫：先做一個仍然算數的最小版本。',
      ja: '今日の計画：意味のある最小版から始める。',
    );
  }
}

class _GoalProgressPanel extends StatelessWidget {
  final String goalTitle;
  final int completedDays;
  final int totalDays;

  const _GoalProgressPanel({
    required this.goalTitle,
    required this.completedDays,
    required this.totalDays,
  });

  @override
  Widget build(BuildContext context) {
    final safeCompleted = completedDays.clamp(0, totalDays).toInt();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AuroraColors.purple.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AuroraColors.ink,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
              children: [
                TextSpan(
                  text: AppLocaleText.tr(
                    context,
                    en: 'Goal: ',
                    zhHans: '目标：',
                    zhHant: '目標：',
                    ja: '目標：',
                  ),
                ),
                TextSpan(text: goalTitle),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: AppLocaleText.tr(
                        context,
                        en: 'Day ',
                        zhHans: '第 ',
                        zhHant: '第 ',
                        ja: '',
                      ),
                    ),
                    TextSpan(
                      text: '$safeCompleted',
                      style: const TextStyle(
                        color: AuroraColors.purple,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    TextSpan(
                      text: AppLocaleText.tr(
                        context,
                        en: ' / $totalDays',
                        zhHans: ' / $totalDays 天',
                        zhHant: ' / $totalDays 天',
                        ja: ' / $totalDays 日目',
                      ),
                    ),
                  ],
                ),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AuroraColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _GoalProgressSegments(
                  completed: safeCompleted,
                  total: totalDays,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalProgressSegments extends StatelessWidget {
  final int completed;
  final int total;

  const _GoalProgressSegments({
    required this.completed,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: i < completed
                    ? AuroraColors.purple
                    : AuroraColors.line.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          if (i != total - 1) const SizedBox(width: 7),
        ],
      ],
    );
  }
}

class _GoalInsightQuote extends StatelessWidget {
  final String text;

  const _GoalInsightQuote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const AuroraLandscapeMedallion(size: 42),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '“ $text ”',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AuroraColors.ink,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
          ),
        ),
      ],
    );
  }
}

class _GoalStructureRow extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String label;
  final String body;

  const _GoalStructureRow({
    required this.icon,
    required this.accent,
    required this.label,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AuroraColors.purple.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          AuroraSoftIconCircle(
            icon: icon,
            color: accent,
            size: 34,
            iconSize: 17,
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          Container(
            width: 1,
            height: 32,
            color: AuroraColors.line,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              body,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AuroraColors.ink,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PracticeTaskPill extends StatelessWidget {
  final GoalTaskInstanceModel task;
  final VoidCallback onTap;

  const _PracticeTaskPill({
    required this.task,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final completed = task.status == 'tried';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
        decoration: BoxDecoration(
          color: completed
              ? AuroraColors.mint.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.76),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: completed
                ? AuroraColors.mint.withValues(alpha: 0.32)
                : AuroraColors.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              completed
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: completed ? AuroraColors.mint : AuroraColors.muted,
              size: 18,
            ),
            const SizedBox(width: 7),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 170),
              child: Text(
                task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AuroraColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalFeedbackStrip extends StatelessWidget {
  final void Function(String value) onFeedback;

  const _GoalFeedbackStrip({required this.onFeedback});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ExperimentFeedbackButton(
            icon: Icons.check_circle_outline_rounded,
            label: AppLocaleText.tr(
              context,
              en: 'Happened',
              zhHans: '发生了',
              zhHant: '發生了',
              ja: 'できた',
            ),
            color: AuroraColors.purple,
            onTap: () => onFeedback('tried'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ExperimentFeedbackButton(
            icon: Icons.remove_circle_outline_rounded,
            label: AppLocaleText.tr(
              context,
              en: 'Not today',
              zhHans: '没发生',
              zhHant: '沒發生',
              ja: '今日はまだ',
            ),
            color: AuroraColors.muted,
            onTap: () => onFeedback('not_today'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ExperimentFeedbackButton(
            icon: Icons.favorite_border_rounded,
            label: AppLocaleText.tr(
              context,
              en: 'Helpful',
              zhHans: '有帮助',
              zhHant: '有幫助',
              ja: '役立った',
            ),
            color: AuroraColors.orange,
            onTap: () => onFeedback('helpful'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ExperimentFeedbackButton(
            icon: Icons.tune_rounded,
            label: AppLocaleText.tr(
              context,
              en: 'Adjust',
              zhHans: '想调整',
              zhHant: '想調整',
              ja: '調整したい',
            ),
            color: AuroraColors.blue,
            onTap: () => onFeedback('adjust'),
          ),
        ),
      ],
    );
  }
}

class _CompactSyncNotice extends StatelessWidget {
  final int count;
  final bool isSyncing;
  final String? message;

  const _CompactSyncNotice({
    required this.count,
    required this.isSyncing,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final text = message == 'sync_complete'
        ? AppLocaleText.tr(
            context,
            en: 'Sync completed.',
            zhHans: '同步完成。',
            zhHant: '同步完成。',
            ja: '同期が完了しました。',
          )
        : AppLocaleText.tr(
            context,
            en: '$count saved on this device. Nothing is lost.',
            zhHans: '$count 条已保存在这台设备上，不会丢。',
            zhHant: '$count 條已保存在這台裝置上，不會丟。',
            ja: '$count 件はこの端末に保存済みです。消えません。',
          );
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AuroraColors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_done_rounded,
              color: AuroraColors.blue.withValues(alpha: 0.86), size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

void _showLocalHint(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
      ),
    );
}

class _DiaryTimelineItem {
  final String time;
  final String userText;
  final String aiText;
  final List<_DiaryTag> tags;
  final VoidCallback? onMore;

  const _DiaryTimelineItem({
    required this.time,
    required this.userText,
    required this.aiText,
    required this.tags,
    this.onMore,
  });

  factory _DiaryTimelineItem.fromSignal(
    BuildContext context,
    RecentSignalModel signal, {
    required VoidCallback onOpenDialog,
  }) {
    final createdAt = signal.createdAt?.toLocal();
    final time = createdAt == null
        ? '--:--'
        : '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
    final aiText = (signal.acknowledgement ?? '').trim().isNotEmpty
        ? signal.acknowledgement!.trim()
        : signal.isLocalDraft || signal.syncFailed
            ? AppLocaleText.tr(
                context,
                en: 'AI has not organized this yet. Your original note is already saved.',
                zhHans: 'AI 还没整理这条，但你的原文已经保存。',
                zhHant: 'AI 還沒整理這條，但你的原文已經保存。',
                ja: 'AI はまだ整理していませんが、元の記録は保存されています。',
              )
            : AppLocaleText.tr(
                context,
                en: 'This is saved as one small signal from today.',
                zhHans: '这已经作为今天的一条小信号保存下来。',
                zhHant: '這已經作為今天的一條小信號保存下來。',
                ja: 'これは今日の小さなシグナルとして保存されています。',
              );
    final userText = signal.isLibrarySaved
        ? AppLocaleText.tr(
            context,
            en: 'Saved from Library: ${signal.libraryPatternTitle ?? 'shared signal'}',
            zhHans: '来自信号库：${signal.libraryPatternTitle ?? '共有生活信号'}',
            zhHant: '來自信號庫：${signal.libraryPatternTitle ?? '共有生活信號'}',
            ja: 'シグナルライブラリから：${signal.libraryPatternTitle ?? '共有シグナル'}',
          )
        : signal.content;
    return _DiaryTimelineItem(
      time: time,
      userText: userText,
      aiText: aiText,
      tags: _tagsForSignal(context, signal),
      onMore: signal.id == null ? null : onOpenDialog,
    );
  }

  static List<_DiaryTag> _tagsForSignal(
    BuildContext context,
    RecentSignalModel signal,
  ) {
    final raw = <String>[
      if ((signal.scene ?? '').trim().isNotEmpty) signal.scene!,
      if ((signal.friction ?? '').trim().isNotEmpty) signal.friction!,
      if ((signal.energyLoad ?? '').trim().isNotEmpty) signal.energyLoad!,
      ...signal.sceneTags,
    ].take(3).toList();
    if (raw.isEmpty) {
      raw.addAll([
        if (signal.isLibrarySaved)
          AppLocaleText.tr(
            context,
            en: 'From Library',
            zhHans: '来自 Library',
            zhHant: '來自 Library',
            ja: 'Library から保存',
          )
        else
          AppLocaleText.tr(context,
              en: 'signal', zhHans: '信号', zhHant: '信號', ja: 'シグナル'),
        if (signal.isLibrarySaved)
          AppLocaleText.tr(
            context,
            en: 'Private observation',
            zhHans: '私密观察',
            zhHant: '私密觀察',
            ja: 'プライベート観察',
          )
        else
          AppLocaleText.tr(context,
              en: 'today', zhHans: '今天', zhHant: '今天', ja: '今日'),
      ]);
    }
    final colors = [AuroraColors.purple, AuroraColors.blue, AuroraColors.mint];
    return [
      for (var i = 0; i < raw.length; i++)
        _DiaryTag(_diaryLabelTag(context, raw[i]), colors[i % colors.length]),
    ];
  }

  static String _diaryLabelTag(BuildContext context, String value) {
    switch (value) {
      case 'work':
      case 'work_tasks':
        return AppLocaleText.tr(context,
            en: 'work', zhHans: '工作', zhHant: '工作', ja: '仕事');
      case 'relationship':
      case 'relationships':
        return AppLocaleText.tr(context,
            en: 'relationship', zhHans: '关系', zhHant: '關係', ja: '関係');
      case 'draining':
        return AppLocaleText.tr(context,
            en: 'drain', zhHans: '消耗', zhHant: '消耗', ja: '消耗');
      case 'restoring':
        return AppLocaleText.tr(context,
            en: 'recovery', zhHans: '恢复', zhHant: '恢復', ja: '回復');
      case 'mixed':
        return AppLocaleText.tr(context,
            en: 'mixed', zhHans: '混合', zhHant: '混合', ja: '混在');
      case 'neutral':
        return AppLocaleText.tr(context,
            en: 'neutral', zhHans: '中性', zhHant: '中性', ja: '中立');
      default:
        return value
            .replaceAll('_', ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
    }
  }
}

class _TimelineRow extends StatelessWidget {
  final _DiaryTimelineItem item;

  const _TimelineRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 48,
          child: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              item.time,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AuroraColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ),
        Container(
          width: 18,
          height: 18,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(
              color: AuroraColors.purple.withValues(alpha: 0.72),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AuroraColors.purple.withValues(alpha: 0.18),
                blurRadius: 10,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: AuroraColors.purple,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _DiarySignalCard(item: item),
        ),
      ],
    );
  }
}

class _DiarySignalCard extends StatelessWidget {
  final _DiaryTimelineItem item;

  const _DiarySignalCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
        boxShadow: [
          BoxShadow(
            color: AuroraColors.purple.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SpeakerLine(
                  label: AppLocaleText.tr(context,
                      en: 'Me', zhHans: '我', zhHant: '我', ja: '自分'),
                  text: item.userText,
                  color: AuroraColors.purple,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints.tightFor(width: 28, height: 28),
                onPressed: item.onMore,
                icon: const Icon(Icons.more_horiz_rounded,
                    color: AuroraColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _SpeakerLine(
            label: 'AI',
            text: item.aiText,
            color: AuroraColors.blue,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: item.tags
                .map((tag) => AuroraChip(label: tag.label, color: tag.color))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _SpeakerLine extends StatelessWidget {
  final String label;
  final String text;
  final Color color;

  const _SpeakerLine({
    required this.label,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AuroraColors.ink,
                  fontSize: 13.5,
                  height: 1.30,
                ),
          ),
        ),
      ],
    );
  }
}

class _DiaryTag {
  final String label;
  final Color color;

  const _DiaryTag(this.label, this.color);
}

class _WeeklyExperimentTodayCard extends StatelessWidget {
  final dynamic experiment;
  final bool isSubmitting;
  final Future<void> Function(String status, String feedbackText) onFeedback;

  const _WeeklyExperimentTodayCard({
    required this.experiment,
    required this.isSubmitting,
    required this.onFeedback,
  });

  @override
  Widget build(BuildContext context) {
    final title = (experiment?.title as String?)?.trim();
    final action = (experiment?.suggestedAction as String?)?.trim();
    final hasExperiment = experiment != null &&
        ((title != null && title.isNotEmpty) ||
            (action != null && action.isNotEmpty));
    final status = (experiment?.status as String?)?.trim() ?? '';
    final feedbackText = (experiment?.feedbackText as String?)?.trim() ?? '';
    final feedbackLabel = _experimentFeedbackLabel(context, status);

    return AuroraCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFFF4F0FF).withValues(alpha: 0.82),
          Colors.white.withValues(alpha: 0.92),
          const Color(0xFFFFFBF2).withValues(alpha: 0.82),
        ],
      ),
      child: Row(
        children: [
          const _ExperimentFlask(size: 58),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasExperiment
                      ? AppLocaleText.tr(
                          context,
                          en: 'Weekly experiment',
                          zhHans: '本周实验',
                          zhHant: '本週實驗',
                          ja: '今週の小さな試み',
                        )
                      : AppLocaleText.tr(
                          context,
                          en: 'Weekly experiment is forming',
                          zhHans: '本周实验正在形成',
                          zhHant: '本週實驗正在形成',
                          ja: '今週の小さな試みが形になっています',
                        ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasExperiment
                      ? (action?.isNotEmpty == true ? action! : title!)
                      : AppLocaleText.tr(
                          context,
                          en: 'After Weekly gathers enough signals, one small optional experiment will appear here.',
                          zhHans: '等本周线索再聚一点，这里会出现一个可选的小实验。',
                          zhHant: '等本週線索再聚一點，這裡會出現一個可選的小實驗。',
                          ja: '今週のシグナルがもう少し集まると、ここに小さな試みが表示されます。',
                        ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AuroraColors.ink,
                        height: 1.35,
                      ),
                ),
                if (feedbackLabel != null) ...[
                  const SizedBox(height: 8),
                  AuroraChip(
                    label: feedbackText.isNotEmpty
                        ? '$feedbackLabel：$feedbackText'
                        : feedbackLabel,
                    color: AuroraColors.mint,
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ExperimentFeedbackButton(
                        icon: Icons.check_circle_outline_rounded,
                        label: AppLocaleText.tr(
                          context,
                          en: 'Happened',
                          zhHans: '发生了',
                          zhHant: '發生了',
                          ja: 'できた',
                        ),
                        color: AuroraColors.purple,
                        onTap: hasExperiment && !isSubmitting
                            ? () => onFeedback(
                                  'tried',
                                  'The experiment happened today.',
                                )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ExperimentFeedbackButton(
                        icon: Icons.cancel_outlined,
                        label: AppLocaleText.tr(
                          context,
                          en: 'Not yet',
                          zhHans: '没发生',
                          zhHant: '沒發生',
                          ja: 'まだ',
                        ),
                        color: AuroraColors.muted,
                        onTap: hasExperiment && !isSubmitting
                            ? () => onFeedback('saved', 'Not yet today.')
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ExperimentFeedbackButton(
                        icon: Icons.favorite_border_rounded,
                        label: AppLocaleText.tr(
                          context,
                          en: 'Helpful',
                          zhHans: '有帮助',
                          zhHant: '有幫助',
                          ja: '役立った',
                        ),
                        color: AuroraColors.orange,
                        onTap: hasExperiment && !isSubmitting
                            ? () => onFeedback(
                                  'adjusted',
                                  'This helped a little today.',
                                )
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _experimentFeedbackLabel(BuildContext context, String status) {
    switch (status) {
      case 'tried':
        return AppLocaleText.tr(
          context,
          en: 'Recorded: happened',
          zhHans: '已记录：发生了',
          zhHant: '已記錄：發生了',
          ja: '記録済み：できた',
        );
      case 'saved':
        return AppLocaleText.tr(
          context,
          en: 'Recorded: not yet',
          zhHans: '已记录：没发生',
          zhHant: '已記錄：沒發生',
          ja: '記録済み：まだ',
        );
      case 'adjusted':
        return AppLocaleText.tr(
          context,
          en: 'Recorded: helpful',
          zhHans: '已记录：有帮助',
          zhHant: '已記錄：有幫助',
          ja: '記録済み：役立った',
        );
      default:
        return null;
    }
  }
}

class _ExperimentFeedbackButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ExperimentFeedbackButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Opacity(
        opacity: onTap == null ? 0.55 : 1,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.70),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AuroraColors.line),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 5),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AuroraColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExperimentFlask extends StatelessWidget {
  final double size;

  const _ExperimentFlask({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _ExperimentFlaskPainter()),
    );
  }
}

class _ExperimentFlaskPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(
      center,
      size.width * 0.48,
      Paint()..color = AuroraColors.purple.withValues(alpha: 0.10),
    );
    final flask = Path()
      ..moveTo(size.width * 0.42, size.height * 0.18)
      ..lineTo(size.width * 0.58, size.height * 0.18)
      ..lineTo(size.width * 0.58, size.height * 0.45)
      ..lineTo(size.width * 0.76, size.height * 0.78)
      ..quadraticBezierTo(
        size.width * 0.50,
        size.height * 0.92,
        size.width * 0.24,
        size.height * 0.78,
      )
      ..lineTo(size.width * 0.42, size.height * 0.45)
      ..close();
    canvas.drawPath(
      flask,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEDEBFF), Color(0xFF7B6FF2)],
        ).createShader(Offset.zero & size)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      flask,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.78)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      Offset(size.width * 0.62, size.height * 0.62),
      3,
      Paint()..color = Colors.white.withValues(alpha: 0.70),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _InlineStatusCard extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isError;

  const _InlineStatusCard({
    required this.icon,
    required this.text,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: isError ? scheme.errorContainer : scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: isError ? scheme.onErrorContainer : scheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: isError ? scheme.onErrorContainer : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanBlockCard extends StatelessWidget {
  final String text;

  const _PlanBlockCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return _UnifiedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_note_outlined),
              const SizedBox(width: 10),
              Text(
                AppLocaleText.tr(
                  context,
                  en: 'Plan Block',
                  zhHans: 'Plan Block',
                  zhHant: 'Plan Block',
                  ja: 'Plan Block',
                ),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: 10),
          const ExperimentPathVisual(),
          const SizedBox(height: 10),
          Text(text),
          const SizedBox(height: 4),
          Text(
            AppLocaleText.tr(
              context,
              en: 'Local only. No calendar event, notification, or task was created.',
              zhHans: '仅本地保存，没有创建日历、提醒或任务。',
              zhHant: '僅本地保存，沒有建立日曆、提醒或任務。',
              ja: 'ローカル保存のみです。カレンダー、通知、タスクは作成していません。',
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _FollowupQuestionCard extends StatelessWidget {
  final FollowupQuestionModel question;
  final bool isSubmitting;
  final ValueChanged<String> onSubmit;

  const _FollowupQuestionCard({
    required this.question,
    required this.isSubmitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return _UnifiedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question.question,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: question.options
                .map(
                  (option) => OutlinedButton(
                    onPressed:
                        isSubmitting ? null : () => onSubmit(option.value),
                    child: Text(option.label),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _TimelineList extends StatelessWidget {
  final List<RecentSignalModel> signals;
  final void Function(RecentSignalModel signal) onOpenDialog;
  final Future<void> Function({
    required RecentSignalModel signal,
    required String confirmation,
    Map<String, dynamic>? correction,
  }) onConfirm;

  const _TimelineList({
    required this.signals,
    required this.onOpenDialog,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: signals
          .map(
            (signal) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SignalCard(
                signal: signal,
                onOpenDialog: () => onOpenDialog(signal),
                onConfirm: onConfirm,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _SignalCard extends StatelessWidget {
  final RecentSignalModel signal;
  final VoidCallback onOpenDialog;
  final Future<void> Function({
    required RecentSignalModel signal,
    required String confirmation,
    Map<String, dynamic>? correction,
  }) onConfirm;

  const _SignalCard({
    required this.signal,
    required this.onOpenDialog,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metaTags = _metaTags(context);
    final statusTags = _statusTags(context);
    final aiReply = _aiReplyText(context);
    final showConfirmation = _shouldShowConfirmation;

    return _UnifiedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (signal.createdAt != null)
            Text(
              _formatTime(signal.createdAt!.toLocal()),
              style: theme.textTheme.labelMedium,
            ),
          if (signal.createdAt != null) const SizedBox(height: 8),
          if (signal.isLibrarySaved)
            _LibrarySavedObservation(signal: signal)
          else
            Text(
              signal.content,
              style: theme.textTheme.bodyLarge,
            ),
          if (aiReply != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(140),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                aiReply,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: (signal.acknowledgement ?? '').trim().isEmpty
                      ? theme.colorScheme.onSurfaceVariant
                      : null,
                ),
              ),
            ),
          ],
          if (metaTags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: metaTags.map((tag) => _MetaChip(label: tag)).toList(),
            ),
          ],
          if (statusTags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: statusTags
                  .map((tag) => _MetaChip(label: tag, isStatus: true))
                  .toList(),
            ),
          ],
          if (showConfirmation) ...[
            const SizedBox(height: 10),
            _ConfirmationBar(
              signal: signal,
              onConfirm: onConfirm,
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: (signal.signalCardId ?? signal.id) == null
                  ? null
                  : onOpenDialog,
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              label: Text(
                AppLocaleText.tr(
                  context,
                  en: 'Talk through this',
                  zhHans: '围绕这条继续想',
                  zhHant: '圍繞這條繼續想',
                  ja: 'この記録をもう少し整理する',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  List<String> _metaTags(BuildContext context) {
    final tags = <String>[
      if ((signal.emotion ?? '').isNotEmpty)
        _labelTag(context, signal.emotion!),
      if ((signal.scene ?? '').isNotEmpty) _labelTag(context, signal.scene!),
      if ((signal.friction ?? '').isNotEmpty)
        _labelTag(context, signal.friction!),
      if ((signal.energyLoad ?? '').isNotEmpty)
        _labelTag(context, signal.energyLoad!),
    ];
    if (tags.length < 3) {
      tags.addAll(signal.sceneTags
          .take(3 - tags.length)
          .map((tag) => _labelTag(context, tag)));
    }
    return tags.take(3).toList();
  }

  List<String> _statusTags(BuildContext context) {
    return <String>[
      if (_shouldShowConfirmation)
        _confirmationLabel(context, signal.userConfirmation),
      if (signal.isLibrarySaved)
        AppLocaleText.tr(
          context,
          en: 'From Library',
          zhHans: '来自 Library',
          zhHant: '來自 Library',
          ja: 'Library から保存',
        ),
      if (signal.isLibrarySaved)
        AppLocaleText.tr(
          context,
          en: 'Private observation',
          zhHans: '私密观察',
          zhHant: '私密觀察',
          ja: 'プライベート観察',
        ),
      if (signal.sourceType == 'voice')
        AppLocaleText.tr(
          context,
          en: 'Transcript only',
          zhHans: '仅转写文字',
          zhHant: '僅轉寫文字',
          ja: '文字のみ保存',
        ),
      if (signal.sourceType == 'ai_predicted')
        AppLocaleText.tr(
          context,
          en: 'Suggested by AI',
          zhHans: 'AI 预判',
          zhHant: 'AI 預判',
          ja: 'AI の提案',
        ),
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
          en: 'Sync needs retry',
          zhHans: '同步待重试',
          zhHant: '同步待重試',
          ja: '同期は再試行待ち',
        ),
      if (!signal.isLocalDraft && !signal.syncFailed)
        AppLocaleText.tr(
          context,
          en: 'Synced',
          zhHans: '已同步',
          zhHant: '已同步',
          ja: '同期済み',
        ),
      if (signal.includedInSummary)
        AppLocaleText.tr(
          context,
          en: 'Used today',
          zhHans: '已进入今日观察',
          zhHant: '已進入今日觀察',
          ja: '今日の観察に使用',
        ),
      if (signal.includedInWeekly)
        AppLocaleText.tr(
          context,
          en: 'Part of Weekly',
          zhHans: '已进入本周小观察',
          zhHant: '已進入本週小觀察',
          ja: '今週の小さな観察に反映',
        ),
      if (signal.includedInJourney)
        AppLocaleText.tr(
          context,
          en: 'Part of Journey',
          zhHans: '已进入生活地图',
          zhHant: '已進入生活地圖',
          ja: '生活の旅路に反映',
        ),
    ];
  }

  bool get _shouldShowConfirmation {
    return signal.isAiPredicted || signal.isLibrarySaved;
  }

  String? _aiReplyText(BuildContext context) {
    final acknowledgement = signal.acknowledgement?.trim();
    if (acknowledgement != null && acknowledgement.isNotEmpty) {
      return acknowledgement;
    }

    if (signal.isLibrarySaved) {
      return AppLocaleText.tr(
        context,
        en: 'You can add a little of your own context when it feels useful. This stays private.',
        zhHans: '你也可以补充一点自己的情况。这条仍然只保存在你的私密观察里。',
        zhHant: '你也可以補充一點自己的情況。這條仍然只保存在你的私密觀察裡。',
        ja: '必要なら、自分の状況を少し足せます。これは非公開の観察として残ります。',
      );
    }

    if (signal.isLocalDraft || signal.syncFailed) {
      return AppLocaleText.tr(
        context,
        en: 'AI has not organized this yet. Your original note is already saved.',
        zhHans: 'AI 还没整理这条，但你的原文已经保存。',
        zhHant: 'AI 還沒整理這條，但你的原文已經保存。',
        ja: 'AI はまだ整理していませんが、元の記録は保存されています。',
      );
    }

    return null;
  }

  String _confirmationLabel(BuildContext context, String value) {
    switch (value) {
      case 'accurate':
        return AppLocaleText.tr(
          context,
          en: 'Looks right',
          zhHans: '看起来是准的',
          zhHant: '看起來是準的',
          ja: '合っていそう',
        );
      case 'inaccurate':
        return AppLocaleText.tr(
          context,
          en: 'Not quite',
          zhHans: '不太准',
          zhHant: '不太準',
          ja: '少し違う',
        );
      case 'edited':
        return AppLocaleText.tr(
          context,
          en: 'Adjusted',
          zhHans: '已修改',
          zhHant: '已修改',
          ja: '修正済み',
        );
      case 'supplemented':
        return AppLocaleText.tr(
          context,
          en: 'Added context',
          zhHans: '已补充',
          zhHant: '已補充',
          ja: '補足済み',
        );
      default:
        return AppLocaleText.tr(
          context,
          en: 'Not checked yet',
          zhHans: '还没确认',
          zhHant: '還沒確認',
          ja: '未確認',
        );
    }
  }

  String _labelTag(BuildContext context, String value) {
    switch (value) {
      case 'positive':
        return AppLocaleText.tr(
          context,
          en: 'positive',
          zhHans: '正向',
          zhHant: '正向',
          ja: 'ポジティブ',
        );
      case 'negative':
        return AppLocaleText.tr(
          context,
          en: 'heavy',
          zhHans: '偏消耗',
          zhHant: '偏消耗',
          ja: '重め',
        );
      case 'mixed':
        return AppLocaleText.tr(
          context,
          en: 'mixed',
          zhHans: '混合',
          zhHant: '混合',
          ja: '混在',
        );
      case 'neutral':
        return AppLocaleText.tr(
          context,
          en: 'neutral',
          zhHans: '中性',
          zhHant: '中性',
          ja: '中立',
        );
      case 'low':
        return AppLocaleText.tr(
          context,
          en: 'light',
          zhHans: '轻',
          zhHant: '輕',
          ja: '軽め',
        );
      case 'medium':
        return AppLocaleText.tr(
          context,
          en: 'medium',
          zhHans: '中等',
          zhHant: '中等',
          ja: '中くらい',
        );
      case 'high':
        return AppLocaleText.tr(
          context,
          en: 'strong',
          zhHans: '强',
          zhHant: '強',
          ja: '強め',
        );
      case 'daily_life':
        return AppLocaleText.tr(
          context,
          en: 'daily life',
          zhHans: '日常',
          zhHant: '日常',
          ja: '日常',
        );
      case 'overload':
        return AppLocaleText.tr(
          context,
          en: 'overload',
          zhHans: '过载',
          zhHant: '過載',
          ja: '過負荷',
        );
      case 'draining':
        return AppLocaleText.tr(
          context,
          en: 'draining',
          zhHans: '消耗',
          zhHant: '消耗',
          ja: '消耗',
        );
      case 'recovering':
        return AppLocaleText.tr(
          context,
          en: 'restoring',
          zhHans: '恢复',
          zhHant: '恢復',
          ja: '回復',
        );
      default:
        return value.replaceAll('_', ' ');
    }
  }
}

class _LibrarySavedObservation extends StatelessWidget {
  final RecentSignalModel signal;

  const _LibrarySavedObservation({required this.signal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = signal.libraryPatternTitle ??
        AppLocaleText.tr(
          context,
          en: 'Library observation',
          zhHans: 'Library 观察',
          zhHant: 'Library 觀察',
          ja: 'Library の観察',
        );
    final abstract = signal.libraryAbstractPattern;
    final supplement = _userSupplement;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocaleText.tr(
              context,
              en: 'Saved from Library',
              zhHans: '从 Library 保存',
              zhHant: '從 Library 保存',
              ja: 'Library から保存',
            ),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(title, style: theme.textTheme.titleSmall),
          if (abstract != null && abstract.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              abstract,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (supplement != null && supplement.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              AppLocaleText.tr(
                context,
                en: 'Your context',
                zhHans: '你的补充',
                zhHant: '你的補充',
                ja: '自分の補足',
              ),
              style: theme.textTheme.labelMedium,
            ),
            const SizedBox(height: 4),
            Text(supplement),
          ],
        ],
      ),
    );
  }

  String? get _userSupplement {
    final supplement =
        signal.userCorrectionJson['supplement_text']?.toString().trim();
    if (supplement != null && supplement.isNotEmpty) return supplement;
    final edited = signal.userCorrectionJson['edited_text']?.toString().trim();
    if (edited != null && edited.isNotEmpty) return edited;
    final content = signal.content.trim();
    return content.isEmpty ? null : content;
  }
}

class _DailyObservationCard extends StatelessWidget {
  final String summary;

  const _DailyObservationCard({
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    return _UnifiedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocaleText.tr(
              context,
              en: 'Today, you can look at it this way',
              zhHans: '今天可以先这样看',
              zhHant: '今天可以先這樣看',
              ja: '今日はまずこう見てみる',
            ),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Text(summary),
        ],
      ),
    );
  }
}

class _TryNextCard extends StatelessWidget {
  final String summary;

  const _TryNextCard({
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    return _UnifiedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocaleText.tr(
              context,
              en: 'You can try this today',
              zhHans: '今天可以先试试',
              zhHant: '今天可以先試試',
              ja: '今日ひとつ試してみるなら',
            ),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Text(summary),
        ],
      ),
    );
  }
}

class _ConfirmationBar extends StatelessWidget {
  final RecentSignalModel signal;
  final Future<void> Function({
    required RecentSignalModel signal,
    required String confirmation,
    Map<String, dynamic>? correction,
  }) onConfirm;

  const _ConfirmationBar({
    required this.signal,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton(
          onPressed: () => onConfirm(
            signal: signal,
            confirmation: 'accurate',
          ),
          child: Text(
            AppLocaleText.tr(
              context,
              en: 'Looks right',
              zhHans: '是准的',
              zhHant: '是準的',
              ja: '合っていそう',
            ),
          ),
        ),
        OutlinedButton(
          onPressed: () => onConfirm(
            signal: signal,
            confirmation: 'inaccurate',
          ),
          child: Text(
            AppLocaleText.tr(
              context,
              en: 'Not quite',
              zhHans: '不太准',
              zhHant: '不太準',
              ja: '少し違う',
            ),
          ),
        ),
        OutlinedButton(
          onPressed: () => _openCorrectionDialog(
            context,
            confirmation: 'edited',
          ),
          child: Text(
            AppLocaleText.tr(
              context,
              en: 'Adjust',
              zhHans: '改一下',
              zhHant: '改一下',
              ja: '調整',
            ),
          ),
        ),
        OutlinedButton(
          onPressed: () => _openCorrectionDialog(
            context,
            confirmation: 'supplemented',
          ),
          child: Text(
            AppLocaleText.tr(
              context,
              en: 'Add context',
              zhHans: '补一点',
              zhHant: '補一點',
              ja: '少し補足',
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openCorrectionDialog(
    BuildContext context, {
    required String confirmation,
  }) async {
    final value = await showDialog<String>(
      context: context,
      builder: (context) => _CorrectionDialog(confirmation: confirmation),
    );

    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return;

    await onConfirm(
      signal: signal,
      confirmation: confirmation,
      correction: {
        confirmation == 'edited' ? 'edited_text' : 'supplement_text': trimmed,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }
}

class _CorrectionDialog extends StatefulWidget {
  final String confirmation;

  const _CorrectionDialog({required this.confirmation});

  @override
  State<_CorrectionDialog> createState() => _CorrectionDialogState();
}

class _CorrectionDialogState extends State<_CorrectionDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.confirmation == 'edited'
            ? AppLocaleText.tr(
                context,
                en: 'Edit Signal Card',
                zhHans: '修改 Signal Card',
                zhHant: '修改 Signal Card',
                ja: 'Signal Card を修正',
              )
            : AppLocaleText.tr(
                context,
                en: 'Add a supplement',
                zhHans: '补充一点',
                zhHant: '補充一點',
                ja: '補足する',
              ),
      ),
      content: TextField(
        controller: _controller,
        minLines: 3,
        maxLines: 5,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            AppLocaleText.tr(
              context,
              en: 'Cancel',
              zhHans: '取消',
              zhHant: '取消',
              ja: 'キャンセル',
            ),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(
            AppLocaleText.tr(
              context,
              en: 'Save',
              zhHans: '保存',
              zhHant: '保存',
              ja: '保存',
            ),
          ),
        ),
      ],
    );
  }
}

enum _VoiceDraftStage { ready, listening, paused, editing }

class _VoiceTranscriptSheet extends StatefulWidget {
  const _VoiceTranscriptSheet();

  @override
  State<_VoiceTranscriptSheet> createState() => _VoiceTranscriptSheetState();
}

class _VoiceTranscriptSheetState extends State<_VoiceTranscriptSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  _VoiceDraftStage _stage = _VoiceDraftStage.ready;
  Timer? _timer;
  int _elapsedSeconds = 0;
  String? _errorText;

  bool get _isRecording => _stage == _VoiceDraftStage.listening;
  bool get _isPaused => _stage == _VoiceDraftStage.paused;
  bool get _isEditing => _stage == _VoiceDraftStage.editing;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _isRecording) {
        setState(() => _elapsedSeconds += 1);
      }
    });
  }

  void _startRecording() {
    setState(() {
      _stage = _VoiceDraftStage.listening;
      _errorText = null;
      _elapsedSeconds = 0;
    });
    _startTimer();
  }

  void _pauseOrResume() {
    setState(() {
      if (_isPaused) {
        _stage = _VoiceDraftStage.listening;
        _startTimer();
      } else {
        _stage = _VoiceDraftStage.paused;
        _timer?.cancel();
      }
    });
  }

  void _stopToEdit() {
    _timer?.cancel();
    setState(() {
      _stage = _VoiceDraftStage.editing;
      _errorText = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _recordAgain() {
    _controller.clear();
    _startRecording();
  }

  void _saveTranscript() {
    final transcript = _controller.text.trim();
    if (transcript.isEmpty) {
      setState(() {
        _errorText = AppLocaleText.tr(
          context,
          en: 'Add or edit the transcript before saving.',
          zhHans: '请先补上要保存的转写内容。',
          zhHant: '請先補上要保存的轉寫內容。',
          ja: '保存する文字起こしを入力してください。',
        );
      });
      return;
    }
    Navigator.of(context).pop(transcript);
  }

  String _timerLabel() {
    final minutes = _elapsedSeconds ~/ 60;
    final seconds = _elapsedSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_stage) {
      _VoiceDraftStage.ready => AppLocaleText.tr(
          context,
          en: 'Ready to record',
          zhHans: '准备录音',
          zhHant: '準備錄音',
          ja: '録音の準備',
        ),
      _VoiceDraftStage.listening => AppLocaleText.tr(
          context,
          en: 'Recognizing...',
          zhHans: '正在识别中...',
          zhHant: '正在識別中...',
          ja: '認識中...',
        ),
      _VoiceDraftStage.paused => AppLocaleText.tr(
          context,
          en: 'Paused',
          zhHans: '已暂停',
          zhHant: '已暫停',
          ja: '一時停止中',
        ),
      _VoiceDraftStage.editing => AppLocaleText.tr(
          context,
          en: 'Recognition complete',
          zhHans: '识别完成',
          zhHant: '識別完成',
          ja: '認識完了',
        ),
    };
    final subtitle = switch (_stage) {
      _VoiceDraftStage.ready => AppLocaleText.tr(
          context,
          en: 'Tap start, then speak. You can edit the transcript before saving.',
          zhHans: '点开始后再说话，保存前可以编辑转写内容。',
          zhHant: '點開始後再說話，保存前可以編輯轉寫內容。',
          ja: '開始を押して話します。保存前に文字起こしを編集できます。',
        ),
      _VoiceDraftStage.listening => AppLocaleText.tr(
          context,
          en: 'Voice recognition is active. Keep speaking.',
          zhHans: '语音识别中，请继续说话。',
          zhHant: '語音識別中，請繼續說話。',
          ja: '音声認識中です。続けて話してください。',
        ),
      _VoiceDraftStage.paused => AppLocaleText.tr(
          context,
          en: 'Recognition is paused. Resume or stop to edit.',
          zhHans: '识别已暂停，可以继续或停止后编辑。',
          zhHant: '識別已暫停，可以繼續或停止後編輯。',
          ja: '認識を一時停止しています。再開するか、停止して編集できます。',
        ),
      _VoiceDraftStage.editing => AppLocaleText.tr(
          context,
          en: 'Edit the transcript, then save it as a signal.',
          zhHans: '编辑转写内容后，再保存为信号。',
          zhHant: '編輯轉寫內容後，再保存為信號。',
          ja: '文字起こしを編集して、シグナルとして保存します。',
        ),
    };

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.92)),
          boxShadow: [
            BoxShadow(
              color: AuroraColors.ink.withValues(alpha: 0.18),
              blurRadius: 52,
              offset: const Offset(0, -20),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AuroraColors.line,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: AuroraColors.purple,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: AuroraColors.ink,
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                    ),
                    _VoiceTimerBadge(label: _timerLabel()),
                  ],
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    subtitle,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AuroraColors.muted),
                  ),
                ),
                const SizedBox(height: 20),
                if (!_isEditing) ...[
                  AuroraCard(
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 72,
                          width: double.infinity,
                          child: CustomPaint(
                            painter: _VoiceWavePainter(
                              color: _stage == _VoiceDraftStage.ready
                                  ? AuroraColors.muted
                                  : AuroraColors.purple,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: _isRecording
                                    ? AuroraColors.purple
                                    : AuroraColors.muted,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 9),
                            Text(
                              AppLocaleText.tr(
                                context,
                                en: _isRecording
                                    ? 'Listening...'
                                    : _isPaused
                                        ? 'Paused'
                                        : 'Not recording yet',
                                zhHans: _isRecording
                                    ? '正在聆听...'
                                    : _isPaused
                                        ? '已暂停'
                                        : '还未开始录音',
                                zhHant: _isRecording
                                    ? '正在聆聽...'
                                    : _isPaused
                                        ? '已暫停'
                                        : '尚未開始錄音',
                                ja: _isRecording
                                    ? '聞き取り中...'
                                    : _isPaused
                                        ? '一時停止中'
                                        : 'まだ録音していません',
                              ),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(color: AuroraColors.ink),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_stage == _VoiceDraftStage.ready)
                    _VoicePrimaryAction(
                      label: AppLocaleText.tr(
                        context,
                        en: 'Start recording',
                        zhHans: '开始录音',
                        zhHant: '開始錄音',
                        ja: '録音を開始',
                      ),
                      subtitle: AppLocaleText.tr(
                        context,
                        en: 'Timer starts after tapping',
                        zhHans: '点击后开始计时',
                        zhHant: '點擊後開始計時',
                        ja: 'タップ後に計時します',
                      ),
                      onPressed: _startRecording,
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _VoiceAction(
                          icon: _isPaused
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded,
                          label: AppLocaleText.tr(
                            context,
                            en: _isPaused ? 'Resume' : 'Pause',
                            zhHans: _isPaused ? '继续' : '暂停',
                            zhHant: _isPaused ? '繼續' : '暫停',
                            ja: _isPaused ? '再開' : '一時停止',
                          ),
                          onPressed: _pauseOrResume,
                        ),
                        _VoiceAction(
                          icon: Icons.stop_rounded,
                          label: AppLocaleText.tr(
                            context,
                            en: 'Stop',
                            zhHans: '停止',
                            zhHant: '停止',
                            ja: '停止',
                          ),
                          onPressed: _stopToEdit,
                        ),
                        _VoicePrimaryAction(
                          label: AppLocaleText.tr(
                            context,
                            en: 'Stop and edit',
                            zhHans: '停止并编辑',
                            zhHant: '停止並編輯',
                            ja: '停止して編集',
                          ),
                          subtitle: AppLocaleText.tr(
                            context,
                            en: 'Review transcript',
                            zhHans: '确认转写内容',
                            zhHant: '確認轉寫內容',
                            ja: '文字起こしを確認',
                          ),
                          onPressed: _stopToEdit,
                        ),
                      ],
                    ),
                ] else ...[
                  Row(
                    children: [
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _recordAgain,
                        icon: const Icon(Icons.mic_none_rounded, size: 18),
                        label: Text(
                          AppLocaleText.tr(
                            context,
                            en: 'Record again',
                            zhHans: '重新录制',
                            zhHant: '重新錄製',
                            ja: '録り直す',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    minLines: 5,
                    maxLines: 8,
                    autofocus: true,
                    onChanged: (_) {
                      if (_errorText != null) {
                        setState(() => _errorText = null);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: AppLocaleText.tr(
                        context,
                        en: 'Edit the transcript before saving...',
                        zhHans: '保存前可以先编辑转写内容……',
                        zhHant: '保存前可以先編輯轉寫內容……',
                        ja: '保存前に文字起こしを編集できます…',
                      ),
                      errorText: _errorText,
                      helperText: AppLocaleText.tr(
                        context,
                        en: 'Only transcript text is saved. Audio is not saved or uploaded.',
                        zhHans: '只保存转写文字，不保存或上传音频。',
                        zhHant: '只保存轉寫文字，不保存或上傳音訊。',
                        ja: '保存するのは文字だけです。音声は保存・アップロードしません。',
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _VoiceAction(
                        icon: Icons.close_rounded,
                        label: AppLocaleText.tr(
                          context,
                          en: 'Close',
                          zhHans: '关闭',
                          zhHant: '關閉',
                          ja: '閉じる',
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      _VoicePrimaryAction(
                        label: AppLocaleText.tr(
                          context,
                          en: 'Save as signal',
                          zhHans: '保存为信号',
                          zhHant: '保存為信號',
                          ja: 'シグナルとして保存',
                        ),
                        subtitle: AppLocaleText.tr(
                          context,
                          en: 'Save to diary timeline',
                          zhHans: '保存到手帐时间线',
                          zhHant: '保存到手帳時間線',
                          ja: '手帳タイムラインに保存',
                        ),
                        onPressed: _saveTranscript,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VoiceTimerBadge extends StatelessWidget {
  final String label;

  const _VoiceTimerBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AuroraColors.line.withValues(alpha: 0.70)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule_rounded, size: 16, color: AuroraColors.ink),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AuroraColors.ink,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _VoiceAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _VoiceAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox(
          width: 88,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                color: Colors.white.withValues(alpha: 0.78),
                shape: const CircleBorder(),
                elevation: 8,
                shadowColor: AuroraColors.purple.withValues(alpha: 0.10),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onPressed,
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: Icon(icon, color: AuroraColors.purple, size: 27),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AuroraColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoicePrimaryAction extends StatelessWidget {
  final String label;
  final String subtitle;
  final VoidCallback onPressed;

  const _VoicePrimaryAction({
    required this.label,
    required this.subtitle,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.check_rounded),
              label: Text(label),
              style: FilledButton.styleFrom(
                backgroundColor: AuroraColors.purple,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AuroraColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceWavePainter extends CustomPainter {
  final Color color;

  const _VoiceWavePainter({this.color = AuroraColors.purple});

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.72)
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    final quietPaint = Paint()
      ..color = color.withValues(alpha: 0.22)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const bars = [
      4.0,
      7.0,
      18.0,
      31.0,
      42.0,
      23.0,
      14.0,
      28.0,
      36.0,
      22.0,
      18.0,
      24.0,
      38.0,
      50.0,
      34.0,
      21.0,
      12.0,
      8.0,
    ];
    final step = size.width / (bars.length + 7);
    var x = step * 3.5;
    for (final height in bars) {
      final p = height < 10 ? quietPaint : paint;
      canvas.drawLine(
        Offset(x, centerY - height / 2),
        Offset(x, centerY + height / 2),
        p,
      );
      x += step;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MetaChip extends StatelessWidget {
  final String label;
  final bool isStatus;

  const _MetaChip({
    required this.label,
    this.isStatus = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isStatus
            ? theme.colorScheme.tertiaryContainer
            : theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: isStatus
              ? theme.colorScheme.onTertiaryContainer
              : theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

class _UnifiedCard extends StatelessWidget {
  final Widget child;

  const _UnifiedCard({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: child,
      ),
    );
  }
}
