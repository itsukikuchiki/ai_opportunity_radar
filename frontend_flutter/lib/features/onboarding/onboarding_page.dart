import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/app_router.dart';
import '../../core/i18n/app_locale_text.dart';
import '../../core/state/app_bootstrap_state.dart';
import 'onboarding_view_model.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  static const List<String> _assets = [
    'assets/onboarding/onboarding-welcome.png',
    'assets/onboarding/onboarding-input.png',
    'assets/onboarding/onboarding-experiment.png',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _next(OnboardingViewModel vm) async {
    if (_currentStep < _assets.length - 1) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    await _complete(vm);
  }

  Future<void> _complete(OnboardingViewModel vm) async {
    try {
      await vm.complete();
      if (!mounted) return;
      await context.read<AppBootstrapState>().markOnboardingCompleted();
      if (!mounted) return;
      context.go(AppRoutes.today);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_submitErrorText(context, vm.errorCode))),
      );
    }
  }

  Future<void> _skip() async {
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
    final isLast = _currentStep == _assets.length - 1;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _assets.length,
              onPageChanged: (value) => setState(() => _currentStep = value),
              itemBuilder: (context, index) {
                return _OnboardingArtwork(asset: _assets[index]);
              },
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 10, right: 18),
                child: AnimatedOpacity(
                  opacity: isLast ? 0 : 1,
                  duration: const Duration(milliseconds: 180),
                  child: TextButton(
                    onPressed: vm.submitting ? null : _skip,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF7D8397),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
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
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedOpacity(
                      opacity: isLast ? 1 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: IgnorePointer(
                        ignoring: !isLast,
                        child: _StartButton(
                          submitting: vm.submitting,
                          onPressed: () => _complete(vm),
                        ),
                      ),
                    ),
                    if (!isLast) ...[
                      const SizedBox(height: 8),
                      _SwipeHint(onTap: vm.submitting ? null : () => _next(vm)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingArtwork extends StatelessWidget {
  final String asset;

  const _OnboardingArtwork({required this.asset});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.white),
      child: Center(
        child: Image.asset(
          asset,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  final bool submitting;
  final VoidCallback onPressed;

  const _StartButton({required this.submitting, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7168F6).withValues(alpha: 0.18),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: FilledButton(
          onPressed: submitting ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF7168F6),
            foregroundColor: Colors.white,
            disabledBackgroundColor:
                const Color(0xFF7168F6).withValues(alpha: 0.55),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
            textStyle: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          child: submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Start Signal Path',
                    zhHans: '开始使用 Signal Path',
                    zhHant: '開始使用 Signal Path',
                    ja: 'Signal Path をはじめる',
                  ),
                ),
        ),
      ),
    );
  }
}

class _SwipeHint extends StatelessWidget {
  final VoidCallback? onTap;

  const _SwipeHint({this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF8D92A5),
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      child: Text(
        AppLocaleText.tr(
          context,
          en: 'Swipe or tap to continue',
          zhHans: '左滑或轻点继续',
          zhHant: '左滑或輕點繼續',
          ja: 'スワイプ、またはタップして続ける',
        ),
      ),
    );
  }
}
