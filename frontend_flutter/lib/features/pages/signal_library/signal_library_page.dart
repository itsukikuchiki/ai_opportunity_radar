import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/i18n/app_locale_text.dart';
import '../../../core/models/signal_library_models.dart';
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
      appBar: AppBar(
        title: Text(
          AppLocaleText.tr(
            context,
            en: 'Signal Library',
            zhHans: '信号库',
            zhHant: '信號庫',
            ja: 'シグナルライブラリ',
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            AppLocaleText.tr(
              context,
              en: 'Officially organized life patterns, not community content. No user stories or raw notes are shown here.',
              zhHans: '这里只展示官方整理的生活模式，不是社区内容，也不展示用户故事或原始记录。',
              zhHant: '这里只展示官方整理的生活模式，不是社群內容，也不展示使用者故事或原始記錄。',
              ja: 'ここでは公式に整理した生活パターンだけを表示します。コミュニティ内容ではなく、ユーザーの物語や原文は表示しません。',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
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
            ...viewModel.patterns.map(
              (pattern) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PatternCard(
                  pattern: pattern,
                  saved: viewModel.savedPatternIds.contains(pattern.id),
                  acted: viewModel.privateActionPatternIds.contains(pattern.id),
                  onAlsoHaveThis: () => viewModel.markAlsoHaveThis(pattern),
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
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocaleText.tr(
                context,
                en: 'Share preview',
                zhHans: '分享预览',
                zhHant: '分享預覽',
                ja: '共有プレビュー',
              ),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: PatternIllustration(patternId: pattern.id),
                    ),
                    Text(pattern.title,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(pattern.abstractPattern),
                    const SizedBox(height: 12),
                    Text(
                      'Signal Path',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              AppLocaleText.tr(
                context,
                en: 'Only this official abstract pattern is copied. Your notes and private actions are not included.',
                zhHans: '只会复制这条官方抽象模式，不包含你的记录或私密操作。',
                zhHant: '只會複製這條官方抽象模式，不包含你的記錄或私密操作。',
                ja: '公式の抽象パターンだけをコピーします。あなたの記録や非公開操作は含まれません。',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
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
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child:
                      Text(pattern.title, style: theme.textTheme.titleMedium),
                ),
                const SizedBox(width: 10),
                PatternIllustration(patternId: pattern.id),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              AppLocaleText.tr(
                context,
                en: 'Some people meet a similar structure.',
                zhHans: '有些人会遇到类似结构。',
                zhHant: '有些人會遇到類似結構。',
                ja: '似た構造に出会う人もいます。',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              pattern.abstractPattern,
              style: theme.textTheme.bodyMedium,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...pattern.commonScenes.map((scene) => _SoftChip(text: scene)),
                ...pattern.commonFrictions.map(
                  (friction) => _SoftChip(text: friction),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              AppLocaleText.tr(
                context,
                en: 'Gentle reflection',
                zhHans: '可以观察',
                zhHant: '可以觀察',
                ja: '軽く見るところ',
              ),
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(
              pattern.gentleReflection,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              AppLocaleText.tr(
                context,
                en: 'Small experiment',
                zhHans: '小实验',
                zhHant: '小實驗',
                ja: '小さな実験',
              ),
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(
              pattern.suggestedSmallExperiment,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onAlsoHaveThis,
                  icon: Icon(acted ? Icons.lock_outline : Icons.add),
                  label: Text(
                    AppLocaleText.tr(
                      context,
                      en: 'I also have this',
                      zhHans: '我也有类似结构',
                      zhHant: '我也有類似結構',
                      ja: '似た構造がある',
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: saved ? null : onSave,
                  icon: Icon(saved ? Icons.check : Icons.bookmark_add_outlined),
                  label: Text(
                    saved
                        ? AppLocaleText.tr(
                            context,
                            en: 'In observations',
                            zhHans: '已放进观察',
                            zhHant: '已放進觀察',
                            ja: '観察に保存済み',
                          )
                        : AppLocaleText.tr(
                            context,
                            en: 'Save to my observation',
                            zhHans: '先放进你的观察里',
                            zhHant: '先放進你的觀察裡',
                            ja: '自分の観察に入れる',
                          ),
                  ),
                ),
                TextButton(
                  onPressed: onNotForMe,
                  child: Text(
                    AppLocaleText.tr(
                      context,
                      en: 'Not for me',
                      zhHans: '暂时不像我',
                      zhHant: '暫時不像我',
                      ja: '今は違う',
                    ),
                  ),
                ),
                IconButton.outlined(
                  onPressed: onShare,
                  icon: const Icon(Icons.ios_share_outlined),
                  tooltip: AppLocaleText.tr(
                    context,
                    en: 'Share official pattern only',
                    zhHans: '仅分享官方整理内容',
                    zhHant: '僅分享官方整理內容',
                    ja: '公式に整理した内容だけを共有',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SoftChip extends StatelessWidget {
  final String text;

  const _SoftChip({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: theme.textTheme.labelSmall),
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
