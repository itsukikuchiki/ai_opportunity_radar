import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/app_router.dart';
import '../../../core/i18n/app_locale_text.dart';
import '../../../core/models/today_models.dart';
import '../../../core/purchases/purchase_controller.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/empty_state_block.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/signal_illustration_kit.dart';
import '../../paywall/paywall_sheet.dart';
import '../me/me_view_model.dart';
import 'today_state.dart';
import 'today_view_model.dart';

class TodayPage extends StatefulWidget {
  const TodayPage({super.key});

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  late final TextEditingController _controller;
  int _lastCaptureSuccessTick = 0;
  int _lastFollowupSuccessTick = 0;
  String? _localPlanBlock;

  @override
  void initState() {
    super.initState();
    final vm = context.read<TodayViewModel>();
    _controller = TextEditingController(text: vm.state.inputText);
    _loadLocalPlanBlock();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openMePage() {
    context.go(AppRoutes.me);
  }

  Future<void> _loadLocalPlanBlock() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _localPlanBlock = prefs.getString('local_plan_block_current');
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TodayViewModel>();
    final meVm = context.watch<MeViewModel>();
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

    final observationText =
        _resolveObservationText(context, state, todaySignals);
    final tryNextText = _resolveTryNextText(context, state, todaySignals);

    return Scaffold(
      appBar: AppBar(
        title: Text(_todayTitle(context)),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: AppLocaleText.tr(
              context,
              en: 'Open diary',
              zhHans: '打开手帐',
              zhHant: '打開手帳',
              ja: '手帳を開く',
            ),
            onPressed: () => context.push(AppRoutes.todayDiary),
            icon: const Icon(Icons.menu_book_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          AppHeader(
            title: _todayHeaderTitle(context),
            subtitle: _todayDateText(context),
            summary: _buildTodaySummary(
              context,
              todaySignals,
              state.isInitialLoading,
            ),
            preferenceText: _preferenceText(context, meVm.selectedRepeatArea),
            onTapPreference: _openMePage,
          ),
          const SizedBox(height: 10),
          _CaptureInputCard(
            controller: _controller,
            isSubmitting: state.isCaptureSubmitting,
            onChanged: vm.updateInput,
            onSubmit: () => vm.submitCapture(),
            onVoiceDraft: () => _openVoiceTranscriptDraft(context, vm),
            onPredictSignal: () => vm.createPredictedSignal(
              language: AppLocaleText.resolve(context),
            ),
          ),
          if (state.hasError) ...[
            const SizedBox(height: 16),
            _InlineStatusCard(
              icon: Icons.error_outline,
              text: _displayErrorText(context, state.errorMessage),
              isError: true,
            ),
          ],
          if (pendingDraftCount > 0) ...[
            const SizedBox(height: 16),
            _DraftSyncCard(
              count: pendingDraftCount,
              isSyncing: state.isDraftSyncing,
              message: state.draftSyncMessage,
              onRetry: () => _retryDraftSync(context, vm),
            ),
          ] else if (state.draftSyncMessage == 'sync_complete') ...[
            const SizedBox(height: 16),
            _InlineStatusCard(
              icon: Icons.cloud_done_outlined,
              text: AppLocaleText.tr(
                context,
                en: 'Sync completed.',
                zhHans: '同步完成。',
                zhHant: '同步完成。',
                ja: '同期が完了しました。',
              ),
            ),
          ],
          if ((_localPlanBlock ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            _PlanBlockCard(text: _localPlanBlock!),
          ],
          if (state.pendingQuestion != null) ...[
            const SizedBox(height: 16),
            _FollowupQuestionCard(
              question: state.pendingQuestion!,
              isSubmitting: state.isFollowupSubmitting,
              onSubmit: vm.submitFollowup,
            ),
          ],
          const SizedBox(height: 22),
          if (todaySignals.isEmpty && !state.isInitialLoading) ...[
            EmptyStateBlock(
              icon: Icons.timeline_rounded,
              title: _emptyTitleText(context),
              subtitle: _emptySubtitleText(context),
            ),
          ] else ...[
            SectionHeader(
              title: _todayRecordsTitle(context),
              subtitle: _todayRecordsSubtitle(context),
            ),
            const SizedBox(height: 10),
            _TimelineList(
              signals: todaySignals,
              onConfirm: vm.confirmSignal,
              onOpenDialog: (signal) {
                final captureId = signal.signalCardId ?? signal.id;
                if (captureId == null || captureId.trim().isEmpty) return;
                _openTodayDialog(context, purchase, captureId);
              },
            ),
          ],
          if (state.isInitialLoading) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
          ],
          if (!state.isInitialLoading) ...[
            const SizedBox(height: 22),
            _DailyObservationCard(summary: observationText),
            const SizedBox(height: 16),
            _TryNextCard(summary: tryNextText),
          ],
        ],
      ),
    );
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
    final controller = TextEditingController();
    final focusNode = FocusNode();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          AppLocaleText.tr(
            context,
            en: 'Voice transcript',
            zhHans: '语音转写草稿',
            zhHant: '語音轉寫草稿',
            ja: '音声メモの文字起こし',
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.tonalIcon(
              onPressed: () {
                focusNode.requestFocus();
              },
              icon: const Icon(Icons.mic_none_rounded),
              label: Text(
                AppLocaleText.tr(
                  context,
                  en: 'Start voice input',
                  zhHans: '开始语音录入',
                  zhHant: '開始語音錄入',
                  ja: '音声入力を始める',
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              AppLocaleText.tr(
                context,
                en: 'Use the keyboard microphone or system dictation, then edit the transcript before saving.',
                zhHans: '点击后可使用键盘麦克风或系统听写，保存前还能编辑转写内容。',
                zhHant: '點擊後可使用鍵盤麥克風或系統聽寫，保存前還能編輯轉寫內容。',
                ja: 'キーボードのマイクやシステム音声入力を使い、保存前に文字を編集できます。',
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              focusNode: focusNode,
              minLines: 4,
              maxLines: 6,
              autofocus: true,
              decoration: InputDecoration(
                helperText: AppLocaleText.tr(
                  context,
                  en: 'Only transcript text is saved. Audio is not saved or uploaded.',
                  zhHans: '只保存转写文字，不保存或上传音频。',
                  zhHant: '只保存轉寫文字，不保存或上傳音訊。',
                  ja: '保存するのは文字だけです。音声は保存・アップロードしません。',
                ),
                hintText: AppLocaleText.tr(
                  context,
                  en: 'Edit the transcript before saving...',
                  zhHans: '保存前可以先编辑转写内容……',
                  zhHant: '保存前可以先編輯轉寫內容……',
                  ja: '保存前に文字起こしを編集できます…',
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              AppLocaleText.tr(
                context,
                en: 'Later',
                zhHans: '稍后',
                zhHant: '稍後',
                ja: 'あとで',
              ),
            ),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(
              AppLocaleText.tr(
                context,
                en: 'Save transcript',
                zhHans: '保存转写',
                zhHant: '保存轉寫',
                ja: '文字起こしを保存',
              ),
            ),
          ),
        ],
      ),
    );
    controller.dispose();
    focusNode.dispose();
    if (result == null || result.trim().isEmpty) return;
    await vm.submitVoiceTranscript(result);
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

class _CaptureInputCard extends StatelessWidget {
  final TextEditingController controller;
  final bool isSubmitting;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;
  final VoidCallback onVoiceDraft;
  final VoidCallback onPredictSignal;

  const _CaptureInputCard({
    required this.controller,
    required this.isSubmitting,
    required this.onChanged,
    required this.onSubmit,
    required this.onVoiceDraft,
    required this.onPredictSignal,
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
              en: 'Signal Composer',
              zhHans: 'Signal Composer',
              zhHant: 'Signal Composer',
              ja: 'Signal Composer',
            ),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            AppLocaleText.tr(
              context,
              en: 'Drop a private signal here. It can be unfinished, messy, or just one sentence.',
              zhHans: '把一个私密信号先放在这里就好。可以不完整、很乱，或只有一句话。',
              zhHant: '把一個私密信號先放在這裡就好。可以不完整、很亂，或只有一句話。',
              ja: 'プライベートなシグナルをここに置いておくだけで大丈夫。未整理でも、一文だけでも構いません。',
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          const CompactSignalPathVisual(height: 58),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            minLines: 3,
            maxLines: 6,
            onChanged: onChanged,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: AppLocaleText.tr(
                context,
                en: 'One signal from today... maybe a drain, a recovery clue, or something you want to remember.',
                zhHans: '今天的一个信号……可能是消耗、恢复线索，或只是想留下来的事。',
                zhHant: '今天的一個信號……可能是消耗、恢復線索，或只是想留下來的事。',
                ja: '今日のシグナルを一つ…消耗、回復の手がかり、残しておきたいことなど。',
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: isSubmitting ? null : onVoiceDraft,
                icon: const Icon(Icons.mic_none_rounded),
                label: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Voice draft',
                    zhHans: '语音草稿',
                    zhHant: '語音草稿',
                    ja: '音声メモ',
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: isSubmitting ? null : onPredictSignal,
                icon: const Icon(Icons.auto_awesome_outlined),
                label: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Suggest a signal',
                    zhHans: '预判一个信号',
                    zhHant: '預判一個信號',
                    ja: 'シグナルを提案',
                  ),
                ),
              ),
              FilledButton(
                onPressed: isSubmitting ? null : onSubmit,
                child: Text(
                  isSubmitting
                      ? AppLocaleText.tr(
                          context,
                          en: 'Saving...',
                          zhHans: '保存中…',
                          zhHant: '保存中…',
                          ja: '保存中…',
                        )
                      : AppLocaleText.tr(
                          context,
                          en: 'Save',
                          zhHans: '保存',
                          zhHant: '保存',
                          ja: '保存',
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

class _DraftSyncCard extends StatelessWidget {
  final int count;
  final bool isSyncing;
  final String? message;
  final VoidCallback onRetry;

  const _DraftSyncCard({
    required this.count,
    required this.isSyncing,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return _UnifiedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_sync_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: '$count item(s) are saved on this device first. Nothing is lost; sync can happen when the connection is back.',
                    zhHans: '$count 条内容已先保存在这台设备上。不会丢，网络恢复后可以同步。',
                    zhHant: '$count 條內容已先保存在這台裝置上。不會丟，網路恢復後可以同步。',
                    ja: '$count 件はまずこの端末に保存されています。消えません。接続後に同期できます。',
                  ),
                ),
              ),
              TextButton(
                onPressed: isSyncing ? null : onRetry,
                child: isSyncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        AppLocaleText.tr(
                          context,
                          en: 'Sync',
                          zhHans: '同步',
                          zhHant: '同步',
                          ja: '同期',
                        ),
                      ),
              ),
            ],
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message == 'sync_complete'
                  ? AppLocaleText.tr(
                      context,
                      en: 'Sync completed.',
                      zhHans: '同步完成。',
                      zhHant: '同步完成。',
                      ja: '同期が完了しました。',
                    )
                  : AppLocaleText.tr(
                      context,
                      en: 'Still saved on this device. Please try again when the connection is stable.',
                      zhHans: '内容仍已保存在本机。网络稳定后可以再试一次。',
                      zhHant: '內容仍已保存在本機。網路穩定後可以再試一次。',
                      ja: '内容は端末に保存されています。接続が安定したら、もう一度試せます。',
                    ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ],
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
              onPressed: signal.id == null ? null : onOpenDialog,
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
