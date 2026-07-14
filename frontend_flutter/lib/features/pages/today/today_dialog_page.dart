// ignore_for_file: unused_element

import 'dart:math' as math;

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
      if (signal != null) {
        final opening = (signal.acknowledgement ?? '').trim().isNotEmpty
            ? signal.acknowledgement!.trim()
            : _openingQuestion(context, signal);
        _turns.add(
          LightDialogTurnModel(
            role: 'assistant',
            text: opening,
          ),
        );
      }
    });
  }

  String _openingQuestion(BuildContext context, RecentSignalModel signal) {
    final short = _compactSignalText(signal.content);
    return AppLocaleText.tr(
      context,
      en: 'You mentioned “$short”. Has this been showing up often lately?',
      zhHans: '你说“$short”，这种情况最近常出现吗？',
      zhHant: '你說「$short」，這種情況最近常出現嗎？',
      ja: '「$short」と書いていましたね。最近よく出ていますか？',
    );
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
                      : Stack(
                          children: [
                            const Positioned(
                              right: -16,
                              top: 34,
                              width: 210,
                              height: 210,
                              child: IgnorePointer(
                                child: _DialogHeroArt(),
                              ),
                            ),
                            Column(
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(18, 4, 18, 0),
                                  child: Row(
                                    children: [
                                      Material(
                                        color: Colors.white
                                            .withValues(alpha: 0.62),
                                        shape: const CircleBorder(),
                                        child: InkWell(
                                          onTap: _goBack,
                                          customBorder: const CircleBorder(),
                                          child: const SizedBox(
                                            width: 54,
                                            height: 54,
                                            child: Icon(
                                              Icons.chevron_left_rounded,
                                              size: 34,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: ListView(
                                    padding: const EdgeInsets.fromLTRB(
                                        20, 34, 20, 18),
                                    children: [
                                      Text(
                                        AppLocaleText.tr(
                                          context,
                                          en: 'Chat With AI',
                                          zhHans: '和 AI 聊聊',
                                          zhHant: '和 AI 聊聊',
                                          ja: 'AI と話す',
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .displaySmall
                                            ?.copyWith(
                                              color: AuroraColors.purple,
                                              fontSize: 42,
                                              fontWeight: FontWeight.w900,
                                              height: 1.05,
                                            ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        AppLocaleText.tr(
                                          context,
                                          en: 'Say a little more around this entry and see what it may still be pointing to.',
                                          zhHans: '围绕这条记录，多说一点，看看它还在提示你什么。',
                                          zhHant: '圍繞這條記錄，多說一點，看看它還在提示你什麼。',
                                          ja: 'この記録について少し話して、何を示しているか見てみます。',
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              color: AuroraColors.ink
                                                  .withValues(alpha: 0.72),
                                              height: 1.5,
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                      const SizedBox(height: 24),
                                      _SignalSummaryCard(signal: signal),
                                      const SizedBox(height: 22),
                                      ..._buildTurns(context),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _DialogQuickAction(
                                              icon: Icons.chat_bubble_rounded,
                                              label: AppLocaleText.tr(
                                                context,
                                                en: 'Say more',
                                                zhHans: '再说一点',
                                                zhHant: '再說一點',
                                                ja: 'もう少し',
                                              ),
                                              onPressed: _isSending
                                                  ? null
                                                  : () => _send(
                                                        AppLocaleText.tr(
                                                          context,
                                                          en: 'Help me think one step further.',
                                                          zhHans:
                                                              '帮我围绕这条记录再多看一点。',
                                                          zhHant:
                                                              '幫我圍繞這條記錄再多看一點。',
                                                          ja: 'もう一歩整理して。',
                                                        ),
                                                      ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: _DialogQuickAction(
                                              icon:
                                                  Icons.directions_run_rounded,
                                              label: AppLocaleText.tr(
                                                context,
                                                en: 'Small action',
                                                zhHans: '看看小行动',
                                                zhHant: '看看小行動',
                                                ja: '小さな行動',
                                              ),
                                              onPressed: _isSending
                                                  ? null
                                                  : () => _send(
                                                        AppLocaleText.tr(
                                                          context,
                                                          en: 'What is one lighter action I can try today?',
                                                          zhHans:
                                                              '今天可以试一个更轻的小动作吗？',
                                                          zhHant:
                                                              '今天可以試一個更輕的小動作嗎？',
                                                          ja: '今日できる軽い行動は？',
                                                        ),
                                                      ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: _DialogQuickAction(
                                              icon: Icons.bookmark_rounded,
                                              label: AppLocaleText.tr(
                                                context,
                                                en: 'Summarize',
                                                zhHans: '总结这条',
                                                zhHant: '總結這條',
                                                ja: '要約',
                                              ),
                                              onPressed: _isSending
                                                  ? null
                                                  : () => _send(
                                                        AppLocaleText.tr(
                                                          context,
                                                          en: 'Please summarize this into one small observation.',
                                                          zhHans:
                                                              '请帮我总结成一个小观察。',
                                                          zhHant:
                                                              '請幫我總結成一個小觀察。',
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
                                      const SizedBox(height: 16),
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
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFBA86FF), Color(0xFF7795FF)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AuroraColors.purple.withValues(alpha: 0.22),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'AI',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  gradient: isAssistant
                      ? null
                      : const LinearGradient(
                          colors: [Color(0xFFF1ECFF), Color(0xFFF7F6FF)],
                        ),
                  color:
                      isAssistant ? Colors.white.withValues(alpha: 0.74) : null,
                  borderRadius: BorderRadius.circular(18),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.86)),
                  boxShadow: [
                    BoxShadow(
                      color: (isAssistant
                              ? AuroraColors.purple
                              : AuroraColors.blue)
                          .withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
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
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFB27BFF), Color(0xFF7B6FF2)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AuroraColors.purple.withValues(alpha: 0.16),
                      blurRadius: 14,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 22,
                ),
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

String _compactSignalText(String value, {int maxLength = 18}) {
  final trimmed = value.trim();
  if (trimmed.length <= maxLength) return trimmed;
  return '${trimmed.substring(0, maxLength).trim()}...';
}

class _SignalSummaryCard extends StatelessWidget {
  final RecentSignalModel signal;

  const _SignalSummaryCard({required this.signal});

  @override
  Widget build(BuildContext context) {
    return AuroraCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      color: Colors.white.withValues(alpha: 0.62),
      borderRadius: BorderRadius.circular(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AuroraSoftIconCircle(
                icon: Icons.bookmark_rounded,
                color: AuroraColors.purple,
                size: 34,
                iconSize: 19,
              ),
              const SizedBox(width: 10),
              Text(
                AppLocaleText.tr(
                  context,
                  en: 'This entry',
                  zhHans: '这条记录',
                  zhHant: '這條記錄',
                  ja: 'この記録',
                ),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AuroraColors.purple,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.64),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.86)),
            ),
            child: Row(
              children: [
                Text(
                  _formatTime(signal.createdAt),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AuroraColors.ink.withValues(alpha: 0.70),
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(width: 14),
                _SignalRoundIcon(signal: signal),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    signal.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AuroraColors.ink,
                          height: 1.32,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const SizedBox(width: 12),
                _SignalDomainPill(signal: signal),
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

class _SignalRoundIcon extends StatelessWidget {
  final RecentSignalModel signal;

  const _SignalRoundIcon({required this.signal});

  @override
  Widget build(BuildContext context) {
    final color = _signalAccentColor(signal);
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.92),
            color.withValues(alpha: 0.82),
          ],
        ),
      ),
      child: Icon(_signalIcon(signal), color: Colors.white, size: 24),
    );
  }
}

class _SignalDomainPill extends StatelessWidget {
  final RecentSignalModel signal;

  const _SignalDomainPill({required this.signal});

  @override
  Widget build(BuildContext context) {
    final label = _signalDomainLabel(context, signal);
    return Container(
      constraints: const BoxConstraints(maxWidth: 116),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.64),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AuroraColors.line.withValues(alpha: 0.62)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _signalIcon(signal),
            color: _signalAccentColor(signal),
            size: 19,
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AuroraColors.ink.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _signalIcon(RecentSignalModel signal) {
  final text = [
    signal.content,
    signal.scene ?? '',
    signal.energyLoad ?? '',
    signal.friction ?? '',
  ].join(' ').toLowerCase();
  if (text.contains('睡') ||
      text.contains('午餐') ||
      text.contains('饭') ||
      text.contains('food') ||
      text.contains('sleep')) {
    return Icons.nights_stay_rounded;
  }
  if (text.contains('疲') || text.contains('能量') || text.contains('energy')) {
    return Icons.spa_rounded;
  }
  return Icons.sentiment_satisfied_alt_rounded;
}

Color _signalAccentColor(RecentSignalModel signal) {
  final icon = _signalIcon(signal);
  if (icon == Icons.nights_stay_rounded) return AuroraColors.blue;
  if (icon == Icons.spa_rounded) return AuroraColors.mint;
  return AuroraColors.gold;
}

String _signalDomainLabel(BuildContext context, RecentSignalModel signal) {
  final text = [
    signal.content,
    signal.scene ?? '',
    signal.energyLoad ?? '',
    signal.friction ?? '',
  ].join(' ').toLowerCase();
  if (text.contains('睡') ||
      text.contains('午餐') ||
      text.contains('饭') ||
      text.contains('food') ||
      text.contains('sleep')) {
    return AppLocaleText.tr(
      context,
      en: 'Food & sleep',
      zhHans: '饮食睡眠',
      zhHant: '飲食睡眠',
      ja: '食事と睡眠',
    );
  }
  return AppLocaleText.tr(
    context,
    en: 'Emotional calm',
    zhHans: '情绪安定',
    zhHant: '情緒安定',
    ja: '感情の安定',
  );
}

class _DialogHeroArt extends StatelessWidget {
  const _DialogHeroArt();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: CustomPaint(painter: _DialogRingPainter()),
        ),
        Positioned(
          left: 18,
          bottom: 4,
          width: 58,
          height: 96,
          child: CustomPaint(
            painter: _DialogLeafPainter(
              color: AuroraColors.mint.withValues(alpha: 0.15),
            ),
          ),
        ),
        Positioned(
          right: 8,
          bottom: 10,
          width: 58,
          height: 104,
          child: CustomPaint(
            painter: _DialogLeafPainter(
              color: AuroraColors.purple.withValues(alpha: 0.15),
            ),
          ),
        ),
      ],
    );
  }
}

class _DialogRingPainter extends CustomPainter {
  const _DialogRingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.56, size.height * 0.38);
    final radius = size.shortestSide * 0.32;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius * 1.34,
      Paint()
        ..color = AuroraColors.purple.withValues(alpha: 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );
    canvas.drawArc(
      rect,
      -math.pi * 0.18,
      math.pi * 1.55,
      false,
      Paint()
        ..shader = const SweepGradient(
          colors: [
            Color(0xFF7B6FF2),
            Color(0xFF70DDE2),
            Color(0xFFFFBD67),
            Color(0xFF7B6FF2),
          ],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 17,
    );
    final path = Path()
      ..moveTo(center.dx - radius * 0.94, center.dy + radius * 0.08)
      ..cubicTo(
        center.dx - radius * 0.18,
        center.dy - radius * 0.14,
        center.dx + radius * 0.42,
        center.dy - radius * 0.03,
        center.dx + radius * 0.08,
        center.dy + radius * 0.23,
      )
      ..cubicTo(
        center.dx - radius * 0.18,
        center.dy + radius * 0.44,
        center.dx + radius * 0.14,
        center.dy + radius * 0.58,
        center.dx + radius * 0.92,
        center.dy + radius * 0.68,
      );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.82),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DialogLeafPainter extends CustomPainter {
  final Color color;

  const _DialogLeafPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final stem = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(size.width * 0.48, size.height),
      Offset(size.width * 0.52, size.height * 0.10),
      stem,
    );
    final fill = Paint()..color = color.withValues(alpha: 0.72);
    for (var i = 0; i < 4; i += 1) {
      final y = size.height * (0.28 + i * 0.16);
      final left = i.isEven;
      final cx = size.width * (left ? 0.28 : 0.72);
      final leaf = Path()
        ..moveTo(size.width * 0.50, y)
        ..quadraticBezierTo(
          cx,
          y - size.height * 0.11,
          cx,
          y + size.height * 0.05,
        )
        ..quadraticBezierTo(
          size.width * 0.44,
          y + size.height * 0.06,
          size.width * 0.50,
          y,
        );
      canvas.drawPath(leaf, fill);
    }
  }

  @override
  bool shouldRepaint(covariant _DialogLeafPainter oldDelegate) =>
      oldDelegate.color != color;
}

/*
Legacy detail cards are kept below for now because nearby tests still exercise
their labels indirectly during migration.
*/
class _LegacySignalSummaryCard extends StatelessWidget {
  final RecentSignalModel signal;

  const _LegacySignalSummaryCard({required this.signal});

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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.66),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.84)),
            boxShadow: [
              BoxShadow(
                color: AuroraColors.purple.withValues(alpha: 0.07),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: AuroraColors.purple),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AuroraColors.ink.withValues(alpha: 0.78),
                        fontWeight: FontWeight.w800,
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
                  en: 'Add to archive',
                  zhHans: '加入实验档案',
                  zhHant: '加入實驗檔案',
                  ja: 'アーカイブへ',
                ),
                onPressed: () => showSaved(AppLocaleText.tr(
                  context,
                  en: 'Saved to the experiment archive.',
                  zhHans: '已加入实验档案。',
                  zhHant: '已加入實驗檔案。',
                  ja: '実験アーカイブに保存しました。',
                )),
              ),
              _DialogActionDecision(
                icon: Icons.bookmark_rounded,
                label: AppLocaleText.tr(
                  context,
                  en: 'Keep record only',
                  zhHans: '只保留记录',
                  zhHant: '只保留記錄',
                  ja: '記録だけ残す',
                ),
                onPressed: () => showSaved(AppLocaleText.tr(
                  context,
                  en: 'Kept as a record.',
                  zhHans: '已保留为记录。',
                  zhHant: '已保留為記錄。',
                  ja: '記録として残しました。',
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
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
          color: Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(24),
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
                      zhHans: '继续说一点...',
                      zhHant: '繼續說一點...',
                      ja: '考えをもう少し続ける...',
                    ),
                    hintStyle:
                        Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AuroraColors.muted.withValues(alpha: 0.60),
                              fontWeight: FontWeight.w500,
                            ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isSending
                      ? null
                      : const LinearGradient(
                          colors: [Color(0xFFB88CFF), Color(0xFF778BFF)],
                        ),
                  color: isSending ? AuroraColors.line : null,
                  boxShadow: [
                    BoxShadow(
                      color: AuroraColors.purple.withValues(alpha: 0.26),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: isSending ? null : onSend,
                  icon: isSending
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 27,
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
