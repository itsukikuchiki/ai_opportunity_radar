import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/i18n/app_locale_text.dart';
import '../../../shared/widgets/section_header.dart';
import 'me_view_model.dart';

class MePage extends StatelessWidget {
  const MePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vm = context.watch<MeViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocaleText.tr(
            context,
            en: 'Me',
            zhHans: 'Me',
            zhHant: 'Me',
            ja: 'Me',
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
            Text(
              AppLocaleText.tr(
                context,
                en: 'Me',
                zhHans: 'Me',
                zhHant: 'Me',
                ja: 'Me',
              ),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              AppLocaleText.tr(
                context,
                en: 'This is where your preferences and personal settings come together.',
                zhHans: '这里会慢慢收纳你的偏好设置和个人选项。',
                zhHant: '這裡會慢慢收納你的偏好設定和個人選項。',
                ja: 'ここに、設定や個人の好みが少しずつまとまっていきます。',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            SectionHeader(
              title: AppLocaleText.tr(
                context,
                en: 'Preferences',
                zhHans: '偏好设置',
                zhHant: '偏好設定',
                ja: '好みの設定',
              ),
              subtitle: AppLocaleText.tr(
                context,
                en: 'These settings are not fixed forever. You can adjust them later anytime.',
                zhHans: '这些设置不会把你固定住，之后随时都可以调整。',
                zhHant: '這些設定不會把你固定住，之後隨時都可以調整。',
                ja: 'これらの設定は固定ではなく、あとからいつでも変えられます。',
              ),
            ),
            const SizedBox(height: 10),
            if (vm.loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              _EditablePreferenceCard(
                icon: Icons.tune_rounded,
                title: AppLocaleText.tr(
                  context,
                  en: 'Focus area',
                  zhHans: '关注方向',
                  zhHant: '關注方向',
                  ja: '注目方向',
                ),
                subtitle: AppLocaleText.tr(
                  context,
                  en: 'What you want the system to notice first',
                  zhHans: '你更希望系统先留意哪些方面',
                  zhHant: '你更希望系統先留意哪些方面',
                  ja: 'システムにまず見てほしい方向',
                ),
                value: _focusAreaLabel(context, vm.selectedRepeatArea),
                helper: _focusAreaBody(context, vm.selectedRepeatArea),
                actionLabel: AppLocaleText.tr(
                  context,
                  en: 'Change',
                  zhHans: '修改',
                  zhHant: '修改',
                  ja: '変更',
                ),
                onTap: vm.saving ? null : () => _showFocusAreaSheet(context, vm),
                isBusy: vm.saving,
              ),
              const SizedBox(height: 12),
              _ReadonlyPreferenceCard(
                icon: Icons.language_rounded,
                title: AppLocaleText.tr(
                  context,
                  en: 'Language',
                  zhHans: '语言',
                  zhHant: '語言',
                  ja: '言語',
                ),
                subtitle: AppLocaleText.tr(
                  context,
                  en: 'The app follows your system language by default',
                  zhHans: 'App 默认跟随系统语言',
                  zhHant: 'App 預設跟隨系統語言',
                  ja: 'アプリは基本的にシステム言語に合わせます',
                ),
                value: _languageLabel(context),
                helper: AppLocaleText.tr(
                  context,
                  en: 'English is used when the system language is not supported.',
                  zhHans: '当系统语言不在支持范围内时，会回退到英文。',
                  zhHant: '當系統語言不在支援範圍內時，會回退到英文。',
                  ja: 'システム言語が未対応の場合は英語に戻ります。',
                ),
              ),
            ],
            if (vm.errorMessage != null && vm.errorMessage!.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    vm.errorMessage!,
                    style: TextStyle(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ),
            ],
          ],
      ),
    );
  }

  Future<void> _showFocusAreaSheet(BuildContext context, MeViewModel vm) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return _FocusAreaPickerSheet(
          currentValue: vm.selectedRepeatArea,
        );
      },
    );

    if (selected == null || selected == vm.selectedRepeatArea) return;

    final success = await vm.updateRepeatArea(selected);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? AppLocaleText.tr(
                  context,
                  en: 'Focus area updated.',
                  zhHans: '关注方向已更新。',
                  zhHant: '關注方向已更新。',
                  ja: '注目方向を更新しました。',
                )
              : AppLocaleText.tr(
                  context,
                  en: 'Failed to update focus area.',
                  zhHans: '更新关注方向失败。',
                  zhHant: '更新關注方向失敗。',
                  ja: '注目方向の更新に失敗しました。',
                ),
        ),
      ),
    );
  }

  String _focusAreaLabel(BuildContext context, String? value) {
    switch (value) {
      case 'work_tasks':
        return AppLocaleText.tr(context, en: 'Work and tasks', zhHans: '工作与任务', zhHant: '工作與任務', ja: '仕事とタスク');
      case 'emotion_stress':
        return AppLocaleText.tr(context, en: 'Emotions and stress', zhHans: '情绪与压力', zhHant: '情緒與壓力', ja: '感情とストレス');
      case 'relationships':
        return AppLocaleText.tr(context, en: 'Relationships and interaction', zhHans: '关系与相处', zhHant: '關係與相處', ja: '人間関係と付き合い方');
      case 'time_rhythm':
        return AppLocaleText.tr(context, en: 'Time and daily rhythm', zhHans: '时间与生活节奏', zhHant: '時間與生活節奏', ja: '時間と生活リズム');
      case 'health_body':
        return AppLocaleText.tr(context, en: 'Health and physical state', zhHans: '健康与身体状态', zhHant: '健康與身體狀態', ja: '健康と身体の状態');
      case 'money_spending':
        return AppLocaleText.tr(context, en: 'Money and spending', zhHans: '金钱与消费', zhHant: '金錢與消費', ja: 'お金と消費');
      case 'learning_growth_expression':
        return AppLocaleText.tr(context, en: 'Learning, growth, and expression', zhHans: '学习、成长与表达', zhHant: '學習、成長與表達', ja: '学び・成長・表現');
      case 'open':
        return AppLocaleText.tr(context, en: 'Keep it open for now', zhHans: '先不限定，想到什么记什么', zhHant: '先不限定，想到什麼記什麼', ja: 'まだ決めず、思いついたことから記録する');
      default:
        return AppLocaleText.tr(context, en: 'Not selected yet', zhHans: '还没有选定', zhHant: '還沒有選定', ja: 'まだ選ばれていません');
    }
  }

  String _focusAreaBody(BuildContext context, String? value) {
    switch (value) {
      case 'work_tasks':
        return AppLocaleText.tr(
          context,
          en: 'Progress, priorities, collaboration, communication, and repeated draining workflows.',
          zhHans: '比如推进事情、安排优先级、合作沟通、反复消耗你的流程。',
          zhHant: '比如推進事情、安排優先級、合作溝通、反覆消耗你的流程。',
          ja: '物事の進め方、優先順位、協働や連絡、繰り返し消耗する流れ。',
        );
      case 'emotion_stress':
        return AppLocaleText.tr(
          context,
          en: 'Moments of frustration, hurt, joy, tension, or feelings that linger.',
          zhHans: '比如烦躁、委屈、开心、紧绷，或者总放不下的时刻。',
          zhHant: '比如煩躁、委屈、開心、緊繃，或者總放不下的時刻。',
          ja: 'イライラ、しんどさ、うれしさ、張りつめた感じ、引きずる瞬間。',
        );
      case 'relationships':
        return AppLocaleText.tr(
          context,
          en: 'Family, friends, coworkers, partners, friction, and what matters to you.',
          zhHans: '比如和家人、朋友、同事、伴侣之间的互动、摩擦和在意。',
          zhHant: '比如和家人、朋友、同事、伴侶之間的互動、摩擦和在意。',
          ja: '家族、友人、同僚、パートナーとのやり取り、摩擦、気になること。',
        );
      case 'time_rhythm':
        return AppLocaleText.tr(
          context,
          en: 'Commutes, routines, procrastination, rest, and where your day gets interrupted.',
          zhHans: '比如通勤、作息、拖延、休息不够，或者一天总被打断的地方。',
          zhHant: '比如通勤、作息、拖延、休息不夠，或者一天總被打斷的地方。',
          ja: '通勤、生活リズム、先延ばし、休めなさ、一日の中で何度も途切れること。',
        );
      case 'health_body':
        return AppLocaleText.tr(
          context,
          en: 'Fatigue, sleep, food, exercise, recovery, and body signals.',
          zhHans: '比如疲惫、睡眠、饮食、运动、恢复感，或者身体给你的提醒。',
          zhHant: '比如疲憊、睡眠、飲食、運動、恢復感，或者身體給你的提醒。',
          ja: '疲れ、睡眠、食事、運動、回復感、身体からのサイン。',
        );
      case 'money_spending':
        return AppLocaleText.tr(
          context,
          en: 'Spending, habits, pressure, budgeting, and hesitant purchases.',
          zhHans: '比如花销、消费习惯、金钱压力、预算安排，或者总让你犹豫的支出。',
          zhHant: '比如花銷、消費習慣、金錢壓力、預算安排，或者總讓你猶豫的支出。',
          ja: '支出、買い方の癖、お金のプレッシャー、予算、迷いやすい出費。',
        );
      case 'learning_growth_expression':
        return AppLocaleText.tr(
          context,
          en: 'Things you want to learn, express clearly, improve, or keep moving forward.',
          zhHans: '比如想学的东西、想写清楚的内容、想变好的部分，或者一直在努力推进的方向。',
          zhHant: '比如想學的東西、想寫清楚的內容、想變好的部分，或者一直在努力推進的方向。',
          ja: '学びたいこと、言葉にしたいこと、伸ばしたい部分、少しずつ進めたい方向。',
        );
      case 'open':
        return AppLocaleText.tr(
          context,
          en: 'Capture what really happens first, and sort the direction out later.',
          zhHans: '先把真实发生的事情留下来，之后再慢慢看它更接近哪些方向。',
          zhHant: '先把真實發生的事情留下來，之後再慢慢看它更接近哪些方向。',
          ja: 'まずは実際に起きたことを残して、方向はあとから少しずつ見ていく。',
        );
      default:
        return AppLocaleText.tr(
          context,
          en: 'No focus area has been saved yet.',
          zhHans: '目前还没有保存关注方向。',
          zhHant: '目前還沒有儲存關注方向。',
          ja: 'まだ注目方向は保存されていません。',
        );
    }
  }

  String _languageLabel(BuildContext context) {
    switch (AppLocaleText.resolve(context)) {
      case AppLanguage.english:
        return 'English';
      case AppLanguage.simplifiedChinese:
        return '简体中文';
      case AppLanguage.traditionalChinese:
        return '繁體中文';
      case AppLanguage.japanese:
        return '日本語';
    }
  }
}

class _EditablePreferenceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final String helper;
  final String actionLabel;
  final VoidCallback? onTap;
  final bool isBusy;

  const _EditablePreferenceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.helper,
    required this.actionLabel,
    required this.onTap,
    required this.isBusy,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    value,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 10),
                Text(helper),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: isBusy ? null : onTap,
                    icon: isBusy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.edit_outlined),
                    label: Text(actionLabel),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadonlyPreferenceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final String helper;

  const _ReadonlyPreferenceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.helper,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    value,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 10),
                Text(helper),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusAreaPickerSheet extends StatelessWidget {
  final String? currentValue;

  const _FocusAreaPickerSheet({
    required this.currentValue,
  });

  @override
  Widget build(BuildContext context) {
    final options = <_FocusAreaOption>[
      _FocusAreaOption(
        value: 'work_tasks',
        title: AppLocaleText.tr(context, en: 'Work and tasks', zhHans: '工作与任务', zhHant: '工作與任務', ja: '仕事とタスク'),
        subtitle: AppLocaleText.tr(context, en: 'Progress, priorities, collaboration, communication, and repeated workflows', zhHans: '推进事情、安排优先级、合作沟通、反复消耗你的流程', zhHant: '推進事情、安排優先級、合作溝通、反覆消耗你的流程', ja: '物事の進め方、優先順位、協働や連絡、繰り返し消耗する流れ'),
      ),
      _FocusAreaOption(
        value: 'emotion_stress',
        title: AppLocaleText.tr(context, en: 'Emotions and stress', zhHans: '情绪与压力', zhHant: '情緒與壓力', ja: '感情とストレス'),
        subtitle: AppLocaleText.tr(context, en: 'Frustration, hurt, joy, tension, and lingering feelings', zhHans: '烦躁、委屈、开心、紧绷，或者总放不下的时刻', zhHant: '煩躁、委屈、開心、緊繃，或者總放不下的時刻', ja: 'イライラ、しんどさ、うれしさ、張りつめた感じ、引きずる瞬間'),
      ),
      _FocusAreaOption(
        value: 'relationships',
        title: AppLocaleText.tr(context, en: 'Relationships and interaction', zhHans: '关系与相处', zhHant: '關係與相處', ja: '人間関係と付き合い方'),
        subtitle: AppLocaleText.tr(context, en: 'Family, friends, coworkers, partners, friction, and what matters to you', zhHans: '家人、朋友、同事、伴侣之间的互动、摩擦和在意', zhHant: '家人、朋友、同事、伴侶之間的互動、摩擦和在意', ja: '家族、友人、同僚、パートナーとのやり取り、摩擦、気になること'),
      ),
      _FocusAreaOption(
        value: 'time_rhythm',
        title: AppLocaleText.tr(context, en: 'Time and daily rhythm', zhHans: '时间与生活节奏', zhHant: '時間與生活節奏', ja: '時間と生活リズム'),
        subtitle: AppLocaleText.tr(context, en: 'Commutes, routines, procrastination, rest, and interruptions', zhHans: '通勤、作息、拖延、休息不够，或者一天总被打断的地方', zhHant: '通勤、作息、拖延、休息不夠，或者一天總被打斷的地方', ja: '通勤、生活リズム、先延ばし、休めなさ、中断される場面'),
      ),
      _FocusAreaOption(
        value: 'health_body',
        title: AppLocaleText.tr(context, en: 'Health and physical state', zhHans: '健康与身体状态', zhHant: '健康與身體狀態', ja: '健康と身体の状態'),
        subtitle: AppLocaleText.tr(context, en: 'Fatigue, sleep, food, exercise, recovery, and body signals', zhHans: '疲惫、睡眠、饮食、运动、恢复感，或者身体给你的提醒', zhHant: '疲憊、睡眠、飲食、運動、恢復感，或者身體給你的提醒', ja: '疲れ、睡眠、食事、運動、回復感、身体からのサイン'),
      ),
      _FocusAreaOption(
        value: 'money_spending',
        title: AppLocaleText.tr(context, en: 'Money and spending', zhHans: '金钱与消费', zhHant: '金錢與消費', ja: 'お金と消費'),
        subtitle: AppLocaleText.tr(context, en: 'Spending, habits, pressure, budgeting, and hesitant purchases', zhHans: '花销、消费习惯、金钱压力、预算安排，或者总让你犹豫的支出', zhHant: '花銷、消費習慣、金錢壓力、預算安排，或者總讓你猶豫的支出', ja: '支出、買い方の癖、お金のプレッシャー、予算、迷いやすい出費'),
      ),
      _FocusAreaOption(
        value: 'learning_growth_expression',
        title: AppLocaleText.tr(context, en: 'Learning, growth, and expression', zhHans: '学习、成长与表达', zhHant: '學習、成長與表達', ja: '学び・成長・表現'),
        subtitle: AppLocaleText.tr(context, en: 'Things you want to learn, express clearly, improve, or keep moving forward', zhHans: '想学的东西、想写清楚的内容、想变好的部分，或者一直在努力推进的方向', zhHant: '想學的東西、想寫清楚的內容、想變好的部分，或者一直在努力推進的方向', ja: '学びたいこと、言葉にしたいこと、伸ばしたい部分、少しずつ進めたい方向'),
      ),
      _FocusAreaOption(
        value: 'open',
        title: AppLocaleText.tr(context, en: 'Keep it open for now', zhHans: '先不限定，想到什么记什么', zhHant: '先不限定，想到什麼記什麼', ja: 'まだ決めず、思いついたことから記録する'),
        subtitle: AppLocaleText.tr(context, en: 'Capture what really happens first, and sort the direction out later', zhHans: '先把真实发生的事情留下来，之后再慢慢看它更接近哪些方向', zhHant: '先把真實發生的事情留下來，之後再慢慢看它更接近哪些方向', ja: 'まずは実際に起きたことを残して、方向はあとから少しずつ見ていく'),
      ),
    ];

    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppLocaleText.tr(
                context,
                en: 'Change focus area',
                zhHans: '修改关注方向',
                zhHant: '修改關注方向',
                ja: '注目方向を変更する',
              ),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocaleText.tr(
                context,
                en: 'Pick the one that feels closest to where you want the system to start noticing first.',
                zhHans: '选一个现在最接近你、也最希望系统先开始留意的方向。',
                zhHant: '選一個現在最接近你、也最希望系統先開始留意的方向。',
                ja: '今の自分に近く、システムにまず見てほしい方向を一つ選んでください。',
              ),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final option = options[index];
                  final selected = option.value == currentValue;

                  return InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => Navigator.of(context).pop(option.value),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: selected
                            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.65)
                            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.26),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: selected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
                          width: selected ? 1.6 : 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            selected ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: selected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  option.title,
                                  style: theme.textTheme.titleSmall?.copyWith(
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
