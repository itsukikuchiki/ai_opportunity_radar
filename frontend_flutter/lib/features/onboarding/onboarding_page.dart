import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/app_router.dart';
import '../../core/i18n/app_locale_text.dart';
import '../../core/preferences/focus_domains.dart';
import '../../core/state/app_bootstrap_state.dart';
import 'onboarding_view_model.dart';

const _onboardingSurfaceColor = Color(0xFFFFFCF4);
const _onboardingPageCount = 4;

class OnboardingLaunchPage extends StatelessWidget {
  const OnboardingLaunchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _onboardingSurfaceColor,
      body: Stack(
        children: [
          Positioned.fill(child: _buildOpeningScene(context)),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 10, right: 18),
                child: IgnorePointer(
                  child: TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF7B8092),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
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
          const SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 28),
                child: _OnboardingDots(
                  count: _onboardingPageCount,
                  current: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

_OnboardingScene _buildOpeningScene(BuildContext context) {
  return _OnboardingScene(
    key: const ValueKey('onboarding-opening-scene'),
    step: 0,
    title: AppLocaleText.tr(
      context,
      en: 'Record life signals',
      zhHans: '记录生活信号',
      zhHant: '記錄生活信號',
      ja: '生活のシグナルを記録',
    ),
    subtitle: AppLocaleText.tr(
      context,
      en: 'Text, voice, state and confirmed AI predictions all become life signals.',
      zhHans: '文字、语音、状态与经你确认的 AI 预判，都会成为生活信号。',
      zhHant: '文字、語音、狀態與經你確認的 AI 預判，都會成為生活信號。',
      ja: 'テキスト、音声、状態、確認した AI 予測が、暮らしのシグナルになります。',
    ),
    footer: AppLocaleText.tr(
      context,
      en: 'Let scattered feelings become visible signals.',
      zhHans: '让零散感受，变成可被看见的信号。',
      zhHant: '讓零散感受，變成可被看見的信號。',
      ja: '散らばった感覚を、見えるシグナルへ。',
    ),
    orbitCards: const [
      _OrbitCardData(
        alignment: Alignment(-0.72, -0.08),
        icon: Icons.chat_bubble_rounded,
        title: '文字',
        body: '灵感闪现\n随手记录',
        color: Color(0xFF8D67F5),
      ),
      _OrbitCardData(
        alignment: Alignment(-0.88, 0.42),
        icon: Icons.mic_rounded,
        title: '语音',
        body: '说下此刻\n的想法',
        color: Color(0xFF8D67F5),
      ),
      _OrbitCardData(
        alignment: Alignment(-0.58, 0.76),
        icon: Icons.sentiment_satisfied_alt_rounded,
        title: '状态',
        body: '此刻心情\n与感受',
        color: Color(0xFFF5C966),
      ),
      _OrbitCardData(
        alignment: Alignment(0.72, -0.18),
        icon: Icons.graphic_eq_rounded,
        title: '信号库',
        body: '参考常见\n生活信号',
        color: Color(0xFF7D6CF4),
      ),
      _OrbitCardData(
        alignment: Alignment(0.8, 0.56),
        icon: Icons.auto_awesome_rounded,
        title: 'AI 预判',
        body: '洞察趋势\n提前感知',
        color: Color(0xFF5C8DFF),
      ),
    ],
  );
}

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
        SnackBar(content: Text(_submitErrorText(context))),
      );
    }
  }

  Future<void> _skip() async {
    final vm = context.read<OnboardingViewModel>();
    vm.updateFocusDomains(FocusDomains.defaultIds);
    await vm.persistLocalPreference();
    await vm.trackSkipped();
    if (!mounted) return;
    await context.read<AppBootstrapState>().markOnboardingCompleted();
    if (!mounted) return;
    context.go(AppRoutes.today);
  }

  String _submitErrorText(BuildContext context) {
    return AppLocaleText.tr(
      context,
      en: 'Something went wrong. Please try again.',
      zhHans: '出了一点问题，请再试一次。',
      zhHant: '出了一點問題，請再試一次。',
      ja: '問題が発生しました。もう一度試してください。',
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OnboardingViewModel>();
    return Scaffold(
      backgroundColor: _onboardingSurfaceColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: PageView(
              controller: _pageController,
              onPageChanged: (value) => setState(() => _currentStep = value),
              children: [
                _buildOpeningScene(context),
                _OnboardingScene(
                  step: 1,
                  title: AppLocaleText.tr(
                    context,
                    en: 'See one real pattern each week',
                    zhHans: '每周看见一个真实模式',
                    zhHant: '每週看見一個真實模式',
                    ja: '毎週、ひとつの本当のパターンを見る',
                  ),
                  subtitle: AppLocaleText.tr(
                    context,
                    en: 'Weekly finds one pattern and suggests one goal. Once adopted, Life Experiment keeps its daily practice, real feedback, and adjustments.',
                    zhHans: '每周复盘从本周信号里看见一个模式，提出一个下周目标。\n生活小实验保存每日做法、真实反馈与调整。',
                    zhHant: '每週回顧從本週信號裡看見一個模式，提出一個下週目標。\n生活小實驗保存每日做法、真實回饋與調整。',
                    ja: '週間レビューは今週のパターンから目標を提案し、生活実験が毎日の取り組み、反応、調整を残します。',
                  ),
                  footer: AppLocaleText.tr(
                    context,
                    en: 'Weekly proposes goals; Life Experiment remembers what truly helps.',
                    zhHans: '每周复盘负责提出目标。\n生活小实验负责记住什么真正有效。',
                    zhHant: '每週回顧負責提出目標。\n生活小實驗負責記住什麼真正有效。',
                    ja: '週間レビューが目標を提案し、生活実験が本当に役立つ方法を残します。',
                  ),
                  orbitCards: const [],
                  foregroundArtwork: const _WeeklyDesignPreview(),
                ),
                _OnboardingScene(
                  step: 2,
                  title: AppLocaleText.tr(
                    context,
                    en: 'See the longer path taking shape',
                    zhHans: '看见更长的生活轨迹',
                    zhHant: '看見更長的生活軌跡',
                    ja: 'より長い暮らしの軌跡を見る',
                  ),
                  subtitle: AppLocaleText.tr(
                    context,
                    en: 'Journey connects monthly observations and Signals into a long-term path. Pro L3 Reflect reads core insights and pattern links one layer deeper.',
                    zhHans:
                        '旅程把本月观察与 Signal 连成长期轨迹。\n深度分析会进一步拆解核心洞察、模式联系与调整方向。',
                    zhHant:
                        '旅程把本月觀察與 Signal 連成長期軌跡。\n深度分析會進一步拆解核心洞察、模式聯繫與調整方向。',
                    ja: 'Journey は月ごとの観察と Signal を長期の軌跡につなぎ、Pro の L3 Reflect は関係をもう一段深く読みます。',
                  ),
                  footer: AppLocaleText.tr(
                    context,
                    en: 'Every long-term observation can return to real signals and feedback.',
                    zhHans: '每一条长期观察，都能回到真实信号与反馈。',
                    zhHant: '每一條長期觀察，都能回到真實信號與回饋。',
                    ja: '長期の観察は、いつでも実際のシグナルと反応に戻れます。',
                  ),
                  orbitCards: const [],
                  foregroundArtwork: const _JourneyProDesignPreview(),
                ),
                _PreferenceScene(
                  selectedIds: vm.selectedFocusDomainIds,
                  submitting: vm.submitting,
                  onToggle: (id) {
                    final next = [...vm.selectedFocusDomainIds];
                    if (next.contains(id)) {
                      if (next.length == 1) return;
                      next.remove(id);
                    } else {
                      next.add(id);
                    }
                    vm.updateFocusDomains(next);
                  },
                  onStart: () => _complete(vm),
                ),
              ],
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 10, right: 18),
                child: TextButton(
                  onPressed: vm.submitting ? null : _skip,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF7B8092),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
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
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                child: _OnboardingDots(
                  count: _onboardingPageCount,
                  current: _currentStep,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingScene extends StatelessWidget {
  final int step;
  final String title;
  final String subtitle;
  final String footer;
  final List<_OrbitCardData> orbitCards;
  final Widget? foregroundArtwork;

  const _OnboardingScene({
    super.key,
    required this.step,
    required this.title,
    required this.subtitle,
    required this.footer,
    required this.orbitCards,
    this.foregroundArtwork,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final compact = media.height < 720;

    return _AuroraOnboardingBackground(
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            28,
            compact ? 24 : 78,
            28,
            compact ? 56 : 72,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GradientTitle(title, fontSize: compact ? 33 : 40),
              SizedBox(height: compact ? 12 : 18),
              Text(
                subtitle,
                style: TextStyle(
                  color: const Color(0xFF697083),
                  fontSize: compact ? 16 : 21,
                  height: 1.38,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0,
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final pathWidth = math.min(
                      media.width * (compact ? 0.7 : 0.74),
                      constraints.maxHeight * 0.82,
                    );
                    final cardScale = media.width < 390
                        ? 0.78
                        : (media.width < 430 ? 0.84 : 0.9);
                    final usesBrandBackdrop = step == 0;
                    final artworkWidth =
                        usesBrandBackdrop || foregroundArtwork != null
                            ? pathWidth * 1.22
                            : pathWidth;
                    final backgroundKey = switch (step) {
                      0 => 'onboarding-opening-icon-background',
                      1 => 'onboarding-weekly-experiment-icon-background',
                      2 => 'onboarding-journey-pro-icon-background',
                      _ => 'onboarding-icon-background-$step',
                    };
                    return Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Align(
                          alignment: compact
                              ? const Alignment(0, 0.02)
                              : const Alignment(0, -0.02),
                          child: SizedBox(
                            width: artworkWidth,
                            height: usesBrandBackdrop
                                ? artworkWidth
                                : pathWidth * 1.12,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (usesBrandBackdrop ||
                                    foregroundArtwork != null)
                                  _BrandIconBackdrop(
                                    imageKey: backgroundKey,
                                    opacity: step == 0 ? 0.5 : 0.22,
                                  ),
                                CustomPaint(
                                  painter: _SignalPathPainter(
                                    phase: step,
                                    minimal: false,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (foregroundArtwork != null)
                          Positioned.fill(child: foregroundArtwork!),
                        for (final card in orbitCards)
                          Align(
                            alignment: _sceneCardAlignment(card, compact),
                            child: Transform.scale(
                              scale: cardScale,
                              child: _FloatingOrbitCard(data: card),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              Center(
                child: Text(
                  footer,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF666B79),
                    fontSize: compact ? 14.5 : 19,
                    height: 1.34,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Alignment _sceneCardAlignment(_OrbitCardData card, bool compact) {
    final yScale = compact ? 0.7 : 0.76;
    final yOffset = compact ? -0.08 : -0.04;
    return Alignment(
      card.alignment.x,
      (card.alignment.y * yScale + yOffset).clamp(-0.86, 0.66).toDouble(),
    );
  }
}

class _BrandIconBackdrop extends StatelessWidget {
  final String imageKey;
  final double opacity;

  const _BrandIconBackdrop({
    required this.imageKey,
    this.opacity = 0.58,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.04),
                radius: 0.72,
                colors: [
                  Colors.white.withValues(alpha: 0.5),
                  const Color(0xFFDCD9FF).withValues(alpha: 0.2),
                  Colors.white.withValues(alpha: 0),
                ],
                stops: const [0, 0.6, 1],
              ),
            ),
          ),
          ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) => const RadialGradient(
              center: Alignment(0, -0.02),
              radius: 0.76,
              colors: [Colors.white, Colors.white, Colors.transparent],
              stops: [0, 0.68, 1],
            ).createShader(bounds),
            child: Opacity(
              opacity: opacity,
              child: Image.asset(
                'assets/brand-icon-display.png',
                key: ValueKey(imageKey),
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                isAntiAlias: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyDesignPreview extends StatelessWidget {
  const _WeeklyDesignPreview();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            key: const ValueKey(
              'onboarding-weekly-experiment-design-preview',
            ),
            width: 310,
            child: _OnboardingPreviewPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const _PreviewIcon(
                        icon: Icons.calendar_month_rounded,
                        color: Color(0xFF7767F5),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocaleText.tr(
                                context,
                                en: 'Weekly',
                                zhHans: '每周复盘',
                                zhHant: '每週復盤',
                                ja: 'Weekly',
                              ),
                              style: const TextStyle(
                                color: Color(0xFF7767F5),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              AppLocaleText.tr(
                                context,
                                en: 'Weekly Review',
                                zhHans: '本周复盘',
                                zhHant: '本週復盤',
                                ja: '今週の振り返り',
                              ),
                              style: const TextStyle(
                                color: Color(0xFF29334D),
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _PreviewPill(
                        label: AppLocaleText.tr(
                          context,
                          en: 'Your choice',
                          zhHans: '待你采纳',
                          zhHant: '待你採納',
                          ja: '選択待ち',
                        ),
                        color: const Color(0xFF7767F5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                  Container(
                    padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.52),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.86),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PreviewSectionLabel(
                          icon: Icons.account_tree_rounded,
                          text: AppLocaleText.tr(
                            context,
                            en: 'This week’s behavior pattern',
                            zhHans: '本周行为模式',
                            zhHant: '本週行為模式',
                            ja: '今週の行動パターン',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _PreviewPatternNode(
                                text: AppLocaleText.tr(
                                  context,
                                  en: 'Meetings too close',
                                  zhHans: '会议接得太紧',
                                  zhHant: '會議接得太緊',
                                  ja: '会議が詰まる',
                                ),
                                color: const Color(0xFFF3A46F),
                              ),
                            ),
                            const _PreviewArrow(),
                            Expanded(
                              child: _PreviewPatternNode(
                                text: AppLocaleText.tr(
                                  context,
                                  en: 'Too much switching',
                                  zhHans: '切换太多',
                                  zhHant: '切換太多',
                                  ja: '切替が多い',
                                ),
                                color: const Color(0xFF8D72F5),
                              ),
                            ),
                            const _PreviewArrow(),
                            Expanded(
                              child: _PreviewPatternNode(
                                text: AppLocaleText.tr(
                                  context,
                                  en: 'Less recovery',
                                  zhHans: '恢复变少',
                                  zhHant: '恢復變少',
                                  ja: '回復が減る',
                                ),
                                color: const Color(0xFF69A0EF),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 9),
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7767F5).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(
                        color: const Color(0xFF7767F5).withValues(alpha: 0.16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PreviewSectionLabel(
                          icon: Icons.science_rounded,
                          text: AppLocaleText.tr(
                            context,
                            en: 'Next week’s goal',
                            zhHans: '下周目标',
                            zhHant: '下週目標',
                            ja: '来週の目標',
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AppLocaleText.tr(
                            context,
                            en: 'Give rest a light structure',
                            zhHans: '给休息加一个轻结构',
                            zhHant: '給休息加一個輕結構',
                            ja: '休息に軽い型をつくる',
                          ),
                          style: const TextStyle(
                            color: Color(0xFF3B356E),
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppLocaleText.tr(
                            context,
                            en: 'Before bed, leave 10 minutes for one low-demand recovery action.',
                            zhHans: '睡前留 10 分钟，只做一个低要求恢复动作。',
                            zhHant: '睡前留 10 分鐘，只做一個低要求恢復動作。',
                            ja: '寝る前の10分、負担の少ない回復行動を一つだけ。',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF5F6680),
                            fontSize: 11.5,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _PreviewPill(
                                label: AppLocaleText.tr(
                                  context,
                                  en: 'Keep it small, leave some room',
                                  zhHans: '保持小一点，并留出余地',
                                  zhHant: '保持小一點，並留出餘地',
                                  ja: '小さく、余白を残す',
                                ),
                                color: const Color(0xFF7767F5),
                                expanded: true,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _PreviewAction(
                              label: AppLocaleText.tr(
                                context,
                                en: 'Add',
                                zhHans: '加入下周',
                                zhHant: '加入下週',
                                ja: '来週に追加',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.arrow_downward_rounded,
                        color: Color(0xFF8D84BB),
                        size: 14,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          AppLocaleText.tr(
                            context,
                            en: 'Adopted into Life Experiment',
                            zhHans: '采纳后进入生活小实验',
                            zhHant: '採納後進入生活小實驗',
                            ja: '採用後は生活実験へ',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF777493),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  const _LifeExperimentDesignPreview(compact: true),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LifeExperimentDesignPreview extends StatelessWidget {
  final bool compact;

  const _LifeExperimentDesignPreview({this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        key: const ValueKey('onboarding-life-experiment-bridge-preview'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.88)),
        ),
        child: Row(
          children: [
            const _PreviewIcon(
              icon: Icons.science_rounded,
              color: Color(0xFF5ECAA0),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppLocaleText.tr(
                            context,
                            en: 'Life Experiment · Goal',
                            zhHans: '生活小实验 · 目标',
                            zhHant: '生活小實驗 · 目標',
                            ja: '生活実験 · 目標',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF3D4760),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _PreviewPill(
                        label: AppLocaleText.tr(
                          context,
                          en: 'Active',
                          zhHans: '进行中',
                          zhHant: '進行中',
                          ja: '進行中',
                        ),
                        color: const Color(0xFF5ECAA0),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppLocaleText.tr(
                      context,
                      en: 'Completed · Not completed',
                      zhHans: '已完成 · 未完成',
                      zhHant: '已完成 · 未完成',
                      ja: '完了 · 未完了',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF697287),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return IgnorePointer(
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            key: const ValueKey('onboarding-life-experiment-design-preview'),
            width: 310,
            child: _OnboardingPreviewPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const _PreviewIcon(
                        icon: Icons.science_rounded,
                        color: Color(0xFF7767F5),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocaleText.tr(
                                context,
                                en: 'Life Experiment',
                                zhHans: '生活小实验',
                                zhHant: '生活小實驗',
                                ja: '生活実験',
                              ),
                              style: const TextStyle(
                                color: Color(0xFF7767F5),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              AppLocaleText.tr(
                                context,
                                en: 'Goals and feedback',
                                zhHans: '目标与反馈',
                                zhHant: '目標與回饋',
                                ja: '目標とフィードバック',
                              ),
                              style: const TextStyle(
                                color: Color(0xFF29334D),
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _PreviewPill(
                        label: AppLocaleText.tr(
                          context,
                          en: 'Active',
                          zhHans: '进行中',
                          zhHant: '進行中',
                          ja: '進行中',
                        ),
                        color: const Color(0xFF5ECAA0),
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.56),
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocaleText.tr(
                            context,
                            en: 'Give rest a light structure',
                            zhHans: '给休息加一个轻结构',
                            zhHant: '給休息加一個輕結構',
                            ja: '休息に軽い型をつくる',
                          ),
                          style: const TextStyle(
                            color: Color(0xFF333B56),
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          AppLocaleText.tr(
                            context,
                            en: '3 tries · 2 helpful · 1 adjusted · 0 skipped',
                            zhHans: '3 次尝试 · 2 次有效 · 1 次调整 · 0 次跳过',
                            zhHant: '3 次嘗試 · 2 次有效 · 1 次調整 · 0 次跳過',
                            ja: '3回試行 · 2回有効 · 1回調整 · 0回見送り',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF626B80),
                            fontSize: 11.5,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 9),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: const LinearProgressIndicator(
                            value: 3 / 7,
                            minHeight: 7,
                            color: Color(0xFF7767F5),
                            backgroundColor: Color(0xFFE7E4F7),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            Text(
                              AppLocaleText.tr(
                                context,
                                en: '1 week',
                                zhHans: '1 周',
                                zhHant: '1 週',
                                ja: '1週間',
                              ),
                              style: const TextStyle(
                                color: Color(0xFF7767F5),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Color(0xFF9A9FB2),
                              size: 20,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 9),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8F0).withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(
                        color: const Color(0xFFF2CDAA).withValues(alpha: 0.5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PreviewSectionLabel(
                          icon: Icons.chat_bubble_outline_rounded,
                          text: AppLocaleText.tr(
                            context,
                            en: 'Did you complete it today?',
                            zhHans: '今天完成了吗？',
                            zhHant: '今天完成了嗎？',
                            ja: '今日は完了しましたか？',
                          ),
                          color: const Color(0xFFE49A60),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final label in [
                              AppLocaleText.tr(
                                context,
                                en: 'Completed',
                                zhHans: '已完成',
                                zhHant: '已完成',
                                ja: '完了',
                              ),
                              AppLocaleText.tr(
                                context,
                                en: 'Not completed',
                                zhHans: '未完成',
                                zhHant: '未完成',
                                ja: '未完了',
                              ),
                            ])
                              _PreviewPill(
                                label: label,
                                color: const Color(0xFFE49A60),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _JourneyProDesignPreview extends StatelessWidget {
  const _JourneyProDesignPreview();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            key: const ValueKey('onboarding-journey-pro-design-preview'),
            width: 330,
            child: _OnboardingPreviewPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const _PreviewIcon(
                        icon: Icons.route_rounded,
                        color: Color(0xFF7B63E8),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocaleText.tr(
                                context,
                                en: 'Journey',
                                zhHans: '旅程',
                                zhHant: '旅程',
                                ja: 'Journey',
                              ),
                              style: const TextStyle(
                                color: Color(0xFF7B63E8),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              AppLocaleText.tr(
                                context,
                                en: 'Monthly path and Signals',
                                zhHans: '本月轨迹与 Signal',
                                zhHant: '本月軌跡與 Signal',
                                ja: '今月の軌跡と Signal',
                              ),
                              style: const TextStyle(
                                color: Color(0xFF29334D),
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _PreviewPill(
                        label: AppLocaleText.tr(
                          context,
                          en: 'This month',
                          zhHans: '本月',
                          zhHant: '本月',
                          ja: '今月',
                        ),
                        color: const Color(0xFF7B63E8),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 118,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Image.asset(
                            'assets/journey/journey-hero-road.png',
                            fit: BoxFit.cover,
                            alignment: Alignment.centerRight,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Colors.white.withValues(alpha: 0.94),
                                  Colors.white.withValues(alpha: 0.74),
                                  Colors.white.withValues(alpha: 0.26),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(11, 10, 11, 9),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _PreviewSectionLabel(
                                icon: Icons.repeat_rounded,
                                text: AppLocaleText.tr(
                                  context,
                                  en: 'A repeated observation this month',
                                  zhHans: '本月反复出现的观察',
                                  zhHant: '本月反覆出現的觀察',
                                  ja: '今月くり返し現れた観察',
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                AppLocaleText.tr(
                                  context,
                                  en: 'After frequent switching, a little quiet recovery makes it easier to re-enter the day.',
                                  zhHans: '连续切换后，留一点安静恢复，会更容易重新进入状态。',
                                  zhHant: '連續切換後，留一點安靜恢復，會更容易重新進入狀態。',
                                  ja: '切り替えが続いた後は、静かな回復時間があると戻りやすそうです。',
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF33405D),
                                  fontSize: 11.5,
                                  height: 1.3,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Spacer(),
                              Row(
                                children: [
                                  _PreviewPill(
                                    label: AppLocaleText.tr(
                                      context,
                                      en: 'Confirmed',
                                      zhHans: '已确认',
                                      zhHant: '已確認',
                                      ja: '確認済み',
                                    ),
                                    color: const Color(0xFF5ECAA0),
                                  ),
                                  const Spacer(),
                                  _PreviewPill(
                                    label: AppLocaleText.tr(
                                      context,
                                      en: 'View Signals',
                                      zhHans: '查看 Signal',
                                      zhHant: '查看 Signal',
                                      ja: 'Signal を見る',
                                    ),
                                    color: const Color(0xFF7B63E8),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _JourneyPreviewClue(
                          icon: Icons.spa_rounded,
                          color: const Color(0xFF55BFA2),
                          title: AppLocaleText.tr(
                            context,
                            en: 'Recovery clue',
                            zhHans: '恢复线索',
                            zhHant: '恢復線索',
                            ja: '回復の手がかり',
                          ),
                          body: AppLocaleText.tr(
                            context,
                            en: 'A short walk helps stability return.',
                            zhHans: '短暂散步后，更容易重新稳定。',
                            zhHant: '短暫散步後，更容易重新穩定。',
                            ja: '短い散歩の後は戻りやすい。',
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: _JourneyPreviewClue(
                          icon: Icons.science_rounded,
                          color: const Color(0xFFF0A26B),
                          title: AppLocaleText.tr(
                            context,
                            en: 'Goal feedback',
                            zhHans: '目标反馈',
                            zhHant: '目標回饋',
                            ja: '目標のフィードバック',
                          ),
                          body: AppLocaleText.tr(
                            context,
                            en: 'Ten input-free minutes made starting easier.',
                            zhHans: '睡前 10 分钟无输入，更容易开始。',
                            zhHant: '睡前 10 分鐘無輸入，更容易開始。',
                            ja: '寝る前の10分で始めやすくなった。',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF7767F5).withValues(alpha: 0.14),
                          Colors.white.withValues(alpha: 0.72),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFF7767F5).withValues(alpha: 0.18),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFB956),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: const Text(
                                'PRO',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                AppLocaleText.tr(
                                  context,
                                  en: 'Weekly Deep Review',
                                  zhHans: '每周复盘 · 深度分析',
                                  zhHant: '每週復盤 · 深度分析',
                                  ja: 'Weekly 深掘りレビュー',
                                ),
                                style: const TextStyle(
                                  color: Color(0xFF3B356E),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            _PreviewPill(
                              label: AppLocaleText.tr(
                                context,
                                en: 'Deep reflect',
                                zhHans: '深度反思',
                                zhHant: '深度反思',
                                ja: '深い振り返り',
                              ),
                              color: const Color(0xFF7767F5),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        _PreviewSectionLabel(
                          icon: Icons.auto_graph_rounded,
                          text: AppLocaleText.tr(
                            context,
                            en: 'This week’s core insight',
                            zhHans: '本周核心洞察',
                            zhHant: '本週核心洞察',
                            ja: '今週の中心となる洞察',
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          AppLocaleText.tr(
                            context,
                            en: 'Repeated switching may be squeezing out recovery space.',
                            zhHans: '反复切换，可能正在挤压真正的恢复空间。',
                            zhHant: '反覆切換，可能正在擠壓真正的恢復空間。',
                            ja: '切り替えの多さが、回復の余白を狭めているかもしれません。',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF515A73),
                            fontSize: 11,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            Expanded(
                              child: _PreviewPatternNode(
                                text: AppLocaleText.tr(
                                  context,
                                  en: 'Trigger',
                                  zhHans: '触发点',
                                  zhHant: '觸發點',
                                  ja: 'きっかけ',
                                ),
                                color: const Color(0xFFF0A26B),
                              ),
                            ),
                            const _PreviewArrow(),
                            Expanded(
                              child: _PreviewPatternNode(
                                text: AppLocaleText.tr(
                                  context,
                                  en: 'Reaction',
                                  zhHans: '典型反应',
                                  zhHant: '典型反應',
                                  ja: '反応',
                                ),
                                color: const Color(0xFF8D72F5),
                              ),
                            ),
                            const _PreviewArrow(),
                            Expanded(
                              child: _PreviewPatternNode(
                                text: AppLocaleText.tr(
                                  context,
                                  en: 'Long impact',
                                  zhHans: '长期影响',
                                  zhHant: '長期影響',
                                  ja: '長期的な影響',
                                ),
                                color: const Color(0xFF69A0EF),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        _PreviewSectionLabel(
                          icon: Icons.architecture_rounded,
                          text: AppLocaleText.tr(
                            context,
                            en: 'Deep action design · why first / try / review',
                            zhHans: '深度行动设计 · 为什么先做 / 下周试试 / 复盘指标',
                            zhHant: '深度行動設計 · 為什麼先做 / 下週試試 / 復盤指標',
                            ja: '深い行動設計 · 理由 / 試す / 振り返る',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _JourneyPreviewClue extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const _JourneyPreviewClue({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF5B647B),
              fontSize: 9.8,
              height: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPreviewPanel extends StatelessWidget {
  final Widget child;

  const _OnboardingPreviewPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7568A6).withValues(alpha: 0.12),
            blurRadius: 34,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.34),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PreviewIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _PreviewIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.95),
            color.withValues(alpha: 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(13),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.22),
            blurRadius: 14,
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 21),
    );
  }
}

class _PreviewSectionLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _PreviewSectionLabel({
    required this.icon,
    required this.text,
    this.color = const Color(0xFF7767F5),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _PreviewPatternNode extends StatelessWidget {
  final String text;
  final Color color;

  const _PreviewPatternNode({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color.withValues(alpha: 0.96),
          fontSize: 10.5,
          height: 1.15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PreviewArrow extends StatelessWidget {
  const _PreviewArrow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 3),
      child: Icon(
        Icons.arrow_forward_rounded,
        color: Color(0xFFAAA8C6),
        size: 14,
      ),
    );
  }
}

class _PreviewPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool expanded;

  const _PreviewPill({
    required this.label,
    required this.color,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: expanded ? TextAlign.center : TextAlign.start,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PreviewAction extends StatelessWidget {
  final String label;

  const _PreviewAction({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF7767F5),
        borderRadius: BorderRadius.circular(99),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7767F5).withValues(alpha: 0.2),
            blurRadius: 12,
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PreferenceScene extends StatelessWidget {
  final List<String> selectedIds;
  final bool submitting;
  final ValueChanged<String> onToggle;
  final VoidCallback onStart;

  const _PreferenceScene({
    required this.selectedIds,
    required this.submitting,
    required this.onToggle,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final compact = media.height < 720;
    final iconSize = math.min(
      media.width * (compact ? 0.19 : 0.42),
      compact ? 60.0 : 170.0,
    );

    return _AuroraOnboardingBackground(
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            28,
            compact ? 24 : 76,
            28,
            compact ? 62 : 86,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (compact)
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: _GradientTitle(
                      AppLocaleText.tr(
                        context,
                        en: 'Choose your focus',
                        zhHans: '选择你的关注重点',
                        zhHant: '選擇你的關注重點',
                        ja: '注目したいことを選ぶ',
                      ),
                      fontSize: 34,
                    ),
                  ),
                )
              else
                _GradientTitle(
                  AppLocaleText.tr(
                    context,
                    en: 'Choose your focus',
                    zhHans: '选择你的关注重点',
                    zhHant: '選擇你的關注重點',
                    ja: '注目したいことを選ぶ',
                  ),
                  fontSize: 42,
                ),
              SizedBox(height: compact ? 10 : 18),
              Text(
                AppLocaleText.tr(
                  context,
                  en: 'Tell AI which life areas you want it to notice first. You can adjust this anytime later.',
                  zhHans: '先告诉 AI 你更希望它关注哪些生活领域，之后也可以随时调整。',
                  zhHant: '先告訴 AI 你更希望它關注哪些生活領域，之後也可以隨時調整。',
                  ja: 'AIに見てほしい生活領域を先に伝えます。あとからいつでも調整できます。',
                ),
                style: TextStyle(
                  color: const Color(0xFF697083),
                  fontSize: compact ? 15.2 : 20,
                  height: compact ? 1.32 : 1.38,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0,
                ),
              ),
              SizedBox(height: compact ? 8 : 20),
              Center(
                child: SizedBox.square(
                  dimension: iconSize,
                  child: const _BrandIconBackdrop(
                    imageKey: 'onboarding-preference-icon-background',
                  ),
                ),
              ),
              SizedBox(height: compact ? 8 : 18),
              Expanded(
                child: _FocusDomainGrid(
                  selectedIds: selectedIds,
                  onToggle: onToggle,
                ),
              ),
              SizedBox(height: compact ? 8 : 14),
              Center(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Start where you care. The suggestions will feel closer to life.',
                    zhHans: '从你在意的地方开始，更容易得到贴近生活的建议。',
                    zhHant: '從你在意的地方開始，更容易得到貼近生活的建議。',
                    ja: '気になる場所から始めると、生活に近い提案になります。',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF6F7381),
                    fontSize: compact ? 13.5 : 17,
                    height: compact ? 1.28 : 1.34,
                    letterSpacing: 0,
                  ),
                ),
              ),
              SizedBox(height: compact ? 10 : 16),
              _StartSetupButton(
                submitting: submitting,
                onPressed: onStart,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GradientTitle extends StatelessWidget {
  final String text;
  final double fontSize;

  const _GradientTitle(this.text, {this.fontSize = 42});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [
          Color(0xFF4C86F6),
          Color(0xFF8176F6),
          Color(0xFF7D68EE),
        ],
      ).createShader(bounds),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          height: 1.08,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ).copyWith(fontSize: fontSize),
      ),
    );
  }
}

class _AuroraOnboardingBackground extends StatelessWidget {
  final Widget child;

  const _AuroraOnboardingBackground({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFCF4),
            Color(0xFFFFEBD6),
            Color(0xFFF0E4FF),
            Color(0xFFD9E8FF),
            Color(0xFFEAF3FF),
            Color(0xFFFFFFFF),
          ],
          stops: [0, 0.23, 0.5, 0.72, 0.9, 1],
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _CloudPainter())),
          const Positioned.fill(
            child: CustomPaint(painter: _OnboardingHazePainter()),
          ),
          const Positioned.fill(
            child: CustomPaint(painter: _SoftParticlePainter()),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.1, -0.12),
                    radius: 0.86,
                    colors: [
                      Colors.white.withValues(alpha: 0.08),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _CloudPainter extends CustomPainter {
  const _CloudPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cloudPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.36)
      ..style = PaintingStyle.fill;
    final glowPaint = Paint()
      ..color = const Color(0xFFB6B9FF).withValues(alpha: 0.16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);

    void blob(Offset center, double radius) {
      canvas.drawCircle(center, radius, glowPaint);
      canvas.drawCircle(center, radius, cloudPaint);
    }

    blob(Offset(-size.width * 0.05, size.height * 0.43), size.width * 0.2);
    blob(Offset(size.width * 1.02, size.height * 0.22), size.width * 0.28);
    blob(Offset(size.width * 0.06, size.height * 0.76), size.width * 0.24);
    blob(Offset(size.width * 0.96, size.height * 0.7), size.width * 0.22);

    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.82);
    final sparklePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.86)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final dots = [
      const Offset(0.18, 0.08),
      const Offset(0.41, 0.12),
      const Offset(0.72, 0.09),
      const Offset(0.82, 0.18),
      const Offset(0.36, 0.42),
      const Offset(0.7, 0.47),
      const Offset(0.92, 0.62),
      const Offset(0.14, 0.88),
    ];
    for (final dot in dots) {
      canvas.drawCircle(
        Offset(dot.dx * size.width, dot.dy * size.height),
        dot.dx > 0.8 ? 2.8 : 2,
        dotPaint,
      );
    }
    for (final dot in [const Offset(0.78, 0.26), const Offset(0.12, 0.58)]) {
      final center = Offset(dot.dx * size.width, dot.dy * size.height);
      canvas.drawLine(
          center.translate(-7, 0), center.translate(7, 0), sparklePaint);
      canvas.drawLine(
          center.translate(0, -7), center.translate(0, 7), sparklePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OnboardingHazePainter extends CustomPainter {
  const _OnboardingHazePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final topWash = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0x30FFE1B6),
          Color(0x2CEBDAFF),
          Color(0x28BFD8FF),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, topWash);

    final wavePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0),
          const Color(0xFFFFFFFF).withValues(alpha: 0.42),
          const Color(0xFFE6EFFF).withValues(alpha: 0.44),
        ],
      ).createShader(Offset.zero & size);
    final base = size.height * 0.72;
    final wave = Path()
      ..moveTo(0, base)
      ..cubicTo(size.width * 0.18, base - 44, size.width * 0.34, base + 34,
          size.width * 0.52, base - 10)
      ..cubicTo(size.width * 0.7, base - 52, size.width * 0.86, base + 18,
          size.width, base - 20)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(wave, wavePaint);

    final leafPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.34);

    void leaves(Offset root, double scale, bool flip) {
      final direction = flip ? -1.0 : 1.0;
      final stem = Path()
        ..moveTo(root.dx, root.dy)
        ..cubicTo(
            root.dx + 10 * direction * scale,
            root.dy - 28 * scale,
            root.dx + 18 * direction * scale,
            root.dy - 48 * scale,
            root.dx + 18 * direction * scale,
            root.dy - 72 * scale);
      canvas.drawPath(stem, leafPaint);
      for (final t in const [0.25, 0.42, 0.6, 0.76]) {
        final y = root.dy - 72 * scale * t;
        final x = root.dx + 18 * direction * scale * t;
        final leaf = Path()
          ..moveTo(x, y)
          ..quadraticBezierTo(x + 20 * direction * scale, y - 12 * scale,
              x + 34 * direction * scale, y - 30 * scale)
          ..quadraticBezierTo(x + 8 * direction * scale, y - 26 * scale, x, y);
        canvas.drawPath(leaf, leafPaint);
      }
    }

    leaves(Offset(size.width * 0.1, size.height * 0.82), 0.88, false);
    leaves(Offset(size.width * 0.9, size.height * 0.82), 0.82, true);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SoftParticlePainter extends CustomPainter {
  const _SoftParticlePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final sparkPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withValues(alpha: 0.72);
    final blueGlow = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF76A8FF).withValues(alpha: 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    final violetGlow = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF8D67F5).withValues(alpha: 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);

    final glows = [
      (const Offset(0.32, 0.34), 34.0, blueGlow),
      (const Offset(0.62, 0.42), 28.0, violetGlow),
      (const Offset(0.38, 0.78), 24.0, blueGlow),
    ];
    for (final glow in glows) {
      canvas.drawCircle(
        Offset(glow.$1.dx * size.width, glow.$1.dy * size.height),
        glow.$2,
        glow.$3,
      );
    }

    final sparks = [
      const Offset(0.16, 0.2),
      const Offset(0.28, 0.48),
      const Offset(0.5, 0.28),
      const Offset(0.74, 0.36),
      const Offset(0.66, 0.64),
      const Offset(0.22, 0.72),
      const Offset(0.84, 0.82),
    ];
    for (final point in sparks) {
      final center = Offset(point.dx * size.width, point.dy * size.height);
      canvas.drawCircle(center, point.dx > 0.7 ? 1.8 : 1.4, sparkPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SignalPathPainter extends CustomPainter {
  final int phase;
  final bool minimal;

  const _SignalPathPainter({
    required this.phase,
    required this.minimal,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.42);
    final radius = math.min(size.width, size.height) * (minimal ? 0.32 : 0.36);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final blurPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = minimal ? 20 : 32
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [
          Color(0xFFFFB84D),
          Color(0xFF5CE5D2),
          Color(0xFF6CA6FF),
          Color(0xFF8D64F7),
          Color(0xFFFFB84D),
        ],
      ).createShader(rect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawArc(rect, -math.pi * 0.06, math.pi * 1.78, false, blurPaint);

    final haloPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: minimal ? 0.66 : 0.5),
          const Color(0xFFB8D7FF).withValues(alpha: 0.18),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.3));
    canvas.drawCircle(center, radius * 1.24, haloPaint);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = minimal ? 12 : 22
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [
          Color(0xFFFFBE50),
          Color(0xFF64E5DB),
          Color(0xFF6EA8FF),
          Color(0xFF8C68F7),
          Color(0xFFFFBE50),
        ],
      ).createShader(rect);
    canvas.drawArc(rect, -math.pi * 0.08, math.pi * 1.76, false, ringPaint);

    final whiteLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = minimal ? 2.4 : 4.2
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.86)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.74),
      -math.pi * 0.05,
      math.pi * 1.7,
      false,
      whiteLine,
    );

    final path = Path()
      ..moveTo(size.width * 0.52, size.height * 0.44)
      ..cubicTo(
        size.width * 0.18,
        size.height * 0.56,
        size.width * 0.7,
        size.height * 0.66,
        size.width * 0.4,
        size.height * 0.78,
      )
      ..cubicTo(
        size.width * 0.22,
        size.height * 0.86,
        size.width * 0.75,
        size.height * 0.88,
        size.width * 0.58,
        size.height * 1.08,
      );
    final roadGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = minimal ? 12 : 24
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.5),
          const Color(0xFFFFE5B6).withValues(alpha: 0.44),
          const Color(0xFFA8D6FF).withValues(alpha: 0.5),
        ],
      ).createShader(Offset.zero & size)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawPath(path, roadGlow);
    canvas.drawPath(path, whiteLine..strokeWidth = minimal ? 2 : 3.4);

    if (!minimal) {
      final connectorPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.42)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8);
      final connectors = [
        (
          Offset(size.width * 0.24, size.height * 0.48),
          Offset(size.width * 0.38, size.height * 0.42)
        ),
        (
          Offset(size.width * 0.72, size.height * 0.42),
          Offset(size.width * 0.6, size.height * 0.44)
        ),
        (
          Offset(size.width * 0.58, size.height * 0.72),
          Offset(size.width * 0.5, size.height * 0.58)
        ),
      ];
      for (final connector in connectors) {
        canvas.drawLine(connector.$1, connector.$2, connectorPaint);
      }
    }

    final nodePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white;
    final nodeBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = minimal ? 2 : 4
      ..color = const Color(0xFF85A8FF);
    final nodes = [
      Offset(
        center.dx + math.cos(-math.pi * 0.08) * radius,
        center.dy + math.sin(-math.pi * 0.08) * radius,
      ),
      Offset(
        center.dx + math.cos(math.pi * 0.62) * radius,
        center.dy + math.sin(math.pi * 0.62) * radius,
      ),
      Offset(
        center.dx + math.cos(math.pi * 1.14) * radius,
        center.dy + math.sin(math.pi * 1.14) * radius,
      ),
    ];
    for (final node in nodes) {
      canvas.drawCircle(node, minimal ? 6 : 10, nodePaint);
      canvas.drawCircle(node, minimal ? 6 : 10, nodeBorder);
    }
  }

  @override
  bool shouldRepaint(covariant _SignalPathPainter oldDelegate) {
    return oldDelegate.phase != phase || oldDelegate.minimal != minimal;
  }
}

class _OrbitCardData {
  final Alignment alignment;
  final IconData icon;
  final String title;
  final String body;
  final Color color;

  const _OrbitCardData({
    required this.alignment,
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });
}

class _FloatingOrbitCard extends StatelessWidget {
  final _OrbitCardData data;

  const _FloatingOrbitCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 134,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.52),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
          boxShadow: [
            BoxShadow(
              color: data.color.withValues(alpha: 0.16),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    data.color.withValues(alpha: 0.9),
                    data.color.withValues(alpha: 0.48),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: data.color.withValues(alpha: 0.25),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Icon(data.icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    data.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: data.color,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    data.body,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF6D7281),
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0,
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

class _FocusDomainGrid extends StatelessWidget {
  final List<String> selectedIds;
  final ValueChanged<String> onToggle;

  const _FocusDomainGrid({
    required this.selectedIds,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = constraints.maxWidth < 380 ? 9.0 : 11.0;
        final availableTileHeight = (constraints.maxHeight - (spacing * 2)) / 3;
        final tileHeight = availableTileHeight.clamp(54.0, 74.0);
        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: FocusDomains.options.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            mainAxisExtent: tileHeight,
          ),
          itemBuilder: (context, index) {
            final option = FocusDomains.options[index];
            final selected = selectedIds.contains(option.id);
            return _FocusDomainTile(
              option: option,
              selected: selected,
              onTap: () => onToggle(option.id),
            );
          },
        );
      },
    );
  }
}

class _FocusDomainTile extends StatelessWidget {
  final FocusDomainOption option;
  final bool selected;
  final VoidCallback onTap;

  const _FocusDomainTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('onboarding-focus-${option.id}'),
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: selected ? 0.72 : 0.48),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? option.color.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.72),
            width: selected ? 1.25 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: option.color.withValues(alpha: selected ? 0.16 : 0.07),
              blurRadius: selected ? 22 : 14,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        option.color.withValues(alpha: 0.95),
                        option.color.withValues(alpha: 0.45),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [
                      BoxShadow(
                        color: option.color.withValues(alpha: 0.15),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Icon(option.icon, color: Colors.white, size: 16),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      option.label(context),
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        color:
                            selected ? option.color : const Color(0xFF6B7082),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (selected)
              Positioned(
                top: -7,
                right: -7,
                child: Container(
                  width: 21,
                  height: 21,
                  decoration: const BoxDecoration(
                    color: Color(0xFF7667F5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded,
                      size: 15, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StartSetupButton extends StatelessWidget {
  final bool submitting;
  final VoidCallback onPressed;

  const _StartSetupButton({
    required this.submitting,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7767F6).withValues(alpha: 0.14),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: FilledButton(
          key: const ValueKey('onboarding-start-button'),
          onPressed: submitting ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.62),
            foregroundColor: const Color(0xFF7767F6),
            disabledBackgroundColor: Colors.white.withValues(alpha: 0.45),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.82),
              ),
            ),
            textStyle: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          child: submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Start  >',
                    zhHans: '开始  >',
                    zhHant: '開始  >',
                    ja: '始める  >',
                  ),
                ),
        ),
      ),
    );
  }
}

class _OnboardingDots extends StatelessWidget {
  final int count;
  final int current;

  const _OnboardingDots({
    required this.count,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final active = index == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 7),
          width: active ? 22 : 11,
          height: 11,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            gradient: active
                ? const LinearGradient(
                    colors: [Color(0xFF49B9FF), Color(0xFF8D67F5)],
                  )
                : null,
            color: active ? null : const Color(0xFFD8D8E8),
          ),
        );
      }),
    );
  }
}
