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
                      margin: EdgeInsets.only(right: index == _stepCount - 1 ? 0 : 8),
                      height: 4,
                      decoration: BoxDecoration(
                        color: active
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
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
                children: [
                  const _HeroIntroStep(),
                  const _HowItWorksStep(),
                  _FocusAreaStep(vm: vm),
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
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _PathGlowHero(),
          const SizedBox(height: 28),
          Text(
            'Signal Path',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            AppLocaleText.tr(
              context,
              en: 'AI Journal',
              zhHans: 'AI 手帐',
              zhHant: 'AI 手帳',
              ja: 'AI手帳',
            ),
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),
          Text(
            AppLocaleText.tr(
              context,
              en: 'Write it down first. We can make sense of the rest slowly.',
              zhHans: '先记下来，剩下的我们慢慢看清。',
              zhHant: '先記下來，剩下的我們慢慢看清。',
              ja: 'まずは残しておこう。あとのことは、ゆっくり見えてくる。',
            ),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PathGlowHero extends StatelessWidget {
  const _PathGlowHero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(36),
      ),
      child: CustomPaint(
        painter: _PathGlowPainter(
          lineColor: theme.colorScheme.primary.withValues(alpha: 0.72),
          glowColor: theme.colorScheme.primary,
          softColor: theme.colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
    );
  }
}

class _PathGlowPainter extends CustomPainter {
  final Color lineColor;
  final Color glowColor;
  final Color softColor;

  _PathGlowPainter({
    required this.lineColor,
    required this.glowColor,
    required this.softColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.18, size.height * 0.68)
      ..lineTo(size.width * 0.38, size.height * 0.52)
      ..lineTo(size.width * 0.55, size.height * 0.58)
      ..lineTo(size.width * 0.74, size.height * 0.34);

    final softPaint = Paint()
      ..color = softColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 18;

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 5;

    canvas.drawPath(path, softPaint);
    canvas.drawPath(path, linePaint);

    final points = [
      Offset(size.width * 0.18, size.height * 0.68),
      Offset(size.width * 0.38, size.height * 0.52),
      Offset(size.width * 0.55, size.height * 0.58),
      Offset(size.width * 0.74, size.height * 0.34),
    ];

    final nodePaint = Paint()..color = lineColor;
    for (final point in points.take(3)) {
      canvas.drawCircle(point, 5, nodePaint);
    }

    final glowCenter = points.last;
    canvas.drawCircle(
      glowCenter,
      16,
      Paint()..color = glowColor.withValues(alpha: 0.18),
    );
    canvas.drawCircle(
      glowCenter,
      9,
      Paint()..color = glowColor.withValues(alpha: 0.32),
    );
    canvas.drawCircle(
      glowCenter,
      5.5,
      Paint()..color = glowColor,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HowItWorksStep extends StatelessWidget {
  const _HowItWorksStep();

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        number: '01',
        title: AppLocaleText.tr(
          context,
          en: 'Write down one small thing',
          zhHans: '记下一件小事',
          zhHant: '記下一件小事',
          ja: '小さなことを一つ残す',
        ),
        body: AppLocaleText.tr(
          context,
          en: 'Anything that felt stuck, repeated, frustrating, off, or just a little noticeable today is enough.',
          zhHans: '今天哪里卡了一下，哪里重复了一下，哪里让你烦躁、不顺，或者哪里让你有点在意，都可以先记下来。',
          zhHant: '今天哪裡卡了一下，哪裡重複了一下，哪裡讓你煩躁、不順，或者哪裡讓你有點在意，都可以先記下來。',
          ja: '今日どこで少し引っかかったか、どこが繰り返されたか、どこで少し苛立ったか、少し気になったことでも大丈夫です。',
        ),
      ),
      (
        number: '02',
        title: AppLocaleText.tr(
          context,
          en: 'Receive one short response',
          zhHans: '收到一句回应',
          zhHant: '收到一句回應',
          ja: '短いひと言を受け取る',
        ),
        body: AppLocaleText.tr(
          context,
          en: 'After each entry, AI will first respond with one short line and help you hold onto that moment.',
          zhHans: '每次记完后，AI 会先用一句很短的话接住你，陪你把这条留住。',
          zhHant: '每次記完後，AI 會先用一句很短的話接住你，陪你把這條留住。',
          ja: '記録のたびに、AI がまず短いひと言で受け止め、その瞬間を残すのを手伝います。',
        ),
      ),
      (
        number: '03',
        title: AppLocaleText.tr(
          context,
          en: 'Start seeing patterns slowly',
          zhHans: '慢慢看见规律',
          zhHant: '慢慢看見規律',
          ja: '少しずつパターンが見えてくる',
        ),
        body: AppLocaleText.tr(
          context,
          en: 'After a few days or a week, you’ll start seeing what repeats, what deserves adjustment, and what is already helping.',
          zhHans: '过几天、过一周后，你会看到哪些情况在重复，哪些地方值得调整，哪些做法其实已经开始有帮助。',
          zhHant: '過幾天、過一週後，你會看到哪些情況在重複，哪些地方值得調整，哪些做法其實已經開始有幫助。',
          ja: '数日から一週間ほどすると、何が繰り返されているのか、どこを調整すべきか、何がすでに助けになっているのかが見えてきます。',
        ),
      ),
      (
        number: '04',
        title: AppLocaleText.tr(
          context,
          en: 'Keep the clues that fit you',
          zhHans: '把适合你的线索留下来',
          zhHant: '把適合你的線索留下來',
          ja: '自分に合う手がかりを残す',
        ),
        body: AppLocaleText.tr(
          context,
          en: 'AI will gradually remember your rhythm, recurring frictions, what is getting smoother, and what still deserves watching.',
          zhHans: '让 AI 慢慢记住你的节奏、反复出现的摩擦点、已经开始变顺的方法，以及那些还值得继续观察的变化。',
          zhHant: '讓 AI 慢慢記住你的節奏、反覆出現的摩擦點、已經開始變順的方法，以及那些還值得繼續觀察的變化。',
          ja: 'AI はあなたのリズム、繰り返し現れる摩擦、少しずつ整ってきたやり方、まだ見守るべき変化を少しずつ覚えていきます。',
        ),
      ),
      (
        number: '05',
        title: AppLocaleText.tr(
          context,
          en: 'Leave the trail that appears over time',
          zhHans: '留下这一路慢慢显出来的轨迹',
          zhHant: '留下這一路慢慢顯出來的軌跡',
          ja: '時間とともに見えてくる軌跡を残す',
        ),
        body: AppLocaleText.tr(
          context,
          en: 'The places you return to, where you get stuck, what is getting smoother, and what is still emerging will all be kept bit by bit.',
          zhHans: '你常走到哪些地方，最容易卡在哪些地方，哪些部分已经开始变顺，哪些变化还在慢慢浮现，都会一点点被留下来。',
          zhHant: '你常走到哪些地方，最容易卡在哪些地方，哪些部分已經開始變順，哪些變化還在慢慢浮現，都會一點點被留下來。',
          ja: 'よく戻ってくる場所、詰まりやすい場所、少しずつ整ってきた部分、まだ浮かびつつある変化が、少しずつ残されていきます。',
        ),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocaleText.tr(
              context,
              en: 'How you will use it',
              zhHans: '你会怎么使用它',
              zhHant: '你會怎麼使用它',
              ja: 'どう使っていくか',
            ),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocaleText.tr(
              context,
              en: 'You do not need to figure things out first. Let AI help you see them gradually.',
              zhHans: '不需要你先把事情想清楚，让 AI 来帮你想。',
              zhHant: '不需要你先把事情想清楚，讓 AI 來幫你想。',
              ja: '最初から整理できていなくても大丈夫。AI と一緒に少しずつ見えてきます。',
            ),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = items[index];
                return _OnboardingInfoCard(
                  number: item.number,
                  title: item.title,
                  body: item.body,
                );
              },
            ),
          ),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              AppLocaleText.tr(
                context,
                en: 'The point is not to remember perfectly, but to leave behind what truly happened first.',
                zhHans: '重点不是“记得多好”，而是先把真实发生的东西留下来。',
                zhHant: '重點不是「記得多好」，而是先把真實發生的東西留下來。',
                ja: '大事なのは「どれだけ上手に覚えるか」ではなく、まず本当に起きたことを残しておくことです。',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusAreaStep extends StatelessWidget {
  final OnboardingViewModel vm;

  const _FocusAreaStep({required this.vm});

  @override
  Widget build(BuildContext context) {
    final options = _focusOptions(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocaleText.tr(
              context,
              en: 'What would you like me to notice first?',
              zhHans: '你更希望我先留意哪些方面？',
              zhHant: '你更希望我先留意哪些方面？',
              ja: 'まず、どんな方向に注目してほしい？',
            ),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocaleText.tr(
              context,
              en: 'This is not fixed forever. Choose the closest direction for now, and you can change it later in Me.',
              zhHans: '这一步不是必须的，也不是以后不能改。先选一个最接近的方向，之后可以在 Me 页面里调整。',
              zhHant: '這一步不是必須的，也不是以後不能改。先選一個最接近的方向，之後可以在 Me 頁面裡調整。',
              ja: 'これは固定ではありません。いま一番近い方向を選んで、あとで Me で変えられます。',
            ),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: options.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final option = options[index];
                final selected = vm.selectedRepeatArea == option.value;

                return InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => vm.updateRepeatArea(option.value),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: selected
                          ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.55)
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                        width: selected ? 1.6 : 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          selected ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: selected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                option.title,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(option.subtitle),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<_FocusAreaOption> _focusOptions(BuildContext context) {
    return [
      _FocusAreaOption(
        value: 'work_tasks',
        title: AppLocaleText.tr(
          context,
          en: 'Work and tasks',
          zhHans: '工作与任务',
          zhHant: '工作與任務',
          ja: '仕事とタスク',
        ),
        subtitle: AppLocaleText.tr(
          context,
          en: 'Progress, priorities, collaboration, communication, and repeated workflows',
          zhHans: '比如推进事情、安排优先级、合作沟通、反复消耗你的流程',
          zhHant: '比如推進事情、安排優先級、合作溝通、反覆消耗你的流程',
          ja: '物事の進め方、優先順位、協働や連絡、繰り返し消耗する流れ',
        ),
      ),
      _FocusAreaOption(
        value: 'emotion_stress',
        title: AppLocaleText.tr(
          context,
          en: 'Emotions and stress',
          zhHans: '情绪与压力',
          zhHant: '情緒與壓力',
          ja: '感情とストレス',
        ),
        subtitle: AppLocaleText.tr(
          context,
          en: 'Moments of frustration, hurt, joy, tension, or feelings that linger',
          zhHans: '比如烦躁、委屈、开心、紧绷，或者总放不下的时刻',
          zhHant: '比如煩躁、委屈、開心、緊繃，或者總放不下的時刻',
          ja: 'イライラ、しんどさ、うれしさ、張りつめた感じ、引きずる瞬間',
        ),
      ),
      _FocusAreaOption(
        value: 'relationships',
        title: AppLocaleText.tr(
          context,
          en: 'Relationships and interaction',
          zhHans: '关系与相处',
          zhHant: '關係與相處',
          ja: '人間関係と付き合い方',
        ),
        subtitle: AppLocaleText.tr(
          context,
          en: 'Family, friends, coworkers, partners, friction, and what matters to you',
          zhHans: '比如和家人、朋友、同事、伴侣之间的互动、摩擦和在意',
          zhHant: '比如和家人、朋友、同事、伴侶之間的互動、摩擦和在意',
          ja: '家族、友人、同僚、パートナーとのやり取り、摩擦、気になること',
        ),
      ),
      _FocusAreaOption(
        value: 'time_rhythm',
        title: AppLocaleText.tr(
          context,
          en: 'Time and daily rhythm',
          zhHans: '时间与生活节奏',
          zhHant: '時間與生活節奏',
          ja: '時間と生活リズム',
        ),
        subtitle: AppLocaleText.tr(
          context,
          en: 'Commutes, routines, procrastination, rest, and places where your day gets interrupted',
          zhHans: '比如通勤、作息、拖延、休息不够，或者一天总被打断的地方',
          zhHant: '比如通勤、作息、拖延、休息不夠，或者一天總被打斷的地方',
          ja: '通勤、生活リズム、先延ばし、休めなさ、一日の中で何度も途切れること',
        ),
      ),
      _FocusAreaOption(
        value: 'health_body',
        title: AppLocaleText.tr(
          context,
          en: 'Health and physical state',
          zhHans: '健康与身体状态',
          zhHant: '健康與身體狀態',
          ja: '健康と身体の状態',
        ),
        subtitle: AppLocaleText.tr(
          context,
          en: 'Fatigue, sleep, food, exercise, recovery, and body signals',
          zhHans: '比如疲惫、睡眠、饮食、运动、恢复感，或者身体给你的提醒',
          zhHant: '比如疲憊、睡眠、飲食、運動、恢復感，或者身體給你的提醒',
          ja: '疲れ、睡眠、食事、運動、回復感、身体からのサイン',
        ),
      ),
      _FocusAreaOption(
        value: 'money_spending',
        title: AppLocaleText.tr(
          context,
          en: 'Money and spending',
          zhHans: '金钱与消费',
          zhHant: '金錢與消費',
          ja: 'お金と消費',
        ),
        subtitle: AppLocaleText.tr(
          context,
          en: 'Spending, habits, pressure, budgeting, and hesitant purchases',
          zhHans: '比如花销、消费习惯、金钱压力、预算安排，或者总让你犹豫的支出',
          zhHant: '比如花銷、消費習慣、金錢壓力、預算安排，或者總讓你猶豫的支出',
          ja: '支出、買い方の癖、お金のプレッシャー、予算、迷いやすい出費',
        ),
      ),
      _FocusAreaOption(
        value: 'learning_growth_expression',
        title: AppLocaleText.tr(
          context,
          en: 'Learning, growth, and expression',
          zhHans: '学习、成长与表达',
          zhHant: '學習、成長與表達',
          ja: '学び・成長・表現',
        ),
        subtitle: AppLocaleText.tr(
          context,
          en: 'Things you want to learn, express clearly, improve, or keep moving forward',
          zhHans: '比如想学的东西、想写清楚的内容、想变好的部分，或者一直在努力推进的方向',
          zhHant: '比如想學的東西、想寫清楚的內容、想變好的部分，或者一直在努力推進的方向',
          ja: '学びたいこと、言葉にしたいこと、伸ばしたい部分、少しずつ進めたい方向',
        ),
      ),
      _FocusAreaOption(
        value: 'open',
        title: AppLocaleText.tr(
          context,
          en: 'Keep it open for now',
          zhHans: '先不限定，想到什么记什么',
          zhHant: '先不限定，想到什麼記什麼',
          ja: 'まだ決めず、思いついたことから記録する',
        ),
        subtitle: AppLocaleText.tr(
          context,
          en: 'Capture what really happens first, and sort the direction out later',
          zhHans: '先把真实发生的事情留下来，之后再慢慢看它更接近哪些方向',
          zhHant: '先把真實發生的事情留下來，之後再慢慢看它更接近哪些方向',
          ja: 'まずは実際に起きたことを残して、方向はあとから少しずつ見ていく',
        ),
      ),
    ];
  }
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
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.28),
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

class _FocusAreaOption {
  final String value;
  final String title;
  final String subtitle;

  const _FocusAreaOption({
    required this.value,
    required this.title,
    required this.subtitle,
  });
}
