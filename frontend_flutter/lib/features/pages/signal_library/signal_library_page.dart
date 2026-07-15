import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/i18n/app_locale_text.dart';
import '../../../core/models/signal_library_models.dart';
import '../../../core/preferences/focus_domains.dart';
import '../../../shared/widgets/aurora_ui.dart';
import '../../../shared/widgets/signal_illustration_kit.dart';
import 'signal_library_view_model.dart';

class SignalLibraryPage extends StatefulWidget {
  const SignalLibraryPage({super.key});

  @override
  State<SignalLibraryPage> createState() => _SignalLibraryPageState();
}

class _SignalLibraryPageState extends State<SignalLibraryPage> {
  String? _loadedLanguage;
  String _query = '';
  final Set<String> _submittingPatternIds = <String>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = _languageCode(context);
    if (_loadedLanguage == language) return;
    _loadedLanguage = language;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SignalLibraryViewModel>().load(language: language);
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SignalLibraryViewModel>();
    final theme = Theme.of(context);
    final patterns = _filterPatterns(
      context,
      viewModel.patterns,
      viewModel.selectedCategory,
    );

    return Scaffold(
      body: Stack(
        children: [
          AuroraPage(
            child: Stack(
              children: [
                const Positioned(
                  right: -18,
                  top: 18,
                  width: 180,
                  height: 172,
                  child: IgnorePointer(child: _LibraryHeroDecor()),
                ),
                SafeArea(
                  bottom: false,
                  child: ListView(
                    padding: AuroraMainPageSpec.scrollPadding(context),
                    children: [
                      if (Navigator.of(context).canPop()) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(Icons.arrow_back_ios_new_rounded),
                            color: AuroraColors.ink,
                            tooltip: AppLocaleText.tr(
                              context,
                              en: 'Back',
                              zhHans: '返回',
                              zhHant: '返回',
                              ja: '戻る',
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                      AuroraHeroTitle(
                        text: AppLocaleText.tr(
                          context,
                          en: 'Signal Library',
                          zhHans: '信号库',
                          zhHant: '信號庫',
                          ja: 'シグナルライブラリ',
                        ),
                        fontSize:
                            AuroraMainPageSpec.responsiveHeroTitleSize(context),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppLocaleText.tr(
                          context,
                          en: 'Browse common SignalCard references and decide whether one matches your recent life.',
                          zhHans: '浏览常见的 Signal Card 参考，判断它是否像你最近的情况。',
                          zhHant: '瀏覽常見的 SignalCard 參考，判斷它是否像你最近的情況。',
                          ja: 'よくあるSignalCardの参考から、最近の自分に近いものか判断できます。',
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AuroraColors.ink.withValues(alpha: 0.74),
                          height: 1.42,
                          fontSize: AuroraMainPageSpec.heroSubtitleSize,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: AuroraMainPageSpec.heroGap),
                      _LibrarySearchField(
                        onChanged: (value) => setState(() => _query = value),
                      ),
                      const SizedBox(height: AuroraMainPageSpec.sectionGap),
                      _LibraryCategoryRow(
                        selectedCategory: viewModel.selectedCategory,
                        onSelected: viewModel.selectCategory,
                      ),
                      const SizedBox(height: AuroraMainPageSpec.sectionGap),
                      if (viewModel.loading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else
                        ...patterns.map(
                          (pattern) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AuroraMainPageSpec.sectionGap,
                            ),
                            child: _PatternCard(
                              pattern: pattern,
                              submitting:
                                  _submittingPatternIds.contains(pattern.id),
                              onRespond: (status) => _respondToPattern(
                                pattern: pattern,
                                status: status,
                                viewModel: viewModel,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 2),
                      _LibraryFooterHint(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const AuroraSafeTopMask(),
        ],
      ),
    );
  }

  List<LibraryPatternModel> _filterPatterns(
    BuildContext context,
    List<LibraryPatternModel> patterns,
    String selectedCategory,
  ) {
    final query = _query.trim().toLowerCase();
    final categoryFiltered = selectedCategory == 'all'
        ? patterns
        : patterns.where((pattern) {
            return _LibraryDomainStyle.resolve(context, pattern).id ==
                selectedCategory;
          }).toList(growable: false);
    final filtered = query.isEmpty
        ? categoryFiltered
        : categoryFiltered.where((pattern) {
            final text = [
              pattern.title,
              pattern.abstractPattern,
              ...pattern.commonScenes,
              ...pattern.commonFrictions,
            ].join(' ').toLowerCase();
            return text.contains(query);
          }).toList(growable: false);
    return [...filtered]..sort(_compareLibraryPatternPriority);
  }

  int _compareLibraryPatternPriority(
    LibraryPatternModel a,
    LibraryPatternModel b,
  ) {
    return _libraryPatternPriority(a.id)
        .compareTo(_libraryPatternPriority(b.id));
  }

  int _libraryPatternPriority(String id) {
    if (id.contains('recovery_debt')) return 0;
    if (id.contains('boundary_fatigue')) return 1;
    if (id.contains('late_night_compensation')) return 2;
    return 10;
  }

  String _languageCode(BuildContext context) {
    switch (AppLocaleText.resolve(context)) {
      case AppLanguage.simplifiedChinese:
        return 'zh-Hans';
      case AppLanguage.traditionalChinese:
        return 'zh-Hant';
      case AppLanguage.japanese:
        return 'ja';
      case AppLanguage.english:
        return 'en';
    }
  }

  Future<void> _respondToPattern({
    required LibraryPatternModel pattern,
    required String status,
    required SignalLibraryViewModel viewModel,
  }) async {
    if (_submittingPatternIds.contains(pattern.id)) return;
    final messenger = ScaffoldMessenger.of(context);

    if (status == 'inaccurate') {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              AppLocaleText.tr(
                context,
                en: 'Nothing was added to your timeline.',
                zhHans: '没有加入时间线，也没有保存反馈。',
                zhHant: '沒有加入時間線，也沒有儲存回饋。',
                ja: 'タイムラインには追加せず、フィードバックも保存していません。',
              ),
            ),
          ),
        );
      return;
    }

    setState(() => _submittingPatternIds.add(pattern.id));
    try {
      final signal = await viewModel.respondToPattern(
        pattern: pattern,
        status: status,
        addToTimeline: true,
      );
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              signal != null
                  ? AppLocaleText.tr(
                      context,
                      en: 'Added to your timeline.',
                      zhHans: '已加入你的时间线。',
                      zhHant: '已加入你的時間線。',
                      ja: 'タイムラインに追加しました。',
                    )
                  : AppLocaleText.tr(
                      context,
                      en: 'Nothing was added to your timeline.',
                      zhHans: '没有加入时间线，也没有保存反馈。',
                      zhHant: '沒有加入時間線，也沒有儲存回饋。',
                      ja: 'タイムラインには追加せず、フィードバックも保存していません。',
                    ),
            ),
          ),
        );
    } catch (_) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              AppLocaleText.tr(
                context,
                en: 'Could not complete this action. Please try again.',
                zhHans: '暂时无法完成，请再试一次。',
                zhHant: '暫時無法完成，請再試一次。',
                ja: '操作を完了できませんでした。もう一度お試しください。',
              ),
            ),
          ),
        );
    } finally {
      if (mounted) {
        setState(() => _submittingPatternIds.remove(pattern.id));
      }
    }
  }
}

class _LibraryFeedbackButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool primary;
  final VoidCallback? onPressed;

  const _LibraryFeedbackButton({
    super.key,
    required this.label,
    required this.icon,
    this.primary = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      ),
      textStyle: WidgetStatePropertyAll(
        Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
    if (primary) {
      return FilledButton.icon(
        style: style.merge(
          FilledButton.styleFrom(
            backgroundColor: AuroraColors.purple,
            foregroundColor: Colors.white,
          ),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      );
    }
    return OutlinedButton.icon(
      style: style.merge(
        OutlinedButton.styleFrom(
          foregroundColor: AuroraColors.purple,
          side: BorderSide(
            color: AuroraColors.purple.withValues(alpha: 0.24),
          ),
        ),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

class _LibrarySearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const _LibrarySearchField({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(
          AuroraMainPageSpec.cardRadius,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.88)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF746CA5).withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: TextField(
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: AppLocaleText.tr(
            context,
            en: 'Search a signal...',
            zhHans: '搜索一个信号...',
            zhHant: '搜尋一個信號...',
            ja: 'シグナルを検索...',
          ),
          hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AuroraColors.muted.withValues(alpha: 0.72),
                fontWeight: FontWeight.w500,
              ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: AuroraColors.muted.withValues(alpha: 0.78),
            size: 24,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.fromLTRB(2, 16, 16, 14),
        ),
      ),
    );
  }
}

class _LibraryFooterHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AuroraCard(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      color: Colors.white.withValues(alpha: 0.56),
      borderRadius: BorderRadius.circular(22),
      child: Row(
        children: [
          const SizedBox(
            width: 64,
            height: 58,
            child: AuroraCrystalIllustration(),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Text(
              AppLocaleText.tr(
                context,
                en: 'Library items are references only. You decide whether one becomes your SignalCard.',
                zhHans: '信号库内容只是参考；是否成为你自己的 Signal Card，由你决定。',
                zhHant: '信號庫內容只是參考；是否成為你自己的 SignalCard，由你決定。',
                ja: 'ライブラリは参考です。自分のSignalCardにするかは自分で選べます。',
              ),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AuroraColors.ink.withValues(alpha: 0.72),
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryHeroDecor extends StatelessWidget {
  const _LibraryHeroDecor();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: AuroraHeroEmblem(size: 170, opacity: 0.86),
    );
  }
}

// Retained for compatibility with older visual snapshots.
// ignore: unused_element
class _LibrarySignalOrbPainter extends CustomPainter {
  const _LibrarySignalOrbPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.55, size.height * 0.38);
    final radius = size.shortestSide * 0.34;
    final ringRect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius * 1.18,
      Paint()
        ..color = AuroraColors.purple.withValues(alpha: 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    canvas.drawArc(
      ringRect,
      -math.pi * 0.18,
      math.pi * 1.55,
      false,
      Paint()
        ..shader = const SweepGradient(
          colors: [
            Color(0xFF8272FF),
            Color(0xFF75DDE5),
            Color(0xFFFFC365),
            Color(0xFF8272FF),
          ],
        ).createShader(ringRect)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 17,
    );
    canvas.drawCircle(
      center,
      radius * 0.74,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.80),
    );

    final path = Path()
      ..moveTo(center.dx - radius * 0.95, center.dy + radius * 0.12)
      ..cubicTo(
        center.dx - radius * 0.24,
        center.dy - radius * 0.18,
        center.dx + radius * 0.42,
        center.dy - radius * 0.10,
        center.dx + radius * 0.06,
        center.dy + radius * 0.20,
      )
      ..cubicTo(
        center.dx - radius * 0.22,
        center.dy + radius * 0.45,
        center.dx - radius * 0.08,
        center.dy + radius * 0.58,
        center.dx + radius * 0.92,
        center.dy + radius * 0.70,
      );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.82)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
    );

    final nodePaint = Paint()..color = Colors.white.withValues(alpha: 0.92);
    for (final point in [
      Offset(center.dx - radius * 0.98, center.dy + radius * 0.08),
      Offset(center.dx + radius * 0.66, center.dy - radius * 0.62),
      Offset(center.dx + radius * 0.94, center.dy + radius * 0.58),
    ]) {
      canvas.drawCircle(point, 7.5, nodePaint);
      canvas.drawCircle(
        point,
        4,
        Paint()..color = AuroraColors.purple.withValues(alpha: 0.42),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ignore: unused_element
class _LibraryLeafPainter extends CustomPainter {
  final Color color;

  const _LibraryLeafPainter({required this.color});

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
  bool shouldRepaint(covariant _LibraryLeafPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _LibraryCategoryRow extends StatelessWidget {
  final String selectedCategory;
  final ValueChanged<String> onSelected;

  const _LibraryCategoryRow({
    required this.selectedCategory,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        'all',
        Icons.grid_view_rounded,
        AppLocaleText.tr(
          context,
          en: 'All',
          zhHans: '全部',
          zhHant: '全部',
          ja: 'すべて',
        ),
        AuroraColors.purple,
      ),
      for (final option in FocusDomains.options)
        (option.id, option.icon, option.label(context), option.color),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final item in items) ...[
            _LibraryCategoryChip(
              categoryId: item.$1,
              icon: item.$2,
              label: item.$3,
              color: item.$4,
              selected: selectedCategory == item.$1,
              onTap: () => onSelected(item.$1),
            ),
            const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

class _LibraryCategoryChip extends StatelessWidget {
  final String categoryId;
  final IconData icon;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _LibraryCategoryChip({
    required this.categoryId,
    required this.icon,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        key: ValueKey('library-category-$categoryId'),
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? Colors.white.withValues(alpha: 0.86)
                  : Colors.white.withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: selected
                    ? color.withValues(alpha: 0.55)
                    : Colors.white.withValues(alpha: 0.82),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF746CA5).withValues(alpha: 0.08),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
                if (selected)
                  BoxShadow(
                    color: color.withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
              ],
            ),
            child: Row(
              children: [
                _LibraryMiniIcon(icon: icon, color: color),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: selected ? color : AuroraColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PatternCard extends StatelessWidget {
  final LibraryPatternModel pattern;
  final bool submitting;
  final ValueChanged<String> onRespond;

  const _PatternCard({
    required this.pattern,
    required this.submitting,
    required this.onRespond,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final domain = _LibraryDomainStyle.resolve(context, pattern);

    return AuroraCard(
      padding: AuroraMainPageSpec.comfortableCardPadding,
      color: Colors.white.withValues(alpha: 0.64),
      borderRadius: BorderRadius.circular(
        AuroraMainPageSpec.cardRadiusLarge,
      ),
      child: Stack(
        children: [
          Positioned(
            right: 8,
            top: 8,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: AuroraColors.purple.withValues(alpha: 0.22),
              size: 28,
            ),
          ),
          Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _LibrarySignalIcon(
                    icon: domain.icon,
                    color: domain.color,
                    patternId: pattern.id,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _LibraryDomainBadge(domain: domain),
                        const SizedBox(height: 8),
                        Text(
                          pattern.abstractPattern,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: AuroraColors.ink,
                            height: 1.38,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _LibraryFeedbackButton(
                      key: ValueKey('library-signal-accurate-${pattern.id}'),
                      label: AppLocaleText.tr(
                        context,
                        en: 'Accurate',
                        zhHans: '准',
                        zhHant: '準',
                        ja: '合っている',
                      ),
                      icon: Icons.check_circle_outline,
                      primary: true,
                      onPressed:
                          submitting ? null : () => onRespond('accurate'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _LibraryFeedbackButton(
                      key: ValueKey('library-signal-partial-${pattern.id}'),
                      label: AppLocaleText.tr(
                        context,
                        en: 'Somewhat',
                        zhHans: '有一点像',
                        zhHant: '有一點像',
                        ja: '少し近い',
                      ),
                      icon: Icons.tune,
                      onPressed: submitting ? null : () => onRespond('partial'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _LibraryFeedbackButton(
                      key: ValueKey('library-signal-inaccurate-${pattern.id}'),
                      label: AppLocaleText.tr(
                        context,
                        en: 'Not accurate',
                        zhHans: '不准',
                        zhHant: '不準',
                        ja: '違う',
                      ),
                      icon: Icons.remove_circle_outline,
                      onPressed:
                          submitting ? null : () => onRespond('inaccurate'),
                    ),
                  ),
                ],
              ),
              if (submitting) ...[
                const SizedBox(height: 10),
                const LinearProgressIndicator(minHeight: 2),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _LibraryMiniIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _LibraryMiniIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.96),
            color.withValues(alpha: 0.34),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.16),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 19),
    );
  }
}

class _LibrarySignalIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String patternId;

  const _LibrarySignalIcon({
    required this.icon,
    required this.color,
    required this.patternId,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      height: 68,
      child: Stack(
        alignment: Alignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.62),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.14),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: const SizedBox.expand(),
          ),
          SizedBox(
            width: 46,
            height: 46,
            child: PatternIllustration(patternId: patternId),
          ),
          Icon(icon, color: Colors.white.withValues(alpha: 0.08), size: 46),
        ],
      ),
    );
  }
}

class _LibraryDomainBadge extends StatelessWidget {
  final _LibraryDomainStyle domain;

  const _LibraryDomainBadge({required this.domain});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: domain.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        domain.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: domain.color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _LibraryDomainStyle {
  final String id;
  final String label;
  final IconData icon;
  final Color color;

  const _LibraryDomainStyle({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
  });

  static _LibraryDomainStyle resolve(
    BuildContext context,
    LibraryPatternModel pattern,
  ) {
    final haystack = [
      pattern.id,
      pattern.title,
      pattern.abstractPattern,
      pattern.energyLoadHint,
      pattern.possiblePositiveSignal,
      ...pattern.commonScenes,
      ...pattern.commonFrictions,
    ].join(' ').toLowerCase();

    if (_containsAny(haystack, [
      'relationship',
      'relationships',
      'communication',
      'connection',
      'expectation',
      'expectations',
      'unclear expectation',
      '关系',
      '關係',
      '沟通',
      '溝通',
      '连接',
      '連結',
      '期待',
      '说清楚',
      '說清楚',
      '被理解',
      '関係',
      'コミュニケーション',
      'つながり',
    ])) {
      return _LibraryDomainStyle(
        id: 'relationship_connection',
        label: AppLocaleText.tr(
          context,
          en: 'Relationships',
          zhHans: '关系连接',
          zhHant: '關係連結',
          ja: '関係性',
        ),
        icon: Icons.groups_rounded,
        color: AuroraColors.blue,
      );
    }

    if (_containsAny(haystack, [
      'boundary',
      'personal time',
      'agency',
      '边界',
      '邊界',
      '个人时间',
      '個人時間',
      '自由感',
      '自我边界',
      '自我邊界',
    ])) {
      return _LibraryDomainStyle(
        id: 'self_boundary',
        label: AppLocaleText.tr(
          context,
          en: 'Boundaries',
          zhHans: '自我边界',
          zhHant: '自我邊界',
          ja: '自分の境界',
        ),
        icon: Icons.shield_rounded,
        color: AuroraColors.purple,
      );
    }

    if (_containsAny(haystack, [
      'sleep',
      'late-night',
      'night',
      'rest',
      'body',
      '睡眠',
      '深夜',
      '晚上',
      '休息',
      '身体',
      '身體',
    ])) {
      return _LibraryDomainStyle(
        id: 'food_sleep',
        label: AppLocaleText.tr(
          context,
          en: 'Food & sleep',
          zhHans: '饮食睡眠',
          zhHant: '飲食睡眠',
          ja: '食事と睡眠',
        ),
        icon: Icons.nights_stay_rounded,
        color: AuroraColors.blue,
      );
    }

    if (_containsAny(haystack, [
      'planning',
      'work',
      'attention',
      'growth',
      'schedule',
      '安排',
      '工作',
      '注意力',
      '成长',
      '成長',
      '计划',
      '計劃',
    ])) {
      return _LibraryDomainStyle(
        id: 'growth_plan',
        label: AppLocaleText.tr(
          context,
          en: 'Growth plan',
          zhHans: '成长计划',
          zhHant: '成長計劃',
          ja: '成長計画',
        ),
        icon: Icons.spa_rounded,
        color: AuroraColors.mint,
      );
    }

    return _LibraryDomainStyle(
      id: 'emotional_stability',
      label: AppLocaleText.tr(
        context,
        en: 'Emotional calm',
        zhHans: '情绪安定',
        zhHant: '情緒安定',
        ja: '感情の安定',
      ),
      icon: Icons.sentiment_satisfied_alt_rounded,
      color: AuroraColors.gold,
    );
  }

  static bool _containsAny(String haystack, List<String> values) {
    return values.any((value) => haystack.contains(value.toLowerCase()));
  }
}
