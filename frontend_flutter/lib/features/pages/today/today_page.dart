import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/di/app_dependencies.dart';
import '../../../core/eligibility/signal_eligibility_service.dart';
import '../../../core/i18n/app_locale_text.dart';
import '../../../core/models/phase3_plus_models.dart';
import '../../../core/models/today_models.dart';
import '../../../core/purchases/purchase_controller.dart';
import '../../../core/state/app_data_refresh_coordinator.dart';
import '../../../shared/utils/user_visible_text_sanitizer.dart';
import '../../../shared/widgets/aurora_ui.dart';
import '../../../shared/widgets/editable_timeline_decision_dialog.dart';
import '../../paywall/paywall_sheet.dart';
import 'today_state.dart';
import 'today_view_model.dart';
import 'today_adopted_plans_section.dart';

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

  Future<void> _respondToPredictionMatch({
    required TodayViewModel viewModel,
    required AiJudgementModel judgement,
    required String status,
  }) async {
    final initialText = (judgement.userAdjustmentText ?? '').trim().isNotEmpty
        ? judgement.userAdjustmentText!.trim()
        : judgement.predictedSignalText.trim();
    final decision = await showEditableTimelineDecisionDialog(
      context,
      initialText: initialText,
      keyPrefix: 'ai-prediction',
    );
    if (decision == null || !mounted) return;
    final original = judgement.predictedSignalText.trim();
    final adjustment = decision.text == original ? null : decision.text;
    await viewModel.respondToAiJudgement(
      judgement: judgement,
      status: status,
      userAdjustmentText: adjustment,
      addToTimeline: decision.addToTimeline,
      language: AppLocaleText.resolve(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TodayViewModel>();
    final purchase = context.watch<PurchaseController?>();
    final state = vm.state;
    final todaySignals = _todayOnlySignals(state.recentSignals);

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
                key: const ValueKey('today-scroll-view'),
                padding: AuroraMainPageSpec.scrollPadding(context),
                children: [
                  _TodayHeroHeader(
                    insightText: insightText,
                    signals: todaySignals,
                  ),
                  const SizedBox(height: AuroraMainPageSpec.heroGap),
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
                    onSignalLibrary: () async {
                      if (!await _confirmLeaveWithUnsavedInput(context)) {
                        return;
                      }
                      if (!context.mounted) return;
                      _trackTodayEvent(
                        context,
                        'today_signal_library_opened',
                      );
                      await context.push<void>(AppRoutes.signalLibrary);
                      if (!context.mounted) return;
                      final coordinator =
                          Provider.of<AppDataRefreshCoordinator?>(
                        context,
                        listen: false,
                      );
                      if (coordinator != null) {
                        await coordinator.refreshRoute(
                          AppRoutes.today,
                          force: true,
                        );
                      } else {
                        await vm.load();
                      }
                    },
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
                  const SizedBox(height: AuroraMainPageSpec.sectionGap),
                  _AiJudgementPanel(
                    key: const ValueKey('today-ai-prediction-panel'),
                    judgement: state.aiJudgement,
                    microAction: null,
                    isBusy: state.isCaptureSubmitting,
                    onAccurate: (judgement) => _respondToPredictionMatch(
                      viewModel: vm,
                      judgement: judgement,
                      status: 'accurate',
                    ),
                    onPartial: (judgement) => _respondToPredictionMatch(
                      viewModel: vm,
                      judgement: judgement,
                      status: 'partial',
                    ),
                    onInaccurate: (judgement) => vm.respondToAiJudgement(
                      judgement: judgement,
                      status: 'inaccurate',
                      addToTimeline: false,
                      language: AppLocaleText.resolve(context),
                    ),
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
                  const SizedBox(height: AuroraMainPageSpec.sectionGap),
                  TodayAdoptedPlansSection(
                    signals: state.recentSignals,
                    compatibilityAction: state.activeMicroAction,
                    compatibilityExperiment: state.todayLifeExperiment,
                    isBusy: state.isCaptureSubmitting,
                    onActionFeedback: (action, feedback) async {
                      await vm.submitMicroActionFeedback(
                        action: action,
                        feedback: feedback,
                      );
                      if (!context.mounted) return;
                      _showSoftMessage(
                        context,
                        AppLocaleText.tr(
                          context,
                          en: 'Your action feedback is saved.',
                          zhHans: '今日小行动反馈已保存。',
                          zhHant: '今日小行動回饋已保存。',
                          ja: '今日の小さな行動の反応を保存しました。',
                        ),
                      );
                    },
                    onOpenActionHub: () async {
                      if (!await _confirmLeaveWithUnsavedInput(context)) {
                        return;
                      }
                      if (!context.mounted) return;
                      await context.push(AppRoutes.todayActionCandidates);
                      if (context.mounted) await vm.load();
                    },
                    onOpenExperimentHub: () async {
                      if (!await _confirmLeaveWithUnsavedInput(context)) {
                        return;
                      }
                      if (!context.mounted) return;
                      await context.push(AppRoutes.weeklyExperimentCandidates);
                      if (context.mounted) await vm.load();
                    },
                    onOpenExperiment: () async {
                      if (!await _confirmLeaveWithUnsavedInput(context)) {
                        return;
                      }
                      if (context.mounted) {
                        context.go(AppRoutes.experiment);
                      }
                    },
                  ),
                  const SizedBox(height: AuroraMainPageSpec.sectionGap),
                  _DiaryTimelineSection(
                    signals: todaySignals,
                    onOpenAllRecords: () async {
                      if (!await _confirmLeaveWithUnsavedInput(context)) {
                        return;
                      }
                      if (context.mounted) context.push(AppRoutes.todayDiary);
                    },
                    onOpenDialog: (signal) async {
                      if (!await _confirmLeaveWithUnsavedInput(context)) {
                        return;
                      }
                      final captureId = signal.signalCardId ?? signal.id;
                      if (captureId == null || captureId.trim().isEmpty) {
                        return;
                      }
                      if (context.mounted) {
                        _openTodayDialog(context, purchase, captureId);
                      }
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
                  if (state.isInitialLoading) ...[
                    const SizedBox(height: 18),
                    const Center(child: CircularProgressIndicator()),
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

  void _trackTodayEvent(
    BuildContext context,
    String eventName, {
    Map<String, dynamic>? properties,
  }) {
    final deps = context.read<AppDependencies?>();
    unawaited(deps?.analyticsRepository.track(
      eventName,
      properties: properties,
    ));
  }

  Future<bool> _confirmLeaveWithUnsavedInput(BuildContext context) async {
    if (_controller.text.trim().isEmpty) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          AppLocaleText.tr(
            context,
            en: 'Leave without saving?',
            zhHans: '先不保存就离开吗？',
            zhHant: '先不保存就離開嗎？',
            ja: '保存せずに移動しますか？',
          ),
        ),
        content: Text(
          AppLocaleText.tr(
            context,
            en: 'The text in Quick record has not been saved yet.',
            zhHans: '快速记录里的文字还没有保存。',
            zhHant: '快速記錄裡的文字還沒有保存。',
            ja: 'クイック記録の文章はまだ保存されていません。',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              AppLocaleText.tr(
                context,
                en: 'Keep editing',
                zhHans: '继续编辑',
                zhHant: '繼續編輯',
                ja: '編集を続ける',
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              AppLocaleText.tr(
                context,
                en: 'Leave',
                zhHans: '离开',
                zhHant: '離開',
                ja: '移動する',
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
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

    showPremiumPaywall(context, source: 'Today 记录');
  }

  Future<void> _openVoiceTranscriptDraft(
    BuildContext context,
    TodayViewModel vm,
  ) async {
    _trackTodayEvent(context, 'today_voice_sheet_opened');
    final result = await showModalBottomSheet<_VoiceTranscriptResult>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => const _VoiceTranscriptSheet(),
    );
    if (result == null || result.content.trim().isEmpty) return;
    await vm.submitVoiceTranscript(result.content);
  }

  Future<void> _openQuickStatusSheet(
    BuildContext context,
    TodayViewModel vm,
  ) async {
    _trackTodayEvent(context, 'today_status_sheet_opened');
    final language = AppLocaleText.resolve(context);
    final result = await showModalBottomSheet<_StatusSignalResult>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => const _StatusSignalSheet(),
    );
    if (result == null) return;
    await vm.submitQuickStatus(
      choice: result.mood,
      language: language,
      detail: result.detail,
      energyLevel: result.energyLevel,
      note: result.note,
    );
  }

  List<RecentSignalModel> _todayOnlySignals(List<RecentSignalModel> all) {
    final now = DateTime.now();
    final todayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return all
        .where(
          (signal) =>
              signal.localDateKey() == todayKey &&
              !signal.sourceType.toLowerCase().contains('schedule'),
        )
        .toList()
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
    if (state.isInitialLoading) {
      return AppLocaleText.tr(
        context,
        en: 'Looking through today’s entries…',
        zhHans: '正在整理今天的记录……',
        zhHant: '正在整理今天的記錄……',
        ja: '今日の記録を整理しています……',
      );
    }

    if (todaySignals.isEmpty) {
      return AppLocaleText.tr(
        context,
        en: 'No entries yet. Start with one small real moment from today.',
        zhHans: '今天还没有记录，先留下一件真实发生的小事就好。',
        zhHant: '今天還沒有記錄，先留下一件真實發生的小事就好。',
        ja: '今日はまだ記録がありません。まずは本当にあった小さなことを一つ残してみて。',
      );
    }

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

  bool _hasText(String? value) {
    return value != null && value.trim().isNotEmpty;
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

class _AiJudgementPanel extends StatelessWidget {
  final AiJudgementModel? judgement;
  final MicroActionModel? microAction;
  final bool isBusy;
  final ValueChanged<AiJudgementModel> onAccurate;
  final ValueChanged<AiJudgementModel> onPartial;
  final ValueChanged<AiJudgementModel> onInaccurate;
  final void Function(MicroActionModel action, String choice)
      onMicroActionChoice;
  final void Function(MicroActionModel action, String feedback) onFeedback;

  const _AiJudgementPanel({
    super.key,
    required this.judgement,
    required this.microAction,
    required this.isBusy,
    required this.onAccurate,
    required this.onPartial,
    required this.onInaccurate,
    required this.onMicroActionChoice,
    required this.onFeedback,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AuroraCard(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      borderRadius: BorderRadius.circular(20),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFFF8F3FF).withValues(alpha: 0.88),
          const Color(0xFFF0F3FF).withValues(alpha: 0.78),
          const Color(0xFFFFFAF7).withValues(alpha: 0.82),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 22,
                color: AuroraColors.purple,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'AI prediction',
                    zhHans: 'AI预判',
                    zhHant: 'AI預判',
                    ja: 'AI予測',
                  ),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AuroraColors.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          if (judgement == null) ...[
            Text(
              AppLocaleText.tr(
                context,
                en: 'After you leave real signals, AI can offer one small prediction here.',
                zhHans: '留下真实信号后，AI 会在这里给出一条可确认的预判。',
                zhHant: '留下真實信號後，AI 會在這裡給出一條可確認的預判。',
                ja: '実際のシグナルを残すと、AI がここに確認できる予測を一つ表示します。',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AuroraColors.ink.withValues(alpha: 0.70),
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            _AiJudgementEmptyState(),
          ] else
            _AiJudgementContent(
              judgement: judgement!,
              microAction: microAction,
              isBusy: isBusy,
              onAccurate: onAccurate,
              onPartial: onPartial,
              onInaccurate: onInaccurate,
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
    return Text(
      AppLocaleText.tr(
        context,
        en: 'No prediction yet',
        zhHans: '暂时还没有预判',
        zhHant: '暫時還沒有預判',
        ja: 'まだ予測はありません',
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: const Color(0xFF5D7CFF),
            fontWeight: FontWeight.w900,
            height: 1.25,
          ),
    );
  }
}

class _AiJudgementContent extends StatelessWidget {
  final AiJudgementModel judgement;
  final MicroActionModel? microAction;
  final bool isBusy;
  final ValueChanged<AiJudgementModel> onAccurate;
  final ValueChanged<AiJudgementModel> onPartial;
  final ValueChanged<AiJudgementModel> onInaccurate;
  final void Function(MicroActionModel action, String choice)
      onMicroActionChoice;
  final void Function(MicroActionModel action, String feedback) onFeedback;

  const _AiJudgementContent({
    required this.judgement,
    required this.microAction,
    required this.isBusy,
    required this.onAccurate,
    required this.onPartial,
    required this.onInaccurate,
    required this.onMicroActionChoice,
    required this.onFeedback,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (judgement.userAdjustmentText ?? '').trim().isNotEmpty
                        ? judgement.userAdjustmentText!.trim()
                        : judgement.predictedSignalText,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AuroraColors.ink,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                  if (judgement.evidenceText.trim().isNotEmpty) ...[
                    const SizedBox(height: 5),
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
        const SizedBox(height: 10),
        if (judgement.isPending)
          Row(
            children: [
              Expanded(
                child: _AiJudgementActionButton(
                  key: const ValueKey('ai-prediction-accurate'),
                  label: AppLocaleText.tr(
                    context,
                    en: 'Accurate',
                    zhHans: '准',
                    zhHant: '準',
                    ja: '合っている',
                  ),
                  onPressed: isBusy ? null : () => onAccurate(judgement),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AiJudgementActionButton(
                  key: const ValueKey('ai-prediction-partial'),
                  label: AppLocaleText.tr(
                    context,
                    en: 'Somewhat',
                    zhHans: '有一点像',
                    zhHant: '有一點像',
                    ja: '少し近い',
                  ),
                  onPressed: isBusy ? null : () => onPartial(judgement),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AiJudgementActionButton(
                  key: const ValueKey('ai-prediction-inaccurate'),
                  label: AppLocaleText.tr(
                    context,
                    en: 'Not accurate',
                    zhHans: '不准',
                    zhHant: '不準',
                    ja: '違う',
                  ),
                  onPressed: isBusy ? null : () => onInaccurate(judgement),
                ),
              ),
            ],
          )
        else if (judgement.isDismissed)
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
              en: 'Confirmed as a signal. It can inform Weekly and Journey without becoming a task.',
              zhHans: '已确认成一条信号，会进入后续分析，不会自动变成任务。',
              zhHant: '已確認成一條信號，會進入後續分析，不會自動變成任務。',
              ja: 'シグナルとして確認しました。タスクにはせず、WeeklyやJourneyの材料にします。',
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
                  en: 'Add to experiment archive',
                  zhHans: '加入实验档案',
                  zhHant: '加入實驗檔案',
                  ja: '実験アーカイブへ',
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
                selected: const {'happened', 'occurred'}
                    .contains(action.feedbackStatus),
                onPressed: isBusy ? null : () => onFeedback('occurred'),
              ),
              _FeedbackChip(
                label: AppLocaleText.tr(
                  context,
                  en: 'Did not happen',
                  zhHans: '没发生',
                  zhHant: '沒發生',
                  ja: '起きなかった',
                ),
                selected: const {'not_happened', 'not_occurred'}
                    .contains(action.feedbackStatus),
                onPressed: isBusy ? null : () => onFeedback('not_occurred'),
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
                  en: 'Not suitable today',
                  zhHans: '今天不适合',
                  zhHant: '今天不適合',
                  ja: '今日は合わない',
                ),
                selected: action.feedbackStatus == 'not_suitable_today',
                onPressed:
                    isBusy ? null : () => onFeedback('not_suitable_today'),
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
          zhHans: '实验档案中',
          zhHant: '實驗檔案中',
          ja: '実験アーカイブ',
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
  final VoidCallback? onPressed;

  const _AiJudgementActionButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AuroraColors.purple,
        backgroundColor: const Color(0xFFFEFDFF).withValues(alpha: 0.64),
        minimumSize: const Size.fromHeight(44),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(
            color: AuroraColors.purple.withValues(alpha: 0.32),
          ),
        ),
        textStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(label, maxLines: 1),
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

class _CaptureInputCard extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSubmitting;
  final ValueChanged<String> onChanged;
  final VoidCallback onTextMode;
  final VoidCallback onVoiceDraft;
  final VoidCallback onQuickStatus;
  final VoidCallback onSignalLibrary;

  const _CaptureInputCard({
    required this.controller,
    required this.focusNode,
    required this.isSubmitting,
    required this.onChanged,
    required this.onTextMode,
    required this.onVoiceDraft,
    required this.onQuickStatus,
    required this.onSignalLibrary,
  });

  @override
  Widget build(BuildContext context) {
    return AuroraCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFFFFFAF6).withValues(alpha: 0.88),
          const Color(0xFFF1EEFF).withValues(alpha: 0.76),
          const Color(0xFFEEF6FF).withValues(alpha: 0.82),
        ],
      ),
      borderRadius: BorderRadius.circular(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _GlassIconBadge(
                icon: Icons.edit_rounded,
                color: AuroraColors.purple,
                size: 30,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Quick record',
                    zhHans: '快速记录',
                    zhHant: '快速記錄',
                    ja: 'クイック記録',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AuroraColors.purple,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            focusNode: focusNode,
            minLines: 1,
            maxLines: 3,
            onChanged: onChanged,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFFEFDFF).withValues(alpha: 0.78),
              suffixIcon: Padding(
                padding: const EdgeInsetsDirectional.only(end: 6),
                child: _ComposerSaveIconButton(
                  key: const ValueKey('today-submit-text-action'),
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
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.86),
                ),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.86),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: AuroraColors.purple.withValues(alpha: 0.54),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 6.0;
              final buttonWidth = (constraints.maxWidth - gap * 3) / 4;

              return Row(
                children: [
                  _ComposerModeButton(
                    key: const ValueKey('today-text-action'),
                    width: buttonWidth,
                    onPressed: isSubmitting ? null : onTextMode,
                    icon: Icons.text_fields_rounded,
                    label: AppLocaleText.tr(
                      context,
                      en: 'Text',
                      zhHans: '文字',
                      zhHant: '文字',
                      ja: 'テキスト',
                    ),
                  ),
                  const SizedBox(width: gap),
                  _ComposerModeButton(
                    key: const ValueKey('today-voice-action'),
                    width: buttonWidth,
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
                  const SizedBox(width: gap),
                  _ComposerModeButton(
                    key: const ValueKey('today-status-action'),
                    width: buttonWidth,
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
                  const SizedBox(width: gap),
                  _ComposerModeButton(
                    key: const ValueKey('today-signal-library-action'),
                    width: buttonWidth,
                    onPressed: isSubmitting ? null : onSignalLibrary,
                    icon: Icons.graphic_eq_rounded,
                    label: AppLocaleText.tr(
                      context,
                      en: 'Library',
                      zhHans: '信号库',
                      zhHant: '信號庫',
                      ja: 'ライブラリ',
                    ),
                  ),
                ],
              );
            },
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
    super.key,
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
      enabled: !isSubmitting,
      label: label,
      onTap: isSubmitting ? null : onPressed,
      child: ExcludeSemantics(
        child: Tooltip(
          message: label,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isSubmitting ? null : onPressed,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 44,
                height: 44,
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
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
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
      ),
    );
  }
}

class _ComposerModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final double width;

  const _ComposerModeButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: SizedBox(
          width: width,
          height: 66,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onPressed,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.54),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
                boxShadow: [
                  BoxShadow(
                    color: AuroraColors.purple.withValues(alpha: 0.07),
                    blurRadius: 14,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _GlassIconBadge(
                    icon: icon,
                    color: _modeColor(icon),
                    size: 27,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AuroraColors.ink.withValues(alpha: 0.78),
                          fontWeight: FontWeight.w700,
                          fontSize: 9.5,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _modeColor(IconData icon) {
    if (icon == Icons.text_fields_rounded) return AuroraColors.purple;
    if (icon == Icons.mic_none_rounded) return const Color(0xFFB26AF6);
    if (icon == Icons.mood_outlined) return AuroraColors.gold;
    if (icon == Icons.event_note_outlined) return AuroraColors.purple;
    if (icon == Icons.psychology_alt_outlined) return AuroraColors.blue;
    return AuroraColors.purple;
  }
}

enum _TodayHeroEnergyState {
  waiting,
  steady,
  draining,
  restoring,
  mixed,
}

class _TodayOverviewData {
  final int drainingCount;
  final int restoringCount;
  final int mixedCount;
  final int neutralCount;
  final int frictionClueCount;
  final int recoveryClueCount;

  const _TodayOverviewData({
    required this.drainingCount,
    required this.restoringCount,
    required this.mixedCount,
    required this.neutralCount,
    required this.frictionClueCount,
    required this.recoveryClueCount,
  });

  factory _TodayOverviewData.fromSignals(List<RecentSignalModel> signals) {
    final eligibleSignals = const SignalEligibilityService().filter(
      signals,
      SignalEligibilityStage.daily,
    );
    var draining = 0;
    var restoring = 0;
    var mixed = 0;
    var neutral = 0;
    var frictionClues = 0;
    var recoveryClues = 0;

    for (final signal in eligibleSignals) {
      final energy = (signal.energyLoad ?? '').trim().toLowerCase();
      switch (energy) {
        case 'draining':
        case 'high_draining':
          draining += 1;
        case 'restoring':
        case 'restorative':
        case 'recovering':
          restoring += 1;
        case 'mixed':
          mixed += 1;
        case 'neutral':
          neutral += 1;
      }

      final friction = (signal.friction ?? '').trim().toLowerCase();
      final hasExplicitFriction = friction.isNotEmpty &&
          !const {'unknown', 'none', 'neutral'}.contains(friction);
      if (hasExplicitFriction ||
          energy == 'draining' ||
          energy == 'high_draining' ||
          energy == 'mixed') {
        frictionClues += 1;
      }

      final structuredTags = [
        ...signal.linkedLifeChainStages,
        ...signal.sceneTags,
        ...signal.intentTags,
      ].map((value) => value.trim().toLowerCase());
      if (const {'restoring', 'restorative', 'recovering'}.contains(energy) ||
          structuredTags.any((value) => value == 'recovery')) {
        recoveryClues += 1;
      }
    }

    return _TodayOverviewData(
      drainingCount: draining,
      restoringCount: restoring,
      mixedCount: mixed,
      neutralCount: neutral,
      frictionClueCount: frictionClues,
      recoveryClueCount: recoveryClues,
    );
  }

  int get energyEvidenceCount =>
      drainingCount + restoringCount + mixedCount + neutralCount;

  bool get hasEvidence =>
      energyEvidenceCount > 0 || frictionClueCount > 0 || recoveryClueCount > 0;

  _TodayHeroEnergyState get energyState {
    if (energyEvidenceCount == 0) return _TodayHeroEnergyState.waiting;
    if (restoringCount > drainingCount && restoringCount >= mixedCount) {
      return _TodayHeroEnergyState.restoring;
    }
    if (drainingCount > restoringCount + neutralCount &&
        drainingCount >= mixedCount) {
      return _TodayHeroEnergyState.draining;
    }
    if (mixedCount > 0) return _TodayHeroEnergyState.mixed;
    return _TodayHeroEnergyState.steady;
  }
}

class _TodayHeroHeader extends StatelessWidget {
  final String insightText;
  final List<RecentSignalModel> signals;

  const _TodayHeroHeader({
    required this.insightText,
    required this.signals,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final compact = MediaQuery.sizeOf(context).width < 360;
    final overview = _TodayOverviewData.fromSignals(signals);
    final weekday = AppLocaleText.tr(
      context,
      en: _englishWeekday(now.weekday),
      zhHans: _zhWeekday(now.weekday),
      zhHant: _zhWeekday(now.weekday),
      ja: _jaWeekday(now.weekday),
    );
    final dateText = AppLocaleText.tr(
      context,
      en: '${_englishMonth(now.month)} ${now.day}, $weekday',
      zhHans: '${now.month}月${now.day}日 $weekday',
      zhHant: '${now.month}月${now.day}日 $weekday',
      ja: '${now.month}月${now.day}日 $weekday',
    );

    return ConstrainedBox(
      key: const ValueKey('today-hero-header'),
      constraints: BoxConstraints(
        minHeight: overview.hasEvidence ? 160 : 126,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: compact ? -16 : -12,
            top: compact ? -24 : -28,
            width: compact ? 118 : 142,
            height: compact ? 118 : 142,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.72,
                child: Image.asset(
                  'assets/brand-icon-transparent.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(2, compact ? 2 : 4, 2, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Today',
                    zhHans: '今天',
                    zhHant: '今天',
                    ja: '今日',
                  ),
                  style: TextStyle(
                    color: AuroraColors.ink,
                    fontSize: compact ? 34 : 36,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  dateText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AuroraColors.ink.withValues(alpha: 0.88),
                        fontWeight: FontWeight.w700,
                        fontSize: compact ? 13.5 : 15,
                      ),
                ),
                const SizedBox(height: 10),
                Padding(
                  key: const ValueKey('today-hero-observation'),
                  padding: EdgeInsets.only(right: compact ? 86 : 108),
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: AuroraColors.purple,
                                  fontSize: compact ? 10.5 : 11.5,
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _withoutSummaryPrefix(insightText),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AuroraColors.ink.withValues(alpha: 0.78),
                              height: 1.32,
                              fontWeight: FontWeight.w600,
                              fontSize: compact ? 12.5 : 13.5,
                            ),
                      ),
                    ],
                  ),
                ),
                if (overview.hasEvidence) ...[
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Expanded(
                        child: _TodayHeroMetricChip(
                          key: const ValueKey('today-hero-energy'),
                          icon: Icons.battery_saver_rounded,
                          label: AppLocaleText.tr(
                            context,
                            en: 'Energy',
                            zhHans: '能量',
                            zhHant: '能量',
                            ja: 'エネルギー',
                          ),
                          value: _energyValue(context, overview.energyState),
                          color: AuroraColors.purple,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: _TodayHeroMetricChip(
                          key: const ValueKey('today-hero-friction'),
                          icon: Icons.monitor_heart_outlined,
                          label: AppLocaleText.tr(
                            context,
                            en: 'Friction',
                            zhHans: '摩擦',
                            zhHant: '摩擦',
                            ja: '摩擦',
                          ),
                          value: _frictionValue(
                            context,
                            overview.frictionClueCount,
                          ),
                          color: AuroraColors.orange,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: _TodayHeroMetricChip(
                          key: const ValueKey('today-hero-recovery'),
                          icon: Icons.nights_stay_outlined,
                          label: AppLocaleText.tr(
                            context,
                            en: 'Recovery',
                            zhHans: '恢复',
                            zhHant: '恢復',
                            ja: '回復',
                          ),
                          value: _recoveryValue(
                            context,
                            overview.recoveryClueCount,
                          ),
                          color: AuroraColors.mint,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _withoutSummaryPrefix(String value) {
    final text = value.trim();
    for (final prefix in const [
      'Today, you can look at it this way:',
      '今天可以先这样看：',
      '今天可以先这样看:',
      '今天可以先這樣看：',
      '今天可以先這樣看:',
      '今日はまずこう見てみる：',
      '今日はまずこう見てみる:',
    ]) {
      if (text.startsWith(prefix)) {
        final remainder = text.substring(prefix.length).trim();
        if (remainder.isNotEmpty) return remainder;
      }
    }
    return text;
  }

  String _energyValue(
    BuildContext context,
    _TodayHeroEnergyState state,
  ) {
    return switch (state) {
      _TodayHeroEnergyState.steady => AppLocaleText.tr(
          context,
          en: 'Steady',
          zhHans: '平稳',
          zhHant: '平穩',
          ja: '安定',
        ),
      _TodayHeroEnergyState.draining => AppLocaleText.tr(
          context,
          en: 'Draining',
          zhHans: '有消耗',
          zhHant: '有消耗',
          ja: '消耗あり',
        ),
      _TodayHeroEnergyState.restoring => AppLocaleText.tr(
          context,
          en: 'Restoring',
          zhHans: '在回升',
          zhHant: '在回升',
          ja: '回復中',
        ),
      _TodayHeroEnergyState.mixed => AppLocaleText.tr(
          context,
          en: 'Mixed',
          zhHans: '有波动',
          zhHant: '有波動',
          ja: '揺れあり',
        ),
      _TodayHeroEnergyState.waiting => _waitingValue(context),
    };
  }

  String _frictionValue(BuildContext context, int clueCount) {
    if (clueCount == 0) return _waitingValue(context);
    if (clueCount > 1) {
      return AppLocaleText.tr(
        context,
        en: 'More clues',
        zhHans: '线索较多',
        zhHant: '線索較多',
        ja: '手がかり多め',
      );
    }
    return _clueValue(context);
  }

  String _recoveryValue(BuildContext context, int clueCount) {
    return clueCount > 0 ? _clueValue(context) : _waitingValue(context);
  }

  String _clueValue(BuildContext context) {
    return AppLocaleText.tr(
      context,
      en: 'A clue',
      zhHans: '有线索',
      zhHant: '有線索',
      ja: '手がかりあり',
    );
  }

  String _waitingValue(BuildContext context) {
    return AppLocaleText.tr(
      context,
      en: 'Watching',
      zhHans: '待观察',
      zhHant: '待觀察',
      ja: '観察中',
    );
  }

  static String _zhWeekday(int weekday) {
    return const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][weekday - 1];
  }

  static String _jaWeekday(int weekday) {
    return const ['月', '火', '水', '木', '金', '土', '日'][weekday - 1];
  }

  static String _englishWeekday(int weekday) {
    return const [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ][weekday - 1];
  }

  static String _englishMonth(int month) {
    return const [
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
      'December'
    ][month - 1];
  }
}

class _TodayHeroMetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _TodayHeroMetricChip({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 6, 7, 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.13),
            const Color(0xFFFEFDFF).withValues(alpha: 0.70),
          ],
        ),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AuroraColors.ink.withValues(alpha: 0.66),
                        fontSize: 9.5,
                        height: 1,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 3),
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: color,
                            fontSize: 11.5,
                            height: 1,
                            fontWeight: FontWeight.w800,
                          ),
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

class _TodaySignalOrbPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.55, size.height * 0.46);
    final radius = math.min(size.width, size.height) * 0.38;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [
          Color(0xFFFFB85B),
          Color(0xFF58E4D3),
          Color(0xFF6CA5FF),
          Color(0xFF8E67F4),
          Color(0xFFFFB85B),
        ],
      ).createShader(rect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    canvas.drawArc(rect, -math.pi * 0.08, math.pi * 1.76, false, glow);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [
          Color(0xFFFFB85B),
          Color(0xFF58E4D3),
          Color(0xFF6CA5FF),
          Color(0xFF8E67F4),
          Color(0xFFFFB85B),
        ],
      ).createShader(rect);
    canvas.drawArc(rect, -math.pi * 0.08, math.pi * 1.76, false, ring);

    final white = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.9);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.75),
      -math.pi * 0.05,
      math.pi * 1.66,
      false,
      white,
    );

    final path = Path()
      ..moveTo(size.width * 0.48, size.height * 0.42)
      ..cubicTo(size.width * 0.28, size.height * 0.48, size.width * 0.76,
          size.height * 0.52, size.width * 0.43, size.height * 0.68)
      ..cubicTo(size.width * 0.24, size.height * 0.78, size.width * 0.86,
          size.height * 0.76, size.width * 0.6, size.height * 1.05);
    final pathGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.38)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    canvas.drawPath(path, pathGlow);
    canvas.drawPath(path, white);

    final nodePaint = Paint()..color = Colors.white;
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = const Color(0xFF8AAEFF);
    for (final node in [
      Offset(center.dx + math.cos(-math.pi * 0.05) * radius,
          center.dy + math.sin(-math.pi * 0.05) * radius),
      Offset(center.dx + math.cos(math.pi * 0.66) * radius,
          center.dy + math.sin(math.pi * 0.66) * radius),
      Offset(center.dx + math.cos(math.pi * 1.12) * radius,
          center.dy + math.sin(math.pi * 1.12) * radius),
    ]) {
      canvas.drawCircle(node, 5.6, nodePaint);
      canvas.drawCircle(node, 5.6, border);
    }

    final sparkle = Paint()
      ..color = Colors.white.withValues(alpha: 0.88)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (final point in [
      Offset(size.width * 0.12, size.height * 0.24),
      Offset(size.width * 0.9, size.height * 0.25),
      Offset(size.width * 0.75, size.height * 0.08),
    ]) {
      canvas.drawLine(point.translate(-5, 0), point.translate(5, 0), sparkle);
      canvas.drawLine(point.translate(0, -5), point.translate(0, 5), sparkle);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TodayLeafPainter extends CustomPainter {
  final Color color;

  const _TodayLeafPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final stem = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final base = Offset(size.width * 0.5, size.height);
    canvas.drawLine(base, Offset(size.width * 0.48, size.height * 0.14), stem);
    for (var i = 0; i < 4; i++) {
      final y = size.height * (0.25 + i * 0.16);
      final left = i.isEven;
      final center = Offset(size.width * (left ? 0.37 : 0.62), y);
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..cubicTo(
          center.dx + (left ? -22 : 22),
          center.dy - 8,
          center.dx + (left ? -20 : 20),
          center.dy + 18,
          size.width * 0.48,
          y + 18,
        )
        ..cubicTo(
          center.dx + (left ? -10 : 10),
          center.dy + 9,
          center.dx + (left ? -8 : 8),
          center.dy - 2,
          center.dx,
          center.dy,
        );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TodayLeafPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _GlassIconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _GlassIconBadge({
    required this.icon,
    required this.color,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.92),
            color.withValues(alpha: 0.44),
          ],
        ),
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.20),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.58),
    );
  }
}

class _StatusSignalResult {
  final String mood;
  final String detail;
  final int energyLevel;
  final String note;

  const _StatusSignalResult({
    required this.mood,
    required this.detail,
    required this.energyLevel,
    required this.note,
  });
}

class _StatusSignalSheet extends StatefulWidget {
  const _StatusSignalSheet();

  @override
  State<_StatusSignalSheet> createState() => _StatusSignalSheetState();
}

class _StatusSignalSheetState extends State<_StatusSignalSheet> {
  final TextEditingController _noteController = TextEditingController();
  final String _detail = '';
  String _mood = 'tired';
  int _energyLevel = 0;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.of(context).pop(
      _StatusSignalResult(
        mood: _mood,
        detail: _detail,
        energyLevel: _energyLevel,
        note: _noteController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: FractionallySizedBox(
        heightFactor: bottomInset > 0 ? 0.98 : 1,
        alignment: Alignment.bottomCenter,
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(bottomInset > 0 ? 0 : 30),
          ),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFF9EF),
                  Color(0xFFF8F2FF),
                  Color(0xFFEFF5FF),
                  Colors.white,
                ],
                stops: [0, 0.44, 0.78, 1],
              ),
            ),
            child: SafeArea(
              top: true,
              child: Stack(
                children: [
                  Positioned(
                    top: 20,
                    right: 28,
                    child: Opacity(
                      opacity: 0.70,
                      child: SizedBox(
                        width: 150,
                        height: 150,
                        child: CustomPaint(
                          painter: _TodaySignalOrbPainter(),
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                    top: 132,
                    right: 116,
                    child: Opacity(
                      opacity: 0.18,
                      child: SizedBox(
                        width: 84,
                        height: 96,
                        child: CustomPaint(
                          painter: _TodayLeafPainter(
                            color: AuroraColors.purple,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 42, 18, 98),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocaleText.tr(
                            context,
                            en: 'State record',
                            zhHans: '状态记录',
                            zhHant: '狀態記錄',
                            ja: '状態記録',
                          ),
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(
                                color: AuroraColors.purple,
                                fontWeight: FontWeight.w900,
                                height: 0.96,
                              ),
                        ),
                        const SizedBox(height: 18),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 330),
                          child: Text(
                            AppLocaleText.tr(
                              context,
                              en: 'Use a few simple choices to record how you feel right now.',
                              zhHans: '用几个简单选择，记录你现在的感觉。',
                              zhHant: '用幾個簡單選擇，記錄你現在的感覺。',
                              ja: 'いくつかの簡単な選択で、今の感覚を残します。',
                            ),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: AuroraColors.muted,
                                  height: 1.42,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ),
                        const SizedBox(height: 34),
                        _VoiceGlassCard(
                          padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const _GlassIconBadge(
                                    icon: Icons.mood_rounded,
                                    color: AuroraColors.purple,
                                    size: 34,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    AppLocaleText.tr(
                                      context,
                                      en: 'Current state',
                                      zhHans: '此刻状态',
                                      zhHant: '此刻狀態',
                                      ja: '今の状態',
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: AuroraColors.purple,
                                          fontWeight: FontWeight.w900,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              _MoodOptionStrip(
                                selectedMood: _mood,
                                onSelect: (value) =>
                                    setState(() => _mood = value),
                              ),
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  const _GlassIconBadge(
                                    icon: Icons.bolt_rounded,
                                    color: AuroraColors.blue,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    AppLocaleText.tr(
                                      context,
                                      en: 'Energy',
                                      zhHans: '精力',
                                      zhHant: '精力',
                                      ja: 'エネルギー',
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: AuroraColors.purple,
                                          fontWeight: FontWeight.w900,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _EnergyLevelSelector(
                                value: _energyLevel,
                                onChanged: (value) =>
                                    setState(() => _energyLevel = value),
                              ),
                              const SizedBox(height: 20),
                              _StatusNoteField(controller: _noteController),
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding:
                                    const EdgeInsets.fromLTRB(12, 12, 12, 12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.54),
                                  borderRadius: BorderRadius.circular(17),
                                  border: Border.all(
                                    color: AuroraColors.line.withValues(
                                      alpha: 0.66,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const _GlassIconBadge(
                                      icon: Icons.smart_toy_rounded,
                                      color: AuroraColors.blue,
                                      size: 32,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        AppLocaleText.tr(
                                          context,
                                          en: 'AI hint: the more specific the state, the closer later small actions can be.',
                                          zhHans: 'AI 提示：状态越具体，后面的小行动会更贴近你。',
                                          zhHant: 'AI 提示：狀態越具體，後面的小行動會更貼近你。',
                                          ja: 'AIヒント：状態が具体的なほど、後の小さな行動が合いやすくなります。',
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: AuroraColors.muted,
                                              height: 1.35,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.auto_awesome_rounded,
                                      color: AuroraColors.purple,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: _VoicePrimaryAction(
                                      label: AppLocaleText.tr(
                                        context,
                                        en: 'Save as today’s signal',
                                        zhHans: '保存为今天的信号',
                                        zhHant: '保存為今天的信號',
                                        ja: '今日のシグナルに保存',
                                      ),
                                      icon: Icons.auto_awesome_rounded,
                                      onPressed: _save,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 3,
                                    child: _VoiceAction(
                                      icon: Icons.close_rounded,
                                      label: AppLocaleText.tr(
                                        context,
                                        en: 'Skip',
                                        zhHans: '先跳过',
                                        zhHant: '先跳過',
                                        ja: 'スキップ',
                                      ),
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MoodOptionStrip extends StatelessWidget {
  final String selectedMood;
  final ValueChanged<String> onSelect;

  const _MoodOptionStrip({
    required this.selectedMood,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final options = [
      _MoodOptionData(
          'steady',
          Icons.sentiment_satisfied_alt_rounded,
          AuroraColors.blue,
          AppLocaleText.tr(context,
              en: 'Calm', zhHans: '平静', zhHant: '平靜', ja: '平静')),
      _MoodOptionData(
          'good',
          Icons.mood_rounded,
          AuroraColors.gold,
          AppLocaleText.tr(context,
              en: 'Happy', zhHans: '开心', zhHant: '開心', ja: 'うれしい')),
      _MoodOptionData(
          'tired',
          Icons.sentiment_dissatisfied_rounded,
          AuroraColors.purple,
          AppLocaleText.tr(context,
              en: 'Tired', zhHans: '疲惫', zhHant: '疲憊', ja: '疲れ')),
      _MoodOptionData(
          'anxious',
          Icons.sentiment_very_dissatisfied_rounded,
          const Color(0xFFEE6BA7),
          AppLocaleText.tr(context,
              en: 'Anxious', zhHans: '焦虑', zhHant: '焦慮', ja: '不安')),
      _MoodOptionData(
          'scattered',
          Icons.blur_circular_rounded,
          AuroraColors.blue,
          AppLocaleText.tr(context,
              en: 'Messy', zhHans: '混乱', zhHant: '混亂', ja: '混乱')),
    ];

    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final option = options[index];
          return _StatusMoodCard(
            data: option,
            selected: selectedMood == option.value,
            onTap: () => onSelect(option.value),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemCount: options.length,
      ),
    );
  }
}

class _MoodOptionData {
  final String value;
  final IconData icon;
  final Color color;
  final String label;

  const _MoodOptionData(this.value, this.icon, this.color, this.label);
}

class _StatusMoodCard extends StatelessWidget {
  final _MoodOptionData data;
  final bool selected;
  final VoidCallback onTap;

  const _StatusMoodCard({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 60,
                height: 112,
                padding: const EdgeInsets.fromLTRB(6, 12, 6, 9),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: selected ? 0.66 : 0.44),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? AuroraColors.purple
                        : Colors.white.withValues(alpha: 0.68),
                    width: selected ? 1.4 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          data.color.withValues(alpha: selected ? 0.18 : 0.07),
                      blurRadius: selected ? 18 : 10,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 43,
                      height: 43,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          center: const Alignment(-0.35, -0.35),
                          radius: 0.92,
                          colors: [
                            Colors.white.withValues(alpha: 0.92),
                            data.color.withValues(alpha: 0.78),
                            data.color.withValues(alpha: 0.42),
                          ],
                        ),
                      ),
                      child: Icon(data.icon, color: Colors.white, size: 27),
                    ),
                    const Spacer(),
                    Text(
                      data.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: selected
                                ? AuroraColors.purple
                                : AuroraColors.muted,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: AuroraColors.purple,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 15,
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

class _EnergyLevelSelector extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _EnergyLevelSelector({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final labels = [
      AppLocaleText.tr(context,
          en: 'Low', zhHans: '偏低', zhHant: '偏低', ja: '低め'),
      AppLocaleText.tr(context,
          en: 'Okay', zhHans: '还好', zhHant: '還好', ja: 'まあまあ'),
      AppLocaleText.tr(context,
          en: 'Enough', zhHans: '很足', zhHant: '很足', ja: '十分'),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AuroraColors.line.withValues(alpha: 0.72)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 24,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 28,
                  right: 28,
                  child: Container(
                    height: 2,
                    color: AuroraColors.line.withValues(alpha: 0.72),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < 3; i++)
                      GestureDetector(
                        onTap: () => onChanged(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          width: value == i ? 28 : 11,
                          height: value == i ? 28 : 11,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: value == i
                                ? AuroraColors.purple
                                : AuroraColors.muted.withValues(alpha: 0.34),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.92),
                              width: value == i ? 5 : 0,
                            ),
                            boxShadow: value == i
                                ? [
                                    BoxShadow(
                                      color: AuroraColors.purple
                                          .withValues(alpha: 0.22),
                                      blurRadius: 16,
                                      offset: const Offset(0, 5),
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < labels.length; i++)
                GestureDetector(
                  onTap: () => onChanged(i),
                  child: Text(
                    labels[i],
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: value == i
                              ? AuroraColors.purple
                              : AuroraColors.muted,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusNoteField extends StatefulWidget {
  final TextEditingController controller;

  const _StatusNoteField({required this.controller});

  @override
  State<_StatusNoteField> createState() => _StatusNoteFieldState();
}

class _StatusNoteFieldState extends State<_StatusNoteField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final count = widget.controller.text.characters.length;
    return TextField(
      controller: widget.controller,
      maxLength: 80,
      minLines: 2,
      maxLines: 3,
      decoration: InputDecoration(
        counterText: '$count / 80',
        prefixIcon: const Icon(Icons.edit_rounded, color: AuroraColors.purple),
        hintText: AppLocaleText.tr(
          context,
          en: 'For example: I did not sleep well and kept moving all day.',
          zhHans: '例如：今天没睡好，一直在忙，脑子有点转不动。',
          zhHant: '例如：今天沒睡好，一直在忙，腦子有點轉不動。',
          ja: '例：よく眠れず、一日中忙しくて頭が回りにくい。',
        ),
        labelText: AppLocaleText.tr(
          context,
          en: 'Add a note (optional)',
          zhHans: '补一句（可选）',
          zhHant: '補一句（可選）',
          ja: '一言補足（任意）',
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.52),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide:
              BorderSide(color: AuroraColors.line.withValues(alpha: 0.7)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide:
              BorderSide(color: AuroraColors.line.withValues(alpha: 0.7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AuroraColors.purple, width: 1.4),
        ),
      ),
    );
  }
}

class _DiaryTimelineSection extends StatelessWidget {
  final List<RecentSignalModel> signals;
  final VoidCallback onOpenAllRecords;
  final void Function(RecentSignalModel signal) onOpenDialog;

  const _DiaryTimelineSection({
    required this.signals,
    required this.onOpenAllRecords,
    required this.onOpenDialog,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      for (final signal in signals)
        _DiaryTimelineItem.fromSignal(
          context,
          signal,
          onOpenDialog: () => onOpenDialog(signal),
        ),
    ]..sort((a, b) => b.sortKey.compareTo(a.sortKey));
    final visibleItems = items.take(4).toList(growable: false);
    return AuroraCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      borderRadius: BorderRadius.circular(20),
      color: Colors.white.withValues(alpha: 0.68),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _GlassIconBadge(
                icon: Icons.access_time_rounded,
                color: AuroraColors.purple,
                size: 28,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Today timeline',
                    zhHans: '今日时间线',
                    zhHant: '今日時間線',
                    ja: '今日のタイムライン',
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
          const SizedBox(height: 14),
          if (visibleItems.isEmpty)
            Container(
              key: const ValueKey('today-timeline-empty'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.46),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AuroraColors.line.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                AppLocaleText.tr(
                  context,
                  en: 'No timeline entries yet. Leave one small signal when you are ready.',
                  zhHans: '今天还没有时间线记录，想记的时候留下一点信号就好。',
                  zhHant: '今天還沒有時間線記錄，想記的時候留下一點信號就好。',
                  ja: '今日のタイムラインはまだ空です。残したい時に、小さなシグナルを一つ記録してみて。',
                ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AuroraColors.muted,
                      height: 1.5,
                    ),
              ),
            )
          else
            Stack(
              children: [
                Positioned(
                  left: 64,
                  top: 10,
                  bottom: 10,
                  child: Container(
                    width: 1.4,
                    decoration: BoxDecoration(
                      color: AuroraColors.purple.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                Column(
                  children: [
                    for (final item in visibleItems) ...[
                      _TimelineRow(item: item),
                      if (item != visibleItems.last) const SizedBox(height: 12),
                    ],
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DiaryTimelineItem {
  final int sortKey;
  final String time;
  final String userText;
  final String aiText;
  final List<_DiaryTag> tags;
  final VoidCallback? onMore;

  const _DiaryTimelineItem({
    this.sortKey = 0,
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
    final libraryContent = signal.content.trim();
    final userText = signal.isLibrarySaved && libraryContent.isEmpty
        ? AppLocaleText.tr(
            context,
            en: 'Saved from Library: ${signal.libraryPatternTitle ?? 'shared signal'}',
            zhHans: '来自信号库：${signal.libraryPatternTitle ?? '共有生活信号'}',
            zhHant: '來自信號庫：${signal.libraryPatternTitle ?? '共有生活信號'}',
            ja: 'シグナルライブラリから：${signal.libraryPatternTitle ?? '共有シグナル'}',
          )
        : signal.content;
    return _DiaryTimelineItem(
      sortKey: createdAt?.millisecondsSinceEpoch ?? 0,
      time: time,
      userText: userText,
      aiText: _timelineAiTextForSignal(context, signal),
      tags: _tagsForSignal(context, signal),
      onMore: signal.id == null ? null : onOpenDialog,
    );
  }

  static String _timelineAiTextForSignal(
    BuildContext context,
    RecentSignalModel signal,
  ) {
    final acknowledgement = _usableAiReply(signal.acknowledgement);
    if (acknowledgement != null) return acknowledgement;

    if (signal.isLibrarySaved) {
      return AppLocaleText.tr(
        context,
        en: 'Added from a Signal Library reference after your confirmation.',
        zhHans: '这条 SignalCard 来自信号库参考，并由你确认后加入。',
        zhHant: '這條 SignalCard 來自信號庫參考，並由你確認後加入。',
        ja: 'シグナルライブラリの参考から、確認後に追加したSignalCardです。',
      );
    }

    final content = signal.content.trim();
    if (content.contains('累') ||
        content.contains('疲') ||
        content.contains('耗')) {
      return AppLocaleText.tr(
        context,
        en: 'This looks like an energy signal. Keep it light for now.',
        zhHans: '这更像一条能量信号，今天先把动作放轻一点。',
        zhHant: '這更像一條能量信號，今天先把動作放輕一點。',
        ja: 'これはエネルギーのシグナルに見えます。今日は軽めでよさそうです。',
      );
    }
    if (content.contains('睡') || content.contains('休息')) {
      return AppLocaleText.tr(
        context,
        en: 'This may be pointing to recovery. Notice whether it repeats.',
        zhHans: '这可能在指向恢复，可以留意它是否反复出现。',
        zhHant: '這可能在指向恢復，可以留意它是否反覆出現。',
        ja: '回復に関係していそうです。繰り返すか見てみましょう。',
      );
    }
    if (content.contains('上班') ||
        content.contains('工作') ||
        content.contains('会议')) {
      return AppLocaleText.tr(
        context,
        en: 'This may be about work rhythm rather than a single event.',
        zhHans: '这可能不只是单个事件，而是今天工作节奏的一条线索。',
        zhHant: '這可能不只是單個事件，而是今天工作節奏的一條線索。',
        ja: '単発の出来事より、今日の仕事リズムの手がかりかもしれません。',
      );
    }
    return AppLocaleText.tr(
      context,
      en: 'This is one small signal from today.',
      zhHans: '这是今天的一条生活信号。',
      zhHant: '這是今天的一條生活信號。',
      ja: 'これは今日の小さな生活シグナルです。',
    );
  }

  static String? _usableAiReply(String? raw) {
    return sanitizeUserVisibleAiText(raw);
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
            en: 'Adapted',
            zhHans: '已改成我的说法',
            zhHant: '已改成我的說法',
            ja: '自分向けに調整',
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
                    color: AuroraColors.ink.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
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
              color: AuroraColors.purple.withValues(alpha: 0.52),
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
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.userText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AuroraColors.ink.withValues(alpha: 0.82),
                        fontSize: 13,
                        height: 1.28,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              _TimelineMiniButton(
                label: AppLocaleText.tr(
                  context,
                  en: 'AI chat',
                  zhHans: '和AI聊聊',
                  zhHant: '和AI聊聊',
                  ja: 'AI相談',
                ),
                onTap: item.onMore,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1EEFF).withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _GlassIconBadge(
                  icon: Icons.auto_awesome_rounded,
                  color: AuroraColors.blue,
                  size: 22,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    item.aiText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AuroraColors.muted,
                          height: 1.25,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
          ),
          if (item.tags.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: item.tags
                  .take(2)
                  .map((tag) => AuroraChip(label: tag.label, color: tag.color))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimelineMiniButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _TimelineMiniButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.74),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AuroraColors.line.withValues(alpha: 0.62)),
        ),
        child: Text(
          label,
          maxLines: 1,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AuroraColors.muted,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}

class _DiaryTag {
  final String label;
  final Color color;

  const _DiaryTag(this.label, this.color);
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

enum _VoiceDraftStage { ready, listening, paused, transcribing, editing }

class _VoiceTranscriptResult {
  final String content;

  const _VoiceTranscriptResult({
    required this.content,
  });
}

class _VoiceTranscriptService {
  static const MethodChannel _channel = MethodChannel('signalpath/speech');

  Future<void> start({required AppLanguage language}) async {
    try {
      await _channel.invokeMethod<void>('startVoiceRecognition', {
        'localeIdentifier': _speechLocaleIdentifier(language),
      });
    } on MissingPluginException {
      // Widget tests and non-iOS previews keep using the local draft UI.
    } on PlatformException {
      rethrow;
    }
  }

  String _speechLocaleIdentifier(AppLanguage language) {
    return switch (language) {
      AppLanguage.simplifiedChinese => 'zh-CN',
      AppLanguage.traditionalChinese => 'zh-TW',
      AppLanguage.japanese => 'ja-JP',
      AppLanguage.english => 'en-US',
    };
  }

  Future<String> stop() async {
    try {
      final result = await _channel.invokeMethod<String>(
        'stopVoiceRecognition',
      );
      return result?.trim() ?? '';
    } on MissingPluginException {
      return '';
    } on PlatformException {
      return '';
    }
  }

  Future<void> cancel() async {
    try {
      await _channel.invokeMethod<void>('cancelVoiceRecognition');
    } on MissingPluginException {
      // No-op outside platforms with a native recognizer.
    } on PlatformException {
      // Closing the sheet should never be blocked by native cleanup.
    }
  }
}

class _VoiceTranscriptSheet extends StatefulWidget {
  const _VoiceTranscriptSheet();

  @override
  State<_VoiceTranscriptSheet> createState() => _VoiceTranscriptSheetState();
}

class _VoiceTranscriptSheetState extends State<_VoiceTranscriptSheet> {
  final _speech = _VoiceTranscriptService();
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
    unawaited(_speech.cancel());
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

  Future<void> _startRecording() async {
    setState(() {
      _stage = _VoiceDraftStage.listening;
      _errorText = null;
      _elapsedSeconds = 0;
    });
    _startTimer();
    try {
      await _speech.start(language: AppLocaleText.resolve(context));
    } on PlatformException {
      if (!mounted) return;
      _timer?.cancel();
      setState(() {
        _stage = _VoiceDraftStage.ready;
        _errorText = AppLocaleText.tr(
          context,
          en: 'Voice recognition is unavailable. You can still type the transcript after stopping.',
          zhHans: '当前无法启动语音识别，停止后仍可以手动补转写内容。',
          zhHant: '目前無法啟動語音識別，停止後仍可以手動補轉寫內容。',
          ja: '音声認識を開始できません。停止後に文字起こしを手入力できます。',
        );
      });
    }
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

  Future<void> _stopToEdit() async {
    _timer?.cancel();
    setState(() {
      _stage = _VoiceDraftStage.transcribing;
      _errorText = null;
    });
    final transcript = await _speech.stop();
    if (!mounted) return;
    setState(() {
      _stage = _VoiceDraftStage.editing;
      if (transcript.isNotEmpty) {
        _controller.value = TextEditingValue(
          text: transcript,
          selection: TextSelection.collapsed(offset: transcript.length),
        );
      } else {
        _errorText = AppLocaleText.tr(
          context,
          en: 'No transcript was recognized. You can record again or type it manually.',
          zhHans: '没有识别到内容，可以重录或手动输入。',
          zhHant: '沒有識別到內容，可以重錄或手動輸入。',
          ja: '認識できませんでした。録り直すか手入力できます。',
        );
      }
    });
    if (transcript.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  Future<void> _recordAgain() async {
    _controller.clear();
    await _startRecording();
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
    Navigator.of(context).pop(
      _VoiceTranscriptResult(
        content: transcript,
      ),
    );
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
          en: 'Voice record',
          zhHans: '语音记录',
          zhHant: '語音記錄',
          ja: '音声記録',
        ),
      _VoiceDraftStage.listening => AppLocaleText.tr(
          context,
          en: 'Voice record',
          zhHans: '语音记录',
          zhHant: '語音記錄',
          ja: '音声記録',
        ),
      _VoiceDraftStage.paused => AppLocaleText.tr(
          context,
          en: 'Voice record',
          zhHans: '语音记录',
          zhHant: '語音記錄',
          ja: '音声記録',
        ),
      _VoiceDraftStage.transcribing => AppLocaleText.tr(
          context,
          en: 'Voice record',
          zhHans: '语音记录',
          zhHant: '語音記錄',
          ja: '音声記録',
        ),
      _VoiceDraftStage.editing => AppLocaleText.tr(
          context,
          en: 'Voice record',
          zhHans: '语音记录',
          zhHant: '語音記錄',
          ja: '音声記録',
        ),
    };
    final subtitle = switch (_stage) {
      _VoiceDraftStage.ready => AppLocaleText.tr(
          context,
          en: 'Say what is on your mind. AI will organize it into today’s signal.',
          zhHans: '说下此刻的想法，AI 会帮你整理成今天的信号。',
          zhHant: '說下此刻的想法，AI 會幫你整理成今天的信號。',
          ja: '今の考えを話すと、AI が今日のシグナルに整えます。',
        ),
      _VoiceDraftStage.listening => AppLocaleText.tr(
          context,
          en: 'Say what is on your mind. AI will organize it into today’s signal.',
          zhHans: '说下此刻的想法，AI 会帮你整理成今天的信号。',
          zhHant: '說下此刻的想法，AI 會幫你整理成今天的信號。',
          ja: '今の考えを話すと、AI が今日のシグナルに整えます。',
        ),
      _VoiceDraftStage.paused => AppLocaleText.tr(
          context,
          en: 'Paused. Resume when you are ready, or finish to review the transcript.',
          zhHans: '已暂停。可以继续录，也可以完成后确认转写。',
          zhHant: '已暫停。可以繼續錄，也可以完成後確認轉寫。',
          ja: '一時停止中です。再開するか、完了して文字起こしを確認できます。',
        ),
      _VoiceDraftStage.transcribing => AppLocaleText.tr(
          context,
          en: 'Finishing the recording and waiting for the final transcript.',
          zhHans: '正在完成录音，并等待最终识别内容。',
          zhHant: '正在完成錄音，並等待最終識別內容。',
          ja: '録音を終了し、最終の認識内容を待っています。',
        ),
      _VoiceDraftStage.editing => AppLocaleText.tr(
          context,
          en: 'Review the transcript. Edit only if something looks off.',
          zhHans: '确认识别内容；有不准的地方再手动修改。',
          zhHant: '確認識別內容；有不準的地方再手動修改。',
          ja: '認識内容を確認します。気になる箇所だけ編集してください。',
        ),
    };

    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: FractionallySizedBox(
        heightFactor: bottomInset > 0 ? 0.98 : 1,
        alignment: Alignment.bottomCenter,
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(bottomInset > 0 ? 0 : 30),
          ),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFF9EF),
                  Color(0xFFF7F2FF),
                  Color(0xFFEFF5FF),
                  Colors.white,
                ],
                stops: [0, 0.42, 0.76, 1],
              ),
            ),
            child: SafeArea(
              top: true,
              child: Stack(
                children: [
                  Positioned(
                    top: 24,
                    right: 24,
                    child: Opacity(
                      opacity: 0.72,
                      child: SizedBox(
                        width: 150,
                        height: 150,
                        child: CustomPaint(
                          painter: _TodaySignalOrbPainter(),
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                    top: 134,
                    right: 118,
                    child: Opacity(
                      opacity: 0.20,
                      child: SizedBox(
                        width: 78,
                        height: 90,
                        child: CustomPaint(
                          painter: _TodayLeafPainter(
                            color: AuroraColors.purple,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 36, 18, 96),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(
                                color: AuroraColors.purple,
                                fontWeight: FontWeight.w900,
                                height: 0.96,
                              ),
                        ),
                        const SizedBox(height: 18),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 310),
                          child: Text(
                            subtitle,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: AuroraColors.muted,
                                  height: 1.42,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        _VoiceRecordingPanel(
                          stage: _stage,
                          timerLabel: _timerLabel(),
                          onStart: () => unawaited(_startRecording()),
                          onPauseOrResume: _pauseOrResume,
                          onRecordAgain: () => unawaited(_recordAgain()),
                          onFinish: () => unawaited(_stopToEdit()),
                        ),
                        const SizedBox(height: 18),
                        _VoiceTranscriptPanel(
                          isEditing: _isEditing,
                          isTranscribing:
                              _stage == _VoiceDraftStage.transcribing,
                          controller: _controller,
                          focusNode: _focusNode,
                          errorText: _errorText,
                          onChanged: () {
                            setState(() => _errorText = null);
                          },
                          onSave: _saveTranscript,
                          onSkip: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 46,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AuroraColors.line.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VoiceRecordingPanel extends StatelessWidget {
  final _VoiceDraftStage stage;
  final String timerLabel;
  final VoidCallback onStart;
  final VoidCallback onPauseOrResume;
  final VoidCallback onRecordAgain;
  final VoidCallback onFinish;

  const _VoiceRecordingPanel({
    required this.stage,
    required this.timerLabel,
    required this.onStart,
    required this.onPauseOrResume,
    required this.onRecordAgain,
    required this.onFinish,
  });

  bool get _isReady => stage == _VoiceDraftStage.ready;
  bool get _isPaused => stage == _VoiceDraftStage.paused;
  bool get _isTranscribing => stage == _VoiceDraftStage.transcribing;

  @override
  Widget build(BuildContext context) {
    final status = AppLocaleText.tr(
      context,
      en: _isReady
          ? 'Ready to record'
          : _isPaused
              ? 'Paused'
              : _isTranscribing
                  ? 'Recognizing'
                  : 'Recording',
      zhHans: _isReady
          ? '准备录音'
          : _isPaused
              ? '已暂停'
              : _isTranscribing
                  ? '正在识别语音内容…'
                  : '正在录音',
      zhHant: _isReady
          ? '準備錄音'
          : _isPaused
              ? '已暫停'
              : _isTranscribing
                  ? '正在識別語音內容…'
                  : '正在錄音',
      ja: _isReady
          ? '録音の準備'
          : _isPaused
              ? '一時停止中'
              : _isTranscribing
                  ? '認識中…'
                  : '録音中',
    );

    return _VoiceGlassCard(
      padding: const EdgeInsets.fromLTRB(16, 36, 16, 18),
      child: Column(
        children: [
          SizedBox(
            height: 150,
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _VoiceWavePainter(
                      color:
                          _isReady ? AuroraColors.muted : AuroraColors.purple,
                    ),
                  ),
                ),
                const _VoiceMicOrb(),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            status,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AuroraColors.purple,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            timerLabel,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AuroraColors.purple,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
          ),
          const SizedBox(height: 26),
          if (_isReady)
            _VoicePrimaryAction(
              key: const ValueKey('voice-start-recording-action'),
              label: AppLocaleText.tr(
                context,
                en: 'Start recording',
                zhHans: '开始录音',
                zhHant: '開始錄音',
                ja: '録音を開始',
              ),
              icon: Icons.mic_rounded,
              expanded: true,
              onPressed: onStart,
            )
          else if (_isTranscribing)
            _VoicePrimaryAction(
              label: AppLocaleText.tr(
                context,
                en: 'Recognizing...',
                zhHans: '正在识别…',
                zhHant: '正在識別…',
                ja: '認識中…',
              ),
              icon: Icons.graphic_eq_rounded,
              expanded: true,
              onPressed: null,
            )
          else
            Row(
              children: [
                Expanded(
                  child: _VoiceAction(
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
                    onPressed: onPauseOrResume,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _VoiceAction(
                    icon: Icons.replay_rounded,
                    label: AppLocaleText.tr(
                      context,
                      en: 'Restart',
                      zhHans: '重录',
                      zhHant: '重錄',
                      ja: '録り直す',
                    ),
                    onPressed: onRecordAgain,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _VoicePrimaryAction(
                    key: const ValueKey('voice-stop-edit-action'),
                    label: AppLocaleText.tr(
                      context,
                      en: 'Finish recording',
                      zhHans: '完成录音',
                      zhHant: '完成錄音',
                      ja: '録音を完了',
                    ),
                    icon: Icons.check_rounded,
                    onPressed: onFinish,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _VoiceTranscriptPanel extends StatelessWidget {
  final bool isEditing;
  final bool isTranscribing;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? errorText;
  final VoidCallback onChanged;
  final VoidCallback onSave;
  final VoidCallback onSkip;

  const _VoiceTranscriptPanel({
    required this.isEditing,
    required this.isTranscribing,
    required this.controller,
    required this.focusNode,
    required this.errorText,
    required this.onChanged,
    required this.onSave,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final transcript = controller.text.trim();
    final hasTranscript = transcript.isNotEmpty;
    return _VoiceGlassCard(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _GlassIconBadge(
                icon: Icons.chat_bubble_rounded,
                size: 34,
                color: AuroraColors.purple,
              ),
              const SizedBox(width: 10),
              Text(
                AppLocaleText.tr(
                  context,
                  en: 'Transcript',
                  zhHans: '识别内容',
                  zhHant: '識別內容',
                  ja: '認識内容',
                ),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AuroraColors.purple,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            focusNode: focusNode,
            enabled: isEditing,
            minLines: 3,
            maxLines: 5,
            autofocus: false,
            onChanged: (_) => onChanged(),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AuroraColors.ink,
                  height: 1.55,
                  fontWeight: FontWeight.w500,
                ),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.62),
              hintText: AppLocaleText.tr(
                context,
                en: isTranscribing
                    ? 'Recognizing voice content...'
                    : isEditing
                        ? 'The final transcript appears here. You can edit it.'
                        : 'Finish recording to see the transcript here.',
                zhHans: isTranscribing
                    ? '正在识别语音内容…'
                    : isEditing
                        ? '最终识别内容会显示在这里，你也可以手动修改。'
                        : '完成录音后，识别内容会显示在这里。',
                zhHant: isTranscribing
                    ? '正在識別語音內容…'
                    : isEditing
                        ? '最終識別內容會顯示在這裡，你也可以手動修改。'
                        : '完成錄音後，識別內容會顯示在這裡。',
                ja: isTranscribing
                    ? '音声内容を認識しています…'
                    : isEditing
                        ? '最終の認識内容がここに表示され、手入力でも直せます。'
                        : '録音完了後、認識内容がここに表示されます。',
              ),
              errorText: errorText,
              suffixIcon: isEditing
                  ? const Icon(
                      Icons.edit_rounded,
                      color: AuroraColors.muted,
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(
                  color: AuroraColors.line.withValues(alpha: 0.82),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(
                  color: AuroraColors.line.withValues(alpha: 0.82),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(
                  color: AuroraColors.purple,
                  width: 1.4,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(
                  color: AuroraColors.line.withValues(alpha: 0.60),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _VoiceExtractionPanel(
            transcript: transcript,
            isTranscribing: isTranscribing,
            hasTranscript: hasTranscript,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _VoicePrimaryAction(
                  key: const ValueKey('voice-save-transcript-action'),
                  label: AppLocaleText.tr(
                    context,
                    en: 'Save as today’s signal',
                    zhHans: '保存为今天的信号',
                    zhHant: '保存為今天的信號',
                    ja: '今日のシグナルに保存',
                  ),
                  icon: Icons.auto_awesome_rounded,
                  onPressed: onSave,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _VoiceAction(
                  key: const ValueKey('voice-skip-action'),
                  icon: Icons.close_rounded,
                  label: AppLocaleText.tr(
                    context,
                    en: 'Skip',
                    zhHans: '先跳过',
                    zhHant: '先跳過',
                    ja: 'スキップ',
                  ),
                  onPressed: onSkip,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VoiceExtractionPanel extends StatelessWidget {
  final String transcript;
  final bool isTranscribing;
  final bool hasTranscript;

  const _VoiceExtractionPanel({
    required this.transcript,
    required this.isTranscribing,
    required this.hasTranscript,
  });

  @override
  Widget build(BuildContext context) {
    final tags = hasTranscript ? _tagsForTranscript(context, transcript) : [];
    final summary = hasTranscript
        ? _summaryForTranscript(context, transcript)
        : AppLocaleText.tr(
            context,
            en: isTranscribing
                ? 'AI extraction will appear after recognition finishes.'
                : 'Finish recording or type a transcript before AI extraction.',
            zhHans: isTranscribing ? '识别完成后再为你提炼。' : '识别或手动输入内容后，再为你提炼。',
            zhHant: isTranscribing ? '識別完成後再為你提煉。' : '識別或手動輸入內容後，再為你提煉。',
            ja: isTranscribing ? '認識完了後に要点を抽出します。' : '認識または入力後に要点を抽出します。',
          );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AuroraColors.purple.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _GlassIconBadge(
                icon: Icons.auto_awesome_rounded,
                size: 28,
                color: AuroraColors.purple,
              ),
              const SizedBox(width: 8),
              Text(
                AppLocaleText.tr(
                  context,
                  en: 'AI extraction',
                  zhHans: 'AI 提炼',
                  zhHant: 'AI 提煉',
                  ja: 'AI 抽出',
                ),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AuroraColors.purple,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            summary,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AuroraColors.ink.withValues(alpha: 0.82),
                  height: 1.42,
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in tags)
                  _VoiceTagChip(
                    icon: tag.$1,
                    label: tag.$2,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _summaryForTranscript(BuildContext context, String text) {
    final clipped = text.length > 34 ? '${text.substring(0, 34)}…' : text;
    return AppLocaleText.tr(
      context,
      en: 'Core meaning: $clipped',
      zhHans: '核心意思：$clipped',
      zhHant: '核心意思：$clipped',
      ja: '要点：$clipped',
    );
  }

  List<(IconData, String)> _tagsForTranscript(
      BuildContext context, String text) {
    final lower = text.toLowerCase();
    final tags = <(IconData, String)>[];

    void add(IconData icon, String label) {
      if (tags.length < 3 && !tags.any((tag) => tag.$2 == label)) {
        tags.add((icon, label));
      }
    }

    if (_containsAny(lower, const ['累', '疲', 'tired', 'しんど', '疲れ'])) {
      add(
        Icons.nightlight_round,
        AppLocaleText.tr(
          context,
          en: 'Tired',
          zhHans: '有点累',
          zhHant: '有點累',
          ja: '少し疲れ',
        ),
      );
    }
    if (_containsAny(lower, const ['开心', '高兴', '轻松', 'happy', '楽', 'うれし'])) {
      add(
        Icons.mood_rounded,
        AppLocaleText.tr(
          context,
          en: 'Positive',
          zhHans: '感觉不错',
          zhHant: '感覺不錯',
          ja: 'よい感覚',
        ),
      );
    }
    if (_containsAny(lower, const ['任务', '工作', '会议', 'task', 'work', '会議'])) {
      add(
        Icons.assignment_rounded,
        AppLocaleText.tr(
          context,
          en: 'Workload',
          zhHans: '任务负荷',
          zhHant: '任務負荷',
          ja: '作業量',
        ),
      );
    }
    if (_containsAny(lower, const ['睡', '休息', '放松', 'sleep', 'rest', '休'])) {
      add(
        Icons.eco_rounded,
        AppLocaleText.tr(
          context,
          en: 'Needs rest',
          zhHans: '需要恢复',
          zhHant: '需要恢復',
          ja: '休息が必要',
        ),
      );
    }
    if (tags.isEmpty) {
      add(
        Icons.auto_awesome_rounded,
        AppLocaleText.tr(
          context,
          en: 'Voice signal',
          zhHans: '语音信号',
          zhHant: '語音信號',
          ja: '音声シグナル',
        ),
      );
    }
    return tags;
  }

  bool _containsAny(String text, List<String> needles) {
    return needles.any(text.contains);
  }
}

class _VoiceGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _VoiceGlassCard({
    required this.child,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.90)),
        boxShadow: [
          BoxShadow(
            color: AuroraColors.purple.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _VoiceMicOrb extends StatelessWidget {
  const _VoiceMicOrb();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.34, -0.45),
          radius: 0.92,
          colors: [
            Colors.white.withValues(alpha: 0.96),
            const Color(0xFFE8C7FF).withValues(alpha: 0.86),
            AuroraColors.blue.withValues(alpha: 0.72),
          ],
          stops: const [0.02, 0.52, 1],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.88)),
        boxShadow: [
          BoxShadow(
            color: AuroraColors.purple.withValues(alpha: 0.24),
            blurRadius: 34,
            spreadRadius: 6,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.92),
            blurRadius: 12,
            spreadRadius: -2,
            offset: const Offset(-15, -16),
          ),
        ],
      ),
      child: const Icon(
        Icons.mic_rounded,
        color: Colors.white,
        size: 58,
      ),
    );
  }
}

class _VoiceTagChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _VoiceTagChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AuroraColors.line.withValues(alpha: 0.70)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AuroraColors.purple),
          const SizedBox(width: 6),
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
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 23),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AuroraColors.ink,
          backgroundColor: Colors.white.withValues(alpha: 0.54),
          side: BorderSide(color: AuroraColors.line.withValues(alpha: 0.70)),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

class _VoicePrimaryAction extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  final bool expanded;

  const _VoicePrimaryAction({
    super.key,
    required this.label,
    required this.onPressed,
    required this.icon,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: expanded ? double.infinity : null,
      height: 54,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 22),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label),
        ),
        style: FilledButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: AuroraColors.purple,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 0,
          textStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
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
