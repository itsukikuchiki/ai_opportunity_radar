import 'dart:math' as math;

import 'package:flutter/material.dart';

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

class SwitchingGapVisual extends StatelessWidget {
  const SwitchingGapVisual({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDCE6EE)),
      ),
      child: CustomPaint(painter: _SwitchingGapPainter()),
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
    return SizedBox(
      height: 70,
      width: double.infinity,
      child: CustomPaint(painter: _ExperimentPathPainter()),
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
      Offset(size.width * 0.16, size.height * 0.30),
      Offset(size.width * 0.26, size.height * 0.63),
      Offset(size.width * 0.36, size.height * 0.38),
    ];
    final right = [
      Offset(size.width * 0.64, size.height * 0.35),
      Offset(size.width * 0.76, size.height * 0.65),
      Offset(size.width * 0.88, size.height * 0.40),
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
      fill.color = const Color(0xFF5F9AA0).withValues(alpha: 0.78);
      canvas.drawCircle(dot, 8, fill);
    }
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
    final guide = Paint()
      ..color = const Color(0xFFDCE6EE).withValues(alpha: 0.72)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final x = size.width * i / 4;
      canvas.drawLine(Offset(x, 18), Offset(x, size.height - 18), guide);
    }
    final pathPaint = Paint()
      ..color = const Color(0xFF5F9AA0).withValues(alpha: 0.48)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * 0.08, size.height * 0.70)
      ..cubicTo(size.width * 0.22, size.height * 0.18, size.width * 0.40,
          size.height * 0.90, size.width * 0.56, size.height * 0.50)
      ..cubicTo(size.width * 0.70, size.height * 0.10, size.width * 0.82,
          size.height * 0.80, size.width * 0.94, size.height * 0.32);
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
      Offset(size.width * 0.08, size.height * 0.70),
      Offset(size.width * 0.22, size.height * 0.31),
      Offset(size.width * 0.35, size.height * 0.76),
      Offset(size.width * 0.50, size.height * 0.47),
      Offset(size.width * 0.65, size.height * 0.23),
      Offset(size.width * 0.78, size.height * 0.75),
      Offset(size.width * 0.86, size.height * 0.55),
      Offset(size.width * 0.94, size.height * 0.32),
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

class _ExperimentPathPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0xFF83A881).withValues(alpha: 0.52)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(12, size.height * 0.66)
      ..cubicTo(size.width * 0.30, 6, size.width * 0.58, size.height,
          size.width - 14, 12);
    canvas.drawPath(path, line);
    final fill = Paint()..style = PaintingStyle.fill;
    for (final point in [
      Offset(14, size.height * 0.66),
      Offset(size.width * 0.48, size.height * 0.43),
      Offset(size.width - 14, 12),
    ]) {
      fill.color = const Color(0xFF83A881).withValues(alpha: 0.82);
      canvas.drawCircle(point, 6, fill);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
