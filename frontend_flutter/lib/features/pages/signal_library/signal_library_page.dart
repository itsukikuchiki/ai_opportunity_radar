import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/i18n/app_locale_text.dart';
import '../../../core/models/signal_library_models.dart';
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

    return Scaffold(
      body: Stack(
        children: [
          AuroraPage(
            child: SafeArea(
              bottom: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 116),
                children: [
                  Text(
                    AppLocaleText.tr(
                      context,
                      en: 'Shared life signals',
                      zhHans: '共有生活信号',
                      zhHant: '共有生活信號',
                      ja: '共有される生活シグナル',
                    ),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 21,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _LibraryCategoryRow(
                    selectedCategory: viewModel.selectedCategory,
                    onSelected: viewModel.selectCategory,
                  ),
                  const SizedBox(height: 14),
                  AuroraQuoteCard(
                    landscape: true,
                    minHeight: 80,
                    text: AppLocaleText.tr(
                      context,
                      en: 'Other people have similar signals too. You are not alone.',
                      zhHans: '别人也有同样的信号，你不是一个人。',
                      zhHant: '別人也有同樣的信號，你不是一個人。',
                      ja: '似たシグナルを持つ人はほかにもいます。あなた一人ではありません。',
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (viewModel.message != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _SoftNotice(text: viewModel.message!),
                    ),
                  if (viewModel.loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else
                    ...viewModel.visiblePatterns.map(
                      (pattern) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _PatternCard(
                          pattern: pattern,
                          saved: viewModel.savedPatternIds.contains(pattern.id),
                          acted: viewModel.privateActionPatternIds
                              .contains(pattern.id),
                          onAlsoHaveThis: () => _showLibraryActionLoop(
                              context, pattern, viewModel),
                          onSave: () => viewModel.saveToMyObservation(pattern),
                          onNotForMe: () => viewModel.markNotForMe(pattern),
                          onShare: () async {
                            await Clipboard.setData(
                              ClipboardData(
                                text:
                                    '${pattern.title}\n\n${pattern.abstractPattern}\n\n${pattern.suggestedSmallExperiment}',
                              ),
                            );
                            viewModel.markSharePrepared(pattern);
                            if (!context.mounted) return;
                            _showSharePreview(context, pattern);
                          },
                        ),
                      ),
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

  void _showSharePreview(
    BuildContext context,
    LibraryPatternModel pattern,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
          boxShadow: [
            BoxShadow(
              color: AuroraColors.purple.withValues(alpha: 0.18),
              blurRadius: 36,
              offset: const Offset(0, -12),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AuroraColors.line,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Create share card',
                    zhHans: '生成分享卡片',
                    zhHant: '生成分享卡片',
                    ja: '共有カードを作成',
                  ),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AuroraColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 5),
                Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Only the official abstract pattern is included.',
                    zhHans: '只包含官方抽象模式，不包含你的私人记录。',
                    zhHant: '只包含官方抽象模式，不包含你的私人記錄。',
                    ja: '公式の抽象パターンだけが含まれます。',
                  ),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AuroraColors.muted),
                ),
                const SizedBox(height: 16),
                AuroraCard(
                  padding: const EdgeInsets.all(22),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFF7F3FF),
                      Color(0xFFFFFCF6),
                      Color(0xFFF4F8FF),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const AuroraBrandMark(size: 28),
                          const SizedBox(width: 8),
                          Text(
                            AppLocaleText.tr(
                              context,
                              en: 'Time signal',
                              zhHans: '时光信号',
                              zhHant: '時光信號',
                              ja: '時のシグナル',
                            ),
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  color: AuroraColors.ink,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '“',
                                  style: Theme.of(context)
                                      .textTheme
                                      .displaySmall
                                      ?.copyWith(
                                        color: AuroraColors.purple
                                            .withValues(alpha: 0.45),
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                                Text(
                                  pattern.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        color: AuroraColors.ink,
                                        fontWeight: FontWeight.w800,
                                        height: 1.15,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  pattern.abstractPattern,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: AuroraColors.ink,
                                        height: 1.55,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          SizedBox(
                            width: 92,
                            child: PatternIllustration(patternId: pattern.id),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          AuroraChip(
                            label: AppLocaleText.tr(
                              context,
                              en: 'Recorded from Signal Library',
                              zhHans: '记录于信号库',
                              zhHant: '記錄於信號庫',
                              ja: 'シグナルライブラリより',
                            ),
                            color: AuroraColors.purple,
                          ),
                          const Spacer(),
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.qr_code_2_rounded,
                              color: AuroraColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AuroraPillButton(
                  label: AppLocaleText.tr(
                    context,
                    en: 'Generate card',
                    zhHans: '生成卡片',
                    zhHant: '生成卡片',
                    ja: 'カードを作成',
                  ),
                  icon: Icons.auto_awesome_rounded,
                  filled: true,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLibraryActionLoop(
    BuildContext context,
    LibraryPatternModel pattern,
    SignalLibraryViewModel viewModel,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
          boxShadow: [
            BoxShadow(
              color: AuroraColors.purple.withValues(alpha: 0.18),
              blurRadius: 36,
              offset: const Offset(0, -12),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AuroraColors.line,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    const AuroraSoftIconCircle(
                      icon: Icons.auto_awesome_rounded,
                      color: AuroraColors.purple,
                      size: 42,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppLocaleText.tr(
                          context,
                          en: 'Does this signal feel close to you?',
                          zhHans: '这条信号像不像你最近的情况？',
                          zhHant: '這條信號像不像你最近的情況？',
                          ja: 'このシグナルは最近のあなたに近いですか？',
                        ),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AuroraColors.ink,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  pattern.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AuroraColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  pattern.abstractPattern,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AuroraColors.muted,
                        height: 1.5,
                      ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _LibraryLoopChip(
                      label: AppLocaleText.tr(
                        context,
                        en: 'Looks right',
                        zhHans: '准',
                        zhHant: '準',
                        ja: '近い',
                      ),
                    ),
                    _LibraryLoopChip(
                      label: AppLocaleText.tr(
                        context,
                        en: 'A little',
                        zhHans: '有一点',
                        zhHant: '有一點',
                        ja: '少し',
                      ),
                    ),
                    _LibraryLoopChip(
                      label: AppLocaleText.tr(
                        context,
                        en: 'Not for me',
                        zhHans: '不像',
                        zhHant: '不像',
                        ja: '違う',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                AuroraCard(
                  padding: const EdgeInsets.all(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFFCF5), Color(0xFFF7F3FF)],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AuroraSoftIconCircle(
                        icon: Icons.science_rounded,
                        color: AuroraColors.orange,
                        size: 38,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          AppLocaleText.tr(
                                context,
                                en: 'Small action: ',
                                zhHans: '可以试一个小行动：',
                                zhHant: '可以試一個小行動：',
                                ja: '小さな行動：',
                              ) +
                              pattern.suggestedSmallExperiment,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AuroraColors.ink,
                                    height: 1.45,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: AuroraPillButton(
                        icon: Icons.add_task_rounded,
                        label: AppLocaleText.tr(
                          context,
                          en: 'Try today',
                          zhHans: '加入今日小行动',
                          zhHant: '加入今日小行動',
                          ja: '今日試す',
                        ),
                        filled: true,
                        onPressed: () {
                          viewModel.markAlsoHaveThis(pattern);
                          Navigator.of(sheetContext).maybePop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(AppLocaleText.tr(
                                context,
                                en: 'Added to your observation.',
                                zhHans: '已加入你的观察。',
                                zhHant: '已加入你的觀察。',
                                ja: 'あなたの観察に追加しました。',
                              )),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AuroraPillButton(
                        icon: Icons.bookmark_add_outlined,
                        label: AppLocaleText.tr(
                          context,
                          en: 'Save',
                          zhHans: '保存观察',
                          zhHant: '保存觀察',
                          ja: '保存',
                        ),
                        onPressed: () {
                          viewModel.saveToMyObservation(pattern);
                          Navigator.of(sheetContext).maybePop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(AppLocaleText.tr(
                                context,
                                en: 'Saved as a private observation.',
                                zhHans: '已保存为个人观察。',
                                zhHant: '已保存為個人觀察。',
                                ja: '個人の観察として保存しました。',
                              )),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                AuroraPillButton(
                  icon: Icons.close_rounded,
                  label: AppLocaleText.tr(
                    context,
                    en: 'Not now',
                    zhHans: '暂时不做',
                    zhHant: '暫時不做',
                    ja: '今はしない',
                  ),
                  onPressed: () {
                    viewModel.markNotForMe(pattern);
                    Navigator.of(sheetContext).maybePop();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LibraryLoopChip extends StatelessWidget {
  final String label;

  const _LibraryLoopChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AuroraColors.purple.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AuroraColors.purple.withValues(alpha: 0.14)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AuroraColors.purple,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
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
        'frequent',
        Icons.star_rounded,
        AppLocaleText.tr(context,
            en: 'Frequent', zhHans: '高频', zhHant: '高頻', ja: '高頻'),
        AuroraColors.purple,
      ),
      (
        'recovery',
        Icons.nights_stay_outlined,
        AppLocaleText.tr(context,
            en: 'Recovery', zhHans: '恢复', zhHant: '恢復', ja: '回復'),
        AuroraColors.mint,
      ),
      (
        'relationships',
        Icons.groups_outlined,
        AppLocaleText.tr(context,
            en: 'Relationships', zhHans: '关系', zhHant: '關係', ja: '関係'),
        AuroraColors.orange,
      ),
      (
        'work',
        Icons.work_outline,
        AppLocaleText.tr(context,
            en: 'Work', zhHans: '工作', zhHant: '工作', ja: '仕事'),
        AuroraColors.blue,
      ),
      (
        'boundary',
        Icons.health_and_safety_outlined,
        AppLocaleText.tr(context,
            en: 'Boundary', zhHans: '边界', zhHant: '邊界', ja: '境界'),
        AuroraColors.purple,
      ),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? color.withValues(alpha: 0.10)
                  : Colors.white.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? color.withValues(alpha: 0.55)
                    : AuroraColors.line,
              ),
              boxShadow: [
                if (selected)
                  BoxShadow(
                    color: color.withValues(alpha: 0.10),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
              ],
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
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
  final bool saved;
  final bool acted;
  final VoidCallback onAlsoHaveThis;
  final VoidCallback onSave;
  final VoidCallback onNotForMe;
  final VoidCallback onShare;

  const _PatternCard({
    required this.pattern,
    required this.saved,
    required this.acted,
    required this.onAlsoHaveThis,
    required this.onSave,
    required this.onNotForMe,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AuroraCard(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 66,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: PatternIllustration(patternId: pattern.id),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pattern.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _PatternLine(
                      label: AppLocaleText.tr(
                        context,
                        en: 'Possible structure',
                        zhHans: '可能结构',
                        zhHant: '可能結構',
                        ja: '構造',
                      ),
                      value: pattern.abstractPattern,
                      color: AuroraColors.orange,
                    ),
                    const SizedBox(height: 4),
                    _PatternLine(
                      label: AppLocaleText.tr(
                        context,
                        en: 'Observe',
                        zhHans: '可以观察',
                        zhHant: '可以觀察',
                        ja: '観察',
                      ),
                      value: pattern.gentleReflection,
                      color: AuroraColors.mint,
                    ),
                    const SizedBox(height: 4),
                    _PatternLine(
                      label: AppLocaleText.tr(
                        context,
                        en: 'Small experiment',
                        zhHans: '小实验',
                        zhHant: '小實驗',
                        ja: '試み',
                      ),
                      value: pattern.suggestedSmallExperiment,
                      color: AuroraColors.purple,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: AuroraPillButton(
                  onPressed: onAlsoHaveThis,
                  icon: acted ? Icons.check_circle_outline : Icons.check,
                  label: AppLocaleText.tr(
                    context,
                    en: 'Me too',
                    zhHans: '我也有',
                    zhHant: '我也有',
                    ja: '私にもある',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AuroraPillButton(
                  onPressed: saved ? null : onSave,
                  filled: true,
                  icon: saved ? Icons.check : Icons.bookmark_add_outlined,
                  label: saved
                      ? AppLocaleText.tr(
                          context,
                          en: 'Saved',
                          zhHans: '已保存',
                          zhHant: '已保存',
                          ja: '保存済み',
                        )
                      : AppLocaleText.tr(
                          context,
                          en: 'Save',
                          zhHans: '保存',
                          zhHant: '保存',
                          ja: '保存',
                        ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AuroraPillButton(
                  onPressed: onShare,
                  icon: Icons.ios_share_outlined,
                  label: AppLocaleText.tr(
                    context,
                    en: 'Share',
                    zhHans: '分享',
                    zhHant: '分享',
                    ja: '共有',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PatternLine extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _PatternLine({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelChip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    final valueText = Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(
        color: AuroraColors.ink,
        height: 1.35,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 220) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                child: labelChip,
              ),
              const SizedBox(height: 4),
              valueText,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(flex: 0, child: labelChip),
            const SizedBox(width: 8),
            Expanded(child: valueText),
          ],
        );
      },
    );
  }
}

class _SoftNotice extends StatelessWidget {
  final String text;

  const _SoftNotice({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(text, style: theme.textTheme.bodySmall),
      ),
    );
  }
}
