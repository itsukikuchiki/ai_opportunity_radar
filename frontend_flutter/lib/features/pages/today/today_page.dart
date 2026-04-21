import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/i18n/app_locale_text.dart';
import '../../../core/models/today_models.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/empty_state_block.dart';
import '../../../shared/widgets/section_header.dart';
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

  @override
  void initState() {
    super.initState();
    final vm = context.read<TodayViewModel>();
    _controller = TextEditingController(text: vm.state.inputText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openMePage() {
    context.go(AppRoutes.me);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TodayViewModel>();
    final meVm = context.watch<MeViewModel>();
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

    final observationText = _resolveObservationText(context, state, todaySignals);
    final tryNextText = _resolveTryNextText(context, state, todaySignals);

    return Scaffold(
      appBar: AppBar(
        title: Text(_todayTitle(context)),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          AppHeader(
            title: _todayTitle(context),
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
          ),
          if (state.hasError) ...[
            const SizedBox(height: 16),
            _InlineStatusCard(
              icon: Icons.error_outline,
              text: _displayErrorText(context, state.errorMessage),
              isError: true,
            ),
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
              onOpenDialog: (signal) => context.go(
                '${AppRoutes.todayDialog}/${signal.id}',
              ),
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

  List<RecentSignalModel> _todayOnlySignals(List<RecentSignalModel> all) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    return all.where((signal) {
      final createdAt = signal.createdAt?.toLocal();
      if (createdAt == null) return false;
      return !createdAt.isBefore(start) && createdAt.isBefore(end);
    }).toList()
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
      zhHans: 'Today',
      zhHant: 'Today',
      ja: 'Today',
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
        return AppLocaleText.tr(context, en: 'work and tasks', zhHans: '工作与任务', zhHant: '工作與任務', ja: '仕事とタスク');
      case 'emotion_stress':
        return AppLocaleText.tr(context, en: 'emotions and stress', zhHans: '情绪与压力', zhHant: '情緒與壓力', ja: '感情とストレス');
      case 'relationships':
        return AppLocaleText.tr(context, en: 'relationships and interaction', zhHans: '关系与相处', zhHant: '關係與相處', ja: '人間関係と付き合い方');
      case 'time_rhythm':
        return AppLocaleText.tr(context, en: 'time and daily rhythm', zhHans: '时间与生活节奏', zhHant: '時間與生活節奏', ja: '時間と生活リズム');
      case 'health_body':
        return AppLocaleText.tr(context, en: 'health and physical state', zhHans: '健康与身体状态', zhHant: '健康與身體狀態', ja: '健康と身体の状態');
      case 'money_spending':
        return AppLocaleText.tr(context, en: 'money and spending', zhHans: '金钱与消费', zhHant: '金錢與消費', ja: 'お金と消費');
      case 'learning_growth_expression':
        return AppLocaleText.tr(context, en: 'learning, growth, and expression', zhHans: '学习、成长与表达', zhHant: '學習、成長與表達', ja: '学び・成長・表現');
      case 'open':
        return AppLocaleText.tr(context, en: 'whatever comes up', zhHans: '想到什么记什么', zhHant: '想到什麼記什麼', ja: '思いついたことから記録する');
      default:
        return AppLocaleText.tr(context, en: 'not set yet', zhHans: '暂未设置', zhHant: '暫未設定', ja: '未設定');
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
      en: 'Today’s entries',
      zhHans: '今天的记录',
      zhHant: '今天的記錄',
      ja: '今日の記録',
    );
  }

  String _todayRecordsSubtitle(BuildContext context) {
    return AppLocaleText.tr(
      context,
      en: 'Only what happened today',
      zhHans: '这里只显示今天 0 点到 24 点之间的内容',
      zhHant: '這裡只顯示今天 0 點到 24 點之間的內容',
      ja: 'ここには今日 0 時から 24 時までの内容だけが表示されます',
    );
  }

  String _todayDateText(BuildContext context) {
    final now = DateTime.now();
    final languageCode = Localizations.localeOf(context).languageCode.toLowerCase();

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

  String _fallbackObservation(BuildContext context, List<RecentSignalModel> signals) {
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

  String _fallbackSuggestion(BuildContext context, List<RecentSignalModel> signals) {
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

  const _CaptureInputCard({
    required this.controller,
    required this.isSubmitting,
    required this.onChanged,
    required this.onSubmit,
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
              en: 'Write down one small thing from today',
              zhHans: '记下一件今天的小事',
              zhHant: '記下一件今天的小事',
              ja: '今日の小さなことを一つ記してみて',
            ),
            style: Theme.of(context).textTheme.titleMedium,
          ),
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
                en: 'For example: I felt irritated during a meeting, but dinner helped me settle a bit.',
                zhHans: '例如：开会时很烦，但晚上吃饭后又缓回来一点。',
                zhHant: '例如：開會時很煩，但晚上吃飯後又緩回來一點。',
                ja: 'たとえば：会議中はかなりしんどかったけれど、夜ごはんで少し戻れた。',
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
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
                    onPressed: isSubmitting ? null : () => onSubmit(option.value),
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

  const _TimelineList({
    required this.signals,
    required this.onOpenDialog,
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

  const _SignalCard({
    required this.signal,
    required this.onOpenDialog,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metaTags = <String>[
      if ((signal.emotion ?? '').isNotEmpty) signal.emotion!,
      if ((signal.intensity ?? '').isNotEmpty) signal.intensity!,
      ...signal.sceneTags.take(2),
    ];

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
          Text(
            signal.content,
            style: theme.textTheme.bodyLarge,
          ),
          if ((signal.acknowledgement ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(140),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                signal.acknowledgement!,
                style: theme.textTheme.bodyMedium,
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
          const SizedBox(height: 10),
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
              en: 'A small signal from today',
              zhHans: '今天的一条小线索',
              zhHant: '今天的一條小線索',
              ja: '今日の小さな手がかり',
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

class _MetaChip extends StatelessWidget {
  final String label;

  const _MetaChip({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
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
