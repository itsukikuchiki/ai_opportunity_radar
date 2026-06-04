import 'dart:math' as math;

import 'package:flutter/material.dart';

const _ink = Color(0xFF223044);
const _body = Color(0xFF394B5C);
const _muted = Color(0xFF728292);
const _line = Color(0xFFDCE6EE);
const _paper = Color(0xFFFFFFFF);
const _realitySurface = Color(0xFFF8FBFD);
const _signalBlue = Color(0xFF496D89);
const _teal = Color(0xFF5F9AA0);
const _sage = Color(0xFF83A881);
const _gold = Color(0xFFE4C96D);
const _coral = Color(0xFFC98787);
const _peach = Color(0xFFD7A9A2);

class CompactSignalPathVisual extends StatelessWidget {
  final double height;

  const CompactSignalPathVisual({super.key, this.height = 72});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _CompactSignalPathPainter()),
    );
  }
}

class SignalDropVisual extends StatelessWidget {
  final double height;

  const SignalDropVisual({super.key, this.height = 190});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: _paper.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
      ),
      child: CustomPaint(painter: _SignalDropPainter()),
    );
  }
}

class SignalToMapVisual extends StatelessWidget {
  final double height;

  const SignalToMapVisual({super.key, this.height = 210});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: _paper.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
      ),
      child: CustomPaint(painter: _SignalToMapPainter()),
    );
  }
}

class SwitchingGapVisual extends StatelessWidget {
  const SwitchingGapVisual({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 104,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFDCE6EE)),
        ),
        child: CustomPaint(painter: _SwitchingGapPainter()),
      ),
    );
  }
}

class LibraryFlowVisual extends StatelessWidget {
  const LibraryFlowVisual({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _paper.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
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

class EnergyRingVisual extends StatelessWidget {
  final double height;
  final String label;

  const EnergyRingVisual({
    super.key,
    this.height = 132,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _EnergyRingPainter(),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: _ink,
                  height: 1.25,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ),
    );
  }
}

class JourneyPathVisual extends StatelessWidget {
  final int weakCount;
  final int repeatedCount;
  final int stableCount;
  final int experimentCount;

  const JourneyPathVisual({
    super.key,
    required this.weakCount,
    required this.repeatedCount,
    required this.stableCount,
    required this.experimentCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDCE6EE)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 210,
            width: double.infinity,
            child: CustomPaint(
              painter: _JourneyPathPainter(
                weakCount: weakCount,
                repeatedCount: repeatedCount,
                stableCount: stableCount,
                experimentCount: experimentCount,
              ),
            ),
          ),
          const Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _LegendDot(label: 'W1-W8', color: Color(0xFF5F9AA0)),
              _LegendDot(label: '恢复线索', color: Color(0xFF83A881)),
              _LegendDot(label: '实验轨迹', color: Color(0xFFE4C96D)),
              _LegendDot(label: '耗力模式', color: Color(0xFFC98787)),
            ],
          ),
        ],
      ),
    );
  }
}

class PatternIllustration extends StatelessWidget {
  final String patternId;

  const PatternIllustration({super.key, required this.patternId});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 86,
      height: 86,
      child: CustomPaint(painter: _PatternPainter(patternId)),
    );
  }
}

class ExperimentPathVisual extends StatelessWidget {
  const ExperimentPathVisual({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _paper.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
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
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _signalBlue.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _signalBlue, size: 19),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: _body,
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
      child: Icon(Icons.arrow_forward_rounded, color: _muted, size: 18),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendDot({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _CompactSignalPathPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = const Color(0xFF5F9AA0).withValues(alpha: 0.42)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * 0.08, size.height * 0.66)
      ..cubicTo(size.width * 0.25, size.height * 0.10, size.width * 0.43,
          size.height * 0.78, size.width * 0.62, size.height * 0.36)
      ..cubicTo(size.width * 0.73, size.height * 0.10, size.width * 0.84,
          size.height * 0.52, size.width * 0.94, size.height * 0.24);
    canvas.drawPath(path, stroke);

    final fill = Paint()..style = PaintingStyle.fill;
    fill.color = const Color(0xFFE4C96D).withValues(alpha: 0.28);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.44, size.height * 0.16, size.width * 0.13,
            size.height * 0.62),
        const Radius.circular(10),
      ),
      fill,
    );
    final dots = [
      (
        Offset(size.width * 0.08, size.height * 0.66),
        const Color(0xFF83A881),
        6.0
      ),
      (
        Offset(size.width * 0.31, size.height * 0.34),
        const Color(0xFF496D89),
        8.0
      ),
      (
        Offset(size.width * 0.64, size.height * 0.48),
        const Color(0xFF5F9AA0),
        7.0
      ),
      (
        Offset(size.width * 0.93, size.height * 0.26),
        const Color(0xFFC98787),
        6.0
      ),
    ];
    for (final dot in dots) {
      fill.color = dot.$2.withValues(alpha: 0.84);
      canvas.drawCircle(dot.$1, dot.$3, fill);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SignalDropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = _signalBlue.withValues(alpha: 0.28)
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
    fill.color = _realitySurface.withValues(alpha: 0.92);
    canvas.drawRRect(basin, fill);
    final stroke = Paint()
      ..color = _line
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(basin, stroke);
    final dots = [
      (Offset(size.width * 0.21, size.height * 0.20), _coral, 14.0),
      (Offset(size.width * 0.39, size.height * 0.26), _teal, 18.0),
      (Offset(size.width * 0.55, size.height * 0.48), _sage, 15.0),
      (Offset(size.width * 0.73, size.height * 0.70), _peach, 20.0),
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
      ..color = _signalBlue.withValues(alpha: 0.26);
    final inputDots = [
      Offset(size.width * 0.12, size.height * 0.28),
      Offset(size.width * 0.20, size.height * 0.54),
      Offset(size.width * 0.28, size.height * 0.36),
      Offset(size.width * 0.19, size.height * 0.76),
    ];
    for (final dot in inputDots) {
      fill.color = _teal.withValues(alpha: 0.52);
      canvas.drawCircle(dot, 10, fill);
    }
    final weekly = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.38, size.height * 0.24, size.width * 0.20,
          size.height * 0.52),
      const Radius.circular(18),
    );
    fill.color = const Color(0xFFEAF2F8);
    canvas.drawRRect(weekly, fill);
    for (var i = 0; i < 4; i++) {
      fill.color = [_coral, _teal, _sage, _gold][i].withValues(alpha: 0.76);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width * (0.41 + i * 0.035),
            size.height * (0.62 - i * 0.055),
            size.width * 0.025,
            size.height * (0.18 + i * 0.055),
          ),
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
      (Offset(size.width * 0.66, size.height * 0.72), _sage, 12.0),
      (Offset(size.width * 0.75, size.height * 0.40), _coral, 15.0),
      (Offset(size.width * 0.84, size.height * 0.64), _gold, 12.0),
      (Offset(size.width * 0.92, size.height * 0.34), _teal, 16.0),
    ]) {
      fill.color = dot.$2.withValues(alpha: 0.80);
      canvas.drawCircle(dot.$1, dot.$3, fill);
    }
    final arrow = Paint()
      ..color = _muted.withValues(alpha: 0.5)
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
      ..color = const Color(0xFF5F9AA0).withValues(alpha: 0.44)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..style = PaintingStyle.fill;
    final left = [
      Offset(size.width * 0.12, size.height * 0.58),
      Offset(size.width * 0.24, size.height * 0.36),
      Offset(size.width * 0.36, size.height * 0.56),
    ];
    final right = [
      Offset(size.width * 0.64, size.height * 0.42),
      Offset(size.width * 0.76, size.height * 0.62),
      Offset(size.width * 0.88, size.height * 0.38),
    ];
    for (var i = 0; i < 2; i++) {
      canvas.drawLine(left[i], left[i + 1], stroke);
      canvas.drawLine(right[i], right[i + 1], stroke);
    }
    fill.color = const Color(0xFFE4C96D).withValues(alpha: 0.28);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.44, size.height * 0.16, size.width * 0.12,
            size.height * 0.68),
        const Radius.circular(16),
      ),
      fill,
    );
    for (final dot in [...left, ...right]) {
      fill.color = const Color(0xFF5F9AA0).withValues(alpha: 0.76);
      canvas.drawCircle(dot, 7, fill);
    }

    final labelPaint = Paint()
      ..color = const Color(0xFF496D89).withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width * 0.50, size.height * 0.50),
      math.min(size.width, size.height) * 0.12,
      labelPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _JourneyPathPainter extends CustomPainter {
  final int weakCount;
  final int repeatedCount;
  final int stableCount;
  final int experimentCount;

  _JourneyPathPainter({
    required this.weakCount,
    required this.repeatedCount,
    required this.stableCount,
    required this.experimentCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final top = size.height * 0.12;
    final bottom = size.height * 0.86;
    final usableHeight = bottom - top;
    double y(double factor) => top + usableHeight * factor;

    final guide = Paint()
      ..color = const Color(0xFFDCE6EE).withValues(alpha: 0.72)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final x = size.width * i / 4;
      canvas.drawLine(Offset(x, top), Offset(x, bottom), guide);
    }
    final pathPaint = Paint()
      ..color = const Color(0xFF5F9AA0).withValues(alpha: 0.48)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * 0.08, y(0.70))
      ..cubicTo(size.width * 0.22, y(0.18), size.width * 0.40, y(0.90),
          size.width * 0.56, y(0.50))
      ..cubicTo(size.width * 0.70, y(0.12), size.width * 0.82, y(0.80),
          size.width * 0.94, y(0.32));
    canvas.drawPath(path, pathPaint);

    final colors = [
      const Color(0xFF83A881),
      const Color(0xFF5F9AA0),
      const Color(0xFFC98787),
      const Color(0xFF83A881),
      const Color(0xFFE4C96D),
      const Color(0xFFC98787),
      const Color(0xFFE4C96D),
      const Color(0xFF5F9AA0),
    ];
    final points = [
      Offset(size.width * 0.08, y(0.70)),
      Offset(size.width * 0.22, y(0.31)),
      Offset(size.width * 0.35, y(0.76)),
      Offset(size.width * 0.50, y(0.47)),
      Offset(size.width * 0.65, y(0.23)),
      Offset(size.width * 0.78, y(0.75)),
      Offset(size.width * 0.86, y(0.55)),
      Offset(size.width * 0.94, y(0.32)),
    ];
    final intensity =
        math.max(1, weakCount + repeatedCount + stableCount + experimentCount);
    final fill = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < points.length; i++) {
      fill.color = colors[i].withValues(alpha: 0.78);
      canvas.drawCircle(points[i], 8 + ((intensity + i) % 4) * 2, fill);
      _drawLabel(canvas, 'W${i + 1}', points[i] + const Offset(-8, 17));
    }
  }

  void _drawLabel(Canvas canvas, String text, Offset offset) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Color(0xFF697684), fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _JourneyPathPainter oldDelegate) {
    return oldDelegate.weakCount != weakCount ||
        oldDelegate.repeatedCount != repeatedCount ||
        oldDelegate.stableCount != stableCount ||
        oldDelegate.experimentCount != experimentCount;
  }
}

class _EnergyRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.34;
    final base = Paint()
      ..color = _line.withValues(alpha: 0.70)
      ..strokeWidth = 13
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, base);
    final arcs = [
      (_teal, -math.pi / 2, math.pi * 0.52),
      (_gold, math.pi * 0.08, math.pi * 0.38),
      (_coral, math.pi * 0.54, math.pi * 0.30),
      (_sage, math.pi * 0.90, math.pi * 0.42),
    ];
    for (final arc in arcs) {
      final paint = Paint()
        ..color = arc.$1.withValues(alpha: 0.74)
        ..strokeWidth = 13
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        arc.$2,
        arc.$3,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PatternPainter extends CustomPainter {
  final String patternId;

  _PatternPainter(this.patternId);

  @override
  void paint(Canvas canvas, Size size) {
    final seed = patternId.codeUnits.fold<int>(0, (sum, value) => sum + value);
    final fill = Paint()..style = PaintingStyle.fill;
    final line = Paint()
      ..color = const Color(0xFF496D89).withValues(alpha: 0.34)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final points = List<Offset>.generate(4, (index) {
      final angle = (seed % 7 + index * 2) * math.pi / 7;
      return Offset(
        size.width / 2 + math.cos(angle) * (18 + index * 2),
        size.height / 2 + math.sin(angle) * (16 + index * 2),
      );
    });
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, line);
    final colors = [
      const Color(0xFF496D89),
      const Color(0xFF5F9AA0),
      const Color(0xFF83A881),
      const Color(0xFFE4C96D),
    ];
    for (var i = 0; i < points.length; i++) {
      fill.color = colors[i].withValues(alpha: 0.76);
      canvas.drawCircle(points[i], 7 + (i % 2) * 2, fill);
    }
  }

  @override
  bool shouldRepaint(covariant _PatternPainter oldDelegate) {
    return oldDelegate.patternId != patternId;
  }
}
