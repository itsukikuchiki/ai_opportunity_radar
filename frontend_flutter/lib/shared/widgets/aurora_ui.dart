import 'dart:math' as math;

import 'package:flutter/material.dart';

class AuroraColors {
  static const ink = Color(0xFF252B4A);
  static const muted = Color(0xFF7D849B);
  static const line = Color(0xFFE5E3F2);
  static const surface = Color(0xFFFFFCFB);
  static const purple = Color(0xFF7767F4);
  static const blue = Color(0xFF5E8FF0);
  static const mint = Color(0xFF55C8A2);
  static const orange = Color(0xFFFFA05F);
  static const gold = Color(0xFFF7C85E);
}

/// Shared density and typography contract for the five primary tab pages.
///
/// Today is the reference surface. Weekly, Experiment, Journey and Me use
/// these values so their information hierarchy and viewport density stay
/// consistent instead of drifting independently.
abstract final class AuroraMainPageSpec {
  static const double horizontalPadding = 18;
  static const double topPadding = 14;
  static const double bottomNavigationClearance = 96;
  static const double heroGap = 14;
  static const double sectionGap = 10;
  static const double cardRadius = 18;
  static const double cardRadiusLarge = 20;
  static const double heroTitleSize = 36;
  static const double compactHeroTitleSize = 34;
  static const double heroSubtitleSize = 13.5;
  static const double sectionTitleSize = 16;
  static const double bodySize = 14;
  static const double supportingSize = 12;
  static const double compactBreakpoint = 360;
  static const double mobileSingleColumnBreakpoint = 600;
  static const EdgeInsets cardPadding = EdgeInsets.all(12);
  static const EdgeInsets comfortableCardPadding =
      EdgeInsets.fromLTRB(16, 14, 16, 16);

  static EdgeInsets scrollPadding(BuildContext context) {
    return EdgeInsets.fromLTRB(
      horizontalPadding,
      topPadding,
      horizontalPadding,
      MediaQuery.paddingOf(context).bottom + bottomNavigationClearance,
    );
  }

  static double responsiveHeroTitleSize(BuildContext context) {
    return MediaQuery.sizeOf(context).width < compactBreakpoint
        ? compactHeroTitleSize
        : heroTitleSize;
  }
}

class AuroraPage extends StatelessWidget {
  final Widget child;

  const AuroraPage({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [0, 0.28, 0.66, 1],
              colors: [
                Color(0xFFFFF5EA),
                Color(0xFFFFF9F7),
                Color(0xFFF1EEFF),
                Color(0xFFEAF3FF),
              ],
            ),
          ),
        ),
        Positioned(
          left: -126,
          top: -132,
          width: 382,
          height: 382,
          child: _AuroraGlow(
            colors: [
              const Color(0xFFFFCDAE).withValues(alpha: 0.36),
              const Color(0xFFFFE8D5).withValues(alpha: 0.24),
              const Color(0x00FFFFFF),
            ],
          ),
        ),
        Positioned(
          right: -116,
          top: -106,
          width: 410,
          height: 410,
          child: _AuroraGlow(
            colors: [
              const Color(0xFFBFC5FF).withValues(alpha: 0.36),
              const Color(0xFFE7DFFF).withValues(alpha: 0.30),
              const Color(0x00FFFFFF),
            ],
          ),
        ),
        Positioned(
          right: -156,
          bottom: 42,
          width: 446,
          height: 446,
          child: _AuroraGlow(
            colors: [
              const Color(0xFFCAD7FF).withValues(alpha: 0.28),
              const Color(0xFFD9EEFF).withValues(alpha: 0.22),
              const Color(0x00FFFFFF),
            ],
          ),
        ),
        Positioned(
          left: -164,
          bottom: -88,
          width: 438,
          height: 438,
          child: _AuroraGlow(
            colors: [
              const Color(0xFFFFDEC8).withValues(alpha: 0.22),
              const Color(0xFFD9F3EC).withValues(alpha: 0.18),
              const Color(0x00FFFFFF),
            ],
          ),
        ),
        const Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _AuroraAtmospherePainter()),
          ),
        ),
        child,
      ],
    );
  }
}

class _AuroraAtmospherePainter extends CustomPainter {
  const _AuroraAtmospherePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final haze = Paint()..style = PaintingStyle.fill;

    final upperRibbon = Path()
      ..moveTo(-size.width * 0.18, size.height * 0.20)
      ..cubicTo(
        size.width * 0.18,
        size.height * 0.12,
        size.width * 0.34,
        size.height * 0.30,
        size.width * 0.62,
        size.height * 0.20,
      )
      ..cubicTo(
        size.width * 0.84,
        size.height * 0.12,
        size.width * 0.92,
        size.height * 0.22,
        size.width * 1.18,
        size.height * 0.12,
      )
      ..lineTo(size.width * 1.18, size.height * 0.31)
      ..cubicTo(
        size.width * 0.82,
        size.height * 0.39,
        size.width * 0.50,
        size.height * 0.28,
        -size.width * 0.18,
        size.height * 0.39,
      )
      ..close();
    haze.shader = LinearGradient(
      colors: [
        Colors.white.withValues(alpha: 0.30),
        const Color(0xFFF0E9FF).withValues(alpha: 0.22),
        const Color(0xFFDDEBFF).withValues(alpha: 0.16),
      ],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.42));
    canvas.drawPath(upperRibbon, haze);

    final lowerRibbon = Path()
      ..moveTo(-size.width * 0.10, size.height * 0.72)
      ..cubicTo(
        size.width * 0.22,
        size.height * 0.64,
        size.width * 0.46,
        size.height * 0.82,
        size.width * 0.76,
        size.height * 0.72,
      )
      ..cubicTo(
        size.width * 0.92,
        size.height * 0.67,
        size.width,
        size.height * 0.70,
        size.width * 1.12,
        size.height * 0.64,
      )
      ..lineTo(size.width * 1.12, size.height * 0.88)
      ..cubicTo(
        size.width * 0.74,
        size.height * 0.92,
        size.width * 0.42,
        size.height * 0.78,
        -size.width * 0.10,
        size.height * 0.91,
      )
      ..close();
    haze.shader = LinearGradient(
      colors: [
        const Color(0xFFFFEFE3).withValues(alpha: 0.16),
        Colors.white.withValues(alpha: 0.25),
        const Color(0xFFE1E8FF).withValues(alpha: 0.20),
      ],
    ).createShader(
        Rect.fromLTWH(0, size.height * 0.60, size.width, size.height * 0.36));
    canvas.drawPath(lowerRibbon, haze);

    final sparklePaint = Paint()..color = Colors.white.withValues(alpha: 0.68);
    final sparkles = <Offset>[
      Offset(size.width * 0.11, size.height * 0.09),
      Offset(size.width * 0.82, size.height * 0.16),
      Offset(size.width * 0.91, size.height * 0.44),
      Offset(size.width * 0.14, size.height * 0.58),
      Offset(size.width * 0.73, size.height * 0.79),
    ];
    for (final point in sparkles) {
      canvas.drawCircle(point, 1.7, sparklePaint);
      canvas.drawLine(
          point - const Offset(5, 0), point + const Offset(5, 0), sparklePaint);
      canvas.drawLine(
          point - const Offset(0, 5), point + const Offset(0, 5), sparklePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AuroraGlow extends StatelessWidget {
  final List<Color> colors;

  const _AuroraGlow({required this.colors});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          radius: 0.72,
          colors: colors,
          stops: const [0, 0.46, 1],
        ),
      ),
    );
  }
}

class AuroraSafeTopMask extends StatelessWidget {
  final double extraHeight;

  const AuroraSafeTopMask({super.key, this.extraHeight = 18});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top + extraHeight;
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          height: top,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFFFFF4E9),
                const Color(0xFFFFF4E9).withValues(alpha: 0.92),
                AuroraColors.surface.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AuroraCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;
  final BorderRadiusGeometry borderRadius;
  final Color? color;
  final Border? border;

  const AuroraCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.gradient,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.color,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null && color != null ? color : null,
        gradient: gradient ??
            (color == null
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.84),
                      const Color(0xFFF8F5FF).withValues(alpha: 0.72),
                      const Color(0xFFF4F9FF).withValues(alpha: 0.68),
                    ],
                  )
                : null),
        borderRadius: borderRadius,
        border: border ??
            Border.all(
              color: Colors.white.withValues(alpha: 0.80),
              width: 1,
            ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7164A8).withValues(alpha: 0.10),
            blurRadius: 30,
            spreadRadius: -14,
            offset: const Offset(0, 15),
          ),
          BoxShadow(
            color: const Color(0xFFFFB17C).withValues(alpha: 0.08),
            blurRadius: 30,
            spreadRadius: -14,
            offset: const Offset(-6, 10),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.92),
            blurRadius: 12,
            spreadRadius: -7,
            offset: const Offset(-4, -4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Shared elevated surface for dialogs and root modal sheets.
///
/// Secondary flows use the same warm pearl / lavender atmosphere as Today,
/// instead of falling back to Material's opaque grey-white modal surface.
/// This widget deliberately owns presentation only; callers keep their
/// existing navigation and form behaviour.
class AuroraModalSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry borderRadius;

  const AuroraModalSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 18),
    this.borderRadius = const BorderRadius.all(Radius.circular(28)),
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        clipBehavior: Clip.antiAlias,
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFFFFCFA).withValues(alpha: 0.98),
              const Color(0xFFF9F5FF).withValues(alpha: 0.97),
              const Color(0xFFF1F7FF).withValues(alpha: 0.96),
            ],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.94),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AuroraColors.purple.withValues(alpha: 0.18),
              blurRadius: 42,
              spreadRadius: -12,
              offset: const Offset(0, 20),
            ),
            BoxShadow(
              color: AuroraColors.orange.withValues(alpha: 0.10),
              blurRadius: 32,
              spreadRadius: -15,
              offset: const Offset(-10, 8),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

/// Responsive Aurora dialog frame used by the app's editable decisions and
/// lightweight confirmations. Actions wrap at narrow widths, preserving 44pt
/// targets without clipping at the 390 × 844 QA viewport.
class AuroraDialog extends StatelessWidget {
  final Widget title;
  final Widget content;
  final List<Widget> actions;
  final EdgeInsets insetPadding;

  const AuroraDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.insetPadding = const EdgeInsets.symmetric(
      horizontal: 18,
      vertical: 24,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.84;
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: insetPadding,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 460, maxHeight: maxHeight),
        child: AuroraModalSurface(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DefaultTextStyle.merge(
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AuroraColors.ink,
                      fontWeight: FontWeight.w700,
                      height: 1.18,
                    ),
                child: title,
              ),
              const SizedBox(height: 14),
              Flexible(
                fit: FlexFit.loose,
                child: SingleChildScrollView(child: content),
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: actions,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AuroraBrandMark extends StatelessWidget {
  final double size;

  const AuroraBrandMark({super.key, this.size = 34});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _AuroraBrandPainter()),
    );
  }
}

/// A soft, reusable hero emblem based on the app icon. It keeps secondary
/// pages visually connected to Today without introducing page-specific art.
class AuroraHeroEmblem extends StatelessWidget {
  final double size;
  final double opacity;

  const AuroraHeroEmblem({
    super.key,
    this.size = 128,
    this.opacity = 0.88,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 0.86,
            height: size * 0.86,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFBBA7FF).withValues(alpha: 0.24),
                  const Color(0xFFFFC894).withValues(alpha: 0.14),
                  const Color(0x00FFFFFF),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AuroraColors.purple.withValues(alpha: 0.12),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          Opacity(
            opacity: opacity,
            child: Image.asset(
              'assets/brand-icon-transparent.png',
              width: size,
              height: size,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ],
      ),
    );
  }
}

class AuroraHeroTitle extends StatelessWidget {
  final String text;
  final double fontSize;
  final int maxLines;

  const AuroraHeroTitle({
    super.key,
    required this.text,
    required this.fontSize,
    this.maxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Color(0xFF5487F4),
          Color(0xFF806AF4),
          Color(0xFF9A63E8),
        ],
      ).createShader(bounds),
      child: Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontSize: fontSize,
              height: 1.04,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.25,
            ),
      ),
    );
  }
}

class AuroraSectionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const AuroraSectionIcon({
    super.key,
    required this.icon,
    this.color = AuroraColors.purple,
    this.size = 34,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.34),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.94),
            Color.lerp(color, AuroraColors.blue, 0.46)!.withValues(alpha: 0.76),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.76)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.22),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.56),
    );
  }
}

class AuroraTopBar extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final bool showBrand;

  const AuroraTopBar({
    super.key,
    required this.title,
    this.trailing,
    this.showBrand = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (showBrand)
            Align(
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AuroraBrandMark(size: 34),
                  const SizedBox(width: 10),
                  Text(
                    'Signal Path',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AuroraColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          Text(
            title,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AuroraColors.ink,
              height: 1.05,
            ),
          ),
          if (trailing != null)
            Align(alignment: Alignment.centerRight, child: trailing!),
        ],
      ),
    );
  }
}

class AuroraIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  const AuroraIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onPressed,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.74),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.92)),
            boxShadow: [
              BoxShadow(
                color: AuroraColors.purple.withValues(alpha: 0.12),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(icon, color: AuroraColors.ink, size: 22),
        ),
      ),
    );
  }
}

class AuroraPillButton extends StatelessWidget {
  final IconData? icon;
  final String label;
  final VoidCallback? onPressed;
  final bool filled;

  const AuroraPillButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = filled ? Colors.white : AuroraColors.ink;
    return LayoutBuilder(
      builder: (context, constraints) {
        final iconOnly = constraints.maxWidth < 38 && icon != null;
        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onPressed,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: iconOnly ? 8 : 6,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              color: filled
                  ? const Color(0xFF6E63EF)
                  : Colors.white.withValues(alpha: 0.70),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: filled
                    ? const Color(0xFF6E63EF)
                    : Colors.white.withValues(alpha: 0.86),
              ),
              boxShadow: filled
                  ? [
                      BoxShadow(
                        color: AuroraColors.purple.withValues(alpha: 0.22),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) Icon(icon, size: 17, color: color),
                if (!iconOnly) ...[
                  if (icon != null) const SizedBox(width: 5),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class AuroraChip extends StatelessWidget {
  final String label;
  final Color color;

  const AuroraChip({
    super.key,
    required this.label,
    this.color = AuroraColors.purple,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class AuroraSoftIconCircle extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final bool glossy;

  const AuroraSoftIconCircle({
    super.key,
    required this.icon,
    required this.color,
    this.size = 48,
    this.iconSize = 24,
    this.glossy = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.38, -0.48),
          colors: [
            Colors.white.withValues(alpha: glossy ? 0.96 : 0.78),
            color.withValues(alpha: 0.34),
            color.withValues(alpha: 0.18),
          ],
          stops: const [0, 0.58, 1],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.88)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}

class AuroraLandscapeMedallion extends StatelessWidget {
  final double size;

  const AuroraLandscapeMedallion({super.key, this.size = 58});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.80),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
        boxShadow: [
          BoxShadow(
            color: AuroraColors.purple.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipOval(child: CustomPaint(painter: _LandscapePainter())),
    );
  }
}

class AuroraCrystalIllustration extends StatelessWidget {
  final double width;
  final double height;

  const AuroraCrystalIllustration({
    super.key,
    this.width = 112,
    this.height = 90,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: _CrystalPainter()),
    );
  }
}

class AuroraQuoteCard extends StatelessWidget {
  final String text;
  final IconData? icon;
  final double minHeight;
  final bool landscape;

  const AuroraQuoteCard({
    super.key,
    required this.text,
    this.icon,
    this.minHeight = 92,
    this.landscape = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AuroraCard(
      padding: const EdgeInsets.all(20),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFF4F0FF),
          Color(0xFFFFFBF2),
          Color(0xFFF6FAFF),
        ],
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Row(
          children: [
            if (landscape)
              const AuroraLandscapeMedallion(size: 60)
            else
              AuroraSoftIconCircle(
                icon: icon ?? Icons.auto_awesome_rounded,
                color: AuroraColors.purple,
                size: 58,
                iconSize: 26,
              ),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.titleMedium?.copyWith(
                  height: 1.55,
                  color: AuroraColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuroraMetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const AuroraMetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 62;
          final showArrow = constraints.maxWidth >= 58;
          final iconSize = compact ? 28.0 : 38.0;
          final glyphSize = compact ? 15.0 : 20.0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AuroraSoftIconCircle(
                    icon: icon,
                    color: color,
                    size: iconSize,
                    iconSize: glyphSize,
                  ),
                  if (showArrow)
                    Container(
                      width: compact ? 18 : 22,
                      height: compact ? 18 : 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.12),
                      ),
                      child: Icon(
                        value.toLowerCase().contains('high') ||
                                value.contains('高') ||
                                value.contains('高め')
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: color,
                        size: compact ? 15 : 18,
                      ),
                    ),
                ],
              ),
              SizedBox(height: compact ? 7 : 9),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AuroraColors.ink,
                      height: 1.1,
                      fontSize: compact ? 11 : null,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                      fontSize: compact ? 14 : null,
                    ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class AuroraSparkline extends StatelessWidget {
  final Color color;

  const AuroraSparkline({super.key, this.color = AuroraColors.purple});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 26,
      width: 76,
      child: CustomPaint(painter: _SparklinePainter(color)),
    );
  }
}

class AuroraStackedBar extends StatelessWidget {
  final List<AuroraBarSegment> segments;
  final double height;

  const AuroraStackedBar({
    super.key,
    required this.segments,
    this.height = 18,
  });

  @override
  Widget build(BuildContext context) {
    final total = segments.fold<double>(
      0,
      (sum, segment) => sum + math.max(segment.value, 0),
    );
    final effectiveTotal = total <= 0 ? 1 : total;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: Row(
        children: [
          for (final segment in segments)
            Expanded(
              flex:
                  math.max(1, (segment.value / effectiveTotal * 1000).round()),
              child: Container(height: height, color: segment.color),
            ),
        ],
      ),
    );
  }
}

class AuroraBarSegment {
  final String label;
  final double value;
  final Color color;

  const AuroraBarSegment({
    required this.label,
    required this.value,
    required this.color,
  });
}

class AuroraSignalPath extends StatelessWidget {
  final double height;

  const AuroraSignalPath({super.key, this.height = 92});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _SignalPathPainter()),
    );
  }
}

class _AuroraBrandPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = size.width * 0.18;
    final glow = Paint()
      ..shader = const SweepGradient(
        colors: [
          Color(0xFF7B6FF2),
          Color(0xFFB9D8FF),
          Color(0xFFFFB277),
          Color(0xFF7B6FF2),
        ],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(size.center(Offset.zero), size.width * 0.34, glow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LandscapePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFEDE8FF),
            Color(0xFFFFE8C9),
            Color(0xFFBFD9FF),
          ],
        ).createShader(rect),
    );

    canvas.drawCircle(
      Offset(size.width * 0.62, size.height * 0.34),
      size.width * 0.13,
      Paint()..color = const Color(0xFFFFF8DD).withValues(alpha: 0.96),
    );

    final far = Path()
      ..moveTo(0, size.height * 0.60)
      ..cubicTo(
        size.width * 0.24,
        size.height * 0.44,
        size.width * 0.48,
        size.height * 0.68,
        size.width * 0.72,
        size.height * 0.55,
      )
      ..cubicTo(
        size.width * 0.85,
        size.height * 0.48,
        size.width * 0.94,
        size.height * 0.48,
        size.width,
        size.height * 0.42,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      far,
      Paint()..color = const Color(0xFF9EA7D9).withValues(alpha: 0.34),
    );

    final near = Path()
      ..moveTo(0, size.height * 0.74)
      ..cubicTo(
        size.width * 0.30,
        size.height * 0.62,
        size.width * 0.55,
        size.height * 0.88,
        size.width,
        size.height * 0.68,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      near,
      Paint()..color = const Color(0xFF7FA6D7).withValues(alpha: 0.30),
    );

    final lake = Paint()
      ..color = Colors.white.withValues(alpha: 0.70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (final y in [0.74, 0.80, 0.86]) {
      canvas.drawLine(
        Offset(size.width * 0.18, size.height * y),
        Offset(size.width * 0.86, size.height * (y + 0.018)),
        lake,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CrystalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.58, size.height * 0.48);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, size.height * 0.82),
        width: size.width * 0.62,
        height: size.height * 0.20,
      ),
      Paint()
        ..color = AuroraColors.purple.withValues(alpha: 0.17)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    final body = Path()
      ..moveTo(center.dx, size.height * 0.06)
      ..lineTo(size.width * 0.83, size.height * 0.32)
      ..lineTo(size.width * 0.72, size.height * 0.72)
      ..lineTo(center.dx, size.height * 0.92)
      ..lineTo(size.width * 0.34, size.height * 0.72)
      ..lineTo(size.width * 0.24, size.height * 0.32)
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE8E0FF),
            Color(0xFF947DFF),
            Color(0xFF7E9DFF),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.72),
    );

    final facet = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = Colors.white.withValues(alpha: 0.46);
    canvas.drawLine(Offset(center.dx, size.height * 0.08), center, facet);
    canvas.drawLine(
        center, Offset(size.width * 0.35, size.height * 0.72), facet);
    canvas.drawLine(
        center, Offset(size.width * 0.73, size.height * 0.72), facet);

    final sparkle = Paint()..color = Colors.white.withValues(alpha: 0.86);
    canvas.drawCircle(
        Offset(size.width * 0.78, size.height * 0.18), 2.2, sparkle);
    canvas.drawCircle(
        Offset(size.width * 0.22, size.height * 0.50), 1.7, sparkle);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SparklinePainter extends CustomPainter {
  final Color color;

  _SparklinePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final path = Path();
    final values = [0.62, 0.55, 0.44, 0.50, 0.35, 0.42, 0.30, 0.36];
    for (var i = 0; i < values.length; i++) {
      final point = Offset(
        i / (values.length - 1) * size.width,
        values[i] * size.height,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _SignalPathPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(20, size.height * 0.58)
      ..cubicTo(
        size.width * 0.25,
        size.height * 0.12,
        size.width * 0.48,
        size.height * 0.72,
        size.width * 0.72,
        size.height * 0.38,
      )
      ..cubicTo(
        size.width * 0.85,
        size.height * 0.20,
        size.width - 42,
        size.height * 0.48,
        size.width - 20,
        size.height * 0.28,
      );
    final paint = Paint()
      ..color = const Color(0xFF8DB8B8).withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, paint);
    final dots = [
      (Offset(24, size.height * 0.58), const Color(0xFF7AB988), 10.0),
      (
        Offset(size.width * 0.36, size.height * 0.30),
        const Color(0xFF637EA3),
        13.0
      ),
      (
        Offset(size.width * 0.68, size.height * 0.44),
        const Color(0xFF5A9EA2),
        12.0
      ),
      (
        Offset(size.width - 24, size.height * 0.28),
        const Color(0xFFB77E86),
        10.0
      ),
    ];
    for (final dot in dots) {
      canvas.drawCircle(
        dot.$1,
        dot.$3,
        Paint()..color = dot.$2.withValues(alpha: 0.92),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
