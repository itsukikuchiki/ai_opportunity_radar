// This tool app is an evidence harness, so keeping scene declarations readable
// matters more than squeezing every widget into const constructors.
// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, unused_element, unused_field, unused_element_parameter

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

const _sceneIndex = int.fromEnvironment('SCENE_INDEX', defaultValue: 0);
const _autoAdvance = bool.fromEnvironment('AUTO_ADVANCE', defaultValue: true);
const _productReview =
    bool.fromEnvironment('PRODUCT_REVIEW', defaultValue: false);

void main() {
  runApp(
    ReleaseQaPhase3EvidenceApp(
      initialScene: _sceneIndex,
      autoAdvance: _autoAdvance,
    ),
  );
}

class ReleaseQaPhase3EvidenceApp extends StatelessWidget {
  final int initialScene;
  final bool autoAdvance;

  const ReleaseQaPhase3EvidenceApp({
    super.key,
    this.initialScene = 0,
    this.autoAdvance = true,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Signal Path ReleaseQA 2.7E',
      locale: const Locale('zh', 'Hans'),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF53738D),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: _Palette.canvas,
        useMaterial3: true,
      ),
      home: EvidenceCarousel(
        initialScene: initialScene,
        autoAdvance: autoAdvance,
      ),
    );
  }
}

class EvidenceCarousel extends StatefulWidget {
  final int initialScene;
  final bool autoAdvance;

  const EvidenceCarousel({
    super.key,
    required this.initialScene,
    required this.autoAdvance,
  });

  @override
  State<EvidenceCarousel> createState() => _EvidenceCarouselState();
}

class _EvidenceCarouselState extends State<EvidenceCarousel> {
  static const _sceneDuration = Duration(seconds: 5);
  late final PageController _controller;
  Timer? _timer;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialScene.clamp(0, _scenes.length - 1);
    _controller = PageController(initialPage: _index);
    if (!widget.autoAdvance) return;
    _timer = Timer.periodic(_sceneDuration, (_) {
      if (!mounted) return;
      final next = (_index + 1) % _scenes.length;
      setState(() => _index = next);
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _SceneTopBar(
              fileName: _scenes[_index].fileName,
              index: _index + 1,
              total: _scenes.length,
              visible: !_productReview,
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (value) => setState(() => _index = value),
                children: _scenes,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SceneTopBar extends StatelessWidget {
  final String fileName;
  final int index;
  final int total;
  final bool visible;

  const _SceneTopBar({
    required this.fileName,
    required this.index,
    required this.total,
    required this.visible,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox(height: 4);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              fileName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _Palette.muted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          _Pill(
            label: '$index / $total',
            color: _Palette.mist,
            textColor: _Palette.ink,
          ),
        ],
      ),
    );
  }
}

class _VisualScene extends StatelessWidget {
  final String fileName;
  final String title;
  final String subtitle;
  final List<String> summary;
  final Widget visual;
  final List<Widget> sections;

  const _VisualScene({
    required this.fileName,
    required this.title,
    required this.subtitle,
    required this.summary,
    required this.visual,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    final productPageOnly =
        _productReview && title.isEmpty && summary.isEmpty && sections.isEmpty;
    if (productPageOnly) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
        children: [visual],
      );
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(18, _productReview ? 14 : 6, 18, 30),
      children: [
        _HeroPanel(
          title: title,
          subtitle: subtitle,
          summary: summary,
          visual: visual,
        ),
        const SizedBox(height: 14),
        ...sections.expand((section) => [section, const SizedBox(height: 12)]),
        if (!_productReview) const _EvidenceFooter(),
      ],
    );
  }
}

class _HeroPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> summary;
  final Widget visual;

  const _HeroPanel({
    required this.title,
    required this.subtitle,
    required this.summary,
    required this.visual,
  });

  @override
  Widget build(BuildContext context) {
    final hasCopy = title.isNotEmpty || subtitle.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _Palette.paper,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _Palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasCopy) ...[
            Text(
              title,
              style: const TextStyle(
                color: _Palette.ink,
                fontSize: 27,
                fontWeight: FontWeight.w500,
                height: 1.12,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                color: _Palette.subtle,
                fontSize: 15,
                height: 1.35,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 16),
          ],
          visual,
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in summary)
                  _Pill(
                    label: item,
                    color: _Palette.mist,
                    textColor: _Palette.ink,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SoftCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final List<String> tags;
  final Color tint;

  const _SoftCard({
    required this.icon,
    required this.title,
    required this.body,
    this.tags = const [],
    this.tint = _Palette.paper,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _Palette.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
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
              _IconBubble(icon: icon, color: _Palette.blue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _Palette.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: const TextStyle(
              color: _Palette.body,
              fontSize: 14.5,
              height: 1.38,
              fontWeight: FontWeight.w400,
            ),
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final tag in tags)
                  _Pill(
                      label: tag, color: Colors.white.withValues(alpha: 0.72)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SignalCard extends StatelessWidget {
  final IconData icon;
  final String source;
  final String time;
  final String raw;
  final String ai;
  final List<String> tags;
  final Color marker;

  const _SignalCard({
    required this.icon,
    required this.source,
    required this.time,
    required this.raw,
    required this.ai,
    required this.tags,
    required this.marker,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _Palette.paper,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _Palette.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 116,
            decoration: BoxDecoration(
              color: marker,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _IconBubble(icon: icon, color: marker, size: 32),
                    const SizedBox(width: 8),
                    Text(
                      '$source · $time',
                      style: const TextStyle(
                        color: _Palette.subtle,
                        fontWeight: FontWeight.w500,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  raw,
                  style: const TextStyle(
                    color: _Palette.ink,
                    fontSize: 15.5,
                    height: 1.32,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 9),
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: _Palette.mist,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    ai,
                    style: const TextStyle(
                      color: _Palette.body,
                      fontSize: 13.5,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    for (final tag in tags) _Pill(label: tag),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final IconData? icon;

  const _Pill({
    required this.label,
    this.color = _Palette.softBlue,
    this.textColor = _Palette.blue,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: textColor.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: textColor, size: 13),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  final String label;
  final IconData? icon;

  const _ActionPill({
    required this.label,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: _Palette.blue,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: _Palette.blue.withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _SecondaryActionPill extends StatelessWidget {
  final String label;
  final IconData? icon;

  const _SecondaryActionPill({
    required this.label,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _Palette.blue.withValues(alpha: 0.26)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: _Palette.blue, size: 14),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: const TextStyle(
              color: _Palette.blue,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _StateBadge extends StatelessWidget {
  final String label;
  final IconData? icon;

  const _StateBadge({
    required this.label,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return _Pill(
      label: label,
      icon: icon,
      color: _Palette.stateBadge,
      textColor: _Palette.stateText,
    );
  }
}

class _InfoCard extends StatelessWidget {
  final _InfoKind kind;
  final IconData icon;
  final String title;
  final String body;
  final List<String> states;
  final List<String> actions;
  final List<String> secondaryActions;
  final Widget? visual;

  const _InfoCard({
    required this.kind,
    required this.icon,
    required this.title,
    required this.body,
    this.states = const [],
    this.actions = const [],
    this.secondaryActions = const [],
    this.visual,
  });

  @override
  Widget build(BuildContext context) {
    final style = _InfoStyle.of(kind);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: style.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
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
              _IconBubble(icon: icon, color: style.accent, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _Palette.ink,
                        fontSize: 17,
                        height: 1.22,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      body,
                      style: const TextStyle(
                        color: _Palette.body,
                        fontSize: 14.5,
                        height: 1.46,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (visual != null) ...[
            const SizedBox(height: 13),
            visual!,
          ],
          if (states.isNotEmpty ||
              actions.isNotEmpty ||
              secondaryActions.isNotEmpty) ...[
            const SizedBox(height: 13),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final state in states) _StateBadge(label: state),
                for (final action in actions) _ActionPill(label: action),
                for (final action in secondaryActions)
                  _SecondaryActionPill(label: action),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

enum _InfoKind { reality, observation, suggestion }

class _InfoStyle {
  final Color background;
  final Color border;
  final Color accent;

  const _InfoStyle({
    required this.background,
    required this.border,
    required this.accent,
  });

  static _InfoStyle of(_InfoKind kind) {
    switch (kind) {
      case _InfoKind.reality:
        return const _InfoStyle(
          background: _Palette.realitySurface,
          border: _Palette.realityLine,
          accent: _Palette.peach,
        );
      case _InfoKind.observation:
        return const _InfoStyle(
          background: _Palette.observationSurface,
          border: _Palette.observationLine,
          accent: _Palette.signalBlue,
        );
      case _InfoKind.suggestion:
        return const _InfoStyle(
          background: _Palette.suggestionSurface,
          border: _Palette.suggestionLine,
          accent: _Palette.recoverySage,
        );
    }
  }
}

class _IconBubble extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _IconBubble({
    required this.icon,
    required this.color,
    this.size = 38,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: size * 0.52),
    );
  }
}

class _SplashVisual extends StatelessWidget {
  const _SplashVisual();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _productReview ? 620 : 260,
      width: double.infinity,
      decoration: BoxDecoration(
        color: _Palette.brandCoral,
        borderRadius: BorderRadius.circular(34),
        border: _productReview ? null : Border.all(color: _Palette.line),
      ),
      child: Center(
        child: Transform.translate(
          offset: const Offset(0, -18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _BrandDisplayIconVisual(size: 150),
              const SizedBox(height: 24),
              const Text(
                'Signal Path',
                style: TextStyle(
                  color: _Palette.ink,
                  fontSize: 34,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '看见信号，轻轻调整',
                style: TextStyle(
                  color: Color(0xFF394B5C),
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandDisplayIconVisual extends StatelessWidget {
  final double size;

  const _BrandDisplayIconVisual({required this.size});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/brand-icon-display.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

class _SignalPathLogoVisual extends StatelessWidget {
  final double size;

  const _SignalPathLogoVisual({this.size = 64});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LogoPainter()),
    );
  }
}

class _OnboardingBrandVisual extends StatelessWidget {
  const _OnboardingBrandVisual();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 790,
      width: double.infinity,
      decoration: BoxDecoration(
        color: _Palette.brandCoral,
        borderRadius: BorderRadius.circular(36),
      ),
      child: Center(
        child: Transform.translate(
          offset: const Offset(0, -44),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _BrandDisplayIconVisual(size: 190),
              SizedBox(height: 26),
              _BrandTitleText('Signal Path', size: 38),
              SizedBox(height: 10),
              Text(
                '看见信号，轻轻调整',
                style: TextStyle(
                  color: Color(0xFF394B5C),
                  fontSize: 17,
                  height: 1.42,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LaunchMiniPathVisual extends StatelessWidget {
  const _LaunchMiniPathVisual();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 138,
      height: 44,
      child: CustomPaint(painter: _LaunchMiniPathPainter()),
    );
  }
}

class _BrandLaunchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final wash = Paint()..style = PaintingStyle.fill;
    wash.color = _Palette.mist.withValues(alpha: 0.0);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LaunchMiniPathPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = _Palette.signalBlue.withValues(alpha: 0.38)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(8, size.height * 0.62)
      ..cubicTo(size.width * 0.28, 4, size.width * 0.48, size.height * 0.84,
          size.width * 0.70, size.height * 0.36)
      ..cubicTo(size.width * 0.80, size.height * 0.14, size.width * 0.90,
          size.height * 0.52, size.width - 8, 12);
    canvas.drawPath(path, stroke);
    final fill = Paint()..style = PaintingStyle.fill;
    final dots = [
      (Offset(8, size.height * 0.62), _Palette.sage, 5.0),
      (Offset(size.width * 0.36, size.height * 0.34), _Palette.blue, 6.0),
      (Offset(size.width * 0.66, size.height * 0.45), _Palette.teal, 5.0),
      (Offset(size.width - 8, 12), _Palette.coral, 4.5),
    ];
    for (final dot in dots) {
      fill.color = dot.$2;
      canvas.drawCircle(dot.$1, dot.$3, fill);
    }
    final sparkle = Paint()
      ..color = _Palette.bufferButter
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final center = Offset(size.width * 0.84, size.height * 0.18);
    canvas.drawLine(center.translate(-5, 0), center.translate(5, 0), sparkle);
    canvas.drawLine(center.translate(0, -5), center.translate(0, 5), sparkle);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OnboardingInputVisual extends StatelessWidget {
  const _OnboardingInputVisual();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 790,
      padding: const EdgeInsets.fromLTRB(28, 52, 28, 34),
      decoration: BoxDecoration(
        color: _Palette.paper,
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: _Palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BrandTitleText('把今天的一点信号\n先放下来。', size: 31),
          const SizedBox(height: 14),
          const Text(
            '原文会先保存，AI 只是帮你轻轻整理。',
            style: TextStyle(
              color: _Palette.subtle,
              fontSize: 17,
              height: 1.42,
              fontWeight: FontWeight.w400,
            ),
          ),
          const Spacer(),
          const _SignalDropVisual(),
          const Spacer(),
          const _InfoCard(
            kind: _InfoKind.reality,
            icon: Icons.edit_note_rounded,
            title: '你留下的内容',
            body: '一句话、语音转写，或只是一个状态，都可以先放进私人观察。',
            states: ['先保存', '私密'],
          ),
          const SizedBox(height: 12),
          const _InfoCard(
            kind: _InfoKind.observation,
            icon: Icons.auto_awesome_rounded,
            title: '轻轻整理',
            body: 'AI 失败也不会影响保存；整理结果只是附加观察。',
            states: ['不覆盖原文'],
          ),
        ],
      ),
    );
  }
}

class _OnboardingOutputVisual extends StatelessWidget {
  const _OnboardingOutputVisual();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 790,
      padding: const EdgeInsets.fromLTRB(28, 52, 28, 34),
      decoration: BoxDecoration(
        color: _Palette.paper,
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: _Palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BrandTitleText('把零散信号整理成\n生活路径。', size: 31),
          const SizedBox(height: 14),
          const Text(
            '不是报告，也不是评分。只是帮你看见这段时间哪里耗力，哪里在恢复。',
            style: TextStyle(
              color: _Palette.subtle,
              fontSize: 16.5,
              height: 1.42,
              fontWeight: FontWeight.w400,
            ),
          ),
          const Spacer(),
          const _SignalToMapVisual(),
          const Spacer(),
          const _InfoCard(
            kind: _InfoKind.observation,
            icon: Icons.stacked_bar_chart_rounded,
            title: 'Weekly',
            body: '这周可以先看一个模式，再选择一个很小的尝试。',
            states: ['生活仪表盘'],
          ),
          const SizedBox(height: 12),
          const _InfoCard(
            kind: _InfoKind.observation,
            icon: Icons.route_rounded,
            title: 'Journey',
            body: '把 8 周里的重复、恢复和实验轨迹放在一张长期地图里。',
            states: ['生活地图'],
          ),
        ],
      ),
    );
  }
}

class _BrandTitleText extends StatelessWidget {
  final String text;
  final double size;

  const _BrandTitleText(this.text, {required this.size});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: _Palette.ink,
        fontSize: size,
        height: 1.18,
        letterSpacing: 0.15,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}

class _SignalDropVisual extends StatelessWidget {
  const _SignalDropVisual();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      width: double.infinity,
      child: CustomPaint(painter: _SignalDropPainter()),
    );
  }
}

class _SignalToMapVisual extends StatelessWidget {
  const _SignalToMapVisual();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 210,
      width: double.infinity,
      child: CustomPaint(painter: _SignalToMapPainter()),
    );
  }
}

class _SignalDotsVisual extends StatelessWidget {
  const _SignalDotsVisual();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 116,
      child: CustomPaint(
        painter: _DotsPainter(),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 150,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.74),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Text(
              '5 条信号\n2 个耗力\n1 个恢复',
              style: TextStyle(
                color: _Palette.ink,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ComposerVisual extends StatelessWidget {
  const _ComposerVisual();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _Palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.edit_note_rounded, color: _Palette.blue),
              SizedBox(width: 8),
              Text(
                '现在有什么信号想留下？',
                style: TextStyle(
                  color: _Palette.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 34),
          Wrap(
            spacing: 8,
            children: const [
              _Pill(label: '文字', icon: Icons.notes_rounded),
              _Pill(label: '语音', icon: Icons.graphic_eq_rounded),
              _Pill(label: 'AI 轻建议', icon: Icons.auto_awesome_rounded),
            ],
          ),
        ],
      ),
    );
  }
}

class _WaveVisual extends StatelessWidget {
  const _WaveVisual();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: CustomPaint(
        painter: _WavePainter(),
        child: const Center(
          child: _Pill(label: '转写后可编辑 · 不保存音频', icon: Icons.graphic_eq),
        ),
      ),
    );
  }
}

class _SpotlightVisual extends StatelessWidget {
  const _SpotlightVisual();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEDEBFA), Color(0xFFE7F2F4)],
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: const Column(
        children: [
          Icon(Icons.auto_awesome_rounded, color: _Palette.lavender, size: 30),
          SizedBox(height: 8),
          Text(
            '也许今天的信号和\n“频繁切换 + 缺少缓冲”有关。',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _Palette.ink,
              fontSize: 20,
              height: 1.28,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AiSuggestionVisual extends StatelessWidget {
  const _AiSuggestionVisual();

  @override
  Widget build(BuildContext context) {
    final style = _InfoStyle.of(_InfoKind.suggestion);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: style.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
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
              _IconBubble(
                icon: Icons.auto_awesome_rounded,
                color: style.accent,
                size: 36,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI 轻建议',
                      style: TextStyle(
                        color: _Palette.ink,
                        fontSize: 17,
                        height: 1.22,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 7),
                    Text(
                      '也许今天的信号和“频繁切换 + 缺少缓冲”有关。',
                      style: TextStyle(
                        color: _Palette.body,
                        fontSize: 14.5,
                        height: 1.46,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const _CompactSignalKitVisual(),
            ],
          ),
          const SizedBox(height: 13),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StateBadge(label: '确认前只作为小观察'),
              _ActionPill(label: '看起来对'),
              _ActionPill(label: '不太像'),
              _ActionPill(label: '补充一点'),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactSignalKitVisual extends StatelessWidget {
  const _CompactSignalKitVisual();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 86,
      height: 74,
      child: CustomPaint(painter: _CompactSignalKitPainter()),
    );
  }
}

class _SwitchingGapIllustration extends StatelessWidget {
  const _SwitchingGapIllustration();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _Palette.suggestionLine),
      ),
      child: CustomPaint(painter: _SwitchingGapPainter()),
    );
  }
}

class _LibrarySavedVisual extends StatelessWidget {
  const _LibrarySavedVisual();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _LibraryFlowVisual(),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _Palette.line),
          ),
          child: const Row(
            children: [
              Icon(Icons.lock_outline_rounded, color: _Palette.blue, size: 20),
              SizedBox(width: 8),
              Expanded(child: Text('你的补充语境只留在私人观察里')),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompactVisual extends StatelessWidget {
  const _CompactVisual();

  @override
  Widget build(BuildContext context) {
    return const _SignalCard(
      icon: Icons.notes_rounded,
      source: '文字',
      time: '18:42',
      raw: '会议、消息和家庭沟通来回切换，晚上有点空。',
      ai: '更像是连续切换让缓冲变少，不是一件事本身太重。',
      tags: ['混合', '切换', '看起来对'],
      marker: _Palette.teal,
    );
  }
}

class _StickyPlanVisual extends StatelessWidget {
  const _StickyPlanVisual();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.018,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _Palette.sticky,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE5D99C)),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sticky_note_2_outlined, color: _Palette.olive),
                SizedBox(width: 8),
                Text(
                  '这周可以小小试一下',
                  style: TextStyle(
                    color: _Palette.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Text(
              '把最密的一段之后，留出 10 分钟空隙。',
              style: TextStyle(
                color: _Palette.body,
                fontSize: 16,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 14),
            _BufferTimelineVisual(),
          ],
        ),
      ),
    );
  }
}

class _WeeklyVisual extends StatelessWidget {
  const _WeeklyVisual();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _Palette.line),
          ),
          child: const Row(
            children: [
              _IconBubble(
                  icon: Icons.center_focus_strong_rounded,
                  color: _Palette.blue),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '这周先看一个模式：切换多，恢复边缘少。',
                  style: TextStyle(
                    color: _Palette.ink,
                    fontSize: 16,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const _SwitchingBurdenVisual(),
      ],
    );
  }
}

class _MiniWeatherStrip extends StatelessWidget {
  const _MiniWeatherStrip();

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.shuffle_rounded, '切换', _Palette.teal),
      (Icons.trending_down_rounded, '耗力', _Palette.coral),
      (Icons.spa_outlined, '恢复', _Palette.sage),
      (Icons.space_bar_rounded, '缓冲', _Palette.olive),
    ];
    return Row(
      children: [
        for (final item in items)
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: item.$3.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  Icon(item.$1, color: item.$3, size: 18),
                  const SizedBox(height: 4),
                  Text(
                    item.$2,
                    style: TextStyle(
                      color: item.$3,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _StackedBarVisual extends StatelessWidget {
  const _StackedBarVisual();

  @override
  Widget build(BuildContext context) {
    final parts = [
      (_Palette.coral, 0.32, '耗力'),
      (_Palette.teal, 0.25, '切换'),
      (_Palette.sage, 0.22, '恢复'),
      (_Palette.olive, 0.13, '缓冲'),
      (_Palette.grayBlue, 0.08, '中性'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            '看分布，不是评分',
            style: TextStyle(
              color: _Palette.subtle,
              fontSize: 12.5,
              height: 1.25,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _Palette.line),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 46,
              child: Row(
                children: [
                  for (final part in parts)
                    Expanded(
                      flex: (part.$2 * 100).round(),
                      child: Container(
                        alignment: Alignment.center,
                        color: part.$1,
                        child: part.$2 > 0.12
                            ? Text(
                                '${(part.$2 * 100).round()}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 11),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final part in parts)
              _LegendItem(label: part.$3, color: part.$1),
          ],
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendItem({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: _Palette.body,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _BufferTimelineVisual extends StatelessWidget {
  const _BufferTimelineVisual();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _Palette.line),
      ),
      child: Row(
        children: [
          _TimeBlock(label: '密集块', color: _Palette.drainCoral, flex: 3),
          const _ArrowGlyph(),
          _TimeBlock(label: '10 分钟空隙', color: _Palette.bufferButter, flex: 2),
          const _ArrowGlyph(),
          _TimeBlock(label: '松一点', color: _Palette.recoverySage, flex: 2),
        ],
      ),
    );
  }
}

class _ExperimentBeforeAfterVisual extends StatelessWidget {
  const _ExperimentBeforeAfterVisual();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7F1),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _Palette.line),
      ),
      child: const Column(
        children: [
          Row(
            children: [
              _MiniStage(icon: Icons.view_week_outlined, label: '问题\n太密'),
              _ArrowGlyph(),
              _MiniStage(icon: Icons.space_bar_rounded, label: '方法\n留白'),
              _ArrowGlyph(),
              _MiniStage(icon: Icons.spa_outlined, label: '目标\n轻一点'),
            ],
          ),
          SizedBox(height: 8),
          _Pill(label: '不是任务，是生活设计的小实验'),
        ],
      ),
    );
  }
}

class _WeeklyExperimentCard extends StatelessWidget {
  const _WeeklyExperimentCard();

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      kind: _InfoKind.suggestion,
      icon: Icons.explore_outlined,
      title: "可以试试：留 10 分钟。",
      body: "切换太密时，先给最密的一段后面留一点空隙。",
      visual: const _CompactExperimentPathVisual(),
      actions: const ["保存", "跳过"],
    );
  }
}

class _QuotaUsageCard extends StatelessWidget {
  const _QuotaUsageCard();

  @override
  Widget build(BuildContext context) {
    final style = _InfoStyle.of(_InfoKind.observation);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: style.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBubble(
                  icon: Icons.speed_rounded, color: _Palette.signalBlue),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '额度使用',
                  style: TextStyle(
                    color: _Palette.ink,
                    fontSize: 17,
                    height: 1.22,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              _StateBadge(label: '本月'),
            ],
          ),
          SizedBox(height: 14),
          Text(
            '本月使用',
            style: TextStyle(
              color: _Palette.body,
              fontSize: 14.5,
              height: 1.35,
              fontWeight: FontWeight.w400,
            ),
          ),
          SizedBox(height: 12),
          _QuotaProgress(
              label: 'Today AI 回应', valueText: '18 / 150', value: 0.12),
          SizedBox(height: 10),
          _QuotaProgress(label: 'Deep Weekly', valueText: '1 / 4', value: 0.25),
          SizedBox(height: 12),
          Text(
            '超出后仍可继续记录',
            style: TextStyle(
              color: _Palette.subtle,
              fontSize: 13.5,
              height: 1.35,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuotaProgress extends StatelessWidget {
  final String label;
  final String valueText;
  final double value;

  const _QuotaProgress({
    required this.label,
    required this.valueText,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: _Palette.ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              valueText,
              style: const TextStyle(
                color: _Palette.subtle,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 8,
            backgroundColor: Colors.white.withValues(alpha: 0.72),
            valueColor:
                const AlwaysStoppedAnimation<Color>(_Palette.signalBlue),
          ),
        ),
      ],
    );
  }
}

class _CompactExperimentPathVisual extends StatelessWidget {
  const _CompactExperimentPathVisual();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _Palette.suggestionLine),
      ),
      child: const Row(
        children: [
          _MiniStage(icon: Icons.view_week_outlined, label: '问题\n太密'),
          _ArrowGlyph(),
          _MiniStage(icon: Icons.space_bar_rounded, label: '方法\n留白'),
          _ArrowGlyph(),
          _MiniStage(icon: Icons.spa_outlined, label: '目标\n轻一点'),
        ],
      ),
    );
  }
}

class _LibraryFlowVisual extends StatelessWidget {
  const _LibraryFlowVisual();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _Palette.librarySand,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFEBD6BB)),
      ),
      child: const Row(
        children: [
          _MiniStage(icon: Icons.auto_stories_outlined, label: 'Library\n模式'),
          _ArrowGlyph(),
          _MiniStage(icon: Icons.lock_outline_rounded, label: '私人\n观察'),
          _ArrowGlyph(),
          _MiniStage(icon: Icons.edit_note_rounded, label: '你的\n语境'),
        ],
      ),
    );
  }
}

class _SwitchingBurdenVisual extends StatelessWidget {
  const _SwitchingBurdenVisual();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _Palette.line),
      ),
      child: const Row(
        children: [
          _MiniStage(icon: Icons.event_note_outlined, label: '计划密'),
          _ArrowGlyph(),
          _MiniStage(icon: Icons.shuffle_rounded, label: '消息切换'),
          _ArrowGlyph(),
          _MiniStage(icon: Icons.nights_stay_outlined, label: '恢复变晚'),
        ],
      ),
    );
  }
}

class _PatternIllustration extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PatternIllustration({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      height: 82,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final offset in const [
            Offset(-18, -14),
            Offset(18, -10),
            Offset(-6, 18),
          ])
            Transform.translate(
              offset: offset,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: _Palette.switchTeal.withValues(alpha: 0.34),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          Icon(icon, color: _Palette.blue, size: 28),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                label,
                style: const TextStyle(
                  color: _Palette.subtle,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStage extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniStage({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          _IconBubble(icon: icon, color: _Palette.blue, size: 36),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _Palette.body,
              fontSize: 12,
              height: 1.22,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArrowGlyph extends StatelessWidget {
  const _ArrowGlyph();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 5),
      child: Icon(Icons.arrow_forward_rounded, color: _Palette.muted, size: 18),
    );
  }
}

class _TimeBlock extends StatelessWidget {
  final String label;
  final Color color;
  final int flex;

  const _TimeBlock({
    required this.label,
    required this.color,
    required this.flex,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ExperimentVisual extends StatelessWidget {
  const _ExperimentVisual();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _ExperimentBeforeAfterVisual(),
        const SizedBox(height: 8),
        const _SoftCard(
          icon: Icons.explore_outlined,
          title: '一个小实验',
          body: '在最密的一段之后，留一个不产出的 10 分钟。',
          tags: ['保存', '稍后再看', '跳过也可以'],
          tint: Color(0xFFF0F5EC),
        ),
        const SizedBox(height: 8),
        CustomPaint(
          painter: _TrailPainter(),
          child: const SizedBox(height: 46),
        ),
      ],
    );
  }
}

class _EnergyVisual extends StatelessWidget {
  const _EnergyVisual();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: CustomPaint(
        painter: _EnergyRingPainter(),
        child: const Center(
          child: Text(
            '分布感\n不是评分',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _Palette.ink,
              fontWeight: FontWeight.w500,
              height: 1.25,
            ),
          ),
        ),
      ),
    );
  }
}

class _JourneyMapVisual extends StatelessWidget {
  const _JourneyMapVisual();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8F5),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _Palette.line),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 220,
            width: double.infinity,
            child: CustomPaint(painter: _JourneyMapPainter()),
          ),
          const SizedBox(height: 4),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _LegendItem(label: '8 周路径', color: _Palette.teal),
              _LegendItem(label: '恢复线索', color: _Palette.sage),
              _LegendItem(label: '实验轨迹', color: _Palette.bufferButter),
              _LegendItem(label: '耗力模式', color: _Palette.coral),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeatmapVisual extends StatelessWidget {
  const _HeatmapVisual();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < 56; i++)
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: _heatColor(i),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        const Row(
          children: [
            _Pill(label: '小观察'),
            SizedBox(width: 6),
            _Pill(label: '重复模式'),
            SizedBox(width: 6),
            _Pill(label: '稳定结构'),
          ],
        ),
      ],
    );
  }

  Color _heatColor(int i) {
    if (i % 13 == 0 || i % 17 == 0) return _Palette.teal;
    if (i % 5 == 0 || i % 7 == 0) return _Palette.sage;
    if (i % 3 == 0) return const Color(0xFFDCE8EA);
    return const Color(0xFFF0F3F1);
  }
}

class _LibraryCardsVisual extends StatelessWidget {
  const _LibraryCardsVisual();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _PatternMiniCard(
          icon: Icons.bubble_chart_outlined,
          title: '注意力切换疲劳',
          body: '有些时候，真正耗力的不是某一件事，而是频繁来回切换。',
        ),
        SizedBox(height: 10),
        _PatternMiniCard(
          icon: Icons.view_week_outlined,
          title: '安排过密的一周',
          body: '当很多事情之间没有空隙，恢复感可能会慢慢变薄。',
        ),
      ],
    );
  }
}

class _PatternMiniCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _PatternMiniCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _Palette.warm,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEBD6BB)),
      ),
      child: Row(
        children: [
          _PatternIllustration(icon: icon, label: '模式'),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _Palette.ink,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    color: _Palette.body,
                    height: 1.42,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 9),
                const Row(
                  children: [
                    _ActionPill(
                        label: '保存到观察', icon: Icons.bookmark_add_outlined),
                    SizedBox(width: 6),
                    _SecondaryActionPill(
                        label: '分享', icon: Icons.ios_share_rounded),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SharePreviewVisual extends StatelessWidget {
  const _SharePreviewVisual();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _Palette.ink,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              Icon(Icons.ios_share_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Signal Path',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          SizedBox(height: 22),
          Text(
            '注意力切换疲劳',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '有些时候，真正耗力的不是某一件事，而是频繁来回切换。',
            style: TextStyle(
              color: Color(0xFFEAF1F5),
              fontSize: 15,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 18),
          _Pill(
              label: '可以试试：把消息集中到一个小时间段',
              color: Color(0xFFFFF7E4),
              textColor: _Palette.ink),
        ],
      ),
    );
  }
}

class _AppFrameVisual extends StatelessWidget {
  final int activeIndex;
  final String pageTitle;
  final String pageSubtitle;
  final IconData heroIcon;
  final Color heroColor;
  final List<Widget> cards;

  const _AppFrameVisual({
    required this.activeIndex,
    required this.pageTitle,
    required this.pageSubtitle,
    required this.heroIcon,
    required this.heroColor,
    required this.cards,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _productReview ? 760 : 630,
      decoration: BoxDecoration(
        color: _Palette.canvas,
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: _Palette.line),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _IconBubble(icon: heroIcon, color: heroColor, size: 42),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pageTitle,
                              style: const TextStyle(
                                color: _Palette.ink,
                                fontSize: 24,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              pageSubtitle,
                              style: const TextStyle(
                                color: _Palette.subtle,
                                fontSize: 13.5,
                                height: 1.34,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ...cards.expand((card) => [card, const SizedBox(height: 9)]),
                ],
              ),
            ),
            _BottomNavVisual(activeIndex: activeIndex),
          ],
        ),
      ),
    );
  }
}

class _BottomNavVisual extends StatelessWidget {
  final int activeIndex;

  const _BottomNavVisual({required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    const tabs = [
      (Icons.edit_note_rounded, '今天'),
      (Icons.stacked_bar_chart_rounded, '本周'),
      (Icons.route_rounded, '旅程'),
      (Icons.auto_stories_outlined, '信号库'),
      (Icons.person_outline_rounded, '我的'),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 16),
      decoration: BoxDecoration(
        color: _Palette.paper,
        border: Border(top: BorderSide(color: _Palette.line)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: i == activeIndex
                      ? _Palette.privateMist
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tabs[i].$1,
                      color: i == activeIndex ? _Palette.blue : _Palette.muted,
                      size: 20,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tabs[i].$2,
                      style: TextStyle(
                        color:
                            i == activeIndex ? _Palette.blue : _Palette.muted,
                        fontSize: 10.5,
                        fontWeight: i == activeIndex
                            ? FontWeight.w600
                            : FontWeight.w400,
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

class _EvidenceFooter extends StatelessWidget {
  const _EvidenceFooter();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 2, bottom: 8),
      child: Text(
        'ReleaseQA-2.7E final visual polish 截图。演示数据为合成数据；不含真实用户内容、原始日历、HealthKit 明细或音频。',
        style: TextStyle(
          color: _Palette.muted,
          fontSize: 11.5,
          height: 1.3,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final dots = [
      (Offset(size.width * 0.62, 26), 18.0, _Palette.coral),
      (Offset(size.width * 0.82, 45), 28.0, _Palette.teal),
      (Offset(size.width * 0.68, 82), 24.0, _Palette.sage),
      (Offset(size.width * 0.92, 92), 13.0, _Palette.grayBlue),
      (Offset(size.width * 0.50, 62), 10.0, _Palette.olive),
    ];
    for (final dot in dots) {
      paint.color = dot.$3.withValues(alpha: 0.78);
      canvas.drawCircle(dot.$1, dot.$2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SplashPathPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final pathPaint = Paint()
      ..color = _Palette.blue.withValues(alpha: 0.34)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * 0.16, size.height * 0.62)
      ..cubicTo(
        size.width * 0.32,
        size.height * 0.18,
        size.width * 0.52,
        size.height * 0.78,
        size.width * 0.72,
        size.height * 0.38,
      )
      ..cubicTo(
        size.width * 0.82,
        size.height * 0.18,
        size.width * 0.88,
        size.height * 0.42,
        size.width * 0.92,
        size.height * 0.28,
      );
    canvas.drawPath(path, pathPaint);
    final fill = Paint()..style = PaintingStyle.fill;
    final dots = [
      (Offset(size.width * 0.16, size.height * 0.62), _Palette.sage, 16.0),
      (Offset(size.width * 0.39, size.height * 0.40), _Palette.blue, 20.0),
      (Offset(size.width * 0.62, size.height * 0.58), _Palette.teal, 15.0),
      (Offset(size.width * 0.82, size.height * 0.32), _Palette.coral, 13.0),
    ];
    for (final dot in dots) {
      fill.color = dot.$2.withValues(alpha: 0.72);
      canvas.drawCircle(dot.$1, dot.$3, fill);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = _Palette.signalBlue.withValues(alpha: 0.52)
      ..strokeWidth = size.width * 0.065
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * 0.18, size.height * 0.64)
      ..cubicTo(
        size.width * 0.34,
        size.height * 0.20,
        size.width * 0.50,
        size.height * 0.78,
        size.width * 0.68,
        size.height * 0.35,
      )
      ..cubicTo(
        size.width * 0.76,
        size.height * 0.16,
        size.width * 0.84,
        size.height * 0.42,
        size.width * 0.90,
        size.height * 0.24,
      );
    canvas.drawPath(path, stroke);
    final fill = Paint()..style = PaintingStyle.fill;
    final dots = [
      (Offset(size.width * 0.18, size.height * 0.64), _Palette.sage, 0.13),
      (Offset(size.width * 0.39, size.height * 0.39), _Palette.blue, 0.16),
      (Offset(size.width * 0.61, size.height * 0.56), _Palette.teal, 0.13),
      (Offset(size.width * 0.84, size.height * 0.31), _Palette.coral, 0.11),
    ];
    for (final dot in dots) {
      fill.color = dot.$2.withValues(alpha: 0.84);
      canvas.drawCircle(dot.$1, size.width * dot.$3, fill);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _Palette.blue
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path();
    for (var x = 0.0; x <= size.width; x += 8) {
      final y = size.height / 2 + math.sin(x / 18) * 22 + math.sin(x / 7) * 8;
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TrailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _Palette.sage
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(12, size.height * 0.7)
      ..cubicTo(size.width * 0.3, 2, size.width * 0.55, size.height,
          size.width - 16, 12);
    canvas.drawPath(path, paint);
    final dot = Paint()..color = _Palette.sage;
    for (final x in [16.0, size.width * 0.46, size.width - 18]) {
      canvas.drawCircle(Offset(x, size.height * 0.5), 5, dot);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EnergyRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: 58);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;
    var start = -math.pi / 2;
    final segments = [
      (_Palette.coral, 0.32),
      (_Palette.teal, 0.24),
      (_Palette.sage, 0.25),
      (_Palette.olive, 0.13),
    ];
    for (final segment in segments) {
      paint.color = segment.$1;
      final sweep = segment.$2 * math.pi * 2;
      canvas.drawArc(rect, start, sweep - 0.08, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _JourneyMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final guidePaint = Paint()
      ..color = _Palette.line.withValues(alpha: 0.62)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (var i = 1; i < 4; i++) {
      final x = size.width * i / 4;
      canvas.drawLine(
        Offset(x, size.height * 0.12),
        Offset(x, size.height * 0.88),
        guidePaint,
      );
    }
    final pathPaint = Paint()
      ..color = _Palette.teal.withValues(alpha: 0.42)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * 0.10, size.height * 0.70)
      ..cubicTo(size.width * 0.24, size.height * 0.18, size.width * 0.42,
          size.height * 0.92, size.width * 0.56, size.height * 0.52)
      ..cubicTo(size.width * 0.70, size.height * 0.10, size.width * 0.82,
          size.height * 0.82, size.width * 0.92, size.height * 0.35);
    canvas.drawPath(path, pathPaint);
    final points = [
      (
        Offset(size.width * 0.10, size.height * 0.70),
        _Palette.sage,
        13.0,
        'W1',
        const Offset(-8, 20),
      ),
      (
        Offset(size.width * 0.22, size.height * 0.30),
        _Palette.teal,
        18.0,
        'W2',
        const Offset(-25, 24),
      ),
      (
        Offset(size.width * 0.35, size.height * 0.76),
        _Palette.coral,
        15.0,
        'W3',
        const Offset(-17, 22),
      ),
      (
        Offset(size.width * 0.50, size.height * 0.47),
        _Palette.sage,
        19.0,
        'W4',
        const Offset(-30, 20),
      ),
      (
        Offset(size.width * 0.66, size.height * 0.22),
        _Palette.olive,
        13.0,
        'W5',
        const Offset(-25, 20),
      ),
      (
        Offset(size.width * 0.78, size.height * 0.76),
        _Palette.peach,
        16.0,
        'W6',
        const Offset(-18, 22),
      ),
      (
        Offset(size.width * 0.86, size.height * 0.56),
        _Palette.bufferButter,
        12.0,
        'W7',
        const Offset(-2, 18),
      ),
      (
        Offset(size.width * 0.92, size.height * 0.35),
        _Palette.teal,
        17.0,
        'W8',
        const Offset(-38, 22),
      ),
    ];
    final fill = Paint()..style = PaintingStyle.fill;
    for (final point in points) {
      fill.color = point.$2.withValues(alpha: 0.75);
      canvas.drawCircle(point.$1, point.$3, fill);
      _drawMapLabel(canvas, point.$4, point.$1 + point.$5);
    }
    final labelPaint = Paint()
      ..color = _Palette.ink.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    for (final offset in [
      Offset(size.width * 0.19, size.height * 0.16),
      Offset(size.width * 0.57, size.height * 0.80),
      Offset(size.width * 0.74, size.height * 0.44),
    ]) {
      canvas.drawCircle(offset, 30, labelPaint);
    }
  }

  void _drawMapLabel(Canvas canvas, String label, Offset offset) {
    final paragraph = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: _Palette.subtle,
          fontSize: 10.5,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final bg = Paint()
      ..color = Colors.white.withValues(alpha: 0.70)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          offset.dx - 4,
          offset.dy - 2,
          paragraph.width + 8,
          paragraph.height + 4,
        ),
        const Radius.circular(8),
      ),
      bg,
    );
    paragraph.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SignalDropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = _Palette.signalBlue.withValues(alpha: 0.28)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width * 0.18, size.height * 0.18)
      ..cubicTo(
        size.width * 0.30,
        size.height * 0.42,
        size.width * 0.42,
        size.height * 0.12,
        size.width * 0.53,
        size.height * 0.48,
      )
      ..cubicTo(
        size.width * 0.61,
        size.height * 0.72,
        size.width * 0.72,
        size.height * 0.58,
        size.width * 0.80,
        size.height * 0.78,
      );
    canvas.drawPath(path, line);
    final basin = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.18, size.height * 0.58, size.width * 0.64,
          size.height * 0.30),
      const Radius.circular(28),
    );
    fill.color = _Palette.realitySurface.withValues(alpha: 0.92);
    canvas.drawRRect(basin, fill);
    final stroke = Paint()
      ..color = _Palette.realityLine
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(basin, stroke);
    final dots = [
      (Offset(size.width * 0.21, size.height * 0.20), _Palette.coral, 14.0),
      (Offset(size.width * 0.39, size.height * 0.26), _Palette.teal, 18.0),
      (Offset(size.width * 0.55, size.height * 0.48), _Palette.sage, 15.0),
      (Offset(size.width * 0.73, size.height * 0.70), _Palette.peach, 20.0),
    ];
    for (final dot in dots) {
      fill.color = dot.$2.withValues(alpha: 0.78);
      canvas.drawCircle(dot.$1, dot.$3, fill);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SignalToMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4
      ..color = _Palette.signalBlue.withValues(alpha: 0.26);
    final inputDots = [
      Offset(size.width * 0.12, size.height * 0.28),
      Offset(size.width * 0.20, size.height * 0.54),
      Offset(size.width * 0.28, size.height * 0.36),
      Offset(size.width * 0.19, size.height * 0.76),
    ];
    for (final dot in inputDots) {
      fill.color = _Palette.teal.withValues(alpha: 0.52);
      canvas.drawCircle(dot, 10, fill);
    }
    final weekly = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.38, size.height * 0.24, size.width * 0.20,
          size.height * 0.52),
      const Radius.circular(18),
    );
    fill.color = _Palette.observationSurface;
    canvas.drawRRect(weekly, fill);
    for (var i = 0; i < 4; i++) {
      fill.color = [
        _Palette.coral,
        _Palette.teal,
        _Palette.sage,
        _Palette.olive
      ][i]
          .withValues(alpha: 0.76);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
              size.width * (0.41 + i * 0.035),
              size.height * (0.62 - i * 0.055),
              size.width * 0.025,
              size.height * (0.18 + i * 0.055)),
          const Radius.circular(5),
        ),
        fill,
      );
    }
    final path = Path()
      ..moveTo(size.width * 0.66, size.height * 0.72)
      ..cubicTo(size.width * 0.72, size.height * 0.25, size.width * 0.84,
          size.height * 0.78, size.width * 0.92, size.height * 0.34);
    canvas.drawPath(path, stroke);
    for (final dot in [
      (Offset(size.width * 0.66, size.height * 0.72), _Palette.sage, 12.0),
      (Offset(size.width * 0.75, size.height * 0.40), _Palette.coral, 15.0),
      (
        Offset(size.width * 0.84, size.height * 0.64),
        _Palette.bufferButter,
        12.0
      ),
      (Offset(size.width * 0.92, size.height * 0.34), _Palette.teal, 16.0),
    ]) {
      fill.color = dot.$2.withValues(alpha: 0.80);
      canvas.drawCircle(dot.$1, dot.$3, fill);
    }
    final arrow = Paint()
      ..color = _Palette.muted.withValues(alpha: 0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(size.width * 0.31, size.height * 0.50),
      Offset(size.width * 0.36, size.height * 0.50),
      arrow,
    );
    canvas.drawLine(
      Offset(size.width * 0.59, size.height * 0.50),
      Offset(size.width * 0.64, size.height * 0.50),
      arrow,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SwitchingGapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = _Palette.switchTeal.withValues(alpha: 0.42)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..style = PaintingStyle.fill;
    final left = [
      Offset(size.width * 0.18, size.height * 0.30),
      Offset(size.width * 0.26, size.height * 0.60),
      Offset(size.width * 0.34, size.height * 0.38),
    ];
    final right = [
      Offset(size.width * 0.66, size.height * 0.35),
      Offset(size.width * 0.77, size.height * 0.63),
      Offset(size.width * 0.86, size.height * 0.42),
    ];
    for (var i = 0; i < left.length - 1; i++) {
      canvas.drawLine(left[i], left[i + 1], stroke);
      canvas.drawLine(right[i], right[i + 1], stroke);
    }
    fill.color = _Palette.bufferButter.withValues(alpha: 0.28);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.44, size.height * 0.18, size.width * 0.12,
            size.height * 0.64),
        const Radius.circular(18),
      ),
      fill,
    );
    for (final dot in [...left, ...right]) {
      fill.color = _Palette.switchTeal.withValues(alpha: 0.76);
      canvas.drawCircle(dot, 9, fill);
    }
    fill.color = _Palette.bufferButter;
    canvas.drawCircle(Offset(size.width * 0.50, size.height * 0.50), 7, fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CompactSignalKitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = _Palette.switchTeal.withValues(alpha: 0.40)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * 0.14, size.height * 0.62)
      ..cubicTo(
        size.width * 0.28,
        size.height * 0.18,
        size.width * 0.46,
        size.height * 0.74,
        size.width * 0.64,
        size.height * 0.34,
      )
      ..cubicTo(
        size.width * 0.74,
        size.height * 0.12,
        size.width * 0.82,
        size.height * 0.48,
        size.width * 0.90,
        size.height * 0.25,
      );
    canvas.drawPath(path, stroke);

    final fill = Paint()..style = PaintingStyle.fill;
    final gap = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.44,
        size.height * 0.20,
        size.width * 0.13,
        size.height * 0.56,
      ),
      const Radius.circular(12),
    );
    fill.color = _Palette.bufferButter.withValues(alpha: 0.30);
    canvas.drawRRect(gap, fill);

    final dots = [
      (Offset(size.width * 0.14, size.height * 0.62), _Palette.sage, 6.0),
      (Offset(size.width * 0.34, size.height * 0.35), _Palette.blue, 8.0),
      (Offset(size.width * 0.62, size.height * 0.47), _Palette.teal, 7.0),
      (Offset(size.width * 0.88, size.height * 0.28), _Palette.coral, 5.8),
    ];
    for (final dot in dots) {
      fill.color = dot.$2.withValues(alpha: 0.82);
      canvas.drawCircle(dot.$1, dot.$3, fill);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Palette {
  static const brandCoral = Color(0xFFF8FBFD);
  static const canvas = Color(0xFFF8FBFD);
  static const paper = Color(0xFFFFFFFF);
  static const mist = Color(0xFFEAF1F3);
  static const softBlue = Color(0xFFE3EEF4);
  static const warm = Color(0xFFF7FAFC);
  static const sticky = Color(0xFFF6FAFD);
  static const line = Color(0xFFDCE6EE);
  static const ink = Color(0xFF1F2A33);
  static const body = Color(0xFF394550);
  static const subtle = Color(0xFF697684);
  static const muted = Color(0xFF7C8791);
  static const blue = Color(0xFF496D89);
  static const teal = Color(0xFF5F9AA0);
  static const sage = Color(0xFF83A881);
  static const coral = Color(0xFF7C91B8);
  static const peach = Color(0xFFD9C45E);
  static const lavender = Color(0xFF8173B6);
  static const olive = Color(0xFF9A9B62);
  static const grayBlue = Color(0xFF9AAABC);
  static const signalBlue = blue;
  static const recoverySage = sage;
  static const switchTeal = teal;
  static const drainCoral = coral;
  static const bufferButter = Color(0xFFD6C783);
  static const librarySand = Color(0xFFF7FAFC);
  static const privateMist = mist;
  static const realitySurface = Color(0xFFFFFFFF);
  static const realityLine = Color(0xFFDCE6EE);
  static const observationSurface = Color(0xFFEAF1F3);
  static const observationLine = Color(0xFFD3E1E6);
  static const suggestionSurface = Color(0xFFF8FAF2);
  static const suggestionLine = Color(0xFFDDE6C8);
  static const stateBadge = Color(0xFFE8EEF1);
  static const stateText = Color(0xFF5F7080);
}

final _scenes = <_VisualScene>[
  _VisualScene(
    fileName: "00_onboarding_brand",
    title: "",
    subtitle: "",
    summary: const [],
    visual: const _OnboardingBrandVisual(),
    sections: const [],
  ),
  _VisualScene(
    fileName: "01_onboarding_input",
    title: "",
    subtitle: "",
    summary: const [],
    visual: const _OnboardingInputVisual(),
    sections: const [],
  ),
  _VisualScene(
    fileName: "02_onboarding_output",
    title: "",
    subtitle: "",
    summary: const [],
    visual: const _OnboardingOutputVisual(),
    sections: const [],
  ),
  _VisualScene(
    fileName: "03_today_real_frame",
    title: "",
    subtitle: "",
    summary: const [],
    visual: const _AppFrameVisual(
      activeIndex: 0,
      pageTitle: "Today",
      pageSubtitle: "把今天的生活信号先放在这里。",
      heroIcon: Icons.edit_note_rounded,
      heroColor: _Palette.blue,
      cards: [
        _ComposerVisual(),
        _InfoCard(
          kind: _InfoKind.reality,
          icon: Icons.notes_rounded,
          title: "你留下的内容",
          body: "计划会很密，结束后脑子有点散；午后走了十分钟，好像回来了一些。",
          states: ["文字", "已同步"],
        ),
        _AiSuggestionVisual(),
      ],
    ),
    sections: const [],
  ),
  _VisualScene(
    fileName: "04_weekly_real_frame",
    title: "",
    subtitle: "",
    summary: const [],
    visual: const _AppFrameVisual(
      activeIndex: 1,
      pageTitle: "Weekly",
      pageSubtitle: "这周可以先这样看：一个模式，一个小实验。",
      heroIcon: Icons.stacked_bar_chart_rounded,
      heroColor: _Palette.teal,
      cards: [
        _WeeklyVisual(),
        _StackedBarVisual(),
        _WeeklyExperimentCard(),
      ],
    ),
    sections: const [],
  ),
  _VisualScene(
    fileName: "05_journey_real_frame",
    title: "",
    subtitle: "",
    summary: const [],
    visual: const _AppFrameVisual(
      activeIndex: 2,
      pageTitle: "Journey",
      pageSubtitle: "看见这段时间反复出现的生活结构。",
      heroIcon: Icons.route_rounded,
      heroColor: _Palette.sage,
      cards: [
        _JourneyMapVisual(),
        _InfoCard(
          kind: _InfoKind.observation,
          icon: Icons.bubble_chart_outlined,
          title: "最近反复出现的模式",
          body: "当计划、消息和照顾责任挤在一起时，切换负担会更明显。",
          states: ["8 周路径", "不是评分"],
        ),
        _InfoCard(
          kind: _InfoKind.suggestion,
          icon: Icons.tune_rounded,
          title: "复盘与调整",
          body: "缓冲设计在切换高的时候可能有帮助；如果太大，就变小一点。",
          actions: ["下次试小一点"],
        ),
      ],
    ),
    sections: const [],
  ),
  _VisualScene(
    fileName: "06_library_real_frame",
    title: "",
    subtitle: "",
    summary: const [],
    visual: const _AppFrameVisual(
      activeIndex: 3,
      pageTitle: "信号库",
      pageSubtitle: "一些官方整理的生活模式，可以先放进观察里。",
      heroIcon: Icons.auto_stories_outlined,
      heroColor: _Palette.peach,
      cards: [
        _LibraryCardsVisual(),
        _InfoCard(
          kind: _InfoKind.reality,
          icon: Icons.bookmark_add_outlined,
          title: "加入我的观察",
          body: "这是信号库里的一个参考模式。加入后，只会放进你的私人观察，不会变成你的原文。",
          states: ["私密", "还没确认"],
          actions: ["加入观察"],
        ),
      ],
    ),
    sections: const [],
  ),
  _VisualScene(
    fileName: "07_me_real_frame",
    title: "",
    subtitle: "",
    summary: const [],
    visual: const _AppFrameVisual(
      activeIndex: 4,
      pageTitle: "Me",
      pageSubtitle: "管理 Pro、额度、恢复购买和数据边界。",
      heroIcon: Icons.person_outline_rounded,
      heroColor: _Palette.blue,
      cards: [
        _InfoCard(
          kind: _InfoKind.suggestion,
          icon: Icons.workspace_premium_outlined,
          title: "Signal Path Pro",
          body: "解锁更深的 Weekly、Journey、额度和轻量对话。",
          states: ["月付 Pro", "年付 Pro"],
          secondaryActions: ["恢复购买"],
        ),
        _QuotaUsageCard(),
        _InfoCard(
          kind: _InfoKind.reality,
          icon: Icons.privacy_tip_outlined,
          title: "隐私与数据",
          body: "信号库不使用你的原文；日历和健康线索只作为抽象辅助。",
          states: ["不上传明细", "用户确认优先"],
        ),
      ],
    ),
    sections: const [],
  ),
];
