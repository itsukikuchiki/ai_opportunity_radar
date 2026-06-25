import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/di/app_dependencies.dart';
import '../../../core/i18n/app_locale_text.dart';
import '../../../core/models/today_models.dart';
import '../../../shared/widgets/aurora_ui.dart';

class TodayDialogPage extends StatefulWidget {
  final String captureId;

  const TodayDialogPage({
    super.key,
    required this.captureId,
  });

  @override
  State<TodayDialogPage> createState() => _TodayDialogPageState();
}

class _TodayDialogPageState extends State<TodayDialogPage> {
  final TextEditingController _controller = TextEditingController();
  final List<LightDialogTurnModel> _turns = [];
  List<String> _suggestedPrompts = const [];
  RecentSignalModel? _signal;
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = context.read<AppDependencies>().todayRepository;
    final signal = await repo.getCaptureById(widget.captureId);
    if (!mounted) return;

    setState(() {
      _signal = signal;
      _isLoading = false;
      _error = signal == null ? 'not_found' : null;
      if (signal != null && (signal.acknowledgement ?? '').trim().isNotEmpty) {
        _turns.add(
          LightDialogTurnModel(
            role: 'assistant',
            text: signal.acknowledgement!.trim(),
          ),
        );
      }
    });
  }

  Future<void> _send([String? preset]) async {
    final signal = _signal;
    final text = (preset ?? _controller.text).trim();
    if (signal == null || text.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
      _error = null;
      _turns.add(LightDialogTurnModel(role: 'user', text: text));
      _controller.clear();
    });

    try {
      final result = await context
          .read<AppDependencies>()
          .todayRepository
          .continueLightDialog(
            signal: signal,
            history: List<LightDialogTurnModel>.from(_turns),
            userMessage: text,
          );

      if (!mounted) return;
      setState(() {
        _turns.add(LightDialogTurnModel(role: 'assistant', text: result.reply));
        _suggestedPrompts = result.suggestedPrompts;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'send_failed';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final signal = _signal;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          AuroraPage(
            child: SafeArea(
              bottom: false,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : signal == null
                      ? _NotFoundState(onBack: _goBack)
                      : Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
                              child: Row(
                                children: [
                                  AuroraIconButton(
                                    icon: Icons.arrow_back_rounded,
                                    tooltip: MaterialLocalizations.of(context)
                                        .backButtonTooltip,
                                    onPressed: _goBack,
                                  ),
                                  const Spacer(),
                                  Icon(Icons.more_horiz_rounded,
                                      color: AuroraColors.muted
                                          .withValues(alpha: 0.86)),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 0, 20, 18),
                                children: [
                                  _SignalSummaryCard(signal: signal),
                                  const SizedBox(height: 26),
                                  _DialogSectionTitle(
                                    text: AppLocaleText.tr(
                                      context,
                                      en: 'AI reflection and response',
                                      zhHans: 'AI 回顾与回应',
                                      zhHant: 'AI 回顧與回應',
                                      ja: 'AI の振り返りと応答',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ..._buildTurns(context),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _DialogQuickAction(
                                          icon: Icons.lightbulb_outline_rounded,
                                          label: AppLocaleText.tr(
                                            context,
                                            en: 'Keep thinking',
                                            zhHans: '继续想一想',
                                            zhHant: '繼續想一想',
                                            ja: 'もう少し考える',
                                          ),
                                          onPressed: _isSending
                                              ? null
                                              : () => _send(
                                                    AppLocaleText.tr(
                                                      context,
                                                      en: 'Help me think one step further.',
                                                      zhHans: '帮我再往下想一步。',
                                                      zhHant: '幫我再往下想一步。',
                                                      ja: 'もう一歩整理して。',
                                                    ),
                                                  ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _DialogQuickAction(
                                          icon: Icons.refresh_rounded,
                                          label: AppLocaleText.tr(
                                            context,
                                            en: 'New angle',
                                            zhHans: '换个角度',
                                            zhHant: '換個角度',
                                            ja: '別の角度',
                                          ),
                                          onPressed: _isSending
                                              ? null
                                              : () => _send(
                                                    AppLocaleText.tr(
                                                      context,
                                                      en: 'Can you look at this from another angle?',
                                                      zhHans: '可以换个角度看这件事吗？',
                                                      zhHant: '可以換個角度看這件事嗎？',
                                                      ja: '別の角度から見られますか？',
                                                    ),
                                                  ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _DialogQuickAction(
                                          icon: Icons.notes_rounded,
                                          label: AppLocaleText.tr(
                                            context,
                                            en: 'Summarize',
                                            zhHans: '帮我总结',
                                            zhHant: '幫我總結',
                                            ja: 'まとめる',
                                          ),
                                          onPressed: _isSending
                                              ? null
                                              : () => _send(
                                                    AppLocaleText.tr(
                                                      context,
                                                      en: 'Please summarize this into one small observation.',
                                                      zhHans: '请帮我总结成一个小观察。',
                                                      zhHant: '請幫我總結成一個小觀察。',
                                                      ja: '小さな観察としてまとめて。',
                                                    ),
                                                  ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_suggestedPrompts.isNotEmpty) ...[
                                    const SizedBox(height: 14),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: _suggestedPrompts
                                          .map(
                                            (prompt) => AuroraPillButton(
                                              icon: Icons
                                                  .lightbulb_outline_rounded,
                                              label: prompt,
                                              onPressed: _isSending
                                                  ? null
                                                  : () => _send(prompt),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ],
                                  const SizedBox(height: 18),
                                  _DialogMicroActionCard(signal: signal),
                                  const SizedBox(height: 18),
                                  _RelatedEvidenceStrip(signal: signal),
                                ],
                              ),
                            ),
                            _ComposerBar(
                              controller: _controller,
                              isSending: _isSending,
                              onSend: _send,
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

  List<Widget> _buildTurns(BuildContext context) {
    final widgets = <Widget>[];
    for (final turn in _turns) {
      final isAssistant = turn.role == 'assistant';
      widgets.add(
        Row(
          mainAxisAlignment:
              isAssistant ? MainAxisAlignment.start : MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isAssistant) ...[
              const AuroraSoftIconCircle(
                icon: Icons.auto_awesome_rounded,
                color: AuroraColors.purple,
                size: 42,
                iconSize: 20,
              ),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: isAssistant
                      ? const LinearGradient(
                          colors: [Color(0xFFF6F2FF), Color(0xFFFFFCFF)],
                        )
                      : const LinearGradient(
                          colors: [Color(0xFFEAF3FF), Color(0xFFF7FBFF)],
                        ),
                  borderRadius: BorderRadius.circular(22),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.86)),
                  boxShadow: [
                    BoxShadow(
                      color: (isAssistant
                              ? AuroraColors.purple
                              : AuroraColors.blue)
                          .withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Text(
                  turn.text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AuroraColors.ink,
                        height: 1.55,
                      ),
                ),
              ),
            ),
            if (!isAssistant) ...[
              const SizedBox(width: 10),
              const AuroraSoftIconCircle(
                icon: Icons.person_rounded,
                color: AuroraColors.blue,
                size: 42,
                iconSize: 20,
              ),
            ],
          ],
        ),
      );
    }
    if (_error != null) {
      widgets.add(
        AuroraCard(
          padding: const EdgeInsets.all(14),
          child: Text(
            AppLocaleText.tr(
              context,
              en: 'This reply did not go through. You can try again.',
              zhHans: '这次没有顺利回复，你可以再试一次。',
              zhHant: '這次沒有順利回覆，你可以再試一次。',
              ja: '今回はうまく返せませんでした。もう一度試せます。',
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.today);
    }
  }
}

class _SignalSummaryCard extends StatelessWidget {
  final RecentSignalModel signal;

  const _SignalSummaryCard({required this.signal});

  @override
  Widget build(BuildContext context) {
    return AuroraCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AuroraSoftIconCircle(
                icon: Icons.auto_awesome_rounded,
                color: AuroraColors.purple,
                size: 54,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AuroraChip(
                      label: AppLocaleText.tr(
                        context,
                        en: 'Signal in focus',
                        zhHans: '正在探讨的信号',
                        zhHant: '正在探討的信號',
                        ja: '見ているシグナル',
                      ),
                      color: AuroraColors.purple,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      signal.content,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AuroraColors.ink,
                            fontWeight: FontWeight.w800,
                            height: 1.28,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.more_horiz_rounded,
                  color: AuroraColors.muted.withValues(alpha: 0.78)),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.66),
              borderRadius: BorderRadius.circular(18),
              border:
                  Border.all(color: AuroraColors.line.withValues(alpha: 0.62)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded,
                        size: 17, color: AuroraColors.muted),
                    const SizedBox(width: 6),
                    Text(
                      AppLocaleText.tr(
                        context,
                        en: 'Recorded',
                        zhHans: '记录时间',
                        zhHant: '記錄時間',
                        ja: '記録時間',
                      ),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AuroraColors.muted,
                          ),
                    ),
                    const Spacer(),
                    Text(
                      _formatTime(signal.createdAt),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AuroraColors.ink,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
                if ((signal.observation ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    '“${signal.observation!.trim()}”',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AuroraColors.ink,
                          height: 1.45,
                        ),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if ((signal.emotion ?? '').isNotEmpty)
                      AuroraChip(label: signal.emotion!),
                    if ((signal.friction ?? '').isNotEmpty)
                      AuroraChip(
                          label: signal.friction!, color: AuroraColors.orange),
                    if ((signal.energyLoad ?? '').isNotEmpty)
                      AuroraChip(
                          label: signal.energyLoad!, color: AuroraColors.mint),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '--:--';
    final local = time.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _DialogSectionTitle extends StatelessWidget {
  final String text;

  const _DialogSectionTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.auto_awesome_rounded, color: AuroraColors.purple),
        const SizedBox(width: 8),
        Text(
          text,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AuroraColors.ink,
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}

class _DialogQuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _DialogQuickAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AuroraColors.ink,
        backgroundColor: Colors.white.withValues(alpha: 0.74),
        side: BorderSide(color: AuroraColors.line.withValues(alpha: 0.72)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}

class _DialogMicroActionCard extends StatelessWidget {
  final RecentSignalModel signal;

  const _DialogMicroActionCard({required this.signal});

  @override
  Widget build(BuildContext context) {
    final raw = signal.content.trim();
    final shortSignal =
        raw.length > 18 ? '${raw.substring(0, 18).trim()}...' : raw;
    final actionText = AppLocaleText.tr(
      context,
      en: 'Turn this into one very small try for today.',
      zhHans: '把刚才说到的线索，变成今天一个很小的尝试。',
      zhHant: '把剛才說到的線索，變成今天一個很小的嘗試。',
      ja: '今話した手がかりを、今日の小さな試みにします。',
    );
    final suggested = shortSignal.isEmpty
        ? actionText
        : '$actionText\n${AppLocaleText.tr(
            context,
            en: 'Signal: ',
            zhHans: '围绕：',
            zhHant: '圍繞：',
            ja: 'シグナル：',
          )}$shortSignal';

    void showSaved(String text) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }

    return AuroraCard(
      padding: const EdgeInsets.all(16),
      gradient: const LinearGradient(
        colors: [Color(0xFFFFFCFF), Color(0xFFF5F1FF)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AuroraSoftIconCircle(
                icon: Icons.science_rounded,
                color: AuroraColors.purple,
                size: 40,
                iconSize: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Make this a small action?',
                    zhHans: '要不要变成一个小行动？',
                    zhHant: '要不要變成一個小行動？',
                    ja: '小さな行動にしますか？',
                  ),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AuroraColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            suggested,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AuroraColors.ink,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _DialogActionDecision(
                icon: Icons.today_rounded,
                label: AppLocaleText.tr(
                  context,
                  en: 'Try today',
                  zhHans: '今天试试',
                  zhHant: '今天試試',
                  ja: '今日試す',
                ),
                onPressed: () => showSaved(AppLocaleText.tr(
                  context,
                  en: 'Saved as a small action for today.',
                  zhHans: '已保存为今天的小行动。',
                  zhHant: '已保存為今天的小行動。',
                  ja: '今日の小さな行動として保存しました。',
                )),
              ),
              _DialogActionDecision(
                icon: Icons.science_rounded,
                label: AppLocaleText.tr(
                  context,
                  en: 'Add to week',
                  zhHans: '加到本周实验',
                  zhHant: '加到本週實驗',
                  ja: '今週に追加',
                ),
                onPressed: () => showSaved(AppLocaleText.tr(
                  context,
                  en: 'Saved for this week.',
                  zhHans: '已加入本周实验方向。',
                  zhHant: '已加入本週實驗方向。',
                  ja: '今週の試みに追加しました。',
                )),
              ),
              _DialogActionDecision(
                icon: Icons.bookmark_rounded,
                label: AppLocaleText.tr(
                  context,
                  en: 'Observation only',
                  zhHans: '只保存为观察',
                  zhHant: '只保存為觀察',
                  ja: '観察だけ保存',
                ),
                onPressed: () => showSaved(AppLocaleText.tr(
                  context,
                  en: 'Saved as an observation.',
                  zhHans: '已保存为观察。',
                  zhHant: '已保存為觀察。',
                  ja: '観察として保存しました。',
                )),
              ),
              _DialogActionDecision(
                icon: Icons.close_rounded,
                label: AppLocaleText.tr(
                  context,
                  en: 'Not now',
                  zhHans: '不要行动',
                  zhHant: '不要行動',
                  ja: '今はしない',
                ),
                onPressed: () => showSaved(AppLocaleText.tr(
                  context,
                  en: 'Kept as dialogue only.',
                  zhHans: '已仅保留为对话。',
                  zhHant: '已僅保留為對話。',
                  ja: '会話として残しました。',
                )),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DialogActionDecision extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _DialogActionDecision({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AuroraColors.purple,
        backgroundColor: Colors.white.withValues(alpha: 0.76),
        side: BorderSide(color: AuroraColors.purple.withValues(alpha: 0.14)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class _RelatedEvidenceStrip extends StatelessWidget {
  final RecentSignalModel signal;

  const _RelatedEvidenceStrip({required this.signal});

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        Icons.battery_3_bar_rounded,
        AppLocaleText.tr(context,
            en: 'Energy', zhHans: '能量', zhHant: '能量', ja: 'エネルギー'),
        signal.energyLoad ??
            AppLocaleText.tr(context,
                en: 'low', zhHans: '偏低', zhHant: '偏低', ja: '低め'),
        AuroraColors.mint,
      ),
      (
        Icons.repeat_rounded,
        AppLocaleText.tr(context,
            en: 'Pattern', zhHans: '长期模式', zhHant: '長期模式', ja: 'パターン'),
        signal.scene ??
            AppLocaleText.tr(context,
                en: 'stable', zhHans: '稳定模式', zhHant: '穩定模式', ja: '安定'),
        AuroraColors.orange,
      ),
      (
        Icons.work_history_rounded,
        AppLocaleText.tr(context,
            en: 'This week', zhHans: '本周趋势', zhHant: '本週趨勢', ja: '今週'),
        signal.friction ??
            AppLocaleText.tr(context,
                en: 'rising', zhHans: '压力上升', zhHant: '壓力上升', ja: '上昇'),
        AuroraColors.blue,
      ),
      (
        Icons.science_rounded,
        AppLocaleText.tr(context,
            en: 'Experiment', zhHans: '小实验', zhHant: '小實驗', ja: '小さな試み'),
        AppLocaleText.tr(context,
            en: 'try gently', zhHans: '轻量尝试', zhHant: '輕量嘗試', ja: '軽く試す'),
        AuroraColors.purple,
      ),
    ];
    return AuroraCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hub_rounded, color: AuroraColors.purple),
              const SizedBox(width: 8),
              Text(
                AppLocaleText.tr(
                  context,
                  en: 'Related evidence',
                  zhHans: '相关依据',
                  zhHant: '相關依據',
                  ja: '関連する手がかり',
                ),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AuroraColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const Spacer(),
              Text(
                AppLocaleText.tr(
                  context,
                  en: 'More',
                  zhHans: '查看更多',
                  zhHant: '查看更多',
                  ja: 'もっと見る',
                ),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AuroraColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AuroraColors.muted),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: items
                  .map(
                    (item) => Container(
                      width: 132,
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            item.$4.withValues(alpha: 0.13),
                            Colors.white.withValues(alpha: 0.74),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.80),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AuroraSoftIconCircle(
                            icon: item.$1,
                            color: item.$4,
                            size: 34,
                            iconSize: 18,
                          ),
                          const SizedBox(height: 8),
                          Text(item.$2,
                              style: Theme.of(context).textTheme.labelSmall),
                          Text(
                            item.$3,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposerBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  const _ComposerBar({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
        child: AuroraCard(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: AppLocaleText.tr(
                      context,
                      en: 'Keep sharing your thoughts...',
                      zhHans: '继续分享你的想法...',
                      zhHant: '繼續分享你的想法...',
                      ja: '考えをもう少し続ける...',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: isSending ? null : onSend,
                style: FilledButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(14),
                  backgroundColor: AuroraColors.purple,
                ),
                child: isSending
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_upward_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotFoundState extends StatelessWidget {
  final VoidCallback onBack;

  const _NotFoundState({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: AuroraCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AuroraSoftIconCircle(
                icon: Icons.search_off_rounded,
                color: AuroraColors.orange,
                size: 72,
              ),
              const SizedBox(height: 18),
              Text(
                AppLocaleText.tr(
                  context,
                  en: 'This entry could not be found.',
                  zhHans: '没找到这条记录。',
                  zhHant: '沒找到這條記錄。',
                  ja: 'この記録は見つかりませんでした。',
                ),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AuroraColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 14),
              AuroraPillButton(
                icon: Icons.arrow_back_rounded,
                label: AppLocaleText.tr(
                  context,
                  en: 'Back to Today',
                  zhHans: '回到今天',
                  zhHant: '回到今天',
                  ja: 'Today に戻る',
                ),
                filled: true,
                onPressed: onBack,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
