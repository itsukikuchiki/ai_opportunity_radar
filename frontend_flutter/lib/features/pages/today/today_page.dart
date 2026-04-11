import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/i18n/app_locale_text.dart';
import '../../../core/models/today_models.dart';
import '../me/me_view_model.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/empty_state_block.dart';
import '../../../shared/widgets/section_header.dart';
import 'today_view_model.dart';

class TodayPage extends StatefulWidget {
  const TodayPage({super.key});

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayInsightResult {
  final String observation;
  final String nextStep;
  final String topCategory;

  const _TodayInsightResult({
    required this.observation,
    required this.nextStep,
    required this.topCategory,
  });
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
    final theme = Theme.of(context);
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

    return Scaffold(
      appBar: AppBar(
        title: Text(_todayTitle(context)),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
          const SizedBox(height: 8),
          _CaptureInputCard(
            controller: _controller,
            isSubmitting: state.isCaptureSubmitting,
            onChanged: vm.updateInput,
            onSubmit: () => vm.submitCapture(),
          ),
          if (state.hasError) ...[
            const SizedBox(height: 16),
            Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _displayErrorText(context, state.errorMessage),
                  style: TextStyle(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
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
          const SizedBox(height: 20),
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
            const SizedBox(height: 8),
            _TimelineList(signals: todaySignals),
          ],
          if (state.isInitialLoading) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
          ],
          if (!state.isInitialLoading) ...[
            const SizedBox(height: 20),
            _DailyObservationCard(
                entryCount: todaySignals.length,
                summary: _buildDailyObservation(context, todaySignals),
              ),
            const SizedBox(height: 16),
            _TryNextCard(
              summary: _buildTryNext(context, todaySignals),
            ),
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
    final language = AppLocaleText.resolve(context);

    switch (language) {
      case AppLanguage.simplifiedChinese:
        const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
        return '${weekdays[now.weekday - 1]} · ${now.month}月${now.day}日';
      case AppLanguage.traditionalChinese:
        const weekdays = ['週一', '週二', '週三', '週四', '週五', '週六', '週日'];
        return '${weekdays[now.weekday - 1]} · ${now.month}月${now.day}日';
      case AppLanguage.japanese:
        const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
        return '${weekdays[now.weekday - 1]}曜日 · ${now.month}月${now.day}日';
      case AppLanguage.english:
        const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        return '${weekdays[now.weekday - 1]} · ${months[now.month - 1]} ${now.day}';
    }
  }

  String _buildTodaySummary(
    BuildContext context,
    List<RecentSignalModel> todaySignals,
    bool isLoading,
  ) {
    if (isLoading) {
      return AppLocaleText.tr(
        context,
        en: 'Gathering today’s signals...',
        zhHans: '正在整理今天的线索',
        zhHant: '正在整理今天的線索',
        ja: '今日の手がかりを整理しています',
      );
    }

    if (todaySignals.isEmpty) {
      return AppLocaleText.tr(
        context,
        en: 'No entries yet today',
        zhHans: '今天还没有记录',
        zhHant: '今天還沒有記錄',
        ja: '今日はまだ記録がありません',
      );
    }

    if (todaySignals.length == 1) {
      return AppLocaleText.tr(
        context,
        en: '1 entry today',
        zhHans: '今天已记录 1 条',
        zhHant: '今天已記錄 1 條',
        ja: '今日は 1 件記録済み',
      );
    }

    final count = todaySignals.length;
    return AppLocaleText.tr(
      context,
      en: '$count entries today',
      zhHans: '今天已记录 $count 条',
      zhHant: '今天已記錄 $count 條',
      ja: '今日は $count 件記録済み',
    );
  }

  String _buildDailyObservation(
    BuildContext context,
    List<RecentSignalModel> signals,
  ) {
    return _buildTodayInsight(context, signals).observation;
  }

  String _buildTryNext(
    BuildContext context,
    List<RecentSignalModel> signals,
  ) {
    return _buildTodayInsight(context, signals).nextStep;
  }

  _TodayInsightResult _buildTodayInsight(
    BuildContext context,
    List<RecentSignalModel> signals,
  ) {
    if (signals.isEmpty) {
      return _TodayInsightResult(
        topCategory: 'empty',
        observation: AppLocaleText.tr(
          context,
          en: 'Today is still blank. One small real moment is enough to start.',
          zhHans: '今天还是空白的，先留下一件真实发生的小事就够了。',
          zhHant: '今天還是空白的，先留下一件真實發生的小事就夠了。',
          ja: '今日はまだ空白です。まずは本当に起きた小さなことを一つ残せば十分です。',
        ),
        nextStep: AppLocaleText.tr(
          context,
          en: 'Today, just note one small moment that made you stop, repeat, or feel something.',
          zhHans: '今天只要先记下一件让你停顿了一下、重复了一下，或者让你有感觉的小事就好。',
          zhHant: '今天只要先記下一件讓你停頓了一下、重複了一下，或者讓你有感覺的小事就好。',
          ja: '今日はまず、少し立ち止まったこと、繰り返したこと、何か感じたことを一つ残してみてください。',
        ),
      );
    }

    if (signals.length == 1) {
      final latest = signals.first.content;
      return _TodayInsightResult(
        topCategory: 'single',
        observation: AppLocaleText.tr(
          context,
          en: 'Today’s first clue is “$latest.” You do not need to explain it yet.',
          zhHans: '今天的第一条线索是“$latest”。先不用急着解释它。',
          zhHant: '今天的第一條線索是「$latest」。先不用急著解釋它。',
          ja: '今日の最初の手がかりは「$latest」です。まだ説明しなくて大丈夫です。',
        ),
        nextStep: AppLocaleText.tr(
          context,
          en: 'If something similar happens again before the day ends, just note it one more time.',
          zhHans: '如果今天结束前它又出现一次，再顺手记下来就好。',
          zhHant: '如果今天結束前它又出現一次，再順手記下來就好。',
          ja: '今日が終わる前に似たことがもう一度起きたら、その時また軽く残しておけば十分です。',
        ),
      );
    }

    return _TodayInsightResult(
      topCategory: 'general',
      observation: AppLocaleText.tr(
        context,
        en: 'Today’s records are already starting to gather around a similar kind of issue.',
        zhHans: '今天的记录已经开始慢慢聚到同一类问题周围了。',
        zhHant: '今天的記錄已經開始慢慢聚到同一類問題周圍了。',
        ja: '今日の記録は、少しずつ同じ種類の問題のまわりに集まり始めています。',
      ),
      nextStep: AppLocaleText.tr(
        context,
        en: 'Before today ends, just notice whether anything happened in the same way more than once.',
        zhHans: '在今天结束前，先留意一下有没有哪件事已经不是第一次这样发生了。',
        zhHant: '在今天結束前，先留意一下有沒有哪件事已經不是第一次這樣發生了。',
        ja: '今日が終わる前に、同じ形で二度以上起きたことがあったかどうかだけ見てみてください。',
      ),
    );
  }

  String _displayErrorText(BuildContext context, String? raw) {
    if (raw == 'empty_input') {
      return AppLocaleText.tr(
        context,
        en: 'Please enter today’s observation before submitting.',
        zhHans: '请先输入今天的观察，再提交。',
        zhHant: '請先輸入今天的觀察，再提交。',
        ja: '送信する前に、今日の観察を入力してください。',
      );
    }
    return raw ?? '';
  }
}

class _CaptureInputCard extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;
  final bool isSubmitting;

  const _CaptureInputCard({
    required this.controller,
    required this.onChanged,
    required this.onSubmit,
    required this.isSubmitting,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocaleText.tr(
                context,
                en: 'Write it down',
                zhHans: '记一下',
                zhHant: '記一下',
                ja: '書き留める',
              ),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              AppLocaleText.tr(
                context,
                en: 'Just write down what happened today',
                zhHans: '刚刚发生了什么，记下来就好',
                zhHant: '剛剛發生了什麼，記下來就好',
                ja: 'さっき起きたことを、そのまま残してみて',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              onChanged: onChanged,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: AppLocaleText.tr(
                  context,
                  en: 'What small thing stood out to you today?',
                  zhHans: '今天有什么让你在意的小事？',
                  zhHant: '今天有什麼讓你在意的小事？',
                  ja: '今日はどんな小さなことが気になった？',
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: isSubmitting ? null : onSubmit,
                icon: isSubmitting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.edit_outlined),
                label: Text(
                  isSubmitting
                      ? AppLocaleText.tr(
                          context,
                          en: 'Saving...',
                          zhHans: '记录中...',
                          zhHant: '記錄中...',
                          ja: '記録中...',
                        )
                      : AppLocaleText.tr(
                          context,
                          en: 'Save',
                          zhHans: '记一下',
                          zhHant: '記一下',
                          ja: '記録する',
                        ),
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
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocaleText.tr(
                context,
                en: 'One small follow-up',
                zhHans: '补充一个小问题',
                zhHant: '補充一個小問題',
                ja: '小さな補足質問',
              ),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(question.question),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: question.options
                  .map(
                    (o) => OutlinedButton(
                      onPressed: isSubmitting ? null : () => onSubmit(o.value),
                      child: Text(o.label),
                    ),
                  )
                  .toList(),
            ),
            if (isSubmitting) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimelineList extends StatelessWidget {
  final List<RecentSignalModel> signals;

  const _TimelineList({
    required this.signals,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < signals.length; i++) ...[
          _TimelineItem(
            signal: signals[i],
            aiText: signals[i].acknowledgement ??
                AppLocaleText.tr(
                  context,
                  en: 'Let’s leave this here for now.',
                  zhHans: '先把这个点放在这里。',
                  zhHant: '先把這個點放在這裡。',
                  ja: 'ひとまず、この点をここに置いておこう。',
                ),
          ),
          if (i != signals.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final RecentSignalModel signal;
  final String aiText;

  const _TimelineItem({
    required this.signal,
    required this.aiText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeText = _buildTimeText(signal.createdAt);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 52,
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              timeText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            children: [
              _UserEntryBubble(text: signal.content),
              const SizedBox(height: 8),
              _AiResponseBubble(text: aiText),
            ],
          ),
        ),
      ],
    );
  }

  String _buildTimeText(DateTime? time) {
    if (time == null) return '--:--';
    final local = time.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _UserEntryBubble extends StatelessWidget {
  final String text;

  const _UserEntryBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            text,
            style: theme.textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}

class _AiResponseBubble extends StatelessWidget {
  final String text;

  const _AiResponseBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.auto_awesome_outlined,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyObservationCard extends StatelessWidget {
  final int entryCount;
  final String summary;

  const _DailyObservationCard({
    required this.entryCount,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = entryCount;

    return Card(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.visibility_outlined,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocaleText.tr(
                      context,
                      en: 'A small observation from today',
                      zhHans: '今天的小观察',
                      zhHant: '今天的小觀察',
                      ja: '今日の小さな観察',
                    ),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppLocaleText.tr(
                      context,
                      en: 'Today has $count entr${count == 1 ? 'y' : 'ies'}',
                      zhHans: '今天记录了 $count 条',
                      zhHant: '今天記錄了 $count 條',
                      ja: '今日は $count 件記録しました',
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(summary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TryNextCard extends StatelessWidget {
  final String summary;

  const _TryNextCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.30),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.track_changes_outlined,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocaleText.tr(
                      context,
                      en: 'Something to try next',
                      zhHans: '今天可以先试试',
                      zhHant: '今天可以先試試',
                      ja: '今日、先に試してみること',
                    ),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(summary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
