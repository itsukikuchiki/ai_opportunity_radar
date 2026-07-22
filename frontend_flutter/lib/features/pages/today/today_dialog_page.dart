// ignore_for_file: unused_element

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/di/app_dependencies.dart';
import '../../../core/i18n/app_locale_text.dart';
import '../../../core/models/today_models.dart';
import '../../../core/navigation/app_back_navigation.dart';
import '../../../core/preferences/focus_domains.dart';
import '../../../shared/widgets/aurora_ui.dart';
import '../../../shared/utils/user_visible_text_sanitizer.dart';

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
  final ScrollController _scrollController = ScrollController();
  final List<LightDialogTurnModel> _turns = [];
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
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
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
        final opening =
            sanitizeTimelineAcknowledgement(signal.acknowledgement) ??
                _openingAcknowledgement(context, signal);
        _turns.add(
          LightDialogTurnModel(
            role: 'assistant',
            text: opening,
          ),
        );
      }
    });
  }

  String _openingAcknowledgement(
    BuildContext context,
    RecentSignalModel signal,
  ) {
    final short = _compactSignalText(signal.content);
    return AppLocaleText.tr(
      context,
      en: 'You mentioned “$short”. I’m here with this moment.',
      zhHans: '你说“$short”，这个片段我接住了。',
      zhHant: '你說「$short」，這個片段我接住了。',
      ja: '「$short」と書いていましたね。この瞬間を受け止めました。',
    );
  }

  Future<void> _send() async {
    final signal = _signal;
    final text = _controller.text.trim();
    if (signal == null || text.isEmpty || _isSending) return;
    final previousTurns = List<LightDialogTurnModel>.from(_turns);

    setState(() {
      _isSending = true;
      _error = null;
      _turns.add(LightDialogTurnModel(role: 'user', text: text));
      _controller.clear();
    });
    _scrollToLatest();

    try {
      final result = await context
          .read<AppDependencies>()
          .todayRepository
          .continueLightDialog(
            signal: signal,
            history: previousTurns,
            userMessage: text,
          );

      if (!mounted) return;
      setState(() {
        _turns.add(LightDialogTurnModel(role: 'assistant', text: result.reply));
      });
      _scrollToLatest();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'send_failed';
      });
      _scrollToLatest();
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
    final dialogTitle = AppLocaleText.tr(
      context,
      en: 'Chat With AI',
      zhHans: '和 AI 聊聊',
      zhHant: '和 AI 聊聊',
      ja: 'AI と話す',
    );
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
                                      AuroraIconButton(
                                        key:
                                            const ValueKey('today-dialog-back'),
                                        icon: Icons.chevron_left_rounded,
                                        tooltip:
                                            MaterialLocalizations.of(context)
                                                .backButtonTooltip,
                                        onPressed: _goBack,
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: ListView(
                                    key: const ValueKey(
                                        'today-dialog-message-list'),
                                    controller: _scrollController,
                                    keyboardDismissBehavior:
                                        ScrollViewKeyboardDismissBehavior
                                            .onDrag,
                                    padding: const EdgeInsets.fromLTRB(
                                        20, 34, 20, 18),
                                    children: [
                                      Semantics(
                                        key: const ValueKey(
                                            'today-dialog-heading-semantics'),
                                        container: true,
                                        excludeSemantics: true,
                                        header: true,
                                        label: dialogTitle,
                                        child: AuroraHeroTitle(
                                          text: dialogTitle,
                                          fontSize: 42,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        AppLocaleText.tr(
                                          context,
                                          en: 'Chat around this entry. AI will first acknowledge what you express without offering unsolicited advice.',
                                          zhHans:
                                              '可以围绕这条记录对话。AI 会先承接你的表达，不主动给建议。',
                                          zhHant:
                                              '可以圍繞這條記錄對話。AI 會先承接你的表達，不主動給建議。',
                                          ja: 'この記録を起点に対話できます。AI はまず表現を受け止め、求められない助言はしません。',
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              color: AuroraColors.ink
                                                  .withValues(alpha: 0.72),
                                              height: 1.5,
                                              fontWeight: FontWeight.w400,
                                            ),
                                      ),
                                      const SizedBox(height: 24),
                                      _SignalSummaryCard(signal: signal),
                                      const SizedBox(height: 22),
                                      ..._buildTurns(context),
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
                      fontWeight: FontWeight.w700,
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
    context.popOrGo(AppRoutes.today);
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
                      fontWeight: FontWeight.w700,
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
                const SizedBox(width: 10),
                _SignalRoundIcon(signal: signal),
                const SizedBox(width: 8),
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
                const SizedBox(width: 8),
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
  final explicitDomain = _explicitSignalDomainLabel(context, signal);
  if (explicitDomain != null) return explicitDomain;

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
  if (signal.sourceType == 'time_use') {
    return AppLocaleText.tr(
      context,
      en: 'Time use',
      zhHans: '时间去向',
      zhHant: '時間去向',
      ja: '時間の使い方',
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

String? _explicitSignalDomainLabel(
  BuildContext context,
  RecentSignalModel signal,
) {
  final candidates = <String?>[
    signal.rawPayloadJson['focus_domain_id']?.toString(),
    signal.rawPayloadJson['category']?.toString(),
    signal.scene,
    if (signal.sceneTags.isNotEmpty) signal.sceneTags.first,
  ];
  for (final raw in candidates) {
    final normalized = raw?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty) continue;
    final focusDomain = FocusDomains.optionFor(normalized);
    if (focusDomain != null) return focusDomain.label(context);
    if (signal.sourceType != 'time_use') continue;
    final legacy = _legacyTimeUseDomainLabel(context, normalized);
    if (legacy != null) return legacy;
  }
  return null;
}

String? _legacyTimeUseDomainLabel(BuildContext context, String value) {
  return switch (value) {
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

String? _signalEnergyLabel(BuildContext context, RecentSignalModel signal) {
  final rawLevel = signal.rawPayloadJson['energy_level'];
  final level = rawLevel is num
      ? rawLevel.toInt()
      : int.tryParse(rawLevel?.toString() ?? '');
  if (level != null && level >= 0 && level <= 2) {
    return _energyLevelLabel(context, level);
  }

  final legacy = (signal.rawPayloadJson['energy_effect'] ?? signal.energyLoad)
          ?.toString()
          .trim()
          .toLowerCase() ??
      '';
  final legacyLevel = switch (legacy) {
    'draining' || 'low' || 'very_low' || '偏低' => 0,
    'neutral' || 'medium' || 'okay' || '还好' || '還好' => 1,
    'restoring' || 'high' || 'full' || 'enough' || '很足' => 2,
    _ => null,
  };
  return legacyLevel == null ? null : _energyLevelLabel(context, legacyLevel);
}

String _energyLevelLabel(BuildContext context, int level) {
  return switch (level) {
    0 => AppLocaleText.tr(
        context,
        en: 'Low',
        zhHans: '偏低',
        zhHant: '偏低',
        ja: '低め',
      ),
    1 => AppLocaleText.tr(
        context,
        en: 'Okay',
        zhHans: '还好',
        zhHant: '還好',
        ja: 'まあまあ',
      ),
    _ => AppLocaleText.tr(
        context,
        en: 'Enough',
        zhHans: '很足',
        zhHant: '很足',
        ja: '十分',
      ),
  };
}

class _DialogHeroArt extends StatelessWidget {
  const _DialogHeroArt();

  @override
  Widget build(BuildContext context) {
    return const AuroraSignalHeroPattern(
      key: ValueKey('today-dialog-signal-pattern'),
      opacity: 0.76,
      alignment: Alignment.centerRight,
      fit: BoxFit.cover,
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
    final energyLabel = _signalEnergyLabel(context, signal);
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
                            fontWeight: FontWeight.w700,
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
                    if (energyLabel != null)
                      AuroraChip(
                        label: energyLabel,
                        color: AuroraColors.mint,
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
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
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
      en: 'Turn this into one very small experiment for today.',
      zhHans: '把刚才说到的线索，变成今天一个很小的尝试。',
      zhHant: '把剛才說到的線索，變成今天一個很小的嘗試。',
      ja: '今話した手がかりを、今日の小実験にします。',
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
                    en: 'Make this a small experiment?',
                    zhHans: '要不要变成一个小实验？',
                    zhHant: '要不要變成一個小實驗？',
                    ja: '小実験にしますか？',
                  ),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AuroraColors.ink,
                        fontWeight: FontWeight.w700,
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
                  en: 'Saved as a small experiment for today.',
                  zhHans: '已保存为今天的小实验。',
                  zhHant: '已保存為今天的小實驗。',
                  ja: '今日の小実験として保存しました。',
                )),
              ),
              _DialogActionDecision(
                icon: Icons.science_rounded,
                label: AppLocaleText.tr(
                  context,
                  en: 'Save as a goal',
                  zhHans: '保存为目标',
                  zhHant: '儲存為目標',
                  ja: '目標として保存',
                ),
                onPressed: () => showSaved(AppLocaleText.tr(
                  context,
                  en: 'Saved as a goal in Life Experiment.',
                  zhHans: '已保存为生活小实验中的目标。',
                  zhHant: '已保存為生活小實驗中的目標。',
                  ja: '生活実験の目標として保存しました。',
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
    final energyLabel = _signalEnergyLabel(context, signal) ??
        AppLocaleText.tr(
          context,
          en: 'Not recorded',
          zhHans: '未记录',
          zhHant: '未記錄',
          ja: '未記録',
        );
    final items = [
      (
        Icons.battery_3_bar_rounded,
        AppLocaleText.tr(context,
            en: 'Energy', zhHans: '能量', zhHant: '能量', ja: 'エネルギー'),
        energyLabel,
        AuroraColors.mint,
      ),
      (
        Icons.repeat_rounded,
        AppLocaleText.tr(context,
            en: 'Pattern', zhHans: '长期模式', zhHant: '長期模式', ja: 'パターン'),
        _signalDomainLabel(context, signal),
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
            en: 'Goal', zhHans: '目标', zhHant: '目標', ja: '目標'),
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
                  en: 'Related Signals',
                  zhHans: '相关 Signal',
                  zhHant: '相關 Signal',
                  ja: '関連する Signal',
                ),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AuroraColors.ink,
                      fontWeight: FontWeight.w700,
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
                                ?.copyWith(fontWeight: FontWeight.w700),
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
                  key: const ValueKey('today-dialog-composer-input'),
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
                  key: const ValueKey('today-dialog-send'),
                  tooltip: AppLocaleText.tr(
                    context,
                    en: 'Send',
                    zhHans: '发送',
                    zhHant: '傳送',
                    ja: '送信',
                  ),
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
                      fontWeight: FontWeight.w700,
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
                  ja: '今日に戻る',
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
