import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/app_router.dart';
import '../../core/state/app_bootstrap_state.dart';
import '../../core/i18n/app_locale_text.dart';
import 'onboarding_view_model.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  static const int _stepCount = 3;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _next(OnboardingViewModel vm) async {
    if (_currentStep < _stepCount - 1) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    try {
      await vm.complete();
      if (!mounted) return;

      await context.read<AppBootstrapState>().markOnboardingCompleted();
      if (!mounted) return;

      context.go(AppRoutes.today);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_submitErrorText(context, vm.errorCode)),
        ),
      );
    }
  }

  Future<void> _skip() async {
    if (!mounted) return;

    await context.read<AppBootstrapState>().markOnboardingCompleted();
    if (!mounted) return;

    context.go(AppRoutes.today);
  }

  String _submitErrorText(BuildContext context, String? code) {
    switch (code) {
      case 'repeat_area_required':
        return AppLocaleText.tr(
          context,
          en: 'Please choose one focus area first.',
          zhHans: '请先选择一个关注方向。',
          zhHant: '請先選擇一個關注方向。',
          ja: 'まず注目したい方向を一つ選んでください。',
        );
      default:
        return AppLocaleText.tr(
          context,
          en: 'Something went wrong. Please try again.',
          zhHans: '出了一点问题，请再试一次。',
          zhHant: '出了一點問題，請再試一次。',
          ja: '問題が発生しました。もう一度試してください。',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OnboardingViewModel>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocaleText.tr(
            context,
            en: 'Welcome',
            zhHans: '欢迎使用',
            zhHant: '歡迎使用',
            ja: 'ようこそ',
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Row(
                children: List.generate(_stepCount, (index) {
                  final active = index <= _currentStep;
                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(
                          right: index == _stepCount - 1 ? 0 : 8),
                      height: 4,
                      decoration: BoxDecoration(
                        color: active
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant
                                .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  );
                }),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (value) {
                  setState(() => _currentStep = value);
                },
                children: const [
                  _HeroIntroStep(),
                  _SignalInputStep(),
                  _SignalOutputStep(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: vm.submitting ? null : () => _next(vm),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                      ),
                      child: vm.submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _currentStep == _stepCount - 1
                                  ? AppLocaleText.tr(
                                      context,
                                      en: 'Start',
                                      zhHans: '开始使用',
                                      zhHant: '開始使用',
                                      ja: 'はじめる',
                                    )
                                  : AppLocaleText.tr(
                                      context,
                                      en: 'Continue',
                                      zhHans: '继续',
                                      zhHant: '繼續',
                                      ja: '続ける',
                                    ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: vm.submitting ? null : _skip,
                    child: Text(
                      AppLocaleText.tr(
                        context,
                        en: 'Skip',
                        zhHans: '跳过',
                        zhHant: '跳過',
                        ja: 'スキップ',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroIntroStep extends StatelessWidget {
  const _HeroIntroStep();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 42, 24, 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/brand-icon-display.png',
            width: 210,
            height: 210,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 28),
          Text(
            AppLocaleText.tr(
              context,
              en: 'Signal Path',
              zhHans: 'Signal Path',
              zhHant: 'Signal Path',
              ja: 'Signal Path',
            ),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            AppLocaleText.tr(
              context,
              en: 'Notice the signals, adjust gently',
              zhHans: '看见信号，轻轻调整',
              zhHant: '看見信號，輕輕調整',
              ja: 'シグナルに気づき、そっと整える',
            ),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w400,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            AppLocaleText.tr(
              context,
              en: 'Not a diagnosis. Not a score.',
              zhHans: '不是诊断，也不是评分。',
              zhHant: '不是診斷，也不是評分。',
              ja: '診断でも、評価でもありません。',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SignalInputStep extends StatelessWidget {
  const _SignalInputStep();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocaleText.tr(
              context,
              en: 'Put down one small signal from today.',
              zhHans: '把今天的一点信号先放下来。',
              zhHant: '把今天的一點信號先放下來。',
              ja: '今日の小さなシグナルを、まず残しておく。',
            ),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocaleText.tr(
              context,
              en: 'Your original text is saved first. AI only helps organize it gently.',
              zhHans: '原文会先保存，AI 只是帮你轻轻整理。',
              zhHant: '原文會先保存，AI 只是幫你輕輕整理。',
              ja: '原文は先に保存され、AI はそっと整えるだけです。',
            ),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          const _SignalDropPreview(),
          const SizedBox(height: 16),
          _OnboardingInfoCard(
            number: '01',
            title: AppLocaleText.tr(
              context,
              en: 'What you left',
              zhHans: '你留下的内容',
              zhHant: '你留下的內容',
              ja: 'あなたが残したこと',
            ),
            body: AppLocaleText.tr(
              context,
              en: 'A sentence, a voice transcript, or even just a state can be saved as a private observation.',
              zhHans: '一句话、语音转写，或只是一个状态，都可以先放进私人观察。',
              zhHant: '一句話、語音轉寫，或只是一個狀態，都可以先放進私人觀察。',
              ja: '一言でも、音声の文字起こしでも、ただの状態でも、まず個人の観察として残せます。',
            ),
          ),
          const SizedBox(height: 12),
          _OnboardingInfoCard(
            number: '02',
            title: AppLocaleText.tr(
              context,
              en: 'Gentle organization',
              zhHans: '轻轻整理',
              zhHant: '輕輕整理',
              ja: 'そっと整理',
            ),
            body: AppLocaleText.tr(
              context,
              en: 'Even if AI fails, your saved content stays. The result is only an added small observation.',
              zhHans: 'AI 失败也不会影响保存；整理结果只是附加小观察。',
              zhHant: 'AI 失敗也不會影響保存；整理結果只是附加小觀察。',
              ja: 'AI の整理に失敗しても保存には影響しません。結果は追加の小さな観察にすぎません。',
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalOutputStep extends StatelessWidget {
  const _SignalOutputStep();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocaleText.tr(
              context,
              en: 'Turn scattered signals into a life path.',
              zhHans: '把零散信号整理成生活路径',
              zhHant: '把零散信號整理成生活路徑',
              ja: 'ばらばらのシグナルを、生活の旅路として整える。',
            ),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocaleText.tr(
              context,
              en: 'Not a report. Not a score. It helps you see where energy is spent and where recovery is happening.',
              zhHans: '不是报告，也不是评分。只是帮你看见这段时间哪里耗力，哪里在恢复。',
              zhHant: '不是報告，也不是評分。只是幫你看見這段時間哪裡耗力，哪裡在恢復。',
              ja: 'レポートでも、評価でもありません。この時期にどこで消耗し、どこで回復しているかを見るためのものです。',
            ),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          const _SignalPathPreview(),
          const SizedBox(height: 16),
          _OnboardingInfoCard(
            number: 'W',
            title: AppLocaleText.tr(
              context,
              en: 'Weekly',
              zhHans: '本周',
              zhHant: '本週',
              ja: '今週',
            ),
            body: AppLocaleText.tr(
              context,
              en: 'Start with one pattern this week, then choose one small experiment.',
              zhHans: '先看一个模式，再选择一个很小的尝试。',
              zhHant: '先看一個模式，再選擇一個很小的嘗試。',
              ja: '今週はまず一つのパターンを見て、小さな試みを一つ選べます。',
            ),
          ),
          const SizedBox(height: 12),
          _OnboardingInfoCard(
            number: 'J',
            title: AppLocaleText.tr(
              context,
              en: 'Journey',
              zhHans: '旅程',
              zhHant: '旅程',
              ja: '旅路',
            ),
            body: AppLocaleText.tr(
              context,
              en: 'It places repetition, recovery, and experiments on one Life Journey.',
              zhHans: '把几周里的重复、恢复和实验轨迹，慢慢连成生活地图。',
              zhHant: '把幾週裡的重複、恢復和實驗軌跡，慢慢連成生活地圖。',
              ja: '繰り返し、回復、試みの軌跡を、一つの生活の旅路にまとめます。',
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalDropPreview extends StatelessWidget {
  const _SignalDropPreview();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 142,
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: CustomPaint(
        painter: _SignalDropPreviewPainter(theme.colorScheme),
      ),
    );
  }
}

class _SignalPathPreview extends StatelessWidget {
  const _SignalPathPreview();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 154,
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: CustomPaint(
        painter: _SignalPathPreviewPainter(theme.colorScheme),
      ),
    );
  }
}

class _SignalDropPreviewPainter extends CustomPainter {
  final ColorScheme colors;

  const _SignalDropPreviewPainter(this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final tray = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.18, size.height * 0.60, size.width * 0.64,
          size.height * 0.22),
      const Radius.circular(18),
    );
    canvas.drawRRect(
      tray,
      Paint()
        ..color = colors.surface.withValues(alpha: 0.86)
        ..style = PaintingStyle.fill,
    );

    final line = Paint()
      ..color = colors.primary.withValues(alpha: 0.40)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * 0.26, size.height * 0.30)
      ..cubicTo(size.width * 0.38, size.height * 0.48, size.width * 0.54,
          size.height * 0.24, size.width * 0.68, size.height * 0.54);
    canvas.drawPath(path, line);

    final fill = Paint()..style = PaintingStyle.fill;
    final dots = [
      (Offset(size.width * 0.25, size.height * 0.30), colors.tertiary, 9.0),
      (Offset(size.width * 0.47, size.height * 0.38), colors.primary, 11.0),
      (Offset(size.width * 0.68, size.height * 0.54), colors.secondary, 9.0),
    ];
    for (final dot in dots) {
      fill.color = dot.$2.withValues(alpha: 0.72);
      canvas.drawCircle(dot.$1, dot.$3, fill);
    }
  }

  @override
  bool shouldRepaint(covariant _SignalDropPreviewPainter oldDelegate) =>
      oldDelegate.colors != colors;
}

class _SignalPathPreviewPainter extends CustomPainter {
  final ColorScheme colors;

  const _SignalPathPreviewPainter(this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final barPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = colors.primary.withValues(alpha: 0.28);
    for (var i = 0; i < 4; i++) {
      final left = size.width * (0.16 + i * 0.055);
      final height = size.height * (0.16 + i * 0.035);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, size.height * 0.54 - height, 9, height),
          const Radius.circular(5),
        ),
        barPaint,
      );
    }

    final pathPaint = Paint()
      ..color = colors.secondary.withValues(alpha: 0.54)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * 0.38, size.height * 0.62)
      ..cubicTo(size.width * 0.48, size.height * 0.30, size.width * 0.58,
          size.height * 0.74, size.width * 0.70, size.height * 0.44)
      ..cubicTo(size.width * 0.76, size.height * 0.29, size.width * 0.84,
          size.height * 0.48, size.width * 0.88, size.height * 0.36);
    canvas.drawPath(path, pathPaint);

    final fill = Paint()..style = PaintingStyle.fill;
    final dots = [
      (Offset(size.width * 0.38, size.height * 0.62), colors.primary, 8.5),
      (Offset(size.width * 0.55, size.height * 0.48), colors.tertiary, 10.0),
      (Offset(size.width * 0.70, size.height * 0.44), colors.secondary, 9.0),
      (Offset(size.width * 0.88, size.height * 0.36), colors.error, 7.0),
    ];
    for (final dot in dots) {
      fill.color = dot.$2.withValues(alpha: 0.68);
      canvas.drawCircle(dot.$1, dot.$3, fill);
    }
  }

  @override
  bool shouldRepaint(covariant _SignalPathPreviewPainter oldDelegate) =>
      oldDelegate.colors != colors;
}

class _OnboardingInfoCard extends StatelessWidget {
  final String number;
  final String title;
  final String body;

  const _OnboardingInfoCard({
    required this.number,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
            child: Text(
              number,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
