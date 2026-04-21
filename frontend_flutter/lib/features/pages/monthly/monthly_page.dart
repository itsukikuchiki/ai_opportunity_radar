import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/i18n/app_locale_text.dart';
import '../../../core/models/monthly_models.dart';
import '../../../shared/states/load_state.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/empty_state_block.dart';
import '../../../shared/widgets/section_header.dart';
import '../me/me_view_model.dart';
import 'monthly_view_model.dart';

class MonthlyPage extends StatelessWidget {
  const MonthlyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MonthlyViewModel>();
    final meVm = context.watch<MeViewModel>();
    final monthly = vm.monthly;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocaleText.tr(
            context,
            en: 'Monthly',
            zhHans: 'Monthly',
            zhHant: 'Monthly',
            ja: 'Monthly',
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          AppHeader(
            title: AppLocaleText.tr(
              context,
              en: 'Monthly',
              zhHans: 'Monthly',
              zhHant: 'Monthly',
              ja: 'Monthly',
            ),
            subtitle:
                monthly == null ? null : '${monthly.monthStart} → ${monthly.monthEnd}',
            summary: monthly?.monthlySummary ??
                AppLocaleText.tr(
                  context,
                  en: 'A slower review of what this month has been circling around.',
                  zhHans: '用更慢一点的视角，看这个月反复在围绕什么。',
                  zhHant: '用更慢一點的視角，看這個月反覆在圍繞什麼。',
                  ja: '少しゆっくりした視点で、この一か月が何の周りを回っていたかを見ます。',
                ),
            preferenceText: _preferenceText(context, meVm.selectedRepeatArea),
          ),
          const SizedBox(height: 12),
          ..._buildBody(context, vm, monthly),
        ],
      ),
    );
  }

  List<Widget> _buildBody(
    BuildContext context,
    MonthlyViewModel vm,
    MonthlyReviewModel? monthly,
  ) {
    switch (vm.loadState) {
      case LoadState.loading:
        return const [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 56),
            child: Center(child: CircularProgressIndicator()),
          ),
        ];

      case LoadState.error:
        return [
          Column(
            children: [
              EmptyStateBlock(
                icon: Icons.error_outline,
                title: AppLocaleText.tr(
                  context,
                  en: 'Monthly review failed to load',
                  zhHans: 'Monthly 载入失败',
                  zhHant: 'Monthly 載入失敗',
                  ja: 'Monthly の読み込みに失敗しました',
                ),
                subtitle: vm.errorMessage ??
                    AppLocaleText.tr(
                      context,
                      en: 'Please try again later.',
                      zhHans: '请稍后重试。',
                      zhHant: '請稍後重試。',
                      ja: 'しばらくしてから、もう一度試してください。',
                    ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: vm.retry,
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Retry',
                    zhHans: '重试',
                    zhHant: '重試',
                    ja: '再試行',
                  ),
                ),
              ),
            ],
          ),
        ];

      case LoadState.empty:
        return [
          vm.showFirstMonthGate
              ? EmptyStateBlock(
                  icon: Icons.calendar_month_outlined,
                  title: AppLocaleText.tr(
                    context,
                    en: 'Monthly starts after your first month has begun',
                    zhHans: 'Monthly 会在你开始进入第一个月后再出现',
                    zhHant: 'Monthly 會在你開始進入第一個月後再出現',
                    ja: 'Monthly は最初の月が動き始めてから表示されます',
                  ),
                  subtitle: AppLocaleText.tr(
                    context,
                    en: 'Keep a few entries first. Once the month has some texture, the longer review becomes much more useful.',
                    zhHans: '先继续记几条，等这个月稍微有点纹理之后，月度回看才会更有意义。',
                    zhHant: '先繼續記幾條，等這個月稍微有點紋理之後，月度回看才會更有意義。',
                    ja: 'もう少し記録がたまると、月単位の振り返りがずっと役立ちます。',
                  ),
                )
              : EmptyStateBlock(
                  icon: Icons.calendar_month_outlined,
                  title: AppLocaleText.tr(
                    context,
                    en: 'Not enough monthly data yet',
                    zhHans: '这个月的数据还不够',
                    zhHant: '這個月的資料還不夠',
                    ja: '今月のデータはまだ足りません',
                  ),
                  subtitle: AppLocaleText.tr(
                    context,
                    en: 'A few more entries will make the month-level review clearer.',
                    zhHans: '再多几条记录，月度回看会更清楚。',
                    zhHant: '再多幾條記錄，月度回看會更清楚。',
                    ja: 'もう少し記録があると、月単位の見え方がはっきりします。',
                  ),
                ),
        ];

      case LoadState.ready:
        if (monthly == null) {
          return const [SizedBox.shrink()];
        }

        return [
          _StringSection(
            title: AppLocaleText.tr(
              context,
              en: 'Monthly summary',
              zhHans: '月度总结',
              zhHant: '月度總結',
              ja: '月のまとめ',
            ),
            items: [monthly.monthlySummary ?? ''],
          ),
          const SizedBox(height: 16),
          _StringSection(
            title: AppLocaleText.tr(
              context,
              en: 'Repeated themes',
              zhHans: '反复主题',
              zhHant: '反覆主題',
              ja: '繰り返し出たテーマ',
            ),
            items: monthly.repeatedThemes,
          ),
          const SizedBox(height: 16),
          _StringSection(
            title: AppLocaleText.tr(
              context,
              en: 'Improving signals',
              zhHans: '正在改善的线索',
              zhHant: '正在改善的線索',
              ja: '少しずつ良くなっている手がかり',
            ),
            items: monthly.improvingSignals,
          ),
          const SizedBox(height: 16),
          _StringSection(
            title: AppLocaleText.tr(
              context,
              en: 'Unresolved points',
              zhHans: '还没解决的点',
              zhHant: '還沒解決的點',
              ja: 'まだ残っている点',
            ),
            items: monthly.unresolvedPoints,
          ),
          const SizedBox(height: 16),
          _StringSection(
            title: AppLocaleText.tr(
              context,
              en: 'Next month watch',
              zhHans: '下个月继续看什么',
              zhHant: '下個月繼續看什麼',
              ja: '来月も見ておきたいこと',
            ),
            items: [monthly.nextMonthWatch ?? ''],
          ),
          const SizedBox(height: 16),
          SectionHeader(
            title: AppLocaleText.tr(
              context,
              en: 'Weekly bridges',
              zhHans: '按周连接起来看',
              zhHant: '按週連接起來看',
              ja: '週ごとの橋渡し',
            ),
            subtitle: AppLocaleText.tr(
              context,
              en: 'This helps you see how the month shifted from week to week.',
              zhHans: '把每周接起来看，更容易看见这个月是怎么变的。',
              zhHant: '把每週接起來看，更容易看見這個月是怎麼變的。',
              ja: '週ごとにつなげて見ると、月の流れが見えやすくなります。',
            ),
          ),
          const SizedBox(height: 12),
          ...monthly.weeklyBridges.map<Widget>(
            (item) => Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(item.summary),
                  ],
                ),
              ),
            ),
          ),
        ];

      case LoadState.initial:
        return const [SizedBox.shrink()];
    }
  }

  String _preferenceText(BuildContext context, String? value) {
    final focusLabel = _focusAreaLabel(context, value);
    return AppLocaleText.tr(
      context,
      en: 'Focus this month: $focusLabel',
      zhHans: '本月关注：$focusLabel',
      zhHant: '本月關注：$focusLabel',
      ja: '今月の注目：$focusLabel',
    );
  }

  String _focusAreaLabel(BuildContext context, String? value) {
    switch (value) {
      case 'work_tasks':
        return AppLocaleText.tr(
          context,
          en: 'work and tasks',
          zhHans: '工作与任务',
          zhHant: '工作與任務',
          ja: '仕事とタスク',
        );
      case 'emotion_stress':
        return AppLocaleText.tr(
          context,
          en: 'emotions and stress',
          zhHans: '情绪与压力',
          zhHant: '情緒與壓力',
          ja: '感情とストレス',
        );
      case 'relationships':
        return AppLocaleText.tr(
          context,
          en: 'relationships and interaction',
          zhHans: '关系与相处',
          zhHant: '關係與相處',
          ja: '人間関係と付き合い方',
        );
      case 'time_rhythm':
        return AppLocaleText.tr(
          context,
          en: 'time and daily rhythm',
          zhHans: '时间与生活节奏',
          zhHant: '時間與生活節奏',
          ja: '時間と生活リズム',
        );
      case 'health_body':
        return AppLocaleText.tr(
          context,
          en: 'health and physical state',
          zhHans: '健康与身体状态',
          zhHant: '健康與身體狀態',
          ja: '健康と身体の状態',
        );
      case 'money_spending':
        return AppLocaleText.tr(
          context,
          en: 'money and spending',
          zhHans: '金钱与消费',
          zhHant: '金錢與消費',
          ja: 'お金と消費',
        );
      case 'learning_growth_expression':
        return AppLocaleText.tr(
          context,
          en: 'learning, growth, and expression',
          zhHans: '学习、成长与表达',
          zhHant: '學習、成長與表達',
          ja: '学び・成長・表現',
        );
      case 'open':
        return AppLocaleText.tr(
          context,
          en: 'whatever comes up',
          zhHans: '想到什么记什么',
          zhHant: '想到什麼記什麼',
          ja: '思いついたことから記録する',
        );
      default:
        return AppLocaleText.tr(
          context,
          en: 'not set yet',
          zhHans: '暂未设置',
          zhHant: '暫未設定',
          ja: '未設定',
        );
    }
  }
}

class _StringSection extends StatelessWidget {
  final String title;
  final List<String> items;

  const _StringSection({
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final filteredItems = items.where((e) => e.trim().isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title),
        const SizedBox(height: 12),
        if (filteredItems.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                AppLocaleText.tr(
                  context,
                  en: 'Nothing clear enough to show here yet.',
                  zhHans: '这里暂时还没有足够清晰的内容。',
                  zhHant: '這裡暫時還沒有足夠清晰的內容。',
                  ja: 'ここにはまだ十分はっきりした内容がありません。',
                ),
              ),
            ),
          )
        else
          ...filteredItems.map(
            (item) => Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(item),
              ),
            ),
          ),
      ],
    );
  }
}
