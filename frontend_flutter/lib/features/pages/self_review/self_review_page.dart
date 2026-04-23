import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/i18n/app_locale_text.dart';
import '../../../shared/states/load_state.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/empty_state_block.dart';
import '../../../shared/widgets/section_header.dart';
import '../me/me_view_model.dart';
import 'self_review_view_model.dart';

class SelfReviewPage extends StatelessWidget {
  const SelfReviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SelfReviewViewModel>();
    final meVm = context.watch<MeViewModel>();
    final review = vm.review;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocaleText.tr(
            context,
            en: 'Self review',
            zhHans: '专题梳理',
            zhHant: '專題梳理',
            ja: 'セルフレビュー',
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          AppHeader(
            title: AppLocaleText.tr(
              context,
              en: 'Structured self-review',
              zhHans: 'Structured Self-Review',
              zhHant: 'Structured Self-Review',
              ja: 'Structured Self-Review',
            ),
            subtitle: AppLocaleText.tr(
              context,
              en: 'A slower pass that gathers your recent signals into a few sharper questions.',
              zhHans: '把最近的线索收成几个更利于判断的问题。',
              zhHant: '把最近的線索收成幾個更利於判斷的問題。',
              ja: '最近の手がかりを、少し絞った問いとして見直します。',
            ),
            summary: review == null || review.reviewedDays <= 0
                ? null
                : AppLocaleText.tr(
                    context,
                    en: 'Reviewing signals across ${review.reviewedDays} active days.',
                    zhHans: '正在回看最近 ${review.reviewedDays} 个有记录的日子。',
                    zhHant: '正在回看最近 ${review.reviewedDays} 個有記錄的日子。',
                    ja: '記録のあった ${review.reviewedDays} 日分をまとめて見ています。',
                  ),
            preferenceText: _preferenceText(context, meVm.selectedRepeatArea),
          ),
          const SizedBox(height: 12),
          ..._buildBody(context, vm),
        ],
      ),
    );
  }

  List<Widget> _buildBody(BuildContext context, SelfReviewViewModel vm) {
    final review = vm.review;
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
          EmptyStateBlock(
            icon: Icons.error_outline,
            title: AppLocaleText.tr(
              context,
              en: 'Self review failed to load',
              zhHans: '专题梳理加载失败',
              zhHant: '專題梳理載入失敗',
              ja: 'セルフレビューの読み込みに失敗しました',
            ),
            subtitle: vm.errorMessage,
          ),
        ];
      case LoadState.empty:
        return [
          EmptyStateBlock(
            icon: Icons.psychology_alt_outlined,
            title: AppLocaleText.tr(
              context,
              en: 'Not enough material yet',
              zhHans: '现在还没有足够的素材',
              zhHant: '現在還沒有足夠的素材',
              ja: 'まだ十分な材料がありません',
            ),
            subtitle: AppLocaleText.tr(
              context,
              en: 'Leave a few more entries first. Then this page can gather what keeps repeating, what drains you most, and what is starting to help.',
              zhHans: '先再留下几条记录，这里才能更清楚地收出：反复卡住你的、最消耗你的，以及开始有效的东西。',
              zhHant: '先再留下幾條記錄，這裡才能更清楚地收出：反覆卡住你的、最消耗你的，以及開始有效的東西。',
              ja: 'もう少し記録がたまると、何が繰り返し詰まりやすいか、何がいちばん消耗するか、何が少し効き始めているかが見えやすくなります。',
            ),
          ),
        ];
      case LoadState.ready:
        if (review == null) return const [SizedBox.shrink()];
        return [
          _ReviewSection(
            title: AppLocaleText.tr(context, en: 'What keeps blocking me lately', zhHans: '最近反复卡住我的是什么', zhHant: '最近反覆卡住我的是什麼', ja: '最近くり返し詰まりやすいもの'),
            items: review.repeatedBlockers,
          ),
          const SizedBox(height: 16),
          _ReviewSection(
            title: AppLocaleText.tr(context, en: 'What drains me most lately', zhHans: '最近最消耗我的是什么', zhHant: '最近最消耗我的是什麼', ja: '最近いちばん消耗しやすいもの'),
            items: review.mainDrains,
          ),
          const SizedBox(height: 16),
          _ReviewSection(
            title: AppLocaleText.tr(context, en: 'What is starting to help', zhHans: '最近开始有效的方式是什么', zhHant: '最近開始有效的方式是什麼', ja: '最近少し効き始めているもの'),
            items: review.helpingPatterns,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocaleText.tr(context, en: 'Closing note', zhHans: '收束一句', zhHant: '收束一句', ja: '最後に一言'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Text(review.closingNote),
                ],
              ),
            ),
          ),
        ];
      case LoadState.initial:
        return const [SizedBox.shrink()];
    }
  }

  String _preferenceText(BuildContext context, String? value) {
    final label = switch (value) {
      'work_tasks' => AppLocaleText.tr(context, en: 'work and tasks', zhHans: '工作与任务', zhHant: '工作與任務', ja: '仕事とタスク'),
      'emotion_stress' => AppLocaleText.tr(context, en: 'emotions and stress', zhHans: '情绪与压力', zhHant: '情緒與壓力', ja: '感情とストレス'),
      'relationships' => AppLocaleText.tr(context, en: 'relationships', zhHans: '关系与相处', zhHant: '關係與相處', ja: '人間関係'),
      'time_rhythm' => AppLocaleText.tr(context, en: 'time and rhythm', zhHans: '时间与节奏', zhHant: '時間與節奏', ja: '時間とリズム'),
      _ => AppLocaleText.tr(context, en: 'current focus', zhHans: '当前关注', zhHant: '當前關注', ja: '今の注目'),
    };
    return AppLocaleText.tr(context, en: 'Review angle: $label', zhHans: '梳理角度：$label', zhHant: '梳理角度：$label', ja: '見る角度：$label');
  }
}

class _ReviewSection extends StatelessWidget {
  final String title;
  final List<String> items;

  const _ReviewSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title),
        const SizedBox(height: 12),
        ...items.map(
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
